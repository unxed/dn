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

{$M 131040}
program RCP;

{                                     }
{  Dos Navigator's Resource Compiler  }
{                                     }
{DataCompBoy: *.dnl and *.dnr now can contain constructions like this }
{ ";$IFDEF bla-bla"                                                   }
{here text                                                            }
{ ";$ELSE"                                                            }
{here also text                                                       }
{ ";$ENDIF"                                                           }
{but constructions                                                    }
{ ";$DEFINE bla-bla"                                                  }
{ ";$UNDEF bla-bla"                                                   }
{didn't work. Because I want so 8) All defines you can do in separate }
{file                                                                 }

uses
  Lfn, osdep, Collect, Drivers, Dos, Defines, objutil, Streams, basics,
  strutil, fileutil,
  RStrings, GetConst, Menus, Commands, Setups, DNHelp, Views, mainapp,
   Startup,
  Dialogs, Validate, IniFiles, Scroller, ListMakr, ObjType, RegAll,
   DefColl,
  ColorSel,
  inputfname
  , DNDlgs, DNStrL, DlgLayout, DnActions;

const
  tidCommands = 'cm'#0'cd'#0;
  tidHelpCtx = 'hc'#0;
  tidHistory = 'hs'#0;
  tidKbdconst = 'kb'#0;
  tidOptions = 'of'#0;
  tidDLGs = 'TDlgIdx';
  tidDLs = 'TStrIdx';

var
  Types: TValuesHolder;
  LngFileName: String;
  OutLngFileName: String;
  dlgFileName: String;
  OutDlgFileName: String;
  OutDir: String;
  DLStream: TBufStream;
  DefineParser: TDefCollection;

procedure Error(const S: String);
  begin
  Writeln(#13, S);
  Halt(1);
  end;

function RemoveLeadSpaces(S: String): String;
  begin
  DelLeft(S);
  RemoveLeadSpaces := S;
  end;

const
  BreakChars = [#9, #10, #13, #12, ' ', #0];

function wSkipBlank(const S: String; i: Integer): Integer;
  near;
  begin
  while (i <= Length(S)) and (S[i] in BreakChars) do
    Inc(i);
  wSkipBlank := i;
  end;

function wSkipText(const S: String; i: Integer): Integer;
  near;
  begin
  while (i <= Length(S)) and not (S[i] in BreakChars) do
    Inc(i);
  wSkipText := i;
  end;

function SeekWord(const S: String; No: Integer): Integer;
  { Pos of word #No in S }
  var
    I: Integer;
  begin
  I := 1;
  SeekWord := 0;
  if No >= 1 then
    repeat
      I := wSkipBlank(S, I);
      if I > Length(S) then
        Break;
      Dec(No);
      if No <= 0 then
        begin
        SeekWord := I;
        Break;
        end;
      I := wSkipText(S, I);
      if I > Length(S) then
        Break;
    until False;
  end { SeekWord };

function GetWord(S: String; No: Integer): String; { Word #No of S }
  var
    I: Integer;
  begin
  I := SeekWord(S, No);
  if I > 0 then
    begin
    if I > 1 then
      begin
      SetLength(S, Length(S)-(I-1));
      Move(S[I], S[1], Length(S));
      end;
    SetLength(S, wSkipText(S, 1)-1);
    GetWord := S;
    end
  else
    GetWord := '';
  end;

const
  RStringList: TStreamRec =
    (ObjType: otStringList; VmtLink: 0; Load: nil; Store: nil; Next: nil);

  {-DataCompBoy-}
procedure ProcessDLs(Enable: Boolean);
  var
    DLs: TTypeHolder;
    SLM: TStrListMaker;
    Fail: Boolean;
    F: lText;
    S, S1: String;
    P: TLngWord;
  function DoSeekID(P_: Pointer): Boolean;
  var P: TLngWord absolute P_;
    begin
    DoSeekID := P.Name = S1
    end;
  procedure DoTest(P_: Pointer);
  var P: TLngWord absolute P_;
    begin
    if P.Mark = 0 then
      begin
      Writeln('Unresolved identifier "'+P.Name+'"');
      Fail := True;
      end;
    end;
  function MakeStr(S: String): String;
    label 1, 2;
    var
      A, M: String;
      I, J: Integer;
      B: Boolean;
      NotFlag: Boolean;
    begin
    MakeStr := '';
    DelLeft(S);
    if S = '' then
      Exit;
    I := 0;
    B := False;
    A := '';
1:
    while I < Length(S) do
      begin
      Inc(I);
      case S[I] of
        '''':
          if  (S[I+1] = '''') and B and (I < Length(S)) then
            begin
            Inc(I);
            A := A+'''' {AddStr(A, '''')}
            end
          else
            B := not B;
        '^':
          if B then
            A := A+S[I] {AddStr(A, S[I])}
          else
            begin
            Inc(I);
            A := A+Char(Byte(UpCase(S[I]))-64)
              {AddStr(A, Char(Byte(UpCase(S[I]))-64));}
            end;
        '#':
          if B then
            A := A+S[I] {AddStr(A, S[I])}
          else
            begin
            J := 1;
            M := '';
            repeat
              Inc(I);
              M := M+S[I]; {AddStr(M, S[I]);}

            until (I >= Length(S)) or not (S[I+1] in ['0'..'9']);
            A := A+Char(StoI(M)) {AddStr(A, Char(StoI(M)));}
            end;
        else {case}
          if B then
            A := A+S[I]; {AddStr(A, S[I]);}
      end {case};
      end;
    if S[Length(S)] = '+' then
      begin
2:
      Readln(F.T, S);
      if S <> '' then
        begin
        S := DefineParser.ProceedStr2(S);
        if S = '' then
          goto 2;
        end;
      DelLeft(S);
      I := 0;
      goto 1;
      end;
    if Pos(^Z, UpStrg(A)) = 1
    then
      A := RemoveLeadSpaces(Copy(A, 2, MaxStringLength));
    MakeStr := A;
    end { MakeStr };
  begin { ProcessDLs }
  if Enable then
    begin
    DLs := Types.GetType(tidDLs);
    SLM := TStrListMaker.Create($FFF0, $280);
    lAssignText(F, LngFileName);
    lResetText(F);
    if IOResult <> 0 then
      Error('Cannot open file '+LngFileName);
    Writeln('Reading ', LngFileName);
    while not Eof(F.T) do
      begin
      Readln(F.T, S);
      S := DefineParser.ProceedStr2(S);
      DelLeft(S);
      S1 := GetWord(UpStrg(S), 1);
      while (S1 <> '') and (S1[Length(S1)] = ',') do
        SetLength(S1, Length(S1)-1);
      if  (S1 = '') or (S1[1] = ';') then
        Continue;
      P := DLs.FirstThat(DoSeekID);
      if P = nil then
        Error('Unknown identifier "'+GetWord(S, 1)+'"');
      if P.Mark = 1 then
        Error('Duplicate identifier "'+GetWord(S, 1)+'"');
      SLM.Put(P.l, MakeStr(S));
      P.Mark := 1;
      end;
    Close(F.T);
    Fail := False;
    DLs.ForEach(DoTest);
    if Fail then
      Halt(1);
    DLStream := TBufStream.Create(SysOsPath(OutLngFileName), stCreate, 512);
    if DLStream.Status <> stOK then
      Error('Cannot create file '+OutLngFileName);
    Writeln('Writing ', OutLngFileName);
    DLStream.Put(SLM);
    if DLStream.Status <> stOK then
      begin
      DLStream.Free;
      EraseFile(OutLngFileName);
      Error('Error writing file '+OutLngFileName);
      end
    else
      DLStream.Free;
    SLM.Free;
    end;
  ReRegisterType(RStringList);
  DLStream := TBufStream.Create(SysOsPath(OutLngFileName), stOpenRead, 512);
  LStringList := TStringList(DLStream.Get);
  if  (LStringList = nil) and Enable then
    begin
    DLStream.Free;
    EraseFile(OutLngFileName);
    Error('Error reading file '+OutLngFileName);
    end;
  end { ProcessDLs };
{-DataCompBoy-}

type
  TEditCommand = record
    C, C1, C2: Word;
    CC1, CC2: array[1..2] of Char;
    end;

  {                            Resource Processing                             }
  {----------------------------------------------------------------------------}
var
  S: String;
  F: lText; {DataCompBoy}
  Line: LongInt;
  IDs: TTypeHolder;
  DLGs: TTypeHolder;

const
  idSubMenu = 'SUBMENU ';
  idMenuItem = 'MENUITEM ';
  idMenuLine = 'MENULINE';
  idMenu = 'MENU ';
  idEND = 'END';
  idStatusDef = 'STATUSDEF ';
  idStatusItem = 'STATUSITEM ';
  idStatusLine = 'STATUSLINE';
  idDialog = 'DIALOG ';
  idLabel = 'LABEL ';
  idInputLine = 'INPUTLINE ';
  idLongInputLine = 'LONGINPUTLINE ';
  idHexLine = 'HEXLINE '; {DataCompBoy}
  idButton = 'BUTTON ';
  idCheckBoxes = 'CHECKBOXES ';
  idRadioButtons = 'RADIOBUTTONS ';
  idComboBox = 'COMBOBOX ';
  idNotepad = 'NOTEPAD ';
  idPage = 'PAGE ';
  idItem = 'ITEM ';
  idHelpCtx = 'HELPCTX ';
  idStaticText = 'STATICTEXT ';
  idListBox = 'LISTBOX ';
  idScrollBar = 'SCROLLBAR ';
  idMScrollBar = 'MOUSESCROLLBAR ';
  idParamText = 'PARAMTEXT ';
  idColorGroup = 'COLORGROUP ';
  idColorItem = 'COLORITEM ';
  idColorDialog = 'COLORDIALOG';
  idSelectBack = 'SELECTBACK';
  idSelectForward = 'SELECTFORWARD';
  idCommand = 'COMMAND ';
  idEditorCommands = 'EDITOR COMMANDS';
  idDriveCheckBox = 'DRIVECHECKBOXES ';
  idColorPoint = 'COLORPOINT ';
  idGrow = 'GROW ';
  idResize = 'RESIZE ';
  idAction = 'ACTION ';
  idActions = 'ACTIONS';

  TheRF: TIdxMaker = nil;

var
  D: TColorDialog;
  PL, PP: PColorGroup;
  PI: PColorItem;
  i: LongInt;
  NumCommands: AInt;

const
  MaxCommands = 200;

var
  EditCommands: array[1..MaxCommands] of TEditCommand;

type
  TEditSaver = class(TStreamable)
    constructor Create;
    constructor Load(S: TStream);
    procedure Store(S: TStream);
    end;

const
  REditSaver: TStreamRec = (ObjType: 12335; VmtLink: 0; Load: nil; Store: nil; Next: nil);

constructor TEditSaver.Load(S: TStream);
  begin
  S.Read(NumCommands, SizeOf(NumCommands));
  S.Read(EditCommands, SizeOf(TEditCommand)*NumCommands);
  end;

constructor TEditSaver.Create;
  begin
  inherited Create;
  end;

procedure TEditSaver.Store(S: TStream);
  begin
  S.Write(NumCommands, SizeOf(NumCommands));
  S.Write(EditCommands, SizeOf(TEditCommand)*NumCommands);
  end;

{-DataCompBoy-}
function FSetExt(F: String; NewExt: String): String;
  var
    Dir: String;
    Name: String;
    Ext: String;
  begin
  lFSplit(F, Dir, Name, Ext);
  FSetExt := Dir+Name+NewExt;
  end;
{-DataCompBoy-}

procedure StoreResource(P: TStreamable; Id: TDlgIdx);
  var
    W: TLngWord;
  function HaveThisID(P_: Pointer): Boolean;
  var P: TLngWord absolute P_;
    begin
    HaveThisID := TDlgIdx(P.l) = Id
    end;
  begin
  W := DLGs.FirstThat(HaveThisID);
  if W = nil then
    Error('*ERROR*: Index #'+ItoS(Word(Id))+' out of range.');
  if  (TheRF.Empty(TDlgIdx(Id))) and (W.Mark = 0)
  then
    if P <> nil then
      TheRF.Put(P, TDlgIdx(Id))
    else
  else
    Error(#13'*ERROR*: Duplicate definition for "'+W.Name+'"');
  W.Mark := 1;
  end;

var
  TkL: array[1..8] of LongInt;
  TkS: array[1..8] of String;
  { the actions (resource/actions.dna, then the keys of the language): the menus and the status lines name them }
  ActionsFileName: String;
  Acts: TActionTable = nil;

function GetID(const S: String): LongInt;
  var
    T: TLngWord;
    I: LongInt;
    L: LongInt;
    k: Integer;
  begin
  FreeStr := S;
  DelRight(FreeStr);
  if S[Length(S)] = ',' then
    SetLength(FreeStr, Length(FreeStr)-1);
  DelRight(FreeStr);
  T := TLngWord.Create(0, FreeStr);
  if IDs.Search(T, I) then
    begin
    GetID := TLngWord(IDs.At(I)).L;
    end
  else
    begin
    Val(FreeStr, L, k);
    if k > 0 then
      Error('Unknown identifier ('+FreeStr+') in line '+ItoS(Line));
    GetID := L;
    end;
  end { GetID };

function Token(const S: String; var Pos: LongInt): String; forward;

function ActionIndex(Name: String): Integer;
  begin
  DelLeft(Name);
  DelRight(Name);
  Result := Acts.IndexOf(Name);
  if Result < 0 then
    Error('Unknown action ('+Name+') in line '+ItoS(Line));
  end;

{ resource/actions.dna: ACTION name, command, key, 'key text', help context }
procedure LoadActions;
  var
    A: lText;
    S, Name, KeyText: String;
    I: LongInt;
    C, K, H: LongInt;
  begin
  Acts.Free;
  Acts := TActionTable.Create;
  lAssignText(A, ActionsFileName);
  lResetText(A);
  if IOResult <> 0 then
    Error('Cannot open file '+ActionsFileName);
  Line := 0;
  while not Eof(A.T) do
    begin
    Readln(A.T, S);
    S := DefineParser.ProceedStr2(S);
    Inc(Line);
    DelLeft(S);
    if (S = '') or (S[1] = ';') then
      Continue;
    if UpStrg(Copy(S, 1, Length(idAction))) <> idAction then
      Error('ACTION expected in line '+ItoS(Line)+' of '+ActionsFileName);
    I := Length(idAction);
    Name := Token(S, I);
    DelRight(Name);
    C := GetID(Token(S, I));
    K := GetID(Token(S, I));
    KeyText := Token(S, I);
    H := GetID(Token(S, I));
    if Acts.IndexOf(Name) >= 0 then
      Error('Duplicate action '+Name+' in line '+ItoS(Line)+' of '+ActionsFileName);
    Acts.Add(Name, C, K, KeyText, H);
    end;
  Close(A.T);
  Line := 0;
  end { LoadActions };

{ ACTIONS ... END of a language: name, key, 'key text'[, help context]: the keys of this language }
procedure MakeActionKeys;
  var
    I: LongInt;
    A: Integer;
  begin
  while not Eof(F.T) do
    begin
    Readln(F.T, S);
    S := DefineParser.ProceedStr2(S);
    Inc(Line);
    DelLeft(S);
    if (S = '') or (S[1] = ';') then
      Continue;
    if UpStrg(S) = idEND then
      Break;
    I := 1;
    A := ActionIndex(Token(S, I));
    with Acts.Items[A] do
      begin
      KeyCode := GetID(Token(S, I));
      KeyText := Token(S, I);
      if I <= Length(S) then
        HelpCtx := GetID(Token(S, I));
      end;
    end;
  end { MakeActionKeys };

function Token(const S: String; var Pos: LongInt): String;
  var
    A: String;
    B, Cmd: Boolean;
    M: String;
    J: LongInt;
  begin
  Token := '';
  A := '';
  B := False;
  Cmd := False;
  while (S[Pos] = ' ') and (Length(S) >= Pos) do
    Inc(Pos);
  while Pos <= Length(S) do
    begin
    case S[Pos] of
      '''':
        if  (S[Pos+1] = '''') and B and (Pos < Length(S)) then
          begin
          Inc(Pos);
          A := A+''''; {AddStr(A, '''')}
          end
        else
          B := not B;
      ',':
        if not B or Cmd then
          Break
        else
          A := A+S[Pos]; {AddStr( A, S[Pos] );}
      '^':
        if B then
          A := A+S[Pos] {AddStr(A, S[Pos])}
        else
          begin
          Inc(Pos);
          A := A+Char(Byte(UpCase(S[Pos]))-64)
            {AddStr(A, Char(Byte(UpCase(S[Pos]))-64));}
          end;
      '#':
        if B then
          A := A+S[Pos] {AddStr(A, S[Pos])}
        else
          begin
          J := 1;
          M := '';
          repeat
            Inc(Pos);
            M := M+S[Pos] {AddStr(M, S[Pos]);}

          until not (S[Pos+1] in ['0'..'9']) or (Pos >= Length(S));
          A := A+Char(StoI(M)) {AddStr(A, Char(StoI(M)));}
          end;
      else {case}
        if B then
          A := A+S[Pos] {AddStr(A, S[Pos])}
        else
          begin
          B := True;
          Cmd := True;
          A := A+S[Pos] {AddStr(A, S[Pos])}
          end;
    end {case};
    Inc(Pos);
    end;
  Inc(Pos);
  Token := A;
  end { Token };

procedure MakeGroup;
  var
    P: PColorGroup;
  begin
  i := Length(idColorGroup);
  P := ColorGroup(Token(S, i), nil, nil);
  if PL = nil then
    PP := P
  else
    PL^.Next := P;
  PL := P;
  PI := nil;
  end;

procedure MakeItem;
  var
    P: PColorItem;
  begin
  if PL = nil then
    Error('Color group should be defined first');
  i := Length(idColorItem);
  begin TkS[1] := Token(S, i); TkL[2] := GetID(Token(S, i)); P := ColorItem(TkS[1], TkL[2], nil) end;
  if PI = nil then
    PL^.Items := P
  else
    PI^.Next := P;
  PI := P;
  end;

{-DataCompBoy-}
procedure MakeColorDialog;
  begin
  PI := nil;
  PL := nil;
  PP := nil;
  while not Eof(F.T) do
    begin
    Readln(F.T, S);
    S := DefineParser.ProceedStr2(S);
    Inc(Line);
    DelLeft(S);
    FreeStr := S;
    UpStr(FreeStr);
    if  (S <> '') and (S[1] <> ';') then
      if Copy(FreeStr, 1, Length(idColorGroup)) = idColorGroup then
        MakeGroup
      else if Copy(FreeStr, 1, Length(idColorItem)) = idColorItem then
        MakeItem
      else if Copy(FreeStr, 1, Length(idEND)) = idEND then
        Break
      else
        Error('Unknown identifier in line '+ItoS(Line));
    end;
  D := TColorDialog.Create(MakePalette(''), PP);
  D.HelpCtx := hcColorDialog;
  StoreResource(D, dlgColors);
  D.Free;
  end { MakeColorDialog };
{-DataCompBoy-}

{-DataCompBoy-}
procedure MakeEditorCommands;
  var
    I, J: LongInt;
    T: TEditSaver;

  procedure MakeCommand;
    begin
    if NumCommands = MaxCommands then
      Error('Editor Commands top limit ('+ItoS(MaxCommands)+') reached');
    Inc(NumCommands);
    i := Length(idCommand);
    with EditCommands[NumCommands] do
      begin
      C := GetID(Token(S, i));
      C1 := GetID(Token(S, i));
      C2 := GetID(Token(S, i));
      FreeStr := Token(S, i)+#0#0;
      Move(FreeStr[1], CC1, 2);
      FreeStr := Token(S, i)+#0#0;
      Move(FreeStr[1], CC2, 2);
      end;
    end;

  begin { MakeEditorCommands }
  FillChar(EditCommands, SizeOf(EditCommands), 0);
  NumCommands := 0;
  while not Eof(F.T) do
    begin
    Readln(F.T, S);
    S := DefineParser.ProceedStr2(S);
    Inc(Line);
    DelLeft(S);
    FreeStr := UpStrg(S);
    if  (S <> '') and (S[1] <> ';') then
      if Copy(FreeStr, 1, Length(idCommand)) = idCommand then
        MakeCommand
      else if Copy(FreeStr, 1, Length(idEND)) = idEND then
        Break
      else
        Error('Unknown identifier in line '+ItoS(Line));
    end;
  T := TEditSaver.Create;
  StoreResource(T, dlgEditorCommands);
  T.Free;
  end { MakeEditorCommands };
{-DataCompBoy-}

procedure ProcessDLGs;
  var
    tP: TTypeHolder;
    St: TStream;
  function GetID(const S: String): LongInt;
    var
      T: TLngWord;
      I: Integer;
      L: LongInt;
    begin
    FreeStr := S;
    DelRight(FreeStr);
    if S[Length(S)] = ',' then
      SetLength(FreeStr, Length(FreeStr)-1);
    DelRight(FreeStr);
    T := TLngWord.Create(0, FreeStr);
    if IDs.Search(T, L) then
      begin
      GetID := TLngWord(IDs.At(L)).L;
      end
    else
      begin
      Val(FreeStr, L, I);
      if I > 0 then
        Error('Unknown identifier ('+FreeStr+') in line '+ItoS(Line));
      GetID := L;
      end;
    end { GetID };

  procedure SetSavers;
    
    var
      D: TDialog;
    begin
    D := MakeSaversDialog;
    StoreResource(D, dlgSaversSetup);
    D.Free;
    
    end;

  function CompileStatus: PStatusDef;
    var
      PM, PL: PStatusItem;
      DM, DL: PStatusDef;
      I, J: LongInt;
      S: String;

    procedure MakeStatusDef;
      var
        P: PStatusDef;
      begin
      i := Length(idStatusDef);
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); P := NewStatusDef(TkL[1], TkL[2], nil, nil) end;
      if DL = nil then
        dM := P
      else
        DL^.Next := P;
      DL := P;
      PL := nil;
      end;

    procedure MakeStatusItem;
      var
        P: PStatusItem;
        A: Integer;
      begin
      if DL = nil then
        Error('Could not make Status Item without Status Definition');
      i := Length(idStatusItem);
      TkS[1] := Token(S, i);
      TkS[2] := Token(S, i);
      if i > Length(S) then
        begin { StatusItem 'text', action }
        A := ActionIndex(TkS[2]);
        P := NewStatusKey(TkS[1], Acts.Items[A].KeyCode, Acts.Items[A].Command, nil);
        end
      else
        begin { StatusItem 'text', key, command }
        TkL[2] := GetID(TkS[2]);
        TkL[3] := GetID(Token(S, i));
        P := NewStatusKey(TkS[1], TkL[2], TkL[3], nil);
        end;
      if PL = nil then
        DL^.Items := P
      else
        PL^.Next := P;
      PL := P;
      end;

    {-DataCompBoy-}
    begin { CompileStatus: }
    DM := nil;
    DL := nil;
    PM := nil;
    PL := nil;
    while not Eof(F.T) do
      begin
      Readln(F.T, S);
      S := DefineParser.ProceedStr2(S);
      Inc(Line);
      DelLeft(S);
      if  (S <> '') and (S[1] <> ';') then
        if UpStrg(Copy(S, 1, Length(idStatusDef))) = idStatusDef then
          MakeStatusDef
        else if UpStrg(Copy(S, 1, Length(idStatusItem))) = idStatusItem
        then
          MakeStatusItem
        else if UpStrg(Copy(S, 1, Length(idEND))) = idEND then
          Break
        else if (S <> '') and (S[1] <> ';') then
          Error('Unknown identifier in line '+ItoS(Line));
      end;
    CompileStatus := DM;
    end { CompileStatus: };
  {-DataCompBoy-}

  procedure MakeStatus;
    var
      PM: PStatusDef;
      R: TRect;
    begin
    PM := CompileStatus;
    R := TRect.Create(0, 0, 80, 1);
    StatusLine := TStatusLine.Create(R, PM);
    StoreResource(StatusLine, dlgStatusLine);
    StatusLine.Free;
    StatusLine := nil;
    end;

  function CompileMenu(S: String): PMenu;
    var
      PM, PL: PMenuItem;
      S1, S2: String;
      I, J: LongInt;

    procedure AddItem(P: Pointer);
      begin
      if PM = nil then
        PM := P
      else
        PL^.Next := P;
      PL := P;
      end;

    procedure MakeSubMenu;
      begin
      i := Length(idSubMenu);
      S1 := Token(S, i);
      S2 := Token(S, i);
      AddItem(NewSubMenu(S1, GetID(S2), CompileMenu(S), nil));
      end;

    procedure MakeMenuItem;
      var
        A: Integer;
      begin
      i := Length(idMenuItem);
      TkS[1] := Token(S, i);
      TkS[2] := Token(S, i);
      if i > Length(S) then
        begin { MenuItem 'caption', action: the key, its text, the command and the help context come from the action }
        A := ActionIndex(TkS[2]);
        with Acts.Items[A] do
          begin
          if Caption = '' then
            Caption := TkS[1];
          AddItem(NewItem(TkS[1], KeyText, KeyCode, Command, HelpCtx, nil));
          end;
        end
      else
        begin { MenuItem 'caption', 'key text', key, command, help context }
        TkL[3] := GetID(Token(S, i));
        TkL[4] := GetID(Token(S, i));
        TkL[5] := GetID(Token(S, i));
        AddItem(NewItem(TkS[1], TkS[2], TkL[3], TkL[4], TkL[5], nil));
        end;
      end;

    procedure MakeMenuLine;
      begin
      AddItem(NewLine(nil));
      end;

    {-DataCompBoy-}
    begin { CompileMenu }
    CompileMenu := nil;
    PL := nil;
    PM := nil;
    while not Eof(F.T) do
      begin
      Readln(F.T, S);
      S := DefineParser.ProceedStr2(S);
      Inc(Line);
      DelLeft(S);
      if  (S <> '') and (S[1] <> ';') then
        if UpStrg(Copy(S, 1, Length(idSubMenu))) = idSubMenu then
          MakeSubMenu
        else if UpStrg(Copy(S, 1, Length(idMenuItem))) = idMenuItem then
          MakeMenuItem
        else if UpStrg(Copy(S, 1, Length(idMenuLine))) = idMenuLine then
          MakeMenuLine
        else if UpStrg(S) = idEND then
          Break
        else if (S <> '') and (S[1] <> ';') then
          Error('Unknown identifier in line '+ItoS(Line));
      end;
    CompileMenu := NewMenu(PM);
    end { CompileMenu };
  {-DataCompBoy-}

  procedure MakeMenu(S: String);
    var
      ID: TDlgIdx;
      T: TLngWord;
      R: TRect;
      D: TMenuBar;
      I: LongInt;
      J: LongInt;
    begin
    I := Length(idMenu);
    FreeStr := Token(S, I);
    T := TLngWord.Create(0, FreeStr);
    if not DLGs.Search(T, J) then
      Error('Unknown Resource ID - '+T.Name);
    ID := TDlgIdx(TLngWord(DLGs.At(J)).l);
    FillChar(R, SizeOf(R), 0);
    D := TMenuBar.Create(R, CompileMenu(S));
    StoreResource(D, ID);
    D.Free;
    end;

  procedure CompileDialog(S: String; IdToken: String);
    var
      D: TDialog;
      Notepad: TNotepad;
      Page: TPage;
      R: TRect;
      I: LongInt;
      J: LongInt;
      PV: TView;
      LastSB: TScrollBar;
      nDirectLink: Byte;
      InPage: Boolean;

    function IsThis(const S: String): Boolean;
      begin
      i := Length(S);
      IsThis := Copy(FreeStr, 1, i) = S;
      end;

    procedure MakeInputLine;
      var
        P: THistory;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      R.B.Y := R.A.Y+1;
      PV := TInputLine.Create(R, GetID(Token(S, i)));
      D.Insert(PV);
      j := GetID(Token(S, i));
      if j > 0 then
        begin
        R.A.X := R.B.X;
        R.B.X := R.A.X+3;
        P := THistory.Create(R, TInputLine(PV), j);
        D.Insert(P);
        end;
      end;

    procedure MakeLongInputLine;
      var
        P: THistory;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      R.B.Y := R.A.Y+1;
      PV := TLongInputLine.Create(R, GetID(Token(S, i)));
      D.Insert(PV);
      j := GetID(Token(S, i));
      if j > 0 then
        Error('LongInputLine dosn''t have a history, line '+ItoS(Line));
      end;

    {-DataCompBoy-}
    procedure MakeHexLine;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      R.B.Y := R.A.Y+1;
      PV := THexLine.Create(R, TInputLine(PV));
      D.Insert(PV);
      end;
    {-DataCompBoy-}

    procedure MakeLabel;
      var
        B: String;
        P: TLabel;
      begin
      R.A.X := GetID(Token(S, i));
      R.A.Y := GetID(Token(S, i));
      R.B.Y := R.A.Y+1;
      B := Token(S, i);
      R.B.X := R.A.X+2+CStrLen(B);
      P := TLabel.Create(R, B, PV);
      D.Insert(P);
      while i < Length(S) do
        P.Options := P.Options or GetID(Token(S, i));
      end;

    {-DataCompBoy-}
    function GetItems: TSItem;
      var
        P, PP: TSItem;
        S: String;
        K: Integer;
      begin
      PP := nil;
      K := i;
      while not Eof(F.T) do
        begin
        Readln(F.T, S);
        S := DefineParser.ProceedStr2(S);
        Inc(Line);
        DelLeft(S);
        DelRight(S);
        FreeStr := S;
        UpStr(FreeStr);
        if IsThis(idItem) then
          begin
          if PP = nil then
            begin
            P := TSItem.Create(Token(S, i), nil);
            PP := P
            end
          else
            begin
            P.Next := TSItem.Create(Token(S, i), nil);
            P := P.Next
            end;
          end
        else if IsThis(idEND) then
          Break
        else if (S <> '') and (S[1] <> ';') then
          Error('Unknown identifier in line '+ItoS(Line));
        end;
      GetItems := PP;
      i := K;
      end { GetItems: };
    {-DataCompBoy-}

    procedure MakeCheckBoxes;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      PV := TCheckBoxes.Create(R, GetItems);
      D.Insert(PV);
      end;

    procedure MakeDriveCheckBoxes;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      PV := TCurrDriveInfo.Create(R, GetItems);
      D.Insert(PV);
      with PV do
        begin
        Options := Options or ofPostProcess;
        EventMask := evBroadcast+evCommand+evKeyDown+evMouseDown;
        end;
      end;

    procedure MakeRadioButtons;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      PV := TRadioButtons.Create(R, GetItems);
      D.Insert(PV);
      end;

    procedure MakeComboBox;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      PV := TComboBox.Create(R, GetItems);
      D.Insert(PV);
      end;

    procedure MakePage;
      begin
      if InPage then
        Page.SelectNext(False);
      Page := Notepad.NewPage((Token(S, i)));
      end;

    procedure MakeButton;
      var
        B, K: String;
        Flags, Options: Word;
        CmD: Word;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      K := Token(S, i);
      CmD := GetID(Token(S, i));
      Flags := 0;
      Options := 0;
      while i < Length(S) do
        begin
        B := Token(S, i);
        UpStr(B);
        if B = 'BFDEFAULT' then
          Flags := Flags or bfDefault
        else if B = 'BFNORMAL' then
          Flags := Flags or bfNormal
        else if B = 'BFBROADCAST' then
          Flags := Flags or bfBroadcast
        else if B = 'BFLEFTJUST' then
          Flags := Flags or bfLeftJust
        else if B = 'BFGRABFOCUS' then
          Flags := Flags or bfGrabFocus
        else
          Options := Options or GetID(B);
        end;
      PV := TButton.Create(R, K, CmD, Flags);
      PV.Options := PV.Options or Options;
      D.Insert(PV);
      end { MakeButton };

    procedure MakeScrollBar(Mouse: Boolean);
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      if Mouse then
        LastSB := TMouseBar.Create(R)
      else
        LastSB := TScrollBar.Create(R);
      D.Insert(LastSB);
      end;

    procedure MakeListBox;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      PV := TListBox.Create(R, GetID(Token(S, i)), LastSB);
      D.Insert(PV);
      end;

    procedure MakeStaticText;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      PV := TStaticText.Create(R, Token(S, i));
      D.Insert(PV);
      end;

    procedure MakeParamText;
      begin
      begin TkL[1] := GetID(Token(S, i)); TkL[2] := GetID(Token(S, i)); TkL[3] := GetID(Token(S, i)); TkL[4] := GetID(Token(S, i)); R := TRect.Create(TkL[1], TkL[2], TkL[3], TkL[4]) end;
      begin TkS[1] := Token(S, i); TkL[2] := GetID(Token(S, i)); PV := TParamText.Create(R, TkS[1], TkL[2]) end;
      D.Insert(PV);
      end;

    procedure MakeColorPoint;
      var
        P: TColorPoint;
      begin
      R.A.X := GetID(Token(S, i));
      R.B.X := R.A.X+1;
      R.A.Y := GetID(Token(S, i));
      R.B.X := R.A.X+1;
      P := TColorPoint.Create(R, GetID(Token(S, i)));
      D.Insert(P);
      while i < Length(S) do
        P.Options := P.Options or GetID(Token(S, i));
      end;

    { GROW flag, flag...: the grow mode of the last control (the names of tv3: gfGrowLoX gfGrowLoY gfGrowHiX gfGrowHiY
      gfGrowAll gfGrowRel, or a number; 0 = it stays); the layout of TResDialog keeps it }
    procedure MakeGrow;
      var
        B: String;
        G, K: Integer;
      begin
      if PV = nil then
        Error('GROW without a control in line '+ItoS(Line));
      G := 0;
      while i <= Length(S) do
        begin
        B := UpStrg(Token(S, i));
        DelLeft(B);
        DelRight(B);
        if B = 'GFGROWLOX' then G := G or gfGrowLoX
        else if B = 'GFGROWLOY' then G := G or gfGrowLoY
        else if B = 'GFGROWHIX' then G := G or gfGrowHiX
        else if B = 'GFGROWHIY' then G := G or gfGrowHiY
        else if B = 'GFGROWALL' then G := G or gfGrowAll
        else if B = 'GFGROWREL' then G := G or gfGrowRel
        else if B <> '' then
          begin
          Val(B, K, J);
          if (J <> 0) or (K < 0) or (K > $3F) then
            Error('Unknown grow mode ('+B+') in line '+ItoS(Line));
          G := G or K;
          end;
        end;
      PV.GrowMode := G or gfExplicit;
      end;

    { RESIZE NONE | X | Y | XY: the directions the dialog may grow in (the default: as its layout finds) }
    procedure MakeResize;
      var
        B: String;
      begin
      if not (D is TResDialog) then
        Error('RESIZE in a dialog that cannot be resized, line '+ItoS(Line));
      B := UpStrg(Token(S, i));
      DelLeft(B);
      DelRight(B);
      if B = 'NONE' then TResDialog(D).Resize := rzNone
      else if B = 'X' then TResDialog(D).Resize := rzX
      else if B = 'Y' then TResDialog(D).Resize := rzY
      else if B = 'XY' then TResDialog(D).Resize := rzXY
      else
        Error('RESIZE: NONE, X, Y or XY expected in line '+ItoS(Line));
      end;

    var
      ID: TDlgIdx;
      T: TLngWord;

    const
      DData: TSysData = (
        Options: 0;
        Mode1: '';
        Mode2: '';
        Temp: '';
        Drives: (List: nil; Focus: 0);
        Current: 0;
        CopyLimitBuf: '';
        ForceDefArch: ''
        );

      {-DataCompBoy-}
    begin { CompileDialog }
    I := Length(idToken);
    PV := nil;
    LastSB := nil;
    InPage := False;
    FreeStr := Token(S, I);
    T := TLngWord.Create(0, FreeStr);
    if not DLGs.Search(T, J) then
      Error('Unknown Resource ID: '+T.Name);
    ID := TDlgIdx(TLngWord(DLGs.At(J)).l);
    begin TkL[1] := GetID(Token(S, I)); TkL[2] := GetID(Token(S, I)); R := TRect.Create(0, 0, TkL[1], TkL[2]) end;
    if ID = dlgSystemSetup then
      begin
      D := TSysDialog.Create(R, Token(S, I));
      D.Awaken;
      end
    else if IdToken = idNotepad then
      begin
      begin TkS[1] := Token(S, I); TkL[2] := GetID(Token(S, I)); Notepad := TNotepad.Create(R, TkS[1], TkL[2]) end;
      D := Notepad; // everything will be inserted into the dialog
      end
    else {idDialog}
      D := TResDialog.Create(R, Token(S, I));
    D.Options := D.Options or ofCentered;
    while not Eof(F.T) do
      begin
      Readln(F.T, S);
      S := DefineParser.ProceedStr2(S);
      Inc(Line);

      { Parse a direct-link label #1 .. #9, strictly from position 1}
      nDirectLink := 0; // 0 - no label
      if (Length(S) >= 2) and (S[1] = '#') and (S[2] in ['1'..'9']) then
        begin
        nDirectLink := Byte(S[2]) - Byte('0');
        S[1] := ' '; S[2] := ' ';
        end;

      DelLeft(S);
      FreeStr := UpStrg(S);
      if  (S <> '') and (S[1] <> ';') then
        begin
        if IsThis(idInputLine) then
          MakeInputLine
        else if IsThis(idLongInputLine) then
          MakeLongInputLine
        else if IsThis(idHexLine) then
          MakeHexLine
        else if IsThis(idHelpCtx) then
          begin
          if PV = nil then
            D.HelpCtx := GetID(Token(S, I))
          else
            PV.HelpCtx := GetID(Token(S, I))
          end
        else if IsThis(idLabel) then
          MakeLabel
        else if IsThis(idStaticText) then
          MakeStaticText
        else if IsThis(idParamText) then
          MakeParamText
        else if IsThis(idListBox) then
          MakeListBox
        else if IsThis(idScrollBar) then
          MakeScrollBar(False)
        else if IsThis(idMScrollBar) then
          MakeScrollBar(True)
        else if IsThis(idCheckBoxes) then
          MakeCheckBoxes
        else if IsThis(idDriveCheckBox) then
          MakeDriveCheckBoxes
        else if IsThis(idSelectForward) then
          D.SelectNext(False)
        else if IsThis(idSelectBack) then
          D.SelectNext(True)
        else if IsThis(idRadioButtons) then
          MakeRadioButtons
        else if IsThis(idComboBox) then
          MakeComboBox
        else if IsThis(idPage) then
          begin
          MakePage;
          inPage := True;
          D := Page;
          end
        else if IsThis(idButton) then
          MakeButton
        else if IsThis(idColorPoint) then
          MakeColorPoint
        else if IsThis(idGrow) then
          MakeGrow
        else if IsThis(idResize) then
          MakeResize
        else if IsThis(idEND) then
          begin
          if not inPage then
            Break;
          inPage := False;
          Page.SelectNext(False);
          D := Notepad;
          end
        else if (S <> '') and (S[1] <> ';') then
          Error('Unknown identifier in line '+ItoS(Line));
        if nDirectLink <> 0 then
          begin { remember a direct link to the current resource }
          if D.DirectLink[nDirectLink] <> nil then
            Error('Direct Link Label redefined in line '+ItoS(Line));
          D.DirectLink[nDirectLink] := PV;
          end;
        while I < Length(S) do
          PV.Options := PV.Options or GetID(Token(S, I));
        end;
      end;
    D.SelectNext(False);
    StoreResource(D, ID);
    if ID = dlgSystemSetup then
      begin
      DData.Drives.List := TLineCollection.Create(0, 10, False);
      D.SetData(DData);
      end;
    D.Free;
    end { CompileDialog };
  {-DataCompBoy-}

  procedure DoInsert(P_: Pointer);
  var P: TLngWord absolute P_;
    begin
    IDs.Insert(P);
    end;

  function FailCheck: Boolean;
    procedure DoCheck(P_: Pointer);
    var P: TLngWord absolute P_;
      begin
      if P.Mark <> 1 then
        begin
        Writeln('Unresolved identifier "', P.Name, '"');
        FailCheck := True;
        end;
      end;
    begin
    FailCheck := False;
    DLGs.ForEach(DoCheck);
    end;

  {-DataCompBoy-}
  begin { ProcessDLGs }
  DLGs := Types.GetType(tidDLGs);
  IDs := TTypeHolder.Create('', tmConst);
  tP := Types.GetType(tidCommands);
  tP.ForEach(DoInsert);
  tP := Types.GetType(tidHelpCtx);
  tP.ForEach(DoInsert);
  tP := Types.GetType(tidHistory);
  tP.ForEach(DoInsert);
  tP := Types.GetType(tidKbdconst);
  tP.ForEach(DoInsert);
  tP := Types.GetType(tidOptions);
  tP.ForEach(DoInsert);

  LoadActions;
  Writeln('Reading ', dlgFileName);
  lAssignText(F, dlgFileName);
  ClrIO;
  lResetText(F);
  Line := 0;
  if IOResult <> 0 then
    Error('Could not open input file');
  St := TBufStream.Create(SysOsPath(OutDlgFileName), stCreate, 512);
  if St.Status <> stOK then
    begin
    Close(F.T);
    St.Free;
    EraseFile(OutDlgFileName);
    Error('Could not create output file '+OutDlgFileName);
    end;

  TheRF := TIdxMaker.Create(St);
  while not Eof(F.T) do
    begin
    Readln(F.T, S);
    S := DefineParser.ProceedStr2(S);
    Inc(Line);
    Write(#13'(', Line, ')');
    DelLeft(S);
    FreeStr := UpStrg(S);
    if  (S <> '') and (S[1] <> ';') then
      if Copy(FreeStr, 1, Length(idColorDialog)) = idColorDialog then
        MakeColorDialog
      else if Copy(FreeStr, 1, Length(idDialog)) = idDialog then
        CompileDialog(S, idDialog)
      else if Copy(FreeStr, 1, Length(idNotepad)) = idNotepad then
        CompileDialog(S, idNotepad)
      else if Copy(FreeStr, 1, Length(idMenu)) = idMenu then
        MakeMenu(S)
      else if FreeStr = idActions then
        MakeActionKeys
      else if Copy(FreeStr, 1, Length(idStatusLine)) = idStatusLine then
        MakeStatus
      else if Copy(FreeStr, 1, Length(idEditorCommands))
         = idEditorCommands
      then
        MakeEditorCommands
      else
        Error('Unknown identifier in line '+ItoS(Line));
    end;

  Close(F.T);
  SetSavers;
  StoreResource(Acts, dlgActions);
  if FailCheck then
    Halt(1);

  Writeln(#13'Writing ', OutDlgFileName);
  TheRF.Free;

  IDs.RemoveAll;
  IDs.Free;
  end { ProcessDLGs };
{-DataCompBoy-}

{-DataCompBoy-}
function GetName(S: String): String;
  var
    P, N, E: String;
  begin
  lFSplit(S, P, N, E);
  GetName := N;
  end;
{-DataCompBoy-}

procedure CleanupTypes;
  procedure DoClean(P_: Pointer);
  var P: TTypeHolder absolute P_;
    procedure DoUnmark(P_: Pointer);
    var P: TLngWord absolute P_;
      begin
      P.Mark := 0
      end;
    begin
    P.ForEach(DoUnmark);
    end;
  begin
  Types.ForEach(DoClean);
  end;

function ReplaceChar(A, B: Char; S: String): String;
  begin
  Replace(A, B, S);
  ReplaceChar := S;
  end;

var
  INI: TIniFile;
  INIs: Integer;
  Lng: String;
  LList: String;

procedure InitParser;
  var
    Sec: TIniSection;
    I: Integer;
    K, S: String;
  begin
  Sec := INI.GetSection('Parser');
  if Sec <> nil then
    begin
    for I := 0 to Sec.Count-1 do
      begin
      K := UpStrg(Sec.GetKeyAt(I));
      if K <> '' then
        begin
        S := Sec.GetValueAt(I);
        DelDoubles('  ', S);
        if K = 'CONST' then
          Types.Insert(TTypeHolder.Create(ReplaceChar(' ', #0,
                 S+' '), tmConst))
        else if K = 'TYPE' then
          Types.Insert(TTypeHolder.Create(S, tmEnum))
        else
          Error('Undefined keyword "'+K+'" in [Parser] section');
        end;
      end;
    end;
  end { InitParser };

function CutWord(const S: String; No: Integer): String;
  { S without word #No }
  var
    I, K: Integer;
  label
    Same;
  begin
  if No < 1 then
    goto Same;
  I := SeekWord(S, No);
  if I > 0
  then
    CutWord := Copy(S, 1, I-1)
        +Copy(S, wSkipBlank(S, wSkipText(S, I)), MaxStringLength)
  else
Same:
    CutWord := S;
  end;

function Build_RStringList(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStrL.TStringList.Load(S));
end;

function Build_REditSaver(S: TStream): TStreamable;
begin
  Result := TStreamable(TEditSaver.Load(S));
end;

procedure Store_REditSaver(P: TStreamable; S: TStream);
begin
  TEditSaver(P).Store(S);
end;

procedure SetStreamRecs_rcp;
begin

  RStringList.VmtLink := PtrUInt(System.TClass(DNStrL.TStringList));
  RStringList.Load := @Build_RStringList;

  REditSaver.VmtLink := PtrUInt(System.TClass(TEditSaver));
  REditSaver.Load := @Build_REditSaver;

  REditSaver.Store := @Store_REditSaver;

end;

begin
SetStreamRecs_rcp;
Writeln(#13'Resource Compiler for DN OSP 1.51.07a+  Version 1.08');
Writeln('Copyright(C) 1994,95 RIT Research Labs');
Writeln('Copyright(C) 1995 AxoN(R)Soft');

{Cat}
{/Cat}

{Cat: choose which config file to use:
      - command line W or W32 → RCPVPW.INI
      - command line D or D32 → RCPVPD.INI
      - empty command line → the config file for the
      system RCP.EXE was compiled for}

FreeStr := ParamStr(1);
UpStr(FreeStr);
if  (FreeStr = 'W') or (FreeStr = 'W32')
  or (FreeStr = 'D') or (FreeStr = 'D32')
  or (FreeStr = '')
then
  begin
  if FreeStr = '' then
    
    
    
    FreeStr := 'D';
    
  
  
  Writeln('Using config file RCPVP'+FreeStr[1]+'.INI');
  INI := TIniFile.Create('RCPVP'+FreeStr[1]+'.INI', INIs);
  if INIs <> stOK then
    Error('File RCPVP'+FreeStr[1]+'.INI not found.');
  end
else
  Error('Invalid parameter "'+FreeStr+'".');
{/Cat}

RegisterType(RStrListMaker);
RegisterAll;
RegisterType(REditSaver);

Types := TValuesHolder.Create(10, 10);
InitParser;

{-DataCompBoy-}
DefineParser := TDefCollection.Create($10, $10);
LList := INI.Get('Controls', 'Defines');
repeat
  Lng := GetWord(LList, 1);
  if Lng <> '' then
    begin
    DefineParser.ProceedFile(Lng);
    LList := CutWord(LList, 1);
    end
  else
    Break
until False;
{-DataCompBoy-}

ActionsFileName := INI.Get('Controls', 'Actions');
if ActionsFileName = '' then
  Error('No Actions file in the section [Controls].');

LList := INI.Get('Controls', 'Indexes');
repeat
  Lng := GetWord(LList, 1);
  if Lng <> '' then
    begin
    ProcessFile(Lng, Types);
    LList := CutWord(LList, 1);
    end
  else
    Break
until False;

LList := INI.Get('Controls', 'Languages');
repeat
  Lng := GetWord(LList, 1);
  if Lng <> '' then
    begin
    if UpStrg(INI.Get(Lng, 'ProcessDLs')) = 'YES' then
      begin
      LngFileName := INI.Get(Lng, 'LngInput');
      if LngFileName = '' then
        Error('No LNG input file defined for language "'+Lng+'".');
      OutLngFileName := INI.Get(Lng, 'LngOutput');
      if OutLngFileName = '' then
        Error('No LNG output file defined for language "'+Lng+'".');
      ProcessDLs(True);
      end
    else
      ProcessDLs(False);
    dlgFileName := INI.Get(Lng, 'DlgInput');
    if dlgFileName = '' then
      Error('No DLG input file defined for language "'+Lng+'".');
    OutDlgFileName := INI.Get(Lng, 'DlgOutput');
    if OutDlgFileName = '' then
      Error('No DLG output file defined for language "'+Lng+'".');
    ProcessDLGs;
    if LStringList <> nil then
      begin
      LStringList.Free;
      LStringList := nil;
      end;
    DLStream.Free;
    ReRegisterType(RStrListMaker);
    CleanupTypes;
    LList := CutWord(LList, 1);
    end
  else
    Break;
until False;
Types.Free;
end.
