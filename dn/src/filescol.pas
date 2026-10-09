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

unit FilesCol;

interface

uses
  uselfn, Defines, Streams,
  Collect, Drivers, Hash
  ;

type
  PDiz = ^TDIZ;
  TDIZ = record
    {` File description for use in TFileRec }
    Container: PString;
      {` Full path of the descriptions file. Need not free it.
       Not used in Arvid. `}
    DIZText: LongString;
      {` Description without the file name. Lines separated by CrLf`}
    Line: LongInt;
      {` At RITLabs this was the line number in the descriptions file where
       this description starts, but it was never used anywhere.
       This field is used only in Arvid, but in a completely
       different sense.`}
    end;
    {`}
  TShortName = String[12];
  PFlName = ^TFlName;
  TFlName = array[TUseLFN] of TShortName;
  {Used here and in TDirRec}
  TDate4 = record
    Minute, Hour, Day, Month: Byte
    end;

  PPFileRec = ^PFileRec;
  PFileRec = ^TFileRec;
  TFileRec = record
    Size: TSize;
      { If size is unknown, Size=-1 (typical for directories) }
    PSize: TSize;
    Owner: PString;
    DIZ: PDiz;
    Yr: Word;
    YrCreat: Word;
    YrLAcc: Word;
    TType: Byte;
    Attr: Word;
    Second: Byte;
    SecondCreat: Byte;
    SecondLAcc: Byte;
    Selected: Boolean;
    UsageCount: Byte; {DataCompBoy}
    FDate, FDateCreat, FDateLAcc: LongInt; {actually TDate4}
    FlName: TFlName;
    {see uselfn.pas }
    Dummy: array[1..SizeOf(ShortString)-SizeOf(TShortName)] of Char;
    {and this is where the long name tail hangs in those
      cases when a local variable of type TFileRec is created or
      with temporary dynamic allocation in the style of new(PFilerec).
      Normally dynamic allocation should be done via
      CreateFileRec or NewFileRec, where exactly as much memory is
      allocated as needed. Because of this trick the FlName field
      must be at the very end of this structure.
      Copy the long name not with ':=', but with
      CopyShortString. AK155 }
      {<filescol.001>}
    end;
var
  pr: TFileRec;
const
  TFileRecFixedSize = SizeOf(TFileRec)
  -SizeOf(pr.Dummy)-SizeOf(pr.FlName[True])+1;

type
  TMakeListRec = record
    FileName: String; {DataCompBoy}
    Header: String;
    HeaderMode: Word;
    Action: String;
    Footer: String;
    FooterMode: Word;
    Options: Word;
    end;

  {-DataCompBoy-}
  PUserParams = ^TUserParams;
  tUserParams = record
    Active, Passive: PFileRec;
    ActiveList, PassiveList: String;
    end;
  {-DataCompBoy-}

  {Cat: removed, Collect.TLineCollection is used now}
  (*
    TLineCollection = PTextCollection;
    TLineCollection = TTextCollection;
*)

  TFilesCollection = class;
  TFilesCollection = class(TSortedCollection)
    {Cat: this type is exposed in the plugin model; change with extreme care!}
    SortMode: Byte;
    Selected: LongInt;
    Panel: Pointer; {TFilePanel}
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    procedure Write(Os: opstream); override;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
    procedure FreeItem(Item: Pointer); override;
    function Compare(Key1, Key2: Pointer): Integer; override;
    function FileCompare(Key1, Key2: Pointer): Integer;
    procedure DelDuplicates(var TotalInfo: TSize);
      {` Remove records that refer to the same file.
        If the collection is sorted, it must be sorted
        before calling this routine `}
    end;

type
  TFilesHash = class;
  {` Hasher used for fast name/path lookup
    in unsorted collections `}
  TFilesHash = class(THash)
    procedure Hash(Item: Pointer); override;
    function Equal(Item1, Item2: Pointer): Boolean; override;
    end;

const
  cmlPathNames = 1;
  cmlAutoDetermine = 2;

  hfmAuto = 0;
  hfmInsertText = 1;
  hfmInsertFiles = 2;

function SelectDrive(X, Y: Integer; Default: Char; IncludeTemp: Boolean)
  : String;
function CopyFileRec(FR: PFileRec): PFileRec; {DataCompBoy}
function FileShortName(const FR: TFileRec): String;
  {` The short name of a file for the macros of the menus and the descriptions: the 8.3 name where the file system has such names (DOS, Windows), else the
   name itself: the field FlName[False] holds 12 bytes and cuts a longer name, which is no name of a file. `}
function CreateFileRec(Name: String): PFileRec;
  {` Name is the name with full path. Based on the path a
   newstr is created and stored in Owner. The caller must
   free owner before destroying this file record. `}

function NewFileRec(const LFN, Name: String; Size: TSize;
     Date, CreationDate, LastAccDate: LongInt; Attr: Word;
     AOwner: PString): PFileRec; {DataCompBoy}

procedure DelFileRec(var FR: PFileRec); {DataCompBoy}
function LoadFileRec(Ip: ipstream): PFileRec; {DataCompBoy}
procedure StoreFileRec(Os: opstream; fr: PFileRec); {DataCompBoy}
function LoadFileRecOwn(Ip: ipstream; Dirs: TCollection): PFileRec;
  {` Read the record, then the index in Dirs and fill Owner`}
procedure StoreFileRecOwn(Os: opstream; fr: PFileRec; Dirs: TCollection);
  {` Write the record and then the owner index into Dirs`}
function PackedDate(P: PFileRec): LongInt; {DataCompBoy}
function PackedCreationDate(P: PFileRec): LongInt; {JO}
function PackedLastAccDate(P: PFileRec): LongInt; {JO}
//function GetFileType(const S: String; Attr: Byte): Integer;
{procedure ReplaceLongName(var fr: PFileRec; const NewName: string);}

function SameFile(P1, P2: PFileRec): Boolean;
  {` Whether the file records refer to the same file,
  i.e. whether the (long) name and path match. `}

implementation
uses DnPath,
  Lfn, DNUtf8, mainapp, Menus, Views, panelroot, filepanel, Drives,
  objutil, Commands, Messages,
  {!!}CmdLine
  
  
  , osdep, Math, OSSystem
  
  , fsinfo, DnIni, Dos, FileType, panelsetup, keymap
  , DNHelp, basics, strutil, fileutil, Startup
  ;

const
  pfrPacked = $80;
  pfrSelect = $40;

type
  TPackedFileRec = record
    Time: LongInt;
    Attr: Byte;
    NLen: Byte;
    end;

  {-DataCompBoy-}
function FileShortName(const FR: TFileRec): String;
  begin
  if OSHasShortNames then
    Result := FR.FlName[False]
  else
    Result := FR.FlName[True];
  end;

