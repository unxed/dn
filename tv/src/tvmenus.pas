{ TvMenus: menus (menu bar, menu box, popup menu).

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/menus.h
    source/tvision/tmnuview.cpp (TMenuItem, TMenu, TMenuView), tmenubar.cpp,
    tmenubox.cpp, tmenupop.cpp, menu.cpp (operator+, replaced by the Pascal functions)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - menus are built with the functions of the Pascal Turbo Vision: NewMenu,
      NewSubMenu, NewItem, NewLine; the key of an item is a key code (Word), kept
      as a normalized TKey; DisposeMenu frees a menu with its submenus;
    - items and menus are records, names are pointers to ShortStrings (nil name =
      separator line);
    - the menu bar and popup menu free their menu in Done, the menu box does not;
    - the status line is built with NewStatusDef and NewStatusKey (Pascal Turbo
      Vision) and frees its definitions in Done; its Hint method returns a
      ShortString;
    - streams are not translated yet. }
unit TvMenus;

{$I tvdefs.inc}

interface

uses
  TvGeom, TvColors, TvCell, TvKeys, TvEvents, TvDrawBuf, TvScreen, TvViews, TvUtil;

type
  PMenu = ^TMenu;
  PMenuItem = ^TMenuItem;

  TMenuItem = record
    Next: PMenuItem;
    Name: PStr;          { nil for a separator line }
    Command: Word;       { 0 for an item with a submenu }
    Disabled: Boolean;
    Key: TKey;
    HelpCtx: Word;
    case Integer of
      0: (Param: PStr);  { the text shown at the right of the item (hot key name) }
      1: (SubMenu: PMenu);
  end;

  TMenu = record
    Items: PMenuItem;
    Default: PMenuItem;
  end;

  PMenuView = ^TMenuView;
  PMenuBar = ^TMenuBar;
  PMenuBox = ^TMenuBox;
  PMenuPopup = ^TMenuPopup;
  PStatusItem = ^TStatusItem;
  PStatusDef = ^TStatusDef;
  PStatusLine = ^TStatusLine;

  { Palette: 1 = normal text, 2 = disabled text, 3 = hot key of normal text,
    4 = selected, 5 = disabled selected, 6 = hot key of selected }
  TMenuView = object(TView)
    ParentMenu: PMenuView;
    Menu: PMenu;
    Current: PMenuItem;
    PutClickEventOnExit: Boolean;
    constructor Init(const Bounds: TRect; AMenu: PMenu; AParent: PMenuView);
    function Execute: Word; virtual;
    function FindItem(const Shortcut: ShortString): PMenuItem;
    function GetItemRect(Item: PMenuItem): TRect; virtual;
    function GetHelpCtx: Word; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function HotKey(Key: TKey): PMenuItem;
    function NewSubView(const Bounds: TRect; AMenu: PMenu;
      AParentMenu: PMenuView): PMenuView; virtual;
  private
    procedure NextItem;
    procedure PrevItem;
    procedure TrackKey(FindNext: Boolean);
    function MouseInOwner(var E: TEvent): Boolean;
    function MouseInMenus(var E: TEvent): Boolean;
    procedure TrackMouse(var E: TEvent; var MouseActive: Boolean);
    function TopMenu: PMenuView;
    function UpdateMenu(AMenu: PMenu): Boolean;
    procedure DoASelect(var Event: TEvent);
    function FindHotKey(P: PMenuItem; Key: TKey): PMenuItem;
    function FindAltShortcut(const Event: TEvent): PMenuItem;
  end;

  TMenuBar = object(TMenuView)
    constructor Init(const Bounds: TRect; AMenu: PMenu);
    destructor Done; virtual;
    procedure Draw; virtual;
    function GetItemRect(Item: PMenuItem): TRect; virtual;
  end;

  TMenuBox = object(TMenuView)
    constructor Init(const Bounds: TRect; AMenu: PMenu; AParentMenu: PMenuView);
    procedure Draw; virtual;
    function GetItemRect(Item: PMenuItem): TRect; virtual;
  private
    procedure FrameLine(var B: TDrawBuffer; N: Integer; const CNormal, Color: TColorAttr);
  end;

  TMenuPopup = object(TMenuBox)
    constructor Init(const Bounds: TRect; AMenu: PMenu; AParentMenu: PMenuView);
    destructor Done; virtual;
    function Execute: Word; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  TStatusItem = record
    Next: PStatusItem;
    Text: PStr;
    Key: TKey;
    Command: Word;
  end;

  { the items shown for the help contexts Min..Max }
  TStatusDef = record
    Next: PStatusDef;
    Min, Max: Word;
    Items: PStatusItem;
  end;

  { Palette: 1 = normal text, 2 = disabled text, 3 = hot key of normal text,
    4 = selected, 5 = disabled selected, 6 = hot key of selected }
  TStatusLine = object(TView)
    Items: PStatusItem;
    Defs: PStatusDef;
    constructor Init(const Bounds: TRect; ADefs: PStatusDef);
    destructor Done; virtual;
    procedure Draw; virtual;
    function GetPalette: TPalette; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    function Hint(AHelpCtx: Word): ShortString; virtual;
    procedure Update;
  private
    procedure DrawSelect(Selected: PStatusItem);
    procedure FindItems;
    function ItemMouseIsIn(Mouse: TPoint): PStatusItem;
  end;

