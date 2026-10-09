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

unit histories;

interface

uses
  SysUtils, Collect, Drivers, Defines, objutil, Streams, Views,
  Drives, basics, keymap
  , DBView 
  ;

type
  PViewRecord = ^TViewRecord;
  TViewRecord = record
    FName: PString;
    fOrigin: TPoint;
    fSize: TPoint;
    fDeskSize: TPoint;
    fViewMode: AInt;
    fKeyMap: TKeyMap;
    fToAscii: TXLat; // needed only when fKeyMap = kmXlat
    fCodeTag: Str8;
    case Byte of
      0: (fPos: Int64;
        fBufPos: AWord;
        fFilter: Byte;
        fHexEdit: Boolean;
        fWrap: Byte; {DataCompBoy}
        fXDelta: AInt;
        fHexPos: AInt;
        fCur: TPoint;
        fMarks: TFPosArray;
        );
      
      1: (fdDelta: TDBPoint;
        fdPos: TDBPoint;
        );
      
      
      2: (fsDelta: TPoint;
        fsCur: TPoint;
        fsMark: TPoint;
        fsCurrentCalc: TPoint;
        fsSearchPos: TPoint;
        fsErrorCell: TPoint);
      
    end;

  PEditRecord = ^TEditRecord;
  TEditRecord = record
    FName: PString;
    fOrigin: TPoint;
    fSize: TPoint;
    fDeskSize: TPoint;
    fPos: TPoint;
    fDelta: TPoint;
    fMarks: TPosArray;
    fBlockStart: TPoint;
    fBlockEnd: TPoint;
    fBlockVisible: Boolean;
    fVerticalBlock: Boolean;
    fHighlight: Boolean;
    fHiliteColumn: Boolean;
    fHiliteLine: Boolean;
    fAutoIndent: Boolean;
    fAutoJustify: Boolean;
    fAutoBrackets: Boolean;
    fInsMode: Boolean;
    fLeftSide,
    fRightSide,
    fInSide: AInt;
    fKeyMap: TKeyMap; {-$VIV}
    { Flash >>> }
    fBackIndent: Boolean;
    fAutoWrap: Boolean;
    fOptimalFill: Boolean;
    fTabReplace: Boolean;
    fSmartTab: Boolean;
    { Flash <<< }
    end;

  TEditHistoryCol = class;
  TEditHistoryCol = class(TCollection)
    function IndexOf(P: Pointer): LongInt; override;
    procedure WriteItem(P: Pointer; Os: opstream); override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure FreeItem(P: Pointer); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  TViewHistoryCol = class;
  TViewHistoryCol = class(TEditHistoryCol)
    procedure WriteItem(P: Pointer; Os: opstream); override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure FreeItem(P: Pointer); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

procedure AddToDirectoryHistory(S: String; DriveType: Integer);
procedure SaveCommands(Os: opstream);
procedure LoadCommands(Ip: ipstream);
procedure CmdHistory;
{DataCompBoy
procedure InitCommands;
}
function DirHistoryMenu: String;
procedure EditHistoryMenu;
procedure ViewHistoryMenu;
procedure StoreEditInfo(P: Pointer);
procedure StoreViewInfo(P: Pointer);
procedure StoreExtViewer(const FileName: String);
procedure AddCommand(const LastCommand: String);
function GetCommand(Idx: Integer): String;
procedure LoadHistories;
procedure SaveHistories;
procedure ClearHistories;
procedure DoneHistories; {Cat}

const
  MaxDirHistorySize = 40;
  MaxEditHistorySize = 20;

  CmdStrings: TCollection = nil;
  DirHistory: TCollection = nil;
  EditHistory: TCollection = nil;
  ViewHistory: TCollection = nil;

var
  HistNameSuffix: string;
    {` Suffixes for the history file name. For example, if this variable has
       the value 'Wrk', then the history will use the file DNWrk.HIS `}

implementation
uses DnPath, FlightRec,
  Lfn, Dos, Commands, mainapp, Dialogs, HistList,
  Startup, timeutil, Messages, DNUtil, DnIni,
  osdep, editwin, strutil,  fileutil, TvGlyphs,
  
  Idlers,
  
  FViewer, CmdLine, panelsetup, editcore
  , panelroot {for ActivePanel}
  , calcwin 
  ;

