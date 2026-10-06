#!/usr/bin/env python3
"""Symbolic links and permissions in the panels of DN on Linux: tools/dn-linux-fsattrs.py OUTDIR
Each case is a start of DN on a small tree, some keys, and the result is checked on the file system:
  - the panel lists a link to a file, a link to a directory and a dangling link; Enter on the link to a directory enters it;
  - F5 of a link to a file makes a regular file with the content of the target;
  - F5 of a read-only file (mode 444) makes a read-only file (the attribute ReadOnly of DOS is the write permission of the owner);
  - F8 of a link removes the link and not its target; F8 of a read-only file asks, and removes it after Yes."""
import os, re, shutil, stat, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

K = {'ENTER': '\r', 'ESC': '\x1b', 'HOME': '\x1b[H', 'DOWN': '\x1b[B', 'TAB': '\t', 'F5': '\x1b[15~', 'F8': '\x1b[19~'}
bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info.replace('\n', '\n    | ')[:1500], flush=True)


def case(out, setup, keys):
    """starts DN in a tree made by setup(work), sends the keys, returns (work, screen text)"""
    d = tempfile.mkdtemp(prefix='dnfsattr-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
            shutil.copy(os.path.join(out, f), d)
    w = os.path.join(d, 'work')
    os.makedirs(os.path.join(w, 'dst'))
    setup(w)
    os.environ['DNLNG'] = 'ENGLISH'
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    for k in keys.split():
        t.send(K.get(k, k), 1.2)
    t.pump(1.0, 3)
    text = t.text()
    alive = t.alive()
    t.close(0.3)
    return d, w, text, alive


def files(w, *names):
    for n in names:
        open(os.path.join(w, n), 'w').write('target\n')


out = os.path.abspath(sys.argv[1])
dirs = []

# the listing and Enter on a link to a directory
def tree_links(w):
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'sub', 'in.txt'), 'w').write('inner\n')
    files(w, 'target.txt')
    os.symlink('target.txt', os.path.join(w, 'link.txt'))
    os.symlink('sub', os.path.join(w, 'dlink'))
    os.symlink('nowhere', os.path.join(w, 'broken'))


d, w, text, alive = case(out, tree_links, '')
dirs.append(d)
check(alive and all(n in text for n in ('dlink', 'broken', 'link', 'target')), 'the panel lists the links, the dangling one too', text)
d, w, text, alive = case(out, tree_links, 'HOME DOWN ENTER')       # .., dlink
dirs.append(d)
check(alive and 'work\\dlink' in text and re.search(r'in\s+txt', text) is not None, 'Enter on a link to a directory enters it', text)

# F5 of a link to a file: the content of the target in a regular file
def tree_one_link(w):
    files(w, 'target.txt')
    os.symlink('target.txt', os.path.join(w, 'link.txt'))


d, w, text, alive = case(out, tree_one_link, 'HOME DOWN DOWN F5 dst ENTER')       # .., dst, link
dirs.append(d)
p = os.path.join(w, 'dst', 'link.txt')
check(os.path.isfile(p) and not os.path.islink(p) and open(p).read() == 'target\n', 'F5 of a link to a file makes a regular file with the content', text)
check(os.path.islink(os.path.join(w, 'link.txt')), 'the link itself is as it was')

# F5 of a read-only file
def tree_ro(w):
    p = os.path.join(w, 'ro.txt')
    open(p, 'w').write('read only\n')
    os.chmod(p, 0o444)


d, w, text, alive = case(out, tree_ro, 'HOME DOWN DOWN F5 dst ENTER')        # .., dst, ro
dirs.append(d)
p = os.path.join(w, 'dst', 'ro.txt')
check(os.path.isfile(p) and open(p).read() == 'read only\n', 'F5 of a read-only file copies the content', text)
check(os.path.isfile(p) and (os.stat(p).st_mode & 0o222) == 0, 'the copy of a read-only file is read-only', text)

# F8 of a link: the target stays
d, w, text, alive = case(out, tree_one_link, 'HOME DOWN DOWN F8 ENTER')       # .., dst, link
dirs.append(d)
check(not os.path.lexists(os.path.join(w, 'link.txt')) and os.path.isfile(os.path.join(w, 'target.txt')), 'F8 of a link removes the link, not the target', text)

# F8 of a read-only file: the usual question, then "marked as Read-Only. OK to delete it?"; Yes to both removes it
d, w, text, alive = case(out, tree_ro, 'HOME DOWN DOWN F8 ENTER')
dirs.append(d)
check('Read-Only' in text and os.path.exists(os.path.join(w, 'ro.txt')), 'F8 of a read-only file asks about the attribute after the first question', text)
d, w, text, alive = case(out, tree_ro, 'HOME DOWN DOWN F8 ENTER ENTER')
dirs.append(d)
check(not os.path.exists(os.path.join(w, 'ro.txt')), 'a read-only file is removed after both confirmations', text)

for d in dirs:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
