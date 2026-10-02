program t_vpsys;
{ Tests of dn/new/vpsyslow.pas (the system layer of DN on Free Pascal). }
{$mode objfpc}{$H-}
uses SysUtils, VPSysLow;
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

begin
  { the constants are those of DOS INT 21h AH=3Dh }
  Check((Open_Access_ReadOnly = 0) and (Open_Access_WriteOnly = 1) and (Open_Access_ReadWrite = 2),
    'access modes');
  Check((Open_Share_DenyReadWrite = $10) and (Open_Share_DenyWrite = $20) and
    (Open_Share_DenyRead = $30) and (Open_Share_DenyNone = $40), 'sharing modes');
  Check((Open_Access_ReadWrite or Open_Share_DenyNone) = $42, 'modes are combined with or');
  Check(SizeOf(TQuad) = 8, 'TQuad has 64 bits');

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
  Check((SysPlatformId >= -1) and (SysPlatformId <= 2), 'the platform id is one of the known');
  SysCtrlSleep(0);
  SysCtrlSleep(5);
  Check(PhysMemAvail > 0, 'there is memory');
  SysDisableHardErrors;
  SysCtrlSetCBreakHandler;
  SysBeepEx(0, 0);
  Check(True, 'the calls that have nothing to do on a test system do not fail');

  { running a program that is not there: an error code, not an exception }
  Rc := SysExecute('no_such_program_vpsys', '', nil, False, nil, -1, -1, -1);
  Check(Rc <> 0, 'running a missing program gives an error code');
  Finish;
end.
