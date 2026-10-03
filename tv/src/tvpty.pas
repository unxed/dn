{ TvPty: a pseudo terminal and the program that runs on it (the part of the terminal view that talks to the system, PLAN.md item 8.2).
  Open starts the program (a shell) with its input and output on the slave side of a new pty; Read and Write move the bytes of the master side (the program
  writes into Read, what the user types goes into Write); Resize tells the program the new size (SIGWINCH); Wait finds out that the program has ended.

  Written for this port (the original has pty.cc for this, with forkpty); only Linux for now: the pty is opened through /dev/ptmx and ioctl (no libc, so the static
  build works). Other Unix systems (BSD, macOS) need posix_openpt and other numbers of ioctl: PLAN.md item 8.2. }
unit TvPty;

{$I tvdefs.inc}

interface

{$IFDEF LINUX}
uses
  BaseUnix, termio, Strings;

type
  TPty = object
    Master: cint;
    Pid: TPid;
    Running: Boolean;
    ExitStatus: Integer;               { the exit code of the program; 128 + the signal when it was killed }
    { Starts Prog with the arguments Args (Args[0] is the name of the program as it sees it) in the directory Cwd ('' = the current one) on a terminal
      of ACols x ARows. The environment is the one of the process with TERM=xterm-256color and COLORTERM=truecolor. False when no pty could be made;
      a program that cannot be started ends with the code 127. }
    function Open(ACols, ARows: Integer; const Prog: AnsiString; const Args: array of AnsiString; const Cwd: AnsiString): Boolean;
    { What the program has written: the number of bytes, 0 when there is nothing now, -1 when it is over (the program has closed the terminal). }
    function Read(var Buf; Size: Integer): Integer;
    { What the user types: all the bytes are written (waits while the program does not take them); False on an error. }
    function Write(const Buf; Size: Integer): Boolean;
    procedure Resize(ACols, ARows: Integer);
    { True when the program has ended (ExitStatus is set); Block waits for it. }
    function Wait(Block: Boolean): Boolean;
    { Ends the program (SIGHUP, then SIGKILL) and closes the pty. }
    procedure Close;
  end;
{$ENDIF}

implementation

{$IFDEF LINUX}
const
  TIOCSPTLCK_ = $40045431;
  TIOCGPTN_ = $80045430;

function TPty.Open(ACols, ARows: Integer; const Prog: AnsiString; const Args: array of AnsiString; const Cwd: AnsiString): Boolean;
var
  Unlock, N, I, J, Sfd: cint;
  Slave: AnsiString;
  WS: TWinSize;
  Argv, Env: array of PChar;
  Store: array of AnsiString;
  P: PPChar;
  Has: Boolean;
  Flags: cint;
