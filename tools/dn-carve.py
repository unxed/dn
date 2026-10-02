#!/usr/bin/env python3
"""Carves the classes that are DN's own out of a unit of the upstream tree that we do not take as a whole (it is
excluded: its Borland-derived code is replaced by tv/). The classes (their declaration, their pointer type and their
methods) are copied, with the license header of the source, into a new unit of the tree; the units of the tree that name
a carved class get the new unit in their uses clause.
usage: tools/dn-carve.py CARVE_LIST TREE_DIR
  CARVE_LIST lines `UnitName <- SourceFile : Class, Class ; uses: Unit, Unit [; consts: Name, Name]` (# comments)
Run by tools/dn-materialize.sh on the freshly extracted tree, before the exclusions. The source is read as it is
(the later edits of the tree are applied to the new unit as to any other file)."""
import os, re, sys

list_file, tree = sys.argv[1], sys.argv[2]
files = {f.lower(): f for f in os.listdir(tree)}

def read(f):
    return open(os.path.join(tree, f), 'rb').read().decode('latin-1')

def code_of(s):
    return re.sub(r"//[^\n]*|\{[^}]*\}|\(\*.*?\*\)|'[^'\n]*'", ' ', s, flags=re.S)

specs = []
for line in open(list_file, encoding='utf-8'):
    line = line.split('#', 1)[0].strip()
    if not line:
        continue
    m = re.match(r'(\w+)\s*<-\s*(\S+)\s*:\s*([^;]+);\s*uses\s*:\s*([^;]+)(?:;\s*consts\s*:\s*(.+))?$', line)
    if not m:
        sys.exit('dn-carve: cannot read the line: ' + line)
    specs.append((m.group(1), m.group(2), [c.strip() for c in m.group(3).split(',')], [u.strip() for u in m.group(4).split(',')],
                  [c.strip() for c in (m.group(5) or '').split(',') if c.strip()]))

ROUTINE = re.compile(r'^(procedure|function|constructor|destructor)\s+(\w+)\.', re.I)
BOUNDARY = re.compile(r'^(procedure|function|constructor|destructor|initialization|finalization|end\.)', re.I)

for unit, src, classes, uses, consts in specs:
    sf = files.get(src.lower())
    if not sf:
        sys.exit('dn-carve: %s is not in the tree' % src)
    text = read(sf)
    lines = text.split('\n')
    # the license header: everything before the include of STDEFINE.INC
    head = []
    for ln in lines:
        if re.match(r'\s*\{\$I\s+STDEFINE', ln, re.I):
            break
        head.append(ln)
    # the interface and the implementation
    imp = next(i for i, ln in enumerate(lines) if re.match(r'implementation\b', ln, re.I))
    iface, impl = lines[:imp], lines[imp + 1:]
    decl = []
    for c in classes:
        p = 'P' + c[1:]
        for i, ln in enumerate(iface):
            if re.match(r'\s*%s\s*=\s*\^%s\s*;' % (p, c), ln):
                decl.append(ln.rstrip('\r'))
                break
        start = next((i for i, ln in enumerate(iface) if re.match(r'\s*%s\s*=\s*object\b' % c, ln)), None)
        if start is None:
            sys.exit('dn-carve: the class %s is not in %s' % (c, src))
        end = next(i for i in range(start, len(iface)) if re.match(r'\s*end;', iface[i]))
        decl.extend(x.rstrip('\r') for x in iface[start:end + 1])
        decl.append('')
    cdecl = []
    for c in consts:
        ln = next((x for x in iface if re.match(r'\s*%s\s*=' % c, x)), None)
        if ln is None:
            sys.exit('dn-carve: the constant %s is not in %s' % (c, src))
        cdecl.append(ln.rstrip('\r'))
    body, keep, n = [], False, 0
    names = set(classes)
    for ln in impl:
        m = ROUTINE.match(ln)
        if m:
            keep = m.group(2) in names
            n += keep
        elif BOUNDARY.match(ln):
            keep = False
        if keep:
            body.append(ln.rstrip('\r'))
    out = list(x.rstrip('\r') for x in head)
    out += ['{$I STDEFINE.INC}', '', 'unit %s;' % unit, '',
            '{ Carved by tools/dn-carve.py from %s: the classes %s of Dos Navigator. }' % (sf, ', '.join(classes)), '',
            'interface', '', 'uses', '  ' + ', '.join(uses) + ';', ''] + (['const'] + cdecl + ['']) * bool(cdecl) + ['type'] + decl + ['implementation', ''] + body + ['', 'end.', '']
    open(os.path.join(tree, unit.lower() + '.pas'), 'wb').write('\r\n'.join(out).encode('latin-1'))
    print('dn-carve: %s <- %s: %d classes, %d routines' % (unit, sf, len(classes), n))
    # the units that name a carved class use the new unit
    want = re.compile(r'\b(%s)\b' % '|'.join(sorted(names | {'P' + c[1:] for c in classes})))
    added = 0
    for f in sorted(files.values()):
        if not f.lower().endswith('.pas') or f.lower() in (sf.lower(), unit.lower() + '.pas'):
            continue
        raw = read(f)
        if not want.search(code_of(raw)):
            continue
        if re.search(r'\buses\b[^;]*\b%s\b' % unit, code_of(raw), re.I):
            continue
        im = re.search(r'^[ \t]*implementation\b[^\n]*\n', raw, re.I | re.M)
        pos_name = want.search(code_of(raw)).start()
        # the first mention decides: before `implementation` (the interface) or after it
        use_iface = im is not None and re.search(r'\b(%s)\b' % '|'.join(sorted(names | {"P" + c[1:] for c in classes})), code_of(raw[:im.start()])) is not None
        if use_iface:
            u = re.search(r'\buses\b([^;]*);', raw[:im.start()], re.I)
            if u:
                pos = u.end() - 1
                raw = raw[:pos] + ', ' + unit + raw[pos:]
            else:
                continue          # no uses in the interface: reported below
        elif im:
            u = re.match(r'(\s*)uses\b([^;]*);', raw[im.end():], re.I)
            if u:
                pos = im.end() + u.end() - 1
                raw = raw[:pos] + ', ' + unit + raw[pos:]
            else:
                raw = raw[:im.end()] + '\r\nuses %s;\r\n' % unit + raw[im.end():]
        else:
            continue
        open(os.path.join(tree, f), 'wb').write(raw.encode('latin-1'))
        added += 1
    print('dn-carve: %s added to the uses of %d units' % (unit, added))
