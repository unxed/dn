#!/usr/bin/env python3
"""The flight recorder of DN (Linux, a pty): tools/dn-linux-crash.py OUTDIR
  - the log of the run (dn.log in the configuration directory) has the facts and the keys; the typed characters are not in it;
  - an access violation (DN_TEST_CRASH=1: the key F12) makes a report crash/crash001.txt: the exception, the facts, the panels, the last
    events, the screen; the fatal screen names the file;
  - the log of a run goes to dn_prev.log at the next start; a run that was killed is told in the next log;
  - DN_LOG_KEYS=full records the characters, DN_LOG=0 writes no log (a crash report is still made)."""
import os, shutil, signal, sys, tempfile, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

bad = 0


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[:600], flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dncrash-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    os.makedirs(os.path.join(d, 'work'))
    os.makedirs(os.path.join(d, 'home'))
    return d


def start(d, extra=None):
    e = {'DNLNG': 'ENGLISH', 'DN2': '', 'HOME': os.path.join(d, 'home'), 'XDG_CONFIG_HOME': '', 'TERM': 'xterm'}
    e.update(extra or {})
    t = PtyTerm(['./dn'], 100, 30, cwd=os.path.join(d, 'work'), exe=os.path.join(d, 'dn'), env=e)
    t.pump(1.5, 6)
    return t


def read(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            return f.read()
    except OSError:
        return ''


out = sys.argv[1]
dirs = []
try:
    d = install(out); dirs.append(d)
    conf = os.path.join(d, 'home', '.config', 'dn')
    log, prev, crash = (os.path.join(conf, n) for n in ('dn.log', 'dn_prev.log', os.path.join('crash', 'crash001.txt')))

    # a run with a crash
    t = start(d, {'DN_TEST_CRASH': '1'})
    t.send('\x1b', 0.5)              # the About box of the first start
    t.send('\x1b[B', 0.3)            # Down
    t.send('\t', 0.3)                # Tab
    t.send('zqxj', 0.3)              # typed characters
    t.send('\x15', 0.3)              # Ctrl+U: clears the command line
    t.send('\x1b[24;1~', 1.0)          # F12: the access violation
    screen = t.text()
    check('Fatal Error' in screen, 'the fatal screen is shown', screen)
    check('crash001.txt' in screen, 'the fatal screen names the report', screen)
    t.send('\r', 0.5)
    t.close(1.0)
    r = read(crash)
    check('Exception ' in r and 'Access violation' in r, 'the report names the exception', r)
    check('TERM=xterm' in r, 'the report has the facts')
    check('config dir=' in r and 'os=Linux' in r, 'the report tells the system and the directory of the settings')
    check('--- panels' in r and 'active:' in r, 'the report tells the panels')
    check('kbDown' in r and 'kbTab' in r and 'kbF12' in r, 'the report has the last keys by name')
    check('<char>' in r, 'the typed characters are masked in the report')
    check('zqxj' not in r.split('--- the screen')[0], 'the typed characters are not in the report (outside the screen)')
    check('--- the screen' in r and ('Name' in r.split('--- the screen')[1]), 'the report has the screen of the moment')
    l = read(log)
    check(' key kbDown' in l and 'fact TERM=xterm' in l, 'the log has the keys and the facts')
    check('zqxj' not in l, 'the typed characters are not in the log')
    check(' exit after a crash' in l, 'the log ends with the line exit')

    # the next start: the log of the run goes to dn_prev.log; no warning after a run that ended
    t = start(d)
    t.send('\x1b', 0.3)
    t.close(0.5)
    check(os.path.isfile(prev) and 'crash report' in read(prev), 'the log of the run before is dn_prev.log')
    check('did not end' not in read(log), 'no warning after a run that wrote its end')

    # a killed run is told in the next log
    t = start(d)
    t.send('\x1b[B', 0.3)
    os.kill(t.pid, signal.SIGKILL)
    time.sleep(0.5)
    t.close(0.5)
    t = start(d)
    t.send('\x1b', 0.3)
    t.close(0.5)
    check('did not end' in read(log), 'a run that was killed is told in the next log', read(log)[:400])

    # the characters on request
    t = start(d, {'DN_LOG_KEYS': 'full'})
    t.send('zqxj', 0.3)
    t.send('\x1b', 0.3)
    t.close(0.5)
    check("'z'" in read(log), 'DN_LOG_KEYS=full records the characters', read(log)[:400])

    # no log of the run, the report still
    shutil.rmtree(os.path.join(d, 'home', '.config'))
    t = start(d, {'DN_LOG': '0', 'DN_TEST_CRASH': '1'})
    t.send('\x1b', 0.5)
    t.send('\x1b[B', 0.3)
    t.send('\x1b[24;1~', 1.0)
    t.send('\r', 0.5)
    t.close(1.0)
    check(not os.path.isfile(log), 'DN_LOG=0 writes no log of the run', read(log)[:200])
    check(os.path.isfile(crash), 'DN_LOG=0 still writes the report of a crash')
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
