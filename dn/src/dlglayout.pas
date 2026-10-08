{ The dialogs of the resources of DN (dn.dnr, compiled by rcp) can be resized: TResDialog has the resize corner and
  gives its controls grow modes (TView.GrowMode of tv3) by a layout rule when it is shown:
    - input lines (and the classes given to RegisterStretch) stretch to the right, list views stretch to the right and
      down; of several in one row only the rightmost stretches, of several in one column only the lowest;
    - a view to the right of a view that stretches or moves (in the rows it covers) moves with the right edge, a view
      below a view that stretches down moves with the bottom edge;
    - buttons move with the right edge unless something that stretches is to the right of them;
    - the scroll bars of a list view follow the list view.
  A control with a grow mode in the resource (GROW, gfExplicit in the stream) keeps it. The dialog grows only in the
  directions where something stretches (or as RESIZE of the resource says) and never below the size it is shown with.
  The format of the resources: docs/RESOURCES.md.

  MIT, see LICENSE. }
{$I STDEFINE.INC}
unit DlgLayout;

interface

uses
  TvGeom, TvObjs, TvViews, TvWindow, TvDialog;

const
  { a bit of TView.GrowMode in the resource stream only: the grow mode was given by the resource (GROW); TResDialog.Load
    takes it off }
  gfExplicit = $80;
  { TResDialog.Resize: the directions the dialog may grow in; rzAuto = as the layout finds }
  rzNone = 0;
  rzX = 1;
  rzY = 2;
  rzXY = 3;
  rzAuto = $FF;

type
  TResDialog = class(TDialog)
    Resize: Byte;
    constructor Create(const Bounds: TRect; const ATitle: ShortString);
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure SizeLimits(out Min, Max: TPoint); override;
    { gives the controls their grow modes; called once, when the dialog is first inserted }
    procedure Layout;
  private
    FLaidOut: Boolean;
    FMinSize: TPoint;
    FGrowX, FGrowY: Boolean;
    FExplicit: array of TView;
    function IsExplicit(P: TView): Boolean;
  end;

{ views of class C (and its descendants) stretch: X to the right, Y down }
procedure RegisterStretch(C: TClass; X, Y: Boolean);

implementation

uses
  TvInput, TvList;

type
  TStretchClass = record
    C: TClass;
    X, Y: Boolean;
  end;

var
  StretchClasses: array of TStretchClass;

procedure RegisterStretch(C: TClass; X, Y: Boolean);
var
  N: Integer;
begin
  N := Length(StretchClasses);
  SetLength(StretchClasses, N + 1);
  StretchClasses[N].C := C;
  StretchClasses[N].X := X;
  StretchClasses[N].Y := Y;
end;

function CanStretch(P: TView; Vertical: Boolean): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(StretchClasses) do
    if P.InheritsFrom(StretchClasses[I].C) then
      if Vertical then
        Result := Result or StretchClasses[I].Y
      else
        Result := Result or StretchClasses[I].X;
  if Vertical then
    Result := Result and (P.Size.Y >= 3)
  else
    Result := Result and (P.Size.X >= 3);
end;

constructor TResDialog.Create(const Bounds: TRect; const ATitle: ShortString);
begin
  inherited Create(Bounds, ATitle);
  Flags := Flags or wfGrow;
  Resize := rzAuto;
end;

constructor TResDialog.Load(S: TStream);
var
  P: TView;
  N: Integer;
begin
  inherited Load(S);
  S.Read(Resize, SizeOf(Resize));
  N := 0;
  P := First;
  while P <> nil do
  begin
    if (P.GrowMode and gfExplicit) <> 0 then
    begin
      P.GrowMode := P.GrowMode and not gfExplicit;
      SetLength(FExplicit, N + 1);
      FExplicit[N] := P;
      Inc(N);
    end;
    P := P.NextView;
  end;
end;

procedure TResDialog.Store(S: TStream);
begin
  inherited Store(S);
  S.Write(Resize, SizeOf(Resize));
end;

function TResDialog.IsExplicit(P: TView): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(FExplicit) do
    if FExplicit[I] = P then
      Exit(True);
end;

procedure TResDialog.SetState(AState: Word; Enable: Boolean);
begin
  if Enable and not FLaidOut and (Owner <> nil) and ((AState and (sfExposed or sfSelected)) <> 0) then
    Layout;
  inherited SetState(AState, Enable);
end;

procedure TResDialog.SizeLimits(out Min, Max: TPoint);
begin
  inherited SizeLimits(Min, Max);
  if not FLaidOut then
    Exit;
  Min := FMinSize;
  if not FGrowX then
    Max.X := FMinSize.X;
  if not FGrowY then
    Max.Y := FMinSize.Y;
end;

const
  mStay = 0;
  mMove = 1;
  mStretch = 2;

type
  TItem = record
    V: TView;
    R: TRect;
    Fixed: Boolean;
    CX, CY: Boolean;       { may stretch }
    MX, MY: Byte;          { mStay, mMove, mStretch }
  end;

