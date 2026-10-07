program t_osdep;
{ Tests of dn/new/osdep.pas (the system layer of DN on Free Pascal). }
{$mode objfpc}{$H-}
uses SysUtils, Strings, {$IFDEF UNIX}BaseUnix, {$ENDIF}osdep, TvScreen, TvCell, TvColors;
{$I dntest.inc}

var
  F: File;
  H: THandle;
  Name: ShortString;
  Buf: array[0..9] of Byte;
  Q: TQuad;
  Drives: LongWord;
  P: array[0..255] of Char;
  Rc: LongInt;
  HI, Act: LongInt;
  Srch: TOSSearchRec;
  Stamp: LongInt;
  AttrFile: File;
  AttrTmp: string;
  Attr: Word;
{$IFDEF UNIX}
  AttrStat: Stat;
{$ENDIF}

begin
  { the constants are those of DOS INT 21h AH=3Dh }
  Check((Open_Access_ReadOnly = 0) and (Open_Access_WriteOnly = 1) and (Open_Access_ReadWrite = 2),
    'access modes');
  Check((Open_Share_DenyReadWrite = $10) and (Open_Share_DenyWrite = $20) and
    (Open_Share_DenyRead = $30) and (Open_Share_DenyNone = $40), 'sharing modes');
  Check((Open_Access_ReadWrite or Open_Share_DenyNone) = $42, 'modes are combined with or');
  Check(SizeOf(TQuad) = 8, 'TQuad has 64 bits');

  { the files of VP: SysFileCreate, Write, Seek, Read, Open, Close }
  P[0] := #0;
  StrPCopy(P, 'vpsys2.tmp');
  Check(SysFileCreate(P, Open_Access_ReadWrite, 0, HI) = 0, 'SysFileCreate');
  Buf[0] := 7; Buf[1] := 8; Buf[2] := 9;
  Check(FileWrite(HI, Buf, 3) = 3, 'three bytes are written (the RTL: SysFileWrite is gone)');
  Check((SysFileSeek(HI, 0, 0, Act) = 0) and (Act = 0), 'SysFileSeek to the beginning');
  FillChar(Buf, SizeOf(Buf), 0);
  Check((SysFileSeek(HI, 0, 2, Act) = 0) and (Act = 3), 'SysFileSeek to the end gives the size');
  Check(SysFileClose(HI) = 0, 'close');
  Check((SysFileOpen(P, Open_Access_ReadOnly, HI) = 0) and (HI <> 0), 'SysFileOpen');
  SysFileClose(HI);
  StrPCopy(P, 'no_such_dir_vpsys/x.tmp');
  Check(SysFileOpen(P, Open_Access_ReadOnly, HI) <> 0, 'opening a missing file gives an error code');

  { searching }
  StrPCopy(P, 'vpsys2.tmp');
  Check((SysFindFirst(P, 0, Srch, False) = 0) and (Srch.Size = 3) and (Srch.Name = 'vpsys2.tmp'),
    'SysFindFirst finds the file with its size');
  Check(SysFindNext(Srch, False) <> 0, 'SysFindNext: nothing more');
  Check(SysFindClose(Srch) = 0, 'SysFindClose');
  StrPCopy(P, 'vpsys2.nothing');
  Check(SysFindFirst(P, 0, Srch, False) <> 0, 'a missing file is not found');
  DeleteFile('vpsys2.tmp');
{$IFDEF UNIX}
  { a link to a directory is found with SysLinkAttr (DN does not enter it: /proc/self/root is a loop) }
  CreateDir('vpsys_dir');
  FpSymlink('vpsys_dir', 'vpsys_lnk');
  StrPCopy(P, 'vpsys_lnk');
  Check((SysFindFirst(P, $10, Srch, False) = 0) and (Srch.Attr and SysLinkAttr <> 0) and (Srch.Attr and $10 <> 0),
    'a link to a directory: SysLinkAttr and the directory bit');
  SysFindClose(Srch);
  StrPCopy(P, 'vpsys_dir');
  Check((SysFindFirst(P, $10, Srch, False) = 0) and (Srch.Attr and SysLinkAttr = 0), 'a directory is not a link');
  SysFindClose(Srch);
  DeleteFile('vpsys_lnk');
  RemoveDir('vpsys_dir');
{$ENDIF}

  { a file: size, close }
  Name := 'vpsys.tmp';
  Assign(F, Name);
  Rewrite(F, 1);
  FillChar(Buf, SizeOf(Buf), 1);
  BlockWrite(F, Buf, SizeOf(Buf));
  Close(F);
  H := FileOpen(AnsiString(Name), fmOpenReadWrite);
  Check(H <> THandle(-1), 'the test file is opened');
  Check(SysFileIsDevice(H) = 0, 'a file is not a device');
  { the position stays where it was (on Windows the truncation moved it to the new end: a copy wrote its data after a block of zeros) }
  Check(FileSeek(H, 2, 0) = 2, 'the position is 2');
  Check(SysFileSetSize(H, 10) = 0, 'SysFileSetSize 10 (a position inside the file)');
  Check(FileSeek(H, 0, 1) = 2, 'the position is still 2 after the size was set');
  FileSeek(H, 0, 0);
  Check(SysFileSetSize(H, 30) = 0, 'SysFileSetSize 30 (the file grows)');
  Check(FileSeek(H, 0, 1) = 0, 'the position is still 0 after the size grew: the data written next goes to the start');
  Check(SysFileSetSize(H, 4) = 0, 'SysFileSetSize cuts the file');
  Check(FileSeek(H, 0, 2) = 4, 'the file is 4 bytes long now');
  Check(SysFileSetSize(H, 20) = 0, 'and grows it');
  Check(FileSeek(H, 0, 2) = 20, 'the file is 20 bytes long now');
  Check(SysFileClose(H) = 0, 'SysFileClose');
  DeleteFile(AnsiString(Name));

  { the disks }
  P[0] := #0;
  Q := SysDiskSizeLongX(P);
  Check(Q > 0, 'the size of the current disk is known');
  Check((SysDiskFreeLongX(P) >= 0) and (SysDiskFreeLongX(P) <= Q), 'free space is between 0 and the size');
  Check(SysDiskFreeLong(0) = SysDiskFreeLongX(P), 'the same by the drive number 0');
  Drives := SysGetValidDrives;
  Check(Drives <> 0, 'some drive exists');
{$IFDEF GO32V2}
  Check((Drives and (1 shl 2)) <> 0, 'drive C exists under DOS');
{$ENDIF}

  { the system }
  Sleep(5);
  Check(PhysMemAvail > 0, 'there is memory');
  SysBeepEx(0, 0);
  Check(True, 'the calls that have nothing to do on a test system do not fail');

  { running a program that is not there: an error code, not an exception }
  Rc := SysExecute('no_such_program_vpsys', '', nil, False, nil, -1, -1, -1);
  Check(Rc <> 0, 'running a missing program gives an error code');
{$IFDEF UNIX}
  { DN starts the archivers as "COMSPEC /c command"; COMSPEC is empty on Unix: the command still runs (in the shell of the system) }
  Name := '/tmp/t_osdep_exec_' + IntToStr(GetProcessID) + '.txt';
  StrPCopy(P, '/c echo run > ' + Name);
  Rc := SysExecute('', P, nil, False, nil, -1, -1, -1);
  Check((Rc = 0) and FileExists(Name), 'the DOS way "COMSPEC /c command" runs the command on Unix');
  DeleteFile(Name);
{$ENDIF}
    { the search of a directory that is not there is "path not found" (3), not "no more files" (18): PathExist of DN depends on it }
  Rc := SysFindFirst('/no_such_dir_osdep_xyz/*.*', faAnyFile, Srch, False);
  Check(Rc = 3, 'SysFindFirst: a missing directory is 3 (path not found)');
  SysFindClose(Srch);
{$IFDEF UNIX}
  Rc := SysFindFirst('/tmp/*.no_match_osdep_xyz', faAnyFile, Srch, False);
  Check(Rc = 18, 'SysFindFirst: nothing matches in an existing directory: 18 (no more files)');
  SysFindClose(Srch);
{$ENDIF}
    Name := SysTempFileName('dn-t-', '.tmp');
  Check((Pos('dn-t-', Name) > 0) and (Copy(Name, Length(Name) - 3, 4) = '.tmp') and (ExtractFilePath(Name) = IncludeTrailingPathDelimiter(GetTempDir(False))), 'SysTempFileName: prefix, extension, the temporary directory');
  Check(SysTempFileName('dn-t-', '.tmp') <> SysTempFileName('dn-t-', '.tmp') , 'SysTempFileName: two names differ');

