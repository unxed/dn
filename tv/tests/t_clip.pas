program t_clip;
{$I ../src/tvdefs.inc}
uses TvCodePg, TvClip;
{$I testlib.inc}

var
  Stored: AnsiString;
  SysHas: Boolean;
  Fail: Boolean;
  Got: AnsiString;

function FakeSet(const Text: AnsiString): Boolean;
begin
  Result := not Fail;
  if Result then
  begin
    Stored := Text;
    SysHas := True;
  end;
end;

function FakeGet(out Text: AnsiString): Boolean;
begin
  Text := Stored;
  Result := SysHas;
end;

begin
  CpSelect(866);

  { without a system clipboard: the internal buffer }
  Check(ClipboardGetText = '', 'empty at the start');
  ClipboardSetText('hello');
  Check(ClipboardGetText = 'hello', 'the internal buffer keeps the text');
  Check(not ClipboardIsSystem, 'and it did not reach a system clipboard');

  { with a system clipboard }
  OnClipboardSet := @FakeSet;
  OnClipboardGet := @FakeGet;
  Stored := ''; SysHas := False; Fail := False;
  ClipboardSetText('Привет');
  Check(Stored = 'Привет', 'the text goes to the system clipboard');
  Check(ClipboardIsSystem, 'which is known');
  Check(ClipboardGetText = 'Привет', 'and comes back from it');
  Stored := 'from another program';
  Check(ClipboardGetText = 'from another program', 'the system clipboard has priority');
  Stored := '';
  Check(ClipboardGetText = 'Привет', 'an empty system clipboard: the internal buffer');
  Fail := True;
  ClipboardSetText('local only');
  Check(not ClipboardIsSystem, 'a failed system set is known');
  Check(ClipboardGetText = 'local only', 'the internal buffer still has the text');
  OnClipboardSet := nil;
  OnClipboardGet := nil;

  { conversions }
  Check(Utf8ToOem('abc') = 'abc', 'ASCII is not changed');
  Check(Utf8ToOem('Жук') = #$86#$E3#$AA, 'UTF-8 to CP866');
  Check(Utf8ToOem('a€b') = 'a?b', 'a character the page has not: ?');
  Check(Utf8ToOem(#$86) = #$86, 'a byte that is not UTF-8 is a character of the page already');
  Check(OemToUtf8(#$86#$E3#$AA) = 'Жук', 'CP866 to UTF-8');
  Check(OemToUtf8('x'#$C4'y') = 'x─y', 'a line drawing character');
  Check(OemToUtf8(Utf8ToOem('Привет, мир!')) = 'Привет, мир!', 'round trip');
  CpSelect(437);
  Check(Utf8ToOem('é') = #$82, 'CP437: e acute');
  Check(Utf8ToOem('Ж') = '?', 'CP437 has no Cyrillic');
  CpSelect(866);

  Check(ToCrLf('a'#10'b') = 'a'#13#10'b', 'LF to CR LF');
  Check(ToCrLf('a'#13#10'b') = 'a'#13#10'b', 'CR LF stays');
  Check(ToCrLf('a'#13'b') = 'a'#13#10'b', 'a lone CR');
  Check(ToCrLf('a'#10#10'b') = 'a'#13#10#13#10'b', 'empty lines');
  Check(ToCrLf('') = '', 'empty text');
  Check(ToLf('a'#13#10'b'#13'c'#10'd') = 'a'#10'b'#10'c'#10'd', 'every break to LF');
  Check(ToLf(ToCrLf('x'#10'y')) = 'x'#10'y', 'round trip of line breaks');
  Check(Base64Encode('') = '', 'base64: empty');
  Check(Base64Encode('f') = 'Zg==', 'base64: one byte');
  Check(Base64Encode('fo') = 'Zm8=', 'base64: two bytes');
  Check(Base64Encode('foo') = 'Zm9v', 'base64: three bytes');
  Check(Base64Encode('foobar') = 'Zm9vYmFy', 'base64: six bytes');
  Finish;
end.
