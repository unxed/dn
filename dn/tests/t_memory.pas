{ Tests of dn/new/memory.pas }
{$mode objfpc}{$H-}
program t_memory;
uses Memory;
{$I dntest.inc}
var
  P, Q: Pointer;
begin
  Check(not LowMemory, 'there is no low memory in the flat model');
  P := MemAlloc(100);
  Check(P <> nil, 'MemAlloc gives memory');
  FillChar(P^, 100, 7);
  Check(PByte(P)[99] = 7, 'the memory can be written');
  FreeMem(P);
  Q := nil;
  NewCache(Q, 4096);
  Check(Q <> nil, 'NewCache gives a buffer');
  DisposeCache(Q);
  DisposeCache(nil);
  InitMemory; InitDOSMem; DoneDOSMem; DoneMemory;
  Finish;
end.
