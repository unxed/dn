#!/usr/bin/env python3
"""reason: (d) the modern compiler. Pascal of Borland and VP lets the implementation of a routine or of a
method repeat nothing: `procedure TFoo.Bar;`, `function Baz;` (the parameters and the result type are those
of the declaration). FPC wants them repeated. This edit copies the parameters and the result type from the
declaration (the interface part of the unit or the object type) into such headers.
usage: 15-short-headers.py FILE...   (all the .pas of the tree)"""
import re, sys

KIND = r'(?:procedure|function|constructor|destructor)'
# name of a routine: Name or Class.Name
HDR = re.compile(r'^(?P<ind>[ \t]*)(?P<kind>' + KIND + r')[ \t]+(?P<name>[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)?)(?P<rest>[^\n]*)$',
                 re.I | re.M)

def take_signature(text, pos):
    """From pos (after the name) up to the ';' at depth 0: returns (signature, end)."""
    depth = 0
    i = pos
    while i < len(text):
        c = text[i]
        if c in '([':
            depth += 1
        elif c in ')]':
            depth -= 1
        elif c == ';' and depth == 0:
            return text[pos:i], i
        elif c in '{' and depth == 0:     # a comment inside a header: give up
            return None, i
        i += 1
    return None, i

def process(path):
    raw = open(path, 'rb').read().decode('latin-1')
    low = raw.lower()
    imp = low.find('\nimplementation')
    if imp < 0:
        return 0
    decl = {}
    # declarations: the interface part and the object types (anywhere before their methods)
    cls = None
    for m in re.finditer(r'^(?P<ind>[ \t]*)(?:(?P<tname>[A-Za-z_]\w*)[ \t]*=[ \t]*(?:packed[ \t]+)?(?:object|class)\b|(?P<end>end\b)|(?P<kind>' + KIND + r')[ \t]+(?P<name>[A-Za-z_]\w*))',
                         raw, re.I | re.M):
        if m.group('tname'):
            cls = m.group('tname').lower()
        elif m.group('end'):
            cls = None if m.start() < imp or True else cls
        elif m.group('kind'):
            sig, end = take_signature(raw, m.end())
            if sig is None:
                continue
            # the comments of the declaration are not copied (a // comment would hide the rest of the joined line)
            sig = re.sub(r'//[^\n]*', '', sig)
            sig = re.sub(r'\{[^}]*\}|\(\*.*?\*\)', '', sig, flags=re.S)
            sig = re.sub(r'\s+', ' ', sig.strip())
            key = (cls + '.' if cls else '') + m.group('name').lower()
            if m.start() < imp or cls:
                decl.setdefault(key, sig)
    n = 0
    out, last = [], 0
    for m in HDR.finditer(raw):
        if m.start() < imp:
            continue
        rest = m.group('rest')
        # a header that has nothing after the name but ';' (and maybe a comment)
        if not re.match(r'^[ \t]*;', rest):
            continue
        name = m.group('name').lower()
        sig = decl.get(name)
        if not sig:
            continue
        if m.group('kind').lower() in ('function',) or sig:
            new = m.group('ind') + m.group('kind') + ' ' + m.group('name') + sig + rest
            out.append(raw[last:m.start()]); out.append(new); last = m.end(); n += 1
    out.append(raw[last:])
    if n:
        open(path, 'wb').write(''.join(out).encode('latin-1'))
    return n

total = files = 0
for p in sys.argv[1:]:
    k = process(p)
    if k:
        total += k; files += 1
print('15-short-headers: %d headers in %d files' % (total, files))
