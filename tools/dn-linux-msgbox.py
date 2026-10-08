#!/usr/bin/env python3
"""The title and the buttons of a message box in the language of DN (Linux, a pty): tools/dn-linux-msgbox.py OUTDIR
Alt-X asks "Do you wish to quit?" in a message box of tv/; its title and its buttons were the English texts of tv/ in every language.
For each language the title and the buttons must be those of the resources, the hot letter of No must close the box and leave DN running,
and the hot letter of Yes must end DN."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0
# language: (title, yes, no, the hot letter of no, the hot letter of yes)
LANGS = {
    'ENGLISH': ('Confirm', 'Yes', 'No', 'n', 'y'),
    'RUSSIAN': ('Подтверждение', 'Да', 'Нет',
                'н', 'д'),
    'UKRAIN': ('Підтвердження', 'Так', 'Ні',
               'н', 'т'),
}


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


def start(out, lang):
    d = tempfile.mkdtemp(prefix='dnmsgbox-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d})
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    return d, t


def box_lines(text, title):
    lines = text.split('\n')
    for i, l in enumerate(lines):
        if title in l:
            return '\n'.join(lines[i:i + 10])
    return ''


out = os.path.abspath(sys.argv[1])
for lang, (title, yes, no, no_key, yes_key) in LANGS.items():
    d, t = start(out, lang)
    try:
        t.send('\x1bx', 0.8)
        text = t.text()
        box = box_lines(text, title)
        check(box != '', '%s: the title of the quit box is %r' % (lang, title), text)
        check(' %s ' % yes in box and ' %s ' % no in box, '%s: the buttons are %r and %r' % (lang, yes, no), box or text)
        t.send(no_key, 0.8)
        text = t.text()
        check(t.alive() and title not in text, '%s: %r (No) closes the box, DN runs' % (lang, no_key), text)
        t.send('\x1bx', 0.8)
        t.send(yes_key, 0.5)
        t.pump(0.5, 3)
        check(not t.alive(), '%s: %r (Yes) ends DN' % (lang, yes_key), t.text())
        t.close(0.3)
    finally:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