function NewMenu(Items: PMenuItem): PMenu;
function NewSubMenu(const Name: ShortString; AHelpCtx: Word; SubMenu: PMenu;
  Next: PMenuItem): PMenuItem;
function NewItem(const Name, Param: ShortString; AKeyCode, ACommand, AHelpCtx: Word;
  Next: PMenuItem): PMenuItem;
function NewLine(Next: PMenuItem): PMenuItem;
{ Frees a menu, its items and submenus. }
procedure DisposeMenu(Menu: PMenu);

function NewStatusKey(const AText: ShortString; AKeyCode, ACommand: Word;
  ANext: PStatusItem): PStatusItem;
function NewStatusDef(AMin, AMax: Word; AItems: PStatusItem; ANext: PStatusDef): PStatusDef;

implementation

{ --- menu data --------------------------------------------------------------- }

function NewMenu(Items: PMenuItem): PMenu;
begin
  New(Result);
  Result^.Items := Items;
  Result^.Default := Items;
end;

function NewSubMenu(const Name: ShortString; AHelpCtx: Word; SubMenu: PMenu;
  Next: PMenuItem): PMenuItem;
begin
  New(Result);
  Result^.Next := Next;
  Result^.Name := NewStr(Name);
  Result^.Command := 0;
  Result^.Disabled := not CommandEnabled(0);
  Result^.Key := KeyMake(kbNoKey);
  Result^.HelpCtx := AHelpCtx;
  Result^.SubMenu := SubMenu;
end;

function NewItem(const Name, Param: ShortString; AKeyCode, ACommand, AHelpCtx: Word;
  Next: PMenuItem): PMenuItem;
begin
  New(Result);
  Result^.Next := Next;
  Result^.Name := NewStr(Name);
  Result^.Command := ACommand;
  Result^.Disabled := not CommandEnabled(ACommand);
  Result^.Key := KeyMake(AKeyCode);
  Result^.HelpCtx := AHelpCtx;
  if Param = '' then
    Result^.Param := nil
  else
    Result^.Param := NewStr(Param);
end;

function NewLine(Next: PMenuItem): PMenuItem;
begin
  New(Result);
  Result^.Next := Next;
  Result^.Name := nil;
  Result^.Command := 0;
  Result^.Disabled := True;
  Result^.Key := KeyMake(kbNoKey);
  Result^.HelpCtx := hcNoContext;
  Result^.Param := nil;
end;

procedure DisposeMenu(Menu: PMenu);
var
  P, T: PMenuItem;
begin
  if Menu = nil then
    Exit;
  P := Menu^.Items;
  while P <> nil do
  begin
    T := P;
    P := P^.Next;
    if T^.Name <> nil then
    begin
      DisposeStr(T^.Name);
      if T^.Command = 0 then
        DisposeMenu(T^.SubMenu)
      else
        DisposeStr(T^.Param);
    end;
    Dispose(T);
  end;
  Dispose(Menu);
end;

{ --- TMenuView --------------------------------------------------------------- }

const
  MenuViewPalette = #2#3#4#5#6#7;

type
  TMenuAction = (doNothing, doSelect, doReturn);

constructor TMenuView.Init(const Bounds: TRect; AMenu: PMenu; AParent: PMenuView);
begin
  inherited Init(Bounds);
  ParentMenu := AParent;
  Menu := AMenu;
  Current := nil;
  PutClickEventOnExit := True;
  EventMask := EventMask or evBroadcast;
end;

procedure TMenuView.TrackMouse(var E: TEvent; var MouseActive: Boolean);
var
  Mouse: TPoint;
  R: TRect;
