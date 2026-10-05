{ mainapp: the application of DN (our unit; it replaces mainapp.PAS of the archive, which repeated the App of
  Borland TV). The classes lie on TvApp (tv/), what DN adds is added here. The names are those that the
  sources of DN use (spec/dn-boundary-dnosp214.md).

  Not done yet (marked TODO): the resources of dialogs and strings (tv/ has no Load/Store of views), the
  window of messages (WriteMsg), the command line. They return nil / '' / cmCancel. }
{$mode objfpc}{$H-}{$POINTERMATH ON}
unit mainapp;

interface

uses
  SysUtils, TvInput, TvGeom, TvObjs, TvEvents, TvViews, TvWindow, TvDialog, TvApp, TvList, TvScreen, TvCell, Menus,
  Streams, Views, Drivers, Commands, timeutil, DnIni, DNStrL, RStrings
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
  TBackground = class;

  TBackground = class(TvApp.TBackground)
    constructor Create(const Bounds: TRect; APattern: Byte);
  end;

  TDesktop = class;

  TDesktop = class(TvApp.TDeskTop)
    procedure Clear;
  end;

  TProgram = class;

  TProgram = class(TvApp.TApplication)
    IdleSecs: TEventTimer;
    constructor Create;
    destructor Destroy; override;
    procedure ActivateView(P: TView);
    { the screen savers of DN (the list of the available ones, the choice of one): TODO, nothing is done; Data is a TSaversData }
    procedure InsertAvIdlerN(const Data; N: Integer);
    { the idler views (the screen saver, the clock...): TODO, nothing is done }
    procedure InsertIdler;
    procedure InsertIdlerN(N: Integer);
    procedure GetEvent(var Event: TEvent); override;
    procedure Idle; override;
    procedure InitCommandLine; virtual;
    function SetScreenMode(Mode: Word): Boolean;
  end;

  TApplication = class;

  TApplication = class(TProgram)
    Clock: TView;
    constructor Create;
    destructor Destroy; override;
    procedure ShowUserScreen;
    procedure WhenShow; virtual;
  end;

  TWriteWin = class;
  TWriteWin = class(TWindow)
    Tmr: TEventTimer;
    IState: Byte;
  end;

procedure UpdateWriteView(P: Pointer);
procedure OpenResource;
function ExecResource(Key: TDlgIdx; var Data): Word;
function ExecDialog(D: TDialog; var Data): Word;
function LoadResource(Key: TDlgIdx): TStreamable;
function GlobalMessage(What, Command: Word; InfoPtr: Pointer): Pointer;
function GlobalMessageL(What, Command: Word; InfoLng: LongInt): Pointer;
procedure GlobalEvent(What, Command: Word; InfoPtr: Pointer);
function ViewPresent(Command: Word; InfoPtr: Pointer): TView;
function WriteMsg(Text: String): TView;
function _WriteMsg(const Text: String): TView;
procedure ForceWriteShow(P: Pointer);
function GetString(Index: TStrIdx): String;
procedure ToggleCommandLine(OnOff: Boolean);
procedure AdjustToDesktopSize(var R: TRect; OldDeskSize: TPoint);

var
  { the same variables as in TvApp (the objects there are the same) }
  Application: TProgram absolute TvApp.Application;
  Desktop: TDesktop absolute TvApp.DeskTop;
  { the menu bar and the status line of DN (the unit Menus of DN, not those of tv/); set by InitMenuBar and InitStatusLine
    of TDNApplication, put into the program by TProgram.Init }
  StatusLine: Menus.TStatusLine = nil;
  MenuBar: Menus.TMenuView = nil;
  CommandLine: TView = nil;
  ResourceStream: TStream = nil;
  LngStream: TStream = nil;
  LStringList: TStringList = nil;
  Resource: TIdxResource = nil;
  { the palettes of the program (the strings of attributes): those of DN (DNPalet), set in the initialization }
  CColor, CBlackWhite, CMonochrome: ShortString;
  appPalette: Integer absolute TvApp.AppPalette;
  SystemColors: array[0..2] of ShortString absolute TvApp.SystemColors;
  { a procedure that prepares a dialog for ExecResource; ExecResource clears it }
  PreExecuteDialog: procedure(D: TView) = nil;

