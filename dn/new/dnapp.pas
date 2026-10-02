{ DNApp: the application of DN (our unit; it replaces DNAPP.PAS of the archive, which repeated the App of
  Borland TV). The classes lie on TvApp (tv/), what DN adds is added here. The names are those that the
  sources of DN use (spec/dn-boundary-dnosp214.md).

  Not done yet (marked TODO): the resources of dialogs and strings (tv/ has no Load/Store of views), the
  window of messages (WriteMsg), the command line. They return nil / '' / cmCancel. }
{$mode objfpc}{$H-}
unit DNApp;

interface

uses
  SysUtils, TvGeom, TvObjs, TvEvents, TvViews, TvWindow, TvDialog, TvApp, Menus,
  Streams, Views, Drivers, Commands, xTime, DnIni, DNStrL, RStrings;

const
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
  appPalette: Integer absolute TvApp.AppPalette;
  SystemColors: array[0..2] of ShortString absolute TvApp.SystemColors;
  { a procedure that prepares a dialog for ExecResource; ExecResource clears it }
  PreExecuteDialog: procedure(D: PView) = nil;

implementation

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
  inherited Init;
  if StatusLine <> nil then
    Insert(StatusLine);
  if MenuBar <> nil then
    Insert(MenuBar);
end;

procedure TProgram.ActivateView(P: PView);
begin
  if P <> nil then
    P^.Select;
end;

procedure TProgram.InsertAvIdlerN(const Data; N: Integer);
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

procedure TProgram.Idle;
begin
  inherited Idle;
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

procedure OpenResource;
begin
  { TODO: resources }
end;

function ExecResource(Key: TDlgIdx; var Data): Word;
begin
  PreExecuteDialog := nil;
  Result := cmCancel;             { TODO: resources }
end;

function ExecDialog(D: PDialog; var Data): Word;
begin
  Result := Application^.ExecuteDialog(D, @Data);
end;

function LoadResource(Key: TDlgIdx): PObject;
begin
  Result := nil;                  { TODO: resources }
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

function GetString(Index: TStrIdx): String;
begin
  if LStringList <> nil then
    Result := LStringList^.Get(Word(Ord(Index)))
  else
    Result := '';
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

initialization
  CommandHiddenHook := @CommandHidden;
end.
