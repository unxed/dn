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
unit editwin;

interface

uses
  Defines, Streams, objutil, editcore, Menus, editundo, UniWin
  ;

type
  { TEditWindow }

  PEditWindow = ^TEditWindow;
  TEditWindow = class(TUniWindow)
    {Cat: этот объект вынесен в плагинную модель; изменять крайне осторожно!}
    AInfo: PInfoLine;
    ABookLine: PBookmarkLine;
    Intern: PFileEditor;
    MenuBar: PMenuBar;
    UpMenu: PMenu;
    ModalEnd: Boolean;
    constructor Init(R: TRect; FileName: String);
    constructor Load(var S: TStream);
    //    procedure ChangeBounds(const R: TRect); virtual;
    procedure Store(var S: TStream);
{AK155 04/04/2006
  Execute нигде не используется, и зачем он нужен - непонятно.
  Вероятно, введён на случай модального окна редактора, только
  вряд ли такое может понадобиться кому-то.
    function Execute: Word; virtual;
}
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    end;

implementation
uses
  editfile, mainapp, Commands, DNHelp, Views,
  Startup, strutil, FViewer, Drivers, Editor, basics
  
  ;

type
  PEditSaver = ^TEditSaver;
  TEditSaver = class(TObject)
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    end;

const
  REditSaver: TStreamRec = (ObjType: 12335; VmtLink: 0; Load: nil; Store: nil; Next: nil);

  Registered: Boolean = False;

constructor TEditSaver.Load(var S: TStream);
  begin
  S.Read(MaxCommands, SizeOf(MaxCommands));
  S.Read(EditCommands, SizeOf(TEditCommand)*MaxCommands);
  end;

procedure TEditSaver.Store(var S: TStream);
  begin
  S.Write(MaxCommands, SizeOf(MaxCommands));
  S.Write(EditCommands, SizeOf(TEditCommand)*MaxCommands);
  end;

procedure LoadCommands;
  var
    P: PEditSaver;
  begin
  if MaxCommands = 0 then
    begin
    if not Registered then
      RegisterType(REditSaver);
    Registered := True;
    P := PEditSaver(LoadResource(dlgEditorCommands));
    P^.Free;
    end;
  end;

constructor TEditWindow.Load(var S: TStream);
  var
    PI: PMenuItem;
    R: TRect;
  begin
  inherited Load(S);
  GetSubViewPtr(S, Intern);
  GetSubViewPtr(S, AInfo);
  GetSubViewPtr(S, ABookLine); {-$VIV}
  { GetSubViewPtr(S, MenuBar);} (*X-Man*)
  if  (Intern = nil) or (AInfo = nil) or (ABookLine = nil) then
    {Cat}
    Fail;
R.Assign(1, 1, Size.X - 1, 2);
  MenuBar := PMenuBar(LoadResource(dlgEditorMenu));
  if MenuBar <> nil then
    MenuBar^.Locate(R);
  Insert(MenuBar);
  UpMenu := MenuBar^.Menu;

  PI := MenuBar^.Menu^.Items;
  while (PI <> nil) and (PI^.HelpCtx <> hcedOptions) do
    PI := PI^.Next;
  if  (PI <> nil) then
    PI := Pointer(PI^.SubMenu);
  PFileEditor(Intern)^.OptMenu := Pointer(PI);
  if Title <> nil then
    DisposeStr(Title);
  if PFileEditor(Intern)^.SmartPad then
    begin
    Title := NewStr('SmartPad(TM) - '+PFileEditor(Intern)^.EditName);
    end
  else if PFileEditor(Intern)^.ClipBrd then
    begin
    Title := NewStr('Clipboard');
    end
  else
    Title := NewStr(GetString(dlEditTitle)+' - '+
        (PFileEditor(Intern)^.EditName));
  LoadCommands;
  end { TEditWindow.Load };

{procedure TEditWindow.ChangeBounds;
var rr: TRect;
begin
 inherited ChangeBounds(R);
 Intern^.HScroll^.GetBounds(rr); RR.B.X:=Size.X - 2;
 Intern^.HScroll^.SetBounds(rr);
 if not (Intern^.SmartPad or GetState(sfModal)) then
    begin
      GetBounds(TempBounds);
      LastEditDeskSize := Desktop^.Size;
    end;
end;
}
(*
function TEditWindow.Execute: Word;
  var
    Event: TEvent;
  begin
  ModalEnd := False;
  repeat
    GetEvent(Event);
    if Event.What <> evNothing then
      HandleEvent(Event)
    else
      TinySlice;
  until ModalEnd;
  end;
*)
procedure TEditWindow.Store(var S: TStream);
  var
    Parts: array[0..2] of PView;
    I: Integer;
  begin
  inherited Store(S);
  Parts[0] := Intern;
  Parts[1] := AInfo;
  Parts[2] := ABookLine;
  for I := 0 to 2 do
    PutSubViewPtr(S, Parts[I]);
  end;

{ TEditWindow }
constructor TEditWindow.Init(R: TRect; FileName: String);
  var
    pm: PMenu;
    Pi: PMenuItem;
  begin
  inherited Init(R, '', 0);
  LoadCommands;
  Options := Options or ofTileable;
  Flags := Flags or wfMaxi;

R.Assign(1, 1, Size.X - 1, 2);
  MenuBar := PMenuBar(LoadResource(dlgEditorMenu));
  if MenuBar <> nil then
    MenuBar^.Locate(R);
  Insert(MenuBar);

  {MenuBar^.Options := MenuBar^.Options or ofPostProcess;}
R.Assign(1, 2, Size.X - 1, Size.Y - 1);

  Intern := New(PXFileEditor, Init(R,
        MakeScrollBar(sbHorizontal+sbHandleKeyboard),
        MakeScrollBar(sbVertical+sbHandleKeyboard), FileName));

  {FreeObject(Intern);}

  Pi := MenuBar^.Menu^.Items;
  while (Pi <> nil) and (Pi^.HelpCtx <> hcedOptions) do
    Pi := Pi^.Next;
  if  (Pi <> nil) then
    Pi := Pointer(Pi^.SubMenu);
  PFileEditor(Intern)^.OptMenu := Pointer(Pi);

  Insert(Intern);
  MILoadFile(Intern, FileName);
  if not Intern^.isValid then
    begin
    Done;
    Fail;
    end;
R.Assign(2, Size.Y - 1, Size.X - 2, Size.Y);
  AInfo := New(PInfoLine, Init(R));
  InsertBefore(AInfo, First);
  GetExtent(R);
  R.B.X := R.A.X+1;
  Inc(R.A.Y, 2);
  Dec(R.B.Y);
  ABookLine := New(PBookmarkLine, Init(R));
  ABookLine^.GrowMode := gfGrowHiY;
  Insert(ABookLine);

  Intern^.InfoL := AInfo;
  Intern^.BMrk := ABookLine;
  end { TEditWindow.Init };

procedure TEditWindow.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  Redraw;
  end;

type
  PR_REditSaver = ^TEditSaver;

function Build_REditSaver(var S: TStream): TStreamable;
begin
  Result := TStreamable(New(PR_REditSaver, Load(S)));
end;

procedure Store_REditSaver(P: TStreamable; var S: TStream);
begin
  PR_REditSaver(P)^.Store(S);
end;

procedure SetStreamRecs_edwin;
begin

  REditSaver.VmtLink := PtrUInt(TypeOf(TEditSaver));
  REditSaver.Load := @Build_REditSaver;

  REditSaver.Store := @Store_REditSaver;

end;

initialization
  SetStreamRecs_edwin;
end.
