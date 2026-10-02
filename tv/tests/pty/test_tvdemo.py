#!/usr/bin/env python3
"""Tests of the terminal backend through a pty: tvdemo is run in a terminal of 80x25, keys are sent, the screen is
compared. usage: test_tvdemo.py PATH/TO/tvdemo   (tools/pty_screen.py is the terminal)"""
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
check(t.wait_for('Window'), 'the program starts and draws the menu bar')
scr = t.text()
lines = scr.split('\n')
check('File' in lines[0] and 'Window' in lines[0], 'the menu bar is on the first row', scr)
check('Alt-X Exit' in lines[24], 'the status line is on the last row', scr)
check(('Window' in ''.join(lines[1:5])) and '┌' in scr or '╔' in scr, 'a window is on the desktop', scr)
check(not t.screen.cursor_visible, 'the cursor is hidden')
check(('h', 1049) in t.screen.log, 'the alternate screen is on')
check(('h', 1006) in t.screen.log, 'the mouse reporting (SGR) is on')

# F4: another window
t.send(b'\x1bOS')
check(t.text().count('Window') >= 2 or 'Window 2' in t.text(), 'F4 (ESC O S) opens another window', t.text())

# the menu: F10, then Esc
t.send(b'\x1b[21~')
check('New window' not in t.text(), 'F10 activates the menu bar (no drop-down yet)', t.text())
t.send(b'\x1b[B')
check('New window' in t.text(), 'Down opens the drop-down', t.text())
t.send(b'\x1b[B')
t.send(b'\x1b[B')
check('Close' in t.text(), '... and Down moves in it', t.text())
t.send(b'\x1b')
t.send(b'\x1b')
check('New window' not in t.text(), 'Esc closes the menu', t.text())

# the mouse: a click on File in the menu bar opens the menu (SGR: button 0 at column 3, row 1)
t.send(b'\x1b[<0;3;1M')
t.send(b'\x1b[<0;3;1m')
check('New window' in t.text(), 'a click on the menu bar opens the menu', t.text())
t.send(b'\x1b')

# a change of the size of the terminal
t.resize(100, 30)
t.pump(0.6)
lines = t.text().split('\n')
check(len(lines) == 30 and 'Alt-X Exit' in lines[29], 'the size changed: the status line is on the last row of 30', t.text())
check('File' in lines[0], '... and the menu bar is still on the first')
t.resize(60, 20)
t.pump(0.6)
lines = t.text().split('\n')
check('Alt-X Exit' in lines[19], 'the terminal got smaller: the status line is on row 20', t.text())

# Alt-X ends the program, the terminal is put back
t.send(b'\x1bx', settle=0.5)
status = t.close()
check(status == 0, 'Alt-X ends the program with status 0 (got %r)' % (status,))
check(('l', 1049) in t.screen.log, 'the alternate screen is off at the end')
check(('l', 1006) in t.screen.log, 'the mouse reporting is off at the end')

print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
sys.exit(1 if fails else 0)