implementation

uses basics, fileutil, langid, Videoman, osdep, dnscreen, TvHist, TvUtf8, TvCodePg, TvLocale, palettes{$IFDEF LINUX}, DNRun, TvVtRun{$ENDIF}{$IFDEF GO32V2}, DNRun{$ENDIF};

constructor TBackground.Create(const Bounds: TRect; APattern: Byte);
begin
  inherited Create(Bounds, APattern);
end;

procedure TDesktop.Clear;
var
  P: TView;
begin
  Lock;
  while (Last <> nil) and (Last <> TView(Background)) do
  begin
    P := Last;
    Delete(P);
    P.Free;
  end;
  Unlock;
end;

{ As TProgram.Init of DN (the order matters: the status line, the menu and the desktop are inserted in this order, then the
  command line is made; the menu views of DN are made with a zero size (TMenuView.Init) and get the height of one row here).
  The Init of TvApp.TProgram is not called: it makes the views of TV (DN has its own menus). }
constructor TProgram.Create;
var
  R: TRect;
begin
  Application := Self;
  InitScreen;
  R.Assign(0, 0, ScreenWidth, ScreenHeight);
  TGroup(Self).Create(R);
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
    StatusLine.GrowTo(StatusLine.Size.X, 1);
  if MenuBar <> nil then
    MenuBar.GrowTo(MenuBar.Size.X, 1);
  NewTimer(IdleSecs, 0);
end;

{ As TProgram.Done of DN: the menu, the status line and the desktop are disposed first and Application is nil before the group
  is destroyed (the broadcasts that the views send while they go find nobody: the command line looks at Desktop^). The Done of
  TvApp.TProgram is not called (it clears the pointers and destroys the group in one go). }
destructor TProgram.Destroy;
begin
  if MenuBar <> nil then
    MenuBar.Free;
  MenuBar := nil;
  if StatusLine <> nil then
    StatusLine.Free;
  StatusLine := nil;
  if Desktop <> nil then
    Desktop.Free;
  Desktop := nil;
  Application := nil;
  inherited Destroy;
end;

procedure TProgram.ActivateView(P: TView);
begin
  if P <> nil then
    P.Select;
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
       (((Event.What and evMouseDown) <> 0) and StatusLine.MouseInView(Event.Where)) then
      StatusLine.HandleEvent(Event);
  { the state of the shift keys is that of keyboard and mouse events: the field is not set in the messages (commands, broadcasts) }
  if (Event.What and (evKeyDown or evMouse)) <> 0 then
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
  before the dump. DNMOUSE=D3:0,U3:0,DD10:5,... mouse events (column:row, 0-based): D down, U up, M move, DD down of a double click
  (L the left button, a leading R the right: RD3:0), one a second, half a second after the keys; they go into the queue of the application
  (the driver of the mouse is not used: DOSBox-X without a display has no pointer). }
var
  DumpStart: QWord = 0;
  Keys: String = '';
  KeysSent: LongInt = 0;
  MouseEv: String = '';
  MouseSent: LongInt = 0;
  IdleSeen: Boolean = False;
  IdleCount: LongInt = 0;

procedure TraceView(P: TView);
begin
  DNTrace('view ' + IntToHex(PtrUInt(P), 8) + ' origin ' + IntToStr(P.Origin.X) + ',' + IntToStr(P.Origin.Y) + ' size ' +
    IntToStr(P.Size.X) + 'x' + IntToStr(P.Size.Y) + ' state ' + IntToHex(P.State, 4) + ' options ' + IntToHex(P.Options, 4));
end;

procedure CheckScreenDump;
{$IFDEF GO32V2}
var
  Name: String;
  Sec, N, I: LongInt;
  V: TView;
  NoShift: Word;
  Entry: String;
  Ev: TEvent;
