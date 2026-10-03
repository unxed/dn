program t_pty;
{$I ../src/tvdefs.inc}
uses
{$IFDEF LINUX}
  BaseUnix, TvPty, TvVt,
{$ENDIF}
  SysUtils;
{$I testlib.inc}

{$IFDEF LINUX}
var
  Pty: TPty;
  E: TVtEmu;

function Send(const S: AnsiString): Boolean;
begin
  Result := Pty.Write(S[1], Length(S));
end;

{ everything that the program writes up to its end (or Limit tenths of a second) goes to the emulator; returns the raw bytes }
function Drain(Limit: Integer): AnsiString;
var
  Buf: array[0..4095] of Byte;
  N, T: Integer;
  S: AnsiString;
begin
  Result := '';
  T := 0;
  while T < Limit * 10 do
  begin
    N := Pty.Read(Buf, SizeOf(Buf));
    if N < 0 then
      Break;
    if N = 0 then
    begin
      fpSelect(0, nil, nil, nil, 10);
      Inc(T);
      Continue;
    end;
    SetLength(S, N);
    Move(Buf[0], S[1], N);
    Result := Result + S;
    E.Feed(S);
  end;
end;

{ the same until the text Want has come (or Limit tenths of a second) }
function DrainUntil(const Want: AnsiString; Limit: Integer): AnsiString;
var
  Buf: array[0..4095] of Byte;
  N, T: Integer;
  S: AnsiString;
begin
  Result := '';
  T := 0;
  while (T < Limit * 10) and (Pos(Want, Result) = 0) do
  begin
    N := Pty.Read(Buf, SizeOf(Buf));
    if N < 0 then
      Break;
    if N = 0 then
    begin
      fpSelect(0, nil, nil, nil, 10);
      Inc(T);
      Continue;
    end;
    SetLength(S, N);
    Move(Buf[0], S[1], N);
    Result := Result + S;
    E.Feed(S);
  end;
end;
{$ENDIF}

var
  Raw: AnsiString;
begin
{$IFDEF LINUX}
  { a program that writes and ends; the size of the terminal is the size that was asked for }
  E.Init(30, 7, 10);
  Check(Pty.Open(30, 7, '/bin/sh', ['sh', '-c', 'echo hi; stty size; exit 3'], ''), 'Open: the program is started');
  Raw := Drain(50);
  Check(Pty.Wait(True) and (Pty.ExitStatus = 3), 'Wait: the exit code is 3');
  Check((E.RowText(0) = 'hi') and (E.RowText(1) = '7 30'), 'Read: the output (hi and the size 7 30) reaches the emulator');
  Pty.Close;
  E.Done;

  { the input: the terminal echoes it, cat writes it back }
  E.Init(30, 7, 10);
  Check(Pty.Open(30, 7, '/bin/cat', ['cat'], ''), 'Open: cat');
  Check(Send('abc'#10), 'Write: the input');
  Raw := DrainUntil('abc'#13#10'abc', 30);
  Check(Pos('abc'#13#10'abc', Raw) > 0, 'the echo of the terminal and the output of cat');
  Check(Send(#4), 'Write: Ctrl-D');
  Drain(30);
  Check(Pty.Wait(True) and (Pty.ExitStatus = 0), 'cat ends at Ctrl-D with the code 0');
  Pty.Close;
  E.Done;

  { the size changes while the program works }
  E.Init(30, 7, 10);
  Check(Pty.Open(30, 7, '/bin/sh', ['sh', '-c', 'read x; stty size'], ''), 'Open: read and stty');
  Pty.Resize(40, 10);
  Send(#10);
  Raw := DrainUntil('10 40', 30);
  Check(Pos('10 40', Raw) > 0, 'Resize: the program sees the new size');
  Pty.Close;
  E.Done;

  { the directory and the environment }
  E.Init(30, 7, 10);
  Check(Pty.Open(30, 7, '/bin/sh', ['sh', '-c', 'pwd; echo $TERM $COLORTERM'], '/tmp'), 'Open: a directory');
  Raw := Drain(50);
  Check((Pos('/tmp', Raw) > 0) and (Pos('xterm-256color truecolor', Raw) > 0), 'the directory is the one that was asked, TERM and COLORTERM are set');
  Pty.Close;
  E.Done;

  { a program that is not there }
  E.Init(30, 7, 10);
  Check(Pty.Open(30, 7, '/no/such/program', ['x'], ''), 'Open: a program that is not there still starts a child');
  Drain(30);
  Check(Pty.Wait(True) and (Pty.ExitStatus = 127), 'the child ends with 127');
  Pty.Close;
  E.Done;

  { Close ends a program that works }
  E.Init(30, 7, 10);
  Check(Pty.Open(30, 7, '/bin/sleep', ['sleep', '30'], ''), 'Open: sleep');
  Pty.Close;
  Check(not Pty.Running, 'Close: the program that works is ended');
  E.Done;
{$ELSE}
  Check(True, 'not Linux: TvPty is Linux only for now');
{$ENDIF}
  Finish;
end.
