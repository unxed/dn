{ The actions of the language of DN (the resource dlgActions, see DnActions) in the registry of tv3 (TvActions): there the
  command, the key, the caption and the help context of an action are found by its name, its command or its key.

  TvActions is compiled before DN by tools/build.sh (its head has a comment inside a comment, which the Delphi mode of DN
  does not read).

  MIT, see LICENSE. }
{$I STDEFINE.INC}
unit DnActReg;

interface

uses
  DnActions;

{ The key of DN (the shift bits above the code) as a key code of tv3 (TvKeys) }
function DnKeyToTv(Code: LongInt): Word;
{ Puts every action of the table into TvActions (a name that is there is replaced) }
procedure RegisterActionTable(T: TActionTable);
{ The same for the table of the resources of the language (dlgActions) }
procedure RegisterLanguageActions;

implementation

uses
  TvObjs, TvActions, Commands, mainapp;

function DnKeyToTv(Code: LongInt): Word;
var
  Shift: LongInt;
begin
  Result := Word(Code);
  Shift := (Code shr 16) and $F;
  if (Shift and 3) <> 0 then
    case Result of
      $5200: Result := $0500;
      $5300: Result := $0700;
    end;
  if (Shift and 4) <> 0 then
    case Result of
      $9200: Result := $0400;
      $9300: Result := $0600;
    else
      if ((Shift and 8) = 0) and ((Result and $FF) in [1..26]) then
        Result := Result and $FF;
    end;
end;

procedure RegisterActionTable(T: TActionTable);
var
  I: Integer;
begin
  for I := 0 to T.Count - 1 do
    with T.Items[I] do
      RegisterAction(Name, Caption, Command, DnKeyToTv(KeyCode), HelpCtx);
end;

procedure RegisterLanguageActions;
var
  T: TStreamable;
begin
  T := LoadResource(dlgActions);
  if T is TActionTable then
    RegisterActionTable(TActionTable(T));
  T.Free;
end;

end.
