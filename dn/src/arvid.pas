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

unit Arvid;

interface

uses DnPath,
  Defines, Collect, objutil, Streams, Dos, Drives, FilesCol, Views,
   DiskInfo, Tree, histories,
  Lfn, uselfn
  ;

type
  TTdrHeader = record
    FileTableOfs: LongInt;
    DirTableOfs: LongInt;
    PosTableOfs: LongInt;

    FileTableLen: LongInt;
    DirTableLen: LongInt;
    PosTableLen: LongInt;

    TapeFmt: AWord;
    TapeID: AWord;
    TapeLen: AWord;
    RecordLen: AWord;
    NewRecordSector: LongInt;

    DescTableOfs: LongInt;
    Res01: array[1..16] of Byte;
    DescTableLen: LongInt;
    Res02: array[1..16] of Byte;
    LastNewRecordSector: LongInt;
    Res03: array[1..36] of Byte;
    end;

  PTdrFileCell = ^TTdrFileCell;
  TTdrFileCell = record
    Name: array[1..11] of Char;
    Attr: Byte;
    StartSector: LongInt;
    Description: LongInt;
    Res: AWord;
    Time: LongInt;
    Cluster: AWord;
    Size: LongInt;
    end;

  TTdrDirCell = record
    Level: AWord;
    Name: array[1..11] of Char;
    Attr: Byte;
    StartSector: LongInt;
    Description: LongInt;
    Res: AWord;
    Time: LongInt;
    Cluster: AWord;
    Size: LongInt;

    Files: AWord;
    LastFile: AWord;
    NumFiles: AWord;

    end;

type
  TAvtHeader = record
    signature: LongInt; {'AVTP' = $50545641}
    AvtFmt: LongInt;
    CheckSum: LongInt;
    AfterLastCell: LongInt;
    FreeCell: LongInt;
    RootDirCell: LongInt;
    NewSector: LongInt;
    LastNewSector: LongInt;
    AvtMediaCell: LongInt;
    Undefined1: LongInt;
    end;

  TAvtMediaCell = record
    NextMediaCell: LongInt;
    TapeFmt: AWord; {16,32}
    TapeLen: AWord;
    TapeID: LongInt;
    Undefined1: LongInt;
    Undefined2: LongInt;
    Undefined3: LongInt;
    FirstSectorNum: LongInt;
    Sectors: LongInt;
    PositionTable: LongInt;
    PositionTableSize: LongInt;
    end;

  TAvtFileCell = record
    LeftFileCell: LongInt;
    RightFileCell: LongInt;
    ChildOrSize: LongInt;
    Time: LongInt;
    StartSector: LongInt;
    Flags: AWord;
    Attr: AWord;
    case Char of
      0: (Name0: array[1..16] of Char);
      1: (Name1: array[1..12] of Char; Next1: LongInt);
      2: (Name2: array[1..12] of Char; DescPtr2: LongInt);
      3: (NamePtr, NonUsed1, NonUsed2, DescPtr3: LongInt);
    end;

  TAvtTextCell = record
    NextTextCell: LongInt;
    Data: array[1..36] of Char;
    end;

