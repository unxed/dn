{ Messages: message boxes and input boxes of DN (our unit; it replaces messages.pas of the archive, which
  repeated MsgBox of Borland TV). The boxes are those of tv/ (TvMsgBox, TvInput); the flags are those of DN.

  Not done yet (TODO): the buttons mfNextDButton, mfAppendButton, mf2YesButton, mfAllButton have no
  equivalent in tv/ (they are shown as the nearest standard button: OK or Yes), the second text of
  MessageBox2 is appended to the first, BigInputBox is a plain input box, HistoryId is not used. }
{$mode objfpc}{$H-}
unit Messages;

interface

uses
  TvGeom, TvViews, Commands;

const
  mfWarning = $0000;
  mfError = $0001;
  mfInformation = $0002;
  mfConfirmation = $0003;
  mfQuery = $0004;
  mfAbout = $0005;
  mfSysError = $0006;

  mfYesButton = $0100;
  mfOKButton = $0200;
  mfNoButton = $0400;
  mfCancelButton = $8000;
  mfNextDButton = $0800;
  mfAppendButton = $1000;
  mf2YesButton = $2000;
  mfAllButton = $4000;

  mfYesNoCancel = mfYesButton + mfNoButton + mfCancelButton;
  mfYesNoConfirm = mfYesButton + mfNoButton + mfConfirmation;
  mfOKCancel = mfOKButton + mfCancelButton;

  MsgActive: Boolean = False;
  MsgHelpCtx: Word = 0;

{ Params: the parameters of the % items of Msg (see FormatStr of Drivers), or nil. }
function MessageBox(Msg: String; Params: Pointer; AOptions: Word): Word;
function MessageBox2(Msg1, Msg2: String; Params1, Params2: Pointer; AOptions: Word): Word;
function MessageBoxRect(var R: TRect; Msg: String; Params: Pointer; AOptions: Word): Word;
function MessageBox2Rect(var R: TRect; Msg1, Msg2: String; Lines1: Word; Params1, Params2: Pointer;
  AOptions: Word): Word;
function InputBox(Title: String; ALabel: String; var S: String; Limit: Word; HistoryId: Word): Word;
function BigInputBox(Title: String; ALabel: String; var S: String; Limit: Word; HistoryId: Word): Word;
function InputBoxRect(var Bounds: TRect; Title: String; ALabel: String; var S: String; Limit: Word;
  HistoryId: Word): Word;
{ The same with the text from the strings of the program (the resource). }
function Msg(Index: TStrIdx; Params: Pointer; AOptions: Word): Word;
function Msg2(Index1, Index2: TStrIdx; Params1, Params2: Pointer; AOptions: Word): Word;
procedure ErrMsg(Index: TStrIdx);
procedure CantWrite(const FName: String);
function FmtFile(const Fmt: String; const FName: String; len: Integer): String;
function FmtStr(const Fmt: String; const S: String): String;
function FmtStrId(Id: TStrIdx; const S: String): String;
function FmtFileId(Id: TStrIdx; const FName: String): String;

implementation

uses
  SysUtils, TvMsgBox, TvInput, Drivers, DNApp;

function ToTv(AOptions: Word): Word;
begin
  Result := AOptions and 7;
  if Result > 3 then
    Result := 0;
  if AOptions and (mfYesButton or mf2YesButton or mfAllButton or mfAppendButton) <> 0 then
    Result := Result or TvMsgBox.mfYesButton;
  if AOptions and (mfNoButton) <> 0 then
    Result := Result or TvMsgBox.mfNoButton;
  if AOptions and (mfOKButton or mfNextDButton) <> 0 then
    Result := Result or TvMsgBox.mfOKButton;
  if AOptions and mfCancelButton <> 0 then
    Result := Result or TvMsgBox.mfCancelButton;
end;

function Fmt(const S: String; Params: Pointer): String;
begin
  if Params = nil then
    Result := S
  else
    FormatStr(Result, S, PByte(Params)^);
