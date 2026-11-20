"""Cloud mode (link, unlink, sync, mark-committed and the command boundary), moved as is from the one-file
engine. Imports wf_store and wf_git; the parser it re-runs inbox entries with is a seam bound by the entry."""
from __future__ import annotations

import difflib
import hashlib
import json
import os
import posixpath
import re
import shlex
import shutil
import stat
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse
import wf_store  # noqa: E402 -- the inbox applier sets its _CLOUD_UNDO (write_text's undo notes)

from wf_store import (  # noqa: E402
    _git, _git_available, _git_dir, _meter_ts, _one_line, _one_line_usage_errors, _worktree_entries, AGENDA,
    AGENDA_ID_RE, all_active_phases, append_event, current_stream, GENERATED_FILES, HOST_ROOT,
    installed_workspace_version, NESTED, normalize_id_args, now_iso, phase_dirs, phase_in_flight, read_json,
    rebuild_index_and_state, require_slice, ROOT, shown, write_json, write_text,
)
from wf_git import (  # noqa: E402
    _in_worktree_set,
)

# The names this module calls in a module above it. It never imports that module: the entry (workflow.py) binds
# each name here before any command runs.
SEAMS = {
    "workflow": (
        'build_parser',
    ),
}


# ---------------------------------------------------------------------------
# Cloud mode: hi2vi holds this workspace's truth and the disk is its copy. A checkout is linked exactly
# when `<ROOT>/.hi2vi/link.json` exists ({schema, server, org_id, project_id, linked_at}; no key). Without
# it `main()` calls the command exactly as before: nothing below is read, imported or run, and no socket
# is opened. With it, the command boundary syncs: before the command, a fast-forward pull of what changed
# in hi2vi (then the generated files are rebuilt); the command runs unchanged against the disk; after it,
# every truth-set difference against `.hi2vi/base.json` (the last-synced head, and each path's rev and sha256),
# in all-or-nothing batches sent in order (over CLOUD_BATCH_MAX a change splits; a 409 on a later batch leaves the
# earlier ones landed). Diffing the tree, not wrapping writes, also catches the files
# agents write with their own tools (plan.md, result.md, topics/), which ride the next batch as `carried`.
# The wire is hi2vi's workspace API under /api/workspace/<project_id>/: head, manifest?since=, fetch and
# commit, with the workspace key only as a Bearer header, read from the user's config, never from argv.
CLOUD_DIR = ".hi2vi"
CLOUD_SCHEMA = 1
# A request fails when it stalls, never while its bytes still move: no byte for CLOUD_TIMEOUT seconds, or fewer than
# CLOUD_FLOOR bytes in a CLOUD_TIMEOUT window (a peer dripping its answer: about 100 B/s, far below any real link). While
# the connection is set up only the peer's bytes count toward the floor: this checkout's own (a CONNECT line, a
# ClientHello of about 200 B to over 1,500 B by the TLS library) prove nothing about the path. Every
# wait of a request is a wait on its TCP socket (_CloudSocket): the connect, a proxy's CONNECT tunnel, the TLS handshake
# (TLS runs over memory buffers, so its bytes are counted as they cross the socket, never a record or a send at a time),
# each send and each read. No such wait lasts over CLOUD_STEP (the connect, where nothing can move, waits once for what
# the wire allows); after each, progress is read at the socket (the bytes in and out, and this checkout's upload
# draining from the socket's queue). A transfer this machine sees moving always finishes; only the session hook keeps a
# wall-clock budget (CLOUD_HOOK_BUDGET), checked before every wait. A name lookup (getaddrinfo) has no bound.
CLOUD_TIMEOUT = 10  # seconds a request waits for its next byte
CLOUD_FLOOR = 1024  # bytes a request must move in each CLOUD_TIMEOUT window
CLOUD_STEP = 1.0  # the longest single wait on the socket: then progress is read and the rules judge again
CLOUD_SEND_PIECE = 65536  # bytes offered to one send (the kernel takes what fits) or taken by one read
CLOUD_TLS_PIECE = 16384  # plaintext encrypted at a time (one TLS record), so an upload is never held twice in memory
CLOUD_LOCAL_HOSTS = ("localhost", "127.0.0.1", "::1")
# The append-only files (the union files of .gitattributes): synced as appended lines, never as revisions.
CLOUD_APPEND_RE = re.compile(r"works/events\.jsonl")
CLOUD_DERIVED = ("works/state.json", "works/index.json")  # sent with every batch as the latest projection only
CLOUD_RACY_NS = 2_000_000_000  # a stat-cache entry this close to the clock is hashed again next time
CLOUD_BATCH_MAX = 8_000_000  # bytes per batch as sent: hi2vi answers 413 above 8 MiB, so a bigger change splits
CLOUD_LOCK_WAIT = 120.0  # seconds a command waits for another command of this checkout before it refuses
CLOUD_HOOK_LOCK_WAIT = 5.0  # the session hook's wait: it never holds a session start for long
# The session hook's whole cloud time: the lock wait and every request of its boundary, against the hook's 15 s
# timeout in settings.json; the interpreter's start, the disk scan and the resume card fit in the 6 s left.
CLOUD_HOOK_BUDGET = 9.0
CLOUD_FAIL_OPEN = ("compact-resume",)  # the SessionStart hook: a cloud stop is a note, the command runs on the disk
CLOUD_FETCH_PATHS = 5000  # paths per P3 request (hi2vi takes at most 20,000 and pages its answer by bytes)
# The safety half. One engine process per checkout: `fcntl.flock` on `.hi2vi/lock` around the whole boundary
# (begin, command, commit). A journal, `.hi2vi/journal.json`, names every interrupted state: `running` from the
# begin step's end until the commit step clears it (a command that died midway: the next command refuses and
# names sync), and `pushing` with the batch ids still to send (their bodies in `.hi2vi/outbox/`), from just
# before the push until the base is updated, so a lost answer is resent with the same batch_id, which hi2vi
# applies once. A pull needs no journal: a revisioned file it wrote equals the cloud's sha, which reads as "same";
# an append file it merged around lines not yet sent (or in an order of its own) does not, so each merge's result
# is saved in base.json (`pulling`) before its write and settled against the disk when base.json is next read
# (cloud_settle_pull); and a pull stopped by a write error records in base.json what it wrote before it stopped.
# One rule at every boundary (begin, commit, link, unlink, sync): any failure inside it ends the command in
# CloudError's one line (the session hook: a note, exit 0), never a traceback or a false success.


class CloudError(Exception):
    """A cloud-mode stop. Its message is one line, safe to print: never the key."""


class CloudUnreachable(CloudError):
    pass


class _CloudStall(Exception):
    """A request that stopped moving (or ran past the session hook's budget); its message is the one-line why.
    Raised only while the request waits for more bytes, so an answer already in hand is never turned into a stall."""


class _CloudWire:
    """One request's progress. `left(judge)` is called before every wait on the socket and says how long that wait may
    last; it raises _CloudStall when the request has stalled: the session hook's deadline passed, no byte moved for
    CLOUD_TIMEOUT seconds, or (when `judge`) a CLOUD_TIMEOUT window that moved fewer than CLOUD_FLOOR bytes. The floor
    is judged before every wait that follows movement, and at every step while the connection is set up (the connect, a
    proxy's tunnel, the TLS handshake: no server thinks there); a silent wait for the answer is the server thinking, and
    only the idle limit and the deadline judge it. During the set-up only the peer's bytes count toward the floor
    (`moved(n, floor=False)` for this checkout's own: they still reset the idle clock). The request's sending, and from
    the answer's first byte its reading, have floor windows apart. There is no timer: nothing can fire after the answer
    is read."""

    def __init__(self, deadline=None) -> None:
        self.deadline = deadline  # time.monotonic() past which no wait starts (the session hook's budget), or None
        self.last = self.window = time.monotonic()
        self.count = 0
        self.sending = True  # until the answer's first byte
        self.by_deadline = False  # the last wait was cut short by the deadline (a socket timeout then names the budget)

    def answer(self) -> None:
        """The answer's first byte (over TLS its first decrypted byte): the answer's own floor window starts here."""
        if self.sending:
            self.sending, self.window, self.count = False, time.monotonic(), 0

    def moved(self, n: int, answer: bool = False, floor: bool = True) -> None:
        if not n or n <= 0:
            return
        if answer:
            self.answer()
        self.last = time.monotonic()
        if floor:
            self.count += n

    def left(self, judge: bool = True) -> float:
        now = time.monotonic()
        idle = CLOUD_TIMEOUT - (now - self.last)
        hook = None if self.deadline is None else self.deadline - now
        if hook is not None and hook < 0.1:
            raise _CloudStall(f"the session hook's {CLOUD_HOOK_BUDGET:g} s for hi2vi ran out")
        if idle <= 0:
            raise _CloudStall(f"no byte moved for {CLOUD_TIMEOUT:g} s")
        if judge and now - self.window >= CLOUD_TIMEOUT:
            if self.count < CLOUD_FLOOR:
                raise _CloudStall(f"fewer than {CLOUD_FLOOR} bytes moved in {CLOUD_TIMEOUT:g} s")
            self.window, self.count = now, 0
        self.by_deadline = hook is not None and hook < idle
        return min(idle, hook) if hook is not None else idle

    def timed_out(self) -> str:
        """The line for a connect that timed out (the one wait that is not a _CloudSocket step)."""
        if self.by_deadline:
            return f"the session hook's {CLOUD_HOOK_BUDGET:g} s for hi2vi ran out"
        return f"no byte moved for {CLOUD_TIMEOUT:g} s"


def _cloud_unsent(sock):
    """Bytes queued on this socket that the peer has not taken yet (Linux SIOCOUTQ, macOS SO_NWRITE), or None. While
    an upload drains from the socket's buffer the request is still moving, though no send or read returns."""
    import socket
    try:
        if sys.platform.startswith("linux"):
            import fcntl
            import struct
            import termios
            return struct.unpack("i", fcntl.ioctl(sock.fileno(), termios.TIOCOUTQ, b"\0\0\0\0"))[0]
        if sys.platform == "darwin":
            return sock.getsockopt(socket.SOL_SOCKET, 0x1024)  # SO_NWRITE
    except (OSError, ValueError, AttributeError, ImportError):
        return None
    return None


class _CloudSocket:
    """A connection's TCP socket seen through the request's _CloudWire, from the moment it connects: a proxy's tunnel,
    the TLS handshake, every send and every read wait on it in steps of at most CLOUD_STEP. Before each step the wire
    says whether the request has stalled; after each, what moved is counted: the bytes sent or read, and the bytes of
    this checkout's upload that left the socket's queue meanwhile. Over TLS (`start_tls`) the encryption runs over
    memory buffers (ssl.MemoryBIO), so the TLS bytes cross this socket too and count as they move, never a whole record
    or a whole send piece at a time. While `setup`, this checkout's own bytes reset the idle clock but count nothing
    toward the floor: only the peer's do."""

    def __init__(self, sock, wire: _CloudWire) -> None:
        self._sock, self._wire = sock, wire
        self.setup = True  # the connection is being set up: the floor is judged at every step
        self.answers = False  # a read is the answer's (plain HTTP once set up); a tunnel's or TLS's raw reads are not
        self._tls = None  # (ssl.SSLObject, incoming MemoryBIO, outgoing MemoryBIO) once start_tls ran

    def __getattr__(self, name):
        return getattr(self._sock, name)

    def _wait(self, op, *args):
        """op(*args) on the TCP socket, in waits of at most CLOUD_STEP each judged by the wire first."""
        import socket
        judge = True
        while True:
            wait = min(self._wire.left(judge), CLOUD_STEP)
            queued = _cloud_unsent(self._sock)
            self._sock.settimeout(wait)
            try:
                return op(*args)
            except socket.timeout:
                now = _cloud_unsent(self._sock)
                drained = queued is not None and now is not None and now < queued
                if drained:  # the upload still draining from the socket is progress
                    self._wire.moved(queued - now, floor=not self.setup)
                judge = drained or self.setup

    def _send(self, data) -> None:
        view = memoryview(data).cast("B")
        while len(view):
            n = self._wait(self._sock.send, view[:CLOUD_SEND_PIECE])
            self._wire.moved(n, floor=not self.setup)
            view = view[n:]

    def _flush(self) -> None:
        out = self._tls[2].read()
        if out:
            self._send(out)

    def _tls_io(self, op, *args):
        """op(*args) on the TLS object: what it writes goes out on the socket, and what it waits for is read from it."""
        import ssl
        incoming = self._tls[1]
        while True:
            try:
                result = op(*args)
            except ssl.SSLWantReadError:
                self._flush()
                if incoming.eof:
                    raise ConnectionResetError("the TLS connection closed mid-record")
                data = self._wait(self._sock.recv, CLOUD_SEND_PIECE)
                self._wire.moved(len(data))
                if data:
                    incoming.write(data)
                else:
                    incoming.write_eof()
                continue
            self._flush()
            return result

    def start_tls(self, context, hostname: str) -> None:
        """The TLS handshake over this socket (the context's verification and hostname check, as wrap_socket's)."""
        import ssl
        incoming, outgoing = ssl.MemoryBIO(), ssl.MemoryBIO()
        self._tls = (context.wrap_bio(incoming, outgoing, server_hostname=hostname), incoming, outgoing)
        self._tls_io(self._tls[0].do_handshake)

    def sendall(self, data, flags=0) -> None:
        if self._tls is None:
            return self._send(data)
        view = memoryview(data).cast("B")
        while len(view):
            view = view[self._tls_io(self._tls[0].write, view[:CLOUD_TLS_PIECE]):]

    def recv_into(self, buf, nbytes=0, flags=0) -> int:
        import ssl
        if self._tls is None:
            n = self._wait(self._sock.recv_into, buf, nbytes)
            self._wire.moved(n, answer=self.answers)
            return n
        try:
            n = self._tls_io(self._tls[0].read, nbytes or len(buf), buf)
        except (ssl.SSLError, ConnectionResetError):
            if self._tls[1].eof:
                return 0  # the peer closed: an answer cut short is http.client's IncompleteRead, as with wrap_socket
            raise
        if n:
            self._wire.answer()
        return n

    def makefile(self, mode="r", buffering=None, **_):
        import io
        import socket
        self._sock._io_refs += 1  # as socket.makefile does: the socket stays open until the answer is read
        return io.BufferedReader(socket.SocketIO(self, "rb"))


