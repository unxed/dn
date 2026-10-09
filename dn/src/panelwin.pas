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

unit panelwin;

interface

uses
  Views, Defines, Streams, Drivers, panelroot, filepanel
  ;

type
  TPanelDescr = record
  {` Descriptor of one (of two) panels }
    AnyPanel: TView; // if something is visible on this panel - it is this.
    FilePanel: TFilePanel; { File panel. Always present, but
      may be hidden to show a non-file panel.
      If the file panel is visible, then AnyPanel = FilePanel }
    PanelType: Byte; // AnyPanel type
    Drive: Byte; // for FilePanel
    end;
  {`}

  TPanelNum = boolean;
  {` Reference to one of the two panels; for clarity constants
  pLeft and pRight are also defined. Values of this type answer
  the question "which one", e.g. they index
  TDoubleWindow.Panel.
  `}

const
  pLeft = false; // for TPanelNum
  pRight = true; // for TPanelNum


type
  TSeparator = class;
  {`2 Vertical separator between panels. Mimics the left border
  line of the right panel and the right border line of the left panel (in
  reality the panels have no borders at all.) }
  TSeparator = class(TView)
    OldX, OldW: AInt;
    constructor Create(const R: TRect; AH: Integer); overload;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Draw; override;
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    procedure Write(Os: opstream); override;
    end;
  {`}

  TDoubleWindow = class;
  {`2 Dual-panel manager.}
  TDoubleWindow = class(TWindow)
    Separator: TSeparator; // vertical between panels
    Panel: array[TPanelNum] of TPanelDescr;
    OldBounds: TRect;
    OldPanelBounds: TRect;
    NonFilePanelType: Byte;
      {`non-file panel type; 0 if there is none`}
    NonFilePanel: TPanelNum;
      {`Which panel is non-file; garbage if both are file panels `}
    PanelZoomed: Boolean;
      {` One of the panels is maximized `}
    SinglePanel: Boolean;
      {` Whether the panel was the only one before maximization `}
    isValid: Boolean;
    constructor Create(const Bounds: TRect; ANumber, ADrive: Integer); overload;
    procedure InitPanel(N: TPanelNum; R: TRect);
    procedure InitInterior;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
    procedure SwitchView(dtType: Byte);
      {`Make the inactive panel of the given type if it currently has
      a different type; and if it is already that type - make the panel
      a file panel`}
    function Valid(C: Word): Boolean; override;
    procedure ChangeBounds(const Bounds: TRect); override;
    procedure HandleCommand(var Event: TEvent);
      {`panelwin`}
    procedure SwitchPanel(N: TPanelNum);
      {`hide/show panel`}
    procedure ChangeDrv(N: TPanelNum);
      {`change drive with dialog (Alt-F1/F2)`}
    procedure SetMaxiState(P: TFilePanelRoot);
      {` Set the maximized state of the active file
        panel according to its settings `}
    procedure ToggleViewMaxiState(P: TView; Other: TPanelNum);
      {` Invert the maximized state of the active panel
        (possibly non-file). Other panel number is Other `}
    end;
    {`}

const
  CDoubleWindow = #80#81#82+ { 1-3    Frame (P,A,I)            }
  #83#84+ { 4,5    Scroll Bar (Page, Arrow) }
  #85#86#87#88#89+ { 6-10   Panel (NT,Sp,ST,NC,SC)   }
  #90#91+ { 11,12  Panel Top (A,P)          }
  #92#93+ { 13,14  Viewer (NT,ST)           }
  #94#95#96#97+
  #98#99#100+ { 15-21  Tree (T,NI,SI,Df,DS,SI,DI}
  #101+ { 22     Tree info                }
  #102#103+ { 23,24  Disk info (NT, HT)       }
  #119#120#121#122+
  #123#124#125+ { 25-31  File Info                }
  #165+ { 32  File Panel               }
  #172#173#174#175#176#177#180#181+ { 33-40 Highlight groups}
  #186#187#188+ { 41-43 Drive Line }
  #192#193#194#195#196+ { 44-48 JO - 5 additional highlight groups}
  #130#131; { 49,50 JO - File Info (LFN in footer)}

const
  dtPanel = 1;
  dtInfo = 2;
  dtTree = 3;
  dtQView = 4;
  dtDizView = 5;
  

implementation
uses DnPath,
  DiskInfo, Commands, FileCopy, FilesCol, basics, strutil, fileutil,
  Startup, mainapp, topview, Tree, FViewer, TvGlyphs
  
  , Dos, Math
  ;

