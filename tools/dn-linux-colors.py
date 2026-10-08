#!/usr/bin/env python3
"""The colors of the active elements (Linux, a pty): tools/dn-linux-colors.py OUTDIR
The rule (PLAN.md, the problems of the 2.20 alpha, item 3): an active (selected) element is white on teal (the attribute 3F), like the path in the title
of the active panel and the selected button. The screen of the terminal program (tools/pty_screen.py) keeps the colors of every cell, so they are checked:
  - the title of the active panel and the selected day of the calendar have the same colors;
  - today's date when it is the selected one is blue on teal (31), not black on dark gray (80; the unreadable 89 on a gray selection before);
  - no cell of the calendar shows black on dark gray (an unreadable pair)."""
import datetime, os, re, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0
TEAL_WHITE = (('i', 15), ('i', 6))          # 3F
TEAL_BLUE = (('i', 4), ('i', 6))             # 31 (the ANSI index of the DOS blue is 4)
DULL = (('i', 0), ('i', 8))                  # 80


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dncolors-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    return d, w


def pair(t, y, x):
    a = t.screen.cells[y][x][1]
    return (a[0], a[1]) if a else None


def day_cell(t, day):
    """(row, column) of the first digit of the day in the table of the calendar"""
    lines = t.text().split('\n')
    head = [y for y, l in enumerate(lines) if re.search(r'Su\s+Mo\s+Tu', l)]
    if not head:
        return None
    for y in range(head[0] + 1, head[0] + 8):
        for m in re.finditer(r'(?<!\d)(\d{1,2})(?!\d)', lines[y]):
            if int(m.group(1)) == day and y < len(lines) and '/' not in lines[y][m.end():m.end() + 2]:
                return y, m.start()
    return None


out = os.path.abspath(sys.argv[1])
d, w = install(out)
try:
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    rows = t.text().split('\n')
    # the title of the active panel: the path on the top border (white on teal)
    p = [pair(t, 1, x) for x in range(1, 99) if t.screen.cells[1][x][0] == '/']
    check(TEAL_WHITE in p, 'the path in the title of the active panel is white on teal (3F)', repr(set(p)))
    t.send('\x1bu', 0.5)                                # Utilities
    t.send('n', 0.8)                                    # Calendar
    check('Calendar' in t.text(), 'the calendar opens (Utilities, Calendar)', t.text())
    today = datetime.date.today()
    cell = day_cell(t, today.day)
    check(cell is not None, 'the calendar shows today (%d)' % today.day, t.text())
    if cell:
        y, x = cell
        check(pair(t, y, x) == TEAL_BLUE, 'today when it is the selected day: blue on teal (31)', repr(pair(t, y, x)))
        step = -1 if today.day > 1 else 1               # the other day of the same month
        t.send('\x1b[D' if step < 0 else '\x1b[C', 0.5)
        other = day_cell(t, today.day + step)
        if other:
            check(pair(t, *other) == TEAL_WHITE, 'the selected day is white on teal (3F)', repr(pair(t, *other)))
        else:
            check(False, 'the neighbour day is shown', t.text())
        check(pair(t, y, x) != DULL, 'today when it is not the selected day is not black on dark gray (80)', repr(pair(t, y, x)))
    box = [(yy, xx) for yy in range(7, 18) for xx in range(20, 70) if t.screen.cells[yy][xx][0].strip() and pair(t, yy, xx) == DULL]
    check(not box, 'no cell of the calendar is black on dark gray (80)', repr(box[:5]))
    t.send('\x1b', 0.3)
    t.close(0.3)
finally:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