def _cloud_connect(address, wire: _CloudWire, source_address=None):
    """socket.create_connection with each attempt's wait bounded by the wire. Nothing can move while a connect waits,
    so one wait of what the wire allows (the idle limit, the session hook's deadline) is the whole rule there."""
    import socket
    host, port = address
    err = None
    for family, kind, proto, _, addr in socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM):
        wait = wire.left()
        sock = socket.socket(family, kind, proto)
        try:
            sock.settimeout(wait)
            if source_address:
                sock.bind(source_address)
            sock.connect(addr)
            return sock
        except OSError as exc:
            err = exc
            sock.close()
    raise err if err is not None else OSError(f"no address for {host}")


def _cloud_handlers(wire: _CloudWire) -> list:
    """urllib's HTTP and HTTPS handlers, whose connections wait only on a _CloudSocket: http.client's own connect
    (the TCP connect, then a proxy's CONNECT tunnel) runs on a socket made through the wire, and HTTPS then runs its
    handshake and every TLS byte through that same socket (never wrap_socket's own waits)."""
    import http.client
    import urllib.request

    def counted(base):
        class Connection(base):
            def connect(self):
                self._create_connection = lambda address, timeout=None, source_address=None: \
                    _CloudSocket(_cloud_connect(address, wire, source_address), wire)
                http.client.HTTPConnection.connect(self)
                tls = isinstance(self, getattr(http.client, "HTTPSConnection", ()))
                if tls:
                    self.sock.start_tls(self._context, self._tunnel_host or self.host)
                self.sock.setup, self.sock.answers = False, not tls
        return Connection

    out = []
    for name in ("HTTPHandler", "HTTPSHandler"):
        handler = getattr(urllib.request, name, None)  # HTTPSHandler is absent without ssl
        if handler is None:
            continue

        class Counted(handler):
            def do_open(self, http_class, req, **kw):
                return super().do_open(counted(http_class), req, **kw)
        out.append(Counted())
    return out


def cloud_stop_line(exc: BaseException, step: str) -> str:
    """The one line for a failure inside a linked command's boundary: a CloudError's own line, anything else
    named by its class (never a traceback). `step`: begin (the command did not run), commit (it ran, its change
    is on disk only) or sync."""
    if isinstance(exc, CloudError):
        return str(exc)
    what = exc.__class__.__name__ + (f": {_one_line(str(exc))[:200]}" if _one_line(str(exc)) else "")
    if step == "commit":
        return f"this change is on disk but not in hi2vi ({what}): run sync"
    if step == "begin":
        return f"the step before the command stopped ({what}), so the command did not run: run sync to see this checkout against hi2vi"
    return f"{step} stopped ({what}): run sync to see this checkout against hi2vi"


class CloudConflict(CloudError):
    """A batch hi2vi refused with 409: it wrote nothing. `conflicts` is the answer's list (a file's, or an inbox
    result's for an entry no longer pending: `{path: None, inbox, state}`)."""

    def __init__(self, message: str, conflicts=None) -> None:
        super().__init__(message)
        self.conflicts = conflicts if isinstance(conflicts, list) else []


class CloudLock:
    """The checkout's lock: `fcntl.flock(LOCK_EX)` on `.hi2vi/lock`, held around a whole command's boundary, so
    an orchestrator and its executors running engine commands at once in one checkout are serialized. A second
    process waits up to `wait` seconds, then refuses with one line. Re-entrant within one process (a nested
    acquire only counts), so a step that runs inside the boundary (the agenda inbox applier) can call
    `CloudSession.begin()` and `commit()` while the lock is held; closing the one descriptor releases it."""

    depth = 0
    fd = None

    def __init__(self, wait: float = CLOUD_LOCK_WAIT) -> None:
        self.wait = wait

    def acquire(self) -> None:
        if CloudLock.depth:
            CloudLock.depth += 1
            return
        try:
            import fcntl
        except ImportError:
            raise CloudError("cloud mode needs fcntl.flock (macOS or Linux) to lock this checkout: nothing was changed")
        import errno
        path = ROOT / CLOUD_DIR / "lock"
        try:
            fd = os.open(str(path), os.O_RDWR | os.O_CREAT, 0o600)  # written to: LOCK_EX where flock is emulated
        except OSError as exc:
            raise CloudError(f"{shown(path)} cannot be opened ({exc.__class__.__name__}): nothing was changed")
        deadline = time.monotonic() + self.wait
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError as exc:
                busy = exc.errno in (errno.EACCES, errno.EAGAIN, errno.EWOULDBLOCK)
                if busy and time.monotonic() < deadline:
                    time.sleep(0.05)
                    continue
                os.close(fd)
                if busy:
                    raise CloudError(f"another engine command has held this checkout's lock ({shown(path)}) for "
                                     f"{self.wait:g} s: nothing was changed; run it again when that one ends")
                raise CloudError(f"{shown(path)} cannot be locked ({exc.__class__.__name__}): nothing was changed")
        CloudLock.fd, CloudLock.depth = fd, 1

    def release(self) -> None:
        if CloudLock.depth <= 0:
            return
        CloudLock.depth -= 1
        if CloudLock.depth == 0 and CloudLock.fd is not None:
            fd, CloudLock.fd = CloudLock.fd, None
            os.close(fd)

    def __enter__(self) -> "CloudLock":
        self.acquire()
        return self

    def __exit__(self, *exc) -> bool:
        self.release()
        return False


def cloud_link_file() -> Path:
    return ROOT / CLOUD_DIR / "link.json"


def cloud_kind(rel: str) -> str:
    return "append" if CLOUD_APPEND_RE.fullmatch(rel) else "file"


def cloud_truth_rel(rel: str) -> bool:
    """True for a ROOT-relative POSIX path in the truth set: under works/ or docs/, minus the generated files,
    the templates, the version marker and temp files. (Folders whose .gitignore is `*` are cut in the walk.)"""
    import fnmatch
    if not isinstance(rel, str) or "\\" in rel or not rel.startswith(("works/", "docs/")):
        return False
    parts = rel.split("/")
    if any(p in ("", ".", "..") for p in parts):
        return False
    if rel.startswith("works/templates/") or rel == "works/.workspace-version.json":
        return False
    if any(fnmatch.fnmatchcase(rel, pattern) for pattern in GENERATED_FILES):
        return False
    return not (parts[-1].startswith(".tmp_") or parts[-1] == ".DS_Store")


def _cloud_ignored_dir(folder: Path) -> bool:
    """A folder the engine keeps local (its .gitignore holds only `*`: the design caches and renders)."""
    try:
        lines = [l.strip() for l in (folder / ".gitignore").read_text(encoding="utf-8").splitlines() if l.strip()]
    except (OSError, UnicodeDecodeError):
        return False
    return lines == ["*"]


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def cloud_scan(cache: dict) -> dict:
    """{rel: sha256} of the truth set on disk. `cache` (rel -> [mtime_ns, size, ino, sha256]) skips hashing a
    file whose stat is unchanged; it is refreshed in place."""
    found = {}
    for top in ("works", "docs"):
        for dirpath, dirnames, filenames in os.walk(str(ROOT / top)):
            folder = Path(dirpath)
            if _cloud_ignored_dir(folder):
                dirnames[:] = []
                continue
            for name in filenames:
                path = folder / name
                rel = path.relative_to(ROOT).as_posix()
                if not cloud_truth_rel(rel):
                    continue
                try:
                    st = os.lstat(str(path))
                except OSError:
                    continue
                if not stat.S_ISREG(st.st_mode):
                    continue
                key = [st.st_mtime_ns, st.st_size, st.st_ino]
                hit = cache.get(rel)
                if isinstance(hit, list) and len(hit) == 4 and hit[:3] == key:
                    found[rel] = hit[3]
                    continue
                try:
                    digest = _sha(path.read_bytes())
                except OSError:
                    continue
                cache[rel] = key + [digest]
                found[rel] = digest
    for rel in [r for r in cache if r not in found]:
        del cache[rel]
    return found


def _cloud_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp_", suffix=path.name)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _cloud_remove(rel: str) -> None:
    """Delete a pulled deletion's file, then every folder it leaves empty (never works/ or docs/ itself)."""
    path = ROOT / rel
    try:
        path.unlink()
    except FileNotFoundError:
        pass
    folder = path.parent
    while folder != ROOT and folder.parent != ROOT:
        try:
            folder.rmdir()
        except OSError:
            break
        folder = folder.parent


def _cloud_content(data: bytes) -> tuple:
    """(encoding, content) for the wire: utf8 text, else base64."""
    try:
        return "utf8", data.decode("utf-8")
    except UnicodeDecodeError:
        import base64
        return "base64", base64.b64encode(data).decode("ascii")


def cloud_key_file() -> Path:
    cfg = os.environ.get("XDG_CONFIG_HOME") or ""
    return (Path(cfg) if os.path.isabs(cfg) else Path.home() / ".config") / "hi2vi" / "workspace-keys.json"


def cloud_key_problem(path: Path):
    """One line when the key file, or its folder, is open to anyone but its owner (group or others hold any
    permission bit, or another user owns it), else None. Missing is not a problem here. Never the key."""
    for target, mode in ((path.parent, 0o700), (path, 0o600)):
        try:
            st = os.stat(str(target))
        except FileNotFoundError:
            continue
        except OSError as exc:
            return f"{target} cannot be read ({exc.__class__.__name__}): nothing was changed"
        if hasattr(os, "getuid") and st.st_uid != os.getuid():
            return (f"{target} belongs to another user, so the workspace key there is not yours alone: "
                    "nothing was changed")
        if st.st_mode & 0o077:
            return (f"{target} can be read by group or others (mode {stat.S_IMODE(st.st_mode):04o}), and it holds "
                    f"workspace keys: run chmod {mode:o} {shlex.quote(str(target))}, then run this again "
                    "(nothing was changed)")
    return None


def cloud_server_check(server: str) -> str:
    """The server's base URL, refused unless https:// (plain http:// only to a local host)."""
    parsed = urlparse(server)
    host = (parsed.hostname or "").lower()
    local = host in CLOUD_LOCAL_HOSTS or host.endswith(".localhost")
    if not host or not (parsed.scheme == "https" or (parsed.scheme == "http" and local)):
        raise CloudError(f"hi2vi server {server} must be https:// (plain http:// only to localhost, "
                         "127.0.0.1, ::1 or *.localhost): nothing was changed")
    return server.rstrip("/")


