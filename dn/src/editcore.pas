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

{ The editor of DN: a view (TFileEditor) over the editor of tve (https://github.com/unxed/tve).

  The text, the undo, the selections, the search, the highlighting and the keys are the work of tve (TveView and the units under it);
  what is here is what is DN's: the commands of its menus and the dialogs with their resources, the options, the clipboard of DN and the system one, the windows
  (SmartPad, the clipboard window), the history of the places in the files, the information line, and the streams of the desktop.

  The columns of this editor are cells of the screen (a tab is as wide as it looks, a wide character is two); the text is UTF-8 (a file in a code page is
  converted when it is read and written back as it was). }
{$I STDEFINE.INC}
unit editcore;

interface

uses
  Defines, Streams, Drivers, Views, basics, Menus, Commands, ObjType, keymap, Collect,
  TveDoc, TveView, TveSearch;

const
  ClipBoard: TCollection = nil;

  CFileEditor = #13#14#16#17#18#19#20#21#22#23#24#25;
    { 1 text, 2 block, 3 comment, 4 and 5 text and block of the current line, 6 comment of the current line, 7 the current column, 8 signs, 9 strings,
      10 numbers, 11 and 12 the two kinds of keywords }

  ClipBoardStream: TStream = nil;

type
  PEditOptions = ^TEditOptions;
  TEditOptions = record
    AutoIndent: Boolean;
    AutoBrackets: Boolean;
    BackIndent: Boolean; {BACKUNINDENTS}
    HiLite: Boolean;
    HiliteLine: Boolean;
    HiliteColumn: Boolean;
    AutoJustify: Boolean; {WRAPJUSTIFY}
    AutoWrap: Boolean; {AUTOWRAP}
    LeftSide: Word; {LEFTMARGIN}
    RightSide: Word; {RIGHTMARGIN}
    InSide: Word; {PARAGRAPH}
    ForcedCRLF: TCRLF;
    SmartTab: Boolean;
    end;

  TFileEditor = class(TTveView)
    {Cat: this type is exposed via the plugin model; change with extreme care!}
  private
    FLastUndo, FLastRedo: Integer;
    FLastSel, FLastMod: Boolean;
    function HostCommand(Sender: TTveSender; Cmd: Integer): Boolean;
    function LineAttrHook(Sender: TTveSender; Line: Int64; var Attr: TColorAttr): Boolean;
    procedure ClipSet(const Text: AnsiString; Column: Boolean);
    function ClipGet(out Text: AnsiString; out Column: Boolean): Boolean;
    function KeyDown(var Event: TEvent): Boolean;
    procedure TypeAt(const S: AnsiString);
    procedure FindAndShow(Reverse: Boolean);
    procedure DoReplace(const Opt: TTveSearchOptions);
  protected
    function ClassAttr(C: Integer): TColorAttr; override;
    procedure Changed; override;
  public
    ReplaceAllFlag: Boolean;
    EditName: String;
    isValid: Boolean;
    SmartPad: Boolean;
    ClipBrd: Boolean;
    OptMenu: PMenu;
    EdOpt: TEditOptions;
    OptimalFill: Boolean;
    TabReplace: Boolean;
    JustSaved: Boolean;
    Macros: TCollection;
    Locker: TStream;
    InfoL, BMrk: TView;
    SavedCursor: TPoint;
    SavedMark: TRect;
    SavedMarks: TPosArray;
    MenuItemStr: array[Boolean] of PString;
    constructor Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar; var FileName: String);
    constructor Load(S: TStream);
    destructor Destroy; override;
    procedure Store(S: TStream); override;
    procedure Awaken; override;
    procedure HandleEvent(var Event: TEvent); override;
    procedure Draw; override;
    function Valid(Command: Word): Boolean; override;
    function GetPalette: TPalette; override;
    procedure SetState(AState: Word; Enable: Boolean); override;
    procedure ChangeBounds(const R: TRect); override;
    function HandleCommand(var Event: TEvent): Boolean; virtual;
      {` The place of a plugin: a command that the editor has not seen yet. True if it was done. `}
    procedure CalcMenu;
      {` Enables and disables the commands of the menu by the state of the editor, and writes On / Off in the menu of the options. `}

    { --- the place --- }
    function GetCursor: TPoint;
    function GetTopLine: LongInt;
    function GetLineCount: LongInt;
    procedure GotoXY(X, Y: LongInt);
      {` The cursor to the column X (cells) of the line Y (both from 0); the view scrolls to it. `}
    function GetMark: TRect;
    procedure SetMark(const R: TRect);
      {` The block: A is the beginning (the column, the line), B the end; an empty one clears it. `}
    function GetBlockVisible: Boolean;
    function GetMarkPos(N: Integer): TPoint;
    procedure SetMarkPos(N: Integer; const P: TPoint);
    function GetMarks: TPosArray;
    procedure SetMarks(const A: TPosArray);
    function GetVertBlock: Boolean;
    procedure SetVertBlock(V: Boolean);
    function GetModified: Boolean;
    procedure SetModified(V: Boolean);
    function GetEolMode: TCRLF;
    procedure SetEolMode(V: TCRLF);
    function GetInsertMode: Boolean;
    procedure SetInsertMode(V: Boolean);
    function CodeAtCursor: LongWord;
    function CharsetTag: String;
    function CharsetKeyMap: TKeyMap;
    function GetText: AnsiString;
    function GetLineText(L: LongInt): AnsiString;
    property Cursor: TPoint read GetCursor;
    property TopLine: LongInt read GetTopLine;
    property LineCount: LongInt read GetLineCount;
    property Mark: TRect read GetMark write SetMark;
    property BlockVisible: Boolean read GetBlockVisible;
    property MarkPos[N: Integer]: TPoint read GetMarkPos write SetMarkPos;
    property VertBlock: Boolean read GetVertBlock write SetVertBlock;
    property Modified: Boolean read GetModified write SetModified;
    property EolMode: TCRLF read GetEolMode write SetEolMode;
    property InsertMode: Boolean read GetInsertMode write SetInsertMode;
    property HScroll: TScrollBar read HScrollBar;
    property VScroll: TScrollBar read VScrollBar;

    { --- the options --- }
    procedure ApplyOptions;
      {` Gives the options of this editor (EdOpt, VertBlock, TabReplace, and the defaults of DN) to tve and shows the highlight that they ask for. `}
    procedure ApplyLanguage;

    { --- the history of the places in the files --- }
    procedure FillRecord(P: Pointer);
    procedure ApplyRecord(P: Pointer; WithPlace: Boolean);

    { the commands that need dialogs or other windows of DN }
    procedure StartSearch(Replace: Boolean);
    procedure ContinueSearch(Reverse: Boolean);
    procedure GotoLineDialog;
    procedure SetMarginsDialog;
    procedure CopyBlockToFile;
    procedure PasteBlockFromFile;
    procedure PrintText(Block: Boolean);
    procedure OpenFileAtCursor;
    procedure InsertDateTime(Time: Boolean);
    procedure SwitchCharset;
    procedure FormatParagraph(Mode: Word);
    procedure CalcBlock;
    procedure ChangeCase(Command: Word);
    procedure SwitchDraw;
    procedure PlayMacro(N: Integer);
    procedure SelectMacro;
    procedure CloseMe;
    function CommandOf(Cmd: Word; var Event: TEvent): Boolean;
    end;

procedure OpenEditor;
procedure OpenSmartpad;
procedure OpenClipBoard;

