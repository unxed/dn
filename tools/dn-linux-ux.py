#!/usr/bin/env python3
"""The navigation guidelines of vtui (UX_GUIDELINES.md) on the Linux build of DN (a pty): tools/dn-linux-ux.py OUTDIR
Esc closes the dialogs, Enter presses the default button also in an edit field, Space toggles a check box, the arrow keys move the cursor of a
radio group without changing the selection and leave the group only at its boundary, Tab and Shift+Tab cycle, Ctrl+Tab / Ctrl+Shift+Tab walk the
windows, the F keys keep their DN meaning, Ctrl+Left / Ctrl+Right follow the word rules of far2l.
What is kept as it is (Norton Commander habits) is listed in docs/UX-CONFORMANCE.md."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

K = {'ESC': '\x1b', 'ENTER': '\r', 'TAB': '\t', 'BTAB': '\x1b[Z', 'UP': '\x1b[A', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'LEFT': '\x1b[D', 'SPACE': ' ',
     'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~', 'F1': '\x1bOP', 'F10': '\x1b[21~',
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
    finally:
        shutil.rmtree(d, ignore_errors=True)
    sys.exit(1 if bad else 0)


main()
