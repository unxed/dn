#!/usr/bin/env python3
"""DN with a terminal that speaks the far2l extensions (the far2l terminal: tools/f2lterm.py plays it): the reported failure was that in the far2l terminal
Ctrl+Ins in the editor copied nothing (the terminal took the key for its own copy). Here the keys come as events: the text of the editor is selected and Ctrl+Ins puts it
on the clipboard of the terminal; the clipboard of the terminal is pasted with Shift+Ins. usage: tools/dn-linux-far2l.py OUTDIR   (OUTDIR: the result of tools/build.sh linux64)"""
import os, shutil, sys, tempfile, time
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from pty_screen import Screen
from f2lterm import Term, key

LCTRL, SHIFT, LALT = 0x08, 0x10, 0x02
out = os.path.abspath(sys.argv[1])
fails = 0
def check(ok, msg, t=None):
    global fails
    print(('PASS ' if ok else 'FAIL ') + msg)
    if not ok:
        fails += 1
        if t:
            print(t)

d = tempfile.mkdtemp(prefix='dnf2l-')
t = None
try:
    for f in os.listdir(out):
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(os.path.join(out, f), d)
    w = os.path.join(d, 'work'); os.makedirs(w)
    open(os.path.join(w, 'a.txt'), 'w').write('hello world\nsecond line\n')
    env = dict(os.environ, TERM='xterm-256color', TV_CONFIG_DIR=os.path.join(d, 'cfg'), LANG='C.UTF-8')
    env.pop('TV_FAR2L', None)
    t = Term(os.path.join(d, 'dn'), env, w, screen=Screen(100, 30))
    def k(vk, ch=0, cs=0, sc=0, wait=0.6):
        t.send(key(True, ch, cs, sc, vk)); t.send(key(False, ch, cs, sc, vk)); t.pump(wait)
    t.pump(2.0)
    check(t.acked, 'DN asks for the extensions')
    k(0x1B)                                                     # Esc: the box of the start
    k(0x28)                                                     # Down: on a.txt
    k(0x73, wait=1.5)                                           # F4: the editor
    check('hello world' in t.text(), 'the editor shows the file', t.text())
    t.clip = 'ПРИВЕТ из терминала'.encode()
    t.gesture = time.time()                                     # the paste gesture: the terminal lets the clipboard be read
    k(0x2D, cs=SHIFT, sc=0x52, wait=1.0)                        # Shift+Ins: paste
    check('ПРИВЕТ из терминала' in t.text(), 'Shift+Ins: the clipboard of the terminal is pasted into the editor (no block selected)', 'clip now: %r' % t.clip + chr(10) + t.text())
    for _ in range(11): k(0x27, cs=SHIFT, wait=0.15)            # Shift+Right x11: the first word and the space are selected
    k(0x2D, cs=LCTRL, sc=0x52)                                  # Ctrl+Ins: copy (the terminal does not take it, it comes to DN)
    check(t.clip.decode(errors='replace').strip() == 'hello world', 'Ctrl+Ins: the selection is on the clipboard of the terminal (%r)' % t.clip)
    k(0x1B, wait=0.8)                                           # Esc: leave the editor (asks about saving)
    t.send(key(True, ord('n'), 0, 0x31, 0x4E)); t.pump(0.8)
    k(0x58, ord('x'), LALT, 0x2D, wait=0.8)                     # Alt-X
    t.send(key(True, 13, 0, 0x1C, 0x0D)); t.pump(1.5)
    check(b'\x1b_far2l0' in t.out, 'on the exit the extensions are switched off')
finally:
    if t:
        t.close()
    shutil.rmtree(d, ignore_errors=True)
print('ALL OK' if not fails else '%d FAILED' % fails)
sys.exit(1 if fails else 0)