function CreateFileRec(Name: String): PFileRec;
  var
    fr: PFileRec;
    lsr: lSearchRec;
    l: LongInt;
    D: DateTime;
    path: String;
    FName: String;
    iLFN: TUseLFN;
  begin
  Name := lFExpand(Name);
  lFindFirst(Name, AnyFileDir, lsr);
  lFindClose(lsr);
  path := GetPath(Name);
  Name := GetName(Name);
  {  l := TFileRecFixedSize+length(lsr.FullName);}
  l := SizeOf(TFileRec);
  GetMem(fr, l);
  CreateFileRec := fr;
  FillChar(fr^, l, 0);

  if DosError = 0 then
    begin
    
    fr^.FlName[False] := lsr.SR.Name;
    
    CopyShortString(lsr.FullName, fr^.FlName[True]);
    fr^.Size := lsr.FullSize;
    fr^.PSize := lsr.FullSize;
    fr^.Owner := NewStr(path);
    fr^.DIZ := nil;

    UnpackTime(lsr.SR.Time, D);
    fr^.Yr := D.Year;
    with TDate4(fr^.FDate) do
      begin
      Month := D.Month;
      Day := D.Day;
      Hour := D.Hour;
      Minute := D.Min;
      end;
    fr^.Second := D.Sec;

    UnpackTime(lsr.SR.CreationTime, D); {JO}
    fr^.YrCreat := D.Year;
    with TDate4(fr^.FDateCreat) do
      begin
      Month := D.Month;
      Day := D.Day;
      Hour := D.Hour;
      Minute := D.Min;
      end;
    fr^.SecondCreat := D.Sec;

    UnpackTime(lsr.SR.LastAccessTime, D);
    fr^.YrLAcc := D.Year;
    with TDate4(fr^.FDateLAcc) do
      begin
      Month := D.Month;
      Day := D.Day;
      Hour := D.Hour;
      Minute := D.Min;
      end;
    fr^.SecondLAcc := D.Sec; {/JO}

    fr^.Attr := lsr.SR.Attr;
    if CharCount('.', lsr.FullName) = 0 then
      begin
      SetLength(lsr.FullName, Length(lsr.FullName)+1);
      lsr.FullName[Length(lsr.FullName)] := '.';
      fr^.TType := GetFileType(lsr.FullName, fr^.Attr);
      SetLength(lsr.FullName, Length(lsr.FullName)-1);
      end
    else
      fr^.TType := GetFileType(lsr.FullName, fr^.Attr);
    {Cat: this is clearly redundant - for !\!.! masks for viewers and extension
      launch, undistorted file names must be passed
  PS  and one should look again and check whether this function is needed at all
     if fr^.Attr and Directory <> 0 then UpStr(fr^.Name) else LowStr(fr^.Name);}
    {/Cat}
    if fr^.Attr and Directory <> 0 then
      fr^.Size := -1;
    end
  else
    begin
    fr^.Owner := NewStr(path);
    
    fr^.FlName[False] := GetURZ(GetName(lfGetShortFileName(Name)));
    
    fr^.FlName[True] := Name;
    end;
  with fr^ do
    begin
    UsageCount := 1;
    end;
  end { CreateFileRec };
{-DataCompBoy-}

{-DataCompBoy-}
function CopyFileRec(FR: PFileRec): PFileRec;
  begin
  CopyFileRec := FR;
  with FR^ do
    Inc(UsageCount);
  end;
{-DataCompBoy-}

{-DataCompBoy-}
procedure DelFileRec(var FR: PFileRec);
  begin
  if FR <> nil then
    begin
    Dec(FR^.UsageCount);
    if FR^.UsageCount = 0 then
      begin
      if FR^.DIZ <> nil then
        begin
        FR^.DIZ^.DIZText := ''; // free the string
        Dispose(FR^.DIZ);
        end;
      {  FreeMem(FR, TFileRecFixedSize+length(FR^.FlName[true]));}
      FreeMem(FR, SizeOf(TFileRec));
      FR := nil;
      end
    end;
  end;
{-DataCompBoy-}

{-DataCompBoy-}
function LoadFileRec(Ip: ipstream): PFileRec;
  var
    P: PFileRec;
    l: Byte;
    FullLen: LongInt;
  begin
  Ip.ReadBytes(l, SizeOf(l)); {long name length}
  { FullLen := TFileRecFixedSize+l;}
  FullLen := SizeOf(TFileRec);
  GetMem(P, FullLen);
  FillChar(P^, FullLen, 0);
  with P^ do
    begin
    Ip.ReadBytes(Size, SizeOf(Size));
    Ip.ReadBytes(PSize, SizeOf(PSize));
    Ip.ReadBytes(Yr, SizeOf(Yr));
    Ip.ReadBytes(YrCreat, SizeOf(YrCreat));
    Ip.ReadBytes(YrLAcc, SizeOf(YrLAcc));
    Ip.ReadBytes(TType, SizeOf(TType));
    Ip.ReadBytes(Attr, SizeOf(Attr));
    Ip.ReadBytes(Second, SizeOf(Second));
    Ip.ReadBytes(SecondCreat, SizeOf(SecondCreat));
    Ip.ReadBytes(SecondLAcc, SizeOf(SecondLAcc));
    Ip.ReadBytes(Selected, SizeOf(Selected));
    Ip.ReadBytes(FDate, SizeOf(FDate));
    Ip.ReadBytes(FDateCreat, SizeOf(FDateCreat));
    Ip.ReadBytes(FDateLAcc, SizeOf(FDateLAcc));
    
    Ip.ReadBytes(FlName[False], SizeOf(FlName[False]));
    
    Ip.ReadBytes(FlName[True], l+1);
    UsageCount := 1;
    end;
  LoadFileRec := P;
  end { LoadFileRec };

procedure StoreFileRec(Os: opstream; fr: PFileRec);
  var
    l: Byte;
  begin
  with fr^ do
    begin
    l := Length(FlName[True]);
    Os.WriteBytes(l, SizeOf(l));
    Os.WriteBytes(Size, SizeOf(Size));
    Os.WriteBytes(PSize, SizeOf(PSize));
    Os.WriteBytes(Yr, SizeOf(Yr));
    Os.WriteBytes(YrCreat, SizeOf(YrCreat));
    Os.WriteBytes(YrLAcc, SizeOf(YrLAcc));
    Os.WriteBytes(TType, SizeOf(TType));
    Os.WriteBytes(Attr, SizeOf(Attr));
    Os.WriteBytes(Second, SizeOf(Second));
    Os.WriteBytes(SecondCreat, SizeOf(SecondCreat));
    Os.WriteBytes(SecondLAcc, SizeOf(SecondLAcc));
    Os.WriteBytes(Selected, SizeOf(Selected));
    Os.WriteBytes(FDate, SizeOf(FDate));
    Os.WriteBytes(FDateCreat, SizeOf(FDateCreat));
    Os.WriteBytes(FDateLAcc, SizeOf(FDateLAcc));
    
    Os.WriteBytes(FlName[False], SizeOf(FlName[False]));
    
    Os.WriteBytes(FlName[True], l+1);
    end
  end { StoreFileRec };
{-DataCompBoy-}

