#!/usr/bin/env python3
"""Programs that read the terminal, run from the command line of DN (the embedded terminal, Linux, a pty): tools/dn-linux-embterm.py OUTDIR
  - a line typed to a program (read) is echoed and the program gets it;
  - the program sees the size of the terminal of DN;
  - a program in raw mode gets a key as the bytes of the terminal (q, and Up as ESC [ A);
  - Ctrl-C ends a program that waits and DN stays alive."""
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
            print('    | ' + info[-700:].replace('\n', '\n    | '), flush=True)


def install(out):
    d = tempfile.mkdtemp(prefix='dnemb-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    return d, w


def start(d, w):
    e = {'DNLNG': 'ENGLISH', 'DN2': d, 'DN_RUN_PAUSE': '1'}
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env=e)
    t.started()
    t.send('\x1b', 0.5)
    return t


def panels(text):
    return 'F10 Menu' in text and 'Name' in text


RAW = ("python3 -c \"import sys,tty,termios;fd=0;o=termios.tcgetattr(fd);tty.setraw(fd);"
       "c=sys.stdin.buffer.read1(3);termios.tcsetattr(fd,termios.TCSADRAIN,o);print('GOT',list(c))\"")

out = os.path.abspath(sys.argv[1])
dirs = []
try:
    d, w = install(out); dirs.append(d)
    t = start(d, w)
    t.send("read -p 'name? ' x; echo got-$x; stty size", 0.3); t.send('\r', 1.2)
    check('name?' in t.text(), 'the program shows its prompt', t.text())
    t.send('bob', 0.4); t.send('\r', 1.2)
    text = t.text()
    check('name? bob' in text and 'got-bob' in text, 'a line typed to the program is echoed and read', text)
    check('30 100' in text, 'the program sees the size of the terminal of DN (30 rows, 100 columns)', text)
    t.send('\r', 0.8)
    check(panels(t.text()), 'Enter brings the panels back', t.text())

    t.send(RAW, 0.3); t.send('\r', 1.5)
    t.send('q', 1.0)
    check("GOT [113]" in t.text(), 'a program in raw mode gets the key q as one byte', t.text())
    t.send('\r', 0.8)
    t.send(RAW, 0.3); t.send('\r', 1.5)
    t.send('\x1b[A', 1.0)
    check("GOT [27, 91, 65]" in t.text(), 'a program in raw mode gets Up as ESC [ A', t.text())
    t.send('\r', 0.8)

    t.send('sleep 60', 0.3); t.send('\r', 1.2)
    t.send('\x03', 1.5)
    text = t.text()
    check(t.alive() and 'Fatal' not in text, 'Ctrl-C ends the waiting program and DN is alive', text)
    t.send('\r', 0.8)
    check(panels(t.text()), 'the panels are back after Ctrl-C', t.text())
    t.close(0.3)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
