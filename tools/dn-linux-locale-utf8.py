#!/usr/bin/env python3
"""The build with UTF-8 inside under locales that are not UTF-8 (Linux, a pty): tools/dn-linux-locale-utf8.py OUTDIR
The names of files and the typed text are UTF-8 whatever the locale says (C, POSIX, KOI8-R); under a Latin-1 locale DN stays alive and ASCII works
(a terminal that sends UTF-8 to a program that thinks it is Latin-1 is a mistake of the setup, not shown as a fault of DN)."""
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
            print('    | ' + info[-600:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnloc8-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    open(os.path.join(w, '\u0424\u0430\u0439\u043b.txt'), 'w').write('x')
    return d, w


def cmdline(text):
    return [l for l in text.split('\n') if l.startswith('/') and '>' in l][:1]


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    for loc, utf8_ok in (('C', True), ('POSIX', True), ('ru_RU.KOI8-R', True), ('ru_RU.UTF-8', True), ('en_US.UTF-8', True), ('en_US.ISO-8859-1', False)):
        d, w = install(out); dirs.append(d)
        e = {'DNLNG': 'ENGLISH', 'DN2': d, 'LC_ALL': loc, 'LANG': loc, 'LC_CTYPE': loc}
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env=e)
        t.started()
        t.send('\x1b', 0.5)
        text = t.text()
        check('\u0424\u0430\u0439\u043b' in text, '%s: a file with a Russian name is shown' % loc, text)
        t.send('\u043f\u0440\u0438\u0432\u0435\u0442 abc', 0.6)
        line = cmdline(t.text())
        if utf8_ok:
            check(line and line[0].endswith('\u043f\u0440\u0438\u0432\u0435\u0442 abc'), '%s: typed Russian text reaches the command line' % loc, str(line))
        else:
            check(line and line[0].endswith('abc'), '%s: ASCII typed after other text reaches the command line' % loc, str(line))
        if utf8_ok:
            t.send('\x15', 0.3)                                       # Ctrl-U: clears the command line
            t.send('\x1b[18~', 0.6)                                   # F7: make a directory
            t.send('\u041a\u0430\u0442\u0430\u043b\u043e\u0433', 0.6)
            t.send('\r', 1.0)
            check(os.path.isdir(os.path.join(w, '\u041a\u0430\u0442\u0430\u043b\u043e\u0433')), '%s: a directory with a Russian name is made through a dialog' % loc, t.text())
        check(t.alive() and 'Fatal' not in t.text(), '%s: DN is alive' % loc)
        t.close(0.3)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
