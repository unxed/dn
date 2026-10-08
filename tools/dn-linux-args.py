#!/usr/bin/env python3
"""The command line of DN on Unix: a word that starts with "/" is a file to edit (an absolute path), not a switch.
usage: tools/dn-linux-args.py OUTDIR   (OUTDIR: the result of tools/build.sh linux64)"""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

fails = 0


def check(ok, msg, info=''):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    if not ok:
        fails += 1
        if info:
            print(info)


out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dnargs-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    # a name that starts with "e", "s" or "p" would have been taken for the switches /E, /S, /P
    target = os.path.join(w, 'e-notes.txt')
    with open(target, 'w') as f:
        f.write('the text of the file given on the command line\n')
    t = PtyTerm(['./dn', target], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.pump(2.0, 8)
    txt = t.text()
    check('the text of the file given on the command line' in txt, 'dn /abs/path/e-notes.txt opens the file in the editor', txt)
    t.close(1)
finally:
    shutil.rmtree(d, ignore_errors=True)
print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
