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

unit FViewer;

interface

uses
  SysUtils,
  Defines, Streams, Views, Drivers,
  basics, highlite, timeutil,
  Collect, FilesCol, XCode
  ;

const
  MaxILines = 200; { maximum index of the Lines array }
  MaxWrapW = 1023;
  { maximum wrap width for
    lines in unwrap mode }

type
  PComp = ^TFileSize;

  { TViewScroll }

  TViewScroll = class;
  TViewScroll = class(TView)
    {Cat: this object is exposed via the plugin model; change with extreme care!}
    MaxV, Value: TFileSize;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    function GetPartCode: LongInt;
    procedure Draw; override;
    function GetSize: Integer;
    procedure DrawPos(Pos: Integer);
    end;

  { TFileViewer }

  TFileViewer = class;

  TFileViewer = class(TView)
    {Cat: this object is exposed via the plugin model; change with extreme care!}
    Filtr: Boolean;
    NoEdit: Boolean;
    FileName: String; {DataCompBoy}
    VFileName: String; {DataCompBoy}
    Buf: PByteArray;
    Fl: TStream;
    UpdateViewTmr: TEventTimer;
    XDelta, ViewMode, HexPos: AInt;
    SearchActive: Boolean;
    SearchResultVisible: Boolean; {AK155}
    PrevSearchDir: Boolean; {This variable is considered
      only when SearchResultVisible }
    SearchX: TFileSize;
    SB: TView;
    Wrap: Byte; {DataCompBoy}
    Lines: array[0..MaxILines] of record
      Pos: LongInt;
      len: Word;
      end;
    FilePos, FileSize: TFileSize;
    NumLines: LongInt;
    ExposedPos, ExposedLine: LongInt; {AK155}
    Cur: TPoint;
    Info: TView;
    BufPos: LongInt;
    BufSize, MaxLines: LongInt;
    BufLines: AInt;
    KillAfterUse, isValid, QuickView, Loaded, HexEdit, BufModified:
     Boolean;
    FakeKillAfterUse: Boolean; {temporary stub}
    Filter: Byte;
    XCoder: TXCoder;
    MarkPos: TFPosArray;
    CtrlK: Boolean;
    CtrlQ: Boolean;
    HiLite: Boolean; {PZ 2000.06.09}
    ScrollEOF: Boolean; {AK155}
    HiLitePar: THighliteParams;
    constructor Create(const Bounds: TRect; AStream: TStream;
        const AFileName, AVFileName: String;
        ASB: TView; Quick, Hex: Boolean); {DataCompBoy}
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    destructor Destroy; override;
    procedure Draw; override;
    function ReadFile(const FName, VFName: String; NewStream: Boolean)
      : Boolean; {DataCompBoy}
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure HandleEvent(var Event: TEvent); override;
    function WriteModify: Boolean;
    procedure CountDown(ANumber: Integer); virtual;
    procedure CountUp(ANumber: Integer); virtual;
    procedure Seek(APos: TFileSize);
    procedure MakeLines; virtual;
    procedure SaveToFile(FN: String);
    function Valid(Command: Word): Boolean; override;
    procedure ChangeBounds(const Bounds: TRect); override;
    function GetPalette: TPalette; override;
    procedure DoHighlite(var B: TScreenCell; const S: String; const Attr: String);
    procedure Update; override; {AK155}
    procedure SeekEof;
    procedure SeekBof;
    function BreakOnStreamReadError: Boolean;
    procedure ChangeFile(FR: PFileRec); virtual;
  private
    procedure AdjustBuf;
    end;

  THFileViewer = class;

    {`2 A viewer inserted not into a window but into the manager panel`}
  THFileViewer = class(TFileViewer)
    procedure ChangeBounds(const Bounds: TRect); override;
    function GetPalette: TPalette; override;
    end;

  TQFileViewer = class;

    {`2 Quick View`}
  TQFileViewer = class(THFileViewer)
    procedure ChangeFile(FR: PFileRec); override;
    end;

  TDFileViewer = class;

    {`2 Description View`}
  TDFileViewer = class(THFileViewer)
    procedure HandleEvent(var Event: TEvent); override;
    procedure ChangeFile(FR: PFileRec); override;
    end;

  TNFileViewer = class;

    {`IMHO viewing a memo in a dbf`}
  TNFileViewer = class(TFileViewer)
    function GetPalette: TPalette; override;
    end;

  TViewInfo = class;
  TViewInfo = class(TView)
    Viewer: TFileViewer;
    constructor Create(const R: TRect; AViewer: TFileViewer);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    end;

  TFileWindow = class;

  TFileWindow = class(TWindow)
    constructor Create(const FileName, VFileName: String; Hex: Boolean);
    {DataCompBoy}
    function GetPalette: TPalette; override;
    function ReactOnCmd: Boolean; virtual;
    procedure ChangeBounds(const Bounds: TRect); override;
    end;

const
  CHViewer = #13#14#117#118#199#200#201#202#203#204;
  CViewer = #6#7#8#9#10#11#12#13;
  CViewWindow = #112#113#114#115#116#117#118#199#200#201#202#203#204;

type
  TViewSearch = record
    What: String[250];
    Opts: Word;
    Dir: Word
    end;

const
  cmChangeValue = 9990;
  SearchString: TViewSearch = (What: ''; Opts: 0; Dir: 0);

  {Cat: do not change variable order; they are saved contiguously in the DSK file}

var
  LastViewerBounds: TRect;
  LastViewerDeskSize: TPoint {= (X:0;Y:0)};
  LastEditDeskSize: TPoint {= (X:0;Y:0)};

