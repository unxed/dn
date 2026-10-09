#!/usr/bin/env python3
"""The scroll bar characters of dn.ini (Linux, a pty, the build with UTF-8 inside): tools/dn-linux-scrollchars.py OUTDIR
VertScrollBarChars / HorizScrollBarChars of the section [Interface] are five characters: the arrow at the start, the arrow at the end, the page area,
the thumb and the bar that has nothing to scroll. They are written as Unicode text (any character; the build for DOS turns them into the bytes of the code page, a missing one becomes its plain sign).
  - the defaults are the glyphs of the file: the arrows, the shades and the block;
  - a dn.ini with other characters changes the vertical bar of the panel (the long list has a page area and a thumb);
  - the old form of the value (the bytes of a code page) is still read (it must not crash and the bar is drawn)."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info, flush=True)


def install(out, ini, files):
    d = tempfile.mkdtemp(prefix='dnscroll-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    for i in range(files):
        open(os.path.join(w, 'file%03d.txt' % i), 'w').write('x')
    if ini is not None:
        open(os.path.join(d, 'dn.ini'), 'wb').write(ini)
    return d, w


def bar(out, ini, files):
    """the column of the vertical scroll bar of the right panel: its characters from the top to the bottom"""
    d, w = install(out, ini, files)
    try:
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
        t.started()
        t.send('\x1b', 0.5)
        rows = t.text().split('\n')
        alive = t.alive()
        t.close(0.3)
        # the panels are 50 columns wide: the bar is the last column of the right panel
        col = [r[99] if len(r) > 99 else ' ' for r in rows[2:26]]
        return ''.join(col), alive, rows
    finally:
        shutil.rmtree(d, ignore_errors=True)


out = os.path.abspath(sys.argv[1])

col, alive, rows = bar(out, None, 0)
check(alive and col.startswith('▲') and '▼' in col, 'defaults: the arrows of the bar are the triangles', repr(col) + '\n    | ' + '\n    | '.join(rows[:6]))
check('▓' in col, 'defaults: a short list has the bar of nothing to scroll (the dark shade)', repr(col))

col, alive, rows = bar(out, b'[Interface]\nVertScrollBarChars=^v:#.\n', 0)
check(alive and col.startswith('^') and 'v' in col and '.' in col, 'dn.ini: ASCII characters, nothing to scroll', repr(col))

col, alive, rows = bar(out, b'[Interface]\nVertScrollBarChars=^v:#.\n', 90)
check(alive and col.startswith('^') and 'v' in col and '#' in col and ':' in col, 'dn.ini: a long list shows the page area and the thumb', repr(col))

# a character that the code page of DOS lacks (the arrows up and down): the UTF-8 build draws it as it is
col, alive, rows = bar(out, '[Interface]\nVertScrollBarChars=\u2191\u2193\u2592\u25a0\u2593\n'.encode('utf-8'), 90)
check(alive and col.startswith('\u2191') and '\u2193' in col and '\u25a0' in col, 'dn.ini: any Unicode characters are drawn (the arrows up and down)', repr(col))

# the old form: the bytes of the code page 866 (the triangles, the shades, the block)
col, alive, rows = bar(out, b'[Interface]\nVertScrollBarChars=\x1e\x1f\xb1\xfe\xb2\n', 90)
check(alive and col.startswith('▲') and '■' in col, 'dn.ini: the old form (bytes of the page) is still read', repr(col))
sys.exit(1 if bad else 0)
