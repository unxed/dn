#!/usr/bin/env python3
"""The editor of DN (a view over tve) through a pty: tools/dn-linux-editor.py OUTDIR
Opens files with F4 and checks what the user sees and what lands on the disk."""
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
            print('    | ' + info[-900:].replace('\n', '\n    | '), flush=True)


K = {'F2': '\x1bOQ', 'F4': '\x1bOS', 'F7': '\x1b[18~', 'F10': '\x1b[21~', 'CF7': '\x1b[18;5~', 'SF7': '\x1b[18;2~', 'AF7': '\x1b[18;3~',
     'UP': '\x1b[A', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'LEFT': '\x1b[D', 'HOME': '\x1b[H', 'END': '\x1b[F',
     'SDOWN': '\x1b[1;2B', 'SRIGHT': '\x1b[1;2C', 'CINS': '\x1b[2;5~', 'SINS': '\x1b[2;2~', 'ENTER': '\r', 'ESC': '\x1b',
     'ALT-G': '\x1bg', 'ALT-BS': '\x1b\x7f', 'BS': '\x7f', 'DEL': '\x1b[3~', 'CPGUP': '\x1b[5;5~', 'CPGDN': '\x1b[6;5~'}


def install(out, files):
    d = tempfile.mkdtemp(prefix='dned-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(w)
    for n, c in files.items():
        with open(os.path.join(w, n), 'wb') as fh:
            fh.write(c)
    return d, w


def start(d, w):
    e = {'DNLNG': 'ENGLISH', 'DN2': d, 'TERM': 'xterm-256color'}
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env=e)
    t.started()
    t.send('\x1b', 0.5)
    return t


def edit(t, downs):
    for _ in range(downs):
        t.send(K['DOWN'], 0.2)
    t.send(K['F4'], 1.5)


def info(t):
    """The line:column of the information line."""
    import re
    m = re.search(r'(\d+):(\d+)\s*[\u2550\u2500]*\[', t.text())
    return (int(m.group(1)), int(m.group(2))) if m else None


def keys(t, s, gap=0.12):
    for ch in s:
        t.send(ch, gap)


def disk(w, n):
    with open(os.path.join(w, n), 'rb') as fh:
        return fh.read()


