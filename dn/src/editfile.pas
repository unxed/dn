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

{ The files of the editor of DN: reading, writing, locking, and the streams of a window of the desktop.

  The reading and the writing are those of tve (TveFile): the character set of the file is found (UTF-8, UTF-16 with a mark, or a code
  page chosen among DOS, Windows and KOI8-R), the line ends are kept as they were, and a file is written through a temporary file and a rename. }
{$I STDEFINE.INC}
unit editfile;

interface

uses
  Defines, Streams, editcore, editwin
  ;

procedure MISaveFileAs(AED: TFileEditor);
procedure MISaveFile(AED: TFileEditor);
procedure MIOpenFile(AED: TFileEditor);
procedure MILoadFile(AED: TFileEditor; Name: String);
procedure MILockFile(AED: TFileEditor);
procedure MIUnLockFile(AED: TFileEditor);

procedure MIStore(AED: TFileEditor; S: TStream);
procedure MILoad(AED: TFileEditor; S: TStream);
procedure MIAwaken(AED: TFileEditor);

const
  SmartWindow: TEditWindow = nil;
  ClipboardWindow: TEditWindow = nil;
  SmartWindowPtr: ^TEditWindow = @SmartWindow;
  ClipboardWindowPtr: ^TEditWindow = @ClipboardWindow;

implementation
uses
  DNStdDlg, basics, mainapp, Commands, Lfn, fileutil, strutil, Views,
  Collect, WinClp, Dos, Messages, Startup, DnIni, iniengine, CopyIni, DNUtf8,
  keymap, Macro, timeutil, Drivers, fsinfo, dirwatch, fileerrors, highlite,
  TveDoc, TveFile, TveBuf, TvCharset
  ;

{ --- how the files are read and written --- }

function FileOptions(AED: TFileEditor): TTveFileOptions;
  var
    Km: TKeyMap;
    Tag: String;
  begin
  Result := TveDefaultOptions;
  SetLength(Result.Candidates, 3);
  Result.Candidates[0] := 866;
  Result.Candidates[1] := 1251;
  Result.Candidates[2] := 20866;
  Km := ProcessDefCodepage(DefCodePage);
  Result.Detect := Km = kmNone;
  Result.DefaultCharset := 866;
  if Km <> kmNone then
    begin
    Tag := KeyMapDescr[Km].Tag;
    if Tag = 'WIN' then
      Result.DefaultCharset := 1251
    else if Tag = 'KOI' then
      Result.DefaultCharset := 20866;
    end;
  case EditorDefaults.NewLine of
    1: Result.DefaultEol := eolCR;
    2: Result.DefaultEol := eolLF;
    else
      Result.DefaultEol := eolCRLF;
  end;
  Result.StripTrailing := True;
  Result.Backup := EditorDefaults.EdOpt and ebfCBF <> 0;
  Result.BackupExt := '.bak';
  end;

