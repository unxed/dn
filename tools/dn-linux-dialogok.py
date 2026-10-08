#!/usr/bin/env python3
"""Dialogs that ended in an access violation after the class migration (Linux, a pty): tools/dn-linux-dialogok.py OUTDIR
In the old code a constructor was called on the variable (`New(P, Init(R))`); the migration wrote `P.Create(R)`, which does not store the new object in P (FPC allocates one
and drops it): the variable stayed nil. The places that hand-testing and the sweep of the hot letters found:
  - File attributes of several files (Alt-E), OK: the progress window `PInfo.Create(R)`;
  - the in-place rename (Shift-F6): the input line `PIF.Create(R, 255)`;
  - the list of windows (Alt-0), the Delete key (Close): the collection `PC.Create(10, 10)` on a collection that the list had freed;
  - the phone book (search, import, dial) had the same pattern (no pty scenario: it needs a phone book; the code is covered by the build)."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


def fine(t):
    text = t.text()
    return t.alive() and 'Fatal Error' not in text and 'Runtime error' not in text


out = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp(prefix='dnok-')
try:
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    for n in ('a.txt', 'b.txt'):
        open(os.path.join(w, n), 'w').write('x')
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    t.send('\x1b[B', 0.3)                                           # a.txt
    t.send('\x1b[2~', 0.3)
    t.send('\x1b[2~', 0.3)                                          # a.txt and b.txt are selected
    t.send('\x1be', 1.0)                                            # Alt-E: File attributes
    check('File Attributes' in t.text(), 'Alt-E opens the attributes of the selected files', t.text())
    t.send('\r', 1.5)
    check(fine(t) and 'File Attributes' not in t.text(), 'OK of the attributes of several files does not stop DN', t.text())

    t.send('\x1b[17;2~', 1.0)                                       # Shift-F6: the rename in the line of the panel
    t.send('X', 0.4)
    t.send('\r', 1.2)
    check(fine(t) and os.path.exists(os.path.join(w, 'X')) and len(os.listdir(w)) == 2, 'Shift-F6, a new name, Enter: the file under the cursor is renamed',
          t.text() + repr(os.listdir(w)))

    t.send('\x1b0', 1.0)                                            # Alt-0: the list of windows
    check('Window' in t.text() or 'Windows' in t.text(), 'Alt-0 opens the list of windows', t.text())
    t.send('\x1b[3~', 1.2)                                          # Del: Close
    t.pump(0.5, 2)
    check(fine(t), 'Del (Close) in the list of windows does not stop DN', t.text())
    t.close(0.3)
finally:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
