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

unit apploop;

interface

uses
   {Cat}
  DNUtil, Drivers, Views, Collect,
  timeutil, Defines, objutil, FlightRec
  ;

type
  MyApp = class(TDNApplication)
    {Cat: this type is in the plugin model; change with extreme care!}
    procedure HandleEvent(var Event: TEvent); override;
    procedure GetEvent(var Event: TEvent); override;
    procedure Idle; override;
    end;

var
  MyApplication: MyApp;

implementation

uses
  
  osdep, dirwatch, fileutil, mainapp, gadgets,
  Drives, basics, envutil, Commands,
  boot, UserMenu, Messages, Startup,
  panelroot, Macro
  ;

(*{$I  runcmd.inc}*)


{Gimly}
procedure PostQuitMessage;
  var
    Event: TEvent;
  begin
  w95locked := True;
  Event.What := evCommand;
  Event.Message.Command := cmQuit;
  TDNApplication(Application).HandleCommand(Event);
  if w95locked then
    MyApplication.HandleEvent(Event);
  end;


procedure MyApp.GetEvent(var Event: TEvent);
  var
    W: Word;
    WW: Word;
    PM: TKeyMacros;

  const
    MacroPlaying: Boolean = False;
    MacroKey: Integer = 0;
    CurrentMacro: TKeyMacros = nil;
  begin
  
  
  if  (not w95locked) and w95QuitCheck then
    PostQuitMessage; {Gimly}
  

  inherited GetEvent(Event);
  FRNoteEvent(Event);                { the flight recorder: the keys, the clicks and the commands }
  { a test aid (tools/dn-linux-crash.py): with DN_TEST_CRASH set, F12 is an access violation }
  if (Event.What = evKeyDown) and (Event.KeyDown.KeyCode = kbF12) and (GetEnv('DN_TEST_CRASH') <> '') then
    PInteger(nil)^ := 1;
  if MacroPlaying and ((Event.What = evKeyDown) or (Event.What =
         evNothing))
  then
    begin
    Event.What := evKeyDown;
    SetDNKeyCode(Event, CurrentMacro.Keys^[MacroKey]);
    Inc(MacroKey);
    MacroPlaying := MacroKey < CurrentMacro.Count;
    end;
  case Event.What of
    evNothing:
      if  (NeedLocated > 0) and (GetSTime-NeedLocated > 30) then
        begin
        NeedLocated := 0;
        Message(MainApp.Desktop, evCommand, cmDoSendLocated, nil);
        end;
    evKeyDown:
      begin
      {          if (DNKeyCode(Event) = kbAltQ) and Desktop.GetState(sfFocused) then begin OpenSmartpad; ClearEvent(Event) end;}
{$IFDEF DNUTF8}
      { a character outside the code page has no key code, but it has the text (the editor puts it into the table of the document) }
      if (DNKeyCode(Event) = kbNoKey) and (Event.KeyDown.TextLength = 0) then
{$ELSE}
      if DNKeyCode(Event) = kbNoKey then
{$ENDIF}
        begin
        Event.What := evNothing;
        Exit
        end
      else if (not MacroPlaying)
        and (DNKeyCode(Event) = kbAltShiftIns)
        and (ShiftState and kbCtrlShift = 0)
      then
        begin
        Event.What := evNothing;
        ScreenGrabber(False);
        Exit
        end;
      if  (Event.KeyDown.CharScan.ScanCode >= ((kbCtrlF1 shr 8) and $FF))
             and (Event.KeyDown.CharScan.ScanCode <= ((kbCtrlF10 shr 8) and $FF))
        and (Pointer(Current) = Pointer(MainApp.Desktop))
           and (ShiftState and 3 <> 0)
      then
        begin
        if QuickExecExternal(Event.KeyDown.CharScan.ScanCode-((kbCtrlF1 shr 8) and $FF)+1) then
          begin
          Event.What := evCommand;
          Event.Message.Command := cmExecString;
          Event.Message.InfoPtr := @QuickExecExternalStr;
          end
        else
          Event.What := evNothing;
        Exit;
        end;
      if  (ShiftState and 7 <> 0)
             and ((ShiftState and 4 = 0) or (ShiftState and 3 = 0)) and
          (Event.KeyDown.CharScan.ScanCode >= ((kbAlt1 shr 8) and $FF))
           and (Event.KeyDown.CharScan.ScanCode <= ((kbAlt9 shr 8) and $FF))
      then
        begin
        WW := Event.KeyDown.CharScan.ScanCode-((kbAlt1 shr 8) and $FF);
        if ShiftState and 3 <> 0 then
          begin
          if KeyMacroses = nil then
            begin
            KeyMacroses := TObjCollection.Create(10, 10);
            for W := 1 to 10 do
              KeyMacroses.Insert(nil);
            end;
          if MacroRecord then
            begin
            MacroRecord := False;
            ClearEvent(Event);
            Exit;
            end;
          MacroRecord := True;
          KeyMacroses.AtFree(WW);
          PM.Create;
          KeyMacroses.AtInsert(WW, PM);
          CurrentMacro := PM;
          end
        else if KeyMacroses <> nil then
          begin
          if MacroRecord then
            begin
            MacroRecord := False;
            ClearEvent(Event);
            Exit;
            end;
          CurrentMacro := KeyMacroses.At(WW);
          MacroPlaying := CurrentMacro <> nil;
          MacroKey := 0;
          end;
        ClearEvent(Event);
        end;

      {AK155: Alt-Shift-F3 -> cmFileTextView}
      {if (DNKeyCode(Event) = kbAltF3) and
              (ShiftState and kbAltShift <> 0) and
              (ShiftState and (kbRightShift or kbLeftShift) <> 0) then}
      if DNKeyCode(Event) = kbAltShiftF3 then
        {Cat}
        begin
        Event.What := evCommand;
        Event.Message.Command := cmFileTextView;
        Exit;
        end;
      {/AK155}
      {if (DNKeyCode(Event) = kbAlt0) and (ShiftState and 3 <> 0) then}
      if DNKeyCode(Event) = kbAltShift0 then
        {Cat}
        begin
        Event.What := evCommand;
        Event.Message.Command := cmListOfDirs;
        Exit;
        end;
      if MsgActive then
        if DNKeyCode(Event) = kbLeft then
          SetDNKeyCode(Event, kbShiftTab)
        else if DNKeyCode(Event) = kbRight then
          SetDNKeyCode(Event, kbTab);
      if  (Event.What = evKeyDown) then
        begin
        if MacroRecord and (CurrentMacro <> nil) then
          CurrentMacro.PutKey(DNKeyCode(Event));
        if  (MainApp.StatusLine <> nil) then
          MainApp.StatusLine.HandleEvent(Event);
        { F10 opens DN's menu bar.  Keep this explicit fallback because
          the status-line view is not the owner of the menu command. }
        if (Event.What = evKeyDown) and
           ((DNKeyCode(Event) = kbF10) or (Event.KeyDown.CharScan.ScanCode = ((kbF10 shr 8) and $FF))) then
          begin
          Event.What := evCommand;
          Event.Message.Command := cmMenu;
          Event.Message.InfoPtr := nil;
          end;
        end;
      end;
  end {case};
  case Event.What of
    evCommand:
      case Event.Message.Command of
        cmTree,
        cmGetTeam,
        cmHelp,
        cmClearData,
        cmSearchAdvance,
        cmAdvancePortSetup,
        cmNavyLinkSetup,
        cmQuit:
          HandleCommand(Event);
        {Cat: check whether it is time to run EventCatcher plugins}
        
        {/Cat}
      end {case};
  end {case};

  end { MyApp.GetEvent };

