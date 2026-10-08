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
{DataCompBoy = Anton Fedorov, 2:5000/111.33@fidonet}
{JO = Jaroslaw Osadtchiy, 2:5030/1082.53@fidonet}
{AK155 = Alexey Korop, 2:461/155@fidonet}
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}
{Interface part from LFN.PAS}
{$AlignRec-}

{Cat
   05/12/2001 - attempt to fight a Windows quirk: the current
   directory is remembered not for all drives, but only for the current drive, which leads to
   various minor annoyances; to fix this, on lChDir we save
   the path being set in an array, and on lGetDir we take it from there
}

unit LFN;

interface

uses
  osdep,
  Dos, Defines
  ;

type

  lAPIType = (lDOS, lWIN95);
  CompRec = record
             Lo, Hi: LongInt
            end;


  {Extended search structure to be used instead of SearchRec}
  lSearchRec = record
    SR: TOSSearchRec; {Basic field set}
    FullSize: TSize; {True file size}
    (*  LoCreationTime: Longint; {Time created (low-order byte)}
    HiCreationTime: Longint; {Time created (high-order byte)}
    LoLastAccessTime: Longint; {Time accessed (low-order byte)}
    HiLastAccessTime: Longint; {Time accessed (high-order byte)}
    LoLastModificationTime: Longint; {Time modified (low-order byte)}
    HiLastModificationTime: Longint; {Time modified (high-order byte)} *)
    FullName: String;
    {True file name or short name if LFNs not available}
    
    
    FileHandle: Word; {Search handle, undefined in lDOS mode}
    FindFirstMode : lAPIType;
    
    { Other fields will be added later }
    end;

  TNameZ = array[0..259] of Char;
  {The type for file names. (String is suitable for most purpuses)}

  lFile = record
    {Extended file record to be used instead of File}
    F: file;
    
    FullName       : TNameZ;
    AssignFileMode : lAPIType;
    
    { Other fields will be added later }
    end;

  lText = record
    {Extended text file record to be used instead of Text}
    T: Text;
    
    FullName       : TNameZ;
    AssignTextMode : lAPIType;
    
    { Other fields will be added later }
    end;


var
  lAPI       : lApiType = lWin95;


  {   Basic parameters   }
const

  
  ltMod = 0;    {Store time modified}
  ltAcc = 1;    {Store time accessed}
  ltCre = 2;    {Store time created}

  LFNTimes: Byte = ltMod; { What time info to store in lSearchRec.SR.Time? }

  faOpen = 1;
  faTruncate = 2;
  faCreate = $10;
  faRewrite = faTruncate + faCreate;

  faGetAttr = 0;
  faSetAttr = 1;
  
  MaxPathLen: Byte = 255; { Maximum name length for the present moment }

const
  IllegalChars = '<>|:';
  { Characters invalid for short names }
  IllegalCharSet = ['<', '>', '|', ':'];
  { Characters invalid for short names }

  { File searching routines. lFindClose must be called /in all cases/ }
procedure lFindFirst(const Path: String; Attr: Word; var R: lSearchRec);
procedure lFindNext(var R: lSearchRec);
procedure lFindClose(var R: lSearchRec);


function lfGetShortFileName(const Name: String): String;


function SysFileCreate(FileName: PChar; Mode,Attr: Longint; var Handle: Longint): Longint;
function SysFileOpen(FileName: PChar; Mode: Longint; var Handle: Longint): Longint;
function lfGetLongFileName(const Name: String): String;
procedure lWIN95FindFirst(const Path: String; Attr: Word; var R: lSearchRec);


{ Name correction routine }
procedure lTrueName(const Name: String; var S: String);
procedure NameToNameZ(const Name: String; var NameZ: TNameZ);

function GetShareEnd(const S: String): Integer;
{` AK155 22-11-2003 Find the end of the share in the path. 0 if this is not a UNC path `}

function GetRootStart(const Path: String): Integer;
{` Find the start of the root; e.g. for C:\DIR the result is 3,
for \\Server\Share\Dir the result is 15. For paths like '' or C: the result
is length plus 1. `}

{ Basic file operation routines. To use IO functions from standard units,
              specify lFile.F or lText.T }

procedure lAssignFile(var F: lFile; const Name: String);
procedure lAssignText(var T: lText; const Name: String);
procedure lResetFile(var F: lFile; RecSize: Word);
procedure lResetFileReadOnly(var F: lFile; RecSize: Word);
procedure lReWriteFile(var F: lFile; RecSize: Word);
procedure lResetText(var F: lText);
procedure lResetTextReadOnly(var F: lText);
procedure lRewriteText(var F: lText);
procedure lAppendText(var T: lText);
procedure lEraseFile(var F: lFile);

procedure lEraseText(var T: lText);

procedure lRenameFile(var F: lFile; const NewName: String);
procedure lRenameText(var T: lText; const NewName: String);
procedure lChangeFileName(const Name, NewName: String);
function lFileNameOf(var lF: lFile): String;
function lTextNameOf(var lT: lText): String;

