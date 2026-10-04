#!/usr/bin/env python3
"""The file operations of the Linux build of DN in a pty, checked on the file system: make a directory, copy, move, delete, edit and
save a file. usage: tools/dn-linux-ops.py OUTDIR   (OUTDIR: the result of tools/build.sh linux|linux64)"""
import base64
import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

F = {'F1': '\x1bOP', 'F2': '\x1bOQ', 'F3': '\x1bOR', 'F4': '\x1bOS', 'F5': '\x1b[15~', 'F6': '\x1b[17~', 'F7': '\x1b[18~', 'F8': '\x1b[19~', 'F10': '\x1b[21~',
     'DOWN': '\x1b[B', 'UP': '\x1b[A', 'ENTER': '\r', 'HOME': '\x1b[H', 'END': '\x1b[F', 'ESC': '\x1b', 'ALT-X': '\x1bx', 'TAB': '\t', 'CTRL-R': '\x12', 'INS': '\x1b[2~'}
fails = count = 0


def check(cond, name, info=''):
    global fails, count
    count += 1
    print(('PASS ' if cond else 'FAIL ') + name)
    if not cond:
        fails += 1
        if info:
            print(info)


def main():
    out = os.path.abspath(sys.argv[1])
    d = tempfile.mkdtemp(prefix='dnops-')
    try:
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), d)
            elif f == 'xlt':
                shutil.copytree(os.path.join(out, f), os.path.join(d, f))
        w = os.path.join(d, 'work')
        os.makedirs(w)
        open(os.path.join(w, 'a.txt'), 'w').write('first\n')
        open(os.path.join(w, 'b.txt'), 'w').write('other\n')
        open(os.path.join(w, 'c.txt'), 'w').write('third\n')
        payload = os.urandom(3 * 1024 * 1024 + 123)       # more than 64K: the copy buffer (Word was 16 bits)
        open(os.path.join(w, 'z.txt'), 'wb').write(payload)
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        t.pump(1.5, 6)
        check(b'Error in country' not in t.raw, 'start: no country setup error (xlt next to the program)')
        t.send(F['ESC'], 0.5)

        def key(k, settle=0.6):
            t.send(F.get(k, k), settle)

        # the order of the panel: .., newdir, a, b, c (the default sort is by extension, then by name)
        key('F7'); key('newdir'); key('ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, 'newdir')), 'F7: the directory is made')

        # the cursor moves: only the two lines of the panel are redrawn, they must be the same as in the other panel (the same directory)
        key('HOME'); key('DOWN')
        rows = [l for l in t.text().split('\n') if 'newdir' in l or ' txt' in l]
        halves = [(l[1:20].strip(), l[51:70].strip()) for l in rows]
        check(rows and all(a_ == b_ for a_, b_ in halves) and '\u2642' not in t.text(), 'Down: the redrawn lines of the panel are not garbage (the same as in the other panel)', t.text())

        # copy a.txt into newdir: the cursor on a.txt (.., newdir, a.txt; DN puts the cursor on the new directory)
        key('HOME'); key('DOWN'); key('DOWN')
        key('F5'); key('newdir'); key('ENTER', 1.2)
        check(os.path.isfile(os.path.join(w, 'newdir', 'a.txt')) and os.path.isfile(os.path.join(w, 'a.txt')),
              'F5: a.txt is copied into newdir, the original stays', t.text())
        if os.path.isfile(os.path.join(w, 'newdir', 'a.txt')):
            check(open(os.path.join(w, 'newdir', 'a.txt')).read() == 'first\n', 'F5: the copy has the same content')

        # move b.txt into newdir
        key('DOWN')
        key('F6'); key('newdir'); key('ENTER', 1.2)
        check(os.path.isfile(os.path.join(w, 'newdir', 'b.txt')) and not os.path.exists(os.path.join(w, 'b.txt')),
              'F6: b.txt is moved into newdir', t.text())

        # delete c.txt (the cursor is on the next file after the moved one)
        key('F8'); key('ENTER', 1.2)
        gone = not os.path.exists(os.path.join(w, 'c.txt'))
        check(gone, 'F8: the file under the cursor is deleted (c.txt)', t.text())

        # a big file (the last one in the list): the copy must be the same bytes
        key('END')
        key('F5'); key('newdir'); key('ENTER', 2.5)
        got = os.path.join(w, 'newdir', 'z.txt')
        check(os.path.isfile(got) and open(got, 'rb').read() == payload, 'F5: a file of 3 MB is copied byte by byte', t.text())

        # edit a.txt: the cursor on a.txt; F4, a line at the top, F2 saves, Esc leaves
        key('HOME'); key('DOWN'); key('DOWN')
        key('F4', 1.0)
        key('hello ')
        key('F2', 0.8)
        key('ESC', 0.8)
        txt = open(os.path.join(w, 'a.txt')).read() if os.path.exists(os.path.join(w, 'a.txt')) else None
        check(txt is not None and txt.startswith('hello first'), 'F4: the edited text is saved (%r)' % (txt,), t.text())

        # into a directory and back
        key('HOME'); key('DOWN'); key('ENTER', 1.0)
        title = t.text().split('\n')[1]
        check('NEWDIR' in title.upper() and 'a' in t.text().split('\n')[3] + t.text().split('\n')[4],
              'Enter on a directory shows it (the title has newdir)', t.text())
        key('HOME'); key('ENTER', 1.0)
        check('NEWDIR' not in t.text().split('\n')[1].upper(), 'Enter on .. goes back up', t.text())

        # the help, several times: the window of the help is kept between the calls and was used after it was freed
        for _ in range(4):
            key('F1', 1.0)
            for _ in range(6):                       # Esc until the window of the help is gone (a slow machine needs time)
                if '\u2550 Help \u2550' not in t.text():
                    break
                key('ESC', 0.8)
        check(t.alive() and 'Fatal' not in t.text() and 'Name' in t.text() and '\u2550 Help \u2550' not in t.text(), 'F1 and Esc four times: no crash', t.text())

        # Russian names: a directory made by F7 has the name in UTF-8 in the file system and is shown as Russian
        key('F7'); key('\u0442\u0435\u0441\u0442'); key('ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, '\u0442\u0435\u0441\u0442')), 'F7: a Russian name is a UTF-8 name in the file system', t.text())
        check('\u0442\u0435\u0441\u0442' in t.text(), 'the Russian name is shown as Russian', t.text())
        os.makedirs(os.path.join(w, '\u043f\u0430\u043f\u043a\u0430'))
        open(os.path.join(w, '\u043f\u0430\u043f\u043a\u0430', 'x.txt'), 'w').write('x')
        key('HOME'); key('DOWN'); key('ENTER', 1.0); key('HOME'); key('ENTER', 1.0)     # into newdir and back: the directory is read again
        check('\u043f\u0430\u043f\u043a\u0430' in t.text(), 'a directory with a Russian name made outside is shown as Russian', t.text())

        # a long Russian name typed into the dialog: the letters were drawn as other characters (the bytes of "ров", "рка" of CP866 are valid UTF-8)
        key('F7'); key('\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0434\u043b\u0438\u043d\u043d\u044b\u0445 \u0438\u043c\u0451\u043d', 0.8)
        check('\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0434\u043b\u0438\u043d\u043d\u044b\u0445 \u0438\u043c\u0451\u043d' in t.text(), 'the typed Russian text is drawn as typed in the input line', t.text())
        key('ENTER', 1.0)
        check(os.path.isdir(os.path.join(w, '\u041f\u0440\u043e\u0432\u0435\u0440\u043a\u0430 \u0434\u043b\u0438\u043d\u043d\u044b\u0445 \u0438\u043c\u0451\u043d')), 'the directory with the long Russian name is made')

        # Alt-F1, the drive menu, TEMP: (a temporary drive; the panel info was drawn with an empty list: collection error 213)
        key('\x1b[1;3P'); key('DOWN'); key('ENTER', 1.0)
        check('TEMP:' in t.text().split('\n')[1] and t.alive(), 'Alt-F1: the drive TEMP: opens without an error', t.text())

        # a command of the command line: the terminal is given to the shell, Enter returns to DN (it hung before)
        key('echo ran-ok > ran.txt; echo shown-ok'); key('ENTER', 1.5)
        check('shown-ok' in t.text() and 'Press Enter' in t.text(), 'a command: its output is on the screen and DN waits for Enter', t.text())
        key('ENTER', 1.5)
        check(os.path.isfile(os.path.join(w, 'ran.txt')) and open(os.path.join(w, 'ran.txt')).read() == 'ran-ok\n', 'the command was run in the directory of the panel')
        check('Name' in t.text() and t.alive(), 'DN is back with its panels', t.text())

        # the Info panel is on at the end: quitting disposes the windows (TGroup.Done followed a view that had been disposed: Access violation)
        # no Esc before F10: on an empty command line Esc shows the screen of the user
        key('F10'); [key('\x1b[C', 0.2) for _ in range(5)]; [key('DOWN', 0.2) for _ in range(3)]; key('ENTER', 1.0)
        check(t.alive() and 'Current directory' in t.text(), 'the Info panel is on', t.text())

        # the screen of the user: Ctrl-O shows what the commands drew (the emulator of tv/), a key leaves it
        key('\x0f', 1.0)
        check('shown-ok' in t.text() and 'ran-ok' in t.text(), 'Ctrl-O: the screen of the commands (the command line and its output)', t.text())
        key('x', 1.0)
        check('Name' in t.text() and t.alive(), 'a key leaves the screen of the user: the panels are back', t.text())

        key('ALT-X'); key('ENTER', 1.5)
        scr = t.text()
        status = t.close(4)
        check(status == 0, 'Alt-X ends the program (status %r)' % (status,), scr)

        if os.environ.get('DN_OPS_UTF8') == '1':          # the build with -dDNUTF8 (UTF-8 inside): what the legacy build cannot show
            u = os.path.join(d, 'u8')
            os.makedirs(u)
            for n in ('\u042f\u0431\u043b\u043e\u043a\u043e', '\u0430\u0440\u0431\u0443\u0437', '\u0410\u043b\u044c\u0444\u0430', '\u0431\u0435\u0442\u0430', 'Zeta'):
                open(os.path.join(u, n), 'w').write('x')
            open(os.path.join(u, '\u0444\u0430\u0439\u043b.txt'), 'w').write('\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440\nsecond\n')
            t = PtyTerm(['./dn'], 100, 30, cwd=u, exe=os.path.join(d, 'dn'))
            t.pump(1.5, 6)
            t.send(F['ESC'], 0.5)
            lines = [l for l in t.text().split('\n')]
            order = [n for n in ('Zeta', '\u0410\u043b\u044c\u0444\u0430', '\u0430\u0440\u0431\u0443\u0437', '\u0431\u0435\u0442\u0430', '\u042f\u0431\u043b\u043e\u043a\u043e')]
            pos = [next((i for i, l in enumerate(lines) if n in l), -1) for n in order]
            check(all(p >= 0 for p in pos) and pos == sorted(pos), 'UTF-8: the names are sorted ignoring the case (Zeta, \u0410\u043b\u044c\u0444\u0430, \u0430\u0440\u0431\u0443\u0437, \u0431\u0435\u0442\u0430, \u042f\u0431\u043b\u043e\u043a\u043e)', t.text())
            t.send(F['END'], 0.5)
            t.send(F['F3'], 1.2)
            check('\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440' in t.text(), 'UTF-8: F3 shows a Russian text file', t.text())
            t.send(F['ESC'], 0.5)
            t.send(F['ALT-X'], 0.8)
            t.send(F['ENTER'], 1.0)
            t.close(3)

            # the columns: a name with wide (CJK) letters takes two columns each, the next column stays in its place
            cj = os.path.join(d, 'u8cjk')
            os.makedirs(cj)
            for n in ('abc.txt', '\u65e5\u672c\u8a9e.txt', 'e\u0301x.txt'):
                open(os.path.join(cj, n), 'w').write('x')
            t = PtyTerm(['./dn'], 100, 30, cwd=cj, exe=os.path.join(d, 'dn'))
            t.pump(1.5, 6)
            t.send(F['ESC'], 0.5)
            rows = {k: next((l for l in t.text().split('\n') if k in l), '') for k in ('abc', '\u65e5\u672c\u8a9e', 'ex')}     # the screen of the test has no cell for a combining mark
            ok = all(rows.values())
            col = {k: v.find('txt') for k, v in rows.items()}
            check(ok and col['abc'] == col['\u65e5\u672c\u8a9e'] + 3 and col['abc'] == col['ex'], 'UTF-8: wide letters take two columns and a combining mark none (the extension stays in its column)', t.text())
            t.send(F['ALT-X'], 0.8)
            t.send(F['ENTER'], 1.0)
            t.close(3)

            # the Russian interface: Alt and a Cyrillic letter (the keyboard sends Esc and the letter in UTF-8)
            ru = os.path.join(d, 'u8ru')                                   # a new copy of the program: DN.INI of the first session keeps its language
            os.makedirs(os.path.join(ru, 'w'))
            for f in os.listdir(out):
                if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                    shutil.copy(os.path.join(out, f), ru)
                elif f == 'xlt':
                    shutil.copytree(os.path.join(out, f), os.path.join(ru, f))
            t = PtyTerm(['./dn'], 100, 30, env={'DNLNG': 'Russian'}, cwd=os.path.join(ru, 'w'), exe=os.path.join(ru, 'dn'))
            t.pump(1.5, 6)
            t.send(F['ESC'], 0.5)
            t.send('\x1b\u0444', 1.0)                                   # Alt-\u0444: the menu "\u0424\u0430\u0439\u043b"
            check('\u0421\u043c\u043e\u0442\u0440\u0435\u0442\u044c' in t.text(), 'UTF-8: Alt and a Cyrillic letter opens the menu', t.text())
            t.send(F['ESC'], 0.5)
            t.send(F['F7'], 1.0)
            t.send('\u0442\u0435\u0441\u0442\u0032', 0.5)
            t.send('\x1b\u043a', 1.2)                                   # Alt-\u043a: the button "\u041e~\u041a~"
            check(os.path.isdir(os.path.join(ru, 'w', '\u0442\u0435\u0441\u0442\u0032')), 'UTF-8: Alt and a Cyrillic letter presses the button of a dialog', t.text())
            t.send('\x13', 0.6)                                          # Ctrl-S: the quick search of the panel, Cyrillic letters
            t.send('\u0442\u0435', 0.8)
            check('\u041f\u043e\u0438\u0441\u043a: \u0442\u0435' in t.text(), 'UTF-8: Ctrl-S and Cyrillic letters make the mask of the quick search', t.text())
            t.send(F['ESC'], 0.5)
            t.send(F['ALT-X'], 0.8)
            t.send(F['ENTER'], 1.0)
            t.close(3)

            # the system clipboard: Edit/Copy of the editor puts the text on the clipboard of the terminal (OSC 52, UTF-8)
            t = PtyTerm(['./dn'], 100, 30, env={'TERM': 'xterm-256color'}, cwd=u, exe=os.path.join(d, 'dn'))
            t.pump(1.5, 6)
            t.send(F['ESC'], 0.5)
            t.send(F['END'], 0.5)
            t.send(F['F4'], 1.2)
            for _ in range(6):
                t.send('\x1b[1;2C', 0.5)                                   # Shift-Right: select
            t.send(F['F10'], 0.5)
            t.send('\x1b[C', 0.5)
            t.send(F['ENTER'], 0.8)
            t.send('c', 1.0)                                             # Copy
            got = [base64.b64decode(x).decode('utf-8', 'replace') for x in re.findall(rb'\x1b\]52;c;([A-Za-z0-9+/=]*)\x07', t.raw)]
            check(got and got[-1] == '\u041f\u0440\u0438\u0432\u0435\u0442', 'UTF-8: Edit/Copy puts the selected Russian text on the clipboard (OSC 52)', repr(got))
            t.send(F['ESC'], 0.5)
            t.send(F['ALT-X'], 0.8)
            t.send(F['ENTER'], 1.0)
            t.close(3)

            # the editor works by characters: typing, Backspace, the dash and the quotes of the text stay, the file is saved as UTF-8
            ed = os.path.join(d, 'u8ed')
            os.makedirs(ed)
            fn = os.path.join(ed, 'f.txt')
            open(fn, 'w', encoding='utf-8').write('\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440\n\u0432\u0442\u043e\u0440\u0430\u044f \u2014 \u0441\u0442\u0440\u043e\u043a\u0430 \u00abx\u00bb\n')
            t = PtyTerm(['./dn'], 100, 30, env={'TERM': 'xterm-256color'}, cwd=ed, exe=os.path.join(d, 'dn'))
            t.pump(1.5, 6)
            t.send(F['ESC'], 0.5)
            t.send(F['DOWN'], 0.3)
            t.send(F['DOWN'], 0.3)
            t.send(F['F4'], 1.2)
            t.send(F['HOME'], 0.4)
            t.send('\u0416', 0.5)
            t.send(F['END'], 0.4)
            t.send('!', 0.4)
            t.send(F['DOWN'], 0.4)
            t.send(F['END'], 0.4)
            t.send('\x7f', 0.4)
            t.send('\x7f', 0.4)
            scr = t.text()
            check('\u0416\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440!' in scr and '\u0432\u0442\u043e\u0440\u0430\u044f \u2014 \u0441\u0442\u0440\u043e\u043a\u0430 \u00ab' in scr, 'UTF-8 editor: the typed text is on the screen, Backspace removes characters', scr)
            t.send(F['F2'], 1.0)
            check(open(fn, encoding='utf-8').read() == '\u0416\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440!\n\u0432\u0442\u043e\u0440\u0430\u044f \u2014 \u0441\u0442\u0440\u043e\u043a\u0430 \u00ab\n', 'UTF-8 editor: the file is saved as UTF-8 (the dash and the quotes are kept)')
            t.send(F['UP'], 0.4)
            t.send(F['END'], 0.4)
            for ch in '\u03b1\u03b2\u2502\u2026':                 # Greek letters (the code page has none), a frame character (a cell of the table), the ellipsis
                t.send(ch, 0.4)
            t.send(F['F2'], 1.0)
            check(open(fn, encoding='utf-8').read() == '\u0416\u041f\u0440\u0438\u0432\u0435\u0442, \u043c\u0438\u0440!\u03b1\u03b2\u2502\u2026\n\u0432\u0442\u043e\u0440\u0430\u044f \u2014 \u0441\u0442\u0440\u043e\u043a\u0430 \u00ab\n', 'UTF-8 editor: characters outside the code page are typed and saved', open(fn, encoding='utf-8').read())
            t.send(F['ESC'], 0.5)
            t.send(F['ALT-X'], 0.8)
            t.send(F['ENTER'], 1.0)
            t.close(3)
        # Options -> Startup -> "Autosave Desktop" + "Preserve directory": the desktop is saved at Alt-X (DN.DSK next to the program) and comes back
        # at the next start (the active panel's directory is stored only with "Preserve directory": that is how TFilePanelRoot.Store is written)
        dd = os.path.join(d, 'dskrun')
        os.makedirs(os.path.join(dd, 'work', 'sub'))
        for f in os.listdir(out):
            if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
                shutil.copy(os.path.join(out, f), dd)
            elif f == 'xlt':
                shutil.copytree(os.path.join(out, f), os.path.join(dd, 'xlt'))
        dw = os.path.join(dd, 'work')

        def dsk_start():
            tt = PtyTerm(['./dn'], 100, 30, cwd=dw, exe=os.path.join(dd, 'dn'))
            tt.pump(1.5, 6)
            tt.send(F['ESC'], 0.5)
            return tt

        def dsk_cwd(tt):                                   # the directory of the active panel: the end of the command line prompt
            return [l for l in tt.text().split('\n') if l.rstrip().endswith('>')][-1].strip()

        def dsk_quit(tt):
            tt.send(F['ALT-X'], 0.8)
            tt.send(F['ENTER'], 1.0)
            tt.close(3)

        t = dsk_start()
        t.send(F['F10'], 0.4)
        for _ in range(6):
            t.send('\x1b[C', 0.2)                          # ... Panel Manager Options
        t.send(F['ENTER'], 0.6)                            # Options: Configuration >
        t.send(F['ENTER'], 0.6)
        t.send(F['DOWN'], 0.2)                             # Startup...
        t.send(F['ENTER'], 0.8)
        t.send(F['TAB'], 0.3)                              # the "Shutdown options" cluster: Inactivity, Autosave Desktop, blinking, Preserve directory
        t.send(F['DOWN'], 0.3)
        t.send(' ', 0.3)
        t.send(F['DOWN'], 0.3)
        t.send(F['DOWN'], 0.3)
        t.send(' ', 0.3)
        scr = t.text()
        check('[X] Autosave Desktop' in scr and '[X] Preserve directory' in scr, 'Startup dialog: both shutdown options are switched on', scr)
        t.send(F['ENTER'], 0.8)
        t.send(F['DOWN'], 0.3)
        t.send(F['ENTER'], 1.0)                            # into sub
        check(dsk_cwd(t).endswith('sub>'), 'autosave desktop: the panel is in sub before the exit', t.text())
        dsk_quit(t)
        check(os.path.isfile(os.path.join(dd, 'dn.dsk')), 'autosave desktop: dn.dsk is written at Alt-X')
        ini = os.path.join(dd, 'dn.ini')
        check(os.path.isfile(ini) and '[Saved]' in open(ini, errors='replace').read() and 'Size=' in open(ini, errors='replace').read(),
              'autosave desktop: the option itself is saved (the section [Saved] of dn.ini)')
        check(not os.path.isfile(os.path.join(dd, 'dn.cfg')), 'there is no separate dn.cfg any more')
        t = dsk_start()
        check(dsk_cwd(t).endswith('sub>'), 'autosave desktop: the next start restores the panel directory (sub)', t.text())
        dsk_quit(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
    sys.exit(1 if fails else 0)


main()
