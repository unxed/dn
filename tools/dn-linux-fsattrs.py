#!/usr/bin/env python3
"""Symbolic links and permissions in the panels of DN on Linux: tools/dn-linux-fsattrs.py OUTDIR
Each case is a start of DN on a small tree, some keys, and the result is checked on the file system:
  - the panel lists a link to a file, a link to a directory and a dangling link; Enter on the link to a directory enters it;
  - a fresh start lists the dot files (the setting "show hidden files" is on by default on Unix); a saved setup with it off (Options, File Manager, Setup) hides them;
  - F5 of a link to a file makes a regular file with the content of the target;
  - F5 of a read-only file (mode 444) makes a read-only file (the attribute ReadOnly of DOS is the write permission of the owner);
  - F8 of a link removes the link and not its target; F8 of a read-only file asks, and removes it after Yes;
  - a link to a directory is a link for the operations on trees: F8 of a directory that holds one removes the link and not the files of its target
    (they were deleted), F5 of such a directory copies the link (a link to `..` made the copy endless), F5 and F8 of the link itself act on the link,
    Find File does not enter it (a link to `..` gave the same file again and again); F5 of a directory (with no link) does not stop DN (an access
    violation at the end of every copy of a directory);
  - F6 to another file system (/dev/shm when it is one) moves a file and a directory with a link in it (the rename gave EXDEV, which DN did not
    take for "another device": the file stayed silently, the directory gave an error)."""
import os, re, shutil, stat, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

K = {'F6': '\x1b[17~', 'ALT-F7': '\x1b[18;3~', 'ENTER': '\r', 'ESC': '\x1b', 'HOME': '\x1b[H', 'DOWN': '\x1b[B', 'TAB': '\t', 'F5': '\x1b[15~', 'F8': '\x1b[19~', 'ALT-O': '\x1bo', 'SPACE': ' '}
bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info.replace('\n', '\n    | ')[:1500], flush=True)


def case(out, setup, keys, d=None, quit=False):
    """starts DN in a tree made by setup(work), sends the keys, returns (work, screen text);
    d: the directory of an earlier case (its saved setup is used again); quit: DN exits by Alt-X (the setup is saved)"""
    if d is None:
        d = tempfile.mkdtemp(prefix='dnfsattr-')
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')):
                shutil.copy(os.path.join(out, f), d)
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(w, 'dst'))
        setup(w)
    w = os.path.join(d, 'work')
    os.environ['DNLNG'] = 'ENGLISH'
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
    # the clock of the menu bar writes every second: wait for a screen that stays the same (settle), not for silence
    t.settle(1.0, 6)
    t.key('\x1b', 0.5)
    for k in keys.split():
        t.key(K.get(k, k), 0.8)
    t.settle(1.0, 3)
    text = t.text()
    alive = t.alive()
    if quit:
        t.key('\x1bx', 0.8)
        t.key('\r', 0.8)
        for _ in range(20):
            if not t.alive():
                break
            t.pump(0.3, 1)
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
check(alive and re.search(r'work[\\/]dlink', text) and re.search(r'in\s+txt', text) is not None, 'Enter on a link to a directory enters it', text)

# dot files: listed by a fresh start; a saved setup with "show hidden files" off hides them
def tree_dot(w):
    files(w, '.hidden', 'plain.txt')


d, w, text, alive = case(out, tree_dot, '')
dirs.append(d)
# the name and the extension of a dot file: tools/dn-linux-dotfiles.py
check(alive and '.hidden' in text and 'plain' in text, 'a fresh start lists a dot file in the panel', text)
# the check box "Show hidden files" of the dialog (the fifth of the group "Display", the fifth stop of Tab) off, OK; then Alt-X saves the setup
d, w, text, alive = case(out, tree_dot, 'ALT-O f s TAB TAB TAB TAB DOWN DOWN DOWN DOWN SPACE ENTER', quit=True)
dirs.append(d)
check(alive, 'the setting "Show hidden files" switched off in the dialog', text)
d, w, text, alive = case(out, tree_dot, '', d=d)
check(alive and 'hid' not in text and 'plain' in text, 'the saved setting wins over the default at the next start', text)

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

