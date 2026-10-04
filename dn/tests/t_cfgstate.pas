program t_cfgstate;
{ Tests of src/cfgstate.pas (the state of the dialogs in the section [Saved] of dn.ini). }
{$mode objfpc}{$H-}
uses SysUtils, Classes, cfgstate;
{$I dntest.inc}

const
  Ini = 'cfgstate-test.ini';

var
  A, B: array[0..999] of Byte;
  P: Pointer;
  N, I: LongInt;
  T: TStringList;
  S: String;

function Text: String;
var
  L: TStringList;
begin
  L := TStringList.Create;
  L.LoadFromFile(Ini);
  Result := L.Text;
  L.Free;
end;

begin
  { an ini file of the people, with a comment and a section of their own }
  T := TStringList.Create;
  T.Add('[Interface]');
  T.Add('; a comment of a person');
  T.Add('SkipXLatMenu=1');
  T.SaveToFile(Ini);
  T.Free;
  for I := 0 to High(A) do
    A[I] := (I * 7 + 3) and $FF;
  Check(not LoadState(Ini, '', P, N), 'nothing is there before the first save');
  Check(SaveState(Ini, '', A, SizeOf(A)), 'SaveState gives True');
  Check(LoadState(Ini, '', P, N) and (N = SizeOf(A)), 'LoadState gives the size back');
  Move(P^, B, N);
  FreeMem(P, N);
  Check(CompareByte(A, B, SizeOf(A)) = 0, 'the bytes come back as they were');
  S := Text;
  Check((Pos('; a comment of a person', S) > 0) and (Pos('SkipXLatMenu=1', S) > 0), 'the settings and the comments of the people are kept');
  Check(Pos('[Saved]', S) > 0, 'the section is [Saved]');
  { a shorter image replaces the longer one: no old pieces are left }
  Check(SaveState(Ini, '', A, 100), 'a shorter image');
  Check(LoadState(Ini, '', P, N) and (N = 100), 'the size of the shorter image');
  FreeMem(P, N);
  Check(Pos('S0002=', Text) = 0, 'the old pieces are gone');
  { the suffix of DNCFG is another section }
  Check(SaveState(Ini, '2', A, 50) and LoadState(Ini, '2', P, N) and (N = 50), 'DNCFG=2: its own section');
  FreeMem(P, N);
  Check(LoadState(Ini, '', P, N) and (N = 100), 'the first section did not change');
  FreeMem(P, N);
  { a damaged piece: refused }
  T := TStringList.Create;
  T.LoadFromFile(Ini);
  for I := 0 to T.Count - 1 do
    if Copy(T[I], 1, 6) = 'S0000=' then
      T[I] := 'S0000=ZZ';
  T.SaveToFile(Ini);
  T.Free;
  Check(not LoadState(Ini, '', P, N) and (P = nil), 'a damaged piece is not accepted');
  DeleteFile(Ini);
  Finish;
end.
