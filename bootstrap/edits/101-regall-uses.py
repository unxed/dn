#!/usr/bin/env python3
"""reason: (д) the modern compiler. regall.pas names classes with the qualifier of their unit (`DblWnd.TFoo`) and
does not use all of those units (in VP the units of the program are known everywhere). The units of the tree that it names
are added to its uses clause of the implementation.
usage: 101-regall-uses.py FILE...   (all the .pas of the tree)"""
import re, sys, os
files = {}
for p in sys.argv[1:]:
    files[os.path.splitext(os.path.basename(p))[0].lower()] = os.path.splitext(os.path.basename(p))[0]
import glob
here = os.path.dirname(os.path.abspath(__file__))
for q in glob.glob(os.path.join(here, '..', 'new', '*.pas')):      # our own units are copied into the tree later
    files[os.path.splitext(os.path.basename(q))[0].lower()] = os.path.splitext(os.path.basename(q))[0]
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'regall.pas':
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    code = re.sub(r"//[^\n]*|\{[^}]*\}|\(\*.*?\*\)|'[^'\n]*'", ' ', raw, flags=re.S)
    im = re.search(r'^implementation\b', code, re.M)
    uses = re.search(r'\buses\b([^;]*);', code[im.end():], re.I)
    have = {x.strip().lower() for x in uses.group(1).split(',')}
    named = {m.group(1).lower() for m in re.finditer(r'\b(\w+)\.[PT]\w+', code)}
    add = sorted(files[n] for n in named if n in files and n not in have and n != 'regall')
    if add:
        a = raw.index('uses', raw.index('implementation'))
        raw = raw[:a] + 'uses\r\n  ' + ', '.join(add) + ',' + raw[a + 4:]
        open(p, 'wb').write(raw.encode('latin-1'))
    print('101-regall-uses: %s' % ', '.join(add))
