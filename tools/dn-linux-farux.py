#!/usr/bin/env python3
"""Far UX fast find (Alt+letters) in a pty, checked on the screen: with
[FilePanels] FarUxMode=1 Alt+A moves the cursor to alpha1 (no menu opens),
Ctrl+Enter goes to the next match, Ctrl+Shift+Enter goes back, Esc leaves
the search, Alt+B (held by the status line of DN) is fast find too, Alt+F10 opens the folder tree and Alt+F12 the folder history;
Ctrl+F6..F10 sort by size, no sort, creation time, access time and description;
repeating the current sort reverses its order;
Shift+Gray+/- select/deselect all, Ctrl+Gray+/- select/deselect the files
with the extension of the current one, Ctrl+Gray* inverts; with the mode
off Alt+A starts no search and the gray keys select nothing; the check box "Far UX
mode" of the File Manager setup switches the mode on at once and in dn.ini. Ctrl+F3/F4/F5
sort the focused panel by name, extension and modification time, Ctrl+F12 opens the sort menu
(with the mode off it stays the calendar). The exact keys go over the
win32 input mode (TV_WIN32_INPUT=1), the Alt trigger additionally
over a plain ESC prefix. Ctrl+H toggles hidden files in the focused panel
only when FarUxMode is on. With the mode on the keys DN shares with Far still work: Ctrl+R,
Ctrl+PgDn/PgUp, Tab, Ctrl+U, Ctrl+Q and Ctrl+L. Ctrl+T shows the tree of the file system of the current folder (the folders next to
it, none of the file systems mounted inside it), the second Ctrl+T gives the file panel back, and Esc during the scan does the same.
usage: tools/dn-linux-farux.py OUTDIR"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

CURSOR = (('i', 0), ('i', 6), 0)
SEL = (('i', 11), ('i', 8), 0)


def w32(vk, uc=0, cs=0, sc=0):
    """a press and a release of a key"""
    return '\x1b[%d;%d;%d;1;%d;1_\x1b[%d;%d;%d;0;%d;1_' % (vk, sc, uc, cs, vk, sc, uc, cs)


def start(out, farux, sort_files=False, hidden_files=False, base=None):
    d = tempfile.mkdtemp(prefix='dnfar-')
    for f in os.listdir(out):
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(os.path.join(out, f), d)
        elif f == 'xlt':
            shutil.copytree(os.path.join(out, f), os.path.join(d, f))
    if farux:
        with open(os.path.join(d, 'dn.ini'), 'w') as f:
            f.write('[FilePanels]\nFarUxMode=1\n')
    w = os.path.join(base or d, 'work')
    os.makedirs(w)
    open(os.path.join(w, 'alpha1.txt'), 'w').write('first\n')
    open(os.path.join(w, 'alpha2.txt'), 'w').write('other\n')
    open(os.path.join(w, 'beta.txt'), 'w').write('third\n')
    # another extension, sorted (by the extension, the default) after the .txt files
    open(os.path.join(w, 'gamma.xyz'), 'w').write('fourth\n')
    if hidden_files:
        open(os.path.join(w, '.secret'), 'w').write('hidden\n')
    if sort_files:
        open(os.path.join(w, 'able.zzz'), 'w').write('small')
        time.sleep(2.1)
        open(os.path.join(w, 'zeta.aaa'), 'w').write('largest file by size\n' * 8)
        for name, mtime in (('alpha1.txt', 1600000000), ('alpha2.txt', 1600000000),
                            ('beta.txt', 1600000000), ('gamma.xyz', 1600000000),
                            ('able.zzz', 1700000000)):
            os.utime(os.path.join(w, name), (mtime, mtime))
        time.sleep(2.1)
        # utime also changes ctime; zeta goes last to keep the newest creation time
        os.utime(os.path.join(w, 'zeta.aaa'), (1500000000, 1500000000))
    t = PtyTerm(['./dn'], 100, 30, env={'TV_WIN32_INPUT': '1'}, cwd=w, exe=os.path.join(d, 'dn'))
    t.pump(1.5, 6)
    t.send(w32(0x1B), 1.0)                       # Esc closes the start box
    return d, t


def has_file(s):
    return any(name in s for name in ('alpha', 'beta', 'gamma', 'zeta', 'able'))


def cursor_file(t):
    # the text under the cursor bar only: the row also holds the other panel, whose
    # first entry must not be taken for the cursor file (the focused panel may be the right one)
    for row in t.screen.cells:
        s = ''.join(c for c, _ in row)
        if has_file(s) and CURSOR in set(a for _, a in row):
            runs = ''.join(c if a == CURSOR else '\0' for c, a in row).split('\0')
            return ' | '.join(r.strip() for r in runs if r.strip())
    return None


def selected_files(t):
    # selected rows carry ('i', 11) as the first attr element; the second
    # differs under the cursor (('i', 6) instead of ('i', 8))
    out = []
    for row in t.screen.cells:
        s = ''.join(c for c, _ in row)
        if has_file(s) and any(a[0] == ('i', 11) for _, a in row):
            out.append(s.strip()[:8])
    return out


def quit_dn(t):
    t.send(w32(0x58, ord('x'), 2), 0.5)           # Alt-X
    t.send(w32(0x0D, 13), 1.5)                   # Enter confirms
    return t.close(4)


def cmdline_row(t):
    return '\n'.join(''.join(c for c, _ in row)
                     for row in t.screen.cells[27:29])


out = os.path.abspath(sys.argv[1])
fails = 0


def check(ok, msg, t=None):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    if not ok:
        fails += 1
        if t is not None:
            print(t.text())


d, t = start(out, True)
try:
    t.send(w32(0x41, ord('a'), 2), 1.0)           # Alt+A
    check('Search:' in t.text(), 'FarUx on: Alt+A shows the fast-find mask', t)
    check(cursor_file(t) is not None and 'alpha1' in cursor_file(t),
          'FarUx on: the cursor stands on alpha1, no menu opens', t)
    t.send(w32(0x0D, 13, 4), 1.0)                # Ctrl+Enter
    check(cursor_file(t) is not None and 'alpha2' in cursor_file(t),
          'FarUx on: Ctrl+Enter moves to the next match', t)
    t.send(w32(0x0D, 13, 20), 1.0)               # Ctrl+Shift+Enter
    check(cursor_file(t) is not None and 'alpha1' in cursor_file(t),
          'FarUx on: Ctrl+Shift+Enter moves back', t)
    t.send(w32(0x1B), 1.0)                       # Esc
    check('Search:' not in t.text(), 'FarUx on: Esc leaves the search', t)
    t.send(w32(0x42, ord('b'), 2), 1.0)           # Alt+B: the sort menu of DN's status line
    check('Search:' in t.text() and cursor_file(t) is not None and 'beta' in cursor_file(t),
          'FarUx on: Alt+B is fast find (the cursor on beta), not the sort menu', t)
    t.send(w32(0x1B), 1.0)                       # Esc
    check('Search:' not in t.text(), 'FarUx on: Esc leaves the search after Alt+B', t)
    t.send(w32(0x6B, ord('+'), 16), 1.0)         # Shift+NumpadAdd
    check(len(selected_files(t)) == 4, 'FarUx on: Shift+Gray+ selects all', t)
    t.send(w32(0x6D, ord('-'), 16), 1.0)         # Shift+NumpadSub
    check(selected_files(t) == [], 'FarUx on: Shift+Gray- deselects all', t)
    t.send('\x1b[H', 0.5)                       # Home
    t.send('\x1b[B', 0.5)                       # Down -> alpha1.txt
    t.send(w32(0x6B, ord('+'), 8), 1.0)          # Ctrl+NumpadAdd
    sel = selected_files(t)
    check(len(sel) == 3 and not any('gamma' in f for f in sel),
          'FarUx on: Ctrl+Gray+ selects the files with the extension of the current one', t)
    t.send(w32(0x6D, ord('-'), 8), 1.0)          # Ctrl+NumpadSub
    check(selected_files(t) == [],
          'FarUx on: Ctrl+Gray- deselects the files with the extension of the current one', t)
    t.send(w32(0x6B, ord('+'), 2), 1.0)         # Alt+NumpadAdd
    sel = selected_files(t)
    # DN selects by the name without the extension (the key of DN, kept in Far mode)
    check(any('alpha1' in f for f in sel) and not any(('beta' in f or 'gamma' in f) for f in sel),
          'FarUx on: terminal Alt+Gray+ selects the files with the name of the current one', t)
    t.send(w32(0x6D, ord('-'), 2), 1.0)         # Alt+NumpadSubtract
    check(selected_files(t) == [], 'FarUx on: terminal Alt+Gray- deselects the files with the name of the current one', t)
    t.send(w32(0x6A, ord('*'), 8), 1.0)          # Ctrl+NumpadMultiply
    check(len(selected_files(t)) == 4, 'FarUx on: Ctrl+Gray* inverts the selection', t)
    t.send(w32(0x6D, ord('-'), 16), 1.0)         # Shift+NumpadSub
    check(selected_files(t) == [], 'FarUx on: Shift+Gray- deselects all again', t)
    t.send('\x1b[H', 0.5)                       # Home
    t.send('\x1b[B', 0.5)                       # Down -> alpha1
    t.send(w32(0x2D, 0, 6), 1.0)                 # Ctrl+Alt+Ins: full names
                                                     # (win32 Cs: $04 ctrl + $02 alt)
    t.send('\x1b[B', 0.5)
    t.send('\x1b[B', 0.5)                       # Down,Down -> beta.txt
    t.send(w32(0x73), 1.2)                       # F4 editor
    t.send(w32(0x2D, 0, 16), 1.0)                # Shift+Ins pastes
    t.pump(0.5)
    editor_text = t.text()
    editor_text = editor_text[editor_text.find('Edit -'):]
    check(re.search(r'work[\\/]alpha1', editor_text) is not None,
          'FarUx on: Ctrl+Alt+Ins puts the full name into the clipboard', t)
    t.send(w32(0x1B), 1.0)                       # Esc leaves the editor
    t.pump(0.5)
    if 'was modified' in t.text():
        t.send('n', 1.0)                         # No: do not save the paste
    check('Edit -' not in t.text(), 'FarUx on: the editor is closed', t)
    t.send('\x1b[H', 0.5)                       # Home
    t.send('\x1b[B', 0.5)                       # Down -> alpha1
    t.send('q', 0.8)                             # type into the command line
    t.send(w32(0x2D, 0, 4), 1.0)                 # Ctrl+Ins
    check('alpha1' in cmdline_row(t),
          'FarUx on: Ctrl+Ins with text inserts the name into the command line', t)
    t.send(w32(0x1B), 0.6)                       # Esc clears the command line
    empty_command = cmdline_row(t)
    t.send('abc', 0.5)
    check(cmdline_row(t).rstrip().endswith('abc'),
          'FarUx on: text is entered into the command line', t)
    t.send(w32(0x25), 0.5)                       # Left: position before c
    t.send(w32(0x4B, 11, 4), 0.8)                # Ctrl+K
    check(cmdline_row(t).rstrip().endswith('a'),
          'FarUx on: Ctrl+K deletes from the cursor to the end of the command line', t)
    t.send(w32(0x59, 25, 4), 0.8)                # Ctrl+Y
    check(cmdline_row(t) == empty_command,
          'FarUx on: Ctrl+Y clears the command line', t)
    for vk, what in ((0x79, 'Alt+F10 opens the folder tree'), (0x7B, 'Alt+F12 opens the folder history')):
        before = t.text()
        t.send(w32(vk, 0, 2), 1.2)               # Alt+F10 / Alt+F12
        check(t.text() != before and t.alive(), 'FarUx on: ' + what, t)
        t.send(w32(0x1B), 1.0)                   # Esc closes it
        check('alpha1' in t.text(), 'FarUx on: Esc after %s returns to the panels' % what.split()[0], t)
    check(quit_dn(t) == 0, 'FarUx on: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)

d, t = start(out, True, sort_files=True)
try:
    for key, expected, message in (
            (0x72, 'able', 'Ctrl+F3 sorts the focused panel by name'),
            (0x73, 'zeta', 'Ctrl+F4 sorts the focused panel by extension'),
            (0x74, 'able', 'Ctrl+F5 sorts the focused panel by modification time')):
        t.send(w32(key, 0, 4), 0.8)                # Ctrl+F3 / Ctrl+F4 / Ctrl+F5
        t.send('\x1b[H', 0.3)                      # Home -> parent entry
        t.send('\x1b[B', 0.5)                      # first file in the sorted panel
        current = cursor_file(t)
        check(current is not None and expected in current, message, t)
    t.send(w32(0x7B, 0, 4), 1.2)                  # Ctrl+F12: the sort menu, as in Far (the calendar in DN)
    check('Unsorted' in t.text() and 'Calendar' not in t.text(), 'FarUx on: Ctrl+F12 opens the sort menu', t)
    t.send(w32(0x1B), 0.8)                       # Esc closes it
    check('Unsorted' not in t.text() and t.alive(), 'FarUx on: Esc closes the sort menu', t)
    check(quit_dn(t) == 0, 'FarUx sort keys: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


d, t = start(out, True, sort_files=True)
try:
    for key, expected, message in (
            (0x75, 'zeta', 'Ctrl+F6 sorts by size'),
            # the Linux build knows no creation time (CorrectSearchRec in lfn.pas sets it to 0), so the order falls back to the name
            # (dn-linux #782: able, alpha1, alpha2, beta, gamma, zeta); the key is checked to be handled, not to order by a time
            (0x77, 'able', 'Ctrl+F8 sorts by creation time (none on Linux: the name order)'),
            (0x78, 'able', 'Ctrl+F9 sorts by access time'),
            (0x79, 'able', 'Ctrl+F10 sorts by description, then name')):
        t.send(w32(key, 0, 4), 0.8)
        t.send('\x1b[H', 0.3)
        t.send('\x1b[B', 0.5)
        current = cursor_file(t)
        check(current is not None and expected in current, message, t)
    unsorted_first = os.listdir(os.path.join(d, 'work'))[0].split('.')[0]
    t.send(w32(0x76, 0, 4), 0.8)                  # Ctrl+F7
    t.send('\x1b[H', 0.3)
    t.send('\x1b[B', 0.5)
    current = cursor_file(t)
    check(current is not None and unsorted_first in current,
          'Ctrl+F7 restores the directory order', t)
    t.send(w32(0x75, 0, 4), 0.8)                  # Ctrl+F6: by size again, largest first
    t.send('\x1b[H', 0.3)
    t.send('\x1b[B', 0.5)
    current = cursor_file(t)
    check(current is not None and 'zeta' in current,
          'Ctrl+F6 after Ctrl+F7 sorts by size again', t)
    t.send(w32(0x75, 0, 4), 0.8)                  # Ctrl+F6 once more: reversed, smallest first
    t.send('\x1b[H', 0.3)
    t.send('\x1b[B', 0.5)
    current = cursor_file(t)
    check(current is not None and 'able' in current,
          'repeating Ctrl+F6 reverses the sort order', t)
    check(quit_dn(t) == 0, 'FarUx sort keys F6-F10: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


d, t = start(out, True, hidden_files=True)
try:
    check('.secret' in t.text(), 'FarUx on: hidden files are initially shown', t)
    t.send(w32(0x48, ord('h'), 4), 1.0)            # Ctrl+H
    check('.secret' not in t.text(), 'FarUx on: Ctrl+H hides hidden files', t)
    t.send(w32(0x48, ord('h'), 4), 1.0)            # Ctrl+H again
    check('.secret' in t.text(), 'FarUx on: Ctrl+H shows hidden files again', t)
    check(quit_dn(t) == 0, 'FarUx Ctrl+H: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


def screen_rows(t):
    return [''.join(c for c, _ in row) for row in t.screen.cells]


def focused_side(t):
    # the focused panel draws its scroll bar: the up arrow ends the header row of that half
    i = screen_rows(t)[2].find('\u25b2')
    return None if i < 0 else ('left' if i < 50 else 'right')


def panel_titles(t):
    r = screen_rows(t)[1]
    return r[:50], r[50:]


# the keys of Far that DN already has as they are: with the mode on they still work (DN starts with the right panel focused)
d, t = start(out, True)
try:
    w = os.path.join(d, 'work')
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'sub', 'inner.txt'), 'w').write('inner\n')

    def shows_sub():
        return any(r[50:].startswith('\u2551sub ') for r in screen_rows(t))

    t.pump(1.0)
    check(not shows_sub(), 'FarUx on: a new folder is not shown before the reread', t)
    t.send(w32(0x52, 0x12, 8), 1.0)              # Ctrl+R
    check(shows_sub(), 'FarUx on: Ctrl+R rereads the panel', t)
    t.send('\x1b[H', 0.5)                       # Home
    t.send('\x1b[B', 0.5)                       # Down -> sub
    t.send(w32(0x22, 0, 8), 1.0)                 # Ctrl+PgDn
    check('work/sub' in panel_titles(t)[1] and 'inner' in t.text(),
          'FarUx on: Ctrl+PgDn enters the folder under the cursor', t)
    t.send(w32(0x09, 9), 1.0)                    # Tab
    check(focused_side(t) == 'left', 'FarUx on: Tab moves to the other panel', t)
    t.send(w32(0x09, 9), 1.0)                    # Tab
    check(focused_side(t) == 'right', 'FarUx on: Tab moves back', t)
    t.send(w32(0x55, 0x15, 8), 1.0)              # Ctrl+U
    left, right = panel_titles(t)
    check('work/sub' in left and 'work/sub' not in right, 'FarUx on: Ctrl+U swaps the panels', t)
    t.send(w32(0x55, 0x15, 8), 1.0)              # Ctrl+U
    left, right = panel_titles(t)
    check('work/sub' in right and 'work/sub' not in left, 'FarUx on: Ctrl+U swaps them back', t)
    t.send(w32(0x21, 0, 8), 1.0)                 # Ctrl+PgUp
    check('work/sub' not in panel_titles(t)[1] and cursor_file(t) == 'sub',
          'FarUx on: Ctrl+PgUp goes to the parent folder, the cursor on the folder it left', t)
    for vk, ch, what, mark in ((0x51, 0x11, 'Ctrl+Q shows the quick view in the other panel', 'files: 1'),
                               (0x4C, 0x0C, 'Ctrl+L shows the information in the other panel', 'Current directory')):
        t.send(w32(vk, ch, 8), 1.2)
        check(mark in ''.join(r[:50] for r in screen_rows(t)), 'FarUx on: ' + what, t)
        t.send(w32(vk, ch, 8), 1.2)
        check('alpha1' in ''.join(r[:50] for r in screen_rows(t)),
              'FarUx on: %s again gives the file panel back' % what.split()[0], t)
    check(quit_dn(t) == 0, 'FarUx same keys: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


d, t = start(out, False, sort_files=True)
try:
    t.send(w32(0x41, ord('a'), 2), 1.0)           # Alt+A
    check('Search:' not in t.text(), 'FarUx off: Alt+A starts no search', t)
    before = t.text()
    t.send(w32(0x72, 0, 4), 0.8)                 # Ctrl+F3: "create panel" opens its list of drives
    check(t.text() != before and t.alive(), 'FarUx off: Ctrl+F3 keeps the existing behavior', t)
    t.send(w32(0x1B), 0.8)                       # Esc closes the list
    t.send('\x1b[H', 0.3)                       # Home -> parent entry
    t.send('\x1b[B', 0.5)                       # first file, still extension-sorted
    current = cursor_file(t)
    check(current is not None and 'zeta' in current,
          'FarUx off: Ctrl+F3 does not sort the panel', t)
    t.send(w32(0x7B, 0, 4), 1.2)                  # Ctrl+F12: the calendar of DN
    check('Calendar' in t.text() and 'Unsorted' not in t.text(), 'FarUx off: Ctrl+F12 keeps the calendar', t)
    t.send(w32(0x1B), 0.8)
    t.send(w32(0x6B, ord('+'), 16), 1.0)         # Shift+NumpadAdd
    check(selected_files(t) == [], 'FarUx off: Shift+Gray+ selects nothing', t)
    t.send(w32(0x6B, ord('+'), 8), 1.0)          # Ctrl+NumpadAdd
    check(selected_files(t) == [], 'FarUx off: the terminal Ctrl+Gray+ selects nothing', t)
    t.send(w32(0x6B, ord('+'), 2), 1.0)          # Alt+NumpadAdd
    check(selected_files(t) == [], 'FarUx off: the terminal Alt+Gray+ selects nothing', t)
    t.send('\x1b[H', 0.5)                       # Home
    t.send('\x1b[B', 0.5)                       # Down -> alpha1
    t.send('q', 0.8)
    t.send(w32(0x2D, 0, 4), 1.0)                 # Ctrl+Ins
    check('alpha1' not in cmdline_row(t),
          'FarUx off: Ctrl+Ins with text still goes to the clipboard', t)
    check(quit_dn(t) == 0, 'FarUx off: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


d, t = start(out, False, hidden_files=True)
try:
    check('.secret' in t.text(), 'FarUx off: hidden files are initially shown', t)
    t.send(w32(0x48, ord('h'), 4), 1.0)            # Ctrl+H
    check('.secret' in t.text(), 'FarUx off: Ctrl+H does not toggle hidden files', t)
    check(quit_dn(t) == 0, 'FarUx off Ctrl+H: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


# Ctrl+\ goes to the root folder, as in Far and in DN: a terminal sends FS ($1C), tv/ gives '\' with ctrl
d, t = start(out, True)
try:
    t.send('\x1c', 1.0)                         # Ctrl+\
    title = ''.join(c for c, _ in t.screen.cells[1])[50:]
    check(' / ' in title and 'work' not in title, 'FarUx on: Ctrl+\\ goes to the root folder', t)
    check(quit_dn(t) == 0, 'FarUx Ctrl+\\: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


def mount_tmpfs(path):
    return subprocess.run(['sudo', '-n', 'mount', '-t', 'tmpfs', '-o', 'size=8m,mode=1777', 'tmpfs', path],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def tree_base():
    """a folder with two folders next to the one DN starts in; where sudo allows it the folder is a file system of its own (a tmpfs),
    with another tmpfs mounted inside: the tree is then read in a moment, and the inner file system must not be in it"""
    base = tempfile.mkdtemp(prefix='dnfartree-')
    mounted = []
    if shutil.which('sudo') and mount_tmpfs(base):
        mounted.append(base)
        inner = os.path.join(base, 'inner')
        os.makedirs(inner)
        if mount_tmpfs(inner):
            mounted.append(inner)
            os.makedirs(os.path.join(inner, 'foreign_probe'))
    for name in ('zz_sibling_one', 'zz_sibling_two'):
        os.makedirs(os.path.join(base, name))
    return base, mounted


def drop_tree_base(base, mounted):
    for m in reversed(mounted):
        subprocess.run(['sudo', '-n', 'umount', m], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    shutil.rmtree(base, ignore_errors=True)


def half(t, side):
    return '\n'.join(r[:50] if side == 'left' else r[50:] for r in screen_rows(t))


def panels_intact(t, what):
    # both halves hold the file panel of work (the file names, the titles), the right one is focused
    l, r = panel_titles(t)
    check('alpha1' in half(t, 'left') and 'alpha1' in half(t, 'right') and 'work' in l and 'work' in r
          and focused_side(t) == 'right', what, t)


# Ctrl+T: the tree of the file system of the current folder (a host without drives has no drive to take the tree of)
base, mounted = tree_base()
d, t = start(out, True, base=base)
try:
    ctrl_t = w32(0x54, 0x14, 8)
    t.send(ctrl_t, 1.0)                          # Ctrl+T
    # a tmpfs of its own is read in a moment; the whole file system of the runner is not
    shown = t.wait_for('zz_sibling_one', 30 if mounted else 400)
    check(shown and 'zz_sibling_two' in half(t, 'left'),
          'FarUx on: Ctrl+T shows the tree with the folders next to the current one', t)
    if len(mounted) == 2:
        check('foreign_probe' not in t.text() and 'inner' not in half(t, 'left'),
              'FarUx on: the tree does not enter a file system mounted inside it', t)
    else:
        print('SKIP the file system mounted inside the tree: no sudo to mount one')
    t.send(ctrl_t, 1.2)                          # Ctrl+T again: the file panel is back
    check('zz_sibling_one' not in t.text() and t.alive(), 'FarUx on: the second Ctrl+T closes the tree', t)
    panels_intact(t, 'FarUx on: after the second Ctrl+T both panels are as before, none is shrunk')
    t.send(ctrl_t, 1.5)                          # Ctrl+T: the tree again, now from the cache
    check(t.wait_for('zz_sibling_one', 30), 'FarUx on: Ctrl+T shows the tree again', t)
    t.send(w32(0x1B), 1.0)                       # Esc in the tree
    t.send(ctrl_t, 1.2)                          # Ctrl+T: the panels, whether the tree has stayed or not
    if 'zz_sibling_one' in t.text():
        t.send(ctrl_t, 1.2)
    panels_intact(t, 'FarUx on: after Esc and Ctrl+T both panels are as before')
    check(quit_dn(t) == 0, 'FarUx Ctrl+T: DN ends with 0')
finally:
    drop_tree_base(base, mounted)
    shutil.rmtree(d, ignore_errors=True)


# Esc during the scan of a big file system gives the panel back (it was left hidden). A scan that is over before Esc leaves the finished tree
# on the screen (a stopped one never does), so a tree after Esc means there was nothing to stop: no check, not a failure
def stop_scan(t, ctrl_t, what):
    t.send(ctrl_t, 0.0)                          # Ctrl+T on the file system of the temporary folder
    scanning = t.wait_for('Esc - stop', 3)
    t.send(w32(0x1B), 1.5)                       # Esc stops the scan
    if not scanning or '\u251c\u2500' in half(t, 'left') or '\u2514\u2500' in half(t, 'left'):
        print('SKIP Esc during the scan (%s): the tree was read before Esc' % what)
        return False
    check('Esc - stop' not in t.text() and t.alive(), 'FarUx on: Esc stops the scan of the tree (%s)' % what, t)
    panels_intact(t, 'FarUx on: after the scan is stopped both panels are as before (%s)' % what)
    return True


d, t = start(out, True)
try:
    ctrl_t = w32(0x54, 0x14, 8)
    if stop_scan(t, ctrl_t, 'first'):
        stop_scan(t, ctrl_t, 'second')           # Ctrl+T again, and Esc again
    if '\u251c\u2500' in half(t, 'left'):
        t.send(ctrl_t, 1.2)                      # a finished tree stays: Ctrl+T gives the panels back
    check(quit_dn(t) == 0, 'FarUx stopped scan: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)


d, t = start(out, False)
try:
    t.send(w32(0x4F, ord('o'), 2), 0.8)           # Alt+O: the menu Options
    t.send('f', 0.6)                             # File Manager
    t.send('s', 1.0)                             # Setup
    check('[ ] Far UX mode' in t.text(), 'the File Manager setup shows "Far UX mode", off', t)
    t.send(w32(0x58, ord('x'), 2), 0.6)           # Alt+X: its hot key
    check('[X] Far UX mode' in t.text(), 'Alt+X checks "Far UX mode"', t)
    t.send(w32(0x0D, 13), 1.0)                   # Enter: OK
    ini = open(os.path.join(d, 'dn.ini'), errors='replace').read() if os.path.isfile(os.path.join(d, 'dn.ini')) else ''
    check('FarUxMode=1' in ini, 'the setup writes FarUxMode=1 into dn.ini', t)
    t.send(w32(0x41, ord('a'), 2), 1.0)           # Alt+A
    check('Search:' in t.text() and cursor_file(t) is not None and 'alpha1' in cursor_file(t),
          'the mode works at once: Alt+A finds alpha1', t)
    t.send(w32(0x1B), 1.0)                       # Esc leaves the search
    check(quit_dn(t) == 0, 'setup: DN ends with 0')
finally:
    shutil.rmtree(d, ignore_errors=True)

print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
