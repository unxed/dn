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

unit Setups;

interface

uses
  Defines, Drivers, Views, Dialogs, Collect,
  Commands, Startup, dlgrecs
  ;

{                                System Setup                                }
{----------------------------------------------------------------------------}
type
  TSysData = record
    Options: Word;
    Mode1: String[5];
    Mode2: String[5];
    Temp: String;
    Drives: TTextListboxRec;
    Current: Word;
    CopyLimitBuf: String[5];
    ForceDefArch: String[3];
    end;

  TSysDialog = class(TDialog)
    LocalData: TSystemData;
    SysData: TSysData;
    {constructor Init;}
    procedure Awaken; override;
    destructor Destroy; override;
    procedure GetData(var Rec); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  TCurrDriveInfo = class(TCheckBoxes)
    procedure HandleEvent(var Event: TEvent); override;
    procedure Press(Item: Integer); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  TMouseBar = class(TScrollBar)
    constructor Create(var Bounds: TRect); overload;
    procedure SetData(var Rec); override;
    procedure GetData(var Rec); override;
    function DataSize: Integer; override;
    procedure HandleEvent(var Event: TEvent); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  
  TSaversDialog = class(TDialog)
    constructor Create; overload;
    procedure HandleEvent(var Event: TEvent); override;
    destructor Destroy; override;
    procedure Awaken; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;

  TSaversListBox = class(TListBox)
    procedure HandleEvent(var Event: TEvent); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    end;
  

procedure SetupCountryInfo;
  {` Country settings dialog `}
function ApplyCodetables: Integer;
  {` Apply encoding settings from CountryInfo. Result:
     0 - no errors,
     1 - error in KbdToggleLayout
     2 - error in ABCSortTable,
     3 - error in WinCodeTable,
     4 - error in Codetables,
     `}
procedure DoFMSetup;
procedure DriveInfoSetup;
procedure SetupEditorDefaults;
procedure SystemSetup;
procedure InterfaceSetup;
procedure StartupSetup;
procedure MouseSetup;
procedure ConfirmSetup;
function TerminalSetup: Boolean;

procedure SaversSetup;
function MakeSaversDialog: TDialog;


const
  CodeErrMessage: array[1..4] of TStrIdx =
 {`AK155 12.01.2004 Messages about recoding-settings errors.}
   (dlLayoutErr, dlSortError, dlWinErr, dlCodetablesErr);
   {`}

implementation
uses TvSys, DnPath,
  Dos, Tree, Drives, basics, strutil, fileutil, TvGlyphs, Messages, DNHelp,
  linepos, DnIni, iniengine, country, keymap, dirwatch
  , lfn, mainapp, Validate, TvCodePg
  ;

procedure ConfirmSetup;
  var
    D: Word;
  begin
  D := ExecResource(dlgConfirmations, Confirms);
  if D <> cmOK then
    Exit;
  ConfigModified := True;

  ConfirmsOpt := Confirms;
  SaveDnIniSettings(@ConfirmsOpt);
  DoneIniEngine;
  end;

function TerminalSetup: Boolean;
  begin
  TerminalSetup := False;
  if ExecResource(dlgSetupTerminal, TerminalDefaults) <> cmOK then
    Exit;
  TerminalSetup := True;
  Message(Application, evCommand, cmUpdateConfig, nil);
  end;

procedure SystemSetup;
  var
    W: Word;
    D: TDialog;
    B: Boolean;
    Data: TSysData;
    i: Char;
  begin
  OpenResource;
  if Resource = nil then
    Exit;
  D := TDialog
            (Application.ValidView(TDialog(Resource.Get(dlgSystemSetup))
        ));
  if D = nil then
    Exit;
  W := Desktop.ExecView(D);
  if W <> cmCancel then
    begin
    D.GetData(Data);
    SystemData := TSysDialog(D).LocalData;
    Message(Application, evCommand, cmUpdateConfig, nil);
    end;
  D.Free;
  SystemDataOpt := SystemData.Options;
  CopyLimit := SystemData.CopyLimitBuf;
  ForceDefaultArchiver := SystemData.ForceDefArch;

  SaveDnIniSettings(@SystemDataOpt);
  SaveDnIniSettings(@CopyLimit);
  SaveDnIniSettings(@ForceDefaultArchiver);
  DoneIniEngine;
  end { SystemSetup };

