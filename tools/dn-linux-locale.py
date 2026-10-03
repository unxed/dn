#!/usr/bin/env python3
"""The single-byte code page of DN by the locale of the host (TvLocale): the names of files are shown in the page that goes with LANG.
usage: tools/dn-linux-locale.py OUTDIR   (OUTDIR: the result of tools/build.sh linux|linux64)"""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

CASES = [  # LANG, extra env, names that must be seen, names that must not be seen
    ('de_DE.UTF-8', {}, ['Größe', 'Ünï'], ['Привет']),   # 850: German letters, no Cyrillic
    ('ru_RU.UTF-8', {}, ['Привет'], ['Größe']),                    # 866: Cyrillic, no German letters
    ('en_US.UTF-8', {}, ['Größe', 'Ünï'], ['Привет']),   # 437
    ('de_DE.UTF-8', {'DN_CODEPAGE': '866'}, ['Привет'], []),                  # DN_CODEPAGE wins
    ('de_DE.UTF-8', {'LC_CTYPE': 'C.UTF-8'}, ['Größe'], []),                                      # C.UTF-8 says nothing: LANG is used
]
fails = 0
out = os.path.abspath(sys.argv[1])
for lang, extra, want, notwant in CASES:
    d = tempfile.mkdtemp(prefix='dnloc-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
        w = os.path.join(d, 'work')
        for n in ('Größe', 'Привет'):
            os.makedirs(os.path.join(w, n))
        open(os.path.join(w, 'Ünï.txt'), 'w').close()
        env = {'LANG': lang}
        env.update(extra)
        t = PtyTerm(['./dn'], 100, 30, env=env, cwd=w, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        t.send('\x1b', 0.5)
        text = t.text()
        t.close(0.3)
        ok = all(x in text for x in want) and not any(x in text for x in notwant)
        print(('PASS ' if ok else 'FAIL ') + '%s %s' % (lang, extra or ''))
        if not ok:
            fails += 1
            print(text)
    finally:
        shutil.rmtree(d, ignore_errors=True)
print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
