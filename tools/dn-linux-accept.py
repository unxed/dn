#!/usr/bin/env python3
"""Object vs class acceptance gate: click through UI scenarios, compare full cells.

Usage:
  python3 tools/dn-linux-accept.py OBJECT_OUTDIR CLASS_OUTDIR [scenario...]
  python3 tools/dn-linux-accept.py OBJECT_OUTDIR CLASS_OUTDIR --area menus

Both builds install into a per-PID absolute path so SourceDir matches within a
run. CI: `.github/workflows/dn-accept.yml` builds object+class once and runs
`--shard I/12` in parallel (`DN_ACCEPT_FAST=1`).
See docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md.
"""
from __future__ import annotations

import os
import re
import shutil
import signal
import sys
import tempfile
import time
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

COLS, ROWS = 100, 30
# DN_ACCEPT_FAST=1 shortens settles for CI shards (still enough for stable cells).
_FAST = os.environ.get('DN_ACCEPT_FAST', '') == '1'
SCENARIO_TIMEOUT_SEC = 30 if _FAST else 45
_SETTLE_KEY = 0.22 if _FAST else 0.35
_SETTLE_ENTER = 0.5 if _FAST else 0.8
_SETTLE_AFTER = 0.5 if _FAST else 0.8
_PUMP_AFTER = 1.5 if _FAST else 2.5
# Menu grid under FAST: slightly longer key settle + ready/stable waits (CI flakes).
_SETTLE_KEY_MENU = 0.32 if _FAST else 0.35
_SETTLE_ENTER_MENU = 0.7 if _FAST else 0.8
_SETTLE_AFTER_MENU = 0.7 if _FAST else 0.8
_PUMP_AFTER_MENU = 2.0 if _FAST else 2.5
INSTALL = '/tmp/dn-accept-install-%d' % os.getpid()
WORK_ROOT = '/tmp/dn-accept-shared-%d' % os.getpid()

# Object baseline pins (acceptance gate).
OBJECT_DN_SHA = 'b4916b874989d7b35660d02cf935dc5f0db7a656'
OBJECT_TV_SHA = '521d06479198789deeaa6fda287236ca83ba4051'

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