function LoadFileRecOwn(Ip: ipstream; Dirs: TCollection): PFileRec;
  var
    w: LongInt;
  begin
  Result := LoadFileRec(Ip);
  if Result <> nil then
    begin
    Ip.ReadBytes(w, SizeOf(w));
    Result^.Owner := Dirs.At(w);
    end;
  end;

procedure StoreFileRecOwn(Os: opstream; fr: PFileRec; Dirs: TCollection)
  ; {DataCompBoy}
  var
    w: LongInt;
  begin
  StoreFileRec(Os, fr);
  w := Dirs.IndexOf(fr^.Owner);
  Os.WriteBytes(w, SizeOf(w));
  end;

{-DataCompBoy-}
function TFilesCollection.Read(Ip: ipstream): Pointer;
  var
    C, I: LongInt;
  begin
  Result := Self;
  Ip.ReadBytes(Count, SizeOf(Count));
  Ip.ReadBytes(Limit, SizeOf(Limit));
  Ip.ReadBytes(Delta, SizeOf(Delta));
  if  (Count > Limit) or (Delta < 0) then
    begin Free; Result := nil; Exit end;
  C := Count;
  I := Limit;
  Count := 0;
  Limit := 0;
  SetLimit(I);
  for I := 0 to C-1 do
    begin
    AtInsert(I, LoadFileRec(Ip));
    if Ip.Fail <> 0 then
      begin
      SetLimit(0);
      begin Free; Result := nil; Exit end;
      end;
    end;
  Ip.ReadBytes(Selected, SizeOf(Selected));
  end { TFilesCollection.Load };
{-DataCompBoy-}

{-DataCompBoy-}
procedure TFilesCollection.Write(Os: opstream);
  var
    I, J, Sel: LongInt;
  begin
  J := 0;
  for I := 1 to Count do
    if  (I-1 = Selected) or (PFileRec(At(I-1))^.Selected) then
      begin
      if I-1 = Selected then
        Sel := J;
      Inc(J)
      end;
  I := Count;
  Count := J;
  Os.WriteBytes(Count, SizeOf(Count));
  Os.WriteBytes(Limit, SizeOf(Limit));
  Os.WriteBytes(Delta, SizeOf(Delta));
  Count := I;
  for I := 1 to Count do
    if  (I-1 = Selected) or (PFileRec(At(I-1))^.Selected) then
      StoreFileRec(Os, At(I-1));
  Os.WriteBytes(Sel, SizeOf(Sel));
  end { TFilesCollection.Store };

{ an item is a file record (PFileRec) }
function TFilesCollection.ReadItem(Ip: ipstream): Pointer;
  begin
  Result := LoadFileRec(Ip);
  end;

procedure TFilesCollection.WriteItem(Item: Pointer; Os: opstream);
  begin
  StoreFileRec(Os, Item);
  end;

class function TFilesCollection.Build: TStreamable;
begin
  Result := TFilesCollection.Create(streamableInit);
end;

function TFilesCollection.StreamableName: ShortString;
begin
  Result := 'FilesCol.TFilesCollection';
end;
{-DataCompBoy-}

{-DataCompBoy-}
procedure TFilesCollection.FreeItem(Item: Pointer);
  var
    P: PFileRec absolute Item;
  begin
  DelFileRec(P);
  end;
{-DataCompBoy-}

