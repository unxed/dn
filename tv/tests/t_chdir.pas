program t_chdir;
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem,
  TvApp, TvDialog, TvWindow, TvList, TvInput, TvFiles, TvFileDlg, TvChDir;
{$I testlib.inc}

var
  App: PApplication;
  Dlg: PChDirDialog;
  Used0: PtrUInt;
  Orig, Base, Dir: ShortString;

function Same(const A, B: ShortString): Boolean;
begin
  Result := UpperCase(A) = UpperCase(B);      { DOS gives the names in upper case }
end;

{ the main block would keep the temporary string of the conversion until the end }
function DirGone(const D: ShortString): Boolean;
begin
  Result := not DirectoryExists(D);
end;

function Line(L: PListBox; I: Integer): ShortString;
begin
  Result := L^.GetText(I, 255);
end;

procedure Command(V: PView; Cmd: Word);
var
  E: TEvent;
begin
  ClearEvent(E);
  E.What := evCommand;
  E.Command := Cmd;
  V^.HandleEvent(E);
end;

procedure Run;
var
  P: PDirEntry;
begin
  GetDir(0, Orig);
  Base := 'tvf_cd';
  if DirectoryExists(Base) then
  begin
    ChDir(Base);
    RemoveDir('one'); RemoveDir('two' + DirDelim + 'deep'); RemoveDir('two');
    ChDir(Orig);
    RemoveDir(Base);
  end;
  MkDir(Base);
  ChDir(Base);
  MkDir('one');
  MkDir('two');
  MkDir('two' + DirDelim + 'deep');
  Dir := GetCurDir;

  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init(cdNormal, 2));
  App^.InsertWindow(Dlg);

  Check(Same(Dlg^.DirInput^.Data^, Copy(Dir, 1, Length(Dir) - 1)) or Same(Dlg^.DirInput^.Data^, Dir),
    'the input line shows the current directory (without the end separator)');
  Check(Dlg^.DirList^.Items^.Count >= 5, 'Drives, the path and the subdirectories are listed');
  Check(Line(Dlg^.DirList, 0) = DrivesText, 'the first line is "Drives"');
  Check(Pos(PathDirText, Line(Dlg^.DirList, 1)) = 1, 'then the root with the tree mark');
  Check(Dlg^.DirList^.Cur = Dlg^.DirList^.Focused, 'the current directory is focused');
  Check(Same(Dlg^.DirList^.DirItem(Dlg^.DirList^.Cur)^.Dir^, Copy(Dir, 1, Length(Dir) - 1)),
    'and its path is the one of the directory');
  { the subdirectories are the last two lines }
  Check(Pos('one', Line(Dlg^.DirList, Dlg^.DirList^.Items^.Count - 2)) > 0, 'the first subdirectory');
  Check(Pos('two', Line(Dlg^.DirList, Dlg^.DirList^.Items^.Count - 1)) > 0, 'the second subdirectory');
  Check(Pos(#$C0#$C4, Line(Dlg^.DirList, Dlg^.DirList^.Items^.Count - 1)) > 0,
    'the last line ends the tree');

  { choosing a subdirectory with the Chdir command }
  Dlg^.DirList^.FocusItem(Dlg^.DirList^.Items^.Count - 1);   { two }
  Command(Dlg, cmChangeDir);
  Check(Same(Copy(Dlg^.DirInput^.Data^, Length(Dlg^.DirInput^.Data^) - 2, 3), 'two'), 'Chdir puts the directory into the input line');
  Check(Pos('deep', Line(Dlg^.DirList, Dlg^.DirList^.Items^.Count - 1)) > 0, 'and the list shows its subdirectories');

  { Revert returns to the current directory }
  Command(Dlg, cmRevert);
  Check(Same(Copy(Dlg^.DirInput^.Data^, Length(Dlg^.DirInput^.Data^) - 5, 6), 'tvf_cd'), 'Revert shows the current directory again');

  { OK changes the directory }
  Dlg^.DirInput^.Data^ := 'two';
  Check(Dlg^.Valid(cmOK), 'OK with an existing directory');
  GetDir(0, Dir);
  Check(Same(Copy(Dir, Length(Dir) - 2, 3), 'two'), 'the current directory is changed');
  Dlg^.DirInput^.Data^ := 'nonexistent_dir';
  MemKey(kbEnter);
  Check(not Dlg^.Valid(cmOK), 'a missing directory is refused (a message is shown)');
  Check(Dlg^.Valid(cmCancel), 'Cancel is always valid');

  { the drives }
  Dlg^.DirList^.NewDirectory(DrivesText);
  Check(Line(Dlg^.DirList, 0) = DrivesText, 'drives: the first line');
  Check(Dlg^.DirList^.Items^.Count >= 2, 'drives: at least one drive');
  P := Dlg^.DirList^.DirItem(Dlg^.DirList^.Items^.Count - 1);
  Check(Pos(LastDirText, P^.Text^) = 1, 'the last drive ends the tree');

  Dispose(App, Done);
  MemDone;
  ChDir(Orig);
  ChDir(Base);
  RemoveDir('one'); RemoveDir('two' + DirDelim + 'deep'); RemoveDir('two');
  ChDir(Orig);
  RemoveDir(Base);
end;

begin
  { the RTL allocates some state at the first use: not a leak }
  Base := FExpand('x');
  Base := GetCurDir;
  IsDir('.');
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  Run;
  Check(DirGone(Base), 'the test directory is removed');
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