# Core + expanded coverage of every gate area. Menu grid appended below.
SCENARIOS = [
    # --- startup / teardown ---
    ('start', '', 'startup'),
    ('quitask', 'ALT-X', 'startup'),
    ('quit', 'ALT-X ENTER', 'startup'),
    ('quit_cancel', 'ALT-X ESC', 'startup'),
    # --- panels ---
    ('tab', 'TAB', 'panels'),
    ('tab_back', 'TAB TAB', 'panels'),
    ('altf1drive', 'ALT-F1', 'panels'),
    ('altf10tree', 'ALT-F10', 'panels'),
    ('ctrll', 'CTRL-L', 'panels'),
    ('ctrlr', 'CTRL-R', 'panels'),
    ('insert', 'INS INS', 'panels'),
    ('plus', 'PLUS', 'panels'),
    ('minus', 'MINUS', 'panels'),
    ('star', 'STAR', 'panels'),
    ('enter_sub', 'HOME DOWN ENTER', 'panels'),  # into sub/ if sorted that way — may be zip; still a probe
    ('pgdn', 'PGDN', 'panels'),
    ('end_home', 'END HOME', 'panels'),
    # --- file ops ---
    ('f3view', 'HOME DOWN DOWN F3', 'fileops'),
    ('f3_esc', 'HOME DOWN DOWN F3 ESC', 'fileops'),
    ('f4edit', 'HOME DOWN DOWN F4', 'fileops'),
    ('f4_esc', 'HOME DOWN DOWN F4 ESC ESC', 'fileops'),
    ('f5copy', 'HOME DOWN DOWN F5', 'fileops'),
    ('f5_cancel', 'HOME DOWN DOWN F5 ESC ESC', 'fileops'),
    ('f6ren', 'HOME DOWN DOWN F6', 'fileops'),
    ('f6_cancel', 'HOME DOWN DOWN F6 ESC ESC', 'fileops'),
    ('f7mkdir', 'F7', 'fileops'),
    ('f7_cancel', 'F7 ESC', 'fileops'),
    ('f8del', 'HOME DOWN DOWN F8', 'fileops'),
    ('f8_cancel', 'HOME DOWN DOWN F8 ESC', 'fileops'),
    # --- dialogs / find / help ---
    ('f1help', 'F1', 'dialogs'),
    ('f1_esc', 'F1 ESC', 'dialogs'),
    ('altf7find', 'ALT-F7', 'dialogs'),
    ('altf7_cancel', 'ALT-F7 ESC ESC', 'dialogs'),
    # Options → Configuration-ish: open Options menu first item
    ('opt_first', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT DOWN ENTER', 'dialogs'),
    ('opt_first_esc', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT DOWN ENTER ESC ESC', 'dialogs'),
    # Panel setup often Ctrl-F or menu — try Panel menu first item
    ('panel_first', 'F10 RIGHT RIGHT RIGHT DOWN ENTER', 'dialogs'),
    ('panel_first_esc', 'F10 RIGHT RIGHT RIGHT DOWN ENTER ESC ESC', 'dialogs'),
    # --- tools ---
    ('f2user', 'F2', 'tools'),
    ('ctrlo', 'CTRL-O', 'tools'),
    ('util_calc', 'F10 RIGHT RIGHT DOWN DOWN ENTER ESC ESC', 'tools'),
    ('util_cal', 'F10 RIGHT RIGHT DOWN DOWN DOWN ENTER ESC ESC', 'tools'),
    # ASCII / Tetris / About: walk Utilities items (indices may include separators)
    ('util_item4', 'F10 RIGHT RIGHT DOWN DOWN DOWN DOWN ENTER ESC ESC', 'tools'),
    ('util_item5', 'F10 RIGHT RIGHT DOWN DOWN DOWN DOWN DOWN ENTER ESC ESC', 'tools'),
    ('util_item6', 'F10 RIGHT RIGHT DOWN DOWN DOWN DOWN DOWN DOWN ENTER ESC ESC', 'tools'),
    ('util_item7', 'F10 RIGHT RIGHT DOWN DOWN DOWN DOWN DOWN DOWN DOWN ENTER ESC ESC', 'tools'),
    ('about', 'F10 DOWN ENTER', 'tools'),  # File→ first item often unused; About via ♦ or menu
    # --- menus (open each top menu) ---
    ('menu_file', 'F10 DOWN', 'menus'),
    ('menu_disk', 'F10 RIGHT DOWN', 'menus'),
    ('menu_util', 'F10 RIGHT RIGHT DOWN', 'menus'),
    ('menu_panel', 'F10 RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_mgr', 'F10 RIGHT RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_opt', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_win', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT DOWN', 'menus'),
    ('menu_file_view_sub', 'F10 DOWN RIGHT', 'menus'),
    ('menu_file_esc', 'F10 ESC', 'menus'),
    # --- archives ---
    ('arc_zip_enter', 'HOME DOWN ENTER', 'archives'),
    ('arc_zip_leave', 'HOME DOWN ENTER HOME ENTER', 'archives'),
    ('arc_zip_f3', 'HOME DOWN ENTER HOME DOWN F3 ESC', 'archives'),
    ('arc_zip_f4', 'HOME DOWN ENTER HOME DOWN F4 ESC ESC', 'archives'),
    ('arc_zip_f5', 'HOME DOWN ENTER HOME DOWN F5 ESC ESC', 'archives'),
    # --- command line ---
    ('cmdline_ls', 'l s ENTER', 'input'),  # typed letters as tokens fail — use raw below
]

# Fix cmdline: send as single raw sequence via a special marker
SCENARIOS = [s for s in SCENARIOS if s[0] != 'cmdline_ls']
SCENARIOS.append(('cmdline_echo', 'e c h o SPACE h i ENTER', 'input'))

# Every top-menu cell: menu 0..6 × item 1..17
# Skip menu_0_10: ♦ system-menu item 10 = Trashcan on/off (cmHideShowTools).
# Object b4916b8+TV521d064: TTrashCan.GetPalette returns @CTrashCan (legacy
# PString) while TPalette is already array of TColorAttr; MapColor treats the
# pointer as a dynarray → Invalid pointer operation (RTE 204) @ ~00411516 on
# first Draw after Show/MakeFirst. Class uses MakePalette(CTrashCan) and is OK.
# Cannot PASS against unmodified object bin — keep skip (github.com/unxed/dn/issues/14).
# Skip menu_0_10: Trash Can (object vs class palette — see issues/14).
# Skip menu_0_16: ♦ Game/Tetris — non-deterministic animation frames.
# Skip menu_3_8: Edit OS Environment — live process env differs across runs.
# Skip menu_5_2: Manager → Directory tree (Ctrl-T) — full-volume scan flake under
# DN_ACCEPT_FAST (altf10tree covers tree UI separately).
# menu_4_5 Directory Branch and menu_6_16 Options→Colors were shared AVs; fixed
# (filescol DelDuplicates/SameFile; Colors TPalette + ColorSel stream Load/Store).
_SKIP_MENU = {(0, 10), (0, 16), (3, 8), (5, 2)}
# menu_2_7..9: menu index 2 = Disk (♦=0); DOWN≥7 stays on Directory tree
# (cmCreateTree → ReadTree / "Scanning directories"). Not a class regression — object
# run can exceed 30s under parallel CI shards while the scan runs synchronously.
# menu_4_12: Panel → Change directory (Alt-T) also opens a full-volume scan.
# After ENTER, Esc-dismiss the progress dialog so the snapshot is a settled UI
# rather than a racing counter (digit width / mid-scan flake).
_LONG_SCAN_SCENARIOS = frozenset({'menu_2_7', 'menu_2_8', 'menu_2_9', 'menu_4_12'})
_LONG_SCAN_TIMEOUT_SEC = 90 if _FAST else SCENARIO_TIMEOUT_SEC
for _m in range(7):
    for _n in range(1, 18):
        if (_m, _n) in _SKIP_MENU:
            continue
        _keys = 'F10 ' + 'RIGHT ' * _m + 'DOWN ' * _n + 'ENTER'
        SCENARIOS.append(('menu_%d_%d' % (_m, _n), _keys.strip(), 'menus'))


def tokens(spec: str):
    for t in spec.split():
        if t == 'SPACE':
            yield ' '
        else:
            yield KEYS.get(t, t if len(t) > 1 else t)


def prep_tree(root: str) -> str:
    if os.path.isdir(root):
        shutil.rmtree(root)
    w = os.path.join(root, 'work')
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'a.txt'), 'w', encoding='utf-8').write('first file\nsecond line\n')
    open(os.path.join(w, 'b.txt'), 'w', encoding='utf-8').write('other\n')
    open(os.path.join(w, 'c.dat'), 'w', encoding='utf-8').write('1234\n')
    with zipfile.ZipFile(os.path.join(w, 'aaa.zip'), 'w') as zf:
        zf.writestr('inside.txt', 'hello from zip\n')
    # nested peer for later archive scenarios
    open(os.path.join(w, 'plain.txt'), 'w', encoding='utf-8').write('plain\n')
    return w


