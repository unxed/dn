#!/usr/bin/env python3
"""Prints the part of dn/exclude.list that comes from the audit: the files over the gate
(raw > 6 % or maxrun >= 48 against the Borland reference, audit/README.md), which are replaced
by tv/ or rewritten. A file whose regions are rewritten by dn/rewrite is not excluded: the audit
of the tree that dn-materialize.sh makes (after the rewrites) must have it under the gate.

usage: tools/gen-exclude.py audit/reports/2026-10-01/dnosp214.txt [dn/rewrite]
"""
import sys, os, glob
rewritten = set()
if len(sys.argv) > 2:
    for rw in glob.glob(os.path.join(sys.argv[2], '*.rw')):
        for l in open(rw, encoding='ascii'):
            if l.startswith('file:'):
                rewritten.add(l.split(':', 1)[1].strip().lower())
names = []
for l in open(sys.argv[1], encoding='utf-8'):
    p = l.split()
    if len(p) >= 6 and p[0] != 'TOTAL':
        try:
            r = float(p[2].rstrip('%')); m = int(p[5])
        except ValueError:
            continue
        if (r > 6 or m >= 48) and p[0].lower() not in rewritten:
            names.append((p[0], r, m))
print('# --- from the audit (tools/gen-exclude.py audit/reports/2026-10-01/dnosp214.txt dn/rewrite): %d files over the gate' % len(names))
for n, r, m in sorted(names, key=lambda x: x[0].lower()):
    print('%s' % n)
