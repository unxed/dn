#!/usr/bin/env python3
"""Runs the Linux build of DN in a pty with a list of keys and shows the screen and DN.ERR: for reproducing a crash.
usage: tools/dn-linux-try.py OUTDIR 'F7 newdir ENTER ...' [--cols N --rows N]   (names as in tools/dn-linux-tour.py; other words are typed)
ARC=1 adds the archives 0arc.zip and 1arc.7z.
The directory `work` (a.txt b.txt c.txt, sub/deep, dst/, big.txt, link.txt, ro.txt) is made in a temp directory, DN starts in it."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm
import importlib.util
spec = importlib.util.spec_from_file_location('tour', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'dn-linux-tour.py'))
KEYS = {'F1': '\x1bOP', 'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~',
        'F8': '\x1b[19~', 'F9': '\x1b[20~', 'F10': '\x1b[21~', 'UP': '\x1b[A', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'LEFT': '\x1b[D',
        'HOME': '\x1b[H', 'END': '\x1b[F', 'PGUP': '\x1b[5~', 'PGDN': '\x1b[6~', 'INS': '\x1b[2~', 'DEL': '\x1b[3~', 'TAB': '\t',
        'ENTER': '\r', 'ESC': '\x1b', 'BS': '\x7f', 'ALT-X': '\x1bx', 'ALT-F1': '\x1b[1;3P', 'ALT-F2': '\x1b[1;3Q',
        'ALT-F7': '\x1b[18;3~', 'ALT-F10': '\x1b[21;3~', 'CTRL-L': '\x0c', 'CTRL-O': '\x0f', 'CTRL-R': '\x12', 'CTRL-S': '\x13',
        'CTRL-U': '\x15', 'ALT-F5': '\x1b[15;3~', 'PLUS': '+', 'MINUS': '-', 'STAR': '*', 'SPACE': ' ', 'CTRL-F1': '\x1b[1;5P',
        'ALT-C': '\x1bc', 'F11': '\x1b[23~', 'F12': '\x1b[24~', 'CTRL-A': '\x01', 'CTRL-K': '\x0b', 'CTRL-Q': '\x11'}


def main():
    out = os.path.abspath(sys.argv[1])
    cols = rows = None
    args = sys.argv[2:]
    keys = args[0].split() if args else []
    cols = int(args[args.index('--cols') + 1]) if '--cols' in args else 100
    rows = int(args[args.index('--rows') + 1]) if '--rows' in args else 30
    d = tempfile.mkdtemp(prefix='dntry-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(w, 'sub', 'deep'))
        os.makedirs(os.path.join(w, 'dst'))
        open(os.path.join(w, 'sub', 'deep', 'x.txt'), 'w').write('deep\n')
        open(os.path.join(w, 'file-ru.txt'), 'w').write('x\n')
        os.symlink('a.txt', os.path.join(w, 'link.txt'))
        if os.environ.get('HUGE'):
            with open(os.path.join(w, 'huge.bin'), 'wb') as h:
                for _ in range(int(os.environ['HUGE'])):
                    h.write(os.urandom(1 << 20))
        open(os.path.join(w, 'ro.txt'), 'w').write('read only\n')
        os.chmod(os.path.join(w, 'ro.txt'), 0o444)
        for n in ('a.txt', 'b.txt', 'c.txt'):
            open(os.path.join(w, n), 'w').write('file ' + n + '\n')
        open(os.path.join(w, 'sub', 'in.txt'), 'w').write('inner\n')
        open(os.path.join(w, 'big.txt'), 'w').write(''.join('line %d of the big file\n' % i for i in range(5000)))
        if os.environ.get('ARC'):      # ARC=1: archives (zip, 7z) of the files of the directory, named 0arc.*: the first files of the panel
            import subprocess
            subprocess.run(['zip', '-q', '0arc.zip', 'a.txt', 'b.txt'], cwd=w)
            subprocess.run(['7z', 'a', '-bd', '-bso0', '1arc.7z', 'a.txt', 'b.txt'], cwd=w)
        t = PtyTerm(['./dn'], cols, rows, cwd=w, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        t.send('\x1b', 0.5)
        for k in keys:
            t.send(KEYS.get(k, k), 0.7)
        t.pump(0.8, 4)
        print(t.text())
        alive = t.alive()
        print('--- alive:', alive, 'status:', t.status)
        for n in ('dn.err', 'dnerr.txt'):
            p = os.path.join(w, n)
            if os.path.exists(p):
                print('--- ' + n); print(open(p, errors='replace').read()[:int(os.environ.get('DN_TRY_ERRMAX', '1500'))])
        if alive:
            t.close(0.5)
        print('--- files:'); 
        for root, ds, fs in os.walk(w):
            for f in fs:
                print(os.path.relpath(os.path.join(root, f), w), os.path.getsize(os.path.join(root, f)))
    finally:
        shutil.rmtree(d, ignore_errors=True)


main()
