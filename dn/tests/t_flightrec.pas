program t_flightrec;
{ Tests of src/flightrec.pas (the flight recorder): the log of a run, its rotation, the masking of typed characters, the report of a crash. }
{$mode objfpc}{$H-}
uses SysUtils, Classes, TvEvents, TvKeys, FlightRec, evnames;
{$I dntest.inc}

function Slurp(const Name: string): AnsiString;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(Name) then
    Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(Name);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

function Dn(const OsPath: string): string;           { a path of the system as a path of DN }
var
  I: Integer;
begin
  Result := OsPath;
  for I := 1 to Length(Result) do
    if Result[I] = '/' then
      Result[I] := '\';
end;

function StateOfTest: AnsiString;
begin
  Result := 'panel left: \home\x' + LineEnding + 'panel right: \tmp' + LineEnding;
end;

function StateThatFails: AnsiString;
begin
  raise Exception.Create('broken');
end;

var
  Root, Os, Report: string;
  Log: AnsiString;
  E: TEvent;
begin
  Root := GetTempDir + 't_flightrec_' + IntToStr(GetProcessID) + '/';
  ForceDirectories(Root);
  Os := Dn(Root);

  { names of the commands and keys }
  Check(CommandName(1) = 'cmQuit', 'the name of the command 1 is cmQuit');
  Check(KeyCodeName(kbF5) = 'kbF5', 'the name of the key F5 is kbF5');
  Check(KeyCodeName($1234) = '', 'a key code without a name has an empty name');

  { a run: facts and events go to the log at once }
  FRStart(Os, 'DN test build');
  FRFact('terminal', 'xterm');
  FRNote('run', 'ls -l');
  Log := Slurp(Root + 'dn.log');
  Check(Pos(' start ', Log) > 0, 'the log starts with the line "start"');
  Check(Pos('DN test build', Log) > 0, 'the banner is in the log');
  Check(Pos('fact terminal=xterm', Log) > 0, 'a fact is in the log');
  Check(Pos(' run ls -l', Log) > 0, 'an event is in the log at once (it is not buffered)');

  FRNote('run', 'again'); FRNote('run', 'again'); FRNote('run', 'again');
  Check(Pos('x3', FRRecent(10)) > 0, 'the same event repeated is counted');

  { the typed characters are not recorded }
  FillChar(E, SizeOf(E), 0);
  E.What := evKeyDown;
  E.Text[0] := 's'; E.Text[1] := 'e'; E.TextLength := 1;
  E.KeyCode := $1F73;
  FRNoteEvent(E);
  Check(Pos('<char>', FRRecent(1)) > 0, 'a typed character is masked');
  Check(Pos('''s''', FRRecent(1)) = 0, 'a typed character is not in the log');
  FillChar(E, SizeOf(E), 0);
  E.What := evKeyDown;
  E.KeyCode := kbF5;
  FRNoteEvent(E);
  Check(Pos('kbF5', FRRecent(1)) > 0, 'a named key is recorded by its name');
  FillChar(E, SizeOf(E), 0);
  E.What := evCommand;
  E.Command := 1;
  FRNoteEvent(E);
  Check(Pos('cmQuit', FRRecent(1)) > 0, 'a command is recorded by its name');
  FillChar(E, SizeOf(E), 0);
  E.What := evMouseMove;
  FRNoteEvent(E);
  Check(Pos('mouse', FRRecent(1)) = 0, 'a move of the mouse is not an event of the log');

  { a crash: the report }
  FRAddState('panels', @StateOfTest);
  FRAddState('broken one', @StateThatFails);
  Report := FRCrash('EAccessViolation', 'test crash');
  Check(Report <> '', 'FRCrash returns the name of the report');
  Log := Slurp(Root + 'crash/crash001.txt');
  Check(Pos('Exception EAccessViolation: test crash', Log) > 0, 'the report names the exception');
  Check(Pos('terminal=xterm', Log) > 0, 'the report has the facts');
  Check(Pos('panel left: \home\x', Log) > 0, 'the report has the state that a provider tells');
  Check(Pos('the provider failed', Log) > 0, 'a provider that fails does not spoil the report');
  Check(Pos(' run ls -l', Log) > 0, 'the report has the last events');
  Check(Pos('--- the screen', Log) > 0, 'the report has a place for the screen');

  { the end of a run and the next start: rotation }
  FRStop('test');
  Check(Pos(' exit test', Slurp(Root + 'dn.log')) > 0, 'a normal end is written');
  FRStart(Os, 'DN test build 2');
  Check(FileExists(Root + 'dn_prev.log'), 'the log of the run before is kept as dn_prev.log');
  Check(Pos(' exit test', Slurp(Root + 'dn_prev.log')) > 0, 'dn_prev.log is the run before');
  Check(Pos('did not end', Slurp(Root + 'dn.log')) = 0, 'no warning when the run before ended well');
  { this run is not ended: the next start tells }
  FRFact('x', 'y');
  FRReset;
  FRStart(Os, 'DN test build 3');
  Check(Pos('did not end', Slurp(Root + 'dn.log')) > 0, 'a run that was cut is told in the next log');
  FRStop('test');

  { DN_LOG=0 is looked at by the environment: no way to set it here, the case is in the Linux test }
  FRReset;
  DeleteFile(Root + 'dn.log'); DeleteFile(Root + 'dn_prev.log'); DeleteFile(Root + 'crash/crash001.txt');
  RemoveDir(Root + 'crash'); RemoveDir(Root);
  Finish;
end.