var
  L_Tmr: TEventTimer;
  OldNotify, NewNotify: String; {Cat}

procedure MyApp.Idle;

  procedure L_On;
    begin
    timeutil.NewTimer(L_Tmr, 100)
    end;
  procedure NLS;
    begin
    timeutil.NewTimer(LSliceTimer, 150)
    end;

  var
    Event: TEvent;

  begin
  {  Put IdleEvt after IdleClick Expired  }
  with IdleEvt do
    if What <> evNothing then
      if timeutil.TimerExpired(IdleClick) then
        begin
        PutEvent(IdleEvt);
        if What = evCommand then
          begin
          What := evBroadcast;
          PutEvent(IdleEvt);
          end;
        ClearEvent(IdleEvt);
        end;

  inherited Idle;
  {Cat}
  if Startup.AutoRefreshPanels
    and timeutil.TimerExpired(NotifyTmr)
  then
    {JO}
    begin
    if NotifyAsk(NewNotify) and
       (NewNotify <> OldNotify) and (OldNotify <> '')
    then
      
      RereadDirectory(OldNotify);
    
    OldNotify := NewNotify;
    timeutil.NewTimer(NotifyTmr, 1000); {JO}
    end;
  {/Cat}

  UpdateAll(True);

  if CtrlWas then
    if ShiftState and kbCtrlShift = 0 then
      begin
      CtrlWas := False;
      {if DelSpaces(CmdLine.Str) = '' then}
      Message(Self, evCommand, cmTouchFile, nil);
      end;

  IdleWas := True;

  end { MyApp.Idle };

procedure MyApp.HandleEvent(var Event: TEvent);
  var
    s: Word;

  procedure UpView(P: TView);
    begin
    P.MakeFirst;
    Clock.MakeFirst;
    end;

  begin
  if Event.What = evMouseDown
  then
    if  (Event.Mouse.Where.Y = 0) and (Event.Mouse.Buttons and mbLeftButton <> 0)
    then
      MainApp.MenuBar.HandleEvent(Event);
  if Event.What <> evNothing then
    inherited HandleEvent(Event);
  case Event.What of
    evCommand:
      case Event.Message.Command of
        cmUpdateConfig:
          begin
          UpdateConfig;
          WriteConfig;
          end;
        cmMenuOn:
          if  (Event.Message.InfoPtr = MainApp.MenuBar) then
            UpView(MainApp.MenuBar);
        cmMenuOff:
          if  (Event.Message.InfoPtr = MainApp.MenuBar) then
            UpView(MainApp.Desktop);
        
        cmEnvEdit:
          EditDOSEnvironment(Environment);
        
        else {case}
          HandleCommand(Event);
      end {case};
  end {case};
  end { MyApp.HandleEvent };

end.
