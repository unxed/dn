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
unit fmttgz; {TGZ & TAZ & TAR.GZ}

interface

uses
  Archiver, Basics, strutil, Defines, objutil, Streams, Dos, timeutil,
  fileutil
  ;

type
  TTGZArchive = class;
  PTGZArchive = TTGZArchive;
  TTGZArchive = class(TARJArchive)
    TarData: TMemoryStream;
    TarMode: Boolean;
    GzDone: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure GetFile; override;
    function GetID: Byte; override;
    function GetSign: TStr4; override;
    end;

implementation

uses
  osdep
{$IFDEF UNIX}
  , zstream
{$ENDIF}
  ;

const
  BlkSize = 512;
  MaxTName = 100;
  Txt_Word = 8;
  Txt_Long = 12;

type
  TARHdr = record
    FName: array[1..MaxTName] of Char;
    Mode: array[1..Txt_Word] of Char;
    uid: array[1..Txt_Word] of Char;
    gid: array[1..Txt_Word] of Char;
    Size: array[1..Txt_Long] of Char;
    mtime: array[1..Txt_Long] of Char;
    chksum: array[1..Txt_Word] of Char;
    filetype: Char;
    linkname: array[1..MaxTName] of Char;
    end;

function IsCompoundTarGz(const N: String): Boolean;
  var
    U: String;
  begin
  U := UpStrg(N);
  Result := (GetExt(U) = '.TGZ') or (GetExt(U) = '.TAZ') or
    (Length(U) >= 7) and (Copy(U, Length(U) - 6, 7) = '.TAR.GZ');
  end;

{ ----------------------------- TAR ------------------------------------}

constructor TTGZArchive.Create;
  var
    Sign: TStr5;
    q: String;
  begin
  inherited Create;
  TarData := nil;
  TarMode := False;
  GzDone := False;
  Sign := GetSign;
  SetLength(Sign, Length(Sign)-1);
  Sign := Sign+#0;
  FreeStr := SourceDir+DNARC;

{$IFDEF UNIX}
  { GNU tar: list/extract compressed archives; OS/2 UNTGZOS2 is not on Linux. }
  Packer := NewStr(GetVal(@Sign[1], @FreeStr[1], PPacker, 'tar'));
  UnPacker := NewStr(GetVal(@Sign[1], @FreeStr[1], PUnPacker, 'tar'));
  Extract := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtract, 'xzf'));
  ExtractWP := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtractWP, 'xzf'));
  Add := NewStr(GetVal(@Sign[1], @FreeStr[1], PAdd, 'czf'));
  Move := NewStr(GetVal(@Sign[1], @FreeStr[1], PMove, ''));
  Delete := NewStr(GetVal(@Sign[1], @FreeStr[1], PDelete, ''));
  Garble := NewStr(GetVal(@Sign[1], @FreeStr[1], PGarble, ''));
  Test := NewStr(GetVal(@Sign[1], @FreeStr[1], PTest, 'tzf'));
{$ELSE}
  Packer := NewStr(GetVal(@Sign[1], @FreeStr[1], PPacker, ''));
  UnPacker := NewStr(GetVal(@Sign[1], @FreeStr[1], PUnPacker, 'UNTGZOS2'));
  Extract := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtract, '-d'));
  ExtractWP := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtractWP, '-d'));
  Add := NewStr(GetVal(@Sign[1], @FreeStr[1], PAdd, ''));
  Move := NewStr(GetVal(@Sign[1], @FreeStr[1], PMove, ''));
  Delete := NewStr(GetVal(@Sign[1], @FreeStr[1], PDelete, ''));
  Garble := NewStr(GetVal(@Sign[1], @FreeStr[1], PGarble, ''));
  Test := NewStr(GetVal(@Sign[1], @FreeStr[1], PTest, '-t'));
{$ENDIF}
  IncludePaths := NewStr(GetVal(@Sign[1], @FreeStr[1], PIncludePaths, ''));
  ExcludePaths := NewStr(GetVal(@Sign[1], @FreeStr[1], PExcludePaths, ''));
  ForceMode := NewStr(GetVal(@Sign[1], @FreeStr[1], PForceMode, ''));
  RecoveryRec := NewStr(GetVal(@Sign[1], @FreeStr[1], PRecoveryRec, ''));
  SelfExtract := NewStr(GetVal(@Sign[1], @FreeStr[1], PSelfExtract, ''));
  Solid := NewStr(GetVal(@Sign[1], @FreeStr[1], PSolid, ''));
  RecurseSubDirs := NewStr(GetVal(@Sign[1], @FreeStr[1], PRecurseSubDirs,
         ''));
  StoreCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PStoreCompression, ''));
  FastestCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PFastestCompression, ''));
  FastCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PFastCompression, ''));
  NormalCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PNormalCompression, ''));
  GoodCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PGoodCompression, ''));
  UltraCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PUltraCompression, ''));
  ComprListChar := NewStr(GetVal(@Sign[1], @FreeStr[1], PComprListChar,
         ' '));
  ExtrListChar := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtrListChar,
       ' '));

  q := GetVal(@Sign[1], @FreeStr[1], PAllVersion, '0');
  AllVersion := q <> '0';
  q := GetVal(@Sign[1], @FreeStr[1], PPutDirs, '0');
  PutDirs := q <> '0';

  q := GetVal(@Sign[1], @FreeStr[1], PSwapWhenExec, '0');
  SwapWhenExec := q <> '0';

  q := GetVal(@Sign[1], @FreeStr[1], PUseLFN, '1');
  UseLFN := q <> '0';

  end { TTGZArchive.Init };