procedure FreeLastUnmarked(C: TCollection);

  var
    I: Integer;

  function IsThat(P_: Pointer): Boolean;
  var P: PEditRecord absolute P_;
    begin
    Dec(i);
    IsThat := (P^.FName <> nil) and (P^.FName^[1] = ' ');
    end;

  begin
  if  (C = nil) or (C.Count < 1) then
    Exit;
  I := C.Count;
  if C.LastThat(IsThat) <> nil then
    C.AtFree(I);
  end;

function TEditHistoryCol.IndexOf(P: Pointer): LongInt;
  var
    S, S1: String;
    I: Integer;
  begin
  IndexOf := -1;
  S := CnvString(PEditRecord(P)^.FName);
  S[1] := ' ';
  UpStr(S); {AK155}
  for I := 0 to Count-1 do
    begin
    S1 := CnvString(PEditRecord(At(I))^.FName);
    S1[1] := ' ';
    UpStr(S1); {AK155}
    if S1 = S then
      {-$VOL}
      begin
      IndexOf := I;
      Exit
      end;
    end;
  end;

procedure TEditHistoryCol.WriteItem(P: Pointer; Os: opstream);
  begin
  Os.WriteString(PEditRecord(P)^.FName);
  Os.WriteBytes(PEditRecord(P)^.fOrigin, SizeOf(TEditRecord)-SizeOf(PString));
  end;

function TEditHistoryCol.ReadItem(Ip: ipstream): Pointer;
  var
    R: PEditRecord;
  begin
  New(R);
  Result := R;
  R^.FName := Ip.ReadString;
  Ip.ReadBytes(R^.fOrigin, SizeOf(TEditRecord)-SizeOf(PString));
  end;

class function TEditHistoryCol.Build: TStreamable;
begin
  Result := TEditHistoryCol.Create(streamableInit);
end;

function TEditHistoryCol.StreamableName: ShortString;
begin
  Result := 'histories.TEditHistoryCol';
end;

procedure TEditHistoryCol.FreeItem(P: Pointer);
  begin
  if P <> nil then
    begin
    DisposeStr(PEditRecord(P)^.FName);
    Dispose(PEditRecord(P));
    end;
  end;

procedure TViewHistoryCol.WriteItem(P: Pointer; Os: opstream);
  begin
  Os.WriteString(PViewRecord(P)^.FName);
  Os.WriteBytes(PViewRecord(P)^.fOrigin, SizeOf(TViewRecord)-SizeOf(PString));
  end;

function TViewHistoryCol.ReadItem(Ip: ipstream): Pointer;
  var
    R: PViewRecord;
  begin
  New(R);
  Result := R;
  R^.FName := Ip.ReadString;
  Ip.ReadBytes(R^.fOrigin, SizeOf(TViewRecord)-SizeOf(PString));
  end;

class function TViewHistoryCol.Build: TStreamable;
begin
  Result := TViewHistoryCol.Create(streamableInit);
end;

function TViewHistoryCol.StreamableName: ShortString;
begin
  Result := 'histories.TViewHistoryCol';
end;

procedure TViewHistoryCol.FreeItem(P: Pointer);
  begin
  if P <> nil then
    begin
    DisposeStr(PViewRecord(P)^.FName);
    Dispose(PViewRecord(P));
    end;
  end;

