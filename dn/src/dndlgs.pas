{/////////////////////////////////////////////////////////////////////////
//
//  Dos Navigator Open Source 1.51.08
//  Based on Dos Navigator (C) 1991-99 RIT Research Labs
//
//  This programs is free for commercial and non-commercial use as long as
//  the following conditions are aheared to.
//
//  Copyright remains RIT Research Labs, and as such any Copyright notices
//  in the code are not to be removed. If this package is used in a
//  product, RIT Research Labs should be given attribution as the RIT Research
//  Labs of the parts of the library used. This can be in the form of a textual
//  message at program startup or in documentation (online or textual)
//  provided with the package.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//  1. Redistributions of source code must retain the copyright
//     notice, this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//  3. All advertising materials mentioning features or use of this software
//     must display the following acknowledgement:
//     "Based on Dos Navigator by RIT Research Labs."
//
//  THIS SOFTWARE IS PROVIDED BY RIT RESEARCH LABS "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
//  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  The licence and distribution terms for any publically available
//  version or derivative of this code cannot be changed. i.e. this code
//  cannot simply be copied and put under another distribution licence
//  (including the GNU Public Licence).
//
//////////////////////////////////////////////////////////////////////////}
{$I STDEFINE.INC}

unit DNDlgs;

{ Carved by tools/dn-carve.py from DIALOGS.PAS: the classes TComboBox, THexLine, TParamText, TBookmark, TPage, TPageFrame, TNotepad, TNotepadFrame of Dos Navigator. }

interface

uses
  TvDrawBuf, TvColors, Defines, Streams, Drivers, Views, Menus, Commands, mainapp, strutil, TvDialog, TvCluster, TvUtil, basics, TvGlyphs;

const
  CGrayDialog = #32#33#34#35#36#37#38#39#40#41#42#43#44#45#46#47+
  #48#49#50#51#52#53#54#55#56#57#58#59#60#61#62#63+
  #178#179#128#129#132;
  CDialog = CGrayDialog;
  CComboBox = #35#36;
  COwner: String[Length(CDialog)] = #1#2#3#4#5#6#7#8#9#10 +
           #11#12#13#14#15#16#17#18#19#20 +
           #21#22#23#24#25#26#27#28#29#30+
           #31#32#33#34#35#36#37;

type
  TComboBox = class(TView)
    Selected: Word; // current option number (numbering from 1)
    Count: Word; { do not separate from Selected! See Load,Store}
    Menu: PMenu;
    Items: array[1..10] of PMenuItem; // direct references into the menu
    constructor Create(var Bounds: TRect; AStrings: PSItem);
    procedure BuildMenu(AStrings: PSItem);
    destructor Destroy; override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure Draw; override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    function DataSize: Integer; override;
    procedure GetData(var Rec); override;
    procedure SetData(var Rec); override;
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    end;

  THexLine = class(TView)
    InputLine: TInputLine;
    DeltaX, CurX: Integer;
    Sec: Boolean;
    constructor Create(R: TRect; AInputLine: TInputLine);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure HandleEvent(var Event: TEvent); override;
    procedure Draw; override;
    end;


  TParamText = class(TStaticText)
    {Cat: this type is exposed in the plugin model; change with extreme care!}
    ParamCount: AInt;
    ParamList: Pointer;
    constructor Create(var Bounds: TRect; const AText: String;
        AParamCount: AInt);
    constructor Load(var S: TStream);
    function DataSize: Integer; override;
    procedure GetText(var S: String); override;
    procedure SetData(var Rec); override;
    procedure Store(var S: TStream);
    end;

  TBookmark = class(TLabel)
    {` Notebook page bookmark with TNotepas pages }
    constructor Create(var Bounds: TRect; AText: String; ALink: TView);
    procedure Draw; override;
    procedure FocusLink; virtual;
    end;

  TPage = class(TDialog)
    Bookmark: TBookmark;
    PrevPage: TPage;
      { circular list }
    procedure InitFrame; override;
    procedure HandleEvent(var Event: TEvent); override;
    function GetPalette: TPalette; override;
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    end;

  TPageFrame = class(TView)
    function GetPalette: TPalette; override;
    procedure Draw; override;
    end;

    {<dialogs.001>}
  TNotepad = class(TDialog)
    Page: array[0..9] of TPage;
    BookmarkStart: integer; { X-coordinate of the left bookmark line }
    ActivePage: Integer;
    NumPages: Integer;
    constructor Create(var Bounds: TRect; ATitle: TTitleStr;
      ABookmarkStart: integer);
    function NewPage(const ATitle: String): TPage;
    procedure InitFrame; override;
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure GetData(var Rec); override;
    procedure SetData(var Rec); override;
    end;

  TNotepadFrame = class(TFrame)
    procedure FrameLine(var FrameBuf: TvDrawBuf.TDrawBuffer; Y, N: Integer; Color: TColorAttr); virtual;
    function GetTitleWidth: integer; virtual;
    end;

implementation

constructor TParamText.Create(var Bounds: TRect; const AText: String;
    AParamCount: AInt);
  begin
  inherited Create(Bounds, AText);
  ParamCount := AParamCount;
  end;

constructor TParamText.Load(var S: TStream);
  begin
  inherited Load(S);
  S.Read(ParamCount, SizeOf(AInt));
  end;

function TParamText.DataSize: Integer;
  begin
  { FormatStr consumes pointer-sized parameter slots on 64-bit builds. }
  Result := ParamCount * SizeOf(PtrInt);
  end;

procedure TParamText.GetText(var S: String);
  begin
  S := '';
  if Text <> nil then
    FormatStr(S, Text^, ParamList^);
  end;

procedure TParamText.SetData(var Rec);
  begin
  ParamList := @Rec;
  DrawView;
  end;

procedure TParamText.Store(var S: TStream);
  begin
  inherited Store(S);
  S.Write(ParamCount, SizeOf(AInt));
  end;

{ TLabel }

constructor THexLine.Create(R: TRect; AInputLine: TInputLine);
  begin
  if AInputLine = nil then
    Exit;
  inherited Create(R);
  Options := Options or ofSelectable or ofPostProcess;
  EventMask := $FFFF;
  InputLine := AInputLine;
  end;

constructor THexLine.Load(var S: TStream);
  begin
  inherited Load(S);
  GetPeerViewPtr(S, InputLine);
  end;

procedure THexLine.Store(var S: TStream);
  begin
  inherited Store(S);
  PutPeerViewPtr(S, InputLine);
  end;

procedure THexLine.HandleEvent(var Event: TEvent);
  procedure CE;
    begin
    ClearEvent(Event);
    end;
  procedure CED;
    begin
    CE;
    DrawView;
    InputLine.DrawView
    end;

  var
    S: String;

  begin
  inherited HandleEvent(Event);
  case Event.What of
    evBroadcast:
      if  (Event.Command = cmUpdateHexViews) and
          (Event.InfoPtr = InputLine)
      then
        CED;
    evKeyDown:
      case DNKeyCode(Event) of
        kbBack:
          begin
          if CurX >= 0 then
            if Sec
            then
              begin
              Delete(InputLine.Data^, CurX+1, 1);
              Sec := False;
              end
            else
              begin
              Delete(InputLine.Data^, CurX, 1);
              Dec(CurX);
              Sec := False;
              end;
          CED
          end;
        kbDel:
          begin
          if CurX < Length(InputLine.Data^) then
            begin
            Delete(InputLine.Data^, CurX+1, 1);
            Sec := False;
            end;
          CED
          end;
        kbLeft:
          begin
          if Sec
          then
            Sec := False
          else if CurX > 0 then
            begin
            Dec(CurX);
            Sec := True
            end;
          CED
          end;
        kbRight:
          begin
          if Sec and (CurX < Length(InputLine.Data^)) then
            begin
            Inc(CurX);
            Sec := False
            end
          else
            Sec := True;
          CED
          end;
        kbUp:
          SetDNKeyCode(Event, kbShiftTab);
        kbTab, kbShiftTab, kbESC, kbEnter:
          ;
        else {case}
          case UpCase(Char(Event.CharCode)) of
            '0'..'9', 'A'..'F':
              begin
              if  (CurX = InputLine.MaxLen-1) and Sec then
                begin
                CE;
                Exit
                end;
              S := InputLine.Data^;
              if CurX+1 > Length(S) then
                S := S+#0;
              if Sec then
                S[CurX+1] := Char((Byte(S[CurX+1]) and $F0) or
                           (Pos(UpCase(Char(Event.CharCode)),
                        HexStr)-1))
              else
                S[CurX+1] := Char((Byte(S[CurX+1]) and $F) or
                           (Pos(UpCase(Char(Event.CharCode)),
                        HexStr)-1) shl 4);
              InputLine.Data^:= Copy(S, 1, InputLine.MaxLen);
              InputLine.DrawView;
              if Sec then
                begin
                Inc(CurX);
                Sec := False
                end
              else
                Sec := True;
              CED;
              end;
            else {case}
              if GetState(sfFocused) and (Char(Event.CharCode) > #0) then
                CE;
          end {case};
      end {case};
  end {case};
  end { THexLine.HandleEvent };

procedure THexLine.Draw;
  var
    B: TDrawBuffer;
    S: String;
    C: Word;
  begin
  if CurX > Length(InputLine.Data^) then
    CurX := Length(InputLine.Data^);
  if CurX < 0 then
    CurX := 0;
  if CurX <> InputLine.CurPos then
    if InputLine.GetState(sfSelected) then
      begin
      CurX := InputLine.CurPos;
      Sec := False
      end;
  if DeltaX >= Length(InputLine.Data^) then
    DeltaX := Integer(Length(InputLine.Data^))-1;
  if DeltaX < 0 then
    DeltaX := 0;
  if CurX < DeltaX then
    DeltaX := CurX;
  if 3*(CurX-DeltaX) > Size.X-2 then
    DeltaX := CurX-(Size.X-2) div 3;
  if CurX <> InputLine.CurPos then
    if not InputLine.GetState(sfSelected) then
      begin
      InputLine.CurPos := CurX;
      InputLine.FirstPos := DeltaX;
      InputLine.DrawView
      end;
  C := InputLine.GetColorW(1);
  MoveChar(B[0], ' ', C, Size.X);
  S := Copy(InputLine.Data^, DeltaX+1, MaxStringLength);
  S := Copy(DumpStr(S[1], 0, 16, 0), 12, Length(S)*3);
  SetCursor(1+3*(CurX-DeltaX)+Byte(Sec), 0);
  ShowCursor;
  MoveStr(B[1], Copy(S, 1, Size.X-2), C);
  {-DataCompBoy: This is a temporary code!}
  MoveChar(B[Size.X-1], #32, InputLine.GetColorW(4), 1);
  MoveChar(B[0], #32, InputLine.GetColorW(4), 1);
  {-DataCompBoy}
  WriteLineC(0, 0, Size.X, Size.Y, B);
  end { THexLine.Draw };

{ /------------------ TComboBox ----------------\ }

constructor TComboBox.Create(var Bounds: TRect; AStrings: PSItem);
  begin
  inherited Create(Bounds);
  Options := ofSelectable;
  BuildMenu(AStrings);
  Selected := 1;
  end;

procedure TComboBox.BuildMenu(AStrings: PSItem);
  var
    i: Integer;
    LastItem: PMenuItem;
    Tail: ^PMenuItem;
    PrevSItem: PSItem;
  begin
  Menu := NewMenu(nil);
  Tail := @Menu^.Items;
  Count := 0;
  while AStrings <> nil do
    begin
    Inc(Count);
    LastItem := NewItem(
      CenterStr(Copy(AStrings^.Value^, 1, Size.X-2), Size.X-2),
      '',  kbNoKey, 1600+i, 0, nil);
    Items[Count] := LastItem;
    Tail^ := LastItem;
    Tail := @LastItem.Next;
    DisposeStr(AStrings^.Value);
    PrevSItem := AStrings;
    AStrings := AStrings^.Next;
    Dispose(PrevSItem);
    end;
  end;

destructor TComboBox.Destroy;
  begin
  DisposeMenu(Menu);
  inherited Destroy;
  end;

procedure TComboBox.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  DrawView;
  end;

function TComboBox.GetPalette: TPalette;
  const
    P: String[Length(CComboBox)] = CComboBox;
  begin
  GetPalette := MakePalette(P);
  end;

procedure TComboBox.Draw;
  var
    B: TDrawBuffer;
    C: Byte;
    I: Word;
  begin
  I := 1 + 1*Ord(State and sfFocused <> 0);
  C := GetColorW(I);
  MoveChar(B[0], '[', C, 1);
  MoveChar(B[1], ' ', C, Size.x-2);
  MoveStr(B[1], Items[Selected]^.Name^, C);
  MoveChar(B[Size.x-1], ']', C, Size.x);
  WriteLineC(0, 0, Size.X, Size.Y, B);
  end;


procedure TComboBox.HandleEvent(var Event: TEvent);

  procedure OpenList;
    var
      R: TRect;
      MB: TMenuBox;
      C: Word;
    begin
{ Open the menu-list over the line, aligning the line
with the corresponding menu item. Insert the menu into the application,
because if inserted into the dialog, in some palettes the colors
look very strange.
}
    R.Assign(-2,-Selected,0,0);
    MakeGlobal(R.A, R.A);
    if R.A.Y < 0 then
      begin
      Dec(R.B.Y, R.A.Y);
      R.A.Y := 0;
      end;
    MB := TMenuBox.Create(R, Menu, nil);
    MB.Menu^.Default := Items[Selected];
    MB.ComboBoxPal := True;
    C := Application.ExecView(MB);
    if C <> 0 then
      begin
      Selected := C-1600;
      Draw;
//      Owner.SelectNext(False);
      end;
    ClearEvent(Event);
    end;

  begin
  case Event.What of
    evMouseDown:
      begin
      Select; { Instead of TView.HandleEvent }
      OpenList;
      end;
    evKeyDown:
      case DNKeyCode(Event) of
        kbSpace, kbPgDn:
          begin
          repeat
            Selected := Selected mod Count + 1;
          until (Items[Selected]^.Flags and miDisabled) = 0;
          ClearEvent(Event);
          Draw;
          end;
        kbPgUp:
          begin
          repeat
            if Selected <= 1
              then Selected := Count
                else Selected := Selected - 1;
          until (Items[Selected]^.Flags and miDisabled) = 0;
          ClearEvent(Event);
          Draw;
          end;

        kbAltDown, kbCtrlDown:
          OpenList;
        else
          if (DNKeyCode(Event) and $FF0000 = 0) and (Char(Event.CharCode) > ' ')
          then
            OpenList;
      end {case};
  end {case};
//  inherited HandleEvent nothing more to do }
  end { TComboBox.HandleEvent };

function TComboBox.DataSize: Integer;
  begin
  DataSize := SizeOf(Word);
  end;

procedure TComboBox.GetData(var Rec);
  begin
  Word(Rec) := Selected-1; // compatibility with TRadioButtons
  end;

procedure TComboBox.SetData(var Rec);
  begin
  Selected := Word(Rec)+1; // compatibility with TRadioButtons
  DrawView;
  end;

constructor TComboBox.Load(var S: TStream);
  var
    i: Integer;
    PLastItem: ^PMenuItem;
    LastItem: PMenuItem;
    P: PString;
  begin
  inherited Load(S);
  S.Read(Selected, 2*SizeOf(Word)); // including Count
  Menu := NewMenu(nil);
  PLastItem := @Menu^.Items;
  for i := 1 to Count do
    begin
    P := S.ReadStr;
    LastItem := NewItem(Copy(P^, 1, Size.X-2),
      '',  kbNoKey, 1600+i, 0, nil);
    DisposeStr(P);
    PLastItem^ := LastItem;
    Items[i] := LastItem;
    PLastItem := @PLastItem^.Next;
    end;
  Selected := 1;
  end;

procedure TComboBox.Store(var S: TStream);
  var
    i: Integer;
  begin
  inherited Store(S);
  S.Write(Selected, 2*SizeOf(Selected)); // including Count
  for i := 1 to Count do
    S.WriteStr(Items[i]^.Name);
  end;

{ \------------------ TComboBox ----------------/ }

{ /------------------ TNotepad -----------------\ }

procedure TPage.InitFrame;
  var
    R: TRect;
  begin
  GetExtent(R);
  Frame := TFrame(TPageFrame.Create(R));
  end;

function TPage.GetPalette: TPalette;
  begin
  Result := MakePalette(COwner);
  end;

procedure TPage.HandleEvent(var Event: TEvent);
  var
    i: Integer;
  label
    SelectPage;
  begin
  if (Event.What = evKeyDown) then
    begin
    case DNKeyCode(Event) of
      kbCtrlShiftTab:
       begin
       with TNotepad(Owner) do
         i := ActivePage + NumPages - 1;
       goto SelectPage;
       end;
      kbCtrlTab:
       begin
       with TNotepad(Owner) do
         i := ActivePage + 1;
SelectPage:
       with TNotepad(Owner) do
         begin
         i := i mod NumPages;
         ActivePage := i;
         with Page[i] do
           begin
           Bookmark.MakeFirst;
           Show;
           Select;
           end;
         end;
       ClearEvent(Event);
       Exit;
       end;
    end;
    end {case};
  inherited HandleEvent(Event);
  end {TPage.HandleEvent};

constructor TPage.Load(var S: TStream);
  begin
  inherited Load(S);
  GetPeerViewPtr(S, Bookmark);
  GetPeerViewPtr(S, PrevPage);
  end;

procedure TPage.Store(var S: TStream);
  begin
  inherited Store(S);
  PutPeerViewPtr(S, Bookmark);
  PutPeerViewPtr(S, PrevPage);
  end;

constructor TBookmark.Create(var Bounds: TRect; AText: String; ALink: TView);
  begin
  inherited Create(Bounds, AText, ALink);
  TPage(ALink).Bookmark := Self;
  end;

procedure TBookmark.FocusLink;
  var
   i: integer;
   P: TPage;
  begin
  Owner.Lock;
  Link.Focus;
  MakeFirst;
  with TNotepad(Owner) do
    begin
    ActivePage := 0;
    while Pointer(Page[ActivePage]) <> Pointer(Link) do
      Inc(ActivePage);
    end;
  Owner.UnLock;
  end;

constructor TNotepad.Create(var Bounds: TRect; ATitle: TTitleStr;
     ABookmarkStart: integer);
  begin
  inherited Create(Bounds, ATitle);
  BookmarkStart := ABookmarkStart;
  end;

procedure TNotepad.InitFrame;
  var
    R: TRect;
  begin
  GetExtent(R);
  Frame := TFrame(TNotepadFrame.Create(R));
  end;

function TNotepad.NewPage(const ATitle: String): TPage;
  var
    R: TRect;
  begin
  GetExtent(R);
  R.Grow(-1, -1);
  R.B.X := BookmarkStart;
  Result := TPage.Create(R, '');
  Result.Flags := 0;
  Result.State := Result.State and not sfShadow;
  Page[NumPages] := Result;
  Inc(NumPages);
  Insert(Result);
  R.A.X := BookmarkStart;
  R.B.X := Size.X-1;
  R.A.Y := 2*NumPages - 1;
  R.B.Y := R.A.Y + 3;
  Insert(TBookmark.Create(R, ATitle, Result));
  end {TNotepad.NewPage};

constructor TNotepad.Load(var S: TStream);
  var
    i: Integer;
  const
    L = SizeOf(BookmarkStart) + SizeOf(ActivePage) + SizeOf(NumPages);
  begin
  inherited Load(S);
  S.Read(BookmarkStart, L);
  for i := 0 to NumPages-1 do
    GetSubViewPtr(S, Page[i]);
  Page[0].Bookmark.FocusLink;
  end;

procedure TNotepad.Store(var S: TStream);
  var
    i: Integer;
  const
    L = SizeOf(BookmarkStart) + SizeOf(ActivePage) + SizeOf(NumPages);
  begin
  inherited Store(S);
  S.Write(BookmarkStart, L);
  for i := 0 to NumPages-1 do
    PutSubViewPtr(S, Page[i]);
  S.Write(BookmarkStart, L);
  end;

procedure TNotepad.GetData(var Rec);
  type
    Bytes = array[0..65534] of Byte;
  var
    i, l: Integer;
  begin
  l := 0;
  for i := 0 to NumPages-1 do
    begin
    Page[i].GetData(Bytes(Rec)[l]);
    Inc(l, Page[i].DataSize);
    end;
  end;

procedure TNotepad.SetData(var Rec);
  type
    Bytes = array[0..65534] of Byte;
  var
    i, l: Integer;
  begin
  l := 0;
  for i := 0 to NumPages-1 do
    begin
    Page[i].SetData(Bytes(Rec)[l]);
    Inc(l, Page[i].DataSize);
    end;
  end;

function TNotepadFrame.GetTitleWidth: integer;
  begin
  Result := TNotepad(Owner).BookmarkStart;
  end;

procedure TNotepadFrame.FrameLine(var FrameBuf: TvDrawBuf.TDrawBuffer; Y, N: Integer; Color: TColorAttr);
  var
    BMStart: Integer;
    C: LongWord;
  begin
  inherited FrameLine(FrameBuf, Y, N, Color);
  BMStart := TNotepad(Owner).BookmarkStart;
  if Y = 0 then
    C := glDblDL
  else if Y = Size.Y-1 then
    C := glDblUL
  else
    C := glDblV;
  FrameBuf.MoveGlyph(BMStart, C, Color, 1);
  if Size.X-1 > BMStart then
    FrameBuf.MoveChar(BMStart+1, 32, Color, Size.X-1-BMStart);
  end;

const
  FrameC: array[boolean] of record
       H: LongWord; // horizontal line
       C0,  // upper corners (left and right)
       C1,  // vertical lines
       C2:  // lower corners
         array[1..2] of LongWord;
       end =
    ((H: glLightH; C0: (glVertDblRightSgl, glLightVL); C1: (glDblV, glLightV); C2: (glVertDblRightSgl, glLightUL) ),
     (H: glDblH; C0: (glDblUR, glDblDL); C1: (32, glDblV); C2: (glDblDR, glDblUL) )
    );

procedure TBookmark.Draw;
  var
    B: TDrawBuffer;
    LineColor: Byte;
    TextColor: Word;
    C: LongWord;
  begin
  TextColor := GetColorW($0301);
  LineColor := Owner.GetColorW(2);
  with FrameC[Light] do
    begin
    { Remove burr on the upper-right corner of the upper inactive bookmark }
    if not Light and (Origin.Y = 1) then
      C := glDblDR
    else
      C := C0[2];

    MoveGlyph(B[0], C0[1], LineColor, 1);
    MoveGlyph(B[1], H, LineColor, Size.X-2);
    MoveGlyph(B[Size.X-1], C, LineColor, 1);
    WriteLineC(0, 0, Size.X, 1, B);

    MoveGlyph(B[0], C2[1], LineColor, 1);
    MoveGlyph(B[1], H, LineColor, Size.X-2);
    MoveGlyph(B[Size.X-1], C2[2], LineColor, 1);
    WriteLineC(0, Size.Y-1, Size.X, 1, B);

    MoveChar(B[1], ' ', TextColor, Size.X-2);
    MoveGlyph(B[Size.X-1], C1[2], LineColor, 1);
    if Light then
      TextColor := GetColorW($0402);
    MoveGlyph(B[0], C1[1], LineColor, 1);
    MoveCStr(B[1], Text^, TextColor);
    WriteLineC(0, 1, Size.X, 1, B);
    end;
  end;

function TPageFrame.GetPalette: TPalette;
  begin
  Result := MakePalette(COwner);
  end;

procedure TPageFrame.Draw;
  var
    i: integer;
    B: TDrawBuffer;
  begin
  MoveChar(B[0], ' ', GetColorW(1), Size.X);
  for i := 0 to Size.Y-1 do
    WriteLineC(0, i, Size.X, 1, B);
  end;

{ \------------------ TNotepad -----------------/ }

end.