class CloudLink:
    """The link (server, project) and the client. The key lives only in this object's request headers.
    `link` and `key` are given only by the link command, before the checkout's link file exists."""

    def __init__(self, link=None, key=None) -> None:
        if link is None:
            path = cloud_link_file()
            try:
                link = read_json(path)
            except (OSError, ValueError) as exc:
                raise CloudError(f"{shown(path)} is unreadable ({exc.__class__.__name__}): this checkout's link is broken")
            if not isinstance(link, dict) or not isinstance(link.get("server"), str) or not link.get("project_id"):
                raise CloudError(f"{shown(path)} lacks its server or project_id: this checkout's link is broken")
        self.server = cloud_server_check(link["server"].rstrip("/"))
        self.project = str(link["project_id"])
        host = (urlparse(self.server).hostname or "").lower()
        self.local = host in CLOUD_LOCAL_HOSTS or host.endswith(".localhost")
        checkout = link.get("checkout")
        if not isinstance(checkout, str) or not checkout:
            import platform
            checkout = platform.node().split(".")[0] or "checkout"
        self.checkout = re.sub(r"[^A-Za-z0-9._-]+", "-", checkout)[:64] or "checkout"
        version = installed_workspace_version()
        self.engine = f"v{version}" if version is not None else "unknown"
        self._key = key if key is not None else self._read_key(link["server"])
        self.deadline = None  # time.monotonic() past which no request is made (the session hook's budget)

    def _read_key(self, raw_server: str) -> str:
        path = cloud_key_file()
        problem = cloud_key_problem(path)
        if problem:
            raise CloudError(problem)
        try:
            data = read_json(path)
        except (OSError, ValueError):
            raise CloudError(f"no workspace key for this checkout: {path} is missing or unreadable (run link again)")
        servers = data if isinstance(data, dict) else {}
        projects = servers.get(raw_server) or servers.get(self.server)
        entry = projects.get(self.project) if isinstance(projects, dict) else None
        key = entry.get("key") if isinstance(entry, dict) else None
        if not isinstance(key, str) or not key.strip():
            raise CloudError(f"no workspace key for {self.server} project {self.project} in {path} (run link again)")
        if any(ch.isspace() or ord(ch) < 32 or ord(ch) == 127 for ch in key.strip()):
            raise CloudError(f"the workspace key for {self.server} project {self.project} in {path} holds spaces or "
                             "control characters, so it is not a key (run link again): nothing was changed")
        return key.strip()

    def call(self, method: str, route: str, body=None, extra=None) -> tuple:
        """(status, payload) of one request. Any failure to get a whole answer raises CloudUnreachable: a
        network error, a timeout, a cut or malformed answer (http.client's HTTPException), anything else the
        client raises; a 3xx is never followed (the key stays with the host it was meant for); a request fails
        when it stalls (_CloudWire), never while its bytes still move, and the session hook's request also when
        its `deadline` passes. An answer that is not JSON reads as {}. `extra` adds headers (P1's X-Hi2vi-Base)."""
        import urllib.request
        from urllib.parse import quote

        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, *a, **k):
                return None

        url = f"{self.server}/api/workspace/{quote(self.project, safe='')}/{route}"
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
        headers = {"Authorization": "Bearer " + self._key, "Accept": "application/json",
                   "X-Hi2vi-Checkout": self.checkout, "X-Hi2vi-Engine": self.engine}
        if data is not None:
            headers["Content-Type"] = "application/json"
        headers.update(extra or {})
        wire = _CloudWire(self.deadline)
        handlers = [NoRedirect()] + _cloud_handlers(wire) + ([urllib.request.ProxyHandler({})] if self.local else [])
        opener = urllib.request.build_opener(*handlers)
        request = urllib.request.Request(url, data=data, method=method, headers=headers)
        status, raw = self._exchange(opener, request, wire)
        try:
            payload = json.loads(raw.decode("utf-8")) if raw else {}
        except (UnicodeDecodeError, ValueError):
            payload = {}
        return status, payload if isinstance(payload, dict) else {}

    def _exchange(self, opener, request, wire: _CloudWire) -> tuple:
        """(status, raw body); an HTTP error status whose body is read whole is an answer, every other failure
        CloudUnreachable. An error body cut short or stalled is no answer: a 409 never reads as one with no conflicts."""
        import urllib.error
        try:  # no timeout here: every wait of the request is a _CloudSocket step, or the connect's wire-bounded wait
            with opener.open(request) as resp:
                return resp.status, resp.read()
        except urllib.error.HTTPError as exc:
            try:
                return exc.code, exc.read() or b""
            except Exception as err:  # noqa: BLE001 - the error answer was not read whole
                raise CloudUnreachable(self._why(err, wire))
        except Exception as exc:  # noqa: BLE001 - URLError, OSError, http.client.HTTPException, ValueError, ...
            raise CloudUnreachable(self._why(exc, wire))

    def _why(self, exc: BaseException, wire: _CloudWire) -> str:
        import socket
        reason = getattr(exc, "reason", None)
        if isinstance(exc, _CloudStall) or isinstance(reason, _CloudStall):
            return str(exc if isinstance(exc, _CloudStall) else reason)
        if isinstance(exc, socket.timeout) or isinstance(reason, socket.timeout):
            return wire.timed_out()
        return self._reason(exc)

    def _reason(self, exc: BaseException) -> str:
        """One short line naming the failure, never the key (a header error can quote a header's value)."""
        import http.client
        reason = getattr(exc, "reason", None)
        text = str(reason) if reason else str(exc)
        name = exc.__class__.__name__
        if isinstance(exc, http.client.HTTPException) and name not in text:
            text = f"{name}: {text}" if text.strip() else name
        if self._key:  # as typed, and as a str or bytes repr would quote it
            for form in (self._key, repr(self._key)[1:-1], repr(self._key.encode("utf-8", "replace"))[2:-1]):
                text = text.replace(form, "<key>")
        text = (text.splitlines() or [""])[0]
        return text[:200] or name


def cloud_settle_pull(base: dict) -> None:
    """A pull's write-ahead record (`pulling` in base.json: each append file's merged size, sha256 and base entry,
    saved before its write), settled against the disk after a pull that stopped midway: a file whose first `size`
    bytes are the merge's took the write, so its entry is the merge's (hi2vi's lines are then inside the synced
    offset, never sent back); any other file did not, so its entry stays as it was and the next pull merges again."""
    pulling = base.pop("pulling", None)
    if not isinstance(pulling, dict) or not isinstance(base.get("files"), dict):
        return
    for rel, rec in pulling.items():
        if not (cloud_truth_rel(rel) and cloud_kind(rel) == "append" and isinstance(rec, dict)
                and isinstance(rec.get("entry"), dict) and isinstance(rec.get("size"), int)):
            continue
        try:
            data = (ROOT / rel).read_bytes()
        except OSError:
            continue
        if rec["size"] <= len(data) and _sha(data[:rec["size"]]) == rec.get("sha256"):
            base["files"][rel] = rec["entry"]