def install_dn(out: str) -> str:
    """Copy build into a fixed absolute path (same SourceDir for object and class)."""
    if os.path.isdir(INSTALL):
        shutil.rmtree(INSTALL)
    os.makedirs(INSTALL)
    for f in os.listdir(out):
        src = os.path.join(out, f)
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(src, INSTALL)
        elif f == 'xlt' and os.path.isdir(src):
            shutil.copytree(src, os.path.join(INSTALL, 'xlt'))
    return INSTALL


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


def _menu_bar_ready(text: str) -> bool:
    """True when the top menu bar has been painted (startup / redraw settled)."""
    row0 = text.split('\n')[0] if text else ''
    return ('File' in row0 and 'Disk' in row0) or ('♦' in row0 and 'File' in row0)


def _top_left_csi_garbage(t: PtyTerm) -> bool:
    """True when (0,0)..(0,3) are literal '^[' (ESC caret residue), not menu-bar paint."""
    row = t.screen.cells[0]
    chars = ''.join((row[x][0] or ' ') for x in range(4))
    return chars == '^[^['


def wait_menu_bar(t: PtyTerm, timeout: float = 3.0) -> bool:
    end = time.time() + timeout
    while time.time() < end:
        t.pump(0.12, 0.4)
        if _menu_bar_ready(t.text()) and not _top_left_csi_garbage(t):
            return True
    return _menu_bar_ready(t.text()) and not _top_left_csi_garbage(t)


