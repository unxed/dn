#!/usr/bin/env python3
"""The setup of the file panel (Alt-K) and its Store button (Linux, a pty): tools/dn-linux-setup.py OUTDIR
  - the dialog "File Panel appearance" opens in the three languages (the English one died on an item with no text);
  - a column is switched on, Store saves the setup (the dialog "Save panel settings"), OK; after DN is left and started again the dialog shows the column on."""
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
            print('    | ' + info[-700:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnsetup-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    open(os.path.join(w, 'a.txt'), 'w').write('hello\n')
    return d, w


def until(t, cond, seconds=8.0):
    # waits for the screen (a loaded machine is slow): True when cond(text) came true
    import time
    end = time.time() + seconds
    while time.time() < end:
        t.pump(0.2, 0.5)
        if cond(t.text()):
            return True
    return cond(t.text())


def click(t, pattern):
    # a click (the mouse of the terminal) on the first place of the screen where the regular expression matches
    import re
    for y, line in enumerate(t.text().split('\n')):
        m = re.search(pattern, line)
        if m:
            t.send('\x1b[<0;%d;%dM\x1b[<0;%d;%dm' % (m.start() + 2, y + 1, m.start() + 2, y + 1), 0.3)
            return True
    return False


def start(d, w, lang):
    t = DnTerm(['./dn'], 80, 25, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d})
    t.started()
    t.send('\x1b', 0.5)
    return t


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    for lang, title in (('ENGLISH', 'File Panel appearance'), ('RUSSIAN', None), ('UKRAIN', None)):
        d, w = install(out); dirs.append(d)
        t = start(d, w, lang)
        t.send('\x1bk', 1.5)
        text = t.text()
        check('Fatal' not in text and t.alive(), '%s: Alt-K opens the dialog of the panel appearance' % lang, text)
        if title:
            check(title in text, '%s: the dialog has its title' % lang, text)
        t.close(0.3)

    d, w = install(out); dirs.append(d)
    t = start(d, w, 'ENGLISH')
    t.send('\x1bk', 0.5)
    until(t, lambda x: 'File Panel appearance' in x)
    t.send(' ', 0.3)
    check(until(t, lambda x: '[X] Size' in x), 'Space switches the column Size on', t.text())
    check(click(t, r'Store'), 'the button Store is on the screen')
    check(until(t, lambda x: 'Save panel settings' in x), 'Store asks where to save (the dialog "Save panel settings")', t.text())
    click(t, r'OK\s{5,}')                                    # OK of "Save panel settings"
    until(t, lambda x: 'Save panel settings' not in x)
    check('File Panel appearance' in t.text() and 'Save panel settings' not in t.text(), 'the save dialog is closed, the dialog of the panel is still there', t.text())
    click(t, r'OK  ▄')                                  # OK of the dialog of the panel
    until(t, lambda x: 'File Panel appearance' not in x)
    check(t.alive() and 'Fatal' not in t.text() and 'File Panel appearance' not in t.text(), 'DN is alive after Store and OK', t.text())
    t.send('\x1bx', 0.5)
    until(t, lambda x: 'quit' in x.lower())
    t.send('\r', 0.3)
    check(until(t, lambda x: not t.alive(), 10.0), 'DN is left (Alt-X, Yes)', t.text())
    t.close(0.3)
    t = start(d, w, 'ENGLISH')
    t.send('\x1bk', 0.5)
    until(t, lambda x: 'File Panel appearance' in x)
    check('[X] Size' in t.text(), 'after the next start the stored setup has the column Size on', t.text())
    t.send('\x1b', 0.3)
    t.close(0.3)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
