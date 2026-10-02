#!/usr/bin/env python3
"""reason: (a) the new TV, (д) the modern compiler. The routines that DN passes to FirstThat/LastThat/ForEach
(declared inside the caller) take a typed pointer (PMacroCommand, PDOSVar...); Turbo Pascal does not check that.
The procedure variable that tv/ takes has a parameter of the type Pointer (of a collection) or PView (of a
group), and FPC wants the types to be the same. The parameter is renamed and a variable of the declared type
overlays it: `procedure DoPlay(P: PMacroCommand);` becomes `procedure DoPlay(P_: Pointer); var P: PMacroCommand
absolute P_;`. Which parameter type the caller needs is told by the table of kinds below (default Pointer).
usage: 62-callback-params.py FILE...   (all the .pas of the tree)"""
import re, sys

CALL = re.compile(r'\.(FirstThat|LastThat|ForEach)\(([A-Za-z_]\w*)\)')
n = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    names = {}
    for m in CALL.finditer(raw):
        names[m.group(2).lower()] = m.group(2)
    if not names:
        continue
    out = raw
    for low, name in names.items():
        pat = re.compile(r'^([ \t]*)(procedure|function)([ \t]+)(' + re.escape(name) + r')[ \t]*\([ \t]*(\w+)[ \t]*:[ \t]*(\w+)[ \t]*\)([ \t]*:[ \t]*\w+)?[ \t]*;',
                         re.I | re.M)
        def fix(m):
            global n
            ind, kind, sp, nm, par, typ, res = m.groups()
            if typ.lower() in ('pointer',):
                return m.group(0)
            n += 1
            want = 'PView' if typ.lower() == 'pview' else 'Pointer'
            if want == 'PView':
                return m.group(0)
            return '%s%s%s%s(%s_: Pointer)%s;\r\n%svar %s: %s absolute %s_;' % (ind, kind, sp, nm, par, res or '', ind, par, typ, par)
        out = pat.sub(fix, out, count=1)
    if out != raw:
        open(p, 'wb').write(out.encode('latin-1'))
print('62-callback-params: %d routines' % n)