begin
  Name := GetEnvironmentVariable('DNDUMP');
  if Name = '' then
    Exit;
  if DumpStart = 0 then
  begin
    DumpStart := GetTickCount64;
    Keys := GetEnvironmentVariable('DNKEYS');
    MouseEv := GetEnvironmentVariable('DNMOUSE');
  end;
  { the mouse events: the queue of the application holds one event, a second is put in only when the first was taken }
  while (MouseEv <> '') and (GetTickCount64 - DumpStart > QWord(MouseSent + 1) * 1000 + 500) do
  begin
    I := Pos(',', MouseEv);
    if I = 0 then
      I := Length(MouseEv) + 1;
    Entry := UpperCase(Copy(MouseEv, 1, I - 1));
    Delete(MouseEv, 1, I);
    Inc(MouseSent);
    DNTrace('mouse entry ' + Entry);
    FillChar(Ev, SizeOf(Ev), 0);
    Ev.Buttons := mbLeftButton;
    if (Entry <> '') and (Entry[1] = 'R') then
    begin
      Ev.Buttons := mbRightButton;
      Delete(Entry, 1, 1);
    end;
    if Copy(Entry, 1, 2) = 'DD' then
    begin
      Ev.EventFlags := meDoubleClick;
      Delete(Entry, 1, 1);
    end;
    if Entry = '' then
      Continue;
    case Entry[1] of
      'D': Ev.What := evMouseDown;
      'U': Ev.What := evMouseUp;
      'M': Ev.What := evMouseMove;
    else
      Continue;
    end;
    Delete(Entry, 1, 1);
    I := Pos(':', Entry);
    Ev.Where.X := StrToIntDef(Copy(Entry, 1, I - 1), 0);
    Ev.Where.Y := StrToIntDef(Copy(Entry, I + 1, 9), 0);
    Application.PutEvent(Ev);
    DNTrace('mouse event ' + IntToHex(Ev.What, 2) + ' at ' + IntToStr(Ev.Where.X) + ',' + IntToStr(Ev.Where.Y));
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
      ', hook set: ' + BoolToStr(Assigned(OnScreenWrite), True) + ', locks: app ' + IntToStr(Application.LockFlag) + ' desktop ' +
      IntToStr(Desktop.LockFlag) + ', app buffer = screen: ' + BoolToStr(Application.Buffer = TvScreen.ScreenBuffer, True));
    { the help context decides what the status line shows }
    DNTrace('mouse driver: ' + BoolToStr(DosMousePresent, True));
    DNTrace('idle calls: ' + IntToStr(IdleCount) + ' shift state ' + IntToHex(ShiftState, 2) + ' ' + IntToHex(ShiftState2, 2) + ' old ' + IntToHex(OldShiftState, 2));
    DNTrace('help ctx: app ' + IntToStr(Application.GetHelpCtx) + ' desktop ' + IntToStr(Desktop.GetHelpCtx) + ' status ' +
      IntToStr(StatusLine.HelpCtx) + ' topview ' + IntToHex(PtrUInt(StatusLine.TopView), 8) + ' app ' + IntToHex(PtrUInt(Application), 8) +
      ' current ' + IntToHex(PtrUInt(Application.Current), 8) + ' desktop.current ' + IntToHex(PtrUInt(Desktop.Current), 8));
    { the focused control of the window on top of the desktop, if that is a group (a test aid; the top view may be a menu, which
      is not a group: the access violation is taken, the trace must not kill the program) }
    try
      if (Desktop.Current <> nil) and (PGroup(Desktop.Current).Current <> nil) then
        begin
          TraceView(PGroup(Desktop.Current).Current);
          if PGroup(Desktop.Current).Current.Size.Y = 1 then
            DNTrace('as input line: maxlen ' + IntToStr(TInputLine(PGroup(Desktop.Current).Current).MaxLen) + ' curpos ' + IntToStr(TInputLine(PGroup(Desktop.Current).Current).CurPos) + ' data [' + TInputLine(PGroup(Desktop.Current).Current).Data^ + ']');
        end;
    except
      DNTrace('(the top view of the desktop is not a window)');
    end;
    { the geometry of the main views (a test aid) }
    V := Desktop.Last;
    if V <> nil then
      repeat
        V := V.Next;
        TraceView(V);
      until V = Desktop.Last;
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
  inherited Idle;
  if Drivers.ScreenBuffer <> nil then
    ReadScreenCells;               { the copy of the screen that DN reads }
  if StatusLine <> nil then
  begin
    StatusLine.Update;
  end;
  RunBackground;
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
  screen that was there before DN (osdep grabbed it). The language files and the resources are disposed at the end. }
