#!/usr/bin/env python3
"""A debugging aid (not part of the build): puts DNErrLog.DNTrace('> Unit.Routine') at the start of the body of every
routine declared in column 0 (procedure, function, constructor, destructor) of the given files of build/dn, so that the
trace (DNERR.TXT, or COM1 with DNSERIAL) shows what was entered last when DN dies.
usage: dn-trace-calls.py FILE.pas...      (run after tools/dn-materialize.sh; the tree is rebuilt by it)"""
import re, sys, os
HDR = re.compile(r'^(procedure|function|constructor|destructor)\s+([A-Za-z_][\w.]*)', re.I)
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    nl = '\r\n' if '\r\n' in raw else '\n'
    L = raw.split(nl)
    unit = os.path.splitext(os.path.basename(p))[0]
    # only after the line `implementation`
    start = next((i for i, l in enumerate(L) if l.strip().lower() == 'implementation'), None)
    if start is None:
        continue
    out = L[:start + 1]
    i = start + 1
    n = 0
    uses_added = False
    while i < len(L):
        m = HDR.match(L[i])
        out.append(L[i])
        i += 1
        if not m:
            continue
        name = m.group(2)
        # the header may go on; the body begins at the first `begin` of indent <= 2; forward declarations have none
        j = i
        while j < len(L) and not re.match(r'^(procedure|function|constructor|destructor|implementation|initialization|finalization|end\.)', L[j], re.I):
            if re.match(r'^( {0,2})begin\b', L[j], re.I):
                break
            j += 1
        if j < len(L) and re.match(r'^( {0,2})begin\b', L[j], re.I) and not re.search(r'\bforward\b|\bexternal\b', ''.join(L[i - 1:j]), re.I):
            out.extend(L[i:j + 1])
            ind = re.match(r' *', L[j]).group(0)
            out.append("%s  DNErrLog.DNTrace('> %s.%s');" % (ind, unit, name.replace("'", '')))
            n += 1
            i = j + 1
    s = nl.join(out)
    # DNErrLog must be visible: add it to the first uses clause of the implementation or create one
    m = re.search(r'^implementation[ \t]*\r?\n', s, re.I | re.M)
    rest = s[m.end():]
    first_routine = re.search(r'^(procedure|function|constructor|destructor)\b', rest, re.I | re.M)
    mu = re.search(r'^uses\b', rest, re.I | re.M)
    if mu and (first_routine is None or mu.start() < first_routine.start()):
        k = m.end() + mu.end()
        s = s[:k] + ' DNErrLog,' + s[k:]
    else:
        s = s[:m.end()] + 'uses DNErrLog;' + nl + s[m.end():]
    open(p, 'wb').write(s.encode('latin-1'))
    print('%s: %d routines' % (unit, n))
