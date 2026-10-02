{ DNApp: the application of DN (our unit; it replaces DNAPP.PAS of the archive, which repeated the App of
  Borland TV). The classes lie on TvApp (tv/), what DN adds is added here. The names are those that the
  sources of DN use (spec/dn-boundary-dnosp214.md).

  Not done yet (marked TODO): the resources of dialogs and strings (tv/ has no Load/Store of views), the
  window of messages (WriteMsg), the command line. They return nil / '' / cmCancel. }
{$mode objfpc}{$H-}{$POINTERMATH ON}
unit DNApp;

interface

uses
  SysUtils, TvInput, TvGeom, TvObjs, TvEvents, TvViews, TvWindow, TvDialog, TvApp, TvList, TvScreen, TvCell, Menus,
  Streams, Views, Drivers, Commands, xTime, DnIni, DNStrL, RStrings
{$IFDEF GO32V2}, TvDos, go32{$ENDIF}, DNErrLog;

const
  apColor = TvApp.apColor;
  apBlackWhite = TvApp.apBlackWhite;
  apMonochrome = TvApp.apMonochrome;
  EventsLen: Byte = 0;
  MaxEvents = 15;
  IdleWas: Boolean = False;

var
  EventQueue: array[1..MaxEvents] of TEvent;

type
  PBackground = ^TBackground;
  TBackground = object(TvApp.TBackground)
    constructor Init(var Bounds: TRect; APattern: Char);
  end;

  PDesktop = ^TDesktop;
  TDesktop = object(TvApp.TDeskTop)
    procedure Clear;
  end;

  PProgram = ^TProgram;
  TProgram = object(TvApp.TApplication)
    IdleSecs: TEventTimer;
    constructor Init;
    destructor Done; virtual;
    procedure ActivateView(P: PView);
    { the screen savers of DN (the list of the available ones, the choice of one): TODO, nothing is done; Data is a TSaversData }
    procedure InsertAvIdlerN(const Data; N: Integer);
    { the idler views (the screen saver, the clock...): TODO, nothing is done }
    procedure InsertIdler;
    procedure InsertIdlerN(N: Integer);
    procedure GetEvent(var Event: TEvent); virtual;
    procedure Idle; virtual;
    procedure InitCommandLine; virtual;
    function SetScreenMode(Mode: Word): Boolean;
  end;

  PApplication = ^TApplication;
  TApplication = object(TProgram)
    Clock: PView;
    constructor Init;
    destructor Done; virtual;
    procedure ShowUserScreen;
    procedure WhenShow; virtual;
  end;

  PWriteWin = ^TWriteWin;
  TWriteWin = object(TWindow)
    Tmr: TEventTimer;
    IState: Byte;
  end;

procedure UpdateWriteView(P: Pointer);
procedure OpenResource;
function ExecResource(Key: TDlgIdx; var Data): Word;
function ExecDialog(D: PDialog; var Data): Word;
function LoadResource(Key: TDlgIdx): PObject;
function GlobalMessage(What, Command: Word; InfoPtr: Pointer): Pointer;
function GlobalMessageL(What, Command: Word; InfoLng: LongInt): Pointer;
procedure GlobalEvent(What, Command: Word; InfoPtr: Pointer);
function ViewPresent(Command: Word; InfoPtr: Pointer): PView;
function WriteMsg(Text: String): PView;
function _WriteMsg(const Text: String): PView;
procedure ForceWriteShow(P: Pointer);
function GetString(Index: TStrIdx): String;
procedure ToggleCommandLine(OnOff: Boolean);
procedure AdjustToDesktopSize(var R: TRect; OldDeskSize: TPoint);