{ The group "Keys" of the Interface setup: the options of dn.ini for the keys of the vtui UX guidelines, one bit each in the order of the dialog }
function GetUxKeys: Word;
  begin
  Result := Ord(F9OpensMenu) or Ord(MenuArrowsOpen) shl 1 or Ord(MenuEscStep) shl 2 or Ord(ListHomeEndItems) shl 3
    or Ord(EnterTogglesCheck) shl 4 or Ord(EditorWordNav) shl 5;
  end;

procedure SetUxKeys(W: Word);
  begin
  F9OpensMenu := W and 1 <> 0;
  MenuArrowsOpen := W and 2 <> 0;
  MenuEscStep := W and 4 <> 0;
  ListHomeEndItems := W and 8 <> 0;
  EnterTogglesCheck := W and 16 <> 0;
  EditorWordNav := W and 32 <> 0;
  end;

procedure InterfaceSetup;
  var
    AltTab: Boolean;
    R: TRect;
    { the data of the dialog: the options, the group "Keys", the information of the drive menu }
    Data: record
      Options: Word;
      UxKeys: Word;
      DrvInfType: TDriveInfoType;
      end;
  begin
  Data.Options := InterfaceData.Options;
  Data.UxKeys := GetUxKeys;
  Data.DrvInfType := InterfaceData.DrvInfType;
  with TApplication(Application) do
    if ExecResource(dlgInterfaceSetup, Data) <> cmCancel then
      begin
      InterfaceData.Options := Data.Options;
      InterfaceData.DrvInfType := Data.DrvInfType;
      SetUxKeys(Data.UxKeys);
      ApplyUxOptions;
      R := GetExtent;
      if InterfaceData.Options and ouiHideMenu = 0 then
        Inc(R.A.Y);
      if InterfaceData.Options and ouiHideStatus = 0 then
        Dec(R.B.Y);
      if InterfaceData.Options and ouiHideCmdline = 0 then
        Dec(R.B.Y);
      Desktop.Locate(R);
      R.A.Y := R.B.Y;
      R.B.Y := R.A.Y+Byte(InterfaceData.Options and ouiHideCmdline = 0);
      CommandLine.Locate(R);
      CommandLine.SetState(sfVisible, InterfaceData.Options and
         ouiHideCmdline = 0);
      Message(Application, evCommand, cmUpdateConfig, nil);
      if InterfaceData.Options and ouiClock <> 0 then
        if not Clock.GetState(sfVisible) then
          Clock.Show;
      if InterfaceData.Options and ouiClock = 0 then
        if Clock.GetState(sfVisible) then
          Clock.Hide;
      end;
  InterfaceDataOpt := InterfaceData.Options;
  SaveDnIniSettings(@InterfaceDataOpt);
  SaveDnIniSettings(@F9OpensMenu);
  SaveDnIniSettings(@MenuArrowsOpen);
  SaveDnIniSettings(@MenuEscStep);
  SaveDnIniSettings(@ListHomeEndItems);
  SaveDnIniSettings(@EnterTogglesCheck);
  SaveDnIniSettings(@EditorWordNav);
  DoneIniEngine;
  end { InterfaceSetup };

procedure StartupSetup;
  var
    Data: record
      Load, Unload: Word;
      end;
  begin
  Data.Load := StartupData.Load;
  Data.Unload := StartupData.Unload;
  if ExecResource(dlgStartupSetup, Data) <> cmCancel then
    begin
    StartupData.Load := Data.Load;
    StartupData.Unload := Data.Unload;
    LSliceCnt := -3;
    Message(Application, evCommand, cmUpdateConfig, nil);

    StartupDataLoad := StartupData.Load;
    StartupDataUnload := StartupData.Unload;
    SaveDnIniSettings(@StartupDataLoad);
    SaveDnIniSettings(@StartupDataUnload);
    DoneIniEngine;
    end;
  end { StartupSetup };

procedure MouseSetup;
  begin
  if ExecResource(dlgMouseSetup, MouseData) <> cmOK then
    Exit;
  if MouseVisible xor (MouseData.Options and omsCursor <> 0) then
    begin
    DoneEvents;
    InitEvents;
    end;
  TEventQueue.MouseReverse := MouseData.Options and omsReverse <> 0;
  SetMouseSpeed(MouseData.HSense, MouseData.VSense);
  Message(Application, evCommand, cmUpdateConfig, nil);
  end;


