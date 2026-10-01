#!/usr/bin/env python3
"""Token-level verbatim-run detector for C/C++ with two reference corpora.

usage: cclone.py [-k 24] [--min 3] --base BASE_DIR --other OTHER_DIR CAND_DIR

For every candidate C/C++ file:
  base%   tokens covered by k-token runs found in BASE (e.g. Borland release import)
  other%  tokens covered by runs found in OTHER (e.g. SET's GPL port)
  only%   tokens covered by OTHER runs but NOT by BASE runs (code that could only
          have come from OTHER, not from the common Borland ancestor)
  maxonly longest contiguous only-run
"""
import re, sys, os, argparse

TOK = re.compile(r'''
   (?P<str>"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')
 | (?P<num>0[xX][0-9a-fA-F]+[uUlL]*|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?[uUlLfF]*)
 | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
 | (?P<sym>::|->|<<=|>>=|<<|>>|<=|>=|==|!=|&&|\|\||\+\+|--|[-+*/%&|^]=|[^\sA-Za-z0-9_])
''', re.X)
EXT = ('.c', '.cc', '.cpp', '.cxx', '.h', '.hpp', '.hh')

def strip(t):
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if c in '"\'':
            j = i + 1
            while j < n and t[j] != c and t[j] != '\n':
                j += 2 if t[j] == '\\' else 1
            out.append(t[i:j + 1]); i = j + 1
        elif t.startswith('//', i):
            j = t.find('\n', i); i = n if j < 0 else j
        elif t.startswith('/*', i):
            j = t.find('*/', i + 2); i = n if j < 0 else j + 2; out.append(' ')
        elif c == '#' and (i == 0 or t[i - 1] == '\n'):
            # keep preprocessor lines as tokens too (includes, defines)
            out.append(c); i += 1
        else:
            out.append(c); i += 1
    return ''.join(out)

def tokens(p):
    t = strip(open(p, encoding='latin-1').read())
    return [m.group(m.lastgroup) for m in TOK.finditer(t)]

def files(d):
    for root, _, fs in os.walk(d):
        for f in sorted(fs):
            if f.lower().endswith(EXT):
                yield os.path.join(root, f)

def gramset(d, K):
    s = set()
    for p in files(d):
        r = tokens(p)
        s.update(hash(tuple(r[i:i + K])) for i in range(len(r) - K + 1))
    return s

def cover(r, S, K):
    c = [False] * len(r)
    for i in range(len(r) - K + 1):
        if hash(tuple(r[i:i + K])) in S:
            for j in range(i, i + K): c[j] = True
    return c

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-k', type=int, default=24)
    ap.add_argument('--min', type=float, default=3.0)
    ap.add_argument('--base', required=True)
    ap.add_argument('--other', required=True)
    ap.add_argument('cand')
    a = ap.parse_args(); K = a.k
    B, O = gramset(a.base, K), gramset(a.other, K)
    rows = []; T = [0, 0, 0, 0]
    for p in files(a.cand):
        r = tokens(p)
        if len(r) < K: continue
        cb, co = cover(r, B, K), cover(r, O, K)
        only = [o and not b for o, b in zip(co, cb)]
        mx = run = 0
        for x in only:
            run = run + 1 if x else 0; mx = max(mx, run)
        n = len(r); nb, no, nn = sum(cb), sum(co), sum(only)
        T[0] += n; T[1] += nb; T[2] += no; T[3] += nn
        rows.append((os.path.relpath(p, a.cand), n, 100*nb/n, 100*no/n, 100*nn/n, mx))
    print("%-44s %7s %6s %6s %6s %7s" % ('file', 'tokens', 'base%', 'other%', 'only%', 'maxonly'))
    for row in sorted(rows, key=lambda x: (-x[5], -x[4])):
        if row[4] >= a.min or row[5] >= 2 * K:
            print("%-44s %7d %5.0f%% %5.0f%% %5.0f%% %7d" % row)
    print("TOTAL %d files, %d tokens: base %.1f%%  other %.1f%%  only %.1f%%" % (
        len(rows), T[0], 100*T[1]/max(1,T[0]), 100*T[2]/max(1,T[0]), 100*T[3]/max(1,T[0])))

if __name__ == '__main__':
    main()