{ The blanks at the start of a line as tabs where a tab stop is reached (the option "optimal fill"). }
function TabifyLeading(const T: AnsiString; TabSize: Integer): AnsiString;
  var
    P, Q, Sp, Tabs: Integer;
    L: AnsiString;
  begin
  Result := '';
  P := 1;
  while P <= Length(T)+1 do
    begin
    Q := P;
    while (Q <= Length(T)) and (T[Q] <> #10) do
      Inc(Q);
    L := Copy(T, P, Q-P);
    Sp := 0;
    while (Sp < Length(L)) and (L[Sp+1] = ' ') do
      Inc(Sp);
    Tabs := Sp div TabSize;
    if Tabs > 0 then
      L := StringOfChar(#9, Tabs)+Copy(L, Tabs*TabSize+1, Length(L));
    Result := Result+L;
    if Q <= Length(T) then
      Result := Result+#10;
    P := Q+1;
    end;
  end;

{ The document to a file; False and a message if it cannot be done. }
function WriteDoc(AED: TFileEditor; const Name: String): Boolean;
  var
    Info: TTveFileInfo;
    Lost: Integer;
    Err: AnsiString;
    Text: AnsiString;
    Opt: TTveFileOptions;
  begin
  with AED do
    begin
    Opt := FileOptions(AED);
    Info := Doc.Info;
    Info.Eol := Doc.Eol;
    Text := Doc.Buffer.AsString;
    if OptimalFill then
      Text := TabifyLeading(Text, Editor.Opt.TabSize);
    Result := TveWriteFile(OsFileName(Name), Text, Info, Opt, Lost, Err);
    if not Result then
      begin
      CantWrite(Name);
      Exit;
      end;
    if Lost > 0 then
      MessageBox(^C'Some characters are not in this character set: they are saved as "?"', nil, mfWarning+mfOKButton);
    Doc.Info := Info;
    Doc.FileName := OsFileName(Name);
    Doc.MarkSaved;
    end;
  end;

{ --- the lock of the file while it is edited --- }

procedure MILockFile(AED: TFileEditor);
  begin
  with AED do
    begin
    if EditorDefaults.EdOpt and ebfLck = 0 then
      Exit;
    if EditName = '' then
      Exit;
    if Locker <> nil then
      Locker.Free;
    Locker := TDosStream.Create(EditName, (stOpenRead and fmDeny) or fmDenyWrite);
    end
  end;

procedure MIUnLockFile(AED: TFileEditor);
  begin
  with AED do
    begin
    if EditorDefaults.EdOpt and ebfLck = 0 then
      Exit;
    if Locker = nil then
      Exit;
    Locker.Free;
    Locker := nil;
    end
  end;

{ --- the title of the window --- }

procedure SetTitle(AED: TFileEditor);
  begin
  with AED do
    begin
    if Owner = nil then
      Exit;
    DisposeStr(TWindow(Owner).Title);
    if SmartPad then
      TWindow(Owner).Title := NewStr('SmartPad(TM) - '+EditName)
    else if ClipBrd then
      TWindow(Owner).Title := NewStr('Clipboard')
    else if EditName <> '' then
      TWindow(Owner).Title := NewStr(GetString(dlEditTitle)+' - '+EditName)
    else
      TWindow(Owner).Title := NewStr(GetString(dlEditTitle));
    end;
  end;

{ --- reading --- }

procedure MILoadFile(AED: TFileEditor; Name: String);
  var
    Nm, Xt: String;
    Err: AnsiString;
    Opt: TTveFileOptions;
    Inf: TTveFileInfo;
    HiLitePar: THighliteParams;
  begin
  with AED do
    begin
    JustSaved := False;
    if Name <> '' then
      Name := lFExpand(Name);
    Opt := FileOptions(AED);
    if ClipBrd then
      begin
      Doc.LoadText(ClipboardText);
      Inf := Doc.Info;
      Inf.Charset := 65001;
      Doc.Info := Inf;
      end
    else if (Name = '') or not ExistFile(Name) then
      begin
      { a new file (or a name that is not there yet) }
      Doc.LoadText('');
      Inf := Doc.Info;
      Inf.Charset := 65001;
      Inf.Eol := Opt.DefaultEol;
      Doc.Info := Inf;
      Doc.Eol := Opt.DefaultEol;
      end
    else if not TveLoadDoc(Doc, OsFileName(Name), Opt, Err) then
      begin
      MessFileNotOpen(Name, 0);
      isValid := False;
      Exit;
      end;
    Editor.GotoOffset(0);
    Editor.ClearSelection;
    EditName := Name;
    if '*^&'+EditName = TempFile then
      begin
      EditName := '';
      TempFile := '';
      end;
    SetTitle(AED);
    MILockFile(AED);
    lFSplit(EditName, FreeStr, Nm, Xt);
    EdOpt.HiLite := Macro.InitHighLight(Nm+Xt, HiLitePar, Macros, @EdOpt);
    EdOpt.HiLite := EditorDefaults.EdOpt2 and ebfHlt <> 0;
    EdOpt.ForcedCRLF := EolMode;
    ApplyOptions;
    Refresh;
    end;
  end;

procedure MIOpenFile(AED: TFileEditor);
  var
    FileName: String;
  begin
  with AED do
    begin
    FileName := GetFileNameDialog(x_x, GetString(dlOpenFile),
        GetString(dlOpenFileName),
        fdOpenButton+fdHelpButton, hsEditOpen);
    if FileName <> '' then
      begin
      MIUnLockFile(AED);
      MILoadFile(AED, lFExpand(FileName));
      if not isValid then
        begin
        isValid := True;
        Message(Owner, evCommand, cmClose, nil);
        MILockFile(AED);
        Exit;
        end;
      Owner.Redraw;
      end;
    end
  end;

{ --- writing --- }

procedure MISaveFile(AED: TFileEditor);
  var
    F: lFile;
    OldAttr: Word;
    FileExist: Boolean;
    L: array[0..0] of PtrInt;
  begin
  with AED do
    begin
    MIUnLockFile(AED);
    if ClipBrd then
      begin
      SetClipboardText(Doc.Buffer.AsString);
      if SystemData.Options and ossUseSysClip <> 0 then
        SyncClipIn;
      Doc.MarkSaved;
      end
    else
      begin
      if EditName = '' then
        begin
        MISaveFileAs(AED);
        Exit
        end;
      FileExist := False;
      lAssignFile(F, EditName);
      ClrIO;
      OldAttr := 0;
      lGetFAttr(F, OldAttr);
      if DosError = 0 then
        FileExist := True;
      if FileExist and (OldAttr and ReadOnly <> 0) then
        begin
        Pointer(L[0]) := @EditName;
        if Msg(dlED_ModifyRO, @L, mfConfirmation+mfOKCancel) <> cmOK then
          begin
          MILockFile(AED);
          Exit;
          end;
        end;
      ClrIO;
      lSetFAttr(F, Archive);
      if not WriteDoc(AED, EditName) then
        begin
        MILockFile(AED);
        if not (SmartPad or ClipBrd) then
          FileChanged(EditName);
        Exit;
        end;
      lAssignFile(F, EditName);
      ClrIO;
      if (OldAttr <> Archive) and (OldAttr <> $FFFF) and FileExist then
        lSetFAttr(F, OldAttr or Archive);
      ClrIO;
      end;
    MILockFile(AED);
    JustSaved := True;
    Owner.Redraw;
    if not (SmartPad or ClipBrd) then
      FileChanged(EditName);
    if UpStrg(EditName) = UpStrg(MakeNormName(ConfigDir, 'dn.ini')) then
      begin
      LoadDnIniSettings;
      DoneIniEngine;
      CopyIniVarsToCfgVars;
      ShowIniErrors;
      end;
    end
  end;

procedure MISaveFileAs(AED: TFileEditor);
  var
    FileName: String;
    Attr: Word;
    F: lFile;
    P: PString;
    Dr: String[30];
  begin
  with AED do
    begin
    FileName := GetFileNameDialog(x_x, GetString(dlSaveFileAs),
        GetString(dlSaveFileAsName),
        fdOKButton+fdHelpButton, hsEditSave);
    if FileName = '' then
      Exit;
    MIUnLockFile(AED);
    FileName := lFExpand(FileName);
    if FileName[Length(FileName)] = '.' then
      SetLength(FileName, Length(FileName)-1);
    lAssignFile(F, FileName);
    ClrIO;
    Attr := 0;
    lGetFAttr(F, Attr);
    if DosError = 0 then
      begin
      P := @Dr;
      Dr := Cut(FileName, 30);
      if Msg(dlED_OverQuery, @P, mfYesButton+mfCancelButton+mfWarning) <> cmYes then
        begin
        MILockFile(AED);
        Exit;
        end;
      if Attr and ReadOnly <> 0 then
        begin
        lSetFAttr(F, Archive);
        if DosError <> 0 then
          begin
          CantWrite(FileName);
          MILockFile(AED);
          Exit;
          end;
        end;
      end;
    if not WriteDoc(AED, FileName) then
      begin
      MILockFile(AED);
      Exit;
      end;
    EditName := FileName;
    FileChanged(EditName);
    SetTitle(AED);
    ApplyLanguage;
    Owner.Redraw;
    MILockFile(AED);
    end
  end;

{ --- the desktop: what is kept of the editor when DN is left and given back when it starts again --- }

procedure MIStore(AED: TFileEditor; S: TStream);
  var
    M: TRect;
    B: Byte;
  begin
  with AED do
    begin
    PutPeerViewPtr(S, InfoL);
    PutPeerViewPtr(S, BMrk);
    S.WriteStr(@EditName);
    S.Write(SmartPad, SizeOf(SmartPad));
    S.Write(ClipBrd, SizeOf(ClipBrd));
    S.Write(EdOpt.LeftSide, 6);
    S.Write(EdOpt.HiLite, 1);
    S.Write(EdOpt.HiliteColumn, SizeOf(EdOpt.HiliteColumn));
    S.Write(EdOpt.HiliteLine, SizeOf(EdOpt.HiliteLine));
    S.Write(EdOpt.AutoIndent, SizeOf(EdOpt.AutoIndent));
    B := Ord(VertBlock);
    S.Write(B, 1);
    S.Write(EdOpt.BackIndent, SizeOf(EdOpt.BackIndent));
    S.Write(EdOpt.AutoJustify, SizeOf(EdOpt.AutoJustify));
    S.Write(OptimalFill, SizeOf(OptimalFill));
    S.Write(EdOpt.AutoWrap, SizeOf(EdOpt.AutoWrap));
    S.Write(EdOpt.AutoBrackets, SizeOf(EdOpt.AutoBrackets));
    S.Write(TabReplace, SizeOf(TabReplace));
    S.Write(EdOpt.SmartTab, SizeOf(EdOpt.SmartTab));
    S.Write(DrawMode, SizeOf(DrawMode));
    B := Ord(InsertMode);
    S.Write(B, 1);
    S.Write(Cursor, SizeOf(Cursor));
    M := Mark;
    S.Write(M, SizeOf(M));
    S.Write(GetMarks, SizeOf(TPosArray));
    end
  end;

procedure MILoad(AED: TFileEditor; S: TStream);
  var
    SS: PString;
    M: TRect;
    C: TPoint;
    Marks: TPosArray;
    B: Byte;
    DM: Integer;
  begin
  with AED do
    begin
    GetPeerViewPtr(S, InfoL);
    GetPeerViewPtr(S, BMrk);
    SS := S.ReadStr;
    if SS = nil then
      EditName := ''
    else
      begin
      EditName := SS^;
      DisposeStr(SS);
      end;
    S.Read(SmartPad, SizeOf(SmartPad));
    S.Read(ClipBrd, SizeOf(ClipBrd));
    if SmartPad then
      SmartWindowPtr := @Owner;
    if ClipBrd then
      ClipboardWindowPtr := @Owner;
    S.Read(EdOpt.LeftSide, 6);
    S.Read(EdOpt.HiLite, 1);
    S.Read(EdOpt.HiliteColumn, SizeOf(EdOpt.HiliteColumn));
    S.Read(EdOpt.HiliteLine, SizeOf(EdOpt.HiliteLine));
    S.Read(EdOpt.AutoIndent, SizeOf(EdOpt.AutoIndent));
    S.Read(B, 1);
    VertBlock := B <> 0;
    S.Read(EdOpt.BackIndent, SizeOf(EdOpt.BackIndent));
    S.Read(EdOpt.AutoJustify, SizeOf(EdOpt.AutoJustify));
    S.Read(OptimalFill, SizeOf(OptimalFill));
    S.Read(EdOpt.AutoWrap, SizeOf(EdOpt.AutoWrap));
    S.Read(EdOpt.AutoBrackets, SizeOf(EdOpt.AutoBrackets));
    S.Read(TabReplace, SizeOf(TabReplace));
    S.Read(EdOpt.SmartTab, SizeOf(EdOpt.SmartTab));
    S.Read(DM, SizeOf(DM));
    DrawMode := DM;
    S.Read(B, 1);
    InsertMode := B <> 0;
    S.Read(C, SizeOf(C));
    S.Read(M, SizeOf(M));
    S.Read(Marks, SizeOf(TPosArray));
    SavedCursor := C;
    SavedMark := M;
    SavedMarks := Marks;
    Macros := TCollection.Create(10, 10);
    MenuItemStr[True] := NewStr(GetString(dlMenuItemOn));
    MenuItemStr[False] := NewStr(GetString(dlMenuItemOff));
    end
  end;

{ The window is back: the file is read again and the places are given back. }
procedure MIAwaken(AED: TFileEditor);
  var
    X, Y: LongInt;
    Hi: Boolean;
  begin
  with AED do
    begin
    X := HScroll.Value;
    Y := VScroll.Value;
    Hi := EdOpt.HiLite;
    MILoadFile(AED, EditName);
    EdOpt.HiLite := Hi;
    ApplyOptions;
    SetMarks(SavedMarks);
    Mark := SavedMark;
    GotoXY(SavedCursor.X, SavedCursor.Y);
    ScrollTo(X, Y);
    Owner.Redraw;
    end
  end;

end.
