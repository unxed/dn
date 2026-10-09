{ The actions of DN: a command that a menu item or a status line offers, with its key, the text of the key in the menu, its
  help context and its caption. They are declared once (dn/src/resource/actions.dna; a language may give other keys in its
  dn.dnr); rcp builds the menus and the status lines from them and stores the table of each language as the resource
  dlgActions; DnActReg puts it into the registry of tv3 (TvActions) at start. Format: docs/RESOURCES.md.

  MIT, see LICENSE. }
{$I STDEFINE.INC}
unit DnActions;

interface

uses
  TvObjs, Defines;

type
  TDnAction = record
    Name: String;
    Caption: String;            { the caption of the menu item of the language, '' for a key only }
    KeyText: String;            { the key as the menu shows it }
    Command: Word;
    KeyCode: LongInt;           { in the form of DN (the shift bits above the code) }
    HelpCtx: Word;
  end;

  TActionTable = class(TStreamable)
    Items: array of TDnAction;
    constructor Create;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    function Count: Integer;
    { -1 if there is no such name (case does not matter) }
    function IndexOf(const AName: String): Integer;
    function Add(const AName: String; ACommand: Word; AKeyCode: LongInt; const AKeyText: String; AHelpCtx: Word): Integer;
  end;

implementation

uses
  SysUtils;

constructor TActionTable.Create;
begin
  inherited Create;
end;

class function TActionTable.Build: TStreamable;
begin
  Result := TActionTable.Create;
end;

function TActionTable.StreamableName: ShortString;
begin
  Result := 'DnActions.TActionTable';
end;

function TActionTable.Read(Ip: ipstream): Pointer;
var
  N: LongInt;
  I: Integer;
begin
  Result := Self;
  Ip.ReadBytes(N, SizeOf(N));
  SetLength(Items, N);
  for I := 0 to N - 1 do
    with Items[I] do
    begin
      ReadStrV(Ip, Name);
      ReadStrV(Ip, Caption);
      ReadStrV(Ip, KeyText);
      Ip.ReadBytes(Command, SizeOf(Command));
      Ip.ReadBytes(KeyCode, SizeOf(KeyCode));
      Ip.ReadBytes(HelpCtx, SizeOf(HelpCtx));
    end;
end;

procedure TActionTable.Write(Os: opstream);
var
  N: LongInt;
  I: Integer;
begin
  N := Length(Items);
  Os.WriteBytes(N, SizeOf(N));
  for I := 0 to N - 1 do
    with Items[I] do
    begin
      Os.WriteString(Name);
      Os.WriteString(Caption);
      Os.WriteString(KeyText);
      Os.WriteBytes(Command, SizeOf(Command));
      Os.WriteBytes(KeyCode, SizeOf(KeyCode));
      Os.WriteBytes(HelpCtx, SizeOf(HelpCtx));
    end;
end;

function TActionTable.Count: Integer;
begin
  Result := Length(Items);
end;

function TActionTable.IndexOf(const AName: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(Items) do
    if CompareText(Items[I].Name, AName) = 0 then
      Exit(I);
  Result := -1;
end;

function TActionTable.Add(const AName: String; ACommand: Word; AKeyCode: LongInt; const AKeyText: String;
  AHelpCtx: Word): Integer;
begin
  Result := IndexOf(AName);
  if Result < 0 then
  begin
    Result := Length(Items);
    SetLength(Items, Result + 1);
  end;
  with Items[Result] do
  begin
    Name := AName;
    Caption := '';
    KeyText := AKeyText;
    Command := ACommand;
    KeyCode := AKeyCode;
    HelpCtx := AHelpCtx;
  end;
end;

end.
