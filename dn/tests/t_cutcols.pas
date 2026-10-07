program t_cutcols;
{ strutil.CutCols: a field of Width columns; with UTF-8 inside a column is a character (the line below the panel cut the names by bytes: "Privet.txt" lost its extension). }
{$mode objfpc}{$H-}
uses SysUtils, strutil, DNUtf8, TvUtf8;
{$I dntest.inc}

function U(const Codes: array of LongWord): String;
var
  I: Integer;
  Buf: array[0..7] of Byte;
  N, J: Integer;
begin
  Result := '';
  for I := 0 to High(Codes) do
    if Codes[I] < $80 then
      Result := Result + Chr(Codes[I])
    else
    begin
      N := Utf8Encode(Codes[I], @Buf[0]);
      for J := 0 to N - 1 do
        Result := Result + Chr(Buf[J]);
    end;
end;

var
  Name, R: String;
begin
  Name := U([$41, $62, $63, $2E, $74, $78, $74]);               { Abc.txt }
  Check(CutCols(Name, 12, #16) = Name + '     ', 'ASCII fits: padded to the width');
  Check(CutCols(Name, 5, #16) = 'Abc.' + #16, 'ASCII is cut: the last column is the mark');
  { U+041F U+0440 U+0438 U+0432 U+0435 U+0442 . t x t }
  Name := U([$41F, $440, $438, $432, $435, $442, $2E, $74, $78, $74]);
{$IFDEF DNUTF8}
  Check(CutCols(Name, 13, #16) = Name + '   ', 'UTF-8: ten characters fit in 13 columns (they are 16 bytes)');
  R := CutCols(Name, 8, #16);
  Check(StrCols(R) = 8, 'UTF-8: cut to 8 columns');
  Check(R = U([$41F, $440, $438, $432, $435, $442, $2E]) + #16, 'UTF-8: the first seven characters and the mark');
  Check(CutCols(U([$41F, $440]), 2, #16) = U([$41F, $440]), 'UTF-8: two characters fit in two columns');
  Check(CutCols(U([$41F, $440, $438]), 2, #16) = U([$41F]) + #16, 'UTF-8: three characters in two columns: one and the mark');
{$ELSE}
  Check(Length(CutCols(Name, 8, #16)) = 8, 'code page: bytes are columns');
{$ENDIF}
  Finish;
end.