begin
  Mouse := MakeLocal(E.Where);
  Current := Menu^.Items;
  while Current <> nil do
  begin
    R := GetItemRect(Current);
    if R.Contains(Mouse) then
    begin
      MouseActive := True;
      Exit;
    end;
    Current := Current^.Next;
  end;
end;

procedure TMenuView.NextItem;
begin
  Current := Current^.Next;
  if Current = nil then
    Current := Menu^.Items;
end;

procedure TMenuView.PrevItem;
var
  P: PMenuItem;
begin
  P := Current;
  if P = Menu^.Items then
    P := nil;
  repeat
    NextItem;
  until Current^.Next = P;
end;

procedure TMenuView.TrackKey(FindNext: Boolean);
begin
  if Current = nil then
  begin
    Current := Menu^.Items;
    if not FindNext then
      PrevItem;
    if Current^.Name <> nil then
      Exit;
  end;
  repeat
    if FindNext then
      NextItem
    else
      PrevItem;
  until Current^.Name <> nil;
end;

function TMenuView.MouseInOwner(var E: TEvent): Boolean;
var
  Mouse: TPoint;
  R: TRect;
begin
  if ParentMenu = nil then
    Result := False
  else
  begin
    Mouse := ParentMenu^.MakeLocal(E.Where);
    R := ParentMenu^.GetItemRect(ParentMenu^.Current);
    Result := R.Contains(Mouse);
  end;
end;

function TMenuView.MouseInMenus(var E: TEvent): Boolean;
var
  P: PMenuView;
begin
  P := ParentMenu;
  while (P <> nil) and not P^.MouseInView(E.Where) do
    P := P^.ParentMenu;
  Result := P <> nil;
end;

function TMenuView.TopMenu: PMenuView;
var
  P: PMenuView;
begin
  P := @Self;
  while P^.ParentMenu <> nil do
    P := P^.ParentMenu;
  Result := P;
end;

function TMenuView.Execute: Word;
var
  AutoSelect, FirstEvent, MouseActive: Boolean;
  Action: TMenuAction;
  Res: Word;
  ItemShown, P, LastTargetItem: PMenuItem;
  Target: PMenuView;
  R: TRect;
  E: TEvent;
