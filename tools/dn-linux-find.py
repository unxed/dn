#!/usr/bin/env python3
"""Find File (Alt+F7) in a pty, the real operation: tools/dn-linux-find.py OUTDIR
A tree "work" with a.txt, sub/beta.txt (the text "needle"), sub/gamma.txt: the mask "beta*" finds beta.txt only; the mask "*.txt" with the text "needle" finds beta.txt only.
The result panel shows the file names. The dialog and the screens are printed when a check fails (compact)."""
import os, re, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm


def brief(text):
    rows = [re.sub(r'\s{2,}', ' ', l.strip()) for l in text.split('\n')[1:22]]
    return ' | '.join(r for r in rows if r.strip('║│═ '))[:900]


def run(out, mask, text, want, not_want):
    d = tempfile.mkdtemp(prefix='dnfind-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
                shutil.copy(os.path.join(out, f), d)
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(w, 'sub'))
        open(os.path.join(w, 'a.txt'), 'w').write('hay\n')
        open(os.path.join(w, 'sub', 'beta.txt'), 'w').write('a needle in it\n')
        open(os.path.join(w, 'sub', 'gamma.txt'), 'w').write('nothing here\n')
        os.environ['DNLNG'] = 'ENGLISH'
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        t.send('\x1b', 0.5)
        t.send('\x1b[18;3~', 1.0)                 # Alt+F7
        s_dlg = t.text()
        t.send(mask, 0.4)
        if text:
            t.send('\t', 0.3)
            t.send(text, 0.4)
        t.send('\r', 4.0)
        t.pump(2.0, 6)
        s_res = t.text()
        t.close(0.3)
        ok = all(x in s_res for x in want) and not any(x in s_res for x in not_want)
        return ok, ('dialog: ' + brief(s_dlg) + '\nresult: ' + brief(s_res)) if not ok else ''
    finally:
        shutil.rmtree(d, ignore_errors=True)


out = os.path.abspath(sys.argv[1])
bad = 0
for label, mask, text, want, not_want in (
        ('mask beta*', 'beta*', '', ['beta.txt'], ['gamma.txt']),
        ('mask *.txt and the text needle', '*.txt', 'needle', ['beta.txt'], ['gamma.txt'])):
    ok, info = run(out, mask, text, want, not_want)
    bad += not ok
    print('find file, %s: %s' % (label, 'ok' if ok else 'FAIL\n' + info), flush=True)
sys.exit(1 if bad else 0)
