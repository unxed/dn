{ FlightRec: the flight recorder of DN. What a person needs to hand over to have a fault that nobody can reproduce looked at: the key facts of the run,
  the last things that were done (the keys, the mouse clicks, the commands, the external programs, the file operations) and, at a crash, the details.

    <ConfigDir>/dn.log        the log of this run: one line per event, written at once (a hang or a kill leaves it); at the start the log of the
                              run before becomes dn_prev.log (a run that did not end with the line "exit" is told in the new log)
    <ConfigDir>/crash/crashNNN.txt   written at a crash: the exception and the call stack, the key facts, the state that the providers
                              (FRAddState) tell (the panels, the views), the last events, the text of the screen

  The typed characters are not recorded (they may be a password): the line says "<char>"; the keys that are named (F5, Ctrl+Q, Enter...) and the
  commands are. The environment variable DN_LOG_KEYS=full records the characters too (to be set for a hunt of a fault that needs them), DN_LOG=0 turns
  the file of the run off (a crash report is still written). Names of directories and of files appear in the facts and in the screen text: a person looks at the
  report before he hands it over.

  MIT (see LICENSE). }
unit FlightRec;

{$mode objfpc}
{$H-}
{$POINTERMATH ON}

interface

uses
  TvEvents;

type
  { The text (several lines) that tells the state of a part of the program at a crash: the call is in an exception handler, it must not fail but it is guarded. }
  TStateProvider = function: AnsiString;

{ Opens the log in LogDir (a path of DN with the backslash at the end; the directory is made if it is not there; '' keeps only the ring of the last events). Banner
  names the program and its build (the first line of the log and of a report). }
procedure FRStart(const LogDir, Banner: string);
{ The run ends: the line "exit" with Why, the log is closed. }
procedure FRStop(const Why: string);

{ A key fact of the run (the version, the terminal, the screen, the directory of the settings...): what is set again replaces the value. }
procedure FRFact(const Key, Value: string);
{ One event: Kind is a word (key, mouse, cmd, run, file, dir, dialog...), Text is short; the same event repeated is counted ("x3"), not repeated. }
procedure FRNote(const Kind, Text: string);
{ A key, a mouse click, a command of the event: the others are not interesting. }
procedure FRNoteEvent(const Event: TEvent);

{ The part of the state that a crash report tells; Name is the title. A provider may fail: it is guarded. }
procedure FRAddState(const Name: string; Provider: TStateProvider);
{ What is said about the place of an event ("in TFilePanel"): called for every command and key that is noted. nil: nothing. }
var
  FRContext: function: string = nil;

{ At a crash, in the handler of an exception: writes the report, returns its name (a path of DN), '' when it could not be written. }
function FRCrash(const ClassName, MessageText: string): string;

{ The last events as text, the oldest first (Max of them at most). For the report and for tests. }
function FRRecent(Max: Integer): AnsiString;
{ The facts as text: one line Key=Value each. }
function FRFacts: AnsiString;

{ The directory that the log and the reports go to ('' when the log is not started). }
function FRDir: string;

{ Clears the state and closes the log (tests). }
procedure FRReset;

implementation

uses DnPath,
  SysUtils, osdep, TvScreen, TvCell, evnames;

const
  RingSize = 300;                  { the events that a report keeps }
  MaxLogSize = 1024 * 1024;        { the log of the run is cut at this size: it becomes dn_prev.log and the new one starts with the facts }
  MaxCrashFiles = 20;

type
  TRingEntry = record
    Stamp: LongInt;                { ms since the start }
    Kind: string[10];
    Text: string[200];
    Count: LongInt;
  end;

  TProviderRec = record
    Name: string[40];
    Fn: TStateProvider;
  end;

  TFactRec = record
    Key: string[40];
    Value: string[200];
  end;

var
  Ring: array[0..RingSize - 1] of TRingEntry;
  RingHead: Integer = 0;           { the next place }
  RingCount: Integer = 0;
  Facts: array[0..63] of TFactRec;
  FactCount: Integer = 0;
  Providers: array[0..15] of TProviderRec;
  ProviderCount: Integer = 0;
  Dir: string = '';
  LogName: string = '';
  LogF: Text;
  LogOpen: Boolean = False;
  LogWanted: Boolean = True;
  KeysFull: Boolean = False;
  StartTick: QWord = 0;
  LogSize: LongInt = 0;
  InCrash: Boolean = False;
  Banner0: string = '';

function Stamp: LongInt;
begin
  Result := LongInt(GetTickCount64 - StartTick);
end;

{ the text of the log is for people: no control characters, bytes that are not UTF-8 are not a problem of this unit }
function Clean(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] < ' ' then
      Result[I] := '.';
end;

function Num(N: LongInt): string;
begin
  Str(N, Result);
end;

