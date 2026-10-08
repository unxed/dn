#!/usr/bin/env python3
"""The drive menu of a host without drive letters lists places (the root, the home directory, mount points): tools/dn-linux-places.py OUTDIR
Alt+F1 opens the menu, the home directory is chosen, and the panel shows it."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

def main(out):
    d = tempfile.mkdtemp(prefix='dnpl-')
    fails = 0
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
                shutil.copy(os.path.join(out, f), d)
        home = os.path.join(d, 'homedir')
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(home, 'insidehome'))
        os.makedirs(w)
        os.environ['DNLNG'] = 'ENGLISH'
        os.environ['HOME'] = home
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.started()
        t.send('\x1b', 0.5)
        t.pump(0.5, 3)
        t.send('\x1b[1;3P', 1.0)                   # Alt+F1
        t.pump(0.8, 3)
        menu = t.text()
        def check(ok, what):
            nonlocal fails
            print(('PASS ' if ok else 'FAIL ') + what)
            if not ok:
                fails += 1
        check('~' not in menu and ' /' in menu, 'the menu lists the root')
        check(home in menu, 'the menu lists the home directory')
        t.send('\x1b[B', 0.3)                      # the second place: the home directory
        t.send('\r', 1.0)
        t.pump(0.8, 3)
        scr = t.text()
        check('insidehome' in scr, 'the panel shows the home directory after the choice')
        t.close()
    finally:
        shutil.rmtree(d, ignore_errors=True)
    return fails

if __name__ == '__main__':
    sys.exit(1 if main(sys.argv[1]) else 0)
