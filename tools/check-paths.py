#!/usr/bin/env python3
"""Counts the places that spell a path separator or a drive letter by hand in dn/src (a ratchet: the number may only fall).
tools/check-paths.py [--update]   the baseline is in tools/paths-baseline.txt"""
import os, re, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src = os.path.join(root, 'dn', 'src')
base = os.path.join(root, 'tools', 'paths-baseline.txt')
# a backslash or a slash as a char literal, a drive letter prefix, a [2] = ':' test
pat = re.compile(r"'\\'|'[A-Za-z]:\\|\[2\]\s*=\s*':'")
skip = re.compile(r'^\s*(\{|//)')
counts = {}
for f in sorted(os.listdir(src)):
    if not f.endswith('.pas'):
        continue
    n = 0
    for line in open(os.path.join(src, f), encoding='utf-8', errors='replace'):
        if skip.match(line):
            continue
        n += len(pat.findall(line))
    if n:
        counts[f] = n
total = sum(counts.values())
if '--update' in sys.argv:
    with open(base, 'w') as fh:
        for f, n in counts.items():
            fh.write('%s %d\n' % (f, n))
    print('baseline', total)
    sys.exit(0)
old = {}
if os.path.exists(base):
    for l in open(base):
        a, b = l.split()
        old[a] = int(b)
bad = [(f, n, old.get(f, 0)) for f, n in counts.items() if n > old.get(f, 0)]
for f, n, o in bad:
    print('FAIL %s: %d hand-spelled separators (the baseline allows %d); use DnPath' % (f, n, o))
print('total %d (baseline %d)' % (total, sum(old.values())))
sys.exit(1 if bad else 0)
