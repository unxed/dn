{ OSRunUnix: starting programs and restarting DN on Unix (the backend of the facade OSRun).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  This unit is our own code (MIT, see LICENSE). }
unit OSRunUnix;

{$mode objfpc}
{$H-}

interface

{ Runs a command line in the shell and waits; Pause: wait for Enter after it (the user runs a command and wants to see its output). The status of waitpid
  (the exit code is in the second byte), -1 if it could not be run. }
function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
{ DOS error code of running a program (0 = it was run). }
{ Runs a command line in the shell and waits; no screen, no pause. The status as BackendRunShell, -1 if it could not be run. }
function BackendRunQuiet(const CmdLine: string): LongInt;
function BackendExecute(Path, Args: PChar): LongInt;
procedure BackendRestartSelf;

implementation

uses
  SysUtils, BaseUnix, Unix, TvUnix, OSNamesUnix, DNErrLog;

function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
begin
  UnixSuspend;
  Writeln;
  Writeln('$ ', CommandLineToOs(CmdLine));
  Flush(Output);
  Result := fpSystem(CommandLineToOs(CmdLine));
  if Pause and UnixActive then
  begin
    Writeln;
    Write('[DN] Press Enter to return...');
    Flush(Output);
    Readln;
  end;
  UnixResume;
end;

function BackendRunQuiet(const CmdLine: string): LongInt;
begin
  Result := fpSystem(CommandLineToOs(CmdLine));
end;

function BackendExecute(Path, Args: PChar): LongInt;
var
  R: LongInt;
  A: string;
begin
  DNLog('Execute: [' + StrPas(Path) + '] [' + StrPas(Args) + ']');
  { through the shell, with the terminal: the program may write to it and read from it }
  A := StrPas(Args);
  { DN starts its helpers (the archivers) the DOS way: the program is COMSPEC and the arguments are "/c command". COMSPEC is not set
    on Unix (Path is empty), so the command goes to the shell of the system as it is, without a pause for Enter. }
  if (Length(A) >= 3) and (A[1] = '/') and (UpCase(A[2]) = 'C') and (A[3] = ' ') then
    R := BackendRunShell(Copy(A, 4, MaxInt), False)
  else
    R := BackendRunShell('"' + StrPas(Path) + '" ' + A, True);
  Result := 0;
  if (R < 0) or ((R shr 8) = 127) or (R = 9009) then
    Result := 2;                   { the shell could not run it: DOS "file not found" }
  DNLog('Execute: status ' + IntToStr(R) + ', DOS error ' + IntToStr(Result));
end;

procedure BackendRestartSelf;
var
  Strs: array of AnsiString;
  Args: array of PAnsiChar;
  I: Integer;
begin
  DNTrace('RestartSelf: ' + ParamStr(0));
  SetLength(Strs, ParamCount + 1);
  SetLength(Args, ParamCount + 2);
  for I := 0 to ParamCount do
  begin
    Strs[I] := ParamStr(I);
    Args[I] := PAnsiChar(Strs[I]);
  end;
  Args[ParamCount + 1] := nil;
  fpExecve(PAnsiChar(Strs[0]), @Args[0], envp);
  DNTrace('RestartSelf: exec failed, errno ' + IntToStr(fpGetErrno));
end;

end.
