{ The name and the extension of a file whose name starts with a dot (strutil, lfn, fileutil): on a system without drive
  letters the leading dot is a part of the name. }
{$mode objfpc}{$H-}
program t_dotname;
uses DnPath, strutil, Lfn, fileutil;
{$I dntest.inc}

procedure Split(const Path, WantName, WantExt: String);
var
  D, N, E: String;
begin
  lFSplit(Path, D, N, E);
  Check((N = WantName) and (E = WantExt), 'lFSplit ' + Path + ': [' + N + '] [' + E + ']');
end;

begin
  Check(not HasDrives, 'a system without drive letters');
  Check(PosLastDot('.bashrc') = 8, 'PosLastDot .bashrc: no extension');
  Check(PosLastDot('.config.bak') = 8, 'PosLastDot .config.bak: the second dot');
  Check(PosLastDot('a.txt') = 2, 'PosLastDot a.txt');
  Check(PosLastDot('/home/u/.profile') = 17, 'PosLastDot of a path to a dot file');
  Check(PosLastDot('..') = 3, 'PosLastDot ..');
  Check(PosLastDot('..x') = 4, 'PosLastDot ..x: no extension');
  Check(IsExtDot('a..b', 3), 'IsExtDot: a dot after a letter');
  Check(not IsExtDot('dir/.x', 5), 'IsExtDot: a dot after a separator');
  Split('.bashrc', '.bashrc', '');
  Split('.config.bak', '.config', '.bak');
  Split('/home/u/.profile', '.profile', '');
  Split('/home/u/a.tar.gz', 'a.tar', '.gz');
  Split('/home/u/..', '..', '');
  Check(GetExt('.bashrc') = '.', 'GetExt .bashrc: none');
  Check(GetExt('.config.bak') = '.bak', 'GetExt .config.bak');
  Check(GetName('/home/u/.bashrc') = '.bashrc', 'GetName keeps the whole name');
  Check(InMask('.bashrc', '*.'), 'InMask: *. matches .bashrc');
  Check(InMask('.bashrc', '*.*'), 'InMask: *.* matches .bashrc');
  Check(InMask('.config.bak', '*.bak'), 'InMask: *.bak matches .config.bak');
  Check(not InMask('.config.bak', '*.'), 'InMask: *. does not match .config.bak');
  Finish;
end.
