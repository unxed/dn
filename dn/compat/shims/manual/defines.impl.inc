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

const
  { Room for the editor to rewrite the block (DOS env was a fixed PSP block). }
  EnvironmentCapacity = 65536;

procedure DoneEnvironment;
begin
  if Environment <> nil then
  begin
    FreeMem(Environment, EnvironmentSize);
    Environment := nil;
    EnvironmentSize := 0;
  end;
end;

procedure InitEnvironment;
var
  I, N, Need, Used: LongInt;
  S: AnsiString;
  P: PByte;
begin
  DoneEnvironment;
  Need := 2;
  N := GetEnvironmentVariableCount;
  for I := 1 to N do
    Inc(Need, Length(GetEnvironmentString(I)) + 1);
  if Need < EnvironmentCapacity then
    Need := EnvironmentCapacity;
  GetMem(Environment, Need);
  EnvironmentSize := Need;
  FillChar(Environment^, Need, 0);
  P := @Environment^[0];
  Used := 0;
  for I := 1 to N do
  begin
    S := GetEnvironmentString(I);
    if S = '' then
      Continue;
    if Used + Length(S) + 2 >= Need then
      Break;
    Move(S[1], P^, Length(S));
    Inc(P, Length(S));
    P^ := 0;
    Inc(P);
    Inc(Used, Length(S) + 1);
  end;
  P^ := 0;
end;