constructor TDoubleWindow.Create(const Bounds: TRect; ANumber, ADrive: Integer);
  var
    P: TFilePanel;
    R: TRect;
    PV: TView;
    i: TPanelNum;
  begin
  inherited Create(Bounds, '', ANumber);
  Options := Options or ofTileable;
  EventMask := $FFFF;
  Abort := False;
  if  (ADrive <= 0) or not ValidDrive(Char(ADrive+64)) then
    ADrive := 0;
  Panel[pLeft].Drive := ADrive;
  Panel[pRight].Drive := ADrive;
  R := GetExtent;
  R.Grow(-1, 0);
  R.A.X := R.B.X div 2;
  R.B.X := R.A.X+2;
  Separator := TSeparator.Create(R, Size.X);
  Insert(Separator);
  InitInterior;
  PassivePanel := Panel[pLeft].FilePanel;
  if not Abort then
    isValid := True;
  case FMSetup.LeftPanelType of
    fdoInfoDrive:
      Message(Self, evCommand, cmDiskInfo, nil);
    fdoTreeFrive:
      Message(Self, evCommand, cmDirTree, nil);
    fdoRightOnly:
      Message(Self, evCommand, cmHideLeft, nil);
  end {case};
  end { TDoubleWindow.Init };

procedure TDoubleWindow.InitPanel(N: TPanelNum; R: TRect);
  var
    PV: PMyScrollBar;
    P: TFilePanel;
    P1: TInfoView;
    P2: TDirView;
    P3: TSortView;
    PD: TDriveLine;
    B: TRect;
  begin
  if Abort then
    Exit;
  B := R;
  B.A.X := B.B.X;
  Inc(B.B.X);
  Inc(B.A.Y);
  Dec(B.B.Y, 3);
  PV := PMyScrollBar.Create(B);
  P := TFilePanel.Create(R, Panel[N].Drive, PV);
  if Abort then
    begin
    P.Free;
    PV.Free;
    Exit
    end;

  P1 := TInfoView.Create(R);
  P1.Panel := P;
  P1.CompileShowOptions;
  P.InfoView := P1;

  P2 := TDirView.Create(R);
  P2.Panel := P;
  P.DirView := P2;
  P2.EventMask := $FFFF;

  P3 := TSortView.Create(R);
  P3.Panel := P;
  P.SortView := P3;
  P3.EventMask := evMouseDown;

  PD := TDriveLine.Create(R, P);
  P.DriveLine := PD;

  P.ChangeBounds(R);

  Insert(PV);
  Insert(P3);
  Insert(P2);
  Insert(P1);
  Insert(P);
  Insert(PD);
  with Panel[N] do
    begin
    AnyPanel := P;
    FilePanel := TFilePanel(P);
    PanelType := dtPanel;
    FilePanel.SelfNum := N;
    P.Select;
    end;
  end { TDoubleWindow.InitPanel };

function TDoubleWindow.Valid(C: Word): Boolean;
  begin
  Valid := inherited Valid(C) and isValid;
  end;

procedure TDoubleWindow.ChangeBounds(const Bounds: TRect);
  var
    D: TPoint;
    R: TRect;
    SVisible: Boolean;
    N: TPanelNum;
  label 1;
  begin
  D.X := Bounds.B.X-Bounds.A.X-Size.X;
  D.Y := Bounds.B.Y-Bounds.A.Y-Size.Y;
  R := GetExtent;
  R.Grow(-1, 0);
  R.A.X := (R.B.X*Separator.OldX) div Separator.OldW;
  if (D = Point(0, 0)) and (R.A.X = Separator.Origin.X) then
    begin
    SetBounds(Bounds);
    DrawView;
    end
  else
    begin
    FreeBuffer;
    SetBounds(Bounds);
    Clip := GetExtent;
    GetBuffer;
    Lock;
    R := GetExtent;
    Frame.ChangeBounds(R);
    SVisible := Separator.GetState(sfVisible);
    for N := pLeft to pRight do
      begin
      with Panel[N] do
        if not AnyPanel.GetState(sfVisible) then
          begin
          if SVisible then
            Separator.Hide;
          R := GetExtent;
          R.Grow(-1, -1);
          Panel[not N].AnyPanel.ChangeBounds(R);
          goto 1;
          end;
      end;
    if not SVisible then
      Separator.Show;
    R := GetExtent;
    R.Grow(-1, 0);
    R.A.X := (R.B.X*Separator.OldX) div Separator.OldW;
    R.B.X := R.A.X+2;
    Separator.ChangeBounds(R);
    R := GetExtent;
    R.Grow(-1, -1);
    R.A.X := (R.B.X*Separator.OldX) div Separator.OldW+2;
    Panel[pRight].AnyPanel.ChangeBounds(R);
    R := GetExtent;
    R.Grow(-1, -1);
    R.B.X := (R.B.X*Separator.OldX) div Separator.OldW;
    Panel[pLeft].AnyPanel.ChangeBounds(R);
1:
    Redraw;
    UnLock;
    end;
  end { TDoubleWindow.ChangeBounds };