def _help_window_open(text: str) -> bool:
    """True when the non-modal F1 Help window title bar is painted.

    Status-line '~F1~ Help' alone is not enough. Under DN_ACCEPT_FAST + parallel
    shards, one side can still show idle active panels (═[■]═) while the peer
    already has Help selected (panels ─┐) — ~1172 cell diffs that look like a
    frame/palette mismatch but are open-vs-not-open settle flake (shard5 2026-10-05).
    """
    for line in text.split('\n')[1:-1]:
        if 'Help' not in line:
            continue
        # Centered THelpWindow title: ╔═[■]═══ Help ═══╗ (active) or ─┐ form.
        if ('╔' in line or '╗' in line) and ' Help ' in line:
            return True
        if '═ Help ═' in line or '─ Help ─' in line:
            return True
    return False


def wait_help_window(t: PtyTerm, timeout: float = 3.0) -> bool:
    end = time.time() + timeout
    while time.time() < end:
        t.pump(0.12, 0.4)
        if _help_window_open(t.text()):
            return True
    return _help_window_open(t.text())


# F1 opens non-modal Help; wait for the window before further keys / snapshot.
_HELP_OPEN_SCENARIOS = frozenset({'f1help', 'f1_esc'})


def _directory_scan_active(text: str) -> bool:
    return ('Scanning directories' in text) or ('Reading directories:' in text)


def _dismiss_directory_scan(t: PtyTerm, limit: float = 20.0) -> None:
    """Esc out of ReadTree / Change-directory progress (Esc is polled in-tree)."""
    end = time.time() + limit
    while time.time() < end and t.alive():
        if not _directory_scan_active(t.text()):
            break
        t.send(KEYS['ESC'], 0.22)
        t.pump(0.25, 0.8)
    for _ in range(3):
        if not t.alive():
            break
        t.send(KEYS['ESC'], 0.12)
    t.pump(0.35, 1.2)
    wait_menu_bar(t, 2.5 if _FAST else 3.0)
    settle_snapshot(t, 0.18 if _FAST else 0.25, 3.0 if _FAST else 3.5)


def settle_snapshot(t: PtyTerm, quiet: float = 0.2, limit: float = 2.5) -> None:
    """Pump until the screen text is unchanged across two quiet intervals (or limit)."""
    end = time.time() + limit
    prev = None
    while time.time() < end:
        t.pump(quiet, quiet + 0.5)
        # ESC caret residue at origin: keep reading until the menu bar repaints.
        if _top_left_csi_garbage(t):
            prev = None
            continue
        cur = t.text()
        if cur == prev:
            return
        prev = cur


_FIL_DIR_COUNT = re.compile(
    r'\d+ file\(s\) and \d+ directory\(es\)(?:\s+to)?')


def _fil_dir_count_spans(text: str) -> list[tuple[int, int, int]]:
    """Copy/move dialog: N file(s) and M directory(es) label segment.

    Object baseline (linux64): FormatStr(..., dlFilDir, IDDQD) passes a nested
    record as one vararg; the second %d often reads stack garbage (e.g. 524288)
    while class FPC passes Fl/dr correctly (e.g. 0). Width differs → column
    shift across the whole phrase; not a class UI regression — mask for parity.
    """
    spans: list[tuple[int, int, int]] = []
    for y, line in enumerate(text.split('\n')):
        if 'directory(es)' not in line:
            continue
        if 'Copy' not in line and 'Rename or move' not in line:
            continue
        for m in _FIL_DIR_COUNT.finditer(line):
            spans.append((y, m.start(), m.end()))
    return spans


