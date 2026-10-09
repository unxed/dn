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
{AK155 = Alexey Korop, 2:461/155@fidonet}
{$I STDEFINE.INC}

unit CmdLine;

interface

uses
  Drivers, Defines, Views
  ;

type
  TCommandLine = class;
  TCommandLine = class(TView)
    Dir: String;
    DeltaX, CurX: LongInt;
    Overwrite: Boolean;
    LineType: (ltNormal, ltFullScreen, ltWindow, ltTimer);
    constructor Create(const R: TRect);
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure Update; override;
    procedure GetDir;
    procedure GetData(var S); override;
    procedure SetData(var S); override;
    function DataSize: Integer; override;
    procedure SetDirShape;
    procedure QueryCursorVisible; {AK155}
    end;

  (*
     PCmdLine = ^TCmdLine;
     TCmdLine = class(TView)
      procedure Draw; virtual;
     end;

     PCmdWindow = ^TCmdWindow;
     TCmdWindow = class(TWindow)
      constructor Create(const R: TRect);
     end;
*)

const
  Separators = [':', '.', ',', '/', '\', '[', ']', '+', '>', '<', '|',
   ';', ' ', '@', '"'];
  StrModified: Boolean = False;
  DDTimer: LongInt = 0;
  TimerMark: Boolean = False;
  CurString: LongInt = 0;
  CmdDisabled: Boolean = False;
  {     CanProcess:  Boolean = True;}
  HideCommandLine: Boolean = False;
  Str: String = '';
  StrCleared: Boolean = False;

implementation
uses DnPath,
  Dos, Commands, mainapp, Dialogs, basics, strutil, fileutil,
  panelwinx, gadgets, 
  Startup, timeutil, Messages, DNUtil
  , editcore, histories, FViewer, panelroot
  , Idlers 
  , osdep, dnscreen, Lfn, UserMenu, Menus
  , DnIni, Math
  ;

{ The line holds UTF-8 in the build DNUTF8 (a character is 1..4 bytes: the cursor, Backspace, Delete, the scrolling and the mouse go by characters),
  else bytes of the code page (a character is a byte). Not UTF-8 (a byte of the code page that stands alone) is a character of a byte. Wide (double cell)
  characters are counted as one cell: TODO-later.md. }
function CharAt(const S: String; P: Integer): Integer;       { the bytes of the character that starts at P }
  var
    K: Integer;
  begin
  Result := 1;
{$IFDEF DNUTF8}
  if (P < 1) or (P > Length(S)) then
    Exit;
  case Byte(S[P]) of
    $C2..$DF: Result := 2;
    $E0..$EF: Result := 3;
    $F0..$F4: Result := 4;
  end;
  if P+Result-1 > Length(S) then
    Result := 1
  else
    for K := 1 to Result-1 do
      if Byte(S[P+K]) and $C0 <> $80 then
        Result := 1;
{$ENDIF}
  end;

function CharBefore(const S: String; P: Integer): Integer;  { the bytes of the character that ends at P }
  var
    K: Integer;
  begin
  Result := 1;
{$IFDEF DNUTF8}
  K := P;
  while (K > 1) and (P-K < 3) and (Byte(S[K]) and $C0 = $80) do
    Dec(K);
  if (K >= 1) and (CharAt(S, K) = P-K+1) then
    Result := P-K+1;
{$ENDIF}
  end;

function CellsIn(const S: String): Integer;
  var
    I: Integer;
  begin
  Result := 0;
  I := 1;
  while I <= Length(S) do
    begin
    Inc(I, CharAt(S, I));
    Inc(Result);
    end;
  end;

function BytesFor(const S: String; Cells: Integer): Integer; { the bytes of the first Cells characters }
  begin
  Result := 0;
  while (Cells > 0) and (Result < Length(S)) do
    begin
    Inc(Result, CharAt(S, Result+1));
    Dec(Cells);
    end;
  end;

function WholeChars(const S: String): String;                { without a character that is cut at the end }
  var
    I: Integer;
  begin
  I := 1;
  while (I <= Length(S)) and (I+CharAt(S, I)-1 <= Length(S)) do
    Inc(I, CharAt(S, I));
  Result := Copy(S, 1, I-1);
{$IFDEF DNUTF8}
  if (I <= Length(S)) and (Byte(S[I]) and $C0 <> $C0) then
    Result := S;  { not a cut sequence: a stray byte, drawn as it is }
{$ENDIF}
  end;

