#!/usr/bin/env python3
"""Generate a small reproducible archive fixture tree for DN archive-matrix tests.

Usage:
  python3 tools/gen-archive-fixtures.py [OUTDIR]

Creates OUTDIR (default: a temp directory) with simple and nested archives.
Skips formats whose packer is missing. Prints the output path on stdout.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile


def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def run(cmd, cwd=None):
    subprocess.check_call(cmd, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def write_member(dirpath: str, name: str = 'inside.txt', body: str = 'hello from fixture\n') -> str:
    path = os.path.join(dirpath, name)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(body)
    return name


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('outdir', nargs='?', default='')
    args = ap.parse_args()
    out = args.outdir or tempfile.mkdtemp(prefix='dn-arc-fix-')
    os.makedirs(out, exist_ok=True)
    stage = os.path.join(out, '_stage')
    os.makedirs(stage, exist_ok=True)
    write_member(stage)

    made = []

    # zip (stdlib)
    zpath = os.path.join(out, 'simple.zip')
    with zipfile.ZipFile(zpath, 'w') as zf:
        zf.write(os.path.join(stage, 'inside.txt'), 'inside.txt')
    made.append('simple.zip')

    # zip with directory
    z2 = os.path.join(out, 'dirs.zip')
    with zipfile.ZipFile(z2, 'w') as zf:
        zf.writestr('sub/inside.txt', 'in sub\n')
        zf.writestr('root.txt', 'root\n')
    made.append('dirs.zip')

    if have('tar'):
        run(['tar', '-cf', os.path.join(out, 'simple.tar'), 'inside.txt'], cwd=stage)
        made.append('simple.tar')
        run(['tar', '-czf', os.path.join(out, 'simple.tgz'), 'inside.txt'], cwd=stage)
        made.append('simple.tgz')
        run(['tar', '-czf', os.path.join(out, 'simple.tar.gz'), 'inside.txt'], cwd=stage)
        made.append('simple.tar.gz')
        if have('bzip2'):
            run(['tar', '-cjf', os.path.join(out, 'simple.tar.bz2'), 'inside.txt'], cwd=stage)
            made.append('simple.tar.bz2')
        if have('xz'):
            run(['tar', '-cJf', os.path.join(out, 'simple.tar.xz'), 'inside.txt'], cwd=stage)
            made.append('simple.tar.xz')
            # .txz is the short compound alias (same payload)
            shutil.copy(
                os.path.join(out, 'simple.tar.xz'),
                os.path.join(out, 'simple.txz'),
            )
            made.append('simple.txz')

    if have('gzip'):
        shutil.copy(os.path.join(stage, 'inside.txt'), os.path.join(out, 'plain.txt'))
        run(['gzip', '-n', '-f', 'plain.txt'], cwd=out)
        # gzip -n keeps name; result plain.txt.gz
        if os.path.exists(os.path.join(out, 'plain.txt.gz')):
            made.append('plain.txt.gz')

    if have('7z'):
        run(['7z', 'a', '-bd', '-y', os.path.join(out, 'simple.7z'), 'inside.txt'], cwd=stage)
        made.append('simple.7z')

    # zip-in-zip
    inner = os.path.join(stage, 'inner.zip')
    with zipfile.ZipFile(inner, 'w') as zf:
        zf.writestr('nested.txt', 'nested\n')
    with zipfile.ZipFile(os.path.join(out, 'outer.zip'), 'w') as zf:
        zf.write(inner, 'inner.zip')
    made.append('outer.zip')

    shutil.rmtree(stage)
    meta = os.path.join(out, 'MANIFEST.txt')
    with open(meta, 'w', encoding='utf-8') as f:
        f.write('\n'.join(made) + '\n')
    print(out)
    for m in made:
        print(' ', m, file=sys.stderr)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())