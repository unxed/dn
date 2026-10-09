
function TLongInputLine.StreamableName: ShortString;
begin
  Result := 'Dialogs.TLongInputLine';
end;

class function TLongInputLine.Build: TStreamable;
begin
  Result := TLongInputLine.Create(streamableInit);
end;
