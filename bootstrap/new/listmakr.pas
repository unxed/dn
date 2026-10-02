{ The unit ListMakr of DN: TStrListMaker collects the strings of a language (Put(number, text)) and writes them to a stream
  in the form that TStringList (DNStrL) reads: the size of the strings, the strings, the number of the index records, the
  records (the first number, the count of up to 16 consecutive numbers, the offset of their first string). Used by the
  resource compiler (rcp.pas). Written by us for DN (the original is the list maker of Borland TV and is in dn/exclude.list). }
unit ListMakr;

{$mode objfpc}{$H-}

interface

uses
  Defines, Objects2, Streams, DNStrL, ObjType;

type
  PStrListMaker = ^TStrListMaker;
  TStrListMaker = object(TObject)
    constructor Init(AStrSize, AIndexSize: AWord);
    destructor Done; virtual;
    procedure Put(Key: AWord; S: String);
    procedure Store(var S: TStream);
  private
    StrPos: AWord;
    StrSize: AWord;
    Strings: PByteArray;
    IndexPos: AWord;
    IndexSize: AWord;
    Index: PStrIndex;
    Cur: TStrIndexRec;
    procedure CloseCurrent;
  end;

var
  RStrListMaker: TStreamRec;

implementation

constructor TStrListMaker.Init(AStrSize, AIndexSize: AWord);
begin
  inherited Init;
  StrSize := AStrSize;
  IndexSize := AIndexSize;
  GetMem(Strings, AStrSize);
  GetMem(Index, AIndexSize * SizeOf(TStrIndexRec));
  StrPos := 0;
  IndexPos := 0;
  FillChar(Cur, SizeOf(Cur), 0);
end;

destructor TStrListMaker.Done;
begin
  FreeMem(Index, IndexSize * SizeOf(TStrIndexRec));
  FreeMem(Strings, StrSize);
  inherited Done;
end;

procedure TStrListMaker.CloseCurrent;
begin
  if Cur.Count <> 0 then
  begin
    Index^[IndexPos] := Cur;
    Inc(IndexPos);
    Cur.Count := 0;
  end;
end;

procedure TStrListMaker.Put(Key: AWord; S: String);
begin
  { a new record of the index when 16 strings are in the current one or the number does not follow the last }
  if (Cur.Count = 16) or (Key <> Cur.Key + Cur.Count) then
    CloseCurrent;
  if Cur.Count = 0 then
  begin
    Cur.Key := Key;
    Cur.Offset := StrPos;
  end;
  Inc(Cur.Count);
  Move(S, Strings^[StrPos], Length(S) + 1);
  Inc(StrPos, Length(S) + 1);
end;

procedure TStrListMaker.Store(var S: TStream);
begin
  CloseCurrent;
  S.Write(StrPos, SizeOf(StrPos));
  S.Write(Strings^, StrPos);
  S.Write(IndexPos, SizeOf(IndexPos));
  S.Write(Index^, IndexPos * SizeOf(TStrIndexRec));
end;

function BuildNothing(var S: TStream): PObject;
begin
  Result := nil;
end;

procedure StoreMaker(P: PObject; var S: TStream);
begin
  PStrListMaker(P)^.Store(S);
end;

initialization
  RStrListMaker.ObjType := otStrListMaker;
  RStrListMaker.VmtLink := PtrUInt(TypeOf(TStrListMaker));
  RStrListMaker.Load := @BuildNothing;
  RStrListMaker.Store := @StoreMaker;
end.
