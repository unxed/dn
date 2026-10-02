{ A test aid: with the environment variable DNDUMP set, the error output (the runtime errors of the RTL: "Runtime error 216
  at $..." that DOS does not let a test redirect) goes to the file DNERR.TXT. It is the first unit of the program
  (edit 114), so that it works before the other units start. }
unit DNErrLog;

{$mode objfpc}

interface

{ A line of the trace of the start (test aid): written and flushed to DNERR.TXT when DNDUMP is set. }
procedure DNTrace(const Msg: String);

implementation

uses
  SysUtils{$IFDEF GO32V2}, Dos{$ENDIF};

var
  Tracing: Boolean = False;

procedure DNTrace(const Msg: String);
{$IFDEF GO32V2}
var
  R: Registers;
{$ENDIF}
begin
  if Tracing then
  begin
    Writeln(StdErr, Msg);
    Flush(StdErr);

  end;
end;

initialization
  if GetEnvironmentVariable('DNDUMP') <> '' then
  begin
    Assign(StdErr, 'DNERR.TXT');
    Rewrite(StdErr);
    Tracing := True;
    DNTrace('errlog started');
  end;
end.
