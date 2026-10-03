#!/usr/bin/env python3
"""Renames a unit of DN: the file (git mv, lower case), the line `unit OLD;`, the name in every `uses` clause and the qualified uses `OLD.Name` in all the Pascal
sources of dn/ (src, archives, compat, tests). The text is read and written as bytes (the sources are in CP866 and have CRLF or LF: nothing else is touched).
usage: tools/rename-unit.py OLD NEW      (from the root of the repository; then: tools/build.sh linux64, tools/dn-test.sh, the manifest)
Not touched (by hand): the words in comments, the documents, tools/, the maps of shims. Prints what it changed."""
import os, re, subprocess, sys

if len(sys.argv) != 3:
    sys.exit(__doc__)
old, new = sys.argv[1], sys.argv[2].lower()
if not re.fullmatch(r'[a-z][a-z0-9]*', new):
    sys.exit('the new name must be lower case letters and digits (words, not codes)')
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
dirs = ['src', 'archives', 'compat', os.path.join('compat', 'linux'), 'tests']
files = []
for d in dirs:
    p = os.path.join(root, 'dn', d)
    for f in sorted(os.listdir(p)):
        if os.path.isfile(os.path.join(p, f)) and f.lower().endswith(('.pas', '.inc')):
            files.append(os.path.join(p, f))
src = [f for f in files if os.path.basename(f).lower() == old.lower() + '.pas']
if not src:
    sys.exit('the unit %s: no file found' % old)
if any(os.path.basename(f).lower() == new + '.pas' for f in files):
    sys.exit('there is a file %s.pas already' % new)
srcs = src      # a unit can have a replacement for a platform (compat/linux/country_.pas): all of them are renamed
src = src[0]
word = re.compile(rb'\b' + old.encode().replace(b'_', b'_') + rb'\b', re.I)
uses = re.compile(rb'(\buses\b)(.*?;)', re.I | re.S)
qual = re.compile(rb'\b' + re.escape(old.encode()) + rb'\.(?=[A-Za-z_])', re.I)
newb = new.encode()
changed = {}
for f in files:
    data = open(f, 'rb').read()
    out = uses.sub(lambda m: m.group(1) + word.sub(newb, m.group(2)), data)
    out = qual.sub(newb + b'.', out)
    if f in srcs:
        out = re.sub(rb'(^|\n)(\s*unit\s+)' + re.escape(old.encode()) + rb'\s*;', lambda m: m.group(1) + m.group(2) + newb + b';', out, count=1, flags=re.I)
    if out != data:
        open(f, 'wb').write(out)
        changed[os.path.relpath(f, root)] = True
for one in srcs:
    subprocess.check_call(['git', 'mv', one, os.path.join(os.path.dirname(one), new + '.pas')], cwd=root)
dst = os.path.join(os.path.dirname(src), new + '.pas')
# the map new -> original name (dn/renames.map): the origin of a file (dn/PROVENANCE.md) and the old names for whoever reads the archive
mp = os.path.join(root, 'dn', 'renames.map')
pairs = {}
if os.path.exists(mp):
    for line in open(mp, encoding='utf-8'):
        if line.strip() and not line.startswith('#'):
            a, b = line.split()
            pairs[a] = b
orig = pairs.pop(os.path.basename(src).lower(), os.path.basename(src).lower())
pairs[new + '.pas'] = orig
with open(mp, 'w', encoding='utf-8') as fh:
    fh.write('# new name -> the name in the public archive of DN OSP 2.14 (written by tools/rename-unit.py, read by bootstrap/tools/dn-manifest.py)\n')
    for a in sorted(pairs):
        fh.write('%s %s\n' % (a, pairs[a]))
subprocess.check_call(['git', 'add', mp], cwd=root)
print('renamed %s -> %s; %d files changed: %s' % (os.path.relpath(src, root), os.path.relpath(dst, root), len(changed), ' '.join(sorted(changed))[:400]))
