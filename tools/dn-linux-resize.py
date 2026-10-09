#!/usr/bin/env python3
"""The terminal changes its size while DN runs (SIGWINCH): tools/dn-linux-resize.py OUTDIR
DN starts at 100x30; the terminal becomes 80x25, then 120x40, then 100x30 again. After each change: DN is alive, the menu bar is in the first row, the key bar (F1 Help ...) is
in the last row, the two panels have their frames at the new size (the right corner of the right panel is in the last column), no Fatal on the screen."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

bad = 0


def check(ok, what, scr=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        print('\n'.join('    | ' + l for l in scr.split('\n')[:40]), flush=True)


def settle(t, cols, rows):
    t.resize(cols, rows)
    t.pump(0.4, 2)
    t.until(lambda: 'F1 Help' in t.screen.lines()[rows - 1], 22)
    return t.text()


out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dnresize-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
            shutil.copy(os.path.join(out, f), d)
    w = os.path.join(d, 'work')
    os.makedirs(w)
    open(os.path.join(w, 'a.txt'), 'w').write('a\n')
    os.environ['DNLNG'] = 'ENGLISH'
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
    t.started()
    t.send('\x1b', 0.5)
    for cols, rows in ((80, 25), (120, 40), (100, 30)):
        scr = settle(t, cols, rows)
        name = '%dx%d' % (cols, rows)
        lines = t.screen.lines()
        check(t.alive(), name + ': DN is alive', scr)
        check('Fatal' not in scr and 'Access' not in scr, name + ': no Fatal', scr)
        check('File' in lines[0] and 'Window' in lines[0], name + ': the menu bar is in the first row', scr)
        check('F1 Help' in lines[rows - 1], name + ': the key bar is in the last row', scr)
        check(lines[rows - 1].rstrip().endswith('Menu'), name + ': the key bar is cut at the new width, not wider', scr)
        check(len(lines) == rows and all(len(l.rstrip()) <= cols for l in lines), name + ': nothing is drawn outside the screen', scr)
        panels = [l for l in lines[1:rows - 3] if l.strip()]
        check(bool(panels) and len(panels[0].rstrip()) == cols and panels[0].rstrip()[-1] in '╗┐',
              name + ': the frame of the right panel reaches the last column (%d)' % cols, scr)
    t.send('\x1bx', 0.8)
finally:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
