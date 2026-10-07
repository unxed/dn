{/////////////////////////////////////////////////////////////////////////
//
//  Dos Navigator Open Source 1.51.08
//  Based on Dos Navigator (C) 1991-99 RIT Research Labs
//
//  This programs is free for commercial and non-commercial use as long as
//  the following conditions are aheared to.
//
//  Copyright remains RIT Research Labs, and as such any Copyright notices
//  in the code are not to be removed. If this package is used in a
//  product, RIT Research Labs should be given attribution as the RIT Research
//  Labs of the parts of the library used. This can be in the form of a textual
//  message at program startup or in documentation (online or textual)
//  provided with the package.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//  1. Redistributions of source code must retain the copyright
//     notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//  3. All advertising materials mentioning features or use of this software
//     must display the following acknowledgement:
//     "Based on Dos Navigator by RIT Research Labs."
//
//  THIS SOFTWARE IS PROVIDED BY RIT RESEARCH LABS "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
//  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The licence and distribution terms for any publically available
//  version or derivative of this code cannot be changed. i.e. this code
//  cannot simply be copied and put under another distribution licence
//  (including the GNU Public Licence).
//
//////////////////////////////////////////////////////////////////////////}
{$I STDEFINE.INC}
{.$I ZCONF.INC}
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}

program DN;


{Cat: plugin support methods changed, so this chunk
      is commented out; keeping the old code for now}

uses

  DNErrLog, DNRun, Drivers, Lfn, uselfn,
  boot, Dos, mainapp,
  Menus, panelroot, filepanel, FileCopy, Filediz, Filelst, Eraser,
  DiskInfo, basics, strutil, fileutil, winsess, highlite,
  Startup, Dialogs, gadgets, panelwin, Messages, HistList,
  FileFind, Commands, Tree, FViewer, CmdLine, copyio, DNStdDlg,
  FilesCol, UserMenu, Colors, editcore, Editor, Macro,
  ArcView, HelpFile, Validate, ASCIITab, timeutil, Drives, Archiver,
  ArchSet, ArchDet, Setups, DNUtil, panelwinx, histories, calcline,
  DnIni, Collect, objutil, Views, Scroller, evaluator,
  HelpKern, VideoMan
  , calcwin, CellsCol 
  , DBView, DBWatch 
  
  , Tetris 
  , PrintMan 
  , Calendar  {JO}
  , Phones 
  , Idlers 
  , ColorSel, ColorVGA
  
  , SysUtils 
  
 , osdep, dnscreen, fatalerr, FlightRec, TvScreen
 , realmode 
  ;



{&Delphi+}
var
  E: Exception;
  FileName: ShortString;
  LineNo: LongInt;
  DNErrFile: Text;
  CrashFile: String;
  Lines: array[0..11] of String;

  

{ The text of a fatal error on the screen: put into the copy of the cells that dnscreen keeps (the way everything else is drawn), so it needs neither the
  position of the cursor nor the way the terminal ends a line. }
procedure FatalScreen(const Lines: array of String);
var
  Cells: PWord;
  X, Y: Integer;
  S: String;
begin
  if (ScreenWidth <= 0) or (ScreenHeight <= 0) then
    Exit;
  Cells := PWord(ReadScreenCells);
  if Cells = nil then
    Exit;
  for Y := 0 to High(Lines) do
  begin
    if Y >= ScreenHeight then
      Break;
    S := Lines[Y];
    for X := 0 to ScreenWidth - 1 do
      if X < Length(S) then
      begin
        if Byte(S[X + 1]) in [32..126] then
          Cells[Y * ScreenWidth + X] := $0700 or Byte(S[X + 1])
        else
          Cells[Y * ScreenWidth + X] := $073F;        { a character that is not plain ASCII: ? }
      end
      else
        Cells[Y * ScreenWidth + X] := $0720;
  end;
  WriteScreenCells(0, ScreenWidth * ScreenHeight);
  SetCaretSize(0);
end;

begin

{CtrlBreakHandler := TVCtrlBreak;
SysCtrlSetCBreakHandler;}

{ GetMem returns nil instead of raising an exception when there is no memory (DN asks for big buffers and checks the answer) }
ReturnNilIfGrowHeapFails := True;

try
  {Init09Handler;}
  {Cat: on exit, check how much memory was used;
      create a log of all Load and Store method calls}
  begin
 
  StartRecorder;
  RUN_IT;
  if RestartPending then
    RestartSelf;
 
  end
  {/Cat}
except
  on E: EControlC do
    begin
    {This is not really Ctrl-C, but Close via the button,
       system menu, or task list. Ctrl-Break / Ctrl-C
       are handled in killer and never reach here.}
    CloseWriteStream;
    end;
  on E: Exception do
    begin
    { the report first: the screen is still what the user saw (flightrec.pas: the key facts, the last events, the state, the screen) }
    CrashFile := FRCrash(E.ClassName, E.Message);
    DNErrLog.DNTraceException(E.ClassName, E.Message);
    CloseWriteStream;
    if CrashFile = '' then
      begin
      { no directory for the log (it could not be made): the old way, a short text next to the settings }
      CrashFile := ConfigDir+'dn.err';
{$I-}
      Assign(DNErrFile, SysOsPath(CrashFile));
      ClrIO;
      Append(DNErrFile);
      if IOResult <> 0 then
        Rewrite(DNErrFile);
      Writeln(DNErrFile, '');
      Writeln(DNErrFile, 'DN/2 ' + VersionName + ' build '+VersionRev+' compiled '+VersionDate);
      Writeln(DNErrFile, E.Message);
      if GetLocationInfo(ExceptAddr, FileName, LineNo) <> nil then
        Writeln(DNErrFile, 'Source location: '+FileName+' line ', LineNo)
      else
        Writeln(DNErrFile, 'Exception at addr '+IntToHex(PtrUInt(ExceptAddr), 8));
      Close(DNErrFile);
{$I+}
      end;
    ClearScreen;
    Lines[0] := 'Fatal Error';
    Lines[1] := '-----------';
    Lines[2] := '';
    Lines[3] := 'Exception 0' + Hex2(ExitCode) + 'h at address ' + Hex8(LongInt(ExceptAddr));
    Lines[4] := E.Message;
    if GetLocationInfo(ExceptAddr, FileName, LineNo) <> nil then
      Lines[5] := 'Source location: ' + FileName + ' line ' + IntToStr(LineNo)
    else
      Lines[5] := '';
    Lines[6] := '';
    Lines[7] := 'Please report to https://github.com/unxed/dn';
    Lines[8] := 'and attach the file';
    Lines[9] := CrashFile;
    Lines[10] := '';
    Lines[11] := 'Press any key...';
    FatalScreen(Lines);
    WaitForKey;
    end;
end;
 {LINEPOSIT}

(*{$ENDIF PLUGIN}*)

remove_i24;
RemoveDpmi32Exceptionhandlers;


end.
