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
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}
{&Delphi+}
unit filepanel;

interface

uses
  Defines, Streams, Views, Drivers, FilesCol,
  panelroot, Collect, topview
  ;

type
  TFilePanel = class;

  TFilePanel = class(TFilePanelRoot)
    procedure Draw; override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure HandleEvent(var Event: TEvent); override;
    function GetPalette: TPalette; override;
    procedure DrawTop(var B: TScreenCell); virtual;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  TPanelBottomDnD = record
    TotalY, SelectedY, CurrentY1, CurrentY2: Byte;
    end;

const
  MaxFooterHeight = 4;

type
  TInfoView = class;
  TFooterProc = function(IV: TInfoView): Boolean;
    { Procedure that forms (part of) a footer line. For each
    line several such procedures may be given; they are called
    in order.
      Result True means line formation is finished and
    subsequent procedures are not called. }
  TInfoView = class(TView)
    Panel: TFilePanel;
    DnD: TPanelBottomDnD;
    LineMaker: array[0..MaxFooterHeight] of array[0..6] of TFooterProc;
      {` For each footer line, starting from the separator,
       the sequence of procedures that form that line.
       Each sequence ends with nil.`}
    constructor Create(const R: TRect); overload;
    procedure Compile(Value: Word;
      FullProc, BriefProc: TFooterProc);
    procedure CompileShowOptions;
    procedure Draw; override;
    {AK155: This method has two important side effects:
        according to settings it sets its Size.Y and
        fills DnD with coordinates of lines from which D&D is possible.
        The first is used in TFilePanelRoot.ChangeBounds,
        the second in HandleEvent}
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    procedure Write(Os: opstream); override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    end;

  TDirView = class;
  TDirView = class(TTopView)
    procedure HandleEvent(var Event: TEvent); override;
    function GetText(MaxWidth: Integer): String; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  TDriveLine = class;
  {`2 }
  TDriveLine = class(TView)
    Panel: TFilePanel;
    DriveLine: String[29];
    ViewLine: String[60];
    CharDelta: AInt;
    LogDrvMap: LongInt; {Cat}
    constructor Create(const R: TRect; APanel: TFilePanel); overload;
    procedure MakeDriveLine;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Draw; override;
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    procedure Write(Os: opstream); override;
    procedure Refresh; {Cat}
    procedure Update; override;
     {` AK155 18.03.2005 Previously the disk-line auto-update setting
     only took effect at load. That was because
     when changing this setting it is hard to "from outside" include disk bars
     of all panels into the auto-update list (RegisterToBackground).
       Now I did it simply, though crookedly: RegisterToBackground
     is done at creation and forever, and Update actually does
     polling and updating only when the setting is on. `}
    procedure ShiftLetter(d: Integer);
      {` Shift Panel^.DriveLetter right (d=1) or left (d=-1),
        cyclically. `}
    end;
    {`}

const
  CPanel = #6#7#8#9#10#32#33#34#35#36#37#38#39#40#44#45#46#47#48; {JO}
  CTopView = #11#12;
  CInfoView = #25#26#27#28#29#30#31#49#50;
  CDriveLine = #41#42#43;

(* AK155 16.05.05
   I did not understand why these definitions are needed here at all, since
panelroot is in the interface uses and all these variables are visible
without any tricks. And doubly I did not understand why they had to be placed
in the interface with types differing from the originals
(like Pointer instead of PFilesPanelRoot), because after that in other
units the type of these variables depends on the order of
panelroot and filepanel in their uses. So I am throwing this section out.
var
  ActivePanel: Pointer absolute panelroot.ActivePanel;
  PassivePanel: Pointer absolute panelroot.PassivePanel;
  CtrlWas: Boolean absolute panelroot.CtrlWas;
  DirsToChange: array[0..9] of PString absolute panelroot.DirsToChange;
var
  CurrentDirectory: String absolute panelroot.CurrentDirectory;
/AK155 *)

implementation

uses TvEvents, DnPath,
  uselfn, osdep, Dos, Eraser, Drives, DNHelp, TitleSet,
  Lfn, DNUtil, mainapp, basics, strutil, DNUtf8, fileutil, envutil, Startup, FileCopy, Messages, Menus, DiskInfo, Dialogs, Commands,
  HistList, Tree, copyio, ArcView, CmdLine, histories, Archiver,
  gadgets, progress, FileFind, paneldlgs, DnIni, panelwinx, panelwin, Filediz, TvGlyphs
  
  , UUCode
   {, Crt}
  , timeutil
  , panelsetup, Math
  
  
  ;