function TDoubleWindow.Read(Ip: ipstream): Pointer;
  const
    SaveBlockLen =
      SizeOf(OldBounds) +
      SizeOf(OldPanelBounds) +
      SizeOf(NonFilePanelType) +
      SizeOf(NonFilePanel) +
      SizeOf(PanelZoomed) +
      SizeOf(SinglePanel);
  var
    N: TPanelNum;
  begin
  Result := Self;
  inherited Read(Ip);
  Ip.ReadBytes(OldBounds, SaveBlockLen);
  Separator := Ip.ReadPointer;
  for N := pLeft to pRight do
    with Panel[N] do
      begin
      Ip.ReadBytes(PanelType, SizeOf(PanelType)+SizeOf(Drive));
      FilePanel := Ip.ReadPointer;
      if FilePanel = nil then
        begin Free; Result := nil; Exit end;
      AnyPanel := FilePanel;
      FilePanel.SelfNum := N;
      end;
  PassivePanel := OtherFilePanel(ActivePanel);

  if NonFilePanelType <> 0 then
    Panel[NonFilePanel].AnyPanel := Ip.ReadPointer;

  {Cat}
  if  (Separator = nil)
    or (Panel[pLeft].AnyPanel = nil) or (Panel[pRight].AnyPanel = nil)
  then
    begin Free; Result := nil; Exit end;
  {/Cat}

  case NonFilePanelType of
    dtQView, dtDizView:
      with Panel[not NonFilePanel].FilePanel do
        begin
        QuickViewEnabled := True;
        SendLocated;
        end;

    dtTree:
      with THTreeView(Panel[NonFilePanel].AnyPanel) do
        ReadAfterLoad;

    dtInfo:
      with TDiskInfo(Panel[NonFilePanel].AnyPanel) do
        begin
        OtherPanel := Panel[not NonFilePanel].FilePanel;
        ReadData;
        end;
  end {case};

  isValid := True;
  end { TDoubleWindow.Load };

procedure TDoubleWindow.Write(Os: opstream);
  const
    SaveBlockLen =
      SizeOf(OldBounds) +
      SizeOf(OldPanelBounds) +
      SizeOf(NonFilePanelType) +
      SizeOf(NonFilePanel) +
      SizeOf(PanelZoomed) +
      SizeOf(SinglePanel);
  var
    N: TPanelNum;
  begin
  inherited Write(Os);
  Os.WriteBytes(OldBounds, SaveBlockLen);
  Os.WritePointer(Separator);
  for N := pLeft to pRight do
    with Panel[N] do
      begin
      Os.WriteBytes(PanelType, SizeOf(PanelType)+SizeOf(Drive));
      Os.WritePointer(FilePanel);
      end;
  if NonFilePanelType <> 0 then
    Os.WritePointer(Panel[NonFilePanel].AnyPanel);
  end { TDoubleWindow.Store };


const
  VScrollRect: TRect = (A:(X:1;Y:1);B:(X:2;Y:5));
    {Essential that B.X-A.X = 1, i.e. vertical.
    The rest does not matter.}

{ Create a vertical scrollbar for the view panel }
function MakeVScroll: TViewScroll;
  begin
  Result := TViewScroll.Create(VScrollRect);
  Result.Options := Result.Options or ofPostProcess;
  end;

{ Validate newly created non-file panel P; on errors P=nil }
function ValidVP(var P: TView; S: TView {scrollbar}): Boolean;
  begin
  Result := False;
  if (S = nil) or (P = nil) or not P.Valid(0) then
    begin
    S.Free;
    P.Free;
    P := nil;
    Exit;
    end;
  Result := True;
  end;

procedure InsertView(var P: TView; S: TView; Manager: TDoubleWindow);
  begin
  if ValidVP(P, S) then
    with Manager do
      begin
      Insert(P);
      Insert(S);
      P.Hide;
      end;
  end;

{ Non-file panel builders }

function InsertQView(R1: TRect;
    Manager: TDoubleWindow; Other: TFilePanelRoot): TView;
  var
    S: TViewScroll;
  begin
  S := MakeVScroll;
  Result := TQFileViewer.Create(R1, nil, '', '', S, True,
           (EditorDefaults.ViOpt and 1) <> 0);
  InsertView(Result, S, Manager);
  end { InsertQView };

function InsertDizView(R1: TRect;
    Manager: TDoubleWindow; Other: TFilePanelRoot): TView;
  var
    S: TViewScroll;
  begin
  S := MakeVScroll;
  Result := TDFileViewer.Create(R1, nil, '', '', S, True,
    (EditorDefaults.ViOpt and 1) <> 0);
  InsertView(Result, S, Manager);
  end { InsertDizView };

