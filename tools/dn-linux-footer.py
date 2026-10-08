#!/usr/bin/env python3
"""The line under a file panel (Linux, a pty, UTF-8 inside): tools/dn-linux-footer.py OUTDIR
  - the name of the file under the cursor: Unix has no short names, so the line shows the long name cut by columns with the mark of the cut,
    not its first 12 bytes ("averyverylon", or half of a Cyrillic name);
  - the mask of the quick search (Ctrl-S) that is longer than the line is cut by characters from the left: the end of the typed mask is
    shown whole and no character is broken."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

bad = 0
LONG_ASCII = 'averyverylongname.txt'
MASK = '\u0434\u043b\u0438\u043d\u043d\u0430\u044f-\u043c\u0430\u0441\u043a\u0430-' * 4 + '\u043a\u043e\u043d\u0435\u0446'


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


def footer(t, up=1):
    """the line under the right panel (DN starts with it active), without the frame; up=2: the divider line above it"""
    lines = t.text().split('\n')
    for i in range(len(lines) - 1, 0, -1):
        if lines[i].startswith('\u255a') or lines[i].startswith('\u2514'):
            line = lines[i - up]
            return line[len(line) // 2:].strip('\u2551')
    return ''


out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dnfooter-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    for n in (LONG_ASCII, MASK + '.txt'):
        open(os.path.join(w, n), 'w').close()
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.started()
    t.send('\x1b', 0.5)
    t.send('\x1b[B', 0.6)                          # averyverylongname.txt
    f = footer(t)
    check(f.strip().startswith('averyverylong') and '►' in f.split()[0], 'the long ASCII name is cut by the mark, not at 12 bytes: %r' % f, t.text())
    t.send('\x1b[B', 0.6)                          # the Cyrillic name (it is also the name that the quick search finds)
    f = footer(t)
    check(f.strip().startswith(MASK[:12]) and '\u25ba' in f.split()[0] and '\ufffd' not in f,
          'the long Cyrillic name is cut by columns: %r' % f, t.text())
    t.send('\x13', 0.5)                            # Ctrl-S: the quick search (the name of a file must match what is typed)
    t.send(MASK, 1.0)
    t.pump(0.5, 3)
    f = footer(t, 2)
    check(f.rstrip('\u2500 ').rstrip('*').endswith(MASK[-12:]) and '\ufffd' not in f and '\u25c4' in f,
          'the long quick search mask is cut from the left by characters: %r' % f, t.text())
    t.send('\x1b', 0.5)
    check(t.alive(), 'DN runs', t.text())
    t.close(0.3)
finally:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
