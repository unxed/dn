{ The unit StrView of DN: a view with two lines of text (the information of a dialog: TDStringView), over tv/. }
unit StrView;

{$mode objfpc}{$H-}

interface

uses
  TvViews, Drivers, Views;

type
  PDStringView = ^TDStringView;
  TDStringView = object(TView)
    S1, S2: String[50];
    function GetPalette: TPalette; virtual;
    procedure Draw; virtual;
  end;

implementation

procedure TDStringView.Draw;
var
  B: TDrawBuffer;
  C: Byte;
begin
  C := Byte(GetColorW(1));
  MoveChar(B, ' ', C, Size.X);
  MoveStr(B, S1, C);
  WriteLineW(0, 0, Size.X, 1, B);
  MoveChar(B, ' ', C, Size.X);
  MoveStr(B, S2, C);
  WriteLineW(0, 1, Size.X, 1, B);
end;

function TDStringView.GetPalette: TPalette;
begin
  Result := MakePalette(#30);
end;

end.
