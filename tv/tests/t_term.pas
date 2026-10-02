program t_term;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem, TvApp,
  TvWindow, TvTextView;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

var
  App: PApplication;
  Win: PWindow;
  Term: PTerminal;
  Small: PTerminal;
  Used0: PtrUInt;
  T: Text;
  I: Integer;
  S: ShortString;

{ the text of the row Y of the terminal (the window is at 0,2 on the screen; the interior starts at 1,3) }
function Row(Y: Integer): ShortString;
begin
  Result := MemText(3 + Y, 1, 20);
  while (Result <> '') and (Result[Length(Result)] = ' ') do
    SetLength(Result, Length(Result) - 1);
end;

procedure Run;
begin
  MemInit(80, 25);
  New(App, Init);
  New(Win, Init(R(0, 1, 30, 9), 'Terminal', 1));
  New(Term, Init(R(1, 1, 29, 7), Win^.StandardScrollBar(sbHorizontal or sbHandleKeyboard),
    Win^.StandardScrollBar(sbVertical or sbHandleKeyboard), 1000));
  Win^.Insert(Term);
  App^.InsertWindow(Win);

  Check(Term^.QueEmpty, 'a new terminal is empty');
  Check(Term^.GrowMode = (gfGrowHiX + gfGrowHiY), 'grow mode');
  Check((Term^.Limit.X = 0) and (Term^.Limit.Y = 1), 'the limit is one line');

  Term^.PutStr('hello');
  Check(not Term^.QueEmpty, 'text is in the buffer');
  Check(Row(0) = 'hello', 'text without a line end is shown');
  Check((Term^.Cursor.X = 5) and (Term^.Cursor.Y = 0), 'the cursor is after the text');
  Term^.PutLine(' world');
  Check(Row(0) = 'hello world', 'text goes on in the line');
  Check(Term^.Limit.Y = 2, 'and a line end adds a line');
  Check((Term^.Cursor.X = 0) and (Term^.Cursor.Y = 1), 'the cursor is on the new line');
  Term^.PutStr('line2');
  Check((Row(0) = 'hello world') and (Row(1) = 'line2'), 'two lines');
  Check(Row(2) = '', 'the rest is empty');

  { more lines than the height of the window }
  for I := 3 to 10 do
  begin
    Str(I, S);
    Term^.PutLine(' ' + S);
  end;
  Check(Term^.Limit.Y = 10, 'ten lines');
  Check(Row(0) <> 'hello world', 'the first line is scrolled away');
  Check((Row(0) = ' 6') and (Row(4) = ' 10'), 'the last lines are shown');
  Check(Row(5) = '', 'the last (empty) line is the cursor line');

  { UTF-8 text }
  Term^.PutStr(#$D0#$96'!');
  Check(Row(5) = #$D0#$96'!', 'UTF-8 text is shown');
  Term^.PutChar(#10);

  { Pascal Write into the device }
  AssignDevice(T, Term);
  Rewrite(T);
  WriteLn(T, 'from', ' Pascal ', 42);
  Close(T);
  Check(Row(4) = 'from Pascal 42', 'Write(T) goes into the terminal');
  Check(Row(5) = '', 'WriteLn ends the line without a carriage return');

  { a small buffer drops the oldest lines }
  New(Small, Init(R(1, 1, 29, 7), nil, nil, 40));
  Win^.Insert(Small);
  Small^.Select;
  for I := 1 to 8 do
  begin
    Str(I, S);
    Small^.PutLine('line ' + S);
  end;
  Check(Small^.Limit.Y <= 6, 'the old lines are dropped (the buffer holds about 5 lines of 7 bytes)');
  Check(Small^.CanInsert(0), 'CanInsert');
  S := '';
  for I := 1 to 100 do
    S := S + 'x';
  Small^.PutStr(S);
  Check(not Small^.QueEmpty, 'a text longer than the buffer keeps its end');
  Check(Row(Small^.Limit.Y - 1) <> '', 'and shows it');

  Dispose(App, Done);
  MemDone;
end;

begin
  Quiet := True;
  Run;
  Quiet := False;
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  Run;
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