function SearchFileStr(
 {` Search for a string in an already open file }
    F: TStream; // The file itself
    var XLAT: TXlat;
      { recode from the file encoding to ASCII. If
      not CaseSensitive - also convert to uppercase at the same time}
    const What: String;
      { in ASCII. For not CaseSensitive the case of What does not matter }
    Pos: TFileSize; // start point
    CaseSensitive,
    Display, // show search progress info
    WholeWords, Back,
    AllCP, // if AllCP, XLAT is ignored
    IsRegExp: Boolean): TFileSize;
 {`}

type
  eFileError = class(Exception)
  public
    RC: LongInt;
    end;

implementation

uses
  Lfn, Dos, DNUtf8, osdep, Commands, DNHelp, strutil, fileutil, keymap
  , editcore, Macro, linepos, Math, Messages, mainapp, Startup, Dialogs,
  Decoder,  {piwamoto}
   {Cat}
  fileerrors, {AK155}
  DiskInfo, uselfn,
  progress, DNStdDlg, histories, Drives, DNUtil, DnIni
  , FileDiz
  ;

function MaxAvail: LongInt;
  begin
  MaxAvail := MemAdjust(Defines.MaxAvail);
  end;

const
  ViewerBufSize = (1+MaxILines)*(MaxWrapW+2);

function SearchFileStr( F: TStream; var XLAT: TXlat; const What: String; Pos: TFileSize; CaseSensitive, Display, WholeWords, Back, AllCP, IsRegExp: Boolean): TFileSize;
  label 1, LExit;
  var
    Buf: PByteArray;
    Count: LongInt;
    BufLen, BufPos, BPos, T, StPos, StDelta: LongInt;
    J: LongInt;
    I, L, OldPos, NextPos: TFileSize;
    CancelSearch: Boolean;
    Info: TWhileView;
    R: TRect;
    Tmr: TEventTimer;
    Inserted: Boolean;
    W: String;
    
    BMT: BMTable;
  begin
  if IsRegExp then
    begin
    MessageBox('RegExp Search is not implemented yet', nil,
       mfError+mfOKButton);
    Exit;
    end;
  Info := nil;
  SearchFileStr := -1;
  Count := 0;
  ClrIO;
  OldPos := F.GetPos;
  L := F.GetSize;
  if L = 0 then
    goto LExit;
  F.Seek(Pos);
  BufLen := $80000;
  {Cat: better not skimp on memory here, or we lose a lot of speed}
  if BufLen > L then
    BufLen := i32(L);
  if BufLen > MaxAvail then
    BufLen := MaxAvail;
  if BufLen < Length(What) then
    begin
    F.Seek(OldPos);
    goto LExit;
    end;
  T := 0;
  StPos := 0;
  StDelta := 0;
  if Display then
    begin
    R.Assign(1, 1, 30, 9);
    Info := TWhileView.Create(R);
    Info.Top := GetString(dlSearching)+' "'+Cut(SearchString.What, 40)
      +'"';
    NewTimer(Tmr, 100);
    Inserted := False;
    end;
  GetMem(Buf, BufLen);
  I := Pos;
  BPos := 0;
  CancelSearch := False;
  repeat
    if Back then
      begin
      NextPos := I-BufLen+BPos;
      if NextPos < 0 then
        begin
        NextPos := 0;
        BPos := 0;
        end;
      J := i32(I-NextPos);
      if J <= 0 then
        Break;
      end
    else
      begin
      NextPos := F.GetPos;
      J := BufLen;
      if J > L-I+BPos then
        J := i32(L-I+BPos);
      ClrIO;
      end;
    if Display then
      begin
      Info.Write(1, StrGrd(L, I, 30, False));
      Info.Write(2, Percent(L, I));
      if  (not Inserted) and TimerExpired(Tmr) then
        begin
        Desktop.Insert(Info);
        Inserted := True;
        end;
      if Inserted then
        DispatchEvents(Info, CancelSearch);
      end;
    F.Seek(NextPos);
    F.Read(Buf^[BPos], J-BPos);
    T := J-BPos;
1:
    if J <= 0 then
      BufPos := 0
    else
      begin {-$VIV 14.05.99}
      if AllCP then
        begin
        if Back then
          BufPos := BackSearchForAllCP(What, Buf^[StPos], J-StPos,
               CaseSensitive)
        else
          BufPos := SearchForAllCP(What, Buf^[StPos], J-StPos,
               CaseSensitive);
        end
      else
        begin
        W := What;
        if Back then
          begin
          Create_BackBMTable(BMT, W, CaseSensitive);
          BufPos := BackBMsearch(BMT, Buf^[StPos], J-StPos, W,
            XLAT);
          end
        else
          begin
          Create_BMTable(BMT, W, CaseSensitive);
          BufPos := BMsearch(BMT, Buf^[StPos], J-StPos, W,
            XLAT);
          end;
        end;
      end; {-$VIV ::}
    if BufPos > 0 then
      begin
      if WholeWords and not (((BufPos = 1) or (Char(Buf^[BufPos-2+StPos])
               in BreakChars)) and
            (Char(Buf^[BufPos+Length(What)-1+StPos]) in BreakChars))
      then
        begin
        if Back then
          J := BufPos+Length(What)-2
        else
          Inc(StPos, BufPos);
        goto 1;
        end;
      FreeMem(Buf, BufLen);
      F.Seek(OldPos);
      SearchFileStr := NextPos-BPos+BufPos-1+StPos;
      goto LExit;
      end;
    if Back then
      begin
      I := I - T;
      if I < -T then
        Break;
      if I < 0 then
        I := 0;
      end
    else
      I := I + T;
    StPos := 1;
    BPos := Length(What)+1;
    if I < L then
      Move(Buf^[J-BPos], Buf^[0], BPos);
  until (Back and (I < 0)) or
    (not Back and ((I >= L) or (T <= 0) or (F.GetPos >= F.GetSize))) or
  CancelSearch;
  if CancelSearch then
    SearchFileStr := -2;
  FreeMem(Buf, BufLen);
  F.Seek(OldPos);
LExit:
  if Info <> nil then
    Info.Free;
  Info := nil;
  end { SearchFileStr };

constructor TViewInfo.Create(const R: TRect; AViewer: TFileViewer);
  begin
  inherited Create(R);
  Viewer := AViewer;
  GrowMode := gfGrowHiY+gfGrowLoY+gfGrowHiX;
  EventMask := evMouse;
  end;

constructor TViewInfo.Load(S: TStream);
  begin
  inherited Load(S);
  GetPeerViewPtr(S, Viewer);
  end;

procedure TViewInfo.Store(S: TStream);
  begin
  inherited Store(S);
  PutPeerViewPtr(S, Viewer);
  end;

procedure TViewInfo.Draw;
  var
    B: TDrawBuffer;
    S: String;
    I, J: Integer;
    Ch, Ch2: Char;
    Color: Word;
  begin
  if  (Viewer = nil) or
      (Owner = nil) or
      (TWindow(Owner).Frame = nil)
  then
    begin
    inherited Draw;
    Exit;
    end;
  with Viewer, Self do
    begin
    Color := TWindow(Owner).Frame.GetColorW(3);
    Ch2 := #205;
    if not Owner.GetState(sfActive) then
      begin
      Color := TWindow(Owner).Frame.GetColorW(1);
      MoveChar(B[0], #196, Color, Size.X);
      WriteLineC(0, 0, Size.X, 1, B);
      Exit;
      end
    else if Owner.GetState(sfDragging) then
      begin
      Color := TWindow(Owner).Frame.GetColorW(5);
      Ch2 := #196;
      end;
    if ViewMode = vmHex then
      begin
      S := HexFilePos(Cur.X div (1+Byte(HexEdit))+
          Cur.Y* (HexPos+BufPos+FilePos))+' ';
      J := FSizeMod(FilePos+BufPos, Max(1, HexPos));
      for I := 0 to HexPos-1 do
        S := S+Hex2(I+J)+#196;
      SetLength(S, Length(S)-1);
      Insert('[', S, 1);
      Insert(']', S, Length(S)+1);
      end
    else if ViewMode = vmAsm then
      begin
      J := 0;
      for I := 0 to (Cur.Y-1) do
        Inc(J, Lines[I].len);
      S := '['+HexFilePos(((Cur.X-10) div 2)+J+BufPos+FilePos)+']';
      end
    else
      case Wrap of
        wmNone:
          S := Ch2+'<=>';
        wmWidth:
          S := Ch2+'>=<';
        wmWords:
          S := Ch2+'>W<';
      end {case};
    if ViewMode <> vmHex then
      begin
      S := S+Ch2+Ch2+'<';
      for I := 1 to 9 do
        with MarkPos[I] do
          if not ((X=-1) and (Y=-1)) then
            S := S+Char(I+48)
          else
            S := S+#250;
      S := S+'>';
      end;
    Insert(Ch2+Ch2, S, Length(S)+1);
    if ViewMode <> vmAsm then
      begin
      Insert(AddSpace(XCoder.CodeTag, 8), S, Length(S)+1);
      case Filter of
        0:
          Insert('{00-255}'+Ch2, S, Length(S)+1);
        1:
          Insert('{32-127}'+Ch2, S, Length(S)+1);
        else {case}
          Insert('{32-255}'+Ch2, S, Length(S)+1);
      end {case};
      end;
    if ViewMode <> vmHex then
      begin
      S := S+Ch2;
      if  (Lines[Size.Y].Pos < 0) and (FilePos+BufSize >= FileSize)
        or (FileSize = 0)
      then
        S := S+'100'
      else
        S := S + Percent(FileSize, FilePos+ExposedPos);
      S := S + ' of '+FStr(FileSize)+' Bytes'+Ch2;
      end;
    end;
  MoveChar(B[0], Ch2, Color, Size.X);
  MoveStr(B[0], S, Color);
  Self.WriteLineC(0, 0, Size.X, Size.Y, B);
  end { TViewInfo.Draw };

procedure TViewInfo.HandleEvent(var Event: TEvent);
  var
    P: TPoint;
    BookMark: Byte;
    Ev: TEvent;
  begin
  if Viewer = nil then
    Exit;
  if  (Event.What = evMouseDown) then
    with Viewer do
      begin
      Self.MakeLocal(Event.Where, P);
      if  (ViewMode = vmHex) then
        begin
        if P.X < 3*HexPos+9+3 then
          {}
        else if P.X < 3*HexPos+9+12 then
          Message(Viewer, evCommand, cmSwitchKeyMapping, nil)
        else if P.X < 3*HexPos+9+20 then
          Message(Viewer, evCommand, cmAddFilter, nil);
        end
      else if (ViewMode = vmAsm) then
        begin
        if P.X < 12 then
          {}
        else if P.X = 12 then
          SeekBof
        else if P.X < 22 then
          begin
          BookMark := P.X-13;
          if  (Event.Buttons and mbRightButton <> 0) or
              (MarkPos[BookMark+1].Y <> -1)
          then
            with Ev do
              begin
              What := evCommand;
              if  (Event.Buttons and mbRightButton <> 0) then
                Command := cmPlaceMarker1+BookMark
              else
                Command := cmGoToMarker1+BookMark;
              PutEvent(Ev);
              end;
          end
        else if P.X = 22 then
          SeekEof;
        end
      else
        begin
        if P.X < 1 then
          {}
        else if P.X < 4 then
          Message(Viewer, evCommand, cmUnWrap, nil)
        else if P.X < 6 then
          {}
        else if P.X = 6 then
          SeekBof
        else if P.X < 16 then
          begin
          BookMark := P.X-7;
          if  (Event.Buttons and mbRightButton <> 0) or
              (MarkPos[BookMark+1].Y <> -1)
          then
            with Ev do
              begin
              What := evCommand;
              if  (Event.Buttons and mbRightButton <> 0) then
                Command := cmPlaceMarker1+BookMark
              else
                Command := cmGoToMarker1+BookMark;
              PutEvent(Ev);
              end;
          end
        else if P.X = 16 then
          SeekEof
        else if P.X < 19 then
          {}
        else if P.X < 28 then
          Message(Viewer, evCommand, cmSwitchKeyMapping, nil)
        else if P.X < 36 then
          Message(Viewer, evCommand, cmAddFilter, nil);
        end;
      ClearEvent(Event);
      end;
  end { TViewInfo.HandleEvent };

function TFileViewer.WriteModify;
  var
    B: Boolean;
    I: LongInt;
    S: TDOSStream;
    A: Word;
  begin
  B := BufModified;
  WriteModify := False;
  if  (Buf = nil) or (Fl = nil) or (Fl.Status <> stOK) or not B then
    Exit;
  I := MessageBox(GetString(dlViewQuery), nil, mfWarning+mfYesNoCancel);
  WriteModify := I = cmCancel;
  if I <> cmCancel then
    BufModified := False;
  if I = cmNo then
    begin
    Seek(FilePos);
    DrawView;
    end;
  if I <> cmYes then
    Exit;
  if VFileName = '' then
    begin
    FreeStr := GetFileNameDialog(x_x, GetString(dlSaveFileAs),
        GetString(dlSaveFileAsName),
        fdOKButton+fdHelpButton, hsEditSave);
    if FreeStr <> '' then
      begin
      SaveToFile(FreeStr);
      FileName := FreeStr;
      VFileName := FileName;
      WriteModify := True;
      Owner.Redraw;
      end
    else
      Exit;
    end;
  if  (Fl is TDOSStream) or (Fl is TBufStream)
  then
    begin
    Fl.Free;
    ClrIO;
    NeedAbort := True;
    A := 0;
    Fl := TDosStream.Create(FileName, stOpen);
    if not Abort and (Fl.Status <> stOK) then
      begin
      Fl.Free;
      A := GetFileAttr(FileName);
      SetFileAttr(FileName, A and not ReadOnly);
      Fl := TDosStream.Create(FileName, stOpen);
      end;
    if  (Fl.Status <> stOK) or (Abort) then
      begin
      Fl.Free;
      Fl := TDosStream.Create(FileName, stOpenRead);
      MessageBox(GetString(dlFBBNoWrite)+FileName, nil,
         mfError+mfOKButton);
      end
    else
      begin
      Fl.Seek(FilePos);
      Fl.Write(Buf^, BufSize);
      end;
    if A <> 0 then
      begin
      Fl.Free;
      SetFileAttr(FileName, A);
      Fl := TDosStream.Create(FileName, stOpenRead);
      end;
    end
  else
    begin
    Fl.Seek(FilePos);
    Fl.Write(Buf^, BufSize);
    end;
  NeedAbort := False;
  if not Startup.AutoRefreshPanels then
    RereadDirectory(GetPath(FileName));
  end { TFileViewer.WriteModify };

const
  SCViewer: String[Length(CViewer)] = CViewer;
  SCHViewer: String[Length(CHViewer)] = CHViewer;
  SCNViewer: String[Length(CInputLine)] = CInputLine;
  SCViewWindow: String[Length(CViewWindow)] = CViewWindow;

function TFileViewer.GetPalette;
  begin
  GetPalette := MakePalette(SCViewer);
  end;

function TNFileViewer.GetPalette: TPalette;
  begin
  GetPalette := MakePalette(SCNViewer);
  end;

function THFileViewer.GetPalette: TPalette;
  begin
  GetPalette := MakePalette(SCHViewer);
  end;

function TFileWindow.GetPalette: TPalette;
  begin
  GetPalette := MakePalette(SCViewWindow);
  end;

{TViewScroll}

function TViewScroll.GetSize: Integer;
  begin
  GetSize := Size.Y;
  if GetSize < 3 then
    GetSize := 3;
  end;

procedure TViewScroll.DrawPos(Pos: Integer);
  var
    Buf: TDrawBuffer;
    Last: Integer;
  begin
  Last := GetSize-1;
  MoveChar(Buf[0], #177, GetColorW(1), Last+1); { the track }
  MoveChar(Buf[Pos], #254, GetColorW(3), 1); { the thumb }
  MoveChar(Buf[0], #30, GetColorW(2), 1); { the arrow up }
  MoveChar(Buf[Last], #31, GetColorW(2), 1); { the arrow down }
  WriteBufC(0, 0, Size.X, Size.Y, Buf);
  end;
procedure TViewScroll.HandleEvent(var Event: TEvent);
  var
    B: Boolean;
    P: TPoint;
    RD, SP: LongInt;

    Extent: TRect;
    Tracking: Boolean;

    {JO}
  function GetPrecValue: TFileSize;
    var
      Max1: Double; {JO}
    begin
    Max1 := MaxV;
    GetPrecValue :=  Round 
      (Max1*(SP-1)/(Size.Y-3)) + 1;
    end;
  {/JO}

  begin
  inherited HandleEvent(Event);
  case Event.What of
    evCommand:
      case Event.Command of
        cmChangeValue:
          begin
          Value := PComp(Event.InfoPtr)^;
          DrawView;
          ClearEvent(Event)
          end;
        {              cmSetMargins: Message(Owner, evCommand, cmGotoLineNumber, Pointer(Value));}
      end {case};
    evMouseDown:
      if MaxV > 0 then
        begin

        MakeLocal(Event.Where, P);
        GetExtent(Extent);
        {if (Value * (Size.Y-3)) div MaxV + 1 = P.Y then}
        if GetPartCode = P.Y then
          {JO}
          begin
          RD := P.Y;
          repeat
            MakeLocal(Event.Where, P);
            Tracking := Extent.Contains(P);
            if Tracking then
              begin
              {  if Size.X = 1 then}SP := P.Y {else I := P.X};
              if SP <= 0 then
                SP := 1;
              if SP >= Size.Y-1 then
                SP := Size.Y-2;
              end; { else I := GetPos;}
            if SP <> RD then
              begin
              DrawPos(SP);
              RD := SP;
              end;
          until not MouseEvent(Event, evMouseMove+evMouseAuto);
          if SP = 1 then
            Value := 0
          else
            {Value := MaxV * (SP-1) div (Size.Y-3) + 1;}
            {JO: Longint precision is not enough for very large files}
            Value := GetPrecValue; {JO}
          {AK155: the scroller is already drawn and will be drawn twice more }
          {                DrawView; }
          Message(Owner, evCommand, cmScrollBarChanged, @Value);
          Exit;
          end;

        MakeLocal(Event.Where, P);
        RD := RepeatDelay;
        RepeatDelay := 0;
        SP := GetPartCode;
        if P.Y = 0 then
          begin
          repeat
            MakeLocal(Event.Where, P);
            if  (P.X >= -1) and (P.X <= 1) and (P.Y >= -1)
                 and (P.Y <= 1)
            then
              MessageKey(Owner, kbUp);
          until not MouseEvent(Event, evMouseMove+evMouseAuto);
          end
        else if P.Y = Size.Y-1 then
          begin
          repeat
            MakeLocal(Event.Where, P);
            if  (P.X >= -1) and (P.X <= 1) and (P.Y >= Size.Y-2)
                 and (P.Y <= Size.Y)
            then
              MessageKey(Owner, kbDown);
          until not MouseEvent(Event, evMouseMove+evMouseAuto);
          end
        else if P.Y < SP then
          begin
          RepeatDelay := RD;
          repeat
            GetPartCode;
            MakeLocal(Event.Where, P);
            if  (P.X >= -1) and (P.X <= 1) and (P.Y < SP) then
              MessageKey(Owner, kbPgUp);
          until not MouseEvent(Event, evMouseMove+evMouseAuto);
          end
        else if P.Y > SP then
          begin
          RepeatDelay := RD;
          repeat
            GetPartCode;
            MakeLocal(Event.Where, P);
            if  (P.X >= -1) and (P.X <= 1) and (P.Y > SP) then
              MessageKey(Owner, kbPgDn);
          until not MouseEvent(Event, evMouseMove+evMouseAuto);
          end;
        RepeatDelay := RD;
        end;
  end {case};
  end { TViewScroll.HandleEvent };

function TViewScroll.GetPartCode: LongInt;
  var
    Val1, Max1: Double; {JO}
  begin
  if Value >= MaxV then
    GetPartCode := Size.Y-2
  else
    {JO}
    begin
    Val1 := Value;
    Max1 := MaxV;
    {GetPartCode := 1+((Size.Y-3)*Value) div MaxV}
    {JO: Longint precision is not enough for very large files}
    GetPartCode := 1+Round(((Size.Y-3)*Val1)/Max1);
    end;
  {/JO}
  end;

function TViewScroll.GetPalette: TPalette;
  const
    S: String[Length(CScrollBar)] = CScrollBar;
  begin
  GetPalette := MakePalette(S);
  end;

procedure TViewScroll.Draw;
  var
    B1: TDrawBuffer;
    C1, C2: Byte;
    i: Integer;
  begin
  C1 := GetColorW(1);
  C2 := GetColorW(2);
  MoveChar(B1[0], #177, C1, Size.Y);
  i := GetPartCode;
  B1[i] := CellFromBIOS(254+LongInt(C2*256));
  B1[0] := CellFromBIOS(30+LongInt(C2*256));
  B1[Size.Y-1] := CellFromBIOS(31+LongInt(C2*256));
  WriteBufC(0, 0, 1, Size.Y, B1);
  end;

{ TQFileViewer }

procedure TQFileViewer.ChangeFile(FR: PFileRec);
  var
    S: String;
  begin
  S := MakeNormName(FR^.Owner^, FR^.FlName[uLfn]);
  if UpStrg(lFExpand(S)) <> UpStrg(lFExpand(FileName)) then
    begin
    ReadFile(S, S, True);
    DrawView;
    end;
  end;

{ TDFileViewer }

procedure TDFileViewer.ChangeFile(FR: PFileRec);
  var
    S: LongString;
    i, j: Longint;
    L: Longint;
  const
    CrLf: array[1..2] of Char = #13#10;
  begin
  S := MakeNormName(FR^.Owner^, FR^.FlName[uLfn]);
  if UpStrg(lFExpand(S)) <> UpStrg(lFExpand(FileName)) then
    begin
    if Fl = nil then
      begin
      Fl := TMemoryStream.Create(1, 1024);
      Wrap := wmWords;
      end;
    with Fl do
      begin
      Seek(0);
      Truncate;
      end;
    GetDiz(FR);
    if (FR^.Diz <> nil) and (FR^.Diz^.DizText <> '') then
      begin
      S := FR^.Diz^.DizText;
      Fl.Write(S[1], Length(S));
      end;
    ReadFile('', '', False);
//    MakeLines;
    DrawView;
    end;
  end;

procedure TDFileViewer.HandleEvent(var Event: TEvent);
  begin
  if (Event.What = evCommand) and (Event.Command = cmFileEdit) then
    begin
   {! AK155 10.01.05 The jump-to-editor command in the description
    viewer panel is probably sensible. We should actually
    open the editor in this same window and feed it
    this same MemoryStream. But there is no time for that now,
    so for now Alt-E will simply be ignored. }
    ClearEvent(Event);
    end
  else
    inherited HandleEvent(Event);
  end;

{ THFileViewer }

procedure THFileViewer.ChangeBounds(const Bounds: TRect);
  var
    R: TRect;
  begin
  SetBounds(Bounds);
  if  (Wrap > wmNone) or (ViewMode = vmDump) then
    MakeLines;
  if SB <> nil then
    begin
    R := Bounds;
    R.A.X := R.B.X;
    Inc(R.B.X);
    SB.SetBounds(R)
    end
  end;

{ TFileViewer }

procedure TFileViewer.ChangeBounds;
  var
    R: TRect;
  begin
  inherited ChangeBounds(Bounds);
  if  (Wrap > wmNone) or (ViewMode = vmDump) then
    MakeLines;
  DrawView;
  { if Info <> nil then
  begin R := Bounds; R.A.Y := R.B.Y - 1; Dec(R.B.X, 2); Info.SetBounds(R) end}
  end;

{AK155
   Ensure a buffer of a suitable size. That size does not
exceed the file size. The previous buffer, if it was
not that size, is freed }
procedure TFileViewer.AdjustBuf;
  var
    NewBufSize: LongInt;
  begin
  NewBufSize := MinBufSize(FileSize, ViewerBufSize);
  if  (Buf <> nil) and (NewBufSize = BufSize) then
    Exit;
  if Buf <> nil then
    FreeMem(Buf, BufSize);
  if MaxAvail < NewBufSize then
    NewBufSize := MaxAvail;
  BufSize := NewBufSize;
  GetMem(Buf, BufSize);
  end;

{AK155
   Auto-reread the file if its end is visible on screen }
procedure TFileViewer.Update;
  begin
  inherited Update;
  if  ( (EditorDefaults.ViOpt and vbfAutoscroll) <> 0) and
    not BufModified and
    not SearchResultVisible and
      (ViewMode = vmText) and
      (ExposedPos+FilePos = FileSize) and
    TimerExpired(UpdateViewTmr)
  then
    begin
    SeekEof;
    NewTimer(UpdateViewTmr, 500); { update twice per second }
    end;
  end;

constructor TFileViewer.Create(const Bounds: TRect; AStream: TStream;
  const AFileName, AVFileName: String; ASB: TView; Quick, Hex: Boolean);
  var
    C: Char;
  begin
  inherited Create(Bounds);
  ViewMode := vmText;
  XCoder := TXCoder.Create(8);
  FillChar(MarkPos, SizeOf(MarkPos), $FF);
  HelpCtx := hcView;
  GrowMode := gfGrowHiX+gfGrowHiY;
  Options := Options or ofSelectable or (LongInt(Quick)*ofTopSelect);
  EventMask := $FFFF;
  SB := ASB;
  QuickView := Quick;
  Buf := nil;
  isValid := True;
  Loaded := False;
  KillAfterUse := False;
  Wrap := 0;
  if EditorDefaults.ViOpt and vbfWrap <> 0 then
    Wrap := 1;
  if EditorDefaults.ViOpt and vbfWordWrap <> 0 then
    Wrap := 2;
  ViewMode := {EditorDefaults.ViOpt and}Byte(Hex);
  Fl := AStream;
  if  (AFileName = '') and (Fl = nil) then
    Exit;
  TempFile := '';
  try
    if Fl = nil then
      ReadFile(AFileName, AVFileName, True)
    else if Fl.Status = stOK then
      ReadFile(' ', ' ', False);
  except
    on E: eFileError do
      Exit;
  end;
  {AK155 This is for auto-rereading a file with changing length,
    see Update }
  NewTimer(UpdateViewTmr, 500);
  RegisterToBackground(Self);
  {/AK155}
  end { TFileViewer.Init };

destructor TFileViewer.Destroy;
  begin
  EnableCommands([cmUnWrap]);
  if Buf <> nil then
    FreeMem(Buf, BufSize);
  Buf := nil;
  if Fl <> nil then
    Fl.Free;
  Fl := nil;
  if not (TottalExit or Exiting) and KillAfterUse then
    begin
    EraseTempFile(FileName);
    KillAfterUse := False;
    if not Startup.AutoRefreshPanels then
      RereadDirectory(GetPath(FileName));
    end;
  Info := nil;
  inherited Destroy;
  end;

constructor TFileViewer.Load(S: TStream);
  var
    FP: TFileSize;
  begin
  inherited Load(S);
  NoEdit := False;
  BufModified := False;
  GetPeerViewPtr(S, SB);
  GetPeerViewPtr(S, Info);
  S.ReadStrV(FileName);
  {S.Read(FileName[0], 1); S.Read(FileName[1], Length(FileName));}
  S.ReadStrV(VFileName);
  {S.Read(VFileName[0], 1); S.Read(VFileName[1], Length(VFileName));}
  S.Read(FP, SizeOf(FP));
  S.Read(QuickView, 1);
  S.Read(Wrap, 1);
  {???}
  S.Read(FakeKillAfterUse, 1);
  KillAfterUse := False;
  S.Read(Filter, 1);
  S.Read(ViewMode, 2);
  XCoder.Load(S);
  S.Read(MarkPos, SizeOf(MarkPos));
  Fl := nil;
  Buf := nil;
  isValid := True;
  Loaded := True;
  if  (FileName = '') and (VFileName = '') then
    isValid := False
  else
    begin
    try
      ReadFile(FileName, VFileName, True);
      Seek(FP);
      isValid := True;
    except
      on E: eFileError do
        ;
      {AK155 this happens e.g. when restarting DN
       with a remembered viewer on a missing floppy }
    end;
    end;
  end { TFileViewer.Load };

procedure TFileViewer.Store;
  var
    FP: TFileSize;
  begin
  inherited Store(S);
  PutPeerViewPtr(S, SB);
  PutPeerViewPtr(S, Info);
  S.WriteStr(@FileName); {S.Write(FileName[0], 1 + Length(FileName));}
  S.WriteStr(@VFileName); {S.Write(VFileName[0], 1 + Length(VFileName));}
  FP := FilePos+LongInt(BufPos);
  S.Write(FP, SizeOf(FP));
  S.Write(QuickView, 1);
  S.Write(Wrap, 1);
  S.Write(FakeKillAfterUse, 1);
  S.Write(Filter, 1);
  S.Write(ViewMode, 2);
  XCoder.Store(S);
  S.Write(MarkPos, SizeOf(MarkPos));
  end;

procedure XDumpStr(var S: String; var B; Addr: Int64; Count: Integer;
     Filter: Byte);
  var
    I: Integer;
    P: PByte;
    C: Byte;
  begin
  S := HexFilePos(Addr)+' ';
  P := @B;
  for I := 1 to Count do
    begin
    C := P^;
    Inc(P);
    if Filter <> 0 then
      if (C < 32) or ((Filter = 1) and (C >= 128)) then
        C := 250;
    S := S+Chr(C);
    end;
  end { XDumpStr };

{ tab field size }
function GetTabSize: Word;
  var
    TS: Word;
  begin
  GetTabSize := 1;
  if EditorDefaults.EdOpt and ebfTRp <> 0
  then
    begin
    TS := StoI(EditorDefaults.TabSize);
    if TS = 0 then
      GetTabSize := 8
    else if TS > 100 then
      GetTabSize := 100
    else
      GetTabSize := TS;
    end
  end;

procedure TFileViewer.Draw;
  var
    B: TDrawBuffer;
    C: Byte;
    I, K, M, Src: Integer;
    J: LongInt;
    L: TFileSize;
    S, SZ: String;
    IZ: Byte;
    TS: Word;
    C1: Byte;
    C2: Char;
    HP: String[6];
    CC: array[1..8] of Byte;
    SaveXDelta: Word;
    
    D: XCHGData; {GRM!}
    
    SearchLineNum: Integer;
    {screen line number with the found text, or -1 }
    SearchTextStart: Word;
    {X-coordinate in the window of the start of that text }
    ExpandTabs: Boolean;
    { Replace tabs with spaces }
  var
    W, W2, W3: Integer;
    WDH: Integer;
  begin { TFileViewer.Draw }
  ExposedPos := Lines[0].Pos;
  for I := 1 to 8 do
    CC[I] := GetColorW(I);
  TS := GetTabSize;
  ExpandTabs := EditorDefaults.EdOpt and ebfTRp <> 0;
  if  (Buf = nil) and not QuickView and
    not (VFileName = ' ')
    {AK155 11-01-2004
      happens in dbf view when viewing a memo, when the memo file is either
      empty or corrupt. VFileName = ' ' means an external stream and during
      normal operation Buf should not be nil}
    then
    begin
    ReadFile(FileName, VFileName, True);
    BufPos := 0;
    MakeLines;
    end
    (* {AK155 11-01-2003 these crazy checks probably once
        compensated for the effects of some bugs.
        But after BufSize became larger than $8000 they
        became harmful as-is, and there is no desire to update them,
        since the bugs themselves are probably long gone}
  else
  if (BufPos < 0) or (BufPos > BufSize + 20000) or
     (BufPos > 65000) then
  begin
    BufPos:=0;
    MakeLines;
  end *);
  C := CC[1];
  {AK155  if Info <> nil then Info.DrawView;}
  if {(FileName = '') or }(Buf = nil) then
    begin
    HideCursor;
    inherited Draw;
    Exit;
    end;
  SearchResultVisible := SearchActive;
  case ViewMode of
    vmHex:
      begin
      DisableCommands([cmUnWrap]);
      HexPos := (Size.X-12) div 4;
      if HexPos <= 0 then
        HexPos := 1;
      XDelta := 0;
      Src := 0;
      if not ScrollEOF then
        {AK155}
        begin
        while (LongInt(Cur.Y*HexPos)+BufPos+FilePos >= FileSize) do
          Dec(Cur.Y);
        while (LongInt(Cur.Y*HexPos)+BufPos+FilePos+Cur.X
            div (Byte(HexEdit)+1) >= FileSize)
        do
          Dec(Cur.X);
        end;
      if Cur.Y < 0 then
        begin
        W := -Cur.Y;
        Cur.Y := 0;
        CountUp(W);
        end
      else if Cur.Y >= Size.Y then
        begin
        W := Cur.Y-Size.Y+1;
        Dec(Cur.Y, W);
        CountDown(W);
        end;
      W := BufPos;
      L := FilePos+LongInt(BufPos);
      if HexEdit
      then
        SetCursor(11+(Cur.X div 2)*3+Cur.X and 1, Cur.Y)
      else
        SetCursor(12+HexPos*3+Cur.X, Cur.Y);
      ShowCursor;
      for I := 0 to Size.Y-1 do
        begin
        {MoveChar(B[XDelta], ' ', C, Size.X);} {???}
        if Size.X+XDelta > 255 then
          begin
          WDH := 255-XDelta;
          if WDH < 0 then
            WDH := 0;
          end
        else
          WDH := Size.X;
        MoveChar(B[XDelta], ' ', C, WDH);
        J := MinBufSize(FileSize-L, HexPos);
        if J > 0 then
          begin
          S := DumpStr(Buf^[W], L, J, Filter);
          W2 := Pos(#179, S);
          SetLength(SZ, Length(S)-W2);
          for IZ := 1 to Length(SZ) do
            if S[W2+IZ] = #0 then
              begin
              SZ[IZ] := #1;
              S[W2+IZ] := '.';
              end
            else
              SZ[IZ] := #0;
          XLatBuf(S[W2+1], Length(S)-W2, XCoder.XLatCP[ToAscii]);
          CpBytesToUtf8(S, W2+1); { UTF-8 inside: every byte is one character of the page }
          {-DataCompBoy & Axel: apply filter-}
          case Filter of
            0:
              ;
            1:
              for W3 := W2+1 to Length(S) do
                if not (Byte(S[W3]) in [32..127]) then
                  S[W3] := #250;
            else {case}
              for W3 := W2+1 to Length(S) do
                if not (Byte(S[W3]) in [32..255]) then
                  S[W3] := #250;
          end {case};
          {-DataCompBoy & Axel: done-}
          if J = HexPos then
            Drivers.MoveStr(B[0], S, C)
          else
            begin
            Drivers.MoveStr(B[0], Copy(S, 1, J*3+10), C);
            Drivers.MoveStr(B[10+HexPos*3], Copy(S, J*3+11,
                 MaxStringLength), C);
            end;
          for IZ := 1 to Length(SZ) do
            if SZ[IZ] = #1 then
              MoveColor(B[11+HexPos*3+IZ], 1, (CC[1] and $F0)+(CC[3] and $0F));
          if SearchActive then
            begin
            if  (L <= SearchX) and (L+J > SearchX) then
              begin
              Cur.Y := I;
              Cur.X := i32(SearchX-L)*2;
              if HexEdit
              then
                SetCursor(11+(Cur.X div 2)*3+Cur.X and 1, Cur.Y)
              else
                SetCursor(12+HexPos*3+Cur.X, Cur.Y);
              ShowCursor;
              Src := Min(i32(L+J-SearchX), Length(SearchString.What));
              MoveColor(B[11+i32(SearchX-L)*3], Src*3-1, CC[2]);
              MoveColor(B[12+HexPos*3+i32(SearchX-L)], Src, CC[2]);
              Src := Length(SearchString.What)-Src;
              end
            else if Src > 0 then
              begin
              K := Min(Src, J);
              MoveColor(B[11], K*3-1, CC[2]);
              MoveColor(B[12+HexPos*3], K, CC[2]);
              Dec(Src, J);
              end;
            end
          else {+piwamoto}
           if I = Cur.Y then
            begin
            K := Cur.X div (1+Byte(HexEdit));
            MoveColor(B[11+K*3], 2, CC[2]);
            MoveColor(B[12+HexPos*3+K], 1, CC[2]);
            end; {-piwamoto}
          Inc(W, J);
          L := L + J;
          end;
        {WriteLineC(0, I, Size.X, 1, B[XDelta]);} {???}
        WriteLineC(0, I, WDH, 1, B[XDelta]);
        end;
      end;
    vmDump:
      begin
      DisableCommands([cmUnWrap]);
      HideCursor;
      HexPos := ((Size.X-10) div 16)*16;
      if HexPos < 16 then
        HexPos := 16;
      W := BufPos;
      L := FilePos+LongInt(BufPos);
      Src := 0;
      for I := 0 to Size.Y-1 do
        begin
        {MoveChar(B[XDelta], ' ', C, Size.X);}
        if Size.X+XDelta > 255 then
          begin
          WDH := 255-XDelta;
          if WDH < 0 then
            WDH := 0;
          end
        else
          WDH := Size.X;
        MoveChar(B[XDelta], ' ', C, WDH);
        J := MinBufSize(FileSize-L, HexPos);
        if J > 0 then
          begin
          XDumpStr(S, Buf^[W], L, J, Filter); //!!s
          XLatBuf(S[10], Length(S)-9, XCoder.XLatCP[ToAscii]);
          CpBytesToUtf8(S, 10);
          Drivers.MoveStr(B[0], S, C);
          if SearchActive then
            begin
            if  (L <= SearchX) and (L+J > SearchX) then
              begin
              Src := Min(i32(L+J-SearchX), Length(SearchString.What));
              MoveColor(B[9+i32(SearchX-L)], Src, CC[2]);
              Src := Length(SearchString.What)-Src;
              end
            else if Src > 0 then
              begin
              MoveColor(B[9], Min(Src, J), CC[2]);
              Dec(Src, J);
              end;
            end;
          Inc(W, J);
          L := L + J;
          end;
        WriteLineC(0, I, WDH, 1, B[XDelta]);
        end;
      
      end;
    {GRM!}
    vmAsm:
      begin
      DisableCommands([cmUnWrap]);
      XDelta := 0;
      L := FilePos+LongInt(BufPos);
      D.MemBuff := Buf;
      D.Offset := BufPos;
      XDelta := 0;

      SetCursor(Cur.X, Cur.Y);
      ShowCursor;
      for I := 0 to Size.Y-1 do
        begin
        if Size.X+XDelta > 255 then
          begin
          WDH := 255-XDelta;
          if WDH < 0 then
            WDH := 0;
          end
        else
          WDH := Size.X;
        MoveChar(B[XDelta], ' ', C, WDH);
        if L < FileSize-1 then
          begin
          if Cur.Y = I then
            HexPos := i32(L-FilePos-BufPos)+((Cur.X-10) div 2);
          D.InstrMaxLen := MinBufSize(FileSize-L, 15);
          {Draw - doesn't matter}
          ScanCode(D);
          S := HexFilePos(L)
                +': '+D.CodeStr+Strg(' ', 29-Length(D.CodeStr))+
            D.Command+Strg(' ', 10-Length(D.Command))+
            D.Operands;
          Drivers.MoveStr(B[0], S, C);
          L := L + D.InstrLen;
          end;
        WriteLineC(0, I, WDH, 1, B[XDelta]);
        end;
      end
      {GRM!}
       {DisAsm}
    else {case}
      begin {vmText}
      ExposedLine := 0;
      EnableCommands([cmUnWrap]);
      {ak155        HideCursor;}
      { possibly shift XDelta so the found text becomes visible,
and determine its X-position (accounting for tabs) for later highlighting }
      SearchLineNum := -1;
      if SearchActive then
        begin
        for I := 0 to Size.Y-1 do
          begin
          J := i32(SearchX-FilePos-Lines[I].Pos);
          if  (J >= 0) and (J < Lines[I].len) then
            begin
            if not ExpandTabs then
              W := J
            else
              begin
              W := 0;
              for M := Lines[I].Pos to Lines[I].Pos+J-1 do
                begin
                if Buf^[M] = 9 then
                  Inc(W, TS-(W mod TS))
                else
                  Inc(W);
                end;
              end;
            if  (XDelta+Size.X < W+Length(SearchString.What))
              or (XDelta > W)
            then
              XDelta := W+(Length(SearchString.What)-Size.X) div 2;
            if XDelta < 0 then
              XDelta := 0;
            SearchLineNum := I;
            SearchTextStart := W-XDelta;
            Break;
            end;
          end;
        end;

      for I := 0 to Size.Y-1 do
        begin
        MoveChar(B[0], ' ', C, Size.X);
        S := '';
        if  (Lines[I].Pos >= 0) then
          begin
          ExposedLine := I;

          {-DataCompBoy: Expand tabs...-} {AK155: and apply the filter }
          W := 0;
          for M := Lines[I].Pos to Lines[I].Pos+Lines[I].len-1 do
            begin
            C2 := Char(Buf^[M]);
            if  (C2 = #9) and ExpandTabs then
              repeat
                Inc(W);
                if W > XDelta then
                  S[W-XDelta] := ' ';
              until W mod TS = 0
            else
              begin
              Inc(W);
              if W > XDelta then
                S[W-XDelta] := C2;
              end;
            if W-XDelta > Size.X then
              Break;
            end;
          if W > XDelta then
            begin
            SetLength(S, W-XDelta);
            XLatBuf(S[1], Length(S), XCoder.XLatCP[ToAscii]);
            if XCoder.KeyMap <> kmAscii then
              CpBytesToUtf8(S, 1); { UTF-8 inside: the text that went through a table is of the code page; the text with no table is shown as UTF-8 }
            {Cat: the filter was moved here - it must be applied
      after the recoding table}
            case Filter of
              1:
                for W := 1 to Length(S) do
                  if not (Byte(S[W]) in [32..127]) then
                    S[W] := #250;
              2:
                for W := 1 to Length(S) do
                  if not (Byte(S[W]) in [32..255]) then
                    S[W] := #250;
            end {case};
            {/Cat}
            MoveStr(B[0], S, C (*, Filter, TS*));
            if HiLite and not QuickView then
              begin
              Highlites(Length(S), @S[1], HiLitePar);
              C1 := C and $F0; { Background }
              SetLength(HP, 6); { Attr. size }
              HP[Ord(hhComment)] := Chr(CC[3]); { Comments   }
              HP[Ord(hhNumber)] := Chr(C1 or (CC[6] and 15));
              { Numbers    }
              HP[Ord(hhString)] := Chr(C1 or (CC[5] and 15));
              { Strings    }
              HP[Ord(hhSymbol)] := Chr(C1 or (CC[4] and 15));
              { Symbols    }
              HP[Ord(hhKeyword1)] := Chr(C1 or (CC[7] and 15));
              { Keywords 1 }
              HP[Ord(hhKeyword2)] := Chr(C1 or (CC[8] and 15));
              { Keywords 2 }
              DoHighlite(B[0], S, HP);
              end;
            end;

          end;
        if I = SearchLineNum then
          { highlight the found text }
          MoveColor(B[SearchTextStart], Length(SearchString.What), CC[2]);
        WriteLineC(0, I, Size.X, 1, B[0]);
        end;
      end;
    if ExposedLine > MaxLines then
      ExposedPos := Lines[ExposedLine].Pos+Lines[ExposedLine].len
    else if Lines[ExposedLine+1].Pos < 0 then
      ExposedPos := BufSize
    else
      ExposedPos := Lines[ExposedLine+1].Pos
  end {case};
  if Info <> nil then
    Info.DrawView;
  end { TFileViewer.Draw };

function TFileViewer.ReadFile;
  var
    CodePageDetector: TCodePageDetector;
    I, J: Integer;
    P: Pointer;
    Macros: TCollection;
    ClusterLen: TSize;
    NumFiles, NumDirs: Integer;
    DirLen: TSize;
    DirString: String;
    ReadDir: Boolean;
    Nm: String; {John_SW 14-09-2002}
    Xt: String; {John_SW 14-09-2002}
  begin
  ReadFile := True;
  WriteModify;
  if Buf <> nil then
    FreeMem(Buf, BufSize);
  Buf := nil;
  BufModified := False;
  isValid := True;
  FileName := FName;
  VFileName := VFName;
  if NewStream then
    begin
    if Fl <> nil then
      Fl.Free;
    Fl := nil;
    if FName = '' then
      Exit;
    Fl := TDosStream.Create(FName, stOpenRead);
    end;

  { If FName is a directory name, build a buffer (no Stream) with
text data about the directory contents. Used in QuickView
when the cursor is on a directory AK155}
  ReadDir := True;
  I := Length(FName);
  if Copy(FName, I-2, 3) = '\..' then
    begin
    SetLength(FileName, I-3);
    DirString := FileName;
    end
  else if (I = 2) and (FileName[2] = ':') then
    DirString := FileName
      {this happens e.g. when restarting
     DN with a remembered Branch state at the drive root }
  else if (FileName = ' ') or not IsDir(FileName) then
    {Cat: the space check is needed because IsDir returns True for it, which we
        do not want, since a space means the viewer is used
        not for a specific file but for a stream passed to the constructor}
    ReadDir := False;
  if ReadDir then
    begin
    DirLen := CountDirLen(FileName, True, ClusterLen, NumFiles, NumDirs);
    DirString := FileName+#$0D#$0A#$0D#$0A+
      GetString(dlDirectories)+': '+FStr(NumDirs)+#$0D#$0A#$0D#$0A+
      GetString(dlDIFiles)+': '+FStr(NumFiles-NumDirs)+#$0D#$0A#$0D#$0A+
      GetString(dlDIBytes)+': '+FStr(DirLen);
    BufSize := Length(DirString);
    BufPos := 0;
    FilePos := 0;
    FileSize := BufSize;
    GetMem(Buf, 100);
    Move(DirString[1], Buf^, Length(DirString));
    MakeLines;
    Fl.Status := stOK; { clear stInitError }
    Exit;
    end;
  BreakOnStreamReadError;
  {see panelroot, TFilePanelRoot.SendLocated;}

  (*  if (not ExistFile(FName) or isDir(FName)) and
     (FName <> '') and (FName <> ' ') then begin ReadFile:=false; Exit; end;
*)
  Macros := nil;
  lFSplit(VFName, FreeStr, Nm, Xt); {John_SW 14-09-2002}
  {PZ 2000.06.09 }
  if  (EditorDefaults.ViOpt and vbfHlt) <> 0 then
    HiLite := Macro.InitHighLight(Nm+Xt, HiLitePar, Macros, nil);
  {PZ end}
  ScrollEOF := (EditorDefaults.ViOpt and vbfScrollAfterEOF) <> 0;
  {AK155}
  FileSize := Fl.GetSize;
  FilePos := 0;
  I := 1;
  NumLines := 1;
  if FileSize < 0 then
    FileSize := 0;
  AdjustBuf;
  if SB <> nil then
    TViewScroll(SB).MaxV := FileSize;
  Seek(0);
  XDelta := 0;
  if  (UpStrg(VFileName) <> UpStrg(FileName)) then
    begin
    KillAfterUse := True;
    Filtr := True;
    end
  else
    Filtr := False;
  BreakOnStreamReadError;
  XCoder.KeyMap := ProcessDefCodepage(DefCodePageView);
  if XCoder.KeyMap = kmNone then
    begin
    CodePageDetector := TCodePageDetector.Create;
    CodePageDetector.CheckString(PChar(Buf), BufSize);
    XCoder.KeyMap := CodePageDetector.DetectedCodePage;
    XCoder.UseKeyMap;
    end;
  end { TFileViewer.ReadFile };

procedure TFileViewer.ChangeFile(FR: PFileRec);
  begin
  end;

procedure TFileViewer.SetState;
  begin
  inherited SetState(AState, Enable);
  if  (AState and (sfActive+sfSelected) <> 0) then
    begin
    if GetState(sfSelected) and (Owner.GetState(sfActive)) then
      begin
      if SB <> nil then
        begin
        SB.Show;
        SB.EventMask := $FFFF
        end;
      DrawView
      end
    else if SB <> nil then
      begin
      SB.Hide;
      SB.EventMask := 0;
      end;
    end;
  if  (Info <> nil) then
    if  (AState and sfDragging <> 0)
      or (AState and (sfSelected+sfActive) <> 0)
    then
      Info.Draw;
  end { TFileViewer.SetState };

procedure TFileViewer.Seek(APos: TFileSize);
  var
    NewPos: TFileSize;
  begin
  if Buf = nil then
    Exit;
  FileSize := Fl.GetSize;
  WriteModify;
  if APos < 0 then
    APos := 0;
  FilePos := APos;
  if FilePos < 0 then
    FilePos := 0;
  if FilePos = 0 then
    begin
    AdjustBuf;
    if Buf = nil then
      Exit;
    end;
  if APos+BufSize >= FileSize then
    FilePos := FileSize-BufSize;
  Fl.Seek(FilePos);
  if  (FileSize-FilePos < BufSize) then
    begin
    FreeMem(Buf, BufSize);
    BufSize := Max(i32(FileSize-FilePos), 0);
    Buf := GetMem(BufSize);
    if Buf = nil then
      Exit;
    end;
  BufPos := i32(APos-FilePos);
  if BufPos < 0 then
    BufPos := 0;
  if BufPos >= BufSize then
    BufPos := BufSize-1;
  Fl.Read(Buf^, BufSize);
  BreakOnStreamReadError;
  MakeLines;
  NewPos := FilePos+BufPos;
  Message(SB, evCommand, cmChangeValue, @NewPos);
  end { TFileViewer.Seek };

procedure TFileViewer.MakeLines;
  var
    K: LongInt;
    LineLen: LongInt;
    LineStart: LongInt;
    TabsWith: LongInt; { Tab characters additional with }
    MaxX: LongInt;
    LineSeparatorLen: LongInt;
    TabSize: Integer;
    CurChar, NextChar: Byte;
    WrappedLine: Boolean;
    
    X: XCHGData; {GRM!}
    
  label
    LineBegin;
  begin
  if Buf = nil then
    Exit;
  LineStart := BufPos;
  LineLen := BufSize-LineStart;
  FillChar(Lines, SizeOf(Lines), $FF); {AK155}
  TabSize := GetTabSize;
  MaxLines := MaxILines;
  case ViewMode of
    vmHex, vmDump:
      begin
      MaxX := 255;
      LineLen := BufPos;
      for K := 0 to MaxLines do
        begin
        Lines[K].Pos := LineLen;
        Lines[K].len := HexPos;
        Inc(LineLen, HexPos);
        end;
      
      end;
    {GRM!}
    vmAsm:
      begin
      MaxX := 255;
      X.MemBuff := Buf;
      X.Offset := BufPos;
      for K := 0 to MaxLines do
        begin
        Lines[K].Pos := X.Offset;
        X.InstrMaxLen := MinBufSize(FileSize-X.Offset-FilePos-1, 15);
        ScanCode(X);
        Lines[K].len := X.InstrLen;
        if X.InstrLen = 0 then
          Lines[K].Pos := -1;
        end;
      end
      {GRM!}
      
    else {vmText}
      begin
      if Wrap > wmNone then
        MaxX := Size.X
      else
        MaxX := MaxWrapW;
      WrappedLine := False;
      for K := 0 to MaxLines do
        begin {-DataCompBoy-}
        {AK155}
LineBegin:
        if LineStart >= BufSize then
          begin
          Lines[K].Pos := -1;
          Continue;
          end;
        Lines[K].Pos := LineStart;
        {Search for e.nd of line}
        LineLen := 0;
        TabsWith := 0;
        LineSeparatorLen := 0;
        while (LineLen+TabsWith < MaxX) and (LineStart+LineLen < BufSize)
        do
          begin
          CurChar := Buf^[LineStart+LineLen];
          NextChar := 0;
          if  (LineStart+LineLen+1 < BufSize) then
            NextChar := Buf^[LineStart+LineLen+1];
          if  (CurChar in [$0D, $0A]) then
            begin
            LineSeparatorLen := 1;
            if  (NextChar in [$0D, $0A]) and (CurChar <> NextChar) then
              LineSeparatorLen := 2;
            if WrappedLine and (LineLen = 0) then
              begin {ignore line separator exact after wrapped line}
              Inc(LineStart, LineSeparatorLen);
              WrappedLine := False;
              goto LineBegin;
              end;
            WrappedLine := False;
            Break;
            end;
          if CurChar = 9 then
            Inc(TabsWith, TabSize-1-((LineLen+TabsWith) mod TabSize));
          Inc(LineLen);
          WrappedLine := True;
          end;
        Lines[K].len := LineLen;

        {Decrease length of word-wrapped line}
        if  (Wrap = wmWords) and (LineLen+TabsWith >= MaxX) then
          begin
          while (LineLen > 1) and
            not (Char(CurChar) in BreakChars) and
            not (Char(NextChar) in BreakChars)
          do
            begin
            Dec(LineLen);
            NextChar := CurChar;
            CurChar := Buf^[LineStart+LineLen-1];
            end;
          if LineLen > 1 then
            begin
            Lines[K].len := LineLen;
            WrappedLine := True;
            end;
          end;

        Inc(LineStart, Lines[K].len+LineSeparatorLen);
        end; {-DataCompBoy-}
      end;
  end {case};
  end { TFileViewer.MakeLines };

procedure TFileViewer.SaveToFile(FN: String);
  var
    S: TStream;
    P: TView;
    W, L: Word;
    PS: Pointer;
    Xl: Boolean;
    Sz: TFileSize;
  label 2;

  begin
  Xl := (MaxAvail > 4096) and
      (XCoder.KeyMap <> kmAscii) and
      (MessageBox(GetString(dlViewSaveXlat), nil,
        mfYesButton+mfNoButton+mfConfirmation) = cmYes);
  S := TDosStream.Create(FN, stOpen);
  W := 0; {AK155: so it is always defined }
  if S.Status = stOK then
    begin
    PS := @FN;
    W := MessageBox(GetString(dlED_OverQuery)
        , @PS, mfYesButton+mfCancelButton+mfAppendButton+mfWarning);
    if W = cmYes then
      begin {existing file}
      {AK155 This reopen causes a severe OS/2
error when trying to save recoded text into the
same file. It is only needed so that overwriting
a long file with a short one gets the new (smaller) length. But that
is achieved much more directly with Truncate.
            S.Free;
            S := TDosStream.Create(FN, stCreate);
/AK155}
      end
    else if W = cmOK then
      S.Seek(S.GetSize)
    else
      begin
      S.Free;
      Exit
      end;
    end
  else
    begin {new file}
    S.Free; {JO}
    S := TDosStream.Create(FN, stCreate); {JO}
    end;

  if S.Status <> stOK then
    begin
    S.Free;
    MessageBox(GetString(dlFBBNoWrite)+Cut(FN, 40), nil,
       mfError+mfOKButton);
    Exit
    end;
  P := _WriteMsg(^M^M^C+GetString(dlWritingFile));
  Fl.Seek(0);
  BreakOnStreamReadError;
  if Xl then
    begin
    PS := GetMem(4096);
    if PS = nil then
      goto 2;
    Sz := Fl.GetSize;
    while Fl.GetPos < Sz do
      begin
      L := MinBufSize(Sz-Fl.GetPos, 4096);
      Fl.Read(PS^, L);
      BreakOnStreamReadError;
      XLatBuf(PS^, L, XCoder.XLatCP[ToAscii]);
      S.Write(PS^, L);
      end;
    FreeMem(PS, 4096);
    end
  else
2:
    S.CopyFrom(Fl, Fl.GetSize);
  P.Free;
  S.Truncate; {AK155 in case a short file is written over a long one}
  S.Free;
  FN := GetPath(FN);
  MakeNoSlash(FN);
  if not Startup.AutoRefreshPanels then
    GlobalMessage(evCommand, cmRereadDir, @FN);
  end { TFileViewer.SaveToFile };

procedure TFileViewer.SeekBof;
  begin
  SearchX := 0;
  Seek(0);
  if ViewMode = vmAsm
  then
    Cur.Assign(10, 0)
  else
    Cur.Assign(0, 0);
  XDelta := 0;
  DrawView
  end;

{AK155}
{ Show a message, close the window, and raise an exception }
function TFileViewer.BreakOnStreamReadError: Boolean;
  var
    E: eFileError;
  begin
  BreakOnStreamReadError := False;
  if Fl.Status <> stOK then
    begin
    if Fl.Status = stInitError then
      MessFileNotOpen(FileName, Fl.ErrorInfo)
    else
      MessFileNotRead(FileName, Fl.ErrorInfo);
    BreakOnStreamReadError := True;
    E := eFileError.Create('TFileViewer stream read error');
    E.RC := Fl.ErrorInfo;
    { actually this message and RC are needed by nobody, but it may
      help if not all BreakOnStreamReadError calls are wrapped in
      try - except and the exception turns out fatal}

    { In QuickView the viewer is not in a standalone window
but directly in the file manager, so closing the owner in QuickView
is not just unnecessary but forbidden }
    if  (Owner <> nil) and not QuickView then
      Owner.Free;
    isValid := False;
    raise E;
    end;
  end { TFileViewer.BreakOnStreamReadError: };
{/AK155}

procedure TFileViewer.SeekEof;
  var
    i, j: Integer;
    OldFileSize: TFileSize;
    OldStart: TFileSize;
    WC: TFileSize;
    WL: Longint absolute WC;
    OldLen1: LongInt;
    Temp: LongInt;
  label
    EndProc;
  begin
  with Lines[Cur.Y] do
    begin
    if Pos < 0 then
      Exit;
    if Pos+len >= Fl.GetSize then
      Exit;
    end;
  if ViewMode = vmText then
    begin
    OldStart := FilePos+Lines[0].Pos;
    OldLen1 := Lines[0].len;
    end
  else
    begin
    OldStart := FilePos+Lines[Cur.Y].Pos;
    OldLen1 := HexPos;
    end;
  WC := FilePos+BufPos;
  i := WL mod 16;
  Owner.Lock;
  {AK155}
  if Fl is TDOSStream then
    begin
    with TDosStream(Fl) do
      begin
      if  (Status <> stOK) then
        goto EndProc;

      OldFileSize := FileSize;
      SysFileSeek(Handle, 0, 2, StreamSize);
      FileSize := StreamSize;
      if FileSize < OldFileSize then
        begin { The file shrank }
        if Position > FileSize then
          Position := StreamSize;
        end;
      SysFileSeek(Handle, Position, 0, Temp);
      Seek(Position);
      end;

    if  (OldFileSize < FileSize) and (BufSize < FileSize) then
      begin
      AdjustBuf;
      if Buf = nil then
        goto EndProc;
      end;
    end;

  Seek(FileSize-BufSize);
  if  (ViewMode = vmHex) or (ViewMode = vmDump) then
    begin
    BufPos := BufSize-Size.Y*HexPos;
    if BufPos < OldStart-FilePos then
      BufPos := i32(OldStart-FilePos);
    MakeLines;
    end
  else
    begin
    BufPos := BufSize;
    {AK155: Why scroll 3 lines back and forth is unclear. For bugs?
   CountUp(Size.Y+3);
   CountDown(3);}
    CountUp(Size.Y); {AK155}
    MakeLines;

    i := 0;
    while (i < MaxLines) and (FilePos+Lines[i].Pos < OldStart) do
      Inc(i);
    if i <> 0 then
      begin
      if FilePos+Lines[i].Pos > OldStart then
        begin
        Lines[0].Pos := i32(OldStart-FilePos);
        Lines[0].len := OldLen1;
        j := 1;
        end
      else
        j := 0;
      Move(Lines[i], Lines[j], SizeOf(Lines[0])*(MaxLines-i-j));
      Dec(MaxLines, i-j);
      end;
    BufPos := Lines[0].Pos;
    end;

  if  (ViewMode = vmHex) and (FileSize <> 0) then
    begin
    i := i32(FileSize-(FilePos+BufPos)-1);
    Cur.Y := i div HexPos;
    Cur.X := i mod HexPos*2;
    end;
  DrawView;

EndProc:
  Owner.UnLock;
  end { TFileViewer.SeekEof };

procedure TFileViewer.HandleEvent;

  var
    P: TPoint;
    LR: Integer;
    I: Integer;
    LLR, LFR: LongInt;
    ALLR, ALFR: TFileSize;
    F: lFile;
    Ch: Char;
    Lin: Byte;

  procedure CE;
    begin
    ClearEvent(Event)
    end;

  procedure CM_END;
    var
      I, MaxW: Integer;
      w, l: Integer;
      TabSize: Integer;

    begin
    if Buf = nil then
      Exit;
    TabSize := GetTabSize;
    MaxW := 0;
    CE;
    for I := 0 to Size.Y-1 do
      begin
      w := 0;
      for l := Lines[I].Pos to Lines[I].Pos+Lines[I].len-1 do
        begin
        Inc(w);
        if Buf^[l] = 9 then
          Inc(w, TabSize-1-l mod TabSize);
        end;
      if MaxW < w then
        MaxW := w;
      end;
    Dec(MaxW, Size.X);

    if MaxW < 0 then
      XDelta := 0
    else
      XDelta := MaxW;
    DrawView;
    end { CM_END };

  procedure ContinueSearch(Reverse: Boolean);
    var
      I {, J, JJ}: Integer;
      Backward: Boolean;
      CaseSensitive: Boolean;
    begin
    if  (SearchString.What = '') then
      Exit;
    if SearchX < 0 then
      SearchX := 0;
    if  (SearchX < FilePos+Lines[0].Pos)
      { or
     (SearchX > FilePos + Lines[1].Pos+1)} {AK155}
      then
      SearchX := FilePos+BufPos;
    Backward := (SearchString.Dir = 1) xor Reverse;
    if SearchResultVisible and (Backward <> PrevSearchDir)
    then { search direction change: must skip
          the text just found in the other direction }
      begin
      if Backward then
        SearchX := SearchX - length(SearchString.What)
      else
        SearchX := SearchX + length(SearchString.What);
      end;
    CaseSensitive := SearchString.Opts and 1 <> 0;
    SearchX := SearchFileStr(Fl,
        XCoder.XLatCP[Ord(CaseSensitive)],
        SearchString.What, SearchX,
        CaseSensitive,
        True,
        SearchString.Opts and 2 <> 0, Backward,
        SearchString.Opts and 4 <> 0,
        SearchString.Opts and 8 <> 0);
    if SearchX >= 0 then
      begin
      {if HexPos > 0 then JJ := (FilePos+BufPos) mod HexPos;}
      Seek(SearchX);
      CountUp(3);
      SearchActive := True;
      BufPos := Lines[0].Pos;
      MakeLines;
      DrawView;
      SearchActive := False;
      if not Backward then
        SearchX := SearchX + length(SearchString.What);
      PrevSearchDir := Backward;
      end
    else if SearchX <> -2 then
      MessageBox(GetString(dlDBViewSearchNot), nil,
         mfInformation+mfOKButton);
    end { ContinueSearch };

  procedure StartSearch;
    var
      D: TDialog;
      SR: TViewSearch;
      R: TRect;
      P: TView;
      I: Integer;

    begin

    D := TDialog(LoadResource(dlgViewerFind));
    D.SetData(SearchString);
    I := Desktop.ExecView(D);
    D.GetData(SR);
    D.Free;
    if I = cmCancel then
      Exit;
    SearchString := SR;
    {AK155}
    SearchX := FilePos+Lines[0].Pos;
    if SR.Dir = 1 then
      begin {backward}
      I := Size.Y-1;
      while (I <> 0) and (Lines[I].Pos < 0) do
        Dec(I);
      SearchX := FilePos+Lines[I].Pos+Lines[I].len + 1;
      end;
    {/AK155}
    ContinueSearch(False);
    end { StartSearch };


  label 1, 2, DoSave, KBCheck, NotKb;

  var
    ScrollerPos: LongInt;
    WC: TFileSize;
    WL: Longint absolute WC;

  begin { TFileViewer.HandleEvent }

  try

    inherited HandleEvent(Event);
    case ViewMode of
      vmText,
      vmHex:
        begin
        HexPos := (Size.X-12) div 4;
        if HexPos <= 0 then
          HexPos := 1;
        end;
      vmDump:
        begin
        HexPos := ((Size.X-9) div 16)*16;
        if HexPos < 16 then
          HexPos := 16;
        end;
    end {case};
    if Loaded then
      begin
      Loaded := False;
      if SB <> nil then
        begin
        TViewScroll(SB).MaxV := FileSize;
        TViewScroll(SB).Value := FilePos+BufPos;
        end;
      TViewScroll(SB).DrawView;
      end;
    case Event.What of
      evBroadcast:
        case Event.Command of
          cmFindView:
            if  (PString(Event.InfoPtr)^ = FileName) or
                (PString(Event.InfoPtr)^ = VFileName)
            then
              if (Owner <> nil) and not QuickView then
                begin
                Owner.Select;
                ClearEvent(Event);
                end;
          cmReanimator:
DoSave:
              if  (Fl <> nil) and (Fl.Status = stOK) then
                begin
                CE;
                FreeStr := GetFileNameDialog(x_x, GetString(dlSaveFileAs),
                    GetString(dlSaveFileAsName),
                    fdOKButton+fdHelpButton, hsEditSave);
                if FreeStr <> '' then
                  SaveToFile(FreeStr);
                end;
          cmReleaseFile:
            begin
            if UpStrg(FileName) = UpStrg(PString(Event.InfoPtr)^) then
              begin
              ReadFile('', '', True);
              {if not QuickView then Message(Owner, evCommand, cmClose, nil);}
              end;
            end;
        end {case};
      evCommand:
        case Event.Command of
          cmFileEdit:
            if DelSpaces(FileName) <> '' then
              begin
              if Filtr and
                  (MessageBox(GetString(dlViewFilter), nil,
                    mfConfirmation+mfYesButton+mfNoButton) <> cmYes)
              then
                begin
                CE;
                Exit
                end;
              WriteModify;
              {if Desktop<>nil then Desktop.Lock;}
              if (Application <> nil) and (FileSize < $7FFFFFF) then
                begin
                if FileName <> VFileName then
                  TempFile := '*^&'+FileName;
                TDNApplication(Application).EditFile(True, FileName);
                MessageL(Application, evCommand, cmGotoLineNumber2,
                  GetLineNumberForOffset(FileName, i32(FilePos+BufPos))
                  );
                end;
              {if Desktop<>nil then Desktop.UnLock;}
              CE;
              if  (Owner <> nil) and (Owner is TFileWindow)
              then
                Message(Owner, evCommand, cmClose, nil);
              end;
          cmPlaceMarker1..cmPlaceMarker9:
            begin
            I := Event.Command-cmPlaceMarker1+1;
            if  (I >= 1) and (I <= 9) then
              begin
              with MarkPos[I] do
                begin
                if  (Y = -1) or
                    (Y <> FilePos+BufPos) or
                    (X <> Byte(HexEdit)*256*256
                    +Cur.Y*256+Cur.X)
                then
                  begin
                  X := Byte(HexEdit)*256*256+Cur.Y*256+Cur.X;
                  Y := FilePos+BufPos;
                  end
                else
                  begin
                  X := -1;
                  Y := -1;
                  end;
                end;
              DrawView;
              end;
            CE;
            end;
          cmGoToMarker1..cmGoToMarker9:
            begin
            I := Event.Command-cmGoToMarker1+1;
            if  (I >= 1) and (I <= 9) and (MarkPos[I].Y <> -1) then
              begin
              Cur.X := MarkPos[I].X mod 256;
              Cur.Y := (MarkPos[I].X div 256) mod 256;
              HexEdit := (MarkPos[I].X div (256*256)) = 0;
              Seek(MarkPos[I].Y);
              MakeLines;
              DrawView;
              end;
            CE;
            end;
          cmGotoCell:
            begin
            CE;
            FreeStr := '';
            if ViewMode = vmText then
              begin
              if ExecResource(dlgGotoLine, FreeStr) <> cmOK then
                Exit;
              Val(FreeStr, LLR, I);
              if I <> 0 then
                Exit;
              LLR := GetOffsetForLineNumber(FileName, LLR);
              if LLR < 0 then
                Exit;
              Seek(LLR);
              MakeLines;
              DrawView;
              end
            else
              begin
              if ExecResource(dlgGotoAddress, FreeStr) <> cmOK then
                Exit;
              Val('$'+FreeStr, ALLR, I);
              if (I <> 0) or (ALLR < 0) then
                Exit;
              ALFR := ALLR;
              Cur.Assign(0, 0);
              {JO} 
              if ViewMode <> vmAsm then
                begin
                
                WC := BufPos+FilePos;
                while (FSizeMod(ALFR, HexPos) <> (WL mod HexPos)) and (LFR > 0)
                do
                  begin
                  ALFR := ALFR-1;
                  Inc(Cur.X, (1 + Byte(HexEdit)));
                  end;
                
                end
              else
                Cur.X := 10;
              {/JO} 
              Seek(ALFR);
              MakeLines;
              DrawView;
              end;
            end;
          cmLoadXlatTable:
            begin
            XCoder.LoadXlatTable;
            DrawView;
            end;
          cmAddFilter:
            begin
            Filter := (Filter+1) mod 3;
            DrawView;
            CE
            end;
          cmSave:
            begin
            WriteModify;
            CE
            end;
          cmSaveAll:
            goto DoSave;
          cmGetName:
            if VFileName <> ''
            then
              PString(Event.InfoPtr)^:= GetString(dlViewFile)+' - '+
                (VFileName)
            else
              PString(Event.InfoPtr)^:= GetString(dlViewFile);
          cmLoadViewFile:
            begin
            ChangeFile(Event.InfoPtr);
            CE;
            end;
          cmClose, cmQuit, cmKillUsed:
            if WriteModify then
              CE;
          cmSearchFor:
            begin
            StartSearch;
            CE
            end;
          cmReverseSearch,
          cmContinueSearch:
            begin
            ContinueSearch(Event.Command = cmReverseSearch);
            CE
            end;
          cmHexMode:
            begin
            case ViewMode of
              vmText:
                begin
                ViewMode := vmHex;
                HexEdit := True;
                end;
              vmHex:
                begin
                ViewMode := vmDump;
                end;
              
              vmDump:
                if  ( (EditorDefaults.ViOpt and vbfDisAsm) <> 0) then
                  begin
                  ViewMode := vmAsm;
                  HexEdit := True;
                  MakeLines;
                  Cur.X := 10;
                  end {GRM!}
                else
                  begin
                  ViewMode := vmText;
                  MakeLines
                  end;
              
              else {case}
                begin
                ViewMode := vmText;
                HideCursor;
                MakeLines
                end;
            end {case};
            if ViewMode <> vmDump then
              begin
              HexPos := (Size.X-12) div 4;
              if HexPos <= 0 then
                HexPos := 1;
              end
            else
              begin
              HexPos := ((Size.X-9) div 16)*16;
              if HexPos < 16 then
                HexPos := 16;
              MakeLines
              end;
            DrawView;
            CE
            end;
          cmUnWrap:
            begin
            Inc(Wrap);
            if Wrap > wmWords then
              Wrap := wmNone;
            MakeLines;
            if Lines[Size.Y-1].Pos < 0 then
              SeekEof;
            DrawView;
            CE;
            end;
          cmScrollBarChanged:
            begin
            Desktop.Lock;
            Seek(PComp(Event.InfoPtr)^);
            if  (ViewMode = vmText) and (Event.InfoLong <> 0) then
              begin
              { move to the start of the line, but so
                 as not to shift the cursor slider upward }
              CountDown(1);
              ScrollerPos := TViewScroll(SB).GetPartCode;
              CountUp(1);
              if ScrollerPos <> TViewScroll(SB).GetPartCode then
                CountDown(1);
              end;
            if Lines[Size.Y-1].Pos < 0 then
              SeekEof
            else
              DrawView;
            Desktop.UnLock;
            end;
          cmSwitchKeyMapping:
            begin
            XCoder.NextXLat;
            DrawView;
            end;
        end {case};

      evKeyDown:
        case DNKeyCode(Event) of
          kbCtrlHome:
            if ViewMode = vmHex then
              begin
              Cur.Y := 0;
              DrawView;
              CE;
              end
            else
              goto 1;
          kbCtrlEnd:
            if ViewMode = vmHex then
              begin
              Cur.Y := Size.Y-1;
              DrawView;
              CE;
              end
            else
              goto 2;
          kbESC {, kbEnter}:
            if not QuickView then
              begin
              CE;
              Message(Application, evCommand, cmClose, nil)
              end;
          kbCtrlLeft:
            if ViewMode = vmText then
              begin
              CE;
              if XDelta > 19 then
                Dec(XDelta, 20)
              else
                XDelta := 0;
              DrawView
              end
            else (*if ViewMode <> vmAsm then {GRM!}*)
              begin
              if BufPos > 0 then
                Dec(BufPos)
              else if FilePos > 100 then
                begin
                Owner.Lock;
                Seek(FilePos-100);
                BufPos := 99;
                Owner.UnLock;
                end;
              DrawView;
              CE
              end;

          kbCtrlRight:
            if ViewMode = vmText then
              begin
              CE;
              if XDelta < MaxWrapW*8-Size.X-19 then
                Inc(XDelta, 20);
              DrawView
              end
            else (*if ViewMode <> vmAsm then {GRM!}*)
              begin
              if BufPos < BufSize-1024 then
                Inc(BufPos)
              else
                begin
                Owner.Lock;
                Seek(FilePos+BufPos+1);
                Owner.UnLock;
                end;
              DrawView;
              CE
              end;
          kbTab:
            if ViewMode = vmHex then
              begin
              if HexEdit then
                Cur.X := Cur.X div 2
              else
                Cur.X := Cur.X*2;
              HexEdit := not HexEdit;
              DrawView;
              CE
              end;
          kbCtrlPgUp:
            begin
1:
            CE;
            SeekBof;
            end;
          kbCtrlPgDn:
            begin
2:
            Lines[Size.Y].Pos := 0; {piwamoto}
            SeekEof;
            SearchX := FileSize;
            CE
            end;
          kbHome:
            begin
            CE;
            if ViewMode = vmHex then
              Cur.X := 0
            else
              XDelta := 0;
            DrawView
            end;
          kbEnd:
            if ViewMode <> vmHex then
              CM_END
            else
              begin
              Cur.X := HexPos*(Byte(HexEdit)+1)-1;
              DrawView
              end;
          kbDown:
            case ViewMode of
              {GRM!}
              vmText, vmDump:
                begin
                CE;
                CountDown(1);
                DrawView;
                end;
              vmHex:
                begin
                Inc(Cur.Y);
                DrawView;
                CE;
                end;
              
              vmAsm:
                if Cur.Y = Size.Y-1 then
                  begin
                  CountDown(1);
                  DrawView;
                  CE;
                  end
                else if Lines[Cur.Y+1].Pos <> -1 then
                  begin
                  Inc(Cur.Y);
                  Cur.X := 10;
                  DrawView;
                  CE;
                  end;

              
            end {case}; {GRM!}
          kbPgDn:
            begin
            CE;
            CountDown(Size.Y-1);
            DrawView;
            end;
          kbSpace:
            if ViewMode in [vmText, vmDump]
            then
              begin
              CE;
              CountDown(Size.Y-1);
              DrawView;
              end
            else
              goto KBCheck;
          kbUp:
            case ViewMode of
              {GRM!}
              vmText,
              vmDump:
                begin
                CE;
                CountUp(1);
                DrawView;
                end;
              vmHex:
                begin
                Dec(Cur.Y);
                DrawView;
                CE;
                end;
              
              vmAsm:
                if Cur.Y = 0 then
                  begin
                  CountUp(1);
                  DrawView;
                  CE;
                  end
                else
                  begin
                  Cur.X := 10;
                  Dec(Cur.Y);
                  DrawView;
                  CE;
                  end;
              
            end {case}; {GRM!}
          kbPgUp:
            begin
            CE;
            CountUp(Size.Y-1);
            DrawView;
            if BufPos = 0 then
              begin
              TViewScroll(SB).Value := 0;
              SB.DrawView;
              end;
            end;
          kbLeft:
            if ViewMode = vmText then
              begin
              CE;
              if XDelta > 0 then
                Dec(XDelta);
              DrawView
              end
            else
              
              {GRM!}
             if ViewMode = vmAsm then
              begin
              CE;
              if Cur.X > 10 then
                Dec(Cur.X)
              else
                begin
                MessageKey(Self, kbUp);
                if  (BufPos+FilePos <> 0) then
                  Cur.X := Lines[Cur.Y].len*2+9;
                end;
              DrawView;
              end
            else
              {GRM!}
              
              begin
              if Cur.X > 0 then
                Dec(Cur.X)
              else
                begin
                Cur.X := HexPos*(Byte(HexEdit)+1)-1;
                Dec(Cur.Y)
                end;
              {     if ViewMode = vmHex then
                                 Message(Owner, evCommand, cmSetMargins, nil);}
              DrawView;
              CE
              end;
          kbRight:
            if ViewMode = vmText then
              begin
              CE;
              if XDelta < MaxWrapW*8-Size.X then
                Inc(XDelta);
              DrawView
              end
            else
              
              {GRM!}
             if ViewMode = vmAsm then
              begin
              if Cur.X >= Lines[Cur.Y].len*2+9 then
                MessageKey(Self, kbDown)
              else
                Inc(Cur.X);
              DrawView;
              CE
              end
            else
              {GRM!}
              
              begin
              if Cur.X < HexPos*(Byte(HexEdit)+1)-1 then
                Inc(Cur.X)
              else
                begin
                Cur.X := 0;
                Inc(Cur.Y)
                end;
              {       if ViewMode = vmHex then SearchX := HexPos;}
              DrawView;
              CE
              end;
          {JO}kbEnter:
            case UseEnterInViewer of
1:
                if not QuickView then
                  begin
                  CE;
                  Message(Application, evCommand, cmClose, nil)
                  end;
2:
                Message(Owner, evCommand, cmHexMode, nil);
            end
          else {case}
KBCheck:
              if Event.What <> evNothing then
                begin
                if  (Char(Event.CharCode) = #11) and not CtrlK then
                  begin
                  CtrlK := True;
                  CE;
                  end
                else if CtrlK then
                  begin
                  Ch := Char(Event.CharCode);
                  if  (Ch >= '1') and (Ch <= '9') then
                    begin
                    Event.What := evCommand;
                    Event.Command := cmPlaceMarker1+Ord(Ch)-Ord('1');
                    PutEvent(Event);
                    end;
                  CtrlK := False;
                  CE;
                  end
                else
                  begin
                  case DNKeyCode(Event) of
                 //JO: since Ctrl-digit hotkeys under OS/2 do not work without
                 //    a special patch that not everyone may have
                 //    - extra Ctrl-Alt-Shift-digit hotkeys were added
                 //    for jumping to bookmarks
                    
                    kbAlt1:
                      Event.Command := cmPlaceMarker1;
                    kbAlt2:
                      Event.Command := cmPlaceMarker2;
                    kbAlt3:
                      Event.Command := cmPlaceMarker3;
                    kbAlt4:
                      Event.Command := cmPlaceMarker4;
                    kbAlt5:
                      Event.Command := cmPlaceMarker5;
                    kbAlt6:
                      Event.Command := cmPlaceMarker6;
                    kbAlt7:
                      Event.Command := cmPlaceMarker7;
                    kbAlt8:
                      Event.Command := cmPlaceMarker8;
                    kbAlt9:
                      Event.Command := cmPlaceMarker9;
                    kbCtrl1:
                      Event.Command := cmGoToMarker1;
                    kbCtrl2:
                      Event.Command := cmGoToMarker2;
                    kbCtrl3:
                      Event.Command := cmGoToMarker3;
                    kbCtrl4:
                      Event.Command := cmGoToMarker4;
                    kbCtrl5:
                      Event.Command := cmGoToMarker5;
                    kbCtrl6:
                      Event.Command := cmGoToMarker6;
                    kbCtrl7:
                      Event.Command := cmGoToMarker7;
                    kbCtrl8:
                      Event.Command := cmGoToMarker8;
                    kbCtrl9:
                      Event.Command := cmGoToMarker9;
                    else {case}
                      goto NotKb;
                  end {case};
                  Event.What := evCommand;
                  PutEvent(Event);
                  CE;
                  Exit;
                  end;
NotKb:
                if  (Char(Event.CharCode) = #17) and not CtrlQ then
                  begin
                  CtrlQ := True;
                  CE;
                  end
                else if CtrlQ then
                  begin
                  Ch := Char(Event.CharCode);
                  if  (Ch >= '1') and (Ch <= '9') then
                    begin
                    Event.What := evCommand;
                    Event.Command := cmGoToMarker1+Ord(Ch)-Ord('1');
                    PutEvent(Event);
                    end;
                  CtrlQ := False;
                  CE;
                  end
                else if (Char(Event.CharCode) >= #32) and not NoEdit then
                  begin
                  {GRM!}
                  if  ( (ViewMode = vmHex) and (Buf <> nil) and
                        (Cur.X div (Byte(HexEdit)+1)+Cur.Y*HexPos+BufPos
                         < BufSize))
                    
                    or (ViewMode = vmAsm)
                    
                    then
                    begin
                    {GRM!}
                    if Filtr then
                      begin
                      case MessageBox(GetString(dlViewFilter), nil,
                        mfConfirmation+mfYesButton+mfNoButton) of
                        cmYes:
                          begin
                          Filtr := False;
                          VFileName := '';
                          DisposeStr(TWindow(Owner).Title);
                          TWindow(Owner).Title := NewStr
                                (GetString(dlViewFile));
                          TWindow(Owner).Redraw;
                          end;
                        else {case}
                          begin
                          CE;
                          Exit
                          end;
                      end {case};
                      end;
                    if HexEdit then
                      begin
                      Event.CharCode := Byte(UpCase(Char(Event.CharCode)));
                      if Char(Event.CharCode) in ['A'..'F', '0'..'9'] then
                        begin
                        BufModified := True;
                        I := PosChar(Char(Event.CharCode), HexStr)-1;
                        
                        if  (ViewMode <> vmAsm) then
                          {JO}
                          
                          P.X := Cur.X div 2+Cur.Y*HexPos+BufPos
                            {JO} 
                        else
                          begin
                          MakeLines;
                          P.X := 0;
                          for Lin := 0 to (Cur.Y-1) do
                            P.X := P.X+Lines[Lin].len;
                          P.X := P.X+((Cur.X-10) div 2)+BufPos;
                          if P.X < 0 then
                            P.X := 0;
                          end
                          {/JO} 
                          ;
                        if odd(Cur.X) then
                          Buf^[P.X] := (Buf^[P.X] and $F0) or I
                        else
                          Buf^[P.X] := (Buf^[P.X] and $F) or (I shl 4);
                        if ViewMode = vmAsm then
                          MakeLines; {JO}
                        MessageKey(Self, kbRight);
                        CE
                        end;
                      end
                    else
                      begin
                      BufModified := True;
                      Event.CharCode := Byte(XCoder.XLatCP[FromAscii][Char(Event.CharCode)]);
                      Char(Buf^[Cur.X+Cur.Y*HexPos+BufPos])
                         := Char(Event.CharCode);
                      MessageKey(Self, kbRight);
                      CE
                      end;
                    end;
                  end;
                end;
        end {case};
      evMouseDown:
        begin
        LR := RepeatDelay;
        LLR := AutoRepeat;
        repeat
          MakeLocal(Event.Where, P);
          I := Abs((Size.Y shr 1)-P.Y);
          if I = 0 then
            RepeatDelay := 0
          else if MouseInView(Event.Where) then
            begin
            RepeatDelay := 6-Round((I/(Size.Y shr 1))*6);
            AutoRepeat := RepeatDelay;
            if P.X < Size.X div 4 then
              MessageKey(Self, kbLeft)
            else if P.X >= (Size.X*3) div 4 then
              MessageKey(Self, kbRight)
            else if P.Y < Size.Y div 2 then
              MessageKey(Self, kbUp)
            else
              MessageKey(Self, kbDown)
            end
          else
            RepeatDelay := 0;
        until not MouseEvent(Event, evMouseMove+evMouseAuto);
        RepeatDelay := LR;
        AutoRepeat := LLR;
        CE
        end;
    end {case};
  except
    on E:
    eFileError
    do
      begin
      Ch := ' ';
      end;
  end;
  end { TFileViewer.HandleEvent };

procedure TFileViewer.DoHighlite
    (var B: TScreenCell; const S: String; const Attr: String);
  var
    i: Integer;
    j: Integer;
    k: Integer;
    l: Integer;
    c: Char;
  begin
  i := 1;
  j := 0;
  l := Length(S);
  while (i <= l) do
    begin
    c := S[i];
    k := i+1;
    while (k <= l) and (S[k] = c) do
      Inc(k);
    if  (c <> #0) and (Ord(c) <= Length(Attr)) then
      MoveColor(PCellArray(@B)^[j], k-i, Ord(Attr[Ord(c)]));
    Inc(j, k-i);
    i := k;
    end;
  end { TFileViewer.DoHighlite };

{AK155 05.2001 CountDown was almost completely rewritten;
the vmAsm-related parts were gathered together but not tested}

procedure TFileViewer.CountDown;
  
  var
    D: XCHGData; {GRM!}
    
  var
    NewPos: TFileSize;
  begin
  if Buf = nil then
    Exit;
  case ViewMode of

    vmHex, vmDump:
      begin
      if not ScrollEOF and
          (FilePos+BufPos+HexPos*(Size.Y) >= FileSize)
      then
        Exit;
      if FilePos+BufPos+HexPos*ANumber >= FileSize then
        Exit;
      while (BufPos+HexPos < BufSize) and (ANumber > 0) do
        begin
        Inc(BufPos, HexPos);
        Dec(ANumber)
        end;
      if BufPos+HexPos*Size.Y > BufSize then
        Seek(FilePos+LongInt(BufPos));
      Inc(BufPos, ANumber*HexPos);
      end {vmHex, vmDump};

     {GRM!}

    vmAsm:
      begin
      if  (Lines[ANumber].Pos < 0) or (Lines[Size.Y].Pos < 0) then
        Exit;
      D.MemBuff := Buf;
      while (ANumber > 0) do
        begin
        D.InstrMaxLen := MinBufSize(FileSize-FilePos-BufPos-1, 15);
        D.Offset := BufPos;
        ScanCode(D);
        if BufPos+D.InstrLen+15*Size.Y > BufSize then
          Seek(FilePos+LongInt(BufPos));
        if FilePos+BufPos+D.InstrLen >= FileSize then
          Break;
        Inc(BufPos, D.InstrLen);
        Dec(ANumber);
        end;
      MakeLines;
      while (Cur.Y <> 0) and (Lines[Cur.Y].Pos < 0) do
        Dec(Cur.Y);
      Cur.X := 10;
      end {vmAsm};
     {GRM!}

    else {vmText}
      begin
      if not ScrollEOF and (ExposedPos+FilePos = FileSize) then
        Exit;
      if  ( (MaxLines < Size.Y+ANumber-1) or (Lines[Size.Y+ANumber-1].Pos
             = -1))
        and (FilePos+BufSize < FileSize)
      then
        Seek(FilePos+Lines[0].Pos);
      if Lines[ANumber].Pos < 0 then
        Exit;
      BufPos := Lines[ANumber].Pos;
      if ANumber <> 0 then
        begin
        if  (ANumber+Size.Y < MaxLines) then
          begin
          Move(Lines[ANumber], Lines[0],
               SizeOf(Lines[0])*(MaxLines-ANumber));
          Dec(MaxLines, ANumber);
          end
        else
          MakeLines;
        end;
      end {vmText};
  end {case};

  DrawView;
  NewPos := FilePos+BufPos;
  Message(SB, evCommand, cmChangeValue, @NewPos);
  end { TFileViewer.CountDown };

procedure TFileViewer.CountUp;
  var
    I, LineStart, LineEnd: LongInt;
    NextLineStart: LongInt;
    NewFilePos: TFileSize;
    ReadLen: LongInt;
    
    D: XCHGData; {GRM!}
    
    N: LongInt;
    MaxX: LongInt;

  label 1;

  {AK155}
  procedure ScrollUp;
    { Search the buffer for the start of the previous display line
  (TextView mode, accounting for Wrap and Size.X).
 Input: NextLineStart - current line start in the buffer
   (_after_ a CR LF-style marker, if any);
 Output: LineStart - start of the previous line;
         LineEnd - its end (on the marker, if any;
                   usually LineEnd=NextLineStart-1).
 If searching for the start hits the buffer start, we do not try to
 read more of the file; we simply return LineStart=0. }

    var
      I, M, W: LongInt;
      TS: Integer;
      c1, c2: Byte;
    begin
    TS := GetTabSize;
    LineEnd := NextLineStart;
    LineStart := LineEnd;
    if LineEnd <= 0 then
      Exit;
    { Skip the end marker }
    if  (LineEnd > 0) then
      begin
      c1 := Buf^[LineEnd-1];
      if c1 in [$0D, $0A] then
        begin
        Dec(LineEnd);
        if LineEnd > 0 then
          begin
          c2 := Buf^[LineEnd-1];
          if  (c2 in [$0D, $0A]) and (c1 <> c2) then
            Dec(LineEnd);
          end;
        end;
      end;

    { Search for the line start in the buffer. Limiting to screen width
  right now is not possible, because correct tab accounting is only
  possible when scanning from the very start of the line.}
    LineStart := LineEnd;
    while (LineStart > 0) and not (Buf^[LineStart-1] in [$0D, $0A]) do
      begin
      if  (LineEnd-LineStart >= MaxWrapW) then
        begin
        if Wrap = wmNone then
          Exit;
        { This happens when viewing a file with no CR or LF. In that
         case line boundaries are purely conventional, so there is no
         point scanning an unknown distance backward and then
         scanning forward again, cutting into max-length chunks.
         So now we simply search backward from the current point
         for the start of the screen line.}
        LineStart := LineEnd;
        W := MaxX;
        while W > 0 do
          begin
          Dec(LineStart);
          Dec(W);
          if Buf^[LineStart-1] = 9 then
            Dec(W, W mod TS);
          end;
        if Wrap = wmWords then
          begin
          if  (Char(Buf^[LineStart])) in BreakChars then
            Exit;
          if  (Char(Buf^[LineStart-1])) in BreakChars then
            Exit;
          { the screen-line boundary lies inside a word }
          I := LineStart;
          Inc(LineStart, 2);
          while LineStart < LineEnd do
            begin
            if  (Char(Buf^[LineStart])) in BreakChars then
              Exit;
            Inc(LineStart);
            end;
          LineStart := I; { a really long word }
          end;
        Exit;
        end;
      Dec(LineStart);
      end;

    { Now LineStart is the real line start in the buffer. But with wrap
   it may split into several screen lines. Below that is checked
   and LineStart returns the start of the last of them. }

    M := LineStart; { M - candidate for the end of the line }
    W := 0;
    while M < LineEnd-1 do
      begin
      repeat
        Inc(W)
      until (Buf^[M] <> 9) or (W mod TS = 0);
      if W <= MaxX then
        Inc(M)
      else
        begin { a line split is needed }
        if Wrap = wmWords then
          begin { go back to the word boundary }
          I := M;
          while I > LineStart do
            begin
            if Char(Buf^[I-1]) in BreakChars then
              begin { word boundary found }
              M := I;
              Break;
              end;
            Dec(I);
            end;
          end;
        LineStart := M;
        W := 0; { split done }
        end;
      end;
    end { ScrollUp };
  {/AK155}

  begin { TFileViewer.CountUp }
  if Buf = nil then
    Exit;
  (* {AK155 11-01-2003 these crazy checks probably once
        compensated for the effects of some bugs.
        But after BufSize became larger than $8000 they
        became harmful as-is, and there is no desire to update them,
        since the bugs themselves are probably long gone}
  if BufPos > 65000 then
    begin BufPos := 0; MakeLines; end; {AK155: IMHO that never happens}
*)
  NextLineStart := BufPos;
  
  D.MemBuff := Buf; {GRM!}
  D.Offset := BufPos; {GRM!}
  
  if Wrap > wmNone then
    MaxX := Size.X
  else
    MaxX := MaxWrapW;
  for N := 1 to ANumber do
    begin
    if  (NextLineStart <= 0) and (FilePos <= 0) then
      Break; { already at the start, nowhere to move }
1:
    {GRM!}
    case ViewMode of
      vmText:
        ScrollUp;
      vmHex, vmDump:
        begin
        LineStart := Max(0, NextLineStart-HexPos);
        LineEnd := NextLineStart;
        end;
      
      vmAsm:
        begin
        ScanUp(D);
        LineStart := BufPos-D.InstrLen;
        end;
      
    end {case};
    {GRM!}
    if  (ViewMode = vmText) and (LineEnd = Lines[0].Pos) and
        (LineEnd <> 0) {AK155 this happens at the very start of the buffer}
      and (Lines[0].len+Lines[0].Pos-LineStart <= MaxX)
      {AK155 > MaxWrapW happens when viewing a file with no CR or LF }
      then
      begin
      {AK155 When switching from Hex/Dump to Text the start of the first
  screen line may not be a buffer line start. Jumping to the real
  line start at mode-switch time was bad, so mode switching would
  not disturb the position; now we do need to move to the real
  line start. In practice that can only happen when I=1 }
      Inc(Lines[0].len, Lines[0].Pos-LineStart);
      Lines[0].Pos := LineStart;
      BufPos := LineStart;
      end
    else {if ViewMode = vmText then }
      {/AK155}
      begin
      if (LineStart > 0) and (LineStart < BufSize) then
        BufPos := LineStart { normal line start }
      else if FilePos = 0 then
        begin { start of file }
        if BufPos = 0 then
          Exit; { we were already at the start }
        BufPos := 0; { normal line start }
        end
      else
        begin
        { buffer start is not at file start: move through the file
              by half a buffer and retry finding the line start }
        NewFilePos := FilePos-(BufSize div 2);
        if NewFilePos < 0 then
          NewFilePos := 0;
        ReadLen := i32(FilePos-NewFilePos);
        Move(Buf^[0], Buf^[ReadLen], BufSize-ReadLen);
        Fl.Seek(NewFilePos);
        Fl.Read(Buf^, ReadLen);
        BreakOnStreamReadError;
        FilePos := NewFilePos;
        BufPos := ReadLen;
        for I := 0 to MaxLines do
          begin
          if Lines[I].Pos < 0 then
            Break;
          Inc(Lines[I].Pos, ReadLen);
          if Lines[I].Pos+Lines[I].len > BufSize then
            begin
            MaxLines := I-1;
            if I = 0 then
              Break;
            Break;
            end;
          end;
        Inc(NextLineStart, ReadLen);
        goto 1;
        end;

      System.Move(Lines[0], Lines[1], (MaxLines-1)*SizeOf(Lines[0]));
      if MaxLines < MaxILines then
        Inc(MaxLines);
      Lines[0].Pos := LineStart;
      Lines[0].len := LineEnd-LineStart;
      end;

    NextLineStart := LineStart;
    end;
  
  if ViewMode = vmAsm then
    Cur.X := 10; {GRM!}
  
  DrawView;
  NewFilePos := FilePos+BufPos;
  Message(SB, evCommand, cmChangeValue, @NewFilePos);
  end { TFileViewer.CountUp };

function TFileViewer.Valid;
  begin
  Valid := isValid or QuickView;
  if  (Command = cmClose) or (Command = cmQuit) then
    if  (Owner <> nil) and (not QuickView) then
      StoreViewInfo(Owner);
  end;

{ TFileWindow }
constructor TFileWindow.Create(const FileName, VFileName: String; Hex: Boolean);
  var
    R: TRect;
    P: TView;
    PV: TFileViewer;
  begin
  if LastViewerBounds.Empty or (InterfaceData.Options and
       ouiStoreViewerPosition = 0)
  then
    begin
    Desktop.GetExtent(LastViewerBounds);
    LastViewerDeskSize := Desktop.Size;
    end;
  R := LastViewerBounds;
  AdjustToDesktopSize(R, LastViewerDeskSize);
  inherited Create(R, (VFileName),
     0);
  Flags := Flags or wfMaxi;
  Options := Options or ofTileable;
  GetExtent(R);
  R.Grow(-1, -1);
  R.A.X := R.B.X;
  Inc(R.B.X);
  P := TViewScroll.Create(R);
  P.GrowMode := gfGrowHiX+gfGrowLoX+gfGrowHiY;
  Insert(P);
  GetExtent(R);
  R.Grow(-1, -1);
  PV := TFileViewer.Create(R, nil, FileName, VFileName, P, False, Hex);
  Insert(PV); {Must insert even on error for later checking }
  if not PV.isValid then
    {AK155}
    Exit;
  GetExtent(R);
  Inc(R.A.X);
  R.A.Y := R.B.Y-1;
  Dec(R.B.X, 2);
  P := TViewInfo.Create(R, PV);
  Insert(P);
  PV.Info := P;
  end { TFileWindow.Init };

procedure TFileWindow.ChangeBounds(const Bounds: TRect);
  begin
  inherited ChangeBounds(Bounds);
  if not GetState(sfModal) then
    begin
    GetBounds(LastViewerBounds);
    LastViewerDeskSize := Desktop.Size;
    end;
  end;

function TFileWindow.ReactOnCmd: Boolean;
  begin
  ReactOnCmd := True
  end;

end.