end;

{ the middle of a long name is cut: Begin..End }
function Cut(const S: String; Len: Integer): String;
var
  Half: Integer;
begin
  if Length(S) <= Len then
    Exit(S);
  Half := (Len - 2) div 2;
  Result := Copy(S, 1, Len - 2 - Half) + '..' + Copy(S, Length(S) - Half + 1, Half);
end;

function MessageBox(Msg: String; Params: Pointer; AOptions: Word): Word;
begin
  Result := TvMsgBox.MessageBox(Fmt(Msg, Params), ToTv(AOptions));
end;

function MessageBox2(Msg1, Msg2: String; Params1, Params2: Pointer; AOptions: Word): Word;
begin
  Result := TvMsgBox.MessageBox(Fmt(Msg1, Params1) + #13 + Fmt(Msg2, Params2), ToTv(AOptions));
end;

function MessageBoxRect(var R: TRect; Msg: String; Params: Pointer; AOptions: Word): Word;
begin
  Result := TvMsgBox.MessageBoxRect(R, Fmt(Msg, Params), ToTv(AOptions));
end;

function MessageBox2Rect(var R: TRect; Msg1, Msg2: String; Lines1: Word; Params1, Params2: Pointer;
  AOptions: Word): Word;
begin
  Result := TvMsgBox.MessageBoxRect(R, Fmt(Msg1, Params1) + #13 + Fmt(Msg2, Params2), ToTv(AOptions));
end;

function InputBox(Title: String; ALabel: String; var S: String; Limit: Word; HistoryId: Word): Word;
var
  T: ShortString;
begin
  T := S;
  if Limit > 255 then
    Limit := 255;
  Result := TvInput.InputBox(Title, ALabel, T, Limit);
  if Result <> cmCancel then
    S := T;
end;

function BigInputBox(Title: String; ALabel: String; var S: String; Limit: Word; HistoryId: Word): Word;
begin
  Result := InputBox(Title, ALabel, S, Limit, HistoryId);
end;

function InputBoxRect(var Bounds: TRect; Title: String; ALabel: String; var S: String; Limit: Word;
  HistoryId: Word): Word;
var
  T: ShortString;
begin
  T := S;
  if Limit > 255 then
    Limit := 255;
  Result := TvInput.InputBoxRect(Bounds, Title, ALabel, T, Limit);
  if Result <> cmCancel then
    S := T;
end;

function Msg(Index: TStrIdx; Params: Pointer; AOptions: Word): Word;
begin
  Result := MessageBox(GetString(Index), Params, AOptions);
end;

function Msg2(Index1, Index2: TStrIdx; Params1, Params2: Pointer; AOptions: Word): Word;
begin
  Result := MessageBox2(GetString(Index1), GetString(Index2), Params1, Params2, AOptions);
end;

procedure ErrMsg(Index: TStrIdx);
begin
  Msg(Index, nil, mfError + mfOKButton);
end;

procedure CantWrite(const FName: String);
var
  A: String;
  PP: Pointer;
begin
  A := Cut(FName, 30);
  PP := @A;
  Msg(dlCanNotWrite, @PP, mfError + mfOKButton);
end;

function FmtFile(const Fmt: String; const FName: String; len: Integer): String;
var
  S, F: String;
  P: Pointer;
begin
  if len = MaxInt then
    F := FName
  else
    F := Cut(FName, len);
  P := @F;
  FormatStr(S, Fmt, P);
  Result := S;
end;

function FmtStr(const Fmt: String; const S: String): String;
begin
  Result := FmtFile(Fmt, S, MaxInt);
end;

function FmtStrId(Id: TStrIdx; const S: String): String;
begin
  Result := FmtStr(GetString(Id), S);
end;

function FmtFileId(Id: TStrIdx; const FName: String): String;
begin
  Result := FmtFile(GetString(Id), FName, 40);
end;

end.
