{ DNRun: runs an external program from DN (an own unit; it replaces the DN.COM loader of the DPMI32 build, which shuts the
  application down, lets the loader run the command and starts DN again with the saved desktop). Here the application stays
  alive: the screen goes to the text mode (cleared), the program runs through COMMAND.COM, a key returns to DN and the caller
  redraws the application. On Unix: the terminal is given to /bin/sh -c for the command (SysRunShell), Enter returns. A terminal inside DN (as in far2l, F4: tvterm of
  magiblot ported on tv/) is in PLAN.md. }
{$mode objfpc}{$H-}
unit DNRun;

interface

procedure RunExternal(const CmdLine: String);

implementation

uses
  SysUtils, Dos{$IFDEF GO32V2}, go32{$ENDIF}, VPSysLow, DNErrLog;

procedure RunExternal(const CmdLine: String);
{$IFDEF GO32V2}
var
  R: Registers;
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
  SysRunShell(CmdLine);      { Unix: the terminal is given to the shell for the command }
{$ENDIF}
end;

end.
