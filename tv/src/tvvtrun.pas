{ TvVtRun: runs a program on the whole screen of the application with an emulator in between, and keeps what the program drew: the screen of the user (PLAN.md item 8.4).
  While the program runs, the screen of the application is replaced by the screen of the emulator, the keys and the mouse go to the program; when it ends the caller
  redraws its application (the screen is cleared and the size is read again). The emulator stays with the caller: the next program continues on the same screen, and
  VtShowScreen shows it again (the key Ctrl-O of Norton-like programs).

  Written for this port (the original has no such thing: tvterm runs in a window); the parts are TvVt (the screen), TvPty (the program), TvVtKeys (the keys). Linux only. }
unit TvVtRun;

{$I tvdefs.inc}

interface

{$IFDEF LINUX}
uses
  TvVt;

{ Runs Prog (Args[0] is its name for itself) in the directory Cwd ('' = the current one) on the screen of the application; the text Echo (if not empty) is written to
  the emulator before the program starts (the command line, like the prompt of a shell). Pause: 0 goes back at once, 1 shows "Press Enter" after the program ended and waits for Enter, 2 does it only when the status is not 0. Emu is made (the size of the screen) when it is not yet (a zeroed variable: Cols = 0). Result: the exit status of the program, -1 when it could not be started. }
function VtRunScreen(var Emu: TVtEmu; const Prog: AnsiString; const Args: array of AnsiString; const Cwd, Echo: AnsiString; Pause: Integer): Integer;

{ Shows the screen of Emu until a key is pressed. }
procedure VtShowScreen(var Emu: TVtEmu);
{$ENDIF}

implementation

{$IFDEF LINUX}
uses
  TvGeom, TvCell, TvEvents, TvKeys, TvSys, TvScreen, TvViews, TvPty, TvVtKeys;

procedure FitEmu(var Emu: TVtEmu);
begin
  if (ScreenWidth > 0) and ((Emu.Cols <> ScreenWidth) or (Emu.RowCount <> ScreenHeight)) then
    Emu.Resize(ScreenWidth, ScreenHeight);
end;

procedure Blit(var Emu: TVtEmu; All: Boolean);
var
  X, Y, W: Integer;
begin
  W := ScreenWidth;
  if (ScreenBuffer = nil) or (W <= 0) then
    Exit;
  for Y := 0 to ScreenHeight - 1 do
    if All or Emu.RowDirty(Y) then
    begin
      for X := 0 to W - 1 do
        ScreenBuffer[Y * W + X] := Emu.CellAt(X, Y);
      ScreenWrite(0, Y, @ScreenBuffer[Y * W], W);
    end;
  Emu.ClearDirty;
  if Emu.CursorVisible then
  begin
    SetCaretPosition(Emu.CursorX, Emu.CursorY);
    SetCaretSize(15);
  end
  else
    SetCaretSize(0);
end;

procedure ScreenAgain;
begin
  if Assigned(OnSetVideoMode) then
    OnSetVideoMode(smUpdate);
end;

function VtRunScreen(var Emu: TVtEmu; const Prog: AnsiString; const Args: array of AnsiString; const Cwd, Echo: AnsiString; Pause: Integer): Integer;
var
  Pty: TPty;
  Buf: array[0..8191] of Byte;
  Ev: TEvent;
  N, Total: Integer;
  S: AnsiString;
  Over, PasteOpen, All: Boolean;
  P: TPoint;
  B: Integer;

  procedure Send(const T: AnsiString);
  begin
    if (T <> '') and not Over then
      Pty.Write(T[1], Length(T));
  end;

