#!/usr/bin/env python3
"""The win32 input mode of DN on Linux (TvUnix asks the terminal for it, TV_WIN32_INPUT=1): the keys come as "ESC [ Vk ; Sc ; Uc ; Kd ; Cs ; Rc _"
(Windows Terminal, WezTerm...). F7 (Make directory) opens the dialog, Ctrl-Right/Alt-X work as combinations, Alt-X + Enter ends DN with 0; with
TV_WIN32_INPUT=0 the mode is not asked for. usage: tools/dn-linux-win32.py OUTDIR   (OUTDIR: the result of tools/build.sh linux|linux64)"""
import os, shutil, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

def w32(vk, uc=0, cs=0, sc=0):
    """a press and a release of a key"""
    return '\x1b[%d;%d;%d;1;%d;1_\x1b[%d;%d;%d;0;%d;1_' % (vk, sc, uc, cs, vk, sc, uc, cs)

out = os.path.abspath(sys.argv[1])
fails = 0
def check(ok, msg, t=None):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    if not ok:
        fails += 1
        if t:
            print(t)

def start(env):
    d = tempfile.mkdtemp(prefix='dnw32-')
    for f in os.listdir(out):
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(os.path.join(out, f), d)
    w = os.path.join(d, 'work'); os.makedirs(w)
    t = DnTerm(['./dn'], 100, 30, env=env, cwd=w, exe=os.path.join(d, 'dn'))
    t.started()
    return d, t

d, t = start({'TV_WIN32_INPUT': '1'})
try:
    check(any('9001' in str(m) for m in t.screen.log), 'TV_WIN32_INPUT=1: the mode 9001 is asked for', str(t.screen.log))
    t.send(w32(0x1B), 1.0)                       # Esc closes the box "DN/2 Open Source" of the start
    t.send(w32(0x76), 1.0)                       # F7
    check('Make directory' in t.text() or 'directory' in t.text().lower(), 'F7 (win32) opens the dialog "Make directory"', t.text())
    t.send(w32(0x1B), 1.0)                       # Esc closes it
    check('Make directory' not in t.text(), 'Esc (win32) closes it', t.text())
    t.send(w32(0x58, ord('x'), 2), 1.0)          # Alt-X
    t.send(w32(0x0D, 13), 1.5)                   # Enter: confirms
    status = t.close(4)
    check(status == 0, 'Alt-X and Enter (win32): DN ends with 0 (status %r)' % (status,))
finally:
    shutil.rmtree(d, ignore_errors=True)

d, t = start({'TV_WIN32_INPUT': '0'})
try:
    check(not any('9001' in str(m) for m in t.screen.log), 'TV_WIN32_INPUT=0: the mode is not asked for')
    t.send('\x1b', 1.0); t.send('\x1bx', 1.0); t.send('\r', 1.5)
    check(t.close(4) == 0, 'the plain keys still work (Alt-X, Enter)')
finally:
    shutil.rmtree(d, ignore_errors=True)
print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