begin
  AutoSelect := False;
  FirstEvent := True;
  Res := 0;
  ItemShown := nil;
  LastTargetItem := nil;
  Current := Menu^.Default;
  MouseActive := False;
  repeat
    Action := doNothing;
    GetEvent(E);
    case E.What of
      evMouseDown:
        if MouseInView(E.Where) or MouseInOwner(E) then
        begin
          TrackMouse(E, MouseActive);
          { AutoSelect makes it possible to open the selected submenu directly on a
            MouseDown event. This is avoided when the submenu was just closed by
            clicking on its name, or when this is not a menu bar. }
          if Size.Y = 1 then
            AutoSelect := (Current = nil) or (LastTargetItem <> Current)
          { A submenu closes if the MouseDown takes place on the parent menu,
            except when this submenu has just been opened. }
          else if (not FirstEvent) and MouseInOwner(E) then
            Action := doReturn;
        end
        else
        begin
          { a click outside closes the menu; let the event reach the view that
            recovers the focus }
          if PutClickEventOnExit then
            PutEvent(E);
          Action := doReturn;
        end;
      evMouseUp:
        begin
          TrackMouse(E, MouseActive);
          if MouseInOwner(E) then
            Current := Menu^.Default
          else if Current <> nil then
          begin
            if Current^.Name <> nil then
            begin
              if Current <> LastTargetItem then
                Action := doSelect
              else if Size.Y = 1 then
                { a menu bar entry was closed: exit and stop listening }
                Action := doReturn
              else
              begin
                { MouseUp does not reopen a submenu that was just closed by clicking
                  on its name, but the next one will }
                Action := doNothing;
                LastTargetItem := nil;
              end;
            end;
          end
          else if MouseActive and not MouseInView(E.Where) then
            Action := doReturn
          else if Size.Y <> 1 then
          begin
            { MouseUp inside a box but not on an entry (a margin, a separator):
              the default or the first entry gets highlighted (since TV 2.0) }
            Current := Menu^.Default;
            if Current = nil then
              Current := Menu^.Items;
            Action := doNothing;
          end;
        end;
      evMouseMove:
        if E.Buttons <> 0 then
        begin
          TrackMouse(E, MouseActive);
          if not (MouseInView(E.Where) or MouseInOwner(E)) and MouseInMenus(E) then
            Action := doReturn
          { a menu bar entry closed by clicking on its name stays highlighted until
            MouseUp; dragging to another entry opens that one }
          else if (Size.Y = 1) and MouseActive and (Current <> LastTargetItem) then
            AutoSelect := True;
        end;
      evKeyDown:
        case E.KeyCode of
          kbUp, kbDown:
            if Size.Y <> 1 then
              TrackKey(E.KeyCode = kbDown)
            else if E.KeyCode = kbDown then
              AutoSelect := True;
          kbLeft, kbRight:
            if Size.Y = 1 then
              TrackKey(E.KeyCode = kbRight)
            else if ParentMenu <> nil then
              Action := doReturn;
          kbHome, kbEnd:
            if Size.Y <> 1 then
            begin
              Current := Menu^.Items;
              if E.KeyCode = kbEnd then
                TrackKey(False);
            end;
          kbEnter:
            begin
              if Size.Y = 1 then
                AutoSelect := True;
              Action := doSelect;
            end;
          kbEsc:
            begin
              Action := doReturn;
              if (ParentMenu = nil) or (ParentMenu^.Size.Y <> 1) then
                ClearEvent(E);
            end;
        else
          begin
            Target := @Self;
            if GetAltCharStr(E) <> '' then
            begin
              Target := TopMenu;
              P := Target^.FindAltShortcut(E);
            end
            else
              P := FindItem(EventText(E));
            if P = nil then
            begin
              P := TopMenu^.HotKey(EventKey(E));
              if (P <> nil) and CommandEnabled(P^.Command) then
              begin
                Res := P^.Command;
                Action := doReturn;
              end;
            end
            else if Target = PMenuView(@Self) then
            begin
              if Size.Y = 1 then
                AutoSelect := True;
              Action := doSelect;
              Current := P;
            end
            else if (ParentMenu <> Target) or (ParentMenu^.Current <> P) then
              Action := doReturn;
          end;
        end;
      evCommand:
        if E.Command = cmMenu then
        begin
          AutoSelect := False;
          LastTargetItem := nil;
          if ParentMenu <> nil then
            Action := doReturn;
        end
        else
          Action := doReturn;
    end;

    { a submenu closed by clicking on its name opens again the next time it is
      hovered over }
    if LastTargetItem <> Current then
      LastTargetItem := nil;
    if ItemShown <> Current then
    begin
      ItemShown := Current;
      DrawView;
    end;

    if ((Action = doSelect) or ((Action = doNothing) and AutoSelect)) and
      (Current <> nil) and (Current^.Name <> nil) then
    begin
      if (Current^.Command = 0) and not Current^.Disabled then
      begin
        if (E.What and (evMouseDown or evMouseMove)) <> 0 then
          PutEvent(E);
        R := GetItemRect(Current);
        R.A.X := R.A.X + Origin.X;
        R.A.Y := R.B.Y + Origin.Y;
        R.B := Owner^.Size;
        if Size.Y = 1 then
          Dec(R.A.X);
        Target := TopMenu^.NewSubView(R, Current^.SubMenu, @Self);
        Res := Owner^.ExecView(Target);
        Dispose(Target, Done);
        LastTargetItem := Current;
        Menu^.Default := Current;
      end
      else if Action = doSelect then
        Res := Current^.Command;
    end;

    if (Res <> 0) and CommandEnabled(Res) then
    begin
      Action := doReturn;
      ClearEvent(E);
    end
    else
      Res := 0;
    FirstEvent := False;
  until Action = doReturn;

  if (E.What <> evNothing) and ((ParentMenu <> nil) or (E.What = evCommand)) then
    PutEvent(E);
  if Current <> nil then
  begin
    Menu^.Default := Current;
    Current := nil;
    DrawView;
  end;
  Result := Res;
end;

function TMenuView.FindItem(const Shortcut: ShortString): PMenuItem;
var
  P: PMenuItem;
begin
  P := Menu^.Items;
  while P <> nil do
  begin
    if (P^.Name <> nil) and not P^.Disabled and (HotKeyStr(P^.Name^) <> '') and
      EqualsIgnoreCase(Shortcut, HotKeyStr(P^.Name^)) then
      Exit(P);
    P := P^.Next;
  end;
  Result := nil;
end;

function TMenuView.FindAltShortcut(const Event: TEvent): PMenuItem;
var
  C: Char;