constructor TApplication.Create;
begin
  Videoman.InitVideo;
  if (UserScreen <> nil) and (Length(SysStartScreen) > 0) and (SysStartScreenWidth = UserScreenWidth) and
     (Length(SysStartScreen) * 2 <= UserScreenSize) then
  begin
    Move(SysStartScreen[0], UserScreen^, Length(SysStartScreen) * 2);
    ScreenSaved := True;
  end;
  inherited Create;
end;

destructor TApplication.Destroy;
begin
  if LStringList <> nil then
    LStringList.Free;
  LStringList := nil;
  if LngStream <> nil then
    LngStream.Free;
  LngStream := nil;
  if Resource <> nil then
    Resource.Free;
  Resource := nil;
  inherited Destroy;
  DoneHistory;
  DoneSysError;
  Videoman.DoneVideo;
end;

procedure TApplication.ShowUserScreen;
begin
{$IFDEF LINUX}
  { the screen of the commands that DN ran (TvVtRun); the key leaves it, DN is drawn again }
  if UserScr.Cols > 0 then
    begin
    VtShowScreen(UserScr);
    Redraw;
    end;
{$ENDIF}
{$IFDEF GO32V2}
  { the screen of the programs that DN ran (and before that of the one that started DN), DNRun.RunExternal keeps it in UserScreen }
  ShowUserScreenDos;
  Redraw;
{$ENDIF}
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

{ The single-byte code page of the strings of DN (the screen, the typed text, the file names that are converted): DN_CODEPAGE=866 (a number
  of TvCodePg) if it is set; else 866 for the Russian, Ukrainian and Belarusian resources (they are written in it); else the page that goes with
  the locale of the host (TvLocale: ru_RU 866, de_DE 850, pl_PL 852...); a locale that is not known (C, POSIX): the default of TvCodePg. }
procedure ApplyCodePage(WithLanguage: Boolean);
var
  Id: Integer;
  L: String;
begin
  Id := StrToIntDef(GetEnvironmentVariable('DN_CODEPAGE'), 0);
  if Id = 0 then
  begin
    L := '';
    if WithLanguage then
      L := UpperCase(Copy(LngId, 1, 3));
    if (L = 'RUS') or (L = 'UKR') or (L = 'BEL') then
      Id := 866
    else
      Id := HostOemCodePage;
  end;
  if Id <> 0 then
    CpSelect(Id);
end;

{ The resource files lie in the directory named by the environment variable DNDLG, else in that of the program (SourceDir),
  else in the startup directory. Names: <language>.DLG (dialogs and menus), <language>.LNG (strings): see rcp. }
function OpenResourceStream(const Ext: String): TBufStream;
var
  S: String;
  PS: TBufStream;
begin
  ApplyCodePage(True);
  S := GetEnvironmentVariable('DNDLG');
  if S = '' then
    S := SourceDir;
  MakeSlash(S);
  PS := TBufStream.Create(S + LngId + Ext, stOpenRead, 1024);
  if PS.Status <> stOK then
  begin
    PS.Free;
    PS := TBufStream.Create(StartupDir + LngId + Ext, stOpenRead, 1024);
    if PS.Status <> stOK then
      ResourceFail(LngId + Ext);
  end;
  Result := PS;
end;

procedure OpenResource;
begin
  if Resource <> nil then
    Exit;
  ResourceStream := OpenResourceStream('.dlg');
  Resource := TIdxResource.Create(ResourceStream);
end;

function LoadDialog(Key: TDlgIdx): TDialog;
begin
  Result := nil;
  OpenResource;
  if Resource = nil then
    Exit;
  Result := TDialog(Resource.Get(Key));
  Result := TDialog(Application.ValidView(Result));
end;

function ExecDialog(D: TDialog; var Data): Word;
begin
  D.SetData(Data);
  Result := Desktop.ExecView(D);
  if Result <> cmCancel then
    D.GetData(Data);
end;

