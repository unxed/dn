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
{Writted by DataCompBoy at 29.07.2000 21:04:26}
{AK155 = Alexey Korop, 2:461/155@fidonet}
{Cat = Aleksej Kozlov, 2:5030/1326.13@fidonet}

{Cat
   28/08/2001 - переделал функции для совместимости с типами AnsiString и
   LongString, а также для поддержки коллекций с длинными строками

   05/09/2001 - выкинул NeedStream из GetWinClip и SyncClipOut
}

unit WINCLP;

interface

uses
  Defines, Streams, Collect
  ;

function SetWinClip(PC: TLineCollection): Boolean; 
function GetWinClip(var PCL: TLineCollection {; NeedStream: boolean})
  : Boolean; 
function GetWinClipSize: Boolean; 
procedure SyncClipIn; 
procedure SyncClipOut {(NeedStream: boolean)}; 

procedure CopyLines2Stream(PC: TCollection; var PCS: TStream);
procedure CopyStream2Lines(PCS: TStream; var PC: TCollection);

implementation

{ The system clipboard through TvClip (tv/): the text there is UTF-8 and the backend does the rest (the Windows clipboard, OSC 52, WinOldAp of DOS).
  The lines of DN are UTF-8 in the build with -dDNUTF8, else the bytes of the code page of DN (OEM): at the border they are turned into UTF-8 and back.
  The lines of the clipboard of DN are the lines of the text; the system text has the line breaks of the system, any of them splits the lines. }

uses
  TvClip, editcore, strutil
  ;

function ToSys(const S: LongString): AnsiString;
  begin
{$IFDEF DNUTF8}
  Result := S;
{$ELSE}
  Result := OemToUtf8(S);
{$ENDIF}
  end;

function FromSys(const S: AnsiString): LongString;
  begin
{$IFDEF DNUTF8}
  Result := S;
{$ELSE}
  Result := Utf8ToOem(S);
{$ENDIF}
  end;

function LinesText(PC: TLineCollection): AnsiString;
  var
    I: LongInt;
    L: AnsiString;
  begin
  Result := '';
  if PC = nil then
    Exit;
  for I := 0 to PC.Count - 1 do
    begin
    if PC.LongStrings then
      L := PLongString(PC.At(I))^
    else
      L := PStr(PC.At(I))^;
    if I > 0 then
      Result := Result + #10;
    Result := Result + ToSys(L);
    end;
  end;

{ the text of the system into the lines (a new collection) }
function TextLines(const T: AnsiString): TLineCollection;
  var
    P, Q: LongInt;
    S: AnsiString;
  begin
  Result := TLineCollection.Create(10, 10, True);
  P := 1;
  while P <= Length(T) do
    begin
    Q := P;
    while (Q <= Length(T)) and not (T[Q] in [#10, #13]) do
      Inc(Q);
    S := FromSys(Copy(T, P, Q - P));
    Result.Insert(NewLongStr(S));
    if (Q < Length(T)) and (T[Q] = #13) and (T[Q + 1] = #10) then
      Inc(Q);
    P := Q + 1;
    end;
  if Result.Count = 0 then
    Result.Insert(NewLongStr(''));
  end;

function SetWinClip(PC: TLineCollection): Boolean;
  begin
  Result := False;
  if PC = nil then
    Exit;
  ClipboardSetText(LinesText(PC));
  Result := True;
  end;

function GetWinClip(var PCL: TLineCollection {; NeedStream: boolean})
  : Boolean;
  var
    T: AnsiString;
  begin
  Result := False;
  T := ClipboardGetText;
  if T = '' then
    Exit;
  if PCL <> nil then
    PCL.Free;
  PCL := TextLines(T);
  Result := True;
  end;

function GetWinClipSize: Boolean;
  begin
  Result := ClipboardGetText <> '';
  end;

procedure SyncClipIn;
  begin
  if editcore.ClipBoard <> nil then
    SetWinClip(TLineCollection(editcore.ClipBoard));
  end;

procedure SyncClipOut {(NeedStream: boolean)};
  var
    T: AnsiString;
  begin
  T := ClipboardGetText;
  if (T = '') or (T = LinesText(TLineCollection(editcore.ClipBoard))) then
    Exit;
  if editcore.ClipBoard <> nil then
    editcore.ClipBoard.Free;
  editcore.ClipBoard := TextLines(T);
  end;

procedure CopyLines2Stream(PC: TCollection; var PCS: TStream);

  begin {Cat:todo DPMI32}
  end;

procedure CopyStream2Lines(PCS: TStream; var PC: TCollection);

  begin {Cat:todo DPMI32}
  end;

end.
