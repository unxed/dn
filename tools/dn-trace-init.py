#!/usr/bin/env python3
"""A test aid: puts DNErrLog.DNTrace('init UNIT') at the start of the initialization (or of the main block) of every unit
of the tree, so that the file DNERR.TXT (DNDUMP set, see dn/new/dnerrlog.pas) shows the order of the initializations and
where the program stops. Changes the materialized tree only (build/dn), run after tools/dn-materialize.sh.
usage: tools/dn-trace-init.py TREE"""
import os, re, sys
tree = sys.argv[1]
n = 0
for f in sorted(os.listdir(tree)):
    if not f.lower().endswith('.pas') or f.startswith('_') or f.lower() in ('dnerrlog.pas', 'dn.pas', 'version.pas', 'rcp.pas'):
        continue
    p = os.path.join(tree, f)
    raw = open(p, 'rb').read().decode('latin-1')
    if not re.search(r'^unit\b', re.sub(r'\{[^}]*\}|//[^\n]*|\(\*.*?\*\)', ' ', raw, flags=re.S), re.M | re.I):
        continue
    nl = '\r\n' if '\r\n' in raw else '\n'
    knows = re.search(r'\bDNErrLog\b', raw) is not None
    name = os.path.splitext(f)[0]
    ini = re.search(r'^initialization[ \t]*\r?\n', raw, re.M | re.I)
    if ini:
        pos = ini.end()
    else:
        # the main block: the last `begin` at the start of a line that follows the last routine
        ms = list(re.finditer(r'^begin[ \t]*\r?\n', raw, re.M | re.I))
        if not ms:
            continue
        last_routine = max([m.start() for m in re.finditer(r'^(procedure|function|constructor|destructor)\b', raw, re.M | re.I)] + [0])
        cand = [m for m in ms if m.start() > last_routine]
        if not cand:
            continue
        pos = cand[-1].end()
    raw = raw[:pos] + "DNErrLog.DNTrace('init %s');%s" % (name, nl) + raw[pos:]
    if knows:
        open(p, 'wb').write(raw.encode('latin-1'))
        n += 1
        continue
    # DNErrLog must be known: the uses clause of the implementation (or a new one)
    im = re.search(r'^[ \t]*implementation\b[^\n]*\n', raw, re.I | re.M)
    if not im:
        continue
    u = re.match(r'(?:\s*\{\$[^}]*\})*\s*uses\b([^;]*);', raw[im.end():], re.I)
    if u:
        q = im.end() + u.end() - 1
        raw = raw[:q] + ', DNErrLog' + raw[q:]
    else:
        raw = raw[:im.end()] + 'uses DNErrLog;' + nl + raw[im.end():]
    open(p, 'wb').write(raw.encode('latin-1'))
    n += 1
print('dn-trace-init: %d units' % n)