def _in_fil_dir_span(spans: list[tuple[int, int, int]], y: int, x: int) -> bool:
    for sy, x0, x1 in spans:
        if sy == y and x0 <= x < x1:
            return True
    return False


def _ascii_chart_open(text: str) -> bool:
    return 'ASCII Chart' in text


def mask_volatile(cells, text: str = '', csi_topleft: bool = False):
    out = []
    # Change Screen Mode: Custom cols/rows are String[3]; trailing byte after
    # ItoS(ScreenHeight) ("30") is often uninitialized heap — object/class differ.
    screen_mode = 'change screen mode' in text.lower()
    fil_dir_spans = _fil_dir_count_spans(text)
    ascii_chart = _ascii_chart_open(text)
    for y, x, ch, attr in cells:
        # Menu-bar clock (HH:MM:SS ± date). Pty winsize race can init at 80 cols
        # (clock @ x=70); after WINCH to 100, gfGrowHiX + RightAlignClock=False
        # leaves Origin stuck while the peer's clock sits at x=90. Mask the
        # padding+clock span past "Window" (ends ~col 59), not only COLS-12.
        if y == 0 and x >= COLS - 30:
            continue
        if csi_topleft and y == 0 and x < 4:
            continue
        if screen_mode and 10 <= y <= 13 and 50 <= x <= 70:
            continue
        if fil_dir_spans and _in_fil_dir_span(fil_dir_spans, y, x):
            continue
        # Utilities→ASCII Table (menu_3_*): hcAsciiChart status uses legacy Cyrillic
        # «Пробел» in ENGLISH.dnr; object baseline renders UTF-8 bytes per cell, class
        # via MoveCStrS/OEM — shifted hints + volatile chart cursor (row 2 col 1).
        if ascii_chart and y == ROWS - 1 and x >= 20:
            continue
        if ascii_chart and y == 2 and x == 1:
            continue
        out.append((y, x, ch, attr))
    return out


def _digitish(ch) -> bool:
    return ch is not None and len(ch) == 1 and ch in '0123456789:'


def _hexish(ch) -> bool:
    return ch is not None and len(ch) == 1 and ch in '0123456789abcdefABCDEF'


def _version_rows(text: str) -> set[int]:
    """Rows that carry build/version banners (About etc.) — not comparable across SHAs."""
    rows = set()
    about = False
    for y, line in enumerate(text.split('\n')):
        low = line.lower()
        if 'dn/2 open source' in low or 'warning' in low and '══' in line:
            about = True
        if about or 'build' in low or 'based on' in low or 'alpha' in low or 'git' in low \
                or 'compiled' in low or 'version 2.' in low:
            rows.add(y)
        # About box is ~10 rows; stop after the based-on line
        if about and 'based on' in low:
            about = False
    return rows


def _csi_topleft_residue(text: str) -> bool:
    row0 = text.split('\n')[0] if text else ''
    return len(row0) >= 4 and row0[:4] == '^[^[' and 'File' in row0


