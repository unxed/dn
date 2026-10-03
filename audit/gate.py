#!/usr/bin/env python3
"""The gate of the audit: reads audit.txt (the output of xclone.py), fails if a file has raw > 10 % or maxrun >= 48, unless the file is in
audit/accepted.txt and is within its ceilings. Prints the accepted files every time. usage: audit/gate.py audit.txt"""
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
acc = {}
for line in open(os.path.join(here, 'accepted.txt'), encoding='utf-8'):
    line = line.split('#', 1)[0].strip()
    if line:
        f, r, m, t = line.split()
        acc[f] = (float(r), int(m), int(t))
bad = 0
for line in open(sys.argv[1], encoding='utf-8'):
    c = line.split()
    if len(c) < 6 or c[0] in ('file', 'TOTAL') or not c[2].endswith('%'):
        continue
    f, tok, raw, run = c[0], int(c[1]), float(c[2].rstrip('%')), int(c[5])
    if raw <= 10 and run < 48:
        continue
    if f in acc and raw <= acc[f][0] and run <= acc[f][1] and tok <= acc[f][2]:
        print('accepted: %s (%d tokens, raw %g %%, maxrun %d; ceilings %g %% / %d / %d)' % ((f, tok, raw, run) + acc[f]))
    else:
        print('OVER THE GATE: ' + line.strip())
        bad += 1
print('%d files over the gate' % bad)
sys.exit(1 if bad else 0)