{ A key that types a character: of the code page (CharCode), or in the build DNUTF8 a character outside the page (the UTF-8 text of the event) }
function IsTypedChar(const Event: TEvent): Boolean;
  begin
  Result := (Char(Event.KeyDown.CharScan.CharCode) >= #32) and (Char(Event.KeyDown.CharScan.CharCode) <= #254);
{$IFDEF DNUTF8}
  if (not Result) and (Event.KeyDown.TextLength > 0) and (Byte(Event.KeyDown.Text[0]) >= $80) then
    Result := True;
{$ENDIF}
  end;

var
  QSLastSuccessPos: Integer;
    {` Last successful quick-search position. This is our own
    (for quick search) copy of LastSuccessPos, which may change
    as a result of other mask matches (for example, during
    panel auto-update). `}

constructor TDriveLine.Create(const R: TRect; APanel: TFilePanel);
  begin
  inherited Create(R);
  Panel := APanel;
  EventMask := evMouse or evBroadcast;
  MakeDriveLine;
  CharDelta := 1;
  LogDrvMap := SysGetValidDrives;
  UpdTicks := 3000;
  RegisterToBackground(Self);
  end;

function TDriveLine.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  inherited Read(Ip);
  MakeDriveLine;
  CharDelta := 1;
  Panel := Ip.ReadPointer;
  UpdTicks := 3000;
  RegisterToBackground(Self);
  end;

procedure TDriveLine.MakeDriveLine;
  var
    C: Char;
  begin
  DriveLine := '';
  for C := 'A' to 'Z' do
    if ValidDrive(C) then
      DriveLine := DriveLine + C;
  DriveLine := DriveLine + chTempDrive
              ;
  end;

function TDriveLine.GetPalette: TPalette;
  const
    S: String[Length(CDriveLine)] = CDriveLine;
  begin
  GetPalette := MakePalette(S);
  end;

procedure TDriveLine.Draw;
  var
    B: TDrawBuffer;
    M: Byte;
    I: Integer;
    SDir: String;
  begin
  M := Length(DriveLine);
  I := M*2+3;
  if  (Panel.Size.X >= I) then
    begin
    if  (Size.X <> I) then
      begin
      GrowTo(I, 1);
      Exit;
      end;
    ViewLine := '';
    for I := 1 to Length(DriveLine) do
      ViewLine := ViewLine+' '+DriveLine[I];
    ViewLine := '['+ViewLine+' ]';
    end
  else
    begin
    I := 2+M;
    if Panel.Size.X-2 >= I then
      if  (Size.X <> I)
      then
        begin
        GrowTo(I, 1);
        Exit;
        end
      else
        ViewLine := '['+DriveLine+']'
    else if Panel.Size.X <> Size.X+2
    then
      begin
      GrowTo(Panel.Size.X-2, 1);
      CharDelta := 1;
      Exit;
      end
    else
      begin
      ViewLine := Copy(DriveLine, CharDelta, Size.X-2);
      if Length(ViewLine) < Size.X-2 then
        ViewLine := ViewLine+Copy(DriveLine, 1, Size.X-2-Length(ViewLine));
      ViewLine := '{'+ViewLine+'}';
      end;
    end;
  MoveStr(B[0], ViewLine, GetColorW(1));
  I := PosChar(Panel.DriveLetter, ViewLine);
  if I > 0 then
    SetCellAttr(B[I-1], GetColorW(3));

  SetCellAttr(B[0], GetColorW(2));
  SetCellAttr(B[Size.X-1], GetColorW(2));
  WriteLineC(0, 0, Size.X, 1, B);
  end { TDriveLine.Draw };

procedure TDriveLine.HandleEvent(var Event: TEvent);
  var
    P: TPoint;

  { AK155 29.01.06 }
  procedure BracketClick(T: TPanelNum);
    var
      TargetPanel: TView;
      Manager: TDoubleWindow;
    const
      HideCommand: array[TPanelNum] of Word =
         (cmHideLeft, cmHideRight);
    begin
    Manager := TDoubleWindow(Panel.Owner);
    { If the panel is expanded, the operation applies to it regardless
      of whether the right or left bracket was pressed. So we adjust
      T to the internal number of this panel }
    if Manager.PanelZoomed then
      T := Manager.Panel[pRight].AnyPanel.GetState(sfSelected);
    TargetPanel := Manager.Panel[T].AnyPanel;
    if (Event.Mouse.Buttons and mbLeftButton <> 0) or
      not TargetPanel.GetState(sfVisible)
    then { left mouse button or operation on a hidden panel:
           hide/show, like Ctrl-F1/F2}
      Message(Owner, evCommand, HideCommand[T], nil)
    else
      begin { right mouse button: activate and
          expand/restore (like Alt-Ctrl-Z) }
      TargetPanel.Select;
      Message(TargetPanel.Owner, evCommand, cmMaxi, nil);
      end;
    end;

  procedure Scroll(D: Integer{+1 or -1});
    begin
    repeat
      CharDelta := 1 + ((CharDelta+D-1+Length(DriveLine)) mod Length(DriveLine));
      DrawView;
    until not MouseEvent(Event, evMouseAuto);
    end;
  { /AK155 }

  begin { TDriveLine.HandleEvent }
  inherited HandleEvent(Event);
  case Event.What of
    evBroadcast:
      case Event.Message.Command of
        cmDropped:
          if MouseInView(PCopyRec(Event.Message.InfoPtr)^.Where) then
            begin
            Event.What := evNothing;
            ClrIO;
            P := MakeLocal(PCopyRec(Event.Message.InfoPtr)^.Where);
            if ViewLine[P.X+1] = ' ' then
              {Dec(P.X);}
              begin { between letters - ignore. This is better than missing }
              ClearEvent(Event); Exit;
              end;
            case ViewLine[P.X+1] of
              chTempDrive:
                CopyDirName := cTEMP_;
          
              'A'..'Z':
                CopyDirName := ViewLine[P.X+1]+':';
              else {case}
                Exit;
            end {case};
            SkipCopyDialog := Confirms and cfMouseConfirm = 0;
            if ReflectCopyDirection
            then
              RevertBar := (Message(Desktop, evBroadcast,
                     cmIsRightPanel, Panel) <> nil)
            else
              RevertBar := False;
            Message(PCopyRec(Event.Message.InfoPtr)^.Owner,
              evBroadcast, cmCopyCollection,
              PCopyRec(Event.Message.InfoPtr)^.FC);
            SkipCopyDialog := False;
            end;
      end {case};
    evMouseDown:
      begin
      ClrIO;
      P := MakeLocal(Event.Mouse.Where);
      if ViewLine[P.X+1] = ' ' then
        {Dec(P.X);}
        begin { between letters - ignore. This is better than missing }
        ClearEvent(Event); Exit;
        end;
      if ((Event.Mouse.EventFlags and 2) <> 0) then
        begin
        case ViewLine[P.X+1] of
          'A'..'Z':
            Panel.ChDir(DriveRoot(ViewLine[P.X+1]));
          '}':
             Scroll(+1); // without this fast clicks on the bracket do not work
          '{':
             Scroll(-1); // similarly
        end {case};
        end
      else if ViewLine[P.X+1] = Panel.DirectoryName[1]
      then
        Message(Panel, evCommand, cmRereadDir, @Panel.DirectoryName)
      else
        case ViewLine[P.X+1] of
          chTempDrive:
            begin
            FreeStr := cTEMP_;
            Message(Panel, evCommand, cmChangeDrv, @FreeStr);
            end;
        
          'A'..'Z':
            begin
            FreeStr := ViewLine[P.X+1]+':';
            Message(Panel, evCommand, cmChangeDrv, @FreeStr);
            end;
          '[':
             BracketClick(pLeft);
          ']':
             BracketClick(pRight);
          '}':
             Scroll(+1);
          '{':
             Scroll(-1);
        end {case};
      ClearEvent(Event);
      end;
  end {case};
  end { TDriveLine.HandleEvent };

procedure TDriveLine.Write(Os: opstream);
  begin
  inherited Write(Os);
  Os.WritePointer(Panel);
  end;

class function TDriveLine.Build: TStreamable;
begin
  Result := TDriveLine.Create(streamableInit);
end;

function TDriveLine.StreamableName: ShortString;
begin
  Result := 'filepanel.TDriveLine';
end;

procedure TDriveLine.Refresh;
  var
    newLogDrvMap: LongInt;
  begin
  newLogDrvMap := SysGetValidDrives;
  if newLogDrvMap <> LogDrvMap then
    begin
    LogDrvMap := newLogDrvMap;
    MakeDriveLine;
    DrawView;
    end;
  end;

procedure TDriveLine.Update;
  begin
  if (FMSetup.Options and fmoAutorefreshDriveLine) <> 0 then
    Refresh;
  end;

procedure TDriveLine.ShiftLetter(d: Integer);
  var
    i, l: Integer;
  begin
  Refresh;
  i := PosChar(Panel.DriveLetter, DriveLine);
  l := Length(DriveLine);
  if i = 0 then
    begin
    if d < 0 then
      i := PosChar(chTempDrive, DriveLine)
    else
      i := l;
    end;
  Panel.DriveLetter := DriveLine[1 + (i + l - 1 + d) mod l];
  end;

{                                 TFilePanel                                 }
{----------------------------------------------------------------------------}
function TFilePanel.GetPalette: TPalette;
  const
    S: String[Length(CPanel)] = CPanel;
  begin
  GetPalette := MakePalette(S);
  end;

var
  Idx, CurPos, i, j: LongInt;
  C, C1, C2, C3, C4, C5, C6, C7, C8, C9: Byte;
  C2_3, C8_9: AWord;
  B: array[0..300] of TScreenCell;

procedure TFilePanel.DrawTop(var B: TScreenCell);
  var
    S: String;
    I, J: Integer;
    C: Word;
  begin
  Drive.MakeTop(S);
  I := 0;
  C := GetColorW($0206);
  J := CStrLen(S);
  while I < Size.X do
    begin
    MoveCStr(PCellArray(@B)^[I], S, C);
    Inc(I, J);
    end;
  end;

{-DataCompBoy-}
procedure TFilePanel.SetState(AState: Word; Enable: Boolean);

  procedure MakeChange;
    var
      Event: TEvent;
      {A: Boolean;}
    begin
    CurrentDirectory := DirectoryName;
    ClrIO;
    NeedAbort := True;
    lChDir(CurrentDirectory);
    {A := Abort;}

    DriveState := dsActive;

    if IOResult <> 0 then
      begin
      DriveState := DriveState and dsInvalid;
      Exit;
      end;
    DriveState := dsActive;

    NeedAbort := DriveState and dsInvalid <> 0;

    Message(CommandLine, evCommand, cmRereadInfo, nil);
    {Cat:warn somewhere between b4.09 and b4.13 some changes happened,
      most likely related to the command line, as a result of which this
      piece started showing up. At the same time, the actions performed here look
      quite insane to me, so I commented them out}
    (*
     if (UpStrg(ActiveDir) <> UpStrg(DirectoryName)) or A then
      begin
       Drive^.lChDir(ActiveDir);
       ReadDirectory;
       CurrentDirectory := DirectoryName;
       Event.What := evKeyDown;
       SetDNKeyCode(Event, kbTab);
       Event.Message.InfoPtr := nil;
       PutEvent(Event);
      end;
*)
    Message(Owner, evCommand, cmChangeTree, @DirectoryName);
    end { MakeChange };

  var
    DoDraw: Boolean;

  begin { TFilePanel.SetState }
  inherited SetState(AState, Enable);
  { AK155 Footer and disk line must be hidden synchronously with the panel.
    Previously HideView did that }
  if (AState and sfVisible) <> 0 then
    begin
    if (InfoView <> nil) then
      InfoView.SetState(sfVisible, Enable);
    if DriveLine <> nil then
      DriveLine.SetState(sfVisible,
        Enable and (FMSetup.Show and fmsDriveLine <> 0));
    end;
  {/AK155  3-02-2004, 23-05-2005}
  DoDraw := False;
  if QuickSearch and (AState and
         (sfFocused+sfActive+sfVisible+sfSelected) <> 0) and not Enable
  then
    begin
    DoDraw := True;
    StopQuickSearch;
    end;
  if  (AState and sfActive <> 0) then
    if not Enable then
      begin
      DisableCommands(CommandSetOf(PanelCommands));
      if not GetState(sfActive+sfSelected) and
          (ScrollBar <> nil) and ScrollBar.GetState(sfVisible)
      then
        ScrollBar.Hide;
      DoDraw := True;
      end
    else
      EnableCommands(CommandSetOf(PanelCommands));
  if  (AState and sfSelected <> 0) and Enable then
    begin
    ActivePanel := Self;
    if Owner <> nil then { nil happens during Load }
      PassivePanel := OtherFilePanel(Self);
    end;
  if  (AState and sfFocused and State <> 0) then
    if Enable then
      begin
      DoDraw := True;
      if ScrollBar <> nil then
        begin
        ScrollBar.Show;
        ScrollBar.Options := ScrollBar.Options or ofPostProcess;
        end;
      if InfoView <> nil then
        InfoView.DrawView;
      if DirView <> nil then
        DirView.DrawView;
      if  (Drive.DriveType = dtDisk) then
        begin
        AddToDirectoryHistory(DirectoryName, Integer(dtDisk));
        if UpStrg(CurrentDirectory) <> UpStrg(DirectoryName)
        then
          MakeChange;
        end
      else if Drive.DriveType = dtArc
      then
        Drive.lChDir(#0);
      EnableCommands(CommandSetOf(PanelCommands));
      end;
  if GetState(sfFocused) then
    begin
    if AState and sfFocused <> 0 then
      DrawView;
    EnableCommands(CommandSetOf(PanelCommands));
    if  (ScrollBar <> nil) and not ScrollBar.GetState(sfVisible) then
      begin
      ScrollBar.Show;
      ScrollBar.Options := ScrollBar.Options or ofPostProcess;
      end;
    end;
  if AState and (sfSelected+sfActive) <> 0 then
    if GetState(sfSelected+sfActive) then
      begin
      if  (Drive.DriveType = dtDisk)
      then
        MakeChange
      else if Drive.DriveType = dtArc
      then
        Drive.lChDir(#0);
      DoDraw := True;
      EnableCommands(CommandSetOf(PanelCommands))
      end
    else
      begin
      if ScrollBar <> nil then
        begin
        ScrollBar.Hide;
        ScrollBar.Options := ScrollBar.Options and (not ofPostProcess);
        end;
      DoDraw := True;
      if InfoView <> nil then
        InfoView.DrawView;
      if DirView <> nil then
        DirView.DrawView;
      end;
  if DoDraw then
    begin
    PosChanged := False;
    DrawView;
    end;
  if GetState(sfFocused) then
    SetTitle(DirectoryName);
  end { TFilePanel.SetState };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TFilePanel.Draw;
  label 1;
  var
    P: PFileRec;
    CW: AWord;
    CS: AWord;
    PgS: AWord;
    S, S1: String;
    HLC: array[0..ttUpDir] of Byte; {JO, AK155}
    PB: ^Byte;
    TagC: Char;

  procedure DrawAtIdx;
    var
      P: PFileRec;
      CC: Byte;
      JJ: LongInt;
      CursorPos: Integer;
      S: String;
      RLimit: Integer;
    label Scroll;
    begin
    JJ := j*LineLength;
    if  (Files <> nil) and (Idx < Files.Count) then
      begin
      P := Files.At(Idx);
      CC := HLC[P^.TType];
      if  (Idx = CurPos) then
        begin
        LastCurPos.X := JJ;
        LastCurPos.Y := i+1
        end;
      if Idx = CurPos then
        if P^.Selected then
          begin
          C := C5;
          CC := C5
          end
        else
          C := C4
      else if P^.Selected then
        begin
        C := CC;
        CC := C3
        end
      else
        C := CC;
      MoveChar(B[JJ], ' ', C, LineLength);
      if  (Idx = CurPos) and GetState(sfFocused) then
        begin
        Drive.GetFull(B[JJ], P, C shl 8+C, Cs and $00FF+C shl 8);
        end
      else
        Drive.GetFull(B[JJ], P, CC shl 8+C, Cs);
      if QuickSearch and (Idx = CurPos) then
        begin
        if LFNLonger250 then
          Inc(JJ, CalcLengthWithoutName);
        if (QSLastSuccessPos > flnNLength) then {cursor in the extension field }
          begin
          CursorPos := flnDotPos + QSLastSuccessPos - flnNLength - 2;
          if CursorPos >= LFNLen - Byte(flnPanelName[LFNLen] = #16) then
            goto Scroll; { cursor went right past the boundary }
          end
        else if QSLastSuccessPos <= flnNSize then {cursor in the name field }
          CursorPos := QSLastSuccessPos - 1
        else { cursor outside the name }
Scroll:
          begin
          {The character where the cursor should be is not visible.
           Redisplay the name without tabulation and with truncation if needed.
           If there is right truncation, place the cursor no further than
           the last character before truncation. If there is no right truncation,
           let the cursor go right all the way to the line after the column. }
          S := P^.FlName[uLFN];
          RLimit := Max(-1, QSLastSuccessPos - Length(S));
            {Right limit of cursor position relative to LFNLen;
             ranges from -1 to +1 }
          if QSLastSuccessPos > LFNLen  then
            begin
            System.Delete(S, 2, QSLastSuccessPos - LFNLen - RLimit);
            S[1] := #17;
            CursorPos := LFNLen - 1 + RLimit;
            end
          else
            CursorPos := QSLastSuccessPos-1;
          S := FormatLongName(S, LFNLen, 0,
            flnPadRight or flnHandleTildes, nfmNull);
          MoveCStr(B[JJ], S, C);
          end;
        SetCursor(JJ+CursorPos, i);
        ShowCursor;
        NormalCursor
        end;
      end
    else
      begin
      MoveChar(B[JJ], ' ', C1, LineLength);
      GetEmpty(B[JJ], Cs, False);
      end;
    end { DrawAtIdx };

  var
    ColumnTitles: Boolean;

  begin { TFilePanel.Draw }
  if DrawDisableLvl > 0 then
    Exit;
  if DrawDisableLvl < 0 then
    DrawDisableLvl := 0;
  if Loaded then
    RereadDir;
  LineLength := CalcLength;

  if  (DriveState and dsInvalid > 0) then
    begin
    C1 := GetColorW(1); { Normal }
    for i := 0 to pred(Owner.Size.Y) do
      begin
      MoveChar(B[0], ' ', C1, Size.X);
      WriteLineC(0, i, Owner.Size.X, 1, B[0]);
      end;
    Exit;
    end;

  if Size.X > LineLength-1 then
    DeltaX := 0;
  if UpStrg(OldDirectory) <> UpStrg(DirectoryName) then
    begin
    if  (UpStrg(OldDirectory[1]) <> UpStrg(DirectoryName[1]))
         and (OldDirectory <> '')
    then
      ScrollBar.SetValue(0);
    PosChanged := False;
    DecDrawDisabled;
    OldDirectory := DirectoryName;
    end;
  C1 := GetColorW(1); { Normal }
  C2 := GetColorW(2); { Separator }
  C3 := GetColorW(3); { Selected }
  C4 := C1;
  C5 := C3;
  HLC[0] := C1;
  HLC[ttUpDir] := C1;
  if FMSetup.TagChar[1] <> ' ' then
    TagC := FMSetup.TagChar[1]
  else
    TagC := GlyphChar(glRadical);
  if Startup.FMSetup.Show and fmsHiliteFiles <> 0 then
    for i := 1 to ttCust10 do
      HLC[i] := GetColorW(6+i) {JO}
  else
    for i := 1 to ttCust10 do
      HLC[i] := C1; {JO}
  CS := 179+C2 shl 8;
  CW := 32+C2 shl 8;

  ColumnTitles := (Pansetup.Show.MiscOptions and 2) <> 0;
  PgS := (Size.Y-Byte(ColumnTitles))
        *((Size.X+1) div LineLength);
  if PgS = 0 then
    PgS := (Size.Y-Byte(ColumnTitles));
  ScrollBar.PgStep := PgS;
  if Delta < 0 then
    Delta := 0;
  if (Files <> nil {happens, for example, when entering a broken zip archive} )
    and (Files.Count > 0)
  then
    begin
    CurPos := ScrollBar.Value;
    if CurPos < Delta then
      Delta := CurPos;
    if CurPos >= Delta+PgS then
      Delta := CurPos-PgS+1;
    end
  else
    CurPos := -1;
  if GetState(sfFocused) then
    begin
    C4 := GetColorW(4); { Normal cursor }
    C5 := GetColorW(5); { Selected cursor }
    end
  else if CurPos >= 0 then
    begin
    P := Files.At(CurPos);
    if Startup.FMSetup.Show and fmsHiliteFiles <> 0 then
      C4 := HLC[P^.TType];
    end;
  if not QuickSearch then
    HideCursor;
  if PosChanged and (OldDelta = Delta) then
    begin
    if CurPos <> OldPos then
      begin
      for i := Byte(ColumnTitles) to Size.Y-1
      do
        for j := 0 to Size.X div LineLength do
          begin
          Idx := i-Byte(ColumnTitles)+
            j*(Size.Y-Byte(ColumnTitles))+Delta;
          if  (Idx = CurPos) or (Idx = OldPos) then
            begin
            MoveChar(B[0], ' ', C1, Size.X);
            DrawAtIdx;
            Idx := (j+1)*LineLength;
            if Idx < Size.X then
              B[Idx-1] := TScreenCell(Word(CS))
            else
              B[Idx-1] := TScreenCell(Word(CW));
            Idx := j*LineLength;
            WriteLineC(Idx, i, LineLength-1, 1, B[Idx+DeltaX]);
            end;
          end;
      end
    else
      goto 1;
    PosChanged := False;
    OldDelta := Delta;
    OldPos := CurPos;
    Exit;
    end;
1:
  OldDelta := Delta;
  OldPos := CurPos;
  PosChanged := False;
  if ColumnTitles then
    begin
    DrawTop(B[0]);
    if CellChar(B[Size.X-1]) = 179 then
      SetCellChar(B[Size.X-1], 32);
    WriteLineC(0, 0, Size.X, 1, B[DeltaX]);
    end;
  for i := Byte(ColumnTitles) to Size.Y-1 do
    begin
    MoveChar(B[0], ' ', C1, Size.X);
    for j := 0 to Size.X div LineLength do
      begin
      Idx := i-Byte(ColumnTitles)+
        j*(Size.Y-Byte(ColumnTitles))+Delta;
      DrawAtIdx;
      Idx := (j+1)*LineLength;
      if Idx < Size.X then
        B[Idx-1] := TScreenCell(Word(CS))
      else
        B[Idx-1] := TScreenCell(Word(CW));
      end;
    WriteLineC(0, i, Size.X, 1, B[DeltaX]);
    end;
  if GetState(sfFocused) then
    SetTitle(DirectoryName);
  end { TFilePanel.Draw };
{-DataCompBoy-}

{                                 TInfoView                                  }
{----------------------------------------------------------------------------}
constructor TInfoView.Create(const R: TRect);
  begin
  inherited Create(R);
  EventMask := evMouse;
  end;

function TInfoView.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  inherited Read(Ip);
  Panel := Ip.ReadPointer;
  end;

procedure TInfoView.Write(Os: opstream);
  begin
  inherited Write(Os);
  Os.WritePointer(Panel);
  end;

class function TInfoView.Build: TStreamable;
begin
  Result := TInfoView.Create(streamableInit);
end;

function TInfoView.StreamableName: ShortString;
begin
  Result := 'filepanel.TInfoView';
end;

procedure TInfoView.HandleEvent(var Event: TEvent);
  var
    P: TPoint;
    Y: Integer;
    Mover: TView;
    S: String;
    FC: TFilesCollection;
    C: TCopyRec;

  procedure CE;
    begin
    ClearEvent(Event)
    end;

  procedure DragCurrent;
    begin
    with Panel do
      begin
      S := Cut(PFileRec(Files.At(ScrollBar.Value))^.FlName[uLfn], 20);
      {DataCompBoy}
      if S = '..' then
        Exit;
      end;
    FC := TFilesCollection.Create(1, 100);
    FC.Insert(CopyFileRec(Panel.Files.At(Panel.ScrollBar.Value)));
    if P.X < Length(S) then
      Dec(P.X);
    P := MakeGlobal(P);
    DragMover(@P, S, FC, @C);
    CE;
    end;

  procedure DragSelected;
    var
      I: LongInt;
      PF: PFileRec; {DataCompBoy}
    begin
    if Panel.SelNum = 0 then
      Exit;
    FC := TFilesCollection.Create(Panel.SelNum, 100);
    for I := 1 to Panel.Files.Count do
      begin
      PF := Panel.Files.At(I-1); {DataCompBoy}
      if PF^.Selected then
        FC.Insert(CopyFileRec(PF)); {DataCompBoy}
      end;
    P := MakeGlobal(P);
    DragMover(@P, ItoS(Panel.SelNum)+GetString(dlSelectedFiles), FC, @C);
    CE;
    end;

  procedure DragTotals;
    var
      N, I, Start: LongInt;
    begin
    Start := FirstNameNum(Panel)-1;
    with Panel.Files do
      begin
      N := Count-Start;
      FC := TFilesCollection.Create(N, 100);
      for I := Start to N+Start-1 do
        FC.AtInsert(FC.Count, CopyFileRec(PFileRec(At(I))));
      end;
    P := MakeGlobal(P);
    DragMover(@P, ItoS(N)+' '+GetString(dlDIFiles), FC, @C);
    CE;
    end;

  begin {TInfoView.HandleEvent}
  inherited HandleEvent(Event);
  if ((FMSetup.Options and fmoDragAndDrop) <> 0) and
     (Event.What and (evMouseDown+evMouseAuto) <> 0)
  then
    begin
    if Panel.Files.Count = 0 then
      Exit;
    C.Owner := Panel;
    P := MakeLocal(Event.Mouse.Where);
    Y := 0;
    if Y = P.Y then
      begin { mouse in the separator }
      if Panel.Files.Count = 0 then
        Exit;
      if  (P.X >= Panel.SelectedInfoInDividerMin) and
          (P.X <= Panel.SelectedInfoInDividerMax)
      then
        begin
        DragSelected;
        Exit;
        end; {AK155}
      if  (P.X >= Panel.TotalInfoInDividerMin) and
          (P.X <= Panel.TotalInfoInDividerMax)
      then
        begin
        DragTotals;
        Exit;
        end; {AK155}
      if Panel.GetState(sfActive) and not Panel.GetState(sfSelected)
      then
        Panel.Select; {AK155}
      if Panel.GetState(sfActive+sfSelected) then
        begin
        with Panel do
          begin
          MSelect := Event.Mouse.Buttons and mbRightButton <> 0;
          if MSelect then
            begin
            SelectFlag := not PFileRec
              (Files.At(ScrollBar.Value))^.Selected;
            MessageKey(Panel, kbIns);
            end;
          end;
        RepeatDelay := 0;
        repeat
          MessageKey(Self.Owner, kbDown);
        until not MouseEvent(Event, evMouseMove+evMouseAuto);
        RepeatDelay := 2;
        Panel.MSelect := False;
        end;
      Exit
      end;
    Inc(Y);

    { D&D from the panel footer }
    if  (P.Y = DnD.CurrentY1) or (P.Y = DnD.CurrentY2) then
      DragCurrent
    else if P.Y = DnD.SelectedY then
      DragSelected
    else if P.Y = DnD.TotalY then
      DragTotals;
    CE;
    end;
  end { TInfoView.HandleEvent };

var
  Y: Word;
  PF: PFileRec;  { descriptor of the current file }
  BriefL1: Integer;
    { Length on the left already taken by brief info in the separator}
  CDivdier: Byte;
  LFN_inCurFileLine: Boolean;

function MakeDivider(IV: TInfoView): Boolean;
  var
    C: Word;
    I: Integer;
  begin
  Result := False;
  with IV do
    begin
    MoveGlyph(B[0], glLightH, CDivdier, IV.Size.X+Panel.DeltaX);
    I := 0;
    C := (CDivdier shl 8) or GlyphByte(glLightUH);
    while I < Size.X do
      begin
      Panel.GetEmpty(B[I], C, True);
      Inc(I, Panel.LineLength);
      if I = Size.X then
        B[I-1] := TScreenCell(Word((C and $FF00)+GlyphByte(glLightH)));
      end;
    end;
  end;

function MakeCurFile(IV: TInfoView): Boolean;
  begin
  with IV do
    begin
    MoveChar(B[0], ' ', C1, Size.X+Panel.DeltaX);
      { Must clear unconditionally, especially if there are no files. }
    Result := False;
    if PF = nil then
      Exit;
    DnD.CurrentY1 := Y;
    Panel.Drive.GetDown(B[0], C1, PF, LFN_inCurFileLine);
    end;
  Result := True;
  end;

function MakeFilter(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
  begin
  S := IV.Panel.PanSetup^.FileMask;
  Result := S <> x_x;
  if Result then
    begin
    S := fReplace(' ', '', S);
    if Copy(S, 1, 1) = ';' then
      Delete(S, 1, 1);
    I := 0;
    if BriefL1 <> 0 then
      I := Max(BriefL1+1, IV.Size.X div 2);
    MoveCStr(B[I], GetString(dlFileMask)+S, C3);
    end;
  end;

function MakeQSMask(IV: TInfoView): Boolean;
  begin
  Result := QuickSearch and (Pointer(IV.Panel) = Pointer(ActivePanel));
   { Flash 25-01-2004:
       If we do not compare the current panel with the active one, then
    with auto-update on the quick-search mask line
    may appear on both panels, which is nonsense. }
  if Result then
    MoveCStr(B[0], QuickSearchString(IV.Size.X), Swap(C2_3));
  end;

function MakeSelected(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
  begin
  with IV do
    begin
    Result := Panel.SelNum <> 0;
    if Y <> 0 then
      MoveChar(B[0], ' ', C3, IV.Size.X+Panel.DeltaX);
    if Result then
      begin
      with Panel do
        begin
        S := '~'+FStr(SelectedLen);
        if  (Drive.DriveType = dtArc) and (SelectedLen <> PackedLen) then
          S := S+'('+FStr(PackedLen)+')';

        S := S+GetString(dlBytesIn)+
  ItoS(SelNum)+'~'+GetString(dlSelectedFiles);
        end;
      DnD.SelectedY := Y;
      end
    else if Y <> 0 then
      S := GetString(dlNoFilesSelected)
    else
      Exit;
    I := Max(0, (Size.X-CStrLen(S)) div 2);
    MoveCStr(B[I], S, Swap(C2_3));
    end;
  end;

function MakeSelectedBrief(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
  begin
  with IV.Panel do
    if SelNum <> 0 then
      begin
      S := FStr(SelectedLen);
      if  (Drive.DriveType = dtArc) and (SelectedLen <> PackedLen) then
        S := S + '/' + FStr(PackedLen);
      S := S + '(' + ItoS(SelNum) + ')';
      MoveStr(B[1], S, C3);
      BriefL1 := Length(S) + 1;
      SelectedInfoInDividerMin := 1;
      SelectedInfoInDividerMax := BriefL1-1;
      end;
  Result := False;
  end;

function MakeTotals(IV: TInfoView): Boolean;
  var
    S: String;
    FilesCount: LongInt;
    I: Integer;
    C: Word;
  begin
  if BriefL1 <> 0 then
    Exit;
  with IV do
    begin
    FilesCount := Panel.Files.Count-(FirstNameNum(Panel)-1);
    C := GetColorW($0504);
    if FilesCount = 0 then
      S := GetString(dlDINoFiles)
    else
      begin
      S := GetString(dlTotal);
      if FilesCount = 1 then
        S := S+'1~ '+GetString(dlDIFile)
      else
        S := S+ItoS(FilesCount)+'~ '+GetString(dlDIFiles);
      S := S+GetString(dlDIWith)+'~';
      if C = 1 then
        S := S+'1~ '+GetString(dlDIByte)
      else
        S := S+FStr(IV.Panel.TotalInfo)+'~ '+GetString(dlDIBytes);
      end;
    I := Max(0, (Size.X-CStrLen(S)) div 2);
    DnD.TotalY := Y;
    end;
  MoveCStr(B[I], S, C);
  Result := True;
  end;

function MakeTotalsBrief(IV: TInfoView): Boolean;
  var
    S: String;
    FilesCount: LongInt;
    I: Integer;
  begin
  with IV.Panel do
    begin
    FilesCount := Files.Count-(FirstNameNum(IV.Panel)-1);
    S := FStr(TotalInfo)+'('+ItoS(FilesCount)+')';
    I := IV.Size.X - Length(S);
    if BriefL1 < I then
      begin
      MoveStr(B[I], S, CDivdier);
      TotalInfoInDividerMin := I;
      TotalInfoInDividerMax := Size.X-1;
      BriefL1 := IV.Size.X;
      end;
    end;
  Result := False;
  end;

function MakeFreeSpace(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
    C: Word;
  begin
  if BriefL1 <> 0 then
    Exit;
  with IV do
    begin
    C := GetColorW($0706);
    S := Panel.FreeSpace;
    I := Max(0, (Size.X-CStrLen(S)) div 2);
    end;
  MoveCStr(B[I], S, C);
  Result := True;
  end;

function MakePathDecr(IV: TInfoView): Boolean;
  var
    S2: String;
    I: Integer;
    Mask: Word;
  begin
  if BriefL1 <> 0 then
    Exit;
  with IV do
    begin
    S2 := '';
    if Panel.Drive.ColAllowed[psnShowDir] then
      begin { Show path }
      if  (PF <> nil) and (PF^.Owner <> nil) then
        S2 := (PF^.Owner^);
      Mask := psShowDir;
      end
    else
      begin { Show description }
      if  (PF <> nil) and (PF^.DIZ <> nil) and (PF^.DIZ^.DIZText <> '')
      then
        begin
        S2 := DizMaxLine(PF^.DIZ); {Do not highlight the first line}
        Replace('~', #0'~', S2); {show tildes}
        Mask := psShowDescript;
        end;
      end;
    if Panel.PanSetup.Show.ColumnsMask and Mask <> 0
    then
      begin
      { in the footer we output what did not fit in the panel }
      with Panel do
        begin
        J := CalcNameLength + CalcColPos(psShowDescript);
        J := Size.X-J+DeltaX-1;
        end;
      System.Delete(S2, 1, J);
      end;
    if StrCols(S2) > Size.X then
      S2 := CutCols(S2, Size.X, FMSetup.RestChar[1]);   { columns, not bytes: a name in UTF-8 }
    Result := S2 <> '';
    if Result then
      begin
      MoveChar(B[0], ' ', C1, Size.X+Panel.DeltaX);
      MoveCStr(B[0], S2, C1);
      end;
    end;
  end;

function MakePacked(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
    C: Word;
  begin
  Result := (PF <> nil) { happens on an empty disk } and
      ((PF^.Size > 0) or (PF^.Attr and Directory = 0));
  if Result then
    begin
    C := IV.GetColorW($0405);
    MoveChar(B[0], ' ', Hi(C), IV.Size.X+IV.Panel.DeltaX);
    S :=
      GetString(dlArcPSize)+' ' +
      AddSpace(FStr(PF^.PSize), 14) +
      GetString(dlArcRatio) +
      Percent(PF^.Size, PF^.PSize);
    I := Max(0, (IV.Size.X-CStrLen(S)) div 2);
    MoveCStr(B[I], S, C);
    end;
  end;

function MakeRatio(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
  begin
  if (PF <> nil) { happens on an empty disk } and
     ((PF^.Size > 0) or (PF^.Attr and Directory = 0))
  then
    begin
    S := Percent(PF^.Size, PF^.PSize);
    I := (IV.Size.X - Length(S)) div 2;
    if I < BriefL1 + 1 then
      I := BriefL1 + 1;
    if I + Length(S) < PF^.Size then
      begin
      MoveStr(B[I], S, CDivdier);
      BriefL1 := I + Length(S);
      end;
    end;
  Result := False;
  end;

procedure PrepareLongName(IV: TInfoView; var S: String; var I: Integer);
  { Long name in the footer or on the separator. Result - in S,
    Alignment shift - in I (-1 - center) }
  var
    D: TDrive;
    CutLen: Integer;
    Dif1Start, Dif2Start: Integer;
    ExtPos: Integer; { start of extension in the formed string }
    S1: String; { working variable for determining the common part }
    Dummy: String;

  procedure DelFromS(DelStart, DelLen: Integer);
    procedure DecPos(var Pos: Integer);
      begin
      if DelStart < Pos then
        Pos := Max(DelStart, Pos-DelLen);
      end;
    begin
    DecPos(ExtPos);
    DecPos(Dif2Start);
    DecPos(Dif1Start);
    Delete(S, DelStart, DelLen);
    Delete(S1, DelStart, DelLen);
    end { DelFromS };

  var
    ShowLFN_Difference: Word;
    l: Integer;
    CutNamePos: Integer;
  label
    ShowRight;
  begin { PrepareLongName }
  with IV do
    begin
    if LFN_inCurFileLine and
       (FMSetup.LFN_Autohide <> 0)
    then
      begin
      S := '';
      Exit;
      end;
    D := Panel.Drive;
    S := PF^.FlName[True];
    S1 := UpStrg(S);
    TFilePanelRoot(D.Panel).FormatName(PF, Dummy, l);
      { Repeat formatting for the panel so there is something to compare with }
    UpStr(flnPanelName);
      { Must compare case-insensitively }

    ExtPos := PosLastDot(S)+1;
    Dif1Start := 255; Dif2Start := 255;
{Long name     ┌─────────────────────┐
  ├─ .......... │    Do not highlight │0
  ├─ .......... │   Show dimly        │1
  └─ Common part│    Do not show      │2
                └─────────────────────┘
   For now we only find difference positions and cut common parts
 if that is set. During length truncation positions may
 change (shrink), and only after that will we insert tildes
 for coloring. If we insert tildes now, that will hinder length
 control for truncation. }
    Dif2Start := ExtPos;
    l := flnDotPos+1;
    while flnPanelName[l] = S1[Dif2Start] do
      begin
      Inc(Dif2Start); Inc(l);
      end;
    { from Dif2Start to the end - new }

    { Now deal with the common part from the start to ExtPos-1}
    Dif1Start := 1;
    l := 1;
    while (Dif1Start < ExtPos) and (flnPanelName[l] = S1[Dif1Start]) do
      begin
      Inc(Dif1Start); Inc(l);
      end;
    if (Dif1Start = ExtPos-1) and
       (S1[Dif1Start] = '.') and (flnPanelName[l] = ' ')
    then
      inc(Dif1Start); { normal, this is extension tabulation }
    { Finally:
      differences in S from Dif1Start to ExtPos-1 and from Dif2Start to the end }

    if FMSetup.LFN_Autohide <> 0 then
      begin
      if (Dif1Start >= ExtPos-1) and (Dif2Start > Length(S)) then
        begin
        S := '';
        Exit;
        end;
      end;

    ShowLFN_Difference := 0;
    if PF^.TType <> ttUpDir then
      begin
      ShowLFN_Difference := FMSetup.LFN_Difference;
      if ShowLFN_Difference = 2 then
        begin { discard the common part on the left without a truncation character }
        if (Dif1Start < ExtPos) then { There is a difference in the name }
          DelFromS(1, Dif1Start-1)
        else{ The difference, if any, is only in the extension }
          DelFromS(1, Dif2Start-1)
        end;
      end;

    CutLen := Length(S) - Size.X;
    if CutLen <= 0 then
      begin { Alignment variants }
{Long name    ┌─────────────────────┐
 ├─ Place     │        Left         │ 0
 ├─ .......... │      Center         │ 1
 └─ .......... │       Right         │ 2
               └─────────────────────┘ }
        case FMSetup.LFN_Wrap of
          0:
            I := 0;
          1:
            I := -1;
          2:
            I := Size.X - Length(S);
        end {case};
      end
    else
      begin { Truncation variants }
      I := 0;
{Long name    ┌─────────────────────┐
 ├─ .......... │ Left part and ext.  │ 0
 ├─ Show      │    Right part       │ 1
 └─ .......... │     Left part       │ 2
               └─────────────────────┘}
      case FMSetup.LFN_Cut of
        0:
          begin
          if Length(S)-ExtPos > Size.X-3 then
            goto ShowRight; { nothing will remain of the name }
          CutNamePos := Min(Length(S), ExtPos-1) - CutLen;
          DelFromS(CutNamePos, CutLen);
          S[CutNamePos] := FMSetup.RestChar[1];
          end;
        1:
          begin
ShowRight:
          DelFromS(1, CutLen);
          S[1] := #17;
          end;
        2:
          begin
          SetLength(S, Size.X);
          S[Length(S)] := FMSetup.RestChar[1];
          end;
      end {case};
      end;
{  Insert tildes, not forgetting that the name may have had real tildes }
{Long name     ┌─────────────────────┐
  ├─ .......... │   Do not highlight  │0
  ├─ .......... │  Highlight by color │1
  └─ Common part│   Do not show       │2
                └─────────────────────┘}
    if ShowLFN_Difference <> 0 then
      begin
      if Dif2Start <= Length(S) then
        Insert(#1, S, Dif2Start);
      if (ExtPos > Dif1Start) then
        begin
        Insert(#1, S, ExtPos);
        Insert(#1, S, Dif1Start);
        end;
      end;
    Replace('~', #0'~', S);
    Replace(#1, '~', S);
    DnD.CurrentY2 := Y;
    end;
  end { PrepareLongName };

function MakeLongName(IV: TInfoView): Boolean;
  var
    S: String;
    I: Integer;
  begin
  Result := False;
  if PF = nil then
    Exit;
  PrepareLongName(IV, S, I);
  if S = '' then
    Exit;
  Result := True;
  if Y <> 0 then
    MoveChar(B[0], ' ', C9, IV.Size.X+IV.Panel.DeltaX);
  if I < 0 then
    I := Max(0, (IV.Size.X-CStrLen(S)) div 2);
  MoveCStr(B[I], S, Swap(C8_9));
  end;

function Terminate(IV: TInfoView): Boolean;
  begin
  Result := True;
  end;

var
  ElNumber: array[0..MaxFooterHeight] of Byte;
    { Used while compiling footer view settings.
      ElNumber[Y] - number of elements output in line Y }

procedure TInfoView.Compile(Value: Word;
    FullProc, BriefProc: TFooterProc);
  var
    Y: Word;
    P: TFooterProc;
  begin
  if Value = 0 then
    Exit;
  @P := @FullProc;
  if Value > MaxFooterHeight then
    begin { On separator, On separator briefly }
    if Value = MaxFooterHeight+2 then
      @P := @BriefProc;
    Value := 0;
    end;
  if ElNumber[Value] >= High(LineMaker[Value]) then
    Exit; {! Would be nice to show a message, but such absurdity
      is unlikely to occur in life }
  @LineMaker[Value][ElNumber[Value]] := @P;
  inc(ElNumber[Value]);
  end;

procedure TInfoView.CompileShowOptions;
  var
    Y, i: Word;
  begin
  if Self = nil then
    Exit;
  FillChar(ElNumber, SizeOf(ElNumber), 0);
  with Panel.PanSetup.Show do
    begin
    Compile(MaxFooterHeight+1, MakeDivider, nil);
    Compile(ShowCurFile, MakeCurFile, nil);
    Compile(SelectedInfo, MakeQSMask, MakeQSMask);
      { The quick-search mask is output in the same place as
      selected-files data, and the mask has higher priority. }
    Compile(SelectedInfo, MakeSelected, MakeSelectedBrief);
    Compile(FilterInfo, MakeFilter, nil);
    Compile(PathDescrInfo, MakePathDecr, nil);
    if (Panel.Drive.DriveType = dtArc) and
      (ColumnsMask and (psShowRatio or psShowPacked) = 0)
    then
      begin
      Compile(PackedSizeInfo, MakePacked, nil);
      Compile(BriefPercentInfo, nil, MakeRatio);
      end;
    Compile(LFN_InFooter, MakeLongName, nil);
    Compile(TotalsInfo, MakeTotals, MakeTotalsBrief);
    Compile(FreeSpaceInfo, MakeFreeSpace, nil);
    if (FilterInfo in [1..MaxFooterHeight]) and
       (ElNumber[FilterInfo] = 1) and
       (Panel.PanSetup^.FileMask = x_x)
    then
      ElNumber[FilterInfo] := 0;
        { A line that has only an identical filter is not needed }
    end;
  Y := 0;
  for i := 0 to High(ElNumber) do
    begin
    if ElNumber[i] <> 0 then
      begin
      @LineMaker[i][ElNumber[i]] := @Terminate;
      if i <> Y then
        Move(LineMaker[i], LineMaker[Y], SizeOf(LineMaker[i]));
      inc(Y);
      end;
    end;
  Size.Y := Y;
  end { TInfoView.CompileShowOptions };

procedure TInfoView.Draw;
  const
    NoDnD: TPanelBottomDnD =
      (TotalY: 255; SelectedY: 255; CurrentY1: 255; CurrentY2: 255);
  var
    YCurFileLine: Integer;
      {` Footer line number (separator is 0) where
      info about the current file is shown. -1 if shown nowhere.
        This line is drawn first regardless of its position,
      because name info from this line affects drawing
      of the long name.`}

  procedure DrawAtY;
    var
      I: Integer;
    begin
    BriefL1 := 0;
    I := 0;
    while True do
      begin
      if LineMaker[Y][I](Self) then
        Break;
      inc(I);
      end;
    WriteLineC(0, Y, Size.X, 1, B);
    MoveChar(B[0], ' ', C1, Size.X);
    end;

  procedure FindCurFileLine;
    var
      I: Integer;
      P: TFooterProc;
    begin
    for Y := 0 to Size.Y-1 do
      begin
      I := 0;
      while True do
        begin
        @P := @LineMaker[Y][I];
        if @P = @Terminate then
          Break;
        if @P = @MakeCurFile then
          begin
          YCurFileLine := Y;
          Exit;
          end;
        inc(I);
        end;
      end;
    YCurFileLine := -1;
    end;

  begin { TInfoView.Draw }
  C1 := GetColorW(1);
  C2_3 := GetColorW($0203);
  C3 := Lo(C2_3);
  C2 := Hi(C2_3);
  C8_9 := GetColorW($0809);
  C8 := Lo(C8_9);
  C9 := Hi(C8_9);
  CDivdier := Panel.GetColorW(2);
  DnD := NoDnD;
  with Panel do
    begin { Clear D&D coordinates from the separator }
    TotalInfoInDividerMin := 1; TotalInfoInDividerMax := 0;
    SelectedInfoInDividerMin := 1; SelectedInfoInDividerMax := 0;
    end;
  { the list may be empty (a new temporary drive is shown before its directory is read: At(0) was a collection error) }
  if (Panel.Files <> nil) and (Panel.ScrollBar.Value < Panel.Files.Count) and (Panel.ScrollBar.Value >= 0) then
      {AK155 nil happens when starting DN with a saved desktop,
       when the window size does not match the one at which
       the desktop was saved.}
    begin
    PF := Panel.Files.At(Panel.ScrollBar.Value);
    LFN_inCurFileLine := False;
    FindCurFileLine;
    if YCurFileLine >= 0 then
      DrawAtY;
    for Y := 0 to Size.Y-1 do
      if Y <> YCurFileLine then
        DrawAtY;
    end;
  end { TInfoView.Draw };

function TInfoView.GetPalette: TPalette;
  const
    S: String[Length(CInfoView)] = CInfoView;
  begin
  GetPalette := MakePalette(S);
  end;

{ ---------------------------- TDirView ------------------------------ }

function TDirView.GetText(MaxWidth: Integer): String;
  begin
  { On Unix the path is shown the way the system writes it: /dev/shm/, not C:\dev\shm\ (issue #23). }
  Result := SysDisplayPath(TFilePanelRoot(Panel).DirectoryName);
  Result := Cut(Result, MaxWidth);
  end { TDirView.Draw };

procedure TDirView.HandleEvent(var Event: TEvent);
  var
    S: String;
    I: LongInt;
    P: TPoint;
  begin
  inherited HandleEvent(Event);
  case Event.What of
    evMouseDown:
      begin
      P := MakeLocal(Event.Mouse.Where);
      S := GetText(255);
      if Length(S) > Size.X then
        I := 0
      else
        I := PosChar(':', S);
      repeat
      until not MouseEvent(Event, evMouseAuto+evMouseMove);
      ClearEvent(Event);
      if  (P.X <= I)
      then
        Message(Panel, evCommand, cmChangeDrive, nil)
      else
        Message(Panel, evCommand, cmChangeDir, nil);
      end;
  end {case};
  end { TDirView.HandleEvent };

{ FilePanel HandleEvent}

{-DataCompBoy-}
procedure TFilePanel.HandleEvent(var Event: TEvent);
  var
    PF: PFileRec;
    CurPos: LongInt;
    PPC: TCollection;
    MPos: TPoint;
    LastRDelay: Word;
    I, J: LongInt;
    PDr: TDrive;
    KeyCode: LongInt; {Cat}

  procedure CE;
    begin
    ClearEvent(Event)
    end;
  procedure CED;
    begin
    ClearEvent(Event);
    DrawView
    end;

  procedure CM_CopyUnselect;
    label 1;
    var
      PF: PFileRec;
      I, OSM: LongInt;
    begin
    if  (Files.Count = 0) or (Event.Message.InfoPtr = nil) then
      Exit;
    OSM := TFilesCollection(Files).SortMode;
    TFilesCollection(Files).SortMode := fcmPreciseCompare;
    for I := 0 to Files.Count-1 do
      if Files.FileCompare(Files.At(I), Event.Message.InfoPtr) = 0 then
        goto 1; {-$VOL}
    TFilesCollection(Files).SortMode := OSM;
    Exit;
1:
    TFilesCollection(Files).SortMode := OSM;
    PF := {Event.Message.InfoPtr}Files.At(I);
    with PF^ do
      if Selected then
        begin
        Selected := False;
        if Size > 0 then
          begin
          SelectedLen := SelectedLen-Size;
          PackedLen := PackedLen-PSize;
          end;
        Dec(SelNum)
        end;
    if TimerExpired(_Tmr1) then
      begin
      DrawView;
      if InfoView <> nil then
        InfoView.DrawView;
      NewTimer(_Tmr1, 500);
      end;
    end { CM_CopyUnselect };

  function MaskSearch(B: Byte): Boolean;
{ Search for a file matching the quick-search mask, starting from
  the current (B=0) or the next (B=1) file }
    var
      I: LongInt;
    begin
    MaskSearch := True;
    I := CurPos+B;
    if I >= Files.Count then
      I := 0;
    repeat
      if InMask(PFileRec(Files.At(I))^.FlName[uLfn],
           QSMaskPlusStar)
      then
        begin
        ScrollBar.SetValue(I);
        Exit;
        end;
      Inc(I);
      if I >= Files.Count then
        I := 0;
    until I = CurPos;
    MaskSearch := False;
    end { MaskSearch };

  label lbMakeUp, GotoKb, lbMakeDown;

  begin { TFilePanel.HandleEvent }
  
  uLfn := PanSetup.Show.ColumnsMask and psLFN_InColumns <> 0;
  
  inherited HandleEvent(Event);
  if Event.What = evNothing then
    Exit;
  { X.4 of the vtui UX guidelines: the wheel over a panel moves that panel, also when the other one is active (the window would move the bar it finds first) }
  if (Event.What = TvEvents.evMouseWheel) and (ScrollBar <> nil) and
     ((Event.Mouse.Wheel = TvEvents.mwUp) or (Event.Mouse.Wheel = TvEvents.mwDown)) then
    begin
    if Event.Mouse.Wheel = TvEvents.mwUp then
      ScrollBar.SetValue(ScrollBar.Value-3*ScrollBar.ArStep)
    else
      ScrollBar.SetValue(ScrollBar.Value+3*ScrollBar.ArStep);
    CE;
    Exit;
    end;
  CurPos := ScrollBar.Value;
  if Files <> nil
  then
    if Files.Count > CurPos
    then
      PF := Files.At(CurPos)
    else
      PF := nil
  else
    PF := nil;
  I := ShiftState;
  KeyCode := DNKeyCode(Event) and $FFFF; {Cat}
  if  (Event.What = evKeyDown) and (I and 3 <> 0) and
      ( (KeyCode = kbCtrlRight and $FFFF) or (KeyCode = kbCtrlLeft and
         $FFFF) or
        ( (KeyCode = kbBack and $FFFF) and not QuickSearch))
  then
    begin
    CommandHandle(Event);
    Exit;
    end;
  if  (Event.What = evKeyDown) and (CommandLine <> nil) then
    if  ( (I and (kbRightShift+kbLeftShift) <> 0) and
          ( (KeyCode = kbDown and $FFFF) or
            (KeyCode = kbUp and $FFFF) or
            ( (KeyCode = kbCtrlIns and $FFFF) and (CmdLine.Str <> '')) or
            (KeyCode = kbGrayAst and $FFFF)
          )
        ) or
        ( ( (Event.KeyDown.CharScan.ScanCode < Hi(kbAlt1)) or
            (Event.KeyDown.CharScan.ScanCode > Hi(kbAlt9))
          ) and
          (Char(Event.KeyDown.CharScan.CharCode) = #0) and
          (CmdLine.Str <> '') and
          ( ( (I and 3 <> 0) xor (FMSetup.Options and fmoUseArrows = 0)) and
            ( (KeyCode = kbRight and $FFFF) or (KeyCode = kbLeft and
               $FFFF) or
              (KeyCode = kbHome and $FFFF) or (KeyCode = kbEnd and $FFFF)
            )
          )
        )
    then
      CommandLine.HandleEvent(Event);
  if Event.What = evNothing then
    Exit;
  { PanelArrowsPage (dn.ini, the File Manager setup): Left/Right go a page up/down, as PgUp/PgDn (P.1 of the vtui UX guidelines) }
  if PanelArrowsPage and (Event.What = evKeyDown) then
    if DNKeyCode(Event) = kbLeft then
      SetDNKeyCode(Event, kbPgUp)
    else if DNKeyCode(Event) = kbRight then
      SetDNKeyCode(Event, kbPgDn);
  I := ShiftState2;
  case Event.What of
    evCommand:
      case Event.Message.Command of
        cmDoSendLocated:
          SendLocated;
        cmGetDirName,
        cmGetName:
          begin
          if Drive.DriveType = dtDisk then
            begin
            
            { AK155 13.02.05 You can actually only get here from
            panelwin when handling Ctrl-[ and Ctrl-], possibly with Alt.
            And that very Alt we use to invert
            the long-or-short name working flag }
            if (PanSetup.Show.ColumnsMask and psLFN_InColumns <> 0) =
               (ShiftState and kbAltShift <> 0)
            then
              PString(Event.Message.InfoPtr)^:= lfGetShortFileName(DirectoryName)
            else
              
              PString(Event.Message.InfoPtr)^:= DirectoryName;
            end
          else if ScrollBar.Value < Files.Count then
            PString(Event.Message.InfoPtr)^:= PFileRec
                (Files.At(ScrollBar.Value))^.Owner^;
          ClearEvent(Event);
          end;
        cmKillUsed:
          Drive.KillUse;
        cmClose:
          CommandEnabling := False;
        cmCopyUnselect:
          begin
          CM_CopyUnselect;
          CE
          end;
        0..3, 5..100:
          ;
        else {case}
          CommandHandle(Event);
      end {case};

    evKeyDown:
      begin
      if QuickSearch then
        begin
        if Char(Event.KeyDown.CharScan.CharCode) = #27 then
          begin
          StopQuickSearch;
          InfoView.DrawView;
          CED;
          Exit
          end;
        if DNKeyCode(Event) = kbCtrlEnter then
          begin
          MaskSearch(1);
          CE;
          Exit;
          end;
        if  (DNKeyCode(Event) = kbGrayPlus) or (DNKeyCode(Event) = kbGrayMinus) or
            (DNKeyCode(Event) = kbGrayAst) or (DNKeyCode(Event) = kbIns) or
            (DNKeyCode(Event) = kbBackUp)
        then
          goto GotoKb;
        if (Char(Event.KeyDown.CharScan.CharCode) > #31) or
{$IFDEF DNUTF8}
              ((Event.KeyDown.TextLength > 0) and (Byte(Event.KeyDown.Text[0]) >= $80)) or
{$ENDIF}
              (DNKeyCode(Event) = kbBack) or
              (DNKeyCode(Event) = kbBackUp) or
              (DNKeyCode(Event) = kbCtrlRight) or
              (DNKeyCode(Event) = kbCtrlLeft)
        then
          begin
          DoQuickSearchEvent(Event);
          if not MaskSearch(0) then
            DoQuickSearch(kbBack)
          else
            InfoView.DrawView; { need to change both the mask and the file data }
          QSLastSuccessPos := LastSuccessPos;
          CED;
          Exit;
          end;
        end;

      if  ( ( (DNKeyCode(Event) = kbDoubleAlt)) and (FMSetup.Quick =
           pqsAlt)) or
          { a terminal gives no double Alt: Ctrl-S starts the quick search (the command line is empty: else it is the cursor left there) }
          ( (DNKeyCode(Event) = kbCtrlS) and (CmdLine.Str = '')) or
          ( (DNKeyCode(Event) = kbDoubleCtrl) and (FMSetup.Quick = pqsCtrl)) or
          ( IsTypedChar(Event) and
            (Char(Event.KeyDown.CharScan.CharCode) <> DnSep) and (FMSetup.Quick = pqsCaps) and
            (I and $40 <> 0)) or
          ( IsTypedChar(Event) and
            (ShiftState and 3 <> 0) and (ShiftState and 4 = 0) and
            (not CommandLine.GetState(sfVisible)) and
            (InterfaceData.Options and ouiHideCmdline <> 0))
      then
        begin
        if QuickSearch then
          begin
          StopQuickSearch;
          InfoView.DrawView; {Cat}
          end
        else
          begin
          InitQuickSearch(Self);
          QSLastSuccessPos := LastSuccessPos;
          end;
        if  IsTypedChar(Event) then
          begin
          if not ((ShiftState and 3 <> 0) and (not
                   CommandLine.GetState(sfVisible)))
          then
            begin
            ShiftState2 := I and $BF;
            ShiftState := ShiftState and kbCapsState;
            end
          else
            ShiftState := ShiftState and $FC;
          DoQuickSearchEvent(Event);
          if QuickSearch then
            begin
            if  (FMSetup.Quick = pqsCaps) and (I and kbCapsState <> 0)
            then
              begin
              (*
                        {$IFDEF VIRTUALPASCAL}
                        SysTVSetShiftState(ShiftState and not kbCapsState);
                        ShiftState := SysTVGetShiftState;
                        {$ENDIF}
                        *)
              end;
            if not MaskSearch(0) then
              DoQuickSearch(kbBack);
            end;
          end;
        DrawView;
        CE;
        end
      else
        begin
        if QuickSearch then
          begin
          if DNKeyCode(Event) and $FFFF = 0 then
            begin { A pure Shift event. If it is not ignored,
              then during quick search it is impossible to switch
              the layout, because keyboard drivers of both OS/2
              and Windows do not swallow the layout-change hotkey, but
              pass it to the application too. }
            ClearEvent(Event);
            Exit;
            end;
          StopQuickSearch;
          InfoView.DrawView;
          end;
GotoKb:
        case DNKeyCode(Event) of
          kbDel:
            if  ( (CmdLine.Str = '') and (FMSetup.Options and fmoDelErase
                   <> 0))
            then
              Message(Self, evCommand, cmPanelErase, nil);
          kbShiftDel:
            if  ( (CmdLine.Str = '') and (FMSetup.Options and fmoDelErase
                   <> 0))
            then
              Message(Self, evCommand, cmSingleDel, nil);
          { Flash >>> }
          kbCtrlHome:
            begin
            CE;
            DeltaX := 0;
            OldDelta := -1;
            Owner.Redraw
            end;
          kbCtrlEnd:
            begin
            CE;
            DeltaX := LineLength-Size.X-1;
            OldDelta := -1;
            Owner.Redraw
            end;
          kbHome:
            begin
            CE;
            OldDelta := -1;
            ScrollBar.SetValue(0);
            Owner.Redraw
            end;
          { Flash <<< }
          kbEnd:
            begin
            CE;
            OldDelta := -1;
            ScrollBar.SetValue(Files.Count-1)
            end;
          kbUp, kbDown, kbCtrlUp, kbCtrlDown, kbCtrlShiftUp,
           kbCtrlShiftDown, kbUpUp, kbDownUp
          :
            begin
            CtrlWas :=  LongRec(DNKeyCode(Event)).Hi = kbCtrlShift;
            if DNKeyCode(Event) = kbCtrlUp then
              SetDNKeyCode(Event, kbUp);
            if DNKeyCode(Event) = kbCtrlDown then
              SetDNKeyCode(Event, kbDown);
            if  (DNKeyCode(Event) = kbDownUp)
              or (DNKeyCode(Event) = kbUpUp)
            then
              begin
              CE;
              Exit
              end;
            end;
          kbIns, kbSpace:
            if CurPos < Files.Count then
              begin
              StopQuickSearch;
              if  (Char(Event.KeyDown.CharScan.CharCode) = ' ') and ((CmdLine.Str <> '') or
                    (FMSetup.Options and fmoSpaceToggle = 0))
              then
                Exit;
              CE;
              if Files.Count = 0 then
                Exit;
              PF := Files.At(CurPos);
              if PF^.TType <> ttUpDir then
                begin
                PF^.Selected := not PF^.Selected;
                if PF^.Size > 0 then
                  begin
                  SelectedLen := SelectedLen-(1-2*Integer(PF^.Selected))
                    *PF^.Size;
                  PackedLen := PackedLen-(1-2*Integer(PF^.Selected))
                    *PF^.PSize;
                  end;
                Dec(SelNum, 1-2*Integer(PF^.Selected));
                end;
              ScrollBar.SetValue(CurPos+1);
              if CurPos = ScrollBar.Value then
                DrawView;
              if InfoView <> nil then
                InfoView.DrawView;
              end;
          kbAltQuote:
            begin
            FMSetup.Show := FMSetup.Show xor fmsShowHidden;
            ConfigModified := True;
            Message(Application, evCommand, cmUpdateConfig, nil)
            end
          else {case}
            CommandHandle(Event);
        end {case};
        end;
      end; {evKeyDown}
    evBroadcast:
      case Event.Message.Command of
        cmFindForced,
        cmInsertDrive,
        cmUnArchive,
        cmCopyCollection,
        cmDropped:
          CommandHandle(Event);

        cmScrollBarChanged:
          if ScrollBar = Event.Message.InfoPtr then
            begin
            if ScrollBar.ForceScroll or WheelEvent then
              Inc(Delta, ScrollBar.Step);
                { Immediate scrolling keeping the cursor
                  position relative to the window }
            if MSelect then
              begin
              CE;
              if Files <> nil then
                begin
                if Files.Count = 0 then
                  Exit;
                PF := Files.At(ScrollBar.Value);
                if  (PF^.TType <> ttUpDir)
                  and (PF^.Selected xor SelectFlag)
                then
                  begin
                  PF^.Selected := SelectFlag;
                  if SelectFlag then
                    begin
                    Inc(SelNum);
                    if PF^.Size > 0 then
                      begin
                      SelectedLen := SelectedLen+PF^.Size;
                      PackedLen := PackedLen+PF^.PSize
                      end;
                    end
                  else
                    begin
                    Dec(SelNum);
                    if PF^.Size > 0 then
                      begin
                      SelectedLen := SelectedLen-PF^.Size;
                      PackedLen := PackedLen-PF^.PSize
                      end;
                    end;
                  end;
                end;
              end;
            PosChanged := True;
            if InfoView <> nil then
              InfoView.DrawView;
            CED;
            PosChanged := False;
            if  (RepeatDelay <> 0) and QuickViewEnabled then
              NeedLocated := GetSTime;
            end;
      end {case};
    evMouseDown:
      CommandHandle(Event);
  end {case};
  end { TFilePanel.HandleEvent };
{-DataCompBoy-}


class function TFilePanel.Build: TStreamable;
begin
  Result := TFilePanel.Create(streamableInit);
end;

function TFilePanel.StreamableName: ShortString;
begin
  Result := 'filepanel.TFilePanel';
end;

class function TDirView.Build: TStreamable;
begin
  Result := TDirView.Create(streamableInit);
end;

function TDirView.StreamableName: ShortString;
begin
  Result := 'filepanel.TDirView';
end;

end.

