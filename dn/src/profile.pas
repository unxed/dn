{ SPDX-License-Identifier: MIT }
{ Profile: GetPrivateProfileString and friends (the Windows names) over TvIni of tv/.

  Our own unit: it replaces profile.pas of Matthias Koeppe (LGPL), which read and edited the file line by line. The file is read
  by TvIni in its "profile" way (the value is all that follows '='; a ';' in it is no comment) and written at once after a change,
  as the old unit did. The file that was used last stays open until another one is asked for or CloseProfile. }
unit Profile;

interface

function GetPrivateProfileInt(ApplicationName, KeyName: PChar;
    Default: Integer; FileName: PChar): Word;
function GetPrivateProfileString(ApplicationName, KeyName: PChar;
    Default: PChar; ReturnedString: PChar; Size: Integer;
    FileName: PChar): Integer;
function WritePrivateProfileString(ApplicationName, KeyName, Str,
    FileName: PChar): Boolean;
procedure CloseProfile;

implementation

uses
  SysUtils, Strings, TvIni, TvObjs
  ;

var
  Cur: TIniFile = nil;
  CurName: String = '';

procedure CloseProfile;
  begin
  if Cur <> nil then
    begin
    Cur.Update;
    Cur.Free;
    Cur := nil;
    end;
  CurName := '';
  end;

{ Writing: a missing file is created }
function OpenFile(FileName: PChar; Write: Boolean): Boolean;
  var
    N: String;
  begin
  Result := False;
  if FileName = nil then
    begin
    CloseProfile;
    Exit;
    end;
  N := StrPas(FileName);
  if (Cur <> nil) and (CompareText(N, CurName) = 0) then
    Exit(True);
  CloseProfile;
  if Assigned(OnFileName) then                   { the names of DN to the names of the OS, as the streams of tv/ do it }
    Cur := TIniFile.Create(OnFileName(N))
  else
    Cur := TIniFile.Create(N);
  Cur.InlineComments := False;
  Cur.MakeNullEntries := True;                  { Key= with an empty value is written }
  CurName := N;
  Result := Cur.Read or Write;
  if not Result then
    CloseProfile;
  end;

function GetPrivateProfileString(ApplicationName, KeyName: PChar; Default: PChar; ReturnedString: PChar; Size: Integer; FileName: PChar): Integer;
  var
    S: PIniSection;
    E: PIniEntry;
    I, L: Integer;
    Copy: String;
    P: PChar;
  begin
  if (Size <= 0) or (ReturnedString = nil) then
    Exit(0);
  Copy := '';
  if Default <> nil then
    Copy := StrPas(Default);
  if OpenFile(FileName, False) and (ApplicationName <> nil) then
    begin
    S := Cur.SearchSection(StrPas(ApplicationName));
    if S <> nil then
      if KeyName = nil then
        begin
        { all the keys of the section: names one after another, each ends with #0, the list ends with one more #0 }
        P := ReturnedString;
        for I := 0 to S.Count - 1 do
          if S.Entry(I).IsEntry then
            begin
            L := Length(S.Entry(I).GetTag);
            if (P - ReturnedString) + L + 2 > Size then
              Break;
            StrPCopy(P, S.Entry(I).GetTag);
            Inc(P, L + 1);
            end;
        P[0] := #0;
        Exit(P - ReturnedString);
        end
      else
        begin
        E := S.SearchEntry(StrPas(KeyName));
        if E <> nil then
          Copy := E.GetValue;
        end;
    end;
  StrPLCopy(ReturnedString, Copy, Size - 1);
  Result := StrLen(ReturnedString);
  end;

function GetInt(Str: String): Word;
  var
    Res: Word;
    E: Integer;
  begin
  Str := Trim(Str);
  Val(Str, Res, E);                              { $ and 0x for hex are known to Val }
  if E = 1 then
    Res := 0
  else if E <> 0 then
    Val(System.Copy(Str, 1, E - 1), Res, E);
  GetInt := Res;
  end;

function GetPrivateProfileInt(ApplicationName, KeyName: PChar; Default: Integer; FileName: PChar): Word;
  var
    S: PIniSection;
    E: PIniEntry;
  begin
  GetPrivateProfileInt := Default;
  if OpenFile(FileName, False) and (ApplicationName <> nil) and (KeyName <> nil) then
    begin
    S := Cur.SearchSection(StrPas(ApplicationName));
    if S <> nil then
      begin
      E := S.SearchEntry(StrPas(KeyName));
      if E <> nil then
        GetPrivateProfileInt := GetInt(E.GetValue);
      end;
    end;
  end;

function WritePrivateProfileString(ApplicationName, KeyName, Str, FileName: PChar): Boolean;
  var
    S: PIniSection;
    I: Integer;
  begin
  Result := False;
  if (ApplicationName = nil) or not OpenFile(FileName, True) then
    Exit;
  if KeyName = nil then
    begin
    { the section is emptied of its keys (the comment lines stay) }
    S := Cur.SearchSection(StrPas(ApplicationName));
    if S <> nil then
      for I := S.Count - 1 downto 0 do
        if S.Entry(I).IsEntry then
          Cur.DeleteEntry(StrPas(ApplicationName), S.Entry(I).GetTag);
    end
  else if Str = nil then
    Cur.DeleteEntry(StrPas(ApplicationName), StrPas(KeyName))
  else
    Cur.SetEntry(StrPas(ApplicationName), StrPas(KeyName), StrPas(Str));
  Result := Cur.Update;
  end;

end.
