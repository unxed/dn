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
  fmtuc2, fmtufa, fmtzoo, fmttgz, fmt7z,  fmtbz2,
  
  
  Arvid,
  
  Archiver, ArcView, ASCIITab, calcline, Collect, DiskInfo, mainapp,
  DNStdDlg, DNUtil, Drives, editundo, Editor, FileFind, FilesCol,
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
  , DNDlgs, DNStrL, bwselect;

const
    { Validate }
{first TStreamRec used in RegisterAll}
RFilterValidator: TStreamRec = (ObjType: otFilterValidator; VmtLink: 0; Load: nil; Store: nil; Next: nil);
{second TStreamRec used in RegisterAll}
RRangeValidator: TStreamRec = (ObjType: otRangeValidator; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Views }
RView: TStreamRec = (ObjType: otView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFrame : TStreamRec = (ObjType: otFrame; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RScrollBar : TStreamRec = (ObjType: otScrollBar; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RGroup : TStreamRec = (ObjType: otGroup; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RWindow : TStreamRec = (ObjType: otWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { Arc_ZIP }
RZIPArchiver : TStreamRec = (ObjType: otZIPArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_LHA }
RLHAArchiver : TStreamRec = (ObjType: otLHAArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_RAR }
RRARArchiver : TStreamRec = (ObjType: otRARArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_CAB }
RCABArchiver : TStreamRec = (ObjType: otCABArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_ACE }
RACEArchiver : TStreamRec = (ObjType: otACEArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_HA }
RHAArchiver : TStreamRec = (ObjType: otHAArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { Arc_arc }
RARCArchiver : TStreamRec = (ObjType: otARCArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_bsa }
RBSAArchiver : TStreamRec = (ObjType: otBSAArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_bs2 }
RBS2Archiver : TStreamRec = (ObjType: otBS2Archiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_hyp }
RHYPArchiver : TStreamRec = (ObjType: otHYPArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_lim }
RLIMArchiver : TStreamRec = (ObjType: otLIMArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_hpk }
RHPKArchiver : TStreamRec = (ObjType: otHPKArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_TAR }
RTARArchiver : TStreamRec = (ObjType: otTARArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_TGZ }
RTGZArchiver : TStreamRec = (ObjType: otTGZArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_ZXZ }
RZXZArchiver : TStreamRec = (ObjType: otZXZArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_QRK }
RQUARKArchiver : TStreamRec = (ObjType: otQUARKArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_UFA }
RUFAArchiver : TStreamRec = (ObjType: otUFAArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_IS3 }
RIS3Archiver : TStreamRec = (ObjType: otIS3Archiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_SQZ }
RSQZArchiver : TStreamRec = (ObjType: otSQZArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_HAP }
RHAPArchiver : TStreamRec = (ObjType: otHAPArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_ZOO }
RZOOArchiver : TStreamRec = (ObjType: otZOOArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_CHZ }
RCHZArchiver : TStreamRec = (ObjType: otCHZArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_UC2 }
RUC2Archiver : TStreamRec = (ObjType: otUC2Archiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_AIN }
RAINArchiver : TStreamRec = (ObjType: otAINArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_7Z }
RS7ZArchiver : TStreamRec = (ObjType: otS7ZArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Arc_BZ2 }
RBZ2Archiver : TStreamRec = (ObjType: otBZ2Archiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { Archiver }
RARJArchiver : TStreamRec = (ObjType: otARJArchiver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFileInfo : TStreamRec = (ObjType: otFileInfo; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { ArcView }
RArcDrive : TStreamRec = (ObjType: otArcDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { Arvid }
RArvidDrive : TStreamRec = (ObjType: otArvidDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { AsciiTab }
RTable : TStreamRec = (ObjType: otTable; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RReport : TStreamRec = (ObjType: otReport; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RASCIIChart : TStreamRec = (ObjType: otASCIIChart; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Calc }
    
RCalcWindow : TStreamRec = (ObjType: otCalcWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RCalcView : TStreamRec = (ObjType: otCalcView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RCalcInfo : TStreamRec = (ObjType: otCalcInfo; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RInfoView : TStreamRec = (ObjType: otInfoView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { CellsCol }
RCellCollection : TStreamRec = (ObjType: otCellCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    { Calendar }
RCalendarView : TStreamRec = (ObjType: otCalendarView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RCalendarWindow : TStreamRec = (ObjType: otCalendarWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { CCalc }
RCalcLine : TStreamRec = (ObjType: otCalcLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RIndicator : TStreamRec = (ObjType: otIndicator; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Collect }
RCollection : TStreamRec = (ObjType: otCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RLineCollection : TStreamRec = (ObjType: otLineCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RStringCollection : TStreamRec = (ObjType: otStringCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RStrCollection : TStreamRec = (ObjType: otStrCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RStringList : TStreamRec = (ObjType: otStringList; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { ColorSel }
RColorSelector : TStreamRec = (ObjType: otColorSelector; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RMonoSelector : TStreamRec = (ObjType: otMonoSelector; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RColorDisplay : TStreamRec = (ObjType: otColorDisplay; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RColorGroupList : TStreamRec = (ObjType: otColorGroupList; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RColorItemList : TStreamRec = (ObjType: otColorItemList; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RColorDialog : TStreamRec = (ObjType: otColorDialog; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RR_BWSelector : TStreamRec = (ObjType: otR_BWSelector; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    { DBView }
RDBWindow : TStreamRec = (ObjType: otDBWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDBViewer : TStreamRec = (ObjType: otDBViewer; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDBIndicator : TStreamRec = (ObjType: otDBIndicator; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFieldListBox : TStreamRec = (ObjType: otFieldListBox; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    { Dialogs }
RDialog : TStreamRec = (ObjType: otDialog; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RInputLine : TStreamRec = (ObjType: otInputLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RHexLine : TStreamRec = (ObjType: otHexLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RLongInputLine : TStreamRec = (ObjType: otLongInputLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RButton : TStreamRec = (ObjType: otButton; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RCluster : TStreamRec = (ObjType: otCluster; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RRadioButtons : TStreamRec = (ObjType: otRadioButtons; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RComboBox : TStreamRec = (ObjType: otComboBox; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RCheckBoxes : TStreamRec = (ObjType: otCheckBoxes; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RMultiCheckBoxes : TStreamRec = (ObjType: otMultiCheckBoxes; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RListBox : TStreamRec = (ObjType: otListBox; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RStaticText : TStreamRec = (ObjType: otStaticText; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RLabel : TStreamRec = (ObjType: otLabel; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RHistory : TStreamRec = (ObjType: otHistory; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RParamText : TStreamRec = (ObjType: otParamText; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RNotepad : TStreamRec = (ObjType: otNotepad; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPage : TStreamRec = (ObjType: otPage; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RBookmark : TStreamRec = (ObjType: otBookmark; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPageFrame : TStreamRec = (ObjType: otPageFrame; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RNotepadFrame : TStreamRec = (ObjType: otNotepadFrame; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { DiskInfo }
RDiskInfo : TStreamRec = (ObjType: otDiskInfo; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDriveView : TStreamRec = (ObjType: otDriveView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { mainapp }
RBackground : TStreamRec = (ObjType: otBackground; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDesktop : TStreamRec = (ObjType: otDesktop; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { DnStdDlg }
RFileInputLine : TStreamRec = (ObjType: otFileInputLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFileCollection : TStreamRec = (ObjType: otFileCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFileList : TStreamRec = (ObjType: otFileList; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFileInfoPane : TStreamRec = (ObjType: otFileInfoPane; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFileDialog : TStreamRec = (ObjType: otFileDialog; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RSortedListBox : TStreamRec = (ObjType: otSortedListBox; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { DNUtil }
RDataSaver : TStreamRec = (ObjType: otDataSaver; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Drives }
RDrive : TStreamRec = (ObjType: otDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { editundo }
RInfoLine : TStreamRec = (ObjType: otInfoLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RBookLine : TStreamRec = (ObjType: otBookLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Editor }
RXFileEditor : TStreamRec = (ObjType: otXFileEditor; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { FileFind }
RFindDrive : TStreamRec = (ObjType: otFindDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTempDrive : TStreamRec = (ObjType: otTempDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { FilesCol }
RFilesCollection : TStreamRec = (ObjType: otFilesCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { filepanel }
RFilePanel : TStreamRec = (ObjType: otFilePanel; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFlPInfoView : TStreamRec = (ObjType: otFlPInfoView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDirView : TStreamRec = (ObjType: otDirView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RSortView : TStreamRec = (ObjType: otSortView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RSeparator : TStreamRec = (ObjType: otSeparator; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDriveLine : TStreamRec = (ObjType: otDriveLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { FStorage }
RDirStorage : TStreamRec = (ObjType: otDirStorage; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { FViewer }
RFileViewer : TStreamRec = (ObjType: otFileViewer; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RFileWindow : TStreamRec = (ObjType: otFileWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RViewScroll : TStreamRec = (ObjType: otViewScroll; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RQFileViewer : TStreamRec = (ObjType: otQFileViewer; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDFileViewer : TStreamRec = (ObjType: otDFileViewer; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RViewInfo : TStreamRec = (ObjType: otViewInfo; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Gauges }
    
RTrashCan : TStreamRec = (ObjType: otTrashCan; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
RKeyMacros : TStreamRec = (ObjType: otKeyMacros; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { HelpKern }
RHelpTopic : TStreamRec = (ObjType: otHelpTopic; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RHelpIndex : TStreamRec = (ObjType: otHelpIndex; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Histries }
REditHistoryCol : TStreamRec = (ObjType: otEditHistoryCol; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RViewHistoryCol : TStreamRec = (ObjType: otViewHistoryCol; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Menus }
    
RMenuBar : TStreamRec = (ObjType: otMenuBar; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RMenuBox : TStreamRec = (ObjType: otMenuBox; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RStatusLine : TStreamRec = (ObjType: otStatusLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RMenuPopup : TStreamRec = (ObjType: otMenuPopup; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { editcore }
RFileEditor : TStreamRec = (ObjType: otFileEditor; VmtLink: 0; Load: nil; Store: nil; Next: nil);
REditWindow : TStreamRec = (ObjType: otEditWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    
RDStringView : TStreamRec = (ObjType: otDStringView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPhone : TStreamRec = (ObjType: otPhone; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPhoneDir : TStreamRec = (ObjType: otPhoneDir; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPhoneCollection : TStreamRec = (ObjType: otPhoneCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    { PrintManager }
RStringCol : TStreamRec = (ObjType: otStringCol; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPrintManager : TStreamRec = (ObjType: otPrintManager; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPrintStatus : TStreamRec = (ObjType: otPrintStatus; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RPMWindow : TStreamRec = (ObjType: otPMWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    { Scroller }
RScroller : TStreamRec = (ObjType: otScroller; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RListViewer : TStreamRec = (ObjType: otListViewer; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Setups }
RSysDialog : TStreamRec = (ObjType: otSysDialog; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RCurrDriveInfo : TStreamRec = (ObjType: otCurrDriveInfo; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RMouseBar : TStreamRec = (ObjType: otMouseBar; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
RSaversDialog : TStreamRec = (ObjType: otSaversDialog; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RSaversListBox : TStreamRec = (ObjType: otSaversListBox; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    
    { Startup }
RTextCollection : TStreamRec = (ObjType: otTextCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Terminal }
    
    
    { Tetris }
RGameWindow : TStreamRec = (ObjType: otGameWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RGameView : TStreamRec = (ObjType: otGameView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RGameInfo : TStreamRec = (ObjType: otGameInfo; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { Tree }
RTreeView : TStreamRec = (ObjType: otTreeView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTreeReader : TStreamRec = (ObjType: otTreeReader; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTreeWindow : TStreamRec = (ObjType: otTreeWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTreePanel : TStreamRec = (ObjType: otTreePanel; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTreeDialog : TStreamRec = (ObjType: otTreeDialog; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTreeInfoView : TStreamRec = (ObjType: otTreeInfoView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RHTreeView : TStreamRec = (ObjType: otHTreeView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RDirCollection : TStreamRec = (ObjType: otDirCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { UniWin }
REditScrollBar : TStreamRec = (ObjType: otEditScrollBar; VmtLink: 0; Load: nil; Store: nil; Next: nil);
REditFrame : TStreamRec = (ObjType: otEditFrame; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { UserMenu }
RUserWindow : TStreamRec = (ObjType: otUserWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RUserView : TStreamRec = (ObjType: otUserView; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RMyScrollBar : TStreamRec = (ObjType: otMyScrollBar; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { panelwinx }
RDoubleWindow : TStreamRec = (ObjType: otDoubleWindow; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
{last TStreamRec used in RegisterAll}
RColorPoint : TStreamRec = (ObjType: otColorPoint; VmtLink: 0; Load: nil; Store: nil; Next: nil);

procedure RegisterAll;
  begin
    RegisterType(RFilterValidator);
    RegisterType(RRangeValidator);
    RegisterType(RView);
    RegisterType(RFrame);
    RegisterType(RScrollBar);
    RegisterType(RGroup);
    RegisterType(RWindow);
    RegisterType(RZIPArchiver);
    RegisterType(RLHAArchiver);
    RegisterType(RRARArchiver);
    RegisterType(RCABArchiver);
    RegisterType(RACEArchiver);
    RegisterType(RHAArchiver);
    RegisterType(RARCArchiver);
    RegisterType(RBSAArchiver);
    RegisterType(RBS2Archiver);
    RegisterType(RHYPArchiver);
    RegisterType(RLIMArchiver);
    RegisterType(RHPKArchiver);
    RegisterType(RTARArchiver);
    RegisterType(RTGZArchiver);
    RegisterType(RZXZArchiver);
    RegisterType(RQUARKArchiver);
    RegisterType(RUFAArchiver);
    RegisterType(RIS3Archiver);
    RegisterType(RSQZArchiver);
    RegisterType(RHAPArchiver);
    RegisterType(RZOOArchiver);
    RegisterType(RCHZArchiver);
    RegisterType(RUC2Archiver);
    RegisterType(RAINArchiver);
    RegisterType(RS7ZArchiver);
    RegisterType(RBZ2Archiver);
    RegisterType(RARJArchiver);
    RegisterType(RFileInfo);
    RegisterType(RArcDrive);
    RegisterType(RArvidDrive);
    RegisterType(RTable);
    RegisterType(RReport);
    RegisterType(RASCIIChart);
    RegisterType(RCalcWindow);
    RegisterType(RCalcView);
    RegisterType(RCalcInfo);
    RegisterType(RInfoView);
    RegisterType(RCellCollection);
    RegisterType(RCalendarView);
    RegisterType(RCalendarWindow);
    RegisterType(RCalcLine);
    RegisterType(RIndicator);
    RegisterType(RCollection);
    RegisterType(RLineCollection);
    RegisterType(RStringCollection);
    RegisterType(RStrCollection);
    RegisterType(RStringList);
    RegisterType(RColorSelector);
    RegisterType(RMonoSelector);
    RegisterType(RColorDisplay);
    RegisterType(RColorGroupList);
    RegisterType(RColorItemList);
    RegisterType(RColorDialog);
    RegisterType(RR_BWSelector);
    RegisterType(RDBWindow);
    RegisterType(RDBViewer);
    RegisterType(RDBIndicator);
    RegisterType(RFieldListBox);
    RegisterType(RDialog);
    RegisterType(RInputLine);
    RegisterType(RHexLine);
    RegisterType(RLongInputLine);
    RegisterType(RButton);
    RegisterType(RCluster);
    RegisterType(RRadioButtons);
    RegisterType(RComboBox);
    RegisterType(RCheckBoxes);
    RegisterType(RMultiCheckBoxes);
    RegisterType(RListBox);
    RegisterType(RStaticText);
    RegisterType(RLabel);
    RegisterType(RHistory);
    RegisterType(RParamText);
    RegisterType(RNotepad);
    RegisterType(RPage);
    RegisterType(RBookmark);
    RegisterType(RPageFrame);
    RegisterType(RNotepadFrame);
    RegisterType(RDiskInfo);
    RegisterType(RDriveView);
    RegisterType(RBackground);
    RegisterType(RDesktop);
    RegisterType(RFileInputLine);
    RegisterType(RFileCollection);
    RegisterType(RFileList);
    RegisterType(RFileInfoPane);
    RegisterType(RFileDialog);
    RegisterType(RSortedListBox);
    RegisterType(RDataSaver);
    RegisterType(RDrive);
    RegisterType(RInfoLine);
    RegisterType(RBookLine);
    RegisterType(RXFileEditor);
    RegisterType(RFindDrive);
    RegisterType(RTempDrive);
    RegisterType(RFilesCollection);
    RegisterType(RFilePanel);
    RegisterType(RFlPInfoView);
    RegisterType(RDirView);
    RegisterType(RSortView);
    RegisterType(RSeparator);
    RegisterType(RDriveLine);
    RegisterType(RDirStorage);
    RegisterType(RFileViewer);
    RegisterType(RFileWindow);
    RegisterType(RViewScroll);
    RegisterType(RQFileViewer);
    RegisterType(RDFileViewer);
    RegisterType(RViewInfo);
    RegisterType(RTrashCan);
    RegisterType(RKeyMacros);
    RegisterType(RHelpTopic);
    RegisterType(RHelpIndex);
    RegisterType(REditHistoryCol);
    RegisterType(RViewHistoryCol);
    RegisterType(RMenuBar);
    RegisterType(RMenuBox);
    RegisterType(RStatusLine);
    RegisterType(RMenuPopup);
    RegisterType(RFileEditor);
    RegisterType(REditWindow);
    RegisterType(RDStringView);
    RegisterType(RPhone);
    RegisterType(RPhoneDir);
    RegisterType(RPhoneCollection);
    RegisterType(RStringCol);
    RegisterType(RPrintManager);
    RegisterType(RPrintStatus);
    RegisterType(RPMWindow);
    RegisterType(RScroller);
    RegisterType(RListViewer);
    RegisterType(RSysDialog);
    RegisterType(RCurrDriveInfo);
    RegisterType(RMouseBar);
    RegisterType(RSaversDialog);
    RegisterType(RSaversListBox);
    RegisterType(RTextCollection);
    RegisterType(RGameWindow);
    RegisterType(RGameView);
    RegisterType(RGameInfo);
    RegisterType(RTreeView);
    RegisterType(RTreeReader);
    RegisterType(RTreeWindow);
    RegisterType(RTreePanel);
    RegisterType(RTreeDialog);
    RegisterType(RTreeInfoView);
    RegisterType(RHTreeView);
    RegisterType(RDirCollection);
    RegisterType(REditScrollBar);
    RegisterType(REditFrame);
    RegisterType(RUserWindow);
    RegisterType(RUserView);
    RegisterType(RMyScrollBar);
    RegisterType(RDoubleWindow);
    RegisterType(RColorPoint);
  end;

function Build_RFilterValidator(S: TStream): TStreamable;
begin
  Result := TStreamable(Validate.TFilterValidator.Load(S));
end;

procedure Store_RFilterValidator(P: TStreamable; S: TStream);
begin
  Validate.TFilterValidator(P).Store(S);
end;

function Build_RRangeValidator(S: TStream): TStreamable;
begin
  Result := TStreamable(Validate.TRangeValidator.Load(S));
end;

procedure Store_RRangeValidator(P: TStreamable; S: TStream);
begin
  Validate.TRangeValidator(P).Store(S);
end;

function Build_RView(S: TStream): TStreamable;
begin
  Result := TStreamable(Views.TView.Load(S));
end;

procedure Store_RView(P: TStreamable; S: TStream);
begin
  Views.TView(P).Store(S);
end;

function Build_RFrame(S: TStream): TStreamable;
begin
  Result := TStreamable(Views.TFrame.Load(S));
end;

procedure Store_RFrame(P: TStreamable; S: TStream);
begin
  Views.TFrame(P).Store(S);
end;

function Build_RScrollBar(S: TStream): TStreamable;
begin
  Result := TStreamable(Views.TScrollBar.Load(S));
end;

procedure Store_RScrollBar(P: TStreamable; S: TStream);
begin
  Views.TScrollBar(P).Store(S);
end;

function Build_RGroup(S: TStream): TStreamable;
begin
  Result := TStreamable(Views.TGroup.Load(S));
end;

procedure Store_RGroup(P: TStreamable; S: TStream);
begin
  Views.TGroup(P).Store(S);
end;

function Build_RWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(Views.TWindow.Load(S));
end;

procedure Store_RWindow(P: TStreamable; S: TStream);
begin
  Views.TWindow(P).Store(S);
end;

function Build_RZIPArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtzip.TZIPArchive.Load(S));
end;

procedure Store_RZIPArchiver(P: TStreamable; S: TStream);
begin
  fmtzip.TZIPArchive(P).Store(S);
end;

function Build_RLHAArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtlha.TLHAArchive.Load(S));
end;

procedure Store_RLHAArchiver(P: TStreamable; S: TStream);
begin
  fmtlha.TLHAArchive(P).Store(S);
end;

function Build_RRARArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtrar.TRARArchive.Load(S));
end;

procedure Store_RRARArchiver(P: TStreamable; S: TStream);
begin
  fmtrar.TRARArchive(P).Store(S);
end;

function Build_RCABArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtcab.TCABArchive.Load(S));
end;

procedure Store_RCABArchiver(P: TStreamable; S: TStream);
begin
  fmtcab.TCABArchive(P).Store(S);
end;

function Build_RACEArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtace.TACEArchive.Load(S));
end;

procedure Store_RACEArchiver(P: TStreamable; S: TStream);
begin
  fmtace.TACEArchive(P).Store(S);
end;

function Build_RHAArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtha.THAArchive.Load(S));
end;

procedure Store_RHAArchiver(P: TStreamable; S: TStream);
begin
  fmtha.THAArchive(P).Store(S);
end;

function Build_RARCArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtarc.TARCArchive.Load(S));
end;

procedure Store_RARCArchiver(P: TStreamable; S: TStream);
begin
  fmtarc.TARCArchive(P).Store(S);
end;

function Build_RBSAArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtbsa.TBSAArchive.Load(S));
end;

procedure Store_RBSAArchiver(P: TStreamable; S: TStream);
begin
  fmtbsa.TBSAArchive(P).Store(S);
end;

function Build_RBS2Archiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtbs2.TBS2Archive.Load(S));
end;

procedure Store_RBS2Archiver(P: TStreamable; S: TStream);
begin
  fmtbs2.TBS2Archive(P).Store(S);
end;

function Build_RHYPArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmthyp.THYPArchive.Load(S));
end;

procedure Store_RHYPArchiver(P: TStreamable; S: TStream);
begin
  fmthyp.THYPArchive(P).Store(S);
end;

function Build_RLIMArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtlim.TLIMArchive.Load(S));
end;

procedure Store_RLIMArchiver(P: TStreamable; S: TStream);
begin
  fmtlim.TLIMArchive(P).Store(S);
end;

function Build_RHPKArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmthpk.THPKArchive.Load(S));
end;

procedure Store_RHPKArchiver(P: TStreamable; S: TStream);
begin
  fmthpk.THPKArchive(P).Store(S);
end;

function Build_RTARArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmttar.TTARArchive.Load(S));
end;

procedure Store_RTARArchiver(P: TStreamable; S: TStream);
begin
  fmttar.TTARArchive(P).Store(S);
end;

function Build_RTGZArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmttgz.TTGZArchive.Load(S));
end;

procedure Store_RTGZArchiver(P: TStreamable; S: TStream);
begin
  fmttgz.TTGZArchive(P).Store(S);
end;

function Build_RZXZArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtzxz.TZXZArchive.Load(S));
end;

procedure Store_RZXZArchiver(P: TStreamable; S: TStream);
begin
  fmtzxz.TZXZArchive(P).Store(S);
end;

function Build_RQUARKArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtqrk.TQuArkArchive.Load(S));
end;

procedure Store_RQUARKArchiver(P: TStreamable; S: TStream);
begin
  fmtqrk.TQuArkArchive(P).Store(S);
end;

function Build_RUFAArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtufa.TUFAArchive.Load(S));
end;

procedure Store_RUFAArchiver(P: TStreamable; S: TStream);
begin
  fmtufa.TUFAArchive(P).Store(S);
end;

function Build_RIS3Archiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtis3.TIS3Archive.Load(S));
end;

procedure Store_RIS3Archiver(P: TStreamable; S: TStream);
begin
  fmtis3.TIS3Archive(P).Store(S);
end;

function Build_RSQZArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtsqz.TSQZArchive.Load(S));
end;

procedure Store_RSQZArchiver(P: TStreamable; S: TStream);
begin
  fmtsqz.TSQZArchive(P).Store(S);
end;

function Build_RHAPArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmthap.THAPArchive.Load(S));
end;

procedure Store_RHAPArchiver(P: TStreamable; S: TStream);
begin
  fmthap.THAPArchive(P).Store(S);
end;

function Build_RZOOArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtzoo.TZOOArchive.Load(S));
end;

procedure Store_RZOOArchiver(P: TStreamable; S: TStream);
begin
  fmtzoo.TZOOArchive(P).Store(S);
end;

function Build_RCHZArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtchz.TCHZArchive.Load(S));
end;

procedure Store_RCHZArchiver(P: TStreamable; S: TStream);
begin
  fmtchz.TCHZArchive(P).Store(S);
end;

function Build_RUC2Archiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtuc2.TUC2Archive.Load(S));
end;

procedure Store_RUC2Archiver(P: TStreamable; S: TStream);
begin
  fmtuc2.TUC2Archive(P).Store(S);
end;

function Build_RAINArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtain.TAINArchive.Load(S));
end;

procedure Store_RAINArchiver(P: TStreamable; S: TStream);
begin
  fmtain.TAINArchive(P).Store(S);
end;

function Build_RS7ZArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmt7z.TS7ZArchive.Load(S));
end;

procedure Store_RS7ZArchiver(P: TStreamable; S: TStream);
begin
  fmt7z.TS7ZArchive(P).Store(S);
end;

function Build_RBZ2Archiver(S: TStream): TStreamable;
begin
  Result := TStreamable(fmtbz2.TBZ2Archive.Load(S));
end;

procedure Store_RBZ2Archiver(P: TStreamable; S: TStream);
begin
  fmtbz2.TBZ2Archive(P).Store(S);
end;

function Build_RARJArchiver(S: TStream): TStreamable;
begin
  Result := TStreamable(Archiver.TARJArchive.Load(S));
end;

procedure Store_RARJArchiver(P: TStreamable; S: TStream);
begin
  Archiver.TARJArchive(P).Store(S);
end;

function Build_RFileInfo(S: TStream): TStreamable;
begin
  Result := TStreamable(Archiver.TFileInfo.Load(S));
end;

procedure Store_RFileInfo(P: TStreamable; S: TStream);
begin
  Archiver.TFileInfo(P).Store(S);
end;

function Build_RArcDrive(S: TStream): TStreamable;
begin
  Result := TStreamable(ArcView.TArcDrive.Load(S));
end;

procedure Store_RArcDrive(P: TStreamable; S: TStream);
begin
  ArcView.TArcDrive(P).Store(S);
end;

function Build_RArvidDrive(S: TStream): TStreamable;
begin
  Result := TStreamable(Arvid.TArvidDrive.Load(S));
end;

procedure Store_RArvidDrive(P: TStreamable; S: TStream);
begin
  Arvid.TArvidDrive(P).Store(S);
end;

function Build_RTable(S: TStream): TStreamable;
begin
  Result := TStreamable(ASCIITab.TTable.Load(S));
end;

procedure Store_RTable(P: TStreamable; S: TStream);
begin
  ASCIITab.TTable(P).Store(S);
end;

function Build_RReport(S: TStream): TStreamable;
begin
  Result := TStreamable(ASCIITab.TReport.Load(S));
end;

procedure Store_RReport(P: TStreamable; S: TStream);
begin
  ASCIITab.TReport(P).Store(S);
end;

function Build_RASCIIChart(S: TStream): TStreamable;
begin
  Result := TStreamable(ASCIITab.TASCIIChart.Load(S));
end;

procedure Store_RASCIIChart(P: TStreamable; S: TStream);
begin
  ASCIITab.TASCIIChart(P).Store(S);
end;

function Build_RCalcWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(calcwin.TCalcWindow.Load(S));
end;

procedure Store_RCalcWindow(P: TStreamable; S: TStream);
begin
  calcwin.TCalcWindow(P).Store(S);
end;

function Build_RCalcView(S: TStream): TStreamable;
begin
  Result := TStreamable(calcwin.TCalcView.Load(S));
end;

procedure Store_RCalcView(P: TStreamable; S: TStream);
begin
  calcwin.TCalcView(P).Store(S);
end;

function Build_RCalcInfo(S: TStream): TStreamable;
begin
  Result := TStreamable(calcwin.TCalcInput.Load(S));
end;

procedure Store_RCalcInfo(P: TStreamable; S: TStream);
begin
  calcwin.TCalcInput(P).Store(S);
end;

function Build_RInfoView(S: TStream): TStreamable;
begin
  Result := TStreamable(calcwin.TInfoView.Load(S));
end;

procedure Store_RInfoView(P: TStreamable; S: TStream);
begin
  calcwin.TInfoView(P).Store(S);
end;

function Build_RCellCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(CellsCol.TCellCollection.Load(S));
end;

procedure Store_RCellCollection(P: TStreamable; S: TStream);
begin
  CellsCol.TCellCollection(P).Store(S);
end;

function Build_RCalendarView(S: TStream): TStreamable;
begin
  Result := TStreamable(Calendar.TCalendarView.Load(S));
end;

procedure Store_RCalendarView(P: TStreamable; S: TStream);
begin
  Calendar.TCalendarView(P).Store(S);
end;

function Build_RCalendarWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(Calendar.TCalendarWindow.Load(S));
end;

procedure Store_RCalendarWindow(P: TStreamable; S: TStream);
begin
  Calendar.TCalendarWindow(P).Store(S);
end;

function Build_RCalcLine(S: TStream): TStreamable;
begin
  Result := TStreamable(calcline.TCalcLine.Load(S));
end;

procedure Store_RCalcLine(P: TStreamable; S: TStream);
begin
  calcline.TCalcLine(P).Store(S);
end;

function Build_RIndicator(S: TStream): TStreamable;
begin
  Result := TStreamable(calcline.TIndicator.Load(S));
end;

procedure Store_RIndicator(P: TStreamable; S: TStream);
begin
  calcline.TIndicator(P).Store(S);
end;

function Build_RCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Collect.TCollection.Load(S));
end;

procedure Store_RCollection(P: TStreamable; S: TStream);
begin
  Collect.TCollection(P).Store(S);
end;

function Build_RLineCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Collect.TLineCollection.Load(S));
end;

procedure Store_RLineCollection(P: TStreamable; S: TStream);
begin
  Collect.TLineCollection(P).Store(S);
end;

function Build_RStringCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Collect.TStringCollection.Load(S));
end;

procedure Store_RStringCollection(P: TStreamable; S: TStream);
begin
  Collect.TStringCollection(P).Store(S);
end;

function Build_RStrCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Collect.TStrCollection.Load(S));
end;

procedure Store_RStrCollection(P: TStreamable; S: TStream);
begin
  Collect.TStrCollection(P).Store(S);
end;

function Build_RStringList(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStrL.TStringList.Load(S));
end;

function Build_RColorSelector(S: TStream): TStreamable;
begin
  Result := TStreamable(ColorSel.TColorSelector.Load(S));
end;

procedure Store_RColorSelector(P: TStreamable; S: TStream);
begin
  ColorSel.TColorSelector(P).Store(S);
end;

function Build_RMonoSelector(S: TStream): TStreamable;
begin
  Result := TStreamable(ColorSel.TMonoSelector.Load(S));
end;

procedure Store_RMonoSelector(P: TStreamable; S: TStream);
begin
  ColorSel.TMonoSelector(P).Store(S);
end;

function Build_RColorDisplay(S: TStream): TStreamable;
begin
  Result := TStreamable(ColorSel.TColorDisplay.Load(S));
end;

procedure Store_RColorDisplay(P: TStreamable; S: TStream);
begin
  ColorSel.TColorDisplay(P).Store(S);
end;

function Build_RColorGroupList(S: TStream): TStreamable;
begin
  Result := TStreamable(ColorSel.TColorGroupList.Load(S));
end;

procedure Store_RColorGroupList(P: TStreamable; S: TStream);
begin
  ColorSel.TColorGroupList(P).Store(S);
end;

function Build_RColorItemList(S: TStream): TStreamable;
begin
  Result := TStreamable(ColorSel.TColorItemList.Load(S));
end;

procedure Store_RColorItemList(P: TStreamable; S: TStream);
begin
  ColorSel.TColorItemList(P).Store(S);
end;

function Build_RColorDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(ColorSel.TColorDialog.Load(S));
end;

procedure Store_RColorDialog(P: TStreamable; S: TStream);
begin
  ColorSel.TColorDialog(P).Store(S);
end;

function Build_RR_BWSelector(S: TStream): TStreamable;
begin
  Result := TStreamable(bwselect.T_BWSelector.Load(S));
end;

procedure Store_RR_BWSelector(P: TStreamable; S: TStream);
begin
  bwselect.T_BWSelector(P).Store(S);
end;

function Build_RDBWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(DBView.TDBWindow.Load(S));
end;

procedure Store_RDBWindow(P: TStreamable; S: TStream);
begin
  DBView.TDBWindow(P).Store(S);
end;

function Build_RDBViewer(S: TStream): TStreamable;
begin
  Result := TStreamable(DBView.TDBViewer.Load(S));
end;

procedure Store_RDBViewer(P: TStreamable; S: TStream);
begin
  DBView.TDBViewer(P).Store(S);
end;

function Build_RDBIndicator(S: TStream): TStreamable;
begin
  Result := TStreamable(DBView.TDBIndicator.Load(S));
end;

procedure Store_RDBIndicator(P: TStreamable; S: TStream);
begin
  DBView.TDBIndicator(P).Store(S);
end;

function Build_RFieldListBox(S: TStream): TStreamable;
begin
  Result := TStreamable(DBView.TFieldListBox.Load(S));
end;

procedure Store_RFieldListBox(P: TStreamable; S: TStream);
begin
  DBView.TFieldListBox(P).Store(S);
end;

function Build_RDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TDialog.Load(S));
end;

procedure Store_RDialog(P: TStreamable; S: TStream);
begin
  Dialogs.TDialog(P).Store(S);
end;

function Build_RInputLine(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TInputLine.Load(S));
end;

procedure Store_RInputLine(P: TStreamable; S: TStream);
begin
  Dialogs.TInputLine(P).Store(S);
end;

function Build_RHexLine(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.THexLine.Load(S));
end;

procedure Store_RHexLine(P: TStreamable; S: TStream);
begin
  DNDlgs.THexLine(P).Store(S);
end;

function Build_RLongInputLine(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TLongInputLine.Load(S));
end;

procedure Store_RLongInputLine(P: TStreamable; S: TStream);
begin
  Dialogs.TLongInputLine(P).Store(S);
end;

function Build_RButton(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TButton.Load(S));
end;

procedure Store_RButton(P: TStreamable; S: TStream);
begin
  Dialogs.TButton(P).Store(S);
end;

function Build_RCluster(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TCluster.Load(S));
end;

procedure Store_RCluster(P: TStreamable; S: TStream);
begin
  Dialogs.TCluster(P).Store(S);
end;

function Build_RRadioButtons(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TRadioButtons.Load(S));
end;

procedure Store_RRadioButtons(P: TStreamable; S: TStream);
begin
  Dialogs.TRadioButtons(P).Store(S);
end;

function Build_RComboBox(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TComboBox.Load(S));
end;

procedure Store_RComboBox(P: TStreamable; S: TStream);
begin
  DNDlgs.TComboBox(P).Store(S);
end;

function Build_RCheckBoxes(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TCheckBoxes.Load(S));
end;

procedure Store_RCheckBoxes(P: TStreamable; S: TStream);
begin
  Dialogs.TCheckBoxes(P).Store(S);
end;

function Build_RMultiCheckBoxes(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TMultiCheckBoxes.Load(S));
end;

procedure Store_RMultiCheckBoxes(P: TStreamable; S: TStream);
begin
  Dialogs.TMultiCheckBoxes(P).Store(S);
end;

function Build_RListBox(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TListBox.Load(S));
end;

procedure Store_RListBox(P: TStreamable; S: TStream);
begin
  Dialogs.TListBox(P).Store(S);
end;

function Build_RStaticText(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TStaticText.Load(S));
end;

procedure Store_RStaticText(P: TStreamable; S: TStream);
begin
  Dialogs.TStaticText(P).Store(S);
end;

function Build_RLabel(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.TLabel.Load(S));
end;

procedure Store_RLabel(P: TStreamable; S: TStream);
begin
  Dialogs.TLabel(P).Store(S);
end;

function Build_RHistory(S: TStream): TStreamable;
begin
  Result := TStreamable(Dialogs.THistory.Load(S));
end;

procedure Store_RHistory(P: TStreamable; S: TStream);
begin
  Dialogs.THistory(P).Store(S);
end;

function Build_RParamText(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TParamText.Load(S));
end;

procedure Store_RParamText(P: TStreamable; S: TStream);
begin
  DNDlgs.TParamText(P).Store(S);
end;

function Build_RNotepad(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TNotepad.Load(S));
end;

procedure Store_RNotepad(P: TStreamable; S: TStream);
begin
  DNDlgs.TNotepad(P).Store(S);
end;

function Build_RPage(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TPage.Load(S));
end;

procedure Store_RPage(P: TStreamable; S: TStream);
begin
  DNDlgs.TPage(P).Store(S);
end;

function Build_RBookmark(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TBookmark.Load(S));
end;

procedure Store_RBookmark(P: TStreamable; S: TStream);
begin
  DNDlgs.TBookmark(P).Store(S);
end;

function Build_RPageFrame(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TPageFrame.Load(S));
end;

procedure Store_RPageFrame(P: TStreamable; S: TStream);
begin
  DNDlgs.TPageFrame(P).Store(S);
end;

function Build_RNotepadFrame(S: TStream): TStreamable;
begin
  Result := TStreamable(DNDlgs.TNotepadFrame.Load(S));
end;

procedure Store_RNotepadFrame(P: TStreamable; S: TStream);
begin
  DNDlgs.TNotepadFrame(P).Store(S);
end;

function Build_RDiskInfo(S: TStream): TStreamable;
begin
  Result := TStreamable(DiskInfo.TDiskInfo.Load(S));
end;

procedure Store_RDiskInfo(P: TStreamable; S: TStream);
begin
  DiskInfo.TDiskInfo(P).Store(S);
end;

function Build_RDriveView(S: TStream): TStreamable;
begin
  Result := TStreamable(DiskInfo.TDriveView.Load(S));
end;

procedure Store_RDriveView(P: TStreamable; S: TStream);
begin
  DiskInfo.TDriveView(P).Store(S);
end;

function Build_RBackground(S: TStream): TStreamable;
begin
  Result := TStreamable(mainapp.TBackground.Load(S));
end;

procedure Store_RBackground(P: TStreamable; S: TStream);
begin
  mainapp.TBackground(P).Store(S);
end;

function Build_RDesktop(S: TStream): TStreamable;
begin
  Result := TStreamable(mainapp.TDesktop.Load(S));
end;

procedure Store_RDesktop(P: TStreamable; S: TStream);
begin
  mainapp.TDesktop(P).Store(S);
end;

function Build_RFileInputLine(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStdDlg.TFileInputLine.Load(S));
end;

procedure Store_RFileInputLine(P: TStreamable; S: TStream);
begin
  DNStdDlg.TFileInputLine(P).Store(S);
end;

function Build_RFileCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStdDlg.TFileCollection.Load(S));
end;

procedure Store_RFileCollection(P: TStreamable; S: TStream);
begin
  DNStdDlg.TFileCollection(P).Store(S);
end;

function Build_RFileList(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStdDlg.TFileList.Load(S));
end;

procedure Store_RFileList(P: TStreamable; S: TStream);
begin
  DNStdDlg.TFileList(P).Store(S);
end;

function Build_RFileInfoPane(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStdDlg.TFileInfoPane.Load(S));
end;

procedure Store_RFileInfoPane(P: TStreamable; S: TStream);
begin
  DNStdDlg.TFileInfoPane(P).Store(S);
end;

function Build_RFileDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStdDlg.TFileDialog.Load(S));
end;

procedure Store_RFileDialog(P: TStreamable; S: TStream);
begin
  DNStdDlg.TFileDialog(P).Store(S);
end;

function Build_RSortedListBox(S: TStream): TStreamable;
begin
  Result := TStreamable(DNStdDlg.TSortedListBox.Load(S));
end;

procedure Store_RSortedListBox(P: TStreamable; S: TStream);
begin
  DNStdDlg.TSortedListBox(P).Store(S);
end;

function Build_RDataSaver(S: TStream): TStreamable;
begin
  Result := TStreamable(DNUtil.TDataSaver.Load(S));
end;

procedure Store_RDataSaver(P: TStreamable; S: TStream);
begin
  DNUtil.TDataSaver(P).Store(S);
end;

function Build_RDrive(S: TStream): TStreamable;
begin
  Result := TStreamable(Drives.TDrive.Load(S));
end;

procedure Store_RDrive(P: TStreamable; S: TStream);
begin
  Drives.TDrive(P).Store(S);
end;

function Build_RInfoLine(S: TStream): TStreamable;
begin
  Result := TStreamable(editundo.TInfoLine.Load(S));
end;

procedure Store_RInfoLine(P: TStreamable; S: TStream);
begin
  editundo.TInfoLine(P).Store(S);
end;

function Build_RBookLine(S: TStream): TStreamable;
begin
  Result := TStreamable(editundo.TBookmarkLine.Load(S));
end;

procedure Store_RBookLine(P: TStreamable; S: TStream);
begin
  editundo.TBookmarkLine(P).Store(S);
end;

function Build_RXFileEditor(S: TStream): TStreamable;
begin
  Result := TStreamable(Editor.TXFileEditor.Load(S));
end;

procedure Store_RXFileEditor(P: TStreamable; S: TStream);
begin
  Editor.TXFileEditor(P).Store(S);
end;

function Build_RFindDrive(S: TStream): TStreamable;
begin
  Result := TStreamable(FileFind.TFindDrive.Load(S));
end;

procedure Store_RFindDrive(P: TStreamable; S: TStream);
begin
  FileFind.TFindDrive(P).Store(S);
end;

function Build_RTempDrive(S: TStream): TStreamable;
begin
  Result := TStreamable(FileFind.TTempDrive.Load(S));
end;

procedure Store_RTempDrive(P: TStreamable; S: TStream);
begin
  FileFind.TTempDrive(P).Store(S);
end;

function Build_RFilesCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(FilesCol.TFilesCollection.Load(S));
end;

procedure Store_RFilesCollection(P: TStreamable; S: TStream);
begin
  FilesCol.TFilesCollection(P).Store(S);
end;

function Build_RFilePanel(S: TStream): TStreamable;
begin
  Result := TStreamable(filepanel.TFilePanel.Load(S));
end;

procedure Store_RFilePanel(P: TStreamable; S: TStream);
begin
  filepanel.TFilePanel(P).Store(S);
end;

function Build_RFlPInfoView(S: TStream): TStreamable;
begin
  Result := TStreamable(filepanel.TInfoView.Load(S));
end;

procedure Store_RFlPInfoView(P: TStreamable; S: TStream);
begin
  filepanel.TInfoView(P).Store(S);
end;

function Build_RDirView(S: TStream): TStreamable;
begin
  Result := TStreamable(filepanel.TDirView.Load(S));
end;

procedure Store_RDirView(P: TStreamable; S: TStream);
begin
  filepanel.TDirView(P).Store(S);
end;

function Build_RSortView(S: TStream): TStreamable;
begin
  Result := TStreamable(topview.TSortView.Load(S));
end;

procedure Store_RSortView(P: TStreamable; S: TStream);
begin
  topview.TSortView(P).Store(S);
end;

function Build_RSeparator(S: TStream): TStreamable;
begin
  Result := TStreamable(panelwin.TSeparator.Load(S));
end;

procedure Store_RSeparator(P: TStreamable; S: TStream);
begin
  panelwin.TSeparator(P).Store(S);
end;

function Build_RDriveLine(S: TStream): TStreamable;
begin
  Result := TStreamable(filepanel.TDriveLine.Load(S));
end;

procedure Store_RDriveLine(P: TStreamable; S: TStream);
begin
  filepanel.TDriveLine(P).Store(S);
end;

function Build_RDirStorage(S: TStream): TStreamable;
begin
  Result := TStreamable(FStorage.TDirStorage.Load(S));
end;

procedure Store_RDirStorage(P: TStreamable; S: TStream);
begin
  FStorage.TDirStorage(P).Store(S);
end;

function Build_RFileViewer(S: TStream): TStreamable;
begin
  Result := TStreamable(FViewer.TFileViewer.Load(S));
end;

procedure Store_RFileViewer(P: TStreamable; S: TStream);
begin
  FViewer.TFileViewer(P).Store(S);
end;

function Build_RFileWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(FViewer.TFileWindow.Load(S));
end;

procedure Store_RFileWindow(P: TStreamable; S: TStream);
begin
  FViewer.TFileWindow(P).Store(S);
end;

function Build_RViewScroll(S: TStream): TStreamable;
begin
  Result := TStreamable(FViewer.TViewScroll.Load(S));
end;

procedure Store_RViewScroll(P: TStreamable; S: TStream);
begin
  FViewer.TViewScroll(P).Store(S);
end;

function Build_RQFileViewer(S: TStream): TStreamable;
begin
  Result := TStreamable(FViewer.TQFileViewer.Load(S));
end;

procedure Store_RQFileViewer(P: TStreamable; S: TStream);
begin
  FViewer.TQFileViewer(P).Store(S);
end;

function Build_RDFileViewer(S: TStream): TStreamable;
begin
  Result := TStreamable(FViewer.TDFileViewer.Load(S));
end;

procedure Store_RDFileViewer(P: TStreamable; S: TStream);
begin
  FViewer.TDFileViewer(P).Store(S);
end;

function Build_RViewInfo(S: TStream): TStreamable;
begin
  Result := TStreamable(FViewer.TViewInfo.Load(S));
end;

procedure Store_RViewInfo(P: TStreamable; S: TStream);
begin
  FViewer.TViewInfo(P).Store(S);
end;

function Build_RTrashCan(S: TStream): TStreamable;
begin
  Result := TStreamable(gadgets.TTrashCan.Load(S));
end;

procedure Store_RTrashCan(P: TStreamable; S: TStream);
begin
  gadgets.TTrashCan(P).Store(S);
end;

function Build_RKeyMacros(S: TStream): TStreamable;
begin
  Result := TStreamable(gadgets.TKeyMacros.Load(S));
end;

procedure Store_RKeyMacros(P: TStreamable; S: TStream);
begin
  gadgets.TKeyMacros(P).Store(S);
end;

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

function Build_REditHistoryCol(S: TStream): TStreamable;
begin
  Result := TStreamable(histories.TEditHistoryCol.Load(S));
end;

procedure Store_REditHistoryCol(P: TStreamable; S: TStream);
begin
  histories.TEditHistoryCol(P).Store(S);
end;

function Build_RViewHistoryCol(S: TStream): TStreamable;
begin
  Result := TStreamable(histories.TViewHistoryCol.Load(S));
end;

procedure Store_RViewHistoryCol(P: TStreamable; S: TStream);
begin
  histories.TViewHistoryCol(P).Store(S);
end;

function Build_RMenuBar(S: TStream): TStreamable;
begin
  Result := TStreamable(Menus.TMenuBar.Load(S));
end;

procedure Store_RMenuBar(P: TStreamable; S: TStream);
begin
  Menus.TMenuBar(P).Store(S);
end;

function Build_RMenuBox(S: TStream): TStreamable;
begin
  Result := TStreamable(Menus.TMenuBox.Load(S));
end;

procedure Store_RMenuBox(P: TStreamable; S: TStream);
begin
  Menus.TMenuBox(P).Store(S);
end;

function Build_RStatusLine(S: TStream): TStreamable;
begin
  Result := TStreamable(Menus.TStatusLine.Load(S));
end;

procedure Store_RStatusLine(P: TStreamable; S: TStream);
begin
  Menus.TStatusLine(P).Store(S);
end;

function Build_RMenuPopup(S: TStream): TStreamable;
begin
  Result := TStreamable(Menus.TMenuPopup.Load(S));
end;

procedure Store_RMenuPopup(P: TStreamable; S: TStream);
begin
  Menus.TMenuPopup(P).Store(S);
end;

function Build_RFileEditor(S: TStream): TStreamable;
begin
  Result := TStreamable(editcore.TFileEditor.Load(S));
end;

procedure Store_RFileEditor(P: TStreamable; S: TStream);
begin
  editcore.TFileEditor(P).Store(S);
end;

function Build_REditWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(editwin.TEditWindow.Load(S));
end;

procedure Store_REditWindow(P: TStreamable; S: TStream);
begin
  editwin.TEditWindow(P).Store(S);
end;

function Build_RDStringView(S: TStream): TStreamable;
begin
  Result := TStreamable(StrView.TDStringView.Load(S));
end;

procedure Store_RDStringView(P: TStreamable; S: TStream);
begin
  StrView.TDStringView(P).Store(S);
end;

function Build_RPhone(S: TStream): TStreamable;
begin
  Result := TStreamable(Phones.TPhone.Load(S));
end;

procedure Store_RPhone(P: TStreamable; S: TStream);
begin
  Phones.TPhone(P).Store(S);
end;

function Build_RPhoneDir(S: TStream): TStreamable;
begin
  Result := TStreamable(Phones.TPhoneDir.Load(S));
end;

procedure Store_RPhoneDir(P: TStreamable; S: TStream);
begin
  Phones.TPhoneDir(P).Store(S);
end;

function Build_RPhoneCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Phones.TPhoneCollection.Load(S));
end;

procedure Store_RPhoneCollection(P: TStreamable; S: TStream);
begin
  Phones.TPhoneCollection(P).Store(S);
end;

function Build_RStringCol(S: TStream): TStreamable;
begin
  Result := TStreamable(PrintMan.TStringCol.Load(S));
end;

procedure Store_RStringCol(P: TStreamable; S: TStream);
begin
  PrintMan.TStringCol(P).Store(S);
end;

function Build_RPrintManager(S: TStream): TStreamable;
begin
  Result := TStreamable(PrintMan.TPrintManager.Load(S));
end;

procedure Store_RPrintManager(P: TStreamable; S: TStream);
begin
  PrintMan.TPrintManager(P).Store(S);
end;

function Build_RPrintStatus(S: TStream): TStreamable;
begin
  Result := TStreamable(PrintMan.TPrintStatus.Load(S));
end;

procedure Store_RPrintStatus(P: TStreamable; S: TStream);
begin
  PrintMan.TPrintStatus(P).Store(S);
end;

function Build_RPMWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(PrintMan.TPMWindow.Load(S));
end;

procedure Store_RPMWindow(P: TStreamable; S: TStream);
begin
  PrintMan.TPMWindow(P).Store(S);
end;

function Build_RScroller(S: TStream): TStreamable;
begin
  Result := TStreamable(Scroller.TScroller.Load(S));
end;

procedure Store_RScroller(P: TStreamable; S: TStream);
begin
  Scroller.TScroller(P).Store(S);
end;

function Build_RListViewer(S: TStream): TStreamable;
begin
  Result := TStreamable(Scroller.TListViewer.Load(S));
end;

procedure Store_RListViewer(P: TStreamable; S: TStream);
begin
  Scroller.TListViewer(P).Store(S);
end;

function Build_RSysDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(Setups.TSysDialog.Load(S));
end;

procedure Store_RSysDialog(P: TStreamable; S: TStream);
begin
  Setups.TSysDialog(P).Store(S);
end;

function Build_RCurrDriveInfo(S: TStream): TStreamable;
begin
  Result := TStreamable(Setups.TCurrDriveInfo.Load(S));
end;

procedure Store_RCurrDriveInfo(P: TStreamable; S: TStream);
begin
  Setups.TCurrDriveInfo(P).Store(S);
end;

function Build_RMouseBar(S: TStream): TStreamable;
begin
  Result := TStreamable(Setups.TMouseBar.Load(S));
end;

procedure Store_RMouseBar(P: TStreamable; S: TStream);
begin
  Setups.TMouseBar(P).Store(S);
end;

function Build_RSaversDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(Setups.TSaversDialog.Load(S));
end;

procedure Store_RSaversDialog(P: TStreamable; S: TStream);
begin
  Setups.TSaversDialog(P).Store(S);
end;

function Build_RSaversListBox(S: TStream): TStreamable;
begin
  Result := TStreamable(Setups.TSaversListBox.Load(S));
end;

procedure Store_RSaversListBox(P: TStreamable; S: TStream);
begin
  Setups.TSaversListBox(P).Store(S);
end;

function Build_RTextCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(dlgrecs.TTextCollection.Load(S));
end;

procedure Store_RTextCollection(P: TStreamable; S: TStream);
begin
  dlgrecs.TTextCollection(P).Store(S);
end;

function Build_RGameWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(Tetris.TGameWindow.Load(S));
end;

procedure Store_RGameWindow(P: TStreamable; S: TStream);
begin
  Tetris.TGameWindow(P).Store(S);
end;

function Build_RGameView(S: TStream): TStreamable;
begin
  Result := TStreamable(Tetris.TGameView.Load(S));
end;

procedure Store_RGameView(P: TStreamable; S: TStream);
begin
  Tetris.TGameView(P).Store(S);
end;

function Build_RGameInfo(S: TStream): TStreamable;
begin
  Result := TStreamable(Tetris.TGameInfo.Load(S));
end;

procedure Store_RGameInfo(P: TStreamable; S: TStream);
begin
  Tetris.TGameInfo(P).Store(S);
end;

function Build_RTreeView(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TTreeView.Load(S));
end;

procedure Store_RTreeView(P: TStreamable; S: TStream);
begin
  Tree.TTreeView(P).Store(S);
end;

function Build_RTreeReader(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TTreeReader.Load(S));
end;

procedure Store_RTreeReader(P: TStreamable; S: TStream);
begin
  Tree.TTreeReader(P).Store(S);
end;

function Build_RTreeWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TTreeWindow.Load(S));
end;

procedure Store_RTreeWindow(P: TStreamable; S: TStream);
begin
  Tree.TTreeWindow(P).Store(S);
end;

function Build_RTreePanel(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TTreePanel.Load(S));
end;

procedure Store_RTreePanel(P: TStreamable; S: TStream);
begin
  Tree.TTreePanel(P).Store(S);
end;

function Build_RTreeDialog(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TTreeDialog.Load(S));
end;

procedure Store_RTreeDialog(P: TStreamable; S: TStream);
begin
  Tree.TTreeDialog(P).Store(S);
end;

function Build_RTreeInfoView(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TTreeInfoView.Load(S));
end;

procedure Store_RTreeInfoView(P: TStreamable; S: TStream);
begin
  Tree.TTreeInfoView(P).Store(S);
end;

function Build_RHTreeView(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.THTreeView.Load(S));
end;

procedure Store_RHTreeView(P: TStreamable; S: TStream);
begin
  Tree.THTreeView(P).Store(S);
end;

function Build_RDirCollection(S: TStream): TStreamable;
begin
  Result := TStreamable(Tree.TDirCollection.Load(S));
end;

procedure Store_RDirCollection(P: TStreamable; S: TStream);
begin
  Tree.TDirCollection(P).Store(S);
end;

function Build_REditScrollBar(S: TStream): TStreamable;
begin
  Result := TStreamable(UniWin.TEditScrollBar.Load(S));
end;

procedure Store_REditScrollBar(P: TStreamable; S: TStream);
begin
  UniWin.TEditScrollBar(P).Store(S);
end;

function Build_REditFrame(S: TStream): TStreamable;
begin
  Result := TStreamable(UniWin.TEditFrame.Load(S));
end;

procedure Store_REditFrame(P: TStreamable; S: TStream);
begin
  UniWin.TEditFrame(P).Store(S);
end;

function Build_RUserWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(UserMenu.TUserWindow.Load(S));
end;

procedure Store_RUserWindow(P: TStreamable; S: TStream);
begin
  UserMenu.TUserWindow(P).Store(S);
end;

function Build_RUserView(S: TStream): TStreamable;
begin
  Result := TStreamable(UserMenu.TUserView.Load(S));
end;

procedure Store_RUserView(P: TStreamable; S: TStream);
begin
  UserMenu.TUserView(P).Store(S);
end;

function Build_RMyScrollBar(S: TStream): TStreamable;
begin
  Result := TStreamable(Views.TMyScrollBar.Load(S));
end;

procedure Store_RMyScrollBar(P: TStreamable; S: TStream);
begin
  Views.TMyScrollBar(P).Store(S);
end;

function Build_RDoubleWindow(S: TStream): TStreamable;
begin
  Result := TStreamable(panelwinx.TXDoubleWindow.Load(S));
end;

procedure Store_RDoubleWindow(P: TStreamable; S: TStream);
begin
  panelwinx.TXDoubleWindow(P).Store(S);
end;

function Build_RColorPoint(S: TStream): TStreamable;
begin
  Result := TStreamable(inputfname.TColorPoint.Load(S));
end;

procedure Store_RColorPoint(P: TStreamable; S: TStream);
begin
  inputfname.TColorPoint(P).Store(S);
end;

procedure SetStreamRecs_regall;
begin

  RFilterValidator.VmtLink := PtrUInt(System.TClass(Validate.TFilterValidator));
  RFilterValidator.Load := @Build_RFilterValidator;

  RFilterValidator.Store := @Store_RFilterValidator;

  RRangeValidator.VmtLink := PtrUInt(System.TClass(Validate.TRangeValidator));
  RRangeValidator.Load := @Build_RRangeValidator;

  RRangeValidator.Store := @Store_RRangeValidator;

  RView.VmtLink := PtrUInt(System.TClass(Views.TView));
  RView.Load := @Build_RView;

  RView.Store := @Store_RView;

  RFrame.VmtLink := PtrUInt(System.TClass(Views.TFrame));
  RFrame.Load := @Build_RFrame;

  RFrame.Store := @Store_RFrame;

  RScrollBar.VmtLink := PtrUInt(System.TClass(Views.TScrollBar));
  RScrollBar.Load := @Build_RScrollBar;

  RScrollBar.Store := @Store_RScrollBar;

  RGroup.VmtLink := PtrUInt(System.TClass(Views.TGroup));
  RGroup.Load := @Build_RGroup;

  RGroup.Store := @Store_RGroup;

  RWindow.VmtLink := PtrUInt(System.TClass(Views.TWindow));
  RWindow.Load := @Build_RWindow;

  RWindow.Store := @Store_RWindow;

  RZIPArchiver.VmtLink := PtrUInt(System.TClass(fmtzip.TZIPArchive));
  RZIPArchiver.Load := @Build_RZIPArchiver;

  RZIPArchiver.Store := @Store_RZIPArchiver;

  RLHAArchiver.VmtLink := PtrUInt(System.TClass(fmtlha.TLHAArchive));
  RLHAArchiver.Load := @Build_RLHAArchiver;

  RLHAArchiver.Store := @Store_RLHAArchiver;

  RRARArchiver.VmtLink := PtrUInt(System.TClass(fmtrar.TRARArchive));
  RRARArchiver.Load := @Build_RRARArchiver;

  RRARArchiver.Store := @Store_RRARArchiver;

  RCABArchiver.VmtLink := PtrUInt(System.TClass(fmtcab.TCABArchive));
  RCABArchiver.Load := @Build_RCABArchiver;

  RCABArchiver.Store := @Store_RCABArchiver;

  RACEArchiver.VmtLink := PtrUInt(System.TClass(fmtace.TACEArchive));
  RACEArchiver.Load := @Build_RACEArchiver;

  RACEArchiver.Store := @Store_RACEArchiver;

  RHAArchiver.VmtLink := PtrUInt(System.TClass(fmtha.THAArchive));
  RHAArchiver.Load := @Build_RHAArchiver;

  RHAArchiver.Store := @Store_RHAArchiver;

  RARCArchiver.VmtLink := PtrUInt(System.TClass(fmtarc.TARCArchive));
  RARCArchiver.Load := @Build_RARCArchiver;

  RARCArchiver.Store := @Store_RARCArchiver;

  RBSAArchiver.VmtLink := PtrUInt(System.TClass(fmtbsa.TBSAArchive));
  RBSAArchiver.Load := @Build_RBSAArchiver;

  RBSAArchiver.Store := @Store_RBSAArchiver;

  RBS2Archiver.VmtLink := PtrUInt(System.TClass(fmtbs2.TBS2Archive));
  RBS2Archiver.Load := @Build_RBS2Archiver;

  RBS2Archiver.Store := @Store_RBS2Archiver;

  RHYPArchiver.VmtLink := PtrUInt(System.TClass(fmthyp.THYPArchive));
  RHYPArchiver.Load := @Build_RHYPArchiver;

  RHYPArchiver.Store := @Store_RHYPArchiver;

  RLIMArchiver.VmtLink := PtrUInt(System.TClass(fmtlim.TLIMArchive));
  RLIMArchiver.Load := @Build_RLIMArchiver;

  RLIMArchiver.Store := @Store_RLIMArchiver;

  RHPKArchiver.VmtLink := PtrUInt(System.TClass(fmthpk.THPKArchive));
  RHPKArchiver.Load := @Build_RHPKArchiver;

  RHPKArchiver.Store := @Store_RHPKArchiver;

  RTARArchiver.VmtLink := PtrUInt(System.TClass(fmttar.TTARArchive));
  RTARArchiver.Load := @Build_RTARArchiver;

  RTARArchiver.Store := @Store_RTARArchiver;

  RTGZArchiver.VmtLink := PtrUInt(System.TClass(fmttgz.TTGZArchive));
  RTGZArchiver.Load := @Build_RTGZArchiver;

  RTGZArchiver.Store := @Store_RTGZArchiver;

  RZXZArchiver.VmtLink := PtrUInt(System.TClass(fmtzxz.TZXZArchive));
  RZXZArchiver.Load := @Build_RZXZArchiver;

  RZXZArchiver.Store := @Store_RZXZArchiver;

  RQUARKArchiver.VmtLink := PtrUInt(System.TClass(fmtqrk.TQuArkArchive));
  RQUARKArchiver.Load := @Build_RQUARKArchiver;

  RQUARKArchiver.Store := @Store_RQUARKArchiver;

  RUFAArchiver.VmtLink := PtrUInt(System.TClass(fmtufa.TUFAArchive));
  RUFAArchiver.Load := @Build_RUFAArchiver;

  RUFAArchiver.Store := @Store_RUFAArchiver;

  RIS3Archiver.VmtLink := PtrUInt(System.TClass(fmtis3.TIS3Archive));
  RIS3Archiver.Load := @Build_RIS3Archiver;

  RIS3Archiver.Store := @Store_RIS3Archiver;

  RSQZArchiver.VmtLink := PtrUInt(System.TClass(fmtsqz.TSQZArchive));
  RSQZArchiver.Load := @Build_RSQZArchiver;

  RSQZArchiver.Store := @Store_RSQZArchiver;

  RHAPArchiver.VmtLink := PtrUInt(System.TClass(fmthap.THAPArchive));
  RHAPArchiver.Load := @Build_RHAPArchiver;

  RHAPArchiver.Store := @Store_RHAPArchiver;

  RZOOArchiver.VmtLink := PtrUInt(System.TClass(fmtzoo.TZOOArchive));
  RZOOArchiver.Load := @Build_RZOOArchiver;

  RZOOArchiver.Store := @Store_RZOOArchiver;

  RCHZArchiver.VmtLink := PtrUInt(System.TClass(fmtchz.TCHZArchive));
  RCHZArchiver.Load := @Build_RCHZArchiver;

  RCHZArchiver.Store := @Store_RCHZArchiver;

  RUC2Archiver.VmtLink := PtrUInt(System.TClass(fmtuc2.TUC2Archive));
  RUC2Archiver.Load := @Build_RUC2Archiver;

  RUC2Archiver.Store := @Store_RUC2Archiver;

  RAINArchiver.VmtLink := PtrUInt(System.TClass(fmtain.TAINArchive));
  RAINArchiver.Load := @Build_RAINArchiver;

  RAINArchiver.Store := @Store_RAINArchiver;

  RS7ZArchiver.VmtLink := PtrUInt(System.TClass(fmt7z.TS7ZArchive));
  RS7ZArchiver.Load := @Build_RS7ZArchiver;

  RS7ZArchiver.Store := @Store_RS7ZArchiver;

  RBZ2Archiver.VmtLink := PtrUInt(System.TClass(fmtbz2.TBZ2Archive));
  RBZ2Archiver.Load := @Build_RBZ2Archiver;

  RBZ2Archiver.Store := @Store_RBZ2Archiver;

  RARJArchiver.VmtLink := PtrUInt(System.TClass(Archiver.TARJArchive));
  RARJArchiver.Load := @Build_RARJArchiver;

  RARJArchiver.Store := @Store_RARJArchiver;

  RFileInfo.VmtLink := PtrUInt(System.TClass(Archiver.TFileInfo));
  RFileInfo.Load := @Build_RFileInfo;

  RFileInfo.Store := @Store_RFileInfo;

  RArcDrive.VmtLink := PtrUInt(System.TClass(ArcView.TArcDrive));
  RArcDrive.Load := @Build_RArcDrive;

  RArcDrive.Store := @Store_RArcDrive;

  RArvidDrive.VmtLink := PtrUInt(System.TClass(Arvid.TArvidDrive));
  RArvidDrive.Load := @Build_RArvidDrive;

  RArvidDrive.Store := @Store_RArvidDrive;

  RTable.VmtLink := PtrUInt(System.TClass(ASCIITab.TTable));
  RTable.Load := @Build_RTable;

  RTable.Store := @Store_RTable;

  RReport.VmtLink := PtrUInt(System.TClass(ASCIITab.TReport));
  RReport.Load := @Build_RReport;

  RReport.Store := @Store_RReport;

  RASCIIChart.VmtLink := PtrUInt(System.TClass(ASCIITab.TASCIIChart));
  RASCIIChart.Load := @Build_RASCIIChart;

  RASCIIChart.Store := @Store_RASCIIChart;

  RCalcWindow.VmtLink := PtrUInt(System.TClass(calcwin.TCalcWindow));
  RCalcWindow.Load := @Build_RCalcWindow;

  RCalcWindow.Store := @Store_RCalcWindow;

  RCalcView.VmtLink := PtrUInt(System.TClass(calcwin.TCalcView));
  RCalcView.Load := @Build_RCalcView;

  RCalcView.Store := @Store_RCalcView;

  RCalcInfo.VmtLink := PtrUInt(System.TClass(calcwin.TCalcInput));
  RCalcInfo.Load := @Build_RCalcInfo;

  RCalcInfo.Store := @Store_RCalcInfo;

  RInfoView.VmtLink := PtrUInt(System.TClass(calcwin.TInfoView));
  RInfoView.Load := @Build_RInfoView;

  RInfoView.Store := @Store_RInfoView;

  RCellCollection.VmtLink := PtrUInt(System.TClass(CellsCol.TCellCollection));
  RCellCollection.Load := @Build_RCellCollection;

  RCellCollection.Store := @Store_RCellCollection;

  RCalendarView.VmtLink := PtrUInt(System.TClass(Calendar.TCalendarView));
  RCalendarView.Load := @Build_RCalendarView;

  RCalendarView.Store := @Store_RCalendarView;

  RCalendarWindow.VmtLink := PtrUInt(System.TClass(Calendar.TCalendarWindow));
  RCalendarWindow.Load := @Build_RCalendarWindow;

  RCalendarWindow.Store := @Store_RCalendarWindow;

  RCalcLine.VmtLink := PtrUInt(System.TClass(calcline.TCalcLine));
  RCalcLine.Load := @Build_RCalcLine;

  RCalcLine.Store := @Store_RCalcLine;

  RIndicator.VmtLink := PtrUInt(System.TClass(calcline.TIndicator));
  RIndicator.Load := @Build_RIndicator;

  RIndicator.Store := @Store_RIndicator;

  RCollection.VmtLink := PtrUInt(System.TClass(Collect.TCollection));
  RCollection.Load := @Build_RCollection;

  RCollection.Store := @Store_RCollection;

  RLineCollection.VmtLink := PtrUInt(System.TClass(Collect.TLineCollection));
  RLineCollection.Load := @Build_RLineCollection;

  RLineCollection.Store := @Store_RLineCollection;

  RStringCollection.VmtLink := PtrUInt(System.TClass(Collect.TStringCollection));
  RStringCollection.Load := @Build_RStringCollection;

  RStringCollection.Store := @Store_RStringCollection;

  RStrCollection.VmtLink := PtrUInt(System.TClass(Collect.TStrCollection));
  RStrCollection.Load := @Build_RStrCollection;

  RStrCollection.Store := @Store_RStrCollection;

  RStringList.VmtLink := PtrUInt(System.TClass(DNStrL.TStringList));
  RStringList.Load := @Build_RStringList;

  RColorSelector.VmtLink := PtrUInt(System.TClass(ColorSel.TColorSelector));
  RColorSelector.Load := @Build_RColorSelector;

  RColorSelector.Store := @Store_RColorSelector;

  RMonoSelector.VmtLink := PtrUInt(System.TClass(ColorSel.TMonoSelector));
  RMonoSelector.Load := @Build_RMonoSelector;

  RMonoSelector.Store := @Store_RMonoSelector;

  RColorDisplay.VmtLink := PtrUInt(System.TClass(ColorSel.TColorDisplay));
  RColorDisplay.Load := @Build_RColorDisplay;

  RColorDisplay.Store := @Store_RColorDisplay;

  RColorGroupList.VmtLink := PtrUInt(System.TClass(ColorSel.TColorGroupList));
  RColorGroupList.Load := @Build_RColorGroupList;

  RColorGroupList.Store := @Store_RColorGroupList;

  RColorItemList.VmtLink := PtrUInt(System.TClass(ColorSel.TColorItemList));
  RColorItemList.Load := @Build_RColorItemList;

  RColorItemList.Store := @Store_RColorItemList;

  RColorDialog.VmtLink := PtrUInt(System.TClass(ColorSel.TColorDialog));
  RColorDialog.Load := @Build_RColorDialog;

  RColorDialog.Store := @Store_RColorDialog;

  RR_BWSelector.VmtLink := PtrUInt(System.TClass(bwselect.T_BWSelector));
  RR_BWSelector.Load := @Build_RR_BWSelector;

  RR_BWSelector.Store := @Store_RR_BWSelector;

  RDBWindow.VmtLink := PtrUInt(System.TClass(DBView.TDBWindow));
  RDBWindow.Load := @Build_RDBWindow;

  RDBWindow.Store := @Store_RDBWindow;

  RDBViewer.VmtLink := PtrUInt(System.TClass(DBView.TDBViewer));
  RDBViewer.Load := @Build_RDBViewer;

  RDBViewer.Store := @Store_RDBViewer;

  RDBIndicator.VmtLink := PtrUInt(System.TClass(DBView.TDBIndicator));
  RDBIndicator.Load := @Build_RDBIndicator;

  RDBIndicator.Store := @Store_RDBIndicator;

  RFieldListBox.VmtLink := PtrUInt(System.TClass(DBView.TFieldListBox));
  RFieldListBox.Load := @Build_RFieldListBox;

  RFieldListBox.Store := @Store_RFieldListBox;

  RDialog.VmtLink := PtrUInt(System.TClass(Dialogs.TDialog));
  RDialog.Load := @Build_RDialog;

  RDialog.Store := @Store_RDialog;

  RInputLine.VmtLink := PtrUInt(System.TClass(Dialogs.TInputLine));
  RInputLine.Load := @Build_RInputLine;

  RInputLine.Store := @Store_RInputLine;

  RHexLine.VmtLink := PtrUInt(System.TClass(DNDlgs.THexLine));
  RHexLine.Load := @Build_RHexLine;

  RHexLine.Store := @Store_RHexLine;

  RLongInputLine.VmtLink := PtrUInt(System.TClass(Dialogs.TLongInputLine));
  RLongInputLine.Load := @Build_RLongInputLine;

  RLongInputLine.Store := @Store_RLongInputLine;

  RButton.VmtLink := PtrUInt(System.TClass(Dialogs.TButton));
  RButton.Load := @Build_RButton;

  RButton.Store := @Store_RButton;

  RCluster.VmtLink := PtrUInt(System.TClass(Dialogs.TCluster));
  RCluster.Load := @Build_RCluster;

  RCluster.Store := @Store_RCluster;

  RRadioButtons.VmtLink := PtrUInt(System.TClass(Dialogs.TRadioButtons));
  RRadioButtons.Load := @Build_RRadioButtons;

  RRadioButtons.Store := @Store_RRadioButtons;

  RComboBox.VmtLink := PtrUInt(System.TClass(DNDlgs.TComboBox));
  RComboBox.Load := @Build_RComboBox;

  RComboBox.Store := @Store_RComboBox;

  RCheckBoxes.VmtLink := PtrUInt(System.TClass(Dialogs.TCheckBoxes));
  RCheckBoxes.Load := @Build_RCheckBoxes;

  RCheckBoxes.Store := @Store_RCheckBoxes;

  RMultiCheckBoxes.VmtLink := PtrUInt(System.TClass(Dialogs.TMultiCheckBoxes));
  RMultiCheckBoxes.Load := @Build_RMultiCheckBoxes;

  RMultiCheckBoxes.Store := @Store_RMultiCheckBoxes;

  RListBox.VmtLink := PtrUInt(System.TClass(Dialogs.TListBox));
  RListBox.Load := @Build_RListBox;

  RListBox.Store := @Store_RListBox;

  RStaticText.VmtLink := PtrUInt(System.TClass(Dialogs.TStaticText));
  RStaticText.Load := @Build_RStaticText;

  RStaticText.Store := @Store_RStaticText;

  RLabel.VmtLink := PtrUInt(System.TClass(Dialogs.TLabel));
  RLabel.Load := @Build_RLabel;

  RLabel.Store := @Store_RLabel;

  RHistory.VmtLink := PtrUInt(System.TClass(Dialogs.THistory));
  RHistory.Load := @Build_RHistory;

  RHistory.Store := @Store_RHistory;

  RParamText.VmtLink := PtrUInt(System.TClass(DNDlgs.TParamText));
  RParamText.Load := @Build_RParamText;

  RParamText.Store := @Store_RParamText;

  RNotepad.VmtLink := PtrUInt(System.TClass(DNDlgs.TNotepad));
  RNotepad.Load := @Build_RNotepad;

  RNotepad.Store := @Store_RNotepad;

  RPage.VmtLink := PtrUInt(System.TClass(DNDlgs.TPage));
  RPage.Load := @Build_RPage;

  RPage.Store := @Store_RPage;

  RBookmark.VmtLink := PtrUInt(System.TClass(DNDlgs.TBookmark));
  RBookmark.Load := @Build_RBookmark;

  RBookmark.Store := @Store_RBookmark;

  RPageFrame.VmtLink := PtrUInt(System.TClass(DNDlgs.TPageFrame));
  RPageFrame.Load := @Build_RPageFrame;

  RPageFrame.Store := @Store_RPageFrame;

  RNotepadFrame.VmtLink := PtrUInt(System.TClass(DNDlgs.TNotepadFrame));
  RNotepadFrame.Load := @Build_RNotepadFrame;

  RNotepadFrame.Store := @Store_RNotepadFrame;

  RDiskInfo.VmtLink := PtrUInt(System.TClass(DiskInfo.TDiskInfo));
  RDiskInfo.Load := @Build_RDiskInfo;

  RDiskInfo.Store := @Store_RDiskInfo;

  RDriveView.VmtLink := PtrUInt(System.TClass(DiskInfo.TDriveView));
  RDriveView.Load := @Build_RDriveView;

  RDriveView.Store := @Store_RDriveView;

  RBackground.VmtLink := PtrUInt(System.TClass(mainapp.TBackground));
  RBackground.Load := @Build_RBackground;

  RBackground.Store := @Store_RBackground;

  RDesktop.VmtLink := PtrUInt(System.TClass(mainapp.TDesktop));
  RDesktop.Load := @Build_RDesktop;

  RDesktop.Store := @Store_RDesktop;

  RFileInputLine.VmtLink := PtrUInt(System.TClass(DNStdDlg.TFileInputLine));
  RFileInputLine.Load := @Build_RFileInputLine;

  RFileInputLine.Store := @Store_RFileInputLine;

  RFileCollection.VmtLink := PtrUInt(System.TClass(DNStdDlg.TFileCollection));
  RFileCollection.Load := @Build_RFileCollection;

  RFileCollection.Store := @Store_RFileCollection;

  RFileList.VmtLink := PtrUInt(System.TClass(DNStdDlg.TFileList));
  RFileList.Load := @Build_RFileList;

  RFileList.Store := @Store_RFileList;

  RFileInfoPane.VmtLink := PtrUInt(System.TClass(DNStdDlg.TFileInfoPane));
  RFileInfoPane.Load := @Build_RFileInfoPane;

  RFileInfoPane.Store := @Store_RFileInfoPane;

  RFileDialog.VmtLink := PtrUInt(System.TClass(DNStdDlg.TFileDialog));
  RFileDialog.Load := @Build_RFileDialog;

  RFileDialog.Store := @Store_RFileDialog;

  RSortedListBox.VmtLink := PtrUInt(System.TClass(DNStdDlg.TSortedListBox));
  RSortedListBox.Load := @Build_RSortedListBox;

  RSortedListBox.Store := @Store_RSortedListBox;

  RDataSaver.VmtLink := PtrUInt(System.TClass(DNUtil.TDataSaver));
  RDataSaver.Load := @Build_RDataSaver;

  RDataSaver.Store := @Store_RDataSaver;

  RDrive.VmtLink := PtrUInt(System.TClass(Drives.TDrive));
  RDrive.Load := @Build_RDrive;

  RDrive.Store := @Store_RDrive;

  RInfoLine.VmtLink := PtrUInt(System.TClass(editundo.TInfoLine));
  RInfoLine.Load := @Build_RInfoLine;

  RInfoLine.Store := @Store_RInfoLine;

  RBookLine.VmtLink := PtrUInt(System.TClass(editundo.TBookmarkLine));
  RBookLine.Load := @Build_RBookLine;

  RBookLine.Store := @Store_RBookLine;

  RXFileEditor.VmtLink := PtrUInt(System.TClass(Editor.TXFileEditor));
  RXFileEditor.Load := @Build_RXFileEditor;

  RXFileEditor.Store := @Store_RXFileEditor;

  RFindDrive.VmtLink := PtrUInt(System.TClass(FileFind.TFindDrive));
  RFindDrive.Load := @Build_RFindDrive;

  RFindDrive.Store := @Store_RFindDrive;

  RTempDrive.VmtLink := PtrUInt(System.TClass(FileFind.TTempDrive));
  RTempDrive.Load := @Build_RTempDrive;

  RTempDrive.Store := @Store_RTempDrive;

  RFilesCollection.VmtLink := PtrUInt(System.TClass(FilesCol.TFilesCollection));
  RFilesCollection.Load := @Build_RFilesCollection;

  RFilesCollection.Store := @Store_RFilesCollection;

  RFilePanel.VmtLink := PtrUInt(System.TClass(filepanel.TFilePanel));
  RFilePanel.Load := @Build_RFilePanel;

  RFilePanel.Store := @Store_RFilePanel;

  RFlPInfoView.VmtLink := PtrUInt(System.TClass(filepanel.TInfoView));
  RFlPInfoView.Load := @Build_RFlPInfoView;

  RFlPInfoView.Store := @Store_RFlPInfoView;

  RDirView.VmtLink := PtrUInt(System.TClass(filepanel.TDirView));
  RDirView.Load := @Build_RDirView;

  RDirView.Store := @Store_RDirView;

  RSortView.VmtLink := PtrUInt(System.TClass(topview.TSortView));
  RSortView.Load := @Build_RSortView;

  RSortView.Store := @Store_RSortView;

  RSeparator.VmtLink := PtrUInt(System.TClass(panelwin.TSeparator));
  RSeparator.Load := @Build_RSeparator;

  RSeparator.Store := @Store_RSeparator;

  RDriveLine.VmtLink := PtrUInt(System.TClass(filepanel.TDriveLine));
  RDriveLine.Load := @Build_RDriveLine;

  RDriveLine.Store := @Store_RDriveLine;

  RDirStorage.VmtLink := PtrUInt(System.TClass(FStorage.TDirStorage));
  RDirStorage.Load := @Build_RDirStorage;

  RDirStorage.Store := @Store_RDirStorage;

  RFileViewer.VmtLink := PtrUInt(System.TClass(FViewer.TFileViewer));
  RFileViewer.Load := @Build_RFileViewer;

  RFileViewer.Store := @Store_RFileViewer;

  RFileWindow.VmtLink := PtrUInt(System.TClass(FViewer.TFileWindow));
  RFileWindow.Load := @Build_RFileWindow;

  RFileWindow.Store := @Store_RFileWindow;

  RViewScroll.VmtLink := PtrUInt(System.TClass(FViewer.TViewScroll));
  RViewScroll.Load := @Build_RViewScroll;

  RViewScroll.Store := @Store_RViewScroll;

  RQFileViewer.VmtLink := PtrUInt(System.TClass(FViewer.TQFileViewer));
  RQFileViewer.Load := @Build_RQFileViewer;

  RQFileViewer.Store := @Store_RQFileViewer;

  RDFileViewer.VmtLink := PtrUInt(System.TClass(FViewer.TDFileViewer));
  RDFileViewer.Load := @Build_RDFileViewer;

  RDFileViewer.Store := @Store_RDFileViewer;

  RViewInfo.VmtLink := PtrUInt(System.TClass(FViewer.TViewInfo));
  RViewInfo.Load := @Build_RViewInfo;

  RViewInfo.Store := @Store_RViewInfo;

  RTrashCan.VmtLink := PtrUInt(System.TClass(gadgets.TTrashCan));
  RTrashCan.Load := @Build_RTrashCan;

  RTrashCan.Store := @Store_RTrashCan;

  RKeyMacros.VmtLink := PtrUInt(System.TClass(gadgets.TKeyMacros));
  RKeyMacros.Load := @Build_RKeyMacros;

  RKeyMacros.Store := @Store_RKeyMacros;

  RHelpTopic.VmtLink := PtrUInt(System.TClass(HelpKern.THelpTopic));
  RHelpTopic.Load := @Build_RHelpTopic;

  RHelpTopic.Store := @Store_RHelpTopic;

  RHelpIndex.VmtLink := PtrUInt(System.TClass(HelpKern.THelpIndex));
  RHelpIndex.Load := @Build_RHelpIndex;

  RHelpIndex.Store := @Store_RHelpIndex;

  REditHistoryCol.VmtLink := PtrUInt(System.TClass(histories.TEditHistoryCol));
  REditHistoryCol.Load := @Build_REditHistoryCol;

  REditHistoryCol.Store := @Store_REditHistoryCol;

  RViewHistoryCol.VmtLink := PtrUInt(System.TClass(histories.TViewHistoryCol));
  RViewHistoryCol.Load := @Build_RViewHistoryCol;

  RViewHistoryCol.Store := @Store_RViewHistoryCol;

  RMenuBar.VmtLink := PtrUInt(System.TClass(Menus.TMenuBar));
  RMenuBar.Load := @Build_RMenuBar;

  RMenuBar.Store := @Store_RMenuBar;

  RMenuBox.VmtLink := PtrUInt(System.TClass(Menus.TMenuBox));
  RMenuBox.Load := @Build_RMenuBox;

  RMenuBox.Store := @Store_RMenuBox;

  RStatusLine.VmtLink := PtrUInt(System.TClass(Menus.TStatusLine));
  RStatusLine.Load := @Build_RStatusLine;

  RStatusLine.Store := @Store_RStatusLine;

  RMenuPopup.VmtLink := PtrUInt(System.TClass(Menus.TMenuPopup));
  RMenuPopup.Load := @Build_RMenuPopup;

  RMenuPopup.Store := @Store_RMenuPopup;

  RFileEditor.VmtLink := PtrUInt(System.TClass(editcore.TFileEditor));
  RFileEditor.Load := @Build_RFileEditor;

  RFileEditor.Store := @Store_RFileEditor;

  REditWindow.VmtLink := PtrUInt(System.TClass(editwin.TEditWindow));
  REditWindow.Load := @Build_REditWindow;

  REditWindow.Store := @Store_REditWindow;

  RDStringView.VmtLink := PtrUInt(System.TClass(StrView.TDStringView));
  RDStringView.Load := @Build_RDStringView;

  RDStringView.Store := @Store_RDStringView;

  RPhone.VmtLink := PtrUInt(System.TClass(Phones.TPhone));
  RPhone.Load := @Build_RPhone;

  RPhone.Store := @Store_RPhone;

  RPhoneDir.VmtLink := PtrUInt(System.TClass(Phones.TPhoneDir));
  RPhoneDir.Load := @Build_RPhoneDir;

  RPhoneDir.Store := @Store_RPhoneDir;

  RPhoneCollection.VmtLink := PtrUInt(System.TClass(Phones.TPhoneCollection));
  RPhoneCollection.Load := @Build_RPhoneCollection;

  RPhoneCollection.Store := @Store_RPhoneCollection;

  RStringCol.VmtLink := PtrUInt(System.TClass(PrintMan.TStringCol));
  RStringCol.Load := @Build_RStringCol;

  RStringCol.Store := @Store_RStringCol;

  RPrintManager.VmtLink := PtrUInt(System.TClass(PrintMan.TPrintManager));
  RPrintManager.Load := @Build_RPrintManager;

  RPrintManager.Store := @Store_RPrintManager;

  RPrintStatus.VmtLink := PtrUInt(System.TClass(PrintMan.TPrintStatus));
  RPrintStatus.Load := @Build_RPrintStatus;

  RPrintStatus.Store := @Store_RPrintStatus;

  RPMWindow.VmtLink := PtrUInt(System.TClass(PrintMan.TPMWindow));
  RPMWindow.Load := @Build_RPMWindow;

  RPMWindow.Store := @Store_RPMWindow;

  RScroller.VmtLink := PtrUInt(System.TClass(Scroller.TScroller));
  RScroller.Load := @Build_RScroller;

  RScroller.Store := @Store_RScroller;

  RListViewer.VmtLink := PtrUInt(System.TClass(Scroller.TListViewer));
  RListViewer.Load := @Build_RListViewer;

  RListViewer.Store := @Store_RListViewer;

  RSysDialog.VmtLink := PtrUInt(System.TClass(Setups.TSysDialog));
  RSysDialog.Load := @Build_RSysDialog;

  RSysDialog.Store := @Store_RSysDialog;

  RCurrDriveInfo.VmtLink := PtrUInt(System.TClass(Setups.TCurrDriveInfo));
  RCurrDriveInfo.Load := @Build_RCurrDriveInfo;

  RCurrDriveInfo.Store := @Store_RCurrDriveInfo;

  RMouseBar.VmtLink := PtrUInt(System.TClass(Setups.TMouseBar));
  RMouseBar.Load := @Build_RMouseBar;

  RMouseBar.Store := @Store_RMouseBar;

  RSaversDialog.VmtLink := PtrUInt(System.TClass(Setups.TSaversDialog));
  RSaversDialog.Load := @Build_RSaversDialog;

  RSaversDialog.Store := @Store_RSaversDialog;

  RSaversListBox.VmtLink := PtrUInt(System.TClass(Setups.TSaversListBox));
  RSaversListBox.Load := @Build_RSaversListBox;

  RSaversListBox.Store := @Store_RSaversListBox;

  RTextCollection.VmtLink := PtrUInt(System.TClass(dlgrecs.TTextCollection));
  RTextCollection.Load := @Build_RTextCollection;

  RTextCollection.Store := @Store_RTextCollection;

  RGameWindow.VmtLink := PtrUInt(System.TClass(Tetris.TGameWindow));
  RGameWindow.Load := @Build_RGameWindow;

  RGameWindow.Store := @Store_RGameWindow;

  RGameView.VmtLink := PtrUInt(System.TClass(Tetris.TGameView));
  RGameView.Load := @Build_RGameView;

  RGameView.Store := @Store_RGameView;

  RGameInfo.VmtLink := PtrUInt(System.TClass(Tetris.TGameInfo));
  RGameInfo.Load := @Build_RGameInfo;

  RGameInfo.Store := @Store_RGameInfo;

  RTreeView.VmtLink := PtrUInt(System.TClass(Tree.TTreeView));
  RTreeView.Load := @Build_RTreeView;

  RTreeView.Store := @Store_RTreeView;

  RTreeReader.VmtLink := PtrUInt(System.TClass(Tree.TTreeReader));
  RTreeReader.Load := @Build_RTreeReader;

  RTreeReader.Store := @Store_RTreeReader;

  RTreeWindow.VmtLink := PtrUInt(System.TClass(Tree.TTreeWindow));
  RTreeWindow.Load := @Build_RTreeWindow;

  RTreeWindow.Store := @Store_RTreeWindow;

  RTreePanel.VmtLink := PtrUInt(System.TClass(Tree.TTreePanel));
  RTreePanel.Load := @Build_RTreePanel;

  RTreePanel.Store := @Store_RTreePanel;

  RTreeDialog.VmtLink := PtrUInt(System.TClass(Tree.TTreeDialog));
  RTreeDialog.Load := @Build_RTreeDialog;

  RTreeDialog.Store := @Store_RTreeDialog;

  RTreeInfoView.VmtLink := PtrUInt(System.TClass(Tree.TTreeInfoView));
  RTreeInfoView.Load := @Build_RTreeInfoView;

  RTreeInfoView.Store := @Store_RTreeInfoView;

  RHTreeView.VmtLink := PtrUInt(System.TClass(Tree.THTreeView));
  RHTreeView.Load := @Build_RHTreeView;

  RHTreeView.Store := @Store_RHTreeView;

  RDirCollection.VmtLink := PtrUInt(System.TClass(Tree.TDirCollection));
  RDirCollection.Load := @Build_RDirCollection;

  RDirCollection.Store := @Store_RDirCollection;

  REditScrollBar.VmtLink := PtrUInt(System.TClass(UniWin.TEditScrollBar));
  REditScrollBar.Load := @Build_REditScrollBar;

  REditScrollBar.Store := @Store_REditScrollBar;

  REditFrame.VmtLink := PtrUInt(System.TClass(UniWin.TEditFrame));
  REditFrame.Load := @Build_REditFrame;

  REditFrame.Store := @Store_REditFrame;

  RUserWindow.VmtLink := PtrUInt(System.TClass(UserMenu.TUserWindow));
  RUserWindow.Load := @Build_RUserWindow;

  RUserWindow.Store := @Store_RUserWindow;

  RUserView.VmtLink := PtrUInt(System.TClass(UserMenu.TUserView));
  RUserView.Load := @Build_RUserView;

  RUserView.Store := @Store_RUserView;

  RMyScrollBar.VmtLink := PtrUInt(System.TClass(Views.TMyScrollBar));
  RMyScrollBar.Load := @Build_RMyScrollBar;

  RMyScrollBar.Store := @Store_RMyScrollBar;

  RDoubleWindow.VmtLink := PtrUInt(System.TClass(panelwinx.TXDoubleWindow));
  RDoubleWindow.Load := @Build_RDoubleWindow;

  RDoubleWindow.Store := @Store_RDoubleWindow;

  RColorPoint.VmtLink := PtrUInt(System.TClass(inputfname.TColorPoint));
  RColorPoint.Load := @Build_RColorPoint;

  RColorPoint.Store := @Store_RColorPoint;

end;

initialization
  SetStreamRecs_regall;
end.
