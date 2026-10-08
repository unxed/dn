#!/usr/bin/env python3
"""Configured-startup panel visibility (issue #6).

With a shared dn.ini, panels must be visible before any key; F10+Right must
still show them. Usage: tools/dn-linux-startup.py OUTDIR
"""
import hashlib
import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

F10, RIGHT = '\x1b[21~', '\x1b[C'
EXPECTED_INI = '1a9b0b2b63ba27eb9324c3a09587ac337426756e174ba77f60ef05a8ab52ad9f'
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


def main():
    out = os.path.abspath(sys.argv[1])
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ini_src = os.path.join(repo, 'dist', 'linux64', 'dn.ini')
    digest = hashlib.sha256(open(ini_src, 'rb').read()).hexdigest()
    check(digest == EXPECTED_INI, 'shared dn.ini hash', digest)

    d = tempfile.mkdtemp(prefix='dnstartup-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
            elif f == 'xlt':
                shutil.copytree(os.path.join(out, f), os.path.join(d, 'xlt'))
        shutil.copy(ini_src, os.path.join(d, 'dn.ini'))
        w = os.path.join(d, 'work')
        os.makedirs(w)
        open(os.path.join(w, 'a.txt'), 'w').write('x\n')

        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.started()
        before = t.text()
        check(panel_paths(before) >= 2 and has_listing(before),
              'configured start: panel headers and listing before any key', before)
        t.send(F10, 0.35)
        t.send(RIGHT, 0.35)
        after = t.text()
        check(panel_paths(after) >= 2 and has_listing(after),
              'configured start: panels still visible after F10+Right', after)
        t.close(3)
    finally:
        shutil.rmtree(d, ignore_errors=True)

    print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
    sys.exit(1 if fails else 0)


if __name__ == '__main__':
    main()
