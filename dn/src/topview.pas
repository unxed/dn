unit topview;

interface

uses
  Views, Streams, Drivers
  ;

type
  TTopView = class;
  PTopView = TTopView;
  {`2 Базовый тип для текста, выводимого в заголовке панели. }
  TTopView = class(TView)
    Panel: PView; //фактически -  PFilePanel
    constructor Load(S: TStream);
    procedure Store(S: TStream); override;
    procedure Draw; override;
      {` Текст центрируется, не перекрывая элемент управления окна
      менеджера `}
    function GetPalette: TPalette; override;
    function GetText(MaxWidth: Integer): String; virtual;
      {` Этот метод обязательно должен быть перекрыт `}
    end;
  {`}

  TSortView = class;
  PSortView = TSortView;
    {`2 Индикация текущей сортировки панели буковкой в левом верхнем углу `}
  TSortView = class(TView)
    Panel: PView; //фактически -  PFilePanel;
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
  Right := PDoubleWindow(Owner).Panel[pRight].AnyPanel = Panel;
  Width := Panel.Size.X - 4 - Ord(Right);
    {4 - это ширина элемента управления (номера окна в левой панели
     и кнопки максимизации в правой панели. Для правой панели ещё
     один символ - это пробел между индикатором сортировки и TopView }
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
    Inc(R.A.X, D) { пока можно, центрируем без учёта асимметрии }
  else if Right then { правая панель, прижимаем к кнопке максимизации }
    inc(R.A.X, Width - StrCols(S) + 1)
  else { левая панель, прижимаем к номеру окна }
    inc(R.A.X, 4);
  R.B.X := R.A.X + StrCols(S);
  GetBounds(OldR);
  if not MemEqual(R, OldR, SizeOf(R)) then
    begin
    Locate(R); { Тут будет рекурсия, поэтому второй раз рисовать не надо }
    Exit;
    end;
  C := GetColorW(1);
  if not Panel.GetState(sfSelected) then
    C := GetColorW(2);
  MoveChar(B, ' ', C, Size.X);
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

procedure TSortView.Draw;
  var
    B: Word;
    C: Char;
    R: TRect;
    SortSetup: ^TPanelSortSetup;
  begin
  if (Size.X <> 1) or (Size.Y <> 1) then
    begin
    GetBounds(R);
    R.B.X := R.A.X;
    Dec(R.A.X);
    R.B.Y := R.A.Y + 1;
    Locate(R); // тут будет рекурсия, которая и нарисует
    Exit;
    end;
  SortSetup := @PFilePanelRoot(Panel)^.PanSetup^.Sort;
  C := GetString(dlSortTag)[SortSetup^.SortMode + 1];
  if (SortSetup^.SortFlags and psfInverted) <> 0  then
    C := Upcase(C);
  MoveChar(B, C, Panel.Owner.GetColorW(3), 1);
  WriteLineW(0, 0, 1, 1, B);
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