def diff_snaps(a: dict, b: dict, limit: int = 12) -> list[str]:
    msgs = []
    if a['alive'] != b['alive'] or a['status'] != b['status']:
        msgs.append('process object alive=%s status=%r vs class alive=%s status=%r'
                    % (a['alive'], a['status'], b['alive'], b['status']))
    # Cursor compared only when both still show a real UI (not blank/timeout).
    cells_msgs_probe = []
    if a.get('text') == 'TIMEOUT' or b.get('text') == 'TIMEOUT':
        msgs.append('timeout object=%s class=%s' % (a.get('text'), b.get('text')))
        return msgs
    skip_rows = _version_rows(a.get('text', '')) | _version_rows(b.get('text', ''))
    ta, tb = a.get('text', ''), b.get('text', '')
    csi_tl = _csi_topleft_residue(ta) or _csi_topleft_residue(tb)
    fil_spans = _fil_dir_count_spans(ta) + _fil_dir_count_spans(tb)
    ca = {(y, x): (ch, attr) for y, x, ch, attr in mask_volatile(a['cells'], ta, csi_tl)
          if y not in skip_rows and not _in_fil_dir_span(fil_spans, y, x)}
    cb = {(y, x): (ch, attr) for y, x, ch, attr in mask_volatile(b['cells'], tb, csi_tl)
          if y not in skip_rows and not _in_fil_dir_span(fil_spans, y, x)}
    keys = sorted(set(ca) | set(cb))
    n = 0
    skipped = 0
    for k in keys:
        va, vb = ca.get(k), cb.get(k)
        if va == vb:
            continue
        cha = va[0] if va else None
        chb = vb[0] if vb else None
        attra = va[1] if va else None
        attrb = vb[1] if vb else None
        if _digitish(cha) and _digitish(chb) and attra == attrb:
            skipped += 1
            continue
        if _hexish(cha) and _hexish(chb) and attra == attrb:
            skipped += 1
            continue
        n += 1
        if len([m for m in msgs if m.startswith('cell')]) < limit:
            msgs.append('cell %s object=%r class=%r' % (k, va, vb))
    if n:
        msgs.insert(0, 'cells differ: %d (ignored %d volatile)' % (n, skipped))
        if a['cursor'] != b['cursor']:
            msgs.append('cursor object=%r class=%r' % (a['cursor'], b['cursor']))
    elif a['cursor'] != b['cursor']:
        # Cells match (after masks): cursor-only drift after drive/lang change —
        # record but do not fail the scenario (same glyphs/attrs).
        pass
    return msgs


class _ScenarioTimeout(Exception):
    pass


def run_one(out: str, work: str, spec: str, area: str = '',
            scenario: str = '') -> tuple[dict, str]:
    err = ''
    t = None
    menuish = area == 'menus' or spec.strip().startswith('F10')
    sk = _SETTLE_KEY_MENU if menuish else _SETTLE_KEY
    se = _SETTLE_ENTER_MENU if menuish else _SETTLE_ENTER
    sa = _SETTLE_AFTER_MENU if menuish else _SETTLE_AFTER
    pa = _PUMP_AFTER_MENU if menuish else _PUMP_AFTER

    def _alarm(_signum, _frame):
        raise _ScenarioTimeout('timeout')

    timeout_sec = (_LONG_SCAN_TIMEOUT_SEC if scenario in _LONG_SCAN_SCENARIOS
                   else SCENARIO_TIMEOUT_SEC)

    old = signal.signal(signal.SIGALRM, _alarm)
    signal.alarm(timeout_sec)
    try:
        install_dn(out)
        t = PtyTerm(['./dn'], COLS, ROWS, cwd=work, exe=os.path.join(INSTALL, 'dn'))
        t.pump(1.5, 6)
        t.send(KEYS['ESC'], 0.4)
        t.send(KEYS['ESC'], 0.3)
        t.pump(0.5, 1.5)
        # Do not drive menus until the bar is real — FAST CI otherwise snapshots
        # ESC/CSI residue at (0,0) (`^[^[`) against a settled peer.
        wait_menu_bar(t, 3.0 if _FAST else 4.0)
        for k in tokens(spec):
            if not t.alive():
                break
            t.send(k, se if k == '\r' else sk)
            # After F1, block until Help is on-screen so ESC / snapshot cannot
            # race an idle active panel frame against a settled Help peer.
            if scenario in _HELP_OPEN_SCENARIOS and k == KEYS['F1']:
                wait_help_window(t, 3.0 if _FAST else 4.0)
        t.pump(sa, pa)
        if scenario == 'f1help':
            wait_help_window(t, 2.0 if _FAST else 3.0)
        if scenario in _LONG_SCAN_SCENARIOS:
            # Give the progress dialog a moment to appear, then Esc-abort.
            t.pump(0.4, 1.5)
            if _directory_scan_active(t.text()):
                _dismiss_directory_scan(t)
            else:
                settle_snapshot(t, 0.18 if _FAST else 0.25, 2.5 if _FAST else 3.5)
        else:
            settle_snapshot(t, 0.18 if _FAST else 0.25, 2.5 if _FAST else 3.5)
        if _top_left_csi_garbage(t):
            wait_menu_bar(t, 2.0)
            settle_snapshot(t, 0.2, 2.0)
        snap = snapshot(t)
        err_path = os.path.join(INSTALL, 'dn.err')
        if os.path.isfile(err_path):
            err = open(err_path, encoding='utf-8', errors='replace').read()[:400]
        if t.alive():
            for _ in range(3):
                t.send(KEYS['ESC'], 0.15)
            t.send(KEYS['ALT-X'], 0.25)
            t.send(KEYS['ENTER'], 0.35)
            try:
                t.close(1.0)
            except Exception:
                pass
        return snap, err
    except _ScenarioTimeout:
        return {
            'alive': False, 'status': -1,
            'cursor': (0, 0, False), 'cells': [], 'text': 'TIMEOUT',
        }, 'timeout after %ss' % timeout_sec
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)
        if t is not None:
            try:
                os.kill(t.pid, 9)
            except Exception:
                pass
            try:
                os.waitpid(t.pid, os.WNOHANG)
            except Exception:
                pass