{-DataCompBoy-}
//JO: 02-02-2004 - added sort by path in panels showing a branch
//                 and reverse sort
function TFilesCollection.Compare(Key1, Key2: Pointer): Integer;
  var
    {T1: TFileRec;}
    P1: PFileRec absolute Key1;
    P2: PFileRec absolute Key2;
    C: Integer;
    SM, I1, I2, UpN: Integer;
    P1P, P2P: Boolean;
    SortFlags: Byte;
    CmpMethod: Word;
    ST1, ST2: String;
    NameDirsSortEnabled: Boolean;

  const
    Ups: array[1..4] of Word = (0, 0, 0, 0);

  label Lab1;

  function CmpName(const S1: String; const S2: String;
      const owner1: String; const owner2: String): Integer;
    begin
    if S1 > S2 then
      CmpName := +1
    else if S1 < S2 then
      CmpName := -1
    else if owner1 > owner2 then
      CmpName := +1
    else if owner1 < owner2 then
      CmpName := -1
    else
      CmpName := 0;
    end;

  function CmpEXT(S1, S2: String): Integer;
    var
      E1, E2: PString;
      B: Byte;
    const
      D1: Char = #0;
    begin
    B := PosLastDot(S1);
    if B <= Length(S1) then
      begin
      E1 := @S1[B];
      SetLength(E1^, Length(S1)-B);
      SetLength(S1, B-1);
      end
    else
      E1 := @D1;

    B := PosLastDot(S2);
    if B <= Length(S2) then
      begin
      E2 := @S2[B];
      SetLength(E2^, Length(S2)-B);
      SetLength(S2, B-1);
      end
    else
      E2 := @D1;

    if E1^ > E2^ then
      CmpEXT := +1
    else if E1^ < E2^ then
      CmpEXT := -1
    else if S1 > S2 then
      CmpEXT := +1
    else if S1 < S2 then
      CmpEXT := -1
    else
      CmpEXT := 0;
    end { CmpEXT };

  function CmpTime(Yr1, Yr2: Word; FDate1, FDate2: LongInt;
           Second1, Second2: Byte): Integer;
    begin
    if  (Yr1 < Yr2) then
      CmpTime := +1
    else if (Yr1 > Yr2) then
      CmpTime := -1
    else if (FDate1 < FDate2) then
      CmpTime := +1
    else if (FDate1 > FDate2) then
      CmpTime := -1
    else if (Second1 < Second2) then
      CmpTime := +1
    else if (Second1 > Second2) then
      CmpTime := -1
    else
      CmpTime := 0;
    end;

  var
    Name1, Name2: String; {UpStrg(P2^.Name)  // AK155}
    Own1, Own2: String;
    Branched: Boolean; {whether comparison is in a panel showing a branch}
  const
    CompareXlat: array[0..2] of PXLat =
      (@ABCSortXlat, @UpCaseArray, @LowCaseArray);

  procedure CmpKey(var S: String; M: Integer);
    { the key of the comparison of names: by the method of the panel }
    begin
{$IFDEF DNUTF8}
    if M = 2 then
      Utf8LowStr(S)
    else
      Utf8UpStr(S);
{$ELSE}
    XLatStr(S, CompareXlat[M]^);
{$ENDIF}
    end;

  begin { TFilesCollection.Compare }
  NameDirsSortEnabled := False;
  if Panel <> nil then
    begin
    SortFlags := TFilePanel(Panel).PanSetup.Sort.SortFlags;
    Move(TFilePanel(Panel).PanSetup.Sort.Ups, Ups, SizeOf(Ups));
    CmpMethod := TFilePanel(Panel).PanSetup.Sort.CompareMethod;
    if TFilePanel(Panel).Drive <> nil then
      {JO: all panel types that represent an expanded branch}
      Branched := TFilePanel(Panel).Drive.DriveType
        in [dtFind, dtTemp, dtList, dtArcFind]
    else
      Branched := False;
    end
  else
    begin
      {! Previously flags were taken from settings for a new panel,
       interesting, why? And even more interesting, does sorting
       without a panel ever happen and is it needed?}
    SortFlags := 0;
    CmpMethod := 1;
    Branched := False;
    end;
  {Move(Key1^,T1,SizeOf(T1));}
  with P2^ do
    begin
    P1P := P1^.TType = ttUpDir;
    P2P := TType = ttUpDir;
    if P1P and not P2P then
      begin
      Compare := -1;
      Exit;
      end;
    if P2P and not P1P then
      begin
      Compare := +1;
      Exit;
      end;

    Name1 := P1^.FlName[uLfn];
    Name2 := FlName[uLfn];

    CmpKey(Name1, CmpMethod);
    CmpKey(Name2, CmpMethod);

    if P1^.Owner <> nil then
      Own1 := P1^.Owner^
    else
      Own1 := '';
    if Owner <> nil then
      Own2 := Owner^
    else
      Own2 := '';
    //JO: The Branched condition below is for performance,
    //    since changing the case of the enclosing directory for anything but
    //    an expanded branch is a waste of CPU time
    if Branched then
      begin
      MakeNoSlash(Own1);
      MakeNoSlash(Own2);
      CmpKey(Own1, CmpMethod);
      CmpKey(Own2, CmpMethod);
      end;

    SM := SortMode;

    if  (Panel <> nil) then
      begin
      for UpN := 1 to 4 do
        case Ups[UpN] of
     upsDirs:
          begin
//JO: if directories are moved to the start of the panel, then sorting them
//    by name when sorting files by other criteria makes sense
          NameDirsSortEnabled := True;
          if  (P1^.TType = ttDirectory) and (TType <> ttDirectory) then
            begin
            Compare := -1;
            Exit;
            end;
          if  (P1^.TType <> ttDirectory) and (TType = ttDirectory) then
            begin
            Compare := 1;
            Exit;
            end;
          end;
 upsArchives:
          if not (SM in [psmSize, psmTime, psmCrTime,
                         psmLATime]) then
            begin
            if  (P1^.TType = ttArc) and (TType <> ttArc) then
              begin
              Compare := -1;
              Exit;
              end;
            if  (P1^.TType <> ttArc) and (TType = ttArc) then
              begin
              Compare := 1;
              Exit;
              end;
            end;
 upsExecutables:
          if not (SM in [psmSize, psmTime, psmCrTime,
                         psmLATime]) then
            begin
            if  (P1^.TType = ttExec) and (TType <> ttExec) then
              begin
              Compare := -1;
              Exit;
              end;
            if  (P1^.TType <> ttExec) and (TType = ttExec) then
              begin
              Compare := 1;
              Exit;
              end;
            end;
 upsHidSysFiles:
          if not (SM in [psmSize, psmTime, psmCrTime,
                         psmLATime]) then
            begin
            if  ((P1^.Attr and (Hidden+SysFile)) <> 0) and
                ((Attr and (Hidden+SysFile)) = 0) then
              begin
              Compare := -1;
              Exit;
              end;
            if  ((P1^.Attr and (Hidden+SysFile)) = 0) and
                ((Attr and (Hidden+SysFile)) <> 0) then
              begin
              Compare := 1;
              Exit;
              end;
            end;
        end; {case}

      if SortFlags and psfSortByType <> 0 then
        begin
//JO: since when sorting by type all directories are definitely
//    gathered together, sorting them by name when sorting files by
//    other criteria makes sense
        NameDirsSortEnabled := True;
        I1 := P1^.TType;
        I2 := TType;
        if I1 = 0 then
          I1 := 100; // files without type - to the end
        if I2 = 0 then
          I2 := 100; // files without type - to the end
        if I1 < I2 then
          begin
          Compare := -1;
          Exit;
          end
        else if I1 > I2 then
          begin
          Compare := 1;
          Exit;
          end;
        end;
      end; {Panel <> nil}

    if SortFlags and psfOwnerFirst <> 0 then
      begin
      if Own1 < Own2 then
        C := -1
      else if Own1 > Own2 then
        C := 1
      else
        goto Lab1;
      end
    else
      begin
Lab1:

      if (SortFlags and psfDirsByName <> 0) and
//JO: if directories are not moved to the start of the panel, then
//    sorting them by name when sorting files by extension
//    is not only pointless but harmful
         NameDirsSortEnabled and
           ((P1^.Attr or Attr) and Directory <> 0) then
               C := CmpName(Name1, Name2, Own1, Own2)
      else
      case SM of
//JO: in reality with psmUnsorted the Compare method is never called, but
//    just in case it is better that comparison is performed, and
//    it will be fairer if it is a normal comparison by names and
//    paths, rather than something that creates a pseudo-unsorted mess
             psmUnsorted,
        {LFN}psmLongName:
          C := CmpName(Name1, Name2, Own1, Own2);
        {LEXT}psmLongExt:
          begin
          C := CmpEXT(Name1, Name2);
          if C = 0 then
            C := CmpName(Name1, Name2, Own1, Own2);
          end;
        {SIZE}psmSize:
          if P1^.Size > Size then
            C := -1
          else if P1^.Size < Size then
            C := 1
          else
            C := CmpName(Name1, Name2, Own1, Own2);
        {DATE}psmTime:
          begin
          C := CmpTime(P1^.Yr, Yr, P1^.FDate,
                       FDate, P1^.Second, Second);
          if C = 0 then
            C := CmpName(Name1, Name2, Own1, Own2);
          end;
        {JO}
        {Creat.DATE}psmCrTime:
          begin
          C := CmpTime(P1^.YrCreat, YrCreat, P1^.FDateCreat,
                       FDateCreat, P1^.SecondCreat, SecondCreat);
          if C = 0 then
            C := CmpName(Name1, Name2, Own1, Own2);
          end;
        {L.Acc.DATE}psmLATime:
          begin
          C := CmpTime(P1^.YrLAcc, YrLAcc, P1^.FDateLAcc,
                       FDateLAcc, P1^.SecondLAcc, SecondLAcc);
          if C = 0 then
            C := CmpName(Name1, Name2, Own1, Own2);
          end;

        {DIZ}psmDIZ:
          begin
          if  (P1^.DIZ <> nil) then
            begin
            ST1 := P1^.DIZ^.DIZText;
            CmpKey(ST1, CmpMethod);
            end
          else
            ST1 := '';
          if  (P2^.DIZ <> nil) then
            begin
            ST2 := P2^.DIZ^.DIZText;
            CmpKey(ST2, CmpMethod);
            end
          else
            ST2 := '';
          if  (ST1 <> '') and (ST2 = '') then
            C := -1
          else if (ST1 = '') and (ST2 <> '') then
            C := 1
          else
            begin
            if ST1 > ST2 then
              C := 1
            else if ST1 < ST2 then
              C := -1
            else
              C := CmpName(Name1, Name2, Own1, Own2);
            end;
          end;
        {/JO}
      else {case}
//JO: if SortMode has some nonstandard value, then we really
//    compare nothing, just initialize the function result
          C := -1;
      end; {case}
      end;
    end; {with P2^}
  if SortFlags and psfInverted = 0 then
    Compare := C
  else
    Compare := -(C);
  end { TFilesCollection.Compare };

{-DataCompBoy-}

{JO}
//JO: 29-01-2004 - extracted the part of TFilesCollection.Compare that
//    was used when comparing directories into a separate method
//    TFilesCollection.FileCompare . This is justified because first
//    TFilesCollection.Compare had grown disgracefully, and for sort
//    speed its call speed matters, and second because the
//    TFilesCollection.Sortmode field is used by these two functions in completely
//    different ways. FileCompare is used only to compare
//    individual file records, and is never inherited.
//JO: 27-04-2006 - moved into TFilesCollection.FileCompare from
//    TFilesCollection.Compare comparison of files by all criteria at once,
//    used for group file operations in the panel (currently
//    used only for unmarking files via cmCopyUnselect)
function TFilesCollection.FileCompare(Key1, Key2: Pointer): Integer;
  var
    P1: PFileRec absolute Key1;
    P2: PFileRec absolute Key2;
    C: Integer;
    SM: Integer;
    P1P, P2P: Boolean;
    C1: Integer; { name comparison result   // AK155}
    Name1, Name2: String; {UpStrg(P2^.Name)  // AK155}

  begin
  with P2^ do
    begin
    P1P := P1^.TType = ttUpDir;
    P2P := TType = ttUpDir;
    if P1P and not P2P then
      begin
      FileCompare := -1;
      Exit;
      end;
    if P2P and not P1P then
      begin
      FileCompare := +1;
      Exit;
      end;

    Name1 := P1^.FlName[uLfn];
    Name2 := FlName[uLfn];

    UpStr(Name1);
    UpStr(Name2);

    SM := SortMode;

    if  (SM and fcmCaseSensitive = 0)
      
      then
      begin
      if Name1 > Name2 then
        C1 := 1
      else if Name1 < Name2 then
        C1 := -1
      else
        C1 := 0;
      end
    else
      begin
      if P1^.FlName[True] < FlName[True] then
        C1 := -1
      else if P1^.FlName[True] = FlName[True] then
        C1 := 0
      else
        C1 := 1;
      end;

    if SM = fcmPreciseCompare then
//  comparison is used in TFilePanel.HandleEvent for CM_CopyUnselect,
//  i.e. for unmarking files during group operations
      begin
//JO: regarding the $3F mask see AK155's comment of 28-11-05 on the
//    Marked and Copied constants in the FileCopy unit
      if (P1^.Attr and $3F = Attr and $3F)
            and (P1^.Yr = Yr)
            and (P1^.FDate = FDate) and (P1^.Second = Second)
            and (C1 = 0) and (P1^.Owner^ = Owner^)
            then
            FileCompare := 0
          else
            FileCompare := -1;
      Exit;
      end;

    if  (C1 = 0) and ((P1^.Attr or Attr) and Directory = 0) and
        ( (SM and fcmCompSize = 0) or (P1^.Size = Size)) and
        ( (SM and fcmCompTime = 0) or (P1^.Yr < Yr) or
          ( (P1^.Yr = Yr) and (P1^.FDate <= FDate)) or
          ( (P1^.Yr = Yr) and (P1^.FDate = FDate) and (P1^.Second <
             Second))) and
        ( (SM and fcmCompAttr = 0) or (P1^.Attr = Attr)) and
        ( (SM and fcmCompContent = 0) or
        CompareFiles(MakeNormName(P1^.Owner^, Name1),
          MakeNormName(Owner^, Name2)))
    then
      C := 0
    else if (C1 = -1) then
      C := -1
    else
      C := 1;
    FileCompare := C;
    end;
  end { TFilesCollection.FileCompare };
{/JO}

// JO: 18-11-2004 - introduced completely new info display settings
//     in the drive selection menu
function SelectDrive(X, Y: Integer; Default: Char; IncludeTemp: Boolean) : String; {-$VIV, JO}
  var
    R: TRect;
    P: TMenuBox;
    Menu: PMenu;
    Items, Lnk: PMenuItem;
    C: Char;
    N, MaxRY: Integer;
    SC: TCharSet;
    Server_Num, Handle_Num, RetCode, DriveNum, MaxL: Integer;
    {-$VIV start}
    Server, PathName, TmpS: String; {-$VIV end}
    pSaveNeedAbort, ShowDir: Boolean;
    FreeSp: TQuad;
    Tabulated: Boolean;


  function CutLongString(S: String): String;
    var
      P, L: Integer;
      S1: String;
    begin
    CutLongString := #0+S+#0;
    if not CutDriveInfo then
      Exit;
    (* X-Man *)
    CutLongString := FormatLongName(S, 30, 0,
        flnHighlight+flnHandleTildes, nfmNull)
    end;

  var
    IDDQD: record
      Fl, dr: LongInt;
      end;

  procedure GetInfo(P_: Pointer);
  var P: PFileRec absolute P_;
    begin
    if P <> nil then
      if P^.Attr and Directory = 0
      then
        Inc(IDDQD.Fl)
      else
        Inc(IDDQD.dr)
    end;

  type
    TDriveRec = record
      Dr: Char;
      DT: TDrvTypeNew;
      FullS: String[50];
      end;

 const
    MaxSizeDig = 17;

  var
    DrvCnt, InfoCnt, I, J, K: Byte;
    DrvStrArr: array [1..26] of TDriveRec;
    MaxFullSLength: Byte;
    SizeStr: String[MaxSizeDig];

  begin { SelectDrive }
  Items := nil;
  N := 0;
  Lnk := nil;
  MaxL := 8; {-$VIV}
  DrvCnt := 0; {JO}
  MaxFullSLength := 0;
  Tabulated := (InterfaceData.DrvInfType.Tabulated and 1 <> 0);

  

  {Cat}
  
  {/Cat}

  if IncludeTemp
    and (InterfaceData.DrvInfType.AddInfo and ditAddQick <> 0)
  then
    begin
    C := ' ';
    for DriveNum := 8 downto 0 do
      if DirsToChange[DriveNum] <> nil then
        begin
        FreeStr := '~'+ItoS(DriveNum+1)
            +':~ '+CutH(DirsToChange[DriveNum]^, 24);
        Items := NewItem(FreeStr, 'Alt-'+ItoS(DriveNum+1), kbNoKey,
            cmQuickChange1+DriveNum, hcNoContext, Items);
        MaxL := Max(CStrLen(FreeStr), MaxL);
        Inc(N);
        C := '!';
        end;
    if C = '!' then
      Items := NewLine(Items);
    end;

  

  if IncludeTemp then
    begin
    if  (InterfaceData.DrvInfType.AddInfo and ditAddTemp <> 0) then
      if TempFiles <> nil then
        begin
        IDDQD.dr := 0;
        IDDQD.Fl := 0;
        TempFiles.ForEach(GetInfo);
        if IDDQD.dr+IDDQD.Fl = 0 then
          FreeStr := GetString(dlEmpty)
        else if IDDQD.dr = 0 then
          FreeStr := ItoS(IDDQD.Fl)+' '+GetString(dlDIFiles)
        else if IDDQD.Fl = 0 then
          FreeStr := ItoS(IDDQD.dr)+' '+GetString(dlDirectories)
        else
          FormatStr(FreeStr, GetString(dlFilDir), IDDQD);
        end
      else
        FreeStr := GetString(dlEmpty)
    else
      FreeStr := '';

    Items := NewItem('~*:~ TEMP:'+FreeStr, '', kbSpace, 1200,
         hcTempList, Items);
    Items := NewLine(Items);
    Inc(N)
    end;

{$IF HasDrives}
  for C := 'Z' downto 'A' do
    if ValidDrive(C) then
      begin
      Inc(DrvCnt);
      DrvStrArr[DrvCnt].Dr := C;
      DrvStrArr[DrvCnt].FullS := '~'+C+':~';
      end;
  InfoCnt := DrvCnt;
{$ELSE}
  LoadPlaces;                       { one tree: places instead of drive letters }
  for I := PlaceCnt downto 1 do
    begin
    Inc(DrvCnt);
    DrvStrArr[DrvCnt].Dr := Chr(64+I);
    DrvStrArr[DrvCnt].FullS := '~'+Chr(64+I)+'~ '+CutH(Places[I], 40);
    end;
  InfoCnt := 0;
{$ENDIF}

  for I := 1 to InfoCnt do
    begin
    with DrvStrArr[I] do
      if (InterfaceData.DrvInfType.ForDrives = 0) or
        ((InterfaceData.DrvInfType.ForDrives and 1 <> 0) and
         (Pos(Dr, UpStrg(InterfaceData.DrvInfType.ExceptDrv)) = 0)) then
        begin
       {DriveNum := Byte(C)-64;}
        DT := GetDriveTypeNew(Dr);
        case DT of
          dtnFloppy:
            if (InterfaceData.DrvInfType.TypeShowFor and ditFloppy <> 0) then
              FullS := FullS+GetString(sdtRemovable);
          dtnInvalid:
            FullS := FullS+GetString(sdtError);
          dtnCDRom:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditCDMO <> 0) then
              FullS := FullS+GetString(sdtCDROM);
          dtnOptical:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditCDMO <> 0) then
              FullS := FullS+GetString(sdtOptical);
          dtnProgram:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditProgr <> 0) then
              FullS := FullS+GetString(sdtProgram);
          dtnLAN:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditNet <> 0) then
              FullS := FullS+GetString(sdtRemote);
          dtnHDD:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditHDD <> 0) then
              FullS := FullS+GetString(sdtFixed);
          dtRamDisk:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditProgr <> 0) then
              FullS := FullS+GetString(sdtRAMDrive);
          dtnSubst:
            if  (InterfaceData.DrvInfType.TypeShowFor and ditNet <> 0) then
              FullS := FullS+GetString(sdtSubst);
          dtnUnknown:
            FullS := FullS+GetString(sdtError);
        end {case};
        {X-Man <<<}
        if MaxFullSLength < Length(FullS) then
          MaxFullSLength := Length(FullS);
        end;
    end;

  if Tabulated then
    for I := 1 to InfoCnt do
      DrvStrArr[I].FullS := AddSpace(DrvStrArr[I].FullS, MaxFullSLength);

  for I := 1 to InfoCnt do
    with DrvStrArr[I] do
      if (InterfaceData.DrvInfType.ForDrives = 0) or
        ((InterfaceData.DrvInfType.ForDrives and 1 <> 0) and
         (Pos(Dr, UpStrg(InterfaceData.DrvInfType.ExceptDrv)) = 0)) then
        begin
        if ((DT = dtnUnknown)
          or ((DT = dtnHDD)
            and (InterfaceData.DrvInfType.FSShowFor and ditHDD <> 0))
          or ((DT = dtnFloppy)
            and (InterfaceData.DrvInfType.FSShowFor and ditFloppy <> 0))
          or ((DT in [dtnCDRom,dtnOptical])
            and (InterfaceData.DrvInfType.FSShowFor and ditCDMO <> 0))
          or ((DT = dtnProgram)
            and (InterfaceData.DrvInfType.FSShowFor and ditProgr <> 0)))
        then
          begin
          FullS := FullS + ' ' + GetFSString(Dr);
          if MaxFullSLength < Length(FullS) then
            MaxFullSLength := Length(FullS);
          end;
        end;

  if Tabulated then
    for I := 1 to InfoCnt do
      if not (DrvStrArr[I].DT in [dtnLAN, dtnSubst]) then
        DrvStrArr[I].FullS := AddSpace(DrvStrArr[I].FullS, MaxFullSLength);

  for I := 1 to InfoCnt do
    with DrvStrArr[I] do
      if (InterfaceData.DrvInfType.ForDrives = 0) or
        ((InterfaceData.DrvInfType.ForDrives and 1 <> 0) and
         (Pos(Dr, UpStrg(InterfaceData.DrvInfType.ExceptDrv)) = 0)) then
        begin
        if (
          ((DT = dtnHDD)
            and (InterfaceData.DrvInfType.VLabShowFor and ditHDD <> 0))
          or ((DT = dtnFloppy)
            and (InterfaceData.DrvInfType.VLabShowFor and ditFloppy <> 0))
          or ((DT in [dtnCDRom,dtnOptical])
            and (InterfaceData.DrvInfType.VLabShowFor and ditCDMO <> 0))
          or ((DT = dtnProgram)
            and (InterfaceData.DrvInfType.VLabShowFor and ditProgr <> 0)))
        then
          begin
          FullS := FullS + ' ' + SysGetVolumeLabel(Dr);
          if MaxFullSLength < Length(FullS) then
            MaxFullSLength := Length(FullS);
          end;
        end;

  if Tabulated then
    for I := 1 to InfoCnt do
      if not (DrvStrArr[I].DT in [dtnLAN, dtnSubst]) then
        DrvStrArr[I].FullS := AddSpace(DrvStrArr[I].FullS, MaxFullSLength);

  K := MaxSizeDig;

  for I := 1 to InfoCnt do
    with DrvStrArr[I] do
      if (InterfaceData.DrvInfType.ForDrives = 0) or
        ((InterfaceData.DrvInfType.ForDrives and 1 <> 0) and
         (Pos(Dr, UpStrg(InterfaceData.DrvInfType.ExceptDrv)) = 0)) then
        begin
        if (
          ((DT = dtnHDD)
            and (InterfaceData.DrvInfType.FreeSpShowFor and ditHDD <> 0))
          or ((DT = dtnFloppy)
            and (InterfaceData.DrvInfType.FreeSpShowFor and ditFloppy <> 0))
          or ((DT in [dtnCDRom,dtnOptical])
            and (InterfaceData.DrvInfType.FreeSpShowFor and ditCDMO <> 0))
          or ((DT = dtnProgram)
            and (InterfaceData.DrvInfType.FreeSpShowFor and ditProgr <> 0)))
        then
          begin
          FreeSp := SysDiskFreeLong(Byte(Dr)-64);
          if FreeSp >= 0 then
            begin
            SizeStr := RtoS(FreeSp/1048576, MaxSizeDig-1, 1) + 'M';
            for J := 1 to Length (SizeStr) do
              if SizeStr[J] <> ' ' then Break;
            if J < K then K := J;
            if not Tabulated then DelLeft(SizeStr);
            FullS := FullS + ' ' + SizeStr;
            end;
          end;
        end;

  if Tabulated then
    for I := 1 to InfoCnt do
      if not (DrvStrArr[I].DT in [dtnLAN, dtnSubst]) then
        Delete(DrvStrArr[I].FullS, MaxFullSLength+1, K-1);

  for I := 1 to InfoCnt do
    with DrvStrArr[I] do
      if DT = dtnLAN then
        FullS := FullS + ' ~'+GetShare(Dr)+'~'
      else if DT = dtnSubst then
        FullS := FullS + ' ~'+GetSubst(Dr)+'~';

  for I := 1 to DrvCnt do
    with DrvStrArr[I] do
      begin
      if Length(FullS) > MaxL then
        MaxL := Length(FullS);
      Items := NewItem(FullS, '', kbNoKey, 1000+Byte(Dr),
          hcNoContext, Items);
      Inc(N);
      end;

