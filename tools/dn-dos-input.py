#!/usr/bin/env python3
"""Tests of DN for DOS that need the mouse driver and a normal exit, in DOSBox-X on a virtual X display (Xvfb): the mouse is a real X pointer that DOSBox-X turns into
INT 33h, the keys of the harness (DNKEYS) drive the menus. The checks look at the dump of the screen (DNDUMP).
usage: tools/dn-dos-input.py OUTDIR [SCENARIO...]      OUTDIR has the build of DN for DOS (dn.exe, *.dlg, *.lng, *.hlp, cwsdpmi.exe: tools/build.sh dos OUTDIR)
Scenarios: mouse-menu (a click on File opens the menu), mouse-dir (a double click on a directory enters it), mouse-fkey (a click on F7 in the status line opens
the dialog), autosave (Options -> Startup: Autosave Desktop and Preserve directory, enter a directory, File -> Exit; the next start shows the directory),
utf8-names-cp (the build with the code page inside, the DOS with UTF-8 names: Russian names are shown in cp866 and the directory is entered; needs the patched DOSBox-X, DN_DOS_PATCHED=1), files (the keys of the harness on real files: F7 makes a directory, F5 copies, F6 moves, F8 deletes; checked on the file system of the host), edit (F4 edits and F2 saves a real file, F3 views one), save-setup (Alt-K, a column, Store, OK, a restart), clipboard (the editor copies, a DOS program reads the DOS clipboard; needs nasm and DN_DOS_PATCHED=1), pages (chcp 437, 850, 852, 866, 1125: the frames, Russian on 866, Ukrainian on 1125), all of them by default. names-cp-plain (the same names with the stock DOSBox-X, which has no UTF-8 provider: the DOS gives them in the code page; without DN_DOS_PATCHED=1), (The button "Save setup" of the panel setup dialogs is not driven: the saving of the settings of the dialogs is checked by the scenario autosave.)
Needs: Xvfb, libX11 and libXtst (ctypes), dosbox-x (the package of Ubuntu is enough; DOSBOX_X=path to another). The tests of the UTF-8 names need a DOSBox-X with the UTF-8 DOS API (`master` since October 2026; before that the patches of
docs/patches): DN_DOS_PATCHED=1 adds the option `utf8 file names` and the scenario utf8-names."""
import ctypes, os, shutil, subprocess, sys, tempfile, time

DISPLAY = os.environ.get('DN_XDISPLAY', ':97')
DBX = os.environ.get('DOSBOX_X', 'dosbox-x')
PATCHED = os.environ.get('DN_DOS_PATCHED') == '1'
CW, CH = 9, 16                                   # a cell of the text screen of 80x25 in the window of 720x400
STARTUP = int(os.environ.get('DN_DOS_STARTUP', '12'))   # the seconds from the start of the emulator to the first screen of DN

x11 = ctypes.CDLL('libX11.so.6')
xt = ctypes.CDLL('libXtst.so.6')
x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XDefaultRootWindow.restype = ctypes.c_ulong
x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x11.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong),
                           ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_uint)]
x11.XGetWindowAttributes.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_void_p]


class Attr(ctypes.Structure):
    _fields_ = [('x', ctypes.c_int), ('y', ctypes.c_int), ('w', ctypes.c_int), ('h', ctypes.c_int)] + [('pad%d' % i, ctypes.c_int) for i in range(100)]


