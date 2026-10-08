"""A PtyTerm for the pty tests of DN: the clock of the menu bar does not count as output.

DN redraws the clock at the right end of the menu bar every second, so PtyTerm.pump (read until the program is quiet for
`timeout` seconds) never sees a pause of a second or more and always runs to its `limit`. DnTerm.pump is the same wait, but
output that changes only the clock (a time such as 23:36:43 in the top row) does not end the pause.

  from dn_wait import DnTerm
  t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
  t.send(F5, 1.5)           # back after 1.5 s without a change of the screen, not after 8 s
"""
import os
import re
import select
import time

from pty_screen import PtyTerm

CLOCK = re.compile(r'\d{1,2}:\d\d(:\d\d)?')


class DnTerm(PtyTerm):
    def shape(self):
        """the screen without the clock: the text of the rows (the times of the top row masked) and the attributes"""
        s = self.screen
        rows = [''.join(c for c, _ in row) for row in s.cells]
        if rows:
            rows[0] = CLOCK.sub('#', rows[0])
        return rows, [[a for _, a in row] for row in s.cells], s.alt

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

    def started(self, quiet=1.0, timeout=20.0):
        """waits for the first screen of the program and then for a pause of `quiet` seconds; True when something is drawn"""
        end = time.time() + timeout
        while not self.text().strip():
            if time.time() >= end or not self.alive():
                return False
            self.pump(0.05, 0.2)
        self.pump(quiet, max(end - time.time(), quiet))
        return True

    def wait_text(self, text, timeout=10.0):
        """reads until `text` is on the screen; True when it is"""
        end = time.time() + timeout
        while text not in self.text():
            if time.time() >= end:
                return False
            self.pump(0.05, max(min(0.2, end - time.time()), 0.01))
        return True
