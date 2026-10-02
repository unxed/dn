{ DNApp: the application of DN (our unit; it replaces DNAPP.PAS of the archive, which repeated the App of
  Borland TV). The classes lie on TvApp (tv/), what DN adds is added here. The names are those that the
  sources of DN use (spec/dn-boundary-dnosp214.md).

  Not done yet (marked TODO): the resources of dialogs and strings (tv/ has no Load/Store of views), the
  window of messages (WriteMsg), the command line. They return nil / '' / cmCancel. }
{$mode objfpc}{$H-}{$POINTERMATH ON}
unit DNApp;

interface

uses
  SysUtils, TvGeom, TvObjs, TvEvents, TvViews, TvWindow, TvDialog, TvApp, TvList, TvScreen, TvCell, Menus,
  Streams, Views, Drivers, Commands, xTime, DnIni, DNStrL, RStrings
{$IFDEF GO32V2}, TvDos{$ENDIF}, DNErrLog;

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

uses Advance, Advance2, Advance7;

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

constructor TProgram.Init;
begin
  DNTrace('TProgram.Init');
  inherited Init;
  DNTrace('TProgram.Init: tv done, size=' + IntToStr(Size.X) + 'x' + IntToStr(Size.Y) + ' desktop=' + IntToStr(Desktop^.Size.X) + 'x' +
    IntToStr(Desktop^.Size.Y) + ' origin=' + IntToStr(Desktop^.Origin.X) + ',' + IntToStr(Desktop^.Origin.Y));
  DNTrace('StatusLine=' + IntToHex(PtrUInt(StatusLine), 8) + ' MenuBar=' + IntToHex(PtrUInt(MenuBar), 8));
  if StatusLine <> nil then
    Insert(StatusLine);
  DNTrace('status inserted');
  if MenuBar <> nil then
    Insert(MenuBar);
  DNTrace('menu inserted');
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
  if Event.What <> evNothing then
  begin
    OldShiftState := ShiftState;
    ShiftState := Byte(Event.ControlKeyState);
    ShiftState2 := Byte(Event.ControlKeyState shr 8);
  end;
end;

{ A test aid: with the environment variable DNDUMP=file the screen is written to the file (TvDos.DosDumpScreen: see
  tools/render-dump.py) after DNDUMPSEC seconds (default 3), and the program ends. DNKEYS=1C0D,011B,... (hex key codes,
  scan code and character: 1C0D is Enter, 011B Esc, 3B00 F1) are put into the keyboard buffer, one a second, starting
  after the first second: they drive the program before the dump. }
var
  DumpStart: QWord = 0;
  Keys: String = '';
  KeysSent: LongInt = 0;
  IdleSeen: Boolean = False;

procedure CheckScreenDump;
{$IFDEF GO32V2}
var
  Name: String;
  Sec, N, I: LongInt;
begin
  Name := GetEnvironmentVariable('DNDUMP');
  if Name = '' then
    Exit;
  if DumpStart = 0 then
  begin
    DumpStart := GetTickCount64;
    Keys := GetEnvironmentVariable('DNKEYS');
  end;
  { one key a second }
  while (Keys <> '') and (GetTickCount64 - DumpStart > QWord(KeysSent + 1) * 1000) do
  begin
    I := Pos(',', Keys);
    if I = 0 then
      I := Length(Keys) + 1;
    DosStuffKey(StrToIntDef('$' + Copy(Keys, 1, I - 1), 0));
    Delete(Keys, 1, I);
    Inc(KeysSent);
  end;
  Sec := StrToIntDef(GetEnvironmentVariable('DNDUMPSEC'), 3);
  if GetTickCount64 - DumpStart > QWord(Sec) * 1000 then
  begin
    { the trace of a dump that is blank: the state of the screen of TV and of the hooks of the backend }
    N := 0;
    if ScreenBuffer <> nil then
      for I := 0 to ScreenWidth * ScreenHeight - 1 do
        if not (PByte(ScreenBuffer)[I * SizeOf(TScreenCell)] in [0, 32]) then
          Inc(N);
    DNTrace('dump: screen ' + IntToStr(ScreenWidth) + 'x' + IntToStr(ScreenHeight) + ', non-blank cells in the buffer: ' + IntToStr(N) +
      ', hook set: ' + BoolToStr(Assigned(OnScreenWrite), True) + ', locks: app ' + IntToStr(Application^.LockFlag) + ' desktop ' +
      IntToStr(Desktop^.LockFlag) + ', app buffer = screen: ' + BoolToStr(Application^.Buffer = ScreenBuffer, True));
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
  inherited Idle;
  CheckScreenDump;
  if StatusLine <> nil then
    StatusLine^.Update;
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
  D := LoadDialog(Key);
  if D = nil then
    Exit;
  if @PreExecuteDialog <> nil then
    PreExecuteDialog(D);
  Result := ExecDialog(D, Data);
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

function WriteMsg(Text: String): PView;
begin
  Result := nil;                  { TODO: the window of messages }
end;

function _WriteMsg(const Text: String): PView;
begin
  Result := nil;
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
