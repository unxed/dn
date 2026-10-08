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

unit DiskInfo;

interface

uses SysUtils,
  Defines, Streams, Drivers, Views, Collect, topview
  ;

type
  PDiskInfoRec = ^TDiskInfoRec;
  TDiskInfoRec = record
    Title: PString;
    Dir: PString;
    Files: PString;
    Free: PString; { see TDrive.GetFreeSpace }
    Total: PString;
    VolumeID: PString;
    SerialNo: PString; { Rainbow }
    FileSys: PString; { Rainbow }
    DirInfo: TCollection;
    Limit: TPoint;
    InfoFile: Byte;
    ClusterSize: PString;
    end;

  TDriveView = class;

  TDiskInfo = class;
  TDiskInfo = class(TView)
    Info: TDiskInfoRec;
    Delta: TPoint;
    OtherPanel: TView{TFilePanelRoot};
      { File panel this info panel is linked to }
    DriveView: TDriveView;
      { Drive/share in the upper frame. See InsertDriveView and Done }
    constructor Create(R: TRect; Panel: TView{TFilePanelRoot});
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure InsertDriveView;
      { For disk info create DriveView and insert into Owner }
    procedure ReadData;
    procedure HandleEvent(var Event: TEvent); override;
    function GetPalette: TPalette; override;
    procedure Draw; override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    destructor Destroy; override;
    end;

  TDriveView = class(TTopView)
    InfoPanel: TDiskInfo;
    function GetText(MaxWidth: Integer): String; override;
    destructor Destroy; override;
    end;

