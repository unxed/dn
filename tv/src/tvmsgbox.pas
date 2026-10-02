{ TvMsgBox: message boxes.

  Translated from magiblot/tvision @ b4831e2:
    include/tvision/msgbox.h, source/tvision/msgbox.cpp (messageBox, messageBoxRect),
    tvtext2.cpp (the texts of the buttons and titles)
  Borland disclaimer and MIT notice: tv/COPYRIGHT.magiblot.

  Differences from the C++ original (see tv/DESIGN.md):
    - the texts of the buttons and of the titles are variables (translations: set them
      before the first box is shown);
    - the formatted variants take a Pascal format string and an array of const
      (SysUtils.Format: %s, %d, ...), not printf;
    - inputBox is in TvInput (it needs the input line). }
unit TvMsgBox;

{$I tvdefs.inc}

interface

uses
  SysUtils, TvGeom, TvEvents, TvText, TvViews, TvDialog, TvApp;

const
  mfWarning      = $0000;     { display a warning box }
  mfError        = $0001;     { display an error box }
  mfInformation  = $0002;     { display an information box }
  mfConfirmation = $0003;     { display a confirmation box }

  mfYesButton    = $0100;     { put a Yes button into the dialog }
  mfNoButton     = $0200;
  mfOKButton     = $0400;
  mfCancelButton = $0800;

  mfYesNoCancel  = mfYesButton or mfNoButton or mfCancelButton;
  mfOKCancel     = mfOKButton or mfCancelButton;

var
  MsgYesText: ShortString = '~Y~es';
  MsgNoText: ShortString = '~N~o';
  MsgOKText: ShortString = 'O~K~';
  MsgCancelText: ShortString = '~C~ancel';
  MsgWarningText: ShortString = 'Warning';
  MsgErrorText: ShortString = 'Error';
  MsgInformationText: ShortString = 'Information';
  MsgConfirmText: ShortString = 'Confirm';

function MessageBox(const Msg: ShortString; AOptions: Word): Word;
function MessageBoxRect(const R: TRect; const Msg: ShortString; AOptions: Word): Word;
function MessageBoxFmt(AOptions: Word; const Fmt: ShortString; const Args: array of const): Word;
function MessageBoxRectFmt(const R: TRect; AOptions: Word; const Fmt: ShortString;
  const Args: array of const): Word;

implementation

function FormatStr(const Fmt: ShortString; const Args: array of const): ShortString;
var
  S: AnsiString;
begin
  S := Format(Fmt, Args);
  if Length(S) > 255 then
    SetLength(S, 255);
  Result := S;
end;

function MessageBoxRect(const R: TRect; const Msg: ShortString; AOptions: Word): Word;
const
  Commands: array[0..3] of Word = (cmYes, cmNo, cmOK, cmCancel);
var
  Dialog: PDialog;
  I, X, ButtonCount: Integer;
  ButtonList: array[0..4] of PView;
  Names: array[0..3] of PShortString;
  Title: ShortString;
  Btn: PButton;
  Rc: TRect;
begin
  Names[0] := @MsgYesText;
  Names[1] := @MsgNoText;
  Names[2] := @MsgOKText;
  Names[3] := @MsgCancelText;
  case AOptions and 3 of
    mfError: Title := MsgErrorText;
    mfInformation: Title := MsgInformationText;
    mfConfirmation: Title := MsgConfirmText;
  else
    Title := MsgWarningText;
  end;
  New(Dialog, Init(R, Title));
  Rc.Assign(3, 2, Dialog^.Size.X - 2, Dialog^.Size.Y - 3);
  Dialog^.Insert(New(PStaticText, Init(Rc, Msg)));
  X := -2;
  ButtonCount := 0;
  for I := 0 to 3 do
    if (AOptions and ($0100 shl I)) <> 0 then
    begin
      Rc.Assign(0, 0, 10, 2);
      New(Btn, Init(Rc, Names[I]^, Commands[I], bfNormal));
      ButtonList[ButtonCount] := Btn;
      Inc(X, Btn^.Size.X + 2);
      Inc(ButtonCount);
    end;
  X := (Dialog^.Size.X - X) div 2;
  for I := 0 to ButtonCount - 1 do
  begin
    Dialog^.Insert(ButtonList[I]);
    ButtonList[I]^.MoveTo(X, Dialog^.Size.Y - 3);
    Inc(X, ButtonList[I]^.Size.X + 2);
  end;
  Dialog^.SelectNext(False);
  Result := Application^.ExecView(Dialog);
  Dispose(Dialog, Done);
end;

function MakeRect(const Text: ShortString): TRect;
var
  Width: Integer;
begin
  Result.Assign(0, 0, 40, 9);
  Width := TextWidthS(Text);
  if Width > (Result.B.X - 7) * (Result.B.Y - 6) then
    Result.B.Y := Width div (Result.B.X - 7) + 6 + 1;
  Result.Move((DeskTop^.Size.X - Result.B.X) div 2, (DeskTop^.Size.Y - Result.B.Y) div 2);
end;

function MessageBox(const Msg: ShortString; AOptions: Word): Word;
begin
  Result := MessageBoxRect(MakeRect(Msg), Msg, AOptions);
end;

function MessageBoxFmt(AOptions: Word; const Fmt: ShortString; const Args: array of const): Word;
var
  Msg: ShortString;
begin
  Msg := FormatStr(Fmt, Args);
  Result := MessageBoxRect(MakeRect(Msg), Msg, AOptions);
end;

function MessageBoxRectFmt(const R: TRect; AOptions: Word; const Fmt: ShortString;
  const Args: array of const): Word;
begin
  Result := MessageBoxRect(R, FormatStr(Fmt, Args), AOptions);
end;

end.
