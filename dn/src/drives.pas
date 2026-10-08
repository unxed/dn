{///////////////////////////////////////// ////////////////////////////////
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

unit Drives;

interface

uses
  Defines, objutil, Streams, Views, Drivers,
  FilesCol, DiskInfo, Collect
  , panelsetup
  ;

const
  dsActive = 0;
  dsInvalid = 1;

  

type
  TDrive = class;

{`2 Helper class inserted into a file panel.
  Holds features specific to the panel type (disk,
  archive, etc.). Used in particular for drawing
  file panel rows.`}
  TDrive = class(TStreamable)
    {Cat: this type is in the plugin model; change with extreme care!}
    Panel: Pointer{TFilePanelRoot};
    Prev: TDrive;
    DriveType: TDriveType;
    CurDir: String; {DataCompBoy}
    DizOwner: String; {DataCompBoy}
    NoMemory: Boolean;
    SizeX: LongInt;
    ColAllowed: TFileColAllowed;
      {` Depends on the panel type; introduced just in case to
      make future new panel types easier. `}
    
    constructor Create(ADrive: Byte; AOwner: Pointer);
    constructor Load(S: TStream);
    procedure Store(S: TStream); virtual;
    procedure KillUse; virtual;
    procedure lChDir(ADir: String); virtual; {DataCompBoy}
    function GetDir: String; virtual; {DataCompBoy}
    function GetDirectory(
         const FileMask: String;
        var TotalInfo: TSize): TFilesCollection; virtual;
    procedure CopyFiles(Files: TCollection; Own: TView; MoveMode: Boolean)
      ; virtual;
    procedure CopyFilesInto(Files: TCollection; Own: TView;
         MoveMode: Boolean); virtual;
    procedure EraseFiles(Files: TCollection); virtual;
    procedure UseFile(P: PFileRec; Command: Word); virtual;
    {DataCompBoy}
    procedure GetFreeSpace(var S: String); virtual;
    function Disposable: Boolean; virtual;
    function GetRealName: String; virtual;
    function GetInternalName: String; virtual;
    procedure GetFull(var B: TScreenCell; P: PFileRec; C, Sc: Word); virtual;
     {` Form in buffer B a file panel item for file
      P in color C with Draw-code of column separator Sc (the
      separator color may differ from the file color).
        This method works for all standard panel
      classes. It is virtual just in case. `}
    procedure MakeTop(var S: String); virtual;
     {` Form a (colored) column header string.
     This method is actually overridden in different panel
     classes. `}
    procedure RereadDirectory(S: String); virtual; {DataCompBoy}
    procedure GetDown(var B: TScreenCell; C: Word; P: PFileRec;
        var LFN_inCurFileLine: Boolean); virtual;
      {` Form the current-file footer string
      in buffer B with color C. LFN_inCurFileLine shows
      whether the long name was shown, and fully. `}
    procedure HandleCommand(Command: Word; InfoPtr: Pointer); virtual;
    procedure GetDirInfo(var B: TDiskInfoRec); virtual;
    function GetRealDir: String; virtual;
    procedure MakeDir; virtual;
    function isUp: Boolean; virtual;
    procedure ChangeUp(var S: String); virtual;
    procedure ChangeRoot; virtual;
    function GetFullFlags: Word; virtual;
    procedure EditDescription(PF: PFileRec); virtual; {DataCompBoy}
    procedure GetDirLength(PF: PFileRec); virtual; {DataCompBoy}
    destructor Destroy; override;
    function OpenDirectory(const Dir: String;
                                 PutDirs: Boolean): TDrive; virtual;
    procedure DrvFindFile(FC: TFilesCollection); virtual;
    procedure ReadDescrptions(FilesC: TFilesCollection); virtual;
    function GetDriveLetter: Char; virtual;
      {` For choosing a drive letter in the drive line and drive menu `}
    end;

procedure RereadDirectory(Dir: String);

const
  TempDirs: TSortedCollection = nil;
  TempFiles: TFilesCollection = nil;

implementation
uses
  osdep, DnPath, Lfn, uselfn, fsinfo,
  Startup, Tree, mainapp, FileCopy, Eraser, filepanel, Commands,
  Dialogs, FileFind, panelroot, Filediz, CmdLine
  , timeutil, Messages, dirwatch, Dos
  , progress {for TWhileView}, DnIni, basics, strutil, fileutil
  ;

const
  LowMemSize = $4000; {Local setting}

type
  {-DataCompBoy-}
  PDesc = ^TDesc;
    {`2 TDIZCol element }
  TDesc = record
    Name: String;
    DIZText: LongString;
    Line: LongInt;
    end;
    {`}
  {-DataCompBoy-}

  TDIZCol = class;
    {`2 Collection of descriptions from a description file. Used for
    fast lookup of descriptions by name when entering a directory.
    Names are stored in the collection in upper case. }
  TDIZCol = class(TSortedCollection)
    procedure FreeItem(P: Pointer); override;
    function Compare(P1, P2: Pointer): Integer; override;
    end;
    {`}

function ESC_Pressed: Boolean;
  var
    E: TEvent;
  begin
  Application.Idle;
  GetKeyEvent(E);
  ESC_Pressed := (E.What = evKeyDown) and (DNKeyCode(E) = kbESC)
  end;

{-DataCompBoy-}
procedure TDIZCol.FreeItem(P: Pointer);
  begin
  if P <> nil then
    begin
    PDesc(P)^.DIZText := ''; // free the string
    Dispose(PDesc(P));
    end;
  end;
{-DataCompBoy-}

function TDIZCol.Compare(P1, P2: Pointer): Integer;
  var
    Name2: String;
  begin
  Name2 := UpStrg(PDesc(P2)^.Name);
  if PDesc(P1)^.Name < Name2 then
    Compare := -1
  else if PDesc(P1)^.Name = Name2 then
    Compare := 0
  else
    Compare := 1;
  end;

procedure TDrive.GetFreeSpace(var S: String);
  begin
  GetDrInfo(CurDir);
  if FreeSpc < 0 then
    S := ''
  else
    S := '~'+FStr(FreeSpc)+GetString(dlDIFreeDisk);
  end;

{-DataCompBoy-}
constructor TDrive.Create(ADrive: Byte; AOwner: Pointer);
  begin
  inherited Create;
  Panel := AOwner;
  ClrIO;
  if ADrive < $1B then
    lGetDir(ADrive, CurDir) {A: ... Z:}
  else
    CurDir := ''; {any other - i.e. \\server\share}
  
  DriveType := dtDisk;
  ColAllowed := PanelFileColAllowed[pcDisk];
  end { TDrive.Init };
{-DataCompBoy-}

{-DataCompBoy-}
constructor TDrive.Load(S: TStream);
  begin
  inherited Create;
  Prev := TDrive(S.Get);
  S.ReadStrV(CurDir);
  {S.Read(CurDir[0], 1); S.Read(CurDir[1], Length(CurDir));}
  
  S.Read(ColAllowed, SizeOf(ColAllowed));
  
  DriveType := dtDisk;
  NoMemory := False;
  end { TDrive.Load };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TDrive.Store(S: TStream);
  begin
  S.Put(Prev);
  S.WriteStr(@CurDir); {S.Write(CurDir, Length(CurDir)+1);}
  
  S.Write(ColAllowed, SizeOf(ColAllowed));
  end;
{-DataCompBoy-}

destructor TDrive.Destroy;
  begin
  if Prev <> nil then
    Prev.Free;
  inherited Destroy;
  end;

function TDrive.Disposable: Boolean;
  begin
  Disposable := True;
  end;

{-DataCompBoy-}
procedure TDrive.ChangeUp(var S: String);
  begin
  S := GetName(CurDir);
  lChDir(MakeNormName(CurDir, '..'));
  if Abort then
    Exit;
  lGetDir(0, CurDir);
  if Abort then
    Exit;
  end;
{-DataCompBoy-}

{-DataCompBoy-}
procedure TDrive.ChangeRoot;
  var
    I: Word;
    B: Boolean;
  begin
  {Cat: check for a network path}
  if not HasDrives then
    begin
    lChDir(PathSep);
    lGetDir(0, CurDir);
    end
  else if CurDir[1] = '\' then
    begin
    B := False;
    for I := 3 to Length(CurDir) do
      if CurDir[I] = '\' then
        if B then
          begin
          CurDir := Copy(CurDir, 1, I-1);
          lChDir(CurDir);
          Break;
          end
        else
          B := True;
    end
  else
    {/Cat}
    begin
    lChDir(CurDir[1]+':\');
    {
      if Abort then
        Exit;
      }
    lGetDir(0, CurDir);
    {
      if Abort then
        Exit;
      }
    end;
  end { TDrive.ChangeRoot };
{-DataCompBoy-}

function FormatSizeCol(P: PFileRec): String;
  { Form the size column. This may be either
  an actual size, or a directory designation
  if its size is unknown }
  begin
  with P^ do
    begin
    if Size >= 0 then
      Result := FileSizeStr(Size)
    else if TType = ttUpDir then
      Result := GetString(dlUpDir)
        
    else
      Result := GetString(dlSubDir);
    end;
  end;

procedure TDrive.MakeTop(var S: String);
  var
    Q: String;
    Flags: Word;
    i: TFileColNumber;
    LFNLen: Word;
  begin
  Flags := TFilePanelRoot(Panel).PanSetup.Show.ColumnsMask;
  for i := Low(TFileColAllowed) to High(TFileColAllowed) do
    begin
    if not ColAllowed[i] then
      Flags := Flags and not (1 shl Ord(i));
    end;
  { Now Flags contains only bits allowed for this panel type }
  LFNLen := TFilePanelRoot(Panel).CalcNameLength;
  if not TFilePanelRoot(Panel).LFNLonger250 then
    begin
    
    if uLFN then
      begin
      
      if LFNLen <= SizeX then
        S := CenterStr(GetString(dlTopLFN), LFNLen)+GetString(dlTopSplit)
      else
        S := AddSpace(CenterStr(GetString(dlTopLFN), SizeX), LFNLen)
          
          ;
      end
    else
      S := GetString(dlTopName)
        
    end
  else
    S := '';
  if Flags and psShowSize <> 0 then
    S := S+GetString(dlTopSize); //! for dtArcDrive should be dlTopOriginal
  if Flags and psShowPacked <> 0 then
    S := S+GetString(dlTopPacked);
  if Flags and psShowRatio <> 0 then
    S := S+GetString(dlTopRatio);
  if Flags and psShowDate <> 0 then
    S := S+GetString(dlTopDate);
  if Flags and psShowTime <> 0 then
    S := S+Copy(GetString(dlTopTime), 1+CountryInfo.TimeFmt, 255);
  if Flags and psShowCrDate <> 0 then
    S := S+GetString(dlTopCrDate);
  if Flags and psShowCrTime <> 0 then
    S := S+Copy(GetString(dlTopCrTime), 1+CountryInfo.TimeFmt, 255);
  if Flags and psShowLADate <> 0 then
    S := S+GetString(dlTopLADate);
  if Flags and psShowLATime <> 0 then
    S := S+Copy(GetString(dlTopLATime), 1+CountryInfo.TimeFmt, 255);
  if TFilePanelRoot(Panel).LFNLonger250 then
    begin
    S := S+AddSpace(CenterStr(GetString(dlTopLFN), SizeX-Length(S)),
         LFNLen);
    Exit;
    end;
  if  Flags and psShowDescript <> 0 then
    S := S+' '+GetString(dlPnlDescription)+' '+Strg(#32, 255);
  if Flags and psShowDir <> 0 then
    begin
    Q := GetString(dlTopPath);
    S := S+Q+Strg(' ', 252-Length(Q)) {+ '~'#179'~'};
    end;
  end { TDrive.MakeTop };

procedure TDrive.GetFull(var B: TScreenCell; P: PFileRec; C, Sc: Word);
  var
    X: Word;
    Flags: Word;

  procedure FormatDateTime(DateFlag, TimeFlag: Word; DT: Longint; Yr: Word);
    var
      S1: String;
    begin
    if Flags and (DateFlag or TimeFlag) <> 0 then
      begin
      with TDate4(DT) do
        MakeDate(Day, Month, Yr, Hour, Minute, S1);
      if DT = 0 then
        FillChar(S1[1], Length(S1), ' ');
      if Flags and DateFlag <> 0 then
        begin
        MoveStr(PCellArray(@B)^[X],
           Copy(S1, 1, FileColWidht[psnShowDate]-1), C);
        Inc(X, FileColWidht[psnShowDate]);
        if X >= 255 then
          Exit;
        PCellArray(@B)^[X-1] := CellFromBIOS(Sc);
        end;
      if Flags and TimeFlag <> 0 then
        begin
        Delete(S1, 1, FileColWidht[psnShowDate]);
        MoveStr(PCellArray(@B)^[X], S1, C);
        Inc(X, Length(S1)+1);
        if X >= 255 then
          Exit;
        PCellArray(@B)^[X-1] := CellFromBIOS(Sc);
        end;
      end;
    end;

  var
    NameString: String;
    NameLen: Integer;
    S: String;
    D: Word;
    i: TFileColNumber;
  begin {TDrive.GetFull}
  Flags := TFilePanelRoot(Panel).PanSetup.Show.ColumnsMask;
  for i := Low(TFileColAllowed) to High(TFileColAllowed) do
    begin
    if not ColAllowed[i] then
      Flags := Flags and not (1 shl Ord(i));
    end;
  { Now Flags contains only bits allowed for this panel type }

  TFilePanelRoot(Panel).FormatName(P, NameString, NameLen);
  if P^.Selected then
    begin
    Sc := Sc and $00FF + C and $FF00;
    C := Swap(C);
    end;
  X := 0;
  if not TFilePanelRoot(Panel).LFNLonger250 then
    begin
    MoveCStr(PCellArray(@B)^[0], NameString, C);
    X := NameLen;
    PCellArray(@B)^[X] := CellFromBIOS(Sc);
    Inc(X);
    end;
  if X >= 255 then
    Exit;

  if Flags and psShowSize <> 0 then
    begin
    S := FormatSizeCol(P);
    MoveStr(PCellArray(@B)^[X], S, C);
    Inc(X, FileColWidht[psnShowSize]);
    if X >= 255 then
      Exit;
    PCellArray(@B)^[X-1] := CellFromBIOS(Sc);
    end;

  if Flags and psShowPacked <> 0 then
    begin
    if P^.Size >= 0 then
      S := FileSizeStr(P^.PSize)
    else
      S := AddSpace('', FileColWidht[psnShowPacked]-1);
    MoveStr(PCellArray(@B)^[X], S, C);
    Inc(X, FileColWidht[psnShowPacked]);
    if X >= 255 then
      Exit;
    PCellArray(@B)^[X-1] := CellFromBIOS(Sc);
    end;

  if Flags and psShowRatio <> 0 then
    begin
    if (P^.Size > 0) or (P^.Attr and Directory = 0) then
      S := Percent(P^.Size, P^.PSize)
    else
      S := '';
    S := PredSpace(S, FileColWidht[psnShowRatio]);
    MoveStr(PCellArray(@B)^[X], S, C);
    Inc(X, FileColWidht[psnShowRatio]);
    if X >= 255 then
      Exit;
    PCellArray(@B)^[X-1] := CellFromBIOS(Sc);
    end;

  FormatDateTime(psShowDate, psShowTime, P^.FDate, P^.Yr);
  FormatDateTime(psShowCrDate, psShowCrTime, P^.FDateCreat, P^.YrCreat);
  FormatDateTime(psShowLADate, psShowLATime, P^.FDateLAcc, P^.YrLAcc);

  if TFilePanelRoot(Panel).LFNLonger250 then
    begin { a long name at the end suppresses comment and path output }
    MoveCStr(PCellArray(@B)^[X], NameString, C);
    Exit;
    end;

  if Flags and psShowDescript <> 0 then
    begin
    S := ' ';
    if P^.DIZ <> nil then
      S := DizMaxLine(P^.DIZ);
    S := AddSpace(S, MaxViewWidth-X-1);
    MoveStr(PCellArray(@B)^[X], S, C);
    Exit;
    end;

  if Flags and psShowDir <> 0 then
    begin
    MoveStr(PCellArray(@B)^[X], AddSpace( (P^.Owner^), MaxViewWidth-X-1), C);
    Exit;
    end;
end;

procedure TDrive.EraseFiles(Files: TCollection);
  begin
  if Disposable then
    Eraser.EraseFiles(Files);
  end;

procedure TDrive.MakeDir;
  begin
  MakeDirectory;
  end;

procedure TDrive.CopyFiles(Files: TCollection; Own: TView; MoveMode: Boolean);
  var
    B: Boolean;
  begin
  if ReflectCopyDirection
  then
    RevertBar := Message(Desktop, evBroadcast, cmIsRightPanel, Own) <> nil
  else
    RevertBar := False;
  if Disposable then
    FileCopy.CopyFiles(Files, Own, MoveMode, 2*Byte(Self is TFindDrive));
  end;

procedure TDrive.CopyFilesInto(Files: TCollection; Own: TView; MoveMode: Boolean);
  var
    B: Boolean;
  begin
  if ReflectCopyDirection
  then
    RevertBar := (Message(Desktop, evBroadcast, cmIsRightPanel, Own) <>
         nil)
  else
    RevertBar := False;
  FileCopy.CopyFiles(Files, Own, MoveMode, 0);
  end;

{-DataCompBoy-}
procedure TDrive.lChDir(ADir: String);
  var
    I: Word;
    S: String;

  function AskRetry(Drive: Char; RC: Integer): Boolean;
    begin
    ClrIO;
    NeedAbort := False;
    SysErrorFunc(RC, Byte(Drive)-65);
    AskRetry := not Abort;
    end;

  function ValidPath(var ATestDir: String; Ask: Boolean): Boolean;
    var
      S: String;
      Drive: Char;
      OK: Boolean;
      I: Word;
    begin
    OK := False;
    ClrIO;
    NeedAbort := True;
    ATestDir := lFExpand(ATestDir);
    {Cat: check for a network path}
    if not HasDrives then
      OK := True                    { one tree: nothing to probe before the directory itself }
    else if  (Length(ATestDir) > 2) and (ATestDir[1] = '\')
         and (ATestDir[2] = '\')
    then
      begin
      OK := False;
      for I := 3 to Length(ATestDir) do
        if ATestDir[I] = '\' then
          begin
          OK := True;
          Break;
          end;
      end
    else
      {/Cat}
      begin
      if  (Length(ATestDir) > 1) and (ATestDir[2] = ':') then
        Drive := ATestDir[1]
      else
        Drive := Char(GetDrive+Byte('A'));
      S := Drive+':\';
      repeat
        ClrIO;
        NeedAbort := True;
        Lfn.lChDir(S);
        I := IOResult;
        Abort := Abort or (I <> 0);
        if Abort then
          begin
          if Ask and AskRetry(Drive, I) then
            Continue;
          end
        else
          OK := True;
        Break;
      until False;
      end;
    if OK then
      repeat
        ClrIO;
        NeedAbort := True;
        Lfn.lChDir(ATestDir);
        I := IOResult;
        Abort := Abort or (I <> 0);
        if Abort then
          begin
          S := GetPath(ATestDir);
          MakeNoSlash(S);
          if S <> ATestDir then
            begin
            ATestDir := S;
            Continue;
            end;
          OK := False;
          end;
        Break;
      until False;
    ClrIO;
    NeedAbort := False;
    ValidPath := OK;
    end { ValidPath };

  begin { TDrive.lChDir }
  
  NeedAbort := True;
  if ValidPath(ADir, True) then
    begin
    
    CurDir := ADir;
    Exit;
    end;
  if ValidPath(CurDir, False) then
    begin
    
    {CurDir:=CurDir;}Exit;
    end;
  if HasDrives then
    ADir := 'C:\'
  else
    ADir := PathSep;
  if ValidPath(ADir, False) then
    begin
    
    CurDir := ADir;
    Exit;
    end;
  if HasDrives then
    begin
    ADir := 'A:\';
    if ValidPath(ADir, False) then
      begin
      CurDir := ADir;
      Exit;
      end;
    end;
  CurDir := '';
  end { TDrive.lChDir };
{-DataCompBoy-}

{-DataCompBoy-}
function TDrive.GetDir: String;
  begin
  
  GetDir := lfGetLongFileName(CurDir);
  
  end;
{-DataCompBoy-}

{-DataCompBoy-}
procedure TDrive.UseFile(P: PFileRec; Command: Word);
  var
    S: String;
  begin
  if P^.Owner <> nil then
    S := MakeNormName(P^.Owner^, P^.FlName[uLfn]);
  Message(Application, evCommand, Command, @S);
  end;
{-DataCompBoy-}

{ Prepare a sorted collection of descriptions from which descriptions will
be easy to find while reading the directory. Used by ReadFileList}
var
  Descriptions: TDIZCol;
  PD: PDesc;
  IgnoreDiz: Boolean;

function DizNameProc(const N: string; TextStart: Integer): Boolean;
  { For ReadFileList. Insert a collection element and the first line }
  var
    I: Integer;
  begin
  IgnoreDiz := Descriptions.Search(@N, I);
    // Ignore duplicate description
  if not IgnoreDiz then
    begin
    New(PD);
    PD^.Name := N;
    PD^.DizText := Copy(LastDizLine, TextStart, MaxLongStringLength);
    Descriptions.AtInsert(I, PD);
    end;
  end;

procedure DizLineProc;
  { For ReadFileList. Append the next line directly into the
    collection element}
  const
    CrLf: string[2] = #13#10;
  begin
  if not IgnoreDiz then
    PD^.DizText := PD^.DizText + CrLf + LastDizLine;
  end;

function DizEndProc: Boolean;
  { For ReadFileList. Nothing to do}
  begin
  Result := False;
  end;

procedure PrepareDIZ(
  { Read the description container and create the description collection }
    const CurDir: String;
    var Container: String);
  begin
  ClrIO;
  Container := GetDizPath(CurDir, '');
  if Container <> '' then
    begin
    OpenFileList(Container);
    Descriptions := TDIZCol.Create($10, $10);
    ReadFileList(DizNameProc, DizLineProc, DizEndProc);
    end;
  ClrIO;
  end;
{-DataCompBoy-}

{-DataCompBoy-}
procedure TossDescriptions(
    PDizContainer: Pointer;
    FilesC: TFilesCollection);
  var
    I, J: LongInt;
    P: PFileRec;
    FName: String;
    PD: PDesc;
    iLFN: TUseLFN;
  begin
  for I := 1 to FilesC.Count do
    begin
    P := FilesC.At(I-1);
    for iLFN := High(TUseLFN) downto Low(TUseLFN) do
      begin
      FName := P^.FlName[iLFN];
      {if P^.Attr and (Directory+SysFile) <> 0 then LowStr(FName);}
      if Descriptions.Search(@FName, J) then
        begin
        PD := PDesc(Descriptions.At(J));
        New(P^.DIZ);
        P^.DIZ^.DIZText := PD^.DIZText;
        P^.DIZ^.Container := PDizContainer;
        P^.DIZ^.Line := PD^.Line;
//        PD^.DIZText := '';
  {AnsiString does not spend memory on copying, so we need not hurry
  to free and can wait until the collection element is freed }
        Break;
        end
      end;
    end;
  end { TossDescriptions };
{-DataCompBoy-}


procedure TDrive.ReadDescrptions(FilesC: TFilesCollection);
  begin
  PrepareDIZ(CurDir, DizOwner);
  if Descriptions <> nil then
    begin
    TossDescriptions(@DizOwner, FilesC);
    Descriptions.Free;
    end;
  end;

function TDrive.GetDriveLetter: Char;
  begin
  Result := CurDir[1];
  end;

{-DataCompBoy-}
function TDrive.GetDirectory( const FileMask: String; var TotalInfo: TSize): TFilesCollection;
  var
    SR: lSearchRec;
    P: PFileRec;
    I, J: Integer;
    TFiles: Word;
    Files: TFilesCollection;
    MemReq: LongInt;
    MAvail: LongInt;
    SearchAttr: word;
    PName: PString; //AK155 In SR the name for mask comparison
  begin
  ClrIO;
  PName := @SR.FullName;
  
  if (Panel <> nil) and
     ((TFilePanelRoot(Panel).PanSetup.Show.ColumnsMask
       and psLFN_InColumns) = 0)
  then // short names in the panel
    PName := @SR.SR.Name;
  

  TFiles := 0;
  DizOwner := '';
  Descriptions := nil;
  Abort := False;
  NoMemory := False;
  TotalInfo := 0;
  Files := TFilesCollection.Create($10, $20);
  Files.Panel := Panel;

  {JO: first determine available memory once, then along the way}
  {    keep track of how memory requirements grow and whether they exceeded  }
  {    the initially available amount                                              }
  MemReq := LowMemSize;
  MAvail := MaxAvail;

  SearchAttr := AnyFileDir;
  if Security then
    SearchAttr := AnyFileDir and not Hidden;
  lFindFirst(MakeNormName(CurDir, x_x), SearchAttr, SR);
  while (DosError = 0) and not Abort and (MAvail > MemReq)
  do
    begin
    if not IsDummyDir(SR.SR.Name) and
      ((SR.SR.Attr and Directory <> 0) or InFilter(PName^, FileMask))
    then
      begin
      P := NewFileRec(SR.FullName , SR.SR.Name 
          , SR.FullSize, SR.SR.Time, SR.SR.CreationTime
          , SR.SR.LastAccessTime, SR.SR.Attr, @CurDir);
      Inc(MemReq, SizeOf(TFileRec));
      Inc(MemReq, Length(CurDir+SR.FullName)+2);
      
      if SR.SR.Attr and Directory = 0 then
        begin
        TotalInfo := TotalInfo+P^.Size;
        Inc(TFiles);
        end;
      with Files do
        AtInsert(Count, P)
      end;
    DosError := 0;
    lFindNext(SR);
    end;
  lFindClose(SR);
  NoMemory := (MAvail <= MemReq);
  if  (Length(CurDir) > GetRootStart(CurDir)) then
    begin
    Files.AtInsert(0, NewFileRec('..',
       '..', 
      -1, 0, 0, 0, Directory, @CurDir));
    end;
  GetDirectory := Files;
  end { TDrive.GetDirectory };
{-DataCompBoy-}

function TDrive.isUp: Boolean;
  begin
  {if Length(CurDir)>3 then}isUp := False { else isUp:=true;}
  end;

procedure TDrive.RereadDirectory(S: String);
  begin
  if Prev <> nil then
    Prev.RereadDirectory(S);
  end;

procedure TDrive.GetDirInfo(var B: TDiskInfoRec);
  begin
  ReadDiskInfo(CurDir, B);
  B.Free := NewStr(TFilePanelRoot(Panel).FreeSpace);
  end;

procedure TDrive.KillUse;
  begin
  if Prev <> nil then
    Prev.KillUse;
  end;

procedure TDrive.GetDown(var B: TScreenCell; C: Word; P: PFileRec; var LFN_inCurFileLine: Boolean);
  var
    S, S1, S2, SCreat, SLAcc: String;
    w, NameWidht: Word;
  begin
  if P = nil then
    Exit;
  w := TFilePanelRoot(Panel).PanSetup.Show.CurFileNameType;
  if w = cfnHide then
    S2 := ''
  else
    begin
    NameWidht := 13 + CountryInfo.TimeFmt; // fit 12-hour time
    
    uLfn := TFilePanelRoot(Panel).PanSetup.Show.
      ColumnsMask and psLFN_InColumns <> 0;
    if w = cfnTypeOther then
      S2 := P^.FlName[uLfn xor InvLFN]
    else
      
      S2 := P^.FlName[True];
    S2 := CutCols(S2, NameWidht, FMSetup.RestChar[1]);   { columns, not bytes: a name in UTF-8 }
    end;
  LFN_inCurFileLine := UpStrg(P^.FlName[True]) = UpStrg(fDelRight(S2));
  

  with TDate4(P^.FDate) do
    MakeDate(Day, Month, P^.Yr, Hour, Minute, S1);
  S2 := S2 + FormatSizeCol(P) + ' ' + S1;
  if P^.YrCreat <> 0 then
    with TDate4(P^.FDateCreat) do
      begin
      MakeDate(Day, Month, P^.YrCreat, Hour, Minute, SCreat);
      S2 := S2 + ' ' + GetString(dlCre)+SCreat;
      end;
  if P^.YrLAcc <> 0 then
    with TDate4(P^.FDateLAcc) do
      begin
      MakeDate(Day, Month, P^.YrLAcc, Hour, Minute, SLAcc);
      S2 := S2 + ' ' + GetString(dlLac)+SLAcc;
      end;
  MoveStr(PCellArray(@B)^[0], S2, C);
  end { TDrive.GetDown };

function TDrive.GetRealName: String;
  begin
  GetRealName := GetDir;
  end;

function TDrive.GetInternalName: String;
  begin
  GetInternalName := '';
  end;

{-DataCompBoy-}
function TDrive.GetRealDir: String;
  var
    S: String;
    C: Char;
    D: TDialog;
  var
    MM: record
      case Byte of
        1: (l: LongInt; S: String[1]);
        2: (C: Char);
      end;
  begin
  if DriveType = dtDisk then
    begin
    C := GetCurDrive;
    if C = CurDir[1] then
      begin
      ClrIO;
      NeedAbort := True;
      lGetDir(0, S);
      if Abort then
        S := CurrentDirectory;
      NeedAbort := True;
      LFN.lChDir(CurDir);
      repeat
        Abort := False;
        NeedAbort := True;
        lGetDir(0, CurDir);
        if Abort then
          begin
          repeat
            MM.l := 0;
            MM.C := GetCurDrive;
            MM.S := MM.C;
            D := TDialog(LoadResource(dlgDiskError));
            if D <> nil then
              begin
              D.SetData(MM);
              Application.ExecView(D);
              D.GetData(MM);
              D.Free;
              end;
            UpStr(MM.S);
            if ValidDrive(MM.S[1]) then
              Break;
          until False;
          Abort := True;
          end;
      until not Abort;
      NeedAbort := False;
      lGetDir(0, CurDir);
      LFN.lChDir(S);
      end
    else
      begin
      LFN.lChDir(CurDir);
      if not Abort then
        repeat
          Abort := False;
          NeedAbort := True;
          lGetDir(0, CurDir);
          if Abort then
            begin
            repeat
              MM.l := 0;
              MM.C := GetCurDrive;
              MM.S := MM.C;
              D := TDialog(LoadResource(dlgDiskError));
              if D <> nil then
                begin
                D.SetData(MM);
                Application.ExecView(D);
                D.GetData(MM);
                D.Free;
                end;
              UpStr(MM.S);
              if ValidDrive(MM.S[1]) then
                Break;
            until False;
            Abort := True;
            end;
        until not Abort;
      end;
    GetRealDir := CurDir;
    end
  else
    GetRealDir := GetDir;
  NeedAbort := False;
  end { TDrive.GetRealDir };
{-DataCompBoy-}

procedure TDrive.HandleCommand(Command: Word; InfoPtr: Pointer);
  begin
  end;

function TDrive.GetFullFlags: Word;
  begin
  GetFullFlags := psShowSize+psShowDate+psShowTime+
    psShowCrDate+psShowCrTime+psShowLADate+psShowLATime;
  end;

procedure TDrive.EditDescription(PF: PFileRec);
  begin
  if  (DriveType = dtDisk) and (PF^.TType <> ttUpDir)
  then
    SetDescription(PF, DizOwner);
  end;

{-DataCompBoy-}
procedure TDrive.GetDirLength(PF: PFileRec);
  var
    S: String;
    I: TSize;
    J: LongInt;
    NumDirs: Integer;
  begin
  if PF^.Size >= 0 then
    Exit;
  S := PF^.Owner^;
  if  (PF^.TType <> ttUpDir) then
    S := MakeNormName(S, PF^.FlName[True]);
  I := 1;
  PF^.Size := CountDirLen(S, True, I, Integer(J), NumDirs);
  if Abort then
    PF^.Size := -1;
  end;
{-DataCompBoy-}

function TDrive.OpenDirectory(const Dir: String;
                                    PutDirs: Boolean): TDrive;
  var
    I: LongInt;
    PI: TView;
    PDrv: TDrive;
    DirsToProcess: TCollection;
      { unsorted collection whose elements are created with
      NewStr and after use are moved into Dirs }
    Dirs: TStringCollection;
    Files: TFilesCollection;
    P: PString;
    tmr: TEventTimer;
    MemReq: LongInt;
    MAvail: LongInt;

  procedure AddDirectory(S: String);
    { add directory to the processing list }
    begin
    if MAvail <= MemReq then
      Exit;
    MakeSlash(S);
    DirsToProcess.Insert(NewStr(S));
    Inc(MemReq, SizeOf(ShortString)); //why 255, and not something+length(S)?
    end;

  procedure ReadDir(Dr: PString);
    var
      SR: lSearchRec;
      P: PFileRec;
      D: DateTime;
    begin
    ClrIO;
    lFindFirst(Dr^+x_x, AnyFileDir, SR); {JO}
    while not Abort and (DosError = 0) and (MAvail > MemReq) do
      begin
      if  (SR.SR.Attr and Hidden = 0) or (not Security) then
        if SR.SR.Attr and Directory = 0 then
          begin
          Files.AtInsert(Files.Count, NewFileRec(SR.FullName,
              
              SR.SR.Name,
              
              SR.FullSize,
              SR.SR.Time,
              SR.SR.CreationTime,
              SR.SR.LastAccessTime,
              SR.SR.Attr,
              Dr));
          Inc(MemReq, SizeOf(TFileRec));
          Inc(MemReq, Length(Dr^)+Length(SR.FullName)+2); {<drives.001>}
          end
        else if (SR.SR.Name[1] <> '.') and 
               (SR.FullName <> '.') and (SR.FullName <> '..') then
          begin
          AddDirectory(Dr^+SR.FullName);
          if PutDirs then
            begin
            Files.AtInsert(Files.Count, NewFileRec(SR.FullName,
                
                SR.SR.Name,
                
                SR.FullSize,
                SR.SR.Time,
                SR.SR.CreationTime,
                SR.SR.LastAccessTime,
                SR.SR.Attr,
                Dr));
            Inc(MemReq, SizeOf(TFileRec));
            Inc(MemReq, Length(Dr^)+Length(SR.FullName)+2); {<drives.001>}
            end;
          end;
      lFindNext(SR);
      end;
    lFindClose(SR);
    
    end { ReadDir };

  begin { TDrive.OpenDirectory }
  NewTimer(tmr, 0);
  Dirs := TStringCollection.Create($10, $10, False);
  DirsToProcess := TStringCollection.Create($10, $10, False);

  PI := WriteMsg(GetString(dlReadingList));
  Files := TFilesCollection.Create($10, $10);
  {JO: first determine available memory once, then along the way}
  {    keep track of how memory requirements grow and whether they exceeded  }
  {    the initially available amount                                              }
  MemReq := LowMemSize;
  MAvail := MaxAvail;
  AddDirectory(lFExpand(Dir));
  I := DirsToProcess.Count-1;
  Abort := False;
  while (I >= 0) and (not Abort) and (MAvail > MemReq) do
    begin
    P := DirsToProcess.At(I);
    DirsToProcess.AtDelete(I);
    Dirs.Insert(P);
    ReadDir(P);
    if TimerExpired(tmr) then
      begin
      NewTimer(tmr, 50);
      if ESC_Pressed then
        Abort := True;
      end;
    I := DirsToProcess.Count-1;
    end;
  PI.Free;
  // JO: sorting is not needed here, since it is done in TFindDrive.GetDirectory
  //     and as a result we would sort twice
  {Files.Sort;}
//use '><' as the branch flag
  PDrv := TFindDrive.Create('><'+Dir, Dirs, Files);
  PDrv.NoMemory := MAvail <= MemReq;
  OpenDirectory := PDrv;
  end { TDrive.OpenDirectory };

{-DataCompBoy-} {JO - 31-03-2006 - made it a virtual method of TDrive}
procedure TDrive.DrvFindFile(FC: TFilesCollection);
  var
    PInfo: TWhileView;
    Files: TFilesCollection;
    Directories: TCollection;
    BB: Byte; {-$VOL}
    R: TRect;
  begin
  FindRec.AddChar := '';

  if ExecResource(dlgFileFind, FindRec) = cmCancel then
    Exit;
  ConfigModified := True; {AK155 Don't get it. What does the config have to do with it?!!}
  DelLeft(FindRec.Mask);
  DelRight(FindRec.Mask);
  if FindRec.Mask = '' then
    FindRec.Mask := x_x;
  if  (Pos('*', FindRec.Mask) = 0) and
      (Pos('.', FindRec.Mask) = 0) and
      (Pos(';', FindRec.Mask) = 0) and
      (Pos('?', FindRec.Mask) = 0)
  then
    FindRec.AddChar := '*.*'
  else
    FindRec.AddChar := '';
  Files := TFilesCollection.Create($10, $10);
  Files.SortMode := psmLongName;
  Directories := TStringCollection.Create(30, 30, False);
  R.Assign(1, 1, 40, 10);
  Inc(SkyEnabled);
  PInfo := TWhileView.Create(R);
  PInfo.Options := PInfo.Options or ofSelectable or ofCentered;
  if FindRec.What = ''
  then
    PInfo.Top := GetString(dlDBViewSearch)+Cut(FindRec.Mask, 50)
  else
    PInfo.Top := GetString(dlDBViewSearch)+Cut(FindRec.Mask, 30)
      +' | '+Cut(FindRec.What, 17);
  PInfo.Bottom := GetString(dlNoFilesFound);
  PInfo.Write(1, GetString(dlDBViewSearchingIn));
  Desktop.Insert(PInfo);
  BB := FindFiles(Files, Directories, FindRec, PInfo, FC, False);
  Desktop.Delete(PInfo);
  Dec(SkyEnabled);
  PInfo.Free;
  if  (BB and ffSeD2Lng) <> 0 then
    MessageBox(GetString(dlSE_Dir2Long), nil, mfWarning+mfOKButton);
  if  (BB and ffSeNotFnd) = BB then
    MessageBox(^C+GetString(dlNoFilesFound), nil,
       mfInformation+mfOKButton);
  end; { TDrive.DrvFindFile }
{-DataCompBoy-}

procedure RereadDirectory(Dir: String);
  var
    Event: TEvent;

  procedure Action(View: TView);
    begin
    Event.What := evCommand;
    Event.Command := cmRereadDir;
    Event.InfoPtr := @Dir;
    View.HandleEvent(Event);
    end;

  begin
  
  Dir := lfGetLongFileName(Dir);
  
  Desktop.ForEach(Action);
  end;

end.