const
  AvtLogSectors = $00FF; { Mask's for TAvtFileCell.Flags }
  avtBalance = $0300;
  AvtCellFormat = $0C00;
  AvtIsDir = $1000;

  avtCell0 = $0000;
  avtCell1 = $0400;
  avtCell2 = $0800;
  avtCell3 = $0C00;

type
  TAvdType = (avdTdr, avdAvt);

  TArvidDrive = class;

  TArvidDrive = class(TDrive)
    {Cat: this type is in the plugin model; change with extreme care!}
    Name: PString;
    Stream: TStream;
    CurFile: LongInt;
    CurDirPos: LongInt{!!s};
    PosTableOfs: LongInt;
    CurFileNum: AWord;
    CurLevel: AWord;
    CurDate: LongInt;
    KillAfterUse: Boolean;
    filetype: TAvdType;
    D: TTdrHeader;
    AVT: TAvtHeader;
    TapeFmt: AWord;
    TapeTotalTime: AWord;
    TapeRecordedTime: AWord;
    TotFiles: LongInt; {in directory}
    TotLen: LongInt;
    CurDirCellPos: LongInt;
    {this for AVT: location of directory cell.
                               CurDirPos for AVT is position of a root node}

    constructor Create(const AName: String); overload;
    procedure lChDir(ADir: String); override;
    function GetDir: String; override;
    function GetDirectory(
         const FileMask: String;
        var TotalInfo: TSize): TFilesCollection; override;
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    procedure Write(Os: opstream); override;
    procedure RereadDirectory(S: String); override;
    procedure KillUse; override;
    procedure UseFile(P: PFileRec; Command: Word); override;
    procedure CopyFiles(AFiles: TCollection; Own: TView;
         MoveMode: Boolean); override;
    procedure CopyFilesInto(AFiles: TCollection; Own: TView;
         MoveMode: Boolean); override;
    procedure EraseFiles(AFiles: TCollection); override;
    function GetRealName: String; override;
    function GetInternalName: String; override;
    procedure MakeDir; override;
    function isUp: Boolean; override;
    procedure ChangeUp(var S: String); override;
    procedure ChangeRoot; override;
    procedure GetFreeSpace(var S: String); override;
    procedure GetDirInfo(var B: TDiskInfoRec); override;
    procedure EditDescription(PF: PFileRec); override;
    procedure GetDirLength(PF: PFileRec); override;
    destructor Destroy; override;
    procedure SeekDirectory;
    function OpenDirectory(const Dir: String;
                                 PutDirs: Boolean): TDrive; override;
    procedure DrvFindFile(FC: TFilesCollection); override;
    procedure ReadDescrptions(FilesC: TFilesCollection); override;
  private
    procedure Kill;
    end;

const
  ArvidDrives: TNSCollection = nil;
  ArvidWithDN: Boolean = True;

var
  AllFiles: Boolean;

implementation
uses
  SysUtils,
  basics, fileutil, strutil, filepanel, Commands, Startup, mainapp,
  Drivers, Messages, Dialogs, FileFind, DNUtil, FileCopy, keymap,
  ArvidAvt, ArvidTdr
  , panelsetup, FindObj{ remove together with Arvid}, Math
  , osdep;

{$I manual/pstring_bind.inc}

constructor TArvidDrive.Create(const AName: String);
  var
    Attrb: Word;
    i: Integer;
    q: String;

  procedure GetAttr;
    var
      F: lFile;
    begin
    lAssignFile(F, AName);
    lGetFAttr(F, Attrb)
    end;

  procedure SetAttr(A: Word);
    var
      F: lFile;
    begin
    lAssignFile(F, AName);
    lSetFAttr(F, A)
    end;

  label 1;

  begin { TArvidDrive.Init }
  inherited Create(0, nil);
  i := PosChar(':', Copy(AName, 3, MaxStringLength))+2;
  if i > 2 then
    begin
    q := Copy(AName, i+1, MaxStringLength);
    if q[Length(q)] in [ArcSep, '/'] then
      SetLength(q, Length(q)-1);
    Stream := TBufStream.Create(Copy(AName, 1, i-1), stOpen, 2048);
    end
  else
    Stream := TBufStream.Create(AName, stOpen, 2048);

  if Stream.Status <> stOK then
    begin
    GetAttr;
    if Attrb and ReadOnly <> 0 then
      begin
      SetAttr(Archive);
      if  (IOResult <> 0) then
        begin
1:
        Stream.Free;
        Stream := nil;
        Fail;
        end;
      end;
    if i > 0
    then
      Stream := TBufStream.Create(Copy(AName, 1, i-1), stOpen, 2048)
    else
      Stream := TBufStream.Create(AName, stOpen, 2048);
    if Stream.Status <> stOK then
      goto 1;
    end;
  Stream.Read(AVT, SizeOf(AVT));
  if Stream.Status <> stOK then
    goto 1;
  if AVT.signature <> $50545641 {'AVTP'}
    then
    if not TdrInit(Self) then
      goto 1
    else
  else if not AvtInit(Self) then
    goto 1;
  Name := NewStr(lFExpand(AName));
  DriveType := dtArvid;
  ColAllowed := PanelFileColAllowed[pcArvid];

  KillAfterUse := TempFile <> '';
  TempFile := '';
  if i > 2 then
    CurDir := q
  else
    CurDir := ArcSep;
  SeekDirectory;
  if ArvidDrives = nil then
    ArvidDrives := TNSCollection.Create($100, $100);
  ArvidDrives.Insert(Self);
  AddToDirectoryHistory(Name^+':'+CurDir, Integer(DriveType));
  end { TArvidDrive.Init };

procedure TArvidDrive.SeekDirectory;
  begin
  if filetype = avdTdr then
    TdrSeekDirectory(Self)
  else
    AvtSeekDirectory(Self);
  end;

procedure TArvidDrive.Kill;
  begin
  if not KillAfterUse then
    Exit;
  if Stream <> nil then
    Stream.Free;
  Stream := nil;
  EraseTempFile(Name^);
  end;

function TArvidDrive.GetDirectory( const FileMask: String; var TotalInfo: TSize): TFilesCollection;
  var
    FC: TFilesCollection;
    P: PString;
    DT: DateTime;
    TAttr: Word;
  begin
  FC := TFilesCollection.Create($80, $40);
{  if ArvidWithDN then
    GetFreeSpace(FreeSpace);}
  TotFiles := 0;
  TotLen := 0;

  GetDirectory := FC;
  AllFiles := (FileMask = x_x) or (FileMask = '*');

  if filetype = avdTdr then
    TdrGetDirectory(Self, CurDirPos, FC, FileMask)
  else
    AvtGetDirectory(Self, CurDirPos, FC, FileMask);

  if CurDir = '' then
    P := Name
  else
    P := @CurDir;

  TotalInfo := TotLen;
  
  FC.AtInsert(0, NewFileRec('..', '..', 0, CurDate, 0, 0, Directory, P));
  
  end { TArvidDrive.GetDirectory };

destructor TArvidDrive.Destroy;
  begin
  if ArvidDrives <> nil then
    begin
    ArvidDrives.Remove(Self);
    if ArvidDrives.Count = 0 then
      ArvidDrives.Free;
    ArvidDrives := nil;
    end;
  if Stream <> nil then
    Stream.Free;
  Stream := nil;
  DisposeStr(Name);
  inherited Destroy;
  end;

procedure TArvidDrive.lChDir(ADir: String);
  var
    Dr: String;
    Nm: String;
    Xt: String;
  begin
  if ADir = #0 then
    Exit;
  Dr := ArcGetPath(ADir);
  if  ArcGetName(ADir) = '..' then
    begin
    if Dr <> '' then
      CurDir := Dr;
    if CurDir[1] <> ArcSep then
      Insert(ArcSep, CurDir, 1);
    repeat
      SetLength(CurDir, Length(CurDir)-1)
    until (CurDir = '') or (CurDir[Length(CurDir)] = ArcSep);
    if CurDir <> '' then
      SetLength(CurDir, Length(CurDir)-1);
    end
  else
    CurDir := ADir;
  SeekDirectory;
  while (PosChar(CurDir[Length(CurDir)], ' .\') > 0) do
    SetLength(CurDir, Length(CurDir)-1);
  AddToDirectoryHistory(Name^+':'+CurDir, Integer(DriveType));
  end { TArvidDrive.lChDir };

function TArvidDrive.GetDir: String;
  var
    Dr: String;
    Nm: String;
    Xt: String;
  begin
  lFSplit(Name^, Dr, Nm, Xt);
  if filetype = avdTdr
  then
    GetDir := 'TDR:'+Nm+ArcSep+CurDir
  else
    GetDir := 'AVT:'+Nm+ArcSep+CurDir;
  end;

function TArvidDrive.Read(Ip: ipstream): Pointer;
  label 1;
  begin
  Result := Self;
  inherited Create(0, nil);
  inherited Read(Ip);
  DriveType := dtArvid;
  Ip.ReadBytes(KillAfterUse, 1);
  Name := Ip.ReadString;
  Stream := TBufStream.Create(Name^, stOpen, 2048);
  if Stream.Status <> stOK then
    begin
1:
    { Classes: Fail already runs Destroy. }
    begin Free; Result := nil; Exit end;
    end;
  Stream.Read(AVT, SizeOf(AVT));
  if Stream.Status <> stOK then
    goto 1;
  if AVT.signature <> $50545641 {'AVTP'}
    then
    if not TdrInit(Self) then
      goto 1
    else
  else if not AvtInit(Self) then
    goto 1;
  SeekDirectory;
  if ArvidDrives = nil then
    ArvidDrives := TNSCollection.Create($100, $100);
  ArvidDrives.Insert(Self);
  end { TArvidDrive.Load };

procedure TArvidDrive.Write(Os: opstream);
  begin
  inherited Write(Os);
  Os.WriteBytes(KillAfterUse, 1);
  Os.WriteString(Name);
  end;

class function TArvidDrive.Build: TStreamable;
begin
  Result := TArvidDrive.Create(streamableInit);
end;

function TArvidDrive.StreamableName: ShortString;
begin
  Result := 'Arvid.TArvidDrive';
end;

procedure TArvidDrive.RereadDirectory(S: String);
  begin
  if Prev <> nil then
    Prev.RereadDirectory(S);
  if filetype = avdAvt then
    begin
    Stream.Free;
    Stream := TBufStream.Create(Name^, stOpen, 2048);
    Stream.Seek(0);
    Stream.Read(AVT, SizeOf(AVT));
    SeekDirectory;
    end;
  end;

procedure TArvidDrive.KillUse;
  begin
  if Prev <> nil then
    Prev.KillUse;
  Kill;
  end;

procedure TArvidDrive.UseFile(P: PFileRec; Command: Word);
  begin
  {  MessageBox('TArvidDrive.UseFile', nil, mfError + mfOKButton);}
  end;

{ CopyFiles(AFiles: TCollection; Own: TView; MoveMode: Boolean); virtual; }
procedure TArvidDrive.CopyFiles(AFiles: TCollection; Own: TView; MoveMode: Boolean);
  var
    I, J: Integer;
    CopyOpt: Word;
    CopyMode: Word;
    CopyPrn: Boolean;
    CmdFileCreated: Boolean;
    OwnerPtr: TView;
    P: TView;
    T: lText;
    PF: PFileRec;
    FC, FC2: TAvtFileCell;
    Nam, Desc: String;
    CopyDir: String;
    Mask: String;
    S1, S2, S3: String;
    CmdFileNam: String;
    Dr: String;
    Nm: String;
    Xt: String;

  procedure CopyTree(Pos: LongInt);
    begin
    if Pos = 0 then
      Exit;
    Stream.Seek(Pos);
    Stream.Read(FC, SizeOf(FC));
    if  (FC.Flags and AvtIsDir) <> 0 then
      begin
      FC2 := FC;
      FC.ChildOrSize := 0;
      end;
    Nam := AvtCellName(FC, Stream);
    Desc := AvtCellDesc(FC, Stream);
    if AvtNewFile(Self, S2+Nam, Desc, (FC.Flags and AvtIsDir) <> 0,
         FC.ChildOrSize,
        FC.Time, FC.StartSector, FC.Attr) = 0
    then
      begin
      MessageBox(GetString(dlFBBOver1)+S2+Nam, nil, mfError+mfOKButton);
      end
    else
      begin
      if  (FC.Flags and AvtIsDir) <> 0 then
        begin
        S1 := S1+Nam+ArcSep;
        S2 := S2+Nam+ArcSep;
        CopyTree(FC2.ChildOrSize);
        SetLength(S1, Length(S1)-1);
        SetLength(S2, Length(S2)-1);
        while (S1 <> '') and (S1[Length(S1)] <> ArcSep) do
          begin
          SetLength(S1, Length(S1)-1);
          SetLength(S2, Length(S2)-1);
          end;
        Stream.Seek(Pos);
        Stream.Read(FC, SizeOf(FC));
        end;
      Stream.Seek(Pos);
      Stream.Read(FC, SizeOf(FC));
      CopyTree(FC.LeftFileCell);
      Stream.Seek(Pos);
      Stream.Read(FC, SizeOf(FC));
      CopyTree(FC.RightFileCell);
      end;
    end { CopyTree };

  { CopyFiles(AFiles: TCollection; Own: TView; MoveMode: Boolean); virtual; }
  begin { TArvidDrive.CopyFiles }
  CtrlBreakHit := False;
  AFiles.Pack;
  if AFiles.Count <= 0 then
    Exit;
  lFSplit(Name^, Dr, Nm, Xt);
  if filetype = avdTdr then
    S1 := Dr+'TDR:'+Nm+ArcSep
  else
    S1 := Dr+'AVT:'+Nm+ArcSep;
  Message(Application, evCommand, cmPushFirstName, @CopyDirName);
  if not CopyDialog(CopyDir, Mask, CopyOpt, CopyMode, CopyPrn,
      MoveMode, AFiles, 0, Panel, True)
  then
    Exit;

  if Pos(S1, CopyDir) = 1 then
    begin
    if filetype = avdTdr then
      begin
      MessageBox(GetString(dlArvidCanChangeOnlyAVT), nil,
         mfInformation+mfOKButton);
      Exit;
      end;
    P := WriteMsg(GetString(dlPleaseStandBy));
    while Length(S1) <> 1 do
      begin
      Delete(S1, 1, 1); {DelFC(S1);}
      Delete(CopyDir, 1, 1); {DelFC(CopyDir);}
      end;
    S2 := CurDir;
    for I := 0 to AFiles.Count-1 do
      begin
      PF := AFiles.At(I);
      Stream.Seek( {Cat:warn}Round(PF^.PSize));
      Stream.Read(FC, SizeOf(FC));
      Desc := AvtCellDesc(FC, Stream);
      S1 := ArcNormName(ArcSep+CurDir, PF^.FlName[True]);
      S2 := MakeNormName(CopyDir, MkName(PF^.FlName[True], Mask));
      if Pos(S1, S2) = 1 then
        begin
        MessageBox(GetString(erIntoItself), nil, mfError+mfOKButton);
        end
      else
        begin
        if MoveMode then
          begin {move}
          FC2 := FC;
          FC2.ChildOrSize := 0;
          Stream.Seek( {Cat:warn}Round(PF^.PSize));
          Stream.Write(FC2, SizeOf(FC2));
          AvtDelFile(Self, S1);
          if AvtNewFile(Self, S2, Desc, (FC.Flags and AvtIsDir) <> 0,
              FC.ChildOrSize, FC.Time, FC.StartSector, FC.Attr) = 0
          then
            begin
            AvtNewFile(Self, S1, Desc, (FC.Flags and AvtIsDir) <> 0,
              FC.ChildOrSize, FC.Time, FC.StartSector, FC.Attr);
            MessageBox(GetString(dlFBBOver1)+S2, nil, mfError+mfOKButton);
            end;
          end
        else
          begin {copy}
          if  (PF^.Attr and Directory <> 0) then
            begin
            FC2 := FC;
            FC.ChildOrSize := 0;
            end;
          if AvtNewFile(Self, S2, Desc, (FC.Flags and AvtIsDir) <> 0,
              FC.ChildOrSize, FC.Time, FC.StartSector, FC.Attr) = 0
          then
            begin
            MessageBox(GetString(dlFBBOver1)+S2, nil, mfError+mfOKButton);
            end
          else if (PF^.Attr and Directory <> 0) then
            begin
            S1 := S1+ArcSep;
            S2 := S2+ArcSep;
            CopyTree(FC2.ChildOrSize);
            end;
          end;
        end;
      end;
    P.Free;
    Stream.Seek(0);
    Stream.Write(AVT, SizeOf(AVT));
    Stream.Free;
    Stream := TBufStream.Create(Name^, stOpen, 2048);
    GlobalMessage(evCommand, cmPanelReread, nil);
    Exit;
    end
  else
    begin
    S2 := CopyDir;
    J := 0;
    I := Pos(':', S2);
    while I > 0 do
      begin
      Inc(J);
      S2[I] := ' ';
      I := Pos(':', S2);
      end;
    if  (J > 1) or MoveMode then
      begin
      MessageBox(GetString(dlArvidNeedDisk), nil, mfError+mfOKButton);
      Exit;
      end;
    if TapeFmt = 0 then
      begin
      MessageBox(GetString(dlArvidVolumeIsNotTape), nil,
         mfError+mfOKButton);
      Exit;
      end;
    S2 := UpStrg(CopyDir);
    I := Pos(':', S2);
    if  (I <> 2) or (S2[1] < 'A') or (S2[1] > 'Z') then
      begin
      MessageBox(GetString(dlArvidNeedDisk), nil, mfError+mfOKButton);
      Exit;
      end;
    CmdFileNam := MakeNormName(Dr, Nm+'.RD');
    lAssignText(T, CmdFileNam);
    lAppendText(T);
    CmdFileCreated := False;
    if IOResult <> 0 then
      begin
      lRewriteText(T);
      Writeln(T.T, 'IDENT');
      CmdFileCreated := True;
      end;
    Writeln(T.T, '');
    P := WriteMsg(GetString(dlPleaseStandBy));
    for I := 0 to AFiles.Count-1 do
      begin
      PF := AFiles.At(I);
      S1 := ArcNormName(ArcSep+CurDir, PF^.FlName[True]);
      S2 := MakeNormName(CopyDir, MkName(Mask, PF^.FlName[True]));
      if  (PF^.Attr and Directory) = 0 then
        Writeln(T.T,
           'COPY TP:'+SquashesName(S1)+' '+SquashesName(S2)+' /O/R/C/H')
      else
        begin
        MkDir(SysOsPath(S2));
        Writeln(T.T,

           'COPYDIR TP:'+SquashesName(S1)+' '+SquashesName(S2)+' /I/O/R/C/H')
        end;
      end;
    P.Free;
    if CmdFileCreated then
      MessageBox(GetString(dlArvidCmdFileCreated)+CmdFileNam,
        nil, mfInformation+mfOKButton)
    else
      MessageBox(GetString(dlArvidCmdFileAppended)+CmdFileNam,
        nil, mfInformation+mfOKButton);
    Close(T.T);
    GlobalMessage(evCommand, cmPanelReread, nil);
    Exit;
    end;
  end { TArvidDrive.CopyFiles };

{ CopyFilesInto(AFiles: TCollection; Own: TView; MoveMode: Boolean); virtual;}
procedure TArvidDrive.CopyFilesInto(AFiles: TCollection; Own: TView; MoveMode: Boolean);
  begin
  AvtCopyFilesInto(Self, AFiles, Own, MoveMode);
  end;

procedure TArvidDrive.EraseFiles(AFiles: TCollection);
  begin
  AvtEraseFiles(Self, AFiles);
  end;

procedure TArvidDrive.MakeDir;
  begin
  AvtMakeDir(Self)
  end;

function TArvidDrive.isUp: Boolean;
  begin
  isUp := True;
  end;

procedure TArvidDrive.ChangeUp(var S: String);
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
    end;
  TFilePanel(Panel).Drive := Prev;
  Prev.lChDir(Prev.CurDir);
{AK155 If GetState(sfSelected+sfActive), then ActivePanel = Panel anyway
  if  (Prev.DriveType = dtDisk) and
      (TView(Panel).GetState(sfSelected+sfActive))
  then
    ActivePanel := Panel;
/AK155}
  GlobalMessage(evCommand, cmRereadInfo, nil);
  Prev := nil;
  S := GetName(Name^);
  Kill;
  Self.Free;
  end { TArvidDrive.ChangeUp };

procedure TArvidDrive.ChangeRoot;
  begin
  CurDir := '';
  SeekDirectory;
  end;

procedure TArvidDrive.GetFreeSpace(var S: String);
  var
    M, R: LongInt;
    L: array[1..2] of PtrInt;
    A: TAvtMediaCell;
  begin
  case TapeFmt of
    0:
      M := 0;
    2, 4:
      M := 100;
    8:
      M := 200;
    16:
      M := 200;
    32:
      M := 325;
    else {case}
      M := 325;
  end {case};

  if filetype = avdTdr
  then
    L[1] := Max(0, (LongInt(D.TapeLen)-D.RecordLen) div 60)
  else
    L[1] := Max(0, (LongInt(TapeTotalTime)-TapeRecordedTime) div 60);
  L[2] := (L[1]*60*M) div 1024;
  FormatStr(S, GetString(dlArvid_TimeLeft), L);
  end { TArvidDrive.GetFreeSpace };

function TArvidDrive.GetRealName: String;
  var
    Dr: String;
    Nm: String;
    Xt: String;
  begin
  lFSplit(Name^, Dr, Nm, Xt);
  GetRealName := Dr+GetDir;
  end;

function TArvidDrive.GetInternalName: String;
  begin
  GetInternalName := '';
  end;

procedure TArvidDrive.GetDirInfo(var B: TDiskInfoRec);
  var
    L: array[1..2] of PtrInt;
    S, NF, Sz: LongInt;
    S1, S2: String;
    A: TAvtMediaCell;
  begin
  B.Title := NewStr(GetString(dlArvid_Title));
  FreeStr := GetName(Name^);
  SetLength(FreeStr, PosChar('.', FreeStr)-1);
  B.Dir := NewStr(FreeStr);

  case TapeFmt of
    0:
      begin
      S := 000;
      B.VolumeID := NewStr
            (GetString(dlArvid_Type)+GetString(dlArvidNoReal))
      end;
    2:
      begin
      S := 100;
      B.VolumeID := NewStr(GetString(dlArvid_Type)+'~100~ Kb/s, CRC-16')
      end;
    4:
      begin
      S := 100;
      B.VolumeID := NewStr(GetString(dlArvid_Type)+'~100~ Kb/s, CRC-32')
      end;
    8:
      begin
      S := 200;
      B.VolumeID := NewStr(GetString(dlArvid_Type)+'~200~ Kb/s, CRC-32')
      end;
    16:
      begin
      S := 200;
      B.VolumeID := NewStr(GetString(dlArvid_Type)+'~200..300~ Kb/s')
      end;
    32:
      begin
      S := 325;
      B.VolumeID := NewStr(GetString(dlArvid_Type)+'~325..500~ Kb/s')
      end;
    else {case}
      begin
      S := 325;
      B.VolumeID := NewStr(GetString(dlArvid_Type)+'~325..500~ Kb/s')
      end;
  end {case};

  if filetype = avdTdr then
    begin
    Sz := D.RecordLen*S;
    NF := D.FileTableLen div SizeOf(TTdrFileCell);
    end
  else
    begin
    Sz := TotLen div 1024;
    NF := TotFiles;
    end;

  if NF = 0 then
    B.Files := NewStr(GetString(dlDINoFiles))
  else
    begin
    if NF = 1 then
      S1 := GetString(dlDIFile)
    else
      S1 := GetString(dlDIFiles);
    S2 := GetString(dlDIBytes);
    B.Files := NewStr
          ('~'+FStr(NF)+'~ '+S1+GetString(dlDIWith)+'~'+FStr(Sz)+'~K '+S2);
    end;

  if filetype = avdTdr then
    begin
    L[1] := LongInt(TapeTotalTime) div 60;
    L[2] := (TapeTotalTime*S) div 1024;
    FormatStr(FreeStr, GetString(dlArvid_TimeUsed), L);
    B.Total := NewStr(FreeStr);
    L[1] := Max(0, (LongInt(TapeTotalTime)-TapeRecordedTime) div 60);
    L[2] := (L[1]*60*S) div 1024;
    FormatStr(FreeStr, GetString(dlArvid_TimeLeft), L);
    B.Free := NewStr(FreeStr);
    end
  else
    begin
    L[1] := LongInt(D.TapeLen) div 60;
    L[2] := (D.TapeLen*S) div 1024;
    FormatStr(FreeStr, GetString(dlArvid_TimeUsed), L);
    B.Total := NewStr(FreeStr);
    L[1] := Max(0, (LongInt(D.TapeLen)-D.RecordLen) div 60);
    L[2] := (L[1]*60*S) div 1024;
    FormatStr(FreeStr, GetString(dlArvid_TimeLeft), L);
    B.Free := NewStr(FreeStr);
    end;
  end { TArvidDrive.GetDirInfo };

procedure TArvidDrive.EditDescription(PF: PFileRec);
  var
    S: String;
    Nam: String;

  label 1;

  var
    RealAttr, Attrb: Word;

  procedure GetAttr;
    var
      F: lFile;
    begin
    lAssignFile(F, Name^);
    lGetFAttr(F, Attrb)
    end;

  procedure SetAttr(A: Word);
    var
      F: lFile;
    begin
    lAssignFile(F, Name^);
    lSetFAttr(F, A)
    end;

  procedure Err;
    begin
    CantWrite(Name^)
    end;

  { procedure TArvidDrive.EditDescription; }
  begin { TArvidDrive.EditDescription }
  if  (PF^.DIZ = nil) then
    Exit;
  S := PF^.DIZ^.DIZText;
  if BigInputBox(GetString(dlEditDesc), GetString(dl_D_escription), S,
       255, hsEditDesc) <> cmOK
  then
    Exit;
  Stream.Free;
  Stream := nil;
  RealAttr := $FFFF;
  ClrIO;
  Abort := False;
  GetAttr;
  if Attrb and ReadOnly <> 0 then
    begin
    SetAttr(Archive);
    if Abort or (IOResult <> 0) then
      begin
      Err;
      goto 1
      end;
    RealAttr := Attrb or Archive;
    end;
  Stream := TBufStream.Create(Name^, stOpen, 2048);
  if Abort or (Stream.Status <> stOK) then
    begin
    Err;
    goto 1
    end;
  Stream.Seek(PF^.DIZ^.Line);
  if filetype = avdTdr then
    TdrEditDescription(Self, S, Nam, PF)
  else
    AvtEditDescription(Self, S, Nam);
1:
  ClrIO;
  Abort := False;
  Stream.Seek(0);
  if filetype = avdAvt then
    Stream.Write(AVT, SizeOf(AVT))
  else
    Stream.Write(D, SizeOf(D));
  Stream.Free;
  if RealAttr <> $FFFF then
    SetAttr(RealAttr);
  Stream := TBufStream.Create(Name^, stOpen, 2048);
  GlobalMessage(evCommand, cmPanelReread, nil);
  end { TArvidDrive.EditDescription };

procedure TArvidDrive.DrvFindFile(FC: TFilesCollection);
  var
    DT: record
      Mask: String;
      Text: String;
      o: Word;
      end;
    SDesc: Boolean;
    P: TView;
    DateAfter,
    DateBefore,
    SizeGreat,
    SizeLess: LongInt;
    Attr: Byte;
    OOM: Boolean;
    WasTape: Boolean;
    WasDir: Boolean;
    Dr: String;
    LP: LongInt;
    St0: TStream;
    NName: String;
    AA0: TAvtFileCell;
    S0: String;

  label 1;

  procedure Add(P: Pointer; const Name: String);
    begin
    if FindList = nil then
      FindList := TNoStreamCollection.Create($100, $100);
    if OOM or (not MemOK) or (MaxAvail < (FindList.Count+$200)*4) then
      begin
      TStreamable(P).Free;
      OOM := True;
      Exit;
      end;
    if not WasTape then
      FindList.Insert(TFindEntry.Create(Name));
    if not WasDir then
      FindList.Insert(TFindDir.Create(dr, LP));
    WasTape := True;
    WasDir := True;
    FindList.Insert(P);
    end;

  procedure TdrSearchInStream(St: TStream; var D: TTdrHeader;
       const Name: String);
    var
      DD: TTdrDirCell;
      FF: TTdrFileCell;
      I: LongInt;
      J: LongInt; {!!s}
      Lv0: Boolean;
      LastLv: Integer;
      SS: String[12];
    begin
    Lv0 := False;
    LastLv := 0;
    LP := D.DirTableOfs;
    repeat
      St.Seek(LP);
      St.Read(DD, SizeOf(DD));
      if DD.Level = 0 then
        if Lv0 then
          Break
        else
          Lv0 := True;
      SS := DD.Name;
      Insert('.', SS, 9);
      if DD.Level > LastLv then
        dr := MakeNormName(dr, TdrMakeFileName(SS))
      else if DD.Level <= LastLv then
        begin
        repeat
          while (dr[Length(dr)] <> ArcSep) and (dr <> '') do
            SetLength(dr, Length(dr)-1);
          if dr <> '' then
            SetLength(dr, Length(dr)-1);
          Dec(LastLv);
        until DD.Level > LastLv;
        if dr = '' then
          dr := ArcSep;
        dr := MakeNormName(dr, TdrMakeFileName(SS))
        end;
      LastLv := DD.Level;
      WasDir := False;
      if InSpaceFilter(SS, DT.Mask) then
        begin
        if SDesc and (DD.Description <> 0) then
          begin
          St.Seek(D.DescTableOfs+DD.Description-1);
          {Cat:warn AnsiString}
          St.Read(FreeStr, 2);
          St.Read(FreeStr[1], Length(FreeStr));
          UpStr(FreeStr);
          end
        else
          FreeStr := '';
        if  (not SDesc or (Pos(DT.Text, FreeStr) > 0)) and
            ( (DT.o and 1 = 0) or
              (DD.Time <= DateBefore) and (DD.Time >= DateAfter) and
              (DD.Size >= SizeGreat) and (DD.Size <= SizeLess) and
              ( (Attr = 0) or (DD.Attr and Attr <> 0)))
        then
          begin
          WasDir := True;
          Add(TFindDir.Create(dr, LP), Name);
          end;
        end;
      if not OOM then
        begin
        St.Seek(D.FileTableOfs+LongInt(DD.Files)*SizeOf(TTdrFileCell));
        for I := 1 to DD.NumFiles do
          begin
          St.Read(FF, SizeOf(FF));
          SS := FF.Name;
          Insert('.', SS, 9);
          if InSpaceFilter(SS, DT.Mask) then
            begin
            if SDesc and (FF.Description <> 0) then
              begin
              J := i32(St.GetPos);
              St.Seek(D.DescTableOfs+FF.Description-1);
              {Cat:warn AnsiString}
              St.Read(FreeStr, 2);
              St.Read(FreeStr[1], Length(FreeStr));
              St.Seek(J);
              UpStr(FreeStr);
              end
            else
              FreeStr := '';
            if  (not SDesc or (Pos(DT.Text, FreeStr) > 0)) and
                ( (DT.o and 1 = 0) or
                  (FF.Time <= DateBefore) and (FF.Time >= DateAfter) and
                  (FF.Size >= SizeGreat) and (FF.Size <= SizeLess) and
                  ( (Attr = 0) or (FF.Attr and Attr <> 0)))
            then
              begin
              Add(TFindFile.Create(TdrMakeFileName(SS), FF.Size,
                     FF.Time), Name);
              end;
            end;
          end;
        end;
      Inc(LP, SizeOf(DD));
    until (LP > D.DirTableOfs+D.DirTableLen) or OOM;
    if OOM then
      Application.OutOfMemory;
    end { TdrSearchInStream };

  procedure AvtSearchInStream(L: LongInt);
    var
      SaveWasDir: Boolean;
      SaveLP: LongInt;
    begin
    if L = 0 then
      Exit;
    St0.Seek(L);
    St0.Read(AA0, SizeOf(AA0));
    if St0.Status <> stOK then
      Exit;
    AvtSearchInStream(AA0.LeftFileCell);
    St0.Seek(L);
    St0.Read(AA0, SizeOf(AA0));
    if St0.Status <> stOK then
      Exit;
    if AA0.Flags and AvtIsDir <> 0 then
      begin
      SaveWasDir := WasDir;
      WasDir := False;
      SaveLP := LP;
      LP := L;
      dr := dr+AvtCellName(AA0, St0)+ArcSep;
      AvtSearchInStream(AA0.ChildOrSize);
      WasDir := SaveWasDir;
      LP := SaveLP;
      SetLength(dr, Length(dr)-1);
      while (dr[Length(dr)] <> ArcSep) and (dr <> '') do
        SetLength(dr, Length(dr)-1);
      end
    else
      begin
      S0 := AvtCellName(AA0, St0);
      if InSpaceFilter(S0, DT.Mask) then
        begin
        if SDesc then
          FreeStr := UpStrg(AvtCellDesc(AA0, St0));
        if  (not SDesc or (Pos(DT.Text, FreeStr) > 0)) and
            ( (DT.o and 1 = 0) or
              (AA0.Time <= DateBefore) and (AA0.Time >= DateAfter) and
              (AA0.ChildOrSize >= SizeGreat) and (AA0.ChildOrSize <=
               SizeLess))
        then
          begin
          if WasDir = False then
            begin
            WasDir := True;
            Add(TFindDir.Create(dr, LP), NName);
            end;
          Add(TFindFile.Create(S0, AA0.ChildOrSize, AA0.Time), NName);
          end;
        end;
      end;
    St0.Seek(L);
    St0.Read(AA0, SizeOf(AA0));
    if St0.Status <> stOK then
      Exit;
    AvtSearchInStream(AA0.RightFileCell);
    end { AvtSearchInStream };

  procedure SearchInStream(St: TStream; const Name: String);
    var
      DD: TTdrHeader;
      AA: TAvtHeader;
    begin
    WasTape := False;
    dr := ArcSep;
    St.Seek(0);
    St.Read(AA, SizeOf(AA));
    if AA.signature = $50545641 {'AVTP'} then
      begin
      St0 := St;
      NName := Name;
      AvtSearchInStream(AA.RootDirCell);
      end
    else
      begin
      St.Seek(0);
      St.Read(DD, SizeOf(DD));
      if DD.PosTableLen <> 4656 then
        Exit;
      if DD.FileTableOfs <> SizeOf(TTdrHeader) then
        Exit;
      if DD.DirTableOfs <> (DD.FileTableOfs+DD.FileTableLen) then
        Exit;
      if DD.DescTableOfs < (DD.DirTableOfs+DD.DirTableLen) then
        Exit;
      if DD.PosTableOfs <>
          ( (DD.DescTableOfs+DD.DescTableLen+511) div 512*512)
      then
        Exit;
      if DD.TapeLen < DD.RecordLen then
        Exit;
      if DD.FileTableLen <> (DD.FileTableLen div SizeOf(TTdrFileCell)
          *SizeOf(TTdrFileCell))
      then
        Exit;
      TdrSearchInStream(St, DD, Name);
      end;
    end { SearchInStream };

  procedure SearchInAllFiles;
    var
      SR: Dos.SearchRec;
      St: TBufStream;
      D: TTdrHeader;
    begin
    ClrIO;
    Dos.FindFirst(MakeNormName(GetPath(Name^), '*.TDR'),
         Archive+Byte(Security)*Hidden+ReadOnly+SysFile, SR);
    while (DosError = 0) and not Abort do
      begin
      St := TBufStream.Create(MakeNormName(GetPath(Name^), SR.Name), stOpenRead, 2048);
      if St.Status = stOK then
        begin
        SearchInStream(St, SR.Name);
        end;
      St.Free;
      ClrIO;
      Dos.FindNext(SR);
      end;
    Dos.FindFirst(MakeNormName(GetPath(Name^), '*.AVT'),
         Archive+Byte(Security)*Hidden+ReadOnly+SysFile, SR);
    while (DosError = 0) and not Abort do
      begin
      St := TBufStream.Create(MakeNormName(GetPath(Name^), SR.Name), stOpenRead, 2048);
        begin
        SearchInStream(St, SR.Name);
        end;
      St.Free;
      ClrIO;
      Dos.FindNext(SR);
      end;
    end { SearchInAllFiles };

  procedure ExecuteFindDialog;
    label 1;
    var
      D: TDialog;
      R: TRect;
      PL: TFindBox;
      P: TView;
      F: TFindEntry;

    procedure DoCount(P_: Pointer);
    var P: TFindEntry absolute P_;
      begin
      Inc(R.A.X, Byte(P.TT = ttFile));
      end;

    begin

    D := TDialog(LoadResource(dlgArvidFindResults));
    if D = nil then
      Exit;

    R := TRect.Create(58, 1, 59, 13);
    P := TScrollBar.Create(R);
    D.Insert(P);

    R := TRect.Create(2, 1, 58, 13);
    PL := TFindBox.Create(R, 1, TScrollBar(P));
    PL.NewLisT(FindList);
    D.Insert(PL);

    R.A.X := 0;
    if  (FindList <> nil) then
      FindList.ForEach(DoCount);

    FreeStr := FStr(R.A.X)+GetString(dlFilesFound);
    R := TRect.Create(1, 13, 1+Length(FreeStr), 14);
    P := TStaticText.Create(R, FreeStr);
    P.Options := P.Options or ofCenterX;
    D.Insert(P);

    PL.Select;
    R.A.X := Desktop.ExecView(D);
    R.A.Y := PL.Focused;

    PL.Items := nil;

    D.Free;

    if R.A.X = cmNo then
      FreeAndNil(FindList);

    if  (R.A.X = cmOK) and (FindList <> nil) and (FindList.Count > 0)
    then
      begin
      F := FindList.At(R.A.Y);
      if F = nil then
        Exit;
      FreeStr := '';
      R.B.X := R.A.Y;
      while R.B.X >= 0 do
        begin
        F := FindList.At(R.B.X);
        if  (F.TT = ttDir) and (FreeStr = '') then
          FreeStr := CnvString(F.Text);
        if  (F.TT = ttTape) then
          Break;
          Dec(R.B.X);
        end;
      if UpStrg(F.Text^) <> UpStrg(GetName(Name^)) then
        begin
        FreeAndNil(Stream);
        CurDir := FreeStr;
        FreeStr := MakeNormName(GetPath(Name^), F.Text^);
        DisposeStr(Name);
        Name := NewStr(FreeStr);
        Stream := TBufStream.Create(FreeStr, stOpenRead, 2048);
        FreeStr := CurDir;
        CurDir := '';
        if Stream.Status <> stOK then
          begin
1:
          ChangeUp(FreeStr);
          Exit;
          end;
        Stream.Read(Self.D, SizeOf(Self.D));
        if Stream.Status <> stOK then
          goto 1;
        end;
      CurDir := FreeStr;
      if CurDir[1] = ArcSep then
        Delete(CurDir, 1, 1); {DelFC(CurDir);}
      SeekDirectory;
      F := FindList.At(R.A.Y);
      if F.TT = ttFile then
        FreeStr := MakeNormName(FreeStr, CnvString(TFindFile(F).Name));
      Message(Panel, evCommand, cmFindGotoFile, @FreeStr);
      end;

    end { ExecuteFindDialog };

  begin { TArvidDrive.DrvFindFile }
  OOM := False;
  DT.Mask := '';
  DT.Text := '';
  DT.o := 0;
  if ExecResource(dlgArvidFileFind, DT) <> cmOK then
    goto 1;
  if DT.o and 1 <> 0 then
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
  if DT.Mask = '' then
    DT.Mask := x_x;
  SDesc := DT.Text <> '';
  UpStr(DT.Text);
  if FindList <> nil then
    FindList.Free;
  FindList := nil;
  P := WriteMsg(GetString(dlPleaseStandBy));
  if DT.o and 2 <> 0 then
    SearchInAllFiles
  else
    SearchInStream(Stream, GetName(Name^));
  P.Free;
  if FindList = nil then
    begin
    MessageBox(^C+GetString(dlNoFilesFound), nil,
      mfInformation+mfOKButton);
    Exit;
    end;
1:
  if FindList <> nil then
    ExecuteFindDialog;
  if FindList <> nil then
    FindList.Free;
  FindList := nil;
  end { TArvidDrive.DrvFindFile };

procedure TArvidDrive.GetDirLength(PF: PFileRec);
  var
    SaveDir: String;
    LL: TSize;
    P: TView;
  begin
  if  (PF^.Attr and $80 <> 0) or (PF^.Attr and Directory = 0) then
    Exit;
  SaveDir := CurDir;
  LL := 0;
  CurDir := ArcNormName(PF^.Owner^, PF^.FlName[True]);
  SeekDirectory;
  P := WriteMsg(GetString(dlPleaseStandBy));
  if filetype = avdTdr then
    TdrCalcTotal(Self, CurDirPos, LL)
  else
    AvtCalcTotal(Self, CurDirPos, LL);
  P.Free;
  PF^.Size := LL;
  PF^.Attr := PF^.Attr or $80;
  CurDir := SaveDir;
  SeekDirectory;
  end { TArvidDrive.GetDirLength };

function TArvidDrive.OpenDirectory(const Dir: String;
                                         PutDirs: Boolean): TDrive;
  begin
  OpenDirectory := nil;
  end;

procedure TArvidDrive.ReadDescrptions(FilesC: TFilesCollection);
  begin
  end;

end.
