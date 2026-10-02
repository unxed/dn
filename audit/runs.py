#!/usr/bin/env python3
"""List verbatim token runs (>= MIN tokens) of CAND that occur in reference files,
with candidate line range, enclosing routine and reference file:line range.
usage: [REN=1] runs.py CAND REF_LIST [MIN]"""
import re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import xclone as X
K = 24
REN = bool(os.environ.get('REN'))     # REN=1: compare with renamed identifiers

def strip_keep_lines(t):
    # like X.strip_comments, but comments are replaced by their newlines
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if c == "'":
            j = i + 1
            while j < n:
                if t[j] == "'":
                    if j + 1 < n and t[j + 1] == "'":
                        j += 2; continue
                    break
                j += 1
            out.append(t[i:j + 1]); i = j + 1
        elif c == '{' or t.startswith('(*', i) or t.startswith('//', i):
            end = {'{': '}', '(': '*)', '/': '\n'}[c]
            j = t.find(end, i + 1)
            j = n if j < 0 else (j if end == '\n' else j + len(end))
            out.append(' ' + '\n' * t.count('\n', i, j)); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)

def toks(path):
    t = strip_keep_lines(open(path, encoding='latin-1').read())
    raw, lines = [], []
    for m in X.TOK.finditer(t):
        k = m.lastgroup; v = m.group(k)
        if REN:      # identifiers, literals and numbers replaced as in xclone (copy with renamed identifiers)
            raw.append(v.lower() if k == 'id' and v.lower() in X.KEYWORDS else
                       {'id': 'ID', 'str': 'LIT', 'num': 'NUM'}.get(k, v))
        else:
            raw.append(v.lower() if k in ('id', 'str', 'num') else v)
        lines.append(t.count('\n', 0, m.start()) + 1)
    return raw, lines

cand, reflist = sys.argv[1], sys.argv[2]
MIN = int(sys.argv[3]) if len(sys.argv) > 3 else 48
R = {}
refs = [l.strip() for l in open(reflist) if l.strip()]
RT = {}
for p in refs:
    r, ln = toks(p); RT[p] = ln
    for i in range(len(r) - K + 1):
        R.setdefault(hash(tuple(r[i:i + K])), (p, i))
r, ln = toks(cand)
hit = [None] * (len(r) - K + 1)
for i in range(len(r) - K + 1):
    hit[i] = R.get(hash(tuple(r[i:i + K])))
runs, i = [], 0
while i < len(hit):
    if hit[i]:
        j = i
        while j + 1 < len(hit) and hit[j + 1]:
            j += 1
        runs.append((i, j + K))
        i = j + 1
    else:
        i += 1
HDR = ('procedure', 'function', 'constructor', 'destructor')
for a, b in sorted(runs, key=lambda x: x[0] - x[1]):
    if b - a < MIN:
        continue
    # enclosing routine: nearest header before the run
    name = '?'
    for q in range(a, -1, -1):
        if r[q] in HDR and q + 1 < len(r):
            name = r[q] + ' ' + ''.join(r[q + 1:q + 4]); break
    p, ri = hit[a]
    print("%5d tok  %s:%d-%d  in [%s]  ==  %s:%d" % (b - a, os.path.basename(cand), ln[a], ln[b - 1],
          name, os.path.basename(p), RT[p][ri]))
