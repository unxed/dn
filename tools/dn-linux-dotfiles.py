#!/usr/bin/env python3
"""Dot files in the panels of DN on Linux: tools/dn-linux-dotfiles.py OUTDIR
  - a leading dot is a part of the name: `.bashrc` is the name `.bashrc` with no extension, `.config.bak` the name `.config` with the
    extension `bak` (they were shown as an empty name with the extension `bashrc`);
  - the sort by extension (the default) puts `.zzz` with the names without an extension, `.config.bak` among the `bak` files;
  - a mask of the selection (Panel, Select group): `*.bak` selects `.config.bak` and not `.bashrc`, `*.` selects `.bashrc`;
  - Alt-' (show hidden files) hides the dot files in both panels and shows them again (the key did nothing in a terminal);
  - the setting switched off in the dialog (Options, File Manager, Setup) hides them in both panels at once (the active one kept them).
Each case is a start of DN in its own directory, with its own HOME."""
import os, re, shutil, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

K = {'ENTER': '\r', 'TAB': '\t', 'DOWN': '\x1b[B', 'SPACE': ' ', 'ALT-O': '\x1bo', 'ALT-P': '\x1bp', 'ALT-QUOTE': "\x1b'"}
SELECT_GROUP = 'ALT-P ' + 'DOWN ' * 7 + 'ENTER'          # Panel, the eighth item: Select group...
LEFT, RIGHT = 1, 51                                       # the first column of a name in the left and in the right panel (100 columns)


def case(out, names, keys):
    """starts DN in a directory with the files `names` (both panels show it), sends the keys; returns (screen rows, cells, alive)"""
    d = tempfile.mkdtemp(prefix='dndot-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
                shutil.copy(os.path.join(out, f), d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        for n in names:
            open(os.path.join(w, n), 'w').write('x\n')
        env = {'DNLNG': 'ENGLISH', 'HOME': d, 'XDG_CONFIG_HOME': '', 'XDG_STATE_HOME': '', 'XDG_CACHE_HOME': ''}
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env=env)
        t.pump(1.5, 6)
        for k in ['\x1b'] + keys.split():
            t.send(K.get(k, k), 0)
            t.pump(0.6, 2)                      # the clock of the menu bar writes every second: wait for a pause, not for silence
        t.pump(1.0, 3)
        rows = t.text().split('\n')
        cells = [list(r) for r in t.screen.cells]
        alive = t.alive()
        t.close(0.3)
        return rows, cells, alive
    finally:
        shutil.rmtree(d, ignore_errors=True)


def column(rows, col):
    """the names of a panel from the top: the text of the first column of names, without the frame"""
    return [r[col:col + 17].rstrip() for r in rows[3:25] if len(r) > col and r[col:col + 17].strip()]


def row_of(rows, col, name_re):
    for i, r in enumerate(rows):
        if re.match(name_re, r[col:col + 17]):
            return i
    return -1


def selected(rows, cells, name_re):
    """True when the row of the name in the right (active) panel has another colour than the same row in the left one"""
    i = row_of(rows, RIGHT, name_re)
    return i >= 0 and cells[i][RIGHT][1] != cells[i][LEFT][1]


bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info.replace('\n', '\n    | ')[:1500], flush=True)


out = os.path.abspath(sys.argv[1])
DOTS = ['.bashrc', '.config.bak', 'plain.txt', 'x.bak', 'noext']
CASES = {
    'list': (DOTS, ''),
    'sort': (['.zzz', 'b.aaa', '.config.bak', 'a.mmm'], ''),
    'bak': (DOTS, SELECT_GROUP + ' *.bak ENTER'),
    'noext': (DOTS, SELECT_GROUP + ' *. ENTER'),
    'quote': (DOTS, 'ALT-QUOTE'),
    'quote2': (DOTS, 'ALT-QUOTE ALT-QUOTE'),
    'dialog': (DOTS, 'ALT-O f s TAB TAB TAB TAB DOWN DOWN DOWN DOWN SPACE ENTER'),
}
with ThreadPoolExecutor(len(CASES)) as ex:
    res = dict(zip(CASES, ex.map(lambda c: case(out, *CASES[c]), CASES)))

rows, cells, alive = res['list']
text = '\n'.join(rows)
names = column(rows, LEFT)
check(alive and any(re.match(r'\.bashrc\s*\S?$', n) for n in names), 'a dot file is shown with its whole name (.bashrc)', text)
check(any(re.match(r'\.config\s+\S?bak$', n) for n in names), 'a dot file with an extension: the name .config, the extension bak', text)
check('bas►' not in text and not any(re.match(r'\s+\S?bas', n) for n in names), 'no dot file is shown as an empty name with an extension', text)

rows, cells, alive = res['sort']
order = [re.sub(r'\s+', ' ', n).replace('░', '').strip() for n in column(rows, LEFT)]
check(alive and order[:5] == ['..', '.zzz', 'b aaa', '.config bak', 'a mmm'],
      'the sort by extension: .zzz has no extension, .config.bak is a bak file (%s)' % order, '\n'.join(rows))

rows, cells, alive = res['bak']
check(alive and selected(rows, cells, r'\.config\s+\S?bak') and selected(rows, cells, r'x\s+\S?bak') and
      not selected(rows, cells, r'\.bashrc') and not selected(rows, cells, r'plain'),
      'the mask *.bak selects .config.bak and x.bak, not .bashrc', '\n'.join(rows))
rows, cells, alive = res['noext']
check(alive and selected(rows, cells, r'\.bashrc') and selected(rows, cells, r'noext') and
      not selected(rows, cells, r'\.config') and not selected(rows, cells, r'x\s+\S?bak'),
      'the mask *. selects the names without an extension: .bashrc and noext', '\n'.join(rows))

for c, what in (('quote', "Alt-' hides the dot files"), ('dialog', 'the setting switched off in the dialog hides the dot files')):
    rows, cells, alive = res[c]
    for col, side in ((LEFT, 'left'), (RIGHT, 'right')):
        names = column(rows, col)
        check(alive and not any(n.startswith('.') and n != '..' for n in names) and any(n.startswith('plain') for n in names),
              '%s in the %s panel' % (what, side), '\n'.join(rows))
rows, cells, alive = res['quote2']
for col, side in ((LEFT, 'left'), (RIGHT, 'right')):
    names = column(rows, col)
    check(alive and any(n.startswith('.bashrc') for n in names), "Alt-' again shows them in the %s panel" % side, '\n'.join(rows))
sys.exit(1 if bad else 0)