{ TODO: PreExecuteDialog may be a procedure local to the caller (the original ExecResource had no stack frame for that: VP asm) }
function ExecResource(Key: TDlgIdx; var Data): Word;
var
  D: TDialog;
begin
  Result := cmCancel;
  D := LoadDialog(Key);
  if D = nil then
    Exit;
  if Assigned(PreExecuteDialog) then
    PreExecuteDialog(D);
  Result := ExecDialog(D, Data);
  D.Free;
  PreExecuteDialog := nil;
end;

function LoadResource(Key: TDlgIdx): TStreamable;
begin
  Result := nil;
  OpenResource;
  if Resource = nil then
    Exit;
  Result := Resource.Get(Key);
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
  Application.PutEvent(E);
end;

function ViewPresent(Command: Word; InfoPtr: Pointer): TView;
begin
  Result := TView(Message(Application, evBroadcast, Command, InfoPtr));
end;

{ A window with a text (the program shows it while it does something long: "Reading the file..."); the caller disposes it
  (Info.Free). It is made at once: DN shows it only if the work takes time (TWriteWin.Tmr), TODO. }
function WriteMsg(Text: String): TView;
var
  R: TRect;
  W: TWriteWin;
  T: TStaticText;
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
    R.Move((Desktop.Size.X - (R.B.X - R.A.X)) div 2, (Desktop.Size.Y - (R.B.Y - R.A.Y)) div 2);
  W := TWriteWin.Create(R, '', wnNoNumber);
  W.Flags := 0;
  R.Assign(2, 1, Wd + 4, Lines + 3);
  T := TStaticText.Create(R, Text);
  W.Insert(T);
  if Desktop <> nil then
    Desktop.Insert(W);
  Result := W;
end;

function _WriteMsg(const Text: String): TView;
begin
  Result := WriteMsg(Text);
end;

procedure ForceWriteShow(P: Pointer);
begin
end;

procedure InitLngStream;
var
  PS, XS: TStream;
begin
  PS := OpenResourceStream('.lng');
  { the strings are read from memory: the file is copied (as the original does) }
  XS := TMemoryStream.Create(PS.GetSize, PS.GetSize);
  if XS.Status <> stOK then
  begin
    XS.Free;
    XS := nil;
  end;
  if XS <> nil then
  begin
    XS.CopyFrom(PS, PS.GetSize);
    if XS.Status = stOK then
    begin
      PS.Free;
      PS := XS;
    end
    else
      XS.Free;
  end;
  LngStream := PS;
  PS.Seek(0);
  LStringList := TStringList(PS.Get);
  if (PS.Status <> stOK) or (LStringList = nil) then
    ResourceFail('reading ' + LngId + '.lng');
end;

function GetString(Index: TStrIdx): String;
begin
  if LStringList = nil then
    InitLngStream;
  Result := LStringList.Get(Word(Ord(Index)));
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
  S := Desktop.Size;
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
  Assign(T, 'dnlog.txt');
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
  ApplyCodePage(False);           { by the locale of the host (the language of the resources is known later: OpenResourceStream calls it again) }
{$IFDEF DNUTF8}
  Utf8Enabled := True;            { UTF-8 inside (PLAN.md, item 4; the build with -dDNUTF8): text that is valid UTF-8 is UTF-8 }
  InputLineOem := False;          { the typed text stays UTF-8 }
{$ELSE}
  Utf8Enabled := False;           { the strings of DN are bytes of the code page, never UTF-8 (TvUtf8)}
  InputLineOem := True;           { the lines of DN keep the bytes of its code page: the typed text (UTF-8) is converted }
{$ENDIF}
  CommandHiddenHook := @CommandHidden;
  ListBoxOwnsList := False;       { DN: the owner of the list disposes it }
  { the palettes of DN (DNPalet: carved from the archive) replace those of tv/ }
  SystemColors[apColor] := palettes.CColor;
  SystemColors[apBlackWhite] := palettes.CBlackWhite;
  SystemColors[apMonochrome] := palettes.CMonochrome;
  CColor := SystemColors[apColor];
  CBlackWhite := SystemColors[apBlackWhite];
  CMonochrome := SystemColors[apMonochrome];
end.