procedure SaversSetup;
  var
    W: Word;
    D: TDialog;
    B: Boolean;
  begin
  OpenResource;
  if Resource = nil then
    Exit;
  D := TDialog
            (Application.ValidView(TDialog(Resource.Get(dlgSaversSetup))
        ));
  if D = nil then
    Exit;
  W := Desktop.ExecView(D);
  if W <> cmCancel then
    begin
    D.GetData(SaversData);
    Message(Application, evCommand, cmUpdateConfig, nil);
    end;
  D.Free;
  end;


function ApplyCodetables: Integer;
  var
    CP: Word;
    Err: Integer;
{$IFDEF DNUTF8}
    C: Integer;
{$ENDIF}
  begin
  with CountryInfo do
    begin
    
    if not BuildLayoutConvXlat(KbdToggleLayout) then
      begin
      Result := 1;
      Exit;
      end;
{$IFNDEF DNUTF8}
    { the table of the sort order that DN ships goes with the page: the Ukrainian page 1125 has its letters elsewhere (tools/gen-sort1125.py); a table the user
      named is left as it is }
    if CpCurrent = 1125 then
      begin
      if UpStrg(ABCSortTable) = 'SORT866.XLT' then
        ABCSortTable := 'sort1125.xlt';
      end
    else if UpStrg(ABCSortTable) = 'SORT1125.XLT' then
      ABCSortTable := 'sort866.xlt';
{$ENDIF}
    if ABCSortTable = '' then
      ABCSortTable := '0';
    Val(ABCSortTable, CP, Err);
    if (Err = 0) and QueryABCSort(CP, ABCSortXlat) then
      begin { OS table request succeeded }
      end
    else if not BuildABCSortXlat(ABCSortTable) then
      begin
      Result := 2;
      Exit;
      end;

{$IFNDEF DNUTF8}
    RefreshCaseTables;               { the case of the letters of the current page }
{$ENDIF}
    FreeCodetables;
    if (WinCodetable <> '') and not BuildWinCodeTable(WinCodeTable)
    then
      begin
      Result := 3;
      Exit;
      end;
    if not InitCodeTables(CodeTables) then
      begin
      Result := 4;
      Exit;
      end;
    end;
{$IFDEF DNUTF8}
  { UTF-8 inside: the one-byte tables of a code page do not apply to bytes $80 and up (they are the parts of the characters);
    the case is done by UpStr/LowStr (DNUtf8) }
  for C := 128 to 255 do
    begin
    UpCaseArray[Char(C)] := Char(C);
    LowCaseArray[Char(C)] := Char(C);
    ABCSortXlat[Char(C)] := Char(C);
    end;
{$ENDIF}
  Result := 0;
  end;

procedure SetupCountryInfo;
  var
    SaveCountryInfo: TCountryInfo;
    C: Word;
    Err: Integer;
  label
    TryDialog;
  begin
  SaveCountryInfo := CountryInfo;
TryDialog:
  while True do
    begin
    C := ExecResource(dlgCountrySetup, CountryInfo);
    if C = cmYes then
      GetSysCountryInfo
    else
      Break;
    end;
  if C <> cmOK then
    begin
    CountryInfo := SaveCountryInfo;
     // CountryInfo may have changed on cmYes
    ApplyCodetables;
    Exit;
    end;
  Err := ApplyCodetables;
  if Err <> 0 then
    begin
    MessageBox(^C+GetString(CodeErrMessage[Err]), nil, mfError+mfYesButton);
    goto TryDialog;
    end;
  GlobalMessage(evCommand, cmReboundPanel, nil);
  ConfigModified := True;
  end;

