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
  Defines, Streams, objutil, editcore, Menus, editinfo, UniWin
  ;

type
  { TEditWindow }


  TEditWindow = class(TUniWindow)
    {Cat: this type is in the plugin model; change with extreme care!}
    AInfo: TInfoLine;
    ABookLine: TBookmarkLine;
    Intern: TFileEditor;
    MenuBar: TMenuBar;
    UpMenu: PMenu;
    ModalEnd: Boolean;
    constructor Create(R: TRect; FileName: String); overload;
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    //    procedure ChangeBounds(const R: TRect); virtual;
    procedure Write(Os: opstream); override;
{AK155 04/04/2006
  Execute is unused anywhere; unclear why it is needed.
  Probably added for a modal editor window, but
  that is unlikely to be needed by anyone.
    function Execute: Word; override;
}
    procedure SetState(AState: Word; Enable: Boolean); virtual;
    end;

{ the stream type of the editor commands of the resource (the first use of the editor registers it; a test registers it to load every key) }
procedure RegisterEditSaver;

implementation
uses
  editfile, mainapp, Commands, DNHelp, Views,
  Startup, strutil, FViewer, Drivers, Editor, basics
  
  ;

type
  { the table of the editor commands in the resources (rcp writes it under the same name) }
  TEditSaver = class(TStreamable)
    constructor Create(AInit: TStreamableInit);
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

const
  Registered: Boolean = False;

constructor TEditSaver.Create(AInit: TStreamableInit);
  begin
  end;

function TEditSaver.StreamableName: ShortString;
  begin
  Result := 'EditWin.TEditSaver';
  end;

class function TEditSaver.Build: TStreamable;
  begin
  Result := TEditSaver.Create(streamableInit);
  end;

function TEditSaver.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  Ip.ReadBytes(MaxCommands, SizeOf(MaxCommands));
  Ip.ReadBytes(EditCommands, SizeOf(TEditCommand)*MaxCommands);
  end;

procedure TEditSaver.Write(Os: opstream);
  begin
  Os.WriteBytes(MaxCommands, SizeOf(MaxCommands));
  Os.WriteBytes(EditCommands, SizeOf(TEditCommand)*MaxCommands);
  end;

procedure RegisterEditSaver;
  begin
  if not Registered then
    TStreamableClass.Create('EditWin.TEditSaver', @TEditSaver.Build);
  Registered := True;
  end;

procedure LoadCommands;
  var
    P: TEditSaver;
  begin
  if MaxCommands = 0 then
    begin
    RegisterEditSaver;
    P := TEditSaver(LoadResource(dlgEditorCommands));
    P.Free;
    end;
  end;

function TEditWindow.Read(Ip: ipstream): Pointer;
  var
    PI: PMenuItem;
    R: TRect;
  begin
  Result := Self;
  inherited Read(Ip);
  Intern := Ip.ReadPointer;
  AInfo := Ip.ReadPointer;
  ABookLine := Ip.ReadPointer; {-$VIV}
  { MenuBar := Ip.ReadPointer;} (*X-Man*)
  if  (Intern = nil) or (AInfo = nil) or (ABookLine = nil) then
    {Cat}
    begin Free; Result := nil; Exit end;
R := TRect.Create(1, 1, Size.X - 1, 2);
  MenuBar := TMenuBar(LoadResource(dlgEditorMenu));
  if MenuBar <> nil then
    MenuBar.Locate(R);
  Insert(MenuBar);
  UpMenu := MenuBar.Menu;

  PI := MenuBar.Menu^.Items;
  while (PI <> nil) and (PI^.HelpCtx <> hcedOptions) do
    PI := PI^.Next;
  if  (PI <> nil) then
    PI := Pointer(PI^.SubMenu);
  TFileEditor(Intern).OptMenu := Pointer(PI);
  if Title <> nil then
    DisposeStr(Title);
  if TFileEditor(Intern).SmartPad then
    begin
    Title := NewStr('SmartPad(TM) - '+TFileEditor(Intern).EditName);
    end
  else if TFileEditor(Intern).ClipBrd then
    begin
    Title := NewStr('Clipboard');
    end
  else
    Title := NewStr(GetString(dlEditTitle)+' - '+
        (TFileEditor(Intern).EditName));
  LoadCommands;
  end { TEditWindow.Load };

{procedure TEditWindow.ChangeBounds;
var rr: TRect;
begin
 inherited ChangeBounds(R);
 rr := Intern^.HScroll.GetBounds; RR.B.X:=Size.X - 2;
 Intern^.HScroll.SetBounds(rr);
 if not (Intern^.SmartPad or GetState(sfModal)) then
    begin
      TempBounds := GetBounds;
      LastEditDeskSize := Desktop.Size;
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
procedure TEditWindow.Write(Os: opstream);
  var
    Parts: array[0..2] of TView;
    I: Integer;
  begin
  inherited Write(Os);
  Parts[0] := Intern;
  Parts[1] := AInfo;
  Parts[2] := ABookLine;
  for I := 0 to 2 do
    Os.WritePointer(Parts[I]);
  end;

class function TEditWindow.Build: TStreamable;
begin
  Result := TEditWindow.Create(streamableInit);
end;

function TEditWindow.StreamableName: ShortString;
begin
  Result := 'editwin.TEditWindow';
end;

{ TEditWindow }
constructor TEditWindow.Create(R: TRect; FileName: String);
  var
    pm: PMenu;
    Pi: PMenuItem;
  begin
  inherited Create(R, '', 0);
  LoadCommands;
  Options := Options or ofTileable;
  Flags := Flags or wfMaxi;

R := TRect.Create(1, 1, Size.X - 1, 2);
  MenuBar := TMenuBar(LoadResource(dlgEditorMenu));
  if MenuBar <> nil then
    MenuBar.Locate(R);
  Insert(MenuBar);

  {MenuBar.Options := MenuBar.Options or ofPostProcess;}
R := TRect.Create(1, 2, Size.X - 1, Size.Y - 1);

  Intern := TXFileEditor.Create(R,
        MakeScrollBar(sbHorizontal+sbHandleKeyboard),
        MakeScrollBar(sbVertical+sbHandleKeyboard), FileName);



  Pi := MenuBar.Menu^.Items;
  while (Pi <> nil) and (Pi^.HelpCtx <> hcedOptions) do
    Pi := Pi^.Next;
  if  (Pi <> nil) then
    Pi := Pointer(Pi^.SubMenu);
  TFileEditor(Intern).OptMenu := Pointer(Pi);

  Insert(Intern);
  MILoadFile(Intern, FileName);
  if not Intern.isValid then
    begin
    Fail;                      { a failing constructor of a class destroys the instance itself: a Free before it destroyed it twice }
    end;
R := TRect.Create(2, Size.Y - 1, Size.X - 2, Size.Y);
  AInfo := TInfoLine.Create(R);
  InsertBefore(AInfo, First);
  R := GetExtent;
  R.B.X := R.A.X+1;
  Inc(R.A.Y, 2);
  Dec(R.B.Y);
  ABookLine := TBookmarkLine.Create(R);
  ABookLine.GrowMode := gfGrowHiY;
  Insert(ABookLine);

  Intern.InfoL := AInfo;
  Intern.BMrk := ABookLine;
  end { TEditWindow.Init };

procedure TEditWindow.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  Redraw;
  end;

end.
