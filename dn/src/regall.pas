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
unit RegAll;

interface

procedure RegisterAll;

implementation

uses
  panelwin, topview, dlgrecs, strview,
  
  fmtzip, fmtlha, fmtrar, fmtace, fmtha, fmtcab,
  
  fmtarc, fmtbsa, fmtbs2, fmthyp, fmtlim, fmthpk, fmttar,
  fmtzxz, fmtqrk, fmtain, fmtchz, fmthap, fmtis3, fmtsqz,
  fmtuc2, fmtufa, fmtzoo, fmttgz, fmt7z,  fmtbz2, fmtxz,
  
  
  Arvid,
  
  Archiver, ArcView, ASCIITab, calcline, Collect, DiskInfo, mainapp,
  DNStdDlg, DNUtil, Drives, editinfo, Editor, FileFind, FilesCol,
  filepanel, FStorage, FViewer, gadgets, histories, editcore, Startup,
  Tree, UniWin, UserMenu, panelwinx, HelpKern,
  calcwin, CellsCol, 
  Calendar, 
  DBView, 
  
  PrintMan, 
  Tetris, 
  
  Phones, 
  
  
  ColorSel,
  Dialogs, Menus, Streams, ObjType, Scroller, Setups,
  Validate, Views, inputfname 
  , editwin
  , DNDlgs, DNStrL, bwselect, DlgLayout, DnActions;

{ The classes of DN in the streams (opstream, ipstream), by their names (the classes of tv/ register themselves in their units).
  The help topics of tv/ keep the byte streams of TvObjs: RegisterType. }

var
  RHelpTopic: TStreamRec = (ObjType: otHelpTopic; VmtLink: 0; Load: nil; Store: nil; Next: nil);
  RHelpIndex: TStreamRec = (ObjType: otHelpIndex; VmtLink: 0; Load: nil; Store: nil; Next: nil);

function Build_RHelpTopic(S: TStream): TStreamable;
begin
  Result := TStreamable(HelpKern.THelpTopic.Load(S));
end;

procedure Store_RHelpTopic(P: TStreamable; S: TStream);
begin
  HelpKern.THelpTopic(P).Store(S);
end;

function Build_RHelpIndex(S: TStream): TStreamable;
begin
  Result := TStreamable(HelpKern.THelpIndex.Load(S));
end;

procedure Store_RHelpIndex(P: TStreamable; S: TStream);
begin
  HelpKern.THelpIndex(P).Store(S);
end;

procedure Reg(const Name: ShortString; Build: TStreamableBuilder);
begin
  TStreamableClass.Create(Name, Build);
end;

