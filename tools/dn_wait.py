"""A PtyTerm for the pty tests of DN: the clock of the menu bar does not count as output.

DN redraws the clock at the right end of the menu bar every second, so PtyTerm.pump (read until the program is quiet for
`timeout` seconds) never sees a pause of a second or more and always runs to its `limit`. DnTerm.pump is the same wait, but
output that changes only the clock (a time such as 23:36:43 in the top row) does not end the pause.

  from dn_wait import DnTerm
  t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
  t.send(F5, 1.5)           # back after 1.5 s without a change of the screen, not after 8 s
"""
import io
import os
import re
import select
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

from pty_screen import PtyTerm

CLOCK = re.compile(r'\d{1,2}:\d\d(:\d\d)?')


def shape(screen):
    """the screen without the clock: the text of the rows (the times of the top row masked) and the attributes"""
    rows = [''.join(c for c, _ in row) for row in screen.cells]
    if rows:
        rows[0] = CLOCK.sub('#', rows[0])
    return rows, [[a for _, a in row] for row in screen.cells], screen.alt


class DnTerm(PtyTerm):
    def __init__(self, cmd, cols=80, rows=25, env=None, cwd=None, exe=None):
        # the temporary files of DN have fixed names (/tmp/$DN0$.LST): a copy of DN that runs beside others gets a TEMP of its own, next to it
        env = dict(env or {})
        if exe and 'TEMP' not in env and 'TEMP' not in os.environ:
            env['TEMP'] = os.path.join(os.path.dirname(os.path.abspath(exe)), 'tmp')
            os.makedirs(env['TEMP'], exist_ok=True)
        super().__init__(cmd, cols, rows, env=env, cwd=cwd, exe=exe)

    def shape(self):
        return shape(self.screen)

    def pump(self, timeout=0.3, limit=8.0):
        """reads what the program writes until the screen (but the clock) has not changed for `timeout` seconds
        (at most `limit` seconds)"""
        now = time.time()
        stop = now + limit
        end = now + timeout
        last = self.shape()
        while True:
            now = time.time()
            if now >= end or now >= stop:
                break
            r, _, _ = select.select([self.fd], [], [], min(end, stop) - now)
            if not r:
                break
            try:
                data = os.read(self.fd, 65536)
            except OSError:
                break
            if not data:
                break
            self.raw += data
            self.screen.feed(data)
            cur = self.shape()
            if cur != last:
                last = cur
                end = time.time() + timeout

    def started(self, quiet=1.0, timeout=60.0):
        """waits for the first screen of the program and then for a pause of `quiet` seconds; True when something is drawn"""
        end = time.time() + timeout
        while not self.text().strip():
            if time.time() >= end or not self.alive():
                return False
            self.pump(0.05, 0.2)
        self.pump(quiet, max(end - time.time(), quiet))
        return True

    def until(self, cond, timeout=10.0):
        """reads until cond() is true (at most `timeout` seconds); True when it is"""
        end = time.time() + timeout
        while not cond():
            if time.time() >= end:
                return False
            self.pump(0.2, max(min(0.5, end - time.time()), 0.01))
        return True

    def wait_text(self, text, timeout=10.0):
        """reads until `text` is on the screen; True when it is"""
        return self.until(lambda: text in self.text(), timeout)


class _Out:
    """sys.stdout of side_by_side: what a part prints goes to the buffer of its thread"""
    def __init__(self, real):
        self.real, self.local = real, threading.local()

    def write(self, s):
        buf = getattr(self.local, 'buf', None)
        return (buf or self.real).write(s)

    def flush(self):
        if getattr(self.local, 'buf', None) is None:
            self.real.flush()

    def __getattr__(self, name):
        return getattr(self.real, name)


def side_by_side(parts):
    """runs the functions `parts` at once, each in a thread (each must use a directory and a HOME of its own); what a part prints is
    printed when it ends, in the order of the parts; returns their results (an exception of a part is raised after all have ended)"""
    real = sys.stdout
    out = _Out(real)
    sys.stdout = out

    def run(fn):
        out.local.buf = io.StringIO()
        try:
            return fn(), None, out.local.buf.getvalue()
        except BaseException as e:            # SystemExit of a check too
            return None, e, out.local.buf.getvalue()
        finally:
            out.local.buf = None

    try:
        with ThreadPoolExecutor(max(len(parts), 1)) as ex:
            res = []
            for r, e, text in ex.map(run, parts):
                real.write(text)
                real.flush()
                res.append((r, e))
    finally:
        sys.stdout = real
    for r, e in res:
        if e is not None:
            raise e
    return [r for r, _ in res]
