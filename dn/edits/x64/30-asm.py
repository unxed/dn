#!/usr/bin/env python3
"""reason: the 64-bit build. The assembler of DN is Intel with 32-bit registers: it cannot run on x86_64. With NOASM (dn/target-linux-x64.env) the
Pascal versions of the authors are taken; these routines have no such version and are written here in Pascal, with the same behaviour.
usage: 30-asm.py FILE...   (the .pas of the tree)"""
import re
import sys

ASM_END = r'\s*end;?'

REPL = {
    'dbview.pas': [
        # the memo block size is big-endian: the bytes of the long are reversed
        (r'asm\s+mov ax, word ptr ML\s+mov bx, word ptr ML\+2\s+xchg al, ah\s+xchg bl, bh\s+mov word ptr ML, bx\s+mov word ptr ML\+2, ax\s+end;',
         'ML := LongInt(SwapEndian(LongWord(ML)));'),
    ],
    'filecopy.pas': [
        # INT 21h AH=0Dh: the disk buffers go to the disks
        (r'asm\s+mov ah,0dh\s+int 21h\s+end;', 'SysDiskReset;'),
    ],
    'uucode.pas': [
        # the quotient; one more if it does not fit in a word (the high word is not zero)
        (r'function SmartDiv\(L: LongInt; W: LongInt\): LongInt;\s+assembler;\s+\{&USES None\} \{&FRAME-\}\s+asm\s+mov\s+eax,L\s+xor\s+edx,edx\s+div\s+W\s+mov\s+edx,eax\s+and\s+edx,\$FFFF0000\s+jz\s+@@Exit\s+inc\s+eax\s*@@Exit:\s+end;',
         'function SmartDiv(L: LongInt; W: LongInt): LongInt;\n  begin\n  Result := LongInt(LongWord(L) div LongWord(W));\n  if (Result and LongInt($FFFF0000)) <> 0 then\n    Inc(Result);\n  end;'),
        # the quotient rounded up
        (r'function SmartDiv\(L: LongInt; W: LongInt\): LongInt;\s+assembler;\s+\{&USES None\} \{&FRAME-\}\s+asm\s+mov\s+eax,L\s+xor\s+edx,edx\s+div\s+W\s+or\s+edx,edx\s+jz\s+@@Exit\s+inc\s+eax\s*@@Exit:\s+end;',
         'function SmartDiv(L: LongInt; W: LongInt): LongInt;\n  begin\n  Result := LongInt(LongWord(L) div LongWord(W));\n  if LongWord(L) mod LongWord(W) <> 0 then\n    Inc(Result);\n  end;'),
    ],
}

for f in sys.argv[1:]:
    name = f.rsplit('/', 1)[-1].lower()
    if name not in REPL:
        continue
    text = open(f, 'rb').read().decode('latin-1')
    n = 0
    for pat, new in REPL[name]:
        text, k = re.subn(pat, new.replace('\\', '\\\\'), text, flags=re.I)
        n += k
    if n:
        open(f, 'wb').write(text.encode('latin-1'))
        print('%s: %d' % (name, n))
