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
  Defines, baseobjs, Streams, Views, Drivers,
  FilesCol, DiskInfo, Collect
  , panelsetup
  ;

const
  dsActive = 0;
  dsInvalid = 1;

  

type
  PDrive = ^TDrive;
{`2 Вспомогательный объект, вставляемый в файловую панель.
  Содержит особенности, специфические для типа панели (диск,
  архив и т.п. Используется, в частности, для отрисовки строк
  файловой панели.`}
  TDrive = object(TObject)
    {Cat: этот объект вынесен в плагинную модель; изменять крайне осторожно!}
    Panel: Pointer{PFilePanelRoot};
    Prev: PDrive;
    DriveType: TDriveType;
    CurDir: String; {DataCompBoy}
    DizOwner: String; {DataCompBoy}
    NoMemory: Boolean;
    SizeX: LongInt;
    ColAllowed: TFileColAllowed;
      {` Зависит от типа панели; введен на всякий случай для
      облегчения будущего ввода новых типов панелей. `}
    
    constructor Init(ADrive: Byte; AOwner: Pointer);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream); virtual;
    procedure KillUse; virtual;
    procedure lChDir(ADir: String); virtual; {DataCompBoy}
    function GetDir: String; virtual; {DataCompBoy}
    function GetDirectory(
         const FileMask: String;
        var TotalInfo: TSize): PFilesCollection; virtual;
    procedure CopyFiles(Files: PCollection; Own: PView; MoveMode: Boolean)
      ; virtual;
    procedure CopyFilesInto(Files: PCollection; Own: PView;
         MoveMode: Boolean); virtual;
    procedure EraseFiles(Files: PCollection); virtual;
    procedure UseFile(P: PFileRec; Command: Word); virtual;
    {DataCompBoy}
    procedure GetFreeSpace(var S: String); virtual;
    function Disposable: Boolean; virtual;
    function GetRealName: String; virtual;
    function GetInternalName: String; virtual;
    procedure GetFull(var B: TScreenCell; P: PFileRec; C, Sc: Word); virtual;
     {` Сформировать в буфере B элемент файловой панели для файла
      P в цвете С с Draw-кодом разделителя колонок Sc (цвет
      разделителя может отличаться от цвета файла).
        Этот метод работает для всех стандартных классов
      панелей. А виртуальным он сделан на всякий случай. `}
    procedure MakeTop(var S: String); virtual;
     {` Сформировать (раскрашенную) строку заголовков колонок.
     Этот метод действительно перекрывается в разных классах
     панелей. `}
    procedure RereadDirectory(S: String); virtual; {DataCompBoy}
    procedure GetDown(var B: TScreenCell; C: Word; P: PFileRec;
        var LFN_inCurFileLine: Boolean); virtual;
      {` Сформировать строку текущего файла для подвала
      в буфере B цветом С. LFN_inCurFileLine показывает,
      показано ли при этом длинное имя, притом полностью. `}
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
    destructor Done; virtual;
    function OpenDirectory(const Dir: String;
                                 PutDirs: Boolean): PDrive; virtual;
    procedure DrvFindFile(FC: PFilesCollection); virtual;
    procedure ReadDescrptions(FilesC: PFilesCollection); virtual;
    function GetDriveLetter: Char; virtual;
      {` Для выбора обозначения диска в линейке дисков и меню дисков `}
    end;

procedure RereadDirectory(Dir: String);

const
  TempDirs: PSortedCollection = nil;
  TempFiles: PFilesCollection = nil;

implementation
uses
  osdep, Lfn, uselfn, fsinfo,
  Startup, Tree, mainapp, FileCopy, Eraser, filepanel, Commands,
  Dialogs, FileFind, panelroot, Filediz, CmdLine
  , xTime, Messages, dirwatch, Dos
  , progress {для PWhileView}, DnIni, basics, strutil, fileutil
  ;

const
  LowMemSize = $4000; {Local setting}

