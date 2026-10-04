{ Buffered profile reads, updates and stream lifetime across files. }
{$mode delphi}{$H+}
program t_profile;
uses SysUtils, profile;
{$I dntest.inc}

var
  FirstName, SecondName: AnsiString;
  Buf: array[0..255] of Char;
begin
  FirstName := GetTempFileName(GetTempDir(False), 'dn1');
  SecondName := GetTempFileName(GetTempDir(False), 'dn2');
  try
    WritePrivateProfileString('Panel', 'Count', '7', PChar(FirstName));
    CloseProfile;
    CloseProfile;
    Check(GetPrivateProfileInt('Panel', 'Count', 0, PChar(FirstName)) = 7,
      'closing the class stream persists the value');
    Check(GetPrivateProfileInt('Panel', 'Missing', 42, PChar(FirstName)) = 42,
      'a missing key returns its default');

    WritePrivateProfileString('Panel', 'Count', '123', PChar(FirstName));
    WritePrivateProfileString('Other', 'Name', '"label"', PChar(FirstName));
    CloseProfile;
    Check(GetPrivateProfileInt('Panel', 'Count', 0, PChar(FirstName)) = 123,
      'a longer replacement survives reopening');
    GetPrivateProfileString('Other', 'Name', '', Buf, SizeOf(Buf), PChar(FirstName));
    Check(StrPas(Buf) = 'label', 'another section and a quoted value survive');

    WritePrivateProfileString('Panel', 'Count', '99', PChar(SecondName));
    Check(GetPrivateProfileInt('Panel', 'Count', 0, PChar(FirstName)) = 123,
      'switching files closes the previous stream');
    Check(GetPrivateProfileInt('Panel', 'Count', 0, PChar(SecondName)) = 99,
      'the next file has its own value');

    WritePrivateProfileString('Panel', 'Count', nil, PChar(FirstName));
    CloseProfile;
    Check(GetPrivateProfileInt('Panel', 'Count', 42, PChar(FirstName)) = 42,
      'deleting a key is persisted');
    Check(GetPrivateProfileInt('Panel', 'Count', 42, nil) = 42,
      'an absent file releases the current stream');
    Check(GetPrivateProfileInt('Panel', 'Count', 0, PChar(SecondName)) = 99,
      'a valid file can be reopened after a failed open');
  finally
    CloseProfile;
    DeleteFile(FirstName);
    DeleteFile(SecondName);
  end;
  Finish;
end.
