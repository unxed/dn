#!/usr/bin/env python3
"""Drops the repeated names of one uses clause (`uses A, B, A;` -> `uses A, B;`; the case does not matter).
After the unit alias of vpc.cfg has been applied (LFN and LFNVP are one unit) a clause may name the unit twice, which
FPC rejects. usage: dedup-uses.py FILE...   prints the number of the names dropped."""
import re, sys
n = 0
USES = re.compile(r'(\buses\b)(.*?)(;)', re.I | re.S)
for p in sys.argv[1:]:
    raw = open(p, 'rb').read().decode('latin-1')
    def fix(m):
        global n
        body = m.group(2)
        if '{' in body or '(*' in body or '//' in body:
            # comments in the clause: handle the name tokens only, keep the comments where they are
            pass
        seen, out = set(), []
        # split on commas that are not inside comments: names and comments do not contain commas in DN
        parts = body.split(',')
        for part in parts:
            name = re.sub(r'\{[^}]*\}|//[^\r\n]*|\(\*.*?\*\)', ' ', part, flags=re.S).strip().lower()
            if name and name in seen:
                n += 1
                comments = ''.join(re.findall(r'\{[^}]*\}', part))
                out.append(comments)       # the comment of the dropped name stays
                continue
            if name:
                seen.add(name)
            out.append(part)
        return m.group(1) + ','.join(x for x in out if x != '') + m.group(3)
    new = USES.sub(fix, raw)
    if new != raw:
        open(p, 'wb').write(new.encode('latin-1'))
print('dedup-uses: %d names' % n)