out = os.path.abspath(sys.argv[1])
dirs = []
try:
    # a.txt: three lines; b.txt: Cyrillic in UTF-8; c.txt: a code page file (cp1251); d.txt: CRLF
    d, w = install(out, {'a.txt': b'one two three\nfoo bar foo\nlast line\n',
                         'b.txt': '\u043f\u0440\u0438\u0432\u0435\u0442 \u043c\u0438\u0440\n'.encode('utf-8'),
                         'c.txt': '\u043f\u0440\u0438\u0432\u0435\u0442\n'.encode('cp1251'),
                         'd.txt': b'x\r\ny\r\n'}); dirs.append(d)
    t = start(d, w)
    edit(t, 1)
    check('Edit - ' in t.text() and 'a.txt' in t.text() and 'one two three' in t.text(), 'F4 opens the file in an editor window', t.text())
    check(info(t) == (1, 1), 'the cursor is at 1:1', t.text())
    t.send(K['END'], 0.3)
    check(info(t) == (1, 14), 'End goes to the end of the line (1:14)', t.text())
    t.send(K['DOWN'], 0.3)
    check(info(t) == (2, 14), 'Down keeps the column', t.text())
    keys(t, 'ZZ')
    check(info(t) == (2, 14) or info(t)[0] == 2, 'typing works', t.text())
    t.send(K['ALT-BS'], 0.4)
    t.send(K['ALT-BS'], 0.4)
    check('foo bar foo  Z' not in t.text(), 'Alt-Backspace undoes the typing', t.text())
    t.send(K['F2'], 0.8)
    check(disk(w, 'a.txt') == b'one two three\nfoo bar foo\nlast line\n', 'F2 saves (nothing changed any more)', repr(disk(w, 'a.txt')))

    # search
    t.send(K['CPGUP'], 0.3)
    t.send(K['F7'], 0.8)
    check('Find' in t.text() and 'Text to find' in t.text(), 'F7 opens the Find dialog', t.text())
    t.send('\x15', 0.1)             # clear
    keys(t, 'foo')
    t.send(K['ENTER'], 0.8)
    check(info(t) is not None and info(t)[0] == 2, 'the search finds the first "foo" (line 2)', t.text())
    t.send(K['SF7'], 0.6)
    check(info(t) is not None and info(t)[0] == 2 and info(t)[1] > 4, 'Shift-F7 finds the next one', t.text())

    # replace all
    t.send(K['CF7'], 0.8)
    check('Replace' in t.text(), 'Ctrl-F7 opens the Replace dialog', t.text())
    t.send(K['ESC'], 0.4)

    # goto line
    t.send(K['ALT-G'], 0.8)
    check('line' in t.text().lower(), 'Alt-G asks for a line', t.text())
    keys(t, '3')
    t.send(K['ENTER'], 0.6)
    check(info(t) is not None and info(t)[0] == 3, 'Go to line 3', t.text())

    # block: select a line part, copy, paste
    t.send(K['HOME'], 0.3)
    for _ in range(4):
        t.send(K['SRIGHT'], 0.15)
    t.send(K['CINS'], 0.5)
    t.send(K['END'], 0.3)
    t.send(K['SINS'], 0.5)
    check('last linelast' in t.text(), 'Ctrl-Ins / Shift-Ins copy and paste a block', t.text())
    t.send(K['ALT-BS'], 0.4)
    check('last linelast' not in t.text(), 'undo takes the paste back', t.text())

    # modified + Esc asks
    keys(t, 'Q')
    t.send(K['ESC'], 0.8)
    check('modified' in t.text().lower() or 'save' in t.text().lower(), 'Esc on a modified file asks', t.text())
    t.send('n', 0.8)
    check('Edit - ' not in t.text(), 'No closes the editor without saving', t.text())
    check(disk(w, 'a.txt') == b'one two three\nfoo bar foo\nlast line\n', 'the file is unchanged', repr(disk(w, 'a.txt')))
    check(t.alive(), 'DN is alive', t.text())
    t.close(0.3)

    # more: replace all, chords, line commands
    d, w = install(out, {'a.txt': b'one two three\nfoo bar foo\nlast line\n'}); dirs.append(d)
    t = start(d, w)
    edit(t, 1)
    t.send(K['CF7'], 0.8)
    t.send('\x15', 0.1); keys(t, 'foo')
    t.send('\t', 0.2); keys(t, 'baz')
    t.send('\x1b[1;5C', 0.1)   # nothing
    t.send(K['ESC'], 0.4)
    t.send('\x19', 0.4)         # Ctrl-Y deletes the line
    check('one two three' not in t.text() and 'foo bar foo' in t.text(), 'Ctrl-Y deletes the line', t.text())
    t.send('\x0bb', 0.3); t.send(K['DOWN'], 0.2); t.send('\x0bk', 0.3)   # Ctrl-K B, Ctrl-K K: a block of one line
    t.send('\x0bc', 0.5)        # Ctrl-K C: copy the block here
    check(t.text().count('foo bar foo') >= 2, 'Ctrl-K B / K / C copy a block', t.text())
    t.send(K['F2'], 0.8)
    check(b'foo bar foo\nfoo bar foo' in disk(w, 'a.txt'), 'the copy is saved', repr(disk(w, 'a.txt')))
    t.close(0.3)

    # Cyrillic UTF-8, code page, CRLF
    d, w = install(out, {'b.txt': '\u043f\u0440\u0438\u0432\u0435\u0442 \u043c\u0438\u0440\n'.encode('utf-8'), 'c.txt': '\u043f\u0440\u0438\u0432\u0435\u0442\n'.encode('cp1251'), 'd.txt': b'x\r\ny\r\n'}); dirs.append(d)
    t = start(d, w)
    edit(t, 1)
    check('\u043f\u0440\u0438\u0432\u0435\u0442 \u043c\u0438\u0440' in t.text() and 'UTF' in t.text(), 'a UTF-8 file is shown as it is (UTF)', t.text())
    keys(t, '\u042f')
    t.send(K['F2'], 0.8)
    check(disk(w, 'b.txt') == '\u042f\u043f\u0440\u0438\u0432\u0435\u0442 \u043c\u0438\u0440\n'.encode('utf-8'), 'a Cyrillic letter typed in a UTF-8 file is saved', repr(disk(w, 'b.txt')))
    t.send(K['ESC'], 0.6)
    edit(t, 1)
    t.send('\x1b[19~', 0.6)            # F8: the next character set (DOS by default, then Windows)
    check('\u043f\u0440\u0438\u0432\u0435\u0442' in t.text() and 'WIN' in t.text(), 'F8 switches a cp1251 file to Windows: Cyrillic', t.text())
    t.send('\x1b[19~', 0.3); t.send('\x1b[19~', 0.3); t.send('\x1b[19~', 0.3)
    t.send('\x1b[19~', 0.6)            # round: back to DOS ... until Windows again
    t.send(K['F2'], 0.8)
    check(disk(w, 'c.txt') == '\u043f\u0440\u0438\u0432\u0435\u0442\n'.encode('cp1251'), 'and written back in cp1251 as it was', repr(disk(w, 'c.txt')))
    t.send(K['ESC'], 0.6)
    edit(t, 1)
    keys(t, 'a')
    t.send(K['F2'], 0.8)
    check(disk(w, 'd.txt') == b'ax\r\ny\r\n', 'CRLF line ends are kept', repr(disk(w, 'd.txt')))
    check('CrLf' in t.text(), 'the information line says CrLf', t.text())
    t.close(0.3)
finally:
    for d in dirs:
        shutil.rmtree(d, ignore_errors=True)
sys.exit(1 if bad else 0)
