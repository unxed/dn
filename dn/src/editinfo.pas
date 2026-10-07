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

{ The two thin lines of an editor window: the information line at the bottom (the place of the cursor, the code of the character, the modes) and the
  line of the bookmarks at the left.

  They only show what TFileEditor (editcore) knows, and turn a click on a part of the information line into the command of that part. }
{$I STDEFINE.INC}
unit editinfo;

interface

uses
  Views, Drivers;

type
  TInfoLine = class(TView)
    constructor Create(const R: TRect);
    procedure Draw; override;
    procedure HandleEvent(var Event: TEvent); override;
    end;

  TBookmarkLine = class(TView)
    procedure Draw; override;
    end;

implementation

uses
  Defines, Commands, strutil, TvGlyphs, editcore, editwin, DnIni, basics, keymap;

const
  { the parts of the information line, as columns: the mouse takes them (the line is built in the same order) }
  ipLine = 1;
  ipChar = 2;
  ipBlock = 3;
  ipEol = 4;
  ipCode = 5;
  ipTop = 6;
  ipMarks = 7;
  ipBottom = 8;

type
  TParts = array[ipLine..ipBottom] of record
    A, B: Integer;
    end;

var
  Parts: TParts;

constructor TInfoLine.Create(const R: TRect);
  begin
  inherited Create(R);
  EventMask := evMouseDown;
  GrowMode := gfGrowHiX+gfGrowHiY+gfGrowLoY;
  end;

function EditorOf(V: TView): TFileEditor;
  begin
  Result := TFileEditor(TEditWindow(V.Owner).Intern);
  end;

procedure TInfoLine.HandleEvent(var Event: TEvent);
  var
    T: TPoint;
    P: TFileEditor;
    I, Part: Integer;
    Cmd: Word;
  begin
  inherited HandleEvent(Event);
  if Event.What <> evMouseDown then
    Exit;
  Owner.MakeLocal(Event.Where, T);
  if T.X >= Owner.Size.X-2 then
    begin
    TWindow(Owner).Frame.HandleEvent(Event);
    Exit;
    end;
  MakeLocal(Event.Where, T);
  P := EditorOf(Self);
  Part := 0;
  for I := ipLine to ipBottom do
    if (T.X >= Parts[I].A) and (T.X < Parts[I].B) then
      Part := I;
  Cmd := 0;
  case Part of
    ipLine:
      Cmd := cmGotoLineNumber;
    ipChar:
      Cmd := cmSpecChar;
    ipBlock:
      Cmd := cmSwitchBlock;
    ipEol:
      case P.EolMode of
        cfCRLF:
          Cmd := cmEditLfMode;
        cfLF:
          Cmd := cmEditCrMode;
        else
          Cmd := cmEditCrLfMode;
      end;
    ipCode:
      Cmd := cmSwitchKeyMapping;
    ipTop:
      P.GotoXY(0, 0);
    ipBottom:
      P.GotoXY(0, P.LineCount);
    ipMarks:
      if FastBookmark then
        begin
        I := T.X-Parts[ipMarks].A-1;
        if (I >= 0) and (I <= 8) then
          if (Event.Buttons and mbRightButton <> 0) then
            Cmd := cmPlaceMarker1+I
          else if P.MarkPos[I+1].X >= 0 then
            Cmd := cmGoToMarker1+I;
        end;
  end {case};
  if Cmd <> 0 then
    begin
    Event.What := evCommand;
    Event.Command := Cmd;
    PutEvent(Event);
    end;
  ClearEvent(Event);
  end;

