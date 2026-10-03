#!/usr/bin/env python3
"""The clipboard of the terminal backend: ClipboardSetText sends OSC 52 (base64 of the UTF-8 text); not on the Linux console (TERM=linux)
and not with TV_CLIPBOARD=0. usage: test_clip.py PATH/TO/clipdemo"""
import base64
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
from pty_screen import PtyTerm

demo = sys.argv[1]
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


def run(env):
    t = PtyTerm([demo], 80, 25, env=env)
    t.pump(1.5, 6)
    raw = t.raw
    t.close()
    return re.findall(rb'\x1b\]52;c;([A-Za-z0-9+/=]*)\x07', raw)


m = run({'TERM': 'xterm-256color'})
check(len(m) == 1 and base64.b64decode(m[0]).decode('utf-8') == 'Привет, мир', 'OSC 52 carries the text in UTF-8', repr(m))
check(run({'TERM': 'linux'}) == [], 'no OSC 52 on the Linux console')
check(run({'TERM': 'xterm-256color', 'TV_CLIPBOARD': '0'}) == [], 'no OSC 52 with TV_CLIPBOARD=0')
print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
sys.exit(1 if fails else 0)