{ File attributes manipulation }
procedure lGetFAttr(var F: lFile; var Attr: Word);
procedure lSetFAttr(var F: lFile; Attr: Word);
procedure lGetTAttr(var T: lText; var Attr: Word);
procedure lSetTAttr(var T: lText; Attr: Word);

{ Directory manipulation }
procedure lMkDir(const Path: String);
procedure lRmDir(const Path: String);
procedure lChDir(Path: String);
  {` If the given directory exists, switch to it, i.e.
  assign it to ActiveDir. The error code is actually formed in FindFirst,
  i.e. it is in DosError. For compatibility with standard
  ChDir it is also duplicated in InOutRes. `}
procedure lGetDir(D: Byte; var Path: String);

{ Name expansion and splitting }
function lFExpand(Path: String): String;
  {` expand Path relative to ActiveDir. If Path had
  '/', they become the separator of the host in the result.
  Dots . and .. are correctly removed; e.g. instead of C:\TEMP\$$$\..
  you get C:\TEMP. A trailing separator only at the root.`}
procedure lFSplit(const Path: String; var Dir, Name, ext: String);


const
  NoShortName: String[12] = #22#22#22#22#22#22#22#22'.'#22#22#22;
  {JO, AK155: why these #22 are needed:
  On Windows, FindFileFirst and FindFileNext API return two file
names: primary and alternate (short).
  Under NT an abnormal (from my point of view,
at least) situation is possible when for a file with a long (not fitting
8.3) name the alternate name is unavailable. That happens if
the file system does not support dual names at all (HPFS), or
if short-name generation is disabled (on NTFS and FAT32).
  Then in short-name display mode we would show for such files
arbitrarily truncated names in the panel that do not match
reality. So JO invented this placeholder for an
unavailable short name, since character #22 cannot
appear in a real file name. Showing in
short-name mode files that only have a long name this way is
more honest than with a truncated name under which the file is inaccessible.
}
  

{Cat: Windows remembers the current directory only for the current drive;
remembering other current directories has to be done by us}
var
  CurrentPaths: array[1..1+Byte('Z')-Byte('A')] of PathStr;
  ActiveDir: String; // always with a trailing separator
  CurrentRoot: String; // without a trailing separator; may be a share
  StartDir: String;

implementation

uses
  
  Strings, Commands {Cat}
  , strutil, fileutil, Math, TvPath, DnPath
   ,Startup ,realmode 
  , dirwatch
  ;
procedure lResetText(var F: lText);
  
  begin
  Reset(F.T)
  end;

procedure lAppendText(var T: lText);
  
  begin
  Append(T.T);
  end;


