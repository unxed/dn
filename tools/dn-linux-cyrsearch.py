#!/usr/bin/env python3
"""Search for Cyrillic text in the editor and the viewer (Linux, a pty, the build with UTF-8 inside): tools/dn-linux-cyrsearch.py OUTDIR
The input sites that take the typed text of a search (PLAN.md, the problems of the 2.20 alpha, item 2): the editor (F4, F7) finds a Cyrillic word
in a UTF-8 file and puts the cursor on it; the viewer (F3, F7) finds it too."""
import os, re, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0
TEXT = '\u043f\u0435\u0440\u0432\u0430\u044f \u0441\u0442\u0440\u043e\u043a\u0430\n\u0432\u0442\u043e\u0440\u0430\u044f \u0441\u0442\u0440\u043e\u043a\u0430 \u043c\u0438\u0440\n\u0442\u0440\u0435\u0442\u044c\u044f\n'
WORD = '\u043c\u0438\u0440'


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dncyr-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    open(os.path.join(w, 'b.txt'), 'wb').write(TEXT.encode('utf-8'))
    for key, name in (('\x1bOS', 'editor (F4)'), ('\x1bOR', 'viewer (F3)')):
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
        t.pump(1.5, 6)
        t.send('\x1b', 0.5)
        t.send('\x1b[B', 0.3)                                   # b.txt
        t.send(key, 1.5)
        check('\u043f\u0435\u0440\u0432\u0430\u044f' in t.text(), '%s: the Cyrillic text is shown' % name, t.text())
        t.send('\x1b[18~', 0.8)                                 # F7
        t.send('\x15', 0.1)
        for ch in WORD:
            t.send(ch, 0.15)
        check(WORD in t.text(), '%s: the Cyrillic word is typed into the search line' % name, t.text())
        t.send('\r', 1.0)
        t.pump(0.5, 2)
        text = t.text()
        if name.startswith('editor'):
            m = re.search(r'(\d+):(\d+)\s*[\u2550\u2500]*\[', text)
            check(m is not None and m.group(1) == '2', '%s: the cursor is on the line with the word' % name, text)
        else:
            check('Fatal' not in text and t.alive() and WORD in text, '%s: the search ends with the word on the screen' % name, text)
        t.send('\x1b', 0.4)
        t.send('\x1b', 0.4)
        t.close(0.3)
finally:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