procedure TInfoLine.Draw;
  var
    P: TFileEditor;
    Cur: TPoint;
    S, Num: String;
    Color: Word;
    Ch2: Char;
    B: TDrawBuffer;
    I: Integer;
    CP: LongWord;

  procedure Part(Which: Integer; const Text: String);
    begin
    Parts[Which].A := Length(S);
    S := S+Text;
    Parts[Which].B := Length(S);
    end;

  begin
  P := EditorOf(Self);
  if Owner.GetState(sfDragging) or not Owner.GetState(sfActive) then
    begin
    if Owner.GetState(sfDragging)
    then
      Color := TWindow(Owner).Frame.GetColorW(5)
    else
      Color := TWindow(Owner).Frame.GetColorW(2);
    Ch2 := GlyphChar(glLightH);
    end
  else
    begin
    Color := TWindow(Owner).Frame.GetColorW(3);
    Ch2 := GlyphChar(glDblH);
    end;
  S := '';
  FillChar(Parts, SizeOf(Parts), 0);
  if Owner.GetState(sfActive) then
    begin
    Cur := P.Cursor;
    if P.Modified then
      S := #15+Ch2
    else
      S := Ch2+Ch2;
    Part(ipLine, SStr(Cur.Y+1, 5, Ch2)+':'+SSt2(Cur.X+1, 4, Ch2));
    CP := P.CodeAtCursor;
    if CP < 256 then
      Num := SStr(LongInt(CP), 3, '0')+GlyphChar(glMidDot)+Hex2(Byte(CP))
    else
      if CP < $10000 then
        Num := 'U+'+Hex2(CP shr 8)+Hex2(CP and $FF)
      else
        Num := 'U+'+Hex2(CP shr 16)+Hex2((CP shr 8) and $FF)+Hex2(CP and $FF);
    Part(ipChar, Ch2+'['+Num+']');
    S := S+Ch2;
    if P.DrawMode = 1 then
      Part(ipBlock, '{'+GlyphChar(glLightVH))
    else if P.DrawMode = 2 then
      Part(ipBlock, '{'+GlyphChar(glDblVH))
    else if P.VertBlock then
      Part(ipBlock, '('#18)
    else
      Part(ipBlock, '('#29);
    if P.DrawMode = 0 then
      if P.OptimalFill then
        S := S+'F)'
      else
        S := S+')'+GlyphChar(glDblH)
    else if P.OptimalFill then
      S := S+'F}'
    else
      S := S+'}'+GlyphChar(glDblH);
    case P.EolMode of
      cfCR:
        Part(ipEol, Ch2+Ch2+'Cr'+Ch2);
      cfLF:
        Part(ipEol, Ch2+Ch2+'Lf'+Ch2);
      else
        Part(ipEol, Ch2+'CrLf');
    end {case};
    Part(ipCode, Ch2+P.CharsetTag+Ch2);
    Part(ipTop, Ch2);
    if FastBookmark then
      begin
      Parts[ipMarks].A := Length(S);
      S := S+'<';
      for I := 1 to 9 do
        if P.MarkPos[I].X >= 0 then
          S := S+Char(I+48)
        else
          S := S+GlyphChar(glMidDot);
      S := S+'>';
      Parts[ipMarks].B := Length(S);
      end;
    Part(ipBottom, Ch2);
    end;
  MoveChar(B[0], Ch2, Color, Size.X);
  MoveStr(B[0], S, Color);
  WriteLineC(0, 0, Size.X, 1, B);
  end;

procedure TBookmarkLine.Draw;
  var
    P: TFileEditor;
    Col: Word;
    I: Integer;
    Mrk: Char;
    Ch: Char;
    B: array[0..20] of Word;

  function IsMarker(TLine: LongInt): Char;
    var
      N: Byte;
    begin
    IsMarker := #0;
    for N := 1 to 9 do
      if P.MarkPos[N].Y = TLine then
        begin
        IsMarker := Char(N+48);
        Break;
        end;
    end;

  function SwitchHalfs(V: Word): Word;
    begin
    SwitchHalfs := ((V and $0F) shl 4) or ((V and $F0) shr 4);
    end;

  begin
  P := EditorOf(Self);
  if Owner.GetState(sfDragging) or not Owner.GetState(sfActive) then
    begin
    if Owner.GetState(sfDragging)
    then
      Col := TWindow(Owner).Frame.GetColorW(5)
    else
      Col := TWindow(Owner).Frame.GetColorW(2);
    Ch := GlyphChar(glLightV);
    end
  else
    begin
    Col := TWindow(Owner).Frame.GetColorW(3);
    Ch := GlyphChar(glDblV);
    end;
  if not ShowBookmarks then
    begin
    MoveChar(B[0], Ch, Col, 1);
    WriteLineW(0, 0, Size.X, Size.Y, B);
    Exit;
    end;
  for I := 0 to Size.Y do
    begin
    Mrk := IsMarker(P.TopLine+I);
    if Mrk = #0 then
      MoveChar(B[0], Ch, Col, 1)
    else
      MoveChar(B[0], Mrk, SwitchHalfs(Col), 1);
    WriteLineW(0, I, Size.X, 1, B);
    end;
  end;

end.