class CloudSession:
    """One command's boundary in a linked checkout: begin (pull, pre-command scan), then commit (its batches, in order)."""

    def __init__(self, tokens: list, deadline=None) -> None:
        self.tokens = list(tokens)
        self.dir = ROOT / CLOUD_DIR
        self.link = CloudLink()
        self.link.deadline = deadline
        self.base = self._load("base.json") or {}
        if not isinstance(self.base.get("files"), dict) or not isinstance(self.base.get("head"), int):
            self.base = {"schema": CLOUD_SCHEMA, "head": 0, "files": {}}
        cloud_settle_pull(self.base)  # in memory only: the next save_base records it, with the lock held
        self.cache = self._load("stat.json") or {}
        self.pre = {}
        self.inbox_pending = None  # P1's count, read at the begin step; None: unknown, so the inbox is asked

    def _load(self, name: str):
        try:
            data = read_json(self.dir / name)
        except (OSError, ValueError):
            return None
        return data if isinstance(data, dict) else None

    def _unreachable(self, why: str) -> CloudError:
        return CloudError(f"hi2vi is not reachable at {self.link.server} ({why}): in cloud mode nothing runs offline, "
                          "and nothing was changed.")

    def _ask(self, method: str, route: str, body=None) -> dict:
        """A begin-step request: anything but a 200 stops the command before it runs. P1 head names the head
        this checkout last synced (X-Hi2vi-Base), so a read-only day still counts as synced in hi2vi."""
        extra = {"X-Hi2vi-Base": str(self.base["head"])} if route == "head" else None
        try:
            status, payload = self.link.call(method, route, body, extra)
        except CloudUnreachable as exc:
            raise self._unreachable(str(exc))
        if status != 200:
            raise self._unreachable(f"HTTP {status} on {route.split('?')[0]}")
        return payload

    def fetch(self, paths) -> dict:
        """P3 for any number of paths: {rel: (item, bytes)} of the live ones. hi2vi answers one page at a time
        (`rest` names the asked paths left for the next request) and a path with no live record is simply
        absent; each request asks for at most CLOUD_FETCH_PATHS paths. An answer that does not decode (not a
        list of files, content that is not text, base64 that is not base64) stops it before anything is written."""
        import base64
        got, queue = {}, list(dict.fromkeys(paths))
        while queue:
            ask, queue = queue[:CLOUD_FETCH_PATHS], queue[CLOUD_FETCH_PATHS:]
            while ask:
                answer = self._ask("POST", "fetch", {"paths": ask})
                files = answer.get("files") or []
                if not isinstance(files, list):
                    raise self._unreachable("a malformed fetch answer")
                for item in files:
                    rel = item.get("path") if isinstance(item, dict) else None
                    if not isinstance(rel, str) or rel not in ask:
                        continue
                    raw = item.get("content") or ""
                    try:
                        if not isinstance(raw, str):
                            raise TypeError(type(raw).__name__)
                        data = base64.b64decode(raw) if item.get("encoding") == "base64" else raw.encode("utf-8")
                    except (TypeError, ValueError):  # binascii.Error and UnicodeEncodeError are ValueErrors
                        how = "base64" if item.get("encoding") == "base64" else "utf-8 text"
                        raise self._unreachable(f"a fetched file did not decode as {how}: {rel}")
                    if _sha(data) != item.get("sha256"):
                        raise self._unreachable(f"a fetched file did not match its sha256: {rel}")
                    got[rel] = (item, data)
                rest = [r for r in (answer.get("rest") or []) if isinstance(r, str) and r in ask and r not in got]
                if len(rest) >= len(ask):
                    raise self._unreachable("a fetch page returned nothing")
                ask = rest
        return got

    def save_base(self) -> None:
        write_json(self.dir / "base.json", self.base)

    def save_cache(self) -> None:
        now = time.time_ns()
        keep = {rel: entry for rel, entry in self.cache.items() if entry[0] < now - CLOUD_RACY_NS}
        write_text(self.dir / "stat.json", json.dumps(keep, separators=(",", ":"), sort_keys=True) + "\n")

    # The journal ---------------------------------------------------------------------------------
    def journal(self):
        return self._load("journal.json")

    def set_journal(self, state: str, **fields) -> None:
        write_json(self.dir / "journal.json", dict({"schema": CLOUD_SCHEMA, "state": state,
                                                   "command": shlex.join(self.tokens), "at": now_iso()}, **fields))

    def clear_journal(self) -> None:
        try:
            (self.dir / "journal.json").unlink()
        except FileNotFoundError:
            pass
        shutil.rmtree(str(self.dir / "outbox"), ignore_errors=True)

    def mark_crashed(self, exc: BaseException) -> None:
        """The command raised (not a refusal): the journal stays `running` and names the crash for the next
        command's line. Best effort: the original exception is what propagates."""
        try:
            entry = self.journal() or {}
            if entry.get("state") == "running":
                write_json(self.dir / "journal.json", dict(entry, crashed=exc.__class__.__name__))
        except Exception:  # noqa: BLE001 - never mask the command's own crash
            pass

    def _recover(self) -> None:
        """Journal, step 3 of the begin step: resend a batch whose answer was lost (`pushing`), or refuse after
        a command that died midway (`running`). Nothing runs past an interrupted state."""
        entry = self.journal()
        if entry is None:
            return
        if entry.get("state") == "pushing" and isinstance(entry.get("batches"), list):
            self._push([str(b) for b in entry["batches"]], begin=True)
            entry = self.journal()  # a sync --keep's push resumes the interrupted state it was made in
            if entry is None:
                return
        crashed = f", {entry['crashed']}" if isinstance(entry.get("crashed"), str) else ""
        changed = self._count_changed()
        raise CloudError(f"the last command here ({entry.get('command') or 'unknown'}) stopped before it finished"
                         f"{crashed}: {changed} file(s) changed by it are on disk but not in hi2vi (interrupted): "
                         "run sync to see them (nothing was changed)")

    def _count_changed(self) -> int:
        files, disk = self.base["files"], cloud_scan(dict(self.cache))
        return sum(1 for rel in set(files) | set(disk)
                   if disk.get(rel) != (files.get(rel) or {}).get("sha256"))

    # The begin step ------------------------------------------------------------------------------
    def begin(self, inbox: bool = False) -> None:
        """Steps 3 to 6: the journal, P1 head, a fast-forward pull, the pre-command scan, journal `running`.
        Called with the checkout's lock held (`cloud_run`, or a step inside the boundary). `inbox` (next):
        the web's agenda inbox is applied after the pull, before the command reads the disk."""
        self._recover()
        info = self._ask("GET", "head")
        if str(info.get("project_id")) != self.link.project:
            raise CloudError(f"hi2vi answered for project {info.get('project_id')}, not {self.link.project}: "
                             "this checkout's link is broken, and nothing was changed")
        self.inbox_pending = info.get("inbox_pending")
        disk = cloud_scan(self.cache)
        head = info.get("head")
        if isinstance(head, int) and head != self.base["head"] and self._pull(disk):
            disk = cloud_scan(self.cache)
        if inbox:
            cloud_inbox_step(self)
            disk = cloud_scan(self.cache)
        self.pre = disk
        self.set_journal("running", pid=os.getpid())

    def _pull(self, disk: dict, strict: bool = True):
        """Fast-forward the disk to hi2vi's head. A path changed on both sides is a mismatch: refused before
        anything is written. Returns True when a file was written or deleted (the generated files are then
        rebuilt). Not `strict` (sync): the clean paths are pulled, the mismatched ones left as they are, the
        base's head kept (so the next manifest names them again), and the list of mismatched paths returned."""
        manifest = self._ask("GET", f"manifest?since={self.base['head']}")
        new_head, changes = manifest.get("head"), manifest.get("changes")
        if not isinstance(new_head, int) or not isinstance(changes, list):
            raise self._unreachable("a malformed manifest")
        files = self.base["files"]
        fetch, delete, same, mismatch = {}, [], {}, []
        for change in changes:
            rel = change.get("path") if isinstance(change, dict) else None
            if not cloud_truth_rel(rel):
                continue  # nothing outside the truth set is ever written from the cloud
            b, here = files.get(rel), disk.get(rel)
            if change.get("deleted"):
                if here is None:
                    same[rel] = None
                elif b is not None and here == b.get("sha256"):
                    delete.append(rel)
                else:
                    mismatch.append(rel)
            elif here is not None and here == change.get("sha256"):
                same[rel] = change
            elif change.get("kind") == "append" or cloud_kind(rel) == "append":
                fetch[rel] = change  # appends never conflict: the cloud's new lines are merged in
            elif (b is None and here is None) or (b is not None and here == b.get("sha256")):
                fetch[rel] = change
            else:
                mismatch.append(rel)
        if mismatch and strict:
            raise CloudError(f"{len(mismatch)} files differ between this checkout and hi2vi: run sync to see them "
                             "(nothing was changed)")
        got = {}
        if fetch:
            got = self.fetch(sorted(fetch))
            missing = sorted(set(fetch) - set(got))
            if missing:
                raise self._unreachable(f"{len(missing)} file(s) missing from the fetch, first {missing[0]}")
        written, at = [], None  # the paths written or deleted so far, and the path in hand
        merges = {}  # each append file's merge: rel -> (the merged bytes, or None when nothing is added; its entry)
        try:
            for rel, (item, data) in sorted(got.items()):
                if cloud_kind(rel) != "append":
                    continue
                path, at = ROOT / rel, rel
                local = path.read_bytes() if path.is_file() else b""
                b = files.get(rel) or {}
                offset = b.get("offset", 0) if b.get("kind") == "append" else 0
                offset = offset if 0 <= offset <= len(local) else len(local)
                seen = {}
                for line in local.splitlines(keepends=True):
                    seen[line.rstrip(b"\n")] = seen.get(line.rstrip(b"\n"), 0) + 1
                new = []
                for line in data.splitlines():
                    if seen.get(line, 0):
                        seen[line] -= 1
                    else:
                        new.append(line + b"\n")
                added = b"".join(new)
                merged = local[:offset] + added + local[offset:]
                offset += len(added)
                entry = {"rev": item.get("rev"), "sha256": _sha(merged[:offset]), "kind": "append", "offset": offset}
                merges[rel] = (merged if added else None, entry)
            # Write-ahead: the merged file differs from hi2vi's whenever this checkout holds lines past its offset (or
            # an order of its own), so a pull stopped after a write would leave hi2vi's lines past the old offset, to
            # be sent back as new. Each merge's result and its entry are in base.json before its write.
            pulling = {rel: {"size": len(merged), "sha256": _sha(merged), "entry": entry}
                       for rel, (merged, entry) in merges.items() if merged is not None}
            if pulling:
                at = f"{CLOUD_DIR}/base.json"
                self.base["pulling"] = pulling
                self.save_base()
            for rel, (item, data) in sorted(got.items()):
                path, at = ROOT / rel, rel
                if rel in merges:
                    merged, entry = merges[rel]
                    if merged is not None:
                        _cloud_write_bytes(path, merged)
                    files[rel] = entry
                else:
                    _cloud_write_bytes(path, data)
                    files[rel] = {"rev": item.get("rev"), "sha256": item.get("sha256"), "kind": "file"}
                written.append(rel)
            for rel in delete:
                at = rel
                _cloud_remove(rel)
                files.pop(rel, None)
                written.append(rel)
            for rel, change in same.items():
                at = rel
                if change is None:
                    files.pop(rel, None)
                elif cloud_kind(rel) == "append":
                    size = (ROOT / rel).stat().st_size
                    files[rel] = {"rev": change.get("rev"), "sha256": change.get("sha256"), "kind": "append", "offset": size}
                else:
                    files[rel] = {"rev": change.get("rev"), "sha256": change.get("sha256"), "kind": "file"}
        except OSError as exc:  # record what landed (the head stays), so the next command's pull resumes from it
            self.base.pop("pulling", None)  # each write that landed has its entry; the one that failed did not land
            try:
                self.save_base()
                if written:
                    cloud_rebuild(written)
            except Exception:  # noqa: BLE001 - the write error is the line to show
                pass
            raise CloudError(f"{at} could not be written here from hi2vi ({exc.__class__.__name__}: "
                             f"{exc.strerror or exc}): {len(written)} pulled path(s) landed before it and are recorded "
                             "in .hi2vi/base.json; fix it, then run the command again (the pull resumes from there)")
        self.base.pop("pulling", None)
        if not mismatch:
            self.base["head"] = new_head
        self.save_base()
        wrote = bool(got or delete)
        if wrote:
            cloud_rebuild(list(got) + delete)
        return wrote if strict else sorted(mismatch)

    # The commit step -----------------------------------------------------------------------------
    def _origin(self, rel: str, sha) -> str:
        """`command` when the command itself changed the path, `carried` when it changed before (an agent)."""
        return "carried" if self.pre.get(rel) == sha else "command"

    def _diff(self, post: dict, skip=()) -> list:
        """[(wire op, base entry after a 200 or None for a delete)] of every truth-set difference, bar the
        paths in `skip` (sync's mismatched paths, which only `sync --keep` resolves)."""
        files, out, adds, dels = self.base["files"], [], {}, {}
        for rel in sorted((set(files) | set(post)) - set(skip)):
            b, here = files.get(rel), post.get(rel)
            if b is None:
                adds[rel] = here
                continue
            if here is None:
                dels[rel] = b
                continue
            if here == b.get("sha256"):
                continue
            data = (ROOT / rel).read_bytes()
            if b.get("kind") == "append" and cloud_kind(rel) == "append":
                offset = b.get("offset", 0)
                if 0 <= offset <= len(data) and _sha(data[:offset]) == b.get("sha256"):
                    op = self._append_op(rel, data, offset, b.get("rev"), here)
                    if op:
                        out.append(op)
                    continue
            out.append(self._put_op(rel, data, b.get("rev"), here))
        # P7: a delete and an add of equal content are one move, so the record's history follows it.
        for rel, b in sorted(dels.items()):
            match = [a for a, sha in adds.items() if sha == b.get("sha256") and cloud_kind(a) == cloud_kind(rel)]
            if not match:
                out.append(({"op": "delete", "path": rel, "base_rev": b.get("rev"),
                             "origin": "carried" if rel not in self.pre else "command"}, None, rel))
                continue

            def tail(a, parts=rel.split("/")):
                other, n = a.split("/"), 0
                while n < min(len(parts), len(other)) and parts[-1 - n] == other[-1 - n]:
                    n += 1
                return (-n, a)
            to = min(match, key=tail)
            del adds[to]
            out.append(({"op": "move", "from": rel, "to": to, "base_rev": b.get("rev"),
                         "origin": "command" if rel in self.pre else "carried"}, dict(b), to))
        for rel, here in sorted(adds.items()):
            data = (ROOT / rel).read_bytes()
            if cloud_kind(rel) == "append":
                op = self._append_op(rel, data, 0, None, here)
                if op:
                    out.append(op)
            else:
                out.append(self._put_op(rel, data, None, here))
        return out

    def _put_op(self, rel: str, data: bytes, base_rev, here: str) -> tuple:
        encoding, content = _cloud_content(data)
        op = {"op": "put", "path": rel, "base_rev": base_rev, "sha256": here, "encoding": encoding,
              "content": content, "origin": self._origin(rel, here)}
        entry = {"rev": None, "sha256": here, "kind": cloud_kind(rel)}
        if entry["kind"] == "append":
            op["kind"] = "append"
            entry["offset"] = len(data)
        return op, entry, rel

    def _append_op(self, rel: str, data: bytes, offset: int, rev, here: str):
        """P6: the complete lines past the synced offset, or None when there are none; a tail that is not
        utf-8 goes as a revisioned put instead."""
        cut = data.rfind(b"\n", offset) + 1
        if cut <= offset:
            return None
        try:
            lines = data[offset:cut].decode("utf-8").split("\n")[:-1]
        except UnicodeDecodeError:
            return self._put_op(rel, data, rev, here)
        entry = {"rev": rev, "sha256": _sha(data[:cut]), "kind": "append", "offset": cut}
        return {"op": "append", "path": rel, "lines": lines, "origin": self._origin(rel, here)}, entry, rel

    def commit(self, skip=()) -> int:
        """Steps 1 to 4: diff, the batches (each under CLOUD_BATCH_MAX as sent), journal `pushing`, P4, the base
        updated per landed batch, the journal cleared. A 409 or a network error keeps the disk as it is.
        Returns the number of ops sent."""
        post = cloud_scan(self.cache)
        planned = self._diff(post, skip)
        self.save_cache()
        if not planned:
            self.clear_journal()
            return 0
        self.send(planned)
        return len(planned)

    def send(self, planned: list, resume=None, inbox=(), command=None) -> None:
        """The batches of `planned` ops, journaled in the outbox, then pushed. `resume`: a journal entry to put
        back once the push ends (sync --keep inside an interrupted state keeps its `running` journal). `inbox`:
        the agenda inbox results that travel with these ops, all in one batch (`command`: the argv it names)."""
        derived = []
        for rel in CLOUD_DERIVED:
            try:
                derived.append({"path": rel, "content": (ROOT / rel).read_text(encoding="utf-8")})
            except (OSError, UnicodeDecodeError):
                pass
        try:
            batches = self._batches(planned, derived, inbox, command)
        except CloudError:
            self._end_push(resume)  # nothing was sent: the base still names the change, so the next command retries it
            raise
        outbox = self.dir / "outbox"
        for batch, updates in batches:
            write_text(outbox / f"{batch['batch_id']}.json",
                       json.dumps({"batch": batch, "updates": updates}, ensure_ascii=False) + "\n")
        fields = {"resume": resume} if resume else {}
        self.set_journal("pushing", batches=[batch["batch_id"] for batch, _ in batches], **fields)
        self._push([batch["batch_id"] for batch, _ in batches])

    def _end_push(self, resume=None) -> None:
        """A push is over (landed, or refused for good): clear the journal, or put back the entry it resumes."""
        if resume is None:
            entry = self.journal() or {}
            resume = entry.get("resume") if entry.get("state") == "pushing" else None
        self.clear_journal()
        if isinstance(resume, dict):
            write_json(self.dir / "journal.json", resume)

    def _batches(self, planned: list, derived: list, inbox=(), command=None) -> list:
        """[(wire batch, base updates)]: the ops in order, cut so that each batch's JSON as sent stays under
        CLOUD_BATCH_MAX; each batch has its own batch_id and carries the P9 records. One op too big for any
        batch refuses before anything is sent. Inbox results go in one batch with all of their ops (an entry's
        files and its result land together or not at all), so ops that would need two batches are refused."""
        import uuid

        def size(obj) -> int:
            return len(json.dumps(obj, ensure_ascii=False).encode("utf-8"))

        inbox = list(inbox or [])
        command = command or shlex.join(self.tokens)
        envelope = size({"batch_id": uuid.uuid4().hex, "command": command, "origin": "carried", "ops": [],
                         "events": [], "derived": derived, "inbox": inbox})
        groups, current, used = [], [], envelope
        for item in planned:
            n = size(item[0]) + 1  # the op and its comma
            if envelope + n > CLOUD_BATCH_MAX:
                raise CloudError(f"{item[2]} is {n:,} bytes as sent, over hi2vi's {CLOUD_BATCH_MAX:,}-byte batch "
                                 "limit: it is on disk but not in hi2vi; make it smaller, then run any command")
            if current and used + n > CLOUD_BATCH_MAX:
                groups.append(current)
                current, used = [], envelope
            current.append(item)
            used += n
        if current or (inbox and not groups):
            groups.append(current)
        if inbox and len(groups) > 1:
            raise CloudError(f"an agenda change's files are over hi2vi's {CLOUD_BATCH_MAX:,}-byte batch limit, and they "
                             "must land in one batch with its result")
        out = []
        for group in groups:
            ops = [op for op, _, _ in group]
            batch = {"batch_id": uuid.uuid4().hex, "command": command,
                     "origin": "command" if inbox or any(op["origin"] == "command" for op in ops) else "carried",
                     "ops": ops, "events": [], "derived": derived, "inbox": inbox}
            updates = [{"op": op["op"], "from": op.get("from"), "path": rel, "entry": entry} for op, entry, rel in group]
            out.append((batch, updates))
        return out

    def _push(self, ids: list, begin: bool = False) -> None:
        """Send the journal's batches in order. Each 200 updates the base and leaves the journal; a resent
        batch_id gets hi2vi's first answer, so a batch lands once. A 409 is final (the batch wrote nothing,
        the base still names the change, the journal is cleared); a lost answer or another status keeps the
        journal, so the next command resends the same batch."""
        def unsent(why: str) -> CloudError:
            if begin and why.startswith("hi2vi unreachable"):
                return self._unreachable(why.split(": ", 1)[-1])
            return CloudError(f"this change is on disk but not in hi2vi ({why}): run sync")

        remaining = list(ids)
        while remaining:
            bid = remaining[0]
            item = self._load(f"outbox/{bid}.json") if re.fullmatch(r"[0-9a-f]{32}", bid) else None
            if not isinstance(item, dict) or not isinstance(item.get("batch"), dict):
                raise CloudError(f"the unsent batch {bid} is missing from {shown(self.dir / 'outbox')}: this change "
                                 "is on disk but not in hi2vi (interrupted): run sync")
            try:
                status, answer = self.link.call("POST", "commit", item["batch"])
            except CloudUnreachable as exc:
                raise unsent(f"hi2vi unreachable: {exc}")
            if status == 409:
                self._end_push()
                raise CloudConflict(str(unsent(f"{len(answer.get('conflicts') or [])} conflict(s)")), answer.get("conflicts"))
            if status != 200 or not isinstance(answer.get("head"), int):
                raise unsent(f"hi2vi answered HTTP {status}")
            self._landed(answer, item.get("updates") or [])
            remaining.pop(0)
            if remaining:  # the journal keeps its command: a resend at the begin step is the earlier command's
                write_json(self.dir / "journal.json", dict(self.journal() or {}, batches=remaining))
            try:
                (self.dir / "outbox" / f"{bid}.json").unlink()
            except FileNotFoundError:
                pass
        self._end_push()

    def _landed(self, answer: dict, updates: list) -> None:
        revs = answer.get("revs") if isinstance(answer.get("revs"), dict) else {}
        files = self.base["files"]
        for u in updates:
            rel = u.get("path")
            if u.get("op") == "delete":
                files.pop(rel, None)
                continue
            if u.get("op") == "move":
                files.pop(u.get("from"), None)
            entry = dict(u.get("entry") or {})
            entry["rev"] = revs.get(rel, answer["head"])
            files[rel] = entry
        if answer["head"] == self.base["head"] + 1:
            self.base["head"] = answer["head"]  # else another writer landed between: the next pull reads from here
        self.save_base()


