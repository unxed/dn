{ Memory: the memory manager API that DN calls (our unit; it replaces memory.pas of the archive).
  In the flat memory of a 32-bit program there is no low memory and no safety pool: allocation that fails
  raises an exception of the RTL, so LowMemory is False. The routines of the real-mode heap do nothing. }
{$mode objfpc}{$H-}
unit Memory;

interface

const
  { the sizes of the old model (in paragraphs); DN reads them to size buffers }
  LowMemSize = 4096;

{ Memory for a buffer; nil when there is none. The size is a LongInt: in Virtual Pascal Word is 32 bits, DN asks for buffers of megabytes (a Word here made a
  buffer of the size modulo 64K that the copy then overran). }
function MemAlloc(Size: LongInt): Pointer;
function LowMemory: Boolean;
{ A cache buffer: P is nil if there is no memory. }
procedure DisposeCache(P: Pointer);
procedure NewCache(var P: Pointer; Size: LongInt);
procedure DoneDOSMem;
procedure DoneMemory;
procedure InitDOSMem;
procedure InitMemory;

implementation

procedure InitMemory;
begin
end;

procedure DoneMemory;
begin
end;

procedure InitDOSMem;
begin
end;

procedure DoneDOSMem;
begin
end;

function LowMemory: Boolean;
begin
  Result := False;
end;

function MemAlloc(Size: LongInt): Pointer;
begin
  try
    GetMem(Result, Size);
  except
    Result := nil;
  end;
end;

procedure NewCache(var P: Pointer; Size: LongInt);
begin
  P := MemAlloc(Size);
end;

procedure DisposeCache(P: Pointer);
begin
  if P <> nil then
    FreeMem(P);
end;

end.
