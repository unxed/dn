{ The unit StrView of DN: a view with two lines of text (the information of a dialog: TDStringView). }
unit StrView;

{$mode objfpc}{$H-}

interface

uses
  TvViews, Drivers, Views;

type

  TDStringView = class(TView)
    S1, S2: String[50];
    function GetPalette: TPalette; override;
    procedure Draw; override;
  end;

implementation

procedure TDStringView.Draw;
var
  B: TDrawBuffer;
  C: Byte;
begin
  C := Byte(GetColorW(1));
  MoveChar(B[0], ' ', C, Size.X);
  MoveStr(B[0], S1, C);
  WriteLineC(0, 0, Size.X, 1, B);
  MoveChar(B[0], ' ', C, Size.X);
  MoveStr(B[0], S2, C);
  WriteLineC(0, 1, Size.X, 1, B);
end;

function TDStringView.GetPalette: TPalette;
begin
  Result := MakePalette(#30);
end;

end.