procedure TResDialog.Layout;
var
  It: array of TItem;
  N, I, J: Integer;
  P: TView;
  Changed: Boolean;

  function RowsMeet(const A, B: TRect): Boolean;
  begin
    Result := (A.A.Y < B.B.Y) and (B.A.Y < A.B.Y);
  end;

  function IndexOfView(V: TView): Integer;
  var
    K: Integer;
  begin
    for K := 0 to N - 1 do
      if It[K].V = V then
        Exit(K);
    Result := -1;
  end;

  function ModeOf(Lo, Hi: Byte): Byte;
  begin
    if (Hi <> 0) and (Lo <> 0) then
      Result := mMove
    else if Hi <> 0 then
      Result := mStretch
    else
      Result := mStay;
  end;

  function Bits(M: Byte; Lo, Hi: Byte): Byte;
  begin
    case M of
      mMove: Result := Lo or Hi;
      mStretch: Result := Hi;
    else
      Result := 0;
    end;
  end;

  procedure FollowList(L: TListViewer);
  var
    K, S: Integer;
  begin
    K := IndexOfView(L);
    if K < 0 then
      Exit;
    S := IndexOfView(L.VScrollBar);
    if (S >= 0) and not It[S].Fixed then
    begin
      if It[K].MX = mStay then It[S].MX := mStay else It[S].MX := mMove;
      It[S].MY := It[K].MY;
    end;
    S := IndexOfView(L.HScrollBar);
    if (S >= 0) and not It[S].Fixed then
    begin
      It[S].MX := It[K].MX;
      if It[K].MY = mStay then It[S].MY := mStay else It[S].MY := mMove;
    end;
  end;

begin
  FLaidOut := True;
  FMinSize := Size;
  N := 0;
  P := First;
  while P <> nil do
  begin
    if (P <> Frame) and (P.Size.X > 0) and (P.Size.Y > 0) then
    begin
      SetLength(It, N + 1);
      It[N].V := P;
      It[N].R := P.GetBounds;
      It[N].Fixed := IsExplicit(P);
      if It[N].Fixed then
      begin
        It[N].CX := False;
        It[N].CY := False;
        It[N].MX := ModeOf(P.GrowMode and gfGrowLoX, P.GrowMode and gfGrowHiX);
        It[N].MY := ModeOf(P.GrowMode and gfGrowLoY, P.GrowMode and gfGrowHiY);
      end
      else
      begin
        It[N].CX := CanStretch(P, False);
        It[N].CY := CanStretch(P, True);
        It[N].MX := mStay;
        It[N].MY := mStay;
      end;
      Inc(N);
    end;
    P := P.NextView;
  end;

  { across: the rightmost candidate of its rows stretches }
  for I := 0 to N - 1 do
    if It[I].CX then
    begin
      It[I].MX := mStretch;
      for J := 0 to N - 1 do
        if (J <> I) and (It[J].CX or (It[J].MX = mStretch)) and RowsMeet(It[I].R, It[J].R) and
          (It[J].R.A.X >= It[I].R.B.X) then
          It[I].MX := mStay;
    end;
  { buttons go with the right edge unless something to the right of them stretches }
  for I := 0 to N - 1 do
    if not It[I].Fixed and (It[I].V is TButton) then
    begin
      It[I].MX := mMove;
      for J := 0 to N - 1 do
        if (It[J].MX = mStretch) and RowsMeet(It[I].R, It[J].R) and (It[J].R.A.X >= It[I].R.B.X) then
          It[I].MX := mStay;
    end;
  { what is to the right of a view that stretches or moves moves }
  repeat
    Changed := False;
    for I := 0 to N - 1 do
      if not It[I].Fixed and (It[I].MX <> mMove) then
        for J := 0 to N - 1 do
          if (J <> I) and (It[J].MX <> mStay) and RowsMeet(It[I].R, It[J].R) and (It[I].R.A.X >= It[J].R.B.X) then
          begin
            It[I].MX := mMove;
            Changed := True;
            Break;
          end;
  until not Changed;

  { down: a candidate with no other candidate below it stretches; what is below it moves }
  for I := 0 to N - 1 do
    if It[I].CY then
    begin
      It[I].MY := mStretch;
      for J := 0 to N - 1 do
        if (J <> I) and (It[J].CY or (It[J].MY = mStretch)) and (It[J].R.A.Y >= It[I].R.B.Y) then
          It[I].MY := mStay;
    end;
  for I := 0 to N - 1 do
    if not It[I].Fixed and (It[I].MY = mStay) then
      for J := 0 to N - 1 do
        if (It[J].MY = mStretch) and (It[I].R.A.Y >= It[J].R.B.Y) then
        begin
          It[I].MY := mMove;
          Break;
        end;

  for I := 0 to N - 1 do
    if It[I].V is TListViewer then
      FollowList(TListViewer(It[I].V));

  FGrowX := False;
  FGrowY := False;
  for I := 0 to N - 1 do
  begin
    FGrowX := FGrowX or (It[I].MX = mStretch);
    FGrowY := FGrowY or (It[I].MY = mStretch);
    if not It[I].Fixed then
      It[I].V.GrowMode := Bits(It[I].MX, gfGrowLoX, gfGrowHiX) or Bits(It[I].MY, gfGrowLoY, gfGrowHiY);
  end;
  if Resize <> rzAuto then
  begin
    FGrowX := (Resize and rzX) <> 0;
    FGrowY := (Resize and rzY) <> 0;
  end;
  if not (FGrowX or FGrowY) then
    Flags := Flags and not wfGrow;
end;

initialization
  RegisterStretch(TInputLine, True, False);
  RegisterStretch(TListViewer, True, True);
end.