procedure StoreViewInfo(P: Pointer);
  var
    Viewer: TFileWindow absolute P;
    
    DBView: TDBWindow absolute P;
    
    
    SSView: TCalcWindow absolute P;
    
    R: PViewRecord;
    I: Integer;
  label Q;
  begin
  if  (InterfaceData.Options and ouiTrackViewers = 0) or (P = nil) then
    Exit;
  if ViewHistory = nil then
    ViewHistory := TViewHistoryCol.Create(30, 30);
  New(R);

  if TView(P).ClassType = TFileWindow then
    with TFileViewer(Viewer.Current), R^ do
      begin
      if VFileName = '' then
        goto Q;
      
      FName := NewStr(' '+lfGetLongFileName(VFileName)); {DataCompBoy}
      
      fOrigin := Viewer.Origin;
      fSize := Viewer.Size;
      fDeskSize := Desktop.Size;
      if Filtr then
        fViewMode := ViewMode
      else
        fViewMode := ViewMode or vmInternal;

      {AK155 25-03-2003 After BufPos became longint, it may not fit into
fBufPos: AWord. But on the other hand,
it is unclear why remember FilePos and BufPos separately at all.
Bookmarks work without such a split.  }
      (*
     fPos      := FilePos;
     fBufPos   := BufPos;
     end;
*)
      fPos := FilePos+BufPos;
      fBufPos := 0;
      {/AK155 25-03-2003}

      fFilter := Filter;
      fHexEdit := HexEdit;
      fWrap := Wrap;
      fXDelta := XDelta;
      fHexPos := HexPos;
      fCur := Cur;
      fMarks := MarkPos;
      XCoder.ToHistory(fKeyMap, fToAscii, fCodeTag);
      end
       {-DataCompBoy-}
  else if TView(P).ClassType = TDBWindow then
    with DBView.P, R^ do
      begin
      if DBView.RealName = '' then
        goto Q;
      FName := NewStr(' '+DBView.RealName);
      fOrigin := Origin;
      fSize := Size;
      fDeskSize := Desktop.Size;
      fViewMode := vmDB;
    with DBView.P do
        begin
        fdDelta := Delta;
        fdPos := Pos;
        XCoder.ToHistory(fKeyMap, fToAscii, fCodeTag);
        end;
      end
      
      
  else if TView(P).ClassType = TCalcWindow then
    with SSView.CalcView, R^ do
      begin
      
      FName := NewStr(' '+lfGetLongFileName(CnvString(SName)));
      
      fOrigin := Origin;
      fSize := Size;
      fDeskSize := Desktop.Size;
      with SSView.CalcView do
        begin
        if ShowSeparators then
          fViewMode := vmSpreadSL {AK155}
        else
          fViewMode := vmSpread;
        fsDelta := Delta;
        fsCur := Cur;
        fsMark := Mark;
        fsCurrentCalc := CurrentCalc;
        fsSearchPos := SearchPos;
        fsErrorCell := ErrorCell;
        end;
      end
      
  else
Q:
    begin
    Dispose(R);
    R := nil
    end;
  {-DataCompBoy-}
  if R <> nil then
    begin
    I := ViewHistory.IndexOf(R);
    if I >= 0 then
      begin
      R^.FName^[1] := PViewRecord(ViewHistory.At(I))^.FName^[1];
      ViewHistory.AtFree(I);
      end;
    ViewHistory.AtInsert(0, R);
    end;
  if ViewHistory.Count > MaxEditHistorySize then
    FreeLastUnmarked(ViewHistory);
  SaveHistories; {AK155}
  end { StoreViewInfo };

procedure StoreExtViewer(const FileName: String);
  var
    R: PViewRecord;
    I: Integer;
  begin
  if  (InterfaceData.Options and ouiTrackViewers = 0) or (FileName = '')
  then
    Exit;
  if ViewHistory = nil then
    ViewHistory := TViewHistoryCol.Create(30, 30);
  New(R);

  with R^ do
    begin
    
    FName := NewStr(' '+lfGetLongFileName(FileName)); {DataCompBoy}
    
    fViewMode := vmExternal;
    end;
  I := ViewHistory.IndexOf(R);
  if I >= 0 then
    begin
    R^.FName^[1] := PViewRecord(ViewHistory.At(I))^.FName^[1];
    ViewHistory.AtFree(I);
    end;
  ViewHistory.AtInsert(0, R);
  if ViewHistory.Count > MaxEditHistorySize then
    FreeLastUnmarked(ViewHistory);
  end { StoreExtViewer };

procedure StoreEditInfo(P: Pointer);
  var
    E: TEditWindow absolute P;
    I: Integer;
    R: PEditRecord;
    PP: PEditRecord;

  begin
  if  (InterfaceData.Options and ouiTrackEditors = 0) or
      (TFileEditor(E.Intern).EditName = '')
  then
    Exit;
  if EditHistory = nil then
    EditHistory := TEditHistoryCol.Create(30, 30);
  New(R);
  with TFileEditor(E.Intern), R^ do
    begin
    FName := NewStr(' '+lfGetLongFileName(EditName)); {DataCompBoy}
    fOrigin := Owner.Origin;
    fSize := Owner.Size;
    fDeskSize := Desktop.Size;
    end;
  TFileEditor(E.Intern).FillRecord(R);
  I := EditHistory.IndexOf(R);
  if I >= 0 then
    begin
    R^.FName^[1] := PViewRecord(EditHistory.At(I))^.FName^[1];
    EditHistory.AtFree(I);
    end;
  EditHistory.AtInsert(0, R);
  if EditHistory.Count > MaxEditHistorySize then
    FreeLastUnmarked(EditHistory);
  SaveHistories; {AK155}
  end { StoreEditInfo };

