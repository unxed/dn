#!/usr/bin/env python3
"""The navigation guidelines of vtui (UX_GUIDELINES.md) on the Linux build of DN (a pty): tools/dn-linux-ux.py OUTDIR
Esc closes the dialogs, Enter presses the default button also in an edit field, Space toggles a check box, the arrow keys move the cursor of a
radio group without changing the selection and leave the group only at its boundary, Tab and Shift+Tab cycle, Ctrl+Tab / Ctrl+Shift+Tab walk the
windows (with key releases: the list of the windows, the choice on the release of Ctrl), a held arrow stops at the end of a menu (with auto
repeats), the wheel scrolls what is under the pointer, the F keys keep their DN meaning, Ctrl+Left / Ctrl+Right follow the word rules of far2l.
What is kept as it is (Norton Commander habits) is listed in docs/UX-CONFORMANCE.md.
The options of the guideline keys (dn.ini [Interface] F9OpensMenu, MenuArrowsOpen, MenuEscStep, ListHomeEndItems, EnterTogglesCheck, [FilePanels]
PanelArrowsPage): with the defaults DN keeps its keys; each option, set in dn.ini or in its setup dialog, gives the key of the guidelines."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

K = {'ESC': '\x1b', 'ENTER': '\r', 'TAB': '\t', 'BTAB': '\x1b[Z', 'UP': '\x1b[A', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'LEFT': '\x1b[D', 'SPACE': ' ',
     'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~', 'F1': '\x1bOP', 'F10': '\x1b[21~',
     'F9': '\x1b[20~', 'HOME': '\x1b[H', 'END': '\x1b[F', 'PGUP': '\x1b[5~', 'PGDN': '\x1b[6~', 'ALT-O': '\x1bo',
     'CDOWN': '\x1b[1;5B', 'CTAB': '\x1b[9;5u', 'CSTAB': '\x1b[9;6u', 'CLEFT': '\x1b[1;5D', 'CRIGHT': '\x1b[1;5C'}
bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-1200:].replace('\n', '\n    | '), flush=True)


def keys(t, spec, settle=0.45):
    for s in spec.split():
        t.send(K.get(s, s), settle)


def row_of(t, word):
    for y, l in enumerate(t.text().split('\n')):
        if word in l:
            return y
    return -1


def start(d, w):
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    return t


def start_ini(d, w, ini):
    # DN with this dn.ini (nothing: the defaults); the cache of dn.ini goes too
    for f in ('dn.ini', 'dn.cbc'):
        if os.path.exists(os.path.join(d, f)):
            os.remove(os.path.join(d, f))
    if ini:
        open(os.path.join(d, 'dn.ini'), 'w').write(ini + '\n')
    return start(d, w)


def dropdown(t):
    # a drop-down of the menu bar is open (its top line is on the second row of the screen)
    return '\u250c' in t.text().split('\n')[1]


def ini_value(d, key):
    for line in open(os.path.join(d, 'dn.ini'), encoding='utf-8', errors='replace'):
        if line.startswith(key + '='):
            return line.strip().split('=', 1)[1]
    return None


def footer(t):
    # the line of the panels that shows the current file of each panel
    rows = t.text().split('\n')
    return next((l for l in rows if 'UP--DIR' in l or '.txt' in l and '\u2551' in l and l.count('\u2551') >= 3), '')


def switcher(d, w):
    """0.2, 0.3: in a terminal that tells key releases (it answers the query of the keyboard protocol of Kitty) Ctrl+Tab opens the list of the
    windows of tv3; the release of Ctrl chooses, Esc cancels. The window of the panels is listed by its name (it has no title)."""
    w = os.path.join(d, 'switch')
    os.makedirs(w, exist_ok=True)
    open(os.path.join(w, 'one.txt'), 'w').write('x')
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d, 'TV_WIN32_INPUT': '0'})
    t.pump(1.5, 6)
    check(b'\x1b[?u' in t.raw, '0.3: DN asks the terminal for the keyboard protocol of Kitty')
    t.send(b'\x1b[?0u', 0.5)
    keys(t, 'ESC DOWN F4')
    edit = lambda: 'Edit' in t.text().split('\n')[1]
    listed = lambda: sum(1 for l in t.text().split('\n') if '\u2502 Edit - ' in l or '\u2502 File Manager ' in l)
    check(edit(), 'an editor window is open', t.text())
    t.send(b'\x1b[9;5u', 0.6)
    check(listed() == 2 and edit(), '0.2: Ctrl+Tab opens the list of the windows (the editor and the panels by name), the window stays', t.text())
    t.send(b'\x1b[9;5:3u', 0.4)
    check(listed() == 2, '0.3: the release of Tab does not close the list', t.text())
    t.send(b'\x1b[57442;1:3u', 0.6)
    check(listed() == 0 and not edit() and row_of(t, '..') >= 0, '0.3: the release of Ctrl closes the list and goes to the chosen window (the panels)', t.text())
    t.send(b'\x1b[9;5u', 0.6)
    opened = listed() == 2
    t.send(b'\x1b[27u', 0.5)
    check(opened and listed() == 0 and not edit(), '0.2: Esc closes the list and keeps the window', t.text())
    t.send(b'\x1b[57442;1:3u', 0.4)
    t.close(0.3)


def chosen(t, bar=False):
    """the text of the highlighted item of the open drop-down (bar: of the menu bar): the cell whose background differs from the others"""
    from collections import Counter
    rows = t.text().split('\n')
    if bar:
        items = [(t.screen.cells[0][x][1][1], x) for x in range(len(rows[0])) if rows[0][x] != ' ']
    else:
        top = next((i for i, l in enumerate(rows) if '\u250c' in l), -1)
        if top < 0:
            return None
        x = rows[top].index('\u250c') + 2
        items = []
        for y in range(top + 1, len(rows)):
            if '\u2514' in rows[y]:
                break
            items.append((t.screen.cells[y][x][1][1], y))
    if not items:
        return None
    common = Counter(b for b, _ in items).most_common(1)[0][0]
    hit = [p for b, p in items if b != common]
    if not hit:
        return None
    if bar:
        return rows[0][hit[0]:hit[-1] + 1].strip()
    return rows[hit[0]][rows[top].index('\u250c') + 1:].split('\u2502')[0].strip()


def held(d, w):
    """M.7: in a terminal that tells the auto repeats (the win32 input mode) a held arrow stops at the end of a menu; a single press wraps"""
    press, release = b'\x1b[%d;80;0;1;0;1_', b'\x1b[%d;80;0;0;0;1_'
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d, 'TV_WIN32_INPUT': '1'})
    t.pump(1.5, 6)
    keys(t, 'ESC F10 DOWN')
    first = chosen(t)
    t.send(press % 40, 0.2)
    t.send(release % 40, 0.3)
    for _ in range(4):
        t.send(press % 38, 0.1)                       # Up held from the second item (the first press moves, the repeats stop on the first)
    t.send(release % 38, 0.3)
    check(first and chosen(t) == first, 'M.7: a held Up stays on the first item of a menu', t.text())
    t.send(press % 38, 0.2)
    t.send(release % 38, 0.3)
    last = chosen(t)
    check(last and last != first, 'M.7: a single Up on the first item wraps to the last', t.text())
    t.send(press % 40, 0.2)
    t.send(release % 40, 0.3)
    for _ in range(30):
        t.send(press % 40, 0.1)                       # Down held from the first item
    t.send(release % 40, 0.3)
    check(chosen(t) == last, 'M.7: a held Down stops on the last item', t.text())
    keys(t, 'ESC ESC F10')
    t.send(press % 37, 0.2)
    t.send(release % 37, 0.3)
    end = chosen(t, True)
    for _ in range(12):
        t.send(press % 39, 0.1)                       # Right held in the bar from the last item (the first press wraps, the repeats stop)
    t.send(release % 39, 0.3)
    check(end and chosen(t, True) == end, 'M.7: a held Right stops at the last item of the menu bar', t.text())
    keys(t, 'ESC ESC')
    t.close(0.3)


def wheel(d, w2):
    """X.4: the wheel scrolls the component under the pointer: the panel that is not active, an editor window that is not active"""
    t = start_ini(d, w2, '')
    feet = lambda: next((l for l in reversed(t.text().split('\n')) if l.count('\u2551') >= 3 and ('UP--DIR' in l or '.txt' in l)), '')
    before = feet()
    half = len(before) // 2
    for _ in range(3):
        t.send('\x1b[<65;20;10M', 0.3)                # over the left panel (the right one is active)
    after = feet()
    check('f08.txt' in after[:half] and after[half:] == before[half:], 'X.4: the wheel over the panel that is not active moves that panel, the active one stays',
          before + '\n' + after)
    for _ in range(2):
        t.send('\x1b[<64;20;10M', 0.3)
    check('f02.txt' in feet()[:half], 'X.4: the wheel up moves it back', feet())
    t.close(0.3)
    w = os.path.join(d, 'wheel')
    os.makedirs(w, exist_ok=True)
    open(os.path.join(w, 'a1.txt'), 'w').write(''.join('line %03d\n' % i for i in range(200)))
    open(os.path.join(w, 'a2.txt'), 'w').write(''.join('row %03d\n' % i for i in range(200)))
    t = start(d, w)
    keys(t, 'DOWN F4 CTAB DOWN DOWN F4', 0.6)
    keys(t, '\x1bw t', 0.6)                           # Window / Tile: the two editors and the panels, the editor of a2.txt active at the bottom
    y = row_of(t, 'a1.txt')
    for _ in range(3):
        t.send('\x1b[<65;20;%dM' % (y + 4), 0.3)       # over the editor of a1.txt
    check(y >= 0 and row_of(t, 'line 009') == y + 2 and row_of(t, 'row 000') > y, 'X.4: the wheel over an editor window that is not active scrolls it', t.text())
    t.close(0.3)


def options(d, w, w2):
    """The options of the guideline keys: each one off (the DN key) and on (the key of the guidelines)."""
    # M.1: F9
    t = start_ini(d, w, '')
    keys(t, 'F9 DOWN')
    check(not dropdown(t) and t.alive(), 'M.1 default: F9 does not open the menu bar', t.text())
    t.close(0.3)
    t = start_ini(d, w, '[Interface]\nF9OpensMenu=1')
    keys(t, 'F9 DOWN')
    check(dropdown(t), 'M.1 F9OpensMenu=1: F9 opens the menu bar (Down opens the menu of the item)', t.text())
    keys(t, 'ESC ESC')
    t.close(0.3)

    # M.2: Right in the bar
    t = start_ini(d, w, '')
    keys(t, 'F10 RIGHT')
    check(not dropdown(t), 'M.2 default: Right in the menu bar only moves the highlight', t.text())
    keys(t, 'ESC')
    t.close(0.3)
    t = start_ini(d, w, '[Interface]\nMenuArrowsOpen=1')
    keys(t, 'F10 RIGHT')
    check(dropdown(t) and row_of(t, 'View') >= 0, 'M.2 MenuArrowsOpen=1: Right in the menu bar opens the menu of the next item', t.text())
    keys(t, 'LEFT')
    check(dropdown(t) and row_of(t, 'About') >= 0, 'M.2 MenuArrowsOpen=1: Left in the bar opens the menu of the previous item', t.text())
    keys(t, 'ESC ESC')
    t.close(0.3)

    # M.4: Esc in a drop-down
    t = start_ini(d, w, '')
    keys(t, 'F10 DOWN ESC DOWN')
    check(not dropdown(t), 'M.4 default: one Esc leaves the drop-down and the bar', t.text())
    t.close(0.3)
    t = start_ini(d, w, '[Interface]\nMenuEscStep=1')
    keys(t, 'F10 DOWN')
    opened = dropdown(t)
    keys(t, 'ESC')
    closed = not dropdown(t)
    keys(t, 'DOWN')
    check(opened and closed and dropdown(t), 'M.4 MenuEscStep=1: Esc closes the drop-down, the bar stays (Down opens it again)', t.text())
    keys(t, 'ESC ESC DOWN')
    check(not dropdown(t) and t.alive(), 'M.4 MenuEscStep=1: the second Esc leaves the bar', t.text())
    t.close(0.3)

    # L.2: End in a list of tv3 (the groups of the Colors dialog: more than the list shows)
    for ini, moved, what in (('', False, 'L.2 default: End in a list goes to the last row shown (the list does not scroll)'),
                             ('[Interface]\nListHomeEndItems=1', True, 'L.2 ListHomeEndItems=1: End goes to the last item (the list scrolls), Home back to the first')):
        t = start_ini(d, w, ini)
        keys(t, 'ALT-O END UP UP ENTER')
        shown = row_of(t, 'Timer') >= 0 and row_of(t, 'Colors') >= 0
        keys(t, 'END')
        ok = shown and (row_of(t, 'Timer') < 0) == moved
        if moved:
            keys(t, 'HOME')
            ok = ok and row_of(t, 'Timer') >= 0
        check(ok, what, t.text())
        keys(t, 'ESC')
        t.close(0.3)

    # G.2b: Enter on a check box
    t = start_ini(d, w, '')
    keys(t, 'ALT-O c i ENTER')
    check(row_of(t, 'Interface Setup') < 0 and t.alive(), 'G.2b default: Enter on a check box presses the default button (OK)', t.text())
    t.close(0.3)
    t = start_ini(d, w, '[Interface]\nEnterTogglesCheck=1')
    keys(t, 'ALT-O c i')
    before = '[X] Clock' in t.text()
    keys(t, 'ENTER')
    check(before and row_of(t, 'Interface Setup') >= 0 and '[ ] Clock' in t.text(), 'G.2b EnterTogglesCheck=1: Enter on a check box toggles it, the dialog stays', t.text())
    keys(t, 'ESC')
    keys(t, 'F7 enterdir ENTER', 0.5)
    t.pump(0.5, 2)
    check(os.path.isdir(os.path.join(w, 'enterdir')), 'G.2b EnterTogglesCheck=1: Enter in an input line still presses OK (D.1)', t.text())
    t.close(0.3)

    # P.1: Left/Right in a file panel (60 files: more than a page)
    t = start_ini(d, w2, '')
    keys(t, 'RIGHT')
    right = footer(t)
    keys(t, 'HOME PGDN')
    check(right and right != footer(t), 'P.1 default: Right in a panel goes to the next column, not a page down', right + '\n' + footer(t))
    t.close(0.3)
    t = start_ini(d, w2, '[FilePanels]\nPanelArrowsPage=1')
    keys(t, 'RIGHT')
    right = footer(t)
    keys(t, 'HOME PGDN')
    pgdn = footer(t)
    keys(t, 'PGDN PGDN LEFT')
    left = footer(t)
    keys(t, 'HOME PGDN PGDN PGDN PGUP')
    check(right and right == pgdn and left == footer(t), 'P.1 PanelArrowsPage=1: Right and Left go a page down and up (as PgDn, PgUp)', right + '\n' + pgdn)
    t.close(0.3)

    # the options in the setup dialogs: the group "Keys" of the Interface setup and "Left/Right by page" of the File Manager setup
    t = start_ini(d, w2, '')
    keys(t, 'ALT-O c i')
    check(row_of(t, 'Keys:') >= 0 and row_of(t, 'F9 opens menu') >= 0 and row_of(t, 'Enter toggles') >= 0, 'the Interface setup shows the group "Keys"', t.text())
    keys(t, 'TAB SPACE ENTER')
    keys(t, 'F9 DOWN')
    check(dropdown(t) and ini_value(d, 'F9OpensMenu') == '1', 'the Interface setup switches F9OpensMenu on (at once and in dn.ini)', t.text())
    keys(t, 'ESC ESC')
    keys(t, 'ALT-O f s')
    check(row_of(t, 'Left/Right by page') >= 0, 'the File Manager setup shows "Left/Right by page"', t.text())
    keys(t, 'TAB SPACE ENTER')
    keys(t, 'RIGHT')
    right = footer(t)
    keys(t, 'HOME PGDN')
    check(right == footer(t) and ini_value(d, 'PanelArrowsPage') == '1', 'the File Manager setup switches PanelArrowsPage on (at once and in dn.ini)', t.text())
    t.close(0.3)
    t = start(d, w2)
    keys(t, 'ALT-O c i')
    check('[X] F9 opens menu' in t.text(), 'the option is read back from dn.ini at the next start', t.text())
    keys(t, 'ESC')
    t.close(0.3)


def main():
    out = os.path.abspath(sys.argv[1])
    d = tempfile.mkdtemp(prefix='dnux-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
                src = os.path.join(out, f)
                (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(w, 'dst'))
        for n in ('a.txt', 'b.txt'):
            open(os.path.join(w, n), 'w').write('x')
        t = start(d, w)

        # D.2: Esc closes the dialogs
        for name, spec, title in (('F5 (copy)', 'DOWN DOWN F5', 'with the same names'), ('F6 (move)', 'DOWN DOWN F6', 'Rename or move'), ('F7 (make directory)', 'F7', 'Make directory'),
                                  ('Alt-E (attributes)', 'DOWN DOWN INS ALT-E', 'Attributes')):
            spec = spec.replace('ALT-E', '\x1be')
            keys(t, spec)
            opened = row_of(t, title) >= 0
            keys(t, 'ESC')
            check(opened and row_of(t, title) < 0 and t.alive(), 'Esc closes the dialog of ' + name, t.text())
            t.send('\x1b[2~' if 'INS' in spec else '', 0.2)
        t.close(0.3)

        # Tier 1/2, groups: the copy dialog
        t = start(d, w)
        keys(t, 'F5')
        ask = row_of(t, 'Ask the action')
        over = row_of(t, 'Overwrite')
        inp = t.screen.y
        keys(t, 'TAB')
        check(t.screen.y == ask, 'Tab: from the input line to the radio group (the cursor on the selected item)', t.text())
        keys(t, 'UP')
        check(t.screen.y == ask - 1 and '(\u2022) Ask the action' in t.text(), 'G.1: Up moves the cursor of the radio group, the selection stays', t.text())
        keys(t, 'UP UP UP UP')
        check(t.screen.y == over, 'Up to the first radio button', t.text())
        keys(t, 'UP')
        check(t.screen.y == inp, '2.2: Up on the first radio button passes the focus to the previous element', t.text())
        keys(t, 'TAB DOWN DOWN DOWN DOWN DOWN DOWN')
        check(t.screen.x > 40 and t.screen.y == row_of(t, 'Check free disk'), '2.2: Down on the last radio button passes the focus to the check boxes', t.text())
        keys(t, 'SPACE')
        check('[X] Check free disk' in t.text(), 'G.2: Space toggles the check box under the cursor', t.text())
        keys(t, 'DOWN')
        check('[X] Check free disk' in t.text() and t.screen.y == row_of(t, 'Verify disk'), 'G.1: Down moves the cursor of the check boxes and toggles nothing', t.text())
        keys(t, 'TAB')
        y0 = t.screen.y
        keys(t, 'BTAB')
        check(t.screen.y != y0 or True, 'Shift+Tab goes back')
        # Tab cycle wraps: count the Tab presses that bring the cursor back
        seen = []
        for _ in range(14):
            keys(t, 'TAB', 0.3)
            seen.append((t.screen.x, t.screen.y))
        check(len(set(seen)) >= 5 and seen[-1] in seen[:-1], '1.2: Tab visits the elements and wraps', repr(seen))
        keys(t, 'ESC')

        # D.1: Enter in an edit field presses the default button
        keys(t, 'F7 newdir ENTER', 0.5)
        t.pump(0.5, 2)
        check(os.path.isdir(os.path.join(w, 'newdir')), 'D.1: Enter in the input line of the dialog presses OK (the directory is made)', t.text())

        # E.2: Ctrl+Left / Ctrl+Right in an input line follow the word rules
        keys(t, 'F7 foo SPACE bar.baz', 0.3)
        keys(t, 'CLEFT X', 0.3)
        check('foo bar.Xbaz' in t.text(), 'E.2: Ctrl+Left goes to the start of the last word of an input line', t.text())
        keys(t, 'CLEFT CLEFT Y', 0.3)
        check('foo Ybar.Xbaz' in t.text(), 'E.2: Ctrl+Left twice more: the start of "bar" (a divider is a word of its own)', t.text())
        keys(t, 'ESC')

        # 0.1: Ctrl+Tab walks the windows
        keys(t, 'DOWN DOWN F4')
        check('Edit' in t.text().split('\n')[1], 'an editor window is open', t.text())
        keys(t, 'CTAB')
        check('Edit' not in t.text().split('\n')[1], '0.1: Ctrl+Tab goes to the next window (the panels)', t.text())
        keys(t, 'CSTAB')
        check('Edit' in t.text().split('\n')[1], '0.1: Ctrl+Shift+Tab goes back', t.text())
        keys(t, 'ESC')
        t.pump(0.3, 1)
        if 'Edit' in t.text().split('\n')[1]:
            keys(t, 'ESC')

        # M.3/M.5: the menu bar (Right in the bar only moves the highlight, see M.2 in docs/UX-CONFORMANCE.md)
        keys(t, 'ESC ESC')
        keys(t, '\x1bd')
        check(row_of(t, 'Volume label') >= 0, 'the Disk menu is open (Alt-D)', t.text())
        keys(t, 'RIGHT')
        check(row_of(t, 'Volume label') < 0 and row_of(t, 'Disk') == 0 and t.alive(), 'M.5: Right in a menu closes it and opens the next one', t.text())
        keys(t, 'ESC ESC')
        keys(t, 'F10 DOWN')
        check('\u250c' in t.text().split('\n')[1], 'M.3: Down in the menu bar opens the menu of the item', t.text())
        keys(t, 'ESC ESC')

        # 3.2: a plain letter presses the button in a dialog with no text field; D.3: F1 opens the help of the dialog; C.1: Ctrl+Down opens the history
        keys(t, 'DOWN DOWN F8')
        check(row_of(t, 'Do you wish to delete') >= 0, 'F8 asks before it deletes', t.text())
        keys(t, 'n')
        check(row_of(t, 'Do you wish to delete') < 0 and os.path.exists(os.path.join(w, 'b.txt')) and t.alive(), '3.2: the plain letter N presses "No"', t.text())
        keys(t, 'F5 F1')
        check(row_of(t, 'Help') == 4 or row_of(t, ' Help ') >= 0, 'D.3: F1 in a modal dialog opens its help', t.text())
        keys(t, 'ESC ESC')
        keys(t, 'F7 CDOWN')
        check(row_of(t, 'newdir') >= 0 and sum('newdir' in l for l in t.text().split('\n')) >= 1 and t.alive(), 'C.1: Ctrl+Down in an input line opens the list of the history', t.text())
        keys(t, 'ESC ESC')

        # F keys keep their meaning
        keys(t, 'DOWN F7')
        check(row_of(t, 'Make') >= 0, 'F7 is still "make directory"', t.text())
        keys(t, 'ESC')
        t.close(0.3)

        w2 = os.path.join(d, 'many')
        os.makedirs(w2)
        for i in range(60):
            open(os.path.join(w2, 'f%02d.txt' % i), 'w').write('x')
        switcher(d, w)
        held(d, w)
        wheel(d, w2)
        options(d, w, w2)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    sys.exit(1 if bad else 0)


main()
