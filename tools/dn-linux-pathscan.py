#!/usr/bin/env python3
"""Screens that show paths, on the Linux build (a pty): tools/dn-linux-pathscan.py OUTDIR
A path on a host without drives never shows a drive letter ("C:", "C:\\"), a UNC name or a backslash between names (docs/PATHS.md, stage 8b).
Visits the Info panel, the drive menu, the tree, the find dialog and its results, an archive panel, the copy / move / mkdir dialogs, the
history lists, the user menu and the file attributes; every screen is scanned. Exit status 1 when a screen has such a path."""
import os, re, shutil, sys, tempfile, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

PATH_FORM = re.compile(r'(?<![A-Za-z0-9])[A-Za-z]:\\|\\\\[A-Za-z0-9_.-]+\\|[A-Za-z0-9_.-]\\[A-Za-z0-9_.-]')
DRIVE = re.compile(r'(?<![A-Za-z0-9])[A-Za-z]:(?![A-Za-z0-9/])|\[ [A-Z] [*\s]?\]')
KEYS = {'F2': '\x1bOQ', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F10': '\x1b[21~', 'ESC': '\x1b', 'ENTER': '\r', 'DOWN': '\x1b[B', 'TAB': '\t',
        'ALT-F1': '\x1b[1;3P', 'ALT-F2': '\x1b[1;3Q', 'ALT-F7': '\x1b[18;3~', 'ALT-F8': '\x1b[19;3~', 'ALT-F10': '\x1b[21;3~', 'CTRL-L': '\x0c',
        'CTRL-DOWN': '\x1b[1;5B', 'ALT-E': '\x1be', 'INS': '\x1b[2~', 'ALT-D': '\x1bd', 'ALT-G': '\x1bg', 'CTRL-T': '\x14', 'CTRL-R': '\x12'}
SCEN = [
    ('start', ''), ('info panel', 'CTRL-L', 'Current directory'), ('info panel off', 'CTRL-L'), ('drive menu', 'ALT-F1'), ('drive menu right', 'TAB ALT-F2'),
    ('tree', 'ALT-F10', 'sub'), ('find dialog', 'ALT-F7'), ('copy', 'DOWN F5'), ('move', 'DOWN F6'), ('mkdir', 'F7'), ('user menu', 'F2'),
    ('copy history', 'DOWN F5 CTRL-DOWN'), ('command history', 'ALT-F8'), ('attributes', 'DOWN INS ALT-E'),
    ('disk menu', 'ALT-D'), ('volume label', 'ALT-D ENTER'), ('count length', 'DOWN ALT-G'),
    ('archive panel', 'DOWN DOWN DOWN ENTER', 'dir'), ('archive copy', 'DOWN DOWN DOWN ENTER DOWN F5'),
]


def tok(spec):
    for s in spec.split():
        yield KEYS.get(s, s) if s not in ('RIGHT',) else '\x1b[C'


def main():
    out = os.path.abspath(sys.argv[1])
    bad = 0
    d = tempfile.mkdtemp(prefix='dnpath-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
                src = os.path.join(out, f)
                (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(w, 'sub'))
        open(os.path.join(w, 'a.txt'), 'w').write('x')
        with zipfile.ZipFile(os.path.join(w, 'z.zip'), 'w') as z:
            z.writestr('dir/in.txt', 'inside')
        for name, spec, *want in SCEN:
            t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
            t.pump(1.5, 6)
            t.send('\x1b', 0.5)
            for k in tok(spec):
                t.send(k, 0.5)
            t.pump(0.5, 3)
            text = t.text()
            hit = ''
            for line in text.split('\n'):
                m = PATH_FORM.search(line) or DRIVE.search(line)
                if m:
                    hit = line[max(0, m.start() - 20):m.end() + 20].strip()
                    break
            ok = t.alive() and not hit and 'Fatal Error' not in text and all(x in text for x in want)
            print(('PASS ' if ok else 'FAIL ') + 'no DOS path on the screen: ' + name, flush=True)
            if not ok:
                bad += 1
                print('    | ' + (hit or 'dead') + '\n' + text, flush=True)
            t.close(0.3)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    sys.exit(1 if bad else 0)


main()
