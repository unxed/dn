#!/usr/bin/env python3
"""The Windows build of DN on a real Windows console (ConPTY, via pywinpty), the screen is read with the same emulator as in the
Linux tests (tools/pty_screen.py): start, the menu bar, no country-setup error, F7 makes a directory, the quit.
usage: python tools/dn-win-smoke.py OUTDIR   (OUTDIR: the result of tools/build.sh win64|win32; needs: pip install pywinpty; DN_SMOKE_UTF8=1: the build with UTF-8 inside, more checks)"""
import os
import re
import shutil
import sys
import tempfile
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import Screen

sys.stdout.reconfigure(encoding='utf-8', errors='replace')      # the screen has box characters; the console of CI is cp1252
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name, flush=True)
    if not cond:
        fails += 1
        if info:
            print(info, flush=True)


class WinTerm:
    """the same interface as PtyTerm (pump/send/text/raw/alive/close) on top of winpty"""

    def __init__(self, exe, cwd, cols=100, rows=30):
        from winpty import PtyProcess
        self.screen = Screen(cols, rows)
        self.raw = b''
        self.lock = threading.Lock()
        self.p = PtyProcess.spawn([exe], cwd=cwd, dimensions=(rows, cols))
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        while True:
            try:
                s = self.p.read(65536)
            except EOFError:
                break
            except Exception:
                break
            if s:
                with self.lock:
                    self.raw += s.encode('utf-8', 'replace')
                    self.screen.feed(s.encode('utf-8', 'replace'))

    def pump(self, timeout=0.3, limit=8.0):
        time.sleep(min(timeout, limit))

    def send(self, data, settle=0.5):
        self.p.write(data)
        time.sleep(settle)

    def text(self):
        with self.lock:
            return '\n'.join(self.screen.lines())

    def wait_for(self, text, timeout=10.0):
        end = time.time() + timeout
        while time.time() < end:
            if text in self.text():
                return True
            time.sleep(0.2)
        return False

    def alive(self):
        return self.p.isalive()

    def close(self):
        try:
            self.p.terminate(force=True)
        except Exception:
            pass


def shot(t, name):
    """the screen as text between markers (the log of CI; tools/dn-win-smoke.py > dist/win64/screenshots)"""
    print('=== SCREEN %s ===' % name)
    print('\n'.join(l.rstrip() for l in t.text().split('\n')).rstrip())
    print('=== END ===', flush=True)