procedure AddCommand(const LastCommand: String);
  var
    I: Integer;
    P: PString;
  label 1;
  begin
  if LastCommand <> '' then
    begin
    if CmdStrings = nil then
      CmdStrings := TLineCollection.Create(40, 40, False);
    for I := 0 to CmdStrings.Count-1 do
      begin
      P := CmdStrings.At(I);
      if Copy(CnvString(P), 2, MaxStringLength) = LastCommand then
        begin
        CmdStrings.AtRemove(I);
        CmdStrings.Insert(P);
        goto 1;
        end;
      end;
    CmdStrings.Insert(NewStr(' '+LastCommand));
1:
    I := 0;
    while (CmdStrings.Count > 50) and
        (I < CmdStrings.Count)
    do
      begin
      FreeStr := CnvString(CmdStrings.At(I));
      if FreeStr[1] <> '+' then
        begin
        {if LastTHistPos > I then Dec(LastTHistPos);}
        CmdStrings.AtFree(I);
        end
      else
        Inc(I);
      end;
    SaveHistories; {AK155}
    end;
  end { AddCommand };
{DataCompBoy
procedure InitCommands;
begin
 if CmdStrings <> nil then CmdStrings.Free;
 CmdStrings := TLineCollection.Create(40, 10);
 StrModified := False;
 CurString := 0;
end;
}
procedure SaveCommands(Os: opstream);
  var
    I, J: Integer;
    S1, S2: String;
    M: TCollection;
  begin
  {AK155 why this Message - unclear. Executing an empty command
does exactly nothing (see cmdline.pas, search for cmExecCommandLine)
Message(CommandLine, evCommand, cmExecCommandLine, nil);
/AK155}
  if  (CmdStrings <> nil) and (CmdStrings.Count >= 50) then
    begin
    M := TLineCollection.Create(50, 10, False);
    for I := 1 to 40 do
      begin
      if CmdStrings.Count <= 0 then
        Break;
      M.AtInsert(0, CmdStrings.At(CmdStrings.Count-1));
      CmdStrings.AtRemove(CmdStrings.Count-1);
      end;
    CmdStrings.Free;
    CmdStrings := M;
    end;
  Os.WritePointer(CmdStrings);
  if InterfaceData.Options and ouiTrackDirs <> 0 then
    Os.WritePointer(DirHistory)
  else
    Os.WritePointer(nil);
  if InterfaceData.Options and ouiTrackEditors <> 0 then
    Os.WritePointer(EditHistory)
  else
    Os.WritePointer(nil);
  if InterfaceData.Options and ouiTrackViewers <> 0 then
    Os.WritePointer(ViewHistory)
  else
    Os.WritePointer(nil);
  end { SaveCommands };

procedure LoadCommands(Ip: ipstream);
  var
    I: Integer;
  begin
  CmdStrings := TCollection(Ip.ReadPointer);
  DirHistory := TCollection(Ip.ReadPointer);
  EditHistory := TCollection(Ip.ReadPointer);
  ViewHistory := TCollection(Ip.ReadPointer);

  if CmdStrings <> nil then
    CurString := CmdStrings.Count
  else
    CurString := 0;
  {AK155 Command-line redraw is not needed, and clearing even gets in the way}
  (*
 StrModified := False;
 if CommandLine <> nil then CommandLine.DrawView;
 Str := '';
*)
  {/AK155}
  end;

function GetCommand(Idx: Integer): String;
  begin
  GetCommand := '';
  if  (CmdStrings = nil) or (CmdStrings.Count <= Idx)
         or (CmdStrings.At(Idx) = nil)
  then
    Exit;
  GetCommand := Copy(PString(CmdStrings.At(Idx))^, 2, MaxStringLength);
  end;

