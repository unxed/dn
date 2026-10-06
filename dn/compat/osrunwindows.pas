{ OSRunWindows: starting programs and restarting DN on Windows (the backend of the facade OSRun).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  This unit is our own code (MIT, see LICENSE). }
unit OSRunWindows;

{$mode objfpc}
{$H-}

interface

{ Runs a command line in the shell and waits; Pause: wait for Enter after it (the user runs a command and wants to see its output). The status of waitpid
  (the exit code is in the second byte), -1 if it could not be run. }
function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
{ DOS error code of running a program (0 = it was run). }
function BackendExecute(Path, Args: PChar): LongInt;
procedure BackendRestartSelf;

implementation

uses
  SysUtils, TvUnix, DNErrLog;

function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
begin
  UnixSuspend;
  Writeln;
  Writeln('> ', CmdLine);
  Flush(Output);
  try
    Result := ExecuteProcess(GetEnvironmentVariable('COMSPEC'), '/c ' + CmdLine);
  except
    Result := -1;
  end;
  if Pause and UnixActive then
  begin
    Writeln;
    Write('[DN] Press Enter to return...');
    Flush(Output);
    Readln;
  end;
  UnixResume;
  if Result > 0 then
    Result := Result shl 8;        { as the status of waitpid on Unix: the exit code is in the second byte }
end;

function BackendExecute(Path, Args: PChar): LongInt;
var
  R: LongInt;
begin
  { through the shell (COMSPEC), with the terminal: the program may write to it and read from it }
  R := BackendRunShell('"' + StrPas(Path) + '" ' + StrPas(Args), True);
  Result := 0;
  if (R < 0) or ((R shr 8) = 127) or (R = 9009) then
    Result := 2;                   { the shell could not run it: DOS "file not found" }
end;

procedure BackendRestartSelf;
var
  Strs: array of AnsiString;
  I: Integer;
begin
  DNTrace('RestartSelf: ' + ParamStr(0));
  SetLength(Strs, ParamCount);
  for I := 1 to ParamCount do
    Strs[I - 1] := ParamStr(I);
  ExecuteProcess(ParamStr(0), Strs);
end;

end.
