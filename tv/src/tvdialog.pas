{ TvDialog: dialog windows and their simplest controls: TDialog, TStaticText, TLabel,
  TButton.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/dialogs.h (constants, class declarations)
    source/tvision/tdialog.cpp, tstatict.cpp, tlabel.cpp, tbutton.cpp, tvtext1.cpp
    (button shadows and markers, special characters)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - texts are ShortStrings (PStr for the fields); TStaticText.GetText fills a
      ShortString, so that descendants can give a text that changes;
    - the dialog palettes are built from the three ranges of indexes ($20, $40, $60);
    - streams are not translated yet. }
unit TvDialog;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvText, TvDrawBuf, TvScreen, TvObjs,
  TvUtil, TvTimer, TvViews, TvWindow;

const
  { the characters of the markers shown instead of colors on monochrome screens }
  SpecialChars: array[0..5] of Byte = (175, 174, 26, 27, 32, 32);
  { button flags }
  bfNormal    = $00;
  bfDefault   = $01;
  bfLeftJust  = $02;
  bfBroadcast = $04;
  bfGrabFocus = $08;

  { messages of the buttons and of the history }
  cmRecordHistory  = 60;
  cmGrabDefault    = 61;
  cmReleaseDefault = 62;

  { dialog palettes }
  dpBlueDialog = 0;
  dpCyanDialog = 1;
  dpGrayDialog = 2;

type
  PDialog = ^TDialog;
  PStaticText = ^TStaticText;
  PLabel = ^TLabel;
  PButton = ^TButton;

  { Palette: 32 entries, mapped to the application palette through the dialog palette
    of the application (see TvApp) }
  TDialog = object(TWindow)
    { used by DN: the controls of a dialog by number (the loader of its resources fills them; nil = none) }
    DirectLink: array[1..9] of PView;
    constructor Init(const Bounds: TRect; const ATitle: ShortString);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function Valid(Command: Word): Boolean; virtual;
  end;

  { Palette: 1 = text. In the text, #3 at the start of a line centers it and #10 is a
    line break. }
  TStaticText = object(TView)
    Text: PStr;
    constructor Init(const Bounds: TRect; const AText: ShortString);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure GetText(var S: ShortString); virtual;
  end;

  { Palette: 1 = normal text, 2 = selected text, 3 = normal shortcut, 4 = selected
    shortcut }
  TLabel = object(TStaticText)
    Link: PView;
    Light: Boolean;
    constructor Init(const Bounds: TRect; const AText: ShortString; ALink: PView);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  private
    procedure FocusLink(var Event: TEvent);
  end;

  { Palette: 1 = normal, 2 = default, 3 = selected, 4 = disabled, 5 = normal shortcut,
    6 = default shortcut, 7 = selected shortcut, 8 = shadow }
  TButton = object(TView)
    Title: PStr;
    Command: Word;
    Flags: Byte;
    AmDefault: Boolean;
    AnimationTimer: TTimerId;
    constructor Init(const Bounds: TRect; const ATitle: ShortString; ACommand: Word;
      AFlags: Word);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    destructor Done; virtual;
    procedure Draw; virtual;
    procedure DrawState(Down: Boolean);
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure MakeDefault(Enable: Boolean);
    procedure Press; virtual;
    procedure SetState(AState: Word; Enable: Boolean); virtual;
  private
    procedure DrawTitle(var B: TDrawBuffer; S, I: Integer; const CButton: TAttrPair;
      Down: Boolean);
  end;

var
  { stream records (see RView of TvViews) }
  RDialog, RStaticText, RLabel, RButton: TStreamRec;

implementation

const
  ButtonPalette = #$0A#$0B#$0C#$0D#$0E#$0E#$0E#$0F;
  StaticTextPalette = #$06;
  LabelPalette = #$07#$08#$09#$09;
  ButtonShadows: array[0..2] of Byte = ($DC, $DB, $DF);
  AnimationDurationMs = 100;

function RangePalette(First: Byte): TPalette;
var
  S: ShortString;
  I: Integer;
begin
  SetLength(S, 32);
  for I := 1 to 32 do
    S[I] := Chr(First + I - 1);
  Result := MakePalette(S);
end;

var
  GrayDialog, BlueDialog, CyanDialog: TPalette;

{ --- TDialog ----------------------------------------------------------------- }

