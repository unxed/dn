{ TvClip: the clipboard of the program: text in UTF-8, an internal buffer, and hooks for
  the system clipboard of a backend (WinOldAp under DOS, OSC 52 or a library elsewhere).

  Written for this port (the original has TClipboard in system.h for this).

  ClipboardSetText keeps the text in the internal buffer and passes it to the system
  clipboard if the backend has one. ClipboardGetText asks the system clipboard first;
  when it has no text (or there is none) the internal buffer is returned, so that cut and
  paste work inside the program everywhere. }
unit TvClip;

{$I tvdefs.inc}
{$H+}

interface

uses
  TvCodePg, TvUtf8;

type
  TClipSetHook = function(const Text: AnsiString): Boolean;
  TClipGetHook = function(out Text: AnsiString): Boolean;

var
  { set by a backend that has a system clipboard; Set returns False when it failed }
  OnClipboardSet: TClipSetHook = nil;
  OnClipboardGet: TClipGetHook = nil;

procedure ClipboardSetText(const Text: AnsiString);
function ClipboardGetText: AnsiString;
{ True if the last ClipboardSetText reached the system clipboard. }
function ClipboardIsSystem: Boolean;

{ Conversions for backends whose clipboard is in the OEM code page (the current page of
  TvCodePg): UTF-8 -> bytes ('?' for what the page does not have) and back; bytes that
  are valid UTF-8 already are not touched by OemToUtf8 only if AllowUtf8 is set. }
function Utf8ToOem(const S: AnsiString): AnsiString;
function OemToUtf8(const S: AnsiString): AnsiString;
{ Every line break becomes CR LF (a lone LF or a lone CR too). }
function ToCrLf(const S: AnsiString): AnsiString;
{ Every line break becomes LF. }
function ToLf(const S: AnsiString): AnsiString;

implementation

var
  Internal: AnsiString = '';
  LastWasSystem: Boolean = False;

procedure ClipboardSetText(const Text: AnsiString);
begin
  Internal := Text;
  LastWasSystem := False;
  if Assigned(OnClipboardSet) then
    LastWasSystem := OnClipboardSet(Text);
end;

function ClipboardGetText: AnsiString;
var
  T: AnsiString;
begin
  if Assigned(OnClipboardGet) and OnClipboardGet(T) and (T <> '') then
    Exit(T);
  Result := Internal;
end;

function ClipboardIsSystem: Boolean;
begin
  Result := LastWasSystem;
end;

function Utf8ToOem(const S: AnsiString): AnsiString;
var
  I, Used, N: Integer;
  Cp: LongWord;
  B: Byte;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if Byte(S[I]) < $80 then
    begin
      Inc(N);
      Result[N] := S[I];
      Inc(I);
    end
    else
    begin
      if Utf8Decode(@S[I], Length(S) - I + 1, Cp, Used) then
      begin
        B := CpFromUnicode(Cp);
        if B = 0 then
          B := Ord('?');
        Inc(I, Used);
      end
      else
      begin
        { not UTF-8: the byte is a character of the code page already }
        B := Byte(S[I]);
        Inc(I);
      end;
      Inc(N);
      Result[N] := Chr(B);
    end;
  end;
  SetLength(Result, N);
end;

function OemToUtf8(const S: AnsiString): AnsiString;
var
  I: Integer;
  Buf: array[0..7] of Byte;
  N: Integer;
  T: AnsiString;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if Byte(S[I]) < $80 then
      Result := Result + S[I]
    else
    begin
      N := CpToUtf8(Byte(S[I]), @Buf[0]);
      SetLength(T, N);
      Move(Buf[0], T[1], N);
      Result := Result + T;
    end;
  end;
end;

function ToCrLf(const S: AnsiString): AnsiString;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S) * 2);
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    case S[I] of
      #13:
        begin
          if (I < Length(S)) and (S[I + 1] = #10) then
            Inc(I);
          Inc(N); Result[N] := #13;
          Inc(N); Result[N] := #10;
        end;
      #10:
        begin
          Inc(N); Result[N] := #13;
          Inc(N); Result[N] := #10;
        end;
    else
      Inc(N);
      Result[N] := S[I];
    end;
    Inc(I);
  end;
  SetLength(Result, N);
end;

function ToLf(const S: AnsiString): AnsiString;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = #13 then
    begin
      if (I < Length(S)) and (S[I + 1] = #10) then
        Inc(I);
      Inc(N);
      Result[N] := #10;
    end
    else
    begin
      Inc(N);
      Result[N] := S[I];
    end;
    Inc(I);
  end;
  SetLength(Result, N);
end;

end.
