#!/usr/bin/env python3
"""The settings dialog of an archiver (Linux, a pty): tools/dn-linux-arcsetup.py OUTDIR
Options -> Archives -> ZIP opens the dialog "Archiver setup"; OK (with Enter and with the hot letter of the button, in the Russian interface Alt and a Cyrillic
letter) saves the settings to archiver.ini and returns to the panels. An access violation was there for a long time: the class migration made the old
`Done` of the object (it freed the strings of the commands) a `Free` that destroyed the archive object, and the next line saved it."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0
KEYS = {'RIGHT': '\x1b[C', 'DOWN': '\x1b[B', 'ENTER': '\r', 'F10': '\x1b[21~'}


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-700:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnarcset-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    return d, w


def open_dialog(d, w, lang):
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d})
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    # the menu Options (the sixth of the bar after the system one), the submenu Archives (the fourth item), the item ZIP (the 25th)
    for k in ['F10'] + ['RIGHT'] * 6 + ['DOWN'] * 4 + ['ENTER'] + ['DOWN'] * 24 + ['ENTER']:
        t.send(KEYS[k], 0.25)
    t.pump(0.8, 3)
    return t


out = os.path.abspath(sys.argv[1])
for lang, ok_keys in (('ENGLISH', ['\r']), ('RUSSIAN', ['\r', '\x1b\u043a']), ('UKRAIN', ['\r', '\x1b\u043a'])):
    for key in ok_keys:
        d, w = install(out)
        try:
            t = open_dialog(d, w, lang)
            check('PKZIP' in t.text(), '%s: the dialog of ZIP opens' % lang, t.text())
            t.send(key, 1.0)
            t.pump(0.5, 2)
            text = t.text()
            check(t.alive() and 'Fatal Error' not in text and 'PKZIP' not in text, '%s: OK (%r) closes the dialog without an error' % (lang, key), text)
            ini = os.path.join(d, 'archiver.ini')
            check(os.path.isfile(ini) and 'zip' in open(ini, errors='replace').read().lower(), '%s: archiver.ini has the settings of ZIP' % lang)
            t.close(0.3)
        finally:
            shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