procedure DoFMSetup;
  var
    { the data of the dialog: the behaviour, the check box "Left/Right by page" (PanelArrowsPage of dn.ini), the rest of FMSetup }
    Data: record
      Options: Word;
      ArrowsPage: Word;
      Rest: array[1..SizeOf(TFMSetup)-SizeOf(Word)] of Byte;
      end;
  begin
  Data.Options := Startup.FMSetup.Options;
  Data.ArrowsPage := Ord(PanelArrowsPage);
  Move(PByte(@Startup.FMSetup)[SizeOf(Word)], Data.Rest, SizeOf(Data.Rest));
  if ExecResource(dlgFMSetup, Data) <> cmOK then
    Exit;
  Startup.FMSetup.Options := Data.Options;
  Move(Data.Rest, PByte(@Startup.FMSetup)[SizeOf(Word)], SizeOf(Data.Rest));
  PanelArrowsPage := Data.ArrowsPage and 1 <> 0;
  SaveDnIniSettings(@PanelArrowsPage);
  if Startup.FMSetup.TagChar = '' then
    Startup.FMSetup.TagChar[1] := ' ';
  if (Startup.FMSetup.RestChar = '') or
     (Startup.FMSetup.RestChar[1] = ' ')
  then
    Startup.FMSetup.RestChar := GlyphChar(glTriRight); { truncation character must always exist }
  Message(Application, evCommand, cmUpdateConfig, nil);
  GlobalMessage(evCommand, cmReboundPanel, nil);

  FMSetupOpt := Startup.FMSetup.Options;
  SaveDnIniSettings(@FMSetupOpt);
  DoneIniEngine;
  if AutoRefreshPanels <>
     (Startup.FMSetup.Options and fmoAutorefreshPanels <> 0)
  then
    begin
    AutoRefreshPanels := not AutoRefreshPanels;
    if AutoRefreshPanels then
      NotifyInit
    else
      NotifyDone;
    end;
  end;

procedure DriveInfoSetup;
  var
    W: Word;
  begin
  Startup.DriveInfoData := Startup.DriveInfoData and $001F+
    Startup.DriveInfoData and $07E0 shl 2+
    Startup.DriveInfoData and $1800 shr 6;

  if ExecResource(dlgDriveInfoSetup, Startup.DriveInfoData) <> cmOK then
    Exit;
  Startup.DriveInfoData := Startup.DriveInfoData and $001F+
    Startup.DriveInfoData and $FF80 shr 2+
    Startup.DriveInfoData and $0060 shl 6;
  Message(Application, evCommand, cmUpdateConfig, nil);
  GlobalMessage(evCommand, cmReboundPanel, nil);
  end;

procedure SetupEditorDefaults;
  begin
  if ExecResource(dlgEditorDefaults, EditorDefaults) = cmOK then
    begin
    if StoI(EditorDefaults.TabSize) < 2 then
      EditorDefaults.TabSize := '2'; {-$VOL}
    Message(Application, evCommand, cmUpdateConfig, nil);
    EditorDefaultsOpt := EditorDefaults.EdOpt;
    EditorDefaultsOpt2 := EditorDefaults.EdOpt2;
    ViewerOpt := EditorDefaults.ViOpt;
    SaveDnIniSettings(@EditorDefaultsOpt);
    SaveDnIniSettings(@EditorDefaultsOpt2);
    SaveDnIniSettings(@ViewerOpt);
    DoneIniEngine;
    end;
  end;

procedure TCurrDriveInfo.HandleEvent(var Event: TEvent);
  var
    W: Word;
    Data: TSysData;
  begin
  inherited HandleEvent(Event);
  if  (Event.What = evBroadcast)
       and (Event.Message.Command = cmScrollBarChanged)
  then
    begin
    W := TSysDialog(Owner).LocalData.Drives[Char
          (Byte('A')+TScrollBar(Event.Message.InfoPtr).Value)];
    SetData(W);
    end
  else if (Event.What = evKeyDown) and (Char(Event.KeyDown.CharScan.CharCode) = ' ')
         and (Owner.Current.ClassType = TListBox)
  then
    Press(0);
  end;

procedure TCurrDriveInfo.Press(Item: Integer);
  var
    Data: TSysData;
  begin
  inherited Press(Item);
  Owner.GetData(Data);
  TSysDialog(Owner).LocalData.Drives[Char(Byte('A')+Data.Drives.Focus)
  ] := Value;
  end;

procedure TSysDialog.Awaken;
  var
    C: Char;
  begin
  LocalData := SystemData;
  SysData.Drives.List := TLineCollection.Create(26, 1, False);
  for C := 'A' to 'Z' do
    SysData.Drives.List.Insert(NewStr(C+':'));
  Move(SystemData, SysData,
     SizeOf(SysData.Options)+SizeOf(SysData.Mode1)*2);
  SysData.Temp := SystemData.Temp;
  SysData.Drives.Focus := 2;
  SysData.Current := LocalData.Drives['C'];
  SysData.CopyLimitBuf := ItoS(SystemData.CopyLimitBuf);
  SysData.ForceDefArch := SystemData.ForceDefArch;
  SetData(SysData);
  end;

destructor TSysDialog.Destroy;
  var
    Data: TSysData;
  begin
  GetData(Data);
  inherited Destroy;
  Data.Drives.List.Free;
  end;

