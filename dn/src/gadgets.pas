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

unit gadgets;

{ Useful gauges: clock and heap available viewer }
interface

uses
  Dos, Defines, objutil, Streams, Views, Drivers,
  Collect, timeutil, TvGadgets
  ;

type
  
  { Trash can class }
  TTrashCan = class;

  TTrashCan = class(TView)
    ImVisible: Boolean;
    constructor Create(const R: TRect);
    function GetPalette: TPalette; override;
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    end;
  

  TKeyMacros = class;
  TKeyMacros = class
    Keys: PWordArray;
    Count: AInt;
    Limit: AInt;
    constructor Create;
    constructor Load(S: TStream);
    destructor Destroy; override;
    procedure Play;
    procedure PutKey(KeyCode: LongInt);
    procedure Store(S: TStream);
    end;

const
  KeyMacroses: TCollection = nil;
  MacroRecord: Boolean = False;

type
  THeapView = TvGadgets.THeapView;

  { the clock of DN: the views of tv/ TvGadgets with the options of DN (ShowSeconds, BlinkSeparator, RightAlignClock
    of dn.ini, the time format of the country); Shift shows the free memory, Ctrl or Alt the date; a double click opens
    the calendar, a drag moves the clock }
  TClockView = class(TvGadgets.TClockView)
    constructor Create(const Bounds: TRect);
    function ClockText: AnsiString; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Update; override;
    end;
  
procedure PrintFiles(Files: TCollection; Own: TView);


implementation
uses
  Tree, Messages, mainapp, basics, strutil, fileutil, TvGlyphs,
   {AK155}
  FilesCol, Startup, DnIni, FileCopy, Eraser, Commands
  , Calendar 
  ; {-$VIV}

constructor TKeyMacros.Create;
  begin
  inherited Create;
  Limit := 10;
  Count := 0;
  Keys := GetMem(Limit*SizeOf(Word));
  if Keys = nil then
    Fail;
  end;

destructor TKeyMacros.Destroy;
  begin
  if Keys <> nil then
    FreeMem(Keys, Limit*SizeOf(Word));
  inherited Destroy;
  end;

constructor TKeyMacros.Load(S: TStream);
  begin
  inherited Create;
  S.Read(Limit, SizeOf(Limit)*2);
  Keys := GetMem(SizeOf(Word)*Limit);
  if Keys = nil then
    Fail;
  S.Read(Keys^, SizeOf(Word)*Count);
  end;

procedure TKeyMacros.Store(S: TStream);
  begin
  S.Write(Limit, SizeOf(Limit)*2);
  S.Write(Keys^, SizeOf(Word)*Count);
  end;

procedure TKeyMacros.PutKey(KeyCode: LongInt);
  var
    P: Pointer;
  begin
  if Count >= Limit then
    begin
    Inc(Limit, 10);
    P := GetMem(Limit*SizeOf(Word));
    if P = nil then
      Exit;
    Move(Keys^, P^, Count*SizeOf(Word));
    Keys := P;
    end;
  Keys^[Count] := KeyCode;
  Inc(Count);
  end;

procedure TKeyMacros.Play;
  var
    N: Integer;
  begin
  if Application = nil then
    Exit;
  N := 0;
  while N < Count do
    begin
    MessageKey(Application, Keys^[N]);
    Inc(N);
    end;
  end;
{-------- ClockView class ---------}

{ the time in the format of the country (FormatTimeStr); without seconds the hours and the minutes }
function DnClockFormat(H, M, S: Word; Seconds, Separator, Hour12: Boolean): AnsiString;
  begin
  Result := FormatTimeStr(H, M, S);
  if not Seconds then
    Result := Copy(Result, 1, 5);
  if not Separator and (Length(Result) >= 3) then
    Result[3] := ' ';
  end;

constructor TClockView.Create(const Bounds: TRect);
  begin
  inherited Create(Bounds);
  Margin := 1;
  PaletteStr := '';
  FormatHook := @DnClockFormat;
  EventMask := evMouse or evMessage;
  Options := Options or ofTopSelect;
  GrowMode := gfGrowHiX;
  ShowSeconds := DnIni.ShowSeconds;
  BlinkSeparator := DnIni.BlinkSeparator;
  RightAlign := RightAlignClock;
  RegisterToBackground(Self);
  UpdTicks := 500;
  end;

function TClockView.ClockText: AnsiString;
  var
    d, mn, y, DayWeek: Word;
    SS: String[40];
  begin
  if MacroRecord then
    begin
    Result := '>MACRO<';
    if Size.X > Length(Result) then
      Result := Result+StringOfChar(' ', Size.X-Length(Result));
    Exit;
    end;
  if ShiftState and 7 = 0 then
    begin
    Result := inherited ClockText;
    Exit;
    end;
  if ShiftState and 3 <> 0 then
    begin
    Result := ' '+FStr(MemAvail)+' ';
    Exit;
    end;
  GetDate(y, mn, d, DayWeek);
  MakeDateFull(d, mn, y, 0, 0, SS, ShowCentury);
  if ShowCentury then
    Result := Copy(SS, 1, 10)+' '
  else
    Result := Copy(SS, 1, 8)+' ';
  if ShowDayOfWeek then
    begin
    {Cat: some odd problems...}
    if  (Length(DaysOfWeek) <> 14) and (Length(DaysOfWeek) <> 21)
    then
      Result := ' '+Copy(GetString(stDaysWeek), 1+DayWeek*2, 2)
        +' '+Result
    else
      Result := ' '+Copy(DaysOfWeek, 1+DayWeek*
            (Length(DaysOfWeek) div 7), (Length(DaysOfWeek) div 7))
        +' '+Result
    end
  else
    Result := ' '+Result;
  end { TClockView.ClockText };

