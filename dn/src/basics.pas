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
{AK155 = Alexey Korop, 2:461/155@fidonet}
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}

unit basics;

interface

uses
  Dos,
  Strings,
  objutil, Lfn {DataCompBoy}
  , Defines, Streams
  ;


{$I Version.Inc}
{DataCompBoy: DO NOT INCLUDE Version.inc IN OTHER UNITS!}
{simple add in USES basics}


type
  TNameFormatMode = (nfmNull, nfmHidden, nfmSystem, nfmHiddenSystem);

const
  NameFormatChar: array[TNameFormatMode] of Char =
    ('.', #176, #177, #178);

(*  flnPreferName = 1;  { Non-tabulated extension;
        in this case always ExtSize = 0}
  flnHardExtArea = 2; { Tabulate extension
        in this case always ExtSize <> 0}
{  flnUseCutChar = 8; It is always needed }
*)
  flnPreserveExt = 1; { if in non-tabulated display the extension
    does not fit entirely, keep ExtSize characters for
    the extension field (including the truncation character)}
  flnAutoHideDot = 4; { Replace the dot before the extension with a space;
    only occurs when ExtSize <> 0}
  flnHighlight = 16;
  flnUpCase = 32;
  flnLowCase = 64;
  flnCapitalCase = 128;
  flnPadRight = 256;
  flnHandleTildes = 512;
  flnSelected = 1024;

const
  TextReaderBufSize = $1000;

type
  TTextReaderBuf = array[0..TextReaderBufSize-1] of Char;

  TTextReader = class;

  TTextReader = class
    Eof: Boolean;
    constructor Create(const FName: String); {DataCompBoy}
    function GetStr: String;
    function FileName: String; {DataCompBoy}
    destructor Destroy; override;
  private
    Handle: lFile; {DataCompBoy}
    BufSz: Integer;
    BufPos: Integer;
    Buf: TTextReaderBuf;
    Skip1: Boolean;
    end;

  { TColorIndexes }

  PColorIndex = ^TColorIndex;
  TColorIndex = record
    GroupIndex: Byte;
    ColorSize: Byte;
    ColorIndex: array[0..255] of Byte;
    end;

  { TCharImage = array [0..15] of Byte;}

type
  TCountryInfo = record
    {`Data for the country settings dialog }
    DateFmt: Word; {Radiobuttons}
      {`0:MM-DD-YY, 1: DD-MM-YY, 2: YY-MM-DD`}
    TimeFmt: Word; {Radiobuttons}
      {`0:12hour, 1: 24hour`}
    DateSep: String[1]; {Inputline}
    TimeSep: String[1]; {Inputline}
    ThouSep: String[1]; {Inputline}
    DecSep: String[1]; {Inputline}
    DecSign: String[1]; {Inputline}
    CurrencyFmt: Word; {Radiobuttons}
      {` 0:'$123.00', 1:'123.00$', 2:'$ 123.00', 3:'123.00 $' 4: 123$00 `}
    Currency: String[4]; {Inputline}
    KbdToggleLayout: String[79]; {Inputline}
    ABCSortTable: String[79]; {Inputline}
    WinCodeTable: String[79]; {Inputline}
    CodeTables: String[255]; {Inputline}
    end; {`}

var
  RK: Byte;

const

  ColorIndexes: PColorIndex = nil;

  opUnk = 0; { Unknown  }
  opDOS = 1; { DOS      }
  opOS2 = 2; { OS/2     }
  opWin = 4; { Wind0ze  }
  opDV = 8; { DesqView }
  opWNT = 16; { Win NT & Win y2k }
  opDPMI32 = 32; { DPMI32 }
  {Cat: something between DOS and Win32, hence separate from DOS}

  Abort: Boolean = False;

  opSys: Byte = opUnk;

  { useful under OS2 with WinAPI emulator: if (opSys and opWin)=opWin then ...}

procedure CheckOS;
{ Check for OS - For checking API please use error codes }
{ Automatically called while program started }

procedure ClrIO;

function MemOK: Boolean;
function GetMeMemoStream: TStream; {-$VOL}
function MemAdjust(L: LongInt): LongInt;
procedure FillWord(var B; Count, W: Word);
procedure LocateCursor(X, Y: Byte);
procedure TinySlice;
  {` Yield a time slice to the system. This procedure is called from
  the TGroup.Execute event loop, and thus in any situation
  where Desktop or a dialog is running. If someone runs their own
  loop (e.g. with GetEvent), they must call TinySlice themselves
  when needed. See TView.MouseEvent for an example of how this is done `}

function FormatLongName(Name: String; Size, ExtSize: Byte;
  {` Format a long name to total length Size, including
  tabulated extension - ExtSize.
    Individual Options bits set formatting features (constants
  named like flnHighlight.
    FormatMode defines the character shown instead of the dot.}
     Options: Word;
    FormatMode: TNameFormatMode): String; (* X-Man *)
    {`}
{ FormatLongName variables whose residual values may
  be of interest: }
var
  flnNLength: Integer;
    {` After FormatLongName the length of the name itself, without truncation `}
  flnNSize: Integer;
    {` After FormatLongName the length of the name after truncation `}
  flnDotPos: Integer;
    {` After FormatLongName the resulting dot position (if
      not tabulating) or the last space before the extension field
      (if tabulating) `}
  flnPanelName: String;
    {` After FormatLongName the formatted name (without extra
      highlight control characters `}

const
  BreakChars: set of Char = [',', ' ', '[', ']', '{', '}', '(', ')',
   ':', ';', '.', '^',
  '&', '*', '!', '#', '$', '/', '\', '"', '%', '>', '<',
  '-', '+', '=', '|', '?', #13, #10, #9, #26, #12, '@'];

  HexStr: array[0..$F] of Char = '0123456789ABCDEF';
  N_O_E_M_S: array[1..5] of Char = 'NOEMS';
  cTEMP_: String[5] = 'TEMP:';
  cLINK_: String[5] = 'LINK:';
  cNET_: String[7] = 'Network';
  {.$IFNDEF OS2}
  x_x: String[3] = '*.*';
  {.$ELSE}
  {x_x     : string[3] = '*';}
  {.$ENDIF}

var
  OS2exec: Boolean; { use OS2exec to determine if starting of OS/2  }
  { programs is supported                         }
  { use opsys and opOS2 <> 0 to determine if OS/2 }
  { is running                                    }
  Win32exec: Boolean; {starting of Win32 programs is supported  }
  FreeStr: String;
  FreeLongStr: LongString;
  InterfaceStr: String;
    {` Static string for passing data between routines.
    Should not be used unless strictly necessary. `}
  DNNumber: Byte;

  {Cat: do not change variable order, or there will be plugin problems}

var
  {-DataCompBoy-}
  StartupDir: String;
    {` Directory from which DN.EXE was started. With '\' at the end `}
  SourceDir: String;
    {` Directory where configs and histories live. With '\' at the end.
      Controlled by the DN2 env variable. `}
  TempDir: String;
    {` Temporary directory. With '\' at the end `}
  TempFile: String;
  TempFileSWP: String; {JO}
  LngFile: String;
  SwpDir: String;
    {` Directory for temporary command files and lists,
    and under DPMI32 - for swap while an external program runs.
    With '\' at the end. Controlled by the DNSWAP env variable and the /S switch. `}
  {-DataCompBoy-}
const
  DirToChange: String = ''; {DataCompBoy}

  DirToMoveContent: String = ''; {JO}


const
  CL_SafeBuf = $8000;

  Linker: Pointer = nil;
  NeedLocated: LongInt = 0;

const
  CountryInfo: TCountryInfo =
    {`Static variable; always correctly filled`}
   (DateFmt: 0;
    TimeFmt: 0;
    DateSep: '.';
    TimeSep: ':';
    ThouSep: ' ';
    DecSep: '.';
    DecSign: '$';
    CurrencyFmt: 0;
    Currency: '$';
    KbdToggleLayout: 'ru441.xlt';
    ABCSortTable: 'sort866.xlt';

    WinCodeTable: 'win866r.xlt';

    CodeTables: 'KOI:koi8-r.xlt'
    );



type
  TCrc_Table = array[0..255] of LongInt;
const
  Crc_Table_Empty: Boolean = True;
  Crc_Table: ^TCrc_Table = nil;

type
  TPosArray = array[1..9] of TPoint;

  TFPos = record X: Integer; Y: TFileSize end;
  TFPosArray = array [1..9] of TFPos;

implementation

uses
  timeutil, Startup, strutil, Math, DNUtf8,
  osdep, dnscreen, fileutil,
  Commands
  ;
procedure ClrIO;
  
  begin
  InOutRes := 0;
  DosError := 0;
  Abort := False;
  end;

function MemOK: Boolean;
  
  begin
  MemOK := True
  end; {JO}


{-DataCompBoy-}
constructor TTextReader.Create(const FName: String);
  var
    FileSz: TFileSize;
    ToRead: Integer;
  begin
  ClrIO;
  FileMode := $40;
  lAssignFile(Handle, FName);
  lResetFile(Handle, 1);
  if  (IOResult <> 0) or Abort then
    Fail;
  FileSz := FileSize(Handle.F);
  if  (IOResult <> 0) or Abort then
    Fail;
  Eof := FileSz = 0;
  if not Eof then
    begin
    ToRead := MinBufSize(FileSz, TextReaderBufSize);
    BlockRead(Handle.F, Buf, ToRead, BufSz);
    if  (IOResult <> 0) or Abort or (ToRead <> BufSz) then
      begin
      ClrIO;
      Close(Handle.F);
      ClrIO;
      Fail;
      end;
    end;
  BufPos := 0;
  end { TTextReader.Create };
{-DataCompBoy-}

{-DataCompBoy-}
function TTextReader.FileName: String;
  begin
  FileName := lFileNameOf(Handle);
  end;
{-DataCompBoy-}

{-DataCompBoy-}
function TTextReader.GetStr: String;
  var
    CurStr: String;
    BufBeg: Integer;
    Was: Boolean;

  procedure aStr(D: Integer);
    var
      Grow: Integer;
    begin
    Grow := Min((BufPos-BufBeg)-D-Byte(Was), 255-Length(CurStr));
    if Grow > 0 then
      begin
      Move(Buf[BufBeg], CurStr[Length(CurStr)+1], Grow);
      SetLength(CurStr, Length(CurStr)+Grow);
      end;
    end;

  var
    PrevC: Integer;
    C: Char;

  begin { TTextReader.GetStr: }
  CurStr := '';
  if not Eof then
    begin
    PrevC := -1;
    SetLength(CurStr, 0);
    BufBeg := BufPos;
    Was := False;
    repeat
      if BufPos = BufSz then
        begin
        aStr(0);
        ClrIO;
        BlockRead(Handle.F, Buf, TextReaderBufSize, BufSz);
        if BufSz = 0 then
          begin
          Eof := True;
          Break;
          end;
        BufPos := 0;
        BufBeg := 0;
        if Was then
          begin
          Skip1 := True;
          Break
          end;
        end;
      C := Buf[BufPos];
      Inc(BufPos);
      case C of
        #0, #10, #13:
          begin
          if Skip1 then
            begin
            BufBeg := BufPos;
            Skip1 := False;
            Continue;
            end;
          if Was then
            begin
            aStr(1);
            Dec(BufPos, Integer(PrevC = Integer(C)));
            Break;
            end
          else
            Was := True;
          PrevC := Integer(C);
          end;
        else {case}
          begin
          if Was then
            begin
            aStr(1);
            Dec(BufPos);
            Break;
            end;
          Skip1 := False
          end;
      end {case};
    until False;
    end;
  GetStr := CurStr;
  end { TTextReader.GetStr: };
{-DataCompBoy-}

{-DataCompBoy-}
destructor TTextReader.Destroy;
  begin
  ClrIO;
  Close(Handle.F);
  ClrIO;
  end;
{-DataCompBoy-}

{AK155 19.05.05 Replaced all dynamic PString with stack String.
I doubt these PString were useful even in the 16bit version,
and in 32bit they are completely redundant.
   Also introduced a couple of small optimizations and added comments.}
function FormatLongNameB(Name: String; Size, ExtSize: Byte;
     Options: Word;
    FormatMode: TNameFormatMode): String;
  { one byte, one column (the proxy of DNUtf8 for UTF-8 names): FormatLongName below }

  var
    PSize, ESize: Integer; {PathSize, ExtensionSize}
    P, N, E: String; { Path, Name, Extension }
    EFlag, i: Byte;
    Hi: Boolean; { flag that this char}
    Hi1, Hi2, Hi3: Integer; { Positions that should be highlighted.
      Hi1 - path truncation character (suspect it is not really needed,
        since a path never appears together with color);
      Hi2 - file mark character or name truncation before extension;
      Hi3 - truncation character at the right end of the field.
      }
    l: Integer;
  label
    MakeResult;
  begin { FormatLongName }
  if (Name = '..') or (Name = '.' {happens inside foreign archives}) then
    begin
    Result := AddSpace(Name, Size);
    Exit;
    end;
  if  (Options and flnUpCase) <> 0 then
    UpStr(Name)
  else if (Options and (flnLowCase or flnCapitalCase)) <> 0 then
    LowStr(Name);
  lFSplit(Name, P, N, E);
  Delete(E, 1, 1);
  if  (Options and flnCapitalCase) <> 0 then
    N[1] := UpCase(N[1]);
  SetLength(flnPanelName, Size);
  Hi1 := 0;
  Hi2 := 0;
  Hi3 := 0;
  if Size < 5+ExtSize then
    begin
    FillChar(flnPanelName[1], Size, FMSetup.RestChar[1]);
    Hi1 := Size;
    goto MakeResult;
    end;
  flnNLength := Length(N);
  flnNSize := flnNLength;
  ESize := Length(E); { already without the dot }
  EFlag := Byte(ESize > 0);

  if Options and flnPreserveExt <> 0 then
    begin
    l := (Length(N) + Min(3, Length(P)));
      { how much is wanted for path and name with maximal path truncation }
    if (Size - l > ESize) { Extension fits } or
       (l < Size-ExtSize) { Name need not be truncated }
    then
      ExtSize := 0 { Do not tabulate }
    else if ESize < ExtSize then
      ExtSize := ESize; { Tabulate, but minimize name truncation }
    end;

  if (ExtSize <> 0) and (ESize > ExtSize) then
    begin { Truncate extension in tabulated display }
    ESize := ExtSize;
    Hi3 := Size;
    end;

  PSize := Max(3, Size-(ESize+EFlag)-flnNSize);
  if PSize >= Length(P) then
    PSize := Length(P)
  else
    begin { Truncate path }
    P[PSize] := FMSetup.RestChar[1];
    Hi1 := PSize
    end;

  {  Truncate extension in non-tabulated display.
  It cannot be merged with name truncation, because the position of the last
  dot may receive a hidden/system file indicator.}
  if (ExtSize <> 0) then
    i := ExtSize+1
  else
    begin
    ESize := Min(Length(E), Max(0, Size-EFlag-PSize-flnNSize));
    EFlag := Byte(ESize > 0);
    i := ESize+EFlag;
    if ESize < Length(E) then
      Hi3 := Size;
    end;
  { Now i is the extension field width, including the dot position }

  { Truncate name }
  flnNSize := Min(Length(N), Max(1, Size-i-PSize));

  FillChar(flnPanelName[1], Size, ' ');
  if ExtSize = 0 then
    flnDotPos := PSize+flnNSize+1
  else
    flnDotPos := Size-ExtSize;
  { Now flnDotPos is the dot position if it is within the field,
    or Size+1 if the dot goes beyond the field due to a too-long
    name in non-tabulated extension mode }
  for i := 1 to PSize do
    flnPanelName[i] := P[i];
  for i := 1 to flnNSize do
    flnPanelName[PSize+i] := N[i];
  for i := 1 to ESize do
    flnPanelName[flnDotPos+i] := E[i];
  if (FormatMode <> nfmNull) or
     ((Options and flnAutoHideDot = 0) and (ESize <> 0))
  then
    flnPanelName[flnDotPos] := NameFormatChar[FormatMode];
      { Store attribute indicator or restore the dot.
        If the dot position is outside the field (i.e. truncation), attributes
        will not be indicated. Maybe that is wrong, but that is
        how it always was.}
  if flnNSize < Length(N) then
    begin { Truncate name }
    Hi2 := PSize+flnNSize + byte(flnDotPos <= Size);
      {If the dot position is shown, put truncation in its place, and
      if not - have to truncate 1 character more }
    flnPanelName[Hi2] := FMSetup.RestChar[1];
    end;
  if Hi3 <> 0 then {Truncate extension. It may actually
      truncate the name if display is non-tabulated. In that case the mark
      (if any) must overlay the truncation, so
      this fragment must come before storing the mark character. }
    flnPanelName[Hi3] := FMSetup.RestChar[1];
  if (Options and flnSelected) <> 0 then
    begin { Mark }
    Hi2 := flnDotPos - byte(flnDotPos > Size);
      {If the dot position is shown, put the mark in its place, and
      if not - on the last displayed character. Truncation is then
      suppressed }
    flnPanelName[Hi2] := FMSetup.TagChar[1];
    end;

MakeResult:
  Result := '';
  if  (Options and flnPadRight) = 0 then
    DelRight(flnPanelName);
{AK155 13.05.2005 Here, and at the end of the routine, tildes are added,
and in GetFull they are fought with a color code. Simpler not to
add them and not to fight.
  if  ( (Options and flnSelected) <> 0) and
      ( (Options and flnHighlight) <> 0)
  then
    AddStr(Res^, '~');
/AK155}

  for i := 1 to Length(flnPanelName) do
    begin
    Hi := { flag that this character must be highlighted }
       ( (Options and flnHighlight) <> 0) and
       ( (i = Hi1) or (i = Hi2) or (i = Hi3));
    if Hi then
      AddStr(Result, '~');
    if  (flnPanelName[i] = '~') and ((Options and flnHandleTildes) <> 0) then
      AddStr(Result, #0);
    AddStr(Result, flnPanelName[i]);
    {AK155: why this second #0 - could not figure out, so removed it.
As for the first #0, figured it should ensure
tilde drawing. And made the corresponding correction in
drivers._vp.MoveCStr. 06.01.2001}
    {
          if (flnPanelName[i]='~') and ((Options and flnHandleTildes)<>0)
          then AddStr(Res^,#0);}

    {/AK155}
    if Hi then
      AddStr(Result, '~');
    end;
{AK155 13.05.2005 - see above
  if  ( (Options and flnSelected) <> 0) and
      ( (Options and flnHighlight) <> 0)
  then
    AddStr(Res^, '~');
/AK155}
  end { FormatLongNameB };

function FormatLongName(Name: String; Size, ExtSize: Byte;
     Options: Word;
    FormatMode: TNameFormatMode): String;
{$IFDEF DNUTF8}
  var
    Tab: String;
    P, N, E: String;
    Opt: Word;
  begin
  { Case on the real UTF-8 name: FormatLongNameB would call UpStr/LowStr on the proxy and break it. }
  Opt := Options;
  if (Opt and flnUpCase) <> 0 then
    Utf8UpStr(Name)
  else if (Opt and (flnLowCase or flnCapitalCase)) <> 0 then
    Utf8LowStr(Name);
  if (Opt and flnCapitalCase) <> 0 then
    begin
    lFSplit(Name, P, N, E);
    if Length(N) > 0 then
      begin
      Utf8CapFirst(N);
      Name := P + N + E;
      end;
    end;
  Opt := Opt and not (flnUpCase or flnLowCase or flnCapitalCase);
  Name := Utf8ToProxy(Name, Tab);
  Result := ProxyToUtf8(FormatLongNameB(Name, Size, ExtSize, Opt, FormatMode), Tab);
  end;
{$ELSE}
  begin
  Result := FormatLongNameB(Name, Size, ExtSize, Options, FormatMode);
  end;
{$ENDIF}

procedure CheckOS;
  begin
  
  
  
  opSys := opDPMI32;
  opSys := opSys or opDos;   { DOS: no probing of OS/2, Windows, DESQview here (TODO) }
  
  end;


function GetMeMemoStream: TStream; {-$VOL begin}
  const
    _1: Byte = 1;
  var
    S: TStream;
    Pos: LongInt;
  begin
  S := TMemoryStream.Create(2048, 2048);
  {Cat: and now write a one there so that other silly routines,            }
  {     which read from the stream what they did not write, think          }
  {     that our stream contains long strings                              }
  S.Seek(0);
  S.Write(_1, 1);
  S.Seek(0);
  {/Cat}
  if S.Status <> stOK then
    begin
    S.Free;
    S := nil
    end;
  GetMeMemoStream := S;
  end; {-$VOL end}

function MemAdjust(L: LongInt): LongInt;
  begin
  if Linker <> nil then
    begin
    if L > CL_SafeBuf then
      L := L-CL_SafeBuf
    else
      L := 0;
    end;
  MemAdjust := L;
  end;

procedure FillWord(var B; Count, W: Word);
  var
    I: Integer;
    P: PWord;
  begin
  P := @B;
  for I := 1 to Count do
    begin
    P^ := W;
    Inc(P);
    end;
  end;

procedure LocateCursor(X, Y: Byte);
  begin
  MoveCursorTo {GotoXY}(X, Y)
  end;

procedure TinySlice;
  begin
  
//  give_up_cpu_time;
//piwamoto: it crashes under W2K, so i get code from DN OSP
{AK155 Under OS/2 int $28 does not unload the CPU, but
 int $2f (DPMI Idle) does. Probably for DPMI32 int $2f
 is not applicable. So left DPMI Idle unconditionally}
  
  end;

begin
CheckOS;
{ Starting of OS/2 programs is possible under:              }
{ - OS/2 2.10+, OS2COMSPEC environment variable is required }
{ - OS/2 Warp 3+, no additional requirements                }
{ - OS/2 for PPC, future versions for IA64 (I hope)         }

OS2exec := (opSys and opOS2 <> 0) and
    ( (Lo(DosVersion) > 20) or
      ( (Lo(DosVersion) = 20) and
        ( (Hi(DosVersion) >= 30) or
          ( (Hi(DosVersion) >= 10) and (GetEnv('OS2COMSPEC') <> ''))
        )));
Win32exec := opSys and opWin <> 0; {does not work for NT yet}



end.