type
  {-DataCompBoy-}
  PDesc = ^TDesc;
    {`2 Элемент TDIZCol }
  TDesc = record
    Name: String;
    DIZText: LongString;
    Line: LongInt;
    end;
    {`}
  {-DataCompBoy-}

  PDIZCol = ^TDIZCol;
    {`2 Коллекция описаний из файла описаний. Используется для
    быстрого поиска описаний по имени при входе в каталог.
    Имена запоминаются в коллекции на верхнем регистре. }
  TDIZCol = object(TSortedCollection)
    procedure FreeItem(P: Pointer); virtual;
    function Compare(P1, P2: Pointer): Integer; virtual;
    end;
    {`}

function ESC_Pressed: Boolean;
  var
    E: TEvent;
  begin
  Application^.Idle;
  GetKeyEvent(E);
  ESC_Pressed := (E.What = evKeyDown) and (DNKeyCode(E) = kbESC)
  end;

{-DataCompBoy-}
procedure TDIZCol.FreeItem(P: Pointer);
  begin
  if P <> nil then
    begin
    PDesc(P)^.DIZText := ''; // освободить строку
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
constructor TDrive.Init(ADrive: Byte; AOwner: Pointer);
  begin
  TObject.Init;
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
constructor TDrive.Load(var S: TStream);
  begin
  TObject.Init;
  Prev := PDrive(S.Get);
  S.ReadStrV(CurDir);
  {S.Read(CurDir[0], 1); S.Read(CurDir[1], Length(CurDir));}
  
  S.Read(ColAllowed, SizeOf(ColAllowed));
  
  DriveType := dtDisk;
  NoMemory := False;
  end { TDrive.Load };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TDrive.Store(var S: TStream);
  begin
  S.Put(Prev);
  S.WriteStr(@CurDir); {S.Write(CurDir, Length(CurDir)+1);}
  
  S.Write(ColAllowed, SizeOf(ColAllowed));
  end;
{-DataCompBoy-}

destructor TDrive.Done;
  begin
  if Prev <> nil then
    Dispose(Prev, Done);
  inherited Done;
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
  {Cat: проверяем на сетевой путь}
  if CurDir[1] = '\' then
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
  { Сформировать колонку размера. Это может быть либо
  действительно размер, либо обозначение каталога,
  если его размер неизвестен }
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
  Flags := PFilePanelRoot(Panel)^.PanSetup^.Show.ColumnsMask;
  for i := Low(TFileColAllowed) to High(TFileColAllowed) do
    begin
    if not ColAllowed[i] then
      Flags := Flags and not (1 shl Ord(i));
    end;
  { Теперь Flags содержит только допустимые для данного типа панели биты }
  LFNLen := PFilePanelRoot(Panel)^.CalcNameLength;
  if not PFilePanelRoot(Panel)^.LFNLonger250 then
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
    S := S+GetString(dlTopSize); //! для dtArcDrive надо бы dlTopOriginal
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
  if PFilePanelRoot(Panel)^.LFNLonger250 then
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
  Flags := PFilePanelRoot(Panel)^.PanSetup^.Show.ColumnsMask;
  for i := Low(TFileColAllowed) to High(TFileColAllowed) do
    begin
    if not ColAllowed[i] then
      Flags := Flags and not (1 shl Ord(i));
    end;
  { Теперь Flags содержит только допустимые для данного типа панели биты }

  PFilePanelRoot(Panel)^.FormatName(P, NameString, NameLen);
  if P^.Selected then
    begin
    Sc := Sc and $00FF + C and $FF00;
    C := Swap(C);
    end;
  X := 0;
  if not PFilePanelRoot(Panel)^.LFNLonger250 then
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

  if PFilePanelRoot(Panel)^.LFNLonger250 then
    begin { длинное имя в конце подавляет вывод комментария и пути }
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

procedure TDrive.EraseFiles(Files: PCollection);
  begin
  if Disposable then
    Eraser.EraseFiles(Files);
  end;

procedure TDrive.MakeDir;
  begin
  MakeDirectory;
  end;