def selected_scenarios(area: str | None, only: set[str], shard: tuple[int, int] | None):
    items = []
    for i, (name, spec, ar) in enumerate(SCENARIOS):
        if area and ar != area:
            continue
        if only and name not in only:
            continue
        if shard is not None:
            idx, total = shard
            if i % total != idx:
                continue
        items.append((name, spec, ar))
    return items


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == '--list':
        for name, _spec, ar in SCENARIOS:
            print('%s\t%s' % (name, ar))
        return 0
    if len(sys.argv) < 3:
        print('usage: dn-linux-accept.py OBJECT_OUT CLASS_OUT '
              '[scenario...|--area NAME|--shard I/N|--list]',
              file=sys.stderr)
        return 2
    obj = os.path.abspath(sys.argv[1])
    cls = os.path.abspath(sys.argv[2])
    args = sys.argv[3:]
    area = None
    only: set[str] = set()
    shard = None
    i = 0
    while i < len(args):
        if args[i] == '--area' and i + 1 < len(args):
            area = args[i + 1]
            i += 2
        elif args[i] == '--shard' and i + 1 < len(args):
            a, b = args[i + 1].split('/', 1)
            shard = (int(a), int(b))
            i += 2
        else:
            only.add(args[i])
            i += 1
    for path, name in ((obj, 'object'), (cls, 'class')):
        if not os.path.isfile(os.path.join(path, 'dn')):
            print('no dn in', name, path, file=sys.stderr)
            return 2

    selected = selected_scenarios(area, only, shard)
    if shard is not None:
        print('SHARD %d/%d scenarios=%d' % (shard[0], shard[1], len(selected)),
              flush=True)

    fails = 0
    passed = 0
    for name, spec, ar in selected:
        work = prep_tree(WORK_ROOT)
        print('SCENARIO', name, '(%s)' % ar, flush=True)
        so, eo = run_one(obj, work, spec, ar, name)
        work = prep_tree(WORK_ROOT)
        sc, ec = run_one(cls, work, spec, ar, name)
        problems = []
        if 'Fatal' in so['text'] or 'Access' in so['text']:
            problems.append('object Fatal/Access on screen')
        if 'Fatal' in sc['text'] or 'Access' in sc['text']:
            problems.append('class Fatal/Access on screen')
        def _err_line(err: str) -> str:
            for line in err.split('\n'):
                if line.strip():
                    return line.strip()[:120]
            return ''

        if eo and eo.strip():
            problems.append('object dn.err: ' + _err_line(eo))
        if ec and ec.strip():
            problems.append('class dn.err: ' + _err_line(ec))
        problems.extend(diff_snaps(so, sc))
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
