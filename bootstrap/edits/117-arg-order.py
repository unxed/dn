#!/usr/bin/env python3
"""reason: (д) the modern compiler. VP evaluates the arguments of a call left to right, FPC right to left; rcp.pas (the resource
compiler) reads a token stream with calls like `R.Assign(GetID(Token(S,i)), GetID(Token(S,i)), ...)` and so depends on the order.
Each such statement (two or more `Token(S, i)` in it) becomes `begin T1 := ...; T2 := ...; stmt(T1, T2) end` with the
temporaries in the order of reading. usage: 117-arg-order.py FILE...   (acts on rcp.pas only)"""
import re, sys, os
TOK = re.compile(r'GetID\(Token\(S, ?[iI]\)\)|Token\(S, ?[iI]\)')
for p in sys.argv[1:]:
    if os.path.basename(p).lower() != 'rcp.pas':
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    nl = '\r\n' if '\r\n' in raw else '\n'
    L = raw.split(nl)
    out = []
    i = 0
    cnt = 0
    while i < len(L):
        if 'Token(S' in L[i] and not L[i].lstrip().lower().startswith(('function', 'procedure')):
            j = i
            s = L[i]
            while not s.rstrip().endswith(';') and j + 1 < len(L):
                j += 1
                s += ' ' + L[j].strip()
            occ = TOK.findall(s)
            body = s.strip()
            if len(occ) >= 2 and body.endswith(';') and not re.search(r'\b(else|then)\b', body, re.I) and body.count('(') == body.count(')'):
                ind = re.match(r'\s*', L[i]).group(0)
                pre = []
                k = [0]
                def rep(m):
                    k[0] += 1
                    t = 'TkL' if m.group(0).startswith('GetID') else 'TkS'
                    pre.append('%s[%d] := %s;' % (t, k[0], m.group(0)))
                    return '%s[%d]' % (t, k[0])
                body = TOK.sub(rep, body)
                out.append(ind + 'begin ' + ' '.join(pre) + ' ' + body[:-1] + ' end;')
                cnt += 1
                i = j + 1
                continue
        out.append(L[i])
        i += 1
    s = nl.join(out)
    # the temporaries: before the first top-level GetID
    s = re.sub(r'^function GetID', 'var' + nl + '  TkL: array[1..8] of LongInt;' + nl + '  TkS: array[1..8] of String;' + nl + nl + 'function GetID', s, count=1, flags=re.M)
    open(p, 'wb').write(s.encode('latin-1'))
    print('117-arg-order: %d statements%s' % (cnt, '' if 'TkL: array' in s else ' (DECLARATION NOT INSERTED)'))
