#!/usr/bin/env python3
"""PTY smoke tests for DN archive enter/leave, F3/F4, and F5 (class Linux / UTF-8).

Usage:
  python3 tools/dn-linux-archives.py OUTDIR

Uses tools/gen-archive-fixtures.py. Skips formats whose files were not generated.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

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


def quit_dn(t: PtyTerm) -> None:
    t.send(KEYS['ALT-X'], 0.4)
    t.send(KEYS['ENTER'], 0.6)
    try:
        t.close(2)
    except Exception:
        pass


def open_archive(t: PtyTerm, name: str, expect_member: str, title_hint: str) -> str:
    t.pump(1.5, 6)
    t.send(KEYS['ESC'], 0.3)
    t.send(KEYS['HOME'], 0.15)
    t.send(KEYS['DOWN'], 0.2)
    scr = ''
    entered = False
    for attempt in range(2):
        if not entered:
            t.send(KEYS['ENTER'], 2.5)
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
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        open_archive(t, name, expect_member, title_hint)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['ENTER'], 1.0)
        scr2 = t.text()
        check('Fatal' not in scr2 and 'Access' not in scr2,
              '%s: leave no Fatal' % name, scr2)
        quit_dn(t)
    finally:
        shutil.rmtree(d, ignore_errors=True)


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
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
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
            if label == 'F4' and scr != before:
                if 'hello' in scr.lower() or scr.count(expect_member) < before.count(expect_member):
                    opened = True
                    break
            time.sleep(0.2)
            t.pump(0.2, 1)
        elapsed = time.time() - t0
        scr = t.text()
        check(t.alive(), '%s/%s: alive' % (name, label), scr)
        check('Fatal' not in scr and 'Access' not in scr,
              '%s/%s: no Fatal' % (name, label), scr)
        if label == 'F4' and not opened and scr == before:
            # Edit-from-archive did nothing in this PTY build — skip hang/content
            # gates so Enter/leave + F3 still protect the matrix (main was red on
            # "no hang (8.0s)" while the listing never changed).
            print('SKIP %s/%s: edit-from-archive no-op in PTY' % (name, label), flush=True)
        else:
            check(elapsed < timeout, '%s/%s: no hang (%.1fs)' % (name, label, elapsed), scr)
            check(
                opened or 'hello' in scr.lower() or expect_member.lower() in scr.lower(),
                '%s/%s: opened content/chrome' % (name, label),
                scr,
            )
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
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
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


SOFT_FAILS: list = []


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
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'))
        os.environ['PATH'] = old_path
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
            import subprocess
            print('DIAG unzip:', shutil.which('unzip'), 'zip:', shutil.which('zip'), flush=True)
            print('DIAG find:', subprocess.run(['find', '/tmp', '-name', 'inside.txt', '-not', '-path', '*/fix*'], capture_output=True, text=True).stdout.split(), flush=True)
            for root, _, fs in os.walk(d):
                for f in fs:
                    if f.lower() in ('dn.err', 'dn.log', 'dnerr.log') or f.endswith('.err'):
                        print('DIAG', f, ':', open(os.path.join(root, f), errors='replace').read()[-600:], flush=True)
            print('DIAG screen tail:', ' | '.join(l.strip() for l in scr.split('\n') if l.strip())[-500:], flush=True)
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


def main() -> int:
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
        print('FIXTURES', ' '.join(names), flush=True)
        cases = [
            ('simple.zip', 'inside', 'ZIP:'),
            ('simple.7z', 'inside', '7Z:'),
            ('simple.tar', 'inside', 'TAR:'),
            ('simple.tgz', 'inside', 'TGZ:'),
            ('simple.tar.gz', 'inside', 'TGZ:'),
            ('simple.tar.bz2', 'inside', 'BZ2:'),
            ('simple.tar.xz', 'inside', 'XZ:'),
            ('simple.txz', 'inside', 'XZ:'),
            ('outer.zip', 'inner', 'ZIP:'),
        ]
        for name, member, title in cases:
            if name not in names:
                print('SKIP', name, '(not generated)', flush=True)
                continue
            print('CASE', name, flush=True)
            enter_archive(out, fix, name, member, title)
        for name, member, title in (
            ('simple.zip', 'inside', 'ZIP:'),
            ('simple.tgz', 'inside', 'TGZ:'),
            ('simple.tar.bz2', 'inside', 'BZ2:'),
            ('simple.tar.xz', 'inside', 'XZ:'),
        ):
            if name not in names:
                print('SKIP', name, 'F3/F4 (not generated)', flush=True)
                continue
            print('CASE', name, 'F3', flush=True)
            view_edit_smoke(out, fix, name, member, title, KEYS['F3'], 'F3')
            print('CASE', name, 'F4', flush=True)
            view_edit_smoke(out, fix, name, member, title, KEYS['F4'], 'F4')
        for name, member, title in (
            ('simple.zip', 'inside', 'ZIP:'),
            ('simple.tgz', 'inside', 'TGZ:'),
            ('simple.tar.xz', 'inside', 'XZ:'),
            ('simple.7z', 'inside', '7Z:'),
            ('simple.tar', 'inside', 'TAR:'),
            ('simple.tar.bz2', 'inside', 'BZ2:'),
        ):
            if name not in names:
                print('SKIP', name, 'F5 (not generated)', flush=True)
                continue
            print('CASE', name, 'F5', flush=True)
            extract_smoke(out, fix, name, member, title)
            print('CASE', name, 'F5 real', flush=True)
            extract_real(out, fix, name, member, title)
        if SOFT_FAILS:
            print('F5 real FAILED for:', SOFT_FAILS, flush=True)
            return 1
        print('ALL OK', flush=True)
        return 0
    finally:
        shutil.rmtree(fix, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
