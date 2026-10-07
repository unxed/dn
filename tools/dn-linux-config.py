#!/usr/bin/env python3
"""Where DN keeps the files that the user changes (Linux, a pty): tools/dn-linux-config.py OUTDIR
  - by default in the configuration of the user: $XDG_CONFIG_HOME/dn, else ~/.config/dn; the directory of the program gets no dn.ini;
  - the files that an older DN left next to the program are copied there once (the originals stay);
  - the environment variable DN2 names a directory for everything, as it always did."""
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
            print('    | ' + info, flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dncfg-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    os.makedirs(os.path.join(d, 'work'))
    return d


def run_dn(d, env):
    e = {'DNLNG': 'ENGLISH'}
    e.update(env)
    t = PtyTerm(['./dn'], 100, 30, cwd=os.path.join(d, 'work'), exe=os.path.join(d, 'dn'), env=e)
    t.pump(1.5, 6)
    t.send('\x1b', 0.5)
    text = t.text()
    t.close(0.5)
    return text


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    # XDG_CONFIG_HOME
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    xdg = os.path.join(d, 'xdg')
    run_dn(d, {'DN2': '', 'HOME': home, 'XDG_CONFIG_HOME': xdg})
    check(os.path.isfile(os.path.join(xdg, 'dn', 'dn.ini')), 'XDG_CONFIG_HOME: dn.ini is in $XDG_CONFIG_HOME/dn')
    check(not os.path.exists(os.path.join(d, 'dn.ini')), 'the directory of the program gets no dn.ini')
    check(not os.path.exists(os.path.join(home, '.config')), 'nothing in ~/.config when XDG_CONFIG_HOME is set')

    # ~/.config
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    env = {'DN2': '', 'HOME': home, 'XDG_CONFIG_HOME': ''}
    run_dn(d, env)
    check(os.path.isfile(os.path.join(home, '.config', 'dn', 'dn.ini')), '~/.config/dn is the default')

    # the move: the files of the program directory are copied once
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    open(os.path.join(d, 'dn.his'), 'w').write('')
    open(os.path.join(d, 'dn.ini'), 'w').write('[Interface]\nClockVisible=0\n')
    run_dn(d, {'DN2': '', 'HOME': home, 'XDG_CONFIG_HOME': ''})
    conf = os.path.join(home, '.config', 'dn')
    check(os.path.isfile(os.path.join(conf, 'dn.his')), 'the move: the histories were copied')
    check('ClockVisible=0' in open(os.path.join(conf, 'dn.ini')).read(), 'the move: dn.ini of the program directory is the one that is used')
    check(os.path.isfile(os.path.join(d, 'dn.ini')) and os.path.isfile(os.path.join(d, 'dn.his')), 'the originals stay')

    # DN2: everything in that directory, as before
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    own = os.path.join(d, 'own')
    os.makedirs(own)
    for f in os.listdir(d):
        if f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(d, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(own, f))
    run_dn(d, {'DN2': own, 'HOME': home, 'XDG_CONFIG_HOME': ''})
    check(os.path.isfile(os.path.join(own, 'dn.ini')), 'DN2: dn.ini is in the directory that DN2 names')
    check(not os.path.exists(os.path.join(home, '.config')), 'DN2: nothing in ~/.config')
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
