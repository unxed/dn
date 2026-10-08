{ OSNamesUnix: the names of the files of DN at the border of Linux and the other Unix systems (the backend of the facade in OSDep).
  Moved from OSDep (platform separation, stage 3): the code is the same, only the place is new.
  This unit is our own code (MIT, see LICENSE). }
unit OSNamesUnix;

{$mode objfpc}
{$H-}

interface

var
  { False: the names are UTF-8 inside DN (the build DNUTF8) and no conversion is done at the border; DN_NAME_CONV=0 switches it off too }
  NameConv: Boolean = True;

{ the name from the system (UTF-8) as the bytes of the page of DN, and the way back }
function NameFromOs(const S: string): string;
function NameToOs(const S: string): string;
{ a path of DN (A:\x\y, the page of DN) as a path of the system (the case of the existing names is found) }
function OsPath(const S: string): string;
{ a path of DN as the user of Unix expects to read it (issue #23): "C:\dev\shm\" is shown as "/dev/shm/". Only the spelling changes: the
  drive is dropped and "\" becomes "/"; the bytes stay those of the page of DN and no file is looked up (unlike OsPath, which makes a path
  to open) }
function DisplayPath(const S: string): string;
{ a command line of DN: the paths in it are made system paths, the other bytes are converted as names }
function CommandLineToOs(const S: string): string;

implementation

uses
  SysUtils, BaseUnix, TvCodePg, TvUtf8;

function PathExists(const P: string): Boolean;
begin
  Result := fpAccess(P, F_OK) = 0;
end;

{ The names of the files in DN are bytes of its code page (CP866 for the Russian text of the language files and the screen), in
  Linux they are UTF-8. At the border the names are converted: a name that is valid UTF-8 and has only characters that the
  page of DN has is turned into the bytes of the page (so that Russian names are shown as Russian); a name that is not (other
  characters, not UTF-8) stays as it is. The way back (OsPath) takes the converted name if such a file exists, else the
  name as it is. This is a stop-gap until DN is UTF-8 inside (PLAN.md, item 4). DN_NAME_CONV=0 switches it off. }

function HasHigh(const S: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    if Byte(S[I]) >= $80 then
      Exit(True);
  Result := False;
end;

function NameFromOs(const S: string): string;
var
  I, Used: Integer;
  CP: LongWord;
  B: Byte;
begin
  Result := S;
  if not NameConv or not HasHigh(S) then
    Exit;
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
    begin
      Result := Result + S[I];
      Inc(I);
      Continue;
    end;
    if not Utf8Decode(@S[I], Length(S) - I + 1, CP, Used) then
      Exit(S);
    B := CpFromUnicode(CP);
    if B = 0 then
      Exit(S);
    Result := Result + Chr(B);
    Inc(I, Used);
  end;
end;

function NameToOs(const S: string): string;
var
  I, J, N: Integer;
  Buf: array[0..7] of Byte;
begin
  Result := S;
  if not NameConv or not HasHigh(S) then
    Exit;
  Result := '';
  for I := 1 to Length(S) do
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
    begin
      N := Utf8Encode(CpToUnicode(Byte(S[I])), @Buf[0]);
      for J := 0 to N - 1 do
        Result := Result + Chr(Buf[J]);
    end;
end;

{ the case of the names of the path that exist is found by listing the directories }
function ResolveCase(const P: string): string;
var
  I, Start: Integer;
  Base, Comp, Cand, Dir: string;
  SR: SysUtils.TSearchRec;
  Found: Boolean;
begin
  if (P = '') or PathExists(P) then
    Exit(P);
  Base := '';
  I := 1;
  if P[1] = '/' then
  begin
    Base := '/';
    I := 2;
  end;
  while I <= Length(P) do
  begin
    Start := I;
    while (I <= Length(P)) and (P[I] <> '/') do
      Inc(I);
    Comp := Copy(P, Start, I - Start);
    if Comp = '' then
    begin
      Inc(I);
      Continue;
    end;
    Cand := Base + Comp;
    if not PathExists(Cand) then
    begin
      Dir := Base;
      if Dir = '' then
        Dir := '.';
      Found := False;
      if SysUtils.FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
      begin
        repeat
          if SameText(SR.Name, Comp) then
          begin
            Cand := Base + SR.Name;
            Found := True;
            Break;
          end;
        until SysUtils.FindNext(SR) <> 0;
        SysUtils.FindClose(SR);
      end;
      if not Found then
        Exit(Base + Copy(P, Start, MaxInt));       { it does not exist: as it is }
    end;
    Base := Cand;
    if I <= Length(P) then
    begin
      Base := Base + '/';
      Inc(I);
    end;
  end;
  Result := Base;
end;

function OsPath(const S: string): string;
var
  I: Integer;
  Raw: string;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[2] = ':') and (UpCase(Result[1]) in ['A'..'Z']) then
  begin
    Delete(Result, 1, 2);
    if Result = '' then
      Result := '.';
  end;
  for I := 1 to Length(Result) do
    if Result[I] = '\' then
      Result[I] := '/';
  if NameConv and HasHigh(Result) then
  begin
    Raw := Result;
    Result := ResolveCase(NameToOs(Raw));
    if not PathExists(Result) and PathExists(ResolveCase(Raw)) then
      Result := ResolveCase(Raw);          { a file whose name is not in the page of DN: its bytes }
    Exit;
  end;
  Result := ResolveCase(Result);
end;

function DisplayPath(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  if (Length(Result) >= 2) and (Result[2] = ':') and (UpCase(Result[1]) in ['A'..'Z']) then
    Delete(Result, 1, 2);
  if Result = '' then
    Result := '/';
  for I := 1 to Length(Result) do
    if Result[I] = '\' then
      Result[I] := '/';
end;

{ a path in a command line is read by the shell: $ and ` in it (the list files of the archivers are named $DN0$.LST) keep their meaning with a backslash }
function ShellEscape(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if S[I] in ['$', '`'] then
      Result := Result + '\';
    Result := Result + S[I];
  end;
end;

function CommandLineToOs(const S: string): string;
var
  I, J: Integer;
  Q: Boolean;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (I + 2 <= Length(S)) and (UpCase(S[I]) in ['A'..'Z']) and (S[I + 1] = ':') and (S[I + 2] in ['\', '/'])
      and ((I = 1) or (S[I - 1] in [' ', '"', '''', '>', '<', '=', '|', ';', '(', '&', '@'])) then
    begin
      Q := (I > 1) and (S[I - 1] = '"');
      J := I + 2;
      while (J <= Length(S)) and (not Q or (S[J] <> '"')) and (Q or not (S[J] in [' ', '"', '''', '>', '<', '|', ';', '&', ')'])) do
        Inc(J);
      Result := Result + ShellEscape(OsPath(Copy(S, I, J - I)));
      I := J;
    end
    else
    begin
      Result := Result + NameToOs(S[I]);
      Inc(I);
    end;
  end;
end;

end.