{$IF not HasDrives}
  TmpS := '';
  lGetDir(0, TmpS);
  C := Chr(64+Max(1, PlaceOf(TmpS)));
{$ELSE}
  if not (Default in ['A'..'Z']) and not ((Default = '+') and (Lnk <> nil))
  then
    C := GetCurDrive
  else
    C := Default;
{$ENDIF}
  Menu := NewMenu(Items);
  R := Desktop.GetExtent;
  {-$VIV start}
  X := X-(MaxL div 2);
  if  (X+MaxL+4) > R.B.X then
    X := R.B.X-MaxL-4;
  if  (X < 0) then
    X := 0;
  Y := Y-(N div 2)+1;
  if  (Y+N+2) > R.B.Y then
    Y := R.B.Y-N-2;
  if  (Y < 0) then
    Y := 0;
  R.A.X := X;
  R.A.Y := Y;
  R.B.X := R.A.X+MaxL+4;
  MaxRY := R.B.Y;
  R.B.Y := R.A.Y+N+2;
  if R.A.Y = 0 then
    begin
    Inc(R.A.Y);
    Inc(R.B.Y)
    end;
  if  (R.B.Y > MaxRY) then
    R.B.Y := MaxRY;
  {-$VIV end}
  P := TMenuBox.Create(R, Menu, nil); {-$VIV}
  if  (C = '+') then
    Items := Lnk
  else
    Items := P.FindItem(C);
  if Items <> nil then
    Menu^.Default := Items;
  P.HelpCtx := hcSelectDrive+Byte(IncludeTemp = True);

  N := Desktop.ExecView(P);
  P.Free;
  DisposeMenu(Menu);
  SelectDrive := '';
  if N > 1000 then
{$IF HasDrives}
    SelectDrive := Char(N-1000)+':';
{$ELSE}
    if N-1064 <= PlaceCnt then
      SelectDrive := Places[N-1064];
{$ENDIF}
  if N = 1200 then
    SelectDrive := cTEMP_;
  
  if N > 2000 then
    SelectDrive := '+'+Char(N-2000);
  
  if  (N >= cmQuickChange1) and (N <= cmQuickChange9)
  then
    SelectDrive := CnvString(DirsToChange[N-cmQuickChange1]);
  end { SelectDrive };