procedure TClockView.HandleEvent(var Event: TEvent);
  var
    P: TPoint;
    R: TRect;
  begin
  P := Size;
  if Event.What = evMouseDown then
    begin
    if Application = nil then
      begin
      ClearEvent(Event);
      Exit;
      end;
    R := Application.GetBounds;
    
    if ((Event.Mouse.EventFlags and 2) <> 0) then
      begin
      InsertCalendar;
      ClearEvent(Event);
      Exit
      end;
    
    DragView(Event, dmDragMove, R, P, P);
    end;
  end;

procedure TClockView.Update;
  var
    T: Integer;
  begin
  ShowSeconds := DnIni.ShowSeconds;
  BlinkSeparator := DnIni.BlinkSeparator;
  RightAlign := RightAlignClock;
  inherited Update;
  if ShiftState and 7 <> 0 then
    UpdTicks := 330
  else
    begin
    T := MsToNextChange;
    if T > 500 then
      T := 500;
    if T < 1 then
      T := 1;
    UpdTicks := T;
    end;
  end { TClockView.Update };


const
  CTrashCan: String[Length(CGrayWindow)] = CGrayWindow;

  { TTrashCan }

constructor TTrashCan.Create(const R: TRect);
  begin
  inherited Create(R);
  Options := Options or ofTopSelect;
  EventMask := EventMask or evBroadcast;
  GrowMode := gfGrowAll;
  Hide;
  end;

function TTrashCan.GetPalette: TPalette;
  begin
  Result := MakePalette(CTrashCan);
  end;

procedure TTrashCan.Draw;
  var
    Row: TDrawBuffer;
    Attr, Index: Word;
  begin
  if (State and sfDragging) <> 0 then
    Index := 3
  else if (State and sfSelected) <> 0 then
    Index := 2
  else
    Index := 1;
  Attr := GetColorW(Index);
  MoveStr(Row[0], GlyphChar(glDownSglHorizDbl)+GlyphChar(glDownSglHorizDbl)+GlyphChar(glVertSglHorizDbl)+GlyphChar(glDownSglHorizDbl)+GlyphChar(glDownSglHorizDbl), Attr);
  WriteLineC(0, 0, Size.X, 1, Row);
  MoveStr(Row[0], GetString(dlTrashCaption), Attr);
  WriteLineC(0, 1, Size.X, 1, Row);
  MoveStr(Row[0], GlyphChar(glLightUR)+GlyphChar(glUpSglHorizDbl)+GlyphChar(glUpSglHorizDbl)+GlyphChar(glUpSglHorizDbl)+GlyphChar(glLightUL), Attr);
  WriteLineC(0, 2, Size.X, 1, Row);
  end;

procedure TTrashCan.HandleEvent(var Event: TEvent);
  var
    Limits: TRect;
    SavedConfirms: Word;
  begin
  inherited HandleEvent(Event);
  if (Event.What = evBroadcast) and (Event.Message.Command = cmDropped) then
    begin
    SavedConfirms := Confirms;
    if (Confirms and cfMouseConfirm) = 0 then
      Confirms := 0;
    Message(PCopyRec(Event.Message.InfoPtr)^.Owner, evCommand, cmEraseGroup, PCopyRec(Event.Message.InfoPtr)^.FC);
    Confirms := SavedConfirms;
    ClearEvent(Event);
    end;
  if Event.What <> evMouseDown then
    Exit;
  if not ((Event.Mouse.EventFlags and 2) <> 0) then
    begin
    Limits := Owner.GetExtent;
    DragView(Event, dmDragMove, Limits, Size, Size);
    Exit;
    end;
  Event.Message.InfoPtr := nil;
  Event.Message.Command := cmReanimator;
  Event.What := evCommand;
  PutEvent(Event);
  ClearEvent(Event);
  end;
procedure TTrashCan.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  if AState and sfSelected <> 0 then
    EnableCommands([cmNext, cmPrev]);
  if  (AState and (sfSelected+sfFocused+sfDragging) <> 0) then
    DrawView;
  end;


{-DataCompBoy-}

procedure PrintFiles(Files: TCollection; Own: TView);
  var
    PF: PFileRec;
    I, J: Integer;
    S: String;
  begin
  if Files = nil then
    Exit;
  J := 0;
  for I := 0 to Files.Count-1 do
    begin
    PF := Files.At(I);
    if PF^.Attr and Directory = 0 then
      Inc(J);
    end;
  if J = 0 then
    Exit;
  if Files.Count = 1 then
    S := GetString(dlDIFile)+' '+
         Cut(PFileRec(Files.At(0))^.FlName[True], 40)
  else
    S := ItoS(Files.Count)+' '+GetString(dlDIFiles);
  if MessageBox(GetString(dlPM_Print)+S+'?', nil, mfYesNoConfirm)
     <> cmYes
  then
    Exit;
  for I := 0 to Files.Count-1 do
    begin
    PF := Files.At(I);
    if PF^.Attr and Directory = 0 then
      begin
      S := MakeNormName(PF^.Owner^, PF^.FlName[True]);
      Message(Own, evCommand, cmCopyUnselect, PF);
      if Application <> nil then
        Message(Application, evCommand, cmFilePrint, @S);
      end;
    end;
  end { PrintFiles };

{-DataCompBoy-}

end.
