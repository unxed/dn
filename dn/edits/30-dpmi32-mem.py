#!/usr/bin/env python3
"""Replaces the VP style access to the memory below 1 MB in lfnvp.pas (Mem[linear], Ptr(linear)) by
MemGet/MemPut of our Dpmi32: the memory below 1 MB is not in the data segment under go32v2.
usage: 30-dpmi32-mem.py FILE... (all the .pas of the tree; only lfnvp.pas is changed)"""
import re, sys, os

found = [a for a in sys.argv[1:] if os.path.basename(a).lower() == 'lfnvp.pas']
if not found:
    sys.exit(0)
p = found[0]
s = open(p, encoding='latin-1').read()

n0 = s.count('Mem[')
# Move(Src, Mem[Lin], N);  ->  MemPut(Lin, Src, N);
s = re.sub(r'Move\(\s*([^,\n]+?)\s*,\s*Mem\[([^\]\n]+)\]\s*,\s*([^;\n]+?)\s*\);', r'MemPut(\2, \1, \3);', s)
# Move(Mem[Lin], Dest, N);  ->  MemGet(Lin, Dest, N);
s = re.sub(r'Move\(\s*Mem\[([^\]\n]+)\]\s*,\s*([^,\n]+?)\s*,\s*([^;\n]+?)\s*\);', r'MemGet(\1, \2, \3);', s)
if 'Mem[' in s:
    sys.exit('30-dpmi32-mem: Mem[ left in lfnvp.pas (%d of %d)' % (s.count('Mem['), n0))

# FindData lies in the buffer below 1 MB: use a copy in the program
s = s.replace('FindData:=Ptr(segdossyslow32);', 'FindData:=@FDBuf;')
s = s.replace('NameToNameZ(Path, FindData^.FullName);',
              'NameToNameZ(Path, FindData^.FullName);\n  MemPut(segdossyslow32, FindData^.FullName, SizeOf(FindData^.FullName));')
s = s.replace('FindDataToSearchRec(FindData^, R);',
              'MemGet(segdossyslow32, FindData^, SizeOf(lFindDataRec));\n      FindDataToSearchRec(FindData^, R);')
i = s.rfind('procedure lWIN95FindFirst(')       # the implementation, not the declaration in interface
s = s[:i] + 'var\n  FDBuf: lFindDataRec;\n\n' + s[i:]
if 'Ptr(segdossyslow32)' in s:
    sys.exit('30-dpmi32-mem: Ptr(segdossyslow32) left')
open(p, 'w', encoding='latin-1').write(s)
print('30-dpmi32-mem: %d Mem[] accesses replaced' % n0)
