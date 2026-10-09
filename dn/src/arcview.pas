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
{JO, AK155: 27.11.2002 - added expanding archives into a branch via Ctrl-H}
{JO:  1.12.2002 - added file search inside an archive}
{$I STDEFINE.INC}

unit ArcView;

interface

uses
  Collect, Defines, objutil, Streams, Views,
  FilesCol, DiskInfo,
  Drives, Commands, Archiver, FStorage
  ;

type
  TArcDrive = class;

  TArcDrive = class(TDrive)
    {Cat: this type is exposed via the plugin model; change with extreme care!}
    ArcName: String; {DataCompBoy}
    VArcName: String; {JO}
    AType: TARJArchive;
    Files: TDirStorage;
    KillAfterUse: Boolean;
    FakeKillAfterUse: Boolean; {temporary stub}
    ArcDate: LongInt;
    ArcSize: TFileSize; {saved together}
    ForceRescan: Boolean;
    Password: String;
    constructor Create(const AName, VAName: String); overload;
    constructor Create(PC: TDirStorage; const AName, VAName: String);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure RereadDirectory(S: String); override; {DataCompBoy}
    procedure KillUse; override;
    function ReadArchive: Boolean;
    procedure lChDir(ADir: String); override; {DataCompBoy}
    function GetDir: String; override;
    function GetDirectory(
         const FileMask: String;
        var TotalInfo: TSize): TFilesCollection; override;
    function Exec(Prg, Cmd: String; Lst: AnsiString; B: Boolean): Boolean;
    {JO:  extracted the command-line file list or the path to               }
    {     a list file into a separate Lst parameter;                        }
    {     parameter B must be False if we use                               }
    {     a list file, or extract a single file without using a list        }
    {     and True if we use a list on the command line                     }

    procedure UseFile(P: PFileRec; Command: Word); override;
    {DataCompBoy}
    function MakeListFile(PC: TCollection; UseUnp: Boolean;
         var B: Boolean): AnsiString;
    {JO:  UseUnp selects whether the resulting                          }
    {     file list is for the unpacker (True) or the packer (False);   }
    {     variable B returns whether the list was created on            }
    {     the command line (True) or in a list file (False)             }

    procedure CopyFiles(AFiles: TCollection; Own: TView;
         MoveMode: Boolean); override;
    procedure CopyFilesInto(AFiles: TCollection; Own: TView;
         MoveMode: Boolean); override;
    procedure EraseFiles(AFiles: TCollection); override;
    {procedure  GetDown(var B; C: Word; P: PFileRec); virtual;}
    {DataCompBoy}
    function GetRealName: String; override;
    function GetInternalName: String; override;
    procedure HandleCommand(Command: Word; InfoPtr: Pointer); override;
    procedure MakeDir; override;
    function isUp: Boolean; override;
    procedure ChangeUp(var S: String); override;
    procedure ChangeRoot; override;
    procedure ExtractFiles(AFiles: TCollection; ExtrDir: String;
         Own: TView; Options: Byte); {DataCompBoy}
    procedure GetFreeSpace(var S: String); override;
    procedure GetDirInfo(var B: TDiskInfoRec); override;
    function GetFullFlags: Word; override;
    procedure GetDirLength(PF: PFileRec); override; {DataCompBoy}
    destructor Destroy; override;
    procedure StdMsg4;
    function OpenDirectory(const Dir: String;
                                 PutDirs: Boolean): TDrive; override;
    procedure DrvFindFile(FC: TFilesCollection); override;
    procedure ReadDescrptions(FilesC: TFilesCollection); override;
    function GetDriveLetter: Char; override;
    end;

function ArcViewer(AName, VAName: String): Boolean;
{DataCompBoy}
procedure StdMsg(MsgNo: Byte);

const
  ArcPasw: String[32] = '';

type
  PFInfo = ^TFInfo;
  TFInfo = record
    FName: String;
    USize: LongInt;
    PSize: LongInt;
    Date: LongInt;
    Attr: Byte;
    Last: Byte;
    { 0 - not last    }
    { 1 - archive end }
    { 2 - broken arc  }
    end;

implementation

uses DnPath,
  osdep, Eraser, DNErrLog, TvGlyphs,
  Menus, mainapp, Messages, Dialogs, progress, FileCopy, Startup,
  Arvid, timeutil, VideoMan, DnExec, FileFind
  , UserMenu {JO: for hiding panels while extracting }
  , fmtzip {JO: for CentralDirRecPresent}

  , panelsetup, panelroot, dirwatch, Drivers
  , Lfn, uselfn, Tree, Dos, histories, HistList, filepanel
  , basics, strutil, fileutil, ArchDet
  , fmtrar, fmtace
  ;

const
  LowMemSize = $4000; {Local setting}