function CountDirLen(const Dir: String; Recurse: Boolean;
{` Count files (NumFiles) and their total size (Result)
without descending into subdirectories. NumFiles includes directories too.
ClusterLen - total occupied space (including cluster tails).
  Calls GetDrInfo, so all GetDrInfo output variables
will also be defined }
    var ClusterLen: TSize; var NumFiles, NumDirs: Integer): TSize;
{`}

procedure GetDrInfo(CurDir: String);
{` Determines FreeSpc, TotalSpc, BytesPerCluster`}

procedure ReadDiskInfo(Dr: String; var B: TDiskInfoRec);

const
  CDiskInfo = #23#24;
  ifDirInfo = 0;
  ifFileID = 1;
  ifDescription = 2;
  ifReadMe = 3;
  ifReadTxt = 4;
  ifReadMeTxt = 5;

  sDirinfo = 'DirInfo';
  sFileID = 'File_ID.DIZ';
  sReadMe = 'Read.Me';
  sReadTxt = 'Read.Txt';
  sReadMeTxt = 'ReadMe.Txt';

type
  TTeamView = class;
  TTeamView = class(TView)
    LastTick: LongInt;
    Strings: array[1..20] of Integer;
    constructor Create(const R: TRect);
    procedure Draw; override;
    procedure Update; override;
    procedure HandleEvent(var Event: TEvent); override;
    destructor Destroy; override;
    end;

const
  TeamView: TTeamView = nil;

var
  FreeSpc, TotalSpc: TSize;
  {` Total disk size and free space on it. Determined for
  the full directory path (incl. network); NTFS soft links are followed.`}
  BytesPerCluster: LongInt;
  {` Determined for the drive root or network path. Soft links
  are not followed. `}

implementation
uses
  Startup, mainapp, Commands, DNHelp, Tree, timeutil
  , basics, strutil, DNUtf8, fileutil, TvGlyphs, Math
  , osdep, Lfn, keymap, objutil
  , fsinfo, panelroot, panelsetup, Dos
  , Strings;

const
  MaxTeam = Ord(dlTeam150)-Ord(dlTeamAll)+1;

function ESC_Pressed: Boolean;
  var
    E: TEvent;
  begin
  Application.Idle;
  GetKeyEvent(E);
  ESC_Pressed := (E.What = evKeyDown) and (DNKeyCode(E) = kbESC)
  end;

constructor TTeamView.Create(const R: TRect);
  begin
  inherited Create(R);
  UpdTicks := 500;
  Options := Options or ofPreProcess;
  RegisterToBackground(Self);
  end;

procedure TTeamView.Draw;
  var
    B: TDrawBuffer;
    S: String;
    I: Integer;
    C: Word;
  begin
  C := Owner.GetColorW($0807);
  MoveChar(B[0], ' ', C, Size.X);
  S := GetString(dlTeamAll);
  MoveCStr(B[(Size.X-CStrLen(S)) div 2], S, C);
  WriteLineC(0, 0, Size.X, 1, B);
  for I := 1 to Size.Y-1 do
    begin
    MoveChar(B[0], ' ', C, Size.X);
    if  (Strings[I] > 0) and (Strings[I] <= MaxTeam) then
      begin
      S := GetString(TStrIdx(Integer(dlTeamAll)+Strings[I]));
      MoveCStr(B[(Size.X-CStrLen(S)) div 2], S, C);
      end;
    WriteLineC(0, I, Size.X, 1, B);
    end;
  end { TTeamView.Draw };

procedure TTeamView.Update;
  var
    L, I: LongInt;
  begin
  Move(Strings[2], Strings[1], (Size.Y-2)*SizeOf(Integer));
  if  (Strings[Size.Y-1] > 0) and (Strings[Size.Y-1] < MaxTeam)
  then
    Inc(Strings[Size.Y-1]);
  if Strings[Size.Y-1] = MaxTeam then
    Strings[Size.Y-1] := 0;
  if  (Strings[Size.Y-1] = 0) and (Strings[1] = 0) then
    Strings[Size.Y-1] := 1;
  DrawView;
  end;

procedure TTeamView.HandleEvent(var Event: TEvent);
  begin
  if  (Event.What = evKeyDown) and (DNKeyCode(Event) = kbDown) then
    begin
    ClearEvent(Event);
    Update;
    NewTimer(UpTmr, 2000)
    end
  else if (Event.What = evKeyDown) and (DNKeyCode(Event) = kbUp) then
    begin
    ClearEvent(Event);
    Move(Strings[1], Strings[2], (Size.Y-2)*SizeOf(Integer));
    if Strings[1] > 0 then
      Dec(Strings[1]);
    if  (Strings[1] = 0) and (Strings[Size.Y-1] = 0) then
      Strings[1] := MaxTeam;
    DrawView;
    NewTimer(UpTmr, 2000)
    end
  end;

destructor TTeamView.Destroy;
  begin
  TeamView := nil;
  inherited Destroy;
  end;

function TDriveView.GetText(MaxWidth: Integer): String;
  var
    L: Word;
    Share: String;
    P: TFilePanelRoot;
  begin
  P := TFilePanelRoot(TDiskInfo(Panel).OtherPanel);
  if P = nil then
    Exit;
  Result := P.DirectoryName;
  L := Max(2, GetShareEnd(Result));
  SetLength(Result, L);
  if L = 2 then
    begin { Drive letter. Is it network?}
    Share := GetShare(Result[1]);
    if Share <> '' then
      Result := Result + ' ' + Share; { Indeed network }
    end;
  if StrCols(Result) > MaxWidth then
    Result := CutCols(Result, MaxWidth, FMSetup.RestChar[1]);   { columns, not bytes: a path in UTF-8 }
  end;

destructor TDriveView.Destroy;
  begin
  if InfoPanel <> nil then
    InfoPanel.DriveView := nil;
  inherited Destroy;
  end;

procedure DispInfo(var Info: TDiskInfoRec);
  begin
  with Info do
    begin
    if Title <> nil then
      DisposeStr(Title);
    if Dir <> nil then
      DisposeStr(Dir);
    if Files <> nil then
      DisposeStr(Files);
    if Free <> nil then
      DisposeStr(Free);
    if Total <> nil then
      DisposeStr(Total);
    if VolumeID <> nil then
      DisposeStr(VolumeID);
    if SerialNo <> nil then
      DisposeStr(SerialNo); { Rainbow }
    if FileSys <> nil then
      DisposeStr(FileSys); { Rainbow }
    if DirInfo <> nil then
      DirInfo.Free;
    if ClusterSize <> nil then
      DisposeStr(ClusterSize);
    end;
  FillChar(Info, SizeOf(Info), 0);
  end { DispInfo };

constructor TDiskInfo.Load(S: TStream);
  begin
  inherited Load(S);
  S.Read(Delta, SizeOf(Delta));
  GetPeerViewPtr(S, DriveView);
  end;

procedure TDiskInfo.Store(S: TStream);
  begin
  inherited Store(S);
  S.Write(Delta, SizeOf(Delta));
  PutPeerViewPtr(S, DriveView);
  end;

constructor TDiskInfo.Create(R: TRect; Panel: TView);
  begin
  inherited Create(R);
  OtherPanel := Panel;
  HelpCtx := hcDiskInfo;
  EventMask := evCommand or evKeyDown;
  Options := Options or ofSelectable or ofTopSelect;
  end;

procedure TDiskInfo.InsertDriveView;
  var
    R: TRect;
  begin
  if TFilePanelRoot(OtherPanel).Drive.DriveType <> dtDisk then
    Exit;
    { Such analysis is very ugly; it would be better to virtualize
    the info-panel header the way its contents are virtualized }

  R.Assign(0, Origin.Y-1, 0, Origin.Y);
    { On Y - onto the frame, and DriveView.Draw handles X each time }
  DriveView := TDriveView.Create(R);
  DriveView.Panel := Self;
  Owner.Insert(DriveView);
  DriveView.Panel := Self;
  end;

{ On explicit close of the info panel, e.g. on repeated Ctrl-L,
DriveView must also be closed explicitly. But when the manager
terminates, DriveView must not be terminated explicitly - it will be terminated as a member
of the manager group. And the order in which DriveView
and DiskInfo will terminate is unknown. And if after implicit freeing of DriveView
one also tries to terminate it explicitly, that will be a memory access error
and DN will crash when closing the manager.
  To avoid repeated terminations, we give DriveView and DiskInfo
mutual references which we clear when the referent is destroyed.
See also inherited Destroy;
}
destructor TDiskInfo.Destroy;
  begin
  DispInfo(Info);
  if DriveView <> nil then
    DriveView.InfoPanel := nil;
  inherited Destroy;
  end;

procedure TDiskInfo.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  if (DriveView <> nil) and ((AState and sfSelected) <> 0) then
    DriveView.Draw;
  end;

function TDiskInfo.GetPalette: TPalette;
  const
    S: String[Length(CDiskInfo)] = CDiskInfo;
  begin
  GetPalette := MakePalette(S);
  end;

procedure TDiskInfo.ReadData;
  var
    MemBlocks, I: Word;
  begin
  DispInfo(Info);
  Abort := False;
  with TFilePanelRoot(OtherPanel) do
    Drive.GetDirInfo(Info);
  Delta.Assign(0, 0);
  end;

procedure TDiskInfo.HandleEvent(var Event: TEvent);
  var
    S: String; {DataCompBoy}
  begin
  inherited HandleEvent(Event);
  if  (Event.What = evKeyDown) then
    case DNKeyCode(Event) of
      kbLeft:
        begin
        if Delta.X > 0 then
          begin
          Dec(Delta.X);
          SetState(sfExposed, True);
          DrawView
          end;
        ClearEvent(Event);
        end;
      kbRight:
        begin
        if Delta.X+Size.X-2 < Info.Limit.X then
          begin
          Inc(Delta.X);
          SetState(sfExposed, True);
          DrawView
          end;
        ClearEvent(Event);
        end;
      kbDown:
        begin
        if Delta.Y < Info.Limit.Y then
          begin
          Inc(Delta.Y);
          SetState(sfExposed, True);
          DrawView
          end;
        ClearEvent(Event);
        end;
      kbUp:
        begin
        if Delta.Y > 0 then
          begin
          Dec(Delta.Y);
          SetState(sfExposed, True);
          DrawView
          end;
        ClearEvent(Event);
        end;
    end
  else if (Event.What = evCommand) then
    case Event.Command of
      cmEditFile:
        begin
        ClearEvent(Event);
        case Info.InfoFile of
          ifFileID:
            S := sFileID;
          ifDirInfo:
            S := sDirinfo;
          ifReadMe:
            S := sReadMe;
          ifReadTxt:
            S := sReadTxt;
          ifReadMeTxt:
            S := sReadMeTxt;
          else {case}
            Exit;
        end {case};
        S := MakeNormName(TFilePanelRoot(OtherPanel).DirectoryName, S);
        Message(Application, evCommand, cmFileEdit, @S);
        end;
      cmInfoPresent:
        begin
        ClearEvent(Event);
        Event.InfoPtr := Owner
        end;
      cmRereadInfo:
        begin
        ReadData;
        DrawView;
        ClearEvent(Event);
        end;
    end {case};
  end { TDiskInfo.HandleEvent };

procedure TDiskInfo.Draw;
  var
    B: TDrawBuffer;
    C, Y, X: Word;
    R: TRect;
    S1, S2: String[20];
    CC: Boolean;

  procedure Wrt(S: String);
    var
      I: Integer;
    begin
    MoveChar(B[0], ' ', C, Size.X);
    I := (Size.X-CStrLen(S)) div 2;
    if  (I < 0) or CC then
      I := 0;
    MoveCStr(B[I], S, C);
    WriteLineC(0, Y, Size.X, 1, B);
    Inc(Y);
    end;

  procedure Wrt_(S: String); {temporary!!!}
    var
      I: Integer;
    begin
    MoveChar(B[0], ' ', C, Size.X);
    I := (Size.X-CStrLen(S)) div 2;
    if  (I < 0) or CC then
      I := 0;
    Replace('~', #0'~', S);
    S := '~'#0+S;
    {MoveStr(B[I], S, Lo(C);}
    MoveCStr(B[I], S, C);
    WriteLineC(0, Y, Size.X, 1, B);
    Inc(Y);
    end;

  procedure WrtTxt(S: String);
    var
      I: Integer;
    begin
    MoveChar(B[0], ' ', C, Size.X);
    MoveCStr(B[0], S, C);
    WriteLineC(0, Y, Size.X, 1, B);
    Inc(Y);
    end;

  procedure XWrt(P: PString; Flag: Word);
    begin
    if  (P <> nil) and (DriveInfoData and Flag <> 0) then
      Wrt(P^);
    end;

  begin { TDiskInfo.Draw }
  if DriveView <> nil then
    DriveView.Draw;
  C := (GetColorW(1) shl 8) or (GetColorW(2) and 255);
  Y := 0;
  CC := False;
  if  ( (Info.Title <> Info.Dir) or (Info.Title <> Info.Dir)) and
      (DriveInfoData and (fdiTitle+fdiTotals) <> 0)
  then
    begin
    XWrt(Info.Title, fdiTitle);
    {temporary!!!}
    if  (Info.Dir <> nil) and (DriveInfoData and fdiTitle <> 0) then
      Wrt_(Cut(Info.Dir^, Size.X));
    XWrt(Info.Files, fdiTotals);
    Wrt('');
    end;
  if  ( (Info.Total <> Info.Free) or (Info.Total <> Info.VolumeID)) and
      (DriveInfoData and (fdiVolumeSize+fdiVolumeFree+fdiVolumeLabel) <>
       0)
  then
    begin
    XWrt(Info.Total, fdiVolumeSize);
    XWrt(Info.Free, fdiVolumeFree);
    XWrt(Info.VolumeID, fdiVolumeLabel);
    end;
  XWrt(Info.SerialNo, fdiSerialNo);
  XWrt(Info.FileSys, fdiFileSys);
  XWrt(Info.ClusterSize, fdiFileSys);
  Wrt('');
  { Rainbow END }
  if DriveInfoData and fdiMemAvail <> 0 then
    Wrt('~'+FStr(MemAvail div 1024)+GetString(dlDIMemoryForDN));
  if DriveInfoData and fdiLowMemory <> 0 then
    Wrt('~'+FStr(PhysMemAvail div 1024)+GetString(dlDIMemoryTotal));
(*
  {$IFDEF DPMI32}
  if  (EMSFound or XMSFound) and (Y > 0)
    and (DriveInfoData and (fdiEMSFree+fdiXMSFree) <> 0)
  then
    Wrt(
      Strg(GlyphChar(glLightH), 19)
      );
  if  (DriveInfoData and fdiEMSFree <> 0) and EMSFound then
    begin
    Wrt
      ('EMS: ~'+ItoS(EMSSize)+GetString(dlDIEMS1)+ItoS(EMSFreePages*16)+
      GetString(dlDIEMS2));
    end;
  if  (DriveInfoData and fdiXMSFree <> 0) and XMSFound then
    Wrt('~'+ItoS(XMSFree)+GetString(dlDIXMSFree));
  {$ENDIF}
*)
  if  (Y > 0)
       and ((DriveInfoData ) and fdiDIZ <>
       0) and
      (Info.DirInfo <> nil) and (Info.DirInfo.Count > 0)
  then
    begin
    if Owner <> nil then
      C := Owner.GetColorW(1+Byte(Owner.GetState(sfActive)));
    FillChar(FreeStr[1], Size.X, 196);
    SetLength(FreeStr, Size.X);
    case Info.InfoFile of
      ifDirInfo:
        S1 := ' '+sDirinfo+' ';
      ifFileID:
        S1 := ' '+sFileID+' ';
      ifReadMe:
        S1 := ' '+sReadMe+' ';
      ifReadTxt:
        S1 := ' '+sReadTxt+' ';
      ifReadMeTxt:
        S1 := ' '+sReadMeTxt+' ';
      else {case}
        S1 := '';
    end {case};
    X := (Size.X-Length(S1)) div 2;
    if X < 0 then
      X := 0;
    Move(S1[1], FreeStr[X+1], Length(S1));
    Wrt(FreeStr);
    C := (GetColorW(1) shl 8) or (GetColorW(2) and 255);
    CC := True;
    for X := Delta.Y to Info.DirInfo.Count-1 do
      begin
      WrtTxt(Copy(CnvString(Info.DirInfo.At(X)), Delta.X, MaxStringLength));
      if Y > Size.Y then
        Break;
      end;
    end;
  MoveChar(B[0], ' ', C, Size.X);
  if Y <= Size.Y-1 then
    WriteLineC(0, Y, Size.X, Size.Y-Y+1, B);
  end { TDiskInfo.Draw };

{-DataCompBoy-}
{AK155: NumFiles includes NumDirs, so the number
of files alone is NumFiles-NumDirs}
function CountDirLen(const Dir: String; Recurse: Boolean; var ClusterLen: TSize; var NumFiles, NumDirs: Integer): TSize;
  var
    Tmr: TEventTimer;
    L: TSize;
    SR: lSearchRec;
    DC: TDirCol;
  begin
  NewTimer(Tmr, 50);
  ClusterLen := 0;
  L := 0;
  NumFiles := 0;
  NumDirs := 0;

  DC := TDirCol.Create($10, $10, False);
  DC.Insert(NewStr(Dir));
  Abort := False;
  while DC.Count > 0 do
    begin
    FreeStr := PString(DC.At(0))^;
    DC.AtFree(0);
    if Abort then
      Break;

    if TimerExpired(Tmr) then
      begin
      NewTimer(Tmr, 150);
      if ESC_Pressed then
        begin
        Abort := True;
        L := 0;
        Break
        end;
      end;

    if Word(Length(FreeStr)) > MaxPathLen-1 then
      begin
      Abort := True;
      Break
      end;

    DosError := 0;
    Abort := False;

    GetDrInfo(Dir); { For BytesPerCluster }
    if Abort then
      Exit;
    lFindFirst(MakeNormName(FreeStr, x_x), AnyFileDir, SR); {JO}
    while (DosError = 0) and not Abort do
      begin
      if not IsDummyDir( SR.SR.Name )
      then
        begin
        Inc(NumFiles);
        if SR.SR.Attr and Directory <> 0 then
          begin
          Inc(NumDirs); {AK155}
          if Recurse and (SR.SR.Attr and SysLinkAttr = 0) then   { a link to a directory is not entered: a loop of links }
            begin
            if  (Word(Length(FreeStr))+Word(Length(SR.FullName)) >
                 MaxPathLen-1)
              or (MaxAvail < Length(FreeStr+SR.FullName)+$41)
            then
              begin
              Abort := True;
              L := 0;
              Break
              end;
            DC.Insert(NewStr(MakeNormName(FreeStr, SR.FullName)));
            end;
          end
        else
          begin
          L := L+SR.FullSize;
          if BytesPerCluster > 0 then
            begin
            if Round(SR.FullSize/BytesPerCluster)
                -(SR.FullSize/BytesPerCluster) >= 0
            then
              ClusterLen := ClusterLen+Round(SR.FullSize/BytesPerCluster)
                *BytesPerCluster
            else
              ClusterLen := ClusterLen+Round(SR.FullSize/BytesPerCluster)
                *BytesPerCluster+BytesPerCluster;
            end;
          end;
        end;
      lFindNext(SR);
      end;
    lFindClose(SR);
    end;
  DC.FreeAll;
  DC.Free;
  CountDirLen := L;
  end { CountDirLen };
{-DataCompBoy-}

procedure GetDrInfo(CurDir: String);
  var
    Buffer: array[0..255] of Char;
    L: Integer;
  begin
  MakeNoSlash(CurDir);
  Strings.StrPCopy(@Buffer, CurDir);
  FreeSpc := SysDiskFreeLongX(@Buffer);
  TotalSpc := SysDiskSizeLongX(@Buffer);
  L := GetRootStart(CurDir);
  Buffer[L] := #0;
  BytesPerCluster := GetBytesPerCluster(@Buffer);
  end;

{-DataCompBoy-}
procedure ReadDiskInfo(Dr: String; var B: TDiskInfoRec);
  var
    VolumeLabel: String;
    SerialNo: Longint;
    FileSys: String; { Rainbow }
    S: String;
    S1, S2: String[30];
    F: TTextReader;
    DirLen: TSize;
    NumFiles, NumDirs: Integer;
    PathBuffer: array[0..255] of Char;
  begin
  ClrIO;
  if Dr = '' then
    lGetDir(0, Dr); {GetDir(0, S)} {Cat}
  if Abort then
    Exit;

  DispInfo(B);
  B.Title := NewStr(GetString(dlDICurDir));
  B.Dir := NewStr(Copy(Dr, GetRootStart(Dr), 255));

  Strings.StrPCopy(@PathBuffer, Dr);
  CountDirLen(Dr, False, DirLen, NumFiles, NumDirs);

  B.Total := NewStr('~' + FStr(TotalSpc)+GetString(dlDITotalDisk)
      + GetString(dlDIClusterSize) + ItoS(BytesPerCluster)
      );

  if NumFiles = 0 then
    B.Files := NewStr(GetString(dlDINoFiles))
  else
    begin
    if NumFiles = 1 then
      S1 := GetString(dlDIFile)
    else
      S1 := GetString(dlDIFiles);
    S2 := GetString(dlDIUsed);
    B.Files := NewStr
        ('~'+FStr(NumFiles)+'~ '+S1+GetString(dlDIWith)+'~'+FStr(DirLen)
        +'~ '+S2);
    end;

  B.InfoFile := ifDirInfo;
  B.DirInfo := TStringCollection.Create($10, $10, False);
  F := TTextReader.Create(MakeNormName(Dr, sDirinfo));
  if F = nil then
    begin
    B.InfoFile := ifFileID;
    F := TTextReader.Create(MakeNormName(Dr, sFileID));
    end;
  if F = nil then
    begin
    B.InfoFile := ifReadMe;
    F := TTextReader.Create(MakeNormName(Dr, sReadMe));
    end;
  if F = nil then
    begin
    B.InfoFile := ifReadTxt;
    F := TTextReader.Create(MakeNormName(Dr, sReadTxt));
    end;
  if F = nil then
    begin
    B.InfoFile := ifReadMeTxt;
    F := TTextReader.Create(MakeNormName(Dr, sReadMeTxt));
    end;
  if F = nil then
    B.InfoFile := ifFileID; {JO}
  B.Limit.X := 0;
  B.Limit.Y := 0;
  if F <> nil then
    begin
    while not F.Eof and (B.DirInfo.Count < 100) do
      begin
      S := F.GetStr;
      if Length(S) > B.Limit.X then
        B.Limit.X := Length(S);
      B.DirInfo.AtInsert(B.DirInfo.Count, NewStr(S));
      Inc(B.Limit.Y);
      end;
    F.Free;
    F := nil;
    end;
  GetSerFileSys(Dr[1], SerialNo, VolumeLabel, FileSys);
  if VolumeLabel = '' then
    VolumeLabel := GetString(dlDINone); {JO}
  B.VolumeID := NewStr(GetString(dlDIVolumeID) + VolumeLabel+'~');
  if SerialNo <> 0 then
    begin
    S := IntToHex(LongRec(SerialNo).Hi, 4) + '-' +
         IntToHex(LongRec(SerialNo).Lo, 4);
    B.SerialNo := NewStr(GetString(dlDISerialNo) + S + '~');
    end;
  if FileSys <> '' then
    B.FileSys := NewStr(GetString(dlDIFileSys) + FileSys+'~');
  end { ReadDiskInfo };
{-DataCompBoy-}

end.
