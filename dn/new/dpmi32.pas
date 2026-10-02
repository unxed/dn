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

implementation

{$IFDEF GO32V2}
uses go32;
{$ENDIF}

procedure init_register(var Regs: real_mode_call_structure_typ);
begin
  FillChar(Regs, SizeOf(Regs), 0);
end;

procedure intr_realmode(var Regs: real_mode_call_structure_typ; IntNo: Byte);
{$IFDEF GO32V2}
var
  R: TRealRegs absolute Regs;
begin
  realintr(IntNo, R);
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
  dosmemput(Linear shr 4, Linear and 15, Src, Count);
{$ENDIF}
end;

end.