def cloud_run(args: argparse.Namespace, tokens: list):
    """`main()`'s command call in a linked checkout, under the checkout's lock: begin, the command unchanged,
    then the commit (also after a refusal). A failed begin refuses before the command runs; a failed commit
    exits 1 even when the command succeeded, and a refusal's own line is kept. The session hook
    (CLOUD_FAIL_OPEN) never fails on the cloud: any cloud stop becomes a note and it runs on the disk, and its
    whole cloud time (the lock wait and every request) stays inside CLOUD_HOOK_BUDGET."""
    fail_open = args.cmd in CLOUD_FAIL_OPEN
    deadline = time.monotonic() + CLOUD_HOOK_BUDGET if fail_open else None
    lock = CloudLock(min(CLOUD_HOOK_LOCK_WAIT, CLOUD_HOOK_BUDGET) if fail_open else CLOUD_LOCK_WAIT)
    try:
        lock.acquire()
    except Exception as exc:  # noqa: BLE001 - one line, whatever stopped it
        if fail_open:
            return cloud_fail_open(args, cloud_stop_line(exc, "begin"))
        raise SystemExit(cloud_stop_line(exc, "begin"))
    try:
        return cloud_boundary(args, tokens, fail_open, deadline)
    finally:
        lock.release()


def cloud_fail_open(args: argparse.Namespace, line: str):
    """The hook's way past a cloud stop: the command runs on the disk as it is (its ids read from it), then the
    stop as a note."""
    normalize_id_args(args)
    result = args.func(args)
    print(f"note: {line}")
    return result


def cloud_boundary(args: argparse.Namespace, tokens: list, fail_open: bool = False, deadline=None):
    """The boundary itself, with the lock held. Every failure of the begin or the commit step is one line
    (cloud_stop_line): a refusal before the command, or "on disk but not in hi2vi" after it. The command's typed
    ids are resolved after the begin step's pull, against the tree hi2vi holds (a brief id names what another
    checkout made, and a number two phases now share is refused); an id refusal is a refusal like the
    command's own, so the commit step still runs."""
    try:
        session = CloudSession(tokens, deadline=deadline)
        session.begin(inbox=args.cmd in CLOUD_INBOX_AT)
    except Exception as exc:  # noqa: BLE001 - a CloudError's line, or any other failure named in one
        if fail_open:
            return cloud_fail_open(args, cloud_stop_line(exc, "begin"))
        raise SystemExit(cloud_stop_line(exc, "begin"))
    try:
        normalize_id_args(args)
        result = args.func(args)
    except SystemExit as stop:
        line = cloud_commit_step(session)
        if line is not None:
            if fail_open:
                print(f"note: {line}")
            elif stop.code in (None, 0):
                raise SystemExit(line)
            else:
                print(line, file=sys.stderr)
        raise
    except BaseException as crash:  # a crash, not a refusal: no commit, the journal stays `running` and names it
        session.mark_crashed(crash)
        raise
    line = cloud_commit_step(session)
    if line is not None:
        if fail_open:
            print(f"note: {line}")
            return result
        raise SystemExit(line)
    return result


def cloud_commit_step(session: CloudSession):
    """The commit step after the command: None when it landed (or had nothing to send), else its one line. A
    failure that is not a CloudError leaves the journal as it was (`running` names it to the next command, a
    `pushing` one is resent)."""
    try:
        session.commit()
    except Exception as exc:  # noqa: BLE001 - one line, never a traceback after the command ran
        if not isinstance(exc, CloudError):
            session.mark_crashed(exc)
        return cloud_stop_line(exc, "commit")
    return None


# The link, the way back, and sync. These three run outside the boundary (main() calls them directly): each
# takes the checkout's lock itself, and none goes through the begin step's journal recovery, because sync is
# how an interrupted state is resolved and unlink --from-disk is the one command that runs offline.
CLOUD_OWN = ("link", "unlink", "sync")
CLOUD_KEY_PROMPT = "Paste a workspace key for this project (make one under Keys on the project's page): "
# Refused in cloud mode with one line each, before anything is read or written: a linked checkout runs every
# phase here, with no worktree streams (and so no reopened pair).
CLOUD_STREAM_REFUSED = ("worktree start", "worktree add-repo", "worktree gate", "worktree merge-finish",
                        "worktree teardown", "phase reopen")
# An unused install's truth set: only what a fresh install seeds (the five plain docs; an older install's
# docs/index.json and v0001 versions). Joining hi2vi from one replaces these.
CLOUD_SEED_RE = re.compile(r"docs/README\.md|docs/current/(?:product|architecture|operations|qa|decisions)\.md|docs/index\.json"
                           r"|docs/versions/[^/]+/v0001_bootstrap\.md|works/events\.jsonl")
CLOUD_SHOWN_ROWS = 20


def cloud_refusal(args: argparse.Namespace):
    """The one line refusing a stream command in a linked checkout, or None."""
    if args.cmd in CLOUD_STREAM_REFUSED:
        what = "it cuts a worktree pair for the phase" if args.cmd == "phase reopen" else "it runs a phase on a worktree stream"
        return (f"{args.cmd} is refused in cloud mode: {what}, and a linked checkout runs every phase here, "
                "with no streams (nothing was changed)")
    return None


def cloud_store_line() -> str:
    """`next`'s line in a linked checkout: the skills skip the workflow repo's commit when they see it."""
    try:
        link = read_json(cloud_link_file())
    except (OSError, ValueError):
        return "store=cloud link=unreadable"
    return f"store=cloud server={link.get('server')} project={link.get('project_id')}"


# The waiting-commit record of a linked checkout. In local mode a `done` slice whose slice.json the workflow repo
# has not committed is a commit that waits (the do-* skills read git); a linked checkout never commits workflow
# state (hi2vi's revisions are the history), so there the record is explicit: `mark-committed <slice>` writes
# `committed_at` into slice.json (a truth file: it syncs) after the slice's product commit, or right after its
# finish when it changed no product file. A slice leaving `done` loses it; a second finish keeps it (as a second
# slice finish after a commit never waits in git). Slices done before the link were committed (link refuses an
# unclean workflow repo), so only those finished at or after link.json's `linked_at` can wait. Local mode never
# reads, writes or prints any of it.
COMMITTED_AT = "committed_at"


def cloud_commits_waiting(phases=None) -> list:
    """The ids of the done slices without `committed_at`, finished at or after the link, in finish order, across
    every active phase (a linked checkout runs no streams)."""
    try:
        linked_at = _meter_ts(read_json(cloud_link_file()).get("linked_at"))
    except (OSError, ValueError, AttributeError):
        linked_at = None  # an unreadable link: every unmarked done slice is listed, the conservative answer
    rows = []
    for phase in phases if phases is not None else all_active_phases():
        for s in phase.get("slices", []):
            if not isinstance(s, dict) or s.get("status") != "done" or s.get(COMMITTED_AT):
                continue
            done = _meter_ts(s.get("completed_at"))
            if linked_at is not None and done is not None and done < linked_at:
                continue
            rows.append((done if done is not None else float("inf"), len(rows), str(s.get("id"))))
    return [sid for _done, _n, sid in sorted(rows)]


def cloud_commits_waiting_line(phases=None) -> str:
    """`next`'s line in a linked checkout: the do-* skills read it in place of git's answer."""
    waiting = cloud_commits_waiting(phases)
    return f"commits_waiting={','.join(waiting) if waiting else 'none'}"


def mark_committed(args: argparse.Namespace) -> None:
    """A linked checkout's waiting-commit record: `committed_at` on each named done slice. All or nothing."""
    if not cloud_link_file().exists():
        raise SystemExit("mark-committed is for a linked checkout: in local mode the workflow repo's commit of a slice's "
                         "slice.json is the record (nothing was written)")
    targets, problems = [], []
    for sid in dict.fromkeys(args.mark_slices):
        sdir = require_slice(sid)
        data = read_json(sdir / "slice.json")
        if data.get("status") != "done":
            problems.append(f"{sid} is {data.get('status')}, not done")
        else:
            targets.append((sid, sdir, data))
    if problems:
        raise SystemExit(f"mark-committed: refused -- {'; '.join(problems)}: only a done slice's commit is recorded "
                         "(nothing was written)")
    marked = False
    for sid, sdir, data in targets:
        if data.get(COMMITTED_AT):
            print(f"{sid}: already marked (committed_at={data[COMMITTED_AT]})")
            continue
        data[COMMITTED_AT] = now_iso()
        write_json(sdir / "slice.json", data)
        append_event("slice_commit_recorded", slice=sid)
        print(f"{sid}: committed_at={data[COMMITTED_AT]}")
        marked = True
    if marked:
        rebuild_index_and_state()
    print(cloud_commits_waiting_line())


def cloud_rebuild(rels) -> None:
    """The generated files after the disk took files from hi2vi."""
    rebuild_index_and_state()


def cloud_commit_hint() -> str:
    rel = os.path.relpath(ROOT, HOST_ROOT) if HOST_ROOT is not None else "."
    return f"git -C {rel} add -A && git -C {rel} commit"


def cloud_exclude() -> None:
    """Hide `.hi2vi/` in the workflow repo's common info/exclude (the installer does too; this covers an
    install not yet updated). Never .gitignore, which is tracked."""
    exclude = _git_dir(common=True) / "info" / "exclude"
    existing = exclude.read_text(encoding="utf-8") if exclude.exists() else ""
    if {f"{CLOUD_DIR}/", f"/{CLOUD_DIR}/", CLOUD_DIR, f"/{CLOUD_DIR}"} & {l.strip() for l in existing.splitlines()}:
        return
    write_text(exclude, existing + ("\n" if existing and not existing.endswith("\n") else "") + f"/{CLOUD_DIR}/\n")


