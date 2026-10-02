{ DNStdDlg: the standard file dialogs of DN (our unit; it replaces DNStdDlg.pas of the archive, which repeated
  StdDlg of Borland TV). The dialog is TFileDialog of tv/ (TvFileDlg); here are the functions that DN calls.

  Not done yet (TODO): the filter of DN (Mask like "*.Ops;-Pas.*;p*.d") is given to the dialog as it is, the
  dialog of tv/ takes ordinary masks; GetFileNameMenu (the choice from a menu, JO) offers nothing. }
{$mode objfpc}{$H-}
unit DNStdDlg;

interface

uses
  TvViews, TvFileDlg;

const
  fdOKButton = TvFileDlg.fdOKButton;
  fdOpenButton = TvFileDlg.fdOpenButton;
  fdReplaceButton = TvFileDlg.fdReplaceButton;
  fdClearButton = TvFileDlg.fdClearButton;
  fdHelpButton = TvFileDlg.fdHelpButton;
  fdNoLoadDir = TvFileDlg.fdNoLoadDir;

type
  PFileInputLine = TvFileDlg.PFileInputLine;
  TFileInputLine = TvFileDlg.TFileInputLine;
  PFileList = TvFileDlg.PFileList;
  TFileList = TvFileDlg.TFileList;
  PFileInfoPane = TvFileDlg.PFileInfoPane;
  TFileInfoPane = TvFileDlg.TFileInfoPane;
  PFileDialog = TvFileDlg.PFileDialog;
  TFileDialog = TvFileDlg.TFileDialog;

{ The name of a file chosen in the dialog; '' if it was cancelled. }
function GetFileNameDialog(Mask, Title, Name: String; Buttons, HistoryId: Word): String;
{ A choice of a file from a menu; '' and None = True if there is nothing to choose. }
function GetFileNameMenu(Path, Mask, Default: String; PutNumbers: Boolean; var More, None: Boolean): String;

implementation

uses
  TvApp, TvEvents, TvDialog;

function GetFileNameDialog(Mask, Title, Name: String; Buttons, HistoryId: Word): String;
var
  D: PFileDialog;
  R: Word;
begin
  Result := '';
  New(D, Init(Mask, Title, Name, Buttons, HistoryId));
  if Application <> nil then
  begin
    R := Application^.ExecView(D);
    if R <> cmCancel then
      Result := D^.GetFileName;
  end;
  Dispose(D, Done);
end;

function GetFileNameMenu(Path, Mask, Default: String; PutNumbers: Boolean; var More, None: Boolean): String;
begin
  More := False;
  None := True;
  Result := '';
end;

end.
