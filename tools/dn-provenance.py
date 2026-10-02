#!/usr/bin/env python3
"""Classifies the files of the DN tree by the notice at the top: which of them are RIT code or direct
descendants of it in DN OSP (the license notice of Dos Navigator Open Source, "Based on Dos Navigator (C)
1991-99 RIT Research Labs"), and which are not (Borland, Virtual Pascal, other authors, no notice).
Only RIT/OSP code may be taken from the public archives (PLAN.md, decision 11).

usage: tools/dn-provenance.py TREE_DIR
Prints, for every file, the class and the line that decided it (only the notice, no code), then the totals.
Classes: RIT (the DN OSP notice), BORLAND, VP (Virtual Pascal), THIRD (another copyright holder named
in the first 40 lines), NONE (no notice: to be checked by hand).
"""
import os, re, sys, collections

tree = sys.argv[1]
res = []
for f in sorted(os.listdir(tree)):
    p = os.path.join(tree, f)
    if not os.path.isfile(p) or not f.lower().endswith(('.pas', '.inc', '.asm', '.pp')):
        continue
    head = open(p, encoding='cp866', errors='replace').read().split('\n')[:60]
    text = '\n'.join(head)
    low = text.lower()
    cls, why = 'NONE', ''
    if 'rit research labs' in low or 'dos navigator open source' in low or 'dos navigator /2 osp' in low:
        cls, why = 'RIT', 'RIT/DN OSP notice'
    elif 'borland' in low:
        cls = 'BORLAND'; why = next((l.strip() for l in head if 'borland' in l.lower()), '')
    elif 'vpascal' in low or 'virtual pascal' in low:
        cls = 'VP'; why = next((l.strip() for l in head if 'vpascal' in l.lower() or 'virtual pascal' in l.lower()), '')
    else:
        m = next((l.strip() for l in head if re.search(r'copyright|\(c\)|©|written by|author|by [A-Z][a-z]+ [A-Z]', l, re.I)), '')
        if m:
            cls, why = 'THIRD', m
    res.append((f, cls, why[:110]))

for f, cls, why in res:
    print('%-6s %-18s %s' % (cls, f, why if cls != 'RIT' else ''))
tot = collections.Counter(c for _, c, _ in res)
print('TOTAL', dict(tot), 'files', len(res))
