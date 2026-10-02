#!/usr/bin/env python3
"""reason: (д) the modern compiler, DOS target. Virtual Pascal sees the memory below 1 MB as a flat array
Mem[linear] and gives pointers to it; under go32v2 that memory is not in the data segment. In lfnvp.pas and
fltl.pas the VP style access (Mem[linear], Ptr(linear)) is replaced by MemGet/MemPut/MemFill/MemStr of our
Dpmi32; in doslow.pas the pointer to the area of real-mode calls is a block of the program that Dpmi32
copies to the DOS memory and back around every intr_realmode (DosShadow).
usage: 30-dpmi32-mem.py FILE...   (all the .pas of the tree)"""
import re, sys, os

def convert_mem(s, name):
    n0 = len(re.findall(r'Mem\[', s, re.I))
    # Move(Src, Mem[Lin], N);  ->  MemPut(Lin, Src, N);
    s = re.sub(r'\bMove\(\s*([^,\n]+?)\s*,\s*Mem\[([^\]\n]+)\]\s*,\s*([^;\n]+?)\s*\);', r'MemPut(\2, \1, \3);', s, flags=re.I)
    # Move(Mem[Lin], Dest, N);  ->  MemGet(Lin, Dest, N);
    s = re.sub(r'\bMove\(\s*Mem\[([^\]\n]+)\]\s*,\s*([^,\n]+?)\s*,\s*([^;\n]+?)\s*\);', r'MemGet(\1, \2, \3);', s, flags=re.I)
    # FillChar(Mem[Lin], N, V);  ->  MemFill(Lin, N, Byte(V));  (also over two lines)
    s = re.sub(r'\bFillChar\(\s*Mem\[([^\]]+)\]\s*,\s*([^;]+?)\s*,\s*(#0|[^,;]+?)\s*\);',
               lambda m: 'MemFill(%s, %s, %s);' % (m.group(1), re.sub(r'\s+', ' ', m.group(2)),
                                                    '0' if m.group(3) == '#0' else 'Byte(%s)' % m.group(3)), s, flags=re.I)
    # StrPas(@Mem[Lin])  ->  MemStr(Lin)
    s = re.sub(r'\bStrPas\(\s*@Mem\[([^\]]+)\]\s*\)', r'MemStr(\1)', s, flags=re.I)
    code = re.sub(r'//[^\n]*|\{[^}]*\}|\(\*.*?\*\)', ' ', s, flags=re.S)
    left = len(re.findall(r'Mem\[', code, re.I))
    if left:
        sys.exit('30-dpmi32-mem: Mem[ left in %s (%d of %d)' % (name, left, n0))
    return s, n0

done = []
for p in sys.argv[1:]:
    b = os.path.basename(p).lower()
    if b not in ('lfnvp.pas', 'fltl.pas', 'doslow.pas'):
        continue
    s = open(p, encoding='latin-1').read()
    if b == 'doslow.pas':
        s = s.replace('Ptr(dosseg_linear(DosSeg))', 'DosShadow(DosSeg)')
        n = 1
    else:
        s, n = convert_mem(s, b)
    if b == 'lfnvp.pas':
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
    done.append('%s %d' % (b, n))
print('30-dpmi32-mem: ' + ', '.join(done))