class Screen:
    """The X display and the pointer."""
    def __init__(self):
        self.xvfb = subprocess.Popen(['Xvfb', DISPLAY, '-screen', '0', '1024x768x24'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(50):
            self.d = x11.XOpenDisplay(DISPLAY.encode())
            if self.d:
                break
            time.sleep(0.2)
        if not self.d:
            sys.exit('no X display %s' % DISPLAY)
        self.root = x11.XDefaultRootWindow(self.d)

    def window(self):
        """(x, y, w, h) of the window of the emulator, None if it is not there"""
        r = ctypes.c_ulong(); p = ctypes.c_ulong(); ch = ctypes.POINTER(ctypes.c_ulong)(); n = ctypes.c_uint()
        x11.XQueryTree(self.d, self.root, ctypes.byref(r), ctypes.byref(p), ctypes.byref(ch), ctypes.byref(n))
        for i in range(n.value):
            a = Attr()
            x11.XGetWindowAttributes(self.d, ch[i], ctypes.byref(a))
            if a.w >= 640:
                return a.x, a.y, a.w, a.h
        return None

    def _flush(self):
        x11.XFlush(ctypes.c_void_p(self.d))

    def move(self, x, y):
        xt.XTestFakeMotionEvent(ctypes.c_void_p(self.d), 0, x, y, 0)
        self._flush()

    def button(self, b, down):
        xt.XTestFakeButtonEvent(ctypes.c_void_p(self.d), b, 1 if down else 0, 0)
        self._flush()

    def click_cell(self, col, row, times=1, wait=0.25):
        w = self.window()
        if w is None:
            return False
        x = w[0] + col * CW + CW // 2
        y = w[1] + row * CH + CH // 2
        self.move(x, y)
        time.sleep(0.4)
        for _ in range(times):
            self.button(1, True)
            time.sleep(0.06)
            self.button(1, False)
            time.sleep(wait)
        return True

    def close(self):
        self.xvfb.terminate()


def prepare(src, work):
    """the work directory of a scenario: DN, the resources, a directory with files"""
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(os.path.join(work, 'sub'))
    for f in os.listdir(src):
        p = os.path.join(src, f)
        if os.path.isfile(p) and f.lower().endswith(('.exe', '.dlg', '.lng', '.hlp')):
            shutil.copy(p, os.path.join(work, f.lower() if f.lower() != 'dn.exe' else 'dn.exe'))
    xlt = os.path.join(src, 'xlt')
    if os.path.isdir(xlt):
        shutil.copytree(xlt, os.path.join(work, 'xlt'))
    for n in ('plain.txt', 'two.txt'):
        open(os.path.join(work, 'sub', n), 'w').write('hi\n')


def run(work, seconds, keys, screen=None, actions=(), extra=(), after=()):
    """One run of DN: keys by DNKEYS (the harness), actions = [(seconds from the start, function)] on the pointer; returns the lines of the dump of the screen or None"""
    for f in ('SCR.DAT', 'SER.TXT'):
        try:
            os.remove(os.path.join(work, f))
        except OSError:
            pass
    env = dict(os.environ, SDL_AUDIODRIVER='dummy')
    cmd = [DBX, '-nogui', '-noconsole', '-defaultconf', '-set', 'dos lfn=true', '-set', 'dos ver=7.1', '-set', 'serial serial1=file file:SER.TXT']
    if PATCHED:
        cmd += ['-set', 'dos utf8 file names=true']
    cmd += ['-c', 'mount c ' + work, '-c', 'c:', '-c', 'set DNDUMP=SCR.DAT', '-c', 'set DNSERIAL=1', '-c', 'set DNDUMPSEC=%d' % seconds]
    if keys:
        cmd += ['-c', 'set DNKEYS=' + keys]
    cmd += list(extra) + ['-c', 'DN.EXE > OUT.TXT'] + list(after) + ['-c', 'exit']
    if screen is not None:
        env['DISPLAY'] = DISPLAY
        env['SDL_VIDEODRIVER'] = 'x11'
    else:
        env['SDL_VIDEODRIVER'] = 'dummy'
        cmd.insert(1, '-silent')
    t0 = time.time()
    p = subprocess.Popen(cmd, cwd=work, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for at, fn in actions:
        time.sleep(max(0, t0 + at - time.time()))
        fn()
    try:
        p.wait(timeout=seconds + 120)
    except subprocess.TimeoutExpired:
        p.kill()
    scr = os.path.join(work, 'SCR.DAT')
    if not os.path.isfile(scr):
        return None
    out = subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'render-dump.py'), scr], capture_output=True, text=True)
    return out.stdout.splitlines()


fails = 0
count = 0


def check(ok, what, lines=None):
    global fails, count
    count += 1
    print(('PASS ' if ok else 'FAIL ') + what)
    if not ok:
        fails += 1
        if lines:
            print('\n'.join('    | ' + l[:80] for l in lines[:25]))


def has(lines, text):
    return lines is not None and any(text in l for l in lines)


def sc_mouse_menu(src, work, scr):
    prepare(src, work)
    lines = run(work, STARTUP + 14, '011B', scr, [(STARTUP, lambda: scr.click_cell(6, 0))])
    check(has(lines, 'Change name case') and has(lines, 'Make directory'), 'mouse: a click on File opens its menu (INT 33h)', lines)


def sc_mouse_dir(src, work, scr):
    prepare(src, work)
    # the panels list the directories first: "sub" is the first entry of the left panel (column 1, row 3); the active panel is the right one at the start
    lines = run(work, STARTUP + 16, '011B', scr, [(STARTUP, lambda: scr.click_cell(5, 3, 2, 0.12))])
    check(has(lines, 'C:\\sub'), 'mouse: a double click on a directory enters it', lines)