function InsertTree(R1: TRect;
    Manager: TDoubleWindow; Other: TFilePanelRoot): TView;
  var
    S: PMyScrollBar;
    P: TView;
  begin
  S := PMyScrollBar.Create(VScrollRect);
  S.Options := S.Options or ofPostProcess;
  { Split the area vertically between the footer (2 lines) and the tree}
  Dec(R1.B.Y, 2);
  Result := THTreeView.Create(R1, 0, False, S);
  if ValidVP(Result, S) then
    begin
    R1.A.Y := R1.B.Y;
    Inc(R1.B.Y, 2);
    P := TTreeInfoView.Create(R1, THTreeView(Result));
    THTreeView(Result).Info := P;
    with Manager do
      begin
      Insert(P);
      Insert(Result);
      Insert(S);
      end;
    end;
  end { InsertTree };

function InsertInfo(R1: TRect;
    Manager: TDoubleWindow; Other: TFilePanelRoot): TView;
  begin
  Result := TDiskInfo.Create(R1, Other);
  Result.Hide;
  Manager.Insert(Result);
  TDiskInfo(Result).InsertDriveView;
  TDiskInfo(Result).ReadData;
  // This must be done after Insert
  end { InsertTree };


type
  TPanelConstructor = function(R1: TRect;
    Manager: TDoubleWindow; Other: TFilePanelRoot): TView;

{ Anyone (a plugin, for example) can add their
element into this array in place of any nil, after which this new non-file panel type
can be switched on/off via SwitchView by the
corresponding number without problems.}

const
  PanelConstructor: array[dtInfo..10] of TPanelConstructor =
    (  InsertInfo
     , InsertTree
     , InsertQView
     , InsertDizView
     , nil
     , nil
     , nil
     , nil
     , nil
    );

procedure TDoubleWindow.SwitchView(dtType: Byte);
  var
    R1: TRect;
    V: TView;
    N, Selected: TPanelNum;
    VisibleN: Boolean;
  label Ex;
  begin
  Lock;

  if PanelZoomed then
    Message(Self, evCommand, cmMaxi, nil);
      { With PanelZoomed, SwitchView may be needed only if
       the maximized panel is a file panel. That is something like
       Ctrl-Q with a maximized panel. To have somewhere to open
       a non-file panel, maximization must be removed. }

  Selected := Panel[pRight].AnyPanel.GetState(sfSelected);
  N := not Selected;
  VisibleN := Panel[N].AnyPanel.GetState(sfVisible);
  R1 := Panel[N].AnyPanel.GetBounds;

  { If a non-file panel existed - it must be destroyed in any case.
If it existed and was exactly of type dtType, then restore
the file panel; otherwise create a dtType panel. If there was none,
hide the file panel}
  with Panel[N].AnyPanel do
    begin
    if not VisibleN then
      SwitchPanel(N);
    Hide;
    if NonFilePanelType <> 0 then
      Free;
    end;

  if NonFilePanelType <> dtType then
    begin
    NonFilePanelType := 0;
    V := PanelConstructor[dtType](R1, Self, Panel[not N].FilePanel);
    if V = nil then
      goto Ex;
    NonFilePanel := N;
    NonFilePanelType := dtType;
    Panel[N].AnyPanel := V;
    R1.A.Y := 1;
    R1.B.Y := Size.Y-1;
    V.Locate(R1);
    V.Show;
    Panel[N].PanelType := dtType;
    Panel[Selected].AnyPanel.Select;
    if dtType in [dtQView, dtDizView] then
      Panel[Selected].FilePanel.QuickViewEnabled := True;
    Redraw;
    end
  else
    begin
    NonFilePanelType := 0;
    if VisibleN then
      begin
      Panel[N].AnyPanel := Panel[N].FilePanel;
      R1.A.Y := 1;
      R1.B.Y := Size.Y-1;
      Panel[N].FilePanel.Locate(R1);
      Panel[N].FilePanel.Show;
      Panel[N].PanelType := dtPanel;
      Panel[not N].FilePanel.QuickViewEnabled := False;
      if not N <> Selected then
        Panel[not N].FilePanel.Select;
      end
    else
      if not VisibleN then
        SwitchPanel(N);
    end;

Ex:
  UnLock;
  end { TDoubleWindow.SwitchView };

procedure TDoubleWindow.InitInterior;
  var
    R: TRect;
    RP: array[TPanelNum] of TRect;
    N: TPanelNum;
  begin
  R := GetExtent;
  R.Grow(-1, -1);
  RP[pRight] := R;
  RP[pLeft] := R;
  RP[pLeft].B.X := RP[pLeft].B.X div 2;
  RP[pRight].A.X := RP[pLeft].B.X + 2;

  for N := pLeft to pRight do
    begin
    InitPanel(N, RP[N]);
    if Abort then
      Exit;
    end;
  end { TDoubleWindow.InitInterior };

