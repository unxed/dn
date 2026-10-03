procedure Beep(Freq, Dur: LongInt);
begin
  SysBeepEx(Freq, Dur);
end;

function MemAvail: LongInt;
begin
  Result := GetFPCHeapStatus.CurrHeapFree;
end;

function MaxAvail: LongInt;
begin
  Result := GetFPCHeapStatus.CurrHeapFree;      { the free memory is one piece for our purposes }
end;