def cloud_parse_address(address: str) -> tuple:
    """(server, project id) from the project's page address, `<server>/projects/<project-id>`."""
    from urllib.parse import unquote
    parsed = urlparse(address.strip())
    found = re.fullmatch(r"(.*?)/projects/([^/]+)/?", parsed.path or "")
    if parsed.username is not None or parsed.password is not None:
        raise CloudError("link takes the project's page address with no credentials in it: nothing was written")
    if not parsed.scheme or not parsed.netloc or not found or parsed.query or parsed.fragment:
        raise CloudError(f"link takes the project's page address, <server>/projects/<project-id> (not {address}): "
                         "nothing was written")
    return cloud_server_check(f"{parsed.scheme}://{parsed.netloc}{found.group(1)}"), unquote(found.group(2))


def cloud_link_refusal():
    """The one line refusing a link before anything is read or written, or None: at root, in a phase's
    worktree, with a phase in flight on a stream or another worktree, with a dirty workflow repo (its last
    commit is the known point before the link), or already linked."""
    if cloud_link_file().exists():
        return f"this checkout is already linked ({cloud_store_line()}): run unlink first (nothing was written)"
    if NESTED is None:
        return ("link refuses an at-root install: cloud mode needs the nested layout, whose phase scope reads the "
                "anchors in phase.json, never the workflow repo's history (nothing was written)")
    phases = []
    for pdir in phase_dirs():
        try:
            phases.append(read_json(pdir / "phase.json"))
        except (OSError, ValueError):
            continue
    if _in_worktree_set() or current_stream(phases):
        return "link refuses in a phase's worktree: link the default checkout, where every phase then runs (nothing was written)"
    flying = [str(p.get("id")) for p in phases if phase_in_flight(p)]
    if flying:
        return (f"link refuses while a phase is in flight on its own stream ({', '.join(flying)}): merge it and tear "
                "its worktree down first (nothing was written)")
    top = _git(["rev-parse", "--show-toplevel"], check=False) if _git_available() else None
    if top is None or top.returncode != 0 or os.path.realpath(top.stdout.strip()) != os.path.realpath(str(ROOT)):
        return (f"link needs {shown(ROOT)} to be a git repo of its own with a commit to come back to "
                "(nothing was written)")
    if _git(["rev-parse", "--verify", "-q", "HEAD"], check=False).returncode != 0:
        return f"link needs a first commit in {shown(ROOT)}: commit it, then link (nothing was written)"
    others = [path for path, _ref in _worktree_entries()[1:]]
    if others:
        return (f"link refuses while the workflow repo has another worktree ({others[0]}): tear it down first "
                "(nothing was written)")
    dirty = [l[3:] for l in _git(["status", "--porcelain", "--untracked-files=all"]).stdout.splitlines() if l.strip()]
    if dirty:
        return (f"link refuses a workflow repo with uncommitted changes ({len(dirty)} path(s), first {dirty[0]}): "
                f"commit them first, so its last commit is the point before the link (nothing was written)")
    return None


def cloud_read_key() -> str:
    """The key, never echoed and never on argv: getpass at a terminal, else one line of stdin."""
    if sys.stdin is not None and sys.stdin.isatty():
        import getpass
        key = getpass.getpass(CLOUD_KEY_PROMPT)
    else:
        sys.stderr.write(CLOUD_KEY_PROMPT + "\n")
        sys.stderr.flush()
        key = sys.stdin.readline() if sys.stdin is not None else ""
    key = key.strip()
    if not key:
        raise CloudError("no workspace key was given: nothing was written")
    if any(ch.isspace() or ord(ch) < 32 or ord(ch) == 127 for ch in key):
        raise CloudError("that is not a workspace key (it holds spaces or control characters): nothing was written")
    return key


def cloud_save_key(server: str, project: str, org, key: str) -> None:
    """Keep the key in the user's config, `$XDG_CONFIG_HOME/hi2vi/workspace-keys.json`: the folder 0700, the
    file 0600 from its first byte (a temp file made owner-only, then renamed over)."""
    path = cloud_key_file()
    path.parent.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.mkdir(str(path.parent), 0o700)
    except FileExistsError:
        pass
    problem = cloud_key_problem(path)
    if problem:
        raise CloudError(problem)
    data = {}
    if path.exists():
        try:
            data = read_json(path)
        except (OSError, ValueError) as exc:
            raise CloudError(f"{path} is unreadable ({exc.__class__.__name__}): fix or remove it, then link again")
        data = data if isinstance(data, dict) else {}
    projects = data.get(server) if isinstance(data.get(server), dict) else {}
    projects[project] = {"key": key, "org_id": org, "saved_at": now_iso()}
    data[server] = projects
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp_", suffix=path.name)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def cloud_probe(link: CloudLink, route: str) -> dict:
    """One of link's requests before anything is written; any answer but a 200 refuses with one line."""
    try:
        status, payload = link.call("GET", route)
    except CloudUnreachable as exc:
        raise CloudError(f"hi2vi is not reachable at {link.server} ({exc}): nothing was written")
    if status == 200:
        return payload
    why = {401: "hi2vi refused this key (HTTP 401): make a workspace key under Keys on the project's page",
           403: "this key cannot reach a workspace (HTTP 403: it is not a workspace key); make one under Keys on the "
                "project's page",
           404: f"hi2vi has no project {link.project} for this key (HTTP 404)"}.get(status, f"hi2vi answered HTTP {status}")
    raise CloudError(f"{why}: nothing was written")


def cloud_link(args: argparse.Namespace) -> int:
    """link <server>/projects/<project-id>: make hi2vi the truth for this checkout in one step."""
    try:
        server, project = cloud_parse_address(args.address)
        problem = cloud_link_refusal() or cloud_key_problem(cloud_key_file())
        if problem:
            raise CloudError(problem)
        key = cloud_read_key()
        probe = CloudLink({"server": server, "project_id": project}, key=key)
        info = cloud_probe(probe, "head")
        if str(info.get("project_id")) != project:
            raise CloudError(f"hi2vi answered for project {info.get('project_id')}, not {project}: nothing was written")
        manifest = cloud_probe(probe, "manifest?since=0")
        if not isinstance(manifest.get("head"), int) or not isinstance(manifest.get("changes"), list):
            raise CloudError("hi2vi answered a malformed manifest: nothing was written")
    except CloudError as exc:
        raise SystemExit(str(exc))
    live = {c["path"]: c for c in manifest["changes"]
            if isinstance(c, dict) and not c.get("deleted") and cloud_truth_rel(c.get("path"))}
    disk = cloud_scan({})
    mode = "upload"
    if live:
        if disk == {rel: c.get("sha256") for rel, c in live.items()}:
            mode = "equal"
        elif all(CLOUD_SEED_RE.fullmatch(rel) for rel in disk):
            mode = "unused"
        else:
            rows = []
            for rel in sorted(set(disk) | set(live)):
                if rel not in live:
                    rows.append(f"here only  {rel}")
                elif rel not in disk:
                    rows.append(f"cloud only  {rel}")
                elif disk[rel] != live[rel].get("sha256"):
                    rows.append(f"differs  {rel}")
            print(f"link refuses: hi2vi already holds this project's workspace (r{manifest['head']}), and {len(rows)} "
                  "path(s) here differ from it; a second checkout joins only from an unused install or an equal set "
                  "(nothing was written)")
            for row in rows[:CLOUD_SHOWN_ROWS]:
                print(row)
            if len(rows) > CLOUD_SHOWN_ROWS:
                print(f"... and {len(rows) - CLOUD_SHOWN_ROWS} more")
            return 1
    # Past every refusal: the key, the exclude, the link file, then the first sync under the lock.
    try:
        cloud_save_key(server, project, info.get("org_id"), key)
    except CloudError as exc:
        raise SystemExit(str(exc))
    cloud_exclude()
    shutil.rmtree(str(ROOT / CLOUD_DIR), ignore_errors=True)  # bookkeeping left with no link names nothing
    (ROOT / CLOUD_DIR).mkdir()
    write_json(cloud_link_file(), {"schema": CLOUD_SCHEMA, "server": server, "org_id": info.get("org_id"),
                                   "project_id": project, "linked_at": now_iso()})
    try:
        with CloudLock():
            session = CloudSession(["link", f"{server}/projects/{project}"])
            if mode == "unused":  # an unused install's seed files give way to hi2vi's copy
                for rel, sha in disk.items():
                    if (live.get(rel) or {}).get("sha256") != sha:
                        _cloud_remove(rel)
            elif mode == "upload":
                session.base["head"] = manifest["head"]  # nothing live in hi2vi: every file goes up as new
            session.begin()
            sent = session.commit()
    except Exception as exc:  # noqa: BLE001 - one line, whatever stopped the first sync
        raise SystemExit(f"{cloud_stop_line(exc, 'link')} (the link is made: {shown(cloud_link_file())})")
    if mode == "upload":
        print(f"linked: {sent} file(s) sent to hi2vi")
    else:
        pulled = sum(1 for rel, c in live.items() if disk.get(rel) != c.get("sha256"))
        print(f"linked: joined hi2vi's workspace ({pulled} file(s) taken from hi2vi"
              + (", this unused install's seed files replaced)" if mode == "unused" else ")"))
    print(f"store=cloud server={server} project={project} head=r{session.base['head']}")
    return 0


def cloud_unlink(args: argparse.Namespace) -> int:
    """unlink: pull to hi2vi's head (refused on a mismatch), push what is here, remove `.hi2vi/`; local mode
    again. --from-disk: the one offline command, which keeps the disk as it is."""
    if not cloud_link_file().exists():
        raise SystemExit("this checkout is not linked (no .hi2vi/link.json): it is in local mode already")
    if args.from_disk:
        return cloud_unlink_from_disk()
    lock = CloudLock()
    try:
        lock.acquire()
        session = CloudSession(["unlink"])
        session.begin()
        session.commit()
    except Exception as exc:  # noqa: BLE001 - one line, whatever stopped it
        lock.release()
        line = cloud_stop_line(exc, "unlink")
        offline = " (offline, unlink --from-disk keeps the disk as it is)" if line.startswith("hi2vi is not reachable") else ""
        raise SystemExit(f"unlink refused, the checkout is still linked{offline}: {line}")
    try:
        shutil.rmtree(str(ROOT / CLOUD_DIR))
    finally:
        lock.release()
    print(f"unlinked from {session.link.server} project {session.link.project} at r{session.base['head']}")
    print(f"local mode: the files on disk are the truth again; commit them ({cloud_commit_hint()})")
    print(f"the workspace key stays in {cloud_key_file()}: revoke it on the project's page when no checkout needs it")
    return 0


def cloud_unlink_from_disk() -> int:
    """unlink --from-disk: no request at all. The disk becomes the truth as it is; say what it cannot hold."""
    folder = ROOT / CLOUD_DIR
    try:
        base = read_json(folder / "base.json")
    except (OSError, ValueError):
        base = {}
    if isinstance(base, dict):
        cloud_settle_pull(base)
    files = base.get("files") if isinstance(base.get("files"), dict) else {}
    head = base.get("head") if isinstance(base.get("head"), int) else 0
    disk = cloud_scan({})
    unsent = sum(1 for rel in set(files) | set(disk) if disk.get(rel) != (files.get(rel) or {}).get("sha256"))
    try:
        with CloudLock(CLOUD_HOOK_LOCK_WAIT):
            shutil.rmtree(str(folder))
    except CloudError as exc:
        raise SystemExit(f"unlink --from-disk refused, the checkout is still linked: {exc}")
    print(f"unlinked from the disk, offline: changes made in hi2vi after r{head} are not on this disk"
          + (f", and {unsent} file(s) changed here were never sent to hi2vi" if unsent else ""))
    print(f"local mode: the files on disk are the truth again; commit them ({cloud_commit_hint()})")
    return 0


def cloud_rel_arg(raw: str) -> str:
    """A path the operator typed (as sync lists it, from the workspace root, or from the cwd) as a truth-set rel.
    Only a file is a synced path: a folder, or anything on disk that is not a regular file, is refused here."""
    root = os.path.realpath(str(ROOT))
    full = os.path.realpath(raw if os.path.isabs(raw) else os.path.join(os.getcwd(), raw))
    rel = os.path.relpath(full, root).replace(os.sep, "/") if full.startswith(root + os.sep) else posixpath.normpath(raw)
    if not cloud_truth_rel(rel):
        raise SystemExit(f"{raw} is not in the synced set (works/ or docs/, bar the generated files): nothing was changed")
    try:
        mode = os.lstat(str(ROOT / rel)).st_mode
    except OSError:
        return rel  # absent here: sync --keep asks hi2vi whether it holds the file
    if stat.S_ISDIR(mode):
        raise SystemExit(f"{raw} is a folder: sync takes file paths, one by one as sync lists them (nothing was changed)")
    if not stat.S_ISREG(mode):
        raise SystemExit(f"{raw} is not a regular file, so it is never synced (nothing was changed)")
    return rel