{ Hide/show panel }
procedure TDoubleWindow.SwitchPanel(N: TPanelNum);
  var
    R, RN: TRect;
    ThisPanel: TView;
    NewXBound: Integer;
    ForceResize: Boolean;
  begin
  if PanelZoomed or not Panel[not N].AnyPanel.GetState(sfVisible) then
    Exit;
  Lock;
  R := GetBounds;
  ThisPanel := Panel[N].AnyPanel;
  if ThisPanel.GetState(sfVisible) then
    begin // hide
    OldBounds := R;
    NewXBound := Separator.Origin.X+R.A.X+1;
    if N then {hiding the right}
      R.B.X := NewXBound
      { If the manager width became less than MinWinSize.X, then
      ChangeBounds will expand the window to the right, as required}
    else {hiding the left}
      begin
      R.A.X := NewXBound;
      if R.B.X-R.A.X < MinWinSize.X then
        R.A.X := R.B.X - MinWinSize.X;
        { Here we need to expand leftward, so we do it ourselves }
      end;
    ThisPanel.Hide;
    end
  else
    begin // show
    ThisPanel.Show;
    R.A.X := OldBounds.A.X;
    R.B.X := OldBounds.B.X;
    end;
  if OldBounds.B.X - OldBounds.A.X = MinWinSize.X then {<panelwin.002>}
    begin
    Inc(R.B.X);
    ChangeBounds(R);
    Dec(R.B.X);
    end;
  Locate(R);
  UnLock;
  end { TDoubleWindow.SwitchPanel };

{ Change drive via Alt-F1/F2 menu }
procedure TDoubleWindow.ChangeDrv(N: TPanelNum);
  var
    R, R1: TRect;
    S: String;
    P: TPoint;
    ThisPanel: TView;
    PanelSelected, PanelVisible: Boolean;
  begin
  ThisPanel := Panel[N].AnyPanel;
  PanelVisible := ThisPanel.GetState(sfVisible);
  if (NonFilePanelType <> 0) and (N = NonFilePanel) then
    begin
    R := ThisPanel.GetBounds;
    R.A.Y := 1;
    R.B.Y := Size.Y;
    Panel[N].FilePanel.Locate(R);
    end;
  R := GetBounds;
  if not PanelVisible or (Panel[N].PanelType <> dtPanel) then
    begin
    with ThisPanel do
      P.X := Origin.X + Size.X div 2 - 8;
    P.Y := Origin.Y+3;
    S := SelectDrive(P.X, P.Y,
      Panel[N].FilePanel.DirectoryName[1], True);
    if S = '' then
      Exit;
    ClrIO;
    Lock;
    if not PanelVisible then
      SwitchPanel(N);
    Message(Panel[N].FilePanel, evCommand, cmChangeDrv, @S);
    with Panel[N] do
      begin
      if PanelType <> dtPanel then
        begin
        with Panel[NonFilePanel].AnyPanel do
          begin
          PanelSelected := GetState(sfSelected);
          R1 := GetBounds;
          Hide;
          Free;
          end;
        NonFilePanelType := 0;
        R1.A.Y := 1;
        R1.B.Y := Size.Y-1;
        FilePanel.Locate(R1);
        AnyPanel := FilePanel;
        PanelType := dtPanel;
        FilePanel.Show;
        if PanelSelected then
          FilePanel.Select;
        end;
      end;
    end
  else
    begin
    Message(Panel[N].FilePanel, evCommand, cmChangeDrive, nil);
    end;
  if  (ShiftState and 3 <> 0) and (PanelSelected <> N) then
    ThisPanel.Select;
  UnLock;
  end { TDoubleWindow.ChangeDrv };

procedure TDoubleWindow.SetMaxiState(P: TFilePanelRoot);
  var
    Other: TPanelNum;
  begin
  if PanelZoomed and (P = PassivePanel) then
    begin { Attempt to maximize the passive panel when the active one is already
      maximized. In this case we do not maximize it, but instead
      clear the maximize flag in its settings. Detecting this situation
      is done by comparing with PassivePanel, not by checking visibility,
      because during Load the panel may well be invisible. }
    with P.PanSetup.Show do
      MiscOptions := MiscOptions and not 1;
    end
  else if ((P.PanSetup.Show.MiscOptions and 1) <> 0) <>
     PanelZoomed
  then
    ToggleViewMaxiState(P, not P.SelfNum);
  end;

procedure TDoubleWindow.ToggleViewMaxiState(P: TView; Other: TPanelNum);
  begin
  Lock;
  if not PanelZoomed then
    begin { Maximize }
    SinglePanel := not Panel[Other].AnyPanel.GetState(sfVisible);
    if not SinglePanel then
      SwitchPanel(Other);
    OldPanelBounds := GetBounds;
    ChangeBounds(OldBounds);
    PanelZoomed := True;
    end
  else
    begin { Remove maximization }
    if SinglePanel then
      Hide; {AK155 For some reason without this the remnants
        of the expanded panel are not erased }
    ChangeBounds(OldPanelBounds);
    Show;
    PanelZoomed := False;
    if not SinglePanel then
      SwitchPanel(Other);
    end;
  UnLock;
  end;

