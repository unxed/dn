#!/usr/bin/env python3
"""The editor of the environment variables of the OS (Linux, a pty): tools/dn-linux-envedit.py OUTDIR
Utilities -> the editor of the environment (Alt-U, O in the Russian and Ukrainian interface). The list shows the variables of the process; OK (Alt and the
hot letter, or Enter) keeps the changes and returns to the panels. The input line of the value is a short string (255 characters) and was read into the AnsiString
of the variable with Move: the heap was overwritten and OK ended with an access violation."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


out = os.path.abspath(sys.argv[1])
for lang, keys, title, ok_keys in (('RUSSIAN', ['\x1b\u0443', '\u043e'], '\u0420\u0435\u0434\u0430\u043a\u0442\u043e\u0440 \u043f\u0435\u0440\u0435\u043c\u0435\u043d\u043d\u044b\u0445', ['\r', '\x1bK']),
                                   ('UKRAIN', ['\x1b\u0443', '\u043e'], '', ['\r'])):
    for ok_key in ok_keys:
        d = tempfile.mkdtemp(prefix='dnenv-')
        try:
            for f in os.listdir(out):
                if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
                    src = os.path.join(out, f)
                    (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
            w = os.path.join(d, 'work')
            os.makedirs(w)
            t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'),
                        env={'DNLNG': lang, 'DN2': d, 'DN_ENV_TEST_VAR': 'some value'})
            t.started()
            t.send('\x1b', 0.5)
            before = t.text()
            for k in keys:
                t.send(k, 0.6)
            t.pump(0.5, 2)
            opened = t.text() != before and (not title or title in t.text())
            check(opened, '%s: the editor of the environment opens' % lang, t.text())
            t.send(ok_key, 1.0)
            t.pump(0.5, 2)
            text = t.text()
            check(t.alive() and 'Fatal Error' not in text and 'Runtime error' not in text and (not title or title not in text),
                  '%s: OK (%r) closes the editor without an error' % (lang, ok_key), text)
            t.close(0.3)
        finally:
            shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
