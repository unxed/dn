{ OSRun: starting programs and restarting DN: the stable facade used by the DN compatibility layer (osdep). The code of a target is in
  OSRunUnix, OSRunWindows or OSRunDos.
  MIT, see LICENSE. }
unit OSRun;

{$mode objfpc}
{$H-}

interface

{ Runs a command line in the shell of the system and waits, then waits for Enter (the user runs a command): the status as of waitpid, -1 if it could not be run. }
function RunShell(const CmdLine: string): LongInt;
{ Runs a command line in the shell of the system and waits, without touching the screen or the terminal (a filter that DN runs for itself: a decompressor into
  a temporary file): the status as of RunShell, -1 if it could not be run (and on DOS, where DN has no such filters). }
function RunQuiet(const CmdLine: string): LongInt;
{ Runs a program (the DOS way: Path and Args, "/c command" for COMSPEC) and waits: the DOS error code, 0 = it was run. }
function Execute(Path, Args: PChar): LongInt;
{ Replaces the current process with DN and its original arguments, or starts a new DN process on other targets. }
procedure RestartSelf;

implementation

uses
{$IFDEF GO32V2}
  OSRunDos;
{$ELSE}
{$IFDEF WINDOWS}
  OSRunWindows;
{$ELSE}
  OSRunUnix;
{$ENDIF}
{$ENDIF}

function RunShell(const CmdLine: string): LongInt;
begin
  Result := BackendRunShell(CmdLine, True);
end;

function RunQuiet(const CmdLine: string): LongInt;
begin
  Result := BackendRunQuiet(CmdLine);
end;

function Execute(Path, Args: PChar): LongInt;
begin
  Result := BackendExecute(Path, Args);
end;

procedure RestartSelf;
begin
  BackendRestartSelf;
end;

end.
