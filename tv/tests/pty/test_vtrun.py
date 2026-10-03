#!/usr/bin/env python3
"""VtRunScreen and VtShowScreen through a pty: rundemo runs a shell command on the whole screen, the keys go to it, the screen stays for the user.
usage: test_vtrun.py PATH/TO/rundemo   (tools/pty_screen.py is the terminal)"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
from pty_screen import PtyTerm

demo = sys.argv[1]
fails = 0
count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


t = PtyTerm([demo], 80, 25)
check(t.wait_for('hello', 5), 'the command runs on the screen: its output is there', t.text())
check('$ mycommand' in t.text().split('\n')[0], 'the command line is the first line of the screen', t.text())
t.send(b'abc\r', 0.8)
check('got:abc' in t.text(), 'the keys go to the program', t.text())
check(t.wait_for('Press Enter', 3), 'the program has ended: the pause is shown with its status', t.text())
check('(005)' in t.text(), 'the exit status 5 is shown', t.text())
t.send(b'\r', 0.8)
check('got:abc' in t.text() and 'hello' in t.text(), 'the screen stays for the user (VtShowScreen)', t.text())
t.send(b'x', 1.0)
for _ in range(20):
    if not t.alive():
        break
    t.pump(0.2)
check(not t.alive(), 'a key leaves the user screen, the program ends')
check(b'DONE 5' in t.raw, 'the exit status is the result of the call', t.raw[-200:])
t.close()
print('%d/%d' % (count - fails, count))
sys.exit(1 if fails else 0)
