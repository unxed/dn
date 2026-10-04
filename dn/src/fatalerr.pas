{ fatalerr: what the program needs at the screen of a fatal error (dn.pas): the place of the address of the exception in the sources,
  and the wait for a key. They were a part of the layer of Virtual Pascal (GetLocationInfo, SysKeyPressed, SysReadKey). Our own
  code (MIT, see LICENSE). }
unit fatalerr;

{$mode objfpc}
{$H-}

interface

{ The place in the source of an address (VP: from the debug information); here the line information of FPC (the units are
  compiled with -gl): the routine with the file and the line as the runtime prints it, in FileName; nil if there is none. }
function GetLocationInfo(Addr: Pointer; var FileName: ShortString; var LineNo: LongInt): Pointer;

{ Waits for a key and swallows it. A test aid: with DNDUMP set the key is "pressed" after 3 seconds, so that a test run ends and its
  files are closed (DOS keeps the data of a file that is not closed only in memory). }
procedure WaitForKey;

implementation

uses
  SysUtils, TvEvents, TvSys, LineInfo;

function GetLocationInfo(Addr: Pointer; var FileName: ShortString; var LineNo: LongInt): Pointer;
var
  Func: ShortString;
begin
  FileName := '';
  LineNo := 0;
  Result := nil;
  Func := ShortString(BackTraceStrFunc(Addr));       { '  $0001FF3  ROUTINE,  line 12 of file.pas' }
  if (Func <> '') and (Pos('line', Func) > 0) then
  begin
    FileName := Func;
    LineNo := 0;
    Result := Addr;
  end;
end;

procedure WaitForKey;
var
  E: TEvent;
  Start: QWord;
  Auto: Boolean;
begin
  Auto := GetEnvironmentVariable('DNDUMP') <> '';
  Start := GetTickCount64;
  repeat
    Sleep(20);
    TvSys.PollEvent(0, E);
    if Auto and (GetTickCount64 - Start > 3000) then
      Exit;
  until E.What = evKeyDown;
end;

end.
