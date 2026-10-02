(* TVHC: the help compiler of this Turbo Vision (Written for this port, MIT: tv/LICENSE). It makes the help file (.hlp) that
  THelpFile of TvHelp reads from the text of a help (.htx).

  usage: tvhc INPUT.HTX OUTPUT.HLP [CONSTANTS.PAS] [options]
    CONSTANTS.PAS  (optional) a unit-less list of the constants of the topics, `hcName = Number;`, for the programs
    options        words like /x or -x (the defines of the DN build, /4DN_OSP) are accepted and ignored

  The text of a help:
    ;...               a comment (the whole line)
    .topic Name=N      a topic begins: Name is its name (for the references), N its number (a context of the program); without
                       =N the number is the next one after the greatest so far. .topic Name1=N1, Name2=N2: two names, one text
    .title Text        the title of the topic (kept in the list of the names, not in the file: the window has one title)
    {text}             a cross reference to the topic that is named `text`
    {text:Name}        a cross reference to the topic Name, shown as `text` (the last colon counts)
    {{                 one brace (a brace without a closing one in the line is text too)
    other lines        the text. A run of lines without a blank line between them is a paragraph; the paragraph whose first
                       line begins with a blank is not wrapped (its lines are kept), the others are wrapped to the width of
                       the window.
  The bytes of the text are not changed (the code page of the file is the one of the program). *)
program tvhc;

{$mode objfpc}
{$H+}

uses
  SysUtils, Classes, TvObjs, TvHelp;

type
  TTopicInfo = record
    Name: string;
    Number: LongInt;
    Title: string;
    Same: Integer;             { >= 0: the text of that topic (`.topic A=1, B=2`: two names, one text) }
  end;

  TRefInfo = record
    TopicName: string;
    Topic: Integer;            { the index in Topics }
    Offset: LongInt;
    Length: Integer;
    Line: Integer;
  end;

var
  Topics: array of TTopicInfo;
  { the paragraphs and the references of the topics, kept until all the names are known }
  ParaText: array of array of string;
  ParaWrap: array of array of Boolean;
  Refs: array of array of TRefInfo;
  Errors: Integer = 0;
  InName, OutName, ConstName: string;
  LineNo: Integer = 0;

procedure Fail(const Msg: string);
begin
  Writeln(StdErr, InName, '(', LineNo, '): ', Msg);
  Inc(Errors);
end;

function FindTopic(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Topics) do
    if SameText(Topics[I].Name, Name) then
      Exit(I);
  Result := -1;
end;

var
  NextNumber: LongInt = 0;
  FirstOfDirective: Integer;

{ a trailing ; comment or braced comment of a directive line is dropped }
function StripComment(const S: string): string;
var
  P: Integer;
begin
  P := Pos(';', S);
  if (Pos('{', S) > 0) and ((P = 0) or (Pos('{', S) < P)) then
    P := Pos('{', S);
  if P = 0 then
    Result := S
  else
    Result := Copy(S, 1, P - 1);
end;

{ .topic Name=N, Name2=N2 }
procedure BeginTopics(const Rest: string);
var
  Count: Integer;
  Part, Name: string;
  P, Eq, Num, Code: Integer;
  S: string;
begin
  S := Rest;
  Count := 0;
  repeat
    P := Pos(',', S);
    if P = 0 then
      Part := S
    else
      Part := Copy(S, 1, P - 1);
    if P = 0 then
      S := ''
    else
      S := Copy(S, P + 1, Length(S));
    Part := Trim(Part);
    if Part = '' then
      Continue;
    Eq := Pos('=', Part);
    if Eq = 0 then
    begin
      Name := Part;
      Num := NextNumber;
    end
    else
    begin
      Name := Trim(Copy(Part, 1, Eq - 1));
      Val(Trim(Copy(Part, Eq + 1, Length(Part))), Num, Code);
      if Code <> 0 then
      begin
        Fail('the number of the topic ' + Name + ' is not a number');
        Num := NextNumber;
      end;
    end;
    if FindTopic(Name) >= 0 then
      Fail('the topic ' + Name + ' is defined twice');
    SetLength(Topics, Length(Topics) + 1);
    SetLength(ParaText, Length(Topics));
    SetLength(ParaWrap, Length(Topics));
    SetLength(Refs, Length(Topics));
    Topics[High(Topics)].Name := Name;
    Topics[High(Topics)].Number := Num;
    Topics[High(Topics)].Title := '';
    if Count = 0 then
    begin
      FirstOfDirective := High(Topics);
      Topics[High(Topics)].Same := -1;
    end
    else
      Topics[High(Topics)].Same := FirstOfDirective;
    Inc(Count);
    if Num >= NextNumber then
      NextNumber := Num + 1;
  until S = '';
end;

{ the text of a paragraph: the braces of the references are cut out, the offsets of the references (1-based, over the text of the
  topic: Base is the size of the paragraphs before this one) are kept }
function CutRefs(const Line: string; T: Integer; Base: LongInt): string;
var
  I, J, Colon: Integer;
  Inner, Shown, Target: string;
  R: TRefInfo;
begin
  Result := '';
  I := 1;
  while I <= Length(Line) do
  begin
    if (Line[I] = '{') and (I < Length(Line)) and (Line[I + 1] = '{') then
    begin
      Result := Result + '{';           { two braces: a brace }
      Inc(I, 2);
    end
    else if Line[I] = '{' then
    begin
      J := Pos('}', Copy(Line, I, Length(Line)));
      if J = 0 then
      begin
        { a brace with no closing one in the line is plain text (DN's help has such listings) }
        Result := Result + Copy(Line, I, Length(Line));
        Break;
      end;
      Inner := Copy(Line, I + 1, J - 2);
      Colon := Length(Inner);
      while (Colon > 0) and (Inner[Colon] <> ':') do
        Dec(Colon);
      if Colon = 0 then
      begin
        Shown := Inner;
        Target := Inner;
      end
      else
      begin
        Shown := Copy(Inner, 1, Colon - 1);
        Target := Trim(Copy(Inner, Colon + 1, Length(Inner)));
      end;
      R.TopicName := Target;
      R.Topic := -1;
      R.Offset := Base + Length(Result) + 1;
      R.Length := Length(Shown);
      R.Line := LineNo;
      SetLength(Refs[T], Length(Refs[T]) + 1);
      Refs[T][High(Refs[T])] := R;
      Result := Result + Shown;
      Inc(I, J);
    end
    else
    begin
      Result := Result + Line[I];
      Inc(I);
    end;
  end;
end;

procedure ReadText;
var
  F: TextFile;
  Line: string;
  Cur: Integer;
  Run: TStringList;
  RunWrap: Boolean;
  Blank: Integer;

  function SizeBefore: LongInt;
  var
    K: Integer;
  begin
    Result := 0;
    for K := 0 to High(ParaText[Cur]) do
      Inc(Result, Length(ParaText[Cur][K]));
  end;

  { the run of lines (and the blank lines after it) becomes a paragraph of the current topic }
  procedure Flush;
  var
    K: Integer;
    Txt, One: string;
    Base: LongInt;
  begin
    if (Cur < 0) or ((Run.Count = 0) and (Blank = 0)) then
      Exit;
    Base := SizeBefore;
    Txt := '';
    for K := 0 to Run.Count - 1 do
    begin
      One := CutRefs(Run[K], Cur, Base + Length(Txt));
      if RunWrap then
      begin
        if K > 0 then
          Txt := Txt + ' ';
        Txt := Txt + One;
      end
      else
        Txt := Txt + One + #10;
    end;
    if RunWrap and (Run.Count > 0) then
      Txt := Txt + #10;
    for K := 1 to Blank do
      Txt := Txt + #10;
    SetLength(ParaText[Cur], Length(ParaText[Cur]) + 1);
    SetLength(ParaWrap[Cur], Length(ParaWrap[Cur]) + 1);
    ParaText[Cur][High(ParaText[Cur])] := Txt;
    ParaWrap[Cur][High(ParaWrap[Cur])] := RunWrap and (Run.Count > 0);
    Run.Clear;
    Blank := 0;
  end;

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
  Run := TStringList.Create;
  Cur := -1;
  Blank := 0;
  RunWrap := True;
  while not Eof(F) do
  begin
    Readln(F, Line);
    Inc(LineNo);
    while (Line <> '') and (Line[Length(Line)] in [#13, #10]) do
      SetLength(Line, Length(Line) - 1);
    if (Line <> '') and (Line[1] = ';') then
      Continue;
    if (Length(Line) >= 6) and SameText(Copy(Line, 1, 6), '.topic') and ((Length(Line) = 6) or (Line[7] in [' ', #9])) then
    begin
      Flush;
      BeginTopics(Trim(StripComment(Copy(Line, 7, Length(Line)))));
      Cur := FirstOfDirective;
      Blank := 0;
      Continue;
    end;
    if (Length(Line) >= 6) and SameText(Copy(Line, 1, 6), '.title') and ((Length(Line) = 6) or (Line[7] in [' ', #9])) then
    begin
      if Cur >= 0 then
        Topics[Cur].Title := Trim(Copy(Line, 7, Length(Line)));  { not stripped: a title may hold ';' }
      Continue;
    end;
    if Cur < 0 then
      Continue;                   { text before the first topic is ignored }
    if Line = '' then
    begin
      if Run.Count > 0 then
        Inc(Blank)
      else if Blank > 0 then
        Inc(Blank)
      else
        Inc(Blank);
      Continue;
    end;
    { a text line after blank lines: the previous paragraph is closed }
    if Blank > 0 then
      Flush;
    if Run.Count = 0 then
      RunWrap := Line[1] <> ' ';
    Run.Add(Line);
  end;
  Flush;
  CloseFile(F);
  Run.Free;
end;

procedure ResolveRefs;
var
  T, K: Integer;
begin
  for T := 0 to High(Refs) do
    for K := 0 to High(Refs[T]) do
    begin
      Refs[T][K].Topic := FindTopic(Refs[T][K].TopicName);
      if Refs[T][K].Topic < 0 then
      begin
        LineNo := Refs[T][K].Line;
        Fail('the topic ' + Refs[T][K].TopicName + ' is not defined (a reference in the topic ' + Topics[T].Name + ')');
      end;
    end;
end;

procedure WriteHelp;
var
  HF: PHelpFile;
  Topic: PHelpTopic;
  T, K, Src: Integer;
  P: PParagraph;
  C: TCrossRef;
begin
  New(HF, Init(New(PBufStream, Init(OutName, stCreate, 4096))));
  for T := 0 to High(Topics) do
  begin
    Src := T;
    if Topics[T].Same >= 0 then
      Src := Topics[T].Same;
    New(Topic, Init);
    for K := 0 to High(ParaText[Src]) do
    begin
      New(P);
      P^.Size := Length(ParaText[Src][K]);
      GetMem(P^.Text, P^.Size + 1);
      if P^.Size > 0 then
        Move(ParaText[Src][K][1], P^.Text^, P^.Size);
      P^.Text[P^.Size] := 0;
      P^.Wrap := ParaWrap[Src][K];
      P^.Next := nil;
      Topic^.AddParagraph(P);
    end;
    for K := 0 to High(Refs[Src]) do
    begin
      if Refs[Src][K].Topic < 0 then
        Continue;
      C.Ref := Topics[Refs[Src][K].Topic].Number;
      C.Offset := Refs[Src][K].Offset;
      C.Length := Refs[Src][K].Length;
      Topic^.AddCrossRef(C);
    end;
    HF^.RecordPositionInIndex(Topics[T].Number);
    HF^.PutTopic(Topic);
    Dispose(Topic, Done);
  end;
  Dispose(HF, Done);
end;

procedure WriteConstants;
var
  F: TextFile;
  T: Integer;
begin
  AssignFile(F, ConstName);
  Rewrite(F);
  Writeln(F, '{ made by tvhc from ', ExtractFileName(InName), ' }');
  Writeln(F, 'const');
  for T := 0 to High(Topics) do
    Writeln(F, '  hc', Topics[T].Name, ' = ', Topics[T].Number, ';');
  CloseFile(F);
end;

var
  I, N: Integer;
begin
  N := 0;
  for I := 1 to ParamCount do
  begin
    { an option: -x, or /x without more slashes (a path on Unix begins with a slash too) }
    if (ParamStr(I) <> '') and ((ParamStr(I)[1] = '-') or ((ParamStr(I)[1] = '/') and (Pos('/', Copy(ParamStr(I), 2, MaxInt)) = 0))) then
      Continue;
    Inc(N);
    case N of
      1: InName := ParamStr(I);
      2: OutName := ParamStr(I);
      3: ConstName := ParamStr(I);
    end;
  end;
  if (InName = '') or (OutName = '') then
  begin
    Writeln('usage: tvhc INPUT.HTX OUTPUT.HLP [CONSTANTS.PAS] [options]');
    Halt(1);
  end;
  RegisterType(RHelpTopic);
  RegisterType(RHelpIndex);
  ReadText;
  ResolveRefs;
  if Errors > 0 then
  begin
    Writeln(StdErr, Errors, ' error(s): the help file is not written');
    Halt(1);
  end;
  WriteHelp;
  if ConstName <> '' then
    WriteConstants;
  Writeln(Length(Topics), ' topics, ', OutName);
end.
