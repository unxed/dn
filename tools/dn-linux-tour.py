#!/usr/bin/env python3
"""A smoke tour of the Linux build of DN in a pty: each scenario is a start of DN from a clean state, some keys, the screen.
Prints "ok" or what went wrong (the program ended, or does not answer) and keeps the screens in OUTDIR/tour-NAME.txt.
usage: tools/dn-linux-tour.py OUTDIR [NAME...]     (OUTDIR: the result of tools/dn-linux.sh: dn, *.LNG, *.DLG, *.HLP)"""
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from pty_screen import PtyTerm

KEYS = {
    'F1': '\x1bOP', 'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~',
    'F7': '\x1b[18~', 'F8': '\x1b[19~', 'F9': '\x1b[20~', 'F10': '\x1b[21~',
    'UP': '\x1b[A', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'LEFT': '\x1b[D', 'HOME': '\x1b[H', 'END': '\x1b[F',
    'PGUP': '\x1b[5~', 'PGDN': '\x1b[6~', 'INS': '\x1b[2~', 'DEL': '\x1b[3~', 'TAB': '\t', 'ENTER': '\r', 'ESC': '\x1b',
    'BS': '\x7f', 'ALT-X': '\x1bx', 'ALT-F1': '\x1b[1;3P', 'ALT-F7': '\x1b[18;3~', 'ALT-F10': '\x1b[21;3~',
    'CTRL-L': '\x0c', 'CTRL-O': '\x0f', 'CTRL-R': '\x12', 'CTRL-S': '\x13', 'CTRL-U': '\x15', 'ALT-F5': '\x1b[15;3~',
    'INSERT-KEY': '\x1b[2~', 'PLUS': '+', 'MINUS': '-', 'STAR': '*',
}
SCEN = [
    ('start', ''), ('tab', 'TAB'), ('f1help', 'ESC F1'), ('f2user', 'F2'), ('f3view', 'DOWN DOWN F3'), ('f4edit', 'DOWN DOWN F4'),
    ('f5copy', 'F5'), ('f6ren', 'F6'), ('f7mkdir', 'F7'), ('f8del', 'DOWN DOWN F8'), ('altf1drive', 'ALT-F1'), ('altf7find', 'ALT-F7'),
    ('altf10tree', 'ALT-F10'), ('ctrll', 'CTRL-L'), ('ctrlo', 'CTRL-O'), ('insert', 'INS INS'), ('plus', 'PLUS'),
    ('menudisk', 'F10 RIGHT DOWN'), ('menuutil', 'F10 RIGHT RIGHT DOWN'), ('menupanel', 'F10 RIGHT RIGHT RIGHT DOWN'),
    ('menumgr', 'F10 RIGHT RIGHT RIGHT RIGHT DOWN'), ('menuopt', 'F10 RIGHT RIGHT RIGHT RIGHT RIGHT DOWN'),
    ('quitask', 'ALT-X'), ('quit', 'ALT-X ENTER'),
]


def tokens(spec):
    for t in spec.split():
        yield KEYS.get(t, t)


def run(out, name, spec, cols=100, rows=30):
    d = tempfile.mkdtemp(prefix='dntour-')
    try:
        shutil.copy(os.path.join(out, 'dn'), d)
        for f in os.listdir(out):
            if f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
        os.makedirs(os.path.join(d, 'work'))
        for n, c in (('a.txt', 'first file\nsecond line\n'), ('b.txt', 'other\n'), ('c.dat', '1234\n')):
            open(os.path.join(d, 'work', n), 'w').write(c)
        t = PtyTerm(['./dn'], cols, rows, cwd=os.path.join(d, 'work'), exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        for k in tokens(spec):
            t.send(k, 0.5)
        t.pump(0.8, 4)
        text = t.text()
        ended = t.alive() is False
        status = t.close(1.0) if not ended else t.status
        open(os.path.join(out, 'tour-%s.txt' % name), 'w').write(text + '\n')
        if name != 'quit' and ended:
            return 'ENDED rc=%r  %s' % (status, ' | '.join(l for l in text.split('\n') if l.strip())[:160])
        if name == 'quit' and not ended:
            return 'did not quit'
        return 'ok'
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    out = os.path.abspath(sys.argv[1])
    names = sys.argv[2:]
    for name, spec in SCEN:
        if names and name not in names:
            continue
        print('%-12s %s' % (name, run(out, name, spec)), flush=True)


main()
