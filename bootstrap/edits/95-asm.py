#!/usr/bin/env python3
"""reason: (d) the modern compiler, (g) the target. The routines of the assembler of Virtual Pascal (`assembler;` with
{$USES}/{&Frame-}, parameters by name, @Result) do not run in FPC: it does not save the registers (EBX, ESI, EDI) that VP
saved and does not build the frame the same way; the first run of the program in DOSBox-X died of that. The routines are
written in Pascal (they are small: strings, checksums, bytes), the calls of DN loader/Windows 9x/DOS (INT 2Fh, INT 21h) go
away or become calls of VPSysLow. Each replacement is the behaviour of the assembler text (a quirk of the original is kept
and noted). Routines in the assembler that were not met yet stay: compile errors show them.
usage: 95-asm.py FILE...   (all the .pas of the tree)"""
import re, sys, os

def routine(header_re, new):
    return ('routine', re.compile(header_re, re.I), new)

# ---- whole routines (the header up to the `end;` that closes the asm) -------------------------------------------
ROUTINES = {
 'advance.pas': [
  ('procedure FillWord(var B; Count, W: Word);', '''procedure FillWord(var B; Count, W: Word);
  var
    I: Integer;
    P: PWord;
  begin
  P := @B;
  for I := 1 to Count do
    begin
    P^ := W;
    Inc(P);
    end;
  end;'''),
 ],
 'advance1.pas': [
  ('function AddSpace(const s: String; n: Byte): String;', '''function AddSpace(const s: String; n: Byte): String;
  begin
  Result := s;
  while Length(Result) < n do
    Result := Result+' ';
  end;'''),
  ('procedure DelSpace(var s: String);', '''procedure DelSpace(var s: String);
  var
    I, J: Integer;
  begin
  J := 0;
  for I := 1 to Length(s) do
    if (s[I] <> ' ') and (s[I] <> #9) then
      begin
      Inc(J);
      s[J] := s[I];
      end;
  SetLength(s, J);
  end;'''),
  ('procedure DelRight(var S: String);', '''procedure DelRight(var S: String);
  var
    L: Integer;
  begin
  L := Length(S);
  while (L > 0) and ((S[L] = ' ') or (S[L] = #9)) do
    Dec(L);
  SetLength(S, L);
  end;'''),
  ('procedure DelLeft(var S: String);', '''procedure DelLeft(var S: String);
  var
    I: Integer;
  begin
  I := 1;
  while (I <= Length(S)) and ((S[I] = ' ') or (S[I] = #9)) do
    Inc(I);
  if I > 1 then
    Delete(S, 1, I-1);
  end;'''),
  ('function HexChar(a: Byte): Char;', '''function HexChar(a: Byte): Char;
  begin
  a := a and $0F;
  if a < 10 then
    HexChar := Chr(48+a)
  else
    HexChar := Chr(55+a);
  end;'''),
  ('function PosChar(C: Char; const S: String): Byte;', '''function PosChar(C: Char; const S: String): Byte;
  var
    I: Integer;
  begin
  PosChar := 0;
  for I := 1 to Length(S) do
    if S[I] = C then
      begin
      PosChar := I;
      Exit;
      end;
  end;'''),
  # copies the length byte and the characters (to a place declared shorter: see TFileRec)
  ('procedure CopyShortString(const s1, s2: ShortString);', '''procedure CopyShortString(const s1, s2: ShortString);
  begin
  Move(PByte(@s1)^, PByte(@s2)^, PByte(@s1)^+1);
  end;'''),
  # the original does not look at the first character of the string (kept)
  ('function CharCount(C: Char; const S: String): Byte; {DataCompBoy}', '''function CharCount(C: Char; const S: String): Byte; {DataCompBoy}
  var
    I: Integer;
  begin
  Result := 0;
  for I := 2 to Length(S) do   { sic: the first character is not counted, as in the assembler text of DN }
    if S[I] = C then
      Inc(Result);
  end;'''),
 ],
 'advance1.pas#': [],
 'advance3.pas': [
  ('function Chk4Dos: Boolean;', '''function Chk4Dos: Boolean;
  begin
  Result := False;   { INT 2Fh AX=D44Dh: the loader of DN (DN.COM) is not there }
  end;'''),
 ],
 'dn1.pas': [
  ('procedure CrLf;', '''procedure CrLf;
  begin
  Writeln;
  end;'''),
 ],
 'dnutil.pas': [
  ('procedure w95QuitInit;', '''procedure w95QuitInit;
  begin
  w95QuitEnabled := 0;   { the close button of the DOS box of Windows 9x (INT 2Fh AX=168Fh): not handled here }
  end;'''),
  ('function w95QuitCheck: Boolean;', '''function w95QuitCheck: Boolean;
  begin
  Result := False;
  end;'''),
 ],
 'u_keymap.pas': [
  ('procedure XLatBuf(var B; Len: Integer; const XTable: TXLat);', '''procedure XLatBuf(var B; Len: Integer; const XTable: TXLat);
  var
    I: Integer;
    P: PByte;
  begin
  P := @B;
  for I := 1 to Len do
    begin
    P^ := Byte(XTable[Char(P^)]);
    Inc(P);
    end;
  end;'''),
 ],
 'uucode.pas': [
  ('procedure CalcBufCRC(var Buf; Size: LongInt; var PrevSum: Word);', '''procedure CalcBufCRC(var Buf; Size: LongInt; var PrevSum: Word);
    var
      I: LongInt;
      P: PByte;
      Sum: Word;
    begin
    Sum := PrevSum;
    P := @Buf;
    for I := 1 to Size do
      begin
      Sum := Word((Sum shr 1) or (Sum shl 15))+P^;
      Inc(P);
      end;
    PrevSum := Sum;
    end;'''),
  ('procedure CalcLnCRC(var Strng: String; var CRC: Word);', '''procedure CalcLnCRC(var Strng: String; var CRC: Word);
      var
        I: Integer;
        Sum: Word;
      begin
      if Length(Strng) = 0 then
        Exit;
      Sum := CRC;
      for I := 1 to Length(Strng) do
        Sum := Word((Sum shr 1) or (Sum shl 15))+Byte(Strng[I]);
      CRC := Word((Sum shr 10) or (Sum shl 6));
      end;'''),
  ('function MemEqu(var A, B; Size: LongInt): Boolean;', '''function MemEqu(var A, B; Size: LongInt): Boolean;
    begin
    Result := (Size <= 0) or (CompareByte(A, B, Size) = 0);
    end;'''),
  ('function GetDecimal(Number: Word): String;', '''function GetDecimal(Number: Word): String;
        begin
        Result := Chr(48+Number div 10)+Chr(48+Number mod 10);
        end;'''),
  ('procedure DecodeStr(var Src, Dst);', '''procedure DecodeStr(var Src, Dst);
    var
      S: PByte;
      D: PByte;
      I: Integer;
      C1, C2, C3, C4: Byte;
    begin
    S := @Src;
    D := @Dst;
    for I := 1 to 15 do
      begin
      C1 := S[0]; C2 := S[1]; C3 := S[2]; C4 := S[3];
      D[0] := Byte(C1 shl 2) or (C2 shr 4);
      D[1] := (C3 shr 2) or Byte(C2 shl 4);
      D[2] := Byte(C3 shl 6) or C4;
      Inc(S, 4);
      Inc(D, 3);
      end;
    end;'''),
  ('function UUString(var s: String; var CRC: Word): Boolean;', '''function UUString(var s: String; var CRC: Word): Boolean;
    var
      Sum: Word;
      C: Byte;
      L: Integer;
    begin
    { the assembler text: only the first character (the length of the line) is checked and translated and goes into the
      sum; the rest of the string is looked at for a zero and the tail of 70 bytes after the string is cleared }
    L := Length(s);
    if L < 185 then
      FillChar(s[L+1], 70, 0);
    C := Byte(s[1]);
    Sum := Word((CRC shr 1) or (CRC shl 15))+C;
    if (C < Ord('!')) or (C > Ord('`')) then
      begin
      Result := False;
      Exit;
      end;
    s[1] := Chr((C-32) and $3F);
    CRC := Word((Sum shr 10) or (Sum shl 6));
    Result := True;
    end;'''),
 ],
}