function StampText(Ms: LongInt): string;
begin
  Result := Num(Ms div 1000) + '.';
  if Ms mod 1000 < 100 then Result := Result + '0';
  if Ms mod 1000 < 10 then Result := Result + '0';
  Result := Result + Num(Ms mod 1000);
end;

procedure LogLine(const S: string);
begin
  if not LogOpen then
    Exit;
  {$I-}
  Writeln(LogF, S);
  Flush(LogF);
  if IOResult <> 0 then
    LogOpen := False;
  {$I+}
  Inc(LogSize, Length(S) + 1);
end;

function OsName(const DnName: string): string;
begin
  Result := SysOsPath(DnName);
end;

procedure OpenLog;
var
  Prev: string;
  F: file;
begin
  if (Dir = '') or not LogWanted then
    Exit;
  LogName := Dir + 'dn.log';
  Prev := Dir + 'dn_prev.log';
  { the rotation: the log of the run before stays as dn_prev.log }
  if FileExists(OsName(LogName)) then
  begin
    if FileExists(OsName(Prev)) then
      DeleteFile(OsName(Prev));
    RenameFile(OsName(LogName), OsName(Prev));
  end;
  {$I-}
  Assign(LogF, OsName(LogName));
  Rewrite(LogF);
  LogOpen := IOResult = 0;
  {$I+}
  LogSize := 0;
end;

procedure WriteFactsToLog;
var
  I: Integer;
begin
  for I := 0 to FactCount - 1 do
    LogLine('+' + StampText(Stamp) + ' fact ' + Facts[I].Key + '=' + Clean(Facts[I].Value));
end;

procedure RingAdd(const Kind, Text: string);
var
  Last: Integer;
begin
  if RingCount > 0 then
  begin
    Last := (RingHead + RingSize - 1) mod RingSize;
    if (Ring[Last].Kind = Kind) and (Ring[Last].Text = Copy(Text, 1, 200)) then
    begin
      Inc(Ring[Last].Count);
      Ring[Last].Stamp := Stamp;
      Exit;
    end;
  end;
  Ring[RingHead].Stamp := Stamp;
  Ring[RingHead].Kind := Copy(Kind, 1, 10);
  Ring[RingHead].Text := Copy(Text, 1, 200);
  Ring[RingHead].Count := 1;
  RingHead := (RingHead + 1) mod RingSize;
  if RingCount < RingSize then
    Inc(RingCount);
end;

procedure RotateIfBig;
var
  Prev: string;
begin
  if (not LogOpen) or (LogSize < MaxLogSize) then
    Exit;
  Close(LogF);
  LogOpen := False;
  Prev := Dir + 'dn_prev.log';
  if FileExists(OsName(Prev)) then
    DeleteFile(OsName(Prev));
  RenameFile(OsName(LogName), OsName(Prev));
  {$I-}
  Assign(LogF, OsName(LogName));
  Rewrite(LogF);
  LogOpen := IOResult = 0;
  {$I+}
  LogSize := 0;
  LogLine('+' + StampText(Stamp) + ' note the log of this run went on after dn_prev.log was cut at ' + Num(MaxLogSize) + ' bytes');
  WriteFactsToLog;
end;

procedure FRNote(const Kind, Text: string);
var
  S: string;
begin
  S := Clean(Text);
  RingAdd(Kind, S);
  if LogOpen then
  begin
    LogLine('+' + StampText(Stamp) + ' ' + Kind + ' ' + S);
    RotateIfBig;
  end;
end;

procedure FRFact(const Key, Value: string);
var
  I: Integer;
begin
  for I := 0 to FactCount - 1 do
    if Facts[I].Key = Key then
    begin
      if Facts[I].Value = Copy(Value, 1, 200) then
        Exit;
      Facts[I].Value := Copy(Value, 1, 200);
      LogLine('+' + StampText(Stamp) + ' fact ' + Key + '=' + Clean(Value));
      Exit;
    end;
  if FactCount > High(Facts) then
    Exit;
  Facts[FactCount].Key := Copy(Key, 1, 40);
  Facts[FactCount].Value := Copy(Value, 1, 200);
  Inc(FactCount);
  LogLine('+' + StampText(Stamp) + ' fact ' + Key + '=' + Clean(Value));
end;

function Hex2(B: Byte): string;
const
  D: string[16] = '0123456789ABCDEF';
begin
  Result := D[B shr 4 + 1] + D[B and 15 + 1];
end;

function Hex4(W: Word): string;
begin
  Result := Hex2(W shr 8) + Hex2(W and $FF);
end;

function KeyText(const E: TEvent): string;
var
  Name: string;
  I: Integer;
