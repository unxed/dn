type
  TBackgroundItem = record
    View: PView;
    Last: QWord;
  end;

var
  Background: array of TBackgroundItem;

procedure UnregisterFromBackground(P: PView);
var
  I: Integer;
begin
  for I := High(Background) downto 0 do
    if Background[I].View = P then
    begin
      Background[I] := Background[High(Background)];
      SetLength(Background, High(Background));
    end;
end;

procedure RegisterToBackground(P: PView);
var
  I: Integer;
begin
  for I := 0 to High(Background) do
    if Background[I].View = P then
      Exit;
  SetLength(Background, Length(Background) + 1);
  Background[High(Background)].View := P;
  Background[High(Background)].Last := GetTickCount64;
  ViewDoneHook := @UnregisterFromBackground;
end;

procedure RunBackground;
var
  I: Integer;
  Now: QWord;
  P: PView;
begin
  Now := GetTickCount64;
  I := 0;
  while I < Length(Background) do
  begin
    P := Background[I].View;
    if (P^.UpdTicks > 0) and (Now - Background[I].Last >= QWord(P^.UpdTicks)) then
    begin
      Background[I].Last := Now;
      P^.Update;
    end;
    Inc(I);
  end;
end;

procedure TMyScrollBar.Draw;
begin
  inherited Draw;
end;

function MessageL(Receiver: PView; What, Command: Word; InfoLng: LongInt): Pointer;
var
  Event: TEvent;
begin
  Result := nil;
  if Receiver = nil then
    Exit;
  ClearEvent(Event);
  Event.What := What;
  Event.Command := Command;
  Event.InfoLong := InfoLng;
  Receiver^.HandleEvent(Event);
  if Event.What = evNothing then
    Result := Event.InfoPtr;
end;
