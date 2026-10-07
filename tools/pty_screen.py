"""A pty and a tiny terminal emulator, for the tests of the terminal backend (tv/src/tvunix.pas).

PtyTerm runs a program in a pseudo terminal of a given size, sends keys to it and keeps the screen that the
program draws (the text of the cells, the attributes of the cells and the cursor). It understands what TvUnix
writes: cursor moves (CSI H, G), SGR (colors and styles), clear screen (CSI 2J), the alternate screen, the
visibility of the cursor, and ignores the other private modes. It is a test aid, not a terminal.

  t = PtyTerm(['./tvdemo'], cols=80, rows=25)
  t.wait_for('File')        # until the text is on the screen
  t.send(b'\\x1b[15~')       # F5
  print(t.text())           # the screen as 25 lines
  t.close()
"""
import os
import re
import struct
import time
import unicodedata

try:                      # not on Windows (there only Screen is used: tools/dn-win-smoke.py)
    import fcntl
    import pty
    import select
    import signal
    import termios
except ImportError:
    pty = None


class Screen:
    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.reset()

    def reset(self):
        self.cells = [[(' ', None)] * self.cols for _ in range(self.rows)]
        self.x = self.y = 0
        self.attr = (None, None, 0)         # fg, bg, style
        self.cursor_visible = True
        self.alt = False
        self.primary = None
        self.log = []                        # the private modes that were set (for the tests)

    def put(self, ch):
        if len(ch) != 1:
            ch = '?'
        w = 2 if unicodedata.east_asian_width(ch) in 'WF' else 1
        if unicodedata.combining(ch):
            return
        if self.x + w > self.cols:
            return                           # no wrapping (TvUnix switches it off)
        self.cells[self.y][self.x] = (ch, self.attr)
        if w == 2 and self.x + 1 < self.cols:
            self.cells[self.y][self.x + 1] = ('', self.attr)
        self.x += w

    def sgr(self, params):
        fg, bg, style = self.attr
        i = 0
        ps = params or [0]
        while i < len(ps):
            p = ps[i]
            if p == 0:
                fg, bg, style = None, None, 0
            elif p in (1, 3, 4, 5, 7, 9):
                style |= 1 << p
            elif p in (22, 23, 24, 25, 27, 29):
                style &= ~(1 << (p - 20))
                if p == 22:
                    style &= ~(1 << 1)
            elif 30 <= p <= 37:
                fg = ('i', p - 30)
            elif 40 <= p <= 47:
                bg = ('i', p - 40)
            elif 90 <= p <= 97:
                fg = ('i', p - 90 + 8)
            elif 100 <= p <= 107:
                bg = ('i', p - 100 + 8)
            elif p == 39:
                fg = None
            elif p == 49:
                bg = None
            elif p in (38, 48) and i + 1 < len(ps):
                if ps[i + 1] == 5 and i + 2 < len(ps):
                    c = ('i', ps[i + 2]); i += 2
                elif ps[i + 1] == 2 and i + 4 < len(ps):
                    c = ('rgb', ps[i + 2], ps[i + 3], ps[i + 4]); i += 4
                else:
                    c = None
                if p == 38:
                    fg = c
                else:
                    bg = c
            i += 1
        self.attr = (fg, bg, style)

    CSI = re.compile(rb'\x1b\[([?<>=]?)([0-9;:]*)([ -/]*)([@-~])')

    def feed(self, data):
        text = self.pending + data if hasattr(self, 'pending') else data
        self.pending = b''
        i = 0
        while i < len(text):
            b = text[i:i + 1]
            if b == b'\x1b':
                if text[i + 1:i + 2] in (b']', b'_', b'P', b'^', b'X'):
                    # a string (OSC, APC, DCS, PM, SOS) ends with BEL or ESC \: it is not text of the screen
                    end_bel = text.find(b'\x07', i + 2)
                    end_st = text.find(b'\x1b\\', i + 2)
                    ends = [(e, n) for e, n in ((end_bel, 1), (end_st, 2)) if e >= 0]
                    if not ends:
                        self.pending = text[i:]
                        return
                    e, n = min(ends)
                    i = e + n
                    continue
                m = self.CSI.match(text, i)
                if not m:
                    if i + 1 >= len(text) or text[i + 1:i + 2] == b'[':
                        self.pending = text[i:]      # an incomplete sequence: wait for the rest
                        return
                    i += 2
                    continue
                self.csi(m.group(1).decode(), m.group(2).decode(), m.group(3).decode(), m.group(4).decode())
                i = m.end()
                continue
            if b == b'\r':
                self.x = 0
            elif b == b'\n':
                self.y = min(self.y + 1, self.rows - 1)
            elif b == b'\x07':
                pass
            else:
                n = 1
                c = text[i]
                if c >= 0xF0: n = 4
                elif c >= 0xE0: n = 3
                elif c >= 0xC0: n = 2
                if i + n > len(text):
                    self.pending = text[i:]
                    return
                self.put(text[i:i + n].decode('utf-8', 'replace'))
                i += n
                continue
            i += 1

    def csi(self, priv, params, inter, final):
        nums = [int(p) if p else 0 for p in re.split('[;:]', params)] if params else []
        n = lambda d=1: nums[0] if nums and nums[0] else d
        if priv == '?':
            for p in nums:
                if final == 'h':
                    self.log.append(('h', p))
                    if p == 25: self.cursor_visible = True
                    if p == 1049 and not self.alt:
                        self.primary = (self.cells, self.x, self.y, self.attr, self.cursor_visible)
                        self.cells = [[(' ', None)] * self.cols for _ in range(self.rows)]
                        self.x = self.y = 0
                        self.attr = (None, None, 0)
                        self.alt = True
                elif final == 'l':
                    self.log.append(('l', p))
                    if p == 25: self.cursor_visible = False
                    if p == 1049 and self.alt:
                        self.alt = False
                        if self.primary is not None:
                            self.cells, self.x, self.y, self.attr, self.cursor_visible = self.primary
                            self.primary = None
            return
        if priv:
            return
        if final == 'H' or final == 'f':
            self.y = min(max(n() - 1, 0), self.rows - 1)
            self.x = min(max((nums[1] if len(nums) > 1 and nums[1] else 1) - 1, 0), self.cols - 1)
        elif final == 'G':
            self.x = min(max(n() - 1, 0), self.cols - 1)
        elif final == 'A': self.y = max(self.y - n(), 0)
        elif final == 'B': self.y = min(self.y + n(), self.rows - 1)
        elif final == 'C': self.x = min(self.x + n(), self.cols - 1)
        elif final == 'D': self.x = max(self.x - n(), 0)
        elif final == 'm':
            self.sgr(nums)
        elif final == 'J' and (not nums or nums[0] in (2, 3)):
            self.cells = [[(' ', None)] * self.cols for _ in range(self.rows)]
        elif final == 'K':
            for x in range(self.x, self.cols):
                self.cells[self.y][x] = (' ', None)

    def lines(self):
        return [''.join(c for c, _ in row).rstrip() for row in self.cells]