{-DataCompBoy-}
function NewFileRec(const LFN, Name: String; Size: TSize; Date, CreationDate, LastAccDate: LongInt; Attr: Word; AOwner: PString): PFileRec;
  var
    PR: PFileRec;
    T: TFileRec;
    D: DateTime;
    
    Name12: Str12;
    
    l: LongInt;
  begin
  
  T.FlName[False] := Utf8Prefix(Name, SizeOf(TShortName)-1);   { 12 bytes: not in the middle of a UTF-8 character }
  if Attr and Directory <> 0 then
    UpStr(T.FlName[False])
  else
    LowStr(T.FlName[False]);
  (*!  case Attr and (Hidden+SysFile) of                  {Pavel Anufrikov -> }
   Hidden  :        T.Name[9] := NameFormatChar[nfmHidden];
   SysFile :        T.Name[9] := NameFormatChar[nfmSystem];
   Hidden+SysFile : T.Name[9] := NameFormatChar[nfmHiddenSystem];
  end{case};                                         { <- Pavel Anufrikov}
!*)
  if Attr and SysFile <> 0 then
    T.FlName[False][1] := UpCase(T.FlName[False][1]);
  CopyShortString(LFN, T.FlName[True]);
  
  if (Attr and Directory <> 0) and (Size = 0) then
    T.Size := -1 {AK155 28-11-2005.
      Actually, it is not very good to change the size that was
      given in the call. But there are so many of these calls that inserting
      such analysis and -1 as size everywhere is hard.
      If it ever turns out that this spoils existing
      information about zero size, nothing bad will come of it:
      the total size is unaffected by 0, and recounting
      that zero, if needed, will be done quickly enough.
      }
  else
    T.Size := Size;
  T.PSize := Size;
  if Date = 0 then
    begin
    T.Yr := 1980;
    T.FDate := $1111;
    T.Second := 1;
    end
  else
    begin
    UnpackTime(Date, D);
    T.Yr := D.Year;
    with TDate4(T.FDate) do
      begin
      Month := D.Month;
      Day := D.Day;
      Hour := D.Hour;
      Minute := D.Min;
      end;
    T.Second := D.Sec;
    end;
  if CreationDate = 0 then
    begin
    T.YrCreat := 0;
    T.FDateCreat := $0000;
    T.SecondCreat := 0;
    end
  else
    begin
    UnpackTime(CreationDate, D);
    T.YrCreat := D.Year;
    with TDate4(T.FDateCreat) do
      begin
      Month := D.Month;
      Day := D.Day;
      Hour := D.Hour;
      Minute := D.Min;
      end;
    T.SecondCreat := D.Sec;
    end;
  if LastAccDate = 0 then
    begin
    T.YrLAcc := 0;
    T.FDateLAcc := $0000;
    T.SecondLAcc := 0;
    end
  else
    begin
    UnpackTime(LastAccDate, D);
    T.YrLAcc := D.Year;
    with TDate4(T.FDateLAcc) do
      begin
      Month := D.Month;
      Day := D.Day;
      Hour := D.Hour;
      Minute := D.Min;
      end;
    T.SecondLAcc := D.Sec;
    end;
  T.Attr := Attr and $7FFF;
  T.Selected := False;
  T.DIZ := nil;
  T.TType := GetFileType(T.FlName[True], T.Attr);
  T.Owner := AOwner;
  T.UsageCount := 1;
  {  l := TFileRecFixedSize+length(T.FlName[true]);}
  l := SizeOf(TFileRec);
  GetMem(PR, l);
  Move(T, PR^, l);
  NewFileRec := PR;
  end { NewFileRec };
{-DataCompBoy-}