def cloud_keep_check(session: CloudSession, paths: list) -> None:
    """sync --keep's refusal before anything is sent or written: every path must be a file on disk or a file
    hi2vi holds (a path on neither side has nothing to keep)."""
    absent = [rel for rel in paths if not (ROOT / rel).is_file()]
    if not absent:
        return
    got = session.fetch(absent)
    unknown = [rel for rel in absent if rel not in got]
    if unknown:
        more = f" (and {len(unknown) - 1} more)" if len(unknown) > 1 else ""
        raise CloudError(f"sync --keep refused: {unknown[0]}{more} names no file here or in hi2vi; it takes the file "
                         "paths sync lists (nothing was changed)")


# The web's agenda inbox. The web never writes a truth file: each change is a pending entry
# {id, created_at, kind, items, fields, minted_id}, and a linked engine applies it at sync and next
# by running the very agenda command in-process (never main(), whose boundary would begin and commit again).
# Exit 0 is `applied`; 1 (a refusal) or 2 (a usage error) is `refused`, its one line the reason, verbatim; any
# other end (a crash, another exit) sends no result, so the entry stays pending, and the tree is put back as the
# command found it. Each entry's result travels in a batch of its own with exactly the files its command wrote,
# so hi2vi's 409 for an entry no longer pending (another checkout applied it) voids only that entry: its files
# are dropped here and hi2vi's copy pulled, never applied twice.
CLOUD_INBOX_AT = ("next",)  # besides sync, the commands whose begin step applies the inbox
CLOUD_INBOX_COMMANDS = {"add": "agenda-add", "edit": "agenda-edit", "move": "agenda-move", "defer": "agenda-defer",
                        "solve": "agenda-solve", "drop": "agenda-drop", "reopen": "agenda-reopen",
                        "delete": "agenda-delete"}
CLOUD_INBOX_MAX = 500  # entries tried in one step (a bound: the rest wait for the next sync)


def _cloud_inbox_id_shown(raw) -> str:
    return raw if isinstance(raw, str) and len(raw) <= 40 and raw.isprintable() else "that value"


def cloud_inbox_tokens(entry: dict, prog: str) -> tuple:
    """(argv, None) for an entry's agenda command, or (None, its usage line) when it is refused unrun: an
    unknown kind, or any id (items, add's minted id, move's --before/--after) that does not fullmatch
    AGENDA_ID_PATTERN. Brief forms are never resolved here: numbers are reused (no tombstone), so a brief id
    could name a re-minted item. Texts go as --flag=value, so a value starting with a dash stays a value."""
    kind = entry.get("kind")
    cmd = CLOUD_INBOX_COMMANDS.get(kind) if isinstance(kind, str) else None
    if cmd is None:
        return None, (f"{prog}: error: the inbox entry's kind {_cloud_inbox_id_shown(kind)} is not an agenda change "
                      f"(one of {', '.join(CLOUD_INBOX_COMMANDS)}): nothing ran")
    fields = entry.get("fields") if isinstance(entry.get("fields"), dict) else {}
    items = entry.get("items") if isinstance(entry.get("items"), list) else []
    ids = [entry.get("minted_id")] if kind == "add" else list(items)
    if kind == "move":
        ids += [fields[k] for k in ("before", "after") if fields.get(k) is not None]
    for raw in ids:
        if not (isinstance(raw, str) and AGENDA_ID_RE.fullmatch(raw)):
            return None, (f"{prog} {cmd}: error: {_cloud_inbox_id_shown(raw)} is not a full agenda id (like A7-m3): "
                          "the inbox applies full ids only, so nothing ran")

    def text(flag: str, key: str) -> list:
        value = fields.get(key)
        return [f"--{flag}={value}"] if isinstance(value, str) else []

    if kind == "add":
        return [cmd, f"--id={entry['minted_id']}"] + text("title", "title") + text("note", "note"), None
    if kind == "edit":
        return [cmd] + items + text("title", "title") + text("note", "note"), None
    if kind == "move":
        place = [f"--{k}" for k in ("first", "last") if fields.get(k) is True]
        place += [f"--{k}={fields[k]}" for k in ("before", "after") if isinstance(fields.get(k), str)]
        return [cmd] + items + place, None
    extra = text("outcome", "outcome") if kind == "solve" else text("reason", "reason") if kind == "drop" else []
    return [cmd] + items + extra, None


def cloud_inbox_run(parser: argparse.ArgumentParser, tokens: list) -> tuple:
    """(exit, line) of one agenda command run in-process: parsed by `parser`, its ids normalized, its function
    called, stdout and stderr captured. The line: a refusal's message, a usage error's one line, or an applied
    command's first output line. An exception other than SystemExit propagates (the caller undoes it)."""
    import contextlib
    import io
    out, err, cmd = io.StringIO(), io.StringIO(), tokens[0]
    saved = parser.error
    parser.error = lambda message: parser.exit(2, f"{parser.prog} {cmd}: error: {message}\n")
    code, line = 0, None
    try:
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            args = parser.parse_args(tokens)
            normalize_id_args(args)
            result = args.func(args)
        code = 0 if result is None or isinstance(result, tuple) else int(result or 0)
    except SystemExit as stop:
        if stop.code is None:
            code = 0
        elif isinstance(stop.code, int):
            code = stop.code
        else:
            code, line = 1, str(stop.code)
    finally:
        parser.error = saved
    if line is None:
        shown_lines = [l for l in (err.getvalue() if code else out.getvalue() or err.getvalue()).splitlines() if l.strip()]
        line = (shown_lines[-1] if code else shown_lines[0]) if shown_lines else ""
    return code, line.strip() or f"{cmd} exited {code} with no message"


def _cloud_agenda_snapshot() -> dict:
    """{path: bytes} of every file under works/agenda/ (an item folder is removed whole by agenda-delete)."""
    snap = {}
    if AGENDA.is_dir():
        for path in AGENDA.rglob("*"):
            if path.is_file():
                try:
                    snap[str(path)] = path.read_bytes()
                except OSError:
                    pass
    return snap


def _cloud_inbox_undo(undo: dict, snap: dict, pre: dict, cache: dict) -> int:
    """Put the tree back as one entry's command found it: every file it wrote (noted before the write) and the
    agenda folders, then the generated files rebuilt. Returns how many truth-set paths still differ."""
    def remove(path: Path) -> None:
        try:
            path.unlink()
        except FileNotFoundError:
            return
        try:
            rel = path.relative_to(ROOT).as_posix()
        except ValueError:
            return
        _cloud_remove(rel)
    for key, data in undo.items():
        path = Path(key)
        if data is None:
            remove(path)
        elif data is not False:
            _cloud_write_bytes(path, data)
    for key, data in snap.items():
        path = Path(key)
        try:
            same = path.is_file() and path.read_bytes() == data
        except OSError:
            same = False
        if not same:
            _cloud_write_bytes(path, data)
    if AGENDA.is_dir():
        for path in sorted(AGENDA.rglob("*"), reverse=True):
            if path.is_file() and str(path) not in snap:
                remove(path)
    rebuild_index_and_state()
    post = cloud_scan(cache)
    return sum(1 for rel in set(pre) | set(post) if pre.get(rel) != post.get(rel))


def cloud_inbox_apply(session: CloudSession, parser: argparse.ArgumentParser, entry: dict) -> tuple:
    """Apply one entry and report it: (outcome, line). Outcomes: applied, refused, pending (no result sent:
    the entry stays pending) and conflict (hi2vi refused the batch with 409: this checkout's change dropped,
    hi2vi's copy pulled). A network error mid-push propagates: the batch stays journaled and is resent."""
    eid, kind = entry["id"], entry.get("kind")
    tokens, unrun = cloud_inbox_tokens(entry, parser.prog)
    items = entry.get("items") if isinstance(entry.get("items"), list) else []
    named = [entry.get("minted_id")] if kind == "add" else items
    what = " ".join([CLOUD_INBOX_COMMANDS.get(kind, "agenda") if isinstance(kind, str) else "agenda"]
                    + [_cloud_inbox_id_shown(x) for x in named][:5] + (["..."] if len(named) > 5 else []))
    undo, snap, pre = {}, {}, {}
    if tokens is None:
        code, line = 2, unrun
    else:
        pre, snap = cloud_scan(session.cache), _cloud_agenda_snapshot()
        crash, wf_store._CLOUD_UNDO = None, {}
        try:
            code, line = cloud_inbox_run(parser, tokens)
        except BaseException as exc:  # noqa: BLE001 - any crash leaves the entry pending, the tree as it was
            crash = exc
        finally:
            undo, wf_store._CLOUD_UNDO = wf_store._CLOUD_UNDO, None
        if crash is not None or code not in (0, 1, 2):
            left = _cloud_inbox_undo(undo, snap, pre, session.cache)
            if crash is not None and not isinstance(crash, Exception):
                raise crash
            why = f"{crash.__class__.__name__} inside the command" if crash is not None else f"the command exited {code}"
            return "pending", (f"inbox {eid}: left pending ({what}): {why}; "
                               + (f"{left} file(s) could not be put back: run sync" if left else "its changes were undone"))
    planned = []
    if code == 0:
        post = cloud_scan(session.cache)
        changed = {rel for rel in set(pre) | set(post) if pre.get(rel) != post.get(rel)}
        session.pre = pre
        planned = session._diff(post, skip=(set(session.base["files"]) | set(post)) - changed)
        result = {"id": eid, "state": "applied", "exit": 0}
    else:
        if undo:  # a refusal writes nothing; anything one left is undone, so its result carries no file
            _cloud_inbox_undo(undo, snap, pre, session.cache)
        result = {"id": eid, "state": "refused", "reason": line, "exit": code}
    try:
        session.send(planned, inbox=[result], command=shlex.join(tokens) if tokens else f"inbox {eid}")
    except CloudConflict as exc:
        if code == 0:
            _cloud_inbox_undo(undo, snap, pre, session.cache)
            session._pull(cloud_scan(session.cache), strict=False)
        gone = [c for c in exc.conflicts if isinstance(c, dict) and c.get("inbox") == eid]
        why = (f"hi2vi holds it {gone[0].get('state') or 'resolved'} already (another checkout)" if gone
               else f"hi2vi refused its batch ({len(exc.conflicts)} conflict(s): run sync)")
        return "conflict", (f"inbox {eid}: not applied here ({what}): {why}; "
                            + ("this checkout's change was dropped and hi2vi's copy pulled" if code == 0 else "nothing was sent"))
    except CloudError as exc:
        if session.journal() is not None:  # sent, or about to be: the journal resends it at the next command
            raise
        if code == 0:
            _cloud_inbox_undo(undo, snap, pre, session.cache)
        return "pending", f"inbox {eid}: left pending ({what}): {exc}"
    if code == 0:
        return "applied", f"inbox {eid}: applied ({what}): {line}"
    return "refused", f"inbox {eid}: refused, exit {code} ({what}): {line}"


def cloud_inbox_step(session: CloudSession) -> None:
    """The web's agenda inbox, applied by a linked engine inside its lock: entries oldest first, each as its
    agenda command, each result in a batch of its own with the files that command wrote; one line printed per
    entry. Skipped while a journal is open (a push to resend, an interrupted command), and when P1 counted
    nothing pending. After a 409 the inbox is read again, so an entry another checkout took is not tried."""
    if session.inbox_pending == 0 or session.journal() is not None:
        return
    with CloudLock():
        parser, tried = None, set()
        while len(tried) < CLOUD_INBOX_MAX:
            entries = session._ask("GET", "inbox").get("entries")
            todo = [e for e in (entries if isinstance(entries, list) else [])
                    if isinstance(e, dict) and isinstance(e.get("id"), str) and e["id"] not in tried]
            if not todo:
                return
            parser = parser or build_parser()
            again = False
            for entry in todo[:CLOUD_INBOX_MAX - len(tried)]:
                tried.add(entry["id"])
                outcome, line = cloud_inbox_apply(session, parser, entry)
                print(line)
                if outcome == "conflict":
                    again = True
                    break
            if not again:
                return


