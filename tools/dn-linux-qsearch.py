#!/usr/bin/env python3
"""Quick search of the panel with a character that is not in the code page (UTF-8 build): tools/dn-linux-qsearch.py OUTDIR
Ctrl+S, the typed text "Győ" (the key has no CharCode, only the UTF-8 text), Enter: the directory "Győr" is entered (its name is in the panel header)."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dnqs-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
            shutil.copy(os.path.join(out, f), d)
    w = os.path.join(d, 'work')
    os.makedirs(os.path.join(w, 'Győr'))
    open(os.path.join(w, 'alpha'), 'w').close()
    open(os.path.join(w, 'zeta'), 'w').close()
    os.environ['DNLNG'] = 'ENGLISH'
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    t.pump(0.5, 3)
    head0 = '\n'.join(t.text().split('\n')[:3])
    t.send('\x13', 0.5)
    t.send('Győ', 0.8)
    t.pump(0.5, 3)
    t.send('\r', 0.8)
    t.pump(0.8, 3)
    head1 = '\n'.join(t.text().split('\n')[:3])
    t.close(0.3)
finally:
    shutil.rmtree(d, ignore_errors=True)
ok = 'Győr' not in head0 and 'Győr' in head1
print('quick search with a character outside the code page:', 'ok' if ok else 'FAIL\n' + head1)
sys.exit(0 if ok else 1)
