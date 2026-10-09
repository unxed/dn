unit topview;

interface

uses
  Views, Streams, Drivers
  ;

type
  TTopView = class;
  {`2 Base type for text shown in the panel title. }
  TTopView = class(TView)
    Panel: TView; //actually TFilePanel
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure Draw; override;
      {` Text is centered without overlapping the manager
      window control `}
    function GetPalette: TPalette; override;
    function GetText(MaxWidth: Integer): String; virtual;
      {` This method must be overridden `}
    end;
  {`}

  TSortView = class;
    {`2 Current panel sort indicated by a letter in the top-left corner `}
  TSortView = class(TView)
    Panel: TView; //actually TFilePanel;
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    end;

implementation

uses
  Defines, panelwin, strutil, DNUtf8, panelroot, Commands, mainapp, panelsetup
  ;

const
  CTopView = #11#12;

constructor TTopView.Load(S: TStream);
  begin
  inherited Load(S);
  GetPeerViewPtr(S, Panel);
  end;

procedure TTopView.Store(S: TStream);
  begin
  inherited Store(S);
  PutPeerViewPtr(S, Panel);
  end;

function TTopView.GetPalette: TPalette;
  const
    S: String[Length(CTopView)] = CTopView;
  begin
  GetPalette := MakePalette(S);
  end;

function TTopView.GetText(MaxWidth: Integer): String;
  begin
  end;

procedure TTopView.Draw;
  var
    C: Word;
    B: TDrawBuffer;
    S: String;
    R, OldR: TRect;
    D: Integer;
    Width: Integer;
    Right: Boolean;
  begin
  Right := TDoubleWindow(Owner).Panel[pRight].AnyPanel = Panel;
  Width := Panel.Size.X - 4 - Ord(Right);
    {4 is the width of the control (window number on the left panel
     and maximize button on the right). For the right panel one more
     character is the space between the sort indicator and TopView }
  if Width < 1 then
    Exit;
  S := GetText(Width);
  if StrCols(S) < Width - 2 then
    S := ' ' + S + ' ';
  R.A := Panel.Origin;
  R.B.Y := R.A.Y;
  Dec(R.A.Y);
  D := (Width - StrCols(S) + 4) div 2;
  if D >= 4 then
    Inc(R.A.X, D) { while possible, center ignoring asymmetry }
  else if Right then { right panel, pin to the maximize button }
    inc(R.A.X, Width - StrCols(S) + 1)
  else { left panel, pin to the window number }
    inc(R.A.X, 4);
  R.B.X := R.A.X + StrCols(S);
  OldR := GetBounds;
  if not MemEqual(R, OldR, SizeOf(R)) then
    begin
    Locate(R); { This will recurse, so do not draw a second time }
    Exit;
    end;
  C := GetColorW(1);
  if not Panel.GetState(sfSelected) then
    C := GetColorW(2);
  MoveChar(B[0], ' ', C, Size.X);
  MoveStr(B[0], S, C);
  WriteLineC(0, 0, Size.X, Size.Y, B);
  end { TTopView.Draw };

{ ---------------------------- TSortView ------------------------------ }

constructor TSortView.Load(S: TStream);
  begin
  inherited Load(S);
  GetPeerViewPtr(S, Panel);
  end;

procedure TSortView.Store(S: TStream);
  begin
  inherited Store(S);
  PutPeerViewPtr(S, Panel);
  end;

{$IFDEF DNUTF8}
{ the bytes of the character of S that starts at P (the sort letters of the language are UTF-8: the Russian ones are two bytes each) }
function SortCharLen(const S: String; P: Integer): Integer;
  begin
  Result := 1;
  if (P < 1) or (P > Length(S)) then
    Exit;
  case Byte(S[P]) of
    $C2..$DF: Result := 2;
    $E0..$EF: Result := 3;
    $F0..$F4: Result := 4;
  end;
  if P+Result-1 > Length(S) then
    Result := 1;
  end;
{$ENDIF}

procedure TSortView.Draw;
  var
{$IFDEF DNUTF8}
    B: TDrawBuffer;
    S, T: String;
    P, N: Integer;
{$ELSE}
    B: Word;
    C: Char;
{$ENDIF}
    R: TRect;
    SortSetup: ^TPanelSortSetup;
  begin
  if (Size.X <> 1) or (Size.Y <> 1) then
    begin
    R := GetBounds;
    R.B.X := R.A.X;
    Dec(R.A.X);
    R.B.Y := R.A.Y + 1;
    Locate(R); // this will recurse and do the draw
    Exit;
    end;
  SortSetup := @TFilePanelRoot(Panel).PanSetup^.Sort;
{$IFDEF DNUTF8}
  S := GetString(dlSortTag);
  P := 1;
  for N := 1 to SortSetup^.SortMode do
    Inc(P, SortCharLen(S, P));
  T := Copy(S, P, SortCharLen(S, P));
  if (SortSetup^.SortFlags and psfInverted) <> 0  then
    Utf8UpStr(T);
  MoveStr(B[0], T, Panel.Owner.GetColorW(3));
  WriteLineC(0, 0, 1, 1, B);
{$ELSE}
  C := GetString(dlSortTag)[SortSetup^.SortMode + 1];
  if (SortSetup^.SortFlags and psfInverted) <> 0  then
    C := Upcase(C);
  MoveChar(B, C, Panel.Owner.GetColorW(3), 1);
  WriteLineW(0, 0, 1, 1, B);
{$ENDIF}
  end;

procedure TSortView.HandleEvent(var Event: TEvent);
  begin
  if Event.What = evMouseDown then
    begin
    ClearEvent(Event);
    Message(Panel, evCommand, {cmPanelSortSetup}cmSortBy, nil);
    end;
  end;

end.
