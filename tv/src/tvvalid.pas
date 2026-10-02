{ TvValid: input validators (for TInputLine): TValidator, TPXPictureValidator,
  TFilterValidator, TRangeValidator, TLookupValidator, TStringLookupValidator.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/validate.h, source/tvision/tvalidat.cpp, tvtext2.cpp (messages)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - strings are ShortStrings (the picture and the input are indexed from 0 inside the
      picture validator, as in the original, through small helper functions);
    - the error messages are variables (translations);
    - streams are not translated yet. }
unit TvValid;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvObjs, TvUtil, TvMsgBox;

const
  { validator status }
  vsOk     = 0;
  vsSyntax = 1;      { error in the syntax of a picture }

  { validator options }
  voFill     = $0001;
  voTransfer = $0002;
  voReserved = $00FC;

type
  TCharSet = set of Char;

  TVTransfer = (vtDataSize, vtSetData, vtGetData);
  TPicResult = (prComplete, prIncomplete, prEmpty, prError, prSyntax, prAmbiguous,
    prIncompNoFill);

  PValidator = ^TValidator;
  TValidator = object(TObject)
    Status: Word;
    Options: Word;
    constructor Init;
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure Error; virtual;
    function IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean; virtual;
    function IsValid(const S: ShortString): Boolean; virtual;
    function Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word; virtual;
    function Validate(const S: ShortString): Boolean;
  end;

  PPXPictureValidator = ^TPXPictureValidator;
  TPXPictureValidator = object(TValidator)
    Pic: PStr;
    constructor Init(const APic: ShortString; AutoFill: Boolean);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Error; virtual;
    function IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean; virtual;
    function IsValid(const S: ShortString): Boolean; virtual;
    function Picture(var Input: ShortString; AutoFill: Boolean): TPicResult; virtual;
  private
    Index, Jndex: Integer;
    function PicLen: Integer;
    function PicCh(I: Integer): Char;
    procedure Consume(Ch: Char; var Input: ShortString);
    procedure ToGroupEnd(var I: Integer; TermCh: Integer);
    function SkipToComma(TermCh: Integer): Boolean;
    function CalcTerm(TermCh: Integer): Integer;
    function Iteration(var Input: ShortString; InTerm: Integer): TPicResult;
    function Group(var Input: ShortString; InTerm: Integer): TPicResult;
    function CheckComplete(Rslt: TPicResult; TermCh: Integer): TPicResult;
    function Scan(var Input: ShortString; TermCh: Integer): TPicResult;
    function Process(var Input: ShortString; TermCh: Integer): TPicResult;
    function SyntaxCheck: Boolean;
  end;

  PFilterValidator = ^TFilterValidator;
  TFilterValidator = object(TValidator)
    ValidChars: PStr;
    constructor Init(const AValidChars: ShortString); overload;
    { as in the Pascal Turbo Vision: the valid characters as a set (the characters #1..#255 of it) }
    constructor Init(const AValidChars: TCharSet); overload;
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Error; virtual;
    function IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean; virtual;
    function IsValid(const S: ShortString): Boolean; virtual;
  end;

  PRangeValidator = ^TRangeValidator;
  TRangeValidator = object(TFilterValidator)
    Min, Max: LongInt;
    constructor Init(AMin, AMax: LongInt);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure Error; virtual;
    function IsValid(const S: ShortString): Boolean; virtual;
    function Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word; virtual;
  end;

  PLookupValidator = ^TLookupValidator;
  TLookupValidator = object(TValidator)
    function IsValid(const S: ShortString): Boolean; virtual;
    function Lookup(const S: ShortString): Boolean; virtual;
  end;

  PStringLookupValidator = ^TStringLookupValidator;
  TStringLookupValidator = object(TLookupValidator)
    Strings: PStringCollection;
    constructor Init(AStrings: PStringCollection);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Error; virtual;
    function Lookup(const S: ShortString): Boolean; virtual;
    procedure NewStringList(AStrings: PStringCollection);
  end;

var
  { stream records (the numbers of Turbo Vision) }
  RPXPictureValidator, RFilterValidator, RRangeValidator, RStringLookupValidator: TStreamRec;
  ValidPictureError: ShortString = 'Error in picture format.'#10' %s';
  ValidFilterError: ShortString = 'Invalid character in input';
  ValidRangeError: ShortString = 'Value not in the range %d to %d';
  ValidLookupError: ShortString = 'Input is not in list of valid strings';

implementation

const
  ValidUnsignedChars = '+0123456789';
  ValidSignedChars = '+-0123456789';

function Upper(C: Char): Char;
begin
  if (C >= 'a') and (C <= 'z') then
    Result := Chr(Ord(C) - 32)
  else
    Result := C;
end;

{ --- TValidator -------------------------------------------------------------- }

constructor TValidator.Init;
begin
  inherited Init;
  Status := 0;
  Options := 0;
end;

procedure TValidator.Error;
begin
end;

function TValidator.IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean;
begin
  Result := True;
end;

function TValidator.IsValid(const S: ShortString): Boolean;
begin
  Result := True;
end;

function TValidator.Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word;
begin
  Result := 0;
end;

function TValidator.Validate(const S: ShortString): Boolean;
begin
  if not IsValid(S) then
  begin
    Error;
    Result := False;
  end
  else
    Result := True;
end;

{ --- TPXPictureValidator ----------------------------------------------------- }

function IsNumber(Ch: Char): Boolean;
begin
  Result := (Ch >= '0') and (Ch <= '9');
end;

function IsLetter(Ch: Char): Boolean;
begin
  Ch := Chr(Ord(Ch) and $DF);
  Result := (Ch >= 'A') and (Ch <= 'Z');
end;

function IsSpecial(Ch: Char; const Special: ShortString): Boolean;
begin
  Result := Pos(Ch, Special) > 0;
end;

function IsComplete(R: TPicResult): Boolean;
begin
  Result := (R = prComplete) or (R = prAmbiguous);
end;

function IsIncomplete(R: TPicResult): Boolean;
begin
  Result := (R = prIncomplete) or (R = prIncompNoFill);
end;

constructor TPXPictureValidator.Init(const APic: ShortString; AutoFill: Boolean);
var
  S: ShortString;
begin
  inherited Init;
  Pic := NewStr(APic);
  if AutoFill then
    Options := Options or voFill;
  S := '';
  if Picture(S, False) <> prEmpty then
    Status := vsSyntax;
end;

destructor TPXPictureValidator.Done;
begin
  DisposeStr(Pic);
  Pic := nil;
  inherited Done;
end;

function TPXPictureValidator.PicLen: Integer;
begin
  if Pic = nil then
    Result := 0
  else
    Result := Length(Pic^);
end;

{ the picture is indexed from 0; past its end there is a NUL, as in a C string }
function TPXPictureValidator.PicCh(I: Integer): Char;
begin
  if (Pic = nil) or (I < 0) or (I >= Length(Pic^)) then
    Result := #0
  else
    Result := Pic^[I + 1];
end;

procedure TPXPictureValidator.Error;
begin
  if Pic <> nil then
    MessageBoxFmt(mfError or mfOKButton, ValidPictureError, [Pic^])
  else
    MessageBoxFmt(mfError or mfOKButton, ValidPictureError, ['']);
end;

function TPXPictureValidator.IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean;
var
  DoFill: Boolean;
begin
  DoFill := ((Options and voFill) <> 0) and not SuppressFill;
  Result := (Pic = nil) or (Picture(S, DoFill) <> prError);
end;

function TPXPictureValidator.IsValid(const S: ShortString): Boolean;
var
  Str: ShortString;
begin
  Str := S;
  Result := (Pic = nil) or (Picture(Str, False) = prComplete);
end;

{ Consume input }
procedure TPXPictureValidator.Consume(Ch: Char; var Input: ShortString);
begin
  Input[Jndex + 1] := Ch;
  Inc(Index);
  Inc(Jndex);
end;

{ Skip a character or a picture group }
procedure TPXPictureValidator.ToGroupEnd(var I: Integer; TermCh: Integer);
var
  BrkLevel, BrcLevel: Integer;
begin
  BrkLevel := 0;
  BrcLevel := 0;
  repeat
    if I = TermCh then
      Exit;
    case PicCh(I) of
      '[': Inc(BrkLevel);
      ']': Dec(BrkLevel);
      '{': Inc(BrcLevel);
      '}': Dec(BrcLevel);
      ';': Inc(I);
    end;
    Inc(I);
  until (BrkLevel = 0) and (BrcLevel = 0);
end;

{ Find a comma separator }
function TPXPictureValidator.SkipToComma(TermCh: Integer): Boolean;
begin
  repeat
    ToGroupEnd(Index, TermCh);
  until (Index = TermCh) or (PicCh(Index) = ',');
  if PicCh(Index) = ',' then
    Inc(Index);
  Result := Index < TermCh;
end;

{ Calculate the end of a group }
function TPXPictureValidator.CalcTerm(TermCh: Integer): Integer;
var
  K: Integer;
begin
  K := Index;
  ToGroupEnd(K, TermCh);
  Result := K;
end;

{ The next group is repeated X times }
function TPXPictureValidator.Iteration(var Input: ShortString; InTerm: Integer): TPicResult;
var
  Itr, K, L, TermCh: Integer;
  Rslt: TPicResult;
begin
  Itr := 0;
  Rslt := prError;
  Inc(Index);          { skip '*' }
  { retrieve number }
  while IsNumber(PicCh(Index)) do
  begin
    Itr := Itr * 10 + (Ord(PicCh(Index)) - Ord('0'));
    Inc(Index);
  end;
  K := Index;
  TermCh := CalcTerm(InTerm);
  { if Itr is 0 allow any number, otherwise enforce the number }
  if Itr <> 0 then
  begin
    for L := 1 to Itr do
    begin
      Index := K;
      Rslt := Process(Input, TermCh);
      if not IsComplete(Rslt) then
      begin
        { empty means incomplete since all are required }
        if Rslt = prEmpty then
          Rslt := prIncomplete;
        Exit(Rslt);
      end;
    end;
  end
  else
  begin
    repeat
      Index := K;
      Rslt := Process(Input, TermCh);
    until Rslt <> prComplete;
    if (Rslt = prEmpty) or (Rslt = prError) then
    begin
      Inc(Index);
      Rslt := prAmbiguous;
    end;
  end;
  Index := TermCh;
  Result := Rslt;
end;

{ Process a picture group }
function TPXPictureValidator.Group(var Input: ShortString; InTerm: Integer): TPicResult;
var
  Rslt: TPicResult;
  TermCh: Integer;
begin
  TermCh := CalcTerm(InTerm);
  Inc(Index);
  Rslt := Process(Input, TermCh - 1);
  if not IsIncomplete(Rslt) then
    Index := TermCh;
  Result := Rslt;
end;

function TPXPictureValidator.CheckComplete(Rslt: TPicResult; TermCh: Integer): TPicResult;
var
  J: Integer;
  Stat: Boolean;
begin
  J := Index;
  Stat := True;
  if IsIncomplete(Rslt) then
  begin
    { skip optional pieces }
    while Stat do
      case PicCh(J) of
        '[': ToGroupEnd(J, TermCh);
        '*':
          begin
            if not IsNumber(PicCh(J + 1)) then
              Inc(J);
            ToGroupEnd(J, TermCh);
          end;
      else
        Stat := False;
      end;
    if J = TermCh then
      Rslt := prAmbiguous;
  end;
  Result := Rslt;
end;

function TPXPictureValidator.Scan(var Input: ShortString; TermCh: Integer): TPicResult;
var
  Ch: Char;
  Rslt, RScan: TPicResult;
begin
  RScan := prError;
  Rslt := prEmpty;
  while (Index <> TermCh) and (PicCh(Index) <> ',') do
  begin
    if Jndex >= Length(Input) then
      Exit(CheckComplete(Rslt, TermCh));
    Ch := Input[Jndex + 1];
    case PicCh(Index) of
      '#':
        if not IsNumber(Ch) then
          Exit(prError)
        else
          Consume(Ch, Input);
      '?':
        if not IsLetter(Ch) then
          Exit(prError)
        else
          Consume(Ch, Input);
      '&':
        if not IsLetter(Ch) then
          Exit(prError)
        else
          Consume(Upper(Ch), Input);
      '!': Consume(Upper(Ch), Input);
      '@': Consume(Ch, Input);
      '*':
        begin
          Rslt := Iteration(Input, TermCh);
          if not IsComplete(Rslt) then
            Exit(Rslt);
          if Rslt = prError then
            Rslt := prAmbiguous;
        end;
      '{':
        begin
          Rslt := Group(Input, TermCh);
          if not IsComplete(Rslt) then
            Exit(Rslt);
        end;
      '[':
        begin
          Rslt := Group(Input, TermCh);
          if IsIncomplete(Rslt) then
            Exit(Rslt);
          if Rslt = prError then
            Rslt := prAmbiguous;
        end;
    else
      begin
        if PicCh(Index) = ';' then
          Inc(Index);
        if Upper(PicCh(Index)) <> Upper(Ch) then
        begin
          if Ch = ' ' then
            Ch := PicCh(Index)
          else
            Exit(RScan);
        end;
        Consume(PicCh(Index), Input);
      end;
    end;
    if Rslt = prAmbiguous then
      Rslt := prIncompNoFill
    else
      Rslt := prIncomplete;
  end;
  if Rslt = prIncompNoFill then
    Result := prAmbiguous
  else
    Result := prComplete;
end;

function TPXPictureValidator.Process(var Input: ShortString; TermCh: Integer): TPicResult;
var
  Rslt, RProcess: TPicResult;
  Incomp: Boolean;
  OldI, OldJ, IncompJ, IncompI: Integer;
begin
  IncompJ := 0;
  IncompI := 0;
  RProcess := prError;
  Incomp := False;
  OldI := Index;
  OldJ := Jndex;
  repeat
    Rslt := Scan(Input, TermCh);
    { only accept completes if they make it farther in the input stream than the last
      incomplete }
    if (Rslt = prComplete) and Incomp and (Jndex < IncompJ) then
    begin
      Rslt := prIncomplete;
      Jndex := IncompJ;
    end;
    if (Rslt = prError) or (Rslt = prIncomplete) then
    begin
      RProcess := Rslt;
      if (not Incomp) and (Rslt = prIncomplete) then
      begin
        Incomp := True;
        IncompI := Index;
        IncompJ := Jndex;
      end;
      Index := OldI;
      Jndex := OldJ;
      if not SkipToComma(TermCh) then
      begin
        if Incomp then
        begin
          RProcess := prIncomplete;
          Index := IncompI;
          Jndex := IncompJ;
        end;
        Exit(RProcess);
      end;
      OldI := Index;
    end;
  until (Rslt <> prError) and (Rslt <> prIncomplete);
  if (Rslt = prComplete) and Incomp then
    Result := prAmbiguous
  else
    Result := Rslt;
end;

function TPXPictureValidator.SyntaxCheck: Boolean;
var
  I, Len, BrkLevel, BrcLevel: Integer;
begin
  Result := False;
  if (Pic = nil) or (Length(Pic^) = 0) then
    Exit;
  if Pic^[Length(Pic^)] = ';' then
    Exit;
  I := 0;
  BrkLevel := 0;
  BrcLevel := 0;
  Len := Length(Pic^);
  while I < Len do
  begin
    case PicCh(I) of
      '[': Inc(BrkLevel);
      ']': Dec(BrkLevel);
      '{': Inc(BrcLevel);
      '}': Dec(BrcLevel);
      ';': Inc(I);
    end;
    Inc(I);
  end;
  Result := (BrkLevel = 0) and (BrcLevel = 0);
end;

function TPXPictureValidator.Picture(var Input: ShortString; AutoFill: Boolean): TPicResult;
var
  Reprocess: Boolean;
  Rslt: TPicResult;
begin
  if not SyntaxCheck then
    Exit(prSyntax);
  if Length(Input) = 0 then
    Exit(prEmpty);
  Jndex := 0;
  Index := 0;
  Rslt := Process(Input, PicLen);
  if (Rslt <> prError) and (Jndex < Length(Input)) then
    Rslt := prError;
  if (Rslt = prIncomplete) and AutoFill then
  begin
    Reprocess := False;
    while (Index < PicLen) and not IsSpecial(PicCh(Index), '#?&!@*{}[],') do
    begin
      if PicCh(Index) = ';' then
        Inc(Index);
      if Length(Input) < 255 then
        Input := Input + PicCh(Index);
      Inc(Index);
      Reprocess := True;
    end;
    Jndex := 0;
    Index := 0;
    if Reprocess then
      Rslt := Process(Input, PicLen);
  end;
  if Rslt = prAmbiguous then
    Result := prComplete
  else if Rslt = prIncompNoFill then
    Result := prIncomplete
  else
    Result := Rslt;
end;

{ --- TFilterValidator -------------------------------------------------------- }

constructor TFilterValidator.Init(const AValidChars: ShortString);
begin
  inherited Init;
  ValidChars := NewStr(AValidChars);
end;

constructor TFilterValidator.Init(const AValidChars: TCharSet);
var
  C: Char;
  T: ShortString;
begin
  T := '';
  for C := #1 to #255 do
    if C in AValidChars then
      T := T + C;
  Init(T);
end;

destructor TFilterValidator.Done;
begin
  DisposeStr(ValidChars);
  ValidChars := nil;
  inherited Done;
end;

function AllIn(const S: ShortString; Valid: PStr): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(S) do
    if (Valid = nil) or (Pos(S[I], Valid^) = 0) then
      Exit(False);
end;

function TFilterValidator.IsValid(const S: ShortString): Boolean;
begin
  Result := AllIn(S, ValidChars);
end;

function TFilterValidator.IsValidInput(var S: ShortString; SuppressFill: Boolean): Boolean;
begin
  Result := AllIn(S, ValidChars);
end;

procedure TFilterValidator.Error;
begin
  MessageBoxFmt(mfError or mfOKButton, ValidFilterError, []);
end;

{ --- TRangeValidator --------------------------------------------------------- }

{ the number at the start of S like sscanf("%ld"): blanks, a sign, digits }
function ScanLong(const S: ShortString; out Value: LongInt): Boolean;
var
  I: Integer;
  Neg: Boolean;
  V: Int64;
begin
  Result := False;
  Value := 0;
  I := 1;
  while (I <= Length(S)) and (S[I] in [' ', #9]) do
    Inc(I);
  Neg := False;
  if (I <= Length(S)) and (S[I] in ['+', '-']) then
  begin
    Neg := S[I] = '-';
    Inc(I);
  end;
  if (I > Length(S)) or not (S[I] in ['0'..'9']) then
    Exit;
  V := 0;
  while (I <= Length(S)) and (S[I] in ['0'..'9']) do
  begin
    V := V * 10 + (Ord(S[I]) - Ord('0'));
    if V > 2147483648 then
      V := 2147483648;
    Inc(I);
  end;
  if Neg then
    V := -V;
  if (V > High(LongInt)) or (V < Low(LongInt)) then
    Exit;
  Value := V;
  Result := True;
end;

constructor TRangeValidator.Init(AMin, AMax: LongInt);
begin
  if AMin >= 0 then
    inherited Init(ValidUnsignedChars)
  else
    inherited Init(ValidSignedChars);
  Min := AMin;
  Max := AMax;
end;

procedure TRangeValidator.Error;
begin
  MessageBoxFmt(mfError or mfOKButton, ValidRangeError, [Min, Max]);
end;

function TRangeValidator.IsValid(const S: ShortString): Boolean;
var
  Value: LongInt;
begin
  Result := False;
  if inherited IsValid(S) then
    if ScanLong(S, Value) then
      if (Value >= Min) and (Value <= Max) then
        Result := True;
end;

function TRangeValidator.Transfer(var S: ShortString; Buffer: Pointer; Flag: TVTransfer): Word;
var
  Value: LongInt;
begin
  if (Options and voTransfer) <> 0 then
  begin
    case Flag of
      vtDataSize: ;
      vtGetData:
        begin
          ScanLong(S, Value);
          PLongInt(Buffer)^ := Value;
        end;
      vtSetData:
        begin
          Str(PLongInt(Buffer)^, S);
        end;
    end;
    Result := SizeOf(LongInt);
  end
  else
    Result := 0;
end;

{ --- TLookupValidator / TStringLookupValidator ----------------------------------- }

function TLookupValidator.IsValid(const S: ShortString): Boolean;
begin
  Result := Lookup(S);
end;

function TLookupValidator.Lookup(const S: ShortString): Boolean;
begin
  Result := True;
end;

constructor TStringLookupValidator.Init(AStrings: PStringCollection);
begin
  inherited Init;
  Strings := AStrings;
end;

destructor TStringLookupValidator.Done;
begin
  NewStringList(nil);
  inherited Done;
end;

procedure TStringLookupValidator.Error;
begin
  MessageBoxFmt(mfError or mfOKButton, ValidLookupError, []);
end;

function TStringLookupValidator.Lookup(const S: ShortString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Strings = nil then
    Exit;
  for I := 0 to Strings^.Count - 1 do
    if PStr(Strings^.At(I))^ = S then
      Exit(True);
end;

procedure TStringLookupValidator.NewStringList(AStrings: PStringCollection);
begin
  if Strings <> nil then
    Dispose(Strings, Done);
  Strings := AStrings;
end;

{ --- streams ----------------------------------------------------------------- }

constructor TValidator.Load(var S: TStream);
begin
  inherited Init;
  S.Read(Options, SizeOf(Options));
  Status := 0;
end;

procedure TValidator.Store(var S: TStream);
begin
  S.Write(Options, SizeOf(Options));
end;

constructor TPXPictureValidator.Load(var S: TStream);
begin
  inherited Load(S);
  Pic := S.ReadStr;
end;

procedure TPXPictureValidator.Store(var S: TStream);
begin
  inherited Store(S);
  S.WriteStr(Pic);
end;

constructor TFilterValidator.Load(var S: TStream);
begin
  inherited Load(S);
  ValidChars := S.ReadStr;
end;

procedure TFilterValidator.Store(var S: TStream);
begin
  inherited Store(S);
  S.WriteStr(ValidChars);
end;

constructor TRangeValidator.Load(var S: TStream);
begin
  inherited Load(S);
  S.Read(Min, SizeOf(Min));
  S.Read(Max, SizeOf(Max));
end;

procedure TRangeValidator.Store(var S: TStream);
begin
  inherited Store(S);
  S.Write(Min, SizeOf(Min));
  S.Write(Max, SizeOf(Max));
end;

constructor TStringLookupValidator.Load(var S: TStream);
begin
  inherited Load(S);
  Strings := PStringCollection(S.Get);
end;

procedure TStringLookupValidator.Store(var S: TStream);
begin
  inherited Store(S);
  S.Put(Strings);
end;

function BuildPXPicture(var S: TStream): PObject;
begin
  Result := New(PPXPictureValidator, Load(S));
end;

procedure StorePXPicture(P: PObject; var S: TStream);
begin
  PPXPictureValidator(P)^.Store(S);
end;

function BuildFilter(var S: TStream): PObject;
begin
  Result := New(PFilterValidator, Load(S));
end;

procedure StoreFilter(P: PObject; var S: TStream);
begin
  PFilterValidator(P)^.Store(S);
end;

function BuildRange(var S: TStream): PObject;
begin
  Result := New(PRangeValidator, Load(S));
end;

procedure StoreRange(P: PObject; var S: TStream);
begin
  PRangeValidator(P)^.Store(S);
end;

function BuildStringLookup(var S: TStream): PObject;
begin
  Result := New(PStringLookupValidator, Load(S));
end;

procedure StoreStringLookup(P: PObject; var S: TStream);
begin
  PStringLookupValidator(P)^.Store(S);
end;

initialization
  RPXPictureValidator.ObjType := 80;
  RPXPictureValidator.VmtLink := PtrUInt(TypeOf(TPXPictureValidator));
  RPXPictureValidator.Load := @BuildPXPicture;
  RPXPictureValidator.Store := @StorePXPicture;
  RFilterValidator.ObjType := 81;
  RFilterValidator.VmtLink := PtrUInt(TypeOf(TFilterValidator));
  RFilterValidator.Load := @BuildFilter;
  RFilterValidator.Store := @StoreFilter;
  RRangeValidator.ObjType := 82;
  RRangeValidator.VmtLink := PtrUInt(TypeOf(TRangeValidator));
  RRangeValidator.Load := @BuildRange;
  RRangeValidator.Store := @StoreRange;
  RStringLookupValidator.ObjType := 83;
  RStringLookupValidator.VmtLink := PtrUInt(TypeOf(TStringLookupValidator));
  RStringLookupValidator.Load := @BuildStringLookup;
  RStringLookupValidator.Store := @StoreStringLookup;

end.
