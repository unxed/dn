#!/usr/bin/env python3
"""reason: (a) the new TV. A stream record of Borland TV holds pointers to the constructor Load and the method Store
(`RFoo: TStreamRec = (ObjType: N; VmtLink: (TypeOf(TFoo)); Load: @TFoo.Load; Store: @TFoo.Store);`); in tv/ it holds a
function that makes and loads an object and a procedure that stores one (tv/DESIGN.md: a constructor cannot be called
through a pointer). The constants stay (the number of the type), the functions are added at the end of the unit and
a procedure sets the record at the start of the program. RegisterAll of regall.pas walked over the records in the
memory (the layout of the constants); it names them one by one.
usage: 93-streamrec.py FILE...   (all the .pas of the tree)"""
import re, sys, os

REC = re.compile(r'(\w+)(\s*:\s*)TStreamRec(\s*=\s*)\(\s*ObjType\s*:\s*([^;]+?)\s*;\s*VmtLink\s*:\s*\(TypeOf\(([\w.]+)\)\)\s*;\s*'
                 r'Load\s*:\s*@([\w.]+)\.Load\s*;\s*Store\s*:\s*@([\w.]+)\.Store\s*\)\s*;', re.I)

def ptr_of(t):
    q, _, n = t.rpartition('.')
    return (q + '.' if q else '') + ('P' + n[1:] if n[:1] in 'Tt' else 'P' + n)

total = 0
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    recs = []
    def sub(m):
        name, c1, c2, obj, t = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        recs.append((name, t))
        return '%s%sTStreamRec%s(ObjType: %s; VmtLink: 0; Load: nil; Store: nil; Next: nil);' % (name, c1, c2, obj)
    new = REC.sub(sub, raw)
    if not recs:
        continue
    nl = '\r\n' if '\r\n' in raw else '\n'
    out = []
    for name, t in recs:
        pt = ptr_of(t)
        out.append('function Build_%s(var S: TStream): PObject;%sbegin%s  Result := PObject(New(%s, Load(S)));%send;%s' % (name, nl, nl, pt, nl, nl))
        out.append('procedure Store_%s(P: PObject; var S: TStream);%sbegin%s  %s(P)^.Store(S);%send;%s' % (name, nl, nl, pt, nl, nl))
    out.append('procedure SetStreamRecs_%s;%sbegin%s' % (os.path.splitext(os.path.basename(p))[0], nl, nl))
    for name, t in recs:
        out.append('  %s.VmtLink := PtrUInt(TypeOf(%s));%s  %s.Load := @Build_%s;%s  %s.Store := @Store_%s;%s' % (name, t, nl, name, name, nl, name, name, nl))
    out.append('end;%s' % nl)
    unit = os.path.splitext(os.path.basename(p))[0]
    is_program = re.search(r'^\s*program\s', new, re.I | re.M) is not None
    m = list(re.finditer(r'^end\.[ \t]*\r?\n?', new, re.M))[-1]
    block = nl.join(out)
    if is_program:
        # a program: the records are set at its start (the first begin of the main block)
        mb = list(re.finditer(r'^begin[ \t]*\r?\n', new, re.M))[-1]
        new = new[:mb.start()] + block + nl + new[mb.start():mb.end()] + 'SetStreamRecs_%s;%s' % (unit, nl) + new[mb.end():]
    else:
        ini = re.search(r'^initialization[ \t]*\r?\n', new, re.M | re.I)
        if ini:
            new = new[:ini.start()] + block + nl + new[ini.start():ini.end()] + '  SetStreamRecs_%s;%s' % (unit, nl) + new[ini.end():]
        else:
            new = new[:m.start()] + block + nl + 'initialization%s  SetStreamRecs_%s;%s' % (nl, unit, nl) + new[m.start():]
    # RegisterAll of regall.pas: no walk over the memory
    if unit.lower() == 'regall':
        names = [r[0] for r in recs]
        calls = ''.join('    RegisterType(%s);%s' % (n, nl) for n in names)
        new = re.sub(r'procedure RegisterAll;[ \t]*\r?\n\s*var.*?until PtrRec\(P\)\.Ofs > Ofs\(RColorPoint\);\r?\n\s*end;',
                     lambda mm: 'procedure RegisterAll;%s  begin%s%s  end;' % (nl, nl, calls), new, count=1, flags=re.S)
    open(p, 'wb').write(new.encode('latin-1'))
    total += len(recs)
print('93-streamrec: %d records' % total)
