#!/usr/bin/env python3
"""Object vs class acceptance gate: click through UI scenarios, compare full cells.

Usage:
  python3 tools/dn-linux-accept.py OBJECT_OUTDIR CLASS_OUTDIR [scenario...]

Compares Screen.cells (glyph, attr), cursor, process status, and dn.err at each
checkpoint. Clock digits in the menu bar are masked. Absolute work path is shared
so panel titles match. See docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md.
"""
from __future__ import annotations

import os
import re
import shutil
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

COLS, ROWS = 100, 30
KEYS = {
    'F1': '\x1bOP', 'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS',
    'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~',
    'F9': '\x1b[20~', 'F10': '\x1b[21~',
    'UP': '\x1b[A', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'LEFT': '\x1b[D',
    'HOME': '\x1b[H', 'END': '\x1b[F', 'PGUP': '\x1b[5~', 'PGDN': '\x1b[6~',
    'INS': '\x1b[2~', 'DEL': '\x1b[3~', 'TAB': '\t', 'ENTER': '\r', 'ESC': '\x1b',
    'BS': '\x7f', 'ALT-X': '\x1bx', 'ALT-F1': '\x1b[1;3P', 'ALT-F7': '\x1b[18;3~',
    'ALT-F10': '\x1b[21;3~', 'CTRL-L': '\x0c', 'CTRL-O': '\x0f', 'CTRL-R': '\x12',
    'CTRL-S': '\x13', 'CTRL-U': '\x15', 'PLUS': '+', 'MINUS': '-', 'STAR': '*',
    'SPACE': ' ',
}

# (name, key-token string, area tag)
# Each starts from a clean DN in the shared work tree after Esc closes About/beta.
SCENARIOS = [
    # Startup / teardown
    ('start', '', 'startup'),
    ('quitask', 'ALT-X', 'startup'),
    ('quit', 'ALT-X ENTER', 'startup'),
    # Function keys / file ops
    ('tab', 'TAB', 'panels'),
    ('f1help', 'F1', 'dialogs'),
    ('f2user', 'F2', 'tools'),
    ('f3view', 'HOME DOWN DOWN F3', 'fileops'),
    ('f4edit', 'HOME DOWN DOWN F4', 'fileops'),
    ('f5copy', 'HOME DOWN DOWN F5', 'fileops'),
    ('f6ren', 'HOME DOWN DOWN F6', 'fileops'),
    ('f7mkdir', 'F7', 'fileops'),
    ('f8del', 'HOME DOWN DOWN F8', 'fileops'),
    ('altf1drive', 'ALT-F1', 'panels'),
    ('altf7find', 'ALT-F7', 'dialogs'),
    ('altf10tree', 'ALT-F10', 'panels'),
    ('ctrll', 'CTRL-L', 'panels'),
    ('ctrlo', 'CTRL-O', 'tools'),
    ('ctrlr', 'CTRL-R', 'panels'),
    ('insert', 'INS INS', 'panels'),
    ('plus', 'PLUS', 'panels'),
    # Top menus (open first item)
    ('menu_file', 'F10 DOWN', 'menus'),
    ('menu_disk', 'F10 RIGHT DOWN', 'menus'),
    ('menu_util', 'F10 RIGHT RIGHT DOWN', 'menus'),
    ('menu_panel', 'F10 RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_mgr', 'F10 RIGHT RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_opt', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_win', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT DOWN', 'menus'),
    # Nested: File → View submenu via Right
    ('menu_file_view_sub', 'F10 DOWN RIGHT', 'menus'),
    # Built-ins via Utilities (indices may drift — still crash/cell probes)
    ('util_calc', 'F10 RIGHT RIGHT DOWN DOWN ENTER ESC ESC', 'tools'),
    ('util_cal', 'F10 RIGHT RIGHT DOWN DOWN DOWN ENTER ESC ESC', 'tools'),
    # Archive enter
    ('arc_zip_enter', 'HOME DOWN ENTER', 'archives'),
    # Cancel path: open copy dialog and Esc
    ('f5_cancel', 'HOME DOWN DOWN F5 ESC ESC', 'fileops'),
]

# Every top-menu cell: menu 0..6 × item 0..17 (F10, Right*m, Down*n, Enter)
for _m in range(7):
    for _n in range(1, 18):
        _keys = 'F10 ' + 'RIGHT ' * _m + 'DOWN ' * _n + 'ENTER'
        SCENARIOS.append(('menu_%d_%d' % (_m, _n), _keys.strip(), 'menus'))



def tokens(spec: str):
    for t in spec.split():
        yield KEYS.get(t, t)


def prep_tree(root: str) -> str:
    """Shared absolute work tree used by both builds."""
    if os.path.isdir(root):
        shutil.rmtree(root)
    w = os.path.join(root, 'work')
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'a.txt'), 'w', encoding='utf-8').write('first file\nsecond line\n')
    open(os.path.join(w, 'b.txt'), 'w', encoding='utf-8').write('other\n')
    open(os.path.join(w, 'c.dat'), 'w', encoding='utf-8').write('1234\n')
    with zipfile.ZipFile(os.path.join(w, 'aaa.zip'), 'w') as zf:
        zf.writestr('inside.txt', 'hello from zip\n')
    return w


def copy_dn(out: str, d: str) -> None:
    for f in os.listdir(out):
        src = os.path.join(out, f)
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(src, d)
        elif f == 'xlt' and os.path.isdir(src):
            shutil.copytree(src, os.path.join(d, 'xlt'))


