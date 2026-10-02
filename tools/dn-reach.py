#!/usr/bin/env python3
"""Which units of the tree are reachable from the main program (by `uses`), and which are not: the
others are not needed for the build (the plugin copies `_*.pas`, tools...). Prints names and counts only.
usage: tools/dn-reach.py TREE [ROOT.pas]   (ROOT default: dn.pas)"""
import sys, os, re
tree = sys.argv[1]
root = (sys.argv[2] if len(sys.argv) > 2 else 'dn.pas').lower()
alias = {'lfn': 'lfnvp', 'winclp': 'winclpvp'}
files = {f.lower()[:-4]: f for f in os.listdir(tree) if f.lower().endswith('.pas')}

def uses(path):
    t = open(os.path.join(tree, path), encoding='latin-1').read()
    t = re.sub(r'\(\*.*?\*\)|\{[^}]*\}|//[^\n]*', ' ', t, flags=re.S)
    out = []
    for m in re.finditer(r'\buses\b([^;]*);', t, re.I):
        out += [u.strip().lower() for u in m.group(1).split(',') if u.strip()]
    return out

seen, todo, missing = set(), [root[:-4]], set()
while todo:
    u = todo.pop()
    u = alias.get(u, u)
    if u in seen:
        continue
    seen.add(u)
    if u not in files:
        missing.add(u); continue
    todo += uses(files[u])
unreach = sorted(set(files) - seen)
print('units: %d, reachable from %s: %d, not reachable: %d' % (len(files), root, len(seen & set(files)), len(unreach)))
print('not reachable:', ' '.join(unreach))
print('missing (no file, not provided by RTL?):', ' '.join(sorted(missing)))
