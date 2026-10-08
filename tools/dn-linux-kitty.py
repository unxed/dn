#!/usr/bin/env python3
"""Keys in the encoding of the Kitty keyboard protocol (CSI code ; modifiers : event u) in DN (Linux, a pty): tools/dn-linux-kitty.py OUTDIR
  - a press and a release of a key give one character (the release is dropped), a repeat is a key;
  - Ctrl-Tab in the encoding of the protocol is a key of DN (a command: the other panel), not text;
  - Alt-X in the encoding of the protocol asks to quit DN;
  - a key with the lock bits (Caps Lock, Num Lock) in the modifiers is the same key."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-500:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnkitty-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    return d, w


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    d, w = install(out); dirs.append(d)
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)

    def line():
        return [l for l in t.text().split('\n') if l.startswith('/') and '>' in l][0].split('>', 1)[1]

    t.send('\x1b[97u', 0.3); t.send('\x1b[97;1:3u', 0.3)
    check(line() == 'a', 'a press and a release of a: one character', line())
    t.send('\x1b[98;1:2u', 0.3)
    check(line() == 'ab', 'a repeat of b is a key', line())
    t.send('\x1b[99;65u', 0.3)                                    # c with Caps Lock (modifiers 1 + 64)
    check(line().startswith('ab') and len(line()) == 3, 'a key with the Caps Lock bit is a key', line())
    t.send('\x1b[9;5u', 0.4)                                      # Ctrl-Tab
    check(line() == 'abc', 'Ctrl-Tab (the protocol) is not typed as text', line())
    t.send('\x1b[120;3u', 1.0)                                    # Alt-X
    check('Do you wish to quit' in t.text(), 'Alt-X (the protocol) asks to quit', t.text())
    t.send('\x1b', 0.4)
    check(t.alive() and 'Do you wish to quit' not in t.text(), 'Esc answers No', t.text())
    t.close(0.3)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