def snapshot(t: PtyTerm) -> dict:
    cells = []
    for y, row in enumerate(t.screen.cells):
        for x, (ch, attr) in enumerate(row):
            cells.append((y, x, ch, attr))
    return {
        'alive': t.alive(),
        'status': t.status,
        'cursor': (t.screen.x, t.screen.y, t.screen.cursor_visible),
        'cells': cells,
        'text': t.text(),
    }


def mask_volatile(cells, work_path: str):
    """Drop menu-bar clock cells (top-right)."""
    out = []
    for y, x, ch, attr in cells:
        if y == 0 and x >= COLS - 12:
            continue
        out.append((y, x, ch, attr))
    return out


def _digitish(ch) -> bool:
    return ch is not None and len(ch) == 1 and ch in '0123456789:'


def diff_snaps(a: dict, b: dict, work_path: str, limit: int = 12) -> list[str]:
    msgs = []
    if a['alive'] != b['alive'] or a['status'] != b['status']:
        msgs.append('process object alive=%s status=%r vs class alive=%s status=%r'
                    % (a['alive'], a['status'], b['alive'], b['status']))
    if a['cursor'] != b['cursor']:
        msgs.append('cursor object=%r class=%r' % (a['cursor'], b['cursor']))
    ca = {(y, x): (ch, attr) for y, x, ch, attr in mask_volatile(a['cells'], work_path)}
    cb = {(y, x): (ch, attr) for y, x, ch, attr in mask_volatile(b['cells'], work_path)}
    keys = sorted(set(ca) | set(cb))
    n = 0
    skipped_digits = 0
    for k in keys:
        va, vb = ca.get(k), cb.get(k)
        if va == vb:
            continue
        # Environmental counters (free space, timestamps) differ between runs.
        cha = va[0] if va else None
        chb = vb[0] if vb else None
        attra = va[1] if va else None
        attrb = vb[1] if vb else None
        if _digitish(cha) and _digitish(chb) and attra == attrb:
            skipped_digits += 1
            continue
        n += 1
        if len([m for m in msgs if m.startswith('cell')]) < limit:
            msgs.append('cell %s object=%r class=%r' % (k, va, vb))
    if n:
        msgs.insert(0, 'cells differ: %d (ignored %d digit/time cells)'
                    % (n, skipped_digits))
    elif skipped_digits:
        msgs.append('note: ignored %d digit/time cells' % skipped_digits)
    return msgs


def run_one(out: str, work: str, spec: str, label: str) -> tuple[dict, str]:
    d = tempfile.mkdtemp(prefix='dn-accept-%s-' % label)
    err = ''
    t = None
    try:
        copy_dn(out, d)
        t = PtyTerm(['./dn'], COLS, ROWS, cwd=work, exe=os.path.join(d, 'dn'))
        t.pump(1.8, 8)
        # Close About / beta / leftover dialogs; then idle so the command line settles.
        t.send(KEYS['ESC'], 0.5)
        t.send(KEYS['ESC'], 0.4)
        t.pump(0.8, 2)
        for k in tokens(spec):
            if not t.alive():
                break
            t.send(k, 0.4)
        t.pump(0.6, 2)
        snap = snapshot(t)
        err_path = os.path.join(d, 'dn.err')
        if os.path.isfile(err_path):
            err = open(err_path, encoding='utf-8', errors='replace').read()[:400]
        if t.alive():
            t.send(KEYS['ESC'], 0.2)
            t.send(KEYS['ESC'], 0.2)
            t.send(KEYS['ALT-X'], 0.3)
            t.send(KEYS['ENTER'], 0.4)
            try:
                t.close(1.5)
            except Exception:
                pass
        return snap, err
    finally:
        if t is not None and t.alive():
            try:
                os.kill(t.pid, 9)
            except Exception:
                pass
        shutil.rmtree(d, ignore_errors=True)


def main() -> int:
    if len(sys.argv) < 3:
        print('usage: dn-linux-accept.py OBJECT_OUTDIR CLASS_OUTDIR [scenario...]',
              file=sys.stderr)
        return 2
    obj = os.path.abspath(sys.argv[1])
    cls = os.path.abspath(sys.argv[2])
    only = set(sys.argv[3:])
    for path, name in ((obj, 'object'), (cls, 'class')):
        if not os.path.isfile(os.path.join(path, 'dn')):
            print('no dn in', name, path, file=sys.stderr)
            return 2

    # Fixed absolute path so panel titles match between builds.
    root = '/tmp/dn-accept-shared'
    work = prep_tree(root)

    fails = 0
    passed = 0
    for name, spec, area in SCENARIOS:
        if only and name not in only:
            continue
        # Fresh tree each scenario (side effects from prior keys).
        work = prep_tree(root)
        print('SCENARIO', name, '(%s)' % area, flush=True)
        so, eo = run_one(obj, work, spec, 'obj')
        # Reset tree again so class sees the same starting files.
        work = prep_tree(root)
        sc, ec = run_one(cls, work, spec, 'cls')
        problems = []
        if 'Fatal' in so['text'] or 'Access' in so['text']:
            problems.append('object Fatal/Access on screen')
        if 'Fatal' in sc['text'] or 'Access' in sc['text']:
            problems.append('class Fatal/Access on screen')
        if eo:
            problems.append('object dn.err: ' + eo.split('\n')[0][:120])
        if ec:
            problems.append('class dn.err: ' + ec.split('\n')[0][:120])
        problems.extend(diff_snaps(so, sc, work))
        if problems:
            fails += 1
            print('FAIL', name, flush=True)
            for p in problems[:20]:
                print(' ', p, flush=True)
        else:
            passed += 1
            print('PASS', name, flush=True)

    print('SUMMARY pass=%d fail=%d' % (passed, fails), flush=True)
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
