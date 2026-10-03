{ DNRun: runs an external program from DN (an own unit; it replaces the DN.COM loader of the DPMI32 build, which shuts the
  application down, lets the loader run the command and starts DN again with the saved desktop). Here the application stays
  alive: the screen goes to the text mode (cleared), the program runs through COMMAND.COM, a key returns to DN and the caller
  redraws the application. On Linux the command runs on a pty on the whole screen through the emulator of tv/ (TvVtRun: the keys go to the command, the screen
  stays as the user screen, Ctrl-O shows it: UserScr); DN_EMBED_TERM=0 gives the terminal to /bin/sh -c as before (SysRunShell), Enter returns. DN_RUN_PAUSE: what
  happens when the command ends: 1 (default) "Press Enter", 0 back to the panels at once, 2 the pause only when the status is not 0. }
{$mode objfpc}{$H-}
unit DNRun;

interface

{$IFDEF LINUX}
uses
  TvVt;

var
  UserScr: TVtEmu;             { the screen of the user: what the commands drew (zeroed until the first command) }
{$ENDIF}

procedure RunExternal(const CmdLine: String);

implementation

uses
  SysUtils, Dos{$IFDEF GO32V2}, go32{$ENDIF}, VPSysLow, DNErrLog{$IFDEF LINUX}, TvVtRun{$ENDIF};

{$IFDEF LINUX}
function CurDir: AnsiString;
begin
  Result := GetCurrentDir;
end;
{$ENDIF}

procedure RunExternal(const CmdLine: String);
{$IFDEF GO32V2}
var
  R: Registers;
{$ENDIF}
{$IFDEF LINUX}
var
  P: Integer;
{$ENDIF}
begin
{$IFDEF GO32V2}
  R.ax := $0003;                  { the text mode 80x25: the screen is cleared }
  Intr($10, R);
  Writeln(CmdLine);
  DNTrace('RunExternal: exec ' + CmdLine);
  SwapVectors;
  Exec(GetEnv('COMSPEC'), '/c ' + CmdLine);
  SwapVectors;
  DNTrace('RunExternal: back, DosError ' + IntToStr(DosError));
  Writeln;
  Write('Press any key to return to DN...');
  { INT 16h, AH = 0: wait for a key (not in the test runs with DNDUMP: no one presses it, the keys of DNKEYS are put in by the
    idle loop that does not run here) }
  if GetEnv('DNDUMP') = '' then
  begin
    R.ax := $0000;
    Intr($16, R);
  end;
{$ELSE}
{$IFDEF LINUX}
  if GetEnvironmentVariable('DN_EMBED_TERM') <> '0' then
  begin
    { the pause: DN_RUN_PAUSE 0 never, 1 always (default), 2 when the status is not 0 }
    P := 1;
    if GetEnvironmentVariable('DN_RUN_PAUSE') = '0' then P := 0
    else if GetEnvironmentVariable('DN_RUN_PAUSE') = '2' then P := 2;
    VtRunScreen(UserScr, '/bin/sh', ['sh', '-c', SysNameToOs(CmdLine)], '', CurDir + '$ ' + SysNameToOs(CmdLine), P);
    Exit;
  end;
{$ENDIF}
  SysRunShell(CmdLine);      { Unix: the terminal is given to the shell for the command }
{$ENDIF}
end;

end.
