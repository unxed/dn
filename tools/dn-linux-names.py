#!/usr/bin/env python3
"""Names with spaces, a missing directory, DN_RUN_PAUSE and an archive in an archive (Linux, a pty, checked on the file system): tools/dn-linux-names.py OUTDIR
  - DN_RUN_PAUSE: 1 waits for Enter after a command (the output of the shell stays), 0 goes back to the panels at once, 2 waits only when the status is not 0;
  - a directory and files with spaces in the names: enter, make a directory, copy, delete;
  - a missing directory: `cd` to a directory that is not there, and a directory that is removed under the panel: DN stays alive;
  - a zip in a zip: the inner archive is entered and its member is listed."""
import os, shutil, sys, tempfile, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm, side_by_side

F = {'F3': '\x1bOR', 'F5': '\x1b[15~', 'F7': '\x1b[18~', 'F8': '\x1b[19~', 'F10': '\x1b[21~', 'DOWN': '\x1b[B', 'UP': '\x1b[A', 'ENTER': '\r',
     'HOME': '\x1b[H', 'ESC': '\x1b', 'CTRL-R': '\x12', 'ALT-X': '\x1bx'}
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name, flush=True)
    if not cond:
        fails += 1
        if info:
            print(info[-900:], flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnnames-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    return d, w


def run(d, w, env=None):
    e = {'DNLNG': 'ENGLISH', 'DN2': d, 'HOME': d}
    e.update(env or {})
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env=e)
    t.started()
    t.send(F['ESC'], 0.5)
    return t


def key(t, k, settle=0.6):
    t.send(F.get(k, k), settle)


def panels(text):
    return 'F10 Menu' in text and ('Name' in text)


def run_pause(out, pause, cmd, waits):
    """DN_RUN_PAUSE"""
    d, w = install(out)
    try:
        t = run(d, w, {'DN_RUN_PAUSE': pause})
        key(t, cmd, 0.4); key(t, 'ENTER', 1.5)
        text = t.text()
        if waits:
            check('hello-from-dn' in text and not panels(text), 'DN_RUN_PAUSE=%s, "%s": waits for Enter, the output of the shell is on the screen' % (pause, cmd), text)
            key(t, 'ENTER', 0.8)
            check(panels(t.text()), 'DN_RUN_PAUSE=%s, "%s": Enter brings the panels back' % (pause, cmd), t.text())
        else:
            check(panels(text), 'DN_RUN_PAUSE=%s, "%s": back to the panels at once' % (pause, cmd), text)
        t.close(0.5)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def spaces(out):
    """names with spaces"""
    d, w = install(out)
    try:
        os.makedirs(os.path.join(w, 'my dir'))
        open(os.path.join(w, 'my dir', 'c d.txt'), 'w').write('inner\n')
        open(os.path.join(w, 'a b.txt'), 'w').write('with a space\n')
        t = run(d, w)
        check('my dir' in t.text(), 'a directory with a space in its name is listed', t.text())
        key(t, 'HOME'); key(t, 'DOWN'); key(t, 'ENTER', 1.0)
        check('my dir' in t.text(), 'Enter: the directory "my dir" is entered (the title of the panel)', t.text())
        key(t, 'HOME'); key(t, 'DOWN')
        key(t, 'F5'); key(t, '..', 0.3); key(t, 'ENTER', 1.2)
        check(os.path.isfile(os.path.join(w, 'c d.txt')) and open(os.path.join(w, 'c d.txt')).read() == 'inner\n',
              'F5: "c d.txt" is copied one directory up', t.text())
        key(t, 'ALT-X', 0.5); key(t, 'ENTER', 0.8)
        t.close(0.5)
        t = run(d, w)
        key(t, 'F7'); key(t, 'new dir'); key(t, 'ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, 'new dir')), 'F7: a directory with a space in its name is made', t.text())
        names = sorted(os.listdir(w))
        # the order of the panel: .., directories (new dir, my dir), then the files (a b.txt, c d.txt)
        key(t, 'HOME')
        for _ in range(3):
            key(t, 'DOWN', 0.3)
        key(t, 'F5'); key(t, 'new dir'); key(t, 'ENTER', 1.2)
        check(os.path.isfile(os.path.join(w, 'new dir', 'a b.txt')) and open(os.path.join(w, 'new dir', 'a b.txt')).read() == 'with a space\n',
              'F5: "a b.txt" is copied into "new dir"', t.text())
        key(t, 'F8', 0.8); key(t, 'ENTER', 1.0)
        check(not os.path.exists(os.path.join(w, 'a b.txt')), 'F8: "a b.txt" is deleted', t.text())
        check(t.alive() and 'Fatal' not in t.text(), 'names with spaces: DN is alive', t.text())
        t.close(0.5)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def missing(out):
    """a missing directory"""
    d, w = install(out)
    try:
        gone = os.path.join(w, 'gone')
        os.makedirs(gone)
        t = run(d, w)
        key(t, 'cd /nonexistent/dir', 0.4); key(t, 'ENTER', 1.0)
        text = t.text()
        check(t.alive() and 'Fatal' not in text and 'Access violation' not in text, 'cd to a directory that is not there: DN is alive', text)
        key(t, 'ESC', 0.3)
        check(panels(t.text()), 'cd to a directory that is not there: the panels are still there', t.text())
        key(t, 'HOME'); key(t, 'DOWN'); key(t, 'ENTER', 1.0)          # into gone
        os.rmdir(gone)
        key(t, 'CTRL-R', 1.2)
        text = t.text()
        check(t.alive() and 'Fatal' not in text and 'Access violation' not in text, 'the directory of the panel is removed, Ctrl-R: DN is alive', text)
        key(t, 'ESC', 0.3)
        key(t, 'DOWN', 0.3); key(t, 'ENTER', 0.8)
        check(t.alive() and 'Fatal' not in t.text(), 'the panel still takes keys after that', t.text())
        t.close(0.5)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def zipzip(out):
    """a zip in a zip"""
    d, w = install(out)
    try:
        inner = os.path.join(w, 'inner.zip')
        with zipfile.ZipFile(inner, 'w') as z:
            z.writestr('deep.txt', 'deep\n')
        with zipfile.ZipFile(os.path.join(w, 'outer.zip'), 'w') as z:
            z.write(inner, 'inner.zip')
        os.remove(inner)
        t = run(d, w)
        key(t, 'HOME'); key(t, 'DOWN'); key(t, 'ENTER', 1.5)
        text = t.text()
        check('inner' in text and 'Fatal' not in text, 'the outer archive is entered and shows the inner one', text)
        key(t, 'HOME'); key(t, 'DOWN'); key(t, 'ENTER', 2.0)
        t.until(lambda: 'deep' in t.text(), 30)       # the inner archive is unpacked first: slow on a loaded runner
        text = t.text()
        check('deep' in text and 'Fatal' not in text and 'Access violation' not in text, 'the inner archive is entered and shows its member', text)
        check(t.alive(), 'zip in zip: DN is alive', text)
        t.close(0.5)

    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    out = os.path.abspath(sys.argv[1])
    parts = [lambda c=c: run_pause(out, *c) for c in (('1', 'echo hello-from-dn', True), ('0', 'echo hello-from-dn', False),
                                                      ('2', 'echo hello-from-dn', False), ('2', 'echo hello-from-dn; false', True))]
    side_by_side(parts + [lambda fn=fn: fn(out) for fn in (spaces, missing, zipzip)])      # each in a directory of its own, all at once
    print('%d checks, %d failed' % (count, fails))
    sys.exit(1 if fails else 0)


main()
