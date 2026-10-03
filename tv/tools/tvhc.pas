(* TVHC: the help compiler of this Turbo Vision (written for this port, MIT: tv/LICENSE). It makes the help file (.hlp) that
  THelpFile of TvHelp reads, from the text of a help (.htx). The format of the text is that of the help compiler of Borland
  Turbo Vision (the help of DN is written in it); the compiler is not a copy of it: the format was learned from the text of
  DN and from the behaviour of the old tool.

  usage: tvhc INPUT.HTX OUTPUT.HLP [SYMBOLS.PAS] [options]
    SYMBOLS.PAS  (optional) a unit with the constants hcName = Number for the names of the topics
    options      words like /x or -x are accepted and ignored (/4DN_OSP of the build of DN)

  The text:
    ; ...                a comment: the whole line is dropped
    .topic Name=N, Name2  a topic begins. Name is its name (for the references), N its number (the context of the program).
                          A name without =N gets the next number (the counter starts from 2; =N sets it; the contexts of
                          Turbo Vision (hcNew, hcOpen ... hcZoom) and Dragging have their own numbers). Several names: one
                          text. The rest of the line is a comment.
    .title Text           the title of the topic: a box with the text (as the first paragraph)
    a paragraph           lines up to a blank one. The first line decides: if it begins with a vertical bar (#179), the lines
                          (each begins with it, it is cut off) are not wrapped; else the paragraph is wrapped to the width of
                          the window, and a line that begins with a blank or with a bar begins a new paragraph.
    {text}                a cross reference to the topic named `text`
    {text:Name}           the same, shown as `text`. {{ is a brace, }} and :: in the reference are a brace and a colon.
    the topic `_` (65535) is the one that has no text: the references to it are marks that lead nowhere
  Topics with no text are not written to the file (the viewer says "no help in this context" for them). The blanks in the
  text of a reference are written as #$FF (so that the wrapping does not break the reference); TvHelp shows them as blanks. *)
program tvhc;

{$mode objfpc}
{$H+}

uses
  SysUtils, Classes, TvObjs, TvHelp;

type
  TNameDef = record
    Name: string;
    Number: LongInt;
  end;

  TRefInfo = record
    TopicName: string;
    Offset: LongInt;
    Length: Integer;
    Line: Integer;
  end;

  TTopicInfo = record
    Names: array of TNameDef;
    Paras: array of string;
    Wrap: array of Boolean;
    Refs: array of TRefInfo;
  end;

const
  { the contexts of Turbo Vision (the constants of its application unit) }
  BuiltIn: array[0..21] of TNameDef = (
    (Name: 'Cascade'; Number: $FF21), (Name: 'ChangeDir'; Number: $FF06), (Name: 'Clear'; Number: $FF14),
    (Name: 'Close'; Number: $FF27), (Name: 'CloseAll'; Number: $FF22), (Name: 'Copy'; Number: $FF12),
    (Name: 'Cut'; Number: $FF11), (Name: 'DosShell'; Number: $FF07), (Name: 'Dragging'; Number: 1),
    (Name: 'Exit'; Number: $FF08), (Name: 'New'; Number: $FF01), (Name: 'Next'; Number: $FF25),
    (Name: 'Open'; Number: $FF02), (Name: 'Paste'; Number: $FF13), (Name: 'Prev'; Number: $FF26),
    (Name: 'Resize'; Number: $FF23), (Name: 'Save'; Number: $FF03), (Name: 'SaveAll'; Number: $FF05),
    (Name: 'SaveAs'; Number: $FF04), (Name: 'Tile'; Number: $FF20), (Name: 'Undo'; Number: $FF10),
    (Name: 'Zoom'; Number: $FF24));
  Bar = #179;                      { the vertical bar of the code page of the help (DOS 437/866) }
  MaxParagraph = 4095;
  Unresolved = 65535;

var
  Lines: array of string;          { the text, comments dropped }
  LineNums: array of Integer;      { the numbers of the lines in the file }
  Cur: Integer = 0;                { the next line to read }
  Topics: array of TTopicInfo;
  Errors: Integer = 0;
  InName, OutName, SymName: string;
  ErrLine: Integer = 0;
  Counter: LongInt = 2;            { 1 is Dragging }

procedure Fail(const Msg: string);
begin
  Writeln(StdErr, InName, '(', ErrLine, '): error: ', Msg);
  Inc(Errors);
end;

procedure Warn(const Msg: string);
begin
  Writeln(StdErr, InName, ': warning: ', Msg);
end;

var
  Utf8Text: Boolean = False;             { the text is UTF-8 (the build of DN with -dDNUTF8 converts the help): columns are characters }
  SawMulti, SawBad: Boolean;

{ looks at the line: a UTF-8 sequence of more than one byte, or a byte that cannot be a part of UTF-8 }
procedure CheckUtf8(const S: string);
var
  I, K, N: Integer;
begin
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
      Inc(I)
    else
    begin
      if (Byte(S[I]) and $E0) = $C0 then N := 1
      else if (Byte(S[I]) and $F0) = $E0 then N := 2
      else if (Byte(S[I]) and $F8) = $F0 then N := 3
      else
      begin
        SawBad := True;
        Inc(I);
        Continue;
      end;
      for K := 1 to N do
        if (I + K > Length(S)) or ((Byte(S[I + K]) and $C0) <> $80) then
          SawBad := True;
      SawMulti := True;
      Inc(I, N + 1);
    end;
  end;
end;

{ the width of the text in columns }
function Cols(const S: string): Integer;
var
  I: Integer;
begin
  if not Utf8Text then
    Exit(Length(S));
  Result := 0;
  for I := 1 to Length(S) do
    if (Byte(S[I]) and $C0) <> $80 then
      Inc(Result);
end;

procedure Load;
var
  F: TextFile;
  L: string;
  N: Integer;
begin
  AssignFile(F, InName);
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then
  begin
    Writeln(StdErr, 'cannot open ', InName);
    Halt(2);
  end;
  N := 0;
  while not Eof(F) do
  begin
    Readln(F, L);
    Inc(N);
    while (L <> '') and (L[Length(L)] in [#13, #10, #26]) do
      SetLength(L, Length(L) - 1);
    if (L <> '') and (L[1] = ';') then
      Continue;
    SetLength(Lines, Length(Lines) + 1);
    SetLength(LineNums, Length(LineNums) + 1);
    Lines[High(Lines)] := L;
    LineNums[High(LineNums)] := N;
    CheckUtf8(L);
  end;
  CloseFile(F);
  Utf8Text := SawMulti and not SawBad;
end;

function AtEnd: Boolean;
begin
  Result := Cur >= Length(Lines);
end;

{ ---- the words of a directive line ---------------------------------------------------------------------------------- }

function IsWordChar(C: Char): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_', #128..#175, #224..#239];
end;

function GetWord(const L: string; var I: Integer): string;
var
  J: Integer;
begin
  while (I <= Length(L)) and (L[I] in [' ', #9]) do
    Inc(I);
  J := I;
  if J > Length(L) then
    Exit('');
  Inc(I);
  if IsWordChar(L[J]) then
    while (I <= Length(L)) and IsWordChar(L[I]) do
      Inc(I);
  Result := Copy(L, J, I - J);
end;

function BuiltInNumber(const Name: string; out Number: LongInt): Boolean;
var
  K: Integer;
begin
  for K := Low(BuiltIn) to High(BuiltIn) do
    if BuiltIn[K].Name = Name then
    begin
      Number := BuiltIn[K].Number;
      Exit(True);
    end;
  Result := False;
end;

{ `.topic A=1, B, C=7 ...`: the names and numbers of the topic, the line is in L }
procedure ParseTopicLine(const L: string; var T: TTopicInfo);
var
  I, J, Code: Integer;
  W, Name: string;
  Num: LongInt;
  V: LongInt;
begin
  I := 1;
  if GetWord(L, I) <> '.' then
  begin
    Fail('TOPIC expected');
    Exit;
  end;
  if UpperCase(GetWord(L, I)) <> 'TOPIC' then
  begin
    Fail('TOPIC expected');
    Exit;
  end;
  repeat
    Name := GetWord(L, I);
    if Name = '' then
    begin
      Fail('a topic name is expected');
      Exit;
    end;
    J := I;
    W := GetWord(L, J);
    if W = '=' then
    begin
      I := J;
      W := GetWord(L, I);
      Val(W, V, Code);
      if Code <> 0 then
      begin
        Fail('a number is expected after =');
        V := Counter;
      end;
      Counter := V;
      Num := V;
    end
    else if not BuiltInNumber(Name, Num) then
    begin
      Inc(Counter);
      Num := Counter;
    end;
    SetLength(T.Names, Length(T.Names) + 1);
    T.Names[High(T.Names)].Name := Name;
    T.Names[High(T.Names)].Number := Num;
    J := I;
    W := GetWord(L, J);
    if W = ',' then
      I := J;                       { past the comma: the next name }
  until W <> ',';
end;

{ ---- the text of a topic -------------------------------------------------------------------------------------------- }

{ Cuts the references out of the line; the shown text is the result, its offset in the topic is Base + the length of what
  was cut before. }
function ScanRefs(const Line: string; var T: TTopicInfo; Base: LongInt): string;
var
  I, K: Integer;
  Disp, Topic: string;
  InTopic, Done: Boolean;
  R: TRefInfo;
begin
  Result := '';
  I := 1;
  while I <= Length(Line) do
  begin
    if Line[I] <> '{' then
    begin
      Result := Result + Line[I];
      Inc(I);
      Continue;
    end;
    if (I < Length(Line)) and (Line[I + 1] = '{') then
    begin
      Result := Result + '{';
      Inc(I, 2);
      Continue;
    end;
    K := I + 1;
    Disp := '';
    Topic := '';
    InTopic := False;
    Done := False;
    while (K <= Length(Line)) and not Done do
    begin
      if Line[K] = '}' then
      begin
        if (K < Length(Line)) and (Line[K + 1] = '}') then
        begin
          if InTopic then
            Topic := Topic + '}'
          else
            Disp := Disp + '}';
          Inc(K, 2);
        end
        else
          Done := True;
      end
      else if (Line[K] = ':') and not InTopic then
      begin
        if (K < Length(Line)) and (Line[K + 1] = ':') then
        begin
          Disp := Disp + ':';
          Inc(K, 2);
        end
        else
        begin
          InTopic := True;
          Inc(K);
        end;
      end
      else
      begin
        if InTopic then
          Topic := Topic + Line[K]
        else
          Disp := Disp + Line[K];
        Inc(K);
      end;
    end;
    if not Done then
    begin
      Fail('unterminated topic reference');
      Result := Result + Copy(Line, I, Length(Line));
      Exit;
    end;
    if not InTopic then
      Topic := Disp;
    R.TopicName := Topic;
    R.Offset := Base + Length(Result) + 1;
    R.Length := Length(Disp);
    R.Line := ErrLine;
    SetLength(T.Refs, Length(T.Refs) + 1);
    T.Refs[High(T.Refs)] := R;
    I := K + 1;                     { past the closing brace }
    for K := 1 to Length(Disp) do
      if Disp[K] = ' ' then
        Disp[K] := #$FF;
    Result := Result + Disp;
  end;
end;

function TrimLeft(const S: string): string;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] = ' ') do
    Inc(I);
  Result := Copy(S, I, Length(S));
end;

function IsEndParagraph(Wrapping: Boolean; NotWrapping: Boolean): Boolean;
begin
  Result := AtEnd or (Lines[Cur] = '') or (Lines[Cur][1] = '.') or
    (Wrapping and (Lines[Cur][1] in [' ', Bar])) or
    (NotWrapping and (Lines[Cur][1] <> Bar));
end;

{ The next paragraph of the topic T; False if there is none (the blank lines before the end are dropped). }
function ReadParagraph(var T: TTopicInfo; var Offset: LongInt): Boolean;
var
  Buf: string;
  Wrapping, NotWrapping: Boolean;
  Line, Title: string;
  Undefined: Boolean;

  procedure Add(const S: string; Wrap: Boolean);
  begin
    if Length(Buf) + Length(S) > MaxParagraph then
      Fail('topic too large')
    else if Wrap then
      Buf := Buf + S + ' '
    else
      Buf := Buf + S + #10;
  end;

  procedure Finish;
  begin
    SetLength(T.Paras, Length(T.Paras) + 1);
    SetLength(T.Wrap, Length(T.Wrap) + 1);
    T.Paras[High(T.Paras)] := Buf;
    T.Wrap[High(T.Wrap)] := Wrapping;
    Inc(Offset, Length(Buf));
  end;

begin
  Result := False;
  Buf := '';
  Wrapping := False;
  NotWrapping := False;
  Undefined := True;
  while (not AtEnd) and (Lines[Cur] = '') do
  begin
    Add('', False);                 { a blank line: it is kept (in front of the text of the paragraph) }
    Inc(Cur);
  end;
  if AtEnd then
    Exit;
  ErrLine := LineNums[Cur];
  Line := Lines[Cur];
  if Copy(UpperCase(TrimLeft(Line)), 1, 6) = '.TITLE' then
  begin
    Title := TrimLeft(Copy(TrimLeft(Line), 7, Length(Line)));
    Inc(Cur);
    Add(#218 + StringOfChar(#196, Cols(Title) + 2), False);
    Add(Bar + ' ' + Title + ' ' + #219, False);
    Add(#192 + StringOfChar(#220, Cols(Title) + 2) + #219, False);
    Add('', False);
    NotWrapping := True;
    Finish;
    Exit(True);
  end;
  if IsEndParagraph(False, False) then
    Exit;
  while not IsEndParagraph(Wrapping, NotWrapping) do
  begin
    ErrLine := LineNums[Cur];
    Line := Lines[Cur];
    if Undefined then
    begin
      Undefined := False;
      NotWrapping := Line[1] = Bar;
      Wrapping := not NotWrapping;
    end;
    if NotWrapping then
      Line := Copy(Line, 2, Length(Line));
    Add(ScanRefs(Line, T, Offset + Length(Buf)), Wrapping);
    Inc(Cur);
  end;
  Finish;
  Result := True;
end;

procedure ReadTopics;
var
  T: TTopicInfo;
  Offset: LongInt;
begin
  while True do
  begin
    while (not AtEnd) and (Lines[Cur] = '') do
      Inc(Cur);
    if AtEnd then
      Break;
    ErrLine := LineNums[Cur];
    T := Default(TTopicInfo);
    ParseTopicLine(Lines[Cur], T);
    Inc(Cur);
    Offset := 0;
    while ReadParagraph(T, Offset) do
      ;
    SetLength(Topics, Length(Topics) + 1);
    Topics[High(Topics)] := T;
    if Errors > 20 then
      Break;
  end;
end;

{ ---- the numbers of the names ------------------------------------------------------------------------------------- }

function NameNumber(const Name: string; out Number: LongInt): Boolean;
var
  T, K: Integer;
begin
  for T := 0 to High(Topics) do
    for K := 0 to High(Topics[T].Names) do
      if SameText(Topics[T].Names[K].Name, Name) then
      begin
        Number := Topics[T].Names[K].Number;
        Exit(True);
      end;
  Number := Unresolved;
  Result := False;
end;

procedure CheckNames;
var
  T, K, T2, K2: Integer;
begin
  for T := 0 to High(Topics) do
    for K := 0 to High(Topics[T].Names) do
      for T2 := T to High(Topics) do
        for K2 := 0 to High(Topics[T2].Names) do
          if ((T2 > T) or (K2 > K)) and SameText(Topics[T].Names[K].Name, Topics[T2].Names[K2].Name) then
          begin
            ErrLine := 0;
            Fail('redefinition of ' + Topics[T].Names[K].Name);
          end;
end;

procedure WriteHelp;
var
  HF: PHelpFile;
  Topic: PHelpTopic;
  T, K: Integer;
  P: PParagraph;
  C: TCrossRef;
  N: LongInt;
begin
  New(HF, Init(New(PBufStream, Init(OutName, stCreate, 4096))));
  for T := 0 to High(Topics) do
  begin
    if Length(Topics[T].Paras) = 0 then
      Continue;
    New(Topic, Init);
    for K := 0 to High(Topics[T].Paras) do
    begin
      New(P);
      P^.Size := Length(Topics[T].Paras[K]);
      GetMem(P^.Text, P^.Size + 1);
      if P^.Size > 0 then
        Move(Topics[T].Paras[K][1], P^.Text^, P^.Size);
      P^.Text[P^.Size] := 0;
      P^.Wrap := Topics[T].Wrap[K];
      P^.Next := nil;
      Topic^.AddParagraph(P);
    end;
    for K := 0 to High(Topics[T].Refs) do
    begin
      if not NameNumber(Topics[T].Refs[K].TopicName, N) then
        Warn('unresolved forward reference "' + Topics[T].Refs[K].TopicName + '" (line ' +
          IntToStr(Topics[T].Refs[K].Line) + ')');
      C.Ref := N;
      C.Offset := Topics[T].Refs[K].Offset;
      C.Length := Topics[T].Refs[K].Length;
      Topic^.AddCrossRef(C);
    end;
    { every name of the topic leads to the one text: the same position in the index }
    for K := 0 to High(Topics[T].Names) do
      HF^.RecordPositionInIndex(Topics[T].Names[K].Number);
    HF^.PutTopic(Topic);
    Dispose(Topic, Done);
  end;
  Dispose(HF, Done);
end;

{ the unit with the constants: the names of the topics (and of the references) that are not the contexts of Turbo Vision }
procedure WriteSymbols;
var
  F: TextFile;
  Names: TStringList;
  T, K, I: Integer;
  N, Dummy: LongInt;
  S: string;
begin
  Names := TStringList.Create;
  Names.CaseSensitive := False;
  Names.Sorted := True;
  Names.Duplicates := dupIgnore;
  for T := 0 to High(Topics) do
  begin
    for K := 0 to High(Topics[T].Names) do
      Names.Add(Topics[T].Names[K].Name);
    for K := 0 to High(Topics[T].Refs) do
      Names.Add(Topics[T].Refs[K].TopicName);
  end;
  AssignFile(F, SymName);
  Rewrite(F);
  Writeln(F, '{ made by tvhc from ', ExtractFileName(InName), ' }');
  Writeln(F, 'unit ', ChangeFileExt(ExtractFileName(SymName), ''), ';');
  Writeln(F);
  Writeln(F, 'interface');
  Writeln(F);
  Writeln(F, 'const');
  for I := 0 to Names.Count - 1 do
    if NameNumber(Names[I], N) and not BuiltInNumber(Names[I], Dummy) then
    begin
      S := Names[I];
      while Length(S) < 20 do
        S := S + ' ';
      Writeln(F, ' hc', S, ' = ', N:5, ';');
    end;
  Writeln(F);
  Writeln(F, 'implementation');
  Writeln(F);
  Writeln(F, 'end.');
  CloseFile(F);
  Names.Free;
end;

var
  I, N: Integer;
begin
  N := 0;
  for I := 1 to ParamCount do
  begin
    { an option: -x, or /x without more slashes (a path on Unix begins with a slash too) }
    if (ParamStr(I) <> '') and ((ParamStr(I)[1] = '-') or
      ((ParamStr(I)[1] = '/') and (Pos('/', Copy(ParamStr(I), 2, MaxInt)) = 0))) then
      Continue;
    Inc(N);
    case N of
      1: InName := ParamStr(I);
      2: OutName := ParamStr(I);
      3: SymName := ParamStr(I);
    end;
  end;
  if (InName = '') or (OutName = '') then
  begin
    Writeln('usage: tvhc INPUT.HTX OUTPUT.HLP [SYMBOLS.PAS] [options]');
    Halt(1);
  end;
  RegisterType(RHelpTopic);
  RegisterType(RHelpIndex);
  Load;
  ReadTopics;
  CheckNames;
  if Errors > 0 then
  begin
    Writeln(StdErr, Errors, ' error(s): the help file is not written');
    Halt(1);
  end;
  WriteHelp;
  if SymName <> '' then
    WriteSymbols;
  Writeln(Length(Topics), ' topics, ', OutName);
end.
