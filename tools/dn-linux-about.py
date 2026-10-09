#!/usr/bin/env python3
"""Virgin first-launch About residue (issue #6 sibling of configured blank panels).

No dn.ini: About must appear; after Esc and after Enter, About markers must be
gone and panel listings must remain. Usage: tools/dn-linux-about.py OUTDIR
"""
import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

ESC, ENTER, ALT_X = '\x1b', '\r', '\x1bx'
ABOUT_MARKERS = ('Based on', 'DN/2 Open Source', 'FREEWARE', 'dnosp.ru')
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


def panel_paths(text):
    n = 0
    for line in text.split('\n')[:5]:
        n += len(re.findall(r'(?:[A-Za-z]:\\|/)[^\s═╗]+', line))
    return n


def has_listing(text):
    return ('a             txt' in text) or ('a.txt' in text) or ('..' in text)


def about_visible(text):
    return any(m in text for m in ABOUT_MARKERS)


def copy_runtime(out, dest):
    for f in os.listdir(out):
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(os.path.join(out, f), dest)
        elif f == 'xlt':
            shutil.copytree(os.path.join(out, f), os.path.join(dest, 'xlt'))


def wait_about(t, seconds=8.0):
    steps = max(1, int(seconds / 0.2))
    for _ in range(steps):
        t.pump(0.2, 0.2)
        if about_visible(t.text()):
            return True
    return about_visible(t.text())


def virgin_close(out, close_key, label):
    d = tempfile.mkdtemp(prefix='dnabout-')
    try:
        copy_runtime(out, d)
        # deliberately no dn.ini -> Virgin := True -> cmAbout
        w = os.path.join(d, 'work')
        os.makedirs(w)
        open(os.path.join(w, 'a.txt'), 'w').write('x\n')
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        shown = wait_about(t)
        during = t.text()
        check(shown, 'virgin: About visible before %s' % label, during)
        t.send(close_key, 1.0)
        t.pump(0.5, 0.5)
        after = t.text()
        check(not about_visible(after),
              'virgin: no About residue after %s' % label, after)
        check(panel_paths(after) >= 2 and has_listing(after),
              'virgin: panels/listing after About %s' % label, after)
        t.send(ALT_X, 0.2)
        t.send(ENTER, 0.4)
        t.close(2)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    if len(sys.argv) < 2:
        print('usage: tools/dn-linux-about.py OUTDIR', file=sys.stderr)
        sys.exit(2)
    out = os.path.abspath(sys.argv[1])
    virgin_close(out, ESC, 'Esc')
    virgin_close(out, ENTER, 'Enter')
    print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