constructor TDialog.Init(const Bounds: TRect; const ATitle: ShortString);
begin
  inherited Init(Bounds, ATitle, wnNoNumber);
  GrowMode := 0;
  Flags := wfMove or wfClose;
  Palette := dpGrayDialog;
end;

function TDialog.GetPalette: TPalette;
begin
  case Palette of
    dpBlueDialog: Result := BlueDialog;
    dpCyanDialog: Result := CyanDialog;
  else
    Result := GrayDialog;
  end;
end;

procedure TDialog.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  case Event.What of
    evKeyDown:
      case Event.KeyCode of
        kbEsc:
          begin
            Event.What := evCommand;
            Event.Command := cmCancel;
            Event.InfoPtr := nil;
            PutEvent(Event);
            ClearEvent(Event);
          end;
        kbEnter:
          begin
            Event.What := evBroadcast;
            Event.Command := cmDefault;
            Event.InfoPtr := nil;
            PutEvent(Event);
            ClearEvent(Event);
          end;
      end;
    evCommand:
      case Event.Command of
        cmOK, cmCancel, cmYes, cmNo:
          if (State and sfModal) <> 0 then
          begin
            EndModal(Event.Command);
            ClearEvent(Event);
          end;
      end;
  end;
end;

function TDialog.Valid(Command: Word): Boolean;
begin
  if Command = cmCancel then
    Result := True
  else
    Result := inherited Valid(Command);
end;

{ --- TStaticText ------------------------------------------------------------- }

constructor TStaticText.Init(const Bounds: TRect; const AText: ShortString);
begin
  inherited Init(Bounds);
  Text := NewStr(AText);
  GrowMode := GrowMode or gfFixed;
end;

destructor TStaticText.Done;
begin
  DisposeStr(Text);
  Text := nil;
  inherited Done;
end;

procedure TStaticText.GetText(var S: ShortString);
var
  I: Integer;
