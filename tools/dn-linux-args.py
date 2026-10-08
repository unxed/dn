#!/usr/bin/env python3
"""The command line of DN on Unix: the words that are not switches (switches start with "-") are files to edit:
an absolute path (a word that starts with "/"), a relative name, several files.
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


def start(args):
    """DN with ARGS in a fresh setup, past the box of the start (Esc); the screen as text"""
    cfg = os.path.join(d, 'cfg')
    shutil.rmtree(cfg, ignore_errors=True)
    os.makedirs(cfg)
    t = PtyTerm(['./dn'] + args, 100, 30, cwd=w, exe=os.path.join(d, 'dn'),
                env={'DNLNG': 'ENGLISH', 'DN2': d, 'HOME': cfg})
    t.pump(2.0, 8)
    t.send('\x1b', 1.0)                            # Esc: the box of the start
    t.pump(1.0, 4)
    return t


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
    with open(os.path.join(w, 'second.txt'), 'w') as f:
        f.write('the text of the second file\n')

    t = start([target])
    txt = t.text()
    check('the text of the file given on the command line' in txt, 'dn /abs/path/e-notes.txt opens the file in the editor', txt)
    t.close(1)

    t = start(['e-notes.txt'])
    txt = t.text()
    check('the text of the file given on the command line' in txt, 'dn e-notes.txt (a relative name) opens the file in the editor', txt)
    t.close(1)

    t = start(['e-notes.txt', 'second.txt'])
    txt = t.text()
    check('the text of the second file' in txt, 'dn FILE1 FILE2: the last file is in front', txt)
    t.send('\x1b[13;3~', 1.0)                      # Alt+F3: close the editor in front
    t.pump(1.0, 4)
    txt = t.text()
    check('the text of the file given on the command line' in txt, 'dn FILE1 FILE2: the first file is open behind it', txt)
    t.close(1)
finally:
    shutil.rmtree(d, ignore_errors=True)
print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
