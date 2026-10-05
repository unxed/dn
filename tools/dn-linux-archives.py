#!/usr/bin/env python3
"""PTY smoke tests for DN archive enter/leave (class Linux / UTF-8 build).

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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

KEYS = {
    'ENTER': '\r',
    'ESC': '\x1b',
    'HOME': '\x1b[H',
    'DOWN': '\x1b[B',
    'UP': '\x1b[A',
    'ALT-X': '\x1bx',
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
        t.pump(1.5, 6)
        t.send(KEYS['ESC'], 0.3)
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['DOWN'], 0.2)
        t.send(KEYS['ENTER'], 2.0)
        scr = t.text()
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
        # Leave via ..
        t.send(KEYS['HOME'], 0.15)
        t.send(KEYS['ENTER'], 1.0)
        scr2 = t.text()
        check('Fatal' not in scr2 and 'Access' not in scr2,
              '%s: leave no Fatal' % name, scr2)
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
        cases = [
            ('simple.zip', 'inside', 'ZIP:'),
            ('simple.7z', 'inside', '7Z:'),
            ('simple.tar', 'inside', 'TAR:'),
            ('simple.tgz', 'inside', 'TGZ:'),
            ('simple.tar.gz', 'inside', 'TGZ:'),
        ]
        for name, member, title in cases:
            if name not in names:
                print('SKIP', name, '(not generated)', flush=True)
                continue
            print('CASE', name, flush=True)
            enter_archive(out, fix, name, member, title)
        print('ALL OK', flush=True)
        return 0
    finally:
        shutil.rmtree(fix, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
