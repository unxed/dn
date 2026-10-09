#!/usr/bin/env python3
"""The history dialogs with nothing in them (Linux, a pty): tools/dn-linux-emptyhist.py OUTDIR
Alt-BkSp (directories), Alt-F8 (commands), Alt-PgUp (edited files), Alt-PgDn (viewed files) open a list that is empty in a fresh DN. OK (Enter) on an empty
list must give nothing and not stop the program: the directories dialog asked the empty collection for an item (Runtime error 213), the command history
did the same, and the buttons Edit and Delete of the commands list (Alt and a Cyrillic letter in the Russian interface, Del in any) took the item -1."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm, side_by_side

bad = 0
KEYS = [('Alt-BkSp', '\x1b\x7f'), ('Alt-F8', '\x1b[19;3~'), ('Alt-PgUp', '\x1b[5;3~'), ('Alt-PgDn', '\x1b[6;3~')]


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


def run(out, lang, key, ok_key, what):
    d = tempfile.mkdtemp(prefix='dnhist-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
                src = os.path.join(out, f)
                (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
        w = os.path.join(d, 'work')
        os.makedirs(w)
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d, 'HOME': d})
        t.started()
        t.send('\x1b', 0.5)
        before = t.shape()                                      # the screen but the clock
        t.send(key, 0.8)
        t.until(lambda: t.shape() != before, 5)
        check(t.shape() != before, '%s %s: the history opens' % (lang, what[0]), t.text())
        t.send(ok_key, 0.8)
        t.pump(0.4, 2)
        text = t.text()
        check(t.alive() and 'Runtime error' not in text and 'Fatal Error' not in text, '%s %s: %s on the empty list does not stop DN' % (lang, what[0], what[1]), text)
        t.close(0.3)
    finally:
        shutil.rmtree(d, ignore_errors=True)


out = os.path.abspath(sys.argv[1])
cases = []
for name, key in KEYS:
    cases.append(('ENGLISH', key, '\r', (name, 'Enter')))
    cases.append(('ENGLISH', key, '\x1b[3~', (name, 'Del')))
# the buttons of the commands list in Russian: Execute, Copy, Edit, Delete
for letter in '\u0432\u043a\u0440\u0443':
    cases.append(('RUSSIAN', '\x1b[19;3~', '\x1b' + letter, ('Alt-F8', 'Alt-' + letter)))
side_by_side([lambda c=c: run(out, *c) for c in cases])          # every case is a start of its own: all at once
sys.exit(1 if bad else 0)