type
  TTHistList = class;
  TTHistList = class(TListBox)
    EVHistory, CommandHistory, RolledFwd: Boolean;
    Dlg: TDlgIdx; {AK155}
    function ItemStr(I: LongInt): PString;
    function IsSelected(I: LongInt): Boolean; override;
    function GetText(Item: LongInt; MaxLen: Integer): String; override;
    procedure SelectItem(Item: LongInt); override;
    procedure HandleEvent(var Event: TEvent); override;
    destructor Destroy; override;
    end;

function TTHistList.IsSelected(I: LongInt): Boolean;
  var
    P: PString;
  begin
  P := ItemStr(I);
  IsSelected := (P <> nil) and (P^[1] = '+');
  end;

function TTHistList.ItemStr(I: LongInt): PString;
  begin
  if EVHistory then
    ItemStr := PEditRecord(List.At(I))^.FName
  else
    ItemStr := List.At(I);
  end;

function TTHistList.GetText(Item: LongInt; MaxLen: Integer): String;
  var
    WasSlash: Boolean;
  begin
  FreeStr := CnvString(ItemStr(Item));
  if not RolledFwd then
    begin
    WasSlash := False;
    if FreeStr[Length(FreeStr)] = DnSep then
      begin
      SetLength(FreeStr, Length(FreeStr)-1);
      WasSlash := True;
      end;
    if WasSlash then
      FreeStr := Cut(FreeStr, Size.X-2) + DnSep
    else
      FreeStr := Cut(FreeStr, Size.X-1);
    end
  else
    begin
    if Length(FreeStr) > Size.X-1 then
      FreeStr := FreeStr[1] + #17 +
        Copy(FreeStr, Length(FreeStr) - (Size.X-4), Size.X-3);
    end;
  if FreeStr[1] = '+' then
    FreeStr[1] := GlyphChar(glSquare)
  else
    FreeStr[1] := ' ';
  GetText := FreeStr;
  end;

procedure TTHistList.SelectItem(Item: LongInt);
  var
    P: PString;
  begin
  P := ItemStr(Focused);
  if P <> nil then
    if P^[1] <> '+' then
      P^[1] := '+'
    else
      P^[1] := ' ';
  DrawView;
  end;

procedure TTHistList.HandleEvent(var Event: TEvent);
  label 1;
  var
    P: Pointer;

  procedure ScanMarked(D: Integer);
    var
      P: PString;
      I: Integer;
    begin
    ClearEvent(Event);
    I := Focused;
    repeat
      Inc(I, D);
      if  (I < 0) or (I >= List.Count) or (ItemStr(I)^[1] <> ' ') then
        Break;
    until False;
    if  (I >= 0) and (I < List.Count) then
      begin
      FocusItem(I);
      DrawView
      end;
    end;

  procedure SwapItems(i: Integer);
    var
      P: Pointer;
    begin
    with List do
      begin
      P := At(i);
      AtPut(i, At(i+1));
      AtPut(i+1, P);
      end;
    DrawView;
    end;

  var
    DirToGo: String;

  begin { TTHistList.HandleEvent }
  if  (Event.What = evKeyDown) and (List <> nil) then
    case DNKeyCode(Event) of
      kbCtrlEnter: {AK155: do as everyone else: CtrlEnter = Drop}
        begin
        EndModal(cmYes);
        ClearEvent(Event);
        Exit;
        end;
      kbDel:
        goto 1;
      kbShiftDown:
        if {(ShiftState and 3 <> 0) and}(Focused < List.Count-1) then
          SwapItems(Focused);
      kbShiftUp:
        if {(ShiftState and 3 <> 0) and}(Focused > 0) then
          SwapItems(Focused-1);
      kbRight, kbAltDown:
        ScanMarked(1);
      kbLeft, kbAltUp:
        ScanMarked(-1);
      kbCtrlRight:
        begin
        RolledFwd := True;
        DrawView;
        end;
      kbCtrlLeft:
        begin
        RolledFwd := False;
        DrawView;
        end;
    end
  else if (Event.What = evBroadcast) then
    case Event.Message.Command of
      cmOK:
        begin
        ClearEvent(Event);
        if (Focused < 0) or (Focused >= List.Count) then
          Exit;
        FreeStr := fDelLeft(fDelRight(Copy(CnvString(List.At(Focused)),
                 2, 255))); {-$VIV}
        {DataCompBoy}
        if InputBox(GetString(dlEditHistory),
             GetString(dlFindCellString), FreeStr, 255, hsEditHistory)
           <> cmOK
        then
          Exit;
        Insert(Copy(CnvString(List.At(Focused)), 1, 1), FreeStr, 1);
        List.AtReplace(Focused, NewStr(FreeStr));
        DrawView;
        end;
      cmYes: { delete }
