function GetCurMSec: LongInt;
begin
  Result := LongInt(Cardinal(GetTickCount64 and $FFFFFFFF));
end;

procedure LongWorkBegin;
begin
end;

procedure LongWorkEnd;
begin
end;
