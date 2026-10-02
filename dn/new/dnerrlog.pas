{ A test aid: with the environment variable DNDUMP set, the error output (the runtime errors of the RTL: "Runtime error 216
  at $..." that DOS does not let a test redirect) goes to the file DNERR.TXT. It is the first unit of the program
  (edit 114), so that it works before the other units start. }
unit DNErrLog;

{$mode objfpc}{$POINTERMATH ON}

interface

{ A line of the trace of the start (test aid): written and flushed to DNERR.TXT when DNDUMP is set. }
procedure DNTrace(const Msg: String);
{ In an exception handler: the class, the message and the call stack of the exception with the lines of the sources (the
  program is built with -gl). }
procedure DNTraceException;

implementation

uses
  SysUtils{$IFDEF GO32V2}, Dos, go32{$ENDIF};

var
  Tracing: Boolean = False;
  { DNSERIAL is set: the trace goes also to COM1 (the emulator writes it to a file at once: DOSBox-X serial1=file
    file:NAME): the files of DOS are lost when the program dies, the serial port is not }
  UseSerial: Boolean = False;

procedure DNTrace(const Msg: String);
{$IFDEF GO32V2}
var
  I, J: Integer;
{$ENDIF}
begin
  if Tracing then
  begin
    Writeln(StdErr, Msg);
    Flush(StdErr);
{$IFDEF GO32V2}
    if UseSerial then
    begin
      for I := 1 to Length(Msg) + 1 do
      begin
        { wait for the transmitter holding register to become empty (bit 5 of the line status) }
        J := 0;
        while ((inportb($3FD) and $20) = 0) and (J < 100000) do
          Inc(J);
        if I <= Length(Msg) then
          outportb($3F8, Ord(Msg[I]))
        else
          outportb($3F8, 10);
      end;
    end;
{$ENDIF}
  end;
end;

procedure DNTraceException;
var
  I: Integer;
  Fr: PPointer;
begin
  if not Tracing then
    Exit;
  if ExceptObject <> nil then
    DNTrace('exception ' + ExceptObject.ClassName + ': ' + (ExceptObject as Exception).Message);
  DNTrace(BackTraceStrFunc(ExceptAddr));
  Fr := ExceptFrames;
  for I := 0 to ExceptFrameCount - 1 do
    DNTrace(BackTraceStrFunc(Fr[I]));
end;

initialization
  if GetEnvironmentVariable('DNDUMP') <> '' then
  begin
    Assign(StdErr, 'DNERR.TXT');
    Rewrite(StdErr);
    Tracing := True;
    UseSerial := GetEnvironmentVariable('DNSERIAL') <> '';
    DNTrace('errlog started');
  end;
end.