1:
          begin
          ClearEvent(Event);
          if  (Dlg = dlgDirectoryHistory) and (Focused = 0) then
            begin
            MessageBox(GetString(dlHistDelCurDir), nil, mfOKButton);
            {John_SW}
            Exit;
            {AK155: 0 is the current directory;
                  deleting it is useless: it will be inserted again, but will
                  scramble the item numbering }
            end;
          if (Focused < 0) or (Focused >= List.Count) then
            Exit;
          if Copy(CnvString(ItemStr(Focused)), 1, 1) = '+' then
            begin
            if HistoryErrorBeep then
              begin
              SysBeepEx {PlaySound}(500, 110);
              end;
            Exit;
            end;
          if CommandHistory and (Focused <= CurString)
               and (CurString > 0)
          then
            Dec(CurString);
          List.AtFree(Focused);
          SetRange(List.Count);
          DrawView;
          end;

       cmNo: {go to}
          begin
          ClearEvent(Event);
          if (Focused < 0) or (Focused >= List.Count) then
            Exit;
          if (Dlg = dlgDirectoryHistory) then
            DirToGo := Copy(CnvString(List.At(Focused)), 2,
                            MaxStringLength)
          else
            DirToGo := Copy(PViewRecord(List.At(Focused))^.FName^, 2,
                            MaxStringLength);
          MakeNoSlash(DirToGo);
          Message(ActivePanel, evCommand, cmStandAt, @DirToGo);
          DrawView;
          EndModal(cmCancel); //Does not matter which command, the point is to finish
          end;

    end {case};
  inherited HandleEvent(Event);
  end { TTHistList.HandleEvent };

destructor TTHistList.Destroy;
  begin
  Items := nil;
  inherited Destroy;
  end;

procedure AddToDirectoryHistory(S: String; DriveType: Integer);
  var
    I: Integer;
    P: PString;

  function IsThat(P_: Pointer): Boolean;
  var P: PString absolute P_;
    begin
    Inc(i);
    IsThat := S = Copy(P^, 2, MaxStringLength);
    end;

  function IsThis(P_: Pointer): Boolean;
  var P: PString absolute P_;
    begin
    IsThis := P^[1] = ' ';
    end;

  begin
  if InterfaceData.Options and ouiTrackDirs = 0 then
    Exit;
  if  (S = '') or not IsQualified(S)
  then
    Exit;
  {Cat: added a check for network paths}
  
  S := lfGetLongFileName(S);
  
  if DirHistory = nil then
    DirHistory := TLineCollection.Create(40, 40, False);
  if  (DriveType <> Integer(dtList)) and
      (DriveType <> Integer(dtFind)) and
      (DriveType <> Integer(dtArcFind)) and
      (DriveType <> Integer(dtArvid)) and
      (DriveType <> Integer(dtArc))
  then
    MakeSlash(S)
  else
    begin
    MakeNoSlash(S);
    if  (DriveType = Integer(dtArvid)) or
        (DriveType = Integer(dtArc))
    then
      AddStr(S, DnSep);
    end;
  I := -1;
  P := DirHistory.FirstThat(IsThat);
  if P <> nil then
    DirHistory.AtRemove(I)
  else
    P := NewStr(' '+S);
  if P <> nil then
    DirHistory.AtInsert(0, P);
  if DirHistory.Count > MaxDirHistorySize then
    begin
    P := DirHistory.LastThat(IsThis);
    if P <> nil then
      DirHistory.Free(P);
    end;
  SaveHistories; {AK155}
  end { AddToDirectoryHistory };

function GetDialog(Dlg: TDlgIdx; var List: Pointer): TDialog;
  var
    D: TDialog;
    L: TTHistList; {AK155}
    P: TView;
    R: TRect;
  begin
  D := TDialog(LoadResource(Dlg));

  R := TRect.Create(D.Size.X-3, 2, D.Size.X-2, 13);
  P := TScrollBar.Create(R);
  D.Insert(P);

  R := TRect.Create(2, 2, D.Size.X-3, 13);
  L := TTHistList.Create(R, 1, TScrollBar(P));
  L.Dlg := Dlg; {AK155: see TTHistList.HandleEvent, cmYes }
  D.Insert(L);
  List := L;

  GetDialog := D;
  end;