def sc_mouse_fkey(src, work, scr):
    prepare(src, work)
    lines = run(work, STARTUP + 14, '011B', scr, [(STARTUP, lambda: scr.click_cell(57, 24))])
    check(has(lines, 'Make directory') or has(lines, 'Create'), 'mouse: a click on F7 in the status line opens the make directory dialog', lines)


EXIT = '4400,4D00,1C0D,4800,1C0D,1C0D'      # F10, File, up to the last item (Exit), Enter, "Yes"
R6 = ','.join(['4D00'] * 6)


def sc_autosave(src, work, scr):
    prepare(src, work)
    # Options (F10 and six Right) -> Configuration > -> Startup...: Autosave Desktop and Preserve directory on, OK; into the directory sub; File -> Exit
    keys1 = '011B,4400,%s,1C0D,1C0D,5000,1C0D,0F09,5000,3920,5000,5000,3920,1C0D' % R6
    run(work, 40, keys1)
    keys2 = '011B,0F09,1C0D,' + EXIT
    run(work, 40, keys2)
    ini = os.path.join(work, 'dn.ini')
    check(os.path.isfile(ini) and b'[Saved]' in open(ini, 'rb').read(), 'the setup: the settings of the dialogs are in the section [Saved] of dn.ini (and they came back: the autosave below works)')
    check(os.path.isfile(os.path.join(work, 'dn.dsk')), 'autosave: dn.dsk is written at the exit')
    lines = run(work, 14, '011B')
    check(has(lines, 'C:\\sub'), 'autosave: the next start restores the directory of the panel', lines)


def sc_utf8_names_cp(src, work, scr):
    """The build with the code page inside (cp866 for the screen) and the DOS with UTF-8 names (the patched DOSBox-X): the host names are UTF-8, DN shows them in the
    code page, goes into the directory and shows its path in the code page (osdep: DosNameToUtf8 and DosNameFromUtf8)."""
    if not PATCHED:
        print('SKIP utf8-names-cp: needs DN_DOS_PATCHED=1 (the patched DOSBox-X)')
        return
    prepare(src, work)
    os.makedirs(os.path.join(work, 'Каталог'), exist_ok=True)
    open(os.path.join(work, 'Каталог', 'Файл.txt'), 'w').write('hi\n')
    open(os.path.join(work, 'Привет.txt'), 'w').write('hi\n')
    extra = ['-c', 'chcp 866']
    lines = run(work, STARTUP + 8, '011B', None, extra=extra)
    check(has(lines, 'Привет'), 'UTF-8 names: a file with a Russian name is shown in the code page', lines)
    check(has(lines, 'Каталог'), 'UTF-8 names: a directory with a Russian name is shown in the code page', lines)
    # the active panel is the right one (C:\); its directories: sub, TEMP, xlt, Каталог (the fourth: row 6)
    lines = run(work, STARTUP + 16, '011B', scr, [(STARTUP, lambda: scr.click_cell(55, 6, 2, 0.12))], extra=extra)
    check(has(lines, 'C:\\Каталог') and has(lines, 'Файл'), 'UTF-8 names: a double click on the directory enters it (the path and the file are in the code page)', lines)


def sc_names_cp_plain(src, work, scr):
    """The same build and names with the stock DOSBox-X: there is no provider DOS-UTF8/NAMES, the DOS gives the names in the code page (the host UTF-8 names become cp866 ones
    by the emulator, `chcp 866`): DN shows them and goes into the directory just the same (the names are what the DOS gives)."""
    if PATCHED:
        print('SKIP names-cp-plain: it is for the stock DOSBox-X (without DN_DOS_PATCHED=1)')
        return
    prepare(src, work)
    os.makedirs(os.path.join(work, 'Каталог'), exist_ok=True)
    open(os.path.join(work, 'Каталог', 'Файл.txt'), 'w').write('hi\n')
    open(os.path.join(work, 'Привет.txt'), 'w').write('hi\n')
    extra = ['-c', 'chcp 866']
    lines = run(work, STARTUP + 8, '011B', None, extra=extra)
    check(has(lines, 'Привет'), 'plain DOS: a file with a Russian name is shown in the code page', lines)
    check(has(lines, 'Каталог'), 'plain DOS: a directory with a Russian name is shown in the code page', lines)