procedure TSysDialog.GetData(var Rec);
  var
    Data: TSysData;
  begin
  inherited GetData(Data);
  TSysData(Rec) := Data;
  LocalData.Options := Data.Options;
  LocalData.Mode1 := Data.Mode1;
  LocalData.Mode2 := Data.Mode2;
  LocalData.Temp := Data.Temp;
  LocalData.CopyLimitBuf := StoI(Data.CopyLimitBuf);
  LocalData.ForceDefArch := Data.ForceDefArch;
  end;

{----------------------------------------------------------------------------}
{                                 Mouse Setup                                }
{----------------------------------------------------------------------------}
constructor TMouseBar.Create(var Bounds: TRect);
  begin
  inherited Create(Bounds);
  Options := Options or ofSelectable;
  SetParams(0, 0, Size.X-1, 3, 1);
  end;

const
  HSenseY = 3;

function TMouseBar.DataSize: Integer;
  begin
  Result := 4;
  end;

procedure TMouseBar.SetData(var Rec);
  begin
  SetValue(Integer(Rec))
  end;

procedure TMouseBar.GetData(var Rec);
  begin
  Integer(Rec) := Value
  end;

procedure TMouseBar.HandleEvent(var Event: TEvent);
  begin
  inherited HandleEvent(Event);
  end;


{----------------------------------------------------------------------------}
{                                Savers Setup                                }
{----------------------------------------------------------------------------}
procedure TSaversListBox.HandleEvent(var Event: TEvent);
  var
    PS: PString;
    F: Integer;
    A, S: TCollection;
    LocalData: TSaversData;
  function SeekStr(P_: Pointer): Boolean;
  var P: PString absolute P_;
    begin
    SeekStr := (P <> nil) and (P^ = PS^);
    end;
  begin
  if Event.What = evBroadcast then
    case Event.Message.Command of
      cmYes:
        begin
        Owner.GetData(LocalData);
        A := LocalData.Available.List;
        if A.Count > 0 then
          begin
          PS := A.At(LocalData.Available.Focus);
          if  (PS <> nil) and (List.FirstThat(SeekStr) = nil) then
            begin
            List.Insert(NewStr(PS^));
            S := List;
            Items := nil;
            NewLisT(S);
            end;
          end;
        ClearEvent(Event);
        end;
      cmNo:
        begin
        F := Focused;
        if F < List.Count then
          begin
          S := List;
          S.AtFree(F);
          Items := nil;
          Owner.Lock;
          NewLisT(S);
          if  (F > 0) and (F >= List.Count) then
            Dec(F);
          FocusItem(F);
          Owner.UnLock;
          end;
        ClearEvent(Event);
        end;
    end {case};
  inherited HandleEvent(Event);
  end { TSaversListBox.HandleEvent };

constructor TSaversDialog.Create;
  var
    R: TRect;
    D: TDialog;
    Control, Labl, Histry: TView;
  begin
  R := TRect.Create(0, 0, 57, 20);
  inherited Create(R, GetString(dlScreenSaverSetup));
  Options := Options or ofCentered or ofValidate;
  HelpCtx := hcSavers;
  R := TRect.Create(19, 3, 20, 13);
  Control := TScrollBar.Create(R);
  Insert(Control);

  R := TRect.Create(2, 3, 19, 13);
  Control := TSaversListBox.Create(R, 1, TScrollBar(Control));
  Insert(Control);

  R := TRect.Create(2, 2, 18, 3);
  Labl := TLabel.Create(R, GetString(dlSS_S_electedSavers), Control);
  Insert(Labl);

  R := TRect.Create(20, 6, 36, 8);
  Control := TButton.Create(R, GetString(dlSS_A_dd), cmYes,
         bfNormal+bfBroadcast);
  Insert(Control);

  R := TRect.Create(20, 8, 36, 10);
  Control := TButton.Create(R, GetString(dlSS_R_emove), cmNo,
         bfNormal+bfBroadcast);
  Insert(Control);

  R := TRect.Create(54, 3, 55, 13);
  Control := TScrollBar.Create(R);
  Insert(Control);

  R := TRect.Create(37, 3, 54, 13);
  Control := TListBox.Create(R, 1, TScrollBar(Control));
  Insert(Control);

  R := TRect.Create(37, 2, 54, 3);
  Labl := TLabel.Create(R, GetString(dlSSA_v_ailableSavers), Control);
  Insert(Labl);

  R := TRect.Create(2, 15, 18, 16);
  Control := TInputLine.Create(R, 3);
  TInputline(Control).SetValidator(TRangeValidator.Create(1, 254));
  { X-Man }
  Control.Options := Control.Options or ofValidate;
  Insert(Control);

  R := TRect.Create(2, 14, 18, 15);
  Labl := TLabel.Create(R, GetString(dlSS_T_ime), Control);
  Insert(Labl);

  R := TRect.Create(20, 15, 55, 16);
  Control := TCheckBoxes.Create(R,
        TSItem.Create(GetString(dlSSUse_M_ouse), nil));
  Insert(Control);

  R := TRect.Create(7, 17, 17, 19);
  Control := TButton.Create(R, GetString(dlOKButton), cmOK, bfDefault);
  Insert(Control);

  R := TRect.Create(17, 17, 28, 19);
  Control := TButton.Create(R, GetString(dlCancelButton), cmCancel,
         bfNormal);
  Insert(Control);

  R := TRect.Create(28, 17, 40, 19);
  Control := TButton.Create(R, GetString(dlHelpButton), cmHelp,
         bfNormal);
  Insert(Control);

  R := TRect.Create(40, 17, 50, 19);
  Control := TButton.Create(R, GetString(dlTestButton), cmTest,
         bfNormal);
  Insert(Control);

  SelectNext(False);
  end { TSaversDialog.Init };