procedure TDrive.CopyFiles(Files: PCollection; Own: PView; MoveMode: Boolean);
  var
    B: Boolean;
  begin
  if ReflectCopyDirection
  then
    RevertBar := Message(Desktop, evBroadcast, cmIsRightPanel, Own) <> nil
  else
    RevertBar := False;
  if Disposable then
    FileCopy.CopyFiles(Files, Own, MoveMode, 2*Byte(TypeOf(Self) =
           TypeOf(TFindDrive)));
  end;

procedure TDrive.CopyFilesInto(Files: PCollection; Own: PView; MoveMode: Boolean);
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
    {Cat: проверяем на сетевой путь}
    if  (Length(ATestDir) > 2) and (ATestDir[1] = '\')
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
  ADir := 'C:\';
  if ValidPath(ADir, False) then
    begin
    
    CurDir := ADir;
    Exit;
    end;
  ADir := 'A:\';
  if ValidPath(ADir, False) then
    begin
    
    CurDir := ADir;
    Exit;
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

{ Подготовка сортированной коллекции описаний, откуда описания будет
удобно находить при считывании каталога. Используется ReadFileList}
var
  Descriptions: PDIZCol;
  PD: PDesc;
  IgnoreDiz: Boolean;

function DizNameProc(const N: string; TextStart: Integer): Boolean;
  { Для ReadFileList. Занесение элемента коллекции и первой строки }
  var
    I: Integer;
  begin
  IgnoreDiz := Descriptions^.Search(@N, I);
    // Повторное описание игнорируем
  if not IgnoreDiz then
    begin
    New(PD);
    PD^.Name := N;
    PD^.DizText := Copy(LastDizLine, TextStart, MaxLongStringLength);
    Descriptions^.AtInsert(I, PD);
    end;
  end;

procedure DizLineProc;
  { Для ReadFileList. Добавление очередной строки прямо в элемент
    коллекции}
  const
    CrLf: string[2] = #13#10;
  begin
  if not IgnoreDiz then
    PD^.DizText := PD^.DizText + CrLf + LastDizLine;
  end;

function DizEndProc: Boolean;
  { Для ReadFileList. Ничего делать не надо}
  begin
  Result := False;
  end;

procedure PrepareDIZ(
  { Чтение контейнера описаний и создание коллекции описаний }
    const CurDir: String;
    var Container: String);
  begin
  ClrIO;
  Container := GetDizPath(CurDir, '');
  if Container <> '' then
    begin
    OpenFileList(Container);
    Descriptions := New(PDIZCol, Init($10, $10));
    ReadFileList(DizNameProc, DizLineProc, DizEndProc);
    end;
  ClrIO;
  end;
{-DataCompBoy-}

{-DataCompBoy-}
procedure TossDescriptions(
    PDizContainer: Pointer;
    FilesC: PFilesCollection);
  var
    I, J: LongInt;
    P: PFileRec;
    FName: String;
    PD: PDesc;
    iLFN: TUseLFN;
  begin
  for I := 1 to FilesC^.Count do
    begin
    P := FilesC^.At(I-1);
    for iLFN := High(TUseLFN) downto Low(TUseLFN) do
      begin
      FName := P^.FlName[iLFN];
      {if P^.Attr and (Directory+SysFile) <> 0 then LowStr(FName);}
      if Descriptions^.Search(@FName, J) then
        begin
        PD := PDesc(Descriptions^.At(J));
        New(P^.DIZ);
        P^.DIZ^.DIZText := PD^.DIZText;
        P^.DIZ^.Container := PDizContainer;
        P^.DIZ^.Line := PD^.Line;
//        PD^.DIZText := '';
  {AnsiString память не тратят при копировании, поэтому можно не спешить
  с освобождением и подождать до освобождения элемента коллекции }
        Break;
        end
      end;
    end;
  end { TossDescriptions };
{-DataCompBoy-}


procedure TDrive.ReadDescrptions(FilesC: PFilesCollection);
  begin
  PrepareDIZ(CurDir, DizOwner);
  if Descriptions <> nil then
    begin
    TossDescriptions(@DizOwner, FilesC);
    Dispose(Descriptions, Done);
    end;
  end;

function TDrive.GetDriveLetter: Char;
  begin
  Result := CurDir[1];
  end;

{-DataCompBoy-}
function TDrive.GetDirectory( const FileMask: String; var TotalInfo: TSize): PFilesCollection;
  var
    SR: lSearchRec;
    P: PFileRec;
    I, J: Integer;
    TFiles: Word;
    Files: PFilesCollection;
    MemReq: LongInt;
    MAvail: LongInt;
    SearchAttr: word;
    PName: PString; //AK155 В SR имя для сравнения с маской
  begin
  ClrIO;
  PName := @SR.FullName;
  
  if (Panel <> nil) and
     ((PFilePanelRoot(Panel)^.PanSetup^.Show.ColumnsMask
       and psLFN_InColumns) = 0)
  then // в панели короткие имена
    PName := @SR.SR.Name;
  

  TFiles := 0;
  DizOwner := '';
  Descriptions := nil;
  Abort := False;
  NoMemory := False;
  TotalInfo := 0;
  Files := New(PFilesCollection, Init($10, $20));
  Files^.Panel := Panel;

  {JO: сначала один pаз опpеделяем объём доступной памяти, а затем по ходу дела}
  {    подсчтитываем насколько тpебования памяти pастут и не пpевысили ли они  }
  {    доступный изначально объём                                              }
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
      with Files^ do
        AtInsert(Count, P)
      end;
    DosError := 0;
    lFindNext(SR);
    end;
  lFindClose(SR);
  NoMemory := (MAvail <= MemReq);
  if  (Length(CurDir) > GetRootStart(CurDir)) then
    begin
    Files^.AtInsert(0, NewFileRec('..',
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
    Prev^.RereadDirectory(S);
  end;

procedure TDrive.GetDirInfo(var B: TDiskInfoRec);
  begin
  ReadDiskInfo(CurDir, B);
  B.Free := NewStr(PFilePanelRoot(Panel)^.FreeSpace);
  end;

procedure TDrive.KillUse;
  begin
  if Prev <> nil then
    Prev^.KillUse;
  end;

procedure TDrive.GetDown(var B: TScreenCell; C: Word; P: PFileRec; var LFN_inCurFileLine: Boolean);
  var
    S, S1, S2, SCreat, SLAcc: String;
    w, NameWidht: Word;
  begin
  if P = nil then
    Exit;
  w := PFilePanelRoot(Panel)^.PanSetup^.Show.CurFileNameType;
  if w = cfnHide then
    S2 := ''
  else
    begin
    NameWidht := 13 + CountryInfo.TimeFmt; // уместить 12-часовое время
    
    uLfn := PFilePanelRoot(Panel)^.PanSetup^.Show.
      ColumnsMask and psLFN_InColumns <> 0;
    if w = cfnTypeOther then
      S2 := P^.FlName[uLfn xor InvLFN]
    else
      
      S2 := P^.FlName[True];
    if Length(S2) > NameWidht then
      begin
      SetLength(S2, NameWidht);
      S2[NameWidht] := FMSetup.RestChar[1];
      end
    else
      S2 := AddSpace(S2, NameWidht);
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
    D: PDialog;
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
            D := PDialog(LoadResource(dlgDiskError));
            if D <> nil then
              begin
              D^.SetData(MM);
              Application^.ExecView(D);
              D^.GetData(MM);
              Dispose(D, Done);
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
              D := PDialog(LoadResource(dlgDiskError));
              if D <> nil then
                begin
                D^.SetData(MM);
                Application^.ExecView(D);
                D^.GetData(MM);
                Dispose(D, Done);
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
                                    PutDirs: Boolean): PDrive;
  var
    I: LongInt;
    PI: PView;
    PDrv: PDrive;
    DirsToProcess: PCollection;
      { несортированная коллекция, элементы которой создаются при помощи
      NewStr и после использования переносятся в Dirs }
    Dirs: PStringCollection;
    Files: PFilesCollection;
    P: PString;
    tmr: TEventTimer;
    MemReq: LongInt;
    MAvail: LongInt;

  procedure AddDirectory(S: String);
    { добавить каталог в список для обработки }
    begin
    if MAvail <= MemReq then
      Exit;
    MakeSlash(S);
    DirsToProcess^.Insert(NewStr(S));
    Inc(MemReq, SizeOf(ShortString)); //почему 255, а не что-то+length(S)?
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
          Files^.AtInsert(Files^.Count, NewFileRec(SR.FullName,
              
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
            Files^.AtInsert(Files^.Count, NewFileRec(SR.FullName,
                
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
  Dirs := New(PStringCollection, Init($10, $10, False));
  DirsToProcess := New(PStringCollection, Init($10, $10, False));

  PI := WriteMsg(GetString(dlReadingList));
  New(Files, Init($10, $10));
  {JO: сначала один pаз опpеделяем объём доступной памяти, а затем по ходу дела}
  {    подсчтитываем насколько тpебования памяти pастут и не пpевысили ли они  }
  {    доступный изначально объём                                              }
  MemReq := LowMemSize;
  MAvail := MaxAvail;
  AddDirectory(lFExpand(Dir));
  I := DirsToProcess^.Count-1;
  Abort := False;
  while (I >= 0) and (not Abort) and (MAvail > MemReq) do
    begin
    P := DirsToProcess^.At(I);
    DirsToProcess^.AtDelete(I);
    Dirs^.Insert(P);
    ReadDir(P);
    if TimerExpired(tmr) then
      begin
      NewTimer(tmr, 50);
      if ESC_Pressed then
        Abort := True;
      end;
    I := DirsToProcess^.Count-1;
    end;
  PI^.Free;
  // JO: здесь сортировка не нужна, т.к. она делается в TFindDrive.GetDirectory
  //     и в результате мы получаем сортировку дважды
  {Files^.Sort;}
//используем '><' в качестве пpизнака ветви
  PDrv := New(PFindDrive, Init('><'+Dir, Dirs, Files));
  PDrv^.NoMemory := MAvail <= MemReq;
  OpenDirectory := PDrv;
  end { TDrive.OpenDirectory };

{-DataCompBoy-} {JO - 31-03-2006 - сделал виртуальным методом TDrive}
procedure TDrive.DrvFindFile(FC: PFilesCollection);
  var
    PInfo: PWhileView;
    Files: PFilesCollection;
    Directories: PCollection;
    BB: Byte; {-$VOL}
    R: TRect;
  begin
  FindRec.AddChar := '';

  if ExecResource(dlgFileFind, FindRec) = cmCancel then
    Exit;
  ConfigModified := True; {AK155 Не понял. При чём тут конфиг?!!}
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
  New(Files, Init($10, $10));
  Files^.SortMode := psmLongName;
  Directories := New(PStringCollection, Init(30, 30, False));
  R.Assign(1, 1, 40, 10);
  Inc(SkyEnabled);
  New(PInfo, Init(R));
  PInfo^.Options := PInfo^.Options or ofSelectable or ofCentered;
  if FindRec.What = ''
  then
    PInfo^.Top := GetString(dlDBViewSearch)+Cut(FindRec.Mask, 50)
  else
    PInfo^.Top := GetString(dlDBViewSearch)+Cut(FindRec.Mask, 30)
      +' | '+Cut(FindRec.What, 17);
  PInfo^.Bottom := GetString(dlNoFilesFound);
  PInfo^.Write(1, GetString(dlDBViewSearchingIn));
  Desktop^.Insert(PInfo);
  BB := FindFiles(Files, Directories, FindRec, PInfo, FC, False);
  Desktop^.Delete(PInfo);
  Dec(SkyEnabled);
  Dispose(PInfo, Done);
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

  procedure Action(View: PView);
    begin
    Event.What := evCommand;
    Event.Command := cmRereadDir;
    Event.InfoPtr := @Dir;
    View^.HandleEvent(Event);
    end;

  begin
  
  Dir := lfGetLongFileName(Dir);
  
  Desktop^.ForEach(Action);
  end;

end.

