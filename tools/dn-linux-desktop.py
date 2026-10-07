#!/usr/bin/env python3
"""The desktop of DN is saved at the exit and restored at the next start (Linux, a pty): tools/dn-linux-desktop.py OUTDIR
Run 1: Options -> Configuration -> Startup: Autosave Desktop and Preserve directory on; Run 2: into the directory sub and out of DN by Alt-X (Yes);
Run 3: the panel is in sub (the title of the panel), dn.dsk is on the disk. Runs 4 and 5: a window of the desktop, the editor, is saved and restored; runs 6 and 7: the viewer. The same scenario as `autosave` of tools/dn-dos-input.py."""
import os, re, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

K = {'ENTER': '\r', 'ESC': '\x1b', 'TAB': '\t', 'DOWN': '\x1b[B', 'UP': '\x1b[A', 'RIGHT': '\x1b[C', 'F10': '\x1b[21~', 'SPACE': ' ', 'ALT-X': '\x1bx'}
bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info.replace('\n', '\n    | ')[:2000], flush=True)


def run(d, w, keys, wait_exit=True):
    os.environ['DNLNG'] = 'ENGLISH'
    t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
    t.pump(1.5, 6)
    for k in keys.split():
        t.send(K.get(k, k), 0.8)
    t.pump(1.0, 3)
    text = t.text()
    if wait_exit:
        for _ in range(20):
            if not t.alive():
                break
            t.pump(0.3, 1)
    alive = t.alive()
    t.close(0.3)
    return text, alive


OPTIONS = 'ESC F10 RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT ENTER ENTER DOWN ENTER TAB DOWN SPACE DOWN DOWN SPACE ENTER ALT-X ENTER'


def install(out):
    d = tempfile.mkdtemp(prefix='dndesk-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'sub', 'in.txt'), 'w').write('inner\n')
    open(os.path.join(w, 'a.txt'), 'w').write('aaa\n')
    return d, w


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    # the directory of the panel
    d, w = install(out)
    dirs.append(d)
    text, alive = run(d, w, OPTIONS)         # the options of the startup (Autosave Desktop, Preserve directory), the exit
    check(not alive, 'run 1: DN ended after the options and Alt-X', text)
    ini = os.path.join(d, 'dn.ini')
    check(os.path.isfile(ini) and b'[Saved]' in open(ini, 'rb').read(), 'run 1: dn.ini has the section [Saved]', text)
    text, alive = run(d, w, 'ESC TAB DOWN ENTER ALT-X ENTER')       # into the directory sub, out
    check(not alive, 'run 2: DN ended', text)
    check(any(n.lower() == 'dn.dsk' for n in os.listdir(d)), 'run 2: dn.dsk is written at the exit', text)
    text, alive = run(d, w, '', wait_exit=False)                     # the panel is in sub
    check(re.search(r'work\\sub', text) is not None, 'run 3: the next start restores the directory of the panel (work\\sub)', text)
    # a window of the desktop (the editor): out of DN by the menu File -> Exit (Alt-X in an editor does not leave DN), the next start brings the editor back
    d, w = install(out)
    dirs.append(d)
    run(d, w, OPTIONS)
    text, alive = run(d, w, 'ESC DOWN DOWN \x1bOS \x1b[<0;5;1M\x1b[<0;5;1m \x1b[F ENTER ENTER')    # a.txt, F4, the menu File (the mouse), its last item (Exit), Yes
    check(not alive, 'run 4: DN ended by File -> Exit with the editor open', text)
    text, alive = run(d, w, '', wait_exit=False)
    check('Edit - ' in text and 'a.txt' in text, 'run 5: the next start brings the editor window back', text)
    # the viewer: the same (the object build restores it; the class build died in the load of the viewer, XCoder was not made)
    d, w = install(out)
    dirs.append(d)
    run(d, w, OPTIONS)
    text, alive = run(d, w, 'ESC DOWN DOWN \x1bOR \x1b[<0;5;1M\x1b[<0;5;1m \x1b[F ENTER ENTER')    # a.txt, F3, File -> Exit, Yes
    check(not alive, 'run 6: DN ended by File -> Exit with the viewer open', text)
    text, alive = run(d, w, '', wait_exit=False)
    check('Fatal' not in text and 'a.txt' in text and 'Edit - ' not in text, 'run 7: the next start brings the viewer window back', text)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
