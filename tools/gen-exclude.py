#!/usr/bin/env python3
"""Prints the part of dn/exclude.list that comes from the audit: the files over the gate
(raw > 2 % or maxrun >= 48 against the Borland reference, audit/README.md), which are replaced
by tv/ or rewritten.

usage: tools/gen-exclude.py audit/reports/2026-10-01/dnosp214.txt
"""
import sys
names = []
for l in open(sys.argv[1], encoding='utf-8'):
    p = l.split()
    if len(p) >= 6 and p[0] != 'TOTAL':
        try:
            r = float(p[2].rstrip('%')); m = int(p[5])
        except ValueError:
            continue
        if r > 2 or m >= 48:
            names.append((p[0], r, m))
print('# --- from the audit (tools/gen-exclude.py audit/reports/2026-10-01/dnosp214.txt): %d files over the gate' % len(names))
for n, r, m in sorted(names, key=lambda x: x[0].lower()):
    print('%s' % n)