begin
  if Text = nil then
    S := ''
  else
    S := Text^;
  { Borland's Turbo Vision (and DN) end a line with #13, magiblot's with #10: both do here }
  for I := 1 to Length(S) do
    if S[I] = #13 then
      S[I] := #10;
end;

function TStaticText.GetPalette: TPalette;
begin
  Result := MakePalette(StaticTextPalette);
end;

procedure TStaticText.Draw;
var
  Color: TColorAttr;
  Center: Boolean;
  I, J, L, P, Y, Last, Width, CharLen, CharWidth, ScLen, ScWidth: Integer;
  B: TDrawBuffer;
  S: ShortString;
  Pt: PByte;
begin
  Color := GetColor(1).Lo;
  GetText(S);
  L := Length(S);
  Pt := @S[1];
  P := 0;
  Y := 0;
  Center := False;
  B.Init(Size.X);
  while Y < Size.Y do
  begin
    B.MoveChar(0, Ord(' '), Color, Size.X);
    if P < L then
    begin
      if Pt[P] = 3 then
      begin
        Center := True;
        Inc(P);
      end;
      I := P;
      TextScroll(Pt + I, L - I, Size.X, False, ScLen, ScWidth);
      Last := I + ScLen;
      { take words while they fit }
      repeat
        J := P;
        while (P < L) and (Pt[P] = 32) do
          Inc(P);
        while (P < L) and (Pt[P] <> 32) and (Pt[P] <> 10) do
        begin
          TextNext(Pt + P, L - P, CharLen, CharWidth);
          Inc(P, CharLen);
        end;
      until not ((P < L) and (P < Last) and (Pt[P] <> 10));
      if P > Last then
      begin
        if J > I then
          P := J
        else
          P := Last;
      end;
      Width := TextWidth(Pt + I, P - I);
      if Center then
        J := (Size.X - Width) div 2
      else
        J := 0;
      B.MoveStr(J, Pt + I, L - I, Color, Width);
      while (P < L) and (Pt[P] = 32) do
        Inc(P);
      if (P < L) and (Pt[P] = 10) then
      begin
        Center := False;
        Inc(P);
      end;
    end;
    WriteLineD(0, Y, Size.X, 1, B);
    Inc(Y);
  end;
  B.Done;
end;

{ --- TLabel ------------------------------------------------------------------ }

constructor TLabel.Init(const Bounds: TRect; const AText: ShortString; ALink: PView);
begin
  inherited Init(Bounds, AText);
  Link := ALink;
  Light := False;
  Options := Options or ofPreProcess or ofPostProcess;
  EventMask := EventMask or evBroadcast;
end;

destructor TLabel.Done;
begin
  Link := nil;
  inherited Done;
end;

function TLabel.GetPalette: TPalette;
begin
  Result := MakePalette(LabelPalette);
end;

procedure TLabel.Draw;
var
  Color: TAttrPair;
  B: TDrawBuffer;
  ScOff: Integer;
begin
  if Light then
  begin
    Color := GetColor($0402);
    ScOff := 0;
  end
  else
  begin
    Color := GetColor($0301);
    ScOff := 4;
  end;
  B.Init(Size.X);
  B.MoveChar(0, Ord(' '), Color.Lo, Size.X);
  if Text <> nil then
    B.MoveCStrS(1, Text^, Color);
  if ShowMarkers then
    B.PutChar(0, SpecialChars[ScOff]);
  WriteLineD(0, 0, Size.X, 1, B);
  B.Done;
end;

procedure TLabel.FocusLink(var Event: TEvent);
begin
  if (Link <> nil) and ((Link^.Options and ofSelectable) <> 0) then
    Link^.Focus;
  ClearEvent(Event);
end;

procedure TLabel.HandleEvent(var Event: TEvent);
var
  C: Char;
begin
  inherited HandleEvent(Event);
  if Event.What = evMouseDown then
    FocusLink(Event)
  else if Event.What = evKeyDown then
  begin
    if Text <> nil then
      C := HotKey(Text^)
    else
      C := #0;
    if (Event.KeyCode <> 0) and
      ((GetAltCode(C) = Event.KeyCode) or
       ((C <> #0) and (Owner^.Phase = phPostProcess) and (C = UpCase(Chr(Event.CharCode))))) then
      FocusLink(Event);
  end
  else if (Event.What = evBroadcast) and (Link <> nil) and
    ((Event.Command = cmReceivedFocus) or (Event.Command = cmReleasedFocus)) then
  begin
    Light := (Link^.State and sfFocused) <> 0;
    DrawView;
  end;
end;

{ --- TButton ----------------------------------------------------------------- }

constructor TButton.Init(const Bounds: TRect; const ATitle: ShortString; ACommand: Word;
  AFlags: Word);
begin
  inherited Init(Bounds);
  Title := NewStr(ATitle);
  Command := ACommand;
  Flags := AFlags;
  AmDefault := (AFlags and bfDefault) <> 0;
  AnimationTimer := nil;
  Options := Options or ofSelectable or ofFirstClick or ofPreProcess or ofPostProcess;
  EventMask := EventMask or evBroadcast;
  if not CommandEnabled(ACommand) then
    State := State or sfDisabled;
end;

destructor TButton.Done;
begin
  DisposeStr(Title);
  Title := nil;
  KillTimer(AnimationTimer);
  inherited Done;
end;

function TButton.GetPalette: TPalette;
begin
  Result := MakePalette(ButtonPalette);
end;

procedure TButton.Draw;
begin
  DrawState(False);
end;

procedure TButton.DrawTitle(var B: TDrawBuffer; S, I: Integer; const CButton: TAttrPair;
  Down: Boolean);
var
  L, ScOff: Integer;
begin
  if (Flags and bfLeftJust) <> 0 then
    L := 1
  else
  begin
    L := (S - CStrLen(Title^) - 1) div 2;
    if L < 1 then
      L := 1;
  end;
  B.MoveCStrS(I + L, Title^, CButton);
  if ShowMarkers and not Down then
  begin
    if (State and sfSelected) <> 0 then
      ScOff := 0
    else if AmDefault then
      ScOff := 2
    else
      ScOff := 4;
    B.PutChar(0, SpecialChars[ScOff]);
    B.PutChar(S, SpecialChars[ScOff + 1]);
  end;
end;

procedure TButton.DrawState(Down: Boolean);
var
  CButton, CShadow: TAttrPair;
  B: TDrawBuffer;
  S, T, Y, I: Integer;
  Ch: Byte;
begin
  if (State and sfDisabled) <> 0 then
    CButton := GetColor($0404)
  else
  begin
    CButton := GetColor($0501);
    if (State and sfActive) <> 0 then
    begin
      if (State and sfSelected) <> 0 then
        CButton := GetColor($0703)
      else if AmDefault then
        CButton := GetColor($0602);
    end;
  end;
  CShadow := GetColor(8);
  S := Size.X - 1;
  T := Size.Y div 2 - 1;
  Ch := Ord(' ');
  B.Init(Size.X);
  for Y := 0 to Size.Y - 2 do
  begin
    B.MoveChar(0, Ord(' '), CButton.Lo, Size.X);
    B.PutAttribute(0, CShadow.Lo);
    if Down then
    begin
      B.PutAttribute(1, CShadow.Lo);
      Ch := Ord(' ');
      I := 2;
    end
    else
    begin
      B.PutAttribute(S, CShadow.Lo);
      if ShowMarkers then
        Ch := Ord(' ')
      else
      begin
        if Y = 0 then
          B.PutChar(S, ButtonShadows[0])
        else
          B.PutChar(S, ButtonShadows[1]);
        Ch := ButtonShadows[2];
      end;
      I := 1;
    end;
    if (Y = T) and (Title <> nil) then
      DrawTitle(B, S, I, CButton, Down);
    if ShowMarkers and not Down then
    begin
      B.PutChar(1, Ord('['));
      B.PutChar(S - 1, Ord(']'));
    end;
    WriteLineD(0, Y, Size.X, 1, B);
  end;
  B.MoveChar(0, Ord(' '), CShadow.Lo, 2);
  B.MoveChar(2, Ch, CShadow.Lo, S - 1);
  WriteLineD(0, Size.Y - 1, Size.X, 1, B);
  B.Done;
end;

procedure TButton.HandleEvent(var Event: TEvent);
var
  Mouse: TPoint;
  ClickRect: TRect;
  Down: Boolean;
  C: Char;
begin
  ClickRect := GetExtent;
  Inc(ClickRect.A.X);
  Dec(ClickRect.B.X);
  Dec(ClickRect.B.Y);
  if Event.What = evMouseDown then
  begin
    Mouse := MakeLocal(Event.Where);
    if not ClickRect.Contains(Mouse) then
      ClearEvent(Event);
  end;
  if (Flags and bfGrabFocus) <> 0 then
    inherited HandleEvent(Event);
  if Title <> nil then
    C := HotKey(Title^)
  else
    C := #0;
  case Event.What of
    evMouseDown:
      begin
        if (State and sfDisabled) = 0 then
        begin
          Inc(ClickRect.B.X);
          Down := False;
          repeat
            Mouse := MakeLocal(Event.Where);
            if Down <> ClickRect.Contains(Mouse) then
            begin
              Down := not Down;
              DrawState(Down);
            end;
          until not MouseEvent(Event, evMouseMove);
          if Down then
          begin
            Press;
            DrawState(False);
          end;
        end;
        ClearEvent(Event);
      end;
    evKeyDown:
      if (Event.KeyCode <> 0) and
        ((Event.KeyCode = GetAltCode(C)) or
         ((Owner^.Phase = phPostProcess) and (C <> #0) and (C = UpCase(Chr(Event.CharCode)))) or
         (((State and sfFocused) <> 0) and (Event.CharCode = Ord(' ')))) then
      begin
        DrawState(True);
        if AnimationTimer = nil then
          AnimationTimer := SetTimer(AnimationDurationMs);
        ClearEvent(Event);
      end;
    evBroadcast:
      case Event.Command of
        cmDefault:
          if AmDefault and ((State and sfDisabled) = 0) then
          begin
            DrawState(True);
            if AnimationTimer = nil then
              AnimationTimer := SetTimer(AnimationDurationMs);
            ClearEvent(Event);
          end;
        cmGrabDefault, cmReleaseDefault:
          if (Flags and bfDefault) <> 0 then
          begin
            AmDefault := Event.Command = cmReleaseDefault;
            DrawView;
          end;
        cmCommandSetChanged:
          begin
            SetState(sfDisabled, not CommandEnabled(Command));
            DrawView;
          end;
        cmTimerExpired:
          if (AnimationTimer <> nil) and (Event.InfoPtr = AnimationTimer) then
          begin
            AnimationTimer := nil;
            DrawState(False);
            Press;
            ClearEvent(Event);
          end;
      end;
  end;
end;

procedure TButton.MakeDefault(Enable: Boolean);
var
  Cmd: Word;
begin
  if (Flags and bfDefault) = 0 then
  begin
    if Enable then
      Cmd := cmGrabDefault
    else
      Cmd := cmReleaseDefault;
    Message(Owner, evBroadcast, Cmd, @Self);
    AmDefault := Enable;
    DrawView;
  end;
end;

procedure TButton.SetState(AState: Word; Enable: Boolean);
begin
  inherited SetState(AState, Enable);
  if (AState and (sfSelected or sfActive)) <> 0 then
    DrawView;
  if (AState and sfFocused) <> 0 then
    MakeDefault(Enable);
end;

procedure TButton.Press;
var
  E: TEvent;
begin
  Message(Owner, evBroadcast, cmRecordHistory, nil);
  if (Flags and bfBroadcast) <> 0 then
    Message(Owner, evBroadcast, Command, @Self)
  else
  begin
    ClearEvent(E);
    E.What := evCommand;
    E.Command := Command;
    E.InfoPtr := @Self;
    PutEvent(E);
  end;
end;

{ --- Streams ------------------------------------------------------------------ }

{ DirectLink (DN) follows the views of the group in the stream: the numbers of the controls in the dialog (0 = none) }
constructor TDialog.Load(var S: TStream);
var
  I: Integer;
begin
  inherited Load(S);
  for I := 1 to 9 do
    DirectLink[I] := ReadChildPtr(S);
end;

procedure TDialog.Store(var S: TStream);
var
  I: Integer;
begin
  inherited Store(S);
  for I := 1 to 9 do
    PutSubViewPtr(S, DirectLink[I]);
end;

constructor TStaticText.Load(var S: TStream);
begin
  inherited Load(S);
  Text := S.ReadStr;
end;

procedure TStaticText.Store(var S: TStream);
begin
  inherited Store(S);
  S.WriteStr(Text);
end;

constructor TLabel.Load(var S: TStream);
begin
  inherited Load(S);
  GetPeerViewPtr(S, Link);
  Light := False;
end;

procedure TLabel.Store(var S: TStream);
begin
  inherited Store(S);
  PutPeerViewPtr(S, Link);
end;

constructor TButton.Load(var S: TStream);
begin
  inherited Load(S);
  Title := S.ReadStr;
  S.Read(Command, SizeOf(Command));
  S.Read(Flags, SizeOf(Flags));
  S.Read(AmDefault, SizeOf(AmDefault));
  AnimationTimer := nil;
  if not CommandEnabled(Command) then
    State := State or sfDisabled;
end;

procedure TButton.Store(var S: TStream);
begin
  inherited Store(S);
  S.WriteStr(Title);
  S.Write(Command, SizeOf(Command));
  S.Write(Flags, SizeOf(Flags));
  S.Write(AmDefault, SizeOf(AmDefault));
end;

function BuildDialog(var S: TStream): PObject;
begin
  Result := New(PDialog, Load(S));
end;

procedure StoreDialog(P: PObject; var S: TStream);
begin
  PDialog(P)^.Store(S);
end;

function BuildStaticText(var S: TStream): PObject;
begin
  Result := New(PStaticText, Load(S));
end;

procedure StoreStaticText(P: PObject; var S: TStream);
begin
  PStaticText(P)^.Store(S);
end;

function BuildLabel(var S: TStream): PObject;
begin
  Result := New(PLabel, Load(S));
end;

procedure StoreLabel(P: PObject; var S: TStream);
begin
  PLabel(P)^.Store(S);
end;

function BuildButton(var S: TStream): PObject;
begin
  Result := New(PButton, Load(S));
end;

procedure StoreButton(P: PObject; var S: TStream);
begin
  PButton(P)^.Store(S);
end;


initialization
  RDialog.ObjType := 10;
  RDialog.VmtLink := PtrUInt(TypeOf(TDialog));
  RDialog.Load := @BuildDialog;
  RDialog.Store := @StoreDialog;
  RStaticText.ObjType := 18;
  RStaticText.VmtLink := PtrUInt(TypeOf(TStaticText));
  RStaticText.Load := @BuildStaticText;
  RStaticText.Store := @StoreStaticText;
  RLabel.ObjType := 19;
  RLabel.VmtLink := PtrUInt(TypeOf(TLabel));
  RLabel.Load := @BuildLabel;
  RLabel.Store := @StoreLabel;
  RButton.ObjType := 12;
  RButton.VmtLink := PtrUInt(TypeOf(TButton));
  RButton.Load := @BuildButton;
  RButton.Store := @StoreButton;
  GrayDialog := RangePalette($20);
  BlueDialog := RangePalette($40);
  CyanDialog := RangePalette($60);
end.
