{ DosHarness: the test aid of the DOS build (DNDUMP, DNKEYS, DNMOUSE: see below and tools/dn-dos-input.py), taken out of mainapp (platform separation, stage 3).
  The code is the same; it is called from TProgram.Idle of mainapp.
  MIT, see LICENSE. }
{$mode objfpc}{$H-}{$POINTERMATH ON}
unit DosHarness;

interface

procedure CheckScreenDump;

implementation

uses
  SysUtils, TvInput, TvGeom, TvObjs, TvEvents, TvViews, TvWindow, TvDialog, TvApp, TvScreen, TvCell, Menus, Views, Drivers, Commands, mainapp, DNErrLog
{$IFDEF GO32V2}, TvDos, go32{$ENDIF};

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
    Ev.Mouse.Buttons := mbLeftButton;
    if (Entry <> '') and (Entry[1] = 'R') then
    begin
      Ev.Mouse.Buttons := mbRightButton;
      Delete(Entry, 1, 1);
    end;
    if Copy(Entry, 1, 2) = 'DD' then
    begin
      Ev.Mouse.EventFlags := meDoubleClick;
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
    Ev.Mouse.Where.X := StrToIntDef(Copy(Entry, 1, I - 1), 0);
    Ev.Mouse.Where.Y := StrToIntDef(Copy(Entry, I + 1, 9), 0);
    Application.PutEvent(Ev);
    DNTrace('mouse event ' + IntToHex(Ev.What, 2) + ' at ' + IntToStr(Ev.Mouse.Where.X) + ',' + IntToStr(Ev.Mouse.Where.Y));
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
    if TvScreen.TScreen.ScreenBuffer <> nil then
      for I := 0 to ScreenWidth * ScreenHeight - 1 do
        if not (PByte(TvScreen.TScreen.ScreenBuffer)[I * SizeOf(TScreenCell)] in [0, 32]) then
          Inc(N);
    DNTrace('dump: screen ' + IntToStr(ScreenWidth) + 'x' + IntToStr(ScreenHeight) + ', non-blank cells in the buffer: ' + IntToStr(N) +
      ', hook set: ' + BoolToStr(Assigned(OnScreenWrite), True) + ', locks: app ' + IntToStr(Application.LockFlag) + ' desktop ' +
      IntToStr(Desktop.LockFlag) + ', app buffer = screen: ' + BoolToStr(Application.Buffer = TvScreen.TScreen.ScreenBuffer, True));
    { the help context decides what the status line shows }
    DNTrace('mouse driver: ' + BoolToStr(DosMousePresent, True));
    DNTrace('idle calls: ' + IntToStr(IdleCount) + ' shift state ' + IntToHex(ShiftState, 2) + ' ' + IntToHex(ShiftState2, 2) + ' old ' + IntToHex(OldShiftState, 2));
    DNTrace('help ctx: app ' + IntToStr(Application.GetHelpCtx) + ' desktop ' + IntToStr(Desktop.GetHelpCtx) + ' status ' +
      IntToStr(StatusLine.HelpCtx) + ' topview ' + IntToHex(PtrUInt(StatusLine.TopView), 8) + ' app ' + IntToHex(PtrUInt(Application), 8) +
      ' current ' + IntToHex(PtrUInt(Application.Current), 8) + ' desktop.current ' + IntToHex(PtrUInt(Desktop.Current), 8));
    { the focused control of the window on top of the desktop, if that is a group (a test aid; the top view may be a menu, which
      is not a group: the access violation is taken, the trace must not kill the program) }
    try
      if (Desktop.Current <> nil) and (TGroup(Desktop.Current).Current <> nil) then
        begin
          TraceView(TGroup(Desktop.Current).Current);
          if TGroup(Desktop.Current).Current.Size.Y = 1 then
            DNTrace('as input line: maxlen ' + IntToStr(TInputLine(TGroup(Desktop.Current).Current).MaxLen) + ' curpos ' + IntToStr(TInputLine(TGroup(Desktop.Current).Current).CurPos) + ' data [' + TInputLine(TGroup(Desktop.Current).Current).Data^ + ']');
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

end.