procedure EditHistoryMenu;
  var
    D: TDialog;
    P: TTHistList;
    I: Integer;
  begin
  if InterfaceData.Options and ouiTrackEditors = 0 then
    begin
    Msg(dlSetEditHistory, nil, mfError+mfOKButton);
    Exit;
    end;
  ClearHistories;
  LoadHistories; {AK155}
  if EditHistory = nil then
    EditHistory := TEditHistoryCol.Create(30, 30);
  {  if EditHistory.Count = 0 then Exit;}
  D := GetDialog(dlgEditHistory, Pointer(P));
  P.NewLisT(EditHistory);
  P.EVHistory := True;
  if Desktop.ExecView(D) = cmOK then
    I := P.Focused
  else
    I := -1;
  D.Free;
  if EditHistory.Count = 0 then
    Exit; {Proverka, esli udalyali, zarazy:}
  if  (I >= 0) then
    begin
    if  (PViewRecord(EditHistory.At(I))^.FName = nil) then
      Exit;
    {A eto tak, na vsyakiy sluchay proverka, esli eto ne DPMI :}
    TDNApplication(Application).EditFile(
      SystemData.Options and ossEditor <> 0,
      {AK155 28.09.2002:
             so that history always invokes the internal
             editor, since an external editor call is not recorded in history}
      Copy(PViewRecord(EditHistory.At(I))^.FName^, 2, MaxStringLength));
    end;
  end { EditHistoryMenu };

procedure ViewHistoryMenu;
  var
    D: TDialog;
    P: TTHistList;
    I: Integer;
  begin
  if InterfaceData.Options and ouiTrackViewers = 0 then
    begin
    Msg(dlSetViewHistory, nil, mfError+mfOKButton);
    Exit;
    end;
  ClearHistories;
  LoadHistories; {AK155}
  if ViewHistory = nil then
    ViewHistory := TViewHistoryCol.Create(30, 30);
  {  if ViewHistory.Count = 0 then Exit;}
  D := GetDialog(dlgViewHistory, Pointer(P));
  P.NewLisT(ViewHistory);
  P.EVHistory := True;
  if Desktop.ExecView(D) = cmOK then
    I := P.Focused
  else
    I := -1;
  D.Free;
  if ViewHistory.Count = 0 then
    Exit; {Proverim, esli udalyali, pa**y}
  if I >= 0 then
    begin
    if  (PViewRecord(ViewHistory.At(I))^.FName = nil) then
      Exit; {Ku :}
    TDNApplication(Application).ViewFile(False, True, {AK155}
      Copy(PViewRecord(ViewHistory.At(I))^.FName^, 2, MaxStringLength));
    end;
  end { ViewHistoryMenu };

function DirHistoryMenu: String;
  var
    PC: TLineCollection;
    D: TDialog;
    P: TView;
    R: TRect;
    I: Integer;
    DT: record
      PC: TCollection;
      I: Integer;
      end;
  begin
  ClearHistories;
  LoadHistories; {AK155}
  DirHistoryMenu := '';

  if InterfaceData.Options and ouiTrackDirs = 0 then
    begin
    Msg(dlSetDirHistory, nil, mfError+mfOKButton);
    Exit;
    end;

  if DirHistory = nil then
    DirHistory := TLineCollection.Create(40, 40, False);
  {  if DirHistory.Count = 0 then Exit;}

  D := GetDialog(dlgDirectoryHistory, Pointer(P));

  TListBox(P).NewLisT(DirHistory);
  if DirHistory.Count > 1 then
    TListBox(P).Focused := 1;

  I := Desktop.ExecView(D);

  DT.I := TListBox(P).Focused;
  D.Free;
  if (I = cmOK) and (DT.I >= 0) and (DT.I < DirHistory.Count) then { an empty list: OK has nothing to give }
    DirHistoryMenu := Copy(CnvString(DirHistory.At(DT.I)), 2,
         MaxStringLength);
  end { DirHistoryMenu: };

