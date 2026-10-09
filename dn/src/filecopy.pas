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

unit FileCopy;

interface

uses
  Collect, FilesCol, Defines, Views
  ;

type
  PCopyRec = ^TCopyRec;
    {2` Used for D&D of event info into InfoPtr `}
  TCopyRec = record
    FC: TFilesCollection;
    Owner: TView;  // panel we dragged from
    Where: TPoint; // where we dropped (global coordinates)
    end;
    {`}

const
  SkipCopyDialog: Boolean = False;
  CopyDirName: String = ''; {DataCompBoy}
  RevertBar: Boolean = False; {DataCompBoy}

procedure CopyFiles(Files: TCollection; SourcePanel: TView;
     MoveMode: Boolean; FromTemp: Byte);
function SelectDialog(Select: Boolean; var ST: String;
     var XORSelect: Boolean): Boolean;
procedure BeepAftercopy;

function CopyDialog(var CopyDir: String; var Mask: String;
    {DataCompBoy}
    var CopyOpt: Word; var CopyMode: Word;
    var CopyPrn: Boolean; {var Inheread: Byte;}
    MoveMode: Boolean; Files: TCollection;
    FromTemp: Byte; SourcePanel: TView; Link: Boolean): Boolean;
  { If the dialog ended successfully and not CopyPrn, then CopyDir
   is surely non-empty, and there is always a DnSep at the end.}

procedure CopyDirContent(Source, Destination: String;
    MoveMode, Forced: Boolean); {JO}

procedure CloseWriteStream;
  {` AK155 20.06.2007
    This procedure is called on abnormal termination. It is needed
    so that if termination happened during writing, the file gets
    the actually written size, not the full size
    that is set at the start of writing.
    Leaving the full size is bad because, first, it is untrue,
    and second, under Win NT the program may close very slowly
    for a large file, because the system for some reason fills with zeros
    the entire unwritten part. `}

implementation
uses DnPath,
  FlightRec, mainapp, Startup, Messages, HistList, Commands,
  timeutil, Validate, TitleSet, UserMenu, Dos, DnIni,
  
  osdep, dnscreen, TvGlyphs, Filediz , ArvidAvt ,
  dirwatch, fsinfo, basics, strutil, fileutil,
  progress, FileFind, Math,
  DNUtil, Tree, Archiver, Drives, DiskInfo
  , fileerrors
  , panelroot {JO: TFilePanelRoot is needed to make unavailable }
  {    copying of descriptions }
  

  , panelsetup, Lfn, uselfn, Streams, Drivers, objutil, Dialogs
  , Strings;

const
  Marked = $4000;
  Copied = $8000;
    { AK155 28/11/05.
       Marked and Copied bits are written into the file record Attr
    if the file (directory) must be moved, and when it has been moved successfully.
    Somewhere these bits are written regardless of copy or move, but
    in the copy case they are never analyzed.
    They were used only in one place, for updating tree files
    and for rereading directories. Work with tree files was removed.
       Previously these magic constants were quietly used directly
    in numeric form, and the meaning was completely unclear. Worse,
    $8000 was also used (filepanel) to mark that
    the directory size is known, which could cause confusion.
       Now for directory size the attribute bit is not used,
    and when the length is unknown, length -1 is simply written, not 0
    (see filescol.pas, TFileRec.Size). }

const
  cpmOverwrite = 0;
  cpmAppend = 1;
  cpmResume = 2;
  cpmSkipAll = 3;
  cpmRefresh = 4;
  cpmAskOver = 5;

  cpoCheckFree = $01;
  cpoVerify = $02;
  cpoDesc = $04;
  
  
  cpoMove = $10;

  cpoFromTemp = $800;
  cpoCopyDesc = $400;
  cpoFitAll = $100;

var
  SeekPos: TFileSize;

function MemAvail: LongInt;
  begin
  MemAvail := MemAdjust(Defines.MemAvail);
  end;

function MaxAvail: LongInt;
  begin
  MaxAvail := MemAdjust(Defines.MaxAvail);
  end;


procedure BeepAftercopy;
  var
    C: Char;
  begin
{AK155 Why?  DelayTics(1); }
  for C := 'A' to 'D' do
    begin
    SysBeepEx {PlaySound}(1259, 55);
    SysBeepEx {PlaySound}(1400, 55);
    end;
  SysBeepEx {PlaySound}(1259, 110);
  end;

procedure PrepareSelectDialog(P: TDialog);
  var
    S: String;
  begin
  with P do
    begin
    if DirectLink[1] <> nil then
      TInputline(DirectLink[1]).SetValidator(
        TFilterValidator.Create([#32..#255] - ['|', '>', '<']));
    end;
  end;

{-DataCompBoy-}
function SelectDialog(Select: Boolean; var ST: String; var XORSelect: Boolean): Boolean;
  var
    P: record
      S: String;
      XorSel: Boolean;
      end;
    Idx: TDlgIdx;
    R: TRect;

  begin
  with P do
    begin
    XorSel := XORSelect;
    SelectDialog := False;
    if Select then
      Idx := dlgSelect
    else
      Idx := dlgUnselect;
    S := HistoryStr(hsSelectBox, 0);
    if S = '' then
      S := x_x;
    @PreExecuteDialog := @PrepareSelectDialog;
    if ExecResource(Idx, P) = cmCancel then
      Exit;
    SelectDialog := True;
    ST := S;
    XORSelect := XorSel;
    end
  end { SelectDialog };
{-DataCompBoy-}

const
  eoStart = $01;
  eoEnd = $02;
  eoAppend = $04;
  eoDir = $08;
  eoCheck = $10;
  eoResume = $20;

  ReadLen = $C000;

var
  ToDo, ToDoCopy, ToDoClusCopy: TSize;
  ToDoClusCopyTemp: TSize;
  MemBuf: PByteArray;
    { copy buffer }
  MemBufPos, MemBufSize: Longint;
  WriteStream: lFile;

type
  TLine = class
    { CopyQueue element}
    Owner: PFileRec;
    OldName: PString;
    NewName: PString;
    Size: TSize; // file length
    Date: LongInt;
    len: Word; // length of the block we will read
    Eof: Byte;
    Attr: Byte;
    constructor Create(var ALen: LongInt; AOwner: Pointer;
         const AOldName, ANewName: String;
        ASize: TSize; ADate: LongInt; AAttr: Byte; AEOF: ShortInt);
    procedure PrepareToWrite; virtual;
    destructor Destroy; override;
    end;

  TLineQueue = class(TCollection)
    procedure FreeItem(Item: Pointer); override;
    end;

  TDirName = class
    OldName, NewName: PString;
    Check: Boolean;
    CopyIt: Boolean;
    Own: PFileRec;
    Attr: Byte;
    constructor Create(const AOld, ANew: String; ACopy: Boolean;
         AnOwn: PFileRec; AnAttr: Byte);
    function DOld: String;
    function DNew: String;
    destructor Destroy; override;
    end;

  { TDirName }

constructor TDirName.Create(const AOld, ANew: String; ACopy: Boolean; AnOwn: PFileRec; AnAttr: Byte);
  begin
  inherited Create;
  OldName := NewStr(AOld);
  NewName := NewStr(fReplace('.'+DnSep, DnSep, ANew));
  CopyIt := ACopy;
  Own := AnOwn;
  Attr := AnAttr;
  end;

function TDirName.DNew: String;
  begin
  if NewName = nil then
    DNew := ''
  else
    DNew := NewName^;
  end;

function TDirName.DOld: String;
  begin
  if OldName = nil then
    DOld := ''
  else
    DOld := OldName^;
  end;

destructor TDirName.Destroy;
  begin
  DisposeStr(OldName);
  DisposeStr(NewName);
  inherited Destroy;
  end;

{ TLine }

constructor TLine.Create(var ALen: LongInt; AOwner: Pointer; const AOldName, ANewName: String; ASize: TSize; ADate: LongInt; AAttr: Byte; AEOF: ShortInt);
  begin
  inherited Create;
  if MaxAvail < 2048 then
    Fail;
  len := ALen;
  Eof := AEOF;
  Attr := AAttr;
  Date := ADate;
  Size := ASize;
  if len <> 0 then
    begin
    PrepareToWrite;
    if len <= 0 then
      Fail;
    ALen := len;
    end
  else
    Eof := eoStart+eoEnd;
  Owner := AOwner;
  if (Eof and eoStart) <> 0 then
    begin
    OldName := NewStr(AOldName);
    NewName := NewStr(ANewName);
    end;
  end { TLine.Init };

destructor TLine.Destroy;
  begin
  DisposeStr(PString(NewName));
  DisposeStr(PString(OldName));
  inherited Destroy;
  end;

procedure TLineQueue.FreeItem(Item: Pointer);
  begin
  if Item <> nil then
    TLine(Item).Free;
  end;

procedure TLine.PrepareToWrite;
  begin
  if MemBufPos+len > MemBufSize then
    len := MemBufSize-MemBufPos;
  end;

procedure InitMemBuf;
  var
    Limit: Longint; // in kByte
  begin
  Limit := Max(1, ((PhysMemAvail div 10)*9) div 1024);
  if SystemData.CopyLimitBuf > 0 then
    Limit := Min(Limit, SystemData.CopyLimitBuf);
  while Limit <> 0 do
    begin
    MemBuf := GetMem(Limit*1024);
    if MemBuf <> nil then
      begin
      MemBufSize := Limit*1024;
      MemBufPos := 0;
      Exit;
      end;
    Limit:= Limit div 2;
    end;
  end;


{ ----------------------------- File Copy ------------------------------ }

{AK155}
function AppendQuery(const S: String): Word;
  var
    D: TDialog;
    P: TStaticText;
    R: TRect;
  begin
  D := TDialog(LoadResource(dlgAppendQuery));
  D.Options := D.Options or ofCentered;
  R := TRect.Create(2, 4, D.Size.X-2, 5);
  P := TStaticText.Create(R, ^C+S);
  D.Insert(P);
  AppendQuery := Desktop.ExecView(D);
  end;

function GetPercent(N: TSize): Str12;
  begin
  if ToDo = 0 then
    Result := ' (100%)'
  else
    begin
    N := (N*100) div ToDo;
    Result := ' ('+ZtoS(N)+'%)';
    end;
  end;

var
  StopDlgData: word;

type
  TOverriteDialog = class(TDialog)
    procedure HandleEvent(var Event: TEvent); override;
    end;

procedure TOverriteDialog.HandleEvent(var Event: TEvent);
  begin
  inherited HandleEvent(Event);
  if (Event.What = evCommand) and (Event.Message.Command = cmSave) then
     begin { "Continue" button }
     EndModal(Event.Message.Command);
     ClearEvent(Event);
     end;
  end;

{-DataCompBoy-}
procedure FilesCopy(Files: TCollection; SourcePanel: TView;
    const CopyDir, Mask: String; CopyMode, CopyOptions: Word;
    CopyPrn, RR: Boolean);

  var
    ReadStream: lFile;
    ReadPos: TSize;
    CopyCancel: Boolean;
    SkipAllBad: Boolean;
    ToRead, ToWrite: TSize;
    CopyStartTime, CopyElapsedTime: LongInt; {John_SW 30-06-2005}
    CopyQueue: TLineQueue;
    Dirs: TCollection;
    iQueue: Integer;
    CurOldName, CurNewName: String;
    CurDate: LongInt;
    CurAttr: Byte;
    Info: TWhileView;
    R: TRect;
    Drv, InhR: Byte;
    ReD: set of Char;
    C: Char;
    SS: String[1];
    Timer: TEventTimer;
    CD_Drives: set of Char;
    AdvCopy: Boolean;
    _Tmr: TEventTimer;
    IOR: Integer;
    SSS: String;
    TargetDirName: String;
    PathBuffer: array[0..255] of Char; {target directory}
    RC: LongInt;
    CondLfn: TUseLFN; {JO}

  function MkName(const Nm: String): String;
    var
      S: String;
    begin
    S := fileutil.MkName(Nm, Mask);
    if  (S[Length(S)] = '.') and (Length(S) > 1) then
      SetLength(S, Length(S)-1); {JO}
    MkName := S;
    end;

  var
    GrdClick: Boolean;
    ExAttr: Word;

  procedure SetDateAttr;
    begin
    case ExAttr shr 8 of
      $FD, $FE:
        ;
      else {case}
        SetFTime(WriteStream.F, CurDate);
    end {case};
    Close(WriteStream.F);
    case ExAttr shr 8 of
      $FF: { Set Source Attribute, if Necessary }
        if CurAttr <> Archive then
          lSetFAttr(WriteStream, CurAttr);
      $FE: { Set Dest' Attribute }
        lSetFAttr(WriteStream, ExAttr and $FF);
      $FD: { Don't Set any attribute }
        ;
      else { Set Source Attribute, Force }
        lSetFAttr(WriteStream, CurAttr);
    end {case};
    end;

  procedure Dispatch;
    var
      CancelAnswer: word;
      C: Boolean;
    procedure DE;
      begin
      GrdClick := True;
      DispatchEvents(Info, C)
      end;

    begin
    C := False;
    if CopyCancel then
      begin
      DE;
      Exit
      end;
    if TimerExpired(_Tmr) then
      begin
      DE;
      if C or CtrlBreakHit then
        begin
        StopDlgData := 0;
        CancelAnswer := ExecResource(dlgQueryAbort, StopDlgData);
        CopyCancel := CancelAnswer <> cmNo;
        end;
      CtrlBreakHit := False;
      NewTimer(_Tmr, 300);
      end;
    end { Dispatch };

  procedure ForceDispatch;
    begin
    NewTimer(_Tmr, 0);
    Dispatch;
    end;

  var
    Wrote: TSize;
    FreeDisk: TSize;

  procedure RemoveFromTemp(P: PFileRec);
    var
      I: LongInt;
    begin
    I := 0;
    if  (P <> nil) and (TempFiles <> nil) and TempFiles.Search(P, I)
    then
      TempFiles.AtFree(I);
    end;

  function Overwrite(const NName: String; OldS, NewS: TSize;
       OldT, NewT: LongInt): Word;
    var
      AcceptAll: Word;
      I: Word;
      D: TDialog;
      P: TView;
      R: TRect;
      S: String;
      D1, D2,
      L1, L2: String[30];
      PP: array[1..4] of Pointer;
      DD: LongInt;
      DT: DateTime;
    begin
    AcceptAll := 0;
    Overwrite := cmSkip;
    UnpackTime(OldT, DT);
    MakeDate(DT.Day, DT.Month, DT.Year mod 100, DT.Hour,
       DT.Min, D2);
    L2 := FStr(OldS);
    UnpackTime(NewT, DT);
    MakeDate(DT.Day, DT.Month, DT.Year mod 100, DT.Hour,
       DT.Min, D1);
    L1 := FStr(NewS);
    if Length(L1) < Length(L2)
    then
      L1 := PredSpace(L1, Length(L2))
    else
      L2 := PredSpace(L2, Length(L1));
    D := TDialog(LoadResource(dlgOverwriteQuery));
    R := D.GetExtent;
    R.Grow(-1, -1);
    Inc(R.A.Y);
    D.Options := D.Options or ofCentered;
    DelRight(D1);
    DelRight(D2);
    D1[9] := '(';
    AddStr(D1, ')');
    D2[9] := '(';
    AddStr(D2, ')');
    PP[1] := @D1;
    PP[2] := @L1;
    PP[3] := @D2;
    PP[4] := @L2;
    FormatStr(S, GetString(dlFCOver), PP);
    R.B.Y := R.A.Y+1;
    for I := 1 to Length(S) do
      if S[I] = ^M then
        Inc(R.B.Y);
    P := TStaticText.Create(R, ^C+GetString(dlFile)+' '+Cut(NName,
           40)+S);
    D.Insert(P);

    MsgActive := True;
    D.SetData(AcceptAll);
    ObjChangeType(D, TClass(TOverriteDialog));
    if OldS >= NewS then
      D.DisableCommands([cmSave]);
    I := Desktop.ExecView(D);
    D.EnableCommands([cmSave]);
    MsgActive := False;
    NewTimer(Timer, 0);

    if I <> cmCancel then
      begin
      D.GetData(AcceptAll);
      if  (AcceptAll and 1 = 1) then
        case I of
          cmYes:
            CopyMode := cpmOverwrite;
          cmSkip:
            CopyMode := cpmSkipAll;
          cmNo:
            CopyMode := cpmAppend;
          cmSave:
            CopyMode := cpmResume;
        end {case};
      Overwrite := I;
      end
    else
      Overwrite := cmSkip;

    D.Free;

    CopyCancel := I = cmCancel;
    end { Overwrite };

  var
    SkipRequested: Boolean;

  var
    DOSErrorCode: Word;

  procedure RnFl(N1, N2: String);
    begin
    lChangeFileName(N1, N2);
    DosErrorCode := IOResult;
    if DosErrorCode = 18 then
      DosErrorCode := 17;  { Unix: EXDEV (another file system) is NOT_SAME_DEVICE of DOS: the move is a copy and a delete }
    end;

{--- start -------- Eugeny Zvyagintzev ---- 30-06-2005 -----}
   function CopyTime: String;
     var
       s1, s2, s3: String;
       M: Array [1..3] Of Pointer;
       Speed: Int64;
       Time: Int64;
       D: Longint;
    begin
    Result := '';
    if (ToWrite = 0) and (ToRead = 0) then
      Exit;
    D := GetCurMSec - CopyStartTime;
    if D - CopyElapsedTime < 1000 then
      Exit;
    CopyElapsedTime := D;
    s1 := SecToStr((CopyElapsedTime + 500) div 1000);
    Time := ((2*ToDo-ToRead-ToWrite)*CopyElapsedTime) div (ToRead+ToWrite);
    s2 := SecToStr(Trunc(Time / 1000));

    Speed := 1000*ToDo div (CopyElapsedTime+Time);
    if Speed > 1024 then
      s3 := ZtoS(Speed div 1024)+' K'
    else
      s3 := ZtoS(Speed)+' ';
    M[1] := @s1; M[2] := @s2; M[3] := @s3;
    FormatStr(Result, GetString(dlCopyTimeSpeed), M);
    end;
{--- finish -------- Eugeny Zvyagintzev ---- 30-06-2005 -----}

  procedure MaxWrite;
    label DoRewrite, DoAppend, 1, 2, lbStartWrite, lbStartCheck
      , lRetryToReset;
    var
      iQueue: Integer;
      J: Word;
      P: TLine;
      A: LongInt;
      BB: TSize;
      F: lFile;
      PS: array[1..2] of Pointer;
      S1: String;
      BufCrc: Word;
      Created: Boolean;
      Opened: Integer;
      MsgResult: Integer;
      Ask: Integer;
      
      LongNameWarn: String[50];
      I_LW: Byte;

    procedure RewriteWriteStrem;
      {Open WriteStrem and set its final size.
       Size is set to reduce fragmentation and
       speed things up.
         InOutres reflects the open result, and the size-set
       result is not analyzed.}
      begin
      lReWriteFile(WriteStream, 1);
      SysFileSetSize(FileRec(WriteStream.F).Handle, CompToFSize(P.Size));
      end;

    procedure TryToReset;
      var
        OldAttr: Word;
      begin
      {AK155 2-02-2002
Previously file existence was checked via lResetFile, which is not
entirely correct. On CD RW under RSJ and, it seems, on some network disks,
this operation creates a file and a false overwrite prompt.
Moreover, on a negative answer the created file remains
(with zero length). Checking via lGetFAttr is cleaner.
}
      if CopyMode <> cpmOverwrite then
        begin
        ClrIO;
        lGetFAttr(WriteStream, OldAttr);
        if  (DosError = 0) then
          begin
          lResetFile(WriteStream, 1);
          Opened := IOResult;
          Created := False;
          Exit;
          end;
        end;
      RewriteWriteStrem;
      Opened := IOResult;
      Created := Opened = 0;
      end { TryToReset };

    procedure DoSkip;
      begin
      while (iQueue < CopyQueue.Count-1)
        and (TLine(CopyQueue.At(iQueue)).Eof and eoEnd = 0)
      do
        Inc(iQueue);
      SkipRequested := iQueue >= CopyQueue.Count-1;
      end;

    function CheckI24Abort: Boolean;
      begin
      CheckI24Abort := Abort;
      if not Abort then
        Exit;
      CopyCancel := True;
      end;
    const
      CrcTable: array[0..255] of Word = (
        $0000, $1021, $2042, $3063, $4084, $50a5, $60c6, $70e7,
        $8108, $9129, $a14a, $b16b, $c18c, $d1ad, $e1ce, $f1ef,
        $1231, $0210, $3273, $2252, $52b5, $4294, $72f7, $62d6,
        $9339, $8318, $b37b, $a35a, $d3bd, $c39c, $f3ff, $e3de,
        $2462, $3443, $0420, $1401, $64e6, $74c7, $44a4, $5485,
        $a56a, $b54b, $8528, $9509, $e5ee, $f5cf, $c5ac, $d58d,
        $3653, $2672, $1611, $0630, $76d7, $66f6, $5695, $46b4,
        $b75b, $a77a, $9719, $8738, $f7df, $e7fe, $d79d, $c7bc,
        $48c4, $58e5, $6886, $78a7, $0840, $1861, $2802, $3823,
        $c9cc, $d9ed, $e98e, $f9af, $8948, $9969, $a90a, $b92b,
        $5af5, $4ad4, $7ab7, $6a96, $1a71, $0a50, $3a33, $2a12,
        $dbfd, $cbdc, $fbbf, $eb9e, $9b79, $8b58, $bb3b, $ab1a,
        $6ca6, $7c87, $4ce4, $5cc5, $2c22, $3c03, $0c60, $1c41,
        $edae, $fd8f, $cdec, $ddcd, $ad2a, $bd0b, $8d68, $9d49,
        $7e97, $6eb6, $5ed5, $4ef4, $3e13, $2e32, $1e51, $0e70,
        $ff9f, $efbe, $dfdd, $cffc, $bf1b, $af3a, $9f59, $8f78,
        $9188, $81a9, $b1ca, $a1eb, $d10c, $c12d, $f14e, $e16f,
        $1080, $00a1, $30c2, $20e3, $5004, $4025, $7046, $6067,
        $83b9, $9398, $a3fb, $b3da, $c33d, $d31c, $e37f, $f35e,
        $02b1, $1290, $22f3, $32d2, $4235, $5214, $6277, $7256,
        $b5ea, $a5cb, $95a8, $8589, $f56e, $e54f, $d52c, $c50d,
        $34e2, $24c3, $14a0, $0481, $7466, $6447, $5424, $4405,
        $a7db, $b7fa, $8799, $97b8, $e75f, $f77e, $c71d, $d73c,
        $26d3, $36f2, $0691, $16b0, $6657, $7676, $4615, $5634,
        $d94c, $c96d, $f90e, $e92f, $99c8, $89e9, $b98a, $a9ab,
        $5844, $4865, $7806, $6827, $18c0, $08e1, $3882, $28a3,
        $cb7d, $db5c, $eb3f, $fb1e, $8bf9, $9bd8, $abbb, $bb9a,
        $4a75, $5a54, $6a37, $7a16, $0af1, $1ad0, $2ab3, $3a92,
        $fd2e, $ed0f, $dd6c, $cd4d, $bdaa, $ad8b, $9de8, $8dc9,
        $7c26, $6c07, $5c64, $4c45, $3ca2, $2c83, $1ce0, $0cc1,
        $ef1f, $ff3e, $cf5d, $df7c, $af9b, $bfba, $8fd9, $9ff8,
        $6e17, $7e36, $4e55, $5e74, $2e93, $3eb2, $0ed1, $1ef0
        );

    function UpdateCrc(CurByte: Byte; CurCrc: Word): Word;
      {-Returns an updated CRC16}
      begin
      UpdateCrc := CrcTable[((CurCrc shr 8) and 255)] xor
          (CurCrc shl 8) xor CurByte;
      end;

    function GetCrc(var Buf; BfLen: Word): Word;
      var
        Data: array[0..$FFF] of Byte absolute Buf;
        I: Word;
        Crc: Word;
      begin
      GetCrc := 0;
      Crc := $1972;
      if BfLen = 0 then
        Exit;
      for I := 0 to pred(BfLen) do
        Crc := UpdateCrc(Data[I], Crc);
      GetCrc := Crc;
      end;

    procedure NoWrite;
      begin
      CopyCancel := True;
      ForceDispatch;
      CantWrite(CurNewName);
      end;

    function WriteCount: String;
      begin
      WriteCount := FStr(ToWrite)+GetString(dlBytes)+GetPercent(ToWrite)
        +GetString(dlFC_Written);
      SetTitle(GetPercent((ToWrite+ToRead) div 2)+GetString(dlCopied));
      end;

    procedure TrySetArch;
      begin
      if  (ExAttr and (ReadOnly+SysFile+Hidden) <> 0) then
        begin
        lSetFAttr(WriteStream, Archive);
        ClrIO;
        end;
      end;

    var
      WPWas: Boolean;

    procedure WriteProgress;
      var
        CT: String;
      begin
      Info.Write(6, StrGrd(P.Size, Wrote, Info.Size.X-6, RevertBar));
      Info.Write(7, WriteCount);
      CT := CopyTime;
      if CT <> '' then
        Info.Write(9, CT); {John_SW 30-06-2005}
      end;

    { **************** }
    { *** FileCopy *** }
    { **************** }

    var
      NFBigger: Boolean; {John_SW}
      WorkS: String;
      DirInfo : lSearchRec; {John_SW}
    begin { MaxWrite }
    SkipRequested := False;
    iQueue := -1;
    WPWas := False;
    MemBufPos := 0;
    if not Abort or not CopyCancel then
      while True do
        begin
1:
        Inc(iQueue);
        if iQueue = CopyQueue.Count then
          begin
          if WPWas then
            WriteProgress;
          Break;
          end;
        P := CopyQueue.At(iQueue);
        if P.Eof and eoStart <> 0 then
          begin
          CurOldName := CnvString(P.OldName);
          CurNewName := CnvString(P.NewName);
          CurDate := P.Date;
          CurAttr := P.Attr;
          DisposeStr(P.OldName);
          P.OldName := nil;
          DisposeStr(P.NewName);
          P.NewName := nil;
          end;
        if CurAttr and Directory <> 0 then
          begin
          SSS := CurOldName;
          MakeNoSlash(SSS);
          ClrIO;
          if CopyOptions and cpoMove <> 0 then
            begin
            DeleteDiz(P.Owner);
            lRmDir(SSS);
            end;
          if  (P.Owner <> nil) then
            begin
            if IOResult = 0 then
              P.Owner.Attr := P.Owner.Attr or Copied;
            if  (SourcePanel <> nil) then
              Message(SourcePanel, evCommand, cmCopyUnselect, P.Owner);
            end;
          Continue;
          end
          
          ;
        if P.Eof and eoStart <> 0 then
          begin
2: { We get here, in particular, when renaming a file with the same name }
          ExAttr := $FFFF;
          Wrote := 0;
          Info.Write(5,
               GetString(dlFC_Writing)+Cut(CurNewName, 40)+' ');
          Info.Write(6, Strg(GlyphChar(glShadeMedium), Info.Size.X-6));
          Info.Write(7, WriteCount);
          //Dispatch;
          GrdClick := False;
          lAssignFile(WriteStream, CurNewName);
          ClrIO;
          FileMode := $42;

          if  (CopyOptions and cpoCheckFree <> 0)
             and (SysDiskFreeLongX(@PathBuffer) < P.Size)
          then
            begin
            {--- start -------- Eugeny Zvyagintzev ---- 29-08-2002 ----}
            {We have to check for existing file's size when not enough free space}
            lFindFirst(CurNewName, AnyFileDir, DirInfo);
            NFBigger := (DosError <> 0) or
                        (P.Size > DirInfo.FullSize +
                                   SysDiskFreeLongX(@PathBuffer));
            lFindClose(DirInfo);
            if NFBigger then
              begin
              {--- finish -------- Eugeny Zvyagintzev ---- 29-08-2002 ----}
              PS[1] := Pointer(LongInt(Drv+64));
              PS[2] := P.OldName;
              lAssignFile(WriteStream, '');
              ForceDispatch;
              if CopyOptions and cpoFitAll = 0 then
                begin
                MsgResult := Msg(erNoDiskSpace, @PS,
                     mfError+mfYesButton+mfNoButton+mfAllButton);
                CopyCancel := (MsgResult <> cmYes) and (MsgResult <> cmOK);
                if MsgResult = cmOK then
                  CopyOptions := CopyOptions or cpoFitAll
                end
              else
                CopyCancel := False;
              NewTimer(Timer, 0);
              DoSkip;
              if not SkipRequested then
                goto 1;
              if  (not CopyCancel) then
                Continue;
              Break;
              end;
            end;

          if P.Eof and eoCheck <> 0 then
            begin
            if AdvCopy then
              begin
lRetryToReset:
              TryToReset;
              case Opened of
                0:
                  begin
                  if Created then
                    goto lbStartWrite
                  else
                    goto lbStartCheck;
                  end;
                5:
                  goto lbStartCheck;
                123, 206:
                  begin
                  if Opened = 206 then
                    LongNameWarn :=
                      GetString(dlCE_Filename_Exced_Range)
                  else
                    LongNameWarn :=
                      GetString(dlCE_Filename_Illegal);
                  I_LW := Pos('%', LongNameWarn);
                  if I_LW > 0 then
                    begin
                    LongNameWarn[I_LW] :=
                      UpCase(CurNewName[1]);
                    LongNameWarn[I_LW+1] := ':'
                    end;
                  case MessageBox(^C+LongNameWarn+^M^C+
                    GetString(dlFCRename)+' ?', nil,
                    mfError+mfYesButton+
                    mfNoButton+mfCancelButton) of
                    cmYes:
                      begin
                      S1 := CurNewName;
                      J := InputBox(GetString(dlFCRename),
                          GetString(dlFCRenameNew), S1, 255, 0);
                      if  (J <> cmOK) or (S1 = '') then
                        begin
                        DoSkip;
                        if not SkipRequested then
                          goto 1;
                        Break;
                        end;
                      CurNewName := S1;
                      NewTimer(Timer, 0);
                      goto 2;
                      end;
                    cmNo:
                      begin
                      DoSkip;
                      if not SkipRequested then
                        goto 1;
                      Break;
                      end;
                    else {case}
                      begin
                      CopyCancel := True;
                      ForceDispatch;
                      Break;
                      end;
                  end {case};
                  end;
                else {case}
                  begin
                  Ask := SysErrorFunc(Opened,
                         Byte(CurNewName[1])-65);
                  if Ask = 1 then
                    goto lRetryToReset;
                  NoWrite;
                  Break;
                  end;
              end {case};
              end
            else { not AdvCopy }
              begin
              ClrIO;
              FileMode := $40;
              lResetFile(WriteStream, 1);
              end;

            if InOutRes = 0 then
              begin
lbStartCheck:
              case CopyMode of
                cpmOverwrite:
                  goto DoRewrite;
                cpmAppend:
                  goto DoAppend;
                cpmResume:
                  begin
                  goto DoAppend;
                  end;
                cpmSkipAll:
                  begin
                  Info.Write(2, GetString(dlFC_Exists));
                  Close(WriteStream.F);
                  DoSkip;
                  if not SkipRequested then
                    goto 1;
                  Break;
                  end;
                cpmRefresh:
                  begin
                  GetFtime(WriteStream.F, A);
                  if A >= P.Date then
                    begin
                    Info.Write(2, GetString(dlFC_Older));
                    Close(WriteStream.F);
                    DoSkip;
                    if not SkipRequested then
                      goto 1;
                    Break;
                    end;
                  end;
                else {case}
                  begin
                  ClrIO;
                  Close(WriteStream.F);
                  ClrIO;
                  GetFTimeSizeAttr(CurNewName, A, BB, ExAttr);
                  if DosError <> 0 then
                    begin
                    NoWrite;
                    Break;
                    end;
                  case Overwrite(CurNewName, BB, P.Size, A,
                     P.Date) of
                    cmSkip:
                      begin
                      DoSkip;
                      if not SkipRequested then
                        goto 1;
                      Break;
                      end;
                    cmOK:
                      begin
                      S1 := CurNewName;
                      J := InputBox(GetString(dlFCRename),
                          GetString(dlFCRenameNew), S1, 255, 0);
                      if  (J <> cmOK) or (S1 = '') then
                        begin
                        DoSkip;
                        if not SkipRequested then
                          goto 1;
                        Break;
                        end;
                      CurNewName := S1;
                      NewTimer(Timer, 0);
                      goto 2;
                      end;
                    cmNo:
                      goto DoAppend;
                    cmYes:
                      goto DoRewrite;
                    else {case}
                      begin
                      CopyCancel := True;
                      Break;
                      end;
                  end {case};
                  end;
              end {case};
              end;
            end;
          if P.Eof and (eoAppend or eoResume) <> 0 then
            begin
DoAppend:
            FileMode := $42;
            lResetFile(WriteStream, 1);
            J := IOResult;
            case J of
              0:
                begin
                ExAttr := $FD00;
                Seek(WriteStream.F, FileSize(WriteStream.F));
                Wrote := FileSize(WriteStream.F);
                end;
              2:
                goto DoRewrite;
              5:
                begin
                if ExAttr = $FFFF then
                  begin
                  ClrIO;
                  lGetFAttr(WriteStream, ExAttr);
                  if DosError = 0 then
                    TrySetArch
                  end
                else
                  TrySetArch;
                if CheckI24Abort then
                  Break;
                ExAttr := ExAttr or $FE00;
                if (P.Eof and eoResume) <> 0 then
                  ExAttr := $FF00;
                lResetFile(WriteStream, 1);
                if IOResult = 0 then
                  Seek(WriteStream.F, FileSize(WriteStream.F));
                end;
            end {case};
            if (P.Eof and eoResume) <> 0 then
              ExAttr := $FF00;
            end
          else
            begin
DoRewrite:
            ClrIO;
            RewriteWriteStrem;
            if CheckI24Abort then
              Break;
            if  (InOutRes = 5) then
              begin
              ClrIO;
              if ExAttr = $FFFF then
                begin
                lGetFAttr(WriteStream, ExAttr);
                if DosError = 0 then
                  TrySetArch;
                end
              else
                TrySetArch;
              if CheckI24Abort then
                Break;
              RewriteWriteStrem;
              end;
            end;

          if CheckI24Abort then
            Break;
          Opened := IOResult;
          if Opened <> 0 then
            begin
            if  (Opened = 206) or (Opened = 123) then
              begin
              if Opened = 206 then
                LongNameWarn := GetString(dlCE_Filename_Exced_Range)
              else
                LongNameWarn := GetString(dlCE_Filename_Illegal);
              I_LW := Pos('%', LongNameWarn);
              if I_LW > 0 then
                begin
                LongNameWarn[I_LW] := UpCase(CurNewName[1]);
                LongNameWarn[I_LW+1] := ':'
                end;
              case MessageBox(^C+LongNameWarn+^M^C+
                GetString(dlFCRename)+' ?', nil,
                 mfError+mfYesButton+mfNoButton+mfCancelButton) of
                cmYes:
                  begin
                  S1 := CurNewName;
                  J := InputBox(GetString(dlFCRename),
                      GetString(dlFCRenameNew), S1, 255, 0);
                  if  (J <> cmOK) or (S1 = '') then
                    begin
                    DoSkip;
                    if not SkipRequested then
                      goto 1;
                    Break;
                    end;
                  CurNewName := S1;
                  NewTimer(Timer, 0);
                  goto 2;
                  end;
                cmNo:
                  Break;
                else {case}
                  begin
                  CopyCancel := True; {instead of NoWrite}
                  ForceDispatch;
                  Break;
                  end;
              end {case};
              end
            else
              Ask := SysErrorFunc(Opened,
                   Byte(CurNewName[1])-65);
            if Ask = 1 then
              goto DoRewrite;
            NoWrite;
            Break;
            end;
          end;
lbStartWrite:
        ClrIO;
        Dispatch;
        if CopyCancel then
          Break;
        if CopyOptions and cpoVerify <> 0 then
          SeekPos := FilePos(WriteStream.F);
        BlockWrite(WriteStream.F, MemBuf^[MemBufPos], P.len, J);
        IOR := IOResult;

        if not Abort and (CopyOptions and cpoVerify <> 0) and (J > 0)
        then
          begin
          
          osdep.SysDiskReset;
          

          BufCrc := GetCrc(MemBuf^[MemBufPos], P.len);

          Seek(WriteStream.F, SeekPos);
          ClrIO;
          BlockRead(WriteStream.F, MemBuf^[MemBufPos], P.len, J);

          if CheckI24Abort then
            Break;

          if  (IOResult <> 0) or
              (J <> P.len) or
              (GetCrc(MemBuf^[MemBufPos], P.len) <> BufCrc)
          then
            begin
            ForceDispatch;
            MessageBox(GetString(dlFCVerifyFailed), nil,
               mfError+mfOKButton);
            CopyCancel := True;
            Break;
            end;
          end;
        inc(MemBufPos, P.len);

        //Dispatch;
        if Abort or CopyCancel then
          Break;
        Wrote := Wrote+J;
        ToWrite := ToWrite+J;

        if GrdClick then
          begin
          WriteProgress;
          GrdClick := False;
          WPWas := False
          end
        else
          WPWas := True;

        if  (J <> P.len) or (IOR <> 0) then
          begin
          CopyCancel := True;
          ForceDispatch;
          if  (CopyPrn) or
              (IOR = 5) or
              (SysDiskSizeLongX(@PathBuffer) > P.Size)
          then
            NoWrite
          else
            ErrMsg(dlFBBDiskFull2);
          Break;
          end;
        if P.Eof and eoEnd <> 0 then
          begin
          WriteProgress;
          WPWas := False;
          SetDateAttr;
          if  (P.Owner <> nil) then
            begin
            P.Owner.Attr := P.Owner.Attr or Copied;
            if  (SourcePanel <> nil) then
              Message(SourcePanel, evCommand, cmCopyUnselect, P.Owner);
            if  (P.Owner.DIZ <> nil) and
                (CopyOptions and cpoDesc <> 0)
            then
              begin
              Info.Write(6, GetString(dlExportingDIZ));
              ExportDiz(nil, GetName(CurNewName), P.Owner.DIZ, CopyDir);
              end;
            end;
          {JO EAs - files}
          
          {Cat SAs - files}
          
          if CopyOptions and cpoFromTemp <> 0 then
            RemoveFromTemp(P.Owner);
          if CopyOptions and cpoMove <> 0 then
            {move of selected; via F6 on a file we do not get here. }
            begin
            Info.Write(6, GetString(dlDeletingSource));
            DeleteDiz(P.Owner);
            EraseFile(CurOldName);
            end;
          end;
        end;
    FreeDisk := -1;
    CopyQueue.FreeAll;
    MemBufPos := 0;
    end { MaxWrite };

  procedure CopyFile(const FName, AddDir: String; Own: PFileRec;
       ln: TSize; Dtt: LongInt; Attr: Word);
    label 1;
    var
      P: TLine;
      A, BB, WW: LongInt;
      Rd: TSize;
      I, J: Word;
      FFF: Boolean;
      Was: TSize;
      EOF: Byte;
      NName, S1, S2: String;
      SR: lSearchRec;
      PS: array[1..2] of Pointer;
      DEr: Boolean;
      Drive: Byte;
      D: TDialog; {John_SW}{process locked files}
      R: TRect;   {John_SW}
      S: String;  {John_SW}

    procedure RenameFile;
      var
        F: lFile;
        W: Word;
        SR: lSearchRec;
      begin
      DosErrorCode := 0;
      RnFl(S1, S2);
      if DosErrorCode = 17 {NOT_SAME_DEVICE} then
        Exit;  { AK155 14.03.2006 actually code 17
          I only managed to get under OS/2 }
      if DosErrorCode in [5, 80, 183] then
          { AK155 14.03.2006
            Code 80 (FILE_EXISTS) happens, for example, under NT 4 when
          "renaming" between actually different network paths,
          when the file exists on the target device. If it is deleted,
          then "renaming" succeeds, though actually it is copy
          and delete. Whether that is good is unclear, because a
          system function runs independently of DN settings.
            And when "renaming" between directories of one disk under NT
          we get code 183 (ALREADY_EXISTS). Interestingly, what is
          the deep difference between FILE_EXISTS and ALREADY_EXISTS?
            Under OS/2 code 183 sort of does not exist, but when the name matches on
          a network Windows disk we get 183 even under OS/2. }
        begin
        lAssignFile(F, S2);
        ClrIO;
        lSetFAttr(F, Archive);
        ClrIO;
        lEraseFile(F);
        RnFl(S1, S2);
        end;
      if DosErrorCode in [5, 183] then
        begin {AK155 The meaning of this block is unclear to me }
        lAssignFile(F, S1);
        lGetFAttr(F, W);
        lSetFAttr(F, Archive);
        ClrIO;
        RnFl(S1, S2);
        lSetFAttr(F, W);
        ClrIO;
        end;
      if not (DosErrorCode in [0, 18]) then
        begin
        ForceDispatch;
        MessFileNotRename(S1, S2, DosErrorCode);
        CopyCancel := True;
        end;
      end { RenameFile };

    procedure DoRename;
      var
        A: array[0..10] of PString;
        I, J: Integer;
      begin
      for I := 0 to Min(10, Info.Lines.Count-1) do
        begin
        A[I] := Info.Lines.At(I);
        Info.Lines.AtPut(I, nil);
        end;
      Info.Write(2, Cut(FName, 40));
      Info.Write(4, GetString(dlFC_To));
      Info.Write(6, Cut(NName, 40));
      //Dispatch;
      if not CopyCancel then
        RenameFile;
      if DosErrorCode = 17 {NOT_SAME_DEVICE} then
        Exit;
      if not CopyCancel and (Own <> nil) then
        begin
        Own^.Attr := Own^.Attr or Copied;
        if  (Own^.DIZ <> nil) and
            (CopyOptions and cpoDesc <> 0)
        then
          begin
          Info.Write(6, GetString(dlExportingDIZ));
          ExportDiz(@Own^.FlName, GetName(NName), Own^.DIZ, CopyDir);
          if  (CopyOptions and cpoMove <> 0) and
              (FMSetup.Options and fmoPreserveDesc = 0)
          then
            DeleteDiz(Own);
          end;
        {no EA copying should be inserted here}

        
        Own^.FlName[False] := GetName(lfGetShortFileName(NName));
        
{!RLN}        CopyShortString(GetName(NName), Own^.FlName[True]);
        //         ReplaceLongName(Own, (NName));
   { This is in case we are standing right on this name.
   So that when the directory is reread the cursor goes to the new name,
   and does not stay at the old position }
        if  (SourcePanel <> nil) then
          Message(SourcePanel, evCommand, cmCopyUnselect, Own);
        ToWrite := ToWrite+ln;
        ToRead := ToRead+ln;
        end;
      Info.DrawView;
      for I := 0 to Min(10, Info.Lines.Count-1) do
        Info.Lines.AtReplace(I, A[I]);
      end { DoRename };

    label
      NoRename, FileRead, PrepareResume, PrepareSkip, PrepareAppend;

    function ReadCount: String;
      begin
      ReadCount := FStr(ToRead)+GetString(dlBytes)+GetPercent(ToRead)
        +GetString(dlFC_WasRead);
      SetTitle(GetPercent((ToWrite+ToRead) div 2)+GetString(dlCopied));
      end;

    procedure ReadProgress;
      var
        CT: String;
      begin
      Info.Write(2, StrGrd(ln, ReadPos, Info.Size.X-6, RevertBar));
      Info.Write(3, ReadCount);
      CT := CopyTime;
      if CT <> '' then
        Info.Write(9, CT); {John_SW 30-06-2005}
      end;

    begin { CopyFile }
    {JO: !!! do not copy files found in archives  }
    {if PathFoundInArc(FName) then Exit;}
    {/JO}
    if CopyPrn then
      begin
      NName := CopyDir;
      while NName[Length(NName)] = DnSep do
        SetLength(NName, Length(NName)-1);
      S1 := lFExpand(FName); {Cat}
      S2 := lFExpand(NName); {Cat}
      S2[1] := '';
      {Cat: now the name starts with ":\", so
        further on the procedure will think that the destination file (which is actually
        a device) is on another disk, so
        instead of rename, copy with
        source deletion will be used. However, there is no full guarantee that the device
        name with a full path, and moreover with such a drive letter,
        will be accepted normally by the system}
      end
    else
      begin
      if AddDir = '' then
        NName := MkName(GetName(FName))
      else
        NName := MakeNormName(AddDir, GetName(FName));

      NName := MakeNormName(CopyDir, NName);
1:
      S1 := lFExpand(FName);
      S2 := lFExpand(NName);
      if S1 = S2 then
        begin
        {--- start -------- Eugeny Zvyagintzev ---------------------------------}
        {This 2 line was commented to allow DN display error message            }
        {during _move_ file to itself                                           }
        {Before this comment DN displayed error message only                    }
        {during _copy_ file to itself                                           }
        {            if CopyOptions and cpoMove = 0 then
               begin}
        {--- finish -------- Eugeny Zvyagintzev --------------------------------}
        if CopyQueue.Count > 0 then
          MaxWrite;
        if CopyCancel then
          Exit;
        ForceDispatch;
        MessageBox(^C+GetString(dlFile)+' '+FName+GetString(dlFCItself),
           nil,
          mfError+mfOKButton);
        CopyCancel := True;
        {             end;} {Eugeny Zvyagintzev}
        Exit;
        end;
      end;

    Was := 0;
    ClrIO;
    lAssignFile(ReadStream, FName);
    if DriveOf(S1) in CD_Drives then
      Attr := Attr and not ReadOnly;

    FileMode := $40;
    lResetFile(ReadStream, 1);
    ReadPos := 0;

    if Abort then
      begin
      ClrIO;
      if CopyQueue.Count > 0 then
        MaxWrite;
      CopyCancel := True;
      Exit;
      end;

    RC := IOResult;
    if RC <> 0 then
      begin
      ClrIO;
      if CopyQueue.Count > 0 then
        MaxWrite;
      if CopyCancel then
        Exit;
      ForceDispatch;
{--- start -------- Eugeny Zvyagintzev and Max Piwamoto 04-02-2005 ----}
      If SkipAllBad Then Exit;
      D := TDialog(LoadResource(dlgSkipBadFile));
      D.Options := D.Options or ofCentered;
      S:=Cut(FName,52);
      R.A.X:=1; R.A.Y:=3; R.B.X:=53; R.B.Y:=4;
      D.Insert(TStaticText.Create(R,^C+S));
      Case Desktop.ExecView(D) Of
       cmOK: Goto 1;
       cmYes: begin SkipAllBad := True; Exit; end;
       cmNo: Exit;
       cmCancel: begin CopyCancel := True; Exit; end;
      End;
{--- finish ------- Eugeny Zvyagintzev and Max Piwamoto 04-02-2005 ----}
      end;
    Rd := 0;
//    EOF := eoStart or eoCheck*Byte(CopyMode >= cpmAppend);
    {--- start -------- Eugeny Zvyagintzev -----------------------------------}
    {This 3 line was commented to prevent DN first coping files to buffer     }
    {and _then_ check for file already exists                                 }
    {Now DN will first check for file exists                                  }

    {if (CopyMode >= cpmAppend) and (CopyOptions and cpoMove <> 0)  and
         (S1[1] = S2[1]) then
        begin}
    {--- finish -------- Eugeny Zvyagintzev ----------------------------------}

    {AK155 so that files and directories can be copied to nul and other
devices, 3 CopyPrn analyses are inserted a bit below. }
    ClrIO;
    EOF := eoStart or eoCheck;
    if not CopyPrn then
      {AK155 no need to look for files on a device}
      begin
      lFindFirst(S2, AnyFileDir, SR); {JO}
      DEr := (DosError <> 0);
      lFindClose(SR);
      end;
    if CopyPrn {AK155} or not DEr then
      begin
      EOF := eoStart;
      Was := SR.FullSize;
      if not CopyPrn {AK155: for a single file} and (SR.SR.Attr and
           Directory <> 0)
      then
        begin
        if CopyQueue.Count > 0 then
          MaxWrite;
        if CopyCancel then
          Exit;
        ForceDispatch;
        MessageBox(GetString(dlFCNotOverDir)+Cut(S2, 40), nil,
           mfError+mfOKButton);
        Exit;
        end;
      case CopyMode of
        cpmAskOver:
NoRename:
            case Overwrite(NName, SR.FullSize, ln, SR.SR.Time, Dtt) of
              cmSkip:
                goto PrepareSkip;
              cmOK:
                begin
                ClrIO;
                Close(ReadStream.F);
                ClrIO;
                if InputBox(GetString(dlFCRename),
                       GetString(dlFCRenameNew),
                    NName, 255, 0) <> cmOK
                then
                  goto NoRename;
                NewTimer(Timer, 0);
                goto 1;
                end;
              cmNo:
                goto PrepareAppend;
              cmSave:
                goto PrepareResume;
            end {case};
        cpmRefresh:
          if Dtt <= SR.SR.Time then
            goto PrepareSkip;
        cpmSkipAll:
          begin
PrepareSkip:
          Info.Write(1, GetString(dlFC_Reading)+Cut(FName, 40));
          Info.Write(2, GetString(dlFC_Exists));
          ClrIO;
          Close(ReadStream.F);
          ClrIO;
          Exit;
          end;
        cpmAppend:
PrepareAppend:
          EOF := EOF or eoAppend;
        cpmResume:
          begin
PrepareResume:
          Rd := SR.FullSize;
          if Rd >= FileSize(ReadStream.F) then
            goto PrepareSkip;
          EOF := EOF or eoResume;
          ReadPos := Rd;
          Seek(ReadStream.F, CompToFSize(Rd));
          end;
      end {case};
      end;
    {       end;} {Eugeny Zvyagintzev}
    if  (CopyOptions and cpoMove <> 0) and (EOF and eoAppend = 0) and
        (S1[1] = S2[1])
          {AK155: for network paths '\'='\'. But maybe that is fine.}
    then
      begin
      ClrIO;
      Close(ReadStream.F);
      ClrIO;
      DoRename;
      if DosErrorCode <> 17 {NOT_SAME_DEVICE} then
        Exit;
      { What seemed one device turned out to be different ones, and move
       failed. Try another way: copy and delete.}
      CopyCancel := False;
      lResetFile(ReadStream, 1);
      end;
    Info.Write(1, GetString(dlFC_Reading)+Cut(FName, 40)+' ');
    Info.Write(2, Strg(GlyphChar(glShadeMedium), Info.Size.X-6));
    Info.Write(3, ReadCount);
    //Dispatch;
    GrdClick := False;
    {Info.DrawView;}
    ln := FileSize(ReadStream.F); {-$VOL}
    P := nil;
    repeat
      if CopyQueue.Count > 400 then
        MaxWrite; {John_SW  06-11-2002}
      SkipRequested := False;
      WW := Min(ReadLen, MemBufSize-MemBufPos);
      if WW > ln-Rd then
        WW := Round(ln-Rd);
      P := TLine.Create(WW, Own, FName, NName, ln, Dtt, Attr, EOF);
      if P = nil then
        begin { buffer exhausted }
        ReadProgress;
        MaxWrite;
        if SkipRequested then
          Break;
        Continue
        end;
      J := 0;

FileRead:
      Dispatch;
      if CopyCancel then
        Break;
      if WW > 0 then
        begin
        BlockRead(ReadStream.F, MemBuf^[MemBufPos], WW, J);
        inc(MemBufPos, WW);
        end;

      {AK155}
//      {$IFNDEF DPMI32} {AK155 28.06.2007 under DPMI32 int24 does not show up }
      { Under OS/2 and Win32 the critical-error handler is not called as in DOS,
 so we must analyze the result ourselves and call the handler }
      I := IOResult;
      if I <> 0 then
        begin
        Drive := Byte('');
        if HasDriveLetter(FName) then
          Drive := Byte(FName[1]);
        SysErrStopButton := True;
        I := SysErrorFunc(I, Drive-Byte('A'));
        SysErrStopButton := False;
        if I = 1 then
          goto FileRead;
        if I = 4 then
          begin
          _Tmr.ExpireMSecs := GetCurMSec-1; // make the timer expired
          CtrlBreakHit := True;
          goto FileRead;
          end;
        CopyCancel := True;
        P.Free;
        P := nil;
        Break;
        end;
//      {$ENDIF}
      {/AK155}
      ReadPos := ReadPos+J;
      //Dispatch;
      if CopyCancel then
        Break;
      if Abort then
        begin
        ClrIO;
        if CopyQueue.Count > 0 then
          MaxWrite;
        CopyCancel := True;
        Break;
        end;
      if ReadPos >= ln then
        begin
        EOF := EOF or eoEnd;
        if P.OldName = nil then
          P.OldName := NewStr(FName);
        end;
      P.EOF := EOF;
      if WW <> J then
        begin
        {AK155 And here we ought to analyze IOResult
               and give a clear message! }
        CopyCancel := True;
        Break;
        end;

      ToRead := ToRead+J;

      //Dispatch;
      if GrdClick then
        begin
        ReadProgress;
        GrdClick := False;
        end;

      if Abort or CopyCancel then
        Break;
      CopyQueue.Insert(P);
      P := nil;
      EOF := EOF and not eoStart;
      Rd := Rd+WW;
    until CopyCancel or Abort or (Rd = ln) or System.EOF(ReadStream.F)
     or SkipRequested; {-$VOL}
    if P <> nil then
      begin
      P.Free; // jumped out via Break after Init but before Insert
      P := nil;
      end;

    SkipRequested := False;
    ClrIO;
    ReadProgress;
    Close(ReadStream.F);
    if not AdvCopy then
      MaxWrite;
    end { CopyFile };

  procedure CopyDirectory(const DirName, AddDir: String; Own: PFileRec);
    var
      SR: lSearchRec;
      P: TLine;
      L: LongInt;
    begin
    ClrIO;
    lFindFirst(DirName+DnSep+'*.*', AnyFileDir, SR); {JO}
    while (DosError = 0) and not Abort and not CopyCancel do
      begin
      SSS := MakeNormName(AddDir, SR.FullName);
      if SR.SR.Attr and Directory = 0 then
        begin
        CopyFile(DirName+DnSep+SR.FullName, Copy(AddDir,
            Length(CopyDir)+1, MaxStringLength), nil, SR.FullSize,
          SR.SR.Time, SR.SR.Attr);
        end;
      if CopyCancel or Abort then
        begin
        lFindClose(SR);
        Exit;
        end;
      ClrIO;
      lFindNext(SR);
      end;
    lFindClose(SR);
    if CopyCancel or Abort then
      Exit;
    L := 0;
    P := TLine.Create(L, Own, DirName, '', 0, 0, Directory,
           eoStart+eoDir);
    if P <> nil then
      CopyQueue.Insert(P);
    end { CopyDirectory };

  procedure MaxRead;
    var
      I: Integer;
      P: PFileRec;
      S: String;

    procedure DoCopyDirectory(P_: Pointer);
    var P: TDirName absolute P_;
      begin
      if P.CopyIt then
        CopyDirectory(P.DOld, P.DNew, P.Own)
      else if P.Own <> nil then
{!RLN}        CopyShortString(GetName(P.DOld), P.Own^.FlName[True]);
   { This is in case we are standing right on this directory. So that
   when the directory is reread the cursor goes to the new name,
   and does not stay at the old position.
     And nil happens, for example, on subdirectories when renaming
   the enclosing directory via F6 with the other panel hidden.
   By the way, then P^.OldName^ =  P^.NewName^. }
      end;

    begin
    CopyStartTime := GetCurMSec; CopyElapsedTime := 0; {John_SW 30-06-2005}
    for I := 0 to Files.Count-1 do
      begin
      P := Files.At(I);
      S := MakeNormName(P.Owner^, P.FlName[True]);
      if P.Attr and Directory = 0 then
        CopyFile(S, '', P, P.Size, PackedDate(P), P.Attr);
      if Abort or CopyCancel then
        Exit;
      end;
    if Abort or CopyCancel then
      Exit;
    if Dirs <> nil then
      Dirs.ForEach(DoCopyDirectory);
    MaxWrite;
    end { MaxRead };

  procedure DoneMemBuf;
    begin
    if MemBuf <> nil then
      begin
      FreeMem(MemBuf);
      MemBuf := nil;
      end;
    end;

  procedure MakeDirectories;
    var
      P: PFileRec;
      PD: TDirName;
      I: Integer;
      S: String;
      FrPos: Integer;
      KillDescrOf: PFlName;
      

    procedure CopyI(Dest{Target directory},
        Source{ full old name }: String;
        Name: String;  {New name}
        o: PFileRec; {here, seems, the same as in Source,
          but o=nil happens}
        CopyIt: Boolean;
        Attr: Byte);
      label 1, 2, TrueCopy;
      var
        JJ: Integer;
      var
        q: String;
        SSS: String;
        
      begin
      Info.Write(5, GetString(dlFCCheckingDirs));

      if  (not CopyPrn) and (Dest <> '') and (Dest[Length(Dest)] <> DnSep)
      then
        AddStr(Dest, DnSep);
      q := MakeNormName(Dest, Name);
      if q[Length(q)] = '.' then
        SetLength(q, Length(q)-1);
      if o = nil then
        goto 1;
      if CopyCancel then
        goto 2;
      ClrIO;
      SSS := Source;
      MakeSlash(SSS);
      if SSS = Copy(S, 1, Length(SSS)) then
        begin
        ForceDispatch;
        MessageBox(^C+GetString(dlDirectory)+' '+Cut(Source, 40)+
          GetString(erIntoItself), nil, mfError+mfOKButton);
        CopyCancel := True;
        Exit;
        end;
      SetLength(SSS, Length(SSS)-1);
      if  (o <> nil) and (CopyOptions and cpoMove <> 0)
           and (SSS[1] = q[1])
      then
        begin { Directory rename }
        ClrIO;
        RnFl(SSS, q);
        if DosErrorCode in [5, 80, 183] then
          begin {Possibly the target directory exists but is empty. Then
             it can be deleted and the rename can still be done }
          LFN.lRmDir(q);
          ClrIO;
          RnFl(SSS, q);
          end;
        if Abort then
          begin
          CopyCancel := True;
          goto 2;
          end;
        if DosErrorCode in [5, 17, 80, 183] then
          goto TrueCopy;
            { The target directory exists and is non-empty, or rename
              is impossible in principle. So we will honestly copy
              and delete. }
        CopyIt := False;
        o^.Attr := o^.Attr or Copied;
        if DosErrorCode <> 0 then
          begin
          Info.Write(5, '');
          Info.Write(2, Cut(SSS, 40));
          Info.Write(4, GetString(dlFC_To));
          Source := lFExpand(q);
          Info.Write(6, Cut(Source, 40));
          ForceDispatch;
          MessageBox(GetString(dlNotRenameDir)+Source, nil,
            mfError+mfOKButton);
          CopyCancel := True;
          Info.Write(2, '');
          Info.Write(4, '');
          Info.Write(6, '');
          Info.Write(5, GetString(dlFCCheckingDirs));
          goto 2;
          end;


(*
{! Must not copy LFN this way! Lengths may differ. Whether we need at all
 to copy the new long name - need to figure out. Seems we do not.
 This is a source-directory record, not the destination one. And the short name
 should not be copied at all but queried, because it may turn out
 completely different. So for now I am killing name transfer. Seems
 it affected nothing.
   Analyzed in more detail. This rename is completely unneeded.
 This file record is used here only to pass
 it to cmCopyUnselect, and there it only serves for name comparison. By the way,
 rare absurdity. The whole collection is scanned for a name match
 with the passed record. And since this record is one of the collection
 elements, a match happens when comparing it with itself. So
 the old name is surely fine, while the new one may perhaps lead to glitches
 if this new name matches an already existing one. And all this
 is needed only for pretty redraw of panels and footer as
 copying proceeds. And then the panel is reread anyway.}
        {$IFDEF DualName}
        o^.FlName[False] := GetName
                (lfGetShortFileName(MakeNormName(GetPath(Source), Name)));
        {$ENDIF}
        CopyShortString(MakeNormName(GetPath(Source), Name),
           o^.FlName[True]);
*)
        if SourcePanel <> nil then
          Message(SourcePanel, evCommand, cmCopyUnselect, o);
        KillDescrOf := @o^.FlName;
          { When renaming a directory the description with the old name
           must be removed }
        goto 1;
        end
      else
        begin { Directory copy }
TrueCopy:
        CopyIt := True;
        ClrIO;
        if not CopyPrn then
          begin
          CheckMkDir(q);
          if not Abort then
            JJ := SetFileAttr(q, Attr and not Directory)
          end;
        KillDescrOf := nil;
          { When copying a directory the description with the old name
            need not be removed }
        end;
      if Abort then
        begin
        CopyCancel := True;
        goto 2;
        end;
1:
      if CopyPrn then
        begin
        if Dest = '' then
          SSS := Name
        else
          SSS := Dest;
        end
      else
        SSS := q;
      
      {MessageBox('Dirs.AtInsert: ' + SSS + ' '+ Source, nil, mfOKButton);}
      Dirs.AtInsert(FrPos, TDirName.Create(Source, SSS, CopyIt, o, Attr));
      Inc(FrPos);
2:
      end { CopyI };

    { The link Source as the link Dest (a move removes Source); -1 when the system does not copy links. An error is told and stops the copy. }
    function CopyLinkOf(const Source, Dest: String): LongInt;
      begin
      Result := SysCopyLink(Source, Dest);
      if (Result = 0) and (CopyOptions and cpoMove <> 0) then
        Result := SysEraseLink(Source);
      if Result > 0 then
        begin
        ForceDispatch;
        MessageBox(^C+GetString(dlErrorWriting)+Cut(Dest, 40), nil, mfError+mfOKButton);
        CopyCancel := True;
        end;
      end;

    procedure CopyF(Dest, Source: String; CopyIt: Boolean; Attr: Byte);
      var
        SR: lSearchRec;
        Drive: Byte;
        LinkRC: LongInt;
      begin
      if Dest[Length(Dest)] = DnSep then
        SetLength(Dest, Length(Dest)-1);
      if Dest[Length(Dest)] = '.' then
        SetLength(Dest, Length(Dest)-1);
      ClrIO;
      {AK155 Why this piece is needed is not immediately clear. Seems
 all this is already done in CopyI. But actually it is needed for
 subdirectories. Of course it would be more direct to do this only for
 subdirectories, but this way is also fine - only one extra operation }
      if not CopyPrn then
        begin
        CheckMkDir(Dest);
        if not Abort then
          SetFileAttr(Dest, Attr and not Directory);
        ClrIO;
        end;
      {/AK155}
      lFindFirst(Source+DnSep+'*.*', AnyFileDir, SR); {JO}
      while (DosError = 0) and not Abort and not CopyCancel do
        begin
        if  (SR.SR.Attr and Directory <> 0) and
          {!!!} not IsDummyDir(SR.SR.Name)
        then
          begin
          { a link to a directory is copied as a link: its target is not entered (a loop of links would never end) }
          LinkRC := -1;
          if (SR.SR.Attr and SysLinkAttr <> 0) and not CopyPrn then
            LinkRC := CopyLinkOf(MakeNormName(Source, SR.FullName), MakeNormName(Dest, SR.FullName));
          if LinkRC < 0 then
            CopyI(Dest, MakeNormName(Source, SR.FullName), SR.FullName,
               nil,
              CopyIt, SR.SR.Attr)
          end
        else
          begin
          ToDo := ToDo+SR.FullSize;
          ToDoCopy := ToDoCopy+SR.FullSize;
          if SR.FullSize > 0 then
            begin
            ToDoClusCopyTemp := SR.FullSize div BytesPerCluster;
            ToDoClusCopy := ToDoClusCopy+
                ( {Round}(ToDoClusCopyTemp)+
                Byte( {Round}(ToDoClusCopyTemp)-ToDoClusCopyTemp <> 0)
                )*BytesPerCluster;
            end;
          end;
        ClrIO;
        //Dispatch;
        if not CopyCancel then
          lFindNext(SR);
        end;
      {AK155 If when copying a directory or selected files
 a read error arises, a message must be shown, not
 simply silently stop copying. But the loop ends normally
 when there are no more files, and under all
 OSes DosError=18 then. Error 3 arises on a directory
 that was successfully moved as a whole.
 }
      if  (DosError = 18 {ERROR_NO_MORE_FILES}) or
          (DosError = 3 {PATH_NOT_FOUND})
      then
        DosError := 0;
      if DosError <> 0 then
        begin
        Drive := Byte('');
        if HasDriveLetter(Source) then
          Drive := Byte(Source[1]);
        SysErrorFunc(DosError, Drive-Byte('A'));
        {Abort will be set then}
        end;
      {/AK155}
      lFindClose(SR);
      end { CopyF };

    label 1, 2;

    function NoCheck(P_: Pointer): Boolean;
    var P: TDirName absolute P_;
      begin
      Inc(FrPos);
      NoCheck := not P.Check;
      end;

    function IsNetworkPath(const Path: String): Boolean; {KV}
      begin
      IsNetworkPath := ((Length(Path) > 2) and (Path[1] = DnSep) and
             (Path[2] = DnSep));
      end;

    label
      TryGetInfo;
    begin { MakeDirectories }
    if not CopyPrn then
      begin
      S := CopyDir;
      Inhr := CreateDirInheritance(S, True);
      if Inhr = 0 then
        Inhr := Length(S);
      Drv := Byte(DriveOf(S))-64;
      Red := [DriveOf(S)];
      end;

    if CopyPrn or (S[1] = DnSep) then
      FreeSpc := 0 // device or network address
    else
      begin
TryGetInfo:
      if SysDiskSizeLongX(@PathBuffer) < 0 then
        case SysErrorFunc(21, Drv-1) of
          1:
            goto TryGetInfo;
          3:
            Exit;
        end {case};
      end {if};
    Dirs := TCollection.Create(10, 10);   { of TDirName: FreeItem of TCollection frees them }
    for I := 0 to Files.Count-1 do
      begin
      P := Files.At(I);
      if (P.Attr and Directory <> 0) and (P.Attr and SysLinkAttr <> 0) and not CopyPrn
        and (CopyLinkOf(MakeNormName(P.Owner^, P.FlName[True]), MakeNormName(CopyDir, MkName(P.FlName[True]))) >= 0)
      then
        { a link to a directory: copied (moved) as a link }
      else if P.Attr and Directory <> 0 then
        begin
        FrPos := Dirs.Count;
        
        CopyI(CopyDir, MakeNormName(P.Owner^, P.FlName[True]),
            MkName(P.FlName[True]), P, True, P.Attr and $3FFF);

        if not (Abort or CopyCancel)
          and (P.DIZ <> nil)
          and (CopyOptions and cpoDesc <> 0)
        then
          begin
          
            begin
            ExportDiz(KillDescrOf, MkName(P.FlName[True]), P.DIZ, CopyDir);
//            {directories!!!}ImportDIZ(LowStrg(P^.FlName[CondLfn]),
//                 MkName(P^.FlName[CondLfn]), P^.DIZ, P^.Owner)
            end
            
          end;
        ;
        end
      else
        begin
        ToDo := ToDo+P.Size;
        if  (CopyDir[1] <> P.Owner^[1]) or (CopyOptions and cpoMove = 0)
        then
          begin
          ToDoCopy := ToDoCopy+P.Size;
          if P.Size > 0 then
            begin
            ToDoClusCopyTemp := P.Size div BytesPerCluster;
            ToDoClusCopy := ToDoClusCopy+
                ( {Round}(ToDoClusCopyTemp)+
                Byte( {Round}(ToDoClusCopyTemp)-ToDoClusCopyTemp <> 0)
                )*BytesPerCluster;
            end;
          end;
        end;
      if CopyCancel then
        Break;
      end;
1:
    repeat
      FrPos := -1;
      if Abort then
        Break; {AK155 Abort may be set by SysErrorFunc}
      PD := Dirs.FirstThat(NoCheck);
      if PD = nil then
        Break;
      CopyF(PD.DNew, PD.DOld, PD.CopyIt, PD.Attr and $3FFF0);
      {JO EAs - dirs }
      if PD.CopyIt then
        begin
        
        {Cat SAs - dirs }
        
        end;
      PD.Check := True;
    until False;
    Info.Write(5, '');
    end { MakeDirectories };

  procedure __Remove;
    var
      RRC: TStringCollection;

    procedure DoRemove(P_: Pointer);
    var P: PFileRec absolute P_;

      procedure MakeMark(P_: Pointer);
      var P: PFileRec absolute P_;
        begin
        if  (Copy(P^.Owner^, 1, Length(SSS)) = SSS) then
          P^.Attr := P^.Attr or Marked;
        end;

      begin
      {Cat: previously the next piece ran only for successfully copied
      directories, i.e. (P^.Attr and Copied <> 0), but all should be reread}
      if P^.Attr and Marked = 0 then
        begin
        SSS := CnvString(P^.Owner);
        if SSS[Length(SSS)] = DnSep then
          SetLength(SSS, Length(SSS)-1);
        if Copy(CopyDir, 1, Length(SSS)) = SSS then
          Inhr := 0;
        RRC.Insert(NewStr(SSS));
        if P^.Attr and Directory <> 0 then
          Red := Red+[DriveOf(SSS)];
        Files.ForEach(MakeMark);
        end;
      end { DoRemove };

    procedure DoReread(P_: Pointer);
    var P: PString absolute P_;
      begin
      RereadDirectory('>'+P^); //'>' - flag for rereading subdirectories
      end;

    begin { __Remove }
    RRC := TStringCollection.Create($10, $8, False);
    Files.ForEach(DoRemove);
    RRC.ForEach(DoReread);
    RRC.Free;
    end { __Remove };

  procedure DoReset(P_: Pointer);
  var P: PFileRec absolute P_;
    var
      s: String;
      i: Integer;
    begin
    CD_Drives := CD_Drives+[DriveOf(P^.Owner^)];
    if  (CopyOptions and cpoDesc) <> 0 then
      GetDiz(P);
    end { DoReset };

  label 1;

  var
    
    Flush: Boolean;
    
    DrvC: Integer;
    DriveChar: String[1];

    { ***************** }
    { *** FilesCopy *** }
    { ***************** }
  label qqqq;
  begin { FilesCopy }
  SSS := CopyDir;
  MakeNoSlash(SSS);
  Strings.StrPCopy(@PathBuffer, SSS);
  BytesPerCluster := GetBytesPerCluster(@PathBuffer);
  if BytesPerCluster = 0 then
    BytesPerCluster := 512;
  
  CondLfn := (FMSetup.Options and fmoDescrByShortNames) = 0;
  

qqqq:
  Dirs := nil;
  AdvCopy := (not CopyPrn)
       and ((SystemData.Options shl 3) and ossAdvCopy <> 0);
  NewTimer(Timer, 0);
  NewTimer(_Tmr, 0);
  GrdClick := True;
  FreeDisk := -1;
  CopyCancel := False;
  SkipAllBad := False;
  ReD := [];
  CD_Drives := [];
  ToRead := 0;
  ToWrite := 0;
  ToDo := 0;
  ToDoCopy := 0;
  ToDoClusCopy := 0;
  R := TRect.Create(0, 0, 60, 15); {John_SW 30-06-2005}
  Info := TWhileView.Create(R);
  if CopyOptions and cpoMove <> 0 then
    Info.Top := GetString(dlFCMove)
  else
    Info.Top := GetString(dlFCCopy);
  Desktop.Insert(Info);
  Files.ForEach(DoReset);
  if  ( (SystemData.Options shl 3) and ossRemoveCD_RO <> 0)
  then
    begin
    for C := 'A' to 'Z' do
      if  (C in CD_Drives)
        and ((GetDriveTypeNew(C) <> dtnCDRom) // so as not to spin the disk for nothing
//JO: here what matters is checking the filesystem type,
//    not the device type, because specifically on CDFS all files have
//    the "read-only" attribute which must be cleared when copying,
//    while for UDF for example there is no such need
             or (GetFSString(C) <> 'CDFS')) then
          CD_Drives := CD_Drives-[C];
    end
  else
    CD_Drives := [];
  MakeDirectories;
  if Abort then
    CopyCancel := True;
  if CopyCancel then
    goto 1;
  InitMemBuf;
  if MemBuf = nil then
    begin
    Application.OutOfMemory;
    goto 1;
    end;
  CopyQueue := TLineQueue.Create(250, 100);
  Info.Bottom := GetString(dlFC_Total)+FStr(ToDo)+GetString(dlBytes);
  Info.DrawView;
  DrvC := Drv+64;
  if  (CopyOptions and cpoCheckFree <> 0) and (Files.Count > 1)
    and (ToDoClusCopy > SysDiskFreeLongX(@PathBuffer))
    and (MessageBox(GetString(erNoDiskSpacePre),
        @DrvC, mfYesButton+mfNoButton) <> cmYes)
  then
    CopyCancel := True;
  if CopyCancel then
    goto 1;
  MaxRead;
  if Abort or CopyCancel then
    begin
    ClrIO;
    if (StopDlgData and 1) <> 0 then
      begin
      CopyCancel := False; // so that writing happens
      MaxWrite;
      end;
    Close(ReadStream.F);
    ClrIO;
    Truncate(WriteStream.F);
    if (IOResult = 0) and ((StopDlgData and 2) = 0) then
      begin
      Close(WriteStream.F);
      lEraseFile(WriteStream);
      end
    else
      SetDateAttr;
    end
  else if (FMSetup.Options and fmoBeep <> 0) and
      (ElapsedTime(Timer) > 30*1000)
  then
    BeepAftercopy;
  CopyQueue.Free;
  CopyQueue := nil;
  DoneMemBuf;
1:
  
  Flush := ((SystemData.Options shl 3) and ossFlushDsk <> 0);
  if Flush then
    begin
    Info.ClearInterior;
    Info.Write(5, GetString(dlFlushingBuffers)+'...');
    end
  else
    
    Info.Free;

  if Dirs <> nil then
    Dirs.Free;
  Dirs := nil;
  if CopyOptions and cpoMove <> 0 then
    __Remove;
  for C := 'A' to 'Z' do
    if C in ReD then
      begin
      SSS := C;
      GlobalMessage(evCommand, cmRereadTree, @SSS);
      end;
  SSS := Copy(lFExpand(CopyDir), 1, InhR);
  if  (InhR <> 0) and RR then
    RereadDirectory('>'+SSS); //'>' - flag for rereading subdirectories
  if SourcePanel <> nil then
    begin
    { Nil happens, for example, when unpacking via F4 from an archive
    panel. Probably just putting such a condition is wrong, and we ought
    to reach the footer and redraw it, but I could not
    reach it. 17.01.2005}
    {AK155 10.01.2005 After panel redraw during group
operations started being done on a timer, a problem arose of drawing
the results of what happened after the last timer tick.
}
    SourcePanel.DrawView;
    TFilePanelRoot(SourcePanel).InfoView.DrawView;
    end;
  
  if Flush then
    begin
    SysDiskReset;
    Info.Free;
    end;
  
  end { FilesCopy };
{-DataCompBoy-}

const
  ccCopyMode: Byte = cpmAskOver;
  ccCopyOpt: Byte = 0;

var
  DialogLabel: String;
  DialogMoveMode: Boolean;

  {-DataCompBoy-}
function CopyDialog(var CopyDir: String; var Mask: String; var CopyOpt: Word; var CopyMode: Word; var CopyPrn: Boolean; MoveMode: Boolean; Files: TCollection; FromTemp: Byte; SourcePanel: TView; Link: Boolean): Boolean;
  var
    PF: PFileRec;
    D: TDialog;
    P, P1, P2: TView; {JO: P2 - checkboxes}
    R: TRect;
    S, S1, S4: String;
    DT: record
      S3: String;
      WW: Word;
      WW1: Word;
      end;
    Nm: String;
    Xt: String;
    hFile: LongInt;
    SR: lSearchRec;
    Idx: TDlgIdx;
    I, l: Integer;
    SSS: String;
    C: Char;
    DEr: Boolean;

    IDDQD: record
      Fl, dr: LongInt;
      end;

  procedure DoCalc(P_: Pointer);
  var P: PFileRec absolute P_;
    begin
    with IDDQD do
      if P^.Attr and Directory <> 0 then
        Inc(dr)
      else
        Inc(Fl)
    end;

  procedure PrepareDialog(P: TDialog);
    var
      R: TRect;
    begin
    with P do
      begin
      if DialogMoveMode then
        begin
        DisposeStr(Title);
        Title := NewStr(GetString(dlFCMove));
        end;
      R := TRect.Create(2, 1, Size.X-3, 2);
      Insert(TLabel.Create(R, DialogLabel, DirectLink[1]));
      {JO}
      if  (FMSetup.Options and fmoAlwaysCopyDesc = 0) and
          (SourcePanel <> nil) and
          (TFilePanelRoot(SourcePanel).Drive <> nil) and
          (TFilePanelRoot(SourcePanel).Drive.DriveType = dtDisk) and
          (TFilePanelRoot(SourcePanel).
            PanSetup.Show.ColumnsMask and psShowDescript = 0)
      then
        TCheckBoxes(DirectLink[2]).SetButtonState(cpoDesc, False);
      {/JO}
      end;
    end;

  begin { CopyDialog }
  CopyDialog := False;
  DialogMoveMode := MoveMode;
  DT.WW := ccCopyMode;
  DT.WW1 := ccCopyOpt;
  DT.WW1 := DT.WW1 and not cpoMove;
  if MoveMode and (FromTemp <> 1) then
    DT.WW1 := DT.WW1 or cpoMove;
  if  (FMSetup.Options and fmoAlwaysCopyDesc <> 0) then
    DT.WW1 := DT.WW1 or cpoDesc; {JO}
  if MoveMode then
    S := GetString(dlFCMove1)
  else
    S := GetString(dlFCCopy1);
  DT.S3 := '';
  if Files.Count = 1 then
    begin
    PF := Files.At(0);
    S1 := PF^.FlName[True];
    I := 1;
    while I <= Length(S1) do
      begin
      if S1[I] = '~' then
        begin
        System.Insert(#0, S1, I);
        Inc(I);
        end;
      Inc(I);
      end;
    if MoveMode then
      DT.S3 := S1;
    if PF^.Attr and Directory = 0 then
      S1 := GetString(dlDIFile)+' '+S1
    else
      S1 := GetString(dlDIDirectory)+' '+S1;
    end
  else
    begin
    IDDQD.dr := 0;
    IDDQD.Fl := 0;
    Files.ForEach(DoCalc);
    if IDDQD.dr = 0 then
      S1 := ItoS(IDDQD.Fl)+' '+#0+GetString(dlDIFiles)+#0
    else if IDDQD.Fl = 0 then
      S1 := ItoS(IDDQD.dr)+' '+#0+GetString(dlDirectories)+#0
    else
      FormatStr(S1, GetString(dlFilDir), IDDQD);
    end;
  if MoveMode then
    DialogLabel := S+S1+GetString(dlFCMove2)
  else
    DialogLabel := S+S1+GetString(dlFCCopy2);
  if MoveMode and (Files.Count = 1)
  then
    DT.S3 := PFileRec(Files.At(0))^.FlName[True]
  else
    GlobalMessageL(evCommand, cmPushName, hsFileCopyName);
  S4 := '';
  if SourcePanel <> nil then
    Message(SourcePanel.Owner, evCommand, cmPushFirstName, @S4);
  if CopyDirName <> '' then
    S4 := CopyDirName;
  if MoveMode and (S4 = cTEMP_) then
    S4 := ''; // Move to TEMP: never happens
  CopyDirName := '';
  if S4 <> '' then
    begin
    if  (Files.Count = 1) and
      HasDrives and IsQualified(S4) and (Length(S4) > 2)
        and (PFileRec(Files.At(0))^.Attr and Directory = 0)
    then
      S4 := MakeNormName(S4, PFileRec(Files.At(0))^.FlName[True]);
    
    HistoryAdd(hsFileCopyName, GetName(S4));
    end
  else if (Files.Count = 1) then
    begin
    S4 := PFileRec(Files.At(0))^.FlName[True];
    
    HistoryAdd(hsFileCopyName, S4);
    end;
  DT.S3 := S4;
  with DT do
    begin
    if HasDriveLetter(DT.S3) then
      C := S3[1]
    else
      C := GetCurDrive;
    {Cat:warn there may be problems with network paths}
    if  SystemData.Drives[C] and ossVerify <> 0  then
      WW1 := WW1 or cpoVerify
    else
      WW1 := WW1 and not cpoVerify;
    if SystemData.Drives[C] and ossCheckFreeSpace <> 0 then
      WW1 := WW1 or cpoCheckFree
    else
      WW1 := WW1 and not cpoCheckFree;
    end;

  if not SkipCopyDialog then
    begin {AK155 6-12-2001. Gathered all dialog work together }
    @PreExecuteDialog := @PrepareDialog;
    if ExecResource(dlgCopyDialog, DT) = cmCancel then
      Exit;
    end;
  SkipCopyDialog := False;

  
  S := DT.S3;
  CopyMode := DT.WW;
  CopyOpt := DT.WW1;
  DelRight(S);
  DelLeft(S); {AK155}
  {AK155 22-12-2002
   The following strange fragment is devoted primarily to fighting
veiled equivalence of the target directory to the source
(when copying a directory). Without this, with the existing directory-copy
implementation, such equivalence on disk produces a cyclic
directory structure. For example, try commenting out this piece,
stand on directory D, press F5 and enter 'D.' or 'D.\.\' . Better do it
on a RAM disk :)
It is also bad when a silly overwrite question is asked when
copying a file like 'f' to 'f..'
   On the other hand, dots and slashes may appear in quite
meaningful combinations like '..' (type by hand to copy
outward) or D:\D\..\file.ext (D&D of a single file onto '..') or
D:\D\.. (D&D of several files onto '..')
   Many hands touched this issue, in particular JO, Cat,
AK155. At times cycling was restored, at times some meaningful
copying became impossible. This correction was caused by the fact
that in b09 D&D of a single file onto UpDir dots stopped working.
}
  SSS := S; {AK155 02-01-2003}
  I := Length(S);
  while True do
    begin
    if GetName(S) = '..' then
      Break;
    l := I;
    while S[I] = '.' do
      Dec(I);
    while S[I] = DnSep do
      Dec(I);
    if l = I then
      Break;
    SetLength(S, I);
    end;
  {/AK155 22-12-2002}

  {AK155 02-01-2003 As a result of the 22-12-2002 correction the last
DnSep was trimmed, which led, for example, to inability to
copy into the disk root ('C:\' became 'C:' and we got
copying into the current directory). Restoring DnSep is done via ':=',
not via 'SetLength(S,I+1)', so as not to plant a mine for a possible
future move from ShortString to AnsiString }
  if  (Length(SSS) > I) and (SSS[I+1] = DnSep) then
    S := Copy(SSS, 1, I+1);
  {/AK155 02-01-2003}

  ccCopyMode := DT.WW;
  ccCopyOpt := DT.WW1;

  if  (FMSetup.Options and fmoAlwaysCopyDesc = 0) and
      (SourcePanel <> nil) and
      (TFilePanelRoot(SourcePanel).Drive <> nil) and
      (TFilePanelRoot(SourcePanel).Drive.DriveType = dtDisk) and
      (TFilePanelRoot(SourcePanel).
        PanSetup.Show.ColumnsMask and psShowDescript = 0)
  then
    CopyOpt := CopyOpt and not cpoDesc; {JO}

  lFSplit(S, CopyDir, Nm, Xt);
  if S = '' then
    Exit;             {<filecopy.001>}
  if not Link then
    begin
    if ArchiveFiles(S, Files, MoveMode, SourcePanel) then
      Exit;
    
    if CopyFilesToArvid(S, Files, MoveMode, SourcePanel) then
      Exit;
    
    if UpStrg(Copy(S, 1, PosChar(':', S))) = cTEMP_ then
      begin
      CopyToTempDrive(Files, SourcePanel, '');
      Exit;
      end;
    
    end;
  SSS := lFExpand(S);
  if Abort then
    Exit;
  Mask := Nm+Xt;
  if  (Mask = '') then
    Mask := x_x
  else if (PosChar('*', Mask) = 0) and (PosChar('?', Mask) = 0) then
    begin
    ClrIO;
    if Length(SSS) = 3 then
      begin
      CopyDir := S+DnSep;
      Mask := x_x
      end
    else
      begin
      if not ((Files.Count = 1) and
            (UpStrg(S) = UpStrg(PFileRec(Files.At(0))^.FlName[True])))
      then
        begin
        lFindFirst(SSS, AnyFileDir, SR); {JO}
        DEr := (DosError <> 0);
        lFindClose(SR);
        if Abort then
          Exit;
        {/AK155
     If when copying/moving several files you enter a non-existent
name in the input line and do not set the append checkbox,
then the first file was copied to that name, and all subsequent ones -
also into it, which is clear absurdity. Now in this case a directory
with the entered name is created and files are copied into it.
}
        if IsDummyDir(S) or (not DEr and (SR.SR.Attr and Directory <> 0))
        then
          begin
          CopyDir := S+DnSep;
          Mask := x_x;
          end
        else if (DEr and (Files.Count <> 1)
            and (ccCopyMode and cpmAppend = 0))
        then
          begin
          case AppendQuery(SSS) of
            cmYes:
              CopyMode := cpmAppend;
            cmNo:
              begin
              CopyDir := S+DnSep;
              Mask := x_x;
              end;
            else {case}
              begin
              CopyDialog := False;
              Exit;
              end;
          end {case};
          end
        end;
      end;
    end;
  if Nm[Length(Nm)] = ':'
  then
    S := UpStrg(Copy(Nm, 1, Length(Nm)-1))+#0
  else
    S := UpStrg(Nm)+#0;
  I := 0;
  if LFN.SysFileOpen(@S[1], Open_Access_ReadOnly or open_share_DenyNone,
       hFile) = 0
  then
    begin
    if SysFileIsDevice(hFile) and $FF <> 0 then
      {AK155: 'and $FF' is necessary because the SysFileIsDevice help
            is untruthful; see the DosQueryHType help}
      I := 1;
    SysFileClose(hFile);
    end;
  if  (I <> 0) then
    begin
    CopyMode := cpmOverwrite;
    CopyDir := SSS;
    Mask := '';
    CopyPrn := True;
    end
  else
    begin
    CopyDir := lFExpand(CopyDir);
    MakeSlash(CopyDir);
    CopyPrn := False;
    end;
  CopyDialog := True;
  end { CopyDialog };
{-DataCompBoy-}

{-DataCompBoy-}
procedure CopyFiles(Files: TCollection; SourcePanel: TView; MoveMode: Boolean; FromTemp: Byte);

  var
    CopyDir: String;
    Mask: String;
    CopyOpt: Word;
    CopyMode: Word;
    CopyPrn: Boolean;
    
  begin
  CtrlBreakHit := False;
  Files.Pack;
  if MoveMode then
    FRNote('file', 'move ' + ItoS(Files.Count) + ' item(s)')
  else
    FRNote('file', 'copy ' + ItoS(Files.Count) + ' item(s)');
  if Files.Count <= 0 then
    Exit;
  if not CopyDialog(CopyDir, Mask, CopyOpt, CopyMode, CopyPrn,
      MoveMode, Files, FromTemp, SourcePanel, False)
  then
    Exit;
  if  (FromTemp > 0) and MoveMode then
    begin
    CopyOpt := CopyOpt or cpoFromTemp;
    end;
  
  Inc(SkyEnabled);
  NotifySuspend; {Cat}
  FilesCopy(Files, SourcePanel, CopyDir, Mask, CopyMode, CopyOpt,
            CopyPrn, True);
  NotifyResume; {Cat}
  Dec(SkyEnabled);
  if MoveMode then
    NotifyUser('Move finished')
  else
    NotifyUser('Copy finished');
  
  end { CopyFiles };

{JO}
procedure CopyDirContent(Source, Destination: String;
    MoveMode, Forced: Boolean);
  var
    SR: lSearchRec;
    FC: TFilesCollection;
    FR: PFileRec;
  begin
  MakeSlash(Source);
  FC := TFilesCollection.Create($10, $10);
  ClrIO;
  lFindFirst(Source+x_x, AnyFileDir, SR);
  while (DosError = 0) and not Abort do
    begin
    if not IsDummyDir(SR.FullName) then
      FC.AtInsert(FC.Count, NewFileRec(SR.FullName,
          
          SR.SR.Name,
          
          SR.FullSize,
          SR.SR.Time,
          SR.SR.CreationTime,
          SR.SR.LastAccessTime,
          SR.SR.Attr,
          @Source));
    lFindNext(SR);
    end;
  lFindClose(SR);
  ClrIO;
  FC.Pack;
  if FC.Count <= 0 then
    begin
    FC.Free;
    Exit;
    end;

  MakeSlash(Destination);
  Inc(SkyEnabled);
  NotifySuspend;
  FilesCopy(FC, nil, Destination, x_x, cpmAskOver*Byte(not Forced),
    cpoMove*Byte(MoveMode), False, False);
  NotifyResume;
  Dec(SkyEnabled);
  FC.RemoveAll;
  FC.Free;
  end { CopyDirContent };
{/JO}

procedure CloseWriteStream;
  begin
  Truncate(WriteStream.F);
  Close(WriteStream.F);
  ClrIO;
  end;

end.