destructor TTGZArchive.Destroy;
  begin
  TarData.Free;
  TarData := nil;
  inherited Destroy;
  end;

function TTGZArchive.GetID: Byte;
  begin
  GetID := arcTGZ;
  end;

function TTGZArchive.GetSign: TStr4;
  begin
  GetSign := sigTGZ;
  end;

{$IFDEF UNIX}
procedure ExpandGzipToTarData(var TarData: TMemoryStream);
  var
    GZ: TGZFileStream;
    Buf: array[0..8191] of Byte;
    N: LongInt;
  begin
  if TarData <> nil then
    Exit;
  TarData := TMemoryStream.Create(0, 8192);
  try
    GZ := TGZFileStream.Create(SysOsPath(ArcFileName), gzOpenRead);
    try
      repeat
        N := GZ.Read(Buf, SizeOf(Buf));
        if N > 0 then
          TarData.Write(Buf, N);
      until N = 0;
    finally
      GZ.Free;
    end;
    TarData.Seek(0);
  except
    TarData.Free;
    TarData := nil;
  end;
  end;

procedure GetTarMemberFromStream(S: TStream);
  var
    Buffer: array[0..BlkSize-1] of Char;
    Hdr: TARHdr absolute Buffer;
    DT: DateTime;
    W: AWord;
    NextPos: Int64;
  begin
  if S.GetPos >= S.GetSize then
    begin
    FileInfo.Last := 1;
    Exit;
    end;
  FillChar(Buffer, SizeOf(Buffer), 0);
  S.Read(Buffer, BlkSize);
  if S.Status <> stOK then
    begin
    FileInfo.Last := 2;
    Exit;
    end;
  FileInfo.Last := 0;
  if Hdr.filetype = '5' then
    FileInfo.Attr := Directory
  else
    FileInfo.Attr := 0;
  FileInfo.FName := Hdr.FName+#0;
  SetLength(FileInfo.FName, PosChar(#0, FileInfo.FName)-1);
  if FileInfo.FName = '' then
    begin
    FileInfo.Last := 1;
    Exit;
    end;
  FileInfo.USize := FromOct(Hdr.Size);
  FileInfo.PSize := FileInfo.USize;
  GetUNIXDate(i32(FromOct(Hdr.mtime)), DT.Year, DT.Month, DT.Day, DT.Hour,
     DT.Min, DT.Sec);
  PackTime(DT, FileInfo.Date);
  W := Word(CompRec(FileInfo.PSize).Lo) and (BlkSize-1);
  NextPos := S.GetPos + FileInfo.PSize - W + BlkSize*Byte(W <> 0);
  S.Seek(NextPos);
  end;
{$ENDIF}

procedure TTGZArchive.GetFile;
  type
    GZipHdr = record
      Id: AWord;
      Flag: AWord;
      Time: LongInt;
      end;
  var
    P: GZipHdr;
    DT: DateTime;
    C: Char;
  begin
{$IFDEF UNIX}
  if IsCompoundTarGz(ArcFileName) then
    begin
    TarMode := True;
    if TarData = nil then
      ExpandGzipToTarData(TarData);
    if TarData = nil then
      begin
      FileInfo.Last := 2;
      Exit;
      end;
    GetTarMemberFromStream(TarData);
    Exit;
    end;
{$ENDIF}

  { Plain .gz (and non-Unix builds): one synthetic member from the gzip header. }
  if GzDone then
    begin
    FileInfo.Last := 1;
    Exit;
    end;
  ArcFile.Read(P, SizeOf(P));
  if ArcFile.Eof then
    begin
    FileInfo.Last := 1;
    Exit;
    end;
  GetUNIXDate(P.Time, DT.Year, DT.Month, DT.Day, DT.Hour, DT.Min, DT.Sec);
  PackTime(DT, FileInfo.Date);
  FileInfo.FName := '';
  if  (P.Flag and $800 = 0) or (P.Id = $9d1f)
  then
    if (UpCase(ArcFileName[Length(ArcFileName)]) = 'Z')
      then
      FileInfo.FName := GetSName(ArcFileName)
    else
      FileInfo.FName := GetName(ArcFileName)
  else
    begin
    if P.Flag and $400 = 0 then
      P.Time := 10 {skip 10 bytes}
    else
      begin
      ArcFile.Read(P.Time, SizeOf(P.Time));
      P.Time := P.Time shr 16+12;
      end;
    ArcFile.Seek(ArcPos+P.Time);
    repeat
      ArcFile.Read(C, 1);
      if C <> #0 then
        FileInfo.FName := FileInfo.FName+C
      else
        Break;
    until ArcFile.Status <> stOK;
    end;
  FileInfo.PSize := ArcFile.GetSize;
  ArcFile.Seek(CompToFSize(FileInfo.PSize-4));
  ArcFile.Read(FileInfo.USize, SizeOf(FileInfo.USize));
  FileInfo.Attr := 0;
  FileInfo.Last := 0;
  GzDone := True;
  end { TTGZArchive.GetFile };

end.