procedure TDoubleWindow.HandleCommand(var Event: TEvent);
  var
    Selected: Boolean;
    Visible: array [TPanelNum] of Boolean;
    Sp: TSeparator;
    EV: TEvent;

  procedure CE;
    begin
    ClearEvent(Event)
    end;

  { Whether the Selected panel is a file panel, i.e. whether a non-file
   panel can be attached to it }
  function isFilePanel: Boolean;
    begin
    result := (NonFilePanelType = 0) or (Selected <> NonFilePanel);
    end;

  procedure InsertPath(N: TPanelNum);
    var
      S: string;
    begin
    S := '';
    Message(Panel[N].AnyPanel, evCommand, cmGetDirName, @S);
    if S <> '' then
      begin
      if not (IsPathSep(S[Length(S)])) then
        AddStr(S, DnSep);
      S := SquashesName(S);
      Message(CommandLine, evCommand, cmInsertName, @S);
      end;
    CE;
    end;

  { Move the separator right (D=1) or left (D=-1). If
  Shift is pressed - by a whole file column }
  procedure SeparatorMove(D: Integer);
    var
      X: Integer;
      N: TPanelNum;
      R: TRect;
    begin
    if Visible[pRight] and Visible[pLeft] then
      begin
      if ShiftState and (kbLeftShift+kbRightShift) <> 0 then
        begin
        { When shifting by a file-column width, choose the panel
        from which to take that width. Take the active one if it is
        a file panel, or the other if the active one is non-file.}
        N := Selected xor (Panel[Selected].PanelType <> dtPanel);
        D := D*Panel[N].FilePanel.LineLength;
        end;
      Sp.OldW := Size.X;
      X := Sp.Origin.X + D + 1;
      Sp.OldX := Min(Max(X, 0), Sp.OldW);
      R := GetBounds;
      ChangeBounds(R);
      CE;
      end;
    end;

  var
    R, R1, R2: TRect;
    I, K: Integer;
    AP, PP: TFilePanel;
    D: Word;
    P: TView;
    N: TPanelNum;
    S: String;
    WPanel: TPanelDescr;
    WR: array[TPanelNum] of TRect;

  begin { TDoubleWindow.HandleCommand }
  for N := pLeft to pRight  do
    Visible[N] := Panel[N].AnyPanel.GetState(sfVisible);
  Selected := Panel[pRight].AnyPanel.GetState(sfSelected);
  Sp := Separator;
  case Event.What of
    evKeyDown:
      case DNKeyCode(Event) of
        kbCtrlLeft, kbCtrlRight,
        kbCtrlShiftLeft, kbCtrlShiftRight:
          if  not QuickSearch and
              (FMSetup.LRCtrlInDriveLine <> fdlNoDifference) and
              (Visible[pLeft] and Visible[pRight]) then
            begin
            N := (ShiftState2 and 1 = 0);
            if (FMSetup.LRCtrlInDriveLine = fdlPassive) then
              N := N xor not Selected;
            Panel[N].AnyPanel.HandleEvent(Event);
            Exit;
            end;

        kbAlt1, kbAlt2, kbAlt3, kbAlt4, kbAlt5, kbAlt0,
        kbAlt6, kbAlt7, kbAlt8, kbAlt9:
          if FMSetup.Options and fmoAltDifference <> 0 then
            begin
            if Visible[pLeft] and (ShiftState2 and 2 <> 0) then
              Panel[pLeft].AnyPanel.HandleEvent(Event)
            else
              Panel[pRight].AnyPanel.HandleEvent(Event);
            Exit;
            end;
        {
              kbCtrl1, kbCtrl2, kbCtrl3, kbCtrl4, kbCtrl5, kbCtrl6, kbCtrl7,
              kbCtrl8, kbCtrl9, kbCtrl0:
                     if FMSetup.Options and fmoCtrlDifference <> 0 then
                           begin
                             if Visible[pLeft] and (ShiftState2 and 1 <> 0) then
                                Panel[pLeft].AnyPanel.HandleEvent(Event) else
                                Panel[pRight].AnyPanel.HandleEvent(Event);
                             Exit;
                           end;
}
        kbAltLeft, kbAltShiftLeft:
          SeparatorMove(-1);
        kbAltRight, kbAltShiftRight:
          SeparatorMove(1);
        kbAltCtrlSqBracketL, kbCtrlSqBracketL:
          InsertPath(pLeft);
        kbAltCtrlSqBracketR, kbCtrlSqBracketR:
          InsertPath(pRight);
      end {case};
    evBroadcast:
      case Event.Message.Command of
        cmLookForPanels:
          ClearEvent(Event);
        cmGetUserParams, cmGetUserParamsWL:
          begin
          PP := Panel[not Selected].FilePanel;
          AP := Panel[Selected].FilePanel;
          with PUserParams(Event.Message.InfoPtr)^ do
            begin
            AP.GetUserParams(Active, ActiveList, Event.Message.Command =
               cmGetUserParamsWL);
            PP.GetUserParams(Passive, PassiveList, Event.Message.Command =
               cmGetUserParamsWL);
            end;
          CE;
          end;
        cmChangeDirectory:
          begin
          Panel[Selected].FilePanel.ChDir(PString(Event.Message.InfoPtr)^);
          CE;
          end;
        cmChangeDrv: {command line like C: or *: }
          begin
          Event.What := evCommand;
          Panel[Selected].FilePanel.HandleEvent(Event);
          ClearEvent(Event);
          end;
        cmIsRightPanel:
          if Event.Message.InfoPtr = Panel[pRight].FilePanel then
            ClearEvent(Event);
      end {case};
    evCommand:
      case Event.Message.Command of

        cmSwitchOther:
          if not PanelZoomed then
            begin
            CE;
            SwitchPanel(not Selected);
            end;
        cmZoom:
          begin
          { Flash 05-02-2004 >>> }
          if Panel[Selected].PanelType = dtQView then
            begin
            OldBounds := GetBounds;
            OldPanelBounds := GetBounds;
            if (Size.X < Desktop.Size.X) or PanelZoomed then
              Message(Self, evCommand, cmMaxi, nil);
            end;
          { Flash 05-02-2004 <<< }
          end;
        cmMaxi:
          begin
          CE;
          if (NonFilePanelType <> 0) and (NonFilePanel = Selected) then
            begin { work with non-file panel }
            ToggleViewMaxiState(Panel[Selected].AnyPanel, not Selected);
            end
          else
            begin { work with file panel }
            with ActivePanel.PanSetup.Show do
              MiscOptions := MiscOptions xor 1;
            SetMaxiState(ActivePanel);
            end;
          end;
        cmGetName:
          begin
          PString(Event.Message.InfoPtr)^:= GetString(dlFileManager);
          K := (55-Length(PString(Event.Message.InfoPtr)^)) div 2;
          for N := pLeft to pRight do
            begin
            S := '??'; // in case the window does not handle cmGetName
            Message(Panel[N].AnyPanel, evCommand, cmGetName, @S);
            PString(Event.Message.InfoPtr)^:= PString(Event.Message.InfoPtr)^+
              Cut((S),K);
            if N = pLeft then
              PString(Event.Message.InfoPtr)^:= PString(Event.Message.InfoPtr)^+',';
            end;
          CE
          end;
        cmPostHideRight, cmPostHideLeft: {Ctrl-F1/F2 from UserScreen}
          begin
          N := Event.Message.Command = cmPostHideRight;
          if not Visible[N] then
            begin
            SwitchPanel(N);
            Visible[N] := True;
            end;
          if Visible[not N] then
            SwitchPanel(not N);
          CE
          end;
        cmChangeInactive: {in search panel Shift-Enter }
          begin
          Event.Message.Command := cmFindGotoFile;
          with Panel[not Selected] do
            begin
            FilePanel.HandleEvent(Event);
            if PanelType <> dtPanel then
              SwitchView(PanelType);
            end;
          CE;
          end;
        cmPanelCompare:
          Panel[not Selected].FilePanel.HandleEvent(Event);
        cmDiskInfo:
          begin
          if isFilePanel then
            begin
            SwitchView(dtInfo);
            Message(Panel[Selected].AnyPanel, evCommand, cmLViewFile, nil)
            end;
          CE;
          end;
        
        cmLoadViewFile:
          if not PanelZoomed then
            begin
            if  (NonFilePanelType in [dtQView, dtDizView]){ and
              NonFilePanel^.GetState(sfVisible)}
            then
              Panel[NonFilePanel].AnyPanel.HandleEvent(Event);
            CE;
            end;
        cmPushFullName,
        cmPushFirstName,
        cmPushInternalName:
          begin {< panelwin.001 >}
          if Visible[not Selected] then
             Panel[not Selected].AnyPanel.HandleEvent(Event);
          CE;
          Exit;
          end;
        cmFindTree,
        cmRereadTree:
          if NonFilePanelType = dtTree then
            Panel[NonFilePanel].AnyPanel.HandleEvent(Event);
        cmHideLeft, cmHideRight:
          begin
          N := Event.Message.Command = cmHideRight;
          if Visible[N] and not Visible[not N] then
            Message(Application, evCommand, cmShowOutput, nil)
          else
            SwitchPanel(N);
          CE
          end;
        cmChangeLeft:
          begin
          ChangeDrv(pLeft);
          CE
          end;
        cmChangeRight:
          begin