procedure TSaversDialog.HandleEvent(var Event: TEvent);
  var
    Data: TSaversData;
  begin
  inherited HandleEvent(Event);
  case Event.What of
    evCommand:
      case Event.Message.Command of
        cmTest:
          begin
          ClearEvent(Event);
          GetData(Data);
          Application.InsertAvIdlerN(Data, Data.Available.Focus);
          end;
      end {case};
  end {case};
  end;

{-DataCompBoy-}
procedure TSaversDialog.Awaken;
  var
    lSR: lSearchRec;
    Data: TSaversData;
  begin
  Data := SaversData;
  Data.Available.Focus := 0;
  Data.Selected.Focus := 0;
  Data.Available.List := TLineCollection.Create(5, 5, False);
  if Data.Selected.List = nil
  then
    Data.Selected.List := TLineCollection.Create(5, 5, False);
  with Data.Available.List do
    begin
    Insert(NewStr(GlyphChar(glDot)+' Star flight'));
    Insert(NewStr(GlyphChar(glDot)+' Flash-light'));
    Insert(NewStr(GlyphChar(glDot)+' Clock'));
    Insert(NewStr(GlyphChar(glDot)+' Blackness'));
    lFindFirst(SourceDir+'ssavers'+DnSep+'*.SS', AnyFileDir, lSR);
    while DosError = 0 do
      begin
      Insert(NewStr(lSR.FullName));
      lFindNext(lSR);
      end;
    lFindClose(lSR);
    end;
  SetData(Data);
  end { TSaversDialog.Awaken };
{-DataCompBoy-}

destructor TSaversDialog.Destroy;
  var
    Data: TSaversData;
  begin
  GetData(Data);
  inherited Destroy;
  if  (Data.Available.List <> nil) then
    Data.Available.List.Free;
  end;

function MakeSaversDialog: TDialog;
  begin
  MakeSaversDialog := TSaversDialog.Create;
  end;



class function TSysDialog.Build: TStreamable;
begin
  Result := TSysDialog.Create(streamableInit);
end;

function TSysDialog.StreamableName: ShortString;
begin
  Result := 'Setups.TSysDialog';
end;

class function TCurrDriveInfo.Build: TStreamable;
begin
  Result := TCurrDriveInfo.Create(streamableInit);
end;

function TCurrDriveInfo.StreamableName: ShortString;
begin
  Result := 'Setups.TCurrDriveInfo';
end;

class function TMouseBar.Build: TStreamable;
begin
  Result := TMouseBar.Create(streamableInit);
end;

function TMouseBar.StreamableName: ShortString;
begin
  Result := 'Setups.TMouseBar';
end;

class function TSaversDialog.Build: TStreamable;
begin
  Result := TSaversDialog.Create(streamableInit);
end;

function TSaversDialog.StreamableName: ShortString;
begin
  Result := 'Setups.TSaversDialog';
end;

class function TSaversListBox.Build: TStreamable;
begin
  Result := TSaversListBox.Create(streamableInit);
end;

function TSaversListBox.StreamableName: ShortString;
begin
  Result := 'Setups.TSaversListBox';
end;

end.