begin
  Result := nil;
  { first the text of the event, then the character of the key code }
  if Event.TextLength > 0 then
    Result := FindItem(GetAltCharStr(Event));
  if Result = nil then
  begin
    C := GetAltChar(Event.KeyCode);
    if C <> #0 then
      Result := FindItem(C);
  end;
end;

function TMenuView.GetItemRect(Item: PMenuItem): TRect;
begin
  Result.Assign(0, 0, 0, 0);
end;

function TMenuView.GetHelpCtx: Word;
var
  C: PMenuView;
begin
  C := @Self;
  while (C <> nil) and ((C^.Current = nil) or (C^.Current^.HelpCtx = hcNoContext) or
    (C^.Current^.Name = nil)) do
    C := C^.ParentMenu;
  if C <> nil then
    Result := C^.Current^.HelpCtx
  else
    Result := HelpCtx;
end;

function TMenuView.GetPalette: TPalette;
begin
  Result := MakePalette(MenuViewPalette);
end;

function TMenuView.UpdateMenu(AMenu: PMenu): Boolean;
var
  P: PMenuItem;
  CommandState: Boolean;
begin
  Result := False;
  if AMenu <> nil then
  begin
    P := AMenu^.Items;
    while P <> nil do
    begin
      if P^.Name <> nil then
      begin
        if P^.Command = 0 then
        begin
          if UpdateMenu(P^.SubMenu) then
            Result := True;
        end
        else
        begin
          CommandState := CommandEnabled(P^.Command);
          if P^.Disabled = CommandState then
          begin
            P^.Disabled := not CommandState;
            Result := True;
          end;
        end;
      end;
      P := P^.Next;
    end;
  end;
end;

procedure TMenuView.DoASelect(var Event: TEvent);
begin
  PutEvent(Event);
  Event.Command := Owner^.ExecView(@Self);
  if (Event.Command <> 0) and CommandEnabled(Event.Command) then
  begin
    Event.What := evCommand;
    Event.InfoPtr := nil;
    PutEvent(Event);
  end;
  ClearEvent(Event);
end;

procedure TMenuView.HandleEvent(var Event: TEvent);
var
  P: PMenuItem;
begin
  if Menu <> nil then
    case Event.What of
      evMouseDown:
        DoASelect(Event);
      evKeyDown:
        if FindAltShortcut(Event) <> nil then
          DoASelect(Event)
        else
        begin
          P := HotKey(EventKey(Event));
          if (P <> nil) and CommandEnabled(P^.Command) then
          begin
            Event.What := evCommand;
            Event.Command := P^.Command;
            Event.InfoPtr := nil;
            PutEvent(Event);
            ClearEvent(Event);
          end;
        end;
      evCommand:
        if Event.Command = cmMenu then
          DoASelect(Event);
      evBroadcast:
        if Event.Command = cmCommandSetChanged then
          if UpdateMenu(Menu) then
            DrawView;
    end;
end;

function TMenuView.FindHotKey(P: PMenuItem; Key: TKey): PMenuItem;
var
  T: PMenuItem;
begin
  while P <> nil do
  begin
    if P^.Name <> nil then
    begin
      if P^.Command = 0 then
      begin
        T := FindHotKey(P^.SubMenu^.Items, Key);
        if T <> nil then
          Exit(T);
      end
      else if (not P^.Disabled) and (P^.Key.Code <> kbNoKey) and KeyEq(P^.Key, Key) then
        Exit(P);
    end;
    P := P^.Next;
  end;
  Result := nil;
end;

function TMenuView.HotKey(Key: TKey): PMenuItem;
begin
  Result := FindHotKey(Menu^.Items, Key);
end;

function TMenuView.NewSubView(const Bounds: TRect; AMenu: PMenu;
  AParentMenu: PMenuView): PMenuView;
var
  B: PMenuBox;
begin
  New(B, Init(Bounds, AMenu, AParentMenu));
  Result := B;
end;

{ --- TMenuBar ---------------------------------------------------------------- }

constructor TMenuBar.Init(const Bounds: TRect; AMenu: PMenu);
begin
  inherited Init(Bounds, AMenu, nil);
  GrowMode := gfGrowHiX;
  Options := Options or ofPreProcess;
end;

destructor TMenuBar.Done;
begin
  DisposeMenu(Menu);
  Menu := nil;
  inherited Done;
end;

procedure TMenuBar.Draw;
var
  Color: TAttrPair;
  X, L: Integer;
  P: PMenuItem;
  B: TDrawBuffer;
  CNormal, CSelect, CNormDisabled, CSelDisabled: TAttrPair;