def main():
    out = os.path.abspath(sys.argv[1])
    d = tempfile.mkdtemp(prefix='dnwin-')
    try:
        for f in os.listdir(out):
            src = os.path.join(out, f)
            if os.path.isdir(src):
                shutil.copytree(src, os.path.join(d, f))
            else:
                shutil.copy(src, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        open(os.path.join(w, 'a.txt'), 'w').write('first\n')
        u8 = os.environ.get('DN_SMOKE_UTF8') == '1'              # the build with UTF-8 inside: names outside the ANSI page (cp1252)
        if u8:
            for nm in ('\u041f\u0440\u0438\u0432\u0435\u0442.txt', '\u03b1\u03b2\u03b3.txt'):
                open(os.path.join(w, nm), 'w', encoding='utf-8').write('\u041f\u0440\u0438\u0432\u0435\u0442\n')
        t = WinTerm(os.path.join(d, 'dn.exe'), w)
        ok = t.wait_for('Utilities', 30)
        check(ok, 'start: the menu bar is drawn', t.text())
        check(b'Error in country' not in t.raw, 'start: no country setup error (xlt next to the program)')
        t.wait_for('txt', 10)
        check('Name' in t.text() and re.search(r'a\s+txt', t.text()), 'start: the panel shows the files of the directory', t.text())
        shot(t, 'start')
        t.send('\x1b', 0.5)
        shot(t, 'panels')
        t.send('\x1b[21~', 0.5)                       # F10: the menu bar
        t.send('\r', 1.0)                            # Enter: the first menu
        shot(t, 'menu')
        t.send('\x1b', 0.5)
        t.send('\x1b', 0.5)
        t.send('\x1bOP', 1.0)                         # F1: help
        shot(t, 'f1help')
        for _ in range(3):
            t.send('\x1b', 0.5)
        t.send('\x1b[18~', 1.0)                       # F7
        shot(t, 'f7mkdir')
        t.send('newdir', 0.5)
        t.send('\r', 1.5)
        check(os.path.isdir(os.path.join(w, 'newdir')), 'F7: the directory is made', t.text())
        if u8:
            check('\u041f\u0440\u0438\u0432\u0435\u0442' in t.text() and '\u03b1\u03b2\u03b3' in t.text(), 'UTF-8: the names outside the ANSI page are shown', t.text())
            t.send('\x1b[18~', 1.0)                   # F7: a directory with a Russian name
            t.send('\u043f\u0430\u043f\u043a\u0430', 0.5)
            t.send('\r', 1.5)
            check(os.path.isdir(os.path.join(w, '\u043f\u0430\u043f\u043a\u0430')), 'UTF-8: F7 makes a directory with a Russian name', t.text())
        # a command typed in the command line is run through COMSPEC /c (osrunwindows): the file that it makes is the proof
        t.send('echo hi> cmdout.txt', 0.5)
        t.send('\r', 3.0)
        for _ in range(20):
            if os.path.isfile(os.path.join(w, 'cmdout.txt')):
                break
            time.sleep(0.3)
        check(os.path.isfile(os.path.join(w, 'cmdout.txt')), 'command line: the command is run (cmdout.txt is made)', t.text())
        shot(t, 'after-command')
        t.send('\r', 1.0)                             # a pause of the screen of the command, if there is one
        if u8:
            # F5 of a file with a Russian name into the directory newdir, then F8 of the copy: the wide API of the files with the names outside the ANSI page
            t.send('\x1b[H', 0.4)                      # Home: the first entry
            for _ in range(6):                         # .., newdir, the Russian directory, a, cmdout (made above), the Greek name, the Russian name
                t.send('\x1b[B', 0.3)
            t.send('\x1b[15~', 1.0)                   # F5
            shot(t, 'f5-u8')
            t.send('newdir', 0.5)
            t.send('\r', 2.0)
            copied = os.path.join(w, 'newdir', '\u041f\u0440\u0438\u0432\u0435\u0442.txt')
            def copied_text():
                try:
                    return open(copied, encoding='utf-8').read().strip()
                except OSError:
                    return None

            for _ in range(25):                        # the copy takes a moment: wait for the content, not for the name
                if copied_text() == '\u041f\u0440\u0438\u0432\u0435\u0442':
                    break
                time.sleep(0.4)
            tree = '\n'.join(os.path.join(r, n) for r, ds, fs in os.walk(w) for n in ds + fs)
            check(copied_text() == '\u041f\u0440\u0438\u0432\u0435\u0442', 'UTF-8: F5 copies a file with a Russian name', 'content: %r\nthe tree of the work directory:\n%s' % (copied_text(), tree))
        # F5 of a plain file into newdir: the data is the same (a copy sets the final size first: the position of the file must stay at the start)
        t.send('\x1b[H', 0.4)
        for _ in range(3 if u8 else 2):                # .., newdir, [the Russian directory,] a
            t.send('\x1b[B', 0.3)
        t.send('\x1b[15~', 1.0)
        t.send('newdir', 0.5)
        t.send('\r', 2.0)
        plain = os.path.join(w, 'newdir', 'a.txt')

        def plain_text():
            try:
                return open(plain).read().strip()
            except OSError:
                return None

        for _ in range(25):
            if plain_text() == 'first':
                break
            time.sleep(0.4)
        check(plain_text() == 'first', 'F5: a plain file is copied with its data (not after a block of zeros)', 'content: %r\n%s' % (plain_text(), t.text()))
        t.send('\x1bx', 1.0)                          # Alt-X: quit
        t.send('\r', 1.5)
        for _ in range(20):
            if not t.alive():
                break
            time.sleep(0.3)
        check(not t.alive(), 'quit: the program ends')
        t.close()
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print('%d/%d' % (count - fails, count))
    sys.exit(1 if fails else 0)


main()
