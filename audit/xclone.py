#!/usr/bin/env python3
"""Token-level clone finder for Pascal (MOSS-like, but exact k-gram coverage).

usage: xclone.py [-k 24] [--min 3] --ref REF_LIST_FILE CAND_DIR

REF_LIST_FILE: one reference source path per line (see fetch_reference.sh).
For every candidate .pas/.pp/.inc file prints the share of its tokens covered by
k-token runs that also occur somewhere in the reference corpus (any file):
  raw%  - identifiers kept (lower-cased): verbatim copy, any formatting/comments
  ren%  - identifiers replaced by ID:    copy with renamed identifiers
  impl% - raw%, implementation section only (interfaces must match for API
          compatibility, so impl% is the number that matters for units)
  ref   - reference file contributing most matches
Comments, whitespace, layout and letter case are ignored.
"""
import re, sys, os, argparse, collections

TOK = re.compile(r"""
   (?P<str>(?:'(?:[^']|'')*'|\#\$?[0-9a-fA-F]+)+)   # 'abc'#13'def', #$70#$78: one literal
 | (?P<num>\$[0-9a-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)
 | (?P<id>[A-Za-z_][A-Za-z0-9_]*)
 | (?P<sym>:=|<=|>=|<>|\.\.|[^\sA-Za-z0-9_])
""", re.X)
KEYWORDS = set("""and array asm begin case const constructor destructor div do downto else end
exports file for function goto if implementation in inherited inline interface label
library mod nil not object of or packed procedure program record repeat set shl shr
string then to type unit until uses var while with xor absolute assembler far forward
external interrupt near private public virtual""".split())

def strip_comments(t):
    out, i, n = [], 0, len(t)
    while i < n:
        c = t[i]
        if c == "'":
            j = i + 1
            while j < n:
                if t[j] == "'":
                    if j + 1 < n and t[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            out.append(t[i:j + 1]); i = j + 1
        elif c == '{':
            j = t.find('}', i); i = n if j < 0 else j + 1; out.append(' ')
        elif t.startswith('(*', i):
            j = t.find('*)', i + 2); i = n if j < 0 else j + 2; out.append(' ')
        elif t.startswith('//', i):
            j = t.find('\n', i); i = n if j < 0 else j; out.append(' ')
        else:
            out.append(c); i += 1
    return ''.join(out)

def tokens(path):
    t = strip_comments(open(path, encoding='latin-1').read())
    raw, ren, impl_start = [], [], None
    for m in TOK.finditer(t):
        k = m.lastgroup; v = m.group(k)
        if k == 'id':
            lv = v.lower()
            if lv == 'implementation' and impl_start is None:
                impl_start = len(raw)
            raw.append(lv)
            ren.append(lv if lv in KEYWORDS else 'ID')
        elif k == 'str':
            raw.append(v.lower()); ren.append('LIT')
        elif k == 'num':
            raw.append(v.lower()); ren.append('NUM')
        else:
            raw.append(v); ren.append(v)
    return raw, ren, (impl_start if impl_start is not None else 0)

def grams(seq, k):
    return [hash(tuple(seq[i:i + k])) for i in range(len(seq) - k + 1)]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('-k', type=int, default=24)
    ap.add_argument('--min', type=float, default=3.0, help='print files with raw%% or ren%% >= this')
    ap.add_argument('--ref', required=True)
    ap.add_argument('cand')
    a = ap.parse_args()
    K = a.k
    refs = [l.strip() for l in open(a.ref) if l.strip()]
    rraw, rren = {}, set()
    for p in refs:
        r, n, _ = tokens(p)
        for g in grams(r, K):
            rraw.setdefault(g, os.path.basename(p).upper())
        rren.update(grams(n, K))
    rows, T = [], collections.Counter()
    for root, _, fs in os.walk(a.cand):
        for f in sorted(fs):
            if not f.lower().endswith(('.pas', '.pp', '.inc')):
                continue
            r, n, imp = tokens(os.path.join(root, f))
            if len(r) < K:
                continue
            cr, cn = [False] * len(r), [False] * len(n)
            src = collections.Counter()
            for i, g in enumerate(grams(r, K)):
                if g in rraw:
                    src[rraw[g]] += 1
                    for j in range(i, i + K): cr[j] = True
            for i, g in enumerate(grams(n, K)):
                if g in rren:
                    for j in range(i, i + K): cn[j] = True
            nr, nn = sum(cr), sum(cn)
            mx = run = 0
            for c in cr:
                run = run + 1 if c else 0
                mx = max(mx, run)
            ni = sum(cr[imp:]); li = len(r) - imp
            T['tok'] += len(r); T['raw'] += nr; T['ren'] += nn; T['itok'] += li; T['iraw'] += ni
            rows.append((os.path.relpath(os.path.join(root, f), a.cand), len(r),
                         100 * nr / len(r), 100 * nn / len(r),
                         100 * ni / li if li else 0.0,
                         mx, src.most_common(1)[0][0] if src else '-'))
    print("%-28s %7s %6s %6s %6s %6s  %s" % ('file', 'tokens', 'raw%', 'ren%', 'impl%', 'maxrun', 'ref'))
    for row in sorted(rows, key=lambda x: (-x[2], -x[5])):
        if row[2] >= a.min or row[5] >= 4 * K:
            print("%-28s %7d %5.0f%% %5.0f%% %5.0f%% %6d  %s" % row)
    print("TOTAL %d files, %d tokens: raw %.1f%%  ren %.1f%%  impl(raw) %.1f%%" % (
        len(rows), T['tok'], 100 * T['raw'] / max(1, T['tok']), 100 * T['ren'] / max(1, T['tok']),
        100 * T['iraw'] / max(1, T['itok'])))

if __name__ == "__main__":
    main()