var
  { the same variables as in TvApp (the objects there are the same) }
  Application: PProgram absolute TvApp.Application;
  Desktop: PDesktop absolute TvApp.DeskTop;
  { the menu bar and the status line of DN (the unit Menus of DN, not those of tv/); set by InitMenuBar and InitStatusLine
    of TDNApplication, put into the program by TProgram.Init }
  StatusLine: Menus.PStatusLine = nil;
  MenuBar: Menus.PMenuView = nil;
  CommandLine: PView = nil;
  ResourceStream: PStream = nil;
  LngStream: PStream = nil;
  LStringList: PStringList = nil;
  Resource: PIdxResource = nil;
  { the palettes of the program (the strings of attributes): those of tv/ for now. TODO: the palettes of DN are longer
    (CComboBox = #35#36 and others index above the 32 entries of the dialog palette of tv/) }
  CColor, CBlackWhite, CMonochrome: ShortString;
  appPalette: Integer absolute TvApp.AppPalette;
  SystemColors: array[0..2] of ShortString absolute TvApp.SystemColors;
  { a procedure that prepares a dialog for ExecResource; ExecResource clears it }
  PreExecuteDialog: procedure(D: PView) = nil;

implementation

uses Advance, Advance2, Advance7, Videoman, VPSysLow, TvHist;

constructor TBackground.Init(var Bounds: TRect; APattern: Char);
begin
  inherited Init(Bounds, Ord(APattern));
end;

procedure TDesktop.Clear;
var
  P: PView;
begin
  Lock;
  while (Last <> nil) and (Last <> PView(Background)) do
  begin
    P := Last;
    Delete(P);
    Dispose(P, Done);
  end;
  Unlock;
end;

{ As TProgram.Init of DN (the order matters: the status line, the menu and the desktop are inserted in this order, then the
  command line is made; the menu views of DN are made with a zero size (TMenuView.Init) and get the height of one row here).
  The Init of TvApp.TProgram is not called: it makes the views of TV (DN has its own menus). }
constructor TProgram.Init;
var
  R: TRect;
begin
  DNTrace('TProgram.Init');
  Application := @Self;
  InitScreen;
  R.Assign(0, 0, ScreenWidth, ScreenHeight);
  TvViews.TGroup.Init(R);
  State := sfVisible or sfSelected or sfFocused or sfModal or sfExposed;
  Options := 0;
  Buffer := TvScreen.ScreenBuffer;
  InitStatusLine;
  InitMenuBar;
  InitDeskTop;
  if StatusLine <> nil then
    Insert(StatusLine);
  if MenuBar <> nil then
    Insert(MenuBar);
  if Desktop <> nil then
    Insert(Desktop);
  InitCommandLine;
  if StatusLine <> nil then
    StatusLine^.GrowTo(StatusLine^.Size.X, 1);
  if MenuBar <> nil then
    MenuBar^.GrowTo(MenuBar^.Size.X, 1);
  NewTimer(IdleSecs, 0);
  DNTrace('TProgram.Init: done, size=' + IntToStr(Size.X) + 'x' + IntToStr(Size.Y));
end;

{ As TProgram.Done of DN: the menu, the status line and the desktop are disposed first and Application is nil before the group
  is destroyed (the broadcasts that the views send while they go find nobody: the command line looks at Desktop^). The Done of
  TvApp.TProgram is not called (it clears the pointers and destroys the group in one go). }
destructor TProgram.Done;
begin
  if MenuBar <> nil then
    Dispose(MenuBar, Done);
  MenuBar := nil;
  if StatusLine <> nil then
    Dispose(StatusLine, Done);
  StatusLine := nil;
  if Desktop <> nil then
    Dispose(Desktop, Done);
  Desktop := nil;
  Application := nil;
  TvViews.TGroup.Done;
end;

procedure TProgram.ActivateView(P: PView);
begin
  if P <> nil then
    P^.Select;
end;

procedure TProgram.InsertAvIdlerN(const Data; N: Integer);
begin
end;

procedure TProgram.InsertIdler;
begin
end;

procedure TProgram.InsertIdlerN(N: Integer);
begin
end;

procedure TProgram.GetEvent(var Event: TEvent);
begin
  inherited GetEvent(Event);
  { as in Turbo Vision: the status line sees the keys and the clicks on it }
  if (Event.What <> evNothing) and (StatusLine <> nil) then
    if ((Event.What and evKeyDown) <> 0) or
       (((Event.What and evMouseDown) <> 0) and StatusLine^.MouseInView(Event.Where)) then
      StatusLine^.HandleEvent(Event);
  if Event.What = evKeyDown then
    DNTrace('key ' + IntToHex(Event.KeyCode, 4) + ' shift ' + IntToHex(Event.ControlKeyState, 4));
  if Event.What <> evNothing then
  begin
    OldShiftState := ShiftState;
    ShiftState := Byte(Event.ControlKeyState);
    ShiftState2 := Byte(Event.ControlKeyState shr 8);
  end;
end;

{ A test aid: with the environment variable DNDUMP=file the screen is written to the file (TvDos.DosDumpScreen: see
  tools/render-dump.py) after DNDUMPSEC seconds (default 3), and the program ends. DNKEYS=1C0D,011B,A2D00,... (hex key codes,
  scan code and character: 1C0D is Enter, 011B Esc, 3B00 F1; the letters S, C, A before the code hold Shift, Ctrl, Alt: A2D00 is
  Alt-X) are put into the keyboard buffer, one a second, starting after the first second: they drive the program
  before the dump. }
var
  DumpStart: QWord = 0;
  Keys: String = '';
  KeysSent: LongInt = 0;
  IdleSeen: Boolean = False;
  IdleCount: LongInt = 0;

procedure TraceView(P: PView);
begin
  DNTrace('view ' + IntToHex(PtrUInt(P), 8) + ' origin ' + IntToStr(P^.Origin.X) + ',' + IntToStr(P^.Origin.Y) + ' size ' +
    IntToStr(P^.Size.X) + 'x' + IntToStr(P^.Size.Y) + ' state ' + IntToHex(P^.State, 4) + ' options ' + IntToHex(P^.Options, 4));
end;

procedure CheckScreenDump;
{$IFDEF GO32V2}
var
  Name: String;
  Sec, N, I: LongInt;
  V: PView;
  NoShift: Word;
  Entry: String;
begin
  Name := GetEnvironmentVariable('DNDUMP');
  if Name = '' then
    Exit;
  if DumpStart = 0 then
  begin
    DumpStart := GetTickCount64;
    Keys := GetEnvironmentVariable('DNKEYS');
  end;
  { DOSBox-X without a display reports Alt as pressed (bit 3 of the shift flags at 0040:0017): clear the flags, the keys are
    those of a person who holds nothing }
  if Keys <> '' then
  begin
    NoShift := 0;
    dosmemput($40, $17, NoShift, 2);
  end;
  { one key a second }
  while (Keys <> '') and (GetTickCount64 - DumpStart > QWord(KeysSent + 1) * 1000) do
  begin
    I := Pos(',', Keys);
    if I = 0 then
      I := Length(Keys) + 1;
    { the modifiers before the code: S (shift), C (ctrl), A (alt): the shift flags of the BIOS while the key is read }
    Entry := Copy(Keys, 1, I - 1);
    NoShift := 0;
    while (Entry <> '') and (UpCase(Entry[1]) in ['S', 'C', 'A']) do
    begin
      case UpCase(Entry[1]) of
        'S': NoShift := NoShift or 2;
        'C': NoShift := NoShift or 4;
        'A': NoShift := NoShift or 8;
      end;
      Delete(Entry, 1, 1);
    end;
    dosmemput($40, $17, NoShift, 2);
    DosStuffKey(StrToIntDef('$' + Entry, 0));
    Delete(Keys, 1, I);
    Inc(KeysSent);
  end;
  Sec := StrToIntDef(GetEnvironmentVariable('DNDUMPSEC'), 3);
  if GetTickCount64 - DumpStart > QWord(Sec) * 1000 then
  begin
    { the trace of a dump that is blank: the state of the screen of TV and of the hooks of the backend }
    N := 0;
    if TvScreen.ScreenBuffer <> nil then
      for I := 0 to ScreenWidth * ScreenHeight - 1 do
        if not (PByte(TvScreen.ScreenBuffer)[I * SizeOf(TScreenCell)] in [0, 32]) then
          Inc(N);
    DNTrace('dump: screen ' + IntToStr(ScreenWidth) + 'x' + IntToStr(ScreenHeight) + ', non-blank cells in the buffer: ' + IntToStr(N) +
      ', hook set: ' + BoolToStr(Assigned(OnScreenWrite), True) + ', locks: app ' + IntToStr(Application^.LockFlag) + ' desktop ' +
      IntToStr(Desktop^.LockFlag) + ', app buffer = screen: ' + BoolToStr(Application^.Buffer = TvScreen.ScreenBuffer, True));
    { the help context decides what the status line shows }
    DNTrace('idle calls: ' + IntToStr(IdleCount) + ' shift state ' + IntToHex(ShiftState, 2) + ' ' + IntToHex(ShiftState2, 2) + ' old ' + IntToHex(OldShiftState, 2));
    DNTrace('help ctx: app ' + IntToStr(Application^.GetHelpCtx) + ' desktop ' + IntToStr(Desktop^.GetHelpCtx) + ' status ' +
      IntToStr(StatusLine^.HelpCtx) + ' topview ' + IntToHex(PtrUInt(StatusLine^.TopView), 8) + ' app ' + IntToHex(PtrUInt(Application), 8) +
      ' current ' + IntToHex(PtrUInt(Application^.Current), 8) + ' desktop.current ' + IntToHex(PtrUInt(Desktop^.Current), 8));
    { the focused control of the window on top of the desktop, if that is a group (a test aid) }
    if (Desktop^.Current <> nil) and (PGroup(Desktop^.Current)^.Current <> nil) then
      begin
        TraceView(PGroup(Desktop^.Current)^.Current);
        if PGroup(Desktop^.Current)^.Current^.Size.Y = 1 then
          DNTrace('as input line: maxlen ' + IntToStr(PInputLine(PGroup(Desktop^.Current)^.Current)^.MaxLen) + ' curpos ' + IntToStr(PInputLine(PGroup(Desktop^.Current)^.Current)^.CurPos) + ' data [' + PInputLine(PGroup(Desktop^.Current)^.Current)^.Data^ + ']');
      end;
    { the geometry of the main views (a test aid) }
    V := Desktop^.Last;
    if V <> nil then
      repeat
        V := V^.Next;
        TraceView(V);
      until V = Desktop^.Last;
    if MenuBar <> nil then
      TraceView(MenuBar);
    if StatusLine <> nil then
      TraceView(StatusLine);
    TraceView(Desktop);
    DosDumpScreen(Name);
    Halt(0);
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TProgram.Idle;
begin
  if not IdleSeen then
    DNTrace('first Idle');
  IdleSeen := True;
  Inc(IdleCount);
  inherited Idle;
  if Drivers.ScreenBuffer <> nil then
    SysTvGetSrcBuf;               { the copy of the screen that DN reads }
  if StatusLine <> nil then
  begin
    StatusLine^.Update;
    if IdleCount < 4 then
      DNTrace('idle ' + IntToStr(IdleCount) + ': status help ctx ' + IntToStr(StatusLine^.HelpCtx) + ' top help ctx ' +
        IntToStr(StatusLine^.TopView^.GetHelpCtx) + ' items ' + IntToHex(PtrUInt(StatusLine^.Items), 8) + ' defs ' +
        IntToHex(PtrUInt(StatusLine^.Defs), 8));
  end;
  RunBackground;
  CheckScreenDump;
end;

procedure TProgram.InitCommandLine;
begin
end;

function TProgram.SetScreenMode(Mode: Word): Boolean;
begin
  inherited SetScreenMode(Mode);
  Result := True;
end;

{ As TApplication.Init / Done of DN: the video manager of DN (videoman.pas) is started and stopped here, the user screen is the
  screen that was there before DN (vpsyslow grabbed it). The language files and the resources are disposed at the end. }
constructor TApplication.Init;
begin
  Videoman.InitVideo;
  if (UserScreen <> nil) and (Length(SysStartScreen) > 0) and (SysStartScreenWidth = UserScreenWidth) and
     (Length(SysStartScreen) * 2 <= UserScreenSize) then
  begin
    Move(SysStartScreen[0], UserScreen^, Length(SysStartScreen) * 2);
    ScreenSaved := True;
  end;
  inherited Init;
end;

destructor TApplication.Done;
begin
  if LStringList <> nil then
    Dispose(LStringList, Done);
  LStringList := nil;
  if LngStream <> nil then
    Dispose(LngStream, Done);
  LngStream := nil;
  if Resource <> nil then
    Dispose(Resource, Done);
  Resource := nil;
  inherited Done;
  DoneHistory;
  DoneSysError;
  Videoman.DoneVideo;
end;

procedure TApplication.ShowUserScreen;
begin
  { TODO: the screen of the program that started DN (the shell) }
end;

procedure TApplication.WhenShow;
begin
end;

procedure UpdateWriteView(P: Pointer);
begin
end;

procedure ResourceFail(const S: String);
begin
  Writeln('Could not open resource file (' + S + ')');
  Halt(219);
end;

{ The resource files lie in the directory named by the environment variable DNDLG, else in that of the program (SourceDir),
  else in the startup directory. Names: <language>.DLG (dialogs and menus), <language>.LNG (strings): see rcp. }
function OpenResourceStream(const Ext: String): PBufStream;
var
  S: String;
  PS: PBufStream;
begin
  S := GetEnvironmentVariable('DNDLG');
  if S = '' then
    S := SourceDir;
  MakeSlash(S);
  PS := New(PBufStream, Init(S + LngId + Ext, stOpenRead, 1024));
  if PS^.Status <> stOK then
  begin
    Dispose(PS, Done);
    PS := New(PBufStream, Init(StartupDir + LngId + Ext, stOpenRead, 1024));
    if PS^.Status <> stOK then
      ResourceFail(LngId + Ext);
  end;
  Result := PS;
end;

procedure OpenResource;
begin
  if Resource <> nil then
    Exit;
  ResourceStream := OpenResourceStream('.DLG');
  New(Resource, Init(ResourceStream));
end;

function LoadDialog(Key: TDlgIdx): PDialog;
begin
  Result := nil;
  OpenResource;
  if Resource = nil then
    Exit;
  Result := PDialog(Resource^.Get(Key));
  Result := PDialog(Application^.ValidView(Result));
end;

function ExecDialog(D: PDialog; var Data): Word;
begin
  D^.SetData(Data);
  Result := Desktop^.ExecView(D);
  if Result <> cmCancel then
    D^.GetData(Data);
end;

{ TODO: PreExecuteDialog may be a procedure local to the caller (the original ExecResource had no stack frame for that: VP asm) }
function ExecResource(Key: TDlgIdx; var Data): Word;
var
  D: PDialog;
begin
  Result := cmCancel;
  DNTrace('ExecResource ' + IntToStr(Ord(Key)));
  D := LoadDialog(Key);
  DNTrace('ExecResource: loaded ' + IntToHex(PtrUInt(D), 8));
  if D = nil then
    Exit;
  if Assigned(PreExecuteDialog) then
    PreExecuteDialog(D);
  DNTrace('ExecResource: executing');
  Result := ExecDialog(D, Data);
  DNTrace('ExecResource: done ' + IntToStr(Result));
  Dispose(D, Done);
  PreExecuteDialog := nil;
end;

function LoadResource(Key: TDlgIdx): PObject;
begin
  Result := nil;
  OpenResource;
  if Resource = nil then
    Exit;
  Result := Resource^.Get(Key);
end;

function GlobalMessage(What, Command: Word; InfoPtr: Pointer): Pointer;
begin
  Result := Message(Application, What, Command, InfoPtr);
end;

function GlobalMessageL(What, Command: Word; InfoLng: LongInt): Pointer;
begin
  Result := Message(Application, What, Command, Pointer(PtrInt(InfoLng)));
end;

procedure GlobalEvent(What, Command: Word; InfoPtr: Pointer);
var
  E: TEvent;
begin
  FillChar(E, SizeOf(E), 0);
  E.What := What;
  E.Command := Command;
  E.InfoPtr := InfoPtr;
  Application^.PutEvent(E);
end;

function ViewPresent(Command: Word; InfoPtr: Pointer): PView;
begin
  Result := PView(Message(Application, evBroadcast, Command, InfoPtr));
end;

{ A window with a text (the program shows it while it does something long: "Reading the file..."); the caller disposes it
  (Info^.Free). It is made at once: DN shows it only if the work takes time (TWriteWin.Tmr), TODO. }
function WriteMsg(Text: String): PView;
var
  R: TRect;
  W: PWriteWin;
  T: PStaticText;
  I, Lines, Wd, Cur: Integer;
begin
  Lines := 1;
  Wd := 1;
  Cur := 0;
  for I := 1 to Length(Text) do
    case Text[I] of
      #13, #10:
        begin
          Inc(Lines);
          Cur := 0;
        end;
      #3: ;
    else
      begin
        Inc(Cur);
        if Cur > Wd then
          Wd := Cur;
      end;
    end;
  if Wd > 60 then
    Wd := 60;
  R.Assign(0, 0, Wd + 6, Lines + 4);
  if Desktop <> nil then
    R.Move((Desktop^.Size.X - (R.B.X - R.A.X)) div 2, (Desktop^.Size.Y - (R.B.Y - R.A.Y)) div 2);
  New(W, Init(R, '', wnNoNumber));
  W^.Flags := 0;
  R.Assign(2, 1, Wd + 4, Lines + 3);
  New(T, Init(R, Text));
  W^.Insert(T);
  if Desktop <> nil then
    Desktop^.Insert(W);
  Result := W;
end;

function _WriteMsg(const Text: String): PView;
begin
  Result := WriteMsg(Text);
end;

procedure ForceWriteShow(P: Pointer);
begin
end;

procedure InitLngStream;
var
  PS, XS: PStream;
begin
  PS := OpenResourceStream('.LNG');
  { the strings are read from memory: the file is copied (as the original does) }
  XS := New(PMemoryStream, Init(PS^.GetSize, PS^.GetSize));
  if XS^.Status <> stOK then
  begin
    Dispose(XS, Done);
    XS := nil;
  end;
  if XS <> nil then
  begin
    XS^.CopyFrom(PS^, PS^.GetSize);
    if XS^.Status = stOK then
    begin
      Dispose(PS, Done);
      PS := XS;
    end
    else
      Dispose(XS, Done);
  end;
  LngStream := PS;
  PS^.Seek(0);
  LStringList := PStringList(PS^.Get);
  if (PS^.Status <> stOK) or (LStringList = nil) then
    ResourceFail('reading ' + LngId + '.LNG');
end;

function GetString(Index: TStrIdx): String;
begin
  if LStringList = nil then
    InitLngStream;
  Result := LStringList^.Get(Word(Ord(Index)));
end;

procedure ToggleCommandLine(OnOff: Boolean);
begin
  { TODO: the command line }
end;

procedure AdjustToDesktopSize(var R: TRect; OldDeskSize: TPoint);
var
  S: TPoint;
begin
  if Desktop = nil then
    Exit;
  S := Desktop^.Size;
  { keep the rectangle inside the desktop (it may have become smaller) }
  if R.B.X > S.X then
    R.Move(S.X - R.B.X, 0);
  if R.B.Y > S.Y then
    R.Move(0, S.Y - R.B.Y);
  if R.A.X < 0 then
    R.Move(-R.A.X, 0);
  if R.A.Y < 0 then
    R.Move(0, -R.A.Y);
  if R.B.X > S.X then
    R.B.X := S.X;
  if R.B.Y > S.Y then
    R.B.Y := S.Y;
end;

{ The commands of the features that DN was built without (TView.MenuEnabled of DN, evaluated for the defines of the
  tree: STDEFINE.INC); the game can be switched off in the setup. }
function CommandHidden(Command: Word): Boolean;
begin
  Result := ((Command = cmGame) and not EnableGame) or (Command = cmPlayCD) or (Command = cmSystemInfo) or
    (Command = cmMemoryInfo);
end;

{ A test aid (see CheckScreenDump): at the end of the program the exit code and the address of the error go to DNLOG.TXT
  and the screen to the file named by DNDUMP (if it was not written yet). }
procedure DumpAtExit;
{$IFDEF GO32V2}
var
  T: Text;
begin
  if GetEnvironmentVariable('DNDUMP') = '' then
    Exit;
  Assign(T, 'DNLOG.TXT');
  Rewrite(T);
  Writeln(T, 'exit code ', ExitCode, ' error address ', IntToHex(PtrUInt(ErrorAddr), 8));
  Close(T);
  if DumpStart = 0 then
    DosDumpScreen(GetEnvironmentVariable('DNDUMP'));
end;
{$ELSE}
begin
end;
{$ENDIF}

initialization
  CommandHiddenHook := @CommandHidden;
  ListBoxOwnsList := False;       { DN: the owner of the list disposes it }
  CColor := SystemColors[apColor];
  CBlackWhite := SystemColors[apBlackWhite];
  CMonochrome := SystemColors[apMonochrome];
finalization
  DumpAtExit;
end.
