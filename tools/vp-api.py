#!/usr/bin/env python3
"""Which names of a Virtual Pascal runtime unit (vpsyslow, vpsyslo2, lfnvp...) the files of DN that we
keep (those that passed the audit gate) really use. Prints names and counts only, no code: this is the
list of what our own replacement units in dn/new must provide (PLAN.md, milestone 4).

usage: tools/vp-api.py TREE_DIR UNIT.pas [AUDIT_REPORT]
  TREE_DIR     the tree of DN (build/dn, made by tools/dn-materialize.sh, or any unpacked copy)
  UNIT.pas     the file of the unit whose interface is the API to replace
  AUDIT_REPORT the report of audit/xclone.py (default audit/reports/2026-10-01/dnosp214.txt):
               the files over the gate are replaced by tv/ anyway, their uses do not count
"""
import re, sys, glob, os, collections

tree = sys.argv[1]
unit = sys.argv[2]
report = sys.argv[3] if len(sys.argv) > 3 else 'audit/reports/2026-10-01/dnosp214.txt'

flag = set()
for l in open(report, encoding='utf-8'):
    p = l.split()
    if len(p) >= 6 and p[0] != 'TOTAL':
        try:
            r = float(p[2].rstrip('%')); m = int(p[5])
        except ValueError:
            continue
        if r > 2 or m >= 48:
            flag.add(p[0].lower())

def read(f):
    return open(f, encoding='cp866', errors='replace').read()

path = os.path.join(tree, unit)
if not os.path.exists(path):
    cand = [f for f in os.listdir(tree) if f.lower() == unit.lower()]
    path = os.path.join(tree, cand[0])
t = read(path)
low = t.lower()
iface = t[:low.find('implementation')] if 'implementation' in low else t
decl = set(m.group(2).lower() for m in re.finditer(r'(?im)^\s*(function|procedure)\s+([A-Za-z_][A-Za-z0-9_]*)', iface))
decl |= set(m.group(1).lower() for m in re.finditer(r'(?im)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=', iface))

own = os.path.basename(path).lower()
cnt = collections.Counter(); byf = collections.defaultdict(set)
for f in sorted(os.listdir(tree)):
    b = f.lower()
    if not b.endswith('.pas') or b == own or b in flag or b.startswith('vpsyslo') or b == 'lfnvp.pas':
        continue
    words = re.findall(r'[a-z_][a-z0-9_]*', read(os.path.join(tree, f)).lower())
    # only the files that name the unit (in a uses clause or as a qualifier): the other files
    # may declare names of their own that happen to be the same
    if os.path.basename(path)[:-4].lower() not in words:
        continue
    for w in words:
        if w in decl:
            cnt[w] += 1; byf[w].add(b[:-4])
print('# %s: names used by the files that we keep' % os.path.basename(path))
print()
print('%d names are declared in the interface; %d are used (%d uses).' % (len(decl), len(cnt), sum(cnt.values())))
print()
print('| name | uses | files |')
print('|---|---|---|')
for n, c in cnt.most_common():
    fs = sorted(byf[n])
    print('| %s | %d | %s |' % (n, c, ', '.join(fs[:6]) + (' …' if len(fs) > 6 else '')))
