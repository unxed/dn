{ HelpKern: the data of the help system of DN (our unit; it replaces HELPKERN.PAS of the archive, which repeated
  the help kernel of Borland TV). TODO: the help files (.HLP, made by tvhc) are not read yet: a topic is empty and
  the help window (HelpFile) says that there is no help. The names are those that DN uses. }
{$mode objfpc}{$H-}
unit HelpKern;

interface

uses
  TvGeom, TvObjs;

type
  PHelpTopic = ^THelpTopic;
  THelpTopic = object(TObject)
    constructor Init;
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);
    function NumLines: Integer;
    function GetLine(Line: Integer): String;
    procedure SetWidth(AWidth: Integer);
  end;

  PHelpIndex = ^THelpIndex;
  THelpIndex = object(TObject)
    constructor Init;
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);
    function Position(I: Word): LongInt;
    procedure Add(I: Word; Val: LongInt);
  end;

  PHelpFile = ^THelpFile;
  THelpFile = object(TObject)
    Stream: PStream;
    Modified: Boolean;
    constructor Init(S: PStream);
    destructor Done; virtual;
    function GetTopic(I: Word): PHelpTopic;
    function InvalidTopic: PHelpTopic;
  end;

  TCrossRefHandler = procedure(var S: TStream; XRefValue: Integer);

procedure NotAssigned(var S: TStream; Value: Integer);

const
  CrossRefHandler: TCrossRefHandler = @NotAssigned;

implementation

constructor THelpTopic.Init;
begin
  inherited Init;
end;

constructor THelpTopic.Load(var S: TStream);
begin
  inherited Init;
end;

destructor THelpTopic.Done;
begin
  inherited Done;
end;

procedure THelpTopic.Store(var S: TStream);
begin
end;

function THelpTopic.NumLines: Integer;
begin
  Result := 0;
end;

function THelpTopic.GetLine(Line: Integer): String;
begin
  Result := '';
end;

procedure THelpTopic.SetWidth(AWidth: Integer);
begin
end;

constructor THelpIndex.Init;
begin
  inherited Init;
end;

constructor THelpIndex.Load(var S: TStream);
begin
  inherited Init;
end;

destructor THelpIndex.Done;
begin
  inherited Done;
end;

procedure THelpIndex.Store(var S: TStream);
begin
end;

function THelpIndex.Position(I: Word): LongInt;
begin
  Result := -1;
end;

procedure THelpIndex.Add(I: Word; Val: LongInt);
begin
end;

constructor THelpFile.Init(S: PStream);
begin
  inherited Init;
  Stream := S;
  Modified := False;
end;

destructor THelpFile.Done;
begin
  if Stream <> nil then
    Dispose(Stream, Done);
  Stream := nil;
  inherited Done;
end;

function THelpFile.GetTopic(I: Word): PHelpTopic;
begin
  Result := InvalidTopic;
end;

function THelpFile.InvalidTopic: PHelpTopic;
begin
  New(Result, Init);
end;

procedure NotAssigned(var S: TStream; Value: Integer);
begin
end;

end.
