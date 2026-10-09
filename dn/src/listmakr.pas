{ The unit ListMakr of DN: TStrListMaker collects the strings of a language (Put(number, text)) and writes them to a stream
  in the form that TStringList (DNStrL) reads, under its name 'DNStrL.TStringList': the size of the strings, the strings, the number of the index records, the
  records (the first number, the count of up to 16 consecutive numbers, the offset of their first string). Used by the
  resource compiler (rcp.pas). }
unit ListMakr;

{$mode objfpc}{$H-}

interface

uses
  Defines, objutil, Streams, DNStrL, ObjType;

type
  TStrListMaker = class(TStreamable)
    constructor Create(AStrSize, AIndexSize: AWord);
    destructor Destroy; override;
    procedure Put(Key: AWord; S: String);
    procedure Write(Os: opstream); override;
    function StreamableName: ShortString; override;
  protected
    function Read(Ip: ipstream): Pointer; override;
  private
    Text: array of Byte;      { the strings, one after another (a length byte, the characters) }
    TextLen: LongInt;
    Runs: array of TStrIndexRec;  { the index: the runs of consecutive keys, up to 16 in a run }
    RunCount: LongInt;
  end;

implementation

const
  MaxRun = 16;

{ the sizes of the arguments are a hint only: the arrays grow as needed }
constructor TStrListMaker.Create(AStrSize, AIndexSize: AWord);
begin
  inherited Create;
  SetLength(Text, AStrSize);
  SetLength(Runs, AIndexSize);
  TextLen := 0;
  RunCount := 0;
end;

destructor TStrListMaker.Destroy;
begin
  Text := nil;
  Runs := nil;
  inherited Destroy;
end;

procedure TStrListMaker.Put(Key: AWord; S: String);
var
  N: LongInt;
  Last: ^TStrIndexRec;
begin
  N := Length(S) + 1;
  if TextLen + N > Length(Text) then
    SetLength(Text, (TextLen + N) * 2);
  Move(S[0], Text[TextLen], N);
  { the key goes to the last run when it is the next one after it and the run is not full }
  if RunCount > 0 then
  begin
    Last := @Runs[RunCount - 1];
    if (Last^.Count < MaxRun) and (Key = Last^.Key + Last^.Count) then
    begin
      Inc(Last^.Count);
      Inc(TextLen, N);
      Exit;
    end;
  end;
  if RunCount = Length(Runs) then
    SetLength(Runs, RunCount * 2 + 16);
  Runs[RunCount].Key := Key;
  Runs[RunCount].Count := 1;
  Runs[RunCount].Offset := TextLen;
  Inc(RunCount);
  Inc(TextLen, N);
end;

procedure TStrListMaker.Write(Os: opstream);
var
  Sz, Cnt: AWord;
begin
  Sz := TextLen;
  Cnt := RunCount;
  Os.WriteBytes(Sz, SizeOf(Sz));
  if TextLen > 0 then Os.WriteBytes(Text[0], TextLen);
  Os.WriteBytes(Cnt, SizeOf(Cnt));
  if RunCount > 0 then Os.WriteBytes(Runs[0], RunCount * SizeOf(TStrIndexRec));
end;

function TStrListMaker.StreamableName: ShortString;
begin
  Result := 'DNStrL.TStringList';
end;

{ what the maker writes is read back as a TStringList (the builder of the name): the maker itself is never read }
function TStrListMaker.Read(Ip: ipstream): Pointer;
begin
  Result := nil;
  raise EStreamableError.Create(pstream.StreamableError.peNotRegistered, ClassName);
end;

end.