def cloud_differences(session: CloudSession, running: bool) -> list:
    """[(state, rel, here's facts, hi2vi's facts)] for every path that differs between the disk, base.json and
    hi2vi. States: differs, here only, cloud only, deleted here, deleted in hi2vi, interrupted (a change on
    disk left by a command that stopped midway)."""
    manifest = session._ask("GET", f"manifest?since={session.base['head']}")
    changes = {c["path"]: c for c in manifest.get("changes") or [] if isinstance(c, dict) and cloud_truth_rel(c.get("path"))}
    disk, files, rows = cloud_scan(session.cache), session.base["files"], []
    for rel in sorted(set(files) | set(disk) | set(changes)):
        b, here, c = files.get(rel), disk.get(rel), changes.get(rel)
        bsha = (b or {}).get("sha256")
        csha = bsha if c is None else (None if c.get("deleted") else c.get("sha256"))
        here_changed, cloud_changed = here != bsha, csha != bsha
        if (not here_changed and not cloud_changed) or here == csha:
            continue  # unchanged, or both sides agree (the next command fixes the base)
        if here_changed and cloud_changed:
            state = "deleted here" if here is None else ("deleted in hi2vi" if csha is None else "differs")
        elif here_changed:
            state = "interrupted" if running else "here only"
        else:
            state = "cloud only"
        since = f"r{b.get('rev')}" if b else "the link"
        if here is None:
            here_fact = f"deleted since {since}" if b else "absent"
        else:
            mtime = datetime.fromtimestamp((ROOT / rel).stat().st_mtime).astimezone().replace(microsecond=0).isoformat()
            here_fact = (f"changed since {since}" if b else "new") if here_changed else f"unchanged since {since}"
            here_fact += f" ({mtime})"
        if c is None:
            cloud_fact = f"r{b.get('rev')} (unchanged)" if b else "no record"
        else:
            cloud_fact = f"r{c.get('rev')}" + (" deleted" if c.get("deleted") else "")
        rows.append((state, rel, here_fact, cloud_fact))
    session.cloud_head = manifest.get("head")
    return rows


def cloud_sync(args: argparse.Namespace) -> int:
    """sync: pull clean hi2vi changes, push clean local ones, apply the agenda inbox, list what remains (exit 1
    while anything differs). --diff <path>, --keep local|cloud <path>..., --status. Never resolves a mismatch on
    its own."""
    if not cloud_link_file().exists():
        raise SystemExit("this checkout is not linked (no .hi2vi/link.json): sync is for a linked checkout")
    if sum(bool(x) for x in (args.diff is not None, args.keep is not None, args.status)) > 1:
        raise SystemExit("sync takes one of --diff, --keep and --status at a time")
    if args.keep is not None and not args.paths:
        raise SystemExit("sync --keep needs at least one path: it never resolves everything at once "
                         "(sync lists them; nothing was changed)")
    if args.keep is None and args.paths:
        raise SystemExit("sync takes paths only with --keep local|cloud (nothing was changed)")
    paths = list(dict.fromkeys(cloud_rel_arg(p) for p in args.paths))
    try:
        if args.status:
            return cloud_sync_status(CloudSession(["sync", "--status"]))
        if args.diff is not None:
            return cloud_sync_diff(CloudSession(["sync", "--diff"]), cloud_rel_arg(args.diff))
        with CloudLock():
            tokens = ["sync"] + (["--keep", args.keep] + paths if args.keep else [])
            return cloud_sync_run(CloudSession(tokens), args.keep, paths)
    except Exception as exc:  # noqa: BLE001 - a CloudError's line, or any other failure named in one
        raise SystemExit(cloud_stop_line(exc, "sync"))


def _cloud_sync_head(session: CloudSession) -> dict:
    info = session._ask("GET", "head")
    if str(info.get("project_id")) != session.link.project:
        raise CloudError(f"hi2vi answered for project {info.get('project_id')}, not {session.link.project}: "
                         "this checkout's link is broken, and nothing was changed")
    session.inbox_pending = info.get("inbox_pending")
    return info


def cloud_sync_status(session: CloudSession) -> int:
    info = _cloud_sync_head(session)
    entry = session.journal()
    rows = cloud_differences(session, bool(entry and entry.get("state") == "running"))
    here = sum(1 for r in rows if r[0] in ("here only", "interrupted"))
    differ = sum(1 for r in rows if r[0] in ("differs", "deleted here", "deleted in hi2vi"))
    print(f"store=cloud server={session.link.server} project={session.link.project} head=r{info.get('head')} "
          f"base=r{session.base['head']} here={here} differ={differ} inbox={info.get('inbox_pending', 0)}"
          + (f" journal={entry.get('state')}" if entry else ""))
    return 0


def cloud_sync_diff(session: CloudSession, rel: str) -> int:
    _cloud_sync_head(session)
    item, cloud = session.fetch([rel]).get(rel, (None, b""))
    path = ROOT / rel
    here = path.read_bytes() if path.is_file() else b""
    if item is not None and here == cloud and path.is_file():
        print(f"no difference: {rel} (r{item.get('rev')})")
        return 0
    left = f"hi2vi/{rel} " + (f"(r{item.get('rev')})" if item is not None else "(no record)")
    right = f"here/{rel}" + ("" if path.is_file() else " (absent)")
    try:
        a, b = cloud.decode("utf-8").splitlines(keepends=True), here.decode("utf-8").splitlines(keepends=True)
    except UnicodeDecodeError:
        print(f"binary content differs: {left} {len(cloud)} bytes, {right} {len(here)} bytes")
        return 0
    for line in difflib.unified_diff(a, b, left, right):
        sys.stdout.write(line if line.endswith("\n") else line + "\n")
    return 0


def cloud_keep(session: CloudSession, side: str, paths: list, running) -> None:
    """sync --keep local|cloud <path>...: the operator's choice, path by path. local pushes the disk's copy
    over hi2vi's current revision (a deliberate overwrite, recorded with this command); cloud writes hi2vi's
    copy over the disk."""
    got, files = session.fetch(paths), session.base["files"]
    if side == "cloud":
        done = 0
        try:
            for rel in paths:
                if rel in got:
                    item, data = got[rel]
                    _cloud_write_bytes(ROOT / rel, data)
                    entry = {"rev": item.get("rev"), "sha256": item.get("sha256"), "kind": cloud_kind(rel)}
                    if entry["kind"] == "append":
                        entry["offset"] = len(data)
                    files[rel] = entry
                else:
                    _cloud_remove(rel)
                    files.pop(rel, None)
                done += 1
        except OSError as exc:  # the paths kept before it are recorded; this one and the rest are as they were
            session.save_base()
            raise CloudError(f"{paths[done]} could not be written here ({exc.__class__.__name__}: {exc.strerror or exc}): "
                             f"{done} path(s) before it are kept; fix it, then run sync --keep cloud again")
        session.save_base()
        cloud_rebuild(paths)
        print(f"kept hi2vi's copy of {len(paths)} path(s): the disk holds it now")
        return
    planned, session.pre = [], {}
    for rel in paths:
        path, cloud = ROOT / rel, got.get(rel)
        rev = cloud[0].get("rev") if cloud else None
        if path.is_file():
            data = path.read_bytes()
            if cloud and cloud[0].get("sha256") == _sha(data):
                entry = {"rev": rev, "sha256": cloud[0].get("sha256"), "kind": cloud_kind(rel)}
                if entry["kind"] == "append":
                    entry["offset"] = len(data)
                files[rel] = entry
                continue
            b = files.get(rel) or {}
            offset = b.get("offset", 0)
            if (cloud_kind(rel) == "append" and b.get("kind") == "append" and 0 <= offset <= len(data)
                    and _sha(data[:offset]) == b.get("sha256")):
                op = session._append_op(rel, data, offset, b.get("rev"), _sha(data))  # its new lines: never a put
                if op:                                                                # over other checkouts' lines
                    planned.append(op)
                continue
            planned.append(session._put_op(rel, data, rev, _sha(data)))
        elif cloud:
            planned.append(({"op": "delete", "path": rel, "base_rev": rev, "origin": "command"}, None, rel))
        else:
            files.pop(rel, None)
    session.save_base()
    if planned:
        session.send(planned, resume=running)
    print(f"kept this checkout's copy of {len(paths)} path(s): hi2vi holds it now")


def cloud_sync_run(session: CloudSession, keep, paths: list) -> int:
    _cloud_sync_head(session)
    if keep:
        cloud_keep_check(session, paths)
    notes = []
    entry = session.journal()
    if entry and entry.get("state") == "pushing" and isinstance(entry.get("batches"), list):
        try:  # the last command's push, resent with its batch ids (hi2vi applies each once)
            session._push([str(b) for b in entry["batches"]])
        except CloudError as exc:
            notes.append(str(exc))
        entry = session.journal()
    running = entry if entry and entry.get("state") == "running" else None
    if keep:
        cloud_keep(session, keep, paths, running)
        entry = session.journal()
        running = entry if entry and entry.get("state") == "running" else None
        session._pull(cloud_scan(session.cache), strict=False)  # hi2vi's clean changes, so the base catches up
    else:
        mismatch = session._pull(cloud_scan(session.cache), strict=False)
        if running is None:  # an interrupted command's changes wait for the operator's --keep
            session.pre = cloud_scan(session.cache)
            try:
                session.commit(skip=mismatch)
            except CloudError as exc:
                notes.append(str(exc).replace(": run sync", ""))
            cloud_inbox_step(session)  # an interrupted command's files wait for --keep, and so does the inbox
        elif session.inbox_pending:
            notes.append(f"the agenda inbox waits ({session.inbox_pending} change(s)): it is applied once the "
                         "interrupted command's files are resolved")
    rows = cloud_differences(session, running is not None)
    session.save_cache()
    if running is not None and not any(r[0] == "interrupted" for r in rows):
        session.clear_journal()
        notes.append(f"the interrupted command ({running.get('command') or 'unknown'}) is resolved: its journal is cleared")
    for note in notes:
        print(note)
    for state, rel, here_fact, cloud_fact in rows:
        print(f"{state}  {rel}  here: {here_fact}  hi2vi: {cloud_fact}")
    if rows:
        print(f"{len(rows)} path(s) differ between this checkout and hi2vi: sync --diff <path> shows one, "
              "sync --keep local|cloud <path>... resolves it")
        return 1
    print(f"in sync: head=r{session.cloud_head} base=r{session.base['head']}")
    return 1 if any(n.startswith("this change is on disk") for n in notes) else 0


def add_cloud_parsers(sub) -> None:
    """Link, unlink, sync: this part's commands, registered by the entry's build_parser in their place."""
    p = sub.add_parser("link", help="Link this checkout to hi2vi (cloud mode): hi2vi becomes the truth for works/ and docs/, and every command syncs at its boundary. Takes the project's page address; the workspace key is pasted at a prompt (one stdin line when not a terminal), never on the command line, and kept in $XDG_CONFIG_HOME/hi2vi/workspace-keys.json (folder 0700, file 0600). An empty project in hi2vi gets this checkout's files; one that already holds files is joined only from an unused install or an equal set, else the differences are listed. Refused, nothing written: at root, in a phase's worktree, with a phase in flight on a stream or another worktree, with uncommitted changes in the workflow repo, when already linked, http:// to a non-local host, a key file open to group or others. Prints store=cloud server= project= head=")
    p.add_argument("address", help="the project's page address: <server>/projects/<project-id>")
    p.set_defaults(func=cloud_link)
    _one_line_usage_errors(p)

    p = sub.add_parser("unlink", help="Return a linked checkout to local mode: pull to hi2vi's head (refused on a mismatch: sync first), push what is here, remove .hi2vi/; then commit the workflow repo once. The key stays in user config (revoke it on the project's page). --from-disk: offline, keep the disk as it is and say what it cannot hold")
    p.add_argument("--from-disk", action="store_true", dest="from_disk", help="the offline way back: no request; the disk becomes the truth as it is")
    p.set_defaults(func=cloud_unlink)
    _one_line_usage_errors(p)

    p = sub.add_parser("sync", help="A linked checkout's mismatch tool: pull clean hi2vi changes, push clean local ones, apply the web's pending agenda changes (each as its agenda command, one line each; next applies them too), then list what remains, one line per path (differs, here only, cloud only, deleted here, deleted in hi2vi, interrupted), exit 1 while anything differs. --diff PATH: a unified diff of hi2vi's copy against the disk. --keep local|cloud PATH...: resolve those paths only (local pushes the disk's copy over hi2vi's revision, cloud writes hi2vi's copy over the disk); never without a path. --status: one line, store=cloud server= project= head= base= here= differ= inbox=")
    p.add_argument("--diff", metavar="PATH", help="show hi2vi's copy against the disk for one path")
    p.add_argument("--keep", choices=("local", "cloud"), help="resolve the named paths with this side's copy")
    p.add_argument("--status", action="store_true", help="one line: the head, the base and the counts")
    p.add_argument("paths", nargs="*", help="--keep only: the paths to resolve")
    p.set_defaults(func=cloud_sync)
    _one_line_usage_errors(p)
