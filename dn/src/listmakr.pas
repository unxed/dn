{ The unit ListMakr of DN: TStrListMaker collects the strings of a language (Put(number, text)) and writes them to a stream
  in the form that TStringList (DNStrL) reads: the size of the strings, the strings, the number of the index records, the
  records (the first number, the count of up to 16 consecutive numbers, the offset of their first string). Used by the
  resource compiler (rcp.pas). Written by us for DN (the original is the list maker of Borland TV and is in dn/exclude.list). }
unit ListMakr;

{$mode objfpc}{$H-}

interface

uses
  Defines, objutil, Streams, DNStrL, ObjType;

type
  PStrListMaker = ^TStrListMaker;
  TStrListMaker = class(TObject)
    constructor Create(AStrSize, AIndexSize: AWord);
    destructor Destroy; override;
    procedure Put(Key: AWord; S: String);
    procedure Store(S: TStream);
  private
    Text: array of Byte;      { the strings, one after another (a length byte, the characters) }
    TextLen: LongInt;
    Runs: array of TStrIndexRec;  { the index: the runs of consecutive keys, up to 16 in a run }
    RunCount: LongInt;
  end;

var
  RStrListMaker: TStreamRec;

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

procedure TStrListMaker.Store(S: TStream);
var
  Sz, Cnt: AWord;
begin
  Sz := TextLen;
  Cnt := RunCount;
  S.Write(Sz, SizeOf(Sz));
  if TextLen > 0 then S.Write(Text[0], TextLen);
  S.Write(Cnt, SizeOf(Cnt));
  if RunCount > 0 then S.Write(Runs[0], RunCount * SizeOf(TStrIndexRec));
end;

function BuildNothing(S: TStream): TStreamable;
begin
  Result := nil;
end;

procedure StoreMaker(P: TStreamable; S: TStream);
begin
  TStrListMaker(P).Store(S);
end;

initialization
  RStrListMaker.ObjType := otStrListMaker;
  RStrListMaker.VmtLink := PtrUInt(TClass(TStrListMaker));
  RStrListMaker.Load := @BuildNothing;
  RStrListMaker.Store := @StoreMaker;
end.