begin
  Name := KeyCodeName(E.KeyCode);
  if (Name <> '') and (E.TextLength <= 1) then
    Result := Name
  else if E.TextLength > 0 then
  begin
    if KeysFull then
    begin
      Result := '''';
      for I := 0 to E.TextLength - 1 do
        Result := Result + E.Text[I];
      Result := Result + '''';
    end
    else
      Result := '<char>';
    if Name <> '' then
      Result := Name + ' ' + Result;
  end
  else
    Result := '$' + Hex4(E.KeyCode);
  if E.ControlKeyState and $0F <> 0 then
  begin
    Result := Result + ' [';
    if E.ControlKeyState and 3 <> 0 then Result := Result + 'S';
    if E.ControlKeyState and 4 <> 0 then Result := Result + 'C';
    if E.ControlKeyState and 8 <> 0 then Result := Result + 'A';
    Result := Result + ']';
  end;
end;

procedure FRNoteEvent(const Event: TEvent);
var
  Where, Ctx, Name: string;
begin
  if (Event.What <> evKeyDown) and (Event.What <> evMouseDown) and (Event.What <> evCommand) then
    Exit;
  Ctx := '';
  if Assigned(FRContext) then
    try
      Ctx := FRContext();
    except
      Ctx := '?';
    end;
  if Ctx <> '' then
    Ctx := '  @ ' + Ctx;
  case Event.What of
    evKeyDown:
      FRNote('key', KeyText(Event) + Ctx);
    evMouseDown:
      begin
        Where := '(' + Num(Event.Where.X) + ',' + Num(Event.Where.Y) + ') buttons ' + Num(Event.Buttons);
        if Event.EventFlags and meDoubleClick <> 0 then
          Where := Where + ' double';
        FRNote('mouse', Where + Ctx);
      end;
    evCommand:
      begin
        Name := CommandName(Event.Command);
        if Name = '' then
          Name := '#' + Num(Event.Command)
        else
          Name := Name + ' #' + Num(Event.Command);
        FRNote('cmd', Name + Ctx);
      end;
  end;
end;

procedure FRAddState(const Name: string; Provider: TStateProvider);
begin
  if ProviderCount > High(Providers) then
    Exit;
  Providers[ProviderCount].Name := Copy(Name, 1, 40);
  Providers[ProviderCount].Fn := Provider;
  Inc(ProviderCount);
end;

function FRDir: string;
begin
  Result := Dir;
end;

function FRFacts: AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FactCount - 1 do
    Result := Result + Facts[I].Key + '=' + Facts[I].Value + LineEnding;
end;

function FRRecent(Max: Integer): AnsiString;
var
  I, N, At: Integer;
  S: string;
begin
  Result := '';
  N := RingCount;
  if N > Max then
    N := Max;
  for I := N - 1 downto 0 do
  begin
    At := (RingHead + RingSize - 1 - I) mod RingSize;
    S := '+' + StampText(Ring[At].Stamp) + ' ' + Ring[At].Kind + ' ' + Ring[At].Text;
    if Ring[At].Count > 1 then
      S := S + '  x' + Num(Ring[At].Count);
    Result := Result + S + LineEnding;
  end;
end;

{ the previous run ended without the line "exit": it was killed, hung or crashed without a report }
function PreviousEndedBadly(const PrevName: string): Boolean;
var
  F: TextFile;
  S, Last: string;
begin
  Result := False;
  if not FileExists(OsName(PrevName)) then
    Exit;
  Last := '';
  {$I-}
  Assign(F, OsName(PrevName));
  Reset(F);
  if IOResult <> 0 then
    Exit;
  while not Eof(F) do
  begin
    Readln(F, S);
    if S <> '' then
      Last := S;
  end;
  Close(F);
  {$I+}
  Result := (Last <> '') and (Pos(' exit ', Last + ' ') = 0);
end;

procedure FRStart(const LogDir, Banner: string);
var
  Bad: Boolean;