{ the text of a key: UTF-8 in the build DNUTF8, else the byte of the code page }
function TypedText(const Event: TEvent): String;
  begin
{$IFDEF DNUTF8}
  if (Event.KeyDown.TextLength > 0) and (Byte(Event.KeyDown.Text[0]) >= $80) then
    begin
    SetLength(Result, Min(Event.KeyDown.TextLength, 255));
    Move(Event.KeyDown.Text[0], Result[1], Length(Result));
    Exit;
    end;
{$ENDIF}
  Result := Char(Event.KeyDown.CharScan.CharCode);
  end;

const
  CursorMustBeVisible: Boolean = False;
  PrevCmdLineCursorVisible: Boolean = False;

constructor TCommandLine.Create(const R: TRect);
  begin
  inherited Create(R);
  EventMask := $FFFF;
  Options := Options {or ofSelectable} or ofPostProcess
    or ofFirstClick {or ofTopSelect};
  DragMode := dmDragMove;
  GetDir;
  Str := '';
  DeltaX := 0;
  CurX := 0;
  GrowMode := gfGrowLoY+gfGrowHiX+gfGrowHiY;
  Overwrite := False;
  LineType := ltNormal;
  end;

function TCommandLine.DataSize: Integer;
  begin
  DataSize := SizeOf(String)
  end;

procedure TCommandLine.GetData(var S);
  begin
  String(S) := Str;
  end;
procedure TCommandLine.SetData(var S);
  begin
  Str := String(S);
  DeltaX := 0;
  CurX := 0
  end;

procedure TCommandLine.GetDir;
  var
    MM: record
      case Byte of
        1: (l: LongInt; S: String[1]);
        2: (C: Char);
      end;
    D: TDialog;
  begin
  Inc(SkyEnabled);
  repeat
    Abort := False;
    NeedAbort := True;
    lGetDir(0, Dir); {DataCompBoy}
    if Abort then
      begin
      repeat
        MM.l := 0;
        MM.C := GetCurDrive;
        MM.S := MM.C;
        D := TDialog(LoadResource(dlgDiskError));
        if D <> nil then
          begin
          D.SetData(MM);
          Application.ExecView(D);
          D.GetData(MM);
          D.Free;
          end;
        UpStr(MM.S);
        if ValidDrive(MM.S[1]) then
          Break;
      until False;
      Abort := True;
      end;
  until not Abort;
  Dec(SkyEnabled);
  NeedAbort := False;
  MakeNoSlash(Dir);
  SetDirShape;
  end { TCommandLine.GetDir };

procedure TCommandLine.SetDirShape;
  begin
  TimerMark := LineType = ltTimer;
  if Dir[1] in ['[', '(', '{'] then
    Dir := Copy(Dir, 2, Length(Dir)-2)
  else if Dir[Length(Dir)] = '>' then
    SetLength(Dir, Length(Dir)-1);
  case LineType of
    ltFullScreen:
      Dir := '['+Dir+']';
    ltWindow:
      Dir := '('+Dir+')';
    ltTimer:
      Dir := '{'+Dir+'}';
    else {case}
      Dir := Dir+'>';
  end {case};
  end;

procedure TCommandLine.QueryCursorVisible; {AK155}
  begin
  { The command line can receive one last update while the desktop is
    being torn down.  Do not dereference the global owner in that phase. }
  if Desktop = nil then
    begin
    CursorMustBeVisible := False;
    Exit;
    end;
  CursorMustBeVisible :=
      (State and sfDisabled = 0) and not QuickSearch and
      ( (Desktop.Current = nil)
      or (Desktop.Current is TXDoubleWindow)
      or (Desktop.Current is TUserWindow)
       or (Desktop.Current is TTrashCan) 
      );
  end;

