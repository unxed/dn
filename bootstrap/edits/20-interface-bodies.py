#!/usr/bin/env python3
"""reason: (д) building with FPC. Virtual Pascal (and Delphi) allow a routine with its body in the
interface section (`function Bit(N: Word): Word; inline; begin ... end;`); FPC does not. The body is moved
to the implementation section (after its uses clause), the interface keeps the header; the directive
`inline;` is dropped. Only routines at the left margin are taken (the methods of objects have no bodies
in the interface).

usage: 20-interface-bodies.py FILE...   (the files are changed in place; bytes are kept as they are)
"""
import re, sys

def strip_comments(s):
    s = re.sub(r'\{[^}]*\}', '', s)
    s = re.sub(r'\(\*.*?\*\)', '', s)
    s = re.sub(r"'[^']*'", "''", s)
    return re.sub(r'//.*$', '', s)

def process(lines):
    low = [l.lower() for l in lines]
    try:
        ii = next(i for i, l in enumerate(low) if re.match(r'^\s*interface\b', l))
        im = next(i for i, l in enumerate(low) if re.match(r'^\s*implementation\b', l) and i > ii)
    except StopIteration:
        return lines, 0
    out = lines[:ii + 1]
    moved = []
    i = ii + 1
    while i < im:
        l = lines[i]
        m = re.match(r'^(function|procedure)\s', l, re.I)
        if not m:
            out.append(l); i += 1; continue
        # the header up to the ';' outside the parentheses
        h = i; depth = 0; text = ''
        while True:
            t = strip_comments(lines[h])
            depth += t.count('(') - t.count(')')
            text += t
            if depth <= 0 and t.rstrip().endswith(';'):
                break
            h += 1
            if h >= im:
                break
        if h >= im:
            out.extend(lines[i:im]); i = im; break
        # what follows: blank lines, directives, `inline;`, then an indented begin / asm / var / const
        k = h + 1
        while k < im and (strip_comments(lines[k]).strip() == '' or re.match(r'^\s*\{\$', lines[k]) or
                          re.match(r'^\s*inline\s*;', lines[k], re.I)):
            k += 1
        has_body = k < im and re.match(r'^\s+(begin|asm|var|const|label)\b', lines[k], re.I)
        # `{$IFDEF X} inline;` on the line of the directive: the directive line is part of the block
        if not has_body:
            out.extend(lines[i:h + 1]); i = h + 1; continue
        # find the end of the body
        depth = 0; seen = False; e = k
        while e < im:
            t = strip_comments(lines[e]).lower()
            for tok in re.findall(r'\b(begin|asm|case|try|end)\b', t):
                if tok == 'end':
                    depth -= 1
                else:
                    depth += 1; seen = True
            if seen and depth <= 0:
                break
            e += 1
        if e >= im:
            out.extend(lines[i:h + 1]); i = h + 1; continue
        header = [re.sub(r'\binline\s*;', '', x, flags=re.I) for x in lines[i:h + 1]]
        body = [re.sub(r'\binline\s*;', '', x, flags=re.I) for x in lines[h + 1:e + 1]]
        out.extend(header)
        moved.append(header + body)
        i = e + 1
    out.extend(lines[im:im + 1])
    rest = lines[im + 1:]
    # after the uses clause of the implementation
    j = 0
    while j < len(rest) and strip_comments(rest[j]).strip() == '':
        j += 1
    if j < len(rest) and re.match(r'^\s*uses\b', rest[j], re.I):
        while ';' not in strip_comments(rest[j]):
            j += 1
        j += 1
    ins = []
    for blk in moved:
        ins.extend(blk)
        ins.append('')
    return out + rest[:j] + ins + rest[j:], len(moved)

for f in sys.argv[1:]:
    data = open(f, 'rb').read().decode('latin-1')
    lines = data.split('\n')
    new, n = process(lines)
    if n:
        open(f, 'wb').write('\n'.join(new).encode('latin-1'))
        print('%s: %d bodies moved' % (f, n))