# links to directories in the operations on trees: the target (outside of the work directory) must stay as it is
def outside(w):
    o = os.path.join(os.path.dirname(w), 'outside')
    os.makedirs(o, exist_ok=True)
    open(os.path.join(o, 'keep.txt'), 'w').write('keep\n')
    return o


def tree_dir_with_link(w):
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'sub', 'in.txt'), 'w').write('inner\n')
    os.symlink(outside(w), os.path.join(w, 'sub', 'out'))


def tree_dir_with_loop(w):
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'sub', 'in.txt'), 'w').write('inner\n')
    os.symlink('..', os.path.join(w, 'sub', 'loop'))


def tree_top_link(w):
    os.symlink(outside(w), os.path.join(w, 'top'))


def kept(w):
    return os.path.isfile(os.path.join(os.path.dirname(w), 'outside', 'keep.txt'))


d, w, text, alive = case(out, tree_dir_with_link, 'HOME DOWN DOWN F8 ENTER ENTER')       # .., dst, sub; the second Enter: "is not empty"
dirs.append(d)
check(alive and not os.path.lexists(os.path.join(w, 'sub')), 'F8 of a directory with a link to a directory removes the directory', text)
check(kept(w), 'F8 of a directory with a link to a directory keeps the files of the target', text)
d, w, text, alive = case(out, tree_dir_with_link, 'HOME DOWN DOWN F5 dst ENTER')
dirs.append(d)
p = os.path.join(w, 'dst', 'sub')
check(alive and os.path.isfile(os.path.join(p, 'in.txt')) and os.path.islink(os.path.join(p, 'out')) and kept(w),
      'F5 of a directory copies a link to a directory as a link', text)
check(not os.path.exists(os.path.join(d, 'crash')), 'F5 of a directory does not stop DN (no crash report)', text)
d, w, text, alive = case(out, tree_dir_with_loop, 'HOME DOWN DOWN F5 dst ENTER')
dirs.append(d)
p = os.path.join(w, 'dst', 'sub')
check(alive and os.path.islink(os.path.join(p, 'loop')) and os.readlink(os.path.join(p, 'loop')) == '..',
      'F5 of a directory with a link to .. copies the link once', text)
d, w, text, alive = case(out, tree_dir_with_loop, 'ALT-F7 *.txt ENTER')
dirs.append(d)
check(alive and len(re.findall(r'\bin\s+txt', text)) == 1, 'Find File does not enter a link to .. (in.txt is found once)', text)
d, w, text, alive = case(out, tree_top_link, 'HOME DOWN DOWN F8 ENTER')               # .., dst, top
dirs.append(d)
check(alive and not os.path.lexists(os.path.join(w, 'top')) and kept(w), 'F8 of a link to a directory removes the link, not the files of the target', text)
d, w, text, alive = case(out, tree_top_link, 'HOME DOWN DOWN F5 dst ENTER')
dirs.append(d)
check(alive and os.path.islink(os.path.join(w, 'dst', 'top')) and os.path.islink(os.path.join(w, 'top')) and kept(w),
      'F5 of a link to a directory makes a link', text)

# F6 to another file system: a copy and a delete
def tree_move(w):
    tree_dir_with_link(w)
    open(os.path.join(w, 'f.txt'), 'w').write('file\n')


if os.path.isdir('/dev/shm') and os.stat('/dev/shm').st_dev != os.stat(tempfile.gettempdir()).st_dev:
    for name, keys in (('f.txt', 'HOME DOWN DOWN DOWN F6'), ('sub', 'HOME DOWN DOWN F6')):       # .., dst, sub, f.txt
        other = tempfile.mkdtemp(prefix='dnfsattr-mv-', dir='/dev/shm')
        d, w, text, alive = case(out, tree_move, keys + ' ' + other + '/ ENTER ENTER')
        dirs.extend([d, other])
        moved = os.path.join(other, name)
        if name == 'f.txt':
            ok = os.path.isfile(moved) and not os.path.exists(os.path.join(w, name))
        else:
            ok = (os.path.isfile(os.path.join(moved, 'in.txt')) and os.path.islink(os.path.join(moved, 'out')) and
                  not os.path.lexists(os.path.join(w, name)) and kept(w))
        check(alive and ok, 'F6 of %s to another file system moves it' % name, text)
else:
    print('SKIP F6 to another file system: /dev/shm is not one', flush=True)

for d in dirs:
    shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
