#!/usr/bin/env python3
"""A stdlib fake of hi2vi's workspace API (P1 to P9), for the smoke suite only.

It lives only for the test that starts it: it binds 127.0.0.1 on a free port, writes the port to
--port-file, serves until the test stops it by PID (or --lifetime seconds pass) and keeps every
record in memory. It is never shipped (tests/ is not a managed directory).

Routes, under /api/workspace/<project_id>/ (a Bearer key equal to --key-file's text; another
project is 404; X-Hi2vi-Checkout and X-Hi2vi-Engine are required):

- P1 GET head -> {head, org_id, project_id, inbox_pending}
- P2 GET manifest?since=<head> -> {head, changes: [{path, rev, sha256, size, deleted, kind}]}
- P3 POST fetch {paths} -> {files: [{path, rev, sha256, encoding, content}]}
- P4 POST commit {batch_id, command, origin, ops, events, derived, inbox} -> 200 {head, revs} or
  409 {conflicts: [...]}; ops are put / delete / move / append, applied in order, all or nothing;
  a batch_id seen before returns its first answer and applies nothing (P4 idempotency); a put
  whose sha256 equals the record's is a no-op, never a conflict (P5); appends never conflict (P6);
  a move keeps the record's history (P7); derived records are kept as the latest projection (P9).

Test-only routes (no key, 127.0.0.1 only): GET /_fake/state (the records, no content) and
POST /_fake/write {path, content, kind?, deleted?} (a change made by another checkout).

Every request is logged as one JSON line in <dir>/requests.jsonl: the route, both headers, whether
the key matched, and for a commit its ops without their content. The key itself is never logged.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
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

    def live(self, path):
        rec = self.records.get(path)
        return rec if rec is not None and not rec["deleted"] else None

    def manifest(self, since: int) -> dict:
        changes = [{"path": p, "rev": r["rev"], "sha256": r["sha256"], "size": len(r["content"]),
                    "deleted": r["deleted"], "kind": r["kind"]}
                   for p, r in sorted(self.records.items()) if r["rev"] > since]
        return {"head": self.head, "changes": changes}

    def fetch(self, paths) -> dict:
        files = []
        for path in paths:
            rec = self.live(path)
            if rec is None:
                continue
            try:
                content, encoding = rec["content"].decode("utf-8"), "utf8"
            except UnicodeDecodeError:
                content, encoding = base64.b64encode(rec["content"]).decode("ascii"), "base64"
            files.append({"path": path, "rev": rec["rev"], "sha256": rec["sha256"], "encoding": encoding, "content": content})
        return {"files": files}

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
        for op in batch.get("ops") or []:
            path = op.get("to") or op.get("path")
            rec = self.records.get(path)
            if rec is not None:
                revs[path] = rec["rev"]
        answer = (200, {"head": self.head, "revs": revs})
        self.batches[bid] = answer
        return answer

    def fake_write(self, body: dict) -> dict:
        """Another checkout's change, landed as one revision."""
        path = body["path"]
        self.head += 1
        if body.get("deleted"):
            rec = self.records.get(path)
            if rec is not None:
                self.records[path] = dict(rec, rev=self.head, deleted=True, content=b"")
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

        def _send(self, status: int, payload: dict) -> None:
            data = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _body(self) -> dict:
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b""
            return json.loads(raw.decode("utf-8")) if raw else {}

        def _log(self, entry: dict) -> None:
            with open(log_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry) + "\n")

        def _handle(self, method: str) -> None:
            url = urlparse(self.path)
            parts = url.path.strip("/").split("/")
            with store.lock:
                if parts[:1] == ["_fake"]:
                    if parts[1:] == ["state"] and method == "GET":
                        return self._send(200, store.dump())
                    if parts[1:] == ["write"] and method == "POST":
                        return self._send(200, store.fake_write(self._body()))
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
                    status, payload = 200, {"head": store.head, "org_id": store.org_id, "project_id": store.project_id,
                                            "inbox_pending": 0}
                elif route == "manifest" and method == "GET":
                    since = int((parse_qs(url.query).get("since") or ["0"])[0])
                    entry["since"] = since
                    status, payload = 200, store.manifest(since)
                elif route == "fetch" and method == "POST":
                    paths = self._body().get("paths") or []
                    entry["paths"] = paths
                    status, payload = 200, store.fetch(paths)
                elif route == "commit" and method == "POST":
                    batch = self._body()
                    replay = batch.get("batch_id") in store.batches
                    status, payload = store.commit(batch, f"checkout {entry['checkout']}")
                    entry["batch"] = {
                        "batch_id": batch.get("batch_id"), "command": batch.get("command"), "origin": batch.get("origin"),
                        "replay": replay, "derived": sorted(d.get("path") for d in batch.get("derived") or []),
                        "events": len(batch.get("events") or []), "inbox": len(batch.get("inbox") or []),
                        "ops": [dict({k: v for k, v in op.items() if k not in ("content", "lines")},
                                     **({"lines": len(op["lines"])} if "lines" in op else {}))
                                for op in batch.get("ops") or []]}
                else:
                    status, payload = 404, {"error": "not found"}
                entry["status"] = status
                self._log(entry)
                return self._send(status, payload)

        def do_GET(self):
            self._handle("GET")

        def do_POST(self):
            self._handle("POST")

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
    server = HTTPServer(("127.0.0.1", 0), make_handler(store, key, os.path.join(args.dir, "requests.jsonl")))
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