procedure CmdHistory;
  var
    PC: TLineCollection;
    D: TDialog;
    P: TView;
    R: TRect;
    I: Integer;
    DT: record
      PC: TCollection;
      I: Integer;
      end;
  begin
  ClearHistories;
  LoadHistories; {AK155}
  if CmdStrings = nil then
    CmdStrings := TLineCollection.Create(40, 40, False);

  D := GetDialog(dlgCommandsHistory, Pointer(P));

  TListBox(P).NewLisT(CmdStrings);
  TListBox(P).FocusItem(CmdStrings.Count-1);
  TTHistList(P).CommandHistory := True;
  if CmdStrings.Count > 0 then
    TListBox(P).FocusItem(CmdStrings.Count-1);

  I := Desktop.ExecView(D);

  DT.I := TListBox(P).Focused;
  D.Free;

  if (I = cmCancel) or (CmdStrings.Count = 0) then { an empty list has no command to give }
    Exit;
  MessageKey(CommandLine, kbDown);

  CurString := DT.I;
  Str := GetCommand(DT.I);
  CommandLine.DrawView;
  MessageKey(CommandLine, kbEnd);
  if I <> cmYes then
    MessageKey(CommandLine, kbEnter);
  end { CmdHistory };

const
  { the last byte is the version of the format: #06 since the streams of tv3; a file of another version is not read }
  HistoryFileSign = 'DN OSP History file'#13#10#26#1#51#06;

  {-DataCompBoy-}
procedure LoadHistories;
  var
    S: TStream;
    Ip: ipstream;
    A: AWord;
  begin
  S := TBufStream.Create(ConfigDir+'dn'+HistNameSuffix+'.his', stOpenRead, 2048);
  if S.Status = stOK then
    begin
    S.Read(FreeStr[1], Length(HistoryFileSign));
    SetLength(FreeStr, Length(HistoryFileSign));
    if FreeStr = HistoryFileSign then
      begin
      Ip := ipstream.Create(S);
      try
        HistoryLoad(Ip);
        LoadCommands(Ip);
      except
        { a damaged file: the histories start empty, the file is written again at the exit }
        on E: Exception do
          begin
          FRNote('file', 'the histories were not read: ' + E.Message);
          ClearHistories;
          end;
      end;
      Ip.Free;
      end
    else
      FRNote('file', 'the histories are of another version: not read');
    end;
  S.Free;
  end { LoadHistories };
{-DataCompBoy-}

{-DataCompBoy-}
procedure SaveHistories;
  var
    S: TStream;
    Os: opstream;
    A: AWord;
  begin
  S := TBufStream.Create(ConfigDir+'dn'+HistNameSuffix+'.his', stCreate, 2048);
  if S.Status = stOK then
    begin
    FreeStr := HistoryFileSign;
    S.Write(FreeStr[1], Length(HistoryFileSign));
    Os := opstream.Create(S);
    HistoryStore(Os);
    SaveCommands(Os);
    Os.Free;
    end;
  S.Free;
  end;
{-DataCompBoy-}

procedure ClearHistories;
  var
    I, J, K: Integer;
    B: PChar;

  procedure ClearStrCollection(C: TCollection);
    begin
    if C = nil then
      Exit;
    C.Pack;
    i := 0;
    while i < C.Count do
      begin
      FreeStr := CnvString(C.At(i));
      if FreeStr[1] = ' ' then
        C.AtFree(i)
      else
        Inc(i);
      end;
    end;

  procedure ClearCollection(C: TCollection);
    begin
    if C = nil then
      Exit;
    C.Pack;
    i := 0;
    while i < C.Count do
      begin
      FreeStr := CnvString(PEditRecord(C.At(i))^.FName);
      if FreeStr[1] = ' ' then
        C.AtFree(i)
      else
        Inc(i);
      end;
    end;

  var
    A: AWord;
  begin { ClearHistories }
  HistoryRemoveEndingWith(' ');
  I := 0;
  ClearStrCollection(CmdStrings);
  ClearStrCollection(DirHistory);
  ClearCollection(EditHistory);
  ClearCollection(ViewHistory);
  end { ClearHistories };

{Cat}
procedure DoneHistories;
  begin
  if CmdStrings <> nil then
    CmdStrings.Free;
  if DirHistory <> nil then
    DirHistory.Free;
  if EditHistory <> nil then
    EditHistory.Free;
  if ViewHistory <> nil then
    ViewHistory.Free;
  end;
{/Cat}

end.
