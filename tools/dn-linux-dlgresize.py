#!/usr/bin/env python3
"""The dialogs of the resources are resized with the mouse (Linux, a pty): tools/dn-linux-dlgresize.py OUTDIR
The bottom right corner of the frame is dragged (SGR mouse reports) and the controls must follow (dn/src/dlglayout.pas):
  - Make directory (F7): it grows to the right only (nothing in it stretches down); the input line stretches (its
    history arrow moves with the right edge), the buttons move with the right edge; it cannot be made smaller than it
    was shown;
  - Commands history (Alt-F8): it grows both ways; the list stretches (the end of its scroll bar moves down and right),
    the buttons below it move down."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0


def check(ok, what, scr=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        print('\n'.join('    | ' + l for l in scr.split('\n')[:40]), flush=True)


def box(lines, title):
    """(left, top, right, bottom) of the frame of the dialog with this title, 0-based, or None"""
    for y, l in enumerate(lines):
        if title in l and '╔' in l:
            x0 = l.index('╔')
            x1 = l.index('╗', l.index(title))
            for y1 in range(y + 1, len(lines)):
                if lines[y1][x0:x0 + 1] in ('└', '╚'):
                    return x0, y, x1, y1
    return None


def find(lines, text, top, bottom):
    """(x, y) of the first place of text between the rows top and bottom"""
    for y in range(top, bottom + 1):
        if text in lines[y]:
            return lines[y].index(text), y
    return None


def drag(t, x0, y0, x1, y1):
    """press the left button at (x0, y0), move to (x1, y1), release (0-based cells)"""
    t.send('\x1b[<0;%d;%dM' % (x0 + 1, y0 + 1), 0.3)
    t.send('\x1b[<32;%d;%dM' % ((x0 + x1) // 2 + 1, (y0 + y1) // 2 + 1), 0.3)
    t.send('\x1b[<32;%d;%dM' % (x1 + 1, y1 + 1), 0.3)
    t.send('\x1b[<0;%d;%dm' % (x1 + 1, y1 + 1), 0.8)


out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dndlgresize-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
            shutil.copy(os.path.join(out, f), d)
    w = os.path.join(d, 'work')
    os.makedirs(w)
    open(os.path.join(w, 'a.txt'), 'w').write('a\n')
    os.environ['DNLNG'] = 'ENGLISH'
    os.environ['HOME'] = d
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)

    # Make directory: wider by 10; the height stays
    t.send('\x1b[18~', 1.0)
    scr, lines = t.text(), t.screen.lines()
    b = box(lines, 'Make directory')
    check(b is not None, 'F7: the dialog Make directory is open', scr)
    if b:
        x0, y0, x1, y1 = b
        arrow = find(lines, '▐↓▌', y0, y1)
        ok = find(lines, 'OK', y0 + 1, y1)
        drag(t, x1, y1, x1 + 10, y1 + 3)
        scr, lines = t.text(), t.screen.lines()
        nb = box(lines, 'Make directory')
        check(nb is not None and nb[2] - nb[0] == x1 - x0 + 10, 'F7: the dialog is 10 columns wider', scr)
        check(nb is not None and nb[3] - nb[1] == y1 - y0, 'F7: its height stays (nothing in it stretches down)', scr)
        if nb:
            narrow = find(lines, '▐↓▌', nb[1], nb[3])
            check(arrow is not None and narrow is not None and narrow[0] - nb[0] == arrow[0] - x0 + 10 and narrow[1] - nb[1] == arrow[1] - y0,
                  'F7: the input line stretched (its history arrow moved with the right edge)', scr)
            nok = find(lines, 'OK', nb[1] + 1, nb[3])
            check(ok is not None and nok is not None and nok[0] - nb[0] == ok[0] - x0 + 10, 'F7: the buttons moved with the right edge', scr)
            drag(t, nb[2], nb[3], nb[2] - 25, nb[3] - 2)
            scr, lines = t.text(), t.screen.lines()
            sb = box(lines, 'Make directory')
            check(sb is not None and sb[2] - sb[0] == x1 - x0 and sb[3] - sb[1] == y1 - y0,
                  'F7: it cannot be made smaller than it was shown', scr)
    t.send('\x1b', 0.6)
    check(t.alive() and box(t.screen.lines(), 'Make directory') is None, 'F7: Esc closes the dialog', t.text())

    # Commands history: bigger by 6 columns and 4 rows
    t.send('\x1b[19;3~', 1.0)
    scr, lines = t.text(), t.screen.lines()
    b = box(lines, 'Commands history')
    check(b is not None, 'Alt-F8: the dialog Commands history is open', scr)
    if b:
        x0, y0, x1, y1 = b
        end = find(lines, '▼', y0, y1)
        run = find(lines, 'Run', y0 + 1, y1)
        drag(t, x1, y1, x1 + 6, y1 + 4)
        scr, lines = t.text(), t.screen.lines()
        nb = box(lines, 'Commands history')
        check(nb is not None and nb[2] - nb[0] == x1 - x0 + 6 and nb[3] - nb[1] == y1 - y0 + 4,
              'Alt-F8: the dialog is 6 columns wider and 4 rows taller', scr)
        if nb:
            nend = find(lines, '▼', nb[1], nb[3])
            check(end is not None and nend is not None and nend[0] - nb[0] == end[0] - x0 + 6 and nend[1] - nb[1] == end[1] - y0 + 4,
                  'Alt-F8: the list stretched (the end of its scroll bar moved down and right)', scr)
            nrun = find(lines, 'Run', nb[1] + 1, nb[3])
            check(run is not None and nrun is not None and nrun[1] - nb[1] == run[1] - y0 + 4, 'Alt-F8: the buttons moved down', scr)
    t.send('\x1b', 0.6)
    check(t.alive() and 'Fatal' not in t.text(), 'DN is alive', t.text())
    t.send('\x1bx', 0.8)
finally:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