procedure CheckSlashDot(var S: String);{piwamoto}
begin
  if ((S[Length(S)] <> '.') and (S[Length(S)-1] <> ArcSep)) then
    {directory name '.' bugfix by piwamoto}
    While (PosChar(S[Length(S)], '.\') > 0) do SetLength(S, Length(S)-1);
end;

function MaxAvail: LongInt;
  begin
  MaxAvail := MemAdjust(Defines.MaxAvail);
  end;

procedure StdMsg(MsgNo: Byte);
  begin
  Application.Redraw;
  case MsgNo of
    1:
      ErrMsg(dlArcMsg1);
    4:
      MessageBox(GetString(dlArcMsg4)+''''+
         (Cut(ArcFileName,
           40))+'''', nil, mfOKButton or mfError);
    5:
      Msg(dlArcMsg5, nil, mfOKButton or mfInformation);
    6:
      if MsgHelpCtx <> 0 then
        MessageBox(GetString(dlArcMsg6)+GetString(dlPressF1),
          nil, mfOKButton or mfError)
      else
        MessageBox(GetString(dlArcMsg6), nil, mfOKButton or mfError);
    7:
      Msg(dlArcMsg7, nil, mfOKButton or mfInformation);
  end {case};
  end;

procedure TArcDrive.StdMsg4;
  begin
  if TempFile <> '' then
    TempFile := '';
  StdMsg(4);
  Abort := True;
  end;

{-DataCompBoy-}
constructor TArcDrive.Create(const AName, VAName: String);
  var
    SR: lSearchRec;
    I: Integer;
    xt, Q: String;
  begin
  inherited Create(0, nil);

  I := PosChar(':', Copy(VAName, 3, MaxStringLength))+2;
  if I > 2 then
    VArcName := lFExpand(Copy(VAName, 1, I-1))
  else
    VArcName := lFExpand(VAName);

  I := PosChar(':', Copy(AName, 3, MaxStringLength))+2;
  if I > 2 then
    begin
    Q := Copy(AName, I+1, MaxStringLength);
    if Q[Length(Q)] in [ArcSep, '/'] then
      SetLength(Q, Length(Q)-1);
    ArcName := lFExpand(Copy(AName, 1, I-1));
    end
  else
    begin
    ArcName := lFExpand(AName);
    Q := ArcSep;
    end;

  {lFSplit(ArcName, FreeStr, Nm, Xt);
 if Xt = '' then AddStr(ArcName, '.');}
  xt := GetExt(ArcName);
  if  ( (xt = '') or (xt = '.')) and (ArcName[Length(ArcName)] <> '.')
  then
    ArcName := ArcName+'.';
  lFindFirst(ArcName, AnyFileDir, SR); {JO}
  lFindClose(SR);
  if DosError <> 0 then
    begin
    ArcFileName := ArcName;
    VArcFileName := VArcName;
    StdMsg4;
    lFindClose(SR);
    Fail
    end;
  DriveType := dtArc;
  ColAllowed := PanelFileColAllowed[pcArc];
  if not ReadArchive or (Files = nil) then
    begin
    { Classes: Fail already runs Destroy; legacy Done+Fail would double-free here. }
    Fail;
    end;
  KillAfterUse := TempFile <> '';
  TempFile := '';
  Password := '';
  {lFindClose(SR);}
  lChDir(Q);
  AddToDirectoryHistory(ArcName+':'+CurDir, Integer(DriveType));
  end { TArcDrive.Init };
{-DataCompBoy-}

{-DataCompBoy-}
constructor TArcDrive.Create(PC: TDirStorage; const AName, VAName: String);
  var
    SR: lSearchRec;
  begin
  inherited Create(0, nil);
  ArcName := lFExpand(AName);
  {VArcName := lFExpand(VAName);}
  lFindFirst(ArcName, AnyFileDir, SR); {JO}
  ArcDate := SR.SR.Time;
  ArcSize := SR.SR.Size;
  lFindClose(SR);
  DriveType := dtArc;
  Files := PC;
  if  (Files = nil) then
    Fail;
  KillAfterUse := TempFile <> '';
  TempFile := '';
  Password := '';
  if ExistFile(ArcName) then
    ArcFile := TBufStream.Create(ArcName, stOpenRead, ArcBufSize)
  else
    ArcFile := nil;
  ArcFileName := ArcName;
  VArcFileName := VArcName;
  if  (ArcFile = nil) or (ArcFile.Status <> stOK) then
    begin
    StdMsg(4);
    ArcFile.Free;
    ArcFile := nil;
    if Files <> nil then
      begin
      Files.Free;
      Files := nil
      end;
    Fail;
    end;
  SkipSFX;
  AType := DetectArchive;
  ArcFile.Free;
  end { TArcDrive.InitCol };
{-DataCompBoy-}

{-DataCompBoy-}
constructor TArcDrive.Load(S: TStream);
  var
    SR: lSearchRec;
  label
    Failure;
  begin
  inherited Load(S);
  S.ReadStrV(ArcName);
  {S.Read(ArcName[0],1); S.Read(ArcName[1],Length(ArcName));}
  {Cat}
  S.ReadStrV(VArcName);
  {S.Read(VArcName[0],1); S.Read(VArcName[1],Length(VArcName));}
  {/Cat}
  S.Read(FakeKillAfterUse, 1);
  {temporary}
  KillAfterUse := False;
  S.ReadStrV(Password);
  {S.Read(Password[0],1); S.Read(Password[1],Length(Password));}
  S.Read(ArcDate, SizeOf(ArcDate)+SizeOf(ArcSize));
  ForceRescan := False;
  DriveType := dtArc;
  ArcFileName := ArcName;
  VArcFileName := VArcName;
  Files := TDirStorage(S.Get);
    { AK155 File data must be read from the stream regardless
    of whether the archive itself is found and whether it needs rereading,
    otherwise further stream reading will get out of sync }
  lFindFirst(ArcName, AnyFileDir, SR); {JO}
  lFindClose(SR);
  if DosError <> 0 then
    goto Failure;
  if  (ArcDate <> SR.SR.Time) or (ArcSize <> SR.SR.Size) then
    begin {archive changed, must reread it}
    CurDir := ArcSep;
    ReadArchive;
    end
  else
    begin
    ArcFile := TBufStream.Create(ArcName, stOpenRead, ArcBufSize);
    if  (ArcFile = nil) or (ArcFile.Status <> stOK) then
      begin
      ArcFile.Free;
      ArcFile := nil;
      goto Failure;
      end;
    SkipSFX;
    AType := DetectArchive;
    ArcFile.Free;
    if AType = nil then
      begin
Failure:
      StdMsg(4);
      if Files <> nil then
        Files.Free;
      Files := nil;
      S.Read(ForceRescan, 1);
      Fail;
      end;
    end;
  S.Read(ForceRescan, 1);
  end { TArcDrive.Load };
{-DataCompBoy-}

procedure TArcDrive.KillUse;
  begin
  if Prev <> nil then
    Prev.KillUse;
  if KillAfterUse then
    EraseTempFile(ArcName);
  end;

procedure TArcDrive.Store(S: TStream);
  begin
  inherited Store(S);
  S.WriteStr(@ArcName); {S.Write(ArcName[0],1 + Length(ArcName));}
  S.WriteStr(@VArcName); {S.Write(VArcName[0],1 + Length(VArcName));}
  {Cat}
  S.Write(KillAfterUse, 1);
  S.WriteStr(@Password); {S.Write(Password[0],1 + Length(Password));}
  S.Write(ArcDate, SizeOf(ArcDate)+SizeOf(ArcSize));
  S.Put(Files);
  S.Write(ForceRescan, 1);
  end;

destructor TArcDrive.Destroy;
  begin
  if Files <> nil then
    Files.Free;
  Files := nil;
  if AType <> nil then
    AType.Free;
  AType := nil;
  inherited Destroy;
  end;

{-DataCompBoy-}
function TArcDrive.ReadArchive: Boolean;
  var
    PF: PArcFile;
    P: TWhileView;
    R: TRect;
    Ln: TFileSize;
    Cancel: Boolean;
    T: TEventTimer;
    SR: lSearchRec;
  begin
  {AK155 26-11-2002 Reread the archive if and only if
 its date/time or length has changed }
  lFindFirst(ArcName, AnyFileDir, SR);
  lFindClose(SR);
  if  (ArcDate = SR.SR.Time) and (ArcSize = SR.SR.Size) then
    begin
    ReadArchive := True;
    Exit;
    end;
  ArcDate := SR.SR.Time;
  ArcSize := SR.SR.Size;
  {/AK155}
  CtrlBreakHit := False;
  ReadArchive := False;
  ArcFile := TBufStream.Create(ArcName, stOpenRead, ArcBufSize);
  ArcFileName := ArcName;
  VArcFileName := VArcName;
  if  (ArcFile = nil) or (ArcFile.Status <> stOK) then
    begin
    ArcFile.Free;
    ArcFile := nil;
    StdMsg4;
    Exit;
    end;
  if Files <> nil then
    Files.Free;
  Files := nil;
  Files := nil;
  SkipSFX;
  if AType <> nil then
    AType.Free;
  AType := nil; {DataCompBoy}
  AType := DetectArchive;
  if AType = nil then
    begin
    ArcFile.Free;
    ArcFile := nil;
    Exit;
    end;
  Files := TDirStorage.Create;
  if Files = nil then
    Exit;
  P := nil;
  R := TRect.Create(1, 1, 30, 10);
  {P := WriteMsg(GetString(dlArcReadArc));}
  Ln := ArcFile.GetSize+1;
  Cancel := False;
  PReader := nil;
  Inc(SkyEnabled);
  NewTimer(T, 300);
  repeat
    if (ArcFile <> nil{see TUC2Archive.GetFile}) and TimerExpired(T)
    then
      begin
      if P = nil then
        begin
        P := TWhileView.Create(R);
        PReader := P;
        P.Top := GetString(dlArcReadArc);
        P.Write(1, GetString(dlPercentComplete));
        Desktop.Insert(P);
        end;
      P.Write(2,
         Copy(Strg(GlyphChar(glBlockFull), 25 div Trunc(Ln / (ArcFile.GetPos+1))) +
           Strg(GlyphChar(glShadeMedium), 25),
         1, 25));
      P.Write(3, ItoS(Files.Files)+GetString(dlFilesFound));
      NewTimer(T, 300);
      end;
    AType.GetFile;
    if FileInfo.Last = 0 then
      begin
      Replace('/', ArcSep, FileInfo.FName);
      if FileInfo.FName[1] <> ArcSep then
        FileInfo.FName := ArcSep+FileInfo.FName;
      if FileInfo.Attr and Directory <> 0 then
        FileInfo.FName := FileInfo.FName+ArcSep;

      if FileInfo.FName[length(FileInfo.FName)] = ArcSep then
        FileInfo.Attr := FileInfo.Attr or Directory;

      {attribute "Hidden" means "with password"}
      Files.AddFile(FileInfo.FName, FileInfo.USize,
        FileInfo.PSize, FileInfo.Date, FileInfo.Attr);
      if FileInfo.Attr and Directory <> 0
      then
        Files.AddFile(ArcNormName(FileInfo.FName, '..'),
          FileInfo.USize, FileInfo.PSize, FileInfo.Date, 0);

      if  (P <> nil) and TimerExpired(T) then
        begin
        DispatchEvents(P, Cancel);
        if Cancel then
          begin
          StdMsg(5);
          FileInfo.Last := 1;
          end;
        end;
      end;
  until (FileInfo.Last > 0) or CtrlBreakHit;
  if CtrlBreakHit then
    StdMsg(5);
  CtrlBreakHit := False;
  Dec(SkyEnabled);
  if P <> nil then
    P.Free;
  ArcFile.Free;
  CDir := '';
  if  (FileInfo.Last = 2) or
      ( (AType.GetID = arcZIP) and not CentralDirRecPresent)
  then
    StdMsg(6);
  ReadArchive := True;
  if Files.Files = 0 then
    begin
    StdMsg(7);
    ReadArchive := False;
    end;
  end { TArcDrive.ReadArchive };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TArcDrive.lChDir(ADir: String);
  var
    Dr: String;
    Nm: String;
    Xt: String;
  begin
  if ADir = #0 then
    Exit;
  CheckSlashDot(CurDir);
{  if IsDummyDir(ADir) then}
{piwamoto: we check for '..' only}
{'.' is a valid directory name in archive}
{.tar.gz have a lots of './path/filename'}
  if ADir = '..' then
    begin
    if CurDir <> '' then
      while (CurDir <> '')
           and (not (CurDir[Length(CurDir)] in [ArcSep, '/']))
      do
        SetLength(CurDir, Length(CurDir)-1)
    else
      LFN.lChDir(GetPath(ArcName));
    Exit;
    end;
  Dr := ArcGetPath(ADir);
  if ArcGetName(ADir) = '..' then
    begin
    CurDir := Dr;
    while (CurDir <> '') and not (CurDir[Length(CurDir)] in [ArcSep, '/'])
    do
      SetLength(CurDir, Length(CurDir)-1);
    end
  else
    CurDir := ADir;
  ArcMakeNoSlash(CurDir);
  if CurDir[1]<>ArcSep then
    CurDir:=ArcSep+CurDir;
  CheckSlashDot(CurDir);
  AddToDirectoryHistory(ArcName+':'+CurDir, Integer(DriveType));
  end { TArcDrive.lChDir };
{-DataCompBoy-}

{-DataCompBoy-}
function TArcDrive.GetDir: String;
  var
    Dr: String;
    Nm: String;
    Xt: String;
  begin
  CheckSlashDot(CurDir);
  if  (Length(CurDir) > 0) and (not (CurDir[1] in [ArcSep, '/'])) then
    CurDir := ArcSep+CurDir;
  if  (Prev <> nil) and (Prev.DriveType = dtDisk) then
    lFSplit(VArcName, Dr, Nm, Xt) {JO}
  else
    lFSplit(ArcName, Dr, Nm, Xt);
  GetDir := AType.GetSign+Nm+Xt+CurDir;
  end;
{-DataCompBoy-}

{-DataCompBoy-}
function TArcDrive.GetDirectory( const FileMask: String; var TotalInfo: TSize): TFilesCollection;
  var
    F: PFileRec;
    I, si: LongInt;
    AllFiles: Boolean;
    AFiles, FD: TFilesCollection;
    TTL, TPL: TSize;
    _USize, _PSize: TSize;
    FR: TFileRec;
    OW: Pointer;
    Dr: String;
    MemReq: LongInt;
    MAvail: LongInt;
  begin
  ReadArchive; {AK155 26-11-2002}
  AFiles := TFilesCollection.Create($10, $10);
  {FD := PFilesCollection.Create($40, $10);}
  TFilesCollection(AFiles).Panel := Panel;
  GetDirectory := AFiles;
  CheckSlashDot(CurDir);
  FD := TFilesCollection.Create($40, $10);
  TTL := 0;
  TPL := 0;
  {GetDirectory := AFiles;}AllFiles := (FileMask = x_x)
       or (FileMask = '*');
  FD.SortMode := psmLongName; {<sort141.001>}
  Files.ResetPointer('');
  {JO: first determine available memory once, then as we go}
  {    track how much memory demand grows and whether it has exceeded         }
  {    the originally available amount                                         }
  MemReq := LowMemSize;
  MAvail := MaxAvail;
  while not Files.Last and Files.GetNextFile and (MAvail > MemReq) do
    begin
    _USize := Files.CurFile.Size;
    _PSize := Files.CurFile.CSize;
    if  (UpStrg(CurDir+ArcSep) = UpStrg(Files.LastDir)) and
        (AllFiles or InFilter(Files.CurFile.Name, FileMask))
    then
      begin
      if Files.CurFile.Name = '' then
        Continue;
      if Files.CurFile.Name = '..' then
        Continue;
      with Files.CurFile do
        begin
        F := NewFileRec(Name, GetURZ(Name), 
            _USize, Date, 0, 0, Attr, @CurDir);
        Inc(MemReq, SizeOf(TFileRec));
        Inc(MemReq, Length(CurDir+Name)+2);
        end;
      F^.PSize := _PSize;
      TTL := TTL+_USize;
      TPL := TPL+_PSize;
      end
    else if (UpStrg(CurDir+ArcSep) = UpStrg(Copy(Files.LastDir, 1,
               Length(CurDir)+1)))
    then
      begin
      Dr := Copy(Files.LastDir, Length(CurDir)+2, MaxStringLength);
      I := PosChar(ArcSep, Dr);
      if I = 0 then
        I := Length(Dr)+1;
      SetLength(Dr, I-1);
      if Dr = '' then
        Continue;
      FillChar(FR, SizeOf(FR), 0);
      CopyShortString(Dr, FR.FlName[True]);
      FR.Attr := Directory;
      I := FD.IndexOf(@FR);
      if I >= 0 then
        with PFileRec(FD.At(I))^ do
          begin
          Size := Size+_USize;
          PSize := PSize+_PSize;
          TTL := TTL+_USize;
          TPL := TPL+_PSize;
          Continue;
          end;
      F := NewFileRec(Dr, GetURZ(Dr), _USize,
           ArcDate, 0, 0, $80 or Directory, @CurDir);
      Inc(MemReq, SizeOf(TFileRec));
      Inc(MemReq, Length(CurDir+Dr)+2);
      F^.PSize := _PSize;
      TTL := TTL+_USize;
      TPL := TPL+_PSize;
      if FD.Search(F, si) then
        begin
        DelFileRec(F);
        Continue;
        end
        {else FD.Insert(F);}
      else
        FD.AtInsert(si, F);
      end
    else
      Continue;
    if AFiles.Search(F, si) then
      DelFileRec(F)
      {else AFiles.Insert(F);}
    else
      AFiles.AtInsert(si, F);
    end;

  NoMemory := MAvail <= MemReq;
  TotalInfo := TTL;

  if CurDir = '' then
    OW := @ArcName
  else
    OW := @CurDir;
  (* if TTL > MaxLongInt then F := NewFileRec('..', '..',0, ArcDate, Directory, OW) else
 begin
   F := NewFileRec('..', '..',Round(TTL), ArcDate, Directory, OW);
   F^.Attr := $8000 or F^.Attr;
 end;
 if TPL < MaxLongInt then F^.PSize := Round(TPL); *)

  F := NewFileRec('..', '..',  {Round}(TTL), ArcDate,
       0, 0, Directory, OW);
  F^.Attr := $8000 or F^.Attr;
  F^.PSize := {Round}(TPL);
  AFiles.AtInsert(0, F);
  FD.RemoveAll;
  FD.Free;
  end { TArcDrive.GetDirectory };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TArcDrive.UseFile(P: PFileRec; Command: Word);
  var
    SS, S, S2, Q: String;
    C: Char;
    Unp: String;
    ATime: LongInt;
    ASize: TSize;
    AAttr: Word;
    RunUnp: Boolean;
    
  label TryAgain;
  
  begin
  TempFile := ''; {-$VOL}
  if  (Command = cmEditFile) or (Command = cmFileEdit) or
      (Command = cmIntEditFile) or (Command = cmIntFileEdit)
  then
    Exit;
  case Command of
    cmDBFView:
      C := '=';
    cmWKZView:
      C := '>';
    cmTextView, cmViewText:
      C := '<';
    cmHexView:
      C := '|';
    cmIntFileView:
      C := '-';
    else {case}
      C := '+';
  end {case};
  {if not CheckPassword(AF) then Exit;}
  S := ' ';
  if P^.Attr and Hidden <> 0 then
    begin
    S := '';
    
TryAgain:
    
    if ExecResource(dlgSetPassword, S) <> cmOK then
      Exit;
    { Flash >>> }
    if CheckForSpaces(S) then
      S := ' '+CnvString(AType.Garble)+S+' '
    else
      
     if AType.UseLFN then
      
      S := ' '+CnvString(AType.Garble)+'"'+S+'"'+' '
        
    else
      begin
      MessageBox(GetString(dlSpacesInPassword), nil, mfWarning+mfOKButton);
      goto TryAgain;
      end
      
      ;
    { Flash <<< }
    end;
  SS := ArcNormName(P^.Owner^, P^.FlName[True]);
  if SS[1] = ArcSep then
    Delete(SS, 1, 1); {DelFC(SS);}
  
  if AType.UseLFN then
    S2 := ArcName
  else
    S2 := lfGetShortFileName(ArcName);
  if ArcName[Length(ArcName)] = '.' then
    S2 := S2+'.';
  S := CnvString(AType.Extract)+' '+S+
    CnvString(AType.ForceMode)+' '+
    SquashesName(S2)+' '+SquashesName(SS)+' ';
  
  {   DelDoubles('  ',S);} {piwamoto: files can have 2 spaces in names}
  TempFile := C+MakeNormName(TempDir, P^.FlName[True]);
  Q := '|'+GetRealName+':'+ArcNormName(CurDir, P^.FlName[True]);

  S2 := Copy(TempFile, 2, MaxStringLength);

  if C in ['<', '-', '|', '+'] then
    TempFile := TempFile+Q;

  GetFTimeSizeAttr(S2, ATime, ASize, AAttr);
  RunUnp := not ExistFile(S2) or (PackedDate(P) <> ATime)
                or (P^.Size <> ASize);
  if RunUnp then
    begin
    Unp := CnvString(AType.UnPacker);
    if  (AType.GetID = arcRAR) and (PosChar(';', Unp) > 0) then
      begin
      if PRARArchive(AType).VersionToExtr > 20 then
        Unp := Copy(Unp, PosChar(';', Unp)+1, 255)
      else
        Unp := Copy(Unp, 1, PosChar(';', Unp)-1);
      end;
    { Flash 21-01-2004
          The directory must be remembered on the drive that holds
          the temporary folder. On the drive that holds the archive
          with the viewed file, it will be remembered anyway. }
    if HasDrives then
      LFN.lChDir(Copy(TempDir, 1, 2));  { "C:" (the current directory of that drive); without drives the first two characters are no path }
    lGetDir(0, DirToChange);
    LFN.lChDir(TempDir);
    DNLog('UseFile: exec [' + Unp + '] [' + S + '] temp [' + TempFile + ']');
    Exec(Unp, (S), '', False);
    DNLog('UseFile: back from exec');
    LFN.lChDir(DirToChange);
    DirToChange := '';
    end;
  
  if not (AType.SwapWhenExec and RunUnp) then
    begin
  
    TempFileSWP := (TempFile);
    TempFile := ''; {-$VOL}
    Message(Application, evCommand, cmRetrieveSwp, nil); {JO}
  
    end
  else
    TempFile := ''; {-$VOL}
  
  end { TArcDrive.UseFile };
{-DataCompBoy-}

function TArcDrive.Exec(Prg, Cmd: String; Lst: AnsiString; B: Boolean): Boolean;
  var
    S: String;
    SS1: AnsiString;
    SM: Word;
    DE: Word;
    CmdLineLim, ListLineLim: AWord;
    CmdLineOK: Boolean;
    I, J: LongInt;
    
    T: lText;
    EX: String;
    I1: Integer;
    

  procedure StdMsg8;
    var
      L: array[0..1] of PtrInt;
      ST: String;
    begin
    Application.Redraw;
    ST := S;
    Pointer(L[0]) := @ST;
    L[1] := DE;
    Msg(dlArcMsg8, @L, mfOKButton or mfError);
    end;

  {AK155 20/12/2001 If under Win32 you try to step through
this function in the debugger, keyboard and mouse lock up completely
on entry (you cannot even leave begin).
The effect goes away if the AnsiString parameter is replaced with String.
Under OS/2 stepping works fine. Whose bug is this -
the Windows debugger or the Windows RTL? Hopefully the former. }
  begin { TArcDrive.Exec }
  Exec := True;
  S := Prg+' '+Cmd;
  DNLog('Exec: swap ' + ItoS(Ord(AType.SwapWhenExec)) + ' b ' + ItoS(Ord(B)) + ' [' + S + '] list [' + Lst + ']');
  
  if AType.SwapWhenExec then
    begin
    if B then
      begin
      CmdLineLim := 120;
      ListLineLim := CmdLineLim-Length(Prg+Cmd)-7;
      CmdLineOK := False;
      SS1 := Lst; {just in case}
      I1 := 1;
      repeat
        ClrIO;
        EX := SwpDir+'$DN'+ItoS(I1)+'$.BAT';
        lAssignText(T, EX);
        FileMode := $40;
        lResetText(T);
        if IOResult <> 0 then
          Break;
        Close(T.T);
        if InOutRes = 0 then
          Inc(I1);
      until IOResult <> 0;
      ClrIO;
      lAssignText(T, EX);
      lRewriteText(T);
      repeat
        if Length(Lst) >= ListLineLim then
          begin
          for I := ListLineLim downto 1 do
            if Lst[I] = #$14 then
              begin
              SS1 := Copy(Lst, 1, I-1);
              Delete(Lst, 1, I);
              Break;
              end;
          end
        else
          begin
          SS1 := Lst;
          CmdLineOK := True;
          end;
        for J := 1 to Length(SS1) do
          if SS1[J] = #$14 then
            SS1[J] := #$20; {JO: replace the temporary character with spaces}
        Writeln(T.T, '@'+S+' '+SS1);
      until CmdLineOK;
      Write(T.T, '@del '+EX);
      Close(T.T);
      S := EX;
      end {if B}
    else
      if Lst <> '' then
        begin
        TempFile := SwpDir+'$DN'+ItoS(DNNumber)+'$.LST';
        S := S + ' ' + Lst;
        end;
    Message(Application, evCommand, cmExecString, @S);
    end
  else {if AType.SwapWhenExec}
  begin
  
  DoneSysError;
  DoneEvents;
  DoneVideo;
  {AK155 Under OS/2, first, PATH usually does not fit
    in 255 characters; second, there is no memory shortage;
    third, the archiver may be a DOS one.
    So let cmd.exe walk PATH, and we will not
    reinvent that ourselves }
  {AK155, added later than the OS/2 comment.
    Under Win32 we also should not reinvent this ourselves.
    First, we leave the console in a bad state,
    so console rar cannot take keyboard input.
    Second, was it worth using ansistring only to then call
    Dos.Exec?}
  if B then
    begin
    {JO: split the part of the command line that holds the file list           }
    {    into chunks of a length the command processor can handle               }
    
    CmdLineLim := 95;
    
    ListLineLim := CmdLineLim-Length(Prg+Cmd)-7;
    CmdLineOK := False;
    SS1 := Lst; {just in case}
    repeat
      if Length(Lst) >= ListLineLim then
        begin
        for I := ListLineLim downto 1 do
          if Lst[I] = #$14 then
            begin
            SS1 := Copy(Lst, 1, I-1);
            Delete(Lst, 1, I);
            Break;
            end;
        end
      else
        begin
        SS1 := Lst;
        CmdLineOK := True;
        end;
      for J := 1 to Length(SS1) do
        if SS1[J] = #$14 then
          SS1[J] := #$20; {JO: replace the temporary character with spaces}
      // DelDoubles('  ', S);{files can have 2 spaces in names}
      // AnsiDelDoubles('  ', SS1);
      {JO: AnsiExec - a DNExec unit routine that }
      {    replaces DOS.Exec and uses an Ansistring        }
      {    as the command line                             }
      SwapVectors;
      AnsiExec(GetEnv('COMSPEC'), '/c '+S+' '+SS1+' ');
      DE := DosError;
      ClrIO;
      SwapVectors;
    until CmdLineOK;
    end
  else
    begin
    // DelDoubles('  ', S);{files can have 2 spaces in names}
    // AnsiDelDoubles('  ', Lst);
    SwapVectors;
    AnsiExec(GetEnv('COMSPEC'), '/c '+S+' '+Lst+' ');
    DE := DosError;
    ClrIO;
    SwapVectors;
    EraseFile(SwpDir+'$DN'+ItoS(DNNumber)+'$.LST'); {DataCompBoy}
    end;
  DNLog('Exec: the program ended, DOS error ' + ItoS(DE));
  InitVideo;
  InitEvents;
  InitSysError;
  case DE of
    0:
      Application.Redraw;
    8:
      StdMsg(1);
    else {case}
      StdMsg8;
  end {case};
  // JO: commented out, because after extraction we now copy
  //     via a temp directory and reread the panel after deleting it
  { GlobalMessage(evCommand, cmPanelReread, nil);
  GlobalMessage(evCommand, cmRereadInfo, nil);}
  
  end; {if AType.SwapWhenExec}
  
  end { TArcDrive.Exec };

function TArcDrive.isUp: Boolean;
  begin
  isUp := {CurDir = ''}True;
  end;

procedure TArcDrive.ChangeUp(var S: String);
  begin
  if CurDir <> '' then
    begin
    S := ArcGetName(CurDir);
    lChDir('..');
    Exit
    end;
  if Panel = nil then
    Exit;
  if Prev = nil then
    begin
    Prev := TDrive.Create(0, Panel);
    if Prev = nil then
      Exit;
    {Prev.Owner := Owner;}
    end;
  TFilePanel(Panel).Drive := Prev;
  if Prev is TDrive then
    Prev.lChDir(GetPath(VArcName));
  {piwamoto: VArcName is a feature, not a bug :-)}
  if  (Prev.DriveType = dtDisk) and
      (TView(Panel).GetState(sfSelected+sfActive))
  then
    ActivePanel := Panel;
  GlobalMessage(evCommand, cmRereadInfo, nil);
  if  (Prev.DriveType = dtDisk) then
    S := GetName(VArcName)
  else
    S := GetName(ArcName);
  Prev := nil;
  if KillAfterUse then
    EraseTempFile(ArcName);
  Free;
  end { TArcDrive.ChangeUp };

procedure TArcDrive.ChangeRoot;
  begin
  CurDir := '';
  end;

{-DataCompBoy-}
function TArcDrive.MakeListFile(PC: TCollection; UseUnp: Boolean; var B: Boolean): AnsiString;
  var
    F: lText;
    PF: PFileRec;
    PA: PArcFile;
    I: Integer;
    S: AnsiString;
    S1: String;

  function GetArcOwn(S: String): String;
    begin
    if Length(S) < 2 then
      begin
      Result := '';
      Exit;
      end;
    S[2] := ';'; {JO: what we replace with does not really matter, as long as it is not ':'}
    Result := Copy(S, PosChar(':', S)+1, MaxStringLength);
    end;

  procedure PutDir(SS: String);
    var
      I: Integer;
      S1: String;
    begin
    if not (SS[Length(SS)] in [ArcSep, '/']) then
      AddStr(SS, ArcSep);
    Files.ResetPointer('');
    while not Files.Last and Files.GetNextFile do
      if  (SS = Copy(Files.LastDir, 1, Length(SS)))
        and (Files.CurFile.Name <> '')
      then
        begin
        S1 := Files.LastDir+Files.CurFile.Name;
        if S1[1] in [ArcSep, '/'] then
          Delete(S1, 1, 1); {DelFC(S1);}
        if  (Copy(S1, Length(S1)-2, 3) = '\..')
               or (Copy(S1, Length(S1)-2, 3) = '/..')
        then
          SetLength(S1, Length(S1)- {2}3); {JO}
        {JO: whether directories need a trailing slash is debatable,     }
        {    but its absence seems harmless, while its presence         }
        {    confuses RAR unless a list file is used;                   }
        {    later some archivers may need                              }
        {    a corresponding option;                                    }
        {    zip works fine either way                                  }

        {JO:  use #$14 as a temporary separator between file names}
        if B then
          S := S+#$14+SquashesName(S1)
        else
          Writeln(F.T, S1);
        end;
    end { PutDir };

  begin { TArcDrive.MakeListFile }
  if UseUnp then
    B := (CnvString(AType.ExtrListChar) = ' ')
           or (CnvString(AType.ExtrListChar) = '')
  else
    B := (CnvString(AType.ComprListChar) = ' ')
           or (CnvString(AType.ComprListChar) = '');
  if B then
    S := ''
  else
    begin
    S := SwpDir+'$DN'+ItoS(DNNumber)+'$.LST';
    lAssignText(F, S);
    ClrIO;
    lRewriteText(F);
    B := IOResult <> 0;
    if B then
      S := ''
    else
      begin
      if UseUnp then
        S := CnvString(AType.ExtrListChar)+S
      else
        S := CnvString(AType.ComprListChar)+S;
      end;
    end;
  for I := 0 to PC.Count-1 do
    begin
    PF := PC.At(I);
    {JO: check for extracting from the archive search panel}
    if PathFoundInArc(PF^.Owner^) then
      S1 := ArcNormName(GetArcOwn(PF^.Owner^), PF^.FlName[True])
    else
      S1 := ArcNormName(PF^.Owner^, PF^.FlName[True]);
    if S1[1] in [ArcSep, '/'] then
      Delete(S1, 1, 1); {DelFC(S1);}

    {JO:  use #$14 as a temporary separator between file names}
    if PF^.Attr and Directory = 0
    then
      if B then
        S := S+#$14+SquashesName(S1)
      else
        Writeln(F.T, S1)
    else
      PutDir(ArcSep+S1+ArcSep);
    MakeListFile := S;
    end;
  MakeListFile := S;
  if not B then
    Close(F.T);
  end { TArcDrive.MakeListFile };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TArcDrive.ExtractFiles(AFiles: TCollection; ExtrDir: String;
    Own: TView; Options: Byte);
  var
    SS, ArchiveName: AnsiString;
    S, SCr: String;
    DT: record
      S: String;
      W: Word;
      Psw: String[30];
      end;
    ExtrChar: String;
    Nm: String;
    Xt: String;
    Pswd: Boolean;
    B: Boolean;
    SCurDir: String;
    Unp: String;
    DNN: Byte;
    TempExtrDir: String;
    TempDirUsed: Boolean;
    FCT: TFilesCollection;
    FRT: PFileRec;
    OldConfirms: Word;
    PV: TView;
    Inhr: Byte;
    SR: lSearchRec;

    
  label TryAgain;
  

  procedure UnSelect(P_: Pointer);
  var P: PFileRec absolute P_;
    begin
    Message(Panel, evCommand, cmCopyUnselect, P);
    Pswd := Pswd or (P^.Attr and Hidden <> 0);
    end;

  begin { TArcDrive.ExtractFiles }
  DNLog('ExtractFiles: to [' + ExtrDir + '] options ' + ItoS(Options) + ' files ' + ItoS(AFiles.Count));
  while ExtrDir[Length(ExtrDir)] = ' ' do
    SetLength(ExtrDir, Length(ExtrDir)-1);
  if  (ExtrDir = '') or (ExtrDir = '..') then
    
    if AType.UseLFN then
      
      lFSplit(VArcName, ExtrDir, Nm, Xt)
      {JO: for F4 unpack of archives viewed through a filter}
      
    else
      lFSplit(lfGetShortFileName(ArcName), ExtrDir, Nm, Xt)
      
      ;

  if not IsPathSep(ExtrDir[Length(ExtrDir)]) then
    ExtrDir := ExtrDir+DnSep;

  SCurDir := CurDir;
  SCr := '';
  if  (SCurDir <> '') then
    begin
    while (SCurDir[Length(SCurDir)] = '.') do
      SetLength(SCurDir, Length(SCurDir)-1);
    while (SCurDir <> '') and (SCurDir[1] = ArcSep) do
      Delete(SCurDir, 1, 1);
    ArcMakeSlash(SCurDir);
    if  (CnvString(AType.SetPathInside) <> '') then
      begin
      SCr := ' '+ CnvString(AType.SetPathInside)+
        SquashesName(Copy(SCurDir, 1, Length(SCurDir)-1))+' ';
      SCurDir := '';
      end;
    end;

//JO: if extracting without preserving paths, files inside the temporary
//    subdirectory end up without the directory structure that
//    existed inside the archive
  if (Options and 1) = 0 then
    SCurDir := '';

  {JO}
  DNLog('ExtractFiles: dir [' + ExtrDir + '] cur [' + SCurDir + ']');
  // check whether the destination directory contains files
  DosError := 0;
  lFindFirst(MakeNormName(ExtrDir, x_x), AnyFileDir, SR); {JO}
  if IsDummyDir(SR.FullName) then
    lFindNext(SR);
  if IsDummyDir(SR.FullName) then
    lFindNext(SR);
  lFindClose(SR);
  // for extracting to floppies and for testing we do not use
  // a temporary subdirectory
  if  ( (Options and 8) = 0) or ((Options and 2) <> 0) or
      ( (DosError <> 0) and (SCurDir = ''))
  then
    begin
    TempExtrDir := ExtrDir;
    TempDirUsed := False;
    end
  else
    begin
    { name the temporary subdirectory under the destination }
    DNN := DNNumber;
    while True do
      begin
      TempExtrDir := ExtrDir+'$DN'+ItoS(DNN)+'$.EDR';
      ClrIO;
      if DNN < 4 then
        DNLog('ExtractFiles: temp dir candidate [' + TempExtrDir + '] exists ' + ItoS(Ord(PathExist(TempExtrDir))));
      if PathExist(TempExtrDir) then
        Inc(DNN)
      else
        Break;
      end;
    ClrIO;
    TempDirUsed := True;
    end;
  {/JO}

  SS := MakeListFile(AFiles, True, B);
  S := ' ';
  Pswd := False;
  AFiles.ForEach(Unselect);
  DNLog('ExtractFiles: list [' + SS + '] password needed ' + ItoS(Ord(Pswd)));
  ExtrChar := CnvString(AType.ExtractWP);
  if Options and 1 = 0 then
    ExtrChar := CnvString(AType.Extract);
  if Options and 2 <> 0 then
    ExtrChar := CnvString(AType.Test);
  if Pswd then
    begin
    if Password = '' then
      
TryAgain:
      
      if ExecResource(dlgSetPassword, Password) <> cmOK then
        Exit;
    { Flash >>> } {JO: took Flash's code from Arcview.TArcDrive.UseFile }
    if CheckForSpaces(Password) then
      S := ' '+CnvString(AType.Garble)+Password+' '
    else
      
     if AType.UseLFN then
      
      S := ' '+CnvString(AType.Garble)+'"'+Password+'"'+' '
        
    else
      begin
      MessageBox(GetString(dlSpacesInPassword), nil, mfWarning+
        mfOKButton);
      goto TryAgain;
      end
      
      ;
    { Flash <<< }
    end;
  
  if AType.UseLFN then
    
    ArchiveName := SquashesName(ArcName)
      
  else
    ArchiveName := SquashesName(lfGetShortFileName(ArcName))
      
      ;
  if  ( (Options and 4 <> 0) or TempDirUsed) and
      (CnvString(AType.ForceMode) <> '')
  then
    S := S+CnvString(AType.ForceMode)+' ';
  S := S+SCr; {set the path inside the archive}
  S := ExtrChar+' '+S+ArchiveName;
  Unp := CnvString(AType.UnPacker);
  if  (AType.GetID = arcRAR) and (PosChar(';', Unp) > 0) then
    begin
    if PRARArchive(AType).VersionToExtr > 20 then
      Unp := Copy(Unp, PosChar(';', Unp)+1, 255)
    else
      Unp := Copy(Unp, 1, PosChar(';', Unp)-1);
    end;
  Inhr := CreateDirInheritance(ExtrDir, True);
  CreateDirInheritance(TempExtrDir, False);
  //JO: if the destination directory was not created (e.g. if the drive is
  //    read-only), there is no point calling the archiver
  if not PathExist(TempExtrDir) then
    begin
    DNLog('ExtractFiles: the directory [' + TempExtrDir + '] was not created');
    Exit;
    end;
  { Flash 21-01-2004
    The directory must be remembered on the drive that holds
    the temporary folder. On the drive that holds the archive
    with the viewed file, it will be remembered anyway. }
  if HasDrives then
    LFN.lChDir(Copy(TempExtrDir,1,2));  { "C:"; without drives the first two characters are no path }
  lGetDir(0, DirToChange);
  LFN.lChDir(TempExtrDir);
 
  if AType.SwapWhenExec and TempDirUsed then
    begin
    DirToMoveContent := TempExtrDir + '|' + SCurDir;
    if Options and 4 <> 0 then
      DirToMoveContent := '<'+ DirToMoveContent;
    end;
 
  DNLog('ExtractFiles: exec [' + Unp + '] [' + S + '] list [' + SS + '] cmdline ' + ItoS(Ord(B)));
  Exec(Unp, (S), SS, B);
  DNLog('ExtractFiles: back from exec');
  {JO}
  if not TempDirUsed then
    begin
    LFN.lChDir(DirToChange);
    DirToChange := '';
    ExtrDir := '>' + ExtrDir; // flag to reread subdirectories in the branch
    GlobalMessage(evCommand, cmPanelReread, @ExtrDir);
    GlobalMessage(evCommand, cmRereadInfo, nil);
    Exit;
    end
  else
    begin
    { move files from the temporary subdirectory to the destination }
    PV := TUserWindow.Create;
    Desktop.Insert(PV);
    CopyDirContent(TempExtrDir+SCurDir, ExtrDir, True,
       (Options and 4 <> 0));
    PV.Free;
    { delete the temporary directory with whatever remains in it }
    SetLength(TempExtrDir, Length(TempExtrDir)-1);
    S := GetPath(TempExtrDir);
    FRT := NewFileRec(GetName(TempExtrDir),
        
        GetName(TempExtrDir),
        
        0, 0, 0, 0, Directory,
        @S);
    FCT := TFilesCollection.Create(1, 1);
    FCT.AtInsert(0, FRT);
    OldConfirms := Confirms;
    Confirms := 0;
    LFN.lChDir(S);
    Eraser.EraseFiles(FCT);
    LFN.lChDir(DirToChange);
    DirToChange := '';
    Confirms := OldConfirms;
    FCT.RemoveAll;
    FCT.Free;
    if Inhr > 0 then
      begin
      ExtrDir := '>' + ExtrDir; // flag to reread subdirectories in the branch
      GlobalMessage(evCommand, cmPanelReread, @ExtrDir);
      GlobalMessage(evCommand, cmRereadInfo, nil);
      end;
    end;
  {/JO}
  end { TArcDrive.ExtractFiles };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TArcDrive.CopyFiles(AFiles: TCollection; Own: TView; MoveMode: Boolean);
  var
    DT: record
      S: String;
      W: Word;
      Psw: String[30];
      end;
    ExtrDir: String;
    DDr: Char;
  begin
  NotifySuspend; {<fnotify.001>}
  ExtrDir := '';
  DT.S := '';
  DT.Psw := Password;
  DT.W := UnarchiveOpt and not 2; {JO}
  Message(Application, evCommand, cmPushFirstName, @DT.S);
  if CopyDirName <> '' then
    DT.S := CopyDirName;
  {if DT.S = cTEMP_ then DT.S := '';}
  if DT.S = '' then
    GlobalMessageL(evCommand, cmPushName, hsExtract);
  if DT.S = '' then
    DT.S := HistoryStr(hsExtract, 0);
  {if DT.S = cTEMP_ then DT.S := '';}
  CopyDirName := '';
  if DT.S = cTEMP_ then
    begin
    CopyToTempDrive(AFiles, Own, ArcName);
    NotifyResume;
    Exit;
    end;
  {JO}
  // check whether the drive is in the list of drives that must be
  // extracted without a temporary subdirectory (default A: and B:)
  if  (DT.S <> '') and (Length(DT.S) >= 2) then
    begin
    if HasDriveLetter(DT.S) then
      DDr := UpCase(DT.S[1])
    else
      DDr := #1; {any character not in 'A'..'Z'}
    end
  else
    begin
    lGetDir(0, ExtrDir);
    DDr := DriveOf(ExtrDir);
    ExtrDir := '';
    end;
  if  (DDr in ['A'..'Z']) and
      (SystemData.Drives[DDr] and ossUnarcToDirectly <> 0)
  then
    DT.W := DT.W and not 8
  else
    DT.W := DT.W or 8;
  {/JO}
  DNLog('CopyFiles: the dialog for [' + DT.S + '] skip ' + ItoS(Ord(SkipCopyDialog)));
  if not SkipCopyDialog then
    if ExecResource(dlgExtract, DT) <> cmOK then
      begin
      DNLog('CopyFiles: the dialog was cancelled');
      NotifyResume;
      Exit;
      end;
  {JO}
  if  ( (DT.W and 1) <> (UnarchiveOpt and 1)) or
      ( (DT.W and 4) <> (UnarchiveOpt and 4))
  then
    ConfigModified := True;
  UnarchiveOpt := (DT.W and not 2) or 8;
  {/JO}
  SkipCopyDialog := False;
  ExtrDir := DT.S;
  Password := DT.Psw;
  ExtractFiles(AFiles, ExtrDir, Own, DT.W);
  NotifyResume;
  end { TArcDrive.CopyFiles };
{-DataCompBoy-}

procedure TArcDrive.MakeDir;
  begin
  end;

{-DataCompBoy-}
procedure TArcDrive.EraseFiles(AFiles: TCollection);
  var
    SS, S: AnsiString;
    PF: PFileRec;
    J, I: Word;
    O: TView;
    P: PString;
    B: Boolean;
  begin
  if AFiles.Count = 0 then
    Exit;
  if AFiles.Count = 1 then
    begin
    PF := AFiles.At(0);
    S := GetString(dlEraseConfirm1)+PF^.FlName[True]+' ?';
    end
  else
    S := GetString(dlEraseConfirms1);
  I := MessageBox(S, nil, mfConfirmation+mfYesButton+mfNoButton
      {+mfFastButton});
  if  (I <> cmYes) then
    Exit;
  if AFiles.Count > 1 then
    begin
    S := GetString(dlEraseConfirm2)+ItoS(AFiles.Count)
        +' '+GetString(dlDIFiles)+' ?';
    J := MessageBox(S, nil, mfConfirmation+mfYesButton+mfNoButton);
    if  (J <> cmYes) then
      Exit;
    end;
  SS := MakeListFile(AFiles, False, B);
  
  if AType.UseLFN then
    
    S := CnvString(AType.Delete)+' '+SquashesName(ArcName)
      
  else
    S := CnvString(AType.Delete)+' '+lfGetShortFileName(ArcName)
      
      ;

  ForceRescan := True;
  Exec(CnvString(AType.Packer), S, SS, B);
  ForceRescan := False;
  O := Panel;
  if not ReadArchive then
    begin
    CurDir := '';
    S := Cut(ArcName, 40);
    MessageBox(GetString(dlArcMsg4)+S, nil, mfError+mfOKButton);
    ChangeUp(CurDir);
    TFilePanel(O).ReadDirectory;
    end
  else
    TFilePanel(O).RereadDir;
  end { TArcDrive.EraseFiles };
{-DataCompBoy-}

function TArcDrive.GetRealName: String;
  var
    S: String;
  begin
  S := GetDir;
  GetRealName := Copy(S, 1, PosChar(':', S))+ArcName;
  end;

function TArcDrive.GetInternalName: String;
  var
    IntPath: String;
  begin
  IntPath := GetDir;
  if PosChar(ArcSep, IntPath) > 0 then
    GetInternalName := Copy(IntPath, PosChar(ArcSep, IntPath), 255)
  else
    GetInternalName := '';
  end;

procedure TArcDrive.CopyFilesInto(AFiles: TCollection; Own: TView; MoveMode: Boolean);
  begin
  ForceRescan := True;
  ArchiveFiles(GetRealName, AFiles, MoveMode, nil);
  ForceRescan := False;
  end;

procedure TArcDrive.HandleCommand(Command: Word; InfoPtr: Pointer);
  var
    C: TCollection absolute InfoPtr;

  procedure SetPassword;
    var
      S: String;
    begin
    S := Password;
    if ExecResource(dlgSetPassword, S) <> cmOK then
      Exit;
    Password := S;
    end;

  procedure TestFiles;
    begin
    ExtractFiles(C, '', Panel, 2);
    end;

  procedure Extract;
    var
      CDir: String;
      Opts: Byte;
    begin
    // JO: check whether the drive is in the list of drives that must be
    //     extracted without a temporary subdirectory (default A: and B:)
    lGetDir(0, CDir);
    if  (UpCase(CDir[1]) in ['A'..'Z']) and
        (SystemData.Drives[UpCase(CDir[1])] and ossUnarcToDirectly <> 0)
    then
      Opts := 1
    else
      Opts := 9;
    ExtractFiles(C, '', Panel, Opts);
    end;

  var
    PDr: TDrive;
    S: String;
    O: TView;

  begin { TArcDrive.HandleCommand }
  case Command of
    cmSetPassword:
      SetPassword;
    cmArcTest:
      TestFiles;
    cmExtractTo:
      Extract;
    cmMakeForced:
      ForceRescan := True;
    cmRereadForced:
      if ForceRescan then
        begin
        ForceRescan := False;
        
        if (AType.GetID = arcUC2) or
           (AType.GetID = arcAIN) or
           (AType.GetID = arc7Z) then
          begin
          TFilePanel(Panel).ForceReading := True;
          end;
        
        O := Panel;
        if not ReadArchive then
          begin
          CurDir := '';
          ChangeUp(CurDir);
          end;
        TFilePanel(O).RereadDir;
        end;
  end {case};
  end { TArcDrive.HandleCommand };

procedure TArcDrive.GetFreeSpace(var S: String);
  begin
  S := '';
  end;

function ArcViewer(AName, VAName: String): Boolean;
  var
    P: TDrive;
    E: TEvent;
    Xt: String;
    I: Byte;
    PathInside: String;
  begin
  {JO: so we can jump to the found file in the archive from the search panel}
  PathInside := AName;
  if HasDriveLetter(PathInside) then
    PathInside[2] := ';'; {JO: replace the colon with anything }
  I := PosChar(':', PathInside);
  if I > 0 then
    begin
    PathInside := Copy(AName, I+1, 255);
    AName := Copy(AName, 1, I-1);
    end
  else
    PathInside := '';
  {/JO}
  ArcViewer := False;
  P := TArcDrive.Create(AName, VAName);
  if Abort then
    begin
    ArcViewer := True;
    Exit;
    end;
  { AK155 21-06-2002
    If the file could not be read as an archive, no other method
    will read it either, so ArcViewer takes responsibility
    to stop pointless further attempts in the viewer. }
  if P = nil then
    begin
    
    Xt := UpStrg(GetExt(AName));
    if  (Xt = '.TDR') or (Xt = '.AVT')
    then
      P := TArvidDrive.Create(AName);
    if P = nil then
      
      Exit;
    end;
  E.What := evCommand;
  E.Message.Command := cmInsertDrive;
  E.Message.InfoPtr := P;
  Desktop.HandleEvent(E);
  if E.What <> evNothing then
    begin
    P.Free;
    Exit;
    end
  else
    ArcViewer := True;
  {JO: jump to the found file in the archive}
  if PathInside <> '' then
    begin
    if Copy(PathInside, Length(PathInside)-1, 2) = '\.' then
      SetLength(PathInside, Length(PathInside)-2);
    if  (ArcGetPath(PathInside) <> ArcSep) then
      begin
      P.lChDir(Copy(ArcGetPath(PathInside), 2, 255));
      Message(Application, evCommand, cmPanelReread, nil);
      end;
    end;
  {/JO}
  end { ArcViewer };

function TArcDrive.GetFullFlags: Word;
  begin
  GetFullFlags :=
     psShowSize+psShowDate+psShowTime+psShowPacked+psShowRatio;
  end;

procedure TArcDrive.RereadDirectory(S: String);
  begin
  if Prev <> nil then
    Prev.RereadDirectory(S);
  end;

procedure TArcDrive.GetDirInfo(var B: TDiskInfoRec);
  var
    Fl: Integer;
    PSz, USz: TSize;
{
  procedure DoCount(P_: Pointer);
  var P: PArcFile absolute P_;
    begin
    if  (P <> nil)
         and (not (P^.FName^[Length(P^.FName^)] in [ArcSep, '/']))
    then
      begin
      Inc(Fl);
      USz := USz+P^.USize;
      PSz := PSz+P^.PSize;
      end;
    end;
}
  begin
  B.Title := NewStr(GetString(dlDICurArchive));
  B.Dir := NewStr(ArcName);

  Fl := Files.Files;
  PSz := Files.TotalCLength;
  USz := Files.TotalLength;
  {
  if Files <> nil then Files.ForEach(DoCount);
  }
  B.Files := NewStr(GetString(dlDIArcTotalFiles)+ItoS(Fl)+'~');

  B.Total := NewStr(GetString(dlDIPackedSize)+FStr(PSz)+'~');
  B.Free := NewStr(GetString(dlDIUnpackedSize)+FStr(USz)+'~');

  if AType.GetID = arcRAR then
    B.VolumeID := NewStr
            (GetString(dlDIVersionToExtract)+RtoS(PRARArchive(AType).
          VersionToExtr/10, 4, 2)+'~');
  if AType.GetID = arcACE then
    B.VolumeID := NewStr
          (GetString(dlDIVersionToExtract)+RtoS(ACEVerToExtr/10, 4,
         2)+'~');

  end { TArcDrive.GetDirInfo };

procedure TArcDrive.GetDirLength(PF: PFileRec);
  begin
  end;

function ESC_Pressed: Boolean;
  var
    E: TEvent;
  begin
  Application.Idle;
  GetKeyEvent(E);
  ESC_Pressed := (E.What = evKeyDown) and (DNKeyCode(E) = kbESC)
  end;

function TArcDrive.OpenDirectory(const Dir: String;
                                       PutDirs: Boolean): TDrive;
  var
    PDrv: TDrive;
    Dirs: TStringCollection;
    Fils: TFilesCollection;
    FR: PFileRec;
    tmr: TEventTimer;
    _USize, _PSize: TSize;
    L: Integer;
    Root: String;
    PDir: PString;
    LDir, DrName: String;
    I: LongInt;
    PI: TView;
    MemReq: LongInt;
    MAvail: LongInt;
  begin
  NewTimer(tmr, 0);
  Dirs := TStringCollection.Create($10, $10, False);
  PI := WriteMsg(GetString(dlReadingList));
  Fils := TFilesCollection.Create($10, $10);
  Fils.SortMode := psmLongName;
  Files.ResetPointer('');
  Root := UpStrg(CurDir)+ArcSep;
  l := Length(Root);
  {JO: first determine available memory once, then as we go}
  {    track how much memory demand grows and whether it has exceeded         }
  {    the originally available amount                                         }
  MemReq := LowMemSize;
  MAvail := MaxAvail;
  while not Files.Last and Files.GetNextFile and (MAvail > MemReq)
  do
    begin
    if  (Root = Copy(UpStrg(Files.LastDir), 1, L)) then
      begin
      with Files.CurFile do
        begin
        if  (Name = '') or (Name = '..') then
          Continue;
        _USize := Size;
        _PSize := CSize;
        PDir := NewStr(Files.LastDir);
        Inc(MemReq, Length(PDir^)+1);
        FR := NewFileRec(Name, GetURZ(Name), 
            _USize, Date, 0, 0, Attr, PDir);
        Inc(MemReq, SizeOf(TFileRec));
        Inc(MemReq, Length(PDir^+Name)+2);
        end;
      if Dirs.IndexOf(PDir) = -1 then
        Dirs.Insert(PDir);
      Fils.AtInsert(Fils.Count, FR);
      {JO: add directories}
      if PutDirs and (Length(Files.LastDir) > L) then
        begin
        LDir := Files.LastDir;
        repeat
          SetLength(LDir, Length(LDir)-1);
          for I := Length(LDir) downto L do
            if LDir[I] = ArcSep then
              Break;
          DrName := Copy(LDir, I+1, MaxStringLength);
          SetLength(LDir, I);
          if  (DrName <> '') then
            begin
            PDir := NewStr(Copy(LDir, 1, I));
            Inc(MemReq, Length(PDir^)+1);
            FR := NewFileRec(DrName, GetURZ(DrName),
                
                0, ArcDate, 0, 0, $80 or Directory, PDir);
            Inc(MemReq, SizeOf(TFileRec));
            Inc(MemReq, Length(PDir^+DrName)+2);
            if Dirs.IndexOf(PDir) = -1 then
              Dirs.Insert(PDir);
            if Fils.Search(FR, I) then
              DelFileRec(FR)
            else
              Fils.AtInsert(I, FR);
            end;
        until Length(LDir) <= L;
        end; {end of directory addition}
      if TimerExpired(tmr) then
        begin
        NewTimer(tmr, 50);
        if ESC_Pressed then
          Break;
        end;
      end;
    end;
  PI.Free;
// use '><' as the branch marker
  PDrv := TFindDrive.Create('><'+Dir, Dirs, Fils);
  PDrv.NoMemory := MAvail <= MemReq;
  OpenDirectory := PDrv;
  end { TArcDrive.OpenDirectory };

procedure TArcDrive.DrvFindFile(FC: TFilesCollection);
  var
    I: LongInt;
    PDrv: TFindDrive;
    Dirs: TStringCollection;
    Fils: TFilesCollection;
    FR: PFileRec;
    tmr: TEventTimer;
    _USize, _PSize: TSize;
    L: Integer;
    Root: String;
    PDir: PString;
    LDir, DrName: String;
    DateAfter, DateBefore,
    SizeGreat, SizeLess: LongInt;
    Attr: Byte;
    PI: TView;
    MemReq: LongInt;
    MAvail: LongInt;

  begin
  NewTimer(tmr, 0);
  FindRec.AddChar := '';
//JO: since ArcFindRec shares storage with FindRec via absolute,
//    after the dialog we can just use FindRec
  if ExecResource(dlgArcFileFind, ArcFindRec) = cmCancel then
    Exit;
  ConfigModified := True;
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

  if FindRec.Options and ffoAdvanced <> 0 then
    begin
    DateAfter := ParseTime(AdvanceSearchData.After);
    DateBefore := ParseTime(AdvanceSearchData.Before);
    if DateBefore = 0 then
      DateBefore := $7FFFFFFF;
    SizeGreat := StoI(AdvanceSearchData.Greater);
    SizeLess := StoI(AdvanceSearchData.Less);
    if SizeLess = 0 then
      SizeLess := $7FFFFFFF;
    Attr := 0;
    if AdvanceSearchData.Attr and 1 <> 0 then
      Attr := Archive;
    if AdvanceSearchData.Attr and 2 <> 0 then
      Attr := Attr or SysFile;
    if AdvanceSearchData.Attr and 4 <> 0 then
      Attr := Attr or Hidden;
    if AdvanceSearchData.Attr and 8 <> 0 then
      Attr := Attr or ReadOnly;
    end;

  Dirs := TStringCollection.Create($10, $10, False);
  PI := WriteMsg(^M^M^C+GetString(dlSearching)+'...');
  Fils := TFilesCollection.Create($10, $10);
  Fils.SortMode := psmLongName;
  Files.ResetPointer('');
  Root := UpStrg(CurDir)+ArcSep;
  L := Length(Root);
  {JO: first determine available memory once, then as we go}
  {    track how much memory demand grows and whether it has exceeded         }
  {    the originally available amount                                         }
  MemReq := LowMemSize;
  MAvail := MaxAvail;
  while not Files.Last and Files.GetNextFile and (MAvail > MemReq)
  do
    begin
    if  (Root = Copy(UpStrg(Files.LastDir), 1, L)) then
      begin
      with Files.CurFile do
        begin
        if  ( (FindRec.Options and ffoAdvanced = 0) or
              (Date >= DateAfter) and (Date <= DateBefore)
            and (Size >= SizeGreat) and (Size <= SizeLess)
            and ((Attr = 0) or (FileInfo.Attr and Attr <> 0)))
          and ((FindRec.Options and ffoRecursive <> 0) or
              (Root = UpStrg(Files.LastDir)))
          and (Name <> '') and (Name <> '..')
          and InFilter(Name, FindRec.Mask+FindRec.AddChar)
        then
          begin
          _USize := Size;
          _PSize := CSize;
          PDir := NewStr(Files.LastDir);
          Inc(MemReq, Length(PDir^)+1);
          FR := NewFileRec(Name, GetURZ(Name), 
              _USize, Date, 0, 0, Attr, PDir);
          Inc(MemReq, SizeOf(TFileRec));
          Inc(MemReq, Length(PDir^+Name)+2);
          if Dirs.IndexOf(PDir) = -1 then
            Dirs.Insert(PDir);
          Fils.AtInsert(Fils.Count, FR);
          end;
        {JO: add directories}
        if Length(Files.LastDir) > L then
          begin
          LDir := Files.LastDir;
          repeat
            SetLength(LDir, Length(LDir)-1);
            for I := Length(LDir) downto L do
              if LDir[I] = ArcSep then
                Break;
            DrName := Copy(LDir, I+1, MaxStringLength);
            SetLength(LDir, I);
            if  (DrName <> '')
              //JO: for directories date and attributes are shown
              //    only approximately anyway, size is zero, so in advanced
              //    search directories only get in the way
              and (FindRec.Options and ffoAdvanced = 0)
              and ((FindRec.Options and ffoRecursive <> 0) or
                  (Root = UpStrg(LDir)))
              and InFilter(DrName, FindRec.Mask+FindRec.AddChar)
            then
              begin
              PDir := NewStr(Copy(LDir, 1, I));
              Inc(MemReq, Length(PDir^)+1);
              FR := NewFileRec(DrName, GetURZ(DrName),
                  
                  0, ArcDate, 0, 0, $80 or Directory, PDir);
              Inc(MemReq, SizeOf(TFileRec));
              Inc(MemReq, Length(PDir^+DrName)+2);
              if Dirs.IndexOf(PDir) = -1 then
                Dirs.Insert(PDir);
              if Fils.Search(FR, I) then
                DelFileRec(FR)
              else
                Fils.AtInsert(I, FR);
              end;
          until Length(LDir) <= L;
          end; {end of directory addition}
        if TimerExpired(tmr) then
          begin
          NewTimer(tmr, 50);
          if ESC_Pressed then
            Break;
          end;
        end;
      end;
    end;
  PI.Free;
  if Fils.Count > 0 then
    begin
// use '<>' as the search-panel marker
    PDrv := TFindDrive.Create('<>'+FindRec.Mask,
          Dirs, Fils);
    PDrv.AMask := NewStr(FindRec.Mask);
    PDrv.NoMemory := MAvail <= MemReq;
    if (FindRec.Options and ffoNoSort) <> 0 then
      RereadNoSort := True;
    Message(Panel, evCommand, cmInsertDrive, PDrv);
    RereadNoSort := False; //!!!
    end
  else
    MessageBox(^C+GetString(dlNoFilesFound), nil,
                 mfInformation+mfOKButton);
  end { TArcDrive.DrvFindFile };

procedure TArcDrive.ReadDescrptions(FilesC: TFilesCollection);
  begin
  end;

function TArcDrive.GetDriveLetter: Char;
  begin
  Result := ArcName[1];
  end;

end.

