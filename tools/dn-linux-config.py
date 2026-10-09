#!/usr/bin/env python3
"""Where DN keeps the files of the user (Linux, a pty): tools/dn-linux-config.py OUTDIR
  - the settings in $XDG_CONFIG_HOME/dn, else ~/.config/dn; the directory of the program gets no dn.ini;
  - the log of the run and the crash reports in $XDG_STATE_HOME/dn, else ~/.local/state/dn; the cache of dn.ini in $XDG_CACHE_HOME/dn, else ~/.cache/dn;
    a relative value of a variable is ignored;
  - the files that an older DN left next to the program are copied there once (the originals stay); the logs and the reports in the directory of the
    settings move to that of the state;
  - the environment variable DN2 names a directory for everything, as it always did."""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

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


def run_dn(d, env, quit=False):
    """quit: DN exits by Alt-X (the cache of dn.ini is written at the exit), else the program is closed."""
    e = {'DNLNG': 'ENGLISH'}
    e.update(env)
    t = DnTerm(['./dn'], 100, 30, cwd=os.path.join(d, 'work'), exe=os.path.join(d, 'dn'), env=e)
    t.started()
    t.send('\x1b', 0.5)
    text = t.text()
    if quit:
        t.send('\x1bx', 0.8)
        t.send('\r', 0.8)
        t.until(lambda: not t.alive(), 20)
    t.close(0.5)
    return text


def xdg_env(home):
    return {'DN2': '', 'HOME': home, 'XDG_CONFIG_HOME': '', 'XDG_STATE_HOME': '', 'XDG_CACHE_HOME': ''}


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    # XDG_CONFIG_HOME
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    xdg = os.path.join(d, 'xdg')
    xs, xc = os.path.join(d, 'xstate'), os.path.join(d, 'xcache')
    run_dn(d, {'DN2': '', 'HOME': home, 'XDG_CONFIG_HOME': xdg, 'XDG_STATE_HOME': xs, 'XDG_CACHE_HOME': xc}, quit=True)
    check(os.path.isfile(os.path.join(xdg, 'dn', 'dn.ini')), 'XDG_CONFIG_HOME: dn.ini is in $XDG_CONFIG_HOME/dn')
    check(os.path.isfile(os.path.join(xs, 'dn', 'dn.log')), 'XDG_STATE_HOME: dn.log is in $XDG_STATE_HOME/dn')
    check(os.path.isfile(os.path.join(xc, 'dn', 'dn.cbc')), 'XDG_CACHE_HOME: dn.cbc is in $XDG_CACHE_HOME/dn')
    check(not os.path.exists(os.path.join(xdg, 'dn', 'dn.log')) and not os.path.exists(os.path.join(xdg, 'dn', 'dn.cbc')),
          'no log and no cache in the directory of the settings')
    check(not os.path.exists(os.path.join(d, 'dn.ini')), 'the directory of the program gets no dn.ini')
    check(not os.listdir(home), 'nothing in the home directory when the XDG variables are set', str(os.listdir(home)))

    # ~/.config
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    run_dn(d, xdg_env(home), quit=True)
    check(os.path.isfile(os.path.join(home, '.config', 'dn', 'dn.ini')), '~/.config/dn is the default')
    check(os.path.isfile(os.path.join(home, '.local', 'state', 'dn', 'dn.log')), '~/.local/state/dn is the default of the log')
    check(os.path.isfile(os.path.join(home, '.cache', 'dn', 'dn.cbc')), '~/.cache/dn is the default of the cache')
    mode = os.stat(os.path.join(home, '.local', 'state', 'dn')).st_mode & 0o777
    check(mode == 0o700, 'the directories are made with the mode 0700', oct(mode))

    # a relative XDG variable is ignored
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    run_dn(d, {'DN2': '', 'HOME': home, 'XDG_CONFIG_HOME': 'rel', 'XDG_STATE_HOME': 'rel', 'XDG_CACHE_HOME': 'rel'})
    check(os.path.isfile(os.path.join(home, '.config', 'dn', 'dn.ini')) and os.path.isfile(os.path.join(home, '.local', 'state', 'dn', 'dn.log')),
          'a relative XDG variable is ignored')
    check(not os.path.exists(os.path.join(d, 'work', 'rel')), 'nothing in the relative directory')

    # the move of the log, the crash reports and the cache that DN kept in the directory of the settings
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    conf = os.path.join(home, '.config', 'dn')
    os.makedirs(os.path.join(conf, 'crash'))
    open(os.path.join(conf, 'dn.ini'), 'w').write('[Interface]\nClockVisible=0\n')
    open(os.path.join(conf, 'dn_prev.log'), 'w').write('old log\n')
    open(os.path.join(conf, 'crash', 'crash001.txt'), 'w').write('old report\n')
    open(os.path.join(conf, 'dn.cbc'), 'w').write('old cache')
    run_dn(d, xdg_env(home))
    state = os.path.join(home, '.local', 'state', 'dn')
    check(os.path.isfile(os.path.join(state, 'crash', 'crash001.txt')) and not os.path.exists(os.path.join(conf, 'crash')),
          'the crash reports move to the directory of the state')
    check(os.path.isfile(os.path.join(state, 'dn_prev.log')) and not os.path.exists(os.path.join(conf, 'dn_prev.log')),
          'the logs move to the directory of the state')
    check(not os.path.exists(os.path.join(conf, 'dn.cbc')), 'the old cache goes')
    check('ClockVisible=0' in open(os.path.join(conf, 'dn.ini')).read(), 'dn.ini stays')

    # the move: the files of the program directory are copied once
    d = install(out); dirs.append(d)
    home = os.path.join(d, 'home'); os.makedirs(home)
    open(os.path.join(d, 'dn.his'), 'w').write('')
    open(os.path.join(d, 'dn.ini'), 'w').write('[Interface]\nClockVisible=0\n')
    run_dn(d, xdg_env(home))
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
    run_dn(d, {'DN2': own, 'HOME': home, 'XDG_CONFIG_HOME': '', 'XDG_STATE_HOME': '', 'XDG_CACHE_HOME': ''})
    check(os.path.isfile(os.path.join(own, 'dn.ini')), 'DN2: dn.ini is in the directory that DN2 names')
    check(os.path.isfile(os.path.join(own, 'dn.log')), 'DN2: dn.log is in the directory that DN2 names')
    check(not os.listdir(home), 'DN2: nothing in the home directory', str(os.listdir(home)))
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
