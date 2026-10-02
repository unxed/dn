program t_files;
{$I ../src/tvdefs.inc}
uses SysUtils, TvObjs, TvUtil, TvFiles;
{$I testlib.inc}

var
  Base, Dir, Name, Ext, LongName: ShortString;
  F: TFileFinder;
  C: PFileCollection;
  D: PDirCollection;
  Rec: TSearchRec;
  Used0: PtrUInt;
  N: Integer;
  T: Text;

function Same(const A, B: ShortString): Boolean;
begin
  Result := UpperCase(A) = UpperCase(B);      { DOS gives the names in upper case }
end;

procedure Touch(const FileName: ShortString; Size: Integer);
var
  H: File;
  B: array[0..99] of Byte;
begin
  Assign(H, FileName);
  Rewrite(H, 1);
  if Size > 0 then
    BlockWrite(H, B, Size);
  Close(H);
end;

procedure Run;
begin
  LongName := 'Long file name.text';
{$IFDEF GO32V2}
  if not LFNSupport then
    LongName := 'long.txt';       { no long names without LFN support in DOS }
{$ENDIF}
  Base := 'tvf_test';            { in the current directory: it is writable in DOS too }
  if DirectoryExists(AnsiString(Base)) then
  begin
    DeleteFile(AnsiString(Base + PathDelim + 'b.txt'));
    DeleteFile(AnsiString(Base + PathDelim + 'a.dat'));
    DeleteFile(AnsiString(Base + PathDelim + LongName));
    RemoveDir(AnsiString(Base + PathDelim + 'sub'));
    RemoveDir(AnsiString(Base));
  end;
  MkDir(Base);
  MkDir(Base + PathDelim + 'sub');
  Touch(Base + PathDelim + 'b.txt', 10);
  Touch(Base + PathDelim + 'a.dat', 0);
  Touch(Base + PathDelim + LongName, 5);

  HeapMark(1);             { 1: the files are made }
  { paths }
  FSplit('c:\dir\sub\file.name.ext', Dir, Name, Ext);
  Check((Dir = 'c:\dir\sub\') and (Name = 'file.name') and (Ext = '.ext'), 'FSplit');
  FSplit('file', Dir, Name, Ext);
  Check((Dir = '') and (Name = 'file') and (Ext = ''), 'FSplit of a bare name');
  FSplit('/a/b/', Dir, Name, Ext);
  Check((Dir = '/a/b/') and (Name = '') and (Ext = ''), 'FSplit of a directory');
  Check(IsWild('*.txt') and IsWild('a?') and not IsWild('abc'), 'IsWild');
  Check(IsDir(Base) and not IsDir(Base + PathDelim + 'b.txt') and not IsDir(Base + PathDelim + 'nope'), 'IsDir');
  Check(PathValid(Base) and PathValid(Base + PathDelim) and not PathValid(Base + PathDelim + 'nope'), 'PathValid');
  Check(ValidFileName(Base + PathDelim + 'x.txt') and ValidFileName('name.txt'), 'valid file names');
  Check(not ValidFileName('na|me.txt') and not ValidFileName('a.b|c.d'), 'illegal characters');
  Check(not ValidFileName(Base + PathDelim + 'nope' + PathDelim + 'x.txt'), 'a name in a missing directory');
  Check(DriveValid(GetDisk), 'the current drive is valid');
  Dir := GetCurDir;
  Check((Dir <> '') and (Dir[Length(Dir)] in ['/', '\']), 'GetCurDir ends with a separator');
  Check(FExpand('x.txt') = ShortString(ExpandFileName('x.txt')), 'FExpand');

  HeapMark(2);             { 2: the path functions are done }
  { the search }
  F.Init;
  Check(F.First(Base + PathDelim + AllMask, faDirectory), 'First finds something');
  N := 0;
  repeat
    Inc(N);
  until not F.Next;
  F.Close;
  Check(N >= 4, 'all entries are found (files, the directory, maybe . and ..)');
  Check(F.First(Base + PathDelim + 'b.*', 0) and (Same(F.Rec.Name, 'b.txt')) and (F.Rec.Size = 10) and
    ((F.Rec.Attr and faDirectory) = 0), 'a mask: name, size, attributes');
  Check(not F.Next, 'one match only');
  Check(F.First(Base + PathDelim + Copy(LongName, 1, Pos('.', LongName) - 1) + '.*', 0) and (Same(F.Rec.Name, LongName)),
    'a long name with blanks');
  F.Close;
  Check(not F.First(Base + PathDelim + '*.zzz', 0), 'nothing found');
  F.Done;

  HeapMark(3);             { 3: the search is done }
  { the collections }
  New(C, Init(10, 5));
  F.Init;
  if F.First(Base + PathDelim + AllMask, faDirectory) then
    repeat
      if (F.Rec.Name <> '.') then
        C^.Insert(NewSearchRec(F.Rec));
    until not F.Next;
  F.Done;
  Rec.Name := '..';
  Rec.Attr := faDirectory;
  if C^.At2(C^.Count - 1)^.Name <> '..' then   { not found by the search: add it }
    C^.Insert(NewSearchRec(Rec));
  Check(Same(C^.At2(0)^.Name, 'a.dat'), 'files come first, by name');
  Check(Same(C^.At2(1)^.Name, 'b.txt'), 'ignoring the case');
  Check(Same(C^.At2(2)^.Name, LongName), 'Long names are sorted too');
  Check(Same(C^.At2(3)^.Name, 'sub'), 'then the directories');
  Check(C^.At2(C^.Count - 1)^.Name = '..', 'and ".." is the last');
  Dispose(C, Done);

  New(D, Init(5, 5));
  D^.Insert(NewDirEntry('Text', 'dir'));
  Check((D^.At2(0)^.Text^ = 'Text') and (D^.At2(0)^.Dir^ = 'dir'), 'a directory entry');
  Dispose(D, Done);

  HeapMark(4);             { 4: the collections are done }
  DeleteFile(AnsiString(Base + PathDelim + 'b.txt'));
  DeleteFile(AnsiString(Base + PathDelim + 'a.dat'));
  DeleteFile(AnsiString(Base + PathDelim + LongName));
  RemoveDir(AnsiString(Base + PathDelim + 'sub'));
  RemoveDir(AnsiString(Base));
  Check(not DirectoryExists(AnsiString(Base)), 'the test directory is removed');
end;

begin
  { the RTL allocates some state at the first use: not a leak }
  Base := FExpand('x');
  IsDir('.');
  Used0 := GetFPCHeapStatus.CurrHeapUsed;
  HeapBase;
  Run;
  HeapMark(5);               { 5: the test is over }
  Check(GetFPCHeapStatus.CurrHeapUsed = Used0, 'no memory is left behind');
  Finish;
end.