def sc_files(src, work, scr):
    """The keys of the harness on real files (DOS, on the file system of the host): F7 makes a directory, F5 copies, F6 moves, F8 deletes."""
    prepare(src, work)
    # Esc (the About box); F7, "newd", Enter; Down (the directory sub), Enter (into it); Down (plain.txt), F5, Enter (to the other panel, C:\); F8, Enter (Yes);
    # the cursor is on two.txt: F6, Enter (to C:\)
    keys = '011B,4100,316E,1265,1177,2064,1C0D,5000,1C0D,5000,3F00,1C0D,4200,1C0D,4000,1C0D'
    run(work, 60, keys)
    check(os.path.isdir(os.path.join(work, 'newd')), 'F7: the directory is made')
    check(os.path.isfile(os.path.join(work, 'plain.txt')) and open(os.path.join(work, 'plain.txt')).read() == 'hi\n', 'F5: plain.txt is copied to the other panel')
    check(not os.path.exists(os.path.join(work, 'sub', 'plain.txt')), 'F8: plain.txt is deleted from sub')
    check(os.path.isfile(os.path.join(work, 'two.txt')) and not os.path.exists(os.path.join(work, 'sub', 'two.txt')), 'F6: two.txt is moved to the other panel')


def sc_edit(src, work, scr):
    """F4 opens the editor on a real file, a typed character and F2 save it; F3 views a file and Esc leaves the viewer (DOS, on the file system of the host)."""
    prepare(src, work)
    # Esc (the About box); the active panel is the right one, in C:\\ (the first entry is the directory sub): Enter (into it); Down (plain.txt); F4, "Z", F2 (save),
    # Esc (leave the editor); Down (two.txt); F3, Esc
    keys = '011B,1C0D,5000,3E00,2C5A,3C00,011B,5000,3D00,011B'
    lines = run(work, 50, keys)
    check(open(os.path.join(work, 'sub', 'plain.txt')).read() == 'Zhi\n', 'F4: the typed character is saved by F2')
    check(open(os.path.join(work, 'sub', 'two.txt')).read() == 'hi\n', 'F3: the viewer does not change the file')
    check(has(lines, 'C:\\sub') and not has(lines, 'Fatal'), 'F3, Esc: back in the panel', lines)


def sc_save_setup(src, work, scr):
    """The button Store of the dialog of the panel appearance (Alt-K): a column is switched on, Store, OK, OK, out of DN; the next start shows the column on (the setup was saved)."""
    prepare(src, work)
    noop = ',8600' * 16                       # F12: nothing happens while the clicks are made
    keys = '011B,A2500,3920' + noop + ',' + EXIT
    clicks = [(STARTUP + 6, lambda: scr.click_cell(70, 18)),      # Store
              (STARTUP + 8, lambda: scr.click_cell(26, 18)),      # OK of "Save panel settings"
              (STARTUP + 10, lambda: scr.click_cell(50, 20))]     # OK of the dialog of the panel
    run(work, 80, keys, scr, clicks)
    lines = run(work, 14, '011B,A2500')
    check(has(lines, '[X] Size') and has(lines, 'File Panel appearance'), 'Store: the next start has the column Size on in the dialog of the panel', lines)


def sc_clipboard(src, work, scr):
    """The clipboard of DN in DOSBox-X (the DOS clipboard API, the provider DOS-UTF8/CLIPBRD): the editor copies "hi", DN is left, and a DOS program (docs/patches/dosbox-x-test/utf8clip.asm,
    built with nasm) reads the text of the clipboard."""
    if not PATCHED:
        print('SKIP clipboard: needs DN_DOS_PATCHED=1 (a DOSBox-X with the UTF-8 DOS API)')
        return
    if shutil.which('nasm') is None:
        print('SKIP clipboard: no nasm')
        return
    prepare(src, work)
    here = os.path.dirname(os.path.abspath(__file__))
    subprocess.run(['nasm', '-f', 'bin', '-o', os.path.join(work, 'UCLIP.COM'), os.path.join(here, '..', 'docs', 'patches', 'dosbox-x-test', 'utf8clip.asm')], check=True)
    # Esc (the About box); Enter (into sub: the first entry); Down (plain.txt); F4 (the editor), Shift-Right twice, Ctrl-Ins (copy), Esc (leave the editor); File -> Exit
    keys = '011B,1C0D,5000,3E00,S4D00,S4D00,C9200,011B,' + EXIT
    run(work, 60, keys, None, extra=['-set', 'dos clipboard api=true'], after=['-c', 'UCLIP.COM > CLIP.TXT'])
    out = open(os.path.join(work, 'CLIP.TXT'), errors='replace').read() if os.path.isfile(os.path.join(work, 'CLIP.TXT')) else ''
    check('SET=FF' in out, 'the clipboard provider is there', out.split('\n'))
    check('TEXT=6869' in out, 'the text that DN copied (hi) is in the DOS clipboard', out.split('\n'))


