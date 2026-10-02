#!/usr/bin/env python3
"""Lists the `asm` blocks (and routines with `assembler;`) of Pascal sources that are not inside comments or strings: what a 64-bit build
(no assembler of 32-bit Intel) still has to replace. usage: tools/asm-blocks.py DIR  (the .pas files of a tree)"""
import os, re, sys

TOK = re.compile(r"\(\*.*?\*\)|\{[^}]*\}|//[^\r\n]*|'[^'\r\n]*'", re.S)
total = 0
for f in sorted(os.listdir(sys.argv[1])):
    if not f.lower().endswith('.pas') or f.startswith('_'):
        continue
    text = open(os.path.join(sys.argv[1], f), 'rb').read().decode('latin-1')
    clean = TOK.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text)
    for m in re.finditer(r'\b(asm|assembler)\b', clean, re.I):
        line = clean.count('\n', 0, m.start()) + 1
        print('%s:%d: %s' % (f, line, m.group(1)))
        total += 1
print('total', total)
