#!/usr/bin/env python3
"""The file operations of the Linux build of DN in a pty, checked on the file system: make a directory, copy, move, delete, edit and
save a file. usage: tools/dn-linux-ops.py OUTDIR   (OUTDIR: the result of tools/dn-linux.sh)"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

F = {'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~',
     'DOWN': '\x1b[B', 'UP': '\x1b[A', 'ENTER': '\r', 'HOME': '\x1b[H', 'ESC': '\x1b', 'ALT-X': '\x1bx', 'TAB': '\t', 'INS': '\x1b[2~'}
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
        w = os.path.join(d, 'work')
        os.makedirs(w)
        open(os.path.join(w, 'a.txt'), 'w').write('first\n')
        open(os.path.join(w, 'b.txt'), 'w').write('other\n')
        open(os.path.join(w, 'c.txt'), 'w').write('third\n')
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
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

        # edit a.txt: the cursor on a.txt; F4, a line at the top, F2 saves, Esc leaves
        key('HOME'); key('DOWN'); key('DOWN')
        key('F4', 1.0)
        key('hello ')
        key('F2', 0.8)
        key('ESC', 0.8)
        txt = open(os.path.join(w, 'a.txt')).read() if os.path.exists(os.path.join(w, 'a.txt')) else None
        check(txt is not None and txt.startswith('hello first'), 'F4: the edited text is saved (%r)' % (txt,), t.text())

        key('ALT-X'); key('ENTER', 0.8)
        status = t.close(2)
        check(status == 0, 'Alt-X ends the program (status %r)' % (status,))
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
    sys.exit(1 if fails else 0)


main()
