#!/usr/bin/env python3
"""The terminal view (TvVtView) through a pty: tvterm (a window with a shell) is run in a terminal of 80x25, commands are typed, the screen is compared.
usage: test_tvterm.py PATH/TO/tvterm   (tools/pty_screen.py is the terminal)"""
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


env = {'TERM': 'xterm-256color', 'PS1': '$ ', 'HOME': '/tmp', 'PATH': os.environ.get('PATH', '/usr/bin:/bin')}
t = PtyTerm([demo, '/bin/sh'], 80, 25, env=env)
check(t.wait_for('$ ', 5), 'the shell starts in the window and shows its prompt', t.text())
check('Terminal' in t.text().split('\n')[1], 'the window has its title')

t.send(b'echo hello\r', 0.8)
check('\nhello' in t.text().replace('║', '\n').replace('│', '\n') or any(l.strip('║ │').startswith('hello') for l in t.text().split('\n')), 'a command is typed and its output is on the screen', t.text())

t.send(b'stty size\r', 0.8)
check(any(l.strip('║ │') == '21 78' for l in t.text().split('\n')), 'the program sees the size of the window (21 rows, 78 columns)', t.text())

t.send('echo привет\r'.encode(), 0.8)
check(any(l.strip('║ │') == 'привет' for l in t.text().split('\n')), 'UTF-8 goes both ways (Cyrillic)', t.text())

t.send(b"printf '\\033[1;31mRED\\033[0m\\n'\r", 0.8)
row = next((y for y, l in enumerate(t.screen.lines()) if l.strip('║ │').startswith('RED')), -1)
check(row >= 0, 'a colored text is shown', t.text())
if row >= 0:
    line = t.screen.lines()[row]
    x = line.find('RED')
    ch, attr = t.screen.cells[row][x]
    check(attr is not None and attr[0] == ('i', 1) and (attr[2] & 2), 'the color (red) and the style (bold) of the cell', repr(attr))

t.send(b'seq 1 100\r', 1.0)
check(any(l.strip('║ │') == '100' for l in t.text().split('\n')), 'long output: the last line is at the bottom', t.text())
t.send(b'\x1b[5;2~', 0.6)                             # Shift-PgUp
txt = t.text()
check(not any(l.strip('║ │') == '100' for l in txt.split('\n')) and any(l.strip('║ │').isdigit() for l in txt.split('\n')),
      'Shift-PgUp shows the history (the last line is gone, earlier lines are there)', txt)
t.send(b'\x1b[6;2~', 0.6)                             # Shift-PgDn
check(any(l.strip('║ │') == '100' for l in t.text().split('\n')), 'Shift-PgDn is back at the live screen', t.text())

t.send(b'sleep 30\r', 0.5)
t.send(b'\x03', 0.8)
t.send(b'echo after\r', 0.8)
check(any(l.strip('║ │') == 'after' for l in t.text().split('\n')), 'Ctrl-C ends the program and the shell goes on', t.text())

t.resize(100, 30)
t.pump(0.8)
t.send(b'stty size\r', 0.8)
check(any(l.strip('║ │') == '26 98' for l in t.text().split('\n')), 'the terminal is resized: the program sees the new size (26 rows, 98 columns)', t.text())

t.send(b'exit\r', 1.5)
for _ in range(20):
    if not t.alive():
        break
    t.pump(0.3)
check(not t.alive(), 'the shell ends: the application ends')
t.close()
print('%d/%d' % (count - fails, count))
sys.exit(1 if fails else 0)