def replace_routine(text, header, new):
    """From the header line (the one of the implementation: the asm follows it at once) to the line `end;` that ends the asm."""
    for m in re.finditer(r'^[ \t]*' + re.escape(header) + r'[ \t]*\r?\n', text, re.M | re.I):
        asm = re.search(r'^[ \t]*asm\b', text[m.end():], re.M | re.I)
        if not asm:
            continue
        between = text[m.end():m.end() + asm.start()]
        if re.search(r'\b(begin|procedure|function)\b', re.sub(r'\{[^}]*\}|\(\*.*?\*\)|//[^\n]*', ' ', between, flags=re.S), re.I):
            continue
        end = re.search(r'^[ \t]*end\b[^\r\n]*\r?\n', text[m.end() + asm.start():], re.M | re.I)
        tail = m.end() + asm.start() + end.end()
        nl = '\r\n' if '\r\n' in text else '\n'
        return text[:m.start()] + new.replace('\n', nl) + nl + text[tail:], True
    return text, False

# ---- blocks (an asm statement inside a routine) ----------------------------------------------------------------
BLOCKS = {
 'advance.pas': [('mov   AX, 4010h', "opSys := opSys or opDos;   { DOS: no probing of OS/2, Windows, DESQview here (TODO) }")],
 'advance.pas#2': [('mov ax,$1680', "VPSysLow.SysCtrlSleep(0);   { the idle of DPMI (INT 2Fh AX=1680h) of VP }")],
 'advance2.pas': [('rep  cmpsb', "if CompareByte(B1^, B2^, I) <> 0 then\n        begin\n        CompareFiles := False;\n        B := True;\n        end;")],
 'dbview.pas': [('mov ax, word ptr ML', "ML := LongInt(SwapEndian(LongWord(ML)));")],
 'dnexec.pas': [('mov ax, 9904h', "{ the loader of DN (DN.COM, INT 2Fh AX=99xxh) is not used: nothing to tell it }")],
 'eraser.pas': [('mov ah, 0dh', "VPSysLow.SysDiskReset;")],
 'fbb.pas': [('mov ah,0dh', "VPSysLow.SysDiskReset;")],
 'filecopy.pas': [('mov ah,0dh', "VPSysLow.SysDiskReset;")],
 'flpanelx.pas': [('mov eax,Command', "if Command = cmIntEditFile then\n      Command := cmIntFileEdit\n    else if Command = cmIntViewFile then\n      Command := cmIntFileView\n    else if Command = cmEditFile then\n      Command := cmFileEdit\n    else if Command = cmFileTextView then\n      Command := cmViewText\n    else\n      Command := cmFileView;")],
 'tetris.pas': [('lea ebx, B', "VPUtils.XorScramble(B, %s);")],
 'dnutil.pas': [('mov ax, 168Fh', "{ the close button of the DOS box of Windows 9x (INT 2Fh AX=168Fh): not handled here }")],
}