begin
  Result := False;
  Running := False;
  ExitStatus := 0;
  Master := fpOpen('/dev/ptmx', O_RDWR or O_NOCTTY);
  if Master < 0 then
    Exit;
  Unlock := 0;
  N := 0;
  if (fpIoctl(Master, TIOCSPTLCK_, @Unlock) <> 0) or (fpIoctl(Master, TIOCGPTN_, @N) <> 0) then
  begin
    fpClose(Master);
    Exit;
  end;
  Str(N, Slave);
  Slave := '/dev/pts/' + Slave;
  FillChar(WS, SizeOf(WS), 0);
  WS.ws_col := ACols;
  WS.ws_row := ARows;
  fpIoctl(Master, TIOCSWINSZ, @WS);
  { the arguments and the environment are made before the fork: the child only calls the system }
  SetLength(Argv, Length(Args) + 1);
  for I := 0 to High(Args) do
    Argv[I] := PChar(Args[I]);
  Argv[High(Argv)] := nil;
  SetLength(Store, 2);
  Store[0] := 'TERM=xterm-256color';
  Store[1] := 'COLORTERM=truecolor';
  SetLength(Env, 0);
  P := envp;
  while (P <> nil) and (P^ <> nil) do
  begin
    Has := (StrLComp(P^, 'TERM=', 5) = 0) or (StrLComp(P^, 'COLORTERM=', 10) = 0);
    if not Has then
    begin
      SetLength(Env, Length(Env) + 1);
      Env[High(Env)] := P^;
    end;
    Inc(P);
  end;
  for I := 0 to 1 do
  begin
    SetLength(Env, Length(Env) + 1);
    Env[High(Env)] := PChar(Store[I]);
  end;
  SetLength(Env, Length(Env) + 1);
  Env[High(Env)] := nil;
  Pid := fpFork;
  if Pid < 0 then
  begin
    fpClose(Master);
    Exit;
  end;
  if Pid = 0 then
  begin
    { the child: its own session, the slave as the controlling terminal and as 0, 1, 2 }
    fpSetsid;
    Sfd := fpOpen(PChar(Slave), O_RDWR);
    if Sfd < 0 then
      fpExit(127);
    fpIoctl(Sfd, TIOCSCTTY, Pointer(0));
    fpDup2(Sfd, 0);
    fpDup2(Sfd, 1);
    fpDup2(Sfd, 2);
    if Sfd > 2 then
      fpClose(Sfd);
    fpClose(Master);
    if Cwd <> '' then
      fpChdir(PChar(Cwd));
    fpExecve(PChar(Prog), @Argv[0], @Env[0]);
    fpExit(127);
  end;
  J := 0;
  Flags := fpFcntl(Master, F_GETFL);
  fpFcntl(Master, F_SETFL, Flags or O_NONBLOCK);
  Running := True;
  Result := True;
end;

function TPty.Read(var Buf; Size: Integer): Integer;
var
  R: ssize_t;
begin
  R := fpRead(Master, Buf, Size);
  if R > 0 then
    Exit(R);
  if R = 0 then
    Exit(-1);
  if (fpgeterrno = ESysEAGAIN) or (fpgeterrno = ESysEINTR) then
    Exit(0);
  Result := -1;                          { EIO: the program has closed its side }
end;

function TPty.Write(const Buf; Size: Integer): Boolean;
var
  P: PByte;
  R: ssize_t;
  Fds: TFDSet;
begin
  P := @Buf;
  while Size > 0 do
  begin
    R := fpWrite(Master, P^, Size);
    if R > 0 then
    begin
      Inc(P, R);
      Dec(Size, R);
    end
    else if (R < 0) and ((fpgeterrno = ESysEAGAIN) or (fpgeterrno = ESysEINTR)) then
    begin
      fpFD_ZERO(Fds);
      fpFD_SET(Master, Fds);
      fpSelect(Master + 1, nil, @Fds, nil, 50);
    end
    else
      Exit(False);
  end;
  Result := True;
end;

procedure TPty.Resize(ACols, ARows: Integer);
var
  WS: TWinSize;
begin
  if Master < 0 then
    Exit;
  FillChar(WS, SizeOf(WS), 0);
  WS.ws_col := ACols;
  WS.ws_row := ARows;
  fpIoctl(Master, TIOCSWINSZ, @WS);       { the kernel sends SIGWINCH to the foreground group of the terminal }
end;

function TPty.Wait(Block: Boolean): Boolean;
var
  St: cint;
  R: TPid;
begin
  if not Running then
    Exit(True);
  if Block then
    R := fpWaitPid(Pid, @St, 0)
  else
    R := fpWaitPid(Pid, @St, WNOHANG);
  if R <> Pid then
    Exit(False);
  Running := False;
  if wifexited(St) then
    ExitStatus := wexitstatus(St)
  else
    ExitStatus := 128 + wtermsig(St);
  Result := True;
end;

procedure TPty.Close;
var
  I: Integer;
begin
  if Master >= 0 then
  begin
    fpClose(Master);                     { the program gets SIGHUP: its terminal is gone }
    Master := -1;
  end;
  if Running then
  begin
    fpKill(Pid, SIGHUP);
    for I := 1 to 40 do
    begin
      if Wait(False) then
        Exit;
      fpSelect(0, nil, nil, nil, 25);
    end;
    fpKill(Pid, SIGKILL);
    Wait(True);
  end;
end;
{$ENDIF}

end.