begin
  CNormal := GetColor($0301);
  CSelect := GetColor($0604);
  CNormDisabled := GetColor($0202);
  CSelDisabled := GetColor($0505);
  B.Init(Size.X);
  B.MoveChar(0, Ord(' '), CNormal.Lo, Size.X);
  if Menu <> nil then
  begin
    X := 1;
    P := Menu^.Items;
    while P <> nil do
    begin
      if P^.Name <> nil then
      begin
        L := CStrLen(P^.Name^);
        if X + L < Size.X then
        begin
          if P^.Disabled then
          begin
            if P = Current then
              Color := CSelDisabled
            else
              Color := CNormDisabled;
          end
          else if P = Current then
            Color := CSelect
          else
            Color := CNormal;
          B.MoveChar(X, Ord(' '), Color.Lo, 1);
          B.MoveCStrS(X + 1, P^.Name^, Color);
          B.MoveChar(X + L + 1, Ord(' '), Color.Lo, 1);
        end;
        Inc(X, L + 2);
      end;
      P := P^.Next;
    end;
  end;
  WriteBufD(0, 0, Size.X, 1, B);
  B.Done;
end;

function TMenuBar.GetItemRect(Item: PMenuItem): TRect;
var
  R: TRect;
  P: PMenuItem;
begin
  R.Assign(1, 0, 1, 1);
  P := Menu^.Items;
  while True do
  begin
    R.A.X := R.B.X;
    if P^.Name <> nil then
      Inc(R.B.X, CStrLen(P^.Name^) + 2);
    if P = Item then
      Exit(R);
    P := P^.Next;
  end;
end;

{ --- TMenuBox ---------------------------------------------------------------- }

const
  { frame pieces of a menu box (CP437): top 0, bottom 5, side 10, separator 15 }
  MenuFrameChars: array[0..19] of Byte = (
    $20, $DA, $C4, $BF, $20, $20, $C0, $C4, $D9, $20,
    $20, $B3, $20, $B3, $20, $20, $C3, $C4, $B4, $20);

function MenuBoxRect(const Bounds: TRect; AMenu: PMenu): TRect;
var
  W, H, L: Integer;
  P: PMenuItem;
begin
  W := 10;
  H := 2;
  if AMenu <> nil then
  begin
    P := AMenu^.Items;
    while P <> nil do
    begin
      if P^.Name <> nil then
      begin
        L := CStrLen(P^.Name^) + 6;
        if P^.Command = 0 then
          Inc(L, 3)
        else if P^.Param <> nil then
          Inc(L, CStrLen(P^.Param^) + 2);
        if L > W then
          W := L;
      end;
      Inc(H);
      P := P^.Next;
    end;
  end;
  Result := Bounds;
  if Result.A.X + W < Result.B.X then
    Result.B.X := Result.A.X + W
  else
    Result.A.X := Result.B.X - W;
  if Result.A.Y + H < Result.B.Y then
    Result.B.Y := Result.A.Y + H
  else
    Result.A.Y := Result.B.Y - H;
end;

constructor TMenuBox.Init(const Bounds: TRect; AMenu: PMenu; AParentMenu: PMenuView);
begin
  inherited Init(MenuBoxRect(Bounds, AMenu), AMenu, AParentMenu);
  State := State or sfShadow;
  Options := Options or ofPreProcess;
end;

procedure TMenuBox.FrameLine(var B: TDrawBuffer; N: Integer; const CNormal, Color: TColorAttr);
begin
  B.MoveBuf(0, @MenuFrameChars[N], CNormal, 2);
  B.MoveChar(2, MenuFrameChars[N + 2], Color, Size.X - 4);
  B.MoveBuf(Size.X - 2, @MenuFrameChars[N + 3], CNormal, 2);
end;

procedure TMenuBox.Draw;
var
  B: TDrawBuffer;
  CNormal, CSelect, CNormDisabled, CSelDisabled, Color: TAttrPair;
  Y: Integer;
  P: PMenuItem;
