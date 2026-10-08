{ mainapp: the application of DN (it replaces mainapp.PAS of the archive, which repeated the App of
  Borland TV). The classes lie on TvApp (tv/), what DN adds is added here. The names are those that the
  sources of DN use (spec/dn-boundary-dnosp214.md).

  Not done yet (marked TODO): the resources of dialogs and strings (tv/ has no Load/Store of views), the
  window of messages (WriteMsg), the command line. They return nil / '' / cmCancel. }
{$mode objfpc}{$H-}{$POINTERMATH ON}
unit mainapp;

interface

uses
  SysUtils, TvInput, TvGeom, TvObjs, TvEvents, TvViews, TvWindow, TvDialog, TvApp, TvList, TvScreen, TvCell, Menus,
  Streams, Views, Drivers, Commands, timeutil, DnIni, DNStrL, RStrings, DNErrLog;

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
    procedure HandleEvent(var Event: TEvent); override;
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
  { the same variables as in TvApp (the instances there are the same) }
  Application: TProgram absolute TvApp.Application;
  Desktop: TDesktop absolute TvApp.DeskTop;
  { the menu bar and the status line of DN (the unit Menus of DN, not those of tv/); set by InitMenuBar and InitStatusLine
    of TDNApplication, put into the program by TProgram.Init }
  StatusLine: Menus.TStatusLine = nil;
  MenuBar: Menus.TMenuView = nil;
  CommandLine: TView = nil;
  { called when the code page of the strings changed (set by the program: boot) }
  CodePageChanged: procedure = nil;
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

uses basics, fileutil, langid, Videoman, osdep, OSStartScreen, dnscreen, TvHist, TvUtf8, TvCodePg, TvLocale, palettes, DNRun, DosHarness, TvCluster, TvKeys, TvSys, TvUtil;

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

{ The list of the window switcher of tv3 (UX guidelines 0.2, 0.3) shows the titles of the windows; a window of DN with no title (the file
  panels) is listed by the name it gives to cmGetName (as in the list of windows of Alt+0): the name is its title while the list is made. }
procedure TDesktop.HandleEvent(var Event: TEvent);
const
  MaxNamed = 32;
var
  Names: array[1..MaxNamed] of ShortString;
  Wins: array[1..MaxNamed] of TWindow;
  Olds: array[1..MaxNamed] of PStr;
  N, I: Integer;
  P: TView;
  K: TKey;
  Back: Boolean;
  IsKey: Boolean;
begin
  N := 0;
  IsKey := False;
  if (Event.What = evKeyDown) and UxSwitcher and UxCtrlTab and KeyUpAvailable then
    if Assigned(OnSwitcherKey) then
      IsKey := OnSwitcherKey(Event, Back)
    else
    begin
      K := KeyMake(Event.KeyCode, Event.ControlKeyState);
      IsKey := (K.Code = TvKeys.kbTab) and ((K.Mods and TvKeys.kbCtrlShift) <> 0);
    end;
  if IsKey and (Last <> nil) then
  begin
    P := Last;
    repeat
      if (P is TWindow) and (TWindow(P).GetTitle(40) = '') and (N < MaxNamed) then
      begin
        Inc(N);
        Names[N] := '';
        Message(P, evCommand, Commands.cmGetName, @Names[N]);
        if Names[N] = '' then
          Dec(N)
        else
        begin
          Wins[N] := TWindow(P);
          Olds[N] := Wins[N].Title;
          Wins[N].Title := @Names[N];
        end;
      end;
      P := P.Next;
    until P = Last;
  end;
  try
    inherited HandleEvent(Event);
  finally
    for I := 1 to N do
      Wins[I].Title := Olds[I];
  end;
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

{ Clear the global references before the group disposes its owned views (the broadcasts
  that the views send while they go find nobody: the command line looks at Desktop^).
  The Done of TvApp.TProgram is not called (it clears the pointers and destroys the
  group in one go). }
destructor TProgram.Destroy;
begin
  MenuBar := nil;
  StatusLine := nil;
  Desktop := nil;
  Buffer := nil;
  inherited Destroy;
  Application := nil;
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

{ True when the focused view (the end of the chain of the current views) is a group of check boxes or radio buttons }
function FocusedIsCluster(App: TGroup): Boolean;
var
  V: TView;
begin
  V := App;
  while (V is TGroup) and (TGroup(V).Current <> nil) do
    V := TGroup(V).Current;
  Result := V is TCluster;
end;

procedure TProgram.GetEvent(var Event: TEvent);
begin
  inherited GetEvent(Event);
  { the keys of the vtui UX guidelines that the options of the Interface setup switch on (dn.ini; the defaults keep the DN keys);
    before the status line, which gives F9 the command "next window" }
  if Event.What = evKeyDown then
    if F9OpensMenu and (DNKeyCode(Event) = Commands.kbF9) then
    begin { M.1: F9 opens the menu bar, as F10 does }
      Event.What := evCommand;
      Event.Command := Commands.cmMenu;
      Event.InfoPtr := nil;
    end
    else if EnterTogglesCheck and (DNKeyCode(Event) = Commands.kbEnter) and FocusedIsCluster(Self) then
      { G.2b: Enter on a check box or a radio button toggles it (it becomes Space); from the other controls it presses the default button }
      MakeKeyEvent(Event, Word(Commands.kbSpace), 0);
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

procedure TProgram.Idle;
begin
  inherited Idle;
  CheckScreenDump;                 { the test harness of the DOS build (DosHarness): inject DNKEYS and stop after DNDUMPSEC; nothing elsewhere }
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
  { the screen of the commands that DN ran (DNRun keeps it: the pty of Linux, the video memory of DOS); the key leaves it, DN is drawn again }
  if HasCommandScreen then
    begin
    ShowCommandScreen;
    Redraw;
    end;
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
  Id, Before: Integer;
  L: String;
begin
  Before := CpCurrent;
  Id := StrToIntDef(GetEnvironmentVariable('DN_CODEPAGE'), 0);
  if Id = 0 then
  begin
    L := '';
    if WithLanguage then
      L := UpperCase(Copy(LngId, 1, 3));
    if (L = 'RUS') or (L = 'BEL') then
      Id := 866
    else if L = 'UKR' then
      Id := 1125                  { the Ukrainian resources of the code page builds are landed on it (tools/to-codepage.py) }
    else
      Id := HostOemCodePage;
  end;
  if Id <> 0 then
    CpSelect(Id);
  { the tables that go with the page (the case of the letters, the sort order) are made again when it changed (the language of the resources is known later than the first call) }
  if (CpCurrent <> Before) and Assigned(CodePageChanged) then
    CodePageChanged;
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
  { Keep the legacy default palette during the class migration.  The
    newer palette is intentionally retained in palettes.pas, but changing
    it here would make the class build differ from the working legacy build
    in every screen cell's foreground/background attributes. }
  { Classic DN palette for acceptance (owner 2026-10-05): cyan default Yes,
    not OSP jaroslaw red/magenta CColorOsp. }
  SystemColors[apColor] := palettes.CColor;
  SystemColors[apBlackWhite] := palettes.CBlackWhite;
  SystemColors[apMonochrome] := palettes.CMonochrome;
  CColor := SystemColors[apColor];
  CBlackWhite := SystemColors[apBlackWhite];
  CMonochrome := SystemColors[apMonochrome];
end.