begin
  FRReset;
  StartTick := GetTickCount64;
  LogWanted := GetEnvironmentVariable('DN_LOG') <> '0';
  KeysFull := LowerCase(GetEnvironmentVariable('DN_LOG_KEYS')) = 'full';
  Dir := LogDir;
  if Dir <> '' then
  begin
    ForceDirectories(OsName(Dir));
    if not DirectoryExists(OsName(Dir)) then
      Dir := '';
  end;
  Bad := (Dir <> '') and PreviousEndedBadly(Dir + 'dn.log');
  OpenLog;
  LogLine('+0.000 start ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + Banner);
  Banner0 := Banner;
  if Bad then
    FRNote('note', 'the run before did not end with "exit": see dn_prev.log (killed, hung or crashed without a report)');
end;

procedure FRStop(const Why: string);
begin
  if LogOpen then
  begin
    LogLine('+' + StampText(Stamp) + ' exit ' + Clean(Why));
    Close(LogF);
    LogOpen := False;
  end;
end;

procedure FRReset;
begin
  if LogOpen then
  begin
    Close(LogF);
    LogOpen := False;
  end;
  RingHead := 0;
  RingCount := 0;
  FactCount := 0;
  Dir := '';
  LogName := '';
  LogSize := 0;
  InCrash := False;
  Banner0 := '';
end;

{ --- the report of a crash ------------------------------------------------------------------------------------------------ }

function PickCrashName(const CrashDir: string): string;
var
  I, Oldest: Integer;
  T, OldestT: LongInt;
  N: string;
begin
  Oldest := 1;
  OldestT := High(LongInt);
  for I := 1 to MaxCrashFiles do
  begin
    N := CrashDir + 'crash' + Copy(Num(1000 + I), 2, 3) + '.txt';
    if not FileExists(OsName(N)) then
      Exit(N);
    T := FileAge(OsName(N));
    if T < OldestT then
    begin
      OldestT := T;
      Oldest := I;
    end;
  end;
  Result := CrashDir + 'crash' + Copy(Num(1000 + Oldest), 2, 3) + '.txt';       { all are used: the oldest goes }
end;

procedure DumpScreen(var T: Text);
var
  Y, X, N, I: Integer;
  C: PScreenCell;
  Row: string;
  Len: Integer;
begin
  if (ScreenBuffer = nil) or (ScreenWidth <= 0) or (ScreenHeight <= 0) then
  begin
    Writeln(T, '(no screen)');
    Exit;
  end;
  for Y := 0 to ScreenHeight - 1 do
  begin
    Row := '';
    for X := 0 to ScreenWidth - 1 do
    begin
      C := ScreenBuffer + (Y * ScreenWidth + X);
      if C^.Character.Meta shr 4 and scTrail <> 0 then
        Continue;
      N := (C^.Character.Meta and $0F) + 1;
      if (N = 1) and (C^.Character.Text[0] < 32) then
        Row := Row + ' '
      else
        for I := 0 to N - 1 do
          Row := Row + Chr(C^.Character.Text[I]);
      if Length(Row) > 240 then
        Break;
    end;
    Len := Length(Row);
    while (Len > 0) and (Row[Len] = ' ') do
      Dec(Len);
    Writeln(T, Copy(Row, 1, Len));
  end;
end;

function FRCrash(const ClassName, MessageText: string): string;
var
  T: Text;
  Name, CrashDir: string;
  I: Integer;
  Fr: PPointer;
  S: AnsiString;
begin
  Result := '';
  if InCrash then
    Exit;
  InCrash := True;
  try
    FRNote('crash', ClassName + ': ' + MessageText);
    if Dir = '' then
      Exit;
    CrashDir := Dir + 'crash' + DnSep;
    ForceDirectories(OsName(CrashDir));
    Name := PickCrashName(CrashDir);
    {$I-}
    Assign(T, OsName(Name));
    Rewrite(T);
    if IOResult <> 0 then
      Exit;
    {$I+}
    Writeln(T, 'DN crash report');
    Writeln(T, '===============');
    Writeln(T, Banner0);
    Writeln(T, 'time ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), ', ', Num(Stamp), ' ms after the start');
    Writeln(T);
    Writeln(T, 'Exception ', ClassName, ': ', MessageText);
    Writeln(T, BackTraceStrFunc(ExceptAddr));
    Fr := ExceptFrames;
    for I := 0 to ExceptFrameCount - 1 do
      Writeln(T, BackTraceStrFunc(Fr[I]));
    Writeln(T);
    Writeln(T, '--- key facts');
    Write(T, FRFacts);
    for I := 0 to ProviderCount - 1 do
    begin
      Writeln(T);
      Writeln(T, '--- ', Providers[I].Name);
      try
        S := Providers[I].Fn();
        Write(T, S);
        if (S <> '') and (S[Length(S)] <> #10) then
          Writeln(T);
      except
        Writeln(T, '(the provider failed)');
      end;
    end;
    Writeln(T);
    Writeln(T, '--- the last events, the oldest first (the characters that were typed are not recorded)');
    Write(T, FRRecent(RingSize));
    Writeln(T);
    Writeln(T, '--- the screen');
    DumpScreen(T);
    Close(T);
    Result := Name;
    LogLine('+' + StampText(Stamp) + ' crash report ' + Name);
  except
    Result := '';
  end;
end;


{ at the end of the program, whatever way: the line "exit" (Halt, a runtime error that the handlers did not catch) }
procedure AtExit;
var
  Why: string;
begin
  if not LogOpen then
    Exit;
  if InCrash then
    Why := 'after a crash'
  else if ErrorAddr <> nil then
    Why := 'runtime error ' + Num(ExitCode)
  else
    Why := 'code ' + Num(ExitCode);
  FRStop(Why);
end;

initialization
  AddExitProc(@AtExit);

end.