def screen_rows(work, page):
    """the rows of the dump of the screen decoded by the code page of the DOS (the cells hold the bytes of the page)"""
    import struct
    data = open(os.path.join(work, 'SCR.DAT'), 'rb').read()
    w, h = struct.unpack_from('<HH', data, 0)
    cells = struct.unpack_from('<%dH' % (w * h), data, 4)
    return [bytes(c & 255 for c in cells[y * w:(y + 1) * w]).decode('cp%d' % page, 'replace') for y in range(h)]


def sc_pages(src, work, scr):
    """The code pages of the DOS (chcp in DOSBox-X): the build with the code page inside shows its language by the page of the machine: the frames are the same on 437, 850, 852, 866, 1125; Russian
    on 866, Ukrainian on 1125 (its letters are not where they are on 866)."""
    ru = '\u0424\u0430\u0439\u043b  \u0414\u0438\u0441\u043a  \u0423\u0442\u0438\u043b\u0438\u0442\u044b  \u041f\u0430\u043d\u0435\u043b\u044c'
    ua = ['\u0423\u0442\u0438\u043b\u0456\u0442\u0438', '\u0456\u043c\'\u044f', '\u0412\u0456\u043a\u043d\u0430']
    cases = [(437, 'ENGLISH', ['File  Disk  Utilities  Panel', 'F1 Help']), (850, 'ENGLISH', ['File  Disk  Utilities  Panel', 'F1 Help']),
             (852, 'ENGLISH', ['File  Disk  Utilities  Panel', 'F1 Help']), (866, 'RUSSIAN', [ru]), (1125, 'UKRAIN', ua)]
    for page, lang, words in cases:
        prepare(src, work)
        run(work, 14, '011B', None, extra=['-c', 'chcp %d' % page, '-c', 'set DNLNG=%s' % lang])
        if not os.path.isfile(os.path.join(work, 'SCR.DAT')):
            check(False, 'page %d, %s: DN gave a screen' % (page, lang))
            continue
        rows = screen_rows(work, page)
        text = '\n'.join(rows)
        for w in words:
            check(w in text, 'page %d, %s: the screen has %r' % (page, lang, w), rows[:6])
        check('\u2550' in text and '\u2551' in text, 'page %d, %s: the frames are on the screen' % (page, lang), rows[:6])
    # the help (F1) in its own language: Russian on 866, Ukrainian on 1125
    helps = [(866, 'RUSSIAN', ['\u0424\u0430\u0439\u043b\u043e\u0432\u0430\u044f \u043f\u0430\u043d\u0435\u043b\u044c']),
             (1125, 'UKRAIN', ['\u0424\u0430\u0439\u043b\u043e\u0432\u0430 \u043f\u0430\u043d\u0435\u043b\u044c', '\u0432\u0456\u0434\u043a\u0440\u0438\u0432\u0430\u0454'])]
    for page, lang, words in helps:
        prepare(src, work)
        run(work, 20, '011B,3B00', None, extra=['-c', 'chcp %d' % page, '-c', 'set DNLNG=%s' % lang])
        rows = screen_rows(work, page) if os.path.isfile(os.path.join(work, 'SCR.DAT')) else []
        text = '\n'.join(rows)
        check(' Help ' in text, 'page %d, %s: F1 opens the help' % (page, lang), rows[:8])
        for w in words:
            check(w in text, 'page %d, %s: the help text has %r' % (page, lang, w), rows[:12])


SCEN = {'mouse-menu': sc_mouse_menu, 'mouse-dir': sc_mouse_dir, 'mouse-fkey': sc_mouse_fkey, 'autosave': sc_autosave, 'utf8-names-cp': sc_utf8_names_cp, 'names-cp-plain': sc_names_cp_plain, 'files': sc_files, 'edit': sc_edit, 'save-setup': sc_save_setup, 'clipboard': sc_clipboard, 'pages': sc_pages}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = os.path.abspath(sys.argv[1])
    names = sys.argv[2:] or list(SCEN)
    work = os.path.join(tempfile.gettempdir(), 'dn-dos-input')
    screen = Screen()
    try:
        for n in names:
            if n not in SCEN:
                sys.exit('unknown scenario %s: %s' % (n, ' '.join(SCEN)))
            SCEN[n](src, work, screen)
    finally:
        screen.close()
    print('ALL OK (%d checks)' % count if not fails else '%d of %d checks FAILED' % (fails, count))
    sys.exit(1 if fails else 0)


main()
