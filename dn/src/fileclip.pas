{ The conversion between file paths, text/uri-list and the Windows file drop list.

  MIT, see LICENSE. }
unit FileClip;

{$mode objfpc}
{$H+}

interface

type
  TFileClipPaths = array of UnicodeString;

function FileClipPathsToUriList(const Paths: TFileClipPaths; out Data, Err: AnsiString): Boolean;
function FileClipUriListToPaths(const Data: AnsiString; out Paths: TFileClipPaths; out Err: AnsiString): Boolean;
function FileClipPathsToDrop(const Paths: TFileClipPaths; out Drop: UnicodeString; out Err: AnsiString): Boolean;
function FileClipDropToPaths(const Drop: UnicodeString; out Paths: TFileClipPaths; out Err: AnsiString): Boolean;

implementation

uses
  SysUtils, NetSplit;

function LowerAscii(const S: AnsiString): AnsiString;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] in ['A'..'Z'] then
      Inc(Result[I], 32);
end;

function IsDrivePath(const S: UnicodeString): Boolean;
begin
  Result := (Length(S) >= 3) and (S[1] in ['A'..'Z', 'a'..'z']) and (S[2] = ':') and
    (S[3] in ['\', '/']);
end;

function IsUncPath(const S: UnicodeString): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Length(S) < 5) or (S[1] <> '\') or (S[2] <> '\') or
     (S[3] = '\') or (S[3] = '/') then Exit;
  I := 3;
  while (I <= Length(S)) and (S[I] <> '\') do Inc(I);
  Result := (I >= 4) and (I < Length(S));
end;

function PathToUri(const Path: UnicodeString; out Uri: AnsiString): Boolean;
var
  P, Server, Tail: UnicodeString;
  I: Integer;
begin
  Result := False;
  Uri := '';
  if Path = '' then Exit;
  if Path[1] = '/' then
    Uri := 'file://' + NetPercentEncode(UTF8Encode(Path), True)
  else if IsDrivePath(Path) then
    begin
      P := Path;
      for I := 1 to Length(P) do if P[I] = '\' then P[I] := '/';
      Uri := 'file:///' + NetPercentEncode(UTF8Encode(P), True);
    end
  else if IsUncPath(Path) then
    begin
      P := Copy(Path, 3, Length(Path));
      I := Pos('\', P);
      Server := Copy(P, 1, I - 1);
      Tail := Copy(P, I, Length(P));
      for I := 1 to Length(Tail) do if Tail[I] = '\' then Tail[I] := '/';
      Uri := 'file://' + UTF8Encode(Server) + NetPercentEncode(UTF8Encode(Tail), True);
    end
  else
    Exit;
  Result := True;
end;

function UriToPath(const Uri: AnsiString; out Path: UnicodeString): Boolean;
var
  Rest, Authority, Encoded, Decoded, UriPath: AnsiString;
  I: Integer;
begin
  Result := False;
  Path := '';
  if Copy(LowerAscii(Uri), 1, 7) <> 'file://' then Exit;
  Rest := Copy(Uri, 8, Length(Uri));
  I := Pos('/', Rest);
  if I = 0 then Exit;
  Authority := Copy(Rest, 1, I - 1);
  Encoded := Copy(Rest, I, Length(Rest));
  if (Pos(' ', Uri) > 0) or (Pos(#9, Uri) > 0) or (Pos(#10, Uri) > 0) or
     (Pos('?', Uri) > 0) or (Pos('#', Uri) > 0) then Exit;
  if not NetPercentDecode(Encoded, Decoded) or (Pos(#0, Decoded) > 0) then Exit;
  UriPath := Decoded;
  if (Authority = '') or (LowerAscii(Authority) = 'localhost') then
    begin
      if (Length(Decoded) >= 4) and (Decoded[1] = '/') and (Decoded[3] = ':') and
         (Decoded[4] = '/') and (Decoded[2] in ['A'..'Z', 'a'..'z']) then
        begin
          Decoded[1] := Decoded[2];
          Decoded[2] := ':';
          Delete(Decoded, 3, 1);
          for I := 1 to Length(Decoded) do if Decoded[I] = '/' then Decoded[I] := '\';
        end
      else if (Decoded = '') or (Decoded[1] <> '/') then Exit;
    end
  else
    begin
      if (Pos(':', Authority) > 0) or (Pos('@', Authority) > 0) or
          (Pos('%', Authority) > 0) or (Pos('\', Authority) > 0) or (Length(Decoded) < 2) or
         (Decoded[1] <> '/') or (Decoded[2] = '/') then Exit;
      Path := '\\' + UTF8Decode(Authority) + UTF8Decode(UriPath);
      for I := 1 to Length(Path) do if Path[I] = '/' then Path[I] := '\';
      Exit(True);
    end;
  Path := UTF8Decode(Decoded);
  Result := True;
end;

function FileClipPathsToUriList(const Paths: TFileClipPaths; out Data, Err: AnsiString): Boolean;
var
  I: Integer;
  U: AnsiString;
begin
  Data := '';
  Err := '';
  for I := 0 to High(Paths) do
    begin
      if not PathToUri(Paths[I], U) then
        begin Err := 'a path is not absolute'; Data := ''; Exit(False); end;
      Data := Data + U + #13#10;
    end;
  Result := True;
end;

function FileClipUriListToPaths(const Data: AnsiString; out Paths: TFileClipPaths; out Err: AnsiString): Boolean;
var
  Start, I, N: Integer;
  Line: AnsiString;
  P: UnicodeString;
begin
  SetLength(Paths, 0);
  Err := '';
  Result := False;
  Start := 1;
  N := Length(Data);
  while Start <= N + 1 do
    begin
      I := Start;
      while (I <= N) and (Data[I] <> #10) do Inc(I);
      Line := Copy(Data, Start, I - Start);
      if (Line <> '') and (Line[Length(Line)] = #13) then Delete(Line, Length(Line), 1);
      if (Line <> '') and (Line[1] <> '#') then
        begin
          if not UriToPath(Line, P) then
            begin SetLength(Paths, 0); Err := 'the URI list contains an invalid file URI'; Exit; end;
          SetLength(Paths, Length(Paths) + 1);
          Paths[High(Paths)] := P;
        end;
      if I > N then Break;
      Start := I + 1;
    end;
  Result := True;
end;

function FileClipPathsToDrop(const Paths: TFileClipPaths; out Drop: UnicodeString; out Err: AnsiString): Boolean;
var
  I: Integer;
begin
  Drop := '';
  Err := '';
  for I := 0 to High(Paths) do
    begin
      if not (IsDrivePath(Paths[I]) or IsUncPath(Paths[I])) then
        begin Drop := ''; Err := 'a drop path is not an absolute drive or UNC path'; Exit(False); end;
      Drop := Drop + Paths[I] + #0;
    end;
  Drop := Drop + #0;
  Result := True;
end;

function FileClipDropToPaths(const Drop: UnicodeString; out Paths: TFileClipPaths; out Err: AnsiString): Boolean;
var
  Start, I, N: Integer;
begin
  SetLength(Paths, 0);
  Err := '';
  Result := False;
  N := Length(Drop);
  if (N < 2) or (Drop[N] <> #0) or (Drop[N - 1] <> #0) then
    begin Err := 'the drop list is truncated'; Exit; end;
  Start := 1;
  while Start < N do
    begin
      I := Start;
      while (I <= N) and (Drop[I] <> #0) do Inc(I);
      if I = Start then
        begin
          if I <> N - 1 then begin Err := 'the drop list has an empty path'; SetLength(Paths, 0); Exit; end;
          Break;
        end;
      if not (IsDrivePath(Copy(Drop, Start, I - Start)) or IsUncPath(Copy(Drop, Start, I - Start))) then
        begin Err := 'the drop list contains a non-absolute path'; SetLength(Paths, 0); Exit; end;
      SetLength(Paths, Length(Paths) + 1);
      Paths[High(Paths)] := Copy(Drop, Start, I - Start);
      Start := I + 1;
    end;
  Result := True;
end;

end.