begin
  B.Init(Size.X);
  CNormal := GetColor($0301);
  CSelect := GetColor($0604);
  CNormDisabled := GetColor($0202);
  CSelDisabled := GetColor($0505);
  Y := 0;
  Color := CNormal;
  FrameLine(B, 0, CNormal.Lo, Color.Lo);
  WriteBufD(0, Y, Size.X, 1, B);
  Inc(Y);
  if Menu <> nil then
  begin
    P := Menu^.Items;
    while P <> nil do
    begin
      Color := CNormal;
      if P^.Name = nil then
        FrameLine(B, 15, CNormal.Lo, Color.Lo)
      else
      begin
        if P^.Disabled then
        begin
          if P = Current then
            Color := CSelDisabled
          else
            Color := CNormDisabled;
        end
        else if P = Current then
          Color := CSelect;
        FrameLine(B, 10, CNormal.Lo, Color.Lo);
        B.MoveCStrS(3, P^.Name^, Color);
        if P^.Command = 0 then
          B.PutChar(Size.X - 4, 16)
        else if P^.Param <> nil then
          B.MoveCStrS(Size.X - 3 - CStrLen(P^.Param^), P^.Param^, Color);
      end;
      WriteBufD(0, Y, Size.X, 1, B);
      Inc(Y);
      P := P^.Next;
    end;
  end;
  Color := CNormal;
  FrameLine(B, 5, CNormal.Lo, Color.Lo);
  WriteBufD(0, Y, Size.X, 1, B);
  B.Done;
end;

function TMenuBox.GetItemRect(Item: PMenuItem): TRect;
var
  Y: Integer;
  P: PMenuItem;
begin
  Y := 1;
  P := Menu^.Items;
  while P <> Item do
  begin
    Inc(Y);
    P := P^.Next;
  end;
  Result.Assign(2, Y, Size.X - 2, Y + 1);
end;

{ --- TMenuPopup -------------------------------------------------------------- }

constructor TMenuPopup.Init(const Bounds: TRect; AMenu: PMenu; AParentMenu: PMenuView);
begin
  inherited Init(Bounds, AMenu, AParentMenu);
  PutClickEventOnExit := False;
end;

destructor TMenuPopup.Done;
begin
  DisposeMenu(Menu);
  Menu := nil;
  inherited Done;
end;

function TMenuPopup.Execute: Word;
begin
  { the default entry is not highlighted: it would look ugly }
  Menu^.Default := nil;
  Result := inherited Execute;
end;

procedure TMenuPopup.HandleEvent(var Event: TEvent);
var
  P: PMenuItem;
  C: Char;
begin
  if Event.What = evKeyDown then
  begin
    C := GetCtrlChar(Event.KeyCode);
    P := FindItem(C);
    if P = nil then
      P := HotKey(EventKey(Event));
    if (P <> nil) and CommandEnabled(P^.Command) then
    begin
      Event.What := evCommand;
      Event.Command := P^.Command;
      Event.InfoPtr := nil;
      PutEvent(Event);
      ClearEvent(Event);
    end
    else if GetAltChar(Event.KeyCode) <> #0 then
      ClearEvent(Event);
  end;
  inherited HandleEvent(Event);
end;

{ --- status line ------------------------------------------------------------- }

const
  { the separator between the items and the hint: CP437 vertical line and a space }
  HintSeparator = #$B3' ';

function NewStatusKey(const AText: ShortString; AKeyCode, ACommand: Word;
  ANext: PStatusItem): PStatusItem;
begin
  New(Result);
  Result^.Next := ANext;
  Result^.Text := NewStr(AText);
  Result^.Key := KeyMake(AKeyCode);
  Result^.Command := ACommand;
end;

function NewStatusDef(AMin, AMax: Word; AItems: PStatusItem; ANext: PStatusDef): PStatusDef;
begin
  New(Result);
  Result^.Next := ANext;
  Result^.Min := AMin;
  Result^.Max := AMax;
  Result^.Items := AItems;
end;

constructor TStatusLine.Init(const Bounds: TRect; ADefs: PStatusDef);
begin
  inherited Init(Bounds);
  Defs := ADefs;
  Options := Options or ofPreProcess;
  EventMask := EventMask or evBroadcast;
  GrowMode := gfGrowLoY or gfGrowHiX or gfGrowHiY;
  FindItems;
end;

destructor TStatusLine.Done;
var
  T: PStatusDef;
  I, TI: PStatusItem;
begin
  while Defs <> nil do
  begin
    T := Defs;
    Defs := Defs^.Next;
    I := T^.Items;
    while I <> nil do
    begin
      TI := I;
      I := I^.Next;
      DisposeStr(TI^.Text);
      Dispose(TI);
    end;
    Dispose(T);
  end;
  Items := nil;
  inherited Done;
end;

procedure TStatusLine.Draw;
begin
  DrawSelect(nil);
end;