//          ChangeDrvRight;
          ChangeDrv(pRight);
          CE
          end;
        cmDirTree:
          begin
          if isFilePanel then
            SwitchView(dtTree);
          CE
          end;
        cmQuickView:
          begin
          if isFilePanel then
            begin
            SwitchView(dtQView);
            Message(Panel[Selected].AnyPanel, evCommand, cmLViewFile, nil);
            end;
          CE;
          end;
        cmDizView:
          begin
          if isFilePanel then
            begin
            SwitchView(dtDizView);
            Message(Panel[Selected].AnyPanel, evCommand, cmLViewFile, nil);
            end;
          CE;
          end;
        cmSwapPanels:
          if not PanelZoomed then
            begin
//            Lock;
            for N := pLeft to pRight do
              begin
              if not Visible[N] then
                SwitchPanel(N);
              WR[N] := Panel[N].AnyPanel.GetBounds;
              WR[N].B.Y := Size.Y-1;
              end;
            WPanel := Panel[pLeft];
            Panel[pLeft] := Panel[pRight];
            Panel[pRight] := WPanel;
            NonFilePanel := not NonFilePanel;
            for N := pLeft to pRight do
              begin
              Panel[N].AnyPanel.ChangeBounds(WR[N]);
              if not Visible[not N] then
                SwitchPanel(N);
              Panel[N].FilePanel.SelfNum := N;
              end;
            Redraw;