begin
  if Emu.Cols = 0 then
    Emu.Init(ScreenWidth, ScreenHeight, 2000);
  FitEmu(Emu);
  if Echo <> '' then
    Emu.Feed(Echo + #13#10);
  if not Pty.Open(Emu.Cols, Emu.RowCount, Prog, Args, Cwd) then
    Exit(-1);
  Over := False;
  PasteOpen := False;
  All := True;
  repeat
    { what the program wrote }
    Total := 0;
    repeat
      N := Pty.Read(Buf, SizeOf(Buf));
      if N < 0 then
      begin
        Over := True;
        Break;
      end;
      if N > 0 then
      begin
        Emu.Feed(@Buf[0], N);
        Inc(Total, N);
      end;
    until (N = 0) or (Total >= 65536);
    S := Emu.TakeReply;
    Send(S);
    Blit(Emu, All);
    All := False;
    if Over then
      Break;
    { what the user does }
    PollEvent(20, Ev);
    case Ev.What of
      evKeyDown:
        begin
          if (Ev.ControlKeyState and kbPaste) <> 0 then
          begin
            if Emu.BracketedPaste and not PasteOpen then
            begin
              PasteOpen := True;
              Send(#27'[200~');
            end;
          end
          else if PasteOpen then
          begin
            PasteOpen := False;
            Send(#27'[201~');
          end;
          Send(VtKeyBytes(Ev, Emu.AppCursor));
        end;
      evMouseDown, evMouseUp, evMouseMove, evMouseAuto, evMouseWheel:
        if Emu.MouseMode <> 0 then
        begin
          P := Ev.Where;
          B := -1;
          if (Ev.Buttons and mbLeftButton) <> 0 then B := 0
          else if (Ev.Buttons and mbMiddleButton) <> 0 then B := 1
          else if (Ev.Buttons and mbRightButton) <> 0 then B := 2;
          case Ev.What of
            evMouseDown, evMouseAuto: Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, True, False, 0, Ev.ControlKeyState));
            evMouseUp: Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, False, False, 0, Ev.ControlKeyState));
            evMouseMove: Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, B, False, True, 0, Ev.ControlKeyState));
            evMouseWheel:
              if (Ev.Wheel and mwUp) <> 0 then
                Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 1, Ev.ControlKeyState))
              else if (Ev.Wheel and mwDown) <> 0 then
                Send(VtMouseBytes(Emu.MouseMode, Emu.MouseEnc, P.X, P.Y, 0, True, False, 2, Ev.ControlKeyState));
          end;
        end;
      evCommand:
        if Ev.Command = cmScreenChanged then
        begin
          ScreenAgain;
          FitEmu(Emu);
          Pty.Resize(Emu.Cols, Emu.RowCount);
          All := True;
        end;
      evNothing:
        if PasteOpen then
        begin
          PasteOpen := False;
          Send(#27'[201~');
        end;
    end;
  until False;
  Pty.Wait(True);
  Result := Pty.ExitStatus;
  Pty.Close;
  if (Pause = 1) or ((Pause = 2) and (Result <> 0)) then
  begin
    Emu.Feed(#13#10#27'[7m [ Process ended (' + Chr(48 + (Result div 100) mod 10) + Chr(48 + (Result div 10) mod 10) + Chr(48 + Result mod 10) +
      '): Press Enter ] '#27'[0m');
    Blit(Emu, False);
    repeat
      PollEvent(100, Ev);
      if Ev.What = evCommand then
        if Ev.Command = cmScreenChanged then
        begin
          ScreenAgain;
          FitEmu(Emu);
          Blit(Emu, True);
        end;
    until (Ev.What = evKeyDown) and ((Ev.KeyCode = kbEnter) or (Ev.KeyCode = kbEsc));
  end;
  SetCaretSize(0);
  ScreenAgain;                                { the caller redraws everything }
end;

procedure VtShowScreen(var Emu: TVtEmu);
var
  Ev: TEvent;
begin
  if Emu.Cols = 0 then
    Exit;
  FitEmu(Emu);
  Blit(Emu, True);
  repeat
    PollEvent(100, Ev);
    if (Ev.What = evCommand) and (Ev.Command = cmScreenChanged) then
    begin
      ScreenAgain;
      FitEmu(Emu);
      Blit(Emu, True);
    end;
  until (Ev.What = evKeyDown) or (Ev.What = evMouseDown);
  SetCaretSize(0);
  ScreenAgain;
end;
{$ENDIF}

end.
