program t_fdlg;
{$I ../src/tvdefs.inc}
uses SysUtils, TvGeom, TvCell, TvCodePg, TvEvents, TvKeys, TvViews, TvObjs, TvUtil, TvMem,
  TvApp, TvDialog, TvWindow, TvList, TvInput, TvFiles, TvFileDlg;
{$I testlib.inc}

var
  Used0: PtrUInt;
  App: PApplication;
  Dlg: PFileDialog;
  Orig, Base: ShortString;
  E: TEvent;

procedure Touch(const FileName: ShortString);
var
  H: Text;
begin
  Assign(H, FileName);
  Rewrite(H);
  Close(H);
end;

function Same(const A, B: ShortString): Boolean;
begin
  Result := UpperCase(A) = UpperCase(B);      { DOS gives the names in upper case }
end;

procedure Key(V: PView; Code: Word; Ch: Char = #0);
var
  E: TEvent;
begin
  MakeKeyEvent(E, Code, 0);
  if Ch <> #0 then
    E.CharCode := Ord(Ch);
  V^.HandleEvent(E);
end;

{ the main block would keep the temporary string of the conversion until the end }
function DirGone(const D: ShortString): Boolean;
begin
  Result := not DirectoryExists(D);
end;

procedure Cleanup;
begin
  DeleteFile('a.txt');
  DeleteFile('b.txt');
  DeleteFile('c.dat');
  RemoveDir('sub');
end;

procedure Run;
var
  Rec: ShortString;
begin
  GetDir(0, Orig);
  Base := 'tvf_dlg';
  if DirectoryExists(Base) then
  begin
    ChDir(Base);
    Cleanup;
    ChDir(Orig);
    RemoveDir(Base);
  end;
  MkDir(Base);
  ChDir(Base);
  Touch('a.txt');
  Touch('b.txt');
  Touch('c.dat');
  MkDir('sub');

  HeapMark(-1);            { -1: the files are made }
  MemInit(80, 25);
  New(App, Init);
  New(Dlg, Init('*.txt', 'Open a file', '~N~ame', fdOpenButton or fdHelpButton, 1));
  HeapMark(0);                   { the dialog is made }
  App^.InsertWindow(Dlg);
  HeapMark(1);                   { it is shown }

  Check(Dlg^.FileName^.Data^ = '*.txt', 'the input line holds the mask');
  Check(Dlg^.FileList^.Range = 4, 'two files, a directory and ".." are listed');
  Check(Same(Dlg^.FileList^.GetText(0, 255), 'a.txt') and Same(Dlg^.FileList^.GetText(1, 255), 'b.txt'),
    'files first');
  Check(Same(Dlg^.FileList^.GetText(2, 255), 'sub' + DirDelim), 'then directories (with a separator)');
  Check(Dlg^.FileList^.GetText(3, 255) = '..' + DirDelim, 'and ".." is the last');

  { the file list tells the dialog what is focused }
  Dlg^.FileList^.Select;
  Key(Dlg^.FileList, Ord('b'), 'b');
  Check(Dlg^.FileList^.Focused = 1, 'a typed letter finds the item');
  Check(Same(Dlg^.FileName^.Data^, 'b.txt'), 'the input line shows the focused file');
  Key(Dlg^.FileList, kbUp);
  Key(Dlg^.FileList, Ord('s'), 's');
  Key(Dlg^.FileList, Ord('u'), 'u');
  Check(Dlg^.FileList^.Focused = 2, 'more letters find a longer name');
  Check(Same(Dlg^.FileName^.Data^, 'sub' + DirDelim + '*.txt'), 'a directory is shown with the mask');

  { a file name }
  Dlg^.FileName^.Data^ := 'b.txt';
  Check(Dlg^.Valid(cmOK), 'an existing file name is valid');
  Dlg^.GetData(Rec);
  Check(Same(Rec, ExpandFileName('b.txt')), 'GetData gives the full name');
  Dlg^.FileName^.Data^ := 'new.txt';
  Check(Dlg^.Valid(cmOK), 'a new file name is valid too');
  Check(Dlg^.Valid(cmCancel), 'Cancel is valid');

  HeapMark(2);                   { after the typing, a file name }
  { a mask }
  Dlg^.FileName^.Data^ := '*.dat';
  Check(not Dlg^.Valid(cmOK), 'a mask is not a result');
  Check(Same(Dlg^.WildCard, '*.dat') and (Dlg^.FileList^.Range = 3), 'it rereads the directory');
  Check(Same(Dlg^.FileList^.GetText(0, 255), 'c.dat'), 'with the files of the mask');

  HeapMark(3);                   { after the mask }
  { a directory }
  Dlg^.FileName^.Data^ := 'sub';
  Check(not Dlg^.Valid(cmOK), 'a directory is not a result');
  Check(Dlg^.FileList^.Range = 1, 'the list is the one of the directory (only "..")');
  Check(Same(Dlg^.Directory^, ExpandFileName('sub') + DirDelim), 'the directory is remembered');
  Dlg^.FileName^.Data^ := '..';
  Check(not Dlg^.Valid(cmOK), 'go up');
  Check(Dlg^.FileList^.Range = 3, 'the list is the one of the parent directory again');

  HeapMark(4);                   { after the directories }
  { an invalid name: a message box with OK }
  Dlg^.FileName^.Data^ := 'na|me';
  MemKey(kbEnter);
  Check(not Dlg^.Valid(cmOK), 'an invalid file name is refused (a message is shown)');

  { a double click is turned into cmOK }
  ClearEvent(E);
  E.What := evBroadcast;
  E.Command := cmFileDoubleClicked;
  E.InfoPtr := Dlg^.FileList^.List^.At(0);
  Dlg^.HandleEvent(E);
  Check(E.What = evNothing, 'a double click is handled');
  Check(Dlg^.FileList^.SearchPos = -1, 'no search is running');

  HeapMark(5);                   { after the message box }
  Dispose(App, Done);
  HeapMark(6);                   { the application is disposed }
  MemDone;
  HeapMark(7);                   { the screen is freed }
  ChDir(Orig);
  ChDir(Base);
  Cleanup;
  ChDir(Orig);
  RemoveDir(Base);
end;

begin
  { the RTL allocates some state at the first use: not a leak }
  Base := FExpand('x');
  Base := GetCurDir;
  IsDir('.');
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  HeapBase;
  Run;
  HeapMark(8);               { 8: the test is over }
  Check(DirGone(Base), 'the test directory is removed');
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
