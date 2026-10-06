#!/usr/bin/env python3
"""The sort mode letter in the corner of a panel (UTF-8 build): tools/dn-linux-sortmark.py OUTDIR
The letter is the character number SortMode of the string dlSortTag of the language: 'x' (extension) in English, the Russian and Ukrainian ones are
two bytes each in UTF-8 (an old bug took one byte of them: the corner showed a box character or a letter of another language)."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

EXPECT = {'ENGLISH': 'x', 'RUSSIAN': 'р', 'UKRAIN': 'р'}      # the default sort is by the extension


def corner(out, lang):
    d = tempfile.mkdtemp(prefix='dnsort-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
                shutil.copy(os.path.join(out, f), d)
        os.environ['DNLNG'] = lang
        t = PtyTerm(['./dn'], 100, 30, cwd=d, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        t.send('\x1b', 0.5)
        t.pump(0.5, 3)
        row = t.text().split('\n')[1]
        t.close(0.3)
        return row[0], row
    finally:
        shutil.rmtree(d, ignore_errors=True)


bad = 0
for lang, want in EXPECT.items():
    got, row = corner(os.path.abspath(sys.argv[1]), lang)
    ok = got == want
    bad += not ok
    print('%-8s corner %r want %r %s' % (lang, got, want, 'ok' if ok else 'FAIL: ' + row[:30]))
sys.exit(1 if bad else 0)