def replace_block(text, key, new):
    """The first asm ... end; whose text contains key."""
    for m in re.finditer(r'^([ \t]*)asm\b.*?^[ \t]*end\b[^\r\n]*\r?\n', text, re.M | re.S | re.I):
        if key.lower() in m.group(0).lower():
            nl = '\r\n' if '\r\n' in text else '\n'
            ind = m.group(1)
            return text[:m.start()] + ind + new.replace('\n', nl + ind) + nl + text[m.end():], True
    return text, False

COMPRESS = '''procedure CompressShortStr(var S: String);
  var
    TSt, I, N, Cnt, Spaces: Integer;
    Out: String;
    C: Char;
  begin
  TSt := StoI(EditorDefaults.TabSize);
  if TSt = 0 then
    TSt := 8;
  N := Length(S);
  Out := '';
  I := 1;
  while I <= N do
    begin
    Cnt := 0;
    Spaces := 0;
    while (Cnt < TSt) and (I <= N) do
      begin
      C := S[I];
      Inc(I);
      Out := Out+C;
      Inc(Cnt);
      if C = ' ' then
        Inc(Spaces)
      else
        Spaces := 0;
      end;
    if Cnt < TSt then
      Break;
    if Spaces > 1 then   { the spaces up to the tab stop become a tab }
      begin
      SetLength(Out, Length(Out)-Spaces);
      Out := Out+#9;
      end;
    end;
  S := Out;
  end { CompressShortStr };
'''
XDUMP = '''procedure XDumpStr(var S: String; var B; Addr: Int64; Count: Integer;
     Filter: Byte);
  var
    I: Integer;
    P: PByte;
    C: Byte;
  begin
  S := HexFilePos(Addr)+' ';
  P := @B;
  for I := 1 to Count do
    begin
    C := P^;
    Inc(P);
    if Filter <> 0 then
      if (C < 32) or ((Filter = 1) and (C >= 128)) then
        C := 250;
    S := S+Chr(C);
    end;
  end { XDumpStr };
'''

