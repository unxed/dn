#!/usr/bin/env python3
"""The class migration gate of DN: the old Pascal `object` dialect must be absent from the tracked Pascal sources.

Blocking: the keyword `object` in the code of a tracked Pascal file (.pas .pp .inc .dpr .lpr), i.e. `T = object(TView)`,
`packed object`; comments, string literals, other words (TFindObject, ExceptObject) and non-Pascal files are not looked at.
Not blocking (printed as a count): the old construction idioms `New(T, Init(...))`, `Dispose(P, Done)`;
CLASS_GATE_STRICT=1 makes them blocking. CLASS_GATE_EXCLUDE optionally lists path prefixes separated by ':'; the default
is empty so every tracked Pascal source, including bootstrap inputs, is checked.
usage: tools/class-gate.py [ROOT]     exit: 0 pass, 1 found, 2 the scan could not be done"""
import os
import re
import subprocess
import sys

EXT = ('.pas', '.pp', '.inc', '.dpr', '.lpr')
KEYWORD = re.compile(r'\bobject\b', re.I)
IDIOMS = {
    'New(T, Init(...))': re.compile(r'\bNew\s*\(\s*\w+\s*,\s*\w+\s*\(', re.I),
    'Dispose(P, Done)': re.compile(r'\bDispose\s*\(\s*\w+\s*,\s*Done\s*\)', re.I),
}
SHOW = 40


def code_only(src):
    """src without comments and string literals; the line structure is kept."""
    out, i, n = [], 0, len(src)
    while i < n:
        c, two = src[i], src[i:i + 2]
        if c == "'":                                   # a string: '' inside is an escaped quote
            j = i + 1
            while j < n and src[j] != '\n' and not (src[j] == "'" and src[j + 1:j + 2] != "'"):
                j += 2 if src[j] == "'" else 1
            out.append(' ')
            i = j + 1
        elif c == '{' or two == '(*':
            end = src.find('}' if c == '{' else '*)', i + (1 if c == '{' else 2))
            end = n if end < 0 else end + (1 if c == '{' else 2)
            out.append(''.join('\n' if x == '\n' else ' ' for x in src[i:end]))
            i = end
        elif two == '//':
            end = src.find('\n', i)
            i = n if end < 0 else end
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def scan(root, exclude, strict):
    r = subprocess.run(['git', '-C', root, 'ls-files', '-z'], capture_output=True)
    if r.returncode != 0:
        raise RuntimeError('git ls-files failed: ' + r.stderr.decode(errors='replace').strip())
    found, idioms, files = [], {k: [0, set()] for k in IDIOMS}, 0
    for rel in r.stdout.decode('utf-8', 'replace').split('\0'):
        if not rel or not rel.lower().endswith(EXT) or any(rel.startswith(p) for p in exclude):
            continue
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            continue
        files += 1
        raw = open(path, 'rb').read().decode('latin-1')
        code = code_only(raw)
        lines = raw.split('\n')
        for m in KEYWORD.finditer(code):
            ln = code.count('\n', 0, m.start())
            found.append('%s:%d: %s' % (rel, ln + 1, lines[ln].strip()[:100]))
        for k, rx in IDIOMS.items():
            for m in rx.finditer(code):
                idioms[k][0] += 1
                idioms[k][1].add(rel)
                if strict:
                    ln = code.count('\n', 0, m.start())
                    found.append('%s:%d: [%s] %s' % (rel, ln + 1, k, lines[ln].strip()[:100]))
    return found, idioms, files


def main():
    root = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    exclude = [p for p in os.environ.get('CLASS_GATE_EXCLUDE', '').split(':') if p]
    strict = os.environ.get('CLASS_GATE_STRICT', '') not in ('', '0')
    try:
        found, idioms, files = scan(root, exclude, strict)
    except (OSError, RuntimeError) as e:
        print('CLASS GATE FAIL: the scan could not be done: %s' % e, file=sys.stderr)
        return 2
    for k, (n, fs) in idioms.items():
        if n and not strict:
            print('note: %s: %d in %d files (not blocking; CLASS_GATE_STRICT=1 blocks)' % (k, n, len(fs)))
    if found:
        print('\n'.join(found[:SHOW]))
        if len(found) > SHOW:
            print('... and %d more' % (len(found) - SHOW))
        print('CLASS GATE FAIL: the old object dialect is still present (%d)' % len(found), file=sys.stderr)
        return 1
    print('dn class gate: PASS (%d Pascal files; not scanned: %s)' % (files, ' '.join(exclude) or 'none'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
