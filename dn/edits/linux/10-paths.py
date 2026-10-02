#!/usr/bin/env python3
"""reason: (д) the Linux build: DN names its files as DOS does ("C:\\DIR\\FILE.EXT", any case). The calls of the system that take a
name get it through SysOsPath (dn/new/vpsyslow.pas): the drive letter is dropped, "\\" is "/", the case is found. Applied to
the sources of DN by tools/dn-materialize.sh for DN_TARGET=linux only (dn/edits/linux/).
usage: 10-paths.py FILE.pas..."""
import re
import sys

# name of the call: the position of the argument that is a path (0-based); None: all of them
CALLS = {'Assign': 1, 'Rename': 1, 'ChDir': 0, 'MkDir': 0, 'RmDir': 0}
OURS = {'vpsyslow.pas', 'vpsyslo2.pas', 'dpmi32.pas', 'country_.pas'}
LOWER = {c.lower(): v for c, v in CALLS.items()}
call_re = re.compile(r'(?<![\w.])(' + '|'.join(CALLS) + r')\s*\(', re.I)


def split_args(text, start):
    """the arguments of the call whose '(' is at start-1; returns (list of (a, b) spans, index of ')')"""
    depth = 1
    i = start
    args = []
    a = start
    in_str = False
    while i < len(text):
        c = text[i]
        if in_str:
            if c == "'":
                in_str = False
        elif c == "'":
            in_str = True
        elif c in '([':
            depth += 1
        elif c in ')]':
            depth -= 1
            if depth == 0:
                args.append((a, i))
                return args, i
        elif c == ',' and depth == 1:
            args.append((a, i))
            a = i + 1
        elif c in '\r\n' or c == ';':
            return None, i
        i += 1
    return None, i


def fix(text):
    out = []
    pos = 0
    count = 0
    for m in call_re.finditer(text):
        if m.start() < pos:
            continue
        # not in a comment line {...} that is on one line: skip when '{' precedes on the line without '}'
        ls = text.rfind('\n', 0, m.start()) + 1
        before = text[ls:m.start()]
        if before.count('{') > before.count('}') or '//' in before or before.count('(*') > before.count('*)'):
            continue
        # a declaration (procedure ChDir(...)): skip
        if re.search(r'(procedure|function)\s+$', before, re.I):
            continue
        args, end = split_args(text, m.end())
        if not args:
            continue
        k = LOWER[m.group(1).lower()]
        if k >= len(args):
            continue
        a, b = args[k]
        arg = text[a:b]
        if 'SysOsPath' in arg or not arg.strip():
            continue
        lead = arg[:len(arg) - len(arg.lstrip())]
        out.append(text[pos:a])
        out.append(lead + 'SysOsPath(' + arg.strip() + ')')
        pos = b
        count += 1
    out.append(text[pos:])
    return ''.join(out), count


def add_uses(text):
    """adds VPSysLow to the uses clause of the implementation (of the program)"""
    m = re.search(r'^[ \t]*implementation\b', text, re.I | re.M)
    if m:
        u = re.compile(r'\buses\b', re.I).search(text, m.end())
        # the uses clause must come before the first declaration after "implementation"
        d = re.compile(r'^\s*(procedure|function|type|var|const|label|begin)\b', re.I | re.M).search(text, m.end())
        if u and (not d or u.start() < d.start()):
            semi = text.index(';', u.end())
            return text[:semi] + ', VPSysLow' + text[semi:]
        return text[:m.end()] + '\n\nuses\n  VPSysLow;\n' + text[m.end():]
    u = re.compile(r'^[ \t]*uses\b', re.I | re.M).search(text)
    if u:
        semi = text.index(';', u.end())
        return text[:semi] + ', VPSysLow' + text[semi:]
    return text


def main():
    for f in sys.argv[1:]:
        name = f.rsplit('/', 1)[-1].lower()
        if name in OURS:
            continue
        raw = open(f, 'rb').read()
        text = raw.decode('latin-1')
        new, n = fix(text)
        # GetDir of the start directory (lfn.pas): the DOS form of the name
        new2 = re.sub(r'(?<![\w.])GetDir\(0, StartDir\)', 'SysGetDirDos(0, StartDir)', new)
        if new2 != new:
            n += 1
        new = new2
        if n:
            if not re.search(r'\bVPSysLow\b', new, re.I):
                new = add_uses(new)
            open(f, 'wb').write(new.encode('latin-1'))
            print('%s: %d' % (name, n))


main()