def replace_whole(text, header_re, end_re, new):
    m = re.search(header_re, text, re.M | re.I)
    if not m:
        return text, False
    e = re.search(end_re, text[m.end():], re.M | re.I)
    if not e:
        return text, False
    nl = '\r\n' if '\r\n' in text else '\n'
    return text[:m.start()] + new.replace('\n', nl) + text[m.end() + e.end():], True

SETUPS = re.compile(r'function TMouseBar\.DataSize: Integer;\s*assembler;\s*asm mov eax,4 end;', re.I)

n = 0
for p in sys.argv[1:]:
    b = os.path.basename(p).lower()
    if b not in ROUTINES and b not in BLOCKS and b not in ('advance1.pas', 'u_keymap.pas', 'fviewer.pas', 'setups.pas'):
        continue
    raw = open(p, 'rb').read().decode('latin-1')
    s = raw
    if b == 'advance1.pas':
        s, ok = replace_whole(s, r'^procedure CompressShortStr\(var S: String\);[^\n]*\n', r'^[ \t]*end \{ CompressShortStr \};[ \t]*\r?\n', COMPRESS)
        n += ok
        if not ok:
            print('95-asm: advance1.pas: NOT replaced: CompressShortStr')
    if b == 'fviewer.pas':
        s, ok = replace_whole(s, r'^procedure XDumpStr\(var S: String; var B; Addr: Int64; Count: Integer;[^\n]*\n[^\n]*\n', r'^[ \t]*end \{ XDumpStr \};[ \t]*\r?\n', XDUMP)
        n += ok
        if not ok:
            print('95-asm: fviewer.pas: NOT replaced: XDumpStr')
    for header, new in ROUTINES.get(b, []):
        s, ok = replace_routine(s, header, new)
        n += ok
        if not ok:
            print('95-asm: %s: NOT replaced: %s' % (b, header))
    for key, new in BLOCKS.get(b, []) + BLOCKS.get(b + '#2', []):
        if b == 'tetris.pas':
            # two blocks, the counters are I and J
            for var in ('I', 'J'):
                s, ok = replace_block(s, key, new % var)
                n += ok
        else:
            s, ok = replace_block(s, key, new)
            n += ok
            if not ok:
                print('95-asm: %s: NOT replaced: block %s' % (b, key))
    if b == 'setups.pas':
        s, k = SETUPS.subn('function TMouseBar.DataSize: Integer;\r\n  begin\r\n  Result := 4;\r\n  end;', s)
        n += k
    if s != raw:
        open(p, 'wb').write(s.encode('latin-1'))
print('95-asm: %d replacements' % n)