function StrPas_(S: array of Char): String;
  var
    ss: String;
    i: Word;
  begin
  ss := '';
  for i := Low(S) to High(S) do
    if  (i < 255) and (S[i] <> #0)
    then
      ss := ss+S[i]
    else
      Break;
  StrPas_ := ss;
  end;

procedure NameToNameZ(const Name: String; var NameZ: TNameZ);
  begin
  Move(Name[1], NameZ, Length(Name));
  NameZ[Length(Name)] := #0;
  end;

(*
 Offset  Size    Description
  00h    DWORD   file attributes
                 bits 0-6 standard DOS attributes
                 bit 8: temporary file
  04h    QWORD   file creation time
                 (number of 100ns intervals since 1/1/1601)
  0Ch    QWORD   last access time
  14h    QWORD   last modification time
  1Ch    DWORD   file size (high 32 bits)
  20h    DWORD   file size (low 32 bits)
  24h  8 BYTEs   reserved
  2Ch 260 BYTEs  ASCIZ full filename
 130h 14 BYTEs   ASCIZ short filename (for backward compatibility)
*)

function SetDosError(ErrCode: Integer): Integer;
  begin
  DosError := ErrCode;
  SetDosError := ErrCode;
  end;

{AK155}

function NotShortName(const S: String): Boolean;
  var
    i, l: Integer;
    iPoint: Integer;
  begin
  NotShortName := True;
  if S[1] = '.' then
    Exit;
  l := Length(S);
  if l > 12 then
    Exit;
  iPoint := 0;
  for i := 1 to l do
    begin
    if S[i] = '.' then
      begin
      if  (iPoint <> 0) or (i > 9) then
        Exit;
      iPoint := i;
      end
    else if S[i] in IllegalCharSet then
      Exit; {DataCompBoy}
    end;
  if  (iPoint = 0) and (l > 8) then
    Exit;
  if  (iPoint <> 0) and (l-iPoint > 3) then
    Exit;
  NotShortName := False;
  end { NotShortName };


procedure CorrectSearchRec(var R: lSearchRec);
  begin
  R.FullName := R.SR.Name;
  
  
  {JO: CorrectSearchRec is called only when Win32 LFN API is absent}
  R.SR.CreationTime := 0;
  R.SR.LastAccessTime := 0;
  {/JO}
  
  (*R.LoCreationTime:= R.SR.Time;
  R.HiCreationTime:= 0;
  R.LoLastAccessTime:= R.SR.Time;
  R.HiLastAccessTime:= 0;
  R.LoLastModificationTime:= R.SR.Time;
  R.HiLastModificationTime:= 0; *)
  R.FullSize := R.SR.Size;
  end;

{lfn functions for dpmi32}
type
  lFindDataRec = record
    LoAttr: SmallWord;
    HiAttr: SmallWord;
    LoCreationTime: Longint;
    HiCreationTime: Longint;
    LoLastAccessTime: Longint;
    HiLastAccessTime: Longint;
    LoLastModificationTime: Longint;
    HiLastModificationTime: Longint;
    HiSize: Longint;
    LoSize: Longint;
    Reserved: Array[0..7] of Byte;
    FullName: TNameZ;
    ShortName: Array[0..13] of Char;
  end;

procedure CheckColonAndSlash(const Name: String; var S: String);
var
  ColonPos: Integer;
begin
  ColonPos := Pos(':', S);
  if (ColonPos > 2) and HasDriveLetter(Name) then
  begin
    Delete(S, 1, ColonPos - 1);
    S := Name[1] + S;
  end;

  if not EndsWithSep(Name) then
    while EndsWithSep(S) do Dec(S[0])
  else if not EndsWithSep(S) and (Length(S) < 255) then
  begin
    Inc(S[0]);
    S[Length(S)] := DnSep;
  end;
end;

procedure FindDataToSearchRec(var FindData: lFindDataRec; var R: lSearchRec);
begin
  R.SR.Attr := FindData.LoAttr;
{ if LFNTimes = ltCre then R.SR.Time := FindData.LoCreationTime
   else if LFNTimes = ltAcc then R.SR.Time := FindData.LoLastAccessTime
    else} R.SR.Time := FindData.LoLastModificationTime;
{JO}
  R.SR.CreationTime := FindData.LoCreationTime;
  R.SR.LastAccessTime := FindData.LoLastAccessTime;
{/JO}
  R.SR.Name := StrPas(FindData.ShortName);
  R.FullName := StrPas(FindData.FullName);
  if R.SR.Name = '' then R.SR.Name := R.FullName;
  if R.FullName = '' then R.FullName := R.SR.Name;
  R.FullSize:= FindData.LoSize;
  if FindData.HiSize=0 then R.SR.Size := FindData.LoSize
  else
   begin
    R.SR.Size := MaxLongInt;
    CompRec(R.FullSize).Hi:=FindData.HiSize;
   end;
end;

(*
 INT 21h  AX=714E
 INT 21 - Windows95 - LONG FILENAME - FIND FIRST MATCHING FILE
         AX = 714Eh
         CL = allowable-attributes mask (bits 0 and 5 ignored)
         CH = required-attributes mask
         SI = date/time format
         DS:DX -> ASCIZ filespec (both "*" and "*.*" match any filename)
         ES:DI -> FindData record
 Return: CF clear if successful
             AX = filefind handle (needed to continue search)
             CX = Unicode conversion flags
         CF set on error
             AX = error code
                 7100h if function not supported
 Notes:  this function is only available when IFSMgr is running,
         not under bare MS-DOS 7
         the application should close the filefind handle
         with AX=71A1h as soon as it has completed its search
*)

var
  FDBuf: lFindDataRec;

procedure lWIN95FindFirst(const Path: String; Attr: Word; var R: lSearchRec);
var
  FindData: ^lFindDataRec;
  regs: real_mode_call_structure_typ;
begin
  FindData:=@FDBuf;
  NameToNameZ(Path, FindData^.FullName);
  MemPut(segdossyslow32, FindData^.FullName, SizeOf(FindData^.FullName));
  init_register(regs);
  with regs do
   begin
    ax_:= $714E;
    cx_:= Attr;
    si_:= 1;
    ds_:= segdossyslow16;
    dx_:= $2c;
    es_:= segdossyslow16;
    di_:= 0;
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0 then
     begin
      R.FileHandle := $FFFF;
      DosError := ax_;
    end
    else
    begin
      R.FileHandle := ax_;
      MemGet(segdossyslow32, FindData^, SizeOf(lFindDataRec));
      FindDataToSearchRec(FindData^, R);
      DosError := 0;
    end;
  end;
end;

(*
 INT 21h  AX=714F
 INT 21 - Windows95 - LONG FILENAME - FIND NEXT MATCHING FILE
         AX = 714Fh
         BX = filefind handle (from AX=714Eh)
         SI = date/time format
         ES:DI -> buffer for FindData record
 Return: CF clear if successful
             CX = Unicode conversion flags
         CF set on error
             AX = error code
                 7100h if function not supported
 Note:   this function is only available when IFSMgr is running,
         not under bare MS-DOS 7

*)

procedure lWIN95FindNext(var R: lSearchRec);
var
  FindData: ^lFindDataRec;
  regs: real_mode_call_structure_typ;
begin
  FindData:=@FDBuf;
  init_register(regs);
  with regs do
   begin
    ax_:= $714F;
    bx_:= R.FileHandle;
    si_:= 1;
    es_:= segdossyslow16;
    di_:= 0;
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0 then DosError := ax_
    else
    begin
      MemGet(segdossyslow32, FindData^, SizeOf(lFindDataRec));
      FindDataToSearchRec(FindData^, R);
      DosError := 0;
    end;
  end;
end;

(*
 INT 21h  AX=71A1
 INT 21 - Windows95 - LONG FILENAME - "FindClose" -
          TERMINATE DIRECTORY SEARCH
         AX = 71A1h
         BX = filefind handle (from AX=714Eh)
 Return: CF clear if successful
         CF set on error
            AX = error code
                 7100h if function not supported
 Notes:  this function must be called after starting a search
         with AX=714Eh, to indicate that the search handle
         returned by that function will no longer be used
         this function is only available when IFSMgr is running,
         not under bare MS-DOS 7
*)

procedure lWIN95FindClose(var R: lSearchRec);
var
  regs: real_mode_call_structure_typ;
begin
  init_register(regs);
  if R.FileHandle <> $FFFF then with regs do
  begin
    ax_:= $71A1;
    bx_:= R.FileHandle;
    intr_realmode(regs,$21);
  end;
end;

procedure lWIN95GetFileNameFunc(const Name: String; var S: String; AFunction: Byte);
var
  NameZ, GetNameZ: TNameZ;
  regs: real_mode_call_structure_typ;
begin
  NameToNameZ(Name, NameZ);
  init_register(regs);
  with regs do
  begin
    ax_ := $7160;
    cl_ := AFunction;
    ch_ := $80;
    ds_ := segdossyslow16;
    si_ := 0;
    es_ := segdossyslow16;
    di_ := SizeOf(TNameZ);
    MemPut(segdossyslow32, NameZ, SizeOf(TNameZ));
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0 then S := Name
    else
    begin
      MemGet(segdossyslow32+SizeOf(TNameZ), GetNameZ, SizeOf(TNameZ));
      S := StrPas(GetNameZ);
      CheckColonAndSlash(Name, S);
    end;
  end;
end;

procedure WIN95TrueName(const Name: String; var S: String);
var
  NameZ, GetNameZ: TNameZ;
  regs: real_mode_call_structure_typ;
begin
  NameToNameZ(Name, NameZ);
  init_register(regs);
  with Regs do
  begin
    ax_ := $7160;
    cl_ := 0;
    ch_ := $00;
    ds_ := segdossyslow16;
    si_ := 0;
    es_ := segdossyslow16;
    di_ := SizeOf(TNameZ);
    MemPut(segdossyslow32, NameZ, SizeOf(TNameZ));
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0 then S := Name
    else
    begin
      MemGet(segdossyslow32+SizeOf(TNameZ), GetNameZ, SizeOf(TNameZ));
      S := StrPas(GetNameZ);
      CheckColonAndSlash(Name, S);
    end;
  end;
end;

function SysFileCreate(FileName: PChar; Mode,Attr: Longint; var Handle: Longint): Longint;
var
  regs     : real_mode_call_structure_typ;
  FullName : TNameZ;
begin
 FillChar(FullName, SizeOf(FullName), #0);
 NameToNameZ(StrPas(FileName), FullName);
 init_register(regs);
 with regs do
  begin
   if lAPI=lDOS then
    begin
     ah_ := $3C;
     al_ := Mode;
     bx_ := 0;
     cx_ := Attr;
     ds_ := segdossyslow16;
    end else
    begin
     ax_ := $716C;
     bx_ := Mode;
     cx_ := Attr;
     dx_ := $12;
     ds_ := segdossyslow16;
     si_ := 0;
     di_ := 0;
    end;
   MemPut(segdossyslow32, FullName, SizeOf(FullName));
   flags_:=fCarry;
   intr_realmode(regs, $21);
   if flags_ and fCarry <> 0
     then begin
           Handle := 0;
           SysFileCreate := ax_;
          end
     else begin
           SysFileCreate := 0;
           Handle := ax_;
          end;
  end;
end;

function SysFileOpen(FileName: PChar; Mode: Longint; var Handle: Longint): Longint;
var
  regs     : real_mode_call_structure_typ;
  FullName : TNameZ;
begin
 FillChar(FullName, SizeOf(FullName), #0);
 NameToNameZ(StrPas(FileName), FullName);
 init_register(regs);
 with regs do
  begin
   If lapi=ldos then
    begin
     ah_ := $3D;
     al_ := Mode;
     bx_ := 0;
     cx_ := 0;
     ds_ := segdossyslow16;
    end else
    begin
     ax_ := $716C;
     bx_ := Mode;
     cx_ := 0;
     dx_ := 1;
     ds_ := segdossyslow16;
     si_ := 0;
     di_ := 0;
    end;
   MemPut(segdossyslow32, FullName, SizeOf(FullName));
   flags_ := fCarry;
   intr_realmode(regs, $21);
   if flags_ and fCarry <> 0
     then begin
           Handle := 0;
           SysFileOpen := ax_;
          end
     else begin
           SysFileOpen := 0;
           Handle := ax_;
          end;
  end;
end;

procedure lWIN95ChDir(const Path: string);
var
  regs: real_mode_call_structure_typ;
  C: Char;
  NameZ: TNameZ;
begin
  NameToNameZ(Path, NameZ);
  MemPut(segdossyslow32, NameZ, SizeOf(TNameZ));
  init_register(regs);
  with regs do
  begin
    C := Upcase(NameZ[0]);
    if (C in ['A'..'Z']) and (NameZ[1] = ':') then
    begin
      ah_ := $0E;
      dl_ := Byte(C) - $41;
      intr_realmode(regs,$21);
    end;

    ax_ := $713B;
    ds_ := segdossyslow16;
    dx_ := 0;
    flags_:=fCarry;
    intr_realmode(regs, $21);

    if (flags_ and fCarry <> 0)
    then InOutRes := ax_
    else InOutRes := 0;
  end;
end;

procedure lWIN95GetDir(D: Byte; var Path: string);
var
  regs: real_mode_call_structure_typ;
  NameZ: TNameZ;
begin
  init_register(regs);
  with regs do
  begin
    ax_ := $7147;
    dl_ := D;
    ds_ := segdossyslow16;
    si_ := 0;
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0 then NameZ[0] := #0
    else
     MemGet(segdossyslow32, NameZ, SizeOf(TNameZ));
    Path := DriveRoot(Char(D + $40)) + StrPas(NameZ);
  end;
end;

procedure lWIN95OpenFile(var F: lFile; RecSize: Word; Action: Byte; Attr:Word);
var
  regs: real_mode_call_structure_typ;
begin
  init_register(regs);
  if FileRec(F.F).Mode <> fmClosed then Close(F.F);
  InOutRes := 0;

  if F.FullName[0] = #0 then
  begin
    FileRec(F.F).Mode := fmInOut;
    FileRec(F.F).RecSize := RecSize;
  end
  else with regs do
  begin
    ax_ := $716C;
    bx_ := FileMode;
    cx_ := Attr;
    dx_ := Action;
    ds_ := segdossyslow16;
    si_ := 0;
    di_ := 0;
    MemPut(segdossyslow32, F.FullName, SizeOf(F.FullName));
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0 then InOutRes := ax_
    else
    begin
      FileRec(F.F).Mode := fmInOut;
      FileRec(F.F).Handle := ax_;
      FileRec(F.F).RecSize := RecSize;
    end;
  end;
end;

procedure lWIN95EraseFile(var F: lFile);
var
  regs: real_mode_call_structure_typ;
begin
  MemPut(segdossyslow32, F.FullName, SizeOf(F.FullName));
  init_register(regs);
  with regs do
  begin
    ax_ := $7141;
    ds_ := segdossyslow16;
    dx_ := 0;
    si_ := 0;
    flags_:=fCarry;
    intr_realmode(regs, $21);
    if flags_ and fCarry <> 0
    then InOutRes := ax_
    else InOutRes := 0;
  end;
end;

procedure lWIN95EraseText(var T: lText);
var
  regs: real_mode_call_structure_typ;
begin
  MemPut(segdossyslow32, T.FullName, SizeOf(T.FullName));
  init_register(regs);
  with regs do
  begin
    ax_ := $7141;
    ds_ := segdossyslow16;
    dx_ := 0;
    si_ := 0;
    flags_:=fCarry;
    intr_realmode(regs, $21);
    if flags_ and fCarry <> 0
    then InOutRes := ax_
    else InOutRes := 0;
  end;
end;

procedure lWIN95RenameFile(var F: lFile; const NewName: string);
var
  NameZ: TNameZ;
  regs: real_mode_call_structure_typ;
begin
  NameToNameZ(NewName, NameZ);
  MemPut(segdossyslow32, F.FullName, SizeOf(F.FullName));
  MemPut(segdossyslow32+SizeOf(F.FullName), NameZ, SizeOf(NameZ));
  init_register(regs);
  with Regs do
  begin
    ax_ := $7156;
    ds_ := segdossyslow16;
    dx_ := 0;
    es_ := segdossyslow16;
    di_ := SizeOf(NameZ);
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0
    then InOutRes := ax_
    else InOutRes := 0;
  end;
end;

procedure lWIN95RenameText(var T: lText; const NewName: shortstring);
var
  NameZ: TNameZ;
  regs: real_mode_call_structure_typ;
begin
  NameToNameZ(NewName, NameZ);
  MemPut(segdossyslow32, T.FullName, SizeOf(T.FullName));
  MemPut(segdossyslow32+SizeOf(T.FullName), NameZ, SizeOf(NameZ));
  init_register(regs);
  with Regs do
  begin
    ax_ := $7156;
    ds_ := segdossyslow16;
    dx_ := 0;
    es_ := segdossyslow16;
    di_ := SizeOf(NameZ);
    flags_:=fCarry;
    intr_realmode(regs, $21);
    if flags_ and fCarry <> 0
    then InOutRes := ax_
    else InOutRes := 0;
  end;
end;

procedure lWIN95FileAttrFunc(var F: lFile; var Attr: Word; Action: Byte);
var
  regs: real_mode_call_structure_typ;
begin
  MemPut(segdossyslow32, F.FullName, SizeOf(F.FullName));
  init_register(regs);
  with regs do
  begin
    ax_ := $7143;
    bl_ := Action;
    if Action = faSetAttr then cx_ := Attr;
    ds_ := segdossyslow16;
    dx_ := 0;
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0
    then DosError := ax_
    else
    begin
      if Action = faGetAttr then Attr := cx_;
      DosError := 0;
    end;
  end;
end;

procedure lWIN95TextAttrFunc(var T: lText; var Attr: Word; Action: Byte);
var
  regs: real_mode_call_structure_typ;
begin
  MemPut(segdossyslow32, T.FullName, SizeOf(T.FullName));
  init_register(regs);
  with Regs do
  begin
    ax_ := $7143;
    bl_ := Action;
    if Action = faSetAttr then cx_ := Attr;
    ds_ := segdossyslow16;
    dx_ := 0;
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0
    then DosError := ax_
    else
    begin
      if Action = faGetAttr then Attr := cx_;
      DosError := 0;
    end;
  end;
end;

procedure lWIN95DirFunc(const Path: shortstring; AFunction: Word);
var
  regs: real_mode_call_structure_typ;
  NameZ: TNameZ;
begin
  NameToNameZ(Path, NameZ);
  MemPut(segdossyslow32, NameZ, SizeOf(TNameZ));
  init_register(regs);
  with regs do
  begin
    ax_ := AFunction;
    ds_ := segdossyslow16;
    dx_ := 0;
    flags_:=fCarry;
    intr_realmode(regs,$21);
    if flags_ and fCarry <> 0
    then InOutRes := ax_
    else InOutRes := 0;
  end;
end;

procedure lEraseFile(var F: lFile);
  begin
  if F.AssignFileMode = lWIN95 then lWIN95EraseFile(F) else
  Erase(F.F);
  end;

procedure lEraseText(var T: lText);
  begin
  if T.AssignTextMode = lWIN95 then lWIN95EraseText(T) else
  Erase(T.T);
  end;

{*** lfn functions for dpmi32 ***}

procedure lFindFirst(const Path: String; Attr: Word; var R: lSearchRec);
  var
    PathBuf: array[0..SizeOf(PathStr)-1] of Char;
  begin
  R.FullName := '';

  if lAPI = lDOS then begin
  R.FindFirstMode := lDOS;

  SetDosError(SysFindFirst(StrPCopy(PathBuf, Path), Attr, R.SR, False));
  CorrectSearchRec(R);

  end else begin
            R.FindFirstMode := lWIN95;
            lWIN95FindFirst(Path, Attr, R);
           end;

  
  end;

procedure lFindNext(var R: lSearchRec);
  begin
  R.FullName := '';

  if R.FindFirstMode = lDOS then begin

  SetDosError(SysFindNext(R.SR, False));
  CorrectSearchRec(R);

  end else lWIN95FindNext(R);

  {JO: error 49 is reserved in the OS; we will use it for}
  {    catching duplicates on HPFS}
  
  end;

procedure lFindClose(var R: lSearchRec);
  var
    DEr: LongInt;
  begin
  DEr := DosError; {JO}
  
  if R.FindFirstMode = lWin95 then lWIN95FindClose(R) else
  
  SysFindClose(R.SR);
  DosError := DEr; {JO}
  end;



function lfGetShortFileName(const Name: String): String;
  begin
  if lApi = lDOS
  then Result := Name
  else lWIN95GetFileNameFunc(Name, Result, 1);
  end;

function lfGetLongFileName(const Name: String): String;
  begin
  if lApi = lDOS
  then Result := Name
  else lWIN95GetFileNameFunc(Name, Result, 2);
  end;


procedure lTrueName(const Name: String; var S: String);
  begin
  
  if lApi = lWin95 then
    WIN95TrueName(Name, S)
  else
  
  S := Name;
  end;

{AK155 22-11-2003 Find the end of the share in the path. 0 if this is not a UNC path
}
function GetShareEnd(const S: String): Integer;
  var
    SlashFound: Boolean;
  begin
  Result := 0;
  if not HasDrives or (Copy(S, 1, 2) <> '\\') then
    Exit;
  { look for a separator after the two leading ones, and then to the end or to the second one }
  Result := 3;
  SlashFound := False;
  while Result < Length(S) do
    begin
    if IsPathSep(S[Result+1]) then
      begin
      if SlashFound then
        Exit; // Success. Now Copy(S, 1, i) is '\\server\share'
      SlashFound := True;
      end;
    Inc(Result);
    end;
  if not SlashFound then
    Result := 0;
  { This path is wrong: '\\' at the start is there,
      but no separator afterwards. Should somehow set an error flag,
      but unclear how and for whom. }
  end { GetShareEnd };
{/AK155 22-11-2003}

function GetRootStart(const Path: String): Integer;
  begin
  if HasDrives then
    Result := Min(Length(Path)+1, Max(3, GetShareEnd(Path)+1))
  else
    Result := Min(Length(Path)+1, 1);
  end;

{AK155 22-11-2003 Reworked to account for UNC paths }
procedure lFSplit(const Path: String; var Dir, Name, ext: String);
  var
    DriveEnd: Integer;
    DotPos, SlashPos, B: Byte;
    D: String;
    N: String;
    E: String;
  begin
  begin
  Dir := '';
  Name := '';
  ext := '';
  DotPos := 0;
  SlashPos := 0;
  if HasDriveLetter(Path) then
    DriveEnd := 2
  else
    DriveEnd := GetShareEnd(Path);

  for B := Length(Path) downto DriveEnd+1 do
    begin
    if  (Path[B] = '.') and (DotPos = 0) then
      begin
      DotPos := B; {JO: names may consist of extension only}
      if SlashPos <> 0 then
        Break;
      end;
    if  IsPathSep(Path[B]) and (SlashPos = 0) then
      begin
      SlashPos := B;
      if DotPos <> 0 then
        Break;
      end;
    end;

  if DotPos+SlashPos = 0 then
    if DriveEnd <> 0 then
      Dir := Path
    else
      Name := Path
  else
    begin
    if DotPos > SlashPos then
      ext := Copy(Path, DotPos, MaxStringLength)
    else
      DotPos := 255;

    if SlashPos <> 0 then
      Dir := Copy(Path, 1, SlashPos);

    Name := Copy(Path, SlashPos+1, DotPos-SlashPos-1);
    end;
  end;
  end { lFSplit };

{ The name in FileRec/TextRec (wide characters in FPC) as a string. }
function NameOfRec(const Name: array of WideChar): String;
var
  I: Integer;
begin
  Result := '';
  I := 0;
  while (I <= High(Name)) and (Name[I] <> #0) and (Length(Result) < 255) do
  begin
    Result := Result + Char(Ord(Name[I]) and $FF);
    Inc(I);
  end;
end;

function lFileNameOf(var lF: lFile): String;
  begin

  if lF.AssignFileMode <> lDos then
    lFileNameOf := StrPas_(lF.FullName)
  else

  lFileNameOf := NameOfRec(FileRec(lF.F).Name);
  end;

function lTextNameOf(var lT: lText): String;
  begin
  lTextNameOf := NameOfRec(TextRec(lT.T).Name);
  end;

procedure lResetFileReadOnly(var F: lFile; RecSize: Word);
  var
    SaveMode: Byte;
  begin
  SaveMode := FileMode;
  FileMode := 64;
  lResetFile(F, RecSize);
  FileMode := SaveMode;
  end;

procedure lReWriteFile(var F: lFile; RecSize: Word);
  var
    OldMode: Byte;
  begin
  OldMode := FileMode;
  FileMode := FileMode and $FC or 2;

  if F.AssignFileMode = lWIN95 then lWIN95OpenFile(F, RecSize, faRewrite, 0) else

  Rewrite(F.F, RecSize);
  FileMode := OldMode;
  end;

procedure lResetTextReadOnly(var F: lText);
  var
    SaveMode: Byte;
  begin
  SaveMode := FileMode;
  FileMode := 64;
  lResetText(F);
  FileMode := SaveMode;
  end;

procedure lRewriteText(var F: lText);
  var
    OldMode: Byte;
  begin
  OldMode := FileMode;
  FileMode := FileMode and $FC or 2;
  Rewrite(F.T);
  FileMode := OldMode;
  end;

{ Inline functions, which temporary compiled as not inline, because VP are   }
{ crased on compiling 8(                                                     }

procedure lAssignFile(var F: lFile; const Name: String);
  var
    FName: String;
  begin
  FName := lFExpand(Name);
    { the panel's current directory is not the OS current directory, so
     the name must be expanded to a full path.}

  if lAPI = lDOS then
  begin
    F.AssignFileMode := lDOS;
    Assign(F.F, SysOsPath(FName));
  end else
  begin
    F.AssignFileMode := lWIN95;
    FileRec(F.F).Handle := 0;
    FileRec(F.F).Mode := fmClosed;
    NameToNameZ(FName, F.FullName);
  end;

  end;

procedure lAssignText(var T: lText; const Name: String);
  begin
  Assign(T.T, SysOsPath(lFExpand(Name)));
    { see comment on lAssignFile }
  end;

procedure lResetFile(var F: lFile; RecSize: Word);
  begin

  if F.AssignFileMode = lWIN95 then lWIN95OpenFile(F, RecSize, faOpen, 0) else

  Reset(F.F, RecSize);
  end;
procedure lRenameFile(var F: lFile; const NewName: String);
  begin

  if F.AssignFileMode = lWIN95 then lWIN95RenameFile(F, NewName) else

  Rename(F.F, SysOsPath(NewName));
  end;
procedure lRenameText(var T: lText; const NewName: String);
  begin

  if T.AssignTextMode = lWIN95 then lWIN95RenameText(T, NewName) else

  Rename(T.T, SysOsPath(NewName));
  end;
procedure lChangeFileName(const Name, NewName: String);
  var
    F: lFile;
  begin
  lAssignFile(F, Name);
  lRenameFile(F, NewName);
  end;
procedure lGetFAttr(var F: lFile; var Attr: Word);
  begin

  if F.AssignFileMode = lWIN95 then lWIN95FileAttrFunc(F, Attr, faGetAttr) else

  SysGetFAttr(F.F, Attr);
  end;
procedure lSetFAttr(var F: lFile; Attr: Word);
  begin

  if F.AssignFileMode = lWIN95 then lWIN95FileAttrFunc(F, Attr, faSetAttr) else

  SysSetFAttr(F.F, Attr);
  end;
procedure lGetTAttr(var T: lText; var Attr: Word);
  begin

  if T.AssignTextMode = lWIN95 then lWIN95TextAttrFunc(T, Attr, faGetAttr) else

  SysGetTAttr(T.T, Attr);
  end;
procedure lSetTAttr(var T: lText; Attr: Word);
  begin

  if T.AssignTextMode = lWIN95 then lWIN95TextAttrFunc(T, Attr, faSetAttr) else

  SysSetTAttr(T.T, Attr);
  end;
procedure lMkDir(const Path: String);
  begin

  if lAPI = lWin95
  then lWIN95DirFunc(Path, $7139) else

  MkDir(SysOsPath(Path));
  end;

{AK155: In DN/2, if a directory has the ReadOnly attribute, on FAT or HPFS
it deletes normally, but on FAT32 it does not. So just in case
ReadOnly must be cleared. }
procedure lRmDir(const Path: String);
  var
    f: lFile;
    Attr: Word;
  begin
  lAssignFile(f, Path);
  lGetFAttr(f, Attr);
  if Attr and ReadOnly <> 0 then
    lSetFAttr(f, Attr and not ReadOnly);
  if DosError <> 0 then
    begin
    InOutRes := DosError;
    Exit;
    end;
  NotifyDeleteWatcher(Path);

  if lAPI = lWin95
  then lWIN95DirFunc(Path, $713A) else

  RmDir(SysOsPath(Path));
  end;
{/AK155}


function lFExpand(Path: String): String;
  var
    Cur: String;
  begin
  Path := NormalizeSep(Path);
  if Path = '' then
    Path := '.';
  Cur := ActiveDir;
  if HasDriveLetter(Path) and not IsAbsPath(Path) then
    Cur := CurrentPaths[Byte(UpCase(Path[1]))-Byte('A')+1]; // relative path of the specified drive
  Result := TvPath.PathDelSep(TvPath.PathExpandIn(Path, Cur, TvPath.NativePathRules));
  end;

procedure lChDir(Path: String);
  var
    i: Longint;
  begin
  Path := lFExpand(Path);
  if PathExist(Path) then
    begin
    ActiveDir := Path;
    MakeSlash(ActiveDir);
    if HasDrives then
      begin
      i := GetShareEnd(Path);
      if i = 0 then
        i := 2;
      CurrentRoot := Copy(ActiveDir, 1, i);
      if  (InOutRes = 0) and (Length(Path) > 2) and HasDriveLetter(Path) then
        CurrentPaths[Byte(UpCase(Path[1]))-Byte('A')+1] := ActiveDir;
      end
    else
      CurrentRoot := '';
    end
  else
    InOutRes := DosError;
  end;

procedure lGetDir(D: Byte; var Path: String);
  label
    DelDlash;
  begin
  if not HasDrives then
    begin
    Path := ActiveDir;           { one tree: the drive number means nothing }
    goto DelDlash;
    end;
  if D = 0 then
    begin
    Path := ActiveDir;
    if IsPathSep(Path[1]) then
      goto DelDlash;
    D := Byte(UpCase(Path[1]))-Byte('A')+1;
    end;
  if CurrentPaths[D] = '' then
    Path := DriveRoot(Char(D+Byte('A')-1)) {GetDir(D, Path)}
  else
    Path := CurrentPaths[D];
DelDlash:
  MakeNoSlash(Path);
  end;
{/Cat}

procedure InitPath;
  var
    D: Integer;
    P: String[3];

    lsr: lSearchRec;

  begin

  //check LFN Api presence
  lsr.FindFirstMode := lWIN95;
  lWIN95FindFirst(ParamStr(0), AnyFileDir, lsr);
  lFindClose(lsr);
  if DosError <> 0 then
    lApi := lDOS;

  if HasDrives then
    begin
    P := DriveRoot('A');
    for D := 1 to High(CurrentPaths) do
      begin
      CurrentPaths[D] := P;
      Inc(P[1]);
      end;
    end;
  SysGetDirDos(0, StartDir);
  if HasDrives then
    StartDir[1] := Upcase(StartDir[1]);
     //piwamoto: w32 shortcut may have c:\ as directory
     //but DN needs C:\ for internal use
  lChDir(StartDir);
  end;

begin
InitPath;
end.
