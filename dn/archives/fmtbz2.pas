{/////////////////////////////////////////////////////////////////////////
//
//  Dos Navigator Open Source
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
//////////////////////////////////////////////////////////////////////////
//
//  2007.06.15
//  BZip2 reader for Dos Navigator
//  Initial version by Max Piwamoto
//
//////////////////////////////////////////////////////////////////////////}
{$I STDEFINE.INC}
unit fmtbz2; {bzip2}

interface

uses
  Archiver, Basics, strutil, Defines, objutil, Streams, Dos, timeutil,
  fileutil
  ;

type
  TBZ2Archive = class;
  PBZ2Archive = TBZ2Archive;
  TBZ2Archive = class(TARJArchive)
    TarData: Streams.TMemoryStream;
    TarMode: Boolean;
    BzDone: Boolean;
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
  , Classes, bzip2stream
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

function IsCompoundTarBz2(const N: String): Boolean;
  var
    U: String;
  begin
  U := UpStrg(N);
  Result := (GetExt(U) = '.TBZ') or (GetExt(U) = '.TBZ2') or
    (Length(U) >= 8) and (Copy(U, Length(U) - 7, 8) = '.TAR.BZ2');
  end;

{ ----------------------------- BZIP2 ------------------------------------ }

constructor TBZ2Archive.Create;
  var
    Sign: TStr5;
    q: String;
  begin
  inherited Create;
  TarData := nil;
  TarMode := False;
  BzDone := False;
  Sign := GetSign;
  SetLength(Sign, Length(Sign)-1);
  Sign := Sign+#0;
  FreeStr := SourceDir+DNARC;

{$IFDEF UNIX}
  if IsCompoundTarBz2(ArcFileName) then
    begin
    { GNU tar lists/extracts .tar.bz2; plain bzip2 only yields a .tar stem. }
    Packer := NewStr(GetVal(@Sign[1], @FreeStr[1], PPacker, 'tar'));
    UnPacker := NewStr(GetVal(@Sign[1], @FreeStr[1], PUnPacker, 'tar'));
    Extract := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtract, 'xjf'));
    ExtractWP := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtractWP, 'xjf'));
    Add := NewStr(GetVal(@Sign[1], @FreeStr[1], PAdd, 'cjf'));
    Move := NewStr(GetVal(@Sign[1], @FreeStr[1], PMove, ''));
    Delete := NewStr(GetVal(@Sign[1], @FreeStr[1], PDelete, ''));
    Garble := NewStr(GetVal(@Sign[1], @FreeStr[1], PGarble, ''));
    Test := NewStr(GetVal(@Sign[1], @FreeStr[1], PTest, 'tjf'));
    end
  else
{$ENDIF}
    begin
    Packer := NewStr(GetVal(@Sign[1], @FreeStr[1], PPacker, 'bzip2'));
    UnPacker := NewStr(GetVal(@Sign[1], @FreeStr[1], PUnPacker, 'bzip2'));
    Extract := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtract, '-dk'));
    ExtractWP := NewStr(GetVal(@Sign[1], @FreeStr[1], PExtractWP, '-dk'));
    Add := NewStr(GetVal(@Sign[1], @FreeStr[1], PAdd, '-k'));
    Move := NewStr(GetVal(@Sign[1], @FreeStr[1], PMove, ''));
    Delete := NewStr(GetVal(@Sign[1], @FreeStr[1], PDelete, ''));
    Garble := NewStr(GetVal(@Sign[1], @FreeStr[1], PGarble, ''));
    Test := NewStr(GetVal(@Sign[1], @FreeStr[1], PTest, '-t'));
    end;
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
         PFastestCompression, '-1'));
  FastCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PFastCompression, '-2'));
  NormalCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PNormalCompression, ''));
  GoodCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PGoodCompression, ''));
  UltraCompression := NewStr(GetVal(@Sign[1], @FreeStr[1],
         PUltraCompression, '-9'));
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

  end { TBZ2Archive.Create };

destructor TBZ2Archive.Destroy;
  begin
  TarData.Free;
  TarData := nil;
  inherited Destroy;
  end;

function TBZ2Archive.GetID: Byte;
  begin
  GetID := arcBZ2;
  end;

function TBZ2Archive.GetSign: TStr4;
  begin
  GetSign := sigBZ2;
  end;

{$IFDEF UNIX}
procedure ExpandBzipToTarData(var TarData: Streams.TMemoryStream);
  var
    Raw: Classes.TMemoryStream;
    BZ: TDecompressBzip2Stream;
    Buf: array[0..8191] of Byte;
    N: LongInt;
    Saved: Int64;
  begin
  if TarData <> nil then
    Exit;
  TarData := Streams.TMemoryStream.Create(0, 8192);
  Raw := Classes.TMemoryStream.Create;
  try
    { ArcFile is already open on the archive; copy bytes then bunzip in memory. }
    Saved := ArcFile.GetPos;
    ArcFile.Seek(ArcPos);
    Raw.Size := ArcFile.GetSize - ArcPos;
    if Raw.Size > 0 then
      ArcFile.Read(Raw.Memory^, Raw.Size);
    ArcFile.Seek(Saved);
    Raw.Position := 0;
    BZ := TDecompressBzip2Stream.Create(Raw);
    try
      repeat
        N := BZ.Read(Buf, SizeOf(Buf));
        if N > 0 then
          TarData.Write(Buf, N);
      until N = 0;
    finally
      BZ.Free;
    end;
    TarData.Seek(0);
  except
    TarData.Free;
    TarData := nil;
  end;
  Raw.Free;
  end;

procedure GetTarMemberFromStream(S: Streams.TStream);
  var
    Buffer: array[0..BlkSize-1] of Char;
    Hdr: TARHdr absolute Buffer;
    DT: DateTime;
    W: AWord;
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
  S.Seek(CompToFSize(S.GetPos + FileInfo.PSize - W + BlkSize*Byte(W <> 0)));
  end;
{$ENDIF}

procedure TBZ2Archive.GetFile;
  var
    S: String;
  begin
{$IFDEF UNIX}
  if IsCompoundTarBz2(ArcFileName) then
    begin
    TarMode := True;
    if TarData = nil then
      ExpandBzipToTarData(TarData);
    if TarData = nil then
      begin
      FileInfo.Last := 2;
      Exit;
      end;
    GetTarMemberFromStream(TarData);
    Exit;
    end;
{$ENDIF}

  if BzDone or (ArcFile.GetPos = ArcFile.GetSize) then
    begin
    FileInfo.Last := 1;
    Exit;
    end;
  S := UpStrg(GetExt(ArcFileName));
  FileInfo.FName := GetSName(ArcFileName);
  if (S = '.TBZ') or (S = '.TBZ2') then
    FileInfo.FName := FileInfo.FName + '.TAR';
  FileInfo.PSize := ArcFile.GetSize;
  FileInfo.USize := 0;
  FileInfo.Date := 0;
  FileInfo.Attr := 0;
  FileInfo.Last := 0;
  ArcFile.Seek(ArcFile.GetSize);
  BzDone := True;
  end { TBZ2Archive.GetFile };

end.
