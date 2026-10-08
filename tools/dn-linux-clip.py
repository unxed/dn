#!/usr/bin/env python3
"""The clipboard of DN on Linux (a pty): tools/dn-linux-clip.py OUTDIR
  - copy in the editor (Ctrl-Ins) sends the text to the terminal by OSC 52;
  - paste inside DN (Shift-Ins) puts the copied text back;
  - a paste by the terminal (bracketed paste) goes into the editor and into the command line of the panels, as one piece (no key commands are run from it);
  - TV_CLIPBOARD=0 keeps the copied text inside DN (no OSC 52)."""
import base64, os, re, shutil, sys, tempfile
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
    d = tempfile.mkdtemp(prefix='dnclip-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    open(os.path.join(w, 'a.txt'), 'w').write('hello clipboard\n')
    return d, w


def start(d, w, env=None):
    e = {'DNLNG': 'ENGLISH', 'DN2': d, 'TERM': 'xterm-256color'}
    e.update(env or {})
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env=e)
    t.started()
    t.send('\x1b', 0.5)
    return t


def osc52(raw):
    return [base64.b64decode(x) for x in re.findall(rb'\x1b\]52;[a-z]*;([A-Za-z0-9+/=]*)(?:\x07|\x1b\\)', raw)]


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    d, w = install(out); dirs.append(d)
    t = start(d, w)
    t.send('\x1b[B', 0.3); t.send('\x1bOS', 1.0)                 # F4 on a.txt
    t.raw = b''
    for _ in range(5):
        t.send('\x1b[1;2C', 0.2)                                  # Shift-Right x5: "hello"
    t.send('\x1b[2;5~', 0.8)                                      # Ctrl-Ins: copy
    check(osc52(t.raw) == [b'hello'], 'copy: the terminal gets "hello" by OSC 52', repr(t.raw[-200:]))
    t.send('\x1b[F', 0.3)                                         # End
    t.send('\x1b[2;2~', 0.8)                                      # Shift-Ins: paste inside DN
    check('hello clipboardhello' in t.text(), 'paste in DN: the copied text comes back at the cursor', t.text())
    t.send('\x1b[200~PASTED text\x1b[201~', 0.8)                   # the terminal pastes
    check('PASTED text' in t.text(), 'bracketed paste: the text of the terminal goes into the editor', t.text())
    t.send('\x1b', 0.3); t.send('n', 0.8)                          # leave the editor without saving (if it asks)
    t.send('\x1b', 0.3)
    t.send('\x1b[200~echo from-paste\x1b[201~', 0.8)
    check('echo from-paste' in t.text(), 'bracketed paste: the text goes into the command line of the panels', t.text())
    check(t.alive() and 'Fatal' not in t.text(), 'DN is alive after the pastes', t.text())
    t.close(0.3)

    d, w = install(out); dirs.append(d)
    t = start(d, w, {'TV_CLIPBOARD': '0'})
    t.send('\x1b[B', 0.3); t.send('\x1bOS', 1.0)
    t.raw = b''
    for _ in range(5):
        t.send('\x1b[1;2C', 0.2)
    t.send('\x1b[2;5~', 0.8)
    check(osc52(t.raw) == [], 'TV_CLIPBOARD=0: nothing is sent to the terminal', repr(t.raw[-200:]))
    t.send('\x1b[F', 0.3); t.send('\x1b[2;2~', 0.8)
    check('hello clipboardhello' in t.text(), 'TV_CLIPBOARD=0: paste inside DN still works', t.text())
    t.send('\x1b', 0.3); t.send('n', 0.5)
    t.close(0.3)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
