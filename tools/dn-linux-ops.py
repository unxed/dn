#!/usr/bin/env python3
"""The file operations of the Linux build of DN in a pty, checked on the file system: make a directory, copy, move, delete, edit and
save a file. usage: tools/dn-linux-ops.py OUTDIR   (OUTDIR: the result of tools/build.sh linux|linux64)"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

F = {'F1': '\x1bOP', 'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~', 'F10': '\x1b[21~',
     'DOWN': '\x1b[B', 'UP': '\x1b[A', 'ENTER': '\r', 'HOME': '\x1b[H', 'END': '\x1b[F', 'ESC': '\x1b', 'ALT-X': '\x1bx', 'TAB': '\t', 'CTRL-R': '\x12', 'INS': '\x1b[2~'}
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


def main():
    out = os.path.abspath(sys.argv[1])
    d = tempfile.mkdtemp(prefix='dnops-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
            elif f == 'XLT':
                shutil.copytree(os.path.join(out, f), os.path.join(d, f))
        w = os.path.join(d, 'work')
        os.makedirs(w)
        open(os.path.join(w, 'a.txt'), 'w').write('first\n')
        open(os.path.join(w, 'b.txt'), 'w').write('other\n')
        open(os.path.join(w, 'c.txt'), 'w').write('third\n')
        payload = os.urandom(3 * 1024 * 1024 + 123)       # more than 64K: the copy buffer (Word was 16 bits)
        open(os.path.join(w, 'z.txt'), 'wb').write(payload)
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        check(b'Error in country' not in t.raw, 'start: no country setup error (XLT next to the program)')
        t.send(F['ESC'], 0.5)

        def key(k, settle=0.6):
            t.send(F.get(k, k), settle)

        # the order of the panel: .., newdir, a, b, c (the default sort is by extension, then by name)
        key('F7'); key('newdir'); key('ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, 'newdir')), 'F7: the directory is made')

        # copy a.txt into newdir: the cursor on a.txt (.., newdir, a.txt; DN puts the cursor on the new directory)
        key('HOME'); key('DOWN'); key('DOWN')
        key('F5'); key('newdir'); key('ENTER', 1.2)
        check(os.path.isfile(os.path.join(w, 'newdir', 'a.txt')) and os.path.isfile(os.path.join(w, 'a.txt')),
              'F5: a.txt is copied into newdir, the original stays', t.text())
        if os.path.isfile(os.path.join(w, 'newdir', 'a.txt')):
            check(open(os.path.join(w, 'newdir', 'a.txt')).read() == 'first\n', 'F5: the copy has the same content')

        # move b.txt into newdir
        key('DOWN')
        key('F6'); key('newdir'); key('ENTER', 1.2)
        check(os.path.isfile(os.path.join(w, 'newdir', 'b.txt')) and not os.path.exists(os.path.join(w, 'b.txt')),
              'F6: b.txt is moved into newdir', t.text())

        # delete c.txt (the cursor is on the next file after the moved one)
        key('F8'); key('ENTER', 1.2)
        gone = not os.path.exists(os.path.join(w, 'c.txt'))
        check(gone, 'F8: the file under the cursor is deleted (c.txt)', t.text())

        # a big file (the last one in the list): the copy must be the same bytes
        key('END')
        key('F5'); key('newdir'); key('ENTER', 2.5)
        got = os.path.join(w, 'newdir', 'z.txt')
        check(os.path.isfile(got) and open(got, 'rb').read() == payload, 'F5: a file of 3 MB is copied byte by byte', t.text())

        # edit a.txt: the cursor on a.txt; F4, a line at the top, F2 saves, Esc leaves
        key('HOME'); key('DOWN'); key('DOWN')
        key('F4', 1.0)
        key('hello ')
        key('F2', 0.8)
        key('ESC', 0.8)
        txt = open(os.path.join(w, 'a.txt')).read() if os.path.exists(os.path.join(w, 'a.txt')) else None
        check(txt is not None and txt.startswith('hello first'), 'F4: the edited text is saved (%r)' % (txt,), t.text())

        # into a directory and back
        key('HOME'); key('DOWN'); key('ENTER', 1.0)
        title = t.text().split('\n')[1]
        check('NEWDIR' in title.upper() and 'a' in t.text().split('\n')[3] + t.text().split('\n')[4],
              'Enter on a directory shows it (the title has newdir)', t.text())
        key('HOME'); key('ENTER', 1.0)
        check('NEWDIR' not in t.text().split('\n')[1].upper(), 'Enter on .. goes back up', t.text())

        # the help, several times: the window of the help is kept between the calls and was used after it was freed
        for _ in range(4):
            key('F1', 1.0)
            for _ in range(6):                       # Esc until the window of the help is gone (a slow machine needs time)
                if '\u2550 Help \u2550' not in t.text():
                    break
                key('ESC', 0.8)
        check(t.alive() and 'Fatal' not in t.text() and 'Name' in t.text() and '\u2550 Help \u2550' not in t.text(), 'F1 and Esc four times: no crash', t.text())

        # Russian names: a directory made by F7 has the name in UTF-8 in the file system and is shown as Russian
        key('F7'); key('\u0442\u0435\u0441\u0442'); key('ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, '\u0442\u0435\u0441\u0442')), 'F7: a Russian name is a UTF-8 name in the file system', t.text())
        check('\u0442\u0435\u0441\u0442' in t.text(), 'the Russian name is shown as Russian', t.text())
        os.makedirs(os.path.join(w, '\u043f\u0430\u043f\u043a\u0430'))
        open(os.path.join(w, '\u043f\u0430\u043f\u043a\u0430', 'x.txt'), 'w').write('x')
        key('HOME'); key('DOWN'); key('ENTER', 1.0); key('HOME'); key('ENTER', 1.0)     # into newdir and back: the directory is read again
        check('\u043f\u0430\u043f\u043a\u0430' in t.text(), 'a directory with a Russian name made outside is shown as Russian', t.text())

        # a long Russian name typed into the dialog: the letters were drawn as other characters (the bytes of "ров", "рка" of CP866 are valid UTF-8)
        key('F7'); key('\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0434\u043b\u0438\u043d\u043d\u044b\u0445 \u0438\u043c\u0451\u043d', 0.8)
        check('\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0434\u043b\u0438\u043d\u043d\u044b\u0445 \u0438\u043c\u0451\u043d' in t.text(), 'the typed Russian text is drawn as typed in the input line', t.text())
        key('ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, '\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0434\u043b\u0438\u043d\u043d\u044b\u0445 \u0438\u043c\u0451\u043d')), 'the directory with the long Russian name is made')

        # Alt-F1, the drive menu, TEMP: (a temporary drive; the panel info was drawn with an empty list: collection error 213)
        key('\x1b[1;3P'); key('DOWN'); key('ENTER', 1.0)
        check('TEMP:' in t.text().split('\n')[1] and t.alive(), 'Alt-F1: the drive TEMP: opens without an error', t.text())

        # a command of the command line: the terminal is given to the shell, Enter returns to DN (it hung before)
        key('echo ran-ok > ran.txt; echo shown-ok'); key('ENTER', 1.5)
        check('shown-ok' in t.text() and 'Press Enter' in t.text(), 'a command: its output is on the screen and DN waits for Enter', t.text())
        key('ENTER', 1.5)
        check(os.path.isfile(os.path.join(w, 'ran.txt')) and open(os.path.join(w, 'ran.txt')).read() == 'ran-ok\n', 'the command was run in the directory of the panel')
        check('Name' in t.text() and t.alive(), 'DN is back with its panels', t.text())

        # the Info panel is on at the end: quitting disposes the windows (TGroup.Done followed a view that had been disposed: Access violation)
        key('\x1b'); key('F10'); [key('\x1b[C', 0.2) for _ in range(5)]; [key('DOWN', 0.2) for _ in range(3)]; key('ENTER', 1.0)
        check(t.alive() and 'Current directory' in t.text(), 'the Info panel is on', t.text())

        key('ALT-X'); key('ENTER', 1.5)
        scr = t.text()
        status = t.close(4)
        check(status == 0, 'Alt-X ends the program (status %r)' % (status,), scr)

        if os.environ.get('DN_OPS_UTF8') == '1':          # the build with -dDNUTF8 (UTF-8 inside): what the legacy build cannot show
            u = os.path.join(d, 'u8')
            os.makedirs(u)
            for n in ('\u042f\u0431\u043b\u043e\u043a\u043e', '\u0430\u0440\u0431\u0443\u0437', '\u0410\u043b\u044c\u0444\u0430', '\u0431\u0435\u0442\u0430', 'Zeta'):
                open(os.path.join(u, n), 'w').write('x')
            open(os.path.join(u, '\u0444\u0430\u0439\u043b.txt'), 'w').write('\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440\nsecond\n')
            t = PtyTerm(['./dn'], 100, 30, cwd=u, exe=os.path.join(d, 'dn'))
            t.pump(1.5, 6)
            t.send(F['ESC'], 0.5)
            lines = [l for l in t.text().split('\n')]
            order = [n for n in ('Zeta', '\u0410\u043b\u044c\u0444\u0430', '\u0430\u0440\u0431\u0443\u0437', '\u0431\u0435\u0442\u0430', '\u042f\u0431\u043b\u043e\u043a\u043e')]
            pos = [next((i for i, l in enumerate(lines) if n in l), -1) for n in order]
            check(all(p >= 0 for p in pos) and pos == sorted(pos), 'UTF-8: the names are sorted ignoring the case (Zeta, \u0410\u043b\u044c\u0444\u0430, \u0430\u0440\u0431\u0443\u0437, \u0431\u0435\u0442\u0430, \u042f\u0431\u043b\u043e\u043a\u043e)', t.text())
            t.send(F['END'], 0.5)
            t.send(F['F3'], 1.2)
            check('\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440' in t.text(), 'UTF-8: F3 shows a Russian text file', t.text())
            t.send(F['ESC'], 0.5)
            t.send(F['ALT-X'], 0.8)
            t.send(F['ENTER'], 1.0)
            t.close(3)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
    sys.exit(1 if fails else 0)


main()