//            UnLock;
            CE
            end;
      end {case};
  end {case};
  inherited HandleEvent(Event);
  end { TDoubleWindow.HandleCommand };

{ --------------------------- TSeparator ----------------------------- }

function TSeparator.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  inherited Read(Ip);
  Ip.ReadBytes(OldX, 4);
  end;

procedure TSeparator.Write(Os: opstream);
  begin
  inherited Write(Os);
  Os.WriteBytes(OldX, 4);
  end;

class function TSeparator.Build: TStreamable;
begin
  Result := TSeparator.Create(streamableInit);
end;

function TSeparator.StreamableName: ShortString;
begin
  Result := 'panelwin.TSeparator';
end;

constructor TSeparator.Create(const R: TRect; AH: Integer);
  begin
  inherited Create(R);
  OldX := Origin.X+1;
  OldW := AH;
  EventMask := $FFFF;
  end;

procedure TSeparator.HandleEvent(var Event: TEvent);
  var
    P: TPoint;
    R: TRect;
    RD: Integer;
    B: Byte;
  begin
  inherited HandleEvent(Event);
  case Event.What of
    evMouseDown:
      begin
      P := MakeLocal(Event.Mouse.Where);
      B := P.X;
      RD := RepeatDelay;
      RepeatDelay := 0;
      repeat
        P := Owner.MakeLocal(Event.Mouse.Where);
        if  (P.X >= 1) and (P.X < Owner.Size.X-2) then
          begin
          OldX := P.X+1-B;
          OldW := Owner.Size.X;
          R.A := Owner.Origin;
          R.B.X := Owner.Origin.X+Owner.Size.X;
          R.B.Y := Owner.Origin.Y+Owner.Size.Y;
          Owner.ChangeBounds(R);
          end;
      until not MouseEvent(Event, evMouseAuto+evMouseMove);
      RepeatDelay := RD;
      ClearEvent(Event);
      end;
  end {case};
  end { TSeparator.HandleEvent };

procedure TSeparator.Draw;
  var
    B: array[0..128] of record
      C: Char;
      B: Byte;
      end;
    C: Word;
    Ch: Char;
  begin
  RK := Owner.GetColorW(2);
  if Owner.GetState(sfActive) then
    C := RK
  else
    C := Owner.GetColorW(1);
  if Owner.GetState(sfDragging) then
    C := Owner.GetColorW(3);
  B[0].B := C;
  B[Size.Y-1].B := C;
  if Owner.GetState(sfActive) and not Owner.GetState(sfDragging) then
    begin
    B[0].C := GlyphChar(glDblDL);
    Ch := GlyphChar(glDblV);
    B[Size.Y-1].C := GlyphChar(glDblUL);
    end
  else
    begin
    B[0].C := GlyphChar(glLightDL);
    Ch := GlyphChar(glLightV);
    B[Size.Y-1].C := GlyphChar(glLightUL);
    end;
  MoveChar(B[1], Ch, C, Size.Y-2);
  WriteBufW(0, 0, 1, Size.Y, B);
  if Owner.GetState(sfActive) and not Owner.GetState(sfDragging) then
    begin
    B[0].C := GlyphChar(glDblDR);
    B[Size.Y-1].C := GlyphChar(glDblUR);
    end
  else
    begin
    B[0].C := GlyphChar(glLightDR);
    B[Size.Y-1].C := GlyphChar(glLightUR);
    end;
  WriteBufW(1, 0, 1, Size.Y, B);
  end { TSeparator.Draw };

end.


