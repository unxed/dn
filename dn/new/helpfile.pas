{ HelpFile: the window of the help (our unit; it replaces HELPFILE.PAS of the archive). TODO: the window only says
  that there is no help; the viewer of the topics is not written. }
{$mode objfpc}{$H-}
unit HelpFile;

interface

uses
  TvGeom, TvObjs, TvViews, TvWindow, TvDialog, HelpKern;

type
  PHelpWindow = ^THelpWindow;
  THelpWindow = object(TWindow)
    HFile: PHelpFile;
    constructor Init(AHelpFile: PHelpFile; Context: Word);
    destructor Done; virtual;
    procedure GotoContext(Context: Word);
  end;

implementation

constructor THelpWindow.Init(AHelpFile: PHelpFile; Context: Word);
var
  R: TRect;
begin
  R.Assign(0, 0, 50, 8);
  inherited Init(R, 'Help', wnNoNumber);
  Options := Options or ofCentered;
  HFile := AHelpFile;
  R.Assign(2, 2, 48, 6);
  Insert(New(PStaticText, Init(R, 'The help is not available in this version.')));
end;

destructor THelpWindow.Done;
begin
  if HFile <> nil then
    Dispose(HFile, Done);
  HFile := nil;
  inherited Done;
end;

procedure THelpWindow.GotoContext(Context: Word);
begin
end;

end.
