"""A terminal with the far2l terminal extensions, for the tests of DN in a pty (tools/dn-linux-far2l.py). MIT, see LICENSE.

Term runs a program in a pseudo terminal, draws what it writes on a pty_screen.Screen and plays the terminal side of the extensions:
it acknowledges `ESC _ far2l1`, answers the requests (features, the maximum size, the color depth, the
F-key titles, the clipboard, images: none) and keeps the clipboard of the terminal in `clip`. Input goes to the program as events:
key() builds a full key event (K / k).

  t = Term('./dn', env, cwd, screen=Screen(100, 30))
  t.pump(2.0)                 # read and answer until the program is quiet for 2 s
  t.acked                     # the program switched the extensions on
  t.clip = b'text'            # the user copied something in another program
  t.gesture = time.time()     # a paste gesture: the clipboard may be read for 5 s
  t.send(key(True, 0, 0x10, 0x52, 0x2D))   # Shift+Ins pressed
  t.close()

Reading the clipboard (CLIP_GETDATA) is allowed for 5 seconds after a paste gesture: the time in `gesture`, set by the test or by a key
event of Ctrl+V or Shift+Ins that goes through send(). A read within that time extends it once more, at most 3 times per gesture.
"""
import base64
import fcntl
import os
import pty
import re
import select
import signal
import struct
import termios
import time
import zlib

CF_TEXT, CF_UNICODETEXT = 1, 13
FEAT_TERMINAL_SIZE = 2
FEATCLIP_DATA_ID, FEATCLIP_CHUNKED_SET = 1, 2
GESTURE_TIME = 5.0
GESTURE_EXTENDS = 3
CLIENT_ID = re.compile(rb'[0-9a-z_-]{32,256}')


class Stack:
    """the stack of a request: pop takes from the end"""

    def __init__(self, data=b''):
        self.data = bytearray(data)

    def pop(self, n):
        if n > len(self.data):
            raise ValueError('the stack is short')
        v = bytes(self.data[len(self.data) - n:])
        del self.data[len(self.data) - n:]
        return v

    def pop_int(self, fmt):
        return struct.unpack('<' + fmt, self.pop(struct.calcsize(fmt)))[0]

    def pop_str(self):
        return self.pop(self.pop_int('I'))

    def push(self, raw):
        self.data += raw
        return self

    def push_int(self, fmt, v):
        return self.push(struct.pack('<' + fmt, v))


def key(down, ch, controlstate, scancode, vk, repeat=1):
    """a key event of the terminal (full form): pop order char, control key state, scan code, virtual key, repeat count"""
    s = Stack().push_int('H', repeat).push_int('H', vk).push_int('H', scancode).push_int('I', controlstate).push_int('I', ch)
    s.push(b'K' if down else b'k')
    return b'\x1b_f2l' + base64.b64encode(bytes(s.data)) + b'\x07'


def data_id(data):
    v = (zlib.crc32(data) << 32 | zlib.crc32(data[::-1]) ^ len(data)) & 0xFFFFFFFFFFFFFFFF
    return v or 1


