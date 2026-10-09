#!/usr/bin/env python3
"""Settings that DN cannot read do not stop it (Linux, a pty): tools/dn-linux-badconfig.py OUTDIR
The files of the settings that are written as streams (the histories dn.his, the desktop dn.dsk) are put next to DN in three forms: the head of another
version of the format (a file of an older DN), the head of this version and bytes that are not a stream, and bytes only. DN must start, draw its
panels and stay alive; what it could not read is noted in its log. An older DN quit at the start, silently, on the histories of the version before."""
import os, random, shutil, sys, tempfile, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm, side_by_side

bad = 0

# the heads of the files: dn/src/histories.pas (HistoryFileSign), dn/src/startup.pas (DskSign)
HEADS = {
    'dn.his': (b'DN OSP History file\r\n\x1a\x01\x33\x06', b'DN OSP History file\r\n\x1a\x01\x33\x05'),
    'dn.dsk': (b'DN OSP Desktop\x1a\x97\x51', b'DN OSP Desktop\x1a\x97\x50'),
}


def check(ok, what, info=''):
    global bad
    print(('PASS ' if ok else 'FAIL ') + what, flush=True)
    if not ok:
        bad += 1
        if info:
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


def junk(seed, n=600):
    r = random.Random(seed)
    return bytes(r.randrange(256) for _ in range(n))


def run(out, name, form, data):
    d = tempfile.mkdtemp(prefix='dnbadcfg-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
                src = os.path.join(out, f)
                (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
        with open(os.path.join(d, name), 'wb') as f:
            f.write(data)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': 'ENGLISH', 'DN2': d, 'HOME': d})
        t.started()
        t.send('\x1b', 0.5)                    # a message about the desktop, if any
        t.pump(0.5, 3)
        time.sleep(0.5)
        text = t.text()
        alive = t.alive()
        check(alive and 'Runtime error' not in text and 'Fatal Error' not in text and 'File' in text,
              '%s, %s: DN starts and stays' % (name, form), '%s (status %r)' % (text, t.status))
        t.close(0.3)
    finally:
        shutil.rmtree(d, ignore_errors=True)


out = os.path.abspath(sys.argv[1])
cases = []
for name, (head, old) in HEADS.items():
    cases.append((name, 'the head of another version', old + junk(name + 'old')))
    cases.append((name, 'this head and bytes that are not a stream', head + junk(name + 'head')))
    cases.append((name, 'bytes only', junk(name)))
side_by_side([lambda c=c: run(out, *c) for c in cases])          # every case is a start of its own: all at once
sys.exit(1 if bad else 0)