procedure TCommandLine.Update;
  var
    P: TPoint;
    A1, A2: SmallWord;
    //     BB: Boolean;
    CursorStartScanLine, CursorEndScanLine: Integer; //ak155
    CursorVisible: Boolean; //ak155
    CursorMaxY, CursorMinY: Integer;
  const
    OldOverwrite: LongInt = 2;
  begin
  QueryCursorVisible;
  if  (CursorMustBeVisible <> PrevCmdLineCursorVisible)
    { there is work to do }
    and (State and (sfDisabled or sfVisible) <> sfVisible)
    { but do not hide someone else's cursor }
    then
    ResetCursor;
  PrevCmdLineCursorVisible := CursorMustBeVisible;
  if not CursorMustBeVisible then
    Exit;

  { Now make the cursor actually look as required }
  GetCursorXY(A1, A2);
  GetCursorType(CursorStartScanLine, CursorEndScanLine, CursorVisible);
  if
    (SSaver <> nil) or 
      (Size.X = 0) or (Size.Y = 0) or
      (Desktop.GetState(sfActive) and
        (Desktop.Current <> nil) and
        (Desktop.Current.GetState(sfCursorVis) or
        Desktop.Current.GetState(sfModal))) or
    MenuActive
  then
    Exit;
  P.X := CellsIn(Copy(Str, DeltaX+1, CurX-DeltaX))+Min(Length(Dir), 50);
  P.Y := 0;
  P := MakeGlobal(P);
  //AK155  BB := not Overwrite  xor (InterfaceData.Options and ouiBlockInsertCursor <> 0);
  {AK155 cursor-mode setup calls are harmless under OS/2,
but under Win32 cause nasty cursor flicker. So I try
not to call them unless needed. 18.10.2001 }
  if  (OldOverwrite <> Ord(Overwrite)) or not CursorVisible
  then
    begin
    CursorMaxY := Lo(Drivers.CursorLines);
    CursorMinY := 0;
    if not Overwrite then
      CursorMinY := CursorMaxY-1;
    SetCursorType(CursorMinY, CursorMaxY, True);
    OldOverwrite := Ord(Overwrite);
    end;
  if  (A1 <> P.X) or (A2 <> Origin.Y) then
    MoveCursorTo(P.X, Origin.Y);
  {/AK155}
  end { TCommandLine.Update };

procedure TCommandLine.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  if AState and (sfActive or sfFocused) <> 0 then
    begin
    DrawView;
    if Enable then
      EnableCommands(CommandSetOf([cmNext, cmPrev]))
    else
      DisableCommands(CommandSetOf([cmNext, cmPrev]))
    end
  end;

procedure TCommandLine.Draw;
  var
    B: array[0..200] of TScreenCell;
    C1, C2, C3: Word;
    S: ^Str50;
    SW: Integer; { the width of the prompt in columns }
  begin
  if CmdDisabled then
    Exit;
  New(S);
  S^:= (Cut(Copy(Dir, 1,
           Length(Dir)-1), 49)+Dir[Length(Dir)]);
  SW := CStrLen(S^);
  C3 := $0F;
  C1 := $07;
  if Overwrite then
    C2 := $4F
  else
    C2 := $70;
  if CurX < 0 then
    CurX := 0;
  if CurX > Length(Str) then
    CurX := Length(Str);
  if DeltaX > CurX then
    DeltaX := CurX;
  while CellsIn(Copy(Str, DeltaX+1, CurX-DeltaX)) > Size.X-Min(Length(Dir), 50)-1 do
    Inc(DeltaX, CharAt(Str, DeltaX+1));
  MoveChar(B[0], ' ', C1, Size.X);
  MoveStr(B[0], S^, C3);
  MoveStr(B[SW], WholeChars(Copy(Str, DeltaX+1, Size.X-SW)), C1);
  if not MenuActive then
    ShowCursor
  else
    HideCursor;
  if Overwrite xor (InterfaceData.Options and ouiBlockInsertCursor <> 0)
  then
    BlockCursor
  else
    NormalCursor;
  Update;
  WriteLineC(0, 0, Size.X, Size.Y, B);
  Dispose(S)
  end { TCommandLine.Draw };

procedure TCommandLine.HandleEvent(var Event: TEvent);
  procedure CE;
    begin
    ClearEvent(Event)
    end;
  procedure CE2;
    begin
    DrawView;
    ClearEvent(Event)
    end;

  procedure CheckSize;
    begin
    if not GetState(sfVisible) and (Str <> '') then
      begin
      ToggleCommandLine(True);
      end;
    end;

  var
    R: TRect;
    P: TPoint;
    i, l, c, ls: Integer;
    s1: String;
    S, T: String;
    CW: Integer;
    Changed: Boolean;
  label
    EndLFN;
  begin { TCommandLine.HandleEvent }
  inherited HandleEvent(Event);
  if Event.What = evNothing then
    Exit;
  QueryCursorVisible;
  S := Str;
  Changed := False;
  if not CursorMustBeVisible then
    Exit;

  case Event.What of
    evMouseDown, evMouseAuto:
      begin
      if ((Event.Mouse.EventFlags and 2) <> 0) then
        begin
        Message(Application, evCommand, cmHistoryList, nil);
        CE
        end;
      P := MakeLocal(Event.Mouse.Where);
      if P.X >= Min(Length(Dir), 50) then
        if Event.Mouse.Buttons and mbRightButton <> 0 then
          begin
          if P.X < (Size.X-Min(Length(Dir), 50)) div 2
          then
            MessageKey(Self, kbLeft)
          else
            MessageKey(Self, kbRight);
          CE2;
          end
        else
          begin
          CurX := DeltaX+BytesFor(Copy(Str, DeltaX+1, 255), P.X-Min(Length(Dir), 50));
          CE2
          end;
      end;
    evCommand:
      case Event.Message.Command of
        cmRereadInfo:
          begin
          GetDir;
          DrawView;
          Update
          end;
        cmInsertName:
          if InterfaceData.Options and ouiHideCmdline = 0 then
            begin
            S := String(Event.Message.InfoPtr^);
            {AK155: handling long names with spaces.}
            if  (CurX > 0) and not (Str[CurX] in Separators)
              {and not (S[1] = '"')}
              then
              begin
              Insert(' ', Str, CurX+1);
              Inc(CurX)
              end;
            ls := Length(S);
            c := CurX;
            l := Length(Str);
            if  not EndsWithSep(S) and (Copy(S, Length(S)-1, 2) <> DnSep+'"')
            then
              S := S+' ';
            Insert(S, Str, CurX+1);
            Inc(CurX, Length(S));
            if c > 0 then
              begin
              s1 := Copy(Str, c, 2);
              if s1 = '""' then
                begin
                i := c+Length(S)+1;
                while (i <= Length(Str)) and (Str[i] <> '"') do
                  Inc(i);
                if i > Length(Str) then
                  begin
                  Delete(Str, c, 2);
                  Dec(c, 1);
                  Dec(l, 1);
                  Dec(ls, 1);
                  Dec(CurX, 2);
                  end
                else {(Str[i] = '"')}
                  begin
                  Delete(Str, c+ls, 1);
                  Delete(Str, c, 1);
                  Dec(c, 1);
                  Dec(l, 1);
                  Dec(ls, 1);
                  Dec(CurX, 2);
                  goto EndLFN; { so as not to process the end of S}
                  end;
                end
              else if s1 = '\"' then
                begin
                i := c-1;
                while (i >= 1) and (Str[i] <> ' ') do
                  Dec(i);
                Delete(Str, c+1, 1);
                Insert('"', Str, i+1);
                Inc(c);
                Inc(l);
                Dec(ls);
                end
              else if (c > 1) and (Copy(Str, c-1, 2) = '\"') then
                begin
                Delete(Str, c, 1);
                Dec(c);
                Dec(l);
                Insert('"', Str, c+Length(S));
                Inc(ls);
                end;
              end;
            if c <> l then
              begin
              s1 := Copy(Str, c+Length(S), 2);
              if s1 = '""' then
                begin
                Delete(Str, c+Length(S), 2);
                Dec(CurX);
                end
              else if s1 = '\"' then
                begin
                i := c+Length(S)-1;
                while (i > c) and (Str[i] <> ' ') do
                  Dec(i);
                Delete(Str, c+Length(S)+1, 1);
                Insert('"', Str, i+1);
                Inc(c);
                Inc(l);
                Dec(ls);
                end
              else if s1[1] = '"' then
                begin
                i := c+Length(S);
                while (i <= Length(Str)) and (Str[i] <> ' ') do
                  Inc(i);
                Insert('"', Str, i);
                Delete(Str, c+Length(S), 1);
                Dec(CurX);
                end;
              end;
EndLFN:
            {/AK155}
            CE2;
            CheckSize;
            end;
        cmClearCommandLine:
          begin
          Str := '';
          CurX := 0;
          DeltaX := 0;
          CE2
          end;
        cmExecCommandLine:
          if InterfaceData.Options and ouiHideCmdline = 0 then
            begin
            if DelSpaces(Str) = '' then
              Exit;
            {AK155: The Up-Down wobbling that was here caused
the previous history command to be fetched after Ctrl-E
instead of the one just run. Unclear why; I simplified.
RIT Labs DN also wobbled but seemed to fetch correctly.
                         StrModified := True;
                         MessageKey(Self, kbDown);
                         MessageKey(Self, kbUp);
}
            AddCommand(Str);
            CurString := CmdStrings.Count;
            StrModified := False;
            {/AK155}
            end;
      end {case};
    evKeyDown:
      begin
{$IFDEF DNUTF8}
      { a character that the code page of the locale lacks (Russian under en_US.UTF-8) has no CharCode, but it has the text: it is typed like the others (TypedText) }
      if (Event.KeyDown.CharScan.CharCode = 0) and (Event.KeyDown.TextLength > 0) and (Byte(Event.KeyDown.Text[0]) >= $80) and (Event.KeyDown.ControlKeyState and 12 = 0) then
        Event.KeyDown.CharScan.CharCode := $80;
{$ENDIF}
      if InterfaceData.Options and ouiHideCmdline = 0 then
        case Char(Event.KeyDown.CharScan.CharCode) of
          ^V:
            begin
            Overwrite := not Overwrite;
            CE2
            end;
          ^J:
            begin
            MessageKey(Self, kbEnter);
            CE
            end;
          ^A:
            begin
            MessageKey(Self, kbCtrlLeft);
            CE
            end;
          ^F:
            begin
            MessageKey(Self, kbCtrlRight);
            CE
            end;
          #32..#126, #128..#255:
            begin
            T := TypedText(Event);
            if Overwrite and (CurX < Length(Str)) then
              Delete(Str, CurX+1, CharAt(Str, CurX+1));
            Insert(T, Str, CurX+1);
            Inc(CurX, Length(T));
            StrModified := True;
            CE2;
            end;
          else {case}
            case DNKeyCode(Event) of
              kbCtrlBack:
                begin
                while (CurX > 0) and not (Str[CurX] in Separators) do
                  begin
                  Delete(Str, CurX, 1);
                  Dec(CurX)
                  end;
                while (CurX > 0) and (Str[CurX] in Separators) do
                  begin
                  Delete(Str, CurX, 1);
                  Dec(CurX)
                  end;
                CE2;
                end;
              kbAltSlash,
              kbAltShiftSlash
             
              :
                begin
                if (DNKeyCode(Event) = kbAltShiftSlash)
                 
                   then
                  Dec(LineType)
                else
                  Inc(LineType);
                while (not Win32exec
                       and (LineType in [ltWindow, ltFullScreen]))
                     //under Windows you cannot launch F/S from the command line
                     or (Win32exec and (LineType = ltFullScreen))
                do
                if (DNKeyCode(Event) = kbAltShiftSlash)
                 
                  then
                    Dec(LineType)
                  else
                    Inc(LineType);

                if LineType > ltTimer then
                  LineType := ltNormal;
                if LineType < ltNormal then
                  LineType := ltTimer;
                SetDirShape;
                if  (InterfaceData.Options and ouiHideCmdline = 0) and
                  not GetState(sfVisible) and (Str = '')
                then
                  begin
                  Str := ' ';
                  ToggleCommandLine(True);
                  Str := '';
                  end;
                CE2
                end;
              kbESC:
                begin
                if  (Str = '') and (InterfaceData.Options and ouiEsc <> 0)
                then
                  begin
                  if EscForOutputWindow then
                    Message(Application, evCommand, cmShowOutput, nil)
                  else
                    Message(Application, evCommand, cmShowUserScreen, nil);
                  end
                else
                  Str := '';
                CurX := 0;
                DeltaX := 0;
                CE2
                end;
              kbBack:
                begin
                if CurX > 0 then
                  begin
                  CW := CharBefore(Str, CurX);
                  Delete(Str, CurX-CW+1, CW);
                  Dec(CurX, CW);
                  if CurX = 0 then
                    StrCleared := True;
                  CE2
                  end;
                end;
              kbBackUp:
                StrCleared := False;
              kbUp, kbShiftUp, kbCtrlE:
                begin
                if  (DNKeyCode(Event) = kbUp)
                     and (ShiftState and kbCtrlShift <> 0)
                then
                  Exit;
                if StrModified then
                  begin
                  AddCommand(Str);
                  CurString := CmdStrings.Count;
                  StrModified := False;
                  end;
                if CurString > 0 then
                  Dec(CurString);
                Str := GetCommand(CurString);
                Changed := True;
                CurX := Length(Str);
                if CurX < Size.X-Min(Length(Dir), 50)-1 then
                  DeltaX := 0; {John_SW}
                CE2;
                end;
              kbDown, kbShiftDown, kbCtrlX:
                begin
                if  (DNKeyCode(Event) = kbDown)
                     and (ShiftState and kbCtrlShift <> 0)
                then
                  Exit;
                if StrModified then
                  begin
                  AddCommand(Str);
                  CurString := CmdStrings.Count;
                  StrModified := False;
                  end;
                Str := GetCommand(CurString);
                if Str <> '' then
                  Inc(CurString);
                Str := GetCommand(CurString);
                Changed := True;
                CurX := Length(Str);
                CE2;
                if CurX < Size.X-Min(Length(Dir), 50)-1 then
                  DeltaX := 0; {John_SW}
                end;
              kbLeft, kbCtrlS, kbShiftLeft:
                begin
                if CurX > 0 then
                  Dec(CurX, CharBefore(Str, CurX));
                CE2
                end;
              kbRight, kbCtrlD, kbShiftRight:
                begin
                if CurX < Length(Str) then
                  Inc(CurX, CharAt(Str, CurX+1));
                CE2
                end;
              kbCtrlIns, kbCtrlShiftIns:
                if Str <> '' then
                  begin
                  PutInClip(Str);
                  CE;
                  end;
              kbShiftIns: {if ShiftState and 4 = 0 then}
                {Cat}
                begin
                GetFromClip(S);
                if S <> '' then
                  Message(Self, evCommand, cmInsertName, @S);
                CE2;
                end
                {else
                               begin
                                 PutInClip(Str);
                                 CE;
                               end};
              kbIns:
                begin
                Overwrite := not Overwrite;
                CE2
                end;
              kbDel:
                begin
                Delete(Str, CurX+1, CharAt(Str, CurX+1));
                CE2
                end;
              kbEnd, kbShiftEnd, kbCtrlEnd:
                begin
                CurX := Length(Str);
                CE2
                end;
              kbHome, kbShiftHome, kbCtrlHome:
                begin
                CurX := 0;
                CE2
                end;
              kbCtrlLeft:
                begin
                if not (Str[CurX] in Separators) then
                  while (CurX > 0) and not (Str[CurX] in Separators) do
                    Dec(CurX)

                else
                  begin
                  while (CurX > 0) and (Str[CurX] in Separators) do
                    Dec(CurX);
                  while (CurX > 0) and not (Str[CurX] in Separators) do
                    Dec(CurX)
                  end;
                CE2;
                end;
              kbEnter:
                Message(Application, evCommand, cmExecCommandLine, nil);
              kbCtrlRight:
                begin
                if not (Str[CurX+1] in Separators) then
                  begin
                  while (CurX < Length(Str))
                       and not (Str[CurX+1] in Separators)
                  do
                    Inc(CurX);
                  while (CurX < Length(Str))
                       and (Str[CurX+1] in Separators)
                  do
                    Inc(CurX);
                  end
                else
                  while (CurX < Length(Str))
                       and (Str[CurX+1] in Separators)
                  do
                    Inc(CurX);
                CE2;
                end;
            end {case};
        end {case};
      CheckSize;
      end;
  end {case};
  if Changed then
    StrModified := False
  else
    StrModified := (S <> Str);
  end { TCommandLine.HandleEvent };

(*
constructor TCmdWindow.Create(R: TRect);
begin
 inherited Create(R, 'Command Line', 0);
 R := GetExtent;
 Palette := wpCyanWindow;
 R.Grow(-1, -1);
 Insert(PCmdLine.Create(R));
end;

procedure TCmdLine.Draw;
 var B: TDrawBuffer;
     I: Integer;
     S: String;
begin
end;
*)

end.
