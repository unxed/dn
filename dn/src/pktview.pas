{/////////////////////////////////////////////////////////////////////////
//
//  Dos Navigator Open Source 1.6.RC1
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

{(c) NDN Team}
unit PktView;
{$F+,O+,V-}
interface

uses
  Defines, objutil, Streams, Strings, FViewer, Dialogs, Views, Drivers,
  Messages, Dos, Collect, strutil, basics, Lfn,
  Scroller
  ;

type
  TNetAddr = record
    Net, Node: Word;
    end;

  PCharArray = ^TCharArray;
  TCharArray = array[0..65500] of Char;

  TPktObj = class(TObject)
    FOfs: LongInt;
    Fu, Tu, Su, DT: PString;
    FA, TA: TNetAddr;
    constructor Create(O: LongInt; Afu, Atu, Asu, Adt: String;
        FAddr, TAddr: TNetAddr);
    procedure GetMsgInfo(var FromUser, ToUser, Subj, Date: String);
    {!}
    procedure GetMsgTxt(var Buffer: PCharArray; var MsgLen: SmallWord);
    destructor Destroy; override;
    end;

  TPktCol = class(TCollection)
    FName: PString;
    constructor Create(PktFile: String);
    destructor Destroy; override;
    end;

  TPktList = class(TListBox)
    function GetText(Item: LongInt; MaxLen: LongInt): String; virtual;
    end;

  TPktListDialog = class(TDialog)
    lb: TPktList;
    constructor Create(FName: String; C: TPktCol);
    destructor Destroy; override;
    procedure HandleEvent(var Event: TEvent); override;
    function GetPalette: TPalette; override;
    end;

  TLineViewer = class(TScroller)
    FileLines: TLineCollection;
    isValid: Boolean;
    constructor Create(var Bounds: TRect;
         AHScrollBar, AVScrollBar: TScrollBar; Buffer: PCharArray);
    destructor Destroy; override;
    procedure Draw; virtual;
    procedure InitCol(Buffer: PCharArray);
    procedure SetState(AState: LongInt; Enable: Boolean); virtual;
    function Valid(Command: LongInt): Boolean; virtual;
    end;

  TMsgViewer = class(TLineViewer)
    FromUser, ToUser, Date, Subj: PString;
    constructor Create(var Bounds: TRect;
         AHScrollBar, AVScrollBar: TScrollBar; FName: String);
    destructor Destroy; override;
    end;

  TPktMsgViewer = class(TDialog)
    FV: TLineViewer;
    PS1, Ps2, Ps3, Ps4: PString;
    constructor Create(Buf: PCharArray; S1, S2, S3, S4: String;
         MsgN: Word; AllMsg: Word;
        FA, TA: TNetAddr);
    destructor Destroy; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SaveAsText;
    end;

  TMsgViewerDlg = class(TDialog)
    Lb1, Lb2, Lb3, Lb4: TLabel;
    CurMsg: PString;
    FV: TMsgViewer;
    constructor Create(FName: String);
    destructor Destroy; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure GotoMsg;
    procedure SaveAsText;
    end;

function IsPktFile(Fname: String): Boolean;
function IsMsgFile(FName: String): Boolean;

procedure ViewPktFile(FName: String);
procedure ViewMsgFile(FName: String);
function ViewPktFileE(FName: String; MsgVisible: Boolean): Boolean;
function ViewMsgFileE(FName: String): Boolean;

const
  COrigin {: word} = 11;
  CArea {: word} = 10;
  CCitate {: word} = 14;
  CCluges {: word} = 4 {7};
  KillAfterUse: Boolean = False;
  FileName: String = '';

implementation

uses
  DNHelp, fileutil, keymap, timeutil, Commands, mainapp

  , osdep;

var
  PktFileName: String;
  PktFromAddr: String;

type
  PacketHeader = record
    origNode: Word;
    DestNode: Word;
    Year: Word;
    Month: Word;
    Day: Word;
    Hour: Word;
    Minute: Word;
    Second: Word;
    baud: Word;
    PacketType: Word; {generally 0200H}
    origNet: Word;
    DestNet: Word;
    ProductCode: Char;
    fill: array[0..32] of Char;
    end;

  PacketMessageHeader = record
    PacketType: Word; {0200H}
    origNode: Word;
    DestNode: Word;
    origNet: Word;
    DestNet: Word;
    Attribute: Word;
    cost: Word;
    DateTime: array[0..19] of Char;
    {-----------
          toUserName   : array [0..35] of char;
          fromUserName : array [0..35] of char;
          subject      : array [0..71] of char;
-----------}
    end;
type
  MessageHeader = record
    case Byte of
      0: (head: array[1..190] of Char);
      1: (fromUserName: array[0..35] of Char;
        toUserName: array[0..35] of Char;
        Subject: array[0..71] of Char;
        DateTime: array[1..20] of Char;
        TimedRead: Word;
        DestNode: Word;
        origNode: Word;
        cost: Word;
        origNet: Word;
        DestNet: Word;
        DateWritten: LongInt;
        DateArriven: LongInt;
        {fill         : array [1..8] of char;}
        ReplyTo: Word;
        Attribute: Word;
        nextReply: Word);
    end;

function Spaces(num: SmallInt): String;
  var
    sp1: SmallInt;
    space: String;
  begin
  space := '';
  for sp1 := 1 to num do
    space := space+' ';
  Spaces := space;
  end;

function rpad(ch: String; Num: SmallInt): String;
  begin
  rpad := Copy(ch+Spaces(Num), 1, Num);
  end;

function DLS(S: String): String;
  begin
  MakeNoSlash(S);
  DLS := S;
  end;

function lpad(ch: String; Num: SmallInt): String;
  var
    sp1: SmallInt;
    sp2: SmallInt;
  begin
  sp1 := Length(ch);
  sp2 := Num-sp1;
  lpad := Spaces(sp2)+ch;
  end;

function just(S: String; len, LRC: LongInt): String;
  begin
  if len > 255 then
    len := 255;
  if Length(S) > len then
    SetLength(S, Lo(len));
  case LRC of
    1:
      just := lpad(S, len); {'       '+s}
    2:
      just := rpad(S, len); {s+'       '}
    3:
      begin {'  '+s+'  '}
      while Length(S) < len do
        S := ' '+S+' ';
      if Length(S) > len then
        SetLength(S, Length(S)-1);
      just := S;
      end
    else {case}
      just := S; {11-01-99,BDS}
  end {case};
  end { just };

function fns_z(n: SmallInt): String;
  var
    c: String;
  begin
  c := ItoS(n);
  if Length(c) = 1
  then
    c := '0'+c;
  fns_z := c;
  end;

procedure Msg2Strs(FName: String; var FromUser, ToUser, Subj, Date: String;
    var C: TLineCollection);
  var
    message: TBufStream; {file of char;}
    header: MessageHeader;
    i, j: SmallInt;
    buf: Char;
    txtbuf: String;
  begin
  message.Init(FName, stOpenRead, 4096);
  if message.Status <> stOK then
    Exit;
  for i := 1 to 190 do
    message.Read(header.head[i], 1);
  FromUser := '';
  for i := 0 to 35 do
    begin
    if header.fromUserName[i] <> #0 then
      FromUser := FromUser+header.fromUserName[i]
    else
      Break;
    end;
  FromUser := FromUser+',( 2:'+ItoS(header.origNet)
      +'/'+ItoS(header.origNode)+' )';
  ToUser := '';
  for i := 0 to 35 do
    begin
    if header.toUserName[i] <> #0 then
      ToUser := ToUser+header.toUserName[i]
    else
      Break;
    end;
  ToUser := ToUser+',( 2:'+ItoS(header.DestNet)+'/'+ItoS(header.DestNode)
    +' )';
  Subj := '';
  for i := 0 to 71 do
    begin
    if header.Subject[i] <> #0 then
      Subj := Subj+header.Subject[i]
    else
      Break;
    end;
  Date := '';
  for i := 1 to 20 do
    begin
    if header.DateTime[i] <> #0 then
      Date := Date+header.DateTime[i]
    else
      Break;
    end;
  i := 1;
  txtbuf := '';
  while message.Status = stOK do
    begin
    message.Read(buf, 1);
    if  (buf = #13) or (Length(txtbuf) >= 76) then
      begin
      if buf <> #13 then
        txtbuf := txtbuf+buf;
      C.Insert(NewStr(txtbuf));
      txtbuf := '';
      end
    else
      txtbuf := txtbuf+buf;
    end;
  message.Done;
  end { Msg2Strs };

function ReadPktHeader(FName: String; var PType: Word;
     var DT, FromUser, ToUser: String): Boolean;
  label l1;
  var
    PH: PacketHeader;
    {F:File;}
    F: TDOSStream;
    {Rb:Word;}
    Res: Boolean;
  begin
  F.Init(FName, stOpenRead);
  if F.Status <> stOK then
    goto l1;
  F.Read(PH, SizeOf(PacketHeader));
  if F.Status > stOK then
    begin
l1:
    PType := 0;
    DT := 'Unknown date and time';
    FromUser := 'Unknown';
    ToUser := FromUser;
    Res := False;
    end
  else
    begin
    with PH do
      begin
      PType := PacketType;
      DT := 'Date: '+fns_z(Day)+'-'+fns_z(Month)+'-'+ItoS(Year)+
        '  Time: '+fns_z(Hour)+':'+fns_z(Minute)+':'+fns_z(Second);
      FromUser := 'From: 2:'+ItoS(origNet)+'/'+ItoS(origNode);
      ToUser := 'To  : 2:'+ItoS(DestNet)+'/'+ItoS(DestNode);
      end;
    Res := True;
    end;
  F.Done;
  ReadPktHeader := Res;
  end { ReadPktHeader };

constructor TPktObj.Create(O: LongInt; Afu, Atu, Asu, Adt: String;
     FAddr, TAddr: TNetAddr);
  begin
  inherited Create;
  FOfs := O;
  Fu := NewStr(Afu);
  Su := NewStr(Asu);
  Tu := NewStr(Atu);
  DT := NewStr(Adt);
  FA := FAddr;
  TA := TAddr;
  end;

constructor TPktCol.Create(PktFile: String);
  label l1;
  var
    PH: PacketHeader;
    PMH: PacketMessageHeader;
    F: TBufStream;
    Rb: Word;
    i: Word;
    ch: Char;
    LPos, LSize: LongInt;
    St: String;
    EmptyPkt: Boolean;
    Date, FromUser, ToUser, Subj: String;
    AFrm, ATo: TNetAddr;
  begin
  inherited Create(0, 1);
  FName := NewStr(PktFile);
  F.Init(PktFile, stOpenRead, 4096);
  if F.Status <> stOK then
    goto l1;
  F.Read(PH, SizeOf(PacketHeader));
  EmptyPkt := (F.GetPos = F.GetSize);
  if EmptyPkt then
    begin
    F.Done;
l1:
    Exit;
    end;
  LSize := F.GetSize;
  repeat
    LPos := F.GetPos;
    F.Read(PMH, SizeOf(PacketMessageHeader));
    if F.Status <> stOK then
      Break;
    Date := StrPas(PMH.DateTime);
    with PMH do
      begin
      AFrm.Net := origNet;
      AFrm.Node := origNode;
      ATo.Net := DestNet;
      ATo.Node := DestNode;
      end;
    St := '';
    repeat
      F.Read(ch, 1);
      if ch <> #0 then
        St := St+ch;
    until ch = #0;
    ToUser := St;
    St := '';
    repeat
      {fromuser}
      F.Read(ch, 1);
      if ch <> #0 then
        St := St+ch;
    until ch = #0;
    FromUser := St;
    St := '';
    repeat
      F.Read(ch, 1);
      if ch <> #0 then
        St := St+ch;
    until ch = #0;
    if St = '' then
      St := ' ';
    Subj := St;
    Insert(New(TPktObj, Init(LPos, FromUser, ToUser, Subj, Date, AFrm,
           ATo)));
    repeat
      F.Read(ch, 1);
    until ch = #0;
  until LPos = LSize;
  F.Done;
  end { TPktCol.Init };

procedure TPktObj.GetMsgInfo(var FromUser, ToUser, Subj, Date: String);
  begin
  FromUser := Fu^;
  ToUser := Tu^;
  Subj := Su^;
  Date := DT^;
  end;

destructor TPktObj.Destroy;
  begin
  DisposeStr(Tu);
  DisposeStr(Fu);
  DisposeStr(Su);
  DisposeStr(DT);
  if KillAfterUse then
    begin
    EraseTempFile(FileName);
    KillAfterUse := False;
    TempFile := '';
    end;
  inherited Destroy;
  end;

procedure TPktObj.GetMsgTxt(var Buffer: PCharArray; var MsgLen: Word);
  var
    F: TBufStream;
    LPos: LongInt;
    PktMsg: TPktObj;
    st: String;
    I: Word;
    PH: PacketHeader;
    PMH: PacketMessageHeader;
    Rb: Word;
    ch: Char;
  begin
  MsgLen := 0;
  I := 0;
  F.Init(PktFileName, stOpenRead, 4096);
  LPos := FOfs;
  F.Seek(LPos);
  F.Read(PMH, SizeOf(PacketMessageHeader));
  if F.Status <> stOK then
    begin
    F.Done;
    Exit;
    end;
  for I := 1 to 3 do
    begin
    repeat
      F.Read(ch, 1);
    until ch = #0;
    end;
  I := 0;
  repeat
    F.Read(ch, 1);
    Buffer^[I] := ch;
    Inc(I);
  until ch = #0;
  MsgLen := I;
  F.Read(ch, 1);
  F.Done;
  end { TPktObj.GetMsgTxt };

destructor TPktCol.Destroy;
  begin
  DisposeStr(FName);
  inherited Destroy;
  end;

var
  PktCol: TPktCol;

procedure InitPktCol(FName: String);
  begin
  PktCol := TPktCol.Create(FName);
  end;

procedure DonePktCOl;
  begin
  PktCol.Free;
  end;

function DelChar(s: String; Ch: Char): String;
  begin
  while Pos(Ch, s) <> 0 do
    Delete(s, Pos(Ch, s), 1);
  DelChar := s;
  end;

procedure CutFromAddr(st: String);
  begin
  while st[1] <> ' ' do
    Delete(st, 1, 1);
  DelRight(st);
  DelLeft(st);
  while st[1] <> ' ' do
    begin
    PktFromAddr := PktFromAddr+st[1];
    Delete(st, 1, 1);
    end;
  end;

procedure Buffer2Strs(Buffer: PCharArray; var C: TLineCollection);
  var
    I: Word;
    st: String;
    Ch: Char;
  begin
  st := '';
  PktFromAddr := '';
  I := 0;
  repeat
    Ch := Buffer^[I];
    if Ch in [#13, #10] then
      begin
      st := DelChar(DelChar(st, #13), #10);
      if  (st[1] = #1) and (Pos('MSGID', st) <> 0) then
        CutFromAddr(st);
      C.Insert(NewStr(st));
      st := '';
      end;
    if Ch <> #0 then
      begin
      if Length(st) > 76 then
        begin
        st := st+Ch;
        if not (Buffer^[I+1] in [' ', #13, #10, #0]) then
          begin
          if Buffer^[I+2] in [' ', #13, #10, #0] then
            st := st+Buffer^[I+1];
          Inc(I);
          end;
        st := DelChar(DelChar(st, #13), #10);
        C.Insert(NewStr(st));
        st := '';
        end
      else
        st := st+Ch;
      end
    else
      begin
      st := DelChar(DelChar(st, #13), #10);
      if  (st[1] = #1) and (Pos('MSGID', st) <> 0) then
        CutFromAddr(st);
      C.Insert(NewStr(st));
      st := '';
      end;
    Inc(I);
  until Ch = #0;
  end { Buffer2Strs };

function TPktList.GetText(Item: LongInt; MaxLen: LongInt): String;
  var
    FromUser, ToUser, Subj, Date: String;
    Pc: TPktObj;
    s1, s2, s3: String;
  begin
  Pc := List.At(Item);
  Pc.GetMsgInfo(FromUser, ToUser, Subj, Date);
  s1 := just(FromUser, 26, 2);
  s2 := just(ToUser, 26, 2);
  s3 := just(Subj, 26, 2);
  GetText := s1+s2+s3;
  end;

destructor TPktListDialog.Destroy;
  begin
  lb.Free;
  inherited Destroy;
  end;

const
  CPktDialog = #112#113#114#115#116#117#117#119#120#121#122#123+
  #124#125#46#47#48#49#50#51#52#53#54#55#1#117#118+
  #1#1#61#62#63#178#179;

function TPktListDialog.GetPalette: TPalette;
  const
    Pal: String = CPktDialog;
  begin
  GetPalette := MakePalette(Pal);
  end;

constructor TPktListDialog.Create(FName: String; C: TPktCol);
  var
    R: TRect;
    View: TView;
  begin
  HelpCtx := hcPktListDialog;
  Desktop.GetExtent(R);
  inherited Create(R, GetString(dlPktView)+FName);
  Options := Options or {ofCentered}ofSelectable;
  GrowMode := gfGrowHiX+gfGrowHiY;
  View := StandardScrollBar(sbVertical+sbHandleKeyboard);
  EventMask := $FFFF;
  Inc(View.Origin.Y);
  Dec(View.Size.Y);
  Insert(View);
  GetExtent(R);
  R.Grow(-1, -1);
  Inc(R.A.Y);
  lb := New(TPktList, Init(R, 1, TScrollBar(View)));
  lb.Options := lb.Options+ofFramed;
  Insert(lb);
  lb.NewLisT(C);
  lb.SetRange(C.Count);
  R.Assign(2, 1, 8, 2);
  View := TLabel.Create(R, '~From~', nil);
  Insert(View);
  R.Assign(31, 1, 35, 2);
  View := TLabel.Create(R, '~To~', nil);
  Insert(View);
  R.Assign(52, 1, 58, 2);
  View := TLabel.Create(R, '~Subj~', nil);
  Insert(View);
  SelectNext(False);
  end { TPktListDialog.Init };

function PktHeaderDlg(AText: String): TDialog;
  var
    R: TRect;
    Dialog: TDialog;
    View: TView;
  begin
  R.Assign(13, 6, 66, 17);
  Dialog := New(TDialog, Init(R, GetString(dlPktHeader)));
  with Dialog do
    begin
    Options := Options+ofCenterX+ofCenterY;
    R.Assign(20, 8, 32, 10);
    View := TButton.Create(R, 'Ok', cmOK, bfDefault);
    View.Options := View.Options+ofCenterX;
    Insert(View);
    R.Assign(2, 1, 51, 8);
    View := TStaticText.Create(R, AText);
    Insert(View);
    SelectNext(False);
    end;
  PktHeaderDlg := Dialog
  end;

procedure ViewPktHeader(MsgCount: SmallInt);
  var
    W: Word;
    s1, s2, s3: String;
    S: String;
    D: TDialog;
  begin
  ReadPktHeader(PktFileName, W, s1, s2, s3);
  S := GetString(dlPktFile)+FExpand(PktFileName)+#13+s1+#13+s2+#13+s3+#13+
    {!!!'Packet Size: '+PrintUsing('###,###',GetFileSize(PktFileName))+' byte(s)'+#13+}
    GetString(dlPktMsg)+ItoS(MsgCount);
  D := PktHeaderDlg(S);
  Desktop.ExecView(D);
  D.Free;
  end;

procedure TPktListDialog.HandleEvent(var Event: TEvent);
  var
    Pc: TPktObj;
    Buf: PCharArray;
    D: TPktMsgViewer;
    M: Word;
    s1, s2, s3, s4: String;
  begin
  if  (Event.What = evKeyDown) then
    case DNKeyCode(Event) of
      kbEnter, kbF3:
        begin
        Pc := lb.List.At(lb.Focused);
        if Pc = nil then
          Exit;
        New(Buf);
        Pc.GetMsgTxt(Buf, M);
        s1 := Pc.Fu^;
        s2 := Pc.Tu^;
        s3 := Pc.Su^;
        s4 := Pc.DT^;
        D := New(TPktMsgViewer, Init(Buf, s1, s2, s3, s4, lb.Focused+1,
               lb.List.Count,
              Pc.FA, Pc.TA));
        Dispose(Buf);
        Desktop.ExecView(D);
        D.Free;
        end;
      kbF2:
        ViewPktHeader(lb.List.Count);
    end {case};
  inherited HandleEvent(Event);
  end { TPktListDialog.HandleEvent };

constructor TLineViewer.Create(var Bounds: TRect; AHScrollBar,
    AVScrollBar: TScrollBar; Buffer: PCharArray);
  begin
  HelpCtx := hcLineViewer;
  Options := Options or {ofCentered}ofSelectable;
  GrowMode := gfGrowHiX+gfGrowHiY;
  EventMask := $FFFF;
  inherited Create(Bounds, AHScrollBar, AVScrollBar);
  TLineViewer.InitCol(Buffer);
  end;

destructor TLineViewer.Destroy;
  begin
  FileLines.Free;
  inherited Destroy;
  end;

procedure TLineViewer.Draw;
  var
    B: TDrawBuffer;
    CNormal: Byte;
    I: SmallInt;
    S: String;
    P: PString;
    Color: Byte;
    Bkg: Byte;
    OrigColor, AreaColor, Citate, WorkStrColor: Word;
  begin
  CNormal := GetColorW(1);
  Bkg := Lo((CNormal and $F0) shr 4);
  OrigColor := Bkg*16+COrigin;
  AreaColor := Bkg*16+CArea;
  Citate := Bkg*16+CCitate;
  WorkStrColor := Bkg*16+CCluges;

  for I := 0 to Size.Y-1 do
    begin
    MoveChar(B[0], ' ', CNormal, Size.X);
    if Delta.Y+I < FileLines^.Count then
      begin
      P := FileLines^.At(Delta.Y+I);
      if P <> nil then
        S := Copy(P^, Delta.X+1, Size.X)
      else
        S := '';
      Color := CNormal;
      if Pos('AREA', S) <> 0 then
        Color := AreaColor;
      if Pos('>', S) <> 0 then
        Color := Citate;
      if Pos('Origin', S) <> 0 then
        Color := OrigColor;
      if  (Pos('SEEN-BY', S) <> 0) then
        Color := WorkStrColor;
      if  (S[1] = #1) then
        begin
        System.Delete(S, 1, 1);
        Color := WorkStrColor;
        end;
      MoveStr(B[0], S, Color);
      end;
    WriteLineC(0, I, Size.X, 1, B);
    end;
  end { TLineViewer.Draw };

procedure TLineViewer.InitCol(Buffer: PCharArray);
  begin
  isValid := True;
  FileLines := TLineCollection.Create(5, 5, False);
  Buffer2Strs(Buffer, FileLines);
  Limit.X := 255;
  Limit.Y := FileLines^.Count;
  end;

procedure TLineViewer.SetState(AState: LongInt; Enable: Boolean);
  begin
  TScroller.SetState(AState, Enable);
  if Enable and (AState and sfExposed <> 0) then
    SetLimit(Limit.X, Limit.Y);
  end;

function TLineViewer.Valid(Command: LongInt): Boolean;
  begin
  Valid := isValid;
  end;

constructor TMsgViewer.Create(var Bounds: TRect; AHScrollBar,
    AVScrollBar: TScrollBar; FName: String);
  var
    s1, s2, s3, s4: String;
  begin
  HelpCtx := hcMsgViewer;
  inherited Create(Bounds, AHScrollBar, AVScrollBar);
  Options := Options or {ofCentered}ofSelectable;
  GrowMode := gfGrowHiX+gfGrowHiY;
  EventMask := $FFFF;
  FileLines := TLineCollection.Create(5, 5, False);
  Msg2Strs(FName, s1, s2, s3, s4, FileLines);
  FromUser := NewStr(s1);
  ToUser := NewStr(s2);
  Subj := NewStr(s3);
  Date := NewStr(s4);
  Limit.X := 255;
  Limit.Y := FileLines^.Count;
  end;

destructor TMsgViewer.Destroy;
  begin
  DisposeStr(FromUser);
  DisposeStr(ToUser);
  DisposeStr(Date);
  DisposeStr(Subj);
  if KillAfterUse then
    begin
    EraseTempFile(FileName);
    KillAfterUse := False;
    TempFile := '';
    end;
  inherited Destroy;
  end;

constructor TPktMsgViewer.Create(Buf: PCharArray; S1, S2, S3, S4: String;
     MsgN: Word; AllMsg: Word;
    FA, TA: TNetAddr);
  var
    R: TRect;
    View: TView;
    VS: TScrollBar;
    S: String;
  begin
  HelpCtx := hcPktMsgViewer;
  Desktop.GetExtent(R);
  inherited Create(R, GetString(dlViewMsg));
  Options := Options or ofCentered;
  VS := StandardScrollBar(sbVertical+sbHandleKeyboard);
  Inc(VS.Origin.Y, 5);
  Dec(VS.Size.Y, 5);
  Insert(VS);
  GetExtent(R);
  R.Grow(-1, -1);
  Inc(R.A.Y, 5);
  EventMask := $FFFF;
  FV := TLineViewer.Create(R, nil, VS, Buf);
  FV.Options := FV.Options or ofFramed;
  Insert(FV);
  R.Assign(1, 1, 79, 2);
  S := '~Msg~  :'+just(ItoS(MsgN), 5, 1)+'/'+just(ItoS(AllMsg), 5, 2)
    +Spaces(30)+'~Date~ :'+S4;
  View := TLabel.Create(R, S, nil);
  Insert(View);
  PS1 := NewStr(DelChar(S, '~'));
  R.Assign(1, 2, 79, 3);
  S := '~From~ :'+just(S1, 50, 2)+PktFromAddr;
  View := TLabel.Create(R, S, nil);
  Insert(View);
  Ps2 := NewStr(DelChar(S, '~'));
  R.Assign(1, 3, 79, 4);
  S := '~To~   :'+just(S2, 50, 2)+'2:'+ItoS(TA.Net)+'/'+ItoS(TA.Node);
  View := TLabel.Create(R, S, nil);
  Insert(View);
  Ps3 := NewStr(DelChar(S, '~'));
  R.Assign(1, 4, 79, 5);
  S := '~Subj~ :'+S3;
  View := TLabel.Create(R, S, nil);
  Insert(View);
  Ps4 := NewStr(DelChar(S, '~'));
  SelectNext(False);
  end { TPktMsgViewer.Init };

function TPktMsgViewer.GetPalette: TPalette;
  const
    Pal: String = CPktDialog;
  begin
  GetPalette := MakePalette(Pal);
  end;

destructor TPktMsgViewer.Destroy;
  begin
  DisposeStr(PS1);
  DisposeStr(Ps2);
  DisposeStr(Ps3);
  DisposeStr(Ps4);
  FV.Free;
  inherited Destroy;
  end;

procedure TPktMsgViewer.SaveAsText;
  var
    TName: String;
    F: Text;
    Area: String;
    {--------------------------------------------}
  procedure WriteFile(Ps_: Pointer);
  var Ps: PString absolute Ps_;
    begin
    if Ps = nil then
      Writeln(F, ' ')
    else
      Writeln(F, DelChar(Ps^, #1));
    end;
  {--------------------------------------------}
  procedure FindArea(Ps_: Pointer);
  var Ps: PString absolute Ps_;
    var
      S: String;
    begin
    if Area <> '' then
      Exit;
    S := Ps^;
    if Pos('AREA', S) <> 0 then
      begin
      while Pos('AREA', S) <> 1 do
        System.Delete(S, 1, 1);
      System.Delete(S, Pos('AREA', S), 4);
      DelLeft(S);
      DelRight(S);
      while (S[1] <> ' ') and (S <> '') do
        begin
        Area := Area+S[1];
        System.Delete(S, 1, 1);
        end;
      end;
    end;
  {--------------------------------------------}
  begin { TPktMsgViewer.SaveAsText }
  TName := '';
  if InputBox(GetString(dlSaveMsg), GetString(dlMsgFile), TName, 255, 0) =
    cmCancel
  then
    Exit;
  Assign(F, SysOsPath(TName));
  DoneSysError;
  if ExistFile(TName) then
    {$I-}Append(F) {$I+}
  else {$I-}
    Rewrite(F); {$I+}
  if IOResult <> 0 then
    begin
    MessageBox(GetString(dlErrorWriting)+TName+'!', nil,
      mfError+mfOKButton);
    Exit;
    end;
  InitSysError;
  Area := '';
  FV.FileLines.ForEach(FindArea);
  Writeln(F, GetString(dlLine));
  Writeln(F, 'AREA: '+Area);
  Writeln(F, PS1^);
  Writeln(F, Ps2^);
  Writeln(F, Ps3^);
  Writeln(F, Ps4^);
  Writeln(F, GetString(dlLine));
  FV.FileLines.ForEach(WriteFile);
  System.Close(F);
  end { TPktMsgViewer.SaveAsText };

procedure TPktMsgViewer.HandleEvent(var Event: TEvent);
  begin
  if  (Event.What = evKeyDown) then
    case DNKeyCode(Event) of
      kbF2:
        SaveAsText;
    end {case};
  inherited HandleEvent(Event);
  end;

constructor TMsgViewerDlg.Create(FName: String);
  var
    R: TRect;
    View: TView;
    VS: TScrollBar;
  begin
  Desktop.GetExtent(R);
  inherited Create(R, GetString(dlNetMailView)+FExpand(FName));
  Options := Options or ofCentered;
  GrowMode := gfGrowHiX+gfGrowHiY;
  EventMask := $FFFF;
  VS := StandardScrollBar(sbVertical+sbHandleKeyboard);
  Inc(VS.Origin.Y, 5);
  Dec(VS.Size.Y, 5);
  Insert(VS);
  GetExtent(R);
  R.Grow(-1, -1);
  Inc(R.A.Y, 5);
  FV := TMsgViewer.Create(R, nil, VS, FName);
  FV.Options := FV.Options or ofFramed;
  Insert(FV);
  R.Assign(1, 1, 79, 2);
  Lb1 := New(TLabel, Init(R,
         '~Msg~  :Private '+Spaces(30)+'~Date~ :'+FV.Date^, nil));
  Insert(Lb1);
  R.Assign(1, 2, 79, 3);
  Lb2 := TLabel.Create(R, '~From~ :'+FV.FromUser^, nil);
  Insert(Lb2);
  R.Assign(1, 3, 79, 4);
  Lb3 := TLabel.Create(R, '~To  ~ :'+FV.ToUser^, nil);
  Insert(Lb3);
  R.Assign(1, 4, 79, 5);
  Lb4 := TLabel.Create(R, '~Subj~ :'+FV.Subj^, nil);
  Insert(Lb4);
  SelectNext(False);
  CurMsg := NewStr(FName);
  end { TMsgViewerDlg.Init };

function TMsgViewerDlg.GetPalette: TPalette;
  const
    Pal: String = CPktDialog;
  begin
  GetPalette := MakePalette(Pal);
  end;

function GetPrevMsg(FName: String): String;
  var
    D, N, E: String;
    Er: LongInt;
    Num: Word;
    Tm: TEventTimer;
    Sr: lSearchRec;
    VM: TView;
  begin
  lFSplit(FName, D, N, E);
  while (N[1] = '0') and (N <> '') do
    System.Delete(N, 1, 1);
  if N = '' then
    N := '0';
  Val(N, Num, Er);
  NewTimer(Tm, 200);
  VM := nil;
  if  (Er <> 0) or (Num = 0) then
    GetPrevMsg := ''
  else
    begin
    while Num > 0 do
      begin
      if  (VM = nil) and TimerExpired(Tm) then
        VM := WriteMsg(GetString(dlPleaseStandBy));
      Dec(Num);
      lFindFirst(MakeNormName(D, ItoS(Num)+'.msg'), AnyFileDir-Directory, Sr);
      if DosError = 0 then
        begin
        GetPrevMsg := MakeNormName(D, Sr.FullName);
        if VM <> nil then
          VM.Free;
        lFindClose(Sr);
        Exit;
        end;
      lFindClose(Sr);
      end;
    if  (Num = 0) then
      GetPrevMsg := '';
    if VM <> nil then
      VM.Free;
    end;
  end { GetPrevMsg };

function GetNextMsg(FName: String): String;
  var
    D, N, E: String;
    Er: LongInt;
    Num, St: Word;
    Tm: TEventTimer;
    Sr: lSearchRec;
    VM: TView;
  begin
  lFSplit(FName, D, N, E);
  while (N[1] = '0') and (N <> '') do
    System.Delete(N, 1, 1);
  if N = '' then
    N := '0';
  Val(N, Num, Er);
  St := Num;
  NewTimer(Tm, 200);
  VM := nil;
  if  (Er <> 0) then
    GetNextMsg := ''
  else
    begin
    while Num < St+1000 do
      begin
      if  (VM = nil) and TimerExpired(Tm) then
        VM := WriteMsg(GetString(dlPleaseStandBy));
      Inc(Num);
      lFindFirst(MakeNormName(D, ItoS(Num)+'.msg'), AnyFileDir-Directory, Sr);
      if DosError = 0 then
        begin
        GetNextMsg := MakeNormName(D, Sr.FullName);
        if VM <> nil then
          VM.Free;
        lFindClose(Sr);
        Exit;
        end
      else
        begin
        GetNextMsg := '';
        lFindClose(Sr);
        Continue;
        end;
      end;
    if VM <> nil then
      VM.Free;
    end;
  end { GetNextMsg };

procedure TMsgViewerDlg.GotoMsg;
  var
    VS: TScrollBar;
    R: TRect;
    View: TView;
  begin
  DisposeStr(Title);
  Title := NewStr(GetString(dlNetMailView)+CurMsg^);
  FV.Free;
  VS := StandardScrollBar(sbVertical+sbHandleKeyboard);
  EventMask := $FFFF;
  Inc(VS.Origin.Y, 5);
  Dec(VS.Size.Y, 5);
  Insert(VS);
  GetExtent(R);
  R.Grow(-1, -1);
  Inc(R.A.Y, 5);
  FV := TMsgViewer.Create(R, nil, VS, CurMsg^);
  FV.Options := FV.Options or ofFramed;
  Insert(FV);
  Lb1.Free;
  Lb1 := nil;
  Lb2.Free;
  Lb2 := nil;
  Lb3.Free;
  Lb3 := nil;
  Lb4.Free;
  Lb4 := nil;
  R.Assign(1, 1, 79, 2);
  if FV <> nil then
    Lb1 := New(TLabel, Init(R,
           '~Msg  ~:Private '+Spaces(30)+'~Date~ :'+FV.Date^, nil));
  Insert(Lb1);
  R.Assign(1, 2, 79, 3);
  Lb2 := TLabel.Create(R, '~From ~:'+FV.FromUser^, nil);
  Insert(Lb2);
  R.Assign(1, 3, 79, 4);
  Lb3 := TLabel.Create(R, '~To   ~:'+FV.ToUser^, nil);
  Insert(Lb3);
  R.Assign(1, 4, 79, 5);
  Lb4 := TLabel.Create(R, '~Subj ~:'+FV.Subj^, nil);
  Insert(Lb4);
  SelectNext(False);
  Redraw;
  end { TMsgViewerDlg.GotoMsg };

procedure TMsgViewerDlg.SaveAsText;
  var
    TName: String;
    F: Text;
  procedure WriteFile(Ps_: Pointer);
  var Ps: PString absolute Ps_;
    begin
    if Ps = nil then
      Writeln(F, ' ')
    else
      Writeln(F, DelChar(Ps^, #1));
    end;
  begin
  TName := '';
  if InputBox(GetString(dlSaveMsg), GetString(dlMsgFile), TName, 255, 0) =
    cmCancel
  then
    Exit;
  Assign(F, SysOsPath(TName));
  DoneSysError;
  if ExistFile(TName) then
    {$I-}Append(F) {$I+}
  else {$I-}
    Rewrite(F); {$I+}
  if IOResult <> 0 then
    begin
    MessageBox(GetString(dlErrorWriting)+TName+'!', nil,
      mfError+mfOKButton);
    Exit;
    end;
  InitSysError;
  Writeln(F,


       #196#196#196#196#196#196#196#196#196'['+CenterStr(GetName(CurMsg^),
       17)
    +']'#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196
    +#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196
    +#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196#196);
  Writeln(F, 'Msg  : Private '+Spaces(30)+'Date : '+FV.Date^);
  Writeln(F, 'From : '+FV.FromUser^);
  Writeln(F, 'To   : '+FV.ToUser^);
  Writeln(F, 'Subj : '+FV.Subj^);
  Writeln(F, GetString(dlLine));
  FV.FileLines.ForEach(WriteFile);
  System.Close(F);
  end { TMsgViewerDlg.SaveAsText };

procedure TMsgViewerDlg.HandleEvent(var Event: TEvent);
  var
    S: String;
    SOld: String;
    Er: Byte;
  begin
  if Event.What = evKeyDown then
    case DNKeyCode(Event) of
      kbGrayPlus, kbRight:
        begin
        S := GetNextMsg(CurMsg^);
        if S <> '' then
          begin
          DisposeStr(CurMsg);
          CurMsg := NewStr(S);
          GotoMsg;
          end
        else
          MessageBox(GetString(dlLastMsg), nil,
            mfError+mfOKButton);
        end;
      kbGrayMinus, kbLeft:
        begin
        S := GetPrevMsg(CurMsg^);
        if S <> '' then
          begin
          DisposeStr(CurMsg);
          CurMsg := NewStr(S);
          GotoMsg;
          end
        else
          MessageBox(GetString(dlFirstMsg), nil,
            mfError+mfOKButton);
        end;
      kbF8, kbDel:
        begin
        if MessageBox(GetString(dlDelMsg)+CurMsg^+'?', nil,
            mfConfirmation+mfOKButton+mfCancelButton) = cmOK
        then
          begin
          SOld := CurMsg^;
          S := GetPrevMsg(CurMsg^);
          if S <> '' then
            begin
            DisposeStr(CurMsg);
            CurMsg := NewStr(S);
            GotoMsg;
            EraseFile(SOld);
            end
          else
            begin
            S := GetNextMsg(CurMsg^);
            if S <> '' then
              begin
              DisposeStr(CurMsg);
              CurMsg := NewStr(S);
              GotoMsg;
              EraseFile(SOld);
              end
            else
              begin
              EraseFile(SOld);
              EndModal(cmCancel);
              end;
            end;
          end;
        end;
      kbF2:
        SaveAsText;
    end {case}; {case}
  inherited HandleEvent(Event);
  end { TMsgViewerDlg.HandleEvent };

destructor TMsgViewerDlg.Destroy;
  begin
  FV.Free;
  Lb1.Free;
  Lb2.Free;
  Lb3.Free;
  Lb4.Free;
  DisposeStr(CurMsg);
  inherited Destroy;
  end;

function TestDiap(Value, Min, Max: Word): Boolean;
  begin
  if  (Value < Min) or (Value > Max) then
    TestDiap := False
  else
    TestDiap := True;
  end;

function IsPktFile(Fname: String): Boolean;
  label l_e;
  var
    S: TDOSStream;
    Head: PacketHeader;
    flag: Boolean;
  begin
  S.Init(Fname, stOpenRead);
  if S.Status <> stOK then
    begin
l_e:
    IsPktFile := False;
    S.Done;
    Exit;
    end;
  S.Read(Head, SizeOf(PacketHeader));
  if S.Status <> stOK then
    goto l_e;
  with Head do
    begin
    flag := TestDiap(Month, 1, 12);
    flag := flag and TestDiap(Day, 1, 31);
    flag := flag and (origNet > 0);
    flag := flag and TestDiap(Minute, 0, 60);
    flag := flag and TestDiap(Second, 0, 60);
    flag := flag and TestDiap(Hour, 0, 60);
    end;
  if not flag then
    goto l_e;
  S.Done;
  IsPktFile := True;
  end { IsPktFile };

procedure ViewPktFile(FName: String);
  var
    C: TPktCol;
    D: TPktListDialog;
    W: TView;
    R: TRect;
  begin
  PktFileName := FName;
  if not IsPktFile(FName) then
    begin
    MessageBox(FName+#13+^C+GetString(dlNotPkt), nil,
      mfError+mfOKButton);
    Exit;
    end;
  W := WriteMsg(^M^M^C+GetString(dlReadingPkt));
  UpdateWriteView(W);
  C := TPktCol.Create(FName);
  W.Free;
  D := TPktListDialog.Create(FName, C);
  Desktop.ExecView(D);
  D.Free;
  if Assigned(C) then
    C.Free;
  end { ViewPktFile };

type
  TLimitStream = class(TDOSStream)
    constructor Create(FileName: FNameStr; Mode: Word; Limit: LongInt);
    end;

constructor TLimitStream.Create(FileName: FNameStr; Mode: Word;
     Limit: LongInt);
  begin
  inherited Create(FileName, Mode);
  if Status = stOK then
    if Limit < StreamSize then
      StreamSize := Limit
  end;

function IsMsgFile(FName: String): Boolean;
  label l_e;
  var
    F: TLimitStream;
    L: array[1..5] of PtrInt;
    i, N: ShortInt;
    XL: TXlat;
  begin
  NullXLAT(XL);
  New(F, Init(FName, stOpenRead, 16384));
  L[1] := -1;
  L[1] := SearchFileStr(F, XL, #1'MSGID: ', 0, False, False, False,
       False, True, False);
  L[2] := -1;
  L[2] := SearchFileStr(F, XL, #1'FMPT ', 0, False, False, False, False,
       True, False);
  L[3] := -1;
  L[3] := SearchFileStr(F, XL, #1'INTL ', 0, False, False, False, False,
       True, False);
  L[4] := -1;
  L[4] := SearchFileStr(F, XL, #1'TOPT ', 0, False, False, False, False,
       True, False);
  L[5] := -1;
  L[5] := SearchFileStr(F, XL, #1'PID: ', 0, False, False, False, False,
       True, False);
  F.Free;
  N := 0;
  for i := 1 to 5 do
    if L[i] > 0 then
      Inc(N);
  if N = 0 then
    IsMsgFile := False
  else
    IsMsgFile := True;
  end { IsMsgFile };

procedure ViewMsgFile(FName: String);
  var
    D: TMsgViewerDlg;
  begin
  if not IsMsgFile(FName) then
    begin
    MessageBox(FName+#13+^C+GetString(dlNotPkt), nil,
      mfError+mfOKButton);
    Exit;
    end;
  D := TMsgViewerDlg.Create(FName);
  Desktop.ExecView(D);
  D.Free;
  end;

function ViewMsgFileE(FName: String): Boolean;
  var
    D: TMsgViewerDlg;
  begin
  if IsMsgFile(FName) then
    begin
    FileName := '';
    KillAfterUse := TempFile <> '';
    TempFile := '';
    FileName := FName;
    ViewMsgFileE := True;
    D := TMsgViewerDlg.Create(FName);
    Desktop.ExecView(D);
    D.Free;
    end
  else
    ViewMsgFileE := True;
  end;

function ViewPktFileE(FName: String; MsgVisible: Boolean): Boolean;
  var
    C: TPktCol;
    D: TPktListDialog;
    W: TView;
    R: TRect;
  begin
  PktFileName := FName;
  if IsPktFile(FName) then
    begin
    FileName := '';
    KillAfterUse := TempFile <> '';
    TempFile := '';
    FileName := FName;
    ViewPktFileE := True;
    W := WriteMsg(^M^M^C+GetString(dlReadingPkt));
    UpdateWriteView(W);
    C := TPktCol.Create(FName);
    W.Free;
    D := TPktListDialog.Create(FName, C);
    Desktop.ExecView(D);
    D.Free;
    if Assigned(C) then
      C.Free;
    end
  else
    ViewPktFileE := False;
  end { ViewPktFileE };
end.
