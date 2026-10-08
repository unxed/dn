program t_osrun;
{ Tests of compat/osrun.pas and ossystem.pas (starting programs, the small system calls) on the system of the test. }
{$mode objfpc}{$H-}
uses SysUtils, OSRun, OSSystem;
{$I dntest.inc}

var
  R: LongInt;
  Name: string;
  P: array[0..255] of Char;

begin
{$IFDEF UNIX}
  R := RunShell('exit 3');
  Check((R >= 0) and ((R shr 8) = 3), 'RunShell: the exit code of the shell is in the second byte');
  R := RunShell('true');
  Check(R = 0, 'RunShell: success is 0');

  R := RunQuiet('exit 3');
  Check((R >= 0) and ((R shr 8) = 3), 'RunQuiet: the exit code of the shell is in the second byte');
  Check(RunQuiet('true') = 0, 'RunQuiet: success is 0');
  Check(RunQuiet('no_such_program_runquiet 2>/dev/null') <> 0, 'RunQuiet: a missing program is an error');

  Name := GetTempDir + 't_osrun_' + IntToStr(GetProcessID) + '.txt';
  StrPCopy(P, '/c echo ok > ' + Name);
  Check((Execute('', P) = 0) and FileExists(Name), 'Execute: COMSPEC /c command (the DOS way) runs the command');
  DeleteFile(Name);
  StrPCopy(P, '/C echo ok > ' + Name);
  Check((Execute('', P) = 0) and FileExists(Name), 'Execute: /C in capitals too');
  DeleteFile(Name);
  StrPCopy(P, '/c exit 127');
  Check(Execute('', P) = 2, 'Execute: "not found" (the shell status 127) is the DOS error 2');
  StrPCopy(P, '');
  Check(Execute('no_such_program_osrun', P) = 2, 'Execute: a missing program is the DOS error 2');
  StrPCopy(P, 'hello');
  Check(Execute('echo', P) = 0, 'Execute: a program with arguments');
{$ENDIF}

{$IFDEF GO32V2}
  Check(OSBatchExt = '.BAT', 'batch extension on DOS');
{$ELSE}
  Check(OSBatchExt = '.CMD', 'batch extension elsewhere');
{$ENDIF}
{$IFDEF UNIX}
  Check(OSDefaultTempDir = '/tmp/', 'default temporary directory of Unix');
{$ELSE}
  Check(OSDefaultTempDir = '', 'no default temporary directory elsewhere');
{$ENDIF}
  Check(OSFileIsDevice(0) = 0, 'a handle is not a device on a system of the tests');
  Check(OSVolumeLabel('C') = '', 'no volume label on a system of the tests');
  OSDiskReset;
  OSBeep(0, 0);
  Check(OSMemAvail > 0, 'there is memory for buffers');
  Finish;
end.