function PackedDate(P: PFileRec): LongInt;
  var
    DT: DateTime;
    L: LongInt;
  begin
  with P^ do
    begin
    DT.Year := Yr;
    with TDate4(FDate) do
      begin
      DT.Month := Month;
      DT.Day := Day;
      DT.Hour := Hour;
      DT.Min := Minute;
      end;
    DT.Sec := Second;
    end;
  PackTime(DT, L);
  PackedDate := L;
  end;

function PackedCreationDate(P: PFileRec): LongInt;
  var
    DT: DateTime;
    L: LongInt;
  begin
  with P^ do
    begin
    DT.Year := YrCreat;
    with TDate4(FDateCreat) do
      begin
      DT.Month := Month;
      DT.Day := Day;
      DT.Hour := Hour;
      DT.Min := Minute;
      end;
    DT.Sec := SecondCreat;
    end;
  PackTime(DT, L);
  PackedCreationDate := L;
  end;

function PackedLastAccDate(P: PFileRec): LongInt;
  var
    DT: DateTime;
    L: LongInt;
  begin
  with P^ do
    begin
    DT.Year := YrLAcc;
    with TDate4(FDateLAcc) do
      begin
      DT.Month := Month;
      DT.Day := Day;
      DT.Hour := Hour;
      DT.Min := Minute;
      end;
    DT.Sec := SecondLAcc;
    end;
  PackTime(DT, L);
  PackedLastAccDate := L;
  end;

