#!/usr/bin/env python3
"""Replaces regions of the sources of the archive by our own text (PLAN.md decision 11: the places that
repeat Borland code are rewritten; git keeps only our text, the replaced lines are never quoted).

usage: dn-rewrite.py TREE RW_DIR      (run on the pristine tree, before any other edit)

A file RW_DIR/NAME.rw:
    file: FVIEWER.PAS            file of the tree (case-insensitive)
    after: <line>                (optional) the search starts after the first line equal to this
    from: <line>                 first line of the region (a line equal to this, ignoring blanks and case)
    from-keep: yes               (optional) the line `from` stays
    to: <line>                   the first line equal to this after `from` ends the region
    to-keep: yes                 (optional) the line `to` stays (default: it is replaced too)
    sha1: <hex>                  (optional) SHA-1 of the replaced lines (stripped, lower-case, joined by \\n):
                                 if the archive changes, the region is not the one that was meant
    ---
    the replacement (ASCII; written with the line ends of the file)
Several regions of one file: several .rw files (applied in the order of the names).
"""
import sys, os, re, hashlib, glob

tree, rwdir = sys.argv[1], sys.argv[2]

def norm(s):
    return re.sub(r'\s+', ' ', s.strip()).lower()

def parse(path):
    head, body, inbody = {}, [], False
    for line in open(path, encoding='ascii').read().split('\n'):
        if inbody:
            body.append(line)
        elif line.strip() == '---':
            inbody = True
        elif ':' in line and not line.startswith('#'):
            k, v = line.split(':', 1)
            head[k.strip()] = v.strip()
    while body and body[-1] == '':
        body.pop()
    return head, body

def find(lines, text, start):
    t = norm(text)
    for i in range(start, len(lines)):
        if norm(lines[i]) == t:
            return i
    return -1

done = 0
for rw in sorted(glob.glob(os.path.join(rwdir, '*.rw'))):
    h, body = parse(rw)
    cands = [f for f in os.listdir(tree) if f.lower() == h['file'].lower()]
    if not cands:
        sys.exit('dn-rewrite: %s: no file %s' % (os.path.basename(rw), h['file']))
    p = os.path.join(tree, cands[0])
    raw = open(p, 'rb').read().decode('latin-1')
    eol = '\r\n' if raw.count('\r\n') >= raw.count('\n') / 2 else '\n'
    lines = raw.split('\n')                     # the lines keep their \r, if any
    start = 0
    if 'after' in h:
        start = find(lines, h['after'], 0)
        if start < 0:
            sys.exit('dn-rewrite: %s: line "after" not found' % os.path.basename(rw))
        start += 1
    a = find(lines, h['from'], start)
    b = find(lines, h['to'], a + 1) if a >= 0 else -1
    if a < 0 or b < 0:
        sys.exit('dn-rewrite: %s: the region is not found' % os.path.basename(rw))
    first = a + (1 if h.get('from-keep') == 'yes' else 0)
    last = b - 1 if h.get('to-keep') == 'yes' else b
    if 'sha1' in h:
        got = hashlib.sha1('\n'.join(norm(x) for x in lines[first:last + 1]).encode('latin-1')).hexdigest()
        if got != h['sha1']:
            sys.exit('dn-rewrite: %s: the region differs from the one that was meant (sha1 %s)' % (os.path.basename(rw), got))
    if 'sha1' not in h:
        print('  (no sha1 in %s; the region has %s)' % (os.path.basename(rw), hashlib.sha1('\n'.join(norm(x) for x in lines[first:last + 1]).encode('latin-1')).hexdigest()))
    new = [x + ('\r' if eol == '\r\n' else '') for x in body]
    lines[first:last + 1] = new
    open(p, 'wb').write('\n'.join(lines).encode('latin-1'))
    print('%s: %s lines %d-%d replaced by %d lines' % (os.path.basename(rw), cands[0], first + 1, last + 1, len(body)))
    done += 1
print('dn-rewrite: %d regions' % done)
