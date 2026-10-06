#!/usr/bin/env python3
"""Quick search of the panel and of the tree with a character that is not in the code page (UTF-8 build): tools/dn-linux-qsearch.py OUTDIR
Ctrl+S, the typed text "Győ" (the key has no CharCode, only the UTF-8 text), Enter: the directory "Győr" is entered (its name is in the panel header).
The same in the tree of the panel (Alt+F10)."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

def run(out, open_tree):
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
        if open_tree:
            # the tree of directories is the window of the button [Tree] of the Copy dialog: F5 on "alpha", Alt+T
            t.send('\x1b[H', 0.2)
            t.send('\x1b[B', 0.2)                  # Gyor
            t.send('\x1b[B', 0.2)                  # alpha
            t.send('\x1b[15~', 1.5)                # F5: the Copy dialog
            t.send('\x1bt', 1.5)                   # Alt+T: [Tree]
            t.pump(1.0, 4)
        else:
            t.send('\x13', 0.5)                    # Ctrl+S: the quick search
        s_open = t.text()
        t.send('Győ', 0.8)
        t.pump(0.5, 3)
        s_typed = t.text()
        t.send('\r', 1.0)
        t.pump(0.8, 3)
        s_end = t.text()
        t.send('\x1b', 0.3)
        t.send('\x1b', 0.3)
        t.close(0.3)
        if open_tree:
            # the chosen directory is the end of the destination in the Copy dialog: "...\\work\\Győr" (the panels show the name without the backslash)
            ok = any('\\Győr' in l for l in s_end.split('\n'))
        else:
            ok = 'Győr' not in head0 and 'Győr' in '\n'.join(s_end.split('\n')[:3])
        res = ''
        if not ok:
            def brief(x):
                import re
                rows = [re.sub(r'\s{2,}', ' ', l.strip()) for l in x.split('\n')[4:20]]
                return ' | '.join(r for r in rows if r.strip('║│ '))[:900]
            res = 'opened: ' + brief(s_open) + '\ntyped: ' + brief(s_typed) + '\nend: ' + brief(s_end)
        return ok, res
    finally:
        shutil.rmtree(d, ignore_errors=True)


out = os.path.abspath(sys.argv[1])
bad = 0
for name, tree in (('panel', False), ('tree', True)):
    ok, head = run(out, tree)
    bad += not ok
    print('quick search of the %s with a character outside the code page: %s' % (name, 'ok' if ok else 'FAIL\n' + head))
sys.exit(1 if bad else 0)
