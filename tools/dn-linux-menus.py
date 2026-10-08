#!/usr/bin/env python3
"""Opens every item of every menu of the Linux build of DN (in a pty, a fresh start for each) and reports the items after which the program died,
shows its "Fatal Error" screen or does not answer an Esc. usage: tools/dn-linux-menus.py OUTDIR [WORKERS]   (OUTDIR: the result of tools/build.sh linux|linux64)
The screens are kept in OUTDIR/menu-M-N.txt (M = the menu from 1, N = the item from 1)."""
import os, shutil, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

RIGHT, DOWN, ENTER, ESC, F10 = '\x1b[C', '\x1b[B', '\r', '\x1b', '\x1b[21~'
MENUS = 7          # File Disk Utilities Panel Manager Options Window
ITEMS = 18


def one(args):
    out, m, n = args
    d = tempfile.mkdtemp(prefix='dnmenu-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
        w = os.path.join(d, 'work')
        os.makedirs(os.path.join(w, 'sub'))
        for name in ('a.txt', 'b.txt'):
            open(os.path.join(w, name), 'w').write('file %s\n' % name)
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.started()
        t.send(ESC, 0.4)
        t.send(F10, 0.4)
        for _ in range(m):
            t.send(RIGHT, 0.2)
        for _ in range(n):
            t.send(DOWN, 0.15)
        t.send(ENTER, 0.9)
        text = t.text()
        alive = t.alive()
        verdict = 'ok'
        if not alive:
            verdict = 'ENDED rc=%r' % (t.status,)
        elif 'Fatal Error' in text or 'Access violation' in text or 'Exception' in text:
            verdict = 'FATAL ' + ' '.join(l.strip() for l in text.split('\n') if 'violation' in l or 'Exception' in l or 'Source' in l)[:140]
        else:
            # does Esc get us out (twice: a dialog, a menu)? then Alt-X ends the program
            t.send(ESC, 0.4); t.send(ESC, 0.4)
            t.send('\x1bx', 0.5); t.send(ENTER, 0.7)
            if t.alive():
                verdict = 'did not quit after Esc Esc Alt-X Enter'
        open(os.path.join(out, 'menu-%d-%d.txt' % (m, n)), 'w').write(text + '\n')
        if t.alive():
            t.close(0.3)
        return (m, n, verdict)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    out = os.path.abspath(sys.argv[1])
    workers = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    jobs = [(out, m, n) for m in range(1, MENUS + 1) for n in range(1, ITEMS + 1)]
    bad = 0
    with ThreadPoolExecutor(workers) as ex:
        for m, n, v in ex.map(one, jobs):
            if v != 'ok':
                bad += 1
                print('menu %d item %d: %s' % (m, n, v), flush=True)
    print('done: %d of %d with a problem' % (bad, len(jobs)))


main()
