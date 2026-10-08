#!/usr/bin/env python3
"""Counts the places that spell a path by hand (a separator, a drive letter, a ':' test) in dn/src (a ratchet: the count of a
file may only fall); DnPath (over TvPath of tv/) is the place that may. Comments ({ }, (* *), //) are not counted, nor a
backslash that is an escape (#27'\\', Ord('\\')).
tools/check-paths.py [--update] [-v]   the baseline is tools/paths-baseline.txt; -v shows the lines"""
import os, re, sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src = os.path.join(root, 'dn', 'src')
base = os.path.join(root, 'tools', 'paths-baseline.txt')

pat = re.compile(
    r"(?<![#\d(])'\\'"                # a backslash as a character
    r"|'[A-Za-z]?:\\"                  # a drive prefix: 'C:\...', ':\'
    r"|\[2\]\s*(?:=|<>)\s*':'"         # S[2] = ':'
    r"|\(\s*'\\'\s*,\s*'/'\s*\)"       # ('\', '/')
)
string = re.compile(r"'(?:[^']|'')*'")


def code_lines(path):
    """The lines without comments; string literals stay."""
    text = open(path, encoding='utf-8', errors='replace').read()
    out, cur, i, n = [], [], 0, len(text)
    close = None                       # the end of the comment we are in: '}' or '*)'
    while i < n:
        c = text[i]
        if close:
            if text.startswith(close, i):
                i += len(close)
                close = None
                continue
        elif c == "'":
            m = string.match(text, i)
            j = m.end() if m else n
            cur.append(text[i:j])
            i = j
            continue
        elif text.startswith('//', i):
            while i < n and text[i] != '\n':
                i += 1
            continue
        elif c == '{' and not text.startswith('{$', i):
            close = '}'
        elif text.startswith('(*', i):
            close = '*)'
            i += 2
            continue
        if c == '\n':
            out.append(''.join(cur))
            cur = []
        elif not close:
            cur.append(c)
        i += 1
    out.append(''.join(cur))
    return out


counts, hits = {}, {}
for f in sorted(os.listdir(src)):
    if not f.endswith(('.pas', '.inc')):
        continue
    n = 0
    for no, line in enumerate(code_lines(os.path.join(src, f)), 1):
        k = len(pat.findall(line))
        if k:
            n += k
            hits.setdefault(f, []).append('dn/src/%s:%d: %s' % (f, no, line.strip()))
    if n:
        counts[f] = n
total = sum(counts.values())
if '--update' in sys.argv:
    with open(base, 'w') as fh:
        for f, n in sorted(counts.items()):
            fh.write('%s %d\n' % (f, n))
    print('baseline', total)
    sys.exit(0)
old = {}
if os.path.exists(base):
    for l in open(base):
        if l.strip():
            a, b = l.split()
            old[a] = int(b)
bad = [(f, n, old.get(f, 0)) for f, n in sorted(counts.items()) if n > old.get(f, 0)]
for f, n, o in bad:
    print('FAIL %s: %d paths spelled by hand (the baseline allows %d); use DnPath (if it is no path, such as an escape or a set of'
          ' punctuation, raise the baseline with --update)' % (f, n, o))
    for h in hits[f]:
        print('    ' + h)
if '-v' in sys.argv:
    for f in sorted(hits):
        for h in hits[f]:
            print(h)
lower = [f for f in old if counts.get(f, 0) < old[f]]
if lower:
    print('fewer than the baseline in %s: run tools/check-paths.py --update' % ', '.join(sorted(lower)))
print('total %d (baseline %d)' % (total, sum(old.values())))
sys.exit(1 if bad else 0)