procedure TStatusLine.DrawSelect(Selected: PStatusItem);
var
  B: TDrawBuffer;
  Color, CNormal, CSelect, CNormDisabled, CSelDisabled: TAttrPair;
  T: PStatusItem;
  I, L: Integer;
  HintText: ShortString;
begin
  CNormal := GetColor($0301);
  CSelect := GetColor($0604);
  CNormDisabled := GetColor($0202);
  CSelDisabled := GetColor($0505);
  B.Init(Size.X);
  B.MoveChar(0, Ord(' '), CNormal.Lo, Size.X);
  T := Items;
  I := 0;
  while T <> nil do
  begin
    if T^.Text <> nil then
    begin
      L := CStrLen(T^.Text^);
      if I + L < Size.X then
      begin
        if CommandEnabled(T^.Command) then
        begin
          if T = Selected then
            Color := CSelect
          else
            Color := CNormal;
        end
        else if T = Selected then
          Color := CSelDisabled
        else
          Color := CNormDisabled;
        B.MoveChar(I, Ord(' '), Color.Lo, 1);
        B.MoveCStrS(I + 1, T^.Text^, Color);
        B.MoveChar(I + L + 1, Ord(' '), Color.Lo, 1);
      end;
      Inc(I, L + 2);
    end;
    T := T^.Next;
  end;
  if I < Size.X - 2 then
  begin
    HintText := Hint(HelpCtx);
    if HintText <> '' then
    begin
      B.MoveStrS(I, HintSeparator, CNormal.Lo);
      Inc(I, 2);
      B.MoveStrS(I, HintText, CNormal.Lo, Size.X - I);
    end;
  end;
  WriteLineD(0, 0, Size.X, 1, B);
  B.Done;
end;

procedure TStatusLine.FindItems;
var
  P: PStatusDef;
begin
  P := Defs;
  while (P <> nil) and ((HelpCtx < P^.Min) or (HelpCtx > P^.Max)) do
    P := P^.Next;
  if P = nil then
    Items := nil
  else
    Items := P^.Items;
end;

function TStatusLine.GetPalette: TPalette;
begin
  Result := MakePalette(MenuViewPalette);
end;

function TStatusLine.ItemMouseIsIn(Mouse: TPoint): PStatusItem;
var
  I, K: Integer;
  T: PStatusItem;
begin
  Result := nil;
  if Mouse.Y <> 0 then
    Exit;
  I := 0;
  T := Items;
  while T <> nil do
  begin
    if T^.Text <> nil then
    begin
      K := I + CStrLen(T^.Text^) + 2;
      if (Mouse.X >= I) and (Mouse.X < K) then
        Exit(T);
      I := K;
    end;
    T := T^.Next;
  end;
end;

procedure TStatusLine.HandleEvent(var Event: TEvent);
var
  T, Hit: PStatusItem;
  Mouse: TPoint;
begin
  inherited HandleEvent(Event);
  case Event.What of
    evMouseDown:
      begin
        T := nil;
        repeat
          Mouse := MakeLocal(Event.Where);
          Hit := ItemMouseIsIn(Mouse);
          if T <> Hit then
          begin
            T := Hit;
            DrawSelect(T);
          end;
        until not MouseEvent(Event, evMouseMove);
        if (T <> nil) and CommandEnabled(T^.Command) then
        begin
          Event.What := evCommand;
          Event.Command := T^.Command;
          Event.InfoPtr := nil;
          PutEvent(Event);
        end;
        ClearEvent(Event);
        DrawView;
      end;
    evKeyDown:
      if Event.KeyCode <> kbNoKey then
      begin
        T := Items;
        while T <> nil do
        begin
          if KeyEq(EventKey(Event), T^.Key) and CommandEnabled(T^.Command) then
          begin
            Event.What := evCommand;
            Event.Command := T^.Command;
            Event.InfoPtr := nil;
            Exit;
          end;
          T := T^.Next;
        end;
      end;
    evBroadcast:
      if Event.Command = cmCommandSetChanged then
        DrawView;
  end;
end;

function TStatusLine.Hint(AHelpCtx: Word): ShortString;
begin
  Result := '';
end;

procedure TStatusLine.Update;
var
  P: PView;
  H: Word;
begin
  P := TopView;
  if P <> nil then
    H := P^.GetHelpCtx
  else
    H := hcNoContext;
  if HelpCtx <> H then
  begin
    HelpCtx := H;
    FindItems;
    DrawView;
  end;
end;

end.
