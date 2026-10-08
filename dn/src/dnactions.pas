{ The actions of DN: a command that a menu item or a status line offers, with its key, the text of the key in the menu, its
  help context and its caption. They are declared once (dn/src/resource/actions.dna; a language may give other keys in its
  dn.dnr); rcp builds the menus and the status lines from them and stores the table of each language as the resource
  dlgActions; DnActReg puts it into the registry of tv3 (TvActions) at start. Format: docs/RESOURCES.md.

  MIT, see LICENSE. }
{$I STDEFINE.INC}
unit DnActions;

interface

uses
  TvObjs;

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
    constructor Load(S: TStream);
    procedure Store(S: TStream);
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

procedure WriteS(S: TStream; const V: String);
var
  L: Byte;
begin
  L := Length(V);
  S.Write(L, 1);
  if L > 0 then
    S.Write(V[1], L);
end;

constructor TActionTable.Load(S: TStream);
var
  N: LongInt;
  I: Integer;
begin
  inherited Create;
  S.Read(N, SizeOf(N));
  SetLength(Items, N);
  for I := 0 to N - 1 do
    with Items[I] do
    begin
      S.ReadStrV(Name);
      S.ReadStrV(Caption);
      S.ReadStrV(KeyText);
      S.Read(Command, SizeOf(Command));
      S.Read(KeyCode, SizeOf(KeyCode));
      S.Read(HelpCtx, SizeOf(HelpCtx));
    end;
end;

procedure TActionTable.Store(S: TStream);
var
  N: LongInt;
  I: Integer;
begin
  N := Length(Items);
  S.Write(N, SizeOf(N));
  for I := 0 to N - 1 do
    with Items[I] do
    begin
      WriteS(S, Name);
      WriteS(S, Caption);
      WriteS(S, KeyText);
      S.Write(Command, SizeOf(Command));
      S.Write(KeyCode, SizeOf(KeyCode));
      S.Write(HelpCtx, SizeOf(HelpCtx));
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