type
  TSearchData = record
   {` Search/replace dialog data}
    Options: Word;
      {` Bit0 - case-sensitive, bit1 - whole words,
        bit2 - "in all encodings" for search and "ask for confirmation"
        for replace. `}
    Dir: Word;
      {` Bit0=1 - search backward`}
    Scope: Word;
      {` Bit0=1 - selected text`}
    Origin: Word;
      {` Bit0=1 - from start of text`}
    Line,
      {` What to search for`}
    What: String[250];
      {` What to replace with.
      Search (not replace) is indicated by What = #0`}
    end;

  {Cat: search parameters (TSearchData.Options)}
  {must stay in sync with the SwapBits constant below}
const
  efoCaseSens = 1;
  efoWholeWords = 2;
  efoReplacePrompt = 4;
  efoRegExp = 8;
  efoAllCP = 16;
  {/Cat}

const
  SearchData: TSearchData = (Options: 4; Dir: 0; Scope: 0; Origin: 0;
     Line: ''; What: '');

type
  TEditCommand = record
    C, C1, C2: Word;
    CC1, CC2: array[1..2] of Char;
    end;

const
  MaxCommands: AInt = 0;
var
  EditCommands: array[1..110] of TEditCommand;

{ The clipboard of DN as the text (the lines joined by LF) and back. }
function ClipboardText: AnsiString;
procedure SetClipboardText(const T: AnsiString);

{ The name of a file of DN (C:\DIR\FILE) as the name that the system opens. }
function OsFileName(const DnName: String): AnsiString;

{ The text of DN (UTF-8 with -dDNUTF8, else the bytes of the code page) as UTF-8 and back. }
function UiToDoc(const S: AnsiString): AnsiString;
function DocToUi(const S: AnsiString): AnsiString;

implementation

uses DnPath,
  Messages, mainapp, Dos, Lfn, strutil, fileutil, Startup,
  progress, FViewer, HistList, Macro, Editor, WinClp, DNUtil, histories,
  timeutil, FileCopy, ASCIITab, DnIni, findspf, editwin, editfile, editinfo
, TvCodePg, TvUtf8, TvGlyphs, TvCharset, TvKeys, TvXlat
, osdep, DNStdDlg, Dialogs, DNHelp, Math, fileerrors
, TveBuf, TveEditor, TveCmds, TveBlocks, TveExtras, TveLang, TveHl, TveLayout, TveFile
  ;

const
  cmNoCommand = 4000;

{ --- the text of DN and the text of the editor --- }

function OsFileName(const DnName: String): AnsiString;
  begin
  Result := SysOsPath(DnName);
  end;

function UiToDoc(const S: AnsiString): AnsiString;
  begin
{$IFDEF DNUTF8}
  Result := S;
{$ELSE}
  Result := OemToUtf8(S);
{$ENDIF}
  end;

function DocToUi(const S: AnsiString): AnsiString;
  begin
{$IFDEF DNUTF8}
  Result := S;
{$ELSE}
  Result := Utf8ToOem(S);
{$ENDIF}
  end;

function UiToDocByte(B: Byte): AnsiString;
  begin
  if B < 128 then
    Result := Char(B)
  else
    Result := UiToDoc(Char(B));
  end;

function ClipboardText: AnsiString;
  var
    I: LongInt;
    P: PLongString;
  begin
  Result := '';
  if ClipBoard = nil then
    Exit;
  for I := 0 to ClipBoard.Count-1 do
    begin
    P := ClipBoard.At(I);
    if I > 0 then
      Result := Result+#10;
    if P <> nil then
      Result := Result+P^;
    end;
  end;

procedure SetClipboardText(const T: AnsiString);
  var
    P, Q: LongInt;
  begin
  if ClipBoard <> nil then
    ClipBoard.Free;
  ClipBoard := TLineCollection.Create(10, 10, True);
  P := 1;
  repeat
    Q := P;
    while (Q <= Length(T)) and (T[Q] <> #10) do
      Inc(Q);
    ClipBoard.Insert(NewLongStr(Copy(T, P, Q-P)));
    P := Q+1;
  until P > Length(T)+1;
  end;

var
  ClipColumn: Boolean = False;     { the text in ClipBoard is a column block }
  ClipColumnText: AnsiString = '';

{ --- TFileEditor: the creation --- }

constructor TFileEditor.Create(const Bounds: TRect; AHScrollBar, AVScrollBar: TScrollBar; var FileName: String);
  var
    Line: String;
  begin
  inherited Create(Bounds, AHScrollBar, AVScrollBar, TTveDoc.Create, True);
  HelpCtx := hcEditor;
  Options := Options or ofSelectable;
  GrowMode := gfGrowHiX+gfGrowHiY;
  EventMask := $FFFF;
  isValid := True;
  EdOpt.HiliteColumn := EditorDefaults.EdOpt and ebfHCl <> 0;
  EdOpt.HiliteLine := EditorDefaults.EdOpt and ebfHLn <> 0;
  EdOpt.AutoIndent := EditorDefaults.EdOpt and ebfAId <> 0;
  EdOpt.BackIndent := EditorDefaults.EdOpt and ebfBSU <> 0;
  EdOpt.AutoJustify := EditorDefaults.EdOpt and ebfJwr <> 0;
  EdOpt.AutoBrackets := EditorDefaults.EdOpt and ebfABr <> 0;
  EdOpt.AutoWrap := EditorDefaults.EdOpt and ebfAwr <> 0;
  EdOpt.SmartTab := EditorDefaults.EdOpt2 and ebfSmt <> 0;
  EdOpt.HiLite := EditorDefaults.EdOpt2 and ebfHlt <> 0;
  EdOpt.ForcedCRLF := cfNone;
  OptimalFill := EditorDefaults.EdOpt and ebfOfl <> 0;
  TabReplace := EditorDefaults.EdOpt and ebfTRp <> 0;
  Editor.Opt.ColumnBlocks := EditorDefaults.EdOpt and ebfVBl <> 0;
  Val(EditorDefaults.RM, EdOpt.RightSide);
  if EdOpt.RightSide = 0 then
    EdOpt.RightSide := 76;
  Val(EditorDefaults.LM, EdOpt.LeftSide);
  Val(EditorDefaults.PM, EdOpt.InSide);
  if EdOpt.InSide = 0 then
    EdOpt.InSide := 5;
  SmartPad := FileName = 'SmartPad';
  ClipBrd := FileName = 'Clipboard';
  if SmartPad then
    begin
    Line := GetEnv('SMARTPAD');
    if Line = '' then
      Line := ConfigDir;
    MakeSlash(Line);
    FileName := Line+FileName+'.DN';
    end
  else if ClipBrd then
    FileName := '';
  Macros := TCollection.Create(10, 10);
  MenuItemStr[True] := NewStr(GetString(dlMenuItemOn));
  MenuItemStr[False] := NewStr(GetString(dlMenuItemOff));
  ApplyOptions;
  end;

constructor TFileEditor.Load(S: TStream);
  begin
  inherited LoadWith(S, TTveDoc.Create, True);
  HelpCtx := hcEditor;
  isValid := True;
  MILoad(Self, S);
  ApplyOptions;
  end;

destructor TFileEditor.Destroy;
  begin
  DisposeStr(MenuItemStr[False]);
  DisposeStr(MenuItemStr[True]);
  if Macros <> nil then
    begin
    Macros.Free;
    Macros := nil;
    end;
  if Locker <> nil then
    begin
    Locker.Free;
    Locker := nil;
    end;
  if SmartPad then
    begin
    SmartWindowPtr := @SmartWindow;
    SmartWindow := nil;
    end;
  if ClipBrd then
    begin
    ClipboardWindowPtr := @ClipboardWindow;
    ClipboardWindow := nil;
    end;
  inherited Destroy;
  end;

procedure TFileEditor.Store(S: TStream);
  begin
  inherited Store(S);
  MIStore(Self, S);
  end;

procedure TFileEditor.Awaken;
  begin
  MIAwaken(Self);
  end;

function TFileEditor.GetPalette: TPalette;
  const
    S: String[Length(CFileEditor)] = CFileEditor;
  begin
  GetPalette := MakePalette(S);
  end;

{ --- the places --- }

function TFileEditor.GetCursor: TPoint;
  begin
  Result.X := Editor.Cell;
  Result.Y := Editor.Line;
  end;

function TFileEditor.GetTopLine: LongInt;
  begin
  Result := ViewToLine(Delta.Y);
  end;

function TFileEditor.GetLineCount: LongInt;
  begin
  Result := Doc.Buffer.LineCount;
  end;

procedure TFileEditor.GotoXY(X, Y: LongInt);
  begin
  if Y < 0 then
    Y := 0;
  if Y >= Doc.Buffer.LineCount then
    Y := Doc.Buffer.LineCount-1;
  if X < 0 then
    X := 0;
  Editor.ClearSelection;
  Editor.GotoLineCell(Y, X);
  Refresh;
  end;

function TFileEditor.GetMark: TRect;
  var
    A, B, L1, L2: Int64;
    C1, C2: Integer;
    Kind: TTveSelKind;

  function Place(Offset: Int64; var P: TPoint): Boolean;
    var
      L: Int64;
      T: AnsiString;
    begin
    L := Doc.Buffer.LineOfOffset(Offset);
    T := Doc.Buffer.LineText(L);
    P.Y := L;
    P.X := LayoutIndexToCell(T, Offset-Doc.Buffer.LineStart(L)+1, Editor.Opt.TabSize);
    Result := True;
    end;

  begin
  Result.Assign(0, 0, 0, 0);
  if not Editor.HasSelection then
    Exit;
  Kind := Editor.SelKind;
  if (Kind = skColumn) and Editor.ColumnRect(L1, L2, C1, C2) then
    begin
    Result.A.X := C1;
    Result.A.Y := L1;
    Result.B.X := C2;
    Result.B.Y := L2;
    end
  else if Editor.SelectionRange(A, B) then
    begin
    Place(A, Result.A);
    Place(B, Result.B);
    end;
  end;

procedure TFileEditor.SetMark(const R: TRect);
  var
    A, B: Int64;
  begin
  if (R.A.X = R.B.X) and (R.A.Y = R.B.Y) then
    begin
    Editor.ClearSelection;
    Exit;
    end;
  A := Editor.LineCellToOffset(R.A.Y, R.A.X);
  B := Editor.LineCellToOffset(R.B.Y, R.B.X);
  Editor.SetBlockMarks(A, B);
  end;

function TFileEditor.GetBlockVisible: Boolean;
  begin
  Result := Editor.HasSelection;
  end;

function TFileEditor.GetMarkPos(N: Integer): TPoint;
  var
    L: Int64;
  begin
  Result.X := -1;
  Result.Y := -1;
  if (N < 1) or (N > 9) then
    Exit;
  L := Editor.BookmarkLine(N);
  if L < 0 then
    Exit;
  Result.Y := L;
  Result.X := 0;
  end;

procedure TFileEditor.SetMarkPos(N: Integer; const P: TPoint);
  var
    Was: TPoint;
  begin
  if (N < 1) or (N > 9) then
    Exit;
  if (P.X < 0) or (P.Y < 0) then
    begin
    Editor.ClearBookmark(N);
    Exit;
    end;
  Was := Cursor;
  Editor.GotoLineCell(P.Y, P.X);
  Editor.SetBookmark(N);
  Editor.GotoLineCell(Was.Y, Was.X);
  end;

function TFileEditor.GetMarks: TPosArray;
  var
    I: Integer;
  begin
  for I := 1 to 9 do
    Result[I] := GetMarkPos(I);
  end;

procedure TFileEditor.SetMarks(const A: TPosArray);
  var
    I: Integer;
  begin
  for I := 1 to 9 do
    SetMarkPos(I, A[I]);
  end;

function TFileEditor.GetVertBlock: Boolean;
  begin
  Result := Editor.Opt.ColumnBlocks;
  end;

procedure TFileEditor.SetVertBlock(V: Boolean);
  begin
  Editor.Opt.ColumnBlocks := V;
  end;

function TFileEditor.GetModified: Boolean;
  begin
  Result := Doc.Modified;
  end;

procedure TFileEditor.SetModified(V: Boolean);
  begin
  if V then
    Exit;
  Doc.MarkSaved;
  end;

function TFileEditor.GetEolMode: TCRLF;
  begin
  case Doc.Eol of
    eolCRLF: Result := cfCRLF;
    eolCR: Result := cfCR;
    else
      Result := cfLF;
  end;
  end;

procedure TFileEditor.SetEolMode(V: TCRLF);
  begin
  case V of
    cfCRLF: Doc.Eol := eolCRLF;
    cfCR: Doc.Eol := eolCR;
    cfLF: Doc.Eol := eolLF;
  end;
  EdOpt.ForcedCRLF := V;
  end;

function TFileEditor.GetInsertMode: Boolean;
  begin
  Result := Editor.Opt.InsertMode;
  end;

procedure TFileEditor.SetInsertMode(V: Boolean);
  begin
  Editor.Opt.InsertMode := V;
  end;

function TFileEditor.CodeAtCursor: LongWord;
  var
    S: AnsiString;
    L: Int64;
    I, N: Integer;
  begin
  Result := 0;
  L := Editor.Line;
  S := Doc.Buffer.LineText(L);
  I := LayoutCellToIndex(S, Editor.Cell, Editor.Opt.TabSize);
  if (I < 1) or (I > Length(S)) then
    Exit;
  if not Utf8Decode(PByte(@S[I]), Length(S)-I+1, Result, N) then
    Result := Byte(S[I]);
  end;

function TFileEditor.CharsetTag: String;
  begin
  case Doc.Info.Charset of
    csUtf8: Result := 'UTF';
    csUtf16LE, csUtf16BE: Result := 'U16';
    866, 437, 850: Result := 'DOS';
    1251, 1252, 1250: Result := 'WIN';
    20866, 21866: Result := 'KOI';
    else
      Result := 'C'+Copy(ItoS(Doc.Info.Charset), 1, 2);
  end;
  end;

function TFileEditor.CharsetKeyMap: TKeyMap;
  begin
  case Doc.Info.Charset of
    1251, 1252, 1250: Result := kmAnsi;
    20866, 21866: Result := kmKoi8r;
    else
      Result := kmAscii;
  end;
  end;

function TFileEditor.GetText: AnsiString;
  begin
  Result := Doc.Buffer.AsString;
  end;

function TFileEditor.GetLineText(L: LongInt): AnsiString;
  begin
  if (L < 0) or (L >= Doc.Buffer.LineCount) then
    Result := ''
  else
    Result := Doc.Buffer.LineText(L);
  end;

{ --- the options --- }

procedure TFileEditor.ApplyOptions;
  var
    T: Integer;
  begin
  T := StoI(EditorDefaults.TabSize);
  if T <= 0 then
    T := 8;
  if T > 100 then
    T := 100;
  with Editor.Opt do
    begin
    TabSize := T;
    IndentSize := 1;
    AutoIndent := EdOpt.AutoIndent;
    SmartTab := EdOpt.SmartTab;
    BackspaceUnindent := EdOpt.BackIndent;
    AutoBrackets := EdOpt.AutoBrackets;
    UseTabChars := not TabReplace;
    PersistentBlocks := EditorDefaults.EdOpt and ebfPBl <> 0;
    OverwriteBlocks := EditorDefaults.EdOpt and ebfObl <> 0;
    FreeCursor := True;
    SmartHome := False;
    if EdOpt.AutoWrap and (EdOpt.RightSide > 0) then
      WrapColumn := EdOpt.RightSide
    else
      WrapColumn := 0;
    end;
  HighlightColumn := EdOpt.HiliteColumn;
  KeysEnabled := False;
  OnLineAttr := LineAttrHook;
  OnHostCommand := HostCommand;
  Editor.OnClipSet := ClipSet;
  Editor.OnClipGet := ClipGet;
  ApplyLanguage;
  end;

procedure TFileEditor.ApplyLanguage;
  begin
  if EdOpt.HiLite and (EditName <> '') then
    SetLanguage(TveLangForFile(OsFileName(EditName)))
  else
    SetLanguage(nil);
  end;

procedure TFileEditor.Changed;
  begin
  inherited Changed;
  if (State and sfExposed) = 0 then
    Exit;
  if InfoL <> nil then
    InfoL.DrawView;
  if BMrk <> nil then
    BMrk.DrawView;
  if (Doc.UndoCount <> FLastUndo) or (Doc.RedoCount <> FLastRedo) or (Editor.HasSelection <> FLastSel) or (Doc.Modified <> FLastMod) then
    CalcMenu;
  end;

{ --- the colours: the palette of DN has twelve entries, see CFileEditor --- }

function TFileEditor.ClassAttr(C: Integer): TColorAttr;
  var
    N: Integer;
  begin
  Result := NormalAttr;
  case C of
    hcComment:
      N := 3;
    hcString, hcEscape, hcValue:
      N := 9;
    hcNumber, hcEntity, hcSpecial:
      N := 10;
    hcKeyword, hcPreproc, hcTag, hcSelector, hcAsm:
      N := 11;
    hcType, hcBuiltin, hcAttr, hcVariable, hcFunction, hcProperty:
      N := 12;
    hcOperator, hcDelimiter:
      N := 8;
    else
      Exit;
  end;
  AttrSetFg(Result, AttrFg(GetColor(N).Lo));
  end;

function TFileEditor.LineAttrHook(Sender: TTveSender; Line: Int64; var Attr: TColorAttr): Boolean;
  begin
  Result := False;
  if EdOpt.HiliteLine and (Line = Editor.Line) then
    begin
    Attr := GetColor(4).Lo;
    Result := True;
    end;
  end;

{ --- the clipboard: the one of DN (lines) and the system one --- }

procedure TFileEditor.ClipSet(const Text: AnsiString; Column: Boolean);
  begin
  SetClipboardText(Text);
  ClipColumn := Column;
  ClipColumnText := Text;
  if SystemData.Options and ossUseSysClip <> 0 then
    SyncClipIn;
  end;

function TFileEditor.ClipGet(out Text: AnsiString; out Column: Boolean): Boolean;
  begin
  if SystemData.Options and ossUseSysClip <> 0 then
    SyncClipOut;
  Text := ClipboardText;
  Column := ClipColumn and (Text = ClipColumnText);
  Result := (ClipBoard <> nil) and (Text <> '');
  end;

{ --- the state of the menu --- }

procedure TFileEditor.CalcMenu;
  var
    GC: TCommandSet;
    MI: PMenuItem;
    BlkC: TCommandSet;

  procedure SetM(B: Boolean);
    var
      G: String;
    begin
    if MI = nil then
      Exit;
    G := MenuItemStr[B]^;
    if MI^.Param^ <> G then
      begin
      DisposeStr(MI^.Param);
      MI^.Param := NewStr(G);
      end;
    MI := MI^.Next;
    end;

  begin
  FLastUndo := Doc.UndoCount;
  FLastRedo := Doc.RedoCount;
  FLastSel := Editor.HasSelection;
  FLastMod := Doc.Modified;
  if (Owner = nil) or (TEditWindow(Owner).MenuBar = nil) then
    Exit;
  BlkC := [cmCopy, cmCut, cmClear, cmBlockWrite, cmFJustify,
     cmCopyBlock, cmMoveBlock,
    cmFRight, cmFLeft, cmFCenter, cmPrintBlock, cmCalcBlock, cmSortBlock,
    cmRevSortBlock, cmIndentBlock, cmUnIndentBlock];
  if FLastSel then
    EnableCommands(BlkC)
  else
    DisableCommands(BlkC);
  if FLastUndo > 0 then
    EnableCommands([cmUndo])
  else
    DisableCommands([cmUndo]);
  if FLastRedo > 0 then
    EnableCommands([cmRedo])
  else
    DisableCommands([cmRedo]);
  if ((ClipBoard <> nil) and (ClipBoard.Count > 0)) or
      ((SystemData.Options and ossUseSysClip <> 0) and GetWinClipSize)
  then
    EnableCommands([cmPaste])
  else
    DisableCommands([cmPaste]);
  if OptMenu <> nil then
    begin
    MI := OptMenu^.Items;
    SetM(EdOpt.BackIndent);
    SetM(EdOpt.AutoBrackets);
    SetM(EdOpt.AutoIndent);
    SetM(EdOpt.AutoWrap);
    SetM(EdOpt.AutoJustify);
    SetM(VertBlock);
    SetM(OptimalFill);
    SetM(EdOpt.HiliteLine);
    SetM(EdOpt.HiliteColumn);
    SetM(EdOpt.HiLite);
    SetM(TabReplace);
    SetM(EdOpt.SmartTab);
    SetM(Wrap);
    end;
  GetCommands(GC);
  TEditWindow(Owner).MenuBar.SetCommands(GC);
  SetCommands(GC);
  end;

procedure TFileEditor.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  if (AState and (sfActive+sfFocused+sfSelected+sfVisible) <> 0) then
    CalcMenu;
  if AState and sfActive <> 0 then
    if GetState(sfActive+sfSelected) then
      begin
      if HScroll <> nil then
        begin
        HScroll.Show;
        HScroll.MakeFirst;
        end;
      if VScroll <> nil then
        VScroll.Show;
      DrawView;
      EnableCommands([cmViewFile]);
      end
    else
      begin
      if HScroll <> nil then
        HScroll.Hide;
      if VScroll <> nil then
        VScroll.Hide;
      DrawView;
      end;
  end;

procedure TFileEditor.Draw;
  begin
  inherited Draw;
  if InfoL <> nil then
    InfoL.Draw;
  if BMrk <> nil then
    BMrk.Draw;
  end;

procedure TFileEditor.ChangeBounds(const R: TRect);
  begin
  inherited ChangeBounds(R);
  end;

function TFileEditor.Valid(Command: Word): Boolean;
  var
    I: Word;
    P: Pointer;
    S: String;
    V: Boolean;
  begin
  Valid := True;
  V := True;
  if Command = cmValid then
    Valid := isValid;
  if SmartPad or ClipBrd then
    begin
    if Modified then
      Message(Self, evCommand, cmSaveText, nil);
    TEditWindow(Owner).ModalEnd := True;
    Exit;
    end;
  if (Command = cmClose) or (Command = cmQuit) then
    begin
    if Modified then
      begin
      S := Cut(EditName, 30);
      P := @S;
      I := MessageBox(GetString(dlQueryModified), @P,
           mfWarning+mfYesNoCancel);
      if I = cmYes then
        Message(Self, evCommand, cmSaveText, nil)
      else if I = cmNo then
        Modified := False;
      V := not ((I = cmCancel) or ((I = cmYes) and Modified));
      end;
    Valid := V;
    if V and not (SmartPad or ClipBrd) and (Owner <> nil) then
      StoreEditInfo(Owner);
    end;
  end;

function TFileEditor.HandleCommand(var Event: TEvent): Boolean;
  begin
  Result := False;
  end;

{ --- the commands of tve that need the dialogs and the windows of DN --- }

function TFileEditor.HostCommand(Sender: TTveSender; Cmd: Integer): Boolean;
  begin
  Result := True;
  case Cmd of
    tcFind:
      StartSearch(False);
    tcReplace:
      StartSearch(True);
    tcFindNext:
      ContinueSearch(False);
    tcFindPrev:
      ContinueSearch(True);
    tcGotoLine:
      GotoLineDialog;
    tcSave:
      MISaveFile(Self);
    tcSaveAs:
      MISaveFileAs(Self);
    tcClose:
      Message(Owner, evCommand, cmClose, nil);
    tcCalculate:
      CalcBlock;
    tcWriteBlock:
      CopyBlockToFile;
    tcReadBlock:
      PasteBlockFromFile;
    tcOpenAtCursor:
      OpenFileAtCursor;
    tcInsertDate:
      InsertDateTime(False);
    tcInsertTime:
      InsertDateTime(True);
    tcDrawMode:
      SwitchDraw;
    tcFormatParagraph:
      FormatParagraph(cmFJustify);
    tcFindInAllCodePages, tcHexSearch:
      Result := False;
    else
      Result := False;
  end {case};
  end;

{ --- the commands of DN: what the menus, the keys of the table of the resource and the macros send --- }

procedure TFileEditor.CloseMe;
  begin
  Message(Owner, evCommand, cmClose, nil);
  end;

procedure TFileEditor.SwitchDraw;
  begin
  DrawMode := (DrawMode+1) mod 3;
  DrawView;
  end;

procedure TFileEditor.FormatParagraph(Mode: Word);
  var
    Al: TTveAlign;
  begin
  case Mode of
    cmFRight, cmLRight:
      Al := alRight;
    cmFLeft, cmLLeft:
      Al := alLeft;
    cmFCenter, cmLCenter:
      Al := alCenter;
    else
      Al := alFull;
  end;
  if (Mode = cmLRight) or (Mode = cmLLeft) or (Mode = cmLCenter) or (Mode = cmLJustify) then
    AlignLines(Editor, Al, EdOpt.LeftSide, EdOpt.RightSide)
  else
    TveBlocks.FormatParagraph(Editor, Al, EdOpt.LeftSide, EdOpt.RightSide, EdOpt.InSide);
  Refresh;
  end;

procedure TFileEditor.CalcBlock;
  var
    R: AnsiString;
  begin
  if TveExtras.CalcBlock(Editor, R) and (R <> '') then
    ClipSet(R, False);
  end;

procedure TFileEditor.InsertDateTime(Time: Boolean);
  begin
  if Editor.TypeText(UiToDoc(GetDateTime(Time))) then
    Refresh;
  end;

procedure TFileEditor.ChangeCase(Command: Word);
  begin
  case Command of
    cmUpcaseBlock:
      TveBlocks.ChangeCase(Editor, caseUpper);
    cmLowcaseBlock:
      TveBlocks.ChangeCase(Editor, caseLower);
    cmCapitalizeBlock:
      TveBlocks.ChangeCase(Editor, caseTitle);
    cmToggleCaseBlock:
      TveBlocks.ChangeCase(Editor, caseToggle);
    cmUpString:
      ChangeCaseLines(Editor, caseUpper);
    cmLowString:
      ChangeCaseLines(Editor, caseLower);
    cmCapString:
      ChangeCaseLines(Editor, caseTitle);
    cmToggleCaseString:
      ChangeCaseLines(Editor, caseToggle);
    cmRusEngConvBlock:
      FixLayout(Editor, False);
    cmRusEngConvString:
      FixLayout(Editor, True);
  end {case};
  Refresh;
  end;

procedure TFileEditor.SwitchCharset;
  const
    Cycle: array[0..3] of LongInt = (65001, 866, 1251, 20866);
  var
    I, Cur: Integer;
    Raw: AnsiString;
    Lost: Integer;
    Inf: TTveFileInfo;
  begin
  Cur := 0;
  for I := 0 to High(Cycle) do
    if Cycle[I] = Doc.Info.Charset then
      Cur := I;
  Inf := Doc.Info;
  { the text as the bytes of the file in the present set, read again in the next one }
  Raw := CharsetFromUtf8(Inf.Charset, Doc.Buffer.AsString, Lost);
  Inf.Charset := Cycle[(Cur+1) mod Length(Cycle)];
  Doc.Info := Inf;
  Doc.BeginGroup;
  try
    Doc.Replace(0, Doc.Buffer.Length, CharsetToUtf8(Inf.Charset, Raw));
  finally
    Doc.EndGroup;
  end;
  Refresh;
  end;

procedure TFileEditor.PlayMacro(N: Integer);
  var
    M: TEditMacros;
    I: Integer;
  begin
  if Macros = nil then
    Exit;
  I := 0;
  while I < Macros.Count do
    begin
    M := Macros.At(I);
    if (M.Name <> nil) and (M.Name^ = Char(N)) then
      begin
      M.Play(Self);
      Exit;
      end;
    Inc(I);
    end;
  end;

procedure TFileEditor.SelectMacro;
  begin
  end;

function TFileEditor.CommandOf(Cmd: Word; var Event: TEvent): Boolean;
  var
    Ch: Integer;

  function Run(Tc: Integer): Boolean;
    begin
    Execute(Tc);
    Result := True;
    end;

  procedure Toggle(var B: Boolean);
    begin
    B := not B;
    ApplyOptions;
    DrawView;
    CalcMenu;
    end;

  begin
  Result := True;
  case Cmd of
    { moving }
    cmMoveUp: Run(tcUp);
    cmMoveDown: Run(tcDown);
    cmMoveLeft: Run(tcLeft);
    cmMoveRight: Run(tcRight);
    cmPgUp: Run(tcPageUp);
    cmPgDn: Run(tcPageDown);
    cmEnd: Run(tcEnd);
    cmWordLeft: Run(tcWordLeft);
    cmWordRight: Run(tcWordRight);
    cmCtrlHome: Run(tcWindowTop);
    cmCtrlEnd: Run(tcWindowBottom);
    cmScrollUp: Run(tcScrollUp);
    cmScrollDn: Run(tcScrollDown);
    { editing }
    cmEnter: Run(tcNewLine);
    cmTab: Run(tcTab);
    cmDelChar: Run(tcDelete);
    cmDelBackChar: Run(tcBackspace);
    cmDeleteLine: Run(tcDeleteLine);
    cmDeltoEOLN: Run(tcDeleteToEol);
    cmDelWordLeft: Run(tcDeleteWordLeft);
    cmDelWordRight: Run(tcDeleteWordRight);
    cmInsLine: Run(tcBreakLineStay);
    cmDuplicateLine: Run(tcDuplicateLine);
    cmSwitchIns: Run(tcToggleInsert);
    cmInsertOn:
      begin
      InsertMode := True;
      DrawView;
      end;
    cmInsertOff:
      begin
      InsertMode := False;
      DrawView;
      end;
    cmUndo: Run(tcUndo);
    cmRedo: Run(tcRedo);
    cmCut: Run(tcCut);
    cmCopy: Run(tcCopy);
    cmPaste: Run(tcPaste);
    cmClear: Run(tcDeleteBlock);
    { blocks }
    cmSelectAll: Run(tcSelectAll);
    cmMarkWord: Run(tcSelectWord);
    cmMarkLine: Run(tcSelectLine);
    cmBlockStart: Run(tcBlockBegin);
    cmBlockEnd: Run(tcBlockEnd);
    cmHideBlock: Run(tcHideBlock);
    cmMoveBlockStart: Run(tcGotoBlockBegin);
    cmMoveBlockEnd: Run(tcGotoBlockEnd);
    cmCopyBlock: Run(tcCopyBlockHere);
    cmMoveBlock: Run(tcMoveBlockHere);
    cmIndentBlock: Run(tcIndent);
    cmUnIndentBlock: Run(tcUnindent);
    cmSortBlock: Run(tcSortAsc);
    cmRevSortBlock: Run(tcSortDesc);
    cmCalcBlock: CalcBlock;
    cmBlockRead: PasteBlockFromFile;
    cmBlockWrite: CopyBlockToFile;
    cmSwitchBlock:
      begin
      VertBlock := not VertBlock;
      DrawView;
      end;
    cmFJustify, cmFRight, cmFLeft, cmFCenter, cmLJustify, cmLRight, cmLLeft, cmLCenter:
      FormatParagraph(Cmd);
    cmUpcaseBlock, cmLowcaseBlock, cmCapitalizeBlock, cmToggleCaseBlock, cmUpString, cmLowString, cmCapString, cmToggleCaseString,
    cmRusEngConvBlock, cmRusEngConvString:
      ChangeCase(Cmd);
    cmBracketPair: Run(tcMatchBracket);
    { the markers }
    cmPlaceMarker1..cmPlaceMarker1+8: Run(tcSetMark0+(Cmd-cmPlaceMarker1)+1);
    cmGoToMarker1..cmGoToMarker1+8: Run(tcGotoMark0+(Cmd-cmGoToMarker1)+1);
    { search and places }
    cmStartSearch: StartSearch(False);
    cmReplace: StartSearch(True);
    cmContSearch: ContinueSearch(False);
    cmReverseSearch: ContinueSearch(True);
    cmGotoLineNumber: GotoLineDialog;
    cmSetMargins: SetMarginsDialog;
    cmOpenFileAtCursor: OpenFileAtCursor;
    { files }
    cmSaveText: MISaveFile(Self);
    cmSaveTextAs: MISaveFileAs(Self);
    cmLoadText: MIOpenFile(Self);
    cmPrintFileEd: PrintText(False);
    cmPrintBlock: PrintText(True);
    cmGetName:
      begin
      Event.InfoPtr := @EditName;
      Result := False;
      end;
    { text }
    cmInsertDate: InsertDateTime(False);
    cmInsertTime: InsertDateTime(True);
    cmSpecChar, cmASCIITable: ASCIITable;
    cmSwitchDrawMode: SwitchDraw;
    cmSwitchKeyMapping: SwitchCharset;
    cmSyncClipOut: SyncClipOut;
    cmSyncClipIn: SyncClipIn;
    cmWindowsPaste:
      begin
      SyncClipOut;
      Execute(tcPaste);
      end;
    cmWindowsCopy:
      begin
      Execute(tcCopy);
      SyncClipIn;
      end;
    cmEditCrLfMode: EolMode := cfCRLF;
    cmEditLfMode: EolMode := cfLF;
    cmEditCrMode: EolMode := cfCR;
    cmPlayMacro:
      begin
      Ch := Event.InfoLong;
      PlayMacro(Ch);
      end;
    cmSelectMacro: SelectMacro;
    { the options }
    cmSwitchHiLine:
      Toggle(EdOpt.HiliteLine);
    cmSwitchHiColumn:
      Toggle(EdOpt.HiliteColumn);
    cmSwitchWrap:
      Toggle(EdOpt.AutoJustify);
    cmSwitchFill:
      Toggle(OptimalFill);
    cmSwitchTabReplace:
      Toggle(TabReplace);
    cmSwitchBack:
      Toggle(EdOpt.BackIndent);
    cmSwitchIndent:
      Toggle(EdOpt.AutoIndent);
    cmIndentOn:
      EdOpt.AutoIndent := True;
    cmIndentOff:
      EdOpt.AutoIndent := False;
    cmSwitchSmartTab:
      Toggle(EdOpt.SmartTab);
    cmSwitchSoftWrap:
      begin
      Wrap := not Wrap;
      CalcMenu;
      end;
    cmSwitchHighLight:
      Toggle(EdOpt.HiLite);
    cmSwitchBrackets:
      Toggle(EdOpt.AutoBrackets);
    cmSwitchSave:
      Toggle(EdOpt.AutoWrap);
    cmMainMenu: Result := False;
    cmClose: Result := False;
    else
      Result := False;
  end {case};
  end;

{ --- search and replace --- }

function SearchOptionsOf(Replace: Boolean): TTveSearchOptions;
  var
    O: Word;
  begin
  Result := TveDefaultSearch;
  O := SearchData.Options;
  Result.Pattern := UiToDoc(SearchData.Line);
  Result.CaseSensitive := O and efoCaseSens <> 0;
  Result.WholeWord := O and efoWholeWords <> 0;
  Result.UseRegex := O and efoRegExp <> 0;
  Result.AllCodePages := (O and efoAllCP <> 0) and not Replace;
  Result.Backward := SearchData.Dir and 1 <> 0;
  Result.ScopeFrom := 0;
  Result.ScopeTo := -1;
  end;

procedure TFileEditor.StartSearch(Replace: Boolean);
  const
    SwapBits = $14;      { the bits of "ask" and "all code pages": the dialog of the search has them the other way }
  var
    Y: Word;
    S: String;
    Ln, X, E: Integer;
    Txt: AnsiString;
    Opt: TTveSearchOptions;
    A, B: Int64;

  procedure Mix2And3(var M: Word);
    begin
    case M and SwapBits of
      0, SwapBits:
      else
        M := M xor SwapBits;
    end {case};
    end;

  begin
  { the word at the cursor is the first thing to look for }
  S := '';
  Txt := Doc.Buffer.LineText(Editor.Line);
  X := LayoutCellToIndex(Txt, Editor.Cell, Editor.Opt.TabSize);
  if (X >= 1) and (X <= Length(Txt)) and not (Txt[X] in BreakChars) then
    begin
    E := X;
    while (X > 1) and not (Txt[X-1] in BreakChars) do
      Dec(X);
    while (E <= Length(Txt)) and not (Txt[E] in BreakChars) do
      Inc(E);
    S := DocToUi(Copy(Txt, X, E-X));
    end;
  SearchData.Line := S;
  if AutoScopeDetect then
    SearchData.Scope := Word(Editor.HasSelection);
  if not Replace then
    SearchData.What := #0
  else
    SetLength(SearchData.What, 0);
  if Replace then
    Y := ExecResource(dlgEditorReplace, SearchData)
  else
    begin
    Mix2And3(SearchData.Options);
    Y := ExecResource(dlgEditorFind, SearchData);
    Mix2And3(SearchData.Options);
    end;
  if Y = cmCancel then
    Exit;
  ReplaceAllFlag := Replace and (Y = cmYes);
  Opt := SearchOptionsOf(Replace);
  if (SearchData.Scope and 1 <> 0) and Editor.SelectionRange(A, B) then
    begin
    Opt.ScopeFrom := A;
    Opt.ScopeTo := B;
    end;
  SearchOptions := Opt;
  Editor.ClearSelection;
  if SearchData.Origin = 0 then
    begin
    if Opt.ScopeTo >= 0 then
      Editor.GotoOffset(Opt.ScopeFrom)
    else if Opt.Backward then
      Editor.GotoOffset(Doc.Buffer.Length)
    else
      Editor.GotoOffset(0);
    end;
  if Replace then
    DoReplace(Opt)
  else
    FindAndShow(False);
  end;

procedure TFileEditor.FindAndShow(Reverse: Boolean);
  var
    St: TTveFindStatus;
  begin
  St := FindNext(Reverse);
  case St of
    fsFound:
      Refresh;
    fsBadPattern:
      MessageBox(GetString(dlDBViewSearchNot), nil, mfError+mfOKButton);
    else
      MessageBox(GetString(dlDBViewSearchNot), nil, mfInformation+mfOKButton);
  end {case};
  end;

procedure TFileEditor.ContinueSearch(Reverse: Boolean);
  begin
  if SearchData.Line = '' then
    begin
    StartSearch(False);
    Exit;
    end;
  FindAndShow(Reverse);
  end;

procedure TFileEditor.DoReplace(const Opt: TTveSearchOptions);
  var
    N, J: Integer;
    Prompt, All: Boolean;
    Repl: AnsiString;
    A, B: Int64;
    O: TTveSearchOptions;
    T: TRect;
    Ask: Boolean;
  begin
  Repl := UiToDoc(SearchData.What);
  Prompt := SearchData.Options and efoReplacePrompt <> 0;
  All := ReplaceAllFlag;
  N := 0;
  if All and not Prompt then
    begin
    N := inherited ReplaceAll(Repl);
    if N < 0 then
      MessageBox(GetString(dlDBViewSearchNot), nil, mfError+mfOKButton)
    else if N = 0 then
      MessageBox(GetString(dlDBViewSearchNot), nil, mfInformation+mfOKButton)
    else
      MessageBox(GetString(dlReplacesMade), @N, mfOKButton+mfInformation);
    Refresh;
    Exit;
    end;
  O := Opt;
  repeat
    SearchOptions := O;
    if FindNext(False) <> fsFound then
      Break;
    Refresh;
    Ask := Prompt and not All;
    J := cmYes;
    if Ask then
      begin
      T.Assign(0, 0, 40, 8);
      if Editor.Line-TopLine < Size.Y div 2 then
        T.A.Y := Desktop.Size.Y-18
      else
        T.A.Y := (Desktop.Size.Y-18) div 2;
      T.B.Y := T.A.Y+8;
      J := MessageBoxRect(T, GetString(dlQueryReplace), nil,
          mfQuery+mfYesButton+mfAllButton+mfNoButton+mfCancelButton);
      if J = cmOK then
        begin
        J := cmYes;
        All := True;
        end;
      end;
    if J = cmCancel then
      Break;
    if J = cmYes then
      begin
      { the match is the selection: go to its beginning and replace what is found there }
      if Editor.SelectionRange(A, B) then
        begin
        Editor.ClearSelection;
        Editor.GotoOffset(A);
        SearchOptions := O;
        if ReplaceNext(Repl) = 0 then
          Break;
        Inc(N);
        if O.ScopeTo >= 0 then
          Inc(O.ScopeTo, Length(Repl)-(B-A));
        end
      else
        Break;
      end;
    if (Opt.ScopeTo < 0) and O.Backward then
      Break;
  until False;
  if N > 0 then
    MessageBox(GetString(dlReplacesMade), @N, mfOKButton+mfInformation);
  Refresh;
  end;

procedure TFileEditor.GotoLineDialog;
  const
    S: String = '';
  var
    I: LongInt;
    J: Integer;
  begin
  if ExecResource(dlgGotoLine, S) <> cmOK then
    Exit;
  Val(S, I, J);
  if (J = 0) and (I > 0) then
    GotoXY(Cursor.X, I-1);
  end;

procedure TFileEditor.SetMarginsDialog;
  var
    Data: record
      S1, S2, S3: String[6];
      end;
    I: LongInt;
    J: Integer;
  begin
  Data.S1 := ItoS(EdOpt.LeftSide);
  Data.S2 := ItoS(EdOpt.RightSide);
  Data.S3 := ItoS(EdOpt.InSide);
  if ExecResource(dlgEditorFormat, Data) = cmCancel then
    Exit;
  Val(Data.S1, I, J);
  if J = 0 then
    EdOpt.LeftSide := I;
  Val(Data.S2, I, J);
  if J = 0 then
    EdOpt.RightSide := I;
  Val(Data.S3, I, J);
  if J = 0 then
    EdOpt.InSide := I;
  if (EdOpt.LeftSide > EdOpt.RightSide) or (EdOpt.LeftSide < 0) then
    EdOpt.LeftSide := 0;
  if EdOpt.RightSide < 2 then
    EdOpt.RightSide := 2;
  if (EdOpt.InSide >= EdOpt.RightSide) or (EdOpt.InSide < 0) then
    EdOpt.InSide := EdOpt.LeftSide;
  ApplyOptions;
  end;

{ --- blocks and files --- }

procedure TFileEditor.CopyBlockToFile;
  var
    Name: String;
  begin
  if not Editor.HasSelection then
    Exit;
  Name := GetFileNameDialog(x_x, GetString(dlCopyTo), GetString(dlFileName), fdOKButton+fdHelpButton, hsEditSave);
  if Name = '' then
    Exit;
  if not WriteBlock(Editor, OsFileName(lFExpand(Name))) then
    MessFileNotOpen(Name, 0);
  end;

procedure TFileEditor.PasteBlockFromFile;
  var
    Name: String;
  begin
  Name := GetFileNameDialog(x_x, GetString(dlPasteFromTitle), GetString(dlPasteFromLabel), fdOpenButton+fdHelpButton, hsEditPasteFrom);
  if Name = '' then
    Exit;
  if ReadBlock(Editor, OsFileName(lFExpand(Name))) then
    Refresh
  else
    MessFileNotOpen(Name, 0);
  end;

procedure TFileEditor.PrintText(Block: Boolean);
  var
    M: String;
    LL: array[1..3] of PtrInt;
    T: AnsiString;
    Col: Boolean;
    F: Text;
    FName: String;
    I: Integer;
    SR: lSearchRec;
    P: String;
  begin
  if Block then
    begin
    if not Editor.HasSelection then
      Exit;
    T := Editor.SelectionText(Col);
    end
  else
    T := GetText;
  LL[1] := 1;
  for I := 1 to Length(T) do
    if T[I] = #10 then
      Inc(LL[1]);
  FormatStr(M, GetString(dlED_PrintQuery), LL);
  if MessageBox(M, nil, mfYesNoConfirm) <> cmYes then
    Exit;
  for I := 1 to 1000 do
    begin
    FName := SwpDir+'$DN'+SStr(I, 4, '0')+'$.PRN';
    ClrIO;
    lFindFirst(FName, Archive, SR);
    if DOSError <> 0 then
      Break;
    lFindClose(SR);
    end;
  lFindClose(SR);
  Assign(F, FName);
  {$I-}
  Rewrite(F);
  {$I+}
  if IOResult <> 0 then
    begin
    P := FName;
    Msg(erCantCreateFile, @P, mfError+mfOKButton);
    Exit;
    end;
  I := 1;
  M := '';
  while I <= Length(T) do
    begin
    if T[I] = #10 then
      begin
      WriteLn(F, DocToUi(M));
      M := '';
      end
    else if Length(M) < 250 then
      M := M+T[I]
    else
      begin
      Write(F, DocToUi(M));
      M := T[I];
      end;
    Inc(I);
    end;
  Write(F, DocToUi(M));
  if not Block then
    Write(F, #12);
  Close(F);
  Message(Application, evCommand, cmFilePrint, @FName);
  end;

procedure TFileEditor.OpenFileAtCursor;
  var
    Line, Res, S: String;
    Info: TWhileView;
    R: TRect;
    P, Min1, Min2, Min3, Min4, Max1, Max2, Max3, Max4: Integer;
    Q: Pointer;
    Txt: AnsiString;
  const
    IllegalCharSetDos =
      [';', ',', '=', '+', '<', '>', '|', '"', '[', ']', ' ', '*', '?'];
    Break2 = IllegalCharSet+['*', '?'];
    Break1 = Break2+[PathSep, '/'];
    Break4 = IllegalCharSetDos;
    Break3 = Break4+[PathSep, '/'];

  type
    TSetChar = set of Char;

  procedure Chk(S: String);
    begin
    DelLeft(S);
    DelRight(S);
    if S = '' then
      Exit;
    if Abort then
      Exit;
    if Res = '' then
      Res := FindFileWithSPF(S, Info);
    if Abort then
      Exit;
    if Res = '' then
      Res := FindFileWithSPF(GetName(S), Info);
    if Abort then
      Exit;
    if Res = '' then
      Res := FindFileWithSPF(GetSName(S), Info);
    if Abort then
      Exit;
    if Res = '' then
      Res := FindFileWithSPF(GetSName(S)+GetExt(EditName), Info);
    end;

  function GetMin(BreakChar: TSetChar): Integer;
    var
      I: Integer;
    begin
    for I := P downto 1 do
      if Line[I] in BreakChar then
        begin
        Result := I+1;
        Exit;
        end;
    Result := 1;
    end;

  function GetMax(BreakChar: TSetChar): Integer;
    var
      I: Integer;
    begin
    for I := P+1 to Length(Line) do
      if Line[I] in BreakChar then
        begin
        Result := I;
        Exit;
        end;
    Result := Length(Line)+1;
    end;

  begin
  Txt := Doc.Buffer.LineText(Editor.Line);
  Line := DocToUi(Txt);
  if Line = '' then
    Exit;
  Res := '';
  R.Assign(0, 0, 20, 7);
  Info := TWhileView.Create(R);
  Info.Write(1, Copy(GetString(dlPleaseStandBy), 4, 255));
  Desktop.Insert(Info);
  Abort := False;
  P := LayoutCellToIndex(Txt, Editor.Cell, Editor.Opt.TabSize);
  if P > Length(Line) then
    P := Length(Line);
  Min1 := GetMin(Break1);
  Min2 := GetMin(Break2);
  Min3 := GetMin(Break3);
  Min4 := GetMin(Break4);
  Max1 := GetMax(Break1);
  Max2 := GetMax(Break2);
  Max3 := GetMax(Break3);
  Max4 := GetMax(Break4);
  DispatchEvents(Info, Abort);
  if not Abort then
    begin
    Chk(Copy(Line, Min1, Max1-Min1));
    if Res = '' then
      Chk(Copy(Line, Min1, Max2-Min1));
    if Res = '' then
      Chk(Copy(Line, Min2, Max1-Min2));
    if Res = '' then
      Chk(Copy(Line, Min2, Max2-Min2));
    if Res = '' then
      Chk(Copy(Line, Min3, Max3-Min3));
    if Res = '' then
      Chk(Copy(Line, Min3, Max4-Min3));
    if Res = '' then
      Chk(Copy(Line, Min4, Max3-Min4));
    if Res = '' then
      Chk(Copy(Line, Min4, Max4-Min4));
    end;
  if not Abort then
    begin
    if Res = '' then
      begin
      Info.Hide;
      S := Copy(Line, Min4, Max4-Min4);
      if PosChar('.', S) = 0 then
        S := S+GetExt(EditName);
      Res := Cut(S, 20);
      Q := @Res;
      case ExecResource(dlgSrchFailed, Q) of
        cmYes:
          TDNApplication(Application).EditFile(True, ConfigDir+'dn.spf');
        cmNo:
          TDNApplication(Application).EditFile(True, S);
      end;
      end
    else
      TDNApplication(Application).EditFile(True, Res);
    end;
  Info.Free;
  Abort := False;
  end;

{ --- the keys: the table of the resource of DN (EDITOR COMMANDS) --- }

procedure TFileEditor.TypeAt(const S: AnsiString);
  begin
  if S = '' then
    Exit;
  if Editor.TypeText(S) then
    Refresh;
  end;

function TFileEditor.KeyDown(var Event: TEvent): Boolean;
  var
    I: Integer;
    Key: LongInt;
    EvStr: array[1..2] of Char;
    Found: Boolean;
    T: AnsiString;
    N, Sel: Integer;
  begin
  Result := False;
  if fASCIITable then
    begin
    { a character of the table of the characters: the byte of the code page of DN }
    TypeAt(UiToDocByte(Byte(Event.CharCode)));
    ClearEvent(Event);
    Exit(True);
    end;
  Key := DNKeyCode(Event);
  case Key of
    kbCtrlAltShift1..kbCtrlAltShift9:
      begin
      N := (Key shr 8)-(kbCtrlAltShift1 shr 8);
      Message(Self, evCommand, cmGoToMarker1+N, nil);
      ClearEvent(Event);
      Exit(True);
      end;
    kbCtrlUp, kbCtrlShiftUp:
      begin
      ScrollLines(-1);
      if Cursor.Y-TopLine >= Size.Y then
        Execute(tcUp);
      ClearEvent(Event);
      Exit(True);
      end;
    kbCtrlDown, kbCtrlShiftDown:
      begin
      ScrollLines(1);
      if Cursor.Y < TopLine then
        Execute(tcDown);
      ClearEvent(Event);
      Exit(True);
      end;
  end {case};
  EvStr[1] := #0;
  EvStr[2] := #0;
  for I := 1 to MaxCommands do
    with EditCommands[I] do
      begin
      if CC1[1] = Char(Event.CharCode) then
        begin
        EvStr[1] := CC1[1];
        if CC1[2] <> #0 then
          begin
          KeyEvent(Event);
          XlatPlain(Event);
          EvStr[2] := Char(Event.CharCode);
          end;
        Break;
        end;
      if CC2[1] = Char(Event.CharCode) then
        begin
        EvStr[1] := CC2[1];
        if CC2[2] <> #0 then
          begin
          KeyEvent(Event);
          XlatPlain(Event);
          EvStr[2] := Char(Event.CharCode);
          end;
        Break;
        end;
      end;
  if EvStr[2] in ['A'..']', 'a'..'z'] then
    EvStr[2] := Char(Ord(UpCase(EvStr[2]))-64);
  Found := False;
  for I := 1 to MaxCommands do
    with EditCommands[I] do
      if ((C1 = Word(Key)) or (C2 = Word(Key))) and (EvStr[2] = #0) or
          ((EvStr[1] <> #0) or (EvStr[2] <> #0)) and
          ((CC1[1] = EvStr[1]) and (CC1[2] = EvStr[2]) or (CC2[1] = EvStr[1]) and (CC2[2] = EvStr[2]))
      then
        begin
        Found := True;
        Break;
        end;
  if Found then
    begin
    { the keys with Shift move and select: the command of the table is the same, the selecting one is run here (the command does not know the key) }
    Sel := 0;
    if ((Key shr 16) and 3 <> 0) or (Event.ControlKeyState and kbShift <> 0) then
      case EditCommands[I].C of
        cmMoveUp: Sel := tcSelUp;
        cmMoveDown: Sel := tcSelDown;
        cmMoveLeft: Sel := tcSelLeft;
        cmMoveRight: Sel := tcSelRight;
        cmPgUp: Sel := tcSelPageUp;
        cmPgDn: Sel := tcSelPageDown;
        cmEnd: Sel := tcSelEnd;
        cmWordLeft: Sel := tcSelWordLeft;
        cmWordRight: Sel := tcSelWordRight;
        cmCtrlHome: Sel := tcSelTextStart;
        cmCtrlEnd: Sel := tcSelTextEnd;
      end;
    ClearEvent(Event);
    if Sel <> 0 then
      Execute(Sel)
    else
      MessageL(Owner, evCommand, EditCommands[I].C, Byte(EvStr[2]));
    Exit(True);
    end;
  case Key of
    kbHome:
      begin
      ClearEvent(Event);
      Execute(tcHome);
      Exit(True);
      end;
    kbShiftHome:
      begin
      ClearEvent(Event);
      Execute(tcSelHome);
      Exit(True);
      end;
  end;
  { a character to type: its text, else the character of the code page of DN }
  if (Event.TextLength > 0) and (Event.ControlKeyState and (kbCtrlShift or kbAltShift) = 0) then
    begin
    T := EventText(Event);
    if (T <> '') and (Byte(T[1]) >= 32) then
      begin
      TypeAt(UiToDoc(T));
      ClearEvent(Event);
      Exit(True);
      end;
    end
  else if (Char(Event.CharCode) > #31) and (Key <> kbShiftGrayPlus) and (Key <> kbShiftGrayMinus) then
    begin
    TypeAt(UiToDocByte(Byte(Event.CharCode)));
    ClearEvent(Event);
    Exit(True);
    end;
  end;

procedure TFileEditor.HandleEvent(var Event: TEvent);
  begin
  case Event.What of
    evCommand:
      begin
      if HandleCommand(Event) then
        begin
        ClearEvent(Event);
        Exit;
        end;
      if CommandOf(Event.Command, Event) then
        begin
        ClearEvent(Event);
        Exit;
        end;
      end;
    evKeyDown:
      if KeyDown(Event) then
        Exit;
    evBroadcast:
      if Event.Command = cmFindEdit then
        if PString(Event.InfoPtr)^ = EditName then
          if Owner <> nil then
            begin
            Owner.Select;
            ClearEvent(Event);
            Exit;
            end;
  end {case};
  inherited HandleEvent(Event);
  end;

{ --- the place of a file in the history: what is kept when an editor is closed and given back when the file is opened again --- }

procedure TFileEditor.FillRecord(P: Pointer);
  var
    R: PEditRecord absolute P;
    M: TRect;
  begin
  M := Mark;
  with R^ do
    begin
    fPos := Delta;
    fDelta := Cursor;
    fMarks := GetMarks;
    fBlockStart := M.A;
    fBlockEnd := M.B;
    fBlockVisible := BlockVisible;
    fVerticalBlock := VertBlock;
    fHighlight := EdOpt.HiLite;
    fHiliteColumn := EdOpt.HiliteColumn;
    fHiliteLine := EdOpt.HiliteLine;
    fAutoIndent := EdOpt.AutoIndent;
    fAutoJustify := EdOpt.AutoJustify;
    fAutoBrackets := EdOpt.AutoBrackets;
    fLeftSide := EdOpt.LeftSide;
    fRightSide := EdOpt.RightSide;
    fInSide := EdOpt.InSide;
    fInsMode := InsertMode;
    fKeyMap := CharsetKeyMap;
    fBackIndent := EdOpt.BackIndent;
    fAutoWrap := EdOpt.AutoWrap;
    fOptimalFill := OptimalFill;
    fTabReplace := TabReplace;
    fSmartTab := EdOpt.SmartTab;
    end;
  end;

procedure TFileEditor.ApplyRecord(P: Pointer; WithPlace: Boolean);
  var
    R: PEditRecord absolute P;
    M: TRect;
  begin
  with R^ do
    begin
    if WithPlace then
      begin
      M.A := fBlockStart;
      M.B := fBlockEnd;
      if fBlockVisible then
        Mark := M;
      GotoXY(fDelta.X, fDelta.Y);
      ScrollTo(fPos.X, fPos.Y);
      end;
    SetMarks(fMarks);
    VertBlock := fVerticalBlock;
    EdOpt.HiLite := fHighlight;
    EdOpt.HiliteColumn := fHiliteColumn;
    EdOpt.HiliteLine := fHiliteLine;
    EdOpt.AutoIndent := fAutoIndent;
    EdOpt.AutoJustify := fAutoJustify;
    EdOpt.AutoBrackets := fAutoBrackets;
    EdOpt.LeftSide := fLeftSide;
    EdOpt.RightSide := fRightSide;
    EdOpt.InSide := fInSide;
    InsertMode := fInsMode;
    EdOpt.BackIndent := fBackIndent;
    EdOpt.AutoWrap := fAutoWrap;
    OptimalFill := fOptimalFill;
    TabReplace := fTabReplace;
    EdOpt.SmartTab := fSmartTab;
    end;
  ApplyOptions;
  end;

{ --- the windows of the editor --- }

procedure OpenEditor;
  var
    R: TRect;
    S: String;
  begin
  S := GetFileNameDialog(x_x, GetString(dlED_OpenFile),
      GetString(dlOpenFileName),
      fdOpenButton+fdHelpButton, hsEditOpen);
  if S = '' then
    Exit;
  Desktop.GetExtent(R);
  Application.InsertWindow(TEditWindow.Create(R, S));
  end;

procedure OpenSmartpad;
  var
    R: TRect;
    PV: Pointer;

  procedure InsertInfo;
    var
      Str, LineCh, LastLn, PrevLn: AnsiString;
      I, N: Integer;
      Count: LongInt;

    function IsStamp(const S: AnsiString): Boolean;
      begin
      Result := (Copy(S, 1, 6*Length(LineCh)) = Copy(Str, 1, 6*Length(LineCh))) and (Pos('< ', S) > 0);
      end;

    begin
    with SmartWindow.Intern do
      begin
      if SPInsertDate then
        begin
        LineCh := UiToDocByte(SPLineChar);
        if (LineCh = '') or (LineCh = #0) then
          LineCh := '-';
        Str := '';
        for I := 1 to 6 do
          Str := Str+LineCh;
        Str := Str+UiToDoc('< '+GetDateTime(False)+' '+GetDateTime(True)+' >');
        for I := 1 to 36 do
          Str := Str+LineCh;
        Count := LineCount;
        { a stamp that nothing was written after is replaced by the new one }
        if Count >= 2 then
          begin
          LastLn := GetLineText(Count-1);
          PrevLn := GetLineText(Count-2);
          if (LastLn = '') and IsStamp(PrevLn) then
            begin
            Doc.Delete(Doc.Buffer.LineStart(Count-2), Doc.Buffer.Length-Doc.Buffer.LineStart(Count-2));
            Count := LineCount;
            end;
          end;
        Editor.GotoOffset(Doc.Buffer.Length);
        if GetLineText(LineCount-1) <> '' then
          Editor.TypeText(#10);
        Editor.TypeText(Str+#10);
        end
      else
        begin
        Editor.GotoOffset(Doc.Buffer.Length);
        Editor.TypeText(#10);
        end;
      Refresh;
      SmartWindow.Redraw;
      end;
    end;

  var
    PS: PString;
    V: TFileEditor;
    I: Integer;
    P: PEditRecord;
  begin
  SmartWindow := SmartWindowPtr^;
  if (SmartWindow <> nil) and SmartWindow.GetState(sfModal) then
    Exit;
  PV := Application.TopView;
  Desktop.GetExtent(R);
  R.Grow(-2, -2);
  if SmartWindow <> nil then
    begin
    InsertInfo;
    if PV <> Application then
      begin
      Desktop.Delete(SmartWindow);
      Desktop.ExecView(SmartWindow);
      Desktop.InsertBefore(SmartWindow, Desktop.Last);
      Desktop.Current := PV;
      end
    else
      SmartWindow.Select;
    Exit;
    end;
  SmartWindow := TEditWindow.Create(R, 'SmartPad');
  V := SmartWindow.Intern;
  FreeStr := V.EditName;
  System.Insert(' ', FreeStr, 1);
  UpStr(FreeStr);
  PS := @FreeStr;
  if (InterfaceData.Options and ouiTrackEditors <> 0) and (EditHistory <> nil) then
    I := EditHistory.IndexOf(@PS)
  else
    I := -1;
  if I >= 0 then
    begin
    P := EditHistory.At(I);
    R.Assign(P^.fOrigin.X, P^.fOrigin.Y, P^.fOrigin.X+P^.fSize.X, P^.fOrigin.Y+P^.fSize.Y);
    AdjustToDesktopSize(R, P^.fDeskSize);
    SmartWindow.Locate(R);
    V.ApplyRecord(P, True);
    end
  else
    StoreEditInfo(SmartWindow);
  InsertInfo;
  if PV <> Application then
    begin
    Desktop.ExecView(SmartWindow);
    SmartWindow.Free;
    SmartWindow := nil;
    end
  else
    Desktop.Insert(SmartWindow);
  end;

procedure OpenClipBoard;
  var
    R: TRect;
    PV: Pointer;
  begin
  ClipboardWindow := ClipboardWindowPtr^;
  if SystemData.Options and ossUseSysClip <> 0 then
    SyncClipOut;
  if (ClipboardWindow <> nil) and ClipboardWindow.GetState(sfModal) then
    Exit;
  PV := Application.TopView;
  Desktop.GetExtent(R);
  if ClipboardWindow <> nil then
    begin
    if PV <> Application then
      begin
      Desktop.Delete(ClipboardWindow);
      Desktop.ExecView(ClipboardWindow);
      Desktop.InsertBefore(ClipboardWindow, Desktop.Last);
      Desktop.Current := TView(PV);
      end
    else
      ClipboardWindow.Select;
    Exit;
    end;
  ClipboardWindow := TEditWindow.Create(R, 'Clipboard');
  if PV <> Application then
    begin
    Desktop.ExecView(ClipboardWindow);
    ClipboardWindow.Free;
    ClipboardWindow := nil;
    end
  else
    Desktop.Insert(ClipboardWindow);
  end;

end.
