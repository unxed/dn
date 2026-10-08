{ OSStartScreen: the text screen of the program that started DN (DOS): copied at the start, before the application takes the screen over.
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  MIT, see LICENSE. }
unit OSStartScreen;

{$mode objfpc}
{$H-}

interface

var
  { the text screen of the program that started DN (16-bit cells: character + attribute), copied before the application takes
    the screen over: the "user screen" of DN (Ctrl-O, Alt-F5) and what is seen after the exit; empty elsewhere }
  SysStartScreen: array of Word;
  SysStartScreenWidth: Integer = 0;
  { the cursor of that screen as the BIOS keeps it (0040:0050): low byte the column, high byte the row; 0 elsewhere }
  SysStartCursor: Word = 0;

implementation

{$IFDEF GO32V2}
uses
  go32;

{ The program takes over the screen at the start (DN reads the size of the screen before it creates the application; the
  application of TV needs the screen of TvScreen to be there). Other targets: their backends do the same. }
procedure GrabStartScreen;
var
  Rows: Byte;
  Cols: Word;
begin
  dosmemget($40, $84, Rows, 1);
  dosmemget($40, $4A, Cols, 2);
  Inc(Rows);
  if (Cols = 0) or (Cols > 255) or (Rows < 2) or (Rows > 100) then
    Exit;
  SetLength(SysStartScreen, Cols * Rows);
  dosmemget($B800, 0, SysStartScreen[0], Cols * Rows * 2);
  SysStartScreenWidth := Cols;
  dosmemget($40, $50, SysStartCursor, 2);
end;

initialization
  GrabStartScreen;
{$ENDIF}

end.