class PtyTerm:
    def __init__(self, cmd, cols=80, rows=25, env=None, cwd=None, exe=None):
        self.screen = Screen(cols, rows)
        self.raw = b''
        e = dict(os.environ)
        # COLUMNS/LINES: OsSize falls back here when TIOCGWINSZ is 0 (common
        # right after pty.fork before the parent sets winsize).
        e.update({
            'TERM': 'xterm-256color',
            'COLORTERM': '',
            'COLUMNS': str(cols),
            'LINES': str(rows),
        })
        if env:
            e.update(env)
            # Keep size pins unless the caller overrode them explicitly.
            e.setdefault('COLUMNS', str(cols))
            e.setdefault('LINES', str(rows))
        # DN keeps its settings in the configuration of the user (~/.config/dn); a test that runs a copy of DN in a directory of its own wants them there (the DN2 of DN:
        # the directory of the program and of the files together, as it was before the move); a test of the default place passes env={'DN2': ''}
        if exe and os.path.basename(exe) == 'dn' and 'DN2' not in e:
            e['DN2'] = os.path.dirname(os.path.abspath(exe))
        winsz = struct.pack('HHHH', rows, cols, 0, 0)
        self.pid, self.fd = pty.fork()
        self.status = None
        if self.pid == 0:
            # Set slave winsize before exec so the program never observes 0x0
            # (→ default 80) while the parent is still calling set_size.
            try:
                fcntl.ioctl(1, termios.TIOCSWINSZ, winsz)
            except OSError:
                pass
            if cwd:
                os.chdir(cwd)
            os.environ.update(e)
            prefix = os.environ.get('PTY_RUN_PREFIX')            # e.g. qemu-aarch64-static: the program is of another CPU
            if prefix:
                os.execvpe(prefix, [prefix, exe or cmd[0]] + list(cmd[1:]), e)
            os.execve(exe or cmd[0], cmd, e) if (exe or '/' in cmd[0]) else os.execvpe(cmd[0], cmd, e)
        self.set_size(cols, rows)

    def set_size(self, cols, rows):
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
        self.screen.cols, self.screen.rows = cols, rows
        self.screen.cells = [[(' ', None)] * cols for _ in range(rows)]

    def resize(self, cols, rows):
        self.set_size(cols, rows)
        os.kill(self.pid, signal.SIGWINCH)

    def pump(self, timeout=0.3, limit=8.0):
        """reads what the program wrote until it is quiet for `timeout` seconds (at most `limit` seconds)"""
        stop = time.time() + limit
        end = time.time() + timeout
        while time.time() < end and time.time() < stop:
            r, _, _ = select.select([self.fd], [], [], max(end - time.time(), 0))
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
            end = time.time() + timeout

    def send(self, data, settle=0.3):
        if isinstance(data, str):
            data = data.encode()
        os.write(self.fd, data)
        self.pump(settle)

    def alive(self):
        """False when the program has ended (its status is in self.status)"""
        if self.status is not None:
            return False
        pid, st = os.waitpid(self.pid, os.WNOHANG)
        if pid:
            self.status = os.waitstatus_to_exitcode(st)
            return False
        return True

    def text(self):
        return '\n'.join(self.screen.lines())

    def wait_for(self, text, timeout=5.0):
        end = time.time() + timeout
        while time.time() < end:
            self.pump(0.2)
            if text in self.text():
                return True
        return False

    def close(self, wait=3.0):
        """the exit status of the program (kills it if it does not end)"""
        end = time.time() + wait
        status = self.status
        while status is None and time.time() < end:
            self.pump(0.1)
            if not self.alive():
                status = self.status
        if status is None:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        os.close(self.fd)
        return status
