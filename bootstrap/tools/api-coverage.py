#!/usr/bin/env python3
"""How much of the API that the clean DN code takes from its flagged units (those that
are replaced by tv/) our tv/src already has.

usage: tools/api-coverage.py [spec/dn-boundary-dnosp214.md] [tv/src]
The spec lists, per flagged unit, the names used by the rest of DN as `name (uses/files)`.
A name counts as "present" when it occurs as an identifier in tv/src (a rough test: the
names are matched case-insensitively, whatever they are: type, method, constant).
Prints, per unit, the coverage by names and by uses, and the missing names by use count.
"""
import re, sys, glob, os

spec = sys.argv[1] if len(sys.argv) > 1 else 'spec/dn-boundary-dnosp214.md'
src = sys.argv[2] if len(sys.argv) > 2 else 'tv/src'

idents = set()
for f in glob.glob(os.path.join(src, '*.pas')) + glob.glob(os.path.join(src, '*.inc')):
    idents.update(w.lower() for w in re.findall(r'[A-Za-z_][A-Za-z0-9_]*', open(f, encoding='utf-8', errors='replace').read()))

units = []
cur = None
for line in open(spec, encoding='utf-8'):
    m = re.match(r'## (\S+) ', line)
    if m:
        cur = [m.group(1), []]
        units.append(cur)
        continue
    if cur and line.strip() and not line.startswith('#'):
        for name, a, b in re.findall(r'([A-Za-z_][A-Za-z0-9_]*) \((\d+)/(\d+)\)', line):
            cur[1].append((name.lower(), int(a), int(b)))

tot_n = tot_h = tot_u = tot_uh = 0
print('%-14s %8s %8s %10s' % ('unit', 'names', 'present', 'uses'))
missing_all = []
for name, items in units:
    n = len(items)
    h = sum(1 for i in items if i[0] in idents)
    u = sum(i[1] for i in items)
    uh = sum(i[1] for i in items if i[0] in idents)
    tot_n += n; tot_h += h; tot_u += u; tot_uh += uh
    print('%-14s %3d/%-4d %3d%% %6d/%-6d %3d%%' % (name, h, n, 100 * h // max(n, 1), uh, u, 100 * uh // max(u, 1)))
    missing_all += [(i[1], i[0], name) for i in items if i[0] not in idents]
print('TOTAL names %d/%d (%d%%), uses %d/%d (%d%%)' % (tot_h, tot_n, 100 * tot_h // max(tot_n, 1), tot_uh, tot_u, 100 * tot_uh // max(tot_u, 1)))
print()
print('missing, by uses:')
for u, n, unit in sorted(missing_all, reverse=True)[:60]:
    print('  %-28s %5d  (%s)' % (n, u, unit))
