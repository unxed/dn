{ OSRunDos: starting programs and restarting DN on DOS (the backend of the facade OSRun).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new. }
unit OSRunDos;

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
  SysUtils, Dos, DNErrLog
{$IFNDEF DNUTF8}, OSNamesDos{$ENDIF};

function BackendRunShell(const CmdLine: string; Pause: Boolean): LongInt;
begin
  Result := -1;                    { DN runs the commands of the user by itself on DOS (DNRun) }
end;

function BackendExecute(Path, Args: PChar): LongInt;
var
  P: string;
begin
  P := StrPas(Path);
{$IFNDEF DNUTF8}
  P := DosNameToUtf8(P);           { the names go to the DOS in UTF-8 when the provider DOS-UTF8/NAMES is on (the build with the code page inside) }
{$ENDIF}
  Dos.DosError := 0;
  Dos.Exec(P, StrPas(Args));
  Result := Dos.DosError;          { 0 = the program was run; its exit code is Dos.DosExitCode }
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
