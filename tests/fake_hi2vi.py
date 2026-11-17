#!/usr/bin/env python3
"""A stdlib fake of hi2vi's workspace API (P1 to P9), for the smoke suite only.

It lives only for the test that starts it: it binds 127.0.0.1 on a free port, writes the port to
--port-file, serves until the test stops it by PID (or --lifetime seconds pass) and keeps every
record in memory. It is never shipped (tests/ is not a managed directory).

Routes, under /api/workspace/<project_id>/ (a Bearer key equal to --key-file's text; another
project is 404; X-Hi2vi-Checkout and X-Hi2vi-Engine are required):

- P1 GET head -> {head, org_id, project_id, inbox_pending}
- P2 GET manifest?since=<head> -> {head, changes: [{path, rev, sha256, size, deleted, kind}]}
- P3 POST fetch {paths} -> {files: [{path, rev, sha256, encoding, content}], rest}, one page at a time
  (the asked paths past the page's byte budget come back in `rest`, to be asked again)
- GET inbox -> {entries: [{id, created_at, kind, items, fields, minted_id}]}: the web's pending agenda
  changes, oldest first
- P4 POST commit {batch_id, command, origin, ops, events, derived, inbox} -> 200 {head, revs} or
  409 {conflicts: [...]}; ops are put / delete / move / append, applied in order, all or nothing;
  an inbox result ({id, state: applied|refused, reason, exit}) for an entry that is not pending makes the
  whole batch a 409 (its conflict {path: null, inbox, state}), like the server; a landed one resolves it;
  a batch_id seen before returns its first answer and applies nothing (P4 idempotency); a put
  whose sha256 equals the record's is a no-op, never a conflict (P5); appends never conflict (P6);
  a move keeps the record's history (P7); derived records are kept as the latest projection (P9).

Like the server, a body over 8,388,608 B is refused with 413 before it is read.

Test-only routes (no key, 127.0.0.1 only): GET /_fake/state (the records, no content),
POST /_fake/write {path, content, kind?, deleted?} or {path, lines} (a change made by another checkout: a revision,
or its lines appended to an append-only record), GET /_fake/file?path=
(one record's content), POST /_fake/inbox {kind, items, fields, minted_id} (a web change: a new pending
entry, answered {id}), GET /_fake/inbox (every entry with its state, reason, exit, batch_id and who resolved
it) and POST /_fake/control {...} (the failure switches, merged into the current ones):
- inbox_race: <entry id> -> another checkout resolves that entry (applied) just before the next commit is
  applied; one-shot (pair it with race to land that checkout's file too);
- offline: true -> every API request is dropped unanswered (the engine sees a network error);
- commit: "drop-before" | "drop-after" -> the next commit is dropped unanswered, before it is applied or
  after (a lost answer); one-shot;
- race: {path, content} or {path, lines} -> another checkout's write (or append) lands just before the next commit
  is applied; one-shot;
- fetch_page: <bytes> -> a fetch page's byte budget (default 6,000,000, the server's), so a test can make
  the engine follow `rest`;
- gate: {route, count, timeout} -> the next `count` requests to that route are held (outside the store's
  lock) until `count` have arrived or `timeout` seconds pass, then all go on together; one-shot. Two engine
  processes that both get through it began at the same head: without the checkout's lock they race.
- break: {route, how} -> every answer to that route is broken until the switch is set to null: "truncate"
  promises 90 bytes more than it sends, then closes (http.client.IncompleteRead); "status" sends a status
  line with no number (BadStatusLine); "longline" sends a header line over http.client's 65,536-byte limit
  (LineTooLong); "badbase64" (fetch only) answers each file as base64 that does not decode (binascii.Error);
  "bad-gateway" answers 502 with an HTML body (a proxy in front of a stopped API); "garbage" answers 200 with a
  body that is not JSON;
- slow: <seconds> -> every API request waits that long before it is answered (a slow but answering server),
  until set to 0; drip: <seconds> -> every API answer's body is sent one byte at a time, that long apart.

Every request is logged as one JSON line in <dir>/requests.jsonl: the route, both headers, whether
the key matched, for a head its X-Hi2vi-Base, for a fetch the paths asked and how many were left in
`rest`, and for a commit its ops without their content. The key itself is never logged.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class Store:
    def __init__(self, org_id: str, project_id: str) -> None:
        self.org_id, self.project_id = org_id, project_id
        self.head = 0
        self.records = {}   # path -> {rev, sha256, kind, content (bytes), deleted}
        self.batches = {}   # batch_id -> (status, answer)
        self.revisions = []  # one per changed op: who, when, which command (O4)
        self.events = []    # P6 lines with their sequence number
        self.derived = {}   # P9: path -> {head, content}
        self.lock = threading.Lock()
        self.inbox = []     # the web's agenda changes: {id, created_at, kind, items, fields, minted_id, state, ...}
        self.control = {"offline": False, "commit": None, "race": None, "gate": None, "fetch_page": None,
                        "inbox_race": None, "break": None, "slow": 0, "drip": 0}
        self.gate = threading.Condition()
        self.gate_seen = 0

    def pass_gate(self, route: str) -> None:
        with self.gate:
            gate = self.control.get("gate")
            if not gate or gate.get("route") != route:
                return
            self.gate_seen += 1
            if self.gate_seen >= int(gate.get("count", 2)):
                self.control["gate"], self.gate_seen = None, 0
                self.gate.notify_all()
                return
            self.gate.wait_for(lambda: self.control.get("gate") is not gate, timeout=float(gate.get("timeout", 5)))
            if self.control.get("gate") is gate:  # timed out: the gate opens for everyone after
                self.control["gate"], self.gate_seen = None, 0
                self.gate.notify_all()

    def live(self, path):
        rec = self.records.get(path)
        return rec if rec is not None and not rec["deleted"] else None

    def manifest(self, since: int) -> dict:
        changes = [{"path": p, "rev": r["rev"], "sha256": r["sha256"], "size": len(r["content"]),
                    "deleted": r["deleted"], "kind": r["kind"]}
                   for p, r in sorted(self.records.items()) if r["rev"] > since]
        return {"head": self.head, "changes": changes}

    def fetch(self, paths) -> dict:
        """One page, like the server: the live files among `paths` in their order until the page's byte budget
        (control `fetch_page`, default the server's 6,000,000) is spent, at least one file per page; `rest` are
        the asked paths left for the next request. A path with no live record is simply absent."""
        budget = int(self.control.get("fetch_page") or 6_000_000)
        files, used, rest = [], 0, []
        for i, path in enumerate(paths):
            rec = self.live(path)
            if rec is None:
                continue
            if files and used + len(rec["content"]) > budget:
                rest = list(paths[i:])
                break
            try:
                content, encoding = rec["content"].decode("utf-8"), "utf8"
            except UnicodeDecodeError:
                content, encoding = base64.b64encode(rec["content"]).decode("ascii"), "base64"
            files.append({"path": path, "rev": rec["rev"], "sha256": rec["sha256"], "encoding": encoding, "content": content})
            used += len(rec["content"])
        return {"files": files, "rest": rest}

    def commit(self, batch: dict, who: str):
        """(status, answer): all or nothing, idempotent by batch_id."""
        bid = batch.get("batch_id")
        if not isinstance(bid, str) or not bid:
            return 400, {"error": "batch_id required"}
        if bid in self.batches:
            status, answer = self.batches[bid]
            return status, answer
        work = {p: dict(r) for p, r in self.records.items()}
        new_head = self.head + 1
        conflicts, changed, revs, lines_out = [], set(), {}, []

        def live(path):
            rec = work.get(path)
            return rec if rec is not None and not rec["deleted"] else None

        def conflict(path, base_rev):
            rec = work.get(path) or {}
            last = next((r for r in reversed(self.revisions) if r["path"] == path), {})
            conflicts.append({"path": path, "base_rev": base_rev, "rev": rec.get("rev"), "sha256": rec.get("sha256"),
                              "by": last.get("by"), "at": last.get("at"), "command": last.get("command")})

        for op in batch.get("ops") or []:
            kind = op.get("op")
            if kind == "put":
                path, base_rev = op["path"], op.get("base_rev")
                raw = op.get("content", "")
                data = base64.b64decode(raw) if op.get("encoding") == "base64" else raw.encode("utf-8")
                if sha(data) != op.get("sha256"):
                    return 400, {"error": f"sha256 does not match the content of {path}"}
                rec = live(path)
                if rec is not None and rec["sha256"] == op["sha256"]:
                    revs[path] = rec["rev"]  # P5: equal content is a no-op
                    continue
                if (rec is None and base_rev is not None) or (rec is not None and base_rev != rec["rev"]):
                    conflict(path, base_rev)
                    continue
                old_kind = rec["kind"] if rec is not None else ("append" if op.get("kind") == "append" else "file")
                work[path] = {"rev": new_head, "sha256": op["sha256"], "kind": old_kind, "content": data, "deleted": False}
                changed.add(path)
            elif kind == "delete":
                path, base_rev = op["path"], op.get("base_rev")
                rec = live(path)
                if rec is None:
                    continue  # already gone: equal, a no-op
                if base_rev != rec["rev"]:
                    conflict(path, base_rev)
                    continue
                work[path] = dict(rec, rev=new_head, deleted=True, content=b"")
                changed.add(path)
            elif kind == "move":
                src, dst, base_rev = op["from"], op["to"], op.get("base_rev")
                rec = live(src)
                if rec is None or base_rev != rec["rev"] or live(dst) is not None:
                    conflict(src, base_rev)
                    continue
                work[dst] = dict(rec, rev=new_head)
                work[src] = dict(rec, rev=new_head, deleted=True, content=b"")
                changed.update((src, dst))
            elif kind == "append":
                path = op["path"]
                rec = live(path)
                add = "".join(line + "\n" for line in op.get("lines") or []).encode("utf-8")
                content = (rec["content"] if rec is not None else b"") + add
                work[path] = {"rev": new_head, "sha256": sha(content), "kind": "append", "content": content, "deleted": False}
                lines_out.extend((path, line) for line in op.get("lines") or [])
                changed.add(path)
            else:
                return 400, {"error": f"unknown op {kind!r}"}
        results = batch.get("inbox") or []
        for result in results:
            if not isinstance(result, dict) or result.get("state") not in ("applied", "refused"):
                return 400, {"error": "an inbox result's state must be applied or refused"}
            if result["state"] == "refused" and not (result.get("reason") or "").strip():
                return 400, {"error": "a refusal carries the engine's line as its reason"}
            entry = self.inbox_entry(result.get("id"))
            if entry is None or entry["state"] != "pending":
                conflicts.append({"path": None, "inbox": result.get("id"), "state": entry and entry["state"]})
        if conflicts:
            answer = (409, {"conflicts": conflicts})
            self.batches[bid] = answer
            return answer
        if changed:
            self.head = new_head
            self.records = work
            for op in batch.get("ops") or []:
                path = op.get("to") or op.get("path")
                if path in changed:
                    self.revisions.append({"path": path, "rev": new_head, "op": op.get("op"), "from_path": op.get("from"),
                                           "batch_id": bid, "by": who, "at": "now", "command": batch.get("command"),
                                           "origin": op.get("origin")})
            for path, line in lines_out:
                self.events.append({"seq": len(self.events) + 1, "path": path, "line": line, "batch_id": bid})
        for item in batch.get("derived") or []:
            self.derived[item["path"]] = {"head": self.head, "content": item.get("content")}
        for result in results:
            self.inbox_entry(result["id"]).update(state=result["state"], reason=result.get("reason"),
                                                  exit=result.get("exit"), batch_id=bid, by=who)
        for op in batch.get("ops") or []:
            path = op.get("to") or op.get("path")
            rec = self.records.get(path)
            if rec is not None:
                revs[path] = rec["rev"]
        answer = (200, {"head": self.head, "revs": revs})
        self.batches[bid] = answer
        return answer

    def inbox_entry(self, eid):
        return next((e for e in self.inbox if e["id"] == eid), None)

    def inbox_add(self, body: dict) -> dict:
        """A web change: one pending entry, oldest first by its sequence."""
        import uuid
        eid = str(uuid.uuid4())
        self.inbox.append({"id": eid, "created_at": f"2026-11-18T10:{len(self.inbox) // 60:02d}:{len(self.inbox) % 60:02d}Z",
                           "kind": body.get("kind"), "items": body.get("items") or [], "fields": body.get("fields") or {},
                           "minted_id": body.get("minted_id"), "state": "pending", "reason": None, "exit": None,
                           "batch_id": None, "by": None})
        return {"id": eid}

    def pending(self) -> list:
        return [{k: e[k] for k in ("id", "created_at", "kind", "items", "fields", "minted_id")}
                for e in self.inbox if e["state"] == "pending"]

    def fake_write(self, body: dict) -> dict:
        """Another checkout's change, landed as one revision."""
        path = body["path"]
        self.head += 1
        if body.get("deleted"):
            rec = self.records.get(path)
            if rec is not None:
                self.records[path] = dict(rec, rev=self.head, deleted=True, content=b"")
        elif isinstance(body.get("lines"), list):  # another checkout's P6 append: its lines after the record's
            rec = self.live(path)
            data = (rec["content"] if rec is not None else b"") + "".join(l + "\n" for l in body["lines"]).encode("utf-8")
            self.records[path] = {"rev": self.head, "sha256": sha(data), "kind": "append", "content": data, "deleted": False}
        else:
            data = body.get("content", "").encode("utf-8")
            kind = body.get("kind") or (self.records.get(path) or {}).get("kind") or "file"
            self.records[path] = {"rev": self.head, "sha256": sha(data), "kind": kind, "content": data, "deleted": False}
        self.revisions.append({"path": path, "rev": self.head, "op": "put", "batch_id": None, "by": "checkout other",
                               "at": "now", "command": "fake-write", "origin": "command"})
        return {"head": self.head}

    def dump(self) -> dict:
        return {"head": self.head,
                "files": {p: {"rev": r["rev"], "sha256": r["sha256"], "kind": r["kind"], "deleted": r["deleted"],
                              "size": len(r["content"])} for p, r in sorted(self.records.items())},
                "events": len(self.events), "derived": {p: d["head"] for p, d in sorted(self.derived.items())},
                "revisions": len(self.revisions)}


def make_handler(store: Store, key: str, log_path: str):
    class Handler(BaseHTTPRequestHandler):
        server_version = "fake-hi2vi"

        def log_message(self, *args):  # quiet: the request log below is the record
            pass

        broken = None  # this request's break switch ({route, how}), read when it arrived
        drip = 0

        def _send(self, status: int, payload: dict) -> None:
            data = json.dumps(payload).encode("utf-8")
            how = (self.broken or {}).get("how")
            if how == "status":
                self.wfile.write(b"HTTP/1.1 OK OK\r\nContent-Length: 0\r\n\r\n")
                self.close_connection = True
                return
            if how == "bad-gateway":
                status, data = 502, b"<html><body>502 Bad Gateway</body></html>"
            elif how == "garbage":
                data = b"<html>not json</html>"
            if how == "longline":
                self.wfile.write(b"HTTP/1.1 200 OK\r\nX-Long: " + b"a" * 70_000 + b"\r\n\r\n")
                self.close_connection = True
                return
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data) + (90 if how == "truncate" else 0)))
            self.end_headers()
            if how == "truncate":
                self.wfile.write(data[:max(1, len(data) // 2)])
                self.wfile.flush()
                self.close_connection = True
                return
            if not self.drip:
                self.wfile.write(data)
                return
            try:
                for i in range(len(data)):
                    self.wfile.write(data[i:i + 1])
                    self.wfile.flush()
                    time.sleep(float(self.drip))
            except OSError:  # the client gave up: nothing more to send
                self.close_connection = True

        def _body(self) -> dict:
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b""
            return json.loads(raw.decode("utf-8")) if raw else {}

        def _log(self, entry: dict) -> None:
            with open(log_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry) + "\n")

        def _drop(self, entry: dict, why: str) -> None:
            entry["status"] = why
            self._log(entry)
            self.close_connection = True  # no answer at all: the client sees the connection closed

        def _handle(self, method: str) -> None:
            url = urlparse(self.path)
            parts = url.path.strip("/").split("/")
            self.broken, self.drip = None, 0
            if parts[:1] != ["_fake"]:
                with store.lock:
                    offline = store.control.get("offline")
                    broken, slow = store.control.get("break"), store.control.get("slow")
                    self.drip = store.control.get("drip") or 0
                if isinstance(broken, dict) and broken.get("route") == (parts[3] if len(parts) == 4 else ""):
                    self.broken = broken
                if slow and not offline:
                    time.sleep(float(slow))
                if offline:
                    with store.lock:
                        return self._drop({"method": method, "path": url.path, "checkout": self.headers.get("X-Hi2vi-Checkout"),
                                           "engine": self.headers.get("X-Hi2vi-Engine"), "auth": "ok"}, "offline")
                store.pass_gate(parts[3] if len(parts) == 4 else "")
                if int(self.headers.get("Content-Length") or 0) > 8_388_608:
                    with store.lock:
                        entry = {"method": method, "path": url.path, "checkout": self.headers.get("X-Hi2vi-Checkout"),
                                 "engine": self.headers.get("X-Hi2vi-Engine"), "auth": "ok", "status": 413,
                                 "bytes": int(self.headers.get("Content-Length") or 0)}
                        self._log(entry)
                    self.rfile.read(entry["bytes"])  # read, so the client sees the answer and not a reset
                    return self._send(413, {"error": "the body is over 8,388,608 bytes"})
            with store.lock:
                if parts[:1] == ["_fake"]:
                    if parts[1:] == ["state"] and method == "GET":
                        return self._send(200, store.dump())
                    if parts[1:] == ["write"] and method == "POST":
                        return self._send(200, store.fake_write(self._body()))
                    if parts[1:] == ["file"] and method == "GET":
                        rec = store.live((parse_qs(url.query).get("path") or [""])[0])
                        if rec is None:
                            return self._send(404, {"error": "no such record"})
                        return self._send(200, {"content": base64.b64encode(rec["content"]).decode("ascii")})
                    if parts[1:] == ["inbox"] and method == "POST":
                        return self._send(200, store.inbox_add(self._body()))
                    if parts[1:] == ["inbox"] and method == "GET":
                        return self._send(200, {"entries": store.inbox})
                    if parts[1:] == ["control"] and method == "POST":
                        with store.gate:
                            store.control.update(self._body())
                            store.gate_seen = 0
                        return self._send(200, {k: v for k, v in store.control.items()})
                    return self._send(404, {"error": "not found"})
                auth = self.headers.get("Authorization") or ""
                bearer = auth[7:] if auth.startswith("Bearer ") else None
                entry = {"method": method, "path": url.path, "checkout": self.headers.get("X-Hi2vi-Checkout"),
                         "engine": self.headers.get("X-Hi2vi-Engine"),
                         "auth": "none" if bearer is None else ("ok" if hmac.compare_digest(bearer, key) else "bad")}
                if len(parts) != 4 or parts[:2] != ["api", "workspace"]:
                    entry["status"] = 404
                    self._log(entry)
                    return self._send(404, {"error": "not found"})
                if entry["auth"] != "ok":
                    entry["status"] = 401
                    self._log(entry)
                    return self._send(401, {"error": "a workspace key is required"})
                if parts[2] != store.project_id:
                    entry["status"] = 404
                    self._log(entry)
                    return self._send(404, {"error": "project not found"})
                if not entry["checkout"] or not entry["engine"]:
                    entry["status"] = 400
                    self._log(entry)
                    return self._send(400, {"error": "X-Hi2vi-Checkout and X-Hi2vi-Engine are required"})
                route = parts[3]
                if route == "head" and method == "GET":
                    entry["base"] = self.headers.get("X-Hi2vi-Base")
                    status, payload = 200, {"head": store.head, "org_id": store.org_id, "project_id": store.project_id,
                                            "inbox_pending": len(store.pending())}
                elif route == "inbox" and method == "GET":
                    status, payload = 200, {"entries": store.pending()}
                    entry["entries"] = len(payload["entries"])
                elif route == "manifest" and method == "GET":
                    since = int((parse_qs(url.query).get("since") or ["0"])[0])
                    entry["since"] = since
                    status, payload = 200, store.manifest(since)
                elif route == "fetch" and method == "POST":
                    paths = self._body().get("paths") or []
                    entry["paths"] = paths
                    status, payload = 200, store.fetch(paths)
                    entry["rest"] = len(payload["rest"])
                    if (self.broken or {}).get("how") == "badbase64":
                        for item in payload["files"]:
                            item.update(encoding="base64", content="not*base64")
                elif route == "commit" and method == "POST":
                    entry["bytes"] = int(self.headers.get("Content-Length") or 0)
                    batch = self._body()
                    replay = batch.get("batch_id") in store.batches
                    fail, store.control["commit"] = store.control.get("commit"), None
                    race, store.control["race"] = store.control.get("race"), None
                    taken, store.control["inbox_race"] = store.control.get("inbox_race"), None
                    entry["batch"] = {"batch_id": batch.get("batch_id"), "replay": replay, "ops": []}
                    if fail == "drop-before":
                        return self._drop(entry, "drop-before")
                    if race:
                        store.fake_write(race)
                    if taken and store.inbox_entry(taken) is not None:
                        store.inbox_entry(taken).update(state="applied", exit=0, by="checkout other")
                    status, payload = store.commit(batch, f"checkout {entry['checkout']}")
                    entry["batch"] = {
                        "batch_id": batch.get("batch_id"), "command": batch.get("command"), "origin": batch.get("origin"),
                        "replay": replay, "derived": sorted(d.get("path") for d in batch.get("derived") or []),
                        "events": len(batch.get("events") or []),
                        "inbox": [{k: r.get(k) for k in ("id", "state", "exit", "reason")} for r in batch.get("inbox") or []
                                  if isinstance(r, dict)],
                        "ops": [dict({k: v for k, v in op.items() if k not in ("content", "lines")},
                                     **({"lines": len(op["lines"])} if "lines" in op else {}))
                                for op in batch.get("ops") or []]}
                else:
                    status, payload = 404, {"error": "not found"}
                if route == "commit" and method == "POST" and fail == "drop-after":
                    return self._drop(entry, f"drop-after {status}")
                entry["status"] = status
                if self.broken:
                    entry["break"] = self.broken.get("how")
                self._log(entry)
                self.reply = (status, payload)  # sent outside the store's lock: a slow or broken answer holds no one

        def _serve(self, method: str) -> None:
            self.reply = None
            self._handle(method)
            if self.reply is not None:
                self._send(*self.reply)

        def do_GET(self):
            self._serve("GET")

        def do_POST(self):
            self._serve("POST")

    return Handler


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dir", required=True, help="where requests.jsonl is written")
    parser.add_argument("--port-file", required=True, help="the chosen port is written here once listening")
    parser.add_argument("--key-file", required=True, help="the one workspace key this fake accepts (never on argv)")
    parser.add_argument("--project", required=True)
    parser.add_argument("--org", required=True)
    parser.add_argument("--lifetime", type=float, default=900.0, help="exit after this many seconds (a stray fake never outlives its test)")
    args = parser.parse_args()
    with open(args.key_file, encoding="utf-8") as f:
        key = f.read().strip()
    os.makedirs(args.dir, exist_ok=True)
    store = Store(args.org, args.project)
    ThreadingHTTPServer.daemon_threads = True
    server = ThreadingHTTPServer(("127.0.0.1", 0), make_handler(store, key, os.path.join(args.dir, "requests.jsonl")))
    tmp = args.port_file + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(str(server.server_address[1]))
    os.replace(tmp, args.port_file)
    timer = threading.Timer(args.lifetime, lambda: os._exit(0))
    timer.daemon = True
    timer.start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