class Term:
    def __init__(self, path, env, cwd, screen):
        self.screen = screen
        self.out = b''                  # all that the program wrote
        self.acked = False              # the program asked for the extensions and got the answer
        self.active = False
        self.features = 0
        self.formats = {}               # the clipboard of the terminal: format -> bytes
        self.registered = {}            # registered format names -> IDs
        self.opened = False
        self.chunks = b''
        self._gesture = 0.0
        self.extends = 0
        self.fkeys = []                 # the last F-key titles
        self.notes = []                 # desktop notifications (title, text)
        self.status = None
        self.pending = b''
        winsz = struct.pack('HHHH', screen.rows, screen.cols, 0, 0)
        e = dict(env)
        e.setdefault('COLUMNS', str(screen.cols))
        e.setdefault('LINES', str(screen.rows))
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            try:
                fcntl.ioctl(1, termios.TIOCSWINSZ, winsz)
                if cwd:
                    os.chdir(cwd)
                os.execve(path, [path], e)
            finally:
                os._exit(127)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, winsz)

    # the clipboard as text (CF_TEXT); setting it replaces the clipboard, as a copy in another program does
    @property
    def clip(self):
        if CF_TEXT in self.formats:
            return self.formats[CF_TEXT].split(b'\0', 1)[0]
        if CF_UNICODETEXT in self.formats:
            return self.formats[CF_UNICODETEXT].decode('utf-32-le', 'replace').split('\0', 1)[0].encode()
        return b''

    @clip.setter
    def clip(self, value):
        self.formats = {CF_TEXT: bytes(value)}

    @property
    def gesture(self):
        return self._gesture

    @gesture.setter
    def gesture(self, t):
        self._gesture = t
        self.extends = 0

    def write(self, data):
        os.write(self.fd, data)

    def send(self, data):
        if isinstance(data, str):
            data = data.encode()
        for m in re.finditer(rb'\x1b_f2l([A-Za-z0-9+/=]*)\x07', data):
            self._seen_event(m.group(1))
        self.write(data)

    def _seen_event(self, b64):
        """a key event on its way to the program: Ctrl+V or Shift+Ins is a paste gesture"""
        try:
            s = Stack(base64.b64decode(b64))
            if s.pop(1) != b'K':
                return
            s.pop_int('I')
            cs = s.pop_int('I')
            s.pop_int('H')
            vk = s.pop_int('H')
        except ValueError:
            return
        ctrl, alt, shift = cs & 0x0C, cs & 0x03, cs & 0x10
        if (vk == 0x56 and ctrl and not alt) or (vk == 0x2D and shift and not ctrl and not alt):
            self.gesture = time.time()

    def pump(self, timeout=0.3, limit=None):
        """reads and answers what the program writes until it is quiet for `timeout` seconds"""
        stop = time.time() + (limit if limit is not None else timeout * 4 + 8)
        end = time.time() + timeout
        while time.time() < end and time.time() < stop:
            r, _, _ = select.select([self.fd], [], [], max(min(end, stop) - time.time(), 0))
            if not r:
                break
            try:
                data = os.read(self.fd, 65536)
            except OSError:
                break
            if not data:
                break
            self.out += data
            self.screen.feed(data)
            self.scan(data)
            end = time.time() + timeout

    SEQ = re.compile(rb'\x1b_(.*?)(?:\x07|\x1b\\)|\x1b\[([56])n', re.S)

    def scan(self, data):
        buf = self.pending + data
        pos = 0
        for m in self.SEQ.finditer(buf):
            pos = m.end()
            if m.group(2) == b'5':
                self.write(b'\x1b[0n')
            elif m.group(2) == b'6':
                self.write(b'\x1b[%d;%dR' % (self.screen.y + 1, self.screen.x + 1))
            else:
                self.apc(m.group(1))
        rest = buf[pos:]
        i = rest.rfind(b'\x1b')
        self.pending = b''
        if i >= 0:
            tail = rest[i:]
            if tail.startswith(b'\x1b_') or len(tail) < 4:
                self.pending = tail
        if len(self.pending) > 1 << 26:
            self.pending = b''

    def apc(self, body):
        if not body.startswith(b'far2l'):
            return
        rest = body[5:]
        if rest == b'1':
            self.acked = self.active = True
            self.write(b'\x1b_far2lok\x07')
        elif rest == b'0':
            self.active = False
            self.features = 0
            self.opened = False
            self.chunks = b''
            self.fkeys = []
        elif rest.startswith(b':') and self.active:
            m = re.match(rb'[A-Za-z0-9+/]*', rest[1:])
            raw = m.group(0)
            try:
                stack = Stack(base64.b64decode(raw + b'=' * (-len(raw) % 4)))
            except ValueError:
                return
            self.request(stack)

    def reply(self, rid, s=None):
        if rid:
            s = s or Stack()
            s.push_int('B', rid)
            self.write(b'\x1b_far2l' + base64.b64encode(bytes(s.data)) + b'\x07')

    def request(self, s):
        try:
            rid = s.pop_int('B')
        except ValueError:
            return
        try:
            cmd = s.pop(1)
            out = self.command(cmd, s)
        except ValueError:
            out = None
        self.reply(rid, out)

    def command(self, cmd, s):
        """executes one request; returns the stack of the reply (without the ID) or None"""
        if cmd == b'x':
            self.features = s.pop_int('Q')
            if self.features & FEAT_TERMINAL_SIZE:
                ev = Stack().push_int('H', self.screen.cols).push_int('H', self.screen.rows).push(b'S')
                self.write(b'\x1b_f2l' + base64.b64encode(bytes(ev.data)) + b'\x07')
        elif cmd == b'h':
            s.pop_int('B')
        elif cmd == b'w':
            return Stack().push_int('h', self.screen.cols).push_int('h', self.screen.rows)
        elif cmd == b'n':
            title = s.pop_str()
            text = s.pop_str()
            self.notes.append((title.decode('utf-8', 'replace'), text.decode('utf-8', 'replace')))
        elif cmd == b'f':
            titles = []
            while len(titles) < 12 and s.data:
                titles.append(s.pop_str().decode('utf-8', 'replace') if s.pop_int('B') else None)
            self.fkeys = titles
            return Stack().push_int('B', 1)
        elif cmd == b'p':
            return Stack().push_int('B', 0).push_int('B', 24)
        elif cmd == b'c':
            return self.clipboard(s.pop(1), s)
        elif cmd == b'i':
            sub = s.pop(1)
            if sub == b'c':
                return Stack().push_int('Q', 0).push_int('h', 0).push_int('h', 0)
            return Stack().push_int('B', 0)
        return None

    def clipboard(self, sub, s):
        r = Stack()
        if sub == b'o':
            cid = s.pop_str()
            self.chunks = b''
            ok = bool(CLIENT_ID.fullmatch(cid)) and not self.opened
            if ok:
                self.opened = True
            return r.push_int('Q', FEATCLIP_DATA_ID | FEATCLIP_CHUNKED_SET).push_int('b', 1 if ok else 0)
        if sub == b'c':
            was = self.opened
            self.opened = False
            self.chunks = b''
            self.extends = 0
            return r.push_int('b', 1 if was else -1)
        if sub == b'e':
            if not self.opened:
                return r.push_int('b', -1)
            self.formats = {}
            return r.push_int('b', 1)
        if sub == b'a':
            fmt = s.pop_int('I')
            return r.push_int('b', 1 if self.get(fmt) else 0)
        if sub == b'S':
            size = s.pop_int('H') << 8
            if size == 0:
                self.chunks = b''
            else:
                chunk = s.pop(size)
                if self.opened:
                    self.chunks += chunk
            return None
        if sub == b's':
            fmt = s.pop_int('I')
            size = s.pop_int('I')
            data = self.chunks + s.pop(size)
            self.chunks = b''
            if not self.opened:
                return r.push_int('b', -1)
            self.put(fmt, data)
            return r.push_int('Q', data_id(data)).push_int('b', 1)
        if sub == b'g':
            fmt = s.pop_int('I')
            if not self.opened:
                return r.push_int('I', 0xFFFFFFFF)
            data = b''
            if self.readable(extend=True):
                data = self.get(fmt)
            return r.push_int('Q', data_id(data) if data else 0).push(data).push_int('I', len(data))
        if sub == b'i':
            fmt = s.pop_int('I')
            data = self.get(fmt) if self.opened and self.readable(extend=False) else b''
            return r.push_int('Q', data_id(data) if data else 0)
        if sub == b'r':
            name = s.pop_str()
            if name not in self.registered:
                self.registered[name] = 0xC000 + len(self.registered)
            return r.push_int('I', self.registered[name])
        return None

    def readable(self, extend):
        now = time.time()
        if now - self._gesture > GESTURE_TIME:
            return False
        if extend and self.extends < GESTURE_EXTENDS:
            self._gesture = now
            self.extends += 1
        return True

    def get(self, fmt):
        if fmt in self.formats:
            return self.formats[fmt]
        if fmt == CF_UNICODETEXT and CF_TEXT in self.formats:
            return self.clip.decode('utf-8', 'replace').encode('utf-32-le')
        if fmt == CF_TEXT and CF_UNICODETEXT in self.formats:
            return self.clip
        return b''

    def put(self, fmt, data):
        self.formats[fmt] = data
        if fmt == CF_TEXT:
            self.formats.pop(CF_UNICODETEXT, None)
        elif fmt == CF_UNICODETEXT:
            self.formats.pop(CF_TEXT, None)

    def text(self):
        return '\n'.join(self.screen.lines())

    def alive(self):
        if self.status is not None:
            return False
        pid, st = os.waitpid(self.pid, os.WNOHANG)
        if pid:
            self.status = os.waitstatus_to_exitcode(st)
            return False
        return True

    def close(self, wait=3.0):
        """the exit status of the program (it is killed if it does not end)"""
        end = time.time() + wait
        while self.alive() and time.time() < end:
            self.pump(0.1, limit=0.5)
        if self.alive():
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        os.close(self.fd)
        return self.status
