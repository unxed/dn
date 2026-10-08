#!/usr/bin/env python3
"""PTY smoke tests for DN archive enter/leave, F3/F4, and F5 (class Linux / UTF-8).

Usage:
  python3 tools/dn-linux-archives.py OUTDIR

Uses tools/gen-archive-fixtures.py. Skips formats whose files were not generated; DN_ARC_ONLY='simple.zip ...' runs only those.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

KEYS = {
    'ENTER': '\r',
    'ESC': '\x1b',
    'HOME': '\x1b[H',
    'DOWN': '\x1b[B',
    'UP': '\x1b[A',
    'ALT-X': '\x1bx',
    'F3': '\x1bOR',
    'F4': '\x1bOS',
    'F5': '\x1b[15~',
}


def gen_fixtures(outdir: str) -> list[str]:
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(os.path.dirname(__file__), 'gen-archive-fixtures.py')
    subprocess.check_call(
        [sys.executable, path, outdir],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    man = os.path.join(outdir, 'MANIFEST.txt')
    if not os.path.exists(man):
        return []
    return [line.strip() for line in open(man, encoding='utf-8') if line.strip()]


def copy_dn(out: str, d: str) -> None:
    for f in os.listdir(out):
        src = os.path.join(out, f)
        if f == 'dn' or f.upper().endswith(('.LNG', '.DLG', '.HLP')):
            shutil.copy(src, d)
        elif f == 'xlt' and os.path.isdir(src):
            shutil.copytree(src, os.path.join(d, 'xlt'))


def check(cond: bool, msg: str, scr: str = '') -> None:
    if cond:
        print('PASS', msg, flush=True)
    else:
        print('FAIL', msg, flush=True)
        if scr:
            print(scr[-800:], flush=True)
        raise SystemExit(1)


def quit_dn(t: DnTerm) -> None:
    t.send(KEYS['ALT-X'], 0.4)
    t.send(KEYS['ENTER'], 0.6)
    try:
        t.close(2)
    except Exception:
        pass


def open_archive(t: DnTerm, name: str, expect_member: str, title_hint: str) -> str:
    t.started()
    t.send(KEYS['ESC'], 0.3)
    t.send(KEYS['HOME'], 0.15)
    t.send(KEYS['DOWN'], 0.2)
    scr = ''
    entered = False
    for attempt in range(2):
        if not entered:
            t.send(KEYS['ENTER'], 0.3)
            t0 = time.time()                    # the unpacker lists the archive: until the panel of the archive is shown
            while time.time() - t0 < 10.0 and not ((title_hint and title_hint in t.text()) or
                                                   expect_member.lower() in t.text().lower()):
                t.pump(0.3, 1)
            t.pump(0.5, 2)
        t0 = time.time()
        while time.time() - t0 < 4.0:
            t.pump(0.3, 1)
            scr = t.text()
            if title_hint and title_hint in scr:
                entered = True
            if expect_member.lower() in scr.lower():
                break
            if entered:
                time.sleep(0.2)
                continue
            break
        if expect_member.lower() in scr.lower():
            break
        if entered:
            # Already inside; never send Enter again (that would leave).
            break
        # Still in parent dir — one retry.
    check(t.alive(), '%s: alive after Enter' % name, scr)
    check('Fatal' not in scr and 'Access' not in scr,
          '%s: Enter no Fatal' % name, scr)
    check(
        expect_member.lower() in scr.lower(),
        '%s: member %r visible' % (name, expect_member),
        scr,
    )
    if title_hint:
        check(title_hint in scr,
              '%s: panel title has %r' % (name, title_hint), scr)
    return scr


def enter_archive(
    dn_out: str,
    fixture_dir: str,
    name: str,
    expect_member: str,
    title_hint: str,
) -> None:
    d = tempfile.mkdtemp(prefix='dn-arc-')
    try:
        copy_dn(dn_out, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        shutil.copy(os.path.join(fixture_dir, name), os.path.join(w, name))
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'HOME': d})
        open_archive(t, name, expect_member, title_hint)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['ENTER'], 1.0)
        scr2 = t.text()
        check('Fatal' not in scr2 and 'Access' not in scr2,
              '%s: leave no Fatal' % name, scr2)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


SOFT_FAILS: list = []


def view_edit_smoke(
    dn_out: str,
    fixture_dir: str,
    name: str,
    expect_member: str,
    title_hint: str,
    key: str,
    label: str,
    timeout: float = 12.0,
) -> None:
    d = tempfile.mkdtemp(prefix='dn-arc-op-')
    try:
        copy_dn(dn_out, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        shutil.copy(os.path.join(fixture_dir, name), os.path.join(w, name))
        os.environ['DN_LOG_FILE'] = os.path.join(d, 'dn.log')
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'HOME': d})
        del os.environ['DN_LOG_FILE']
        open_archive(t, name, expect_member, title_hint)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['DOWN'], 0.2)
        before = t.text()
        t0 = time.time()
        t.send(key, 2.0)
        opened = False
        while time.time() - t0 < timeout:
            if not t.alive():
                break
            scr = t.text()
            if 'Fatal' in scr or 'Access' in scr:
                break
            if 'hello' in scr.lower():
                opened = True
                break
            # F3 viewer often keeps the member name in chrome; F4 editor should
            # leave the archive listing (otherwise it is a no-op, not a hang).
            if label == 'F3' and expect_member.lower() in scr.lower():
                opened = True
                break
            if label == 'F4' and 'extract' in scr.lower():       # F4 in an archive is "Extr": the dialog of the extraction
                opened = True
                break
            time.sleep(0.2)
            t.pump(0.2, 1)
        elapsed = time.time() - t0
        scr = t.text()
        check(t.alive(), '%s/%s: alive' % (name, label), scr)
        check('Fatal' not in scr and 'Access' not in scr,
              '%s/%s: no Fatal' % (name, label), scr)
        if label == 'F4':
            # F4 in an archive is "Extr" (the key bar says so): DN (the object build too) extracts the member to the directory of the other panel
            # at once, or shows the Extract dialog; either is right, nothing else is checked
            for _ in range(10):
                if 'extract' in scr.lower() or os.path.exists(os.path.join(w, expect_member + '.txt')):
                    break
                t.pump(0.5, 2)
                scr = t.text()
            if 'extract' in scr.lower():
                print('PASS %s/F4: the Extract dialog is shown' % name, flush=True)
            elif os.path.exists(os.path.join(w, expect_member + '.txt')):
                print('PASS %s/F4: the member is extracted at once' % name, flush=True)
            else:
                SOFT_FAILS.append('%s F4 dialog' % name)
                print('SOFTFAIL %s/F4: no Extract dialog' % name, flush=True)
        else:
            check(elapsed < timeout, '%s/%s: no hang (%.1fs)' % (name, label, elapsed), scr)
            check(
                opened or 'hello' in scr.lower() or expect_member.lower() in scr.lower(),
                '%s/%s: opened content/chrome' % (name, label),
                scr,
            )
        for _ in range(12):                          # the extraction by the unpacker takes a moment
            if 'hello from fixture' in scr.lower() or not t.alive():
                break
            t.pump(0.5, 2)
            scr = t.text()
        if label == 'F4':
            t.send(KEYS['ESC'], 0.6)
            t.send(KEYS['ESC'], 0.4)
            quit_dn(t)
            return
        # the content of the member must be on the screen (the viewer or the editor shows the file that DN extracted with the unpacker)
        if 'hello from fixture' in scr.lower():
            print('PASS %s/%s: the content of the member is shown' % (name, label), flush=True)
        else:
            SOFT_FAILS.append('%s %s content' % (name, label))
            print('SOFTFAIL %s/%s: the content of the member is not shown' % (name, label), flush=True)
            print('DIAG %s screen: %s' % (label, ' | '.join(' '.join(l.split()) for l in scr.split('\n')[1:24] if l.strip('║│ \t'))[:600]), flush=True)
            print('DIAG %s dn.log: %s' % (label, open(os.path.join(d, 'dn.log')).read()[-900:] if os.path.exists(os.path.join(d, 'dn.log')) else '(none)'), flush=True)
        t.send(KEYS['ESC'], 0.6)
        t.send(KEYS['ESC'], 0.4)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def extract_smoke(
    dn_out: str,
    fixture_dir: str,
    name: str,
    expect_member: str,
    title_hint: str,
    timeout: float = 12.0,
) -> None:
    """F5 extract/copy from inside archive: open dialog, cancel path OK (timeout-bounded)."""
    d = tempfile.mkdtemp(prefix='dn-arc-f5-')
    try:
        copy_dn(dn_out, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        shutil.copy(os.path.join(fixture_dir, name), os.path.join(w, name))
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'HOME': d})
        open_archive(t, name, expect_member, title_hint)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['DOWN'], 0.2)
        t0 = time.time()
        t.send(KEYS['F5'], 1.5)
        while time.time() - t0 < timeout:
            if not t.alive():
                break
            scr = t.text()
            if 'Fatal' in scr or 'Access' in scr:
                break
            low = scr.lower()
            if 'extract' in low or 'copy' in low or 'to:' in low or 'extr' in low:
                break
            if time.time() - t0 > 1.5:
                break
            time.sleep(0.2)
            t.pump(0.2, 1)
        elapsed = time.time() - t0
        scr = t.text()
        check(t.alive(), '%s/F5: alive' % name, scr)
        check('Fatal' not in scr and 'Access' not in scr,
              '%s/F5: no Fatal' % name, scr)
        check(elapsed < timeout, '%s/F5: no hang (%.1fs)' % (name, elapsed), scr)
        t.send(KEYS['ESC'], 0.6)
        t.send(KEYS['ESC'], 0.4)
        scr2 = t.text()
        check(t.alive(), '%s/F5: alive after cancel' % name, scr2)
        check('Fatal' not in scr2 and 'Access' not in scr2,
              '%s/F5: cancel no Fatal' % name, scr2)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def extract_real(dn_out: str, fixture_dir: str, name: str, expect_member: str, title_hint: str) -> None:
    """F5 from inside the archive, confirmed with Enter: the member must be on the disk next to the archive with its content."""
    d = tempfile.mkdtemp(prefix='dn-arc-f5r-')
    try:
        copy_dn(dn_out, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        shutil.copy(os.path.join(fixture_dir, name), os.path.join(w, name))
        # wrappers of the unpackers in the PATH of DN: they log the call (arguments, directory, exit code) and run the real program
        bindir = os.path.join(d, 'wrapbin')
        os.makedirs(bindir)
        wlog = os.path.join(d, 'wrap.log')
        for prog in ('unzip', 'tar', 'gzip', 'gunzip', 'xz', 'bzip2', 'bunzip2', '7z', '7za', '7zr'):
            real = shutil.which(prog)
            if real:
                with open(os.path.join(bindir, prog), 'w') as f:
                    f.write('#!/bin/sh\necho "$0 $* [cwd=$PWD]" >> %s\n%s "$@" 2>>%s\nrc=$?\necho "  rc=$rc" >> %s\nexit $rc\n' % (wlog, real, wlog, wlog))
                os.chmod(os.path.join(bindir, prog), 0o755)
        old_path = os.environ['PATH']
        os.environ['PATH'] = bindir + os.pathsep + old_path
        os.environ['DN_LOG_FILE'] = os.path.join(d, 'dn.log')
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'HOME': d})
        os.environ['PATH'] = old_path
        del os.environ['DN_LOG_FILE']
        open_archive(t, name, expect_member, title_hint)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['DOWN'], 0.2)
        t.send(KEYS['F5'], 1.5)
        dlg = t.text()
        t.send(w + '/', 0.6)                    # the destination typed (the first typed text replaces the one that is there)
        dlg2 = t.text()
        t.send('\r', 1.5)
        for _ in range(8):
            t.pump(0.5, 2)
            if os.path.exists(os.path.join(w, 'inside.txt')):
                break
        scr = t.text()
        check(t.alive(), '%s/F5 real: alive' % name, scr)
        got = os.path.join(w, 'inside.txt')
        if not os.path.exists(got):
            print('DIAG files:', sorted(os.path.relpath(os.path.join(r, f), d) for r, _, fs in os.walk(d) for f in fs if f != 'dn' and not f.endswith(('.lng', '.dlg', '.hlp'))), flush=True)
            print('DIAG wrapper log:', open(wlog).read() if os.path.exists(wlog) else '(the unpacker was not started)', flush=True)
            print('DIAG dn.log:', open(os.path.join(d, 'dn.log')).read()[-900:] if os.path.exists(os.path.join(d, 'dn.log')) else '(none)', flush=True)
            import subprocess
            print('DIAG unzip:', shutil.which('unzip'), 'zip:', shutil.which('zip'), flush=True)
            print('DIAG find:', subprocess.run(['find', '/tmp', '-name', 'inside.txt', '-not', '-path', '*/fix*'], capture_output=True, text=True).stdout.split(), flush=True)
            for root, _, fs in os.walk(d):
                for f in fs:
                    if f.lower() in ('dn.err', 'dn.log', 'dnerr.log') or f.endswith('.err'):
                        print('DIAG', f, ':', open(os.path.join(root, f), errors='replace').read()[-600:], flush=True)
            print('DIAG screen middle:', ' | '.join(' '.join(l.split()) for l in scr.split('\n')[4:20] if l.strip('║│ \t'))[:700], flush=True)
        if not os.path.exists(got):
            SOFT_FAILS.append(name)               # the other formats are still tried (one run tells which formats extract)
            print('SOFTFAIL %s/F5 real: the member is not extracted' % name, flush=True)
        else:
            with open(got) as f:
                check(f.read() == 'hello from fixture\n', '%s/F5 real: the content is right' % name, scr)
            print('PASS %s/F5 real: the member is extracted' % name, flush=True)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def delete_real(dn_out: str, fixture_dir: str, name: str, expect_member: str, title_hint: str) -> None:
    """F8 from inside a zip, confirmed with Enter: the member must be gone from the archive on the disk (the packer is run by DN)."""
    import zipfile

    def members(path):
        try:
            return zipfile.ZipFile(path).namelist()
        except (OSError, zipfile.BadZipFile):
            return []                          # zip removes the archive file when the last member is deleted

    d = tempfile.mkdtemp(prefix='dn-arc-f8r-')
    try:
        copy_dn(dn_out, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        shutil.copy(os.path.join(fixture_dir, name), os.path.join(w, name))
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'HOME': d})
        open_archive(t, name, expect_member, title_hint)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['DOWN'], 0.2)
        t.send('\x1b[19~', 1.5)                # F8
        dlg = t.text()
        t.send('\r', 1.5)
        for _ in range(8):
            t.pump(0.5, 2)
            if 'inside.txt' not in members(os.path.join(w, name)):
                break
        scr = t.text()
        check(t.alive(), '%s/F8 real: alive' % name, scr)
        if 'inside.txt' in members(os.path.join(w, name)):
            SOFT_FAILS.append(name + ' F8')
            print('SOFTFAIL %s/F8 real: the member is still in the archive' % name, flush=True)
            print('DIAG F8 dialog:', ' | '.join(l.strip() for l in dlg.split('\n') if l.strip())[-500:], flush=True)
            print('DIAG F8 screen tail:', ' | '.join(l.strip() for l in scr.split('\n') if l.strip())[-400:], flush=True)
        else:
            print('PASS %s/F8 real: the member is deleted from the archive' % name, flush=True)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def add_real(dn_out: str, fixture_dir: str, name: str, expect_member: str, title_hint: str) -> None:
    """F5 of a file of the other panel into a zip that is open in the active panel (Tab, F5, Enter): the file must be in the archive on the disk
    (the packer is run by DN: the wrapper log tells)."""
    import zipfile

    def members(path):
        try:
            return zipfile.ZipFile(path).namelist()
        except (OSError, zipfile.BadZipFile):
            return []

    d = tempfile.mkdtemp(prefix='dn-arc-f5a-')
    try:
        copy_dn(dn_out, d)
        w = os.path.join(d, 'work')
        os.makedirs(w)
        shutil.copy(os.path.join(fixture_dir, name), os.path.join(w, name))
        with open(os.path.join(w, 'added.zzz'), 'w') as f:
            f.write('added by DN\n')
        bindir = os.path.join(d, 'wrapbin')
        os.makedirs(bindir)
        wlog = os.path.join(d, 'wrap.log')
        real = shutil.which('zip')
        with open(os.path.join(bindir, 'zip'), 'w') as f:
            f.write('#!/bin/sh\necho "$0 $* [cwd=$PWD]" >> %s\n%s "$@" 2>>%s\nrc=$?\necho "  rc=$rc" >> %s\nexit $rc\n' % (wlog, real, wlog, wlog))
        os.chmod(os.path.join(bindir, 'zip'), 0o755)
        old_path = os.environ['PATH']
        os.environ['PATH'] = bindir + os.pathsep + old_path
        os.environ['DN_LOG_FILE'] = os.path.join(d, 'dn.log')
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'HOME': d})
        os.environ['PATH'] = old_path
        del os.environ['DN_LOG_FILE']
        open_archive(t, name, expect_member, title_hint)
        t.send('\t', 0.6)                          # the other panel: the directory with added.zzz
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['DOWN'], 0.2)                  # simple.zip
        t.send(KEYS['DOWN'], 0.2)                  # added.zzz (the extension zzz sorts after zip)
        t.send(KEYS['F5'], 1.5)
        dlg = t.text()
        t.send('\r', 1.5)                              # the Copy dialog: OK; the dialog Archive files follows
        t.send('\r', 1.5)                              # Archive files: OK
        for _ in range(8):
            t.pump(0.5, 2)
            if 'added.zzz' in members(os.path.join(w, name)):
                break
        scr = t.text()
        check(t.alive(), '%s/F5 add: alive' % name, scr)
        if 'added.zzz' in members(os.path.join(w, name)):
            print('PASS %s/F5 add: the file is in the archive' % name, flush=True)
        else:
            SOFT_FAILS.append(name + ' add')
            print('SOFTFAIL %s/F5 add: the file is not in the archive; members: %s' % (name, members(os.path.join(w, name))), flush=True)
            print('DIAG add wrapper log:', open(wlog).read() if os.path.exists(wlog) else '(zip was not started)', flush=True)
            print('DIAG add dn.log:', open(os.path.join(d, 'dn.log')).read()[-900:] if os.path.exists(os.path.join(d, 'dn.log')) else '(none)', flush=True)
            print('DIAG add dialog:', ' | '.join(l.strip() for l in dlg.split('\n') if l.strip())[-500:], flush=True)
            print('DIAG add screen tail:', ' | '.join(l.strip() for l in scr.split('\n') if l.strip())[-400:], flush=True)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


FUNCS = {'enter': enter_archive, 'view': view_edit_smoke, 'f5': extract_smoke, 'f5real': extract_real, 'f8real': delete_real,
         'f5add': add_real}


def jobs(names: list) -> list:
    """the cases in the order of the report: (title, function, arguments after the fixture directory)"""
    res = []
    for name, member, title in (
        ('simple.zip', 'inside', 'ZIP:'),
        ('simple.7z', 'inside', '7Z:'),
        ('simple.tar', 'inside', 'TAR:'),
        ('simple.tgz', 'inside', 'TGZ:'),
        ('simple.tar.gz', 'inside', 'TGZ:'),
        ('simple.tar.bz2', 'inside', 'BZ2:'),
        ('simple.tar.xz', 'inside', 'XZ:'),
        ('simple.txz', 'inside', 'XZ:'),
        ('outer.zip', 'inner', 'ZIP:'),
    ):
        if name not in names:
            res.append(('SKIP %s (not generated)' % name, None, None))
            continue
        res.append(('CASE ' + name, 'enter', [name, member, title]))
    for name, member, title in (
        ('simple.zip', 'inside', 'ZIP:'),
        ('simple.tgz', 'inside', 'TGZ:'),
        ('simple.tar.bz2', 'inside', 'BZ2:'),
        ('simple.tar.xz', 'inside', 'XZ:'),
    ):
        if name not in names:
            res.append(('SKIP %s F3/F4 (not generated)' % name, None, None))
            continue
        res.append(('CASE %s F3' % name, 'view', [name, member, title, KEYS['F3'], 'F3']))
        res.append(('CASE %s F4' % name, 'view', [name, member, title, KEYS['F4'], 'F4']))
    for name, member, title in (
        ('simple.zip', 'inside', 'ZIP:'),
        ('simple.tgz', 'inside', 'TGZ:'),
        ('simple.tar.xz', 'inside', 'XZ:'),
        ('simple.7z', 'inside', '7Z:'),
        ('simple.tar', 'inside', 'TAR:'),
        ('simple.tar.bz2', 'inside', 'BZ2:'),
    ):
        if name not in names:
            res.append(('SKIP %s F5 (not generated)' % name, None, None))
            continue
        res.append(('CASE %s F5' % name, 'f5', [name, member, title]))
        res.append(('CASE %s F5 real' % name, 'f5real', [name, member, title]))
        if name == 'simple.zip':
            res.append(('CASE %s F8 real' % name, 'f8real', [name, member, title]))
            res.append(('CASE %s F5 add' % name, 'f5add', [name, member, title]))
    return res


def one(out: str, fix: str, func: str, args: list) -> int:
    """a single case (a process of its own: run by main side by side with the others); 3 on a soft failure, 1 (check) on a hard one"""
    FUNCS[func](out, fix, *args)
    return 3 if SOFT_FAILS else 0


def main() -> int:
    if len(sys.argv) >= 2 and sys.argv[1] == '--one':          # --one OUTDIR FIXDIR JSON: [function, arguments]
        import json
        func, args = json.loads(sys.argv[4])
        return one(sys.argv[2], sys.argv[3], func, args)
    if len(sys.argv) < 2:
        print('usage: dn-linux-archives.py OUTDIR', file=sys.stderr)
        return 2
    out = os.path.abspath(sys.argv[1])
    if not os.path.isfile(os.path.join(out, 'dn')):
        print('no dn in', out, file=sys.stderr)
        return 2
    fix = tempfile.mkdtemp(prefix='dn-arc-fix-')
    try:
        names = gen_fixtures(fix)
        only = os.environ.get('DN_ARC_ONLY')                  # for example DN_ARC_ONLY='simple.zip simple.tar.bz2': the formats to run
        if only:
            names = [n for n in names if n in only.split()]
        print('FIXTURES', ' '.join(names), flush=True)
        import json
        from concurrent.futures import ThreadPoolExecutor

        def run(job):
            title, func, args = job
            if func is None:
                return None
            return subprocess.run([sys.executable, '-u', os.path.abspath(__file__), '--one', out, fix, json.dumps([func, args])],
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        todo = jobs(names)
        hard = soft = 0
        with ThreadPoolExecutor(len(todo)) as ex:                 # every case is a start of DN in a directory of its own: all at once
            for (title, func, args), r in zip(todo, ex.map(run, todo)):
                print(title, flush=True)
                if r is None:
                    continue
                print(r.stdout, end='', flush=True)
                if r.returncode == 3:
                    soft += 1
                elif r.returncode:
                    hard += 1
        if hard:
            print('FAILED cases: %d' % hard, flush=True)
            return 1
        if soft:
            print('F5 real FAILED for: %d cases (SOFTFAIL above)' % soft, flush=True)
            return 1
        print('ALL OK', flush=True)
        return 0
    finally:
        shutil.rmtree(fix, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
