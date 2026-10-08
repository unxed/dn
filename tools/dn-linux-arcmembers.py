#!/usr/bin/env python3
"""Add and delete the members of an archive (Linux, a pty, checked on the archive itself): tools/dn-linux-arcmembers.py OUTDIR
  - F8 on a member of a zip (the panel is inside the archive) deletes that member and leaves the others;
  - F5 from the other panel adds a file to the archive that the panel shows (the archiver is the system `zip`; skipped without it);
  - the archive panel still shows what the archive had (DN does not reread it after an add: Ctrl-R does)."""
import os, shutil, sys, tempfile, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-700:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnarcm-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    return d, w


def start(d, w):
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d})
    t.started()
    t.send('\x1b', 0.5)
    return t


def names(path):
    with zipfile.ZipFile(path) as z:
        return sorted(z.namelist())


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    # delete: the active panel enters a.zip (the order of the panel: .., a.zip), the cursor on the first member after .., F8, Yes
    d, w = install(out); dirs.append(d)
    with zipfile.ZipFile(os.path.join(w, 'a.zip'), 'w') as z:
        z.writestr('x.txt', 'xx\n')
        z.writestr('y.txt', 'yy\n')
    t = start(d, w)
    t.send('\x1b[B', 0.4); t.send('\r', 2.0)
    check('x' in t.text() and 'txt' in t.text(), 'the archive is entered and lists its members', t.text())
    t.send('\x1b[B', 0.3); t.send('\x1b[19~', 1.2)
    check('delete' in t.text().lower() and 'x.txt' in t.text(), 'F8 asks about the member x.txt', t.text())
    t.send('\r', 2.5)
    check(names(os.path.join(w, 'a.zip')) == ['y.txt'], 'the member is deleted from the archive and the other stays', str(names(os.path.join(w, 'a.zip'))))
    check(t.alive() and 'Fatal' not in t.text(), 'DN is alive after the delete', t.text())
    t.close(0.3)

    # add: the left panel enters a.zip, the right one has new.txt: F5, the archiver dialog, Enter
    if shutil.which('zip'):
        d, w = install(out); dirs.append(d)
        with zipfile.ZipFile(os.path.join(w, 'a.zip'), 'w') as z:
            z.writestr('x.txt', 'xx\n')
        open(os.path.join(w, 'new.txt'), 'w').write('brand new\n')
        t = start(d, w)
        t.send('\t', 0.4); t.send('\x1b[B', 0.3); t.send('\x1b[B', 0.3); t.send('\r', 2.0)       # the left panel: .., new.txt, a.zip -> into a.zip
        t.send('\t', 0.4); t.send('\x1b[B', 0.3)                                                   # the right panel: the cursor on new.txt
        t.send('\x1b[15~', 1.2)
        check('ZIP:' in t.text() and 'Copy file new.txt' in t.text(), 'F5: the copy dialog names new.txt and the archive', t.text())
        t.send('\r', 2.5)
        check('Archive files' in t.text(), 'the dialog of the archiver follows', t.text())
        t.send('\r', 4.0)
        got = names(os.path.join(w, 'a.zip'))
        check(got == ['new.txt', 'x.txt'], 'the file is added to the archive and the old member stays', str(got))
        if 'new.txt' in got:
            with zipfile.ZipFile(os.path.join(w, 'a.zip')) as z:
                check(z.read('new.txt') == b'brand new\n', 'the added member has the content of the file')
        check(t.alive() and 'Fatal' not in t.text(), 'DN is alive after the add', t.text())
        t.send('\t', 0.5); t.send('\x12', 2.0)                                                     # Ctrl-R in the archive panel
        check('new' in t.text(), 'Ctrl-R: the archive panel shows the added member', t.text())
        t.close(0.3)
    else:
        print('SKIP the add: no zip program')
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
