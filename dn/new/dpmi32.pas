{ Dpmi32: calling real-mode interrupts from a 32-bit DPMI program (our unit; the VP one is not available).
  DN (lfnvp.pas) uses it to reach the DOS functions of the long file names (INT 21h AX=71xxh) and the
  clipboard (INT 2Fh). The names of the types and the routines are those of the VP unit, as DN uses them;
  the implementation lies on the go32 unit of the Free Pascal RTL (go32v2 only: on other targets the calls
  fail with the carry flag set, so that the units that use it still compile and can be tested).

  The buffer for the data of a call is the transfer buffer of the RTL, below 1 MB: segdossyslow16 is its
  real-mode segment, segdossyslow32 its linear address. Memory below 1 MB is not in the data segment, so
  DN reads and writes it by MemGet/MemPut (dn/edits/30-dpmi32-mem.py replaces the VP style Mem[] and Ptr()
  in the DN sources). }
{$mode objfpc}{$H-}
unit Dpmi32;

interface

uses VPSysLow;

const
  fCarry = 1;                      { the carry flag in flags_ }

type
  { Registers of a real-mode call, in the layout of TRealRegs of go32 (50 bytes). }
  real_mode_call_structure_typ = packed record
    case Integer of
      0: (di_, di_hi, si_, si_hi, bp_, bp_hi: Word; reserved_: LongWord;
          bx_, bx_hi, dx_, dx_hi, cx_, cx_hi, ax_, ax_hi: Word;
          flags_, es_, ds_, fs_, gs_, ip_, cs_, sp_, ss_: Word);
      1: (pad_: array[0..15] of Byte;
          bl_, bh_: Byte; padb_: Word; dl_, dh_: Byte; padd_: Word;
          cl_, ch_: Byte; padc_: Word; al_, ah_: Byte);
  end;

{ Zero the registers (the stack is given by the host: ss:sp = 0). }
procedure init_register(var Regs: real_mode_call_structure_typ);
{ Call INT IntNo in real mode; flags_ and the registers are returned in Regs. }
procedure intr_realmode(var Regs: real_mode_call_structure_typ; IntNo: Byte);

{ The buffer below 1 MB: the real-mode segment (offset 0) and the linear address. }
function segdossyslow16: Word;
function segdossyslow32: LongInt;
function SizeOfDosBuffer: LongInt;

{ Copy between the buffer (a linear address below 1 MB) and the memory of the program. }
procedure MemGet(Linear: LongInt; var Dest; Count: LongInt);
procedure MemPut(Linear: LongInt; const Src; Count: LongInt);
procedure MemFill(Linear: LongInt; Count: LongInt; Value: Byte);
{ The zero-terminated string at the linear address (at most 255 characters). }
function MemStr(Linear: LongInt): String;

{ A block of memory below 1 MB for the data of real-mode calls: Seg is its real-mode segment (the offset is 0).
  The program does not see that memory: DosShadow gives a block of the program that is copied to the DOS
  block before and from it after every intr_realmode (so code written for a flat memory works as it is). }
procedure getdosmem(var Seg: SmallWord; Size: LongInt);
function dosseg_linear(Seg: SmallWord): LongInt;
function DosShadow(Seg: SmallWord): Pointer;

implementation

{$IFDEF GO32V2}
uses
  go32;
{$ENDIF}

type
  TShadow = record
    Seg: SmallWord;
    Size: LongInt;
    Mem: Pointer;
  end;

var
  Shadows: array[1..8] of TShadow;
  ShadowCount: Integer = 0;

procedure init_register(var Regs: real_mode_call_structure_typ);
begin
  FillChar(Regs, SizeOf(Regs), 0);
end;

procedure intr_realmode(var Regs: real_mode_call_structure_typ; IntNo: Byte);
{$IFDEF GO32V2}
var
  R: TRealRegs absolute Regs;
  I: Integer;
begin
  for I := 1 to ShadowCount do
    dosmemput(Shadows[I].Seg, 0, Shadows[I].Mem^, Shadows[I].Size);
  realintr(IntNo, R);
  for I := 1 to ShadowCount do
    dosmemget(Shadows[I].Seg, 0, Shadows[I].Mem^, Shadows[I].Size);
end;
{$ELSE}
begin
  Regs.flags_ := Regs.flags_ or fCarry;       { not available: an error }
  Regs.ax_ := 1;
end;
{$ENDIF}

function segdossyslow16: Word;
begin
{$IFDEF GO32V2}
  Result := tb_segment;
{$ELSE}
  Result := 0;
{$ENDIF}
end;

function segdossyslow32: LongInt;
begin
{$IFDEF GO32V2}
  Result := transfer_buffer;
{$ELSE}
  Result := 0;
{$ENDIF}
end;

function SizeOfDosBuffer: LongInt;
begin
{$IFDEF GO32V2}
  Result := tb_size;
{$ELSE}
  Result := 0;
{$ENDIF}
end;

procedure MemGet(Linear: LongInt; var Dest; Count: LongInt);
begin
{$IFDEF GO32V2}
  dosmemget(Linear shr 4, Linear and 15, Dest, Count);
{$ELSE}
  FillChar(Dest, Count, 0);
{$ENDIF}
end;

procedure MemPut(Linear: LongInt; const Src; Count: LongInt);
begin
{$IFDEF GO32V2}
  dosmemput(Linear shr 4, Linear and 15, PByte(@Src)^, Count); { go32 declares Src as var }
{$ENDIF}
end;

procedure MemFill(Linear: LongInt; Count: LongInt; Value: Byte);
var
  Buf: array[0..1023] of Byte;
  N: LongInt;
begin
  FillChar(Buf, SizeOf(Buf), Value);
  while Count > 0 do
  begin
    N := Count;
    if N > SizeOf(Buf) then
      N := SizeOf(Buf);
    MemPut(Linear, Buf, N);
    Inc(Linear, N);
    Dec(Count, N);
  end;
end;

function MemStr(Linear: LongInt): String;
var
  Buf: array[0..255] of Char;
  I: Integer;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  MemGet(Linear, Buf, 255);
  I := 0;
  while (I < 255) and (Buf[I] <> #0) do
    Inc(I);
  SetLength(Result, I);
  Move(Buf, Result[1], I);
end;

procedure getdosmem(var Seg: SmallWord; Size: LongInt);
{$IFDEF GO32V2}
var
  R: LongInt;
begin
  R := global_dos_alloc(Size);
  Seg := SmallWord(R and $FFFF);
end;
{$ELSE}
begin
  Seg := 0;
end;
{$ENDIF}

function dosseg_linear(Seg: SmallWord): LongInt;
begin
  Result := LongInt(Seg) shl 4;
end;

function DosShadow(Seg: SmallWord): Pointer;
var
  I: Integer;
begin
  for I := 1 to ShadowCount do
    if Shadows[I].Seg = Seg then
      Exit(Shadows[I].Mem);
  Result := nil;
  if ShadowCount < High(Shadows) then
  begin
    Inc(ShadowCount);
    Shadows[ShadowCount].Seg := Seg;
    Shadows[ShadowCount].Size := 1024;
    GetMem(Shadows[ShadowCount].Mem, 1024);
    FillChar(Shadows[ShadowCount].Mem^, 1024, 0);
    Result := Shadows[ShadowCount].Mem;
  end;
end;

end.
