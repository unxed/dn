{ Memory: the memory manager API that DN calls (our unit; it replaces memory.pas of the archive).
  In the flat memory of a 32-bit program there is no low memory and no safety pool: allocation that fails
  raises an exception of the RTL, so LowMemory is False. The routines of the real-mode heap do nothing. }
{$mode objfpc}{$H-}
unit Memory;

interface

const
  { the sizes of the old model (in paragraphs); DN reads them to size buffers }
  LowMemSize = 4096;
  MaxBufMem = 65536 div 16;
  MaxHeapSize = 655360 div 16;

{ Memory for a buffer; nil when there is none. }
function MemAlloc(Size: Word): Pointer;
function MemAllocSeg(Size: Word): Pointer;
function LowMemory: Boolean;
{ A cache buffer: P is nil if there is no memory. }
procedure DisposeCache(P: Pointer);
procedure NewCache(var P: Pointer; Size: Word);
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

function MemAlloc(Size: Word): Pointer;
begin
  try
    GetMem(Result, Size);
  except
    Result := nil;
  end;
end;

function MemAllocSeg(Size: Word): Pointer;
begin
  Result := MemAlloc(Size);
end;

procedure NewCache(var P: Pointer; Size: Word);
begin
  P := MemAlloc(Size);
end;

procedure DisposeCache(P: Pointer);
begin
  if P <> nil then
    FreeMem(P);
end;

end.