{$IFDEF UNIX}
  Check(SysSkipInTree('C:\', 'proc') and SysSkipInTree('C:\', 'SYS') and SysSkipInTree('/', 'sys'), 'tree: /proc and /sys of the root are not entered');
  Check(not SysSkipInTree('C:\home\', 'proc') and not SysSkipInTree('C:\', 'home'), 'tree: other directories are');
{$ELSE}
  Check(not SysSkipInTree('C:\', 'proc'), 'tree: nothing is skipped');
{$ENDIF}
  { the time of a search record is the DOS packed time on every target (on Unix SysUtils gives the Unix time: the panels showed garbage dates) }
{$IFDEF UNIX}
  Stamp := DateTimeToFileDate(EncodeDate(2026, 10, 6) + EncodeTime(19, 46, 10, 0));
  Check(SysFileTimeToDos(Stamp) = LongInt((Cardinal(2026 - 1980) shl 25) or (10 shl 21) or (6 shl 16) or (19 shl 11) or (46 shl 5) or 5), 'file time: Unix time to DOS time');
  Check(SysFileTimeToDos(0) = LongInt((1 shl 21) or (1 shl 16)), 'file time: before 1980 is the first DOS time');
{$ELSE}
  Check(SysFileTimeToDos($12345678) = $12345678, 'file time: the DOS time stays');
{$ENDIF}
  { the attribute ReadOnly of a file: on Unix the write permission of the owner (the RTL has no attributes there) }
  AttrTmp := GetTempDir + 't_osdep_attr_' + IntToStr(GetProcessID) + '.txt';
  Assign(F, AttrTmp);
  Rewrite(F, 1);
  Close(F);
  Assign(AttrFile, AttrTmp);
  SysGetFAttr(AttrFile, Attr);
  Check((Attr and 1) = 0, 'attributes: a new file is not read-only');
  SysSetFAttr(AttrFile, 1);
  SysGetFAttr(AttrFile, Attr);
  Check((Attr and 1) = 1, 'attributes: ReadOnly is set and read back');
{$IFDEF UNIX}
  fpStat(AttrTmp, AttrStat);
  Check((AttrStat.st_mode and (S_IWUSR or S_IWGRP or S_IWOTH)) = 0, 'attributes: the file has no write permission now (Unix)');
{$ENDIF}
  SysSetFAttr(AttrFile, 32);
  SysGetFAttr(AttrFile, Attr);
  Check((Attr and 1) = 0, 'attributes: ReadOnly is cleared again (Archive alone)');
  DeleteFile(AttrTmp);
Finish;
end.