{ File records are considered to refer to the same file
if the (long) name and path match. }
function SameFile(P1, P2: PFileRec): Boolean;
  begin
  Result := False;
  if (P1 = nil) or (P2 = nil) then
    Exit;
  if P1^.FlName[True] <> P2^.FlName[True] then
    Exit;
  { Owner may be nil (e.g. UpFile ".." before CurDir is bound). Do not
    dereference until both sides are non-nil — otherwise Directory Branch
    DelDuplicates AVs when comparing a nil-Owner record to a real path. }
  if P1^.Owner <> P2^.Owner then
    begin
    if (P1^.Owner = nil) or (P2^.Owner = nil) then
      Exit;
    if P1^.Owner^ <> P2^.Owner^ then
      Exit;
    end;
  Result := True;
  end;

procedure TFilesHash.Hash(Item: Pointer);
  var
    i: Integer;
    R: Longint;
  begin
  R := 0;
  with PFileRec(Item)^ do
    begin
    for i := 1 to Length(FlName[True]) do
      R := R*3 + Byte(FlName[True][i]);
    if Owner <> nil then
      for i := 1 to Length(Owner^) do
        R := R*3 + Byte(PString(Owner)^[i]);
    end;
  R := (R * $33C6EF37) and $7FFFFFF;
  hf := R mod Count;
  RehashStep := ((R div Count) mod Count) or 1;
  end;

function TFilesHash.Equal(Item1, Item2: Pointer): Boolean;
  begin
  Result := SameFile(Item1, Item2);
  end;

procedure TFilesCollection.DelDuplicates(var TotalInfo: TSize);
  var
    i, j: Integer;
    H: TFilesHash;
    S: TSize;
    Dupe: array of Boolean;

  begin
  if not Duplicates then
    Exit;
  { The dupes are first all found, with the items where they are (the hash keeps the indexes of the items), then deleted.
    Dupes are possible after a search in a list panel with subdirectory traversal. }
  SetLength(Dupe, Count);
  if SortMode = psmUnsorted then
    begin
    H := TFilesHash.Create(Self);
    if H.HT = nil then
      begin
      H.Free;           { out of memory: the dupes stay }
      Exit;
      end;
    for i := 0 to Count-1 do
      Dupe[i] := not H.AddItem(i);
    H.Free;
    end
  else
    for i := 1 to Count-1 do
      Dupe[i] := SameFile(Items^[i-1], Items^[i]); { sorted: dupes are adjacent }
  TotalInfo := 0;
  j := 0;
  for i := 0 to Count-1 do
    if Dupe[i] then
      DelFileRec(PFileRec(Items^[i]))
    else
      begin
      Items^[j] := Items^[i];
      S := PFileRec(Items^[j])^.Size;
      if S > 0 then {for a directory with unknown size Size=-1}
        TotalInfo := TotalInfo + S;
      Inc(j);
      end;
  Count := j;
  Duplicates := False;
  { do not free the excess memory in Items^ }
  end;

end.
