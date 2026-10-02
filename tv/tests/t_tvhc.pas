{ The help compiler tvhc (tv/tools/tvhc.pas): the test builds it with fpc (the tool is a program, not a unit), compiles a text
  of a help and reads the file with THelpFile. Run in tv/tests (as the others). }
program t_tvhc;
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvObjs, TvHelp;
{$I testlib.inc}

const
  Htx = 't_tvhc.htx';
  Hlp = 't_tvhc.hlp';
  Bad = 't_tvhc_bad.htx';

procedure WriteText(const Name: string; const Lines: array of string);
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, Name);
  Rewrite(F);
  for I := 0 to High(Lines) do
    Writeln(F, Lines[I]);
  CloseFile(F);
end;

var
  Tool, Fpc: string;
  HF: PHelpFile;
  T: PHelpTopic;
  P: TPoint;
  L: Byte;
  Rf: Integer;
begin
  { the tool is built next to the test }
  ForceDirectories('tvhc-o');
  Fpc := ExeSearch('fpc', GetEnvironmentVariable('PATH'));
  if (Fpc = '') or (ExecuteProcess(Fpc, ['-Fu../src', '-FUtvhc-o', '-FEtvhc-o', '-vewn', '../tools/tvhc.pas']) <> 0) then
  begin
    Writeln('cannot build tvhc (is fpc in the path? cwd must be tv/tests)');
    Halt(1);
  end;
  Tool := ExpandFileName('tvhc-o/tvhc');

  WriteText(Htx, [
    '; a comment',
    '.topic First=1   ; a comment of the line',
    '.title The first',
    'See {the second:Second} and {Second}.',
    '',
    ' kept line one',
    ' kept line two',
    '',
    '.topic Second=300, Alias=301  {an author}',
    'A {:Second} {Third} that is not closed { here',
    '.topic Third',
    'The next number {{ ok.']);
  Check(ExecuteProcess(Tool, [Htx, Hlp, 't_tvhc.pas.inc', '/4DN_OSP']) = 0, 'a good text is compiled');

  RegisterType(RHelpTopic);
  RegisterType(RHelpIndex);
  HF := New(PHelpFile, Init(New(PBufStream, Init(Hlp, stOpenRead, 1024))));
  T := HF^.GetTopic(1);
  T^.SetWidth(40);
  Check(T^.GetLine(1) = 'See the second and Second.', 'topic 1: braces are cut: ' + T^.GetLine(1));
  Check(T^.GetNumCrossRefs = 2, 'topic 1 has two references');
  T^.GetCrossRef(0, P, L, Rf);
  Check((Rf = 300) and (L = 10) and (P.X = 4) and (P.Y = 1), 'the reference "the second:Second" leads to 300 (column 4, length 10)');
  T^.GetCrossRef(1, P, L, Rf);
  Check((Rf = 300) and (L = 6) and (P.X = 19), 'the reference "Second" leads to 300 (column 19, length 6)');
  Check(T^.GetLine(3) = ' kept line one', 'a paragraph with a blank first character is not wrapped');
  Check(T^.GetLine(4) = ' kept line two', '... and its next line');
  Dispose(T, Done);

  T := HF^.GetTopic(301);
  Check(T^.GetLine(1) = 'A  Third that is not closed { here', 'Alias is the same text, an unclosed brace is text: ' + T^.GetLine(1));
  Dispose(T, Done);
  T := HF^.GetTopic(302);
  Check(T^.GetLine(1) = 'The next number { ok.', 'a topic without a number gets the next one (302)');
  Dispose(T, Done);
  Dispose(HF, Done);

  WriteText(Bad, ['.topic A=1', 'a {b:Nowhere}']);
  Check(ExecuteProcess(Tool, [Bad, 't_tvhc_bad.hlp']) <> 0, 'a reference to a missing topic is an error');
  Check(not FileExists('t_tvhc_bad.hlp'), '... and no file is written');

  DeleteFile(Htx); DeleteFile(Hlp); DeleteFile(Bad); DeleteFile('t_tvhc.pas.inc');
  Finish;
end.
