program t_input;
{$I ../src/tvdefs.inc}
uses TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvClip, TvMem, TvApp,
  TvDialog, TvValid, TvInput;
{$I testlib.inc}

function R(A, B, C, D: Integer): TRect;
begin
  Result.Assign(A, B, C, D);
end;

procedure Key(L: PInputLine; Code: Word; Mods: Word = 0);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, Mods);
  L^.HandleEvent(E);
end;

procedure TypeS(L: PInputLine; const S: ShortString);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    Key(L, Ord(S[I]));
end;

procedure Cmd(L: PInputLine; C: Word);
var
  E: TEvent;
begin
  ClearEvent(E);
  E.What := evCommand;
  E.Command := C;
  L^.HandleEvent(E);
end;

{ the main block keeps temporaries of string conversions until the end: compare in a function }
function ClipIs(const S: ShortString): Boolean;
begin
  Result := ClipboardGetText = S;
end;

var
  App: PApplication;
  Dlg: PDialog;
  L, L2: PInputLine;
  Rec: string[20];
  Big: array[0..4] of Byte;
  Used0: PtrUInt;
  S: ShortString;
  E: TEvent;
  Res: Word;

begin
  CpSelect(866);             { lazily allocates the code page tables: not a leak }
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init(R(10, 5, 60, 14), 'Input'));
  New(L, Init(R(2, 2, 22, 3), 20));
  Dlg^.Insert(L);
  New(L2, Init(R(2, 5, 12, 6), 3));
  Dlg^.Insert(L2);
  Dlg^.SelectNext(False);
  App^.InsertWindow(Dlg);

  Check((L^.MaxLen = 20) and (L^.Data^ = '') and (L^.CurPos = 0), 'a new line is empty');
  Check((L^.Options and (ofSelectable or ofFirstClick)) = (ofSelectable or ofFirstClick), 'options');
  Check((L^.State and sfCursorVis) <> 0, 'the cursor is visible');
  Check(L^.GetState(sfSelected), 'the first line is selected');

  { typing }
  TypeS(L, 'hello');
  Check((L^.Data^ = 'hello') and (L^.CurPos = 5), 'typing adds text at the cursor');
  Check(MemText(8, 12, 18) = ' hello ', 'and shows it (a blank before the text)');
  Key(L, kbHome);
  Check(L^.CurPos = 0, 'Home');
  Key(L, kbRight);
  Key(L, kbRight);
  Check(L^.CurPos = 2, 'Right');
  TypeS(L, 'X');
  Check((L^.Data^ = 'heXllo') and (L^.CurPos = 3), 'typing inserts');
  Key(L, kbLeft);
  Check(L^.CurPos = 2, 'Left');
  Key(L, kbEnd);
  Check(L^.CurPos = 6, 'End');
  Key(L, kbBack);
  Check((L^.Data^ = 'heXll') and (L^.CurPos = 5), 'Backspace');
  Key(L, kbHome);
  Key(L, kbDel);
  Check((L^.Data^ = 'eXll') and (L^.CurPos = 0), 'Del');
  Key(L, kbBack);
  Check(L^.Data^ = 'eXll', 'Backspace at the start does nothing');
  Key(L, kbEnd);
  Key(L, kbIns);
  Check((L^.State and sfCursorIns) <> 0, 'Ins: overwrite mode');
  Key(L, kbHome);
  TypeS(L, 'Q');
  Check(L^.Data^ = 'QXll', 'typing replaces the character at the cursor');
  Key(L, kbIns);
  Check((L^.State and sfCursorIns) = 0, 'Ins again: insert mode');

  { selection }
  Key(L, kbEnd);
  Key(L, kbLeft, kbShift);
  Key(L, kbLeft, kbShift);
  Check((L^.SelStart = 2) and (L^.SelEnd = 4), 'Shift+Left selects');
  Key(L, kbRight, kbShift);
  Check((L^.SelStart = 3) and (L^.SelEnd = 4), 'Shift+Right shrinks it');
  Key(L, kbLeft, kbShift);
  Key(L, kbDel);
  Check((L^.Data^ = 'QX') and (L^.CurPos = 2), 'Del deletes the selection');
  Key(L, kbRight);
  Check((L^.SelStart = 0) and (L^.SelEnd = 0), 'a move without Shift drops the selection');
  { Ctrl+Y clears }
  Key(L, $0019);
  Check((L^.Data^ = '') and (L^.CurPos = 0), 'Ctrl+Y clears the line');
  { words }
  TypeS(L, 'one two  three');
  Key(L, kbHome);
  Key(L, kbCtrlRight);
  Check(L^.CurPos = 4, 'Ctrl+Right: the next word');
  Key(L, kbCtrlRight);
  Check(L^.CurPos = 9, 'Ctrl+Right again');
  Key(L, kbCtrlLeft);
  Check(L^.CurPos = 4, 'Ctrl+Left: the previous word');
  Key(L, kbCtrlDel);
  Check(L^.Data^ = 'one three', 'Ctrl+Del deletes the word');
  Key(L, kbEnd);
  Key(L, kbCtrlBack);
  Check(L^.Data^ = 'one ', 'Ctrl+Backspace deletes the word before the cursor');

  { limit }
  L2^.Select;
  TypeS(L2, 'abcdef');
  Check(L2^.Data^ = 'abc', 'the limit: more characters are not taken');
  L^.Select;
  Key(L, $0001);
  Check(L^.Data^ = 'one ', 'other control keys are ignored');

  { SetData and GetData }
  Rec := 'from record';
  L^.SetData(Rec);
  Check((L^.Data^ = 'from record') and (L^.SelStart = 0) and (L^.SelEnd = 11), 'SetData selects all');
  Rec := '';
  L^.GetData(Rec);
  Check(Rec = 'from record', 'GetData');
  Check(L^.DataSize = 21, 'DataSize is MaxLen + 1');
  TypeS(L, 'N');
  Check(L^.Data^ = 'N', 'typing over a selection replaces it');

  { clipboard }
  ClipboardSetText('');
  L^.SelectAll(True);
  Cmd(L, cmCopy);
  Check(ClipIs('N'), 'cmCopy puts the selection into the clipboard');
  Key(L, kbEnd);
  Cmd(L, cmPaste);
  Check(L^.Data^ = 'NN', 'cmPaste inserts the clipboard text');
  ClipboardSetText('line one'#13#10'line two');
  Cmd(L, cmPaste);
  Check(L^.Data^ = 'NNline one', 'paste takes the first line only');
  L^.SelectAll(True);
  Cmd(L, cmCut);
  Check((L^.Data^ = '') and (ClipIs('NNline one')), 'cmCut removes the selection and copies it');
  Check(CommandEnabled(cmPaste), 'paste is enabled while a line is active');

  { an OEM line }
  InputLineOem := True;
  L^.SelectAll(True);
  MakeKeyEvent(E, $0000, 0);
  E.Text[0] := #$D0; E.Text[1] := #$96; E.TextLength := 2;      { Ж in UTF-8 }
  L^.HandleEvent(E);
  Check((Length(L^.Data^) = 1) and (L^.Data^[1] = #$86), 'an OEM line keeps one byte of CP866 for a typed letter');
  L^.SelectAll(True);
  Cmd(L, cmCopy);
  Check(ClipIs('Ж'), 'and gives UTF-8 to the clipboard');
  Cmd(L, cmPaste);
  Check(L^.Data^ = #$86, 'paste converts back to the byte');
  InputLineOem := False;

  { scrolling in a narrow line }
  L2^.Data^ := '';
  L2^.CurPos := 0;
  L2^.FirstPos := 0;
  Dispose(L2, Done);
  New(L2, Init(R(2, 5, 12, 6), 40));
  Dlg^.Insert(L2);
  L2^.Select;
  TypeS(L2, '0123456789ABCDEF');
  Check(L2^.FirstPos = 16 - 10 + 2, 'the line scrolls to keep the cursor visible');
  Check(MemChar(12 + 0, 11) = '◄', 'the left arrow shows that text is hidden on the left');
  Key(L2, kbHome);
  Check(L2^.FirstPos = 0, 'Home scrolls back');
  Check(MemChar(12 + 9, 11) = '►', 'the right arrow shows that text is hidden on the right');

  { validators }
  L^.Select;
  L^.SetValidator(New(PFilterValidator, Init('0123456789')));
  L^.Data^ := '';
  L^.CurPos := 0;
  TypeS(L, '12a3');
  Check(L^.Data^ = '123', 'a filter validator rejects the letter');
  Check(L^.Valid(cmOK), 'a valid text');
  L^.SetValidator(New(PRangeValidator, Init(1, 10)));
  L^.Data^ := '50';
  MemClear;
  MemKey(kbEnter);
  Check(not L^.Valid(cmOK), 'a value out of range is not valid (a message box is shown)');
  Check(L^.Valid(cmCancel), 'but Cancel is always valid');
  Check(L^.Valid(cmValid), 'the validator is syntactically ok');
  L^.SetValidator(nil);

  { the mouse: a click places the cursor, a drag selects }
  L^.Data^ := 'abcdefghij';
  L^.CurPos := 0;
  L^.FirstPos := 0;
  MemClear;
  MemMouse(evMouseUp, 15, 8);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 15;           { column 3 of the line, the text starts at column 1 }
  E.Where.Y := 8;
  E.Buttons := mbLeftButton;
  L^.HandleEvent(E);
  Check(L^.CurPos = 2, 'a click puts the cursor at the character under it');
  MemClear;
  MemMouse(evMouseMove, 18, 8);
  MemMouse(evMouseUp, 18, 8);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 14;
  E.Where.Y := 8;
  E.Buttons := mbLeftButton;
  L^.HandleEvent(E);
  Check((L^.SelStart = 1) and (L^.SelEnd = 5), 'dragging selects');
  MemClear;
  MemMouse(evMouseUp, 15, 8);
  ClearEvent(E);
  E.What := evMouseDown;
  E.Where.X := 15;
  E.Where.Y := 8;
  E.Buttons := mbLeftButton;
  E.EventFlags := meDoubleClick;
  L^.HandleEvent(E);
  Check((L^.SelStart = 0) and (L^.SelEnd = 10), 'a double click selects all');

  { the extensions used by DN: edge characters and own colors }
  Check((L2^.LC = ' ') and (L2^.RC = ' ') and (L2^.C[1] = 0), 'DN extensions: the defaults change nothing');
  L2^.LC := #179;
  L2^.RC := #186;
  L2^.C[1] := $1E;
  L2^.DrawView;
  Check((MemChar(12, 11) <> ' ') and (MemChar(21, 11) <> ' ') and
    (MemChar(12, 11) <> MemChar(21, 11)), 'DN extensions: LC and RC are drawn at the edges');
  Check(MemAttr(15, 11) = $1E, 'DN extensions: C[1] is the color of a passive line');

  Dispose(Dlg, Done);

  { the input box }
  MemClear;
  S := 'xy';
  MemKey(Ord('z'));
  MemKey(kbEnter);
  Res := InputBox('Title', 'Name:', S, 20);
  Check((Res = cmOK) and (S = 'z'), 'InputBox: the text replaces the selected old one');
  MemClear;
  S := 'keep';
  MemKey(Ord('q'));
  MemKey(kbEsc);
  Res := InputBox('Title', 'Name:', S, 20);
  Check((Res = cmCancel) and (S = 'keep'), 'InputBox: Esc leaves the text');

  Dispose(App, Done);
  MemDone;
  ClipboardSetText('');      { the buffer of the clipboard is a global string }
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