procedure RegisterAll;
begin
  Reg('fmtzip.TZIPArchive', @fmtzip.TZIPArchive.Build);
  Reg('fmtlha.TLHAArchive', @fmtlha.TLHAArchive.Build);
  Reg('fmtrar.TRARArchive', @fmtrar.TRARArchive.Build);
  Reg('fmtcab.TCABArchive', @fmtcab.TCABArchive.Build);
  Reg('fmtace.TACEArchive', @fmtace.TACEArchive.Build);
  Reg('fmtha.THAArchive', @fmtha.THAArchive.Build);
  Reg('fmtarc.TARCArchive', @fmtarc.TARCArchive.Build);
  Reg('fmtbsa.TBSAArchive', @fmtbsa.TBSAArchive.Build);
  Reg('fmtbs2.TBS2Archive', @fmtbs2.TBS2Archive.Build);
  Reg('fmthyp.THYPArchive', @fmthyp.THYPArchive.Build);
  Reg('fmtlim.TLIMArchive', @fmtlim.TLIMArchive.Build);
  Reg('fmthpk.THPKArchive', @fmthpk.THPKArchive.Build);
  Reg('fmttar.TTARArchive', @fmttar.TTARArchive.Build);
  Reg('fmttgz.TTGZArchive', @fmttgz.TTGZArchive.Build);
  Reg('fmtzxz.TZXZArchive', @fmtzxz.TZXZArchive.Build);
  Reg('fmtqrk.TQuArkArchive', @fmtqrk.TQuArkArchive.Build);
  Reg('fmtufa.TUFAArchive', @fmtufa.TUFAArchive.Build);
  Reg('fmtis3.TIS3Archive', @fmtis3.TIS3Archive.Build);
  Reg('fmtsqz.TSQZArchive', @fmtsqz.TSQZArchive.Build);
  Reg('fmthap.THAPArchive', @fmthap.THAPArchive.Build);
  Reg('fmtzoo.TZOOArchive', @fmtzoo.TZOOArchive.Build);
  Reg('fmtchz.TCHZArchive', @fmtchz.TCHZArchive.Build);
  Reg('fmtuc2.TUC2Archive', @fmtuc2.TUC2Archive.Build);
  Reg('fmtain.TAINArchive', @fmtain.TAINArchive.Build);
  Reg('fmt7z.TS7ZArchive', @fmt7z.TS7ZArchive.Build);
  Reg('fmtbz2.TBZ2Archive', @fmtbz2.TBZ2Archive.Build);
  Reg('fmtxz.TXZArchive', @fmtxz.TXZArchive.Build);
  Reg('Archiver.TARJArchive', @Archiver.TARJArchive.Build);
  Reg('Archiver.TFileInfo', @Archiver.TFileInfo.Build);
  Reg('ArcView.TArcDrive', @ArcView.TArcDrive.Build);
  Reg('Arvid.TArvidDrive', @Arvid.TArvidDrive.Build);
  Reg('ASCIITab.TTable', @ASCIITab.TTable.Build);
  Reg('ASCIITab.TReport', @ASCIITab.TReport.Build);
  Reg('ASCIITab.TASCIIChart', @ASCIITab.TASCIIChart.Build);
  Reg('calcwin.TCalcWindow', @calcwin.TCalcWindow.Build);
  Reg('calcwin.TCalcView', @calcwin.TCalcView.Build);
  Reg('calcwin.TCalcInput', @calcwin.TCalcInput.Build);
  Reg('calcwin.TInfoView', @calcwin.TInfoView.Build);
  Reg('CellsCol.TCellCollection', @CellsCol.TCellCollection.Build);
  Reg('Calendar.TCalendarView', @Calendar.TCalendarView.Build);
  Reg('Calendar.TCalendarWindow', @Calendar.TCalendarWindow.Build);
  Reg('calcline.TCalcLine', @calcline.TCalcLine.Build);
  Reg('calcline.TIndicator', @calcline.TIndicator.Build);
  Reg('DNStrL.TStringList', @DNStrL.TStringList.Build);
  Reg('bwselect.T_BWSelector', @bwselect.T_BWSelector.Build);
  Reg('DBView.TDBWindow', @DBView.TDBWindow.Build);
  Reg('DBView.TDBViewer', @DBView.TDBViewer.Build);
  Reg('DBView.TDBIndicator', @DBView.TDBIndicator.Build);
  Reg('DBView.TFieldListBox', @DBView.TFieldListBox.Build);
  Reg('DlgLayout.TResDialog', @DlgLayout.TResDialog.Build);
  Reg('DNDlgs.THexLine', @DNDlgs.THexLine.Build);
  Reg('DNDlgs.TComboBox', @DNDlgs.TComboBox.Build);
  Reg('DNDlgs.TParamText', @DNDlgs.TParamText.Build);
  Reg('DNDlgs.TNotepad', @DNDlgs.TNotepad.Build);
  Reg('DNDlgs.TPage', @DNDlgs.TPage.Build);
  Reg('DNDlgs.TBookmark', @DNDlgs.TBookmark.Build);
  Reg('DNDlgs.TPageFrame', @DNDlgs.TPageFrame.Build);
  Reg('DNDlgs.TNotepadFrame', @DNDlgs.TNotepadFrame.Build);
  Reg('DiskInfo.TDiskInfo', @DiskInfo.TDiskInfo.Build);
  Reg('DiskInfo.TDriveView', @DiskInfo.TDriveView.Build);
  Reg('mainapp.TBackground', @mainapp.TBackground.Build);
  Reg('mainapp.TDesktop', @mainapp.TDesktop.Build);
  Reg('DNUtil.TDataSaver', @DNUtil.TDataSaver.Build);
  Reg('Drives.TDrive', @Drives.TDrive.Build);
  Reg('editinfo.TInfoLine', @editinfo.TInfoLine.Build);
  Reg('editinfo.TBookmarkLine', @editinfo.TBookmarkLine.Build);
  Reg('Editor.TXFileEditor', @Editor.TXFileEditor.Build);
  Reg('FileFind.TFindDrive', @FileFind.TFindDrive.Build);
  Reg('FileFind.TTempDrive', @FileFind.TTempDrive.Build);
  Reg('FilesCol.TFilesCollection', @FilesCol.TFilesCollection.Build);
  Reg('filepanel.TFilePanel', @filepanel.TFilePanel.Build);
  Reg('filepanel.TInfoView', @filepanel.TInfoView.Build);
  Reg('filepanel.TDirView', @filepanel.TDirView.Build);
  Reg('topview.TSortView', @topview.TSortView.Build);
  Reg('panelwin.TSeparator', @panelwin.TSeparator.Build);
  Reg('filepanel.TDriveLine', @filepanel.TDriveLine.Build);
  Reg('FStorage.TDirStorage', @FStorage.TDirStorage.Build);
  Reg('FViewer.TFileViewer', @FViewer.TFileViewer.Build);
  Reg('FViewer.TFileWindow', @FViewer.TFileWindow.Build);
  Reg('FViewer.TViewScroll', @FViewer.TViewScroll.Build);
  Reg('FViewer.TQFileViewer', @FViewer.TQFileViewer.Build);
  Reg('FViewer.TDFileViewer', @FViewer.TDFileViewer.Build);
  Reg('FViewer.TViewInfo', @FViewer.TViewInfo.Build);
  Reg('gadgets.TTrashCan', @gadgets.TTrashCan.Build);
  Reg('gadgets.TKeyMacros', @gadgets.TKeyMacros.Build);
  Reg('histories.TEditHistoryCol', @histories.TEditHistoryCol.Build);
  Reg('histories.TViewHistoryCol', @histories.TViewHistoryCol.Build);
  Reg('Menus.TMenuBar', @Menus.TMenuBar.Build);
  Reg('Menus.TMenuBox', @Menus.TMenuBox.Build);
  Reg('Menus.TStatusLine', @Menus.TStatusLine.Build);
  Reg('Menus.TMenuPopup', @Menus.TMenuPopup.Build);
  Reg('editcore.TFileEditor', @editcore.TFileEditor.Build);
  Reg('editwin.TEditWindow', @editwin.TEditWindow.Build);
  Reg('StrView.TDStringView', @StrView.TDStringView.Build);
  Reg('Phones.TPhone', @Phones.TPhone.Build);
  Reg('Phones.TPhoneDir', @Phones.TPhoneDir.Build);
  Reg('Phones.TPhoneCollection', @Phones.TPhoneCollection.Build);
  Reg('PrintMan.TStringCol', @PrintMan.TStringCol.Build);
  Reg('PrintMan.TPrintManager', @PrintMan.TPrintManager.Build);
  Reg('PrintMan.TPrintStatus', @PrintMan.TPrintStatus.Build);
  Reg('PrintMan.TPMWindow', @PrintMan.TPMWindow.Build);
  Reg('Setups.TSysDialog', @Setups.TSysDialog.Build);
  Reg('Setups.TCurrDriveInfo', @Setups.TCurrDriveInfo.Build);
  Reg('Setups.TMouseBar', @Setups.TMouseBar.Build);
  Reg('Setups.TSaversDialog', @Setups.TSaversDialog.Build);
  Reg('Setups.TSaversListBox', @Setups.TSaversListBox.Build);
  Reg('Tetris.TGameWindow', @Tetris.TGameWindow.Build);
  Reg('Tetris.TGameView', @Tetris.TGameView.Build);
  Reg('Tetris.TGameInfo', @Tetris.TGameInfo.Build);
  Reg('Tree.TTreeView', @Tree.TTreeView.Build);
  Reg('Tree.TTreeReader', @Tree.TTreeReader.Build);
  Reg('Tree.TTreeWindow', @Tree.TTreeWindow.Build);
  Reg('Tree.TTreePanel', @Tree.TTreePanel.Build);
  Reg('Tree.TTreeDialog', @Tree.TTreeDialog.Build);
  Reg('Tree.TTreeInfoView', @Tree.TTreeInfoView.Build);
  Reg('Tree.THTreeView', @Tree.THTreeView.Build);
  Reg('Tree.TDirCollection', @Tree.TDirCollection.Build);
  Reg('UniWin.TEditScrollBar', @UniWin.TEditScrollBar.Build);
  Reg('UniWin.TEditFrame', @UniWin.TEditFrame.Build);
  Reg('UserMenu.TUserWindow', @UserMenu.TUserWindow.Build);
  Reg('UserMenu.TUserView', @UserMenu.TUserView.Build);
  Reg('panelwinx.TXDoubleWindow', @panelwinx.TXDoubleWindow.Build);
  Reg('inputfname.TColorPoint', @inputfname.TColorPoint.Build);
  Reg('DnActions.TActionTable', @DnActions.TActionTable.Build);
  Reg('Collect.TObjCollection', @Collect.TObjCollection.Build);
  Reg('Collect.TLineCollection', @Collect.TLineCollection.Build);
  Reg('Collect.TStringCollection', @Collect.TStringCollection.Build);
  Reg('Collect.TStrCollection', @Collect.TStrCollection.Build);
  Reg('Views.TMyScrollBar', @Views.TMyScrollBar.Build);
  Reg('Dialogs.TLongInputLine', @Dialogs.TLongInputLine.Build);
  RHelpTopic.VmtLink := PtrUInt(System.TClass(HelpKern.THelpTopic));
  RHelpTopic.Load := @Build_RHelpTopic;
  RHelpTopic.Store := @Store_RHelpTopic;
  RHelpIndex.VmtLink := PtrUInt(System.TClass(HelpKern.THelpIndex));
  RHelpIndex.Load := @Build_RHelpIndex;
  RHelpIndex.Store := @Store_RHelpIndex;
  RegisterType(RHelpTopic);
  RegisterType(RHelpIndex);
end;

end.
