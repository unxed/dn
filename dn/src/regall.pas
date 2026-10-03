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
  panelwin, TopView_, startupp, strview,
  
  arc_Zip, arc_LHA, arc_RAR, arc_ACE, arc_HA, arc_CAB,
  
  arc_ARC, arc_BSA, arc_BS2, arc_HYP, arc_LIM, arc_HPK, arc_TAR,
  arc_ZXZ, arc_QRK, arc_AIN, arc_CHZ, arc_HAP, arc_IS3, arc_SQZ,
  arc_UC2, arc_UFA, arc_ZOO, arc_TGZ, arc_7Z,  arc_BZ2,
  
  
  Arvid,
  
  Archiver, ArcView, ASCIITab, CCalc, Collect, DiskInfo, mainapp,
  DNStdDlg, DNUtil, Drives, editundo, Editor, FileFind, FilesCol,
  filepanel, FStorage, FViewer, Gauges, Histries, editcore, Startup,
  Tree, UniWin, UserMenu, panelwinx, HelpKern,
  Calc, CellsCol, 
  Calendar, 
  DBView, 
  
  PrintMan, 
  Tetris, 
  
  Phones, 
  
  
  ColorSel,
  Dialogs, Menus, Streams, ObjType, Scroller, Setups,
  Validate, Views, SWE 
  , editwin
  , DNDlgs, DNStrL, DNColor;

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
    { DnApp }
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
    { Ed2 }
RInfoLine : TStreamRec = (ObjType: otInfoLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RBookLine : TStreamRec = (ObjType: otBookLine; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { Editor }
RXFileEditor : TStreamRec = (ObjType: otXFileEditor; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { FileFind }
RFindDrive : TStreamRec = (ObjType: otFindDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
RTempDrive : TStreamRec = (ObjType: otTempDrive; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    
    { FilesCol }
RFilesCollection : TStreamRec = (ObjType: otFilesCollection; VmtLink: 0; Load: nil; Store: nil; Next: nil);
    { FlPanel }
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
    
    { Microed }
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
    { XDblWnd }
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

type
  PR_RFilterValidator = ^Validate.TFilterValidator;

function Build_RFilterValidator(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFilterValidator, Load(S)));
end;

procedure Store_RFilterValidator(P: PObject; var S: TStream);
begin
  PR_RFilterValidator(P)^.Store(S);
end;

type
  PR_RRangeValidator = ^Validate.TRangeValidator;

function Build_RRangeValidator(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RRangeValidator, Load(S)));
end;

procedure Store_RRangeValidator(P: PObject; var S: TStream);
begin
  PR_RRangeValidator(P)^.Store(S);
end;

type
  PR_RView = ^Views.TView;

function Build_RView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RView, Load(S)));
end;

procedure Store_RView(P: PObject; var S: TStream);
begin
  PR_RView(P)^.Store(S);
end;

type
  PR_RFrame = ^Views.TFrame;

function Build_RFrame(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFrame, Load(S)));
end;

procedure Store_RFrame(P: PObject; var S: TStream);
begin
  PR_RFrame(P)^.Store(S);
end;

type
  PR_RScrollBar = ^Views.TScrollBar;

function Build_RScrollBar(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RScrollBar, Load(S)));
end;

procedure Store_RScrollBar(P: PObject; var S: TStream);
begin
  PR_RScrollBar(P)^.Store(S);
end;

type
  PR_RGroup = ^Views.TGroup;

function Build_RGroup(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RGroup, Load(S)));
end;

procedure Store_RGroup(P: PObject; var S: TStream);
begin
  PR_RGroup(P)^.Store(S);
end;

type
  PR_RWindow = ^Views.TWindow;

function Build_RWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RWindow, Load(S)));
end;

procedure Store_RWindow(P: PObject; var S: TStream);
begin
  PR_RWindow(P)^.Store(S);
end;

type
  PR_RZIPArchiver = ^arc_Zip.TZIPArchive;

function Build_RZIPArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RZIPArchiver, Load(S)));
end;

procedure Store_RZIPArchiver(P: PObject; var S: TStream);
begin
  PR_RZIPArchiver(P)^.Store(S);
end;

type
  PR_RLHAArchiver = ^arc_LHA.TLHAArchive;

function Build_RLHAArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RLHAArchiver, Load(S)));
end;

procedure Store_RLHAArchiver(P: PObject; var S: TStream);
begin
  PR_RLHAArchiver(P)^.Store(S);
end;

type
  PR_RRARArchiver = ^arc_RAR.TRARArchive;

function Build_RRARArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RRARArchiver, Load(S)));
end;

procedure Store_RRARArchiver(P: PObject; var S: TStream);
begin
  PR_RRARArchiver(P)^.Store(S);
end;

type
  PR_RCABArchiver = ^arc_CAB.TCABArchive;

function Build_RCABArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCABArchiver, Load(S)));
end;

procedure Store_RCABArchiver(P: PObject; var S: TStream);
begin
  PR_RCABArchiver(P)^.Store(S);
end;

type
  PR_RACEArchiver = ^arc_ACE.TACEArchive;

function Build_RACEArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RACEArchiver, Load(S)));
end;

procedure Store_RACEArchiver(P: PObject; var S: TStream);
begin
  PR_RACEArchiver(P)^.Store(S);
end;

type
  PR_RHAArchiver = ^arc_HA.THAArchive;

function Build_RHAArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHAArchiver, Load(S)));
end;

procedure Store_RHAArchiver(P: PObject; var S: TStream);
begin
  PR_RHAArchiver(P)^.Store(S);
end;

type
  PR_RARCArchiver = ^arc_ARC.TARCArchive;

function Build_RARCArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RARCArchiver, Load(S)));
end;

procedure Store_RARCArchiver(P: PObject; var S: TStream);
begin
  PR_RARCArchiver(P)^.Store(S);
end;

type
  PR_RBSAArchiver = ^arc_BSA.TBSAArchive;

function Build_RBSAArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RBSAArchiver, Load(S)));
end;

procedure Store_RBSAArchiver(P: PObject; var S: TStream);
begin
  PR_RBSAArchiver(P)^.Store(S);
end;

type
  PR_RBS2Archiver = ^arc_BS2.TBS2Archive;

function Build_RBS2Archiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RBS2Archiver, Load(S)));
end;

procedure Store_RBS2Archiver(P: PObject; var S: TStream);
begin
  PR_RBS2Archiver(P)^.Store(S);
end;

type
  PR_RHYPArchiver = ^arc_HYP.THYPArchive;

function Build_RHYPArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHYPArchiver, Load(S)));
end;

procedure Store_RHYPArchiver(P: PObject; var S: TStream);
begin
  PR_RHYPArchiver(P)^.Store(S);
end;

type
  PR_RLIMArchiver = ^arc_LIM.TLIMArchive;

function Build_RLIMArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RLIMArchiver, Load(S)));
end;

procedure Store_RLIMArchiver(P: PObject; var S: TStream);
begin
  PR_RLIMArchiver(P)^.Store(S);
end;

type
  PR_RHPKArchiver = ^arc_HPK.THPKArchive;

function Build_RHPKArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHPKArchiver, Load(S)));
end;

procedure Store_RHPKArchiver(P: PObject; var S: TStream);
begin
  PR_RHPKArchiver(P)^.Store(S);
end;

type
  PR_RTARArchiver = ^arc_TAR.TTARArchive;

function Build_RTARArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTARArchiver, Load(S)));
end;

procedure Store_RTARArchiver(P: PObject; var S: TStream);
begin
  PR_RTARArchiver(P)^.Store(S);
end;

type
  PR_RTGZArchiver = ^arc_TGZ.TTGZArchive;

function Build_RTGZArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTGZArchiver, Load(S)));
end;

procedure Store_RTGZArchiver(P: PObject; var S: TStream);
begin
  PR_RTGZArchiver(P)^.Store(S);
end;

type
  PR_RZXZArchiver = ^arc_ZXZ.TZXZArchive;

function Build_RZXZArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RZXZArchiver, Load(S)));
end;

procedure Store_RZXZArchiver(P: PObject; var S: TStream);
begin
  PR_RZXZArchiver(P)^.Store(S);
end;

type
  PR_RQUARKArchiver = ^arc_QRK.TQuArkArchive;

function Build_RQUARKArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RQUARKArchiver, Load(S)));
end;

procedure Store_RQUARKArchiver(P: PObject; var S: TStream);
begin
  PR_RQUARKArchiver(P)^.Store(S);
end;

type
  PR_RUFAArchiver = ^arc_UFA.TUFAArchive;

function Build_RUFAArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RUFAArchiver, Load(S)));
end;

procedure Store_RUFAArchiver(P: PObject; var S: TStream);
begin
  PR_RUFAArchiver(P)^.Store(S);
end;

type
  PR_RIS3Archiver = ^arc_IS3.TIS3Archive;

function Build_RIS3Archiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RIS3Archiver, Load(S)));
end;

procedure Store_RIS3Archiver(P: PObject; var S: TStream);
begin
  PR_RIS3Archiver(P)^.Store(S);
end;

type
  PR_RSQZArchiver = ^arc_SQZ.TSQZArchive;

function Build_RSQZArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSQZArchiver, Load(S)));
end;

procedure Store_RSQZArchiver(P: PObject; var S: TStream);
begin
  PR_RSQZArchiver(P)^.Store(S);
end;

type
  PR_RHAPArchiver = ^arc_HAP.THAPArchive;

function Build_RHAPArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHAPArchiver, Load(S)));
end;

procedure Store_RHAPArchiver(P: PObject; var S: TStream);
begin
  PR_RHAPArchiver(P)^.Store(S);
end;

type
  PR_RZOOArchiver = ^arc_ZOO.TZOOArchive;

function Build_RZOOArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RZOOArchiver, Load(S)));
end;

procedure Store_RZOOArchiver(P: PObject; var S: TStream);
begin
  PR_RZOOArchiver(P)^.Store(S);
end;

type
  PR_RCHZArchiver = ^arc_CHZ.TCHZArchive;

function Build_RCHZArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCHZArchiver, Load(S)));
end;

procedure Store_RCHZArchiver(P: PObject; var S: TStream);
begin
  PR_RCHZArchiver(P)^.Store(S);
end;

type
  PR_RUC2Archiver = ^arc_UC2.TUC2Archive;

function Build_RUC2Archiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RUC2Archiver, Load(S)));
end;

procedure Store_RUC2Archiver(P: PObject; var S: TStream);
begin
  PR_RUC2Archiver(P)^.Store(S);
end;

type
  PR_RAINArchiver = ^arc_AIN.TAINArchive;

function Build_RAINArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RAINArchiver, Load(S)));
end;

procedure Store_RAINArchiver(P: PObject; var S: TStream);
begin
  PR_RAINArchiver(P)^.Store(S);
end;

type
  PR_RS7ZArchiver = ^arc_7Z.TS7ZArchive;

function Build_RS7ZArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RS7ZArchiver, Load(S)));
end;

procedure Store_RS7ZArchiver(P: PObject; var S: TStream);
begin
  PR_RS7ZArchiver(P)^.Store(S);
end;

type
  PR_RBZ2Archiver = ^Arc_BZ2.TBZ2Archive;

function Build_RBZ2Archiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RBZ2Archiver, Load(S)));
end;

procedure Store_RBZ2Archiver(P: PObject; var S: TStream);
begin
  PR_RBZ2Archiver(P)^.Store(S);
end;

type
  PR_RARJArchiver = ^Archiver.TARJArchive;

function Build_RARJArchiver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RARJArchiver, Load(S)));
end;

procedure Store_RARJArchiver(P: PObject; var S: TStream);
begin
  PR_RARJArchiver(P)^.Store(S);
end;

type
  PR_RFileInfo = ^Archiver.TFileInfo;

function Build_RFileInfo(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileInfo, Load(S)));
end;

procedure Store_RFileInfo(P: PObject; var S: TStream);
begin
  PR_RFileInfo(P)^.Store(S);
end;

type
  PR_RArcDrive = ^ArcView.TArcDrive;

function Build_RArcDrive(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RArcDrive, Load(S)));
end;

procedure Store_RArcDrive(P: PObject; var S: TStream);
begin
  PR_RArcDrive(P)^.Store(S);
end;

type
  PR_RArvidDrive = ^Arvid.TArvidDrive;

function Build_RArvidDrive(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RArvidDrive, Load(S)));
end;

procedure Store_RArvidDrive(P: PObject; var S: TStream);
begin
  PR_RArvidDrive(P)^.Store(S);
end;

type
  PR_RTable = ^ASCIITab.TTable;

function Build_RTable(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTable, Load(S)));
end;

procedure Store_RTable(P: PObject; var S: TStream);
begin
  PR_RTable(P)^.Store(S);
end;

type
  PR_RReport = ^ASCIITab.TReport;

function Build_RReport(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RReport, Load(S)));
end;

procedure Store_RReport(P: PObject; var S: TStream);
begin
  PR_RReport(P)^.Store(S);
end;

type
  PR_RASCIIChart = ^ASCIITab.TASCIIChart;

function Build_RASCIIChart(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RASCIIChart, Load(S)));
end;

procedure Store_RASCIIChart(P: PObject; var S: TStream);
begin
  PR_RASCIIChart(P)^.Store(S);
end;

type
  PR_RCalcWindow = ^Calc.TCalcWindow;

function Build_RCalcWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCalcWindow, Load(S)));
end;

procedure Store_RCalcWindow(P: PObject; var S: TStream);
begin
  PR_RCalcWindow(P)^.Store(S);
end;

type
  PR_RCalcView = ^Calc.TCalcView;

function Build_RCalcView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCalcView, Load(S)));
end;

procedure Store_RCalcView(P: PObject; var S: TStream);
begin
  PR_RCalcView(P)^.Store(S);
end;

type
  PR_RCalcInfo = ^Calc.TCalcInput;

function Build_RCalcInfo(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCalcInfo, Load(S)));
end;

procedure Store_RCalcInfo(P: PObject; var S: TStream);
begin
  PR_RCalcInfo(P)^.Store(S);
end;

type
  PR_RInfoView = ^Calc.TInfoView;

function Build_RInfoView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RInfoView, Load(S)));
end;

procedure Store_RInfoView(P: PObject; var S: TStream);
begin
  PR_RInfoView(P)^.Store(S);
end;

type
  PR_RCellCollection = ^CellsCol.TCellCollection;

function Build_RCellCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCellCollection, Load(S)));
end;

procedure Store_RCellCollection(P: PObject; var S: TStream);
begin
  PR_RCellCollection(P)^.Store(S);
end;

type
  PR_RCalendarView = ^Calendar.TCalendarView;

function Build_RCalendarView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCalendarView, Load(S)));
end;

procedure Store_RCalendarView(P: PObject; var S: TStream);
begin
  PR_RCalendarView(P)^.Store(S);
end;

type
  PR_RCalendarWindow = ^Calendar.TCalendarWindow;

function Build_RCalendarWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCalendarWindow, Load(S)));
end;

procedure Store_RCalendarWindow(P: PObject; var S: TStream);
begin
  PR_RCalendarWindow(P)^.Store(S);
end;

type
  PR_RCalcLine = ^CCalc.TCalcLine;

function Build_RCalcLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCalcLine, Load(S)));
end;

procedure Store_RCalcLine(P: PObject; var S: TStream);
begin
  PR_RCalcLine(P)^.Store(S);
end;

type
  PR_RIndicator = ^CCalc.TIndicator;

function Build_RIndicator(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RIndicator, Load(S)));
end;

procedure Store_RIndicator(P: PObject; var S: TStream);
begin
  PR_RIndicator(P)^.Store(S);
end;

type
  PR_RCollection = ^Collect.TCollection;

function Build_RCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCollection, Load(S)));
end;

procedure Store_RCollection(P: PObject; var S: TStream);
begin
  PR_RCollection(P)^.Store(S);
end;

type
  PR_RLineCollection = ^Collect.TLineCollection;

function Build_RLineCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RLineCollection, Load(S)));
end;

procedure Store_RLineCollection(P: PObject; var S: TStream);
begin
  PR_RLineCollection(P)^.Store(S);
end;

type
  PR_RStringCollection = ^Collect.TStringCollection;

function Build_RStringCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RStringCollection, Load(S)));
end;

procedure Store_RStringCollection(P: PObject; var S: TStream);
begin
  PR_RStringCollection(P)^.Store(S);
end;

type
  PR_RStrCollection = ^Collect.TStrCollection;

function Build_RStrCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RStrCollection, Load(S)));
end;

procedure Store_RStrCollection(P: PObject; var S: TStream);
begin
  PR_RStrCollection(P)^.Store(S);
end;

type
  PR_RStringList = ^DNStrL.TStringList;

function Build_RStringList(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RStringList, Load(S)));
end;

type
  PR_RColorSelector = ^ColorSel.TColorSelector;

function Build_RColorSelector(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RColorSelector, Load(S)));
end;

procedure Store_RColorSelector(P: PObject; var S: TStream);
begin
  PR_RColorSelector(P)^.Store(S);
end;

type
  PR_RMonoSelector = ^ColorSel.TMonoSelector;

function Build_RMonoSelector(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMonoSelector, Load(S)));
end;

procedure Store_RMonoSelector(P: PObject; var S: TStream);
begin
  PR_RMonoSelector(P)^.Store(S);
end;

type
  PR_RColorDisplay = ^ColorSel.TColorDisplay;

function Build_RColorDisplay(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RColorDisplay, Load(S)));
end;

procedure Store_RColorDisplay(P: PObject; var S: TStream);
begin
  PR_RColorDisplay(P)^.Store(S);
end;

type
  PR_RColorGroupList = ^ColorSel.TColorGroupList;

function Build_RColorGroupList(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RColorGroupList, Load(S)));
end;

procedure Store_RColorGroupList(P: PObject; var S: TStream);
begin
  PR_RColorGroupList(P)^.Store(S);
end;

type
  PR_RColorItemList = ^ColorSel.TColorItemList;

function Build_RColorItemList(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RColorItemList, Load(S)));
end;

procedure Store_RColorItemList(P: PObject; var S: TStream);
begin
  PR_RColorItemList(P)^.Store(S);
end;

type
  PR_RColorDialog = ^ColorSel.TColorDialog;

function Build_RColorDialog(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RColorDialog, Load(S)));
end;

procedure Store_RColorDialog(P: PObject; var S: TStream);
begin
  PR_RColorDialog(P)^.Store(S);
end;

type
  PR_RR_BWSelector = ^DNColor.T_BWSelector;

function Build_RR_BWSelector(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RR_BWSelector, Load(S)));
end;

procedure Store_RR_BWSelector(P: PObject; var S: TStream);
begin
  PR_RR_BWSelector(P)^.Store(S);
end;

type
  PR_RDBWindow = ^DBView.TDBWindow;

function Build_RDBWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDBWindow, Load(S)));
end;

procedure Store_RDBWindow(P: PObject; var S: TStream);
begin
  PR_RDBWindow(P)^.Store(S);
end;

type
  PR_RDBViewer = ^DBView.TDBViewer;

function Build_RDBViewer(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDBViewer, Load(S)));
end;

procedure Store_RDBViewer(P: PObject; var S: TStream);
begin
  PR_RDBViewer(P)^.Store(S);
end;

type
  PR_RDBIndicator = ^DBView.TDBIndicator;

function Build_RDBIndicator(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDBIndicator, Load(S)));
end;

procedure Store_RDBIndicator(P: PObject; var S: TStream);
begin
  PR_RDBIndicator(P)^.Store(S);
end;

type
  PR_RFieldListBox = ^DBView.TFieldListBox;

function Build_RFieldListBox(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFieldListBox, Load(S)));
end;

procedure Store_RFieldListBox(P: PObject; var S: TStream);
begin
  PR_RFieldListBox(P)^.Store(S);
end;

type
  PR_RDialog = ^Dialogs.TDialog;

function Build_RDialog(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDialog, Load(S)));
end;

procedure Store_RDialog(P: PObject; var S: TStream);
begin
  PR_RDialog(P)^.Store(S);
end;

type
  PR_RInputLine = ^Dialogs.TInputLine;

function Build_RInputLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RInputLine, Load(S)));
end;

procedure Store_RInputLine(P: PObject; var S: TStream);
begin
  PR_RInputLine(P)^.Store(S);
end;

type
  PR_RHexLine = ^DNDlgs.THexLine;

function Build_RHexLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHexLine, Load(S)));
end;

procedure Store_RHexLine(P: PObject; var S: TStream);
begin
  PR_RHexLine(P)^.Store(S);
end;

type
  PR_RLongInputLine = ^Dialogs.TLongInputLine;

function Build_RLongInputLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RLongInputLine, Load(S)));
end;

procedure Store_RLongInputLine(P: PObject; var S: TStream);
begin
  PR_RLongInputLine(P)^.Store(S);
end;

type
  PR_RButton = ^Dialogs.TButton;

function Build_RButton(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RButton, Load(S)));
end;

procedure Store_RButton(P: PObject; var S: TStream);
begin
  PR_RButton(P)^.Store(S);
end;

type
  PR_RCluster = ^Dialogs.TCluster;

function Build_RCluster(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCluster, Load(S)));
end;

procedure Store_RCluster(P: PObject; var S: TStream);
begin
  PR_RCluster(P)^.Store(S);
end;

type
  PR_RRadioButtons = ^Dialogs.TRadioButtons;

function Build_RRadioButtons(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RRadioButtons, Load(S)));
end;

procedure Store_RRadioButtons(P: PObject; var S: TStream);
begin
  PR_RRadioButtons(P)^.Store(S);
end;

type
  PR_RComboBox = ^DNDlgs.TComboBox;

function Build_RComboBox(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RComboBox, Load(S)));
end;

procedure Store_RComboBox(P: PObject; var S: TStream);
begin
  PR_RComboBox(P)^.Store(S);
end;

type
  PR_RCheckBoxes = ^Dialogs.TCheckBoxes;

function Build_RCheckBoxes(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCheckBoxes, Load(S)));
end;

procedure Store_RCheckBoxes(P: PObject; var S: TStream);
begin
  PR_RCheckBoxes(P)^.Store(S);
end;

type
  PR_RMultiCheckBoxes = ^Dialogs.TMultiCheckBoxes;

function Build_RMultiCheckBoxes(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMultiCheckBoxes, Load(S)));
end;

procedure Store_RMultiCheckBoxes(P: PObject; var S: TStream);
begin
  PR_RMultiCheckBoxes(P)^.Store(S);
end;

type
  PR_RListBox = ^Dialogs.TListBox;

function Build_RListBox(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RListBox, Load(S)));
end;

procedure Store_RListBox(P: PObject; var S: TStream);
begin
  PR_RListBox(P)^.Store(S);
end;

type
  PR_RStaticText = ^Dialogs.TStaticText;

function Build_RStaticText(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RStaticText, Load(S)));
end;

procedure Store_RStaticText(P: PObject; var S: TStream);
begin
  PR_RStaticText(P)^.Store(S);
end;

type
  PR_RLabel = ^Dialogs.TLabel;

function Build_RLabel(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RLabel, Load(S)));
end;

procedure Store_RLabel(P: PObject; var S: TStream);
begin
  PR_RLabel(P)^.Store(S);
end;

type
  PR_RHistory = ^Dialogs.THistory;

function Build_RHistory(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHistory, Load(S)));
end;

procedure Store_RHistory(P: PObject; var S: TStream);
begin
  PR_RHistory(P)^.Store(S);
end;

type
  PR_RParamText = ^DNDlgs.TParamText;

function Build_RParamText(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RParamText, Load(S)));
end;

procedure Store_RParamText(P: PObject; var S: TStream);
begin
  PR_RParamText(P)^.Store(S);
end;

type
  PR_RNotepad = ^DNDlgs.TNotepad;

function Build_RNotepad(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RNotepad, Load(S)));
end;

procedure Store_RNotepad(P: PObject; var S: TStream);
begin
  PR_RNotepad(P)^.Store(S);
end;

type
  PR_RPage = ^DNDlgs.TPage;

function Build_RPage(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPage, Load(S)));
end;

procedure Store_RPage(P: PObject; var S: TStream);
begin
  PR_RPage(P)^.Store(S);
end;

type
  PR_RBookmark = ^DNDlgs.TBookmark;

function Build_RBookmark(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RBookmark, Load(S)));
end;

procedure Store_RBookmark(P: PObject; var S: TStream);
begin
  PR_RBookmark(P)^.Store(S);
end;

type
  PR_RPageFrame = ^DNDlgs.TPageFrame;

function Build_RPageFrame(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPageFrame, Load(S)));
end;

procedure Store_RPageFrame(P: PObject; var S: TStream);
begin
  PR_RPageFrame(P)^.Store(S);
end;

type
  PR_RNotepadFrame = ^DNDlgs.TNotepadFrame;

function Build_RNotepadFrame(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RNotepadFrame, Load(S)));
end;

procedure Store_RNotepadFrame(P: PObject; var S: TStream);
begin
  PR_RNotepadFrame(P)^.Store(S);
end;

type
  PR_RDiskInfo = ^DiskInfo.TDiskInfo;

function Build_RDiskInfo(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDiskInfo, Load(S)));
end;

procedure Store_RDiskInfo(P: PObject; var S: TStream);
begin
  PR_RDiskInfo(P)^.Store(S);
end;

type
  PR_RDriveView = ^DiskInfo.TDriveView;

function Build_RDriveView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDriveView, Load(S)));
end;

procedure Store_RDriveView(P: PObject; var S: TStream);
begin
  PR_RDriveView(P)^.Store(S);
end;

type
  PR_RBackground = ^mainapp.TBackground;

function Build_RBackground(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RBackground, Load(S)));
end;

procedure Store_RBackground(P: PObject; var S: TStream);
begin
  PR_RBackground(P)^.Store(S);
end;

type
  PR_RDesktop = ^mainapp.TDesktop;

function Build_RDesktop(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDesktop, Load(S)));
end;

procedure Store_RDesktop(P: PObject; var S: TStream);
begin
  PR_RDesktop(P)^.Store(S);
end;

type
  PR_RFileInputLine = ^DNStdDlg.TFileInputLine;

function Build_RFileInputLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileInputLine, Load(S)));
end;

procedure Store_RFileInputLine(P: PObject; var S: TStream);
begin
  PR_RFileInputLine(P)^.Store(S);
end;

type
  PR_RFileCollection = ^DNStdDlg.TFileCollection;

function Build_RFileCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileCollection, Load(S)));
end;

procedure Store_RFileCollection(P: PObject; var S: TStream);
begin
  PR_RFileCollection(P)^.Store(S);
end;

type
  PR_RFileList = ^DNStdDlg.TFileList;

function Build_RFileList(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileList, Load(S)));
end;

procedure Store_RFileList(P: PObject; var S: TStream);
begin
  PR_RFileList(P)^.Store(S);
end;

type
  PR_RFileInfoPane = ^DNStdDlg.TFileInfoPane;

function Build_RFileInfoPane(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileInfoPane, Load(S)));
end;

procedure Store_RFileInfoPane(P: PObject; var S: TStream);
begin
  PR_RFileInfoPane(P)^.Store(S);
end;

type
  PR_RFileDialog = ^DNStdDlg.TFileDialog;

function Build_RFileDialog(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileDialog, Load(S)));
end;

procedure Store_RFileDialog(P: PObject; var S: TStream);
begin
  PR_RFileDialog(P)^.Store(S);
end;

type
  PR_RSortedListBox = ^DNStdDlg.TSortedListBox;

function Build_RSortedListBox(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSortedListBox, Load(S)));
end;

procedure Store_RSortedListBox(P: PObject; var S: TStream);
begin
  PR_RSortedListBox(P)^.Store(S);
end;

type
  PR_RDataSaver = ^DNUtil.TDataSaver;

function Build_RDataSaver(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDataSaver, Load(S)));
end;

procedure Store_RDataSaver(P: PObject; var S: TStream);
begin
  PR_RDataSaver(P)^.Store(S);
end;

type
  PR_RDrive = ^Drives.TDrive;

function Build_RDrive(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDrive, Load(S)));
end;

procedure Store_RDrive(P: PObject; var S: TStream);
begin
  PR_RDrive(P)^.Store(S);
end;

type
  PR_RInfoLine = ^editundo.TInfoLine;

function Build_RInfoLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RInfoLine, Load(S)));
end;

procedure Store_RInfoLine(P: PObject; var S: TStream);
begin
  PR_RInfoLine(P)^.Store(S);
end;

type
  PR_RBookLine = ^editundo.TBookmarkLine;

function Build_RBookLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RBookLine, Load(S)));
end;

procedure Store_RBookLine(P: PObject; var S: TStream);
begin
  PR_RBookLine(P)^.Store(S);
end;

type
  PR_RXFileEditor = ^Editor.TXFileEditor;

function Build_RXFileEditor(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RXFileEditor, Load(S)));
end;

procedure Store_RXFileEditor(P: PObject; var S: TStream);
begin
  PR_RXFileEditor(P)^.Store(S);
end;

type
  PR_RFindDrive = ^FileFind.TFindDrive;

function Build_RFindDrive(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFindDrive, Load(S)));
end;

procedure Store_RFindDrive(P: PObject; var S: TStream);
begin
  PR_RFindDrive(P)^.Store(S);
end;

type
  PR_RTempDrive = ^FileFind.TTempDrive;

function Build_RTempDrive(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTempDrive, Load(S)));
end;

procedure Store_RTempDrive(P: PObject; var S: TStream);
begin
  PR_RTempDrive(P)^.Store(S);
end;

type
  PR_RFilesCollection = ^FilesCol.TFilesCollection;

function Build_RFilesCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFilesCollection, Load(S)));
end;

procedure Store_RFilesCollection(P: PObject; var S: TStream);
begin
  PR_RFilesCollection(P)^.Store(S);
end;

type
  PR_RFilePanel = ^filepanel.TFilePanel;

function Build_RFilePanel(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFilePanel, Load(S)));
end;

procedure Store_RFilePanel(P: PObject; var S: TStream);
begin
  PR_RFilePanel(P)^.Store(S);
end;

type
  PR_RFlPInfoView = ^filepanel.TInfoView;

function Build_RFlPInfoView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFlPInfoView, Load(S)));
end;

procedure Store_RFlPInfoView(P: PObject; var S: TStream);
begin
  PR_RFlPInfoView(P)^.Store(S);
end;

type
  PR_RDirView = ^filepanel.TDirView;

function Build_RDirView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDirView, Load(S)));
end;

procedure Store_RDirView(P: PObject; var S: TStream);
begin
  PR_RDirView(P)^.Store(S);
end;

type
  PR_RSortView = ^TopView_.TSortView;

function Build_RSortView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSortView, Load(S)));
end;

procedure Store_RSortView(P: PObject; var S: TStream);
begin
  PR_RSortView(P)^.Store(S);
end;

type
  PR_RSeparator = ^panelwin.TSeparator;

function Build_RSeparator(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSeparator, Load(S)));
end;

procedure Store_RSeparator(P: PObject; var S: TStream);
begin
  PR_RSeparator(P)^.Store(S);
end;

type
  PR_RDriveLine = ^filepanel.TDriveLine;

function Build_RDriveLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDriveLine, Load(S)));
end;

procedure Store_RDriveLine(P: PObject; var S: TStream);
begin
  PR_RDriveLine(P)^.Store(S);
end;

type
  PR_RDirStorage = ^FStorage.TDirStorage;

function Build_RDirStorage(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDirStorage, Load(S)));
end;

procedure Store_RDirStorage(P: PObject; var S: TStream);
begin
  PR_RDirStorage(P)^.Store(S);
end;

type
  PR_RFileViewer = ^FViewer.TFileViewer;

function Build_RFileViewer(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileViewer, Load(S)));
end;

procedure Store_RFileViewer(P: PObject; var S: TStream);
begin
  PR_RFileViewer(P)^.Store(S);
end;

type
  PR_RFileWindow = ^FViewer.TFileWindow;

function Build_RFileWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileWindow, Load(S)));
end;

procedure Store_RFileWindow(P: PObject; var S: TStream);
begin
  PR_RFileWindow(P)^.Store(S);
end;

type
  PR_RViewScroll = ^FViewer.TViewScroll;

function Build_RViewScroll(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RViewScroll, Load(S)));
end;

procedure Store_RViewScroll(P: PObject; var S: TStream);
begin
  PR_RViewScroll(P)^.Store(S);
end;

type
  PR_RQFileViewer = ^FViewer.TQFileViewer;

function Build_RQFileViewer(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RQFileViewer, Load(S)));
end;

procedure Store_RQFileViewer(P: PObject; var S: TStream);
begin
  PR_RQFileViewer(P)^.Store(S);
end;

type
  PR_RDFileViewer = ^FViewer.TDFileViewer;

function Build_RDFileViewer(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDFileViewer, Load(S)));
end;

procedure Store_RDFileViewer(P: PObject; var S: TStream);
begin
  PR_RDFileViewer(P)^.Store(S);
end;

type
  PR_RViewInfo = ^FViewer.TViewInfo;

function Build_RViewInfo(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RViewInfo, Load(S)));
end;

procedure Store_RViewInfo(P: PObject; var S: TStream);
begin
  PR_RViewInfo(P)^.Store(S);
end;

type
  PR_RTrashCan = ^Gauges.TTrashCan;

function Build_RTrashCan(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTrashCan, Load(S)));
end;

procedure Store_RTrashCan(P: PObject; var S: TStream);
begin
  PR_RTrashCan(P)^.Store(S);
end;

type
  PR_RKeyMacros = ^Gauges.TKeyMacros;

function Build_RKeyMacros(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RKeyMacros, Load(S)));
end;

procedure Store_RKeyMacros(P: PObject; var S: TStream);
begin
  PR_RKeyMacros(P)^.Store(S);
end;

type
  PR_RHelpTopic = ^HelpKern.THelpTopic;

function Build_RHelpTopic(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHelpTopic, Load(S)));
end;

procedure Store_RHelpTopic(P: PObject; var S: TStream);
begin
  PR_RHelpTopic(P)^.Store(S);
end;

type
  PR_RHelpIndex = ^HelpKern.THelpIndex;

function Build_RHelpIndex(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHelpIndex, Load(S)));
end;

procedure Store_RHelpIndex(P: PObject; var S: TStream);
begin
  PR_RHelpIndex(P)^.Store(S);
end;

type
  PR_REditHistoryCol = ^Histries.TEditHistoryCol;

function Build_REditHistoryCol(var S: TStream): PObject;
begin
  Result := PObject(New(PR_REditHistoryCol, Load(S)));
end;

procedure Store_REditHistoryCol(P: PObject; var S: TStream);
begin
  PR_REditHistoryCol(P)^.Store(S);
end;

type
  PR_RViewHistoryCol = ^Histries.TViewHistoryCol;

function Build_RViewHistoryCol(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RViewHistoryCol, Load(S)));
end;

procedure Store_RViewHistoryCol(P: PObject; var S: TStream);
begin
  PR_RViewHistoryCol(P)^.Store(S);
end;

type
  PR_RMenuBar = ^Menus.TMenuBar;

function Build_RMenuBar(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMenuBar, Load(S)));
end;

procedure Store_RMenuBar(P: PObject; var S: TStream);
begin
  PR_RMenuBar(P)^.Store(S);
end;

type
  PR_RMenuBox = ^Menus.TMenuBox;

function Build_RMenuBox(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMenuBox, Load(S)));
end;

procedure Store_RMenuBox(P: PObject; var S: TStream);
begin
  PR_RMenuBox(P)^.Store(S);
end;

type
  PR_RStatusLine = ^Menus.TStatusLine;

function Build_RStatusLine(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RStatusLine, Load(S)));
end;

procedure Store_RStatusLine(P: PObject; var S: TStream);
begin
  PR_RStatusLine(P)^.Store(S);
end;

type
  PR_RMenuPopup = ^Menus.TMenuPopup;

function Build_RMenuPopup(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMenuPopup, Load(S)));
end;

procedure Store_RMenuPopup(P: PObject; var S: TStream);
begin
  PR_RMenuPopup(P)^.Store(S);
end;

type
  PR_RFileEditor = ^editcore.TFileEditor;

function Build_RFileEditor(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RFileEditor, Load(S)));
end;

procedure Store_RFileEditor(P: PObject; var S: TStream);
begin
  PR_RFileEditor(P)^.Store(S);
end;

type
  PR_REditWindow = ^editwin.TEditWindow;

function Build_REditWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_REditWindow, Load(S)));
end;

procedure Store_REditWindow(P: PObject; var S: TStream);
begin
  PR_REditWindow(P)^.Store(S);
end;

type
  PR_RDStringView = ^StrView.TDStringView;

function Build_RDStringView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDStringView, Load(S)));
end;

procedure Store_RDStringView(P: PObject; var S: TStream);
begin
  PR_RDStringView(P)^.Store(S);
end;

type
  PR_RPhone = ^Phones.TPhone;

function Build_RPhone(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPhone, Load(S)));
end;

procedure Store_RPhone(P: PObject; var S: TStream);
begin
  PR_RPhone(P)^.Store(S);
end;

type
  PR_RPhoneDir = ^Phones.TPhoneDir;

function Build_RPhoneDir(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPhoneDir, Load(S)));
end;

procedure Store_RPhoneDir(P: PObject; var S: TStream);
begin
  PR_RPhoneDir(P)^.Store(S);
end;

type
  PR_RPhoneCollection = ^Phones.TPhoneCollection;

function Build_RPhoneCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPhoneCollection, Load(S)));
end;

procedure Store_RPhoneCollection(P: PObject; var S: TStream);
begin
  PR_RPhoneCollection(P)^.Store(S);
end;

type
  PR_RStringCol = ^PrintMan.TStringCol;

function Build_RStringCol(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RStringCol, Load(S)));
end;

procedure Store_RStringCol(P: PObject; var S: TStream);
begin
  PR_RStringCol(P)^.Store(S);
end;

type
  PR_RPrintManager = ^PrintMan.TPrintManager;

function Build_RPrintManager(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPrintManager, Load(S)));
end;

procedure Store_RPrintManager(P: PObject; var S: TStream);
begin
  PR_RPrintManager(P)^.Store(S);
end;

type
  PR_RPrintStatus = ^PrintMan.TPrintStatus;

function Build_RPrintStatus(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPrintStatus, Load(S)));
end;

procedure Store_RPrintStatus(P: PObject; var S: TStream);
begin
  PR_RPrintStatus(P)^.Store(S);
end;

type
  PR_RPMWindow = ^PrintMan.TPMWindow;

function Build_RPMWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RPMWindow, Load(S)));
end;

procedure Store_RPMWindow(P: PObject; var S: TStream);
begin
  PR_RPMWindow(P)^.Store(S);
end;

type
  PR_RScroller = ^Scroller.TScroller;

function Build_RScroller(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RScroller, Load(S)));
end;

procedure Store_RScroller(P: PObject; var S: TStream);
begin
  PR_RScroller(P)^.Store(S);
end;

type
  PR_RListViewer = ^Scroller.TListViewer;

function Build_RListViewer(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RListViewer, Load(S)));
end;

procedure Store_RListViewer(P: PObject; var S: TStream);
begin
  PR_RListViewer(P)^.Store(S);
end;

type
  PR_RSysDialog = ^Setups.TSysDialog;

function Build_RSysDialog(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSysDialog, Load(S)));
end;

procedure Store_RSysDialog(P: PObject; var S: TStream);
begin
  PR_RSysDialog(P)^.Store(S);
end;

type
  PR_RCurrDriveInfo = ^Setups.TCurrDriveInfo;

function Build_RCurrDriveInfo(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RCurrDriveInfo, Load(S)));
end;

procedure Store_RCurrDriveInfo(P: PObject; var S: TStream);
begin
  PR_RCurrDriveInfo(P)^.Store(S);
end;

type
  PR_RMouseBar = ^Setups.TMouseBar;

function Build_RMouseBar(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMouseBar, Load(S)));
end;

procedure Store_RMouseBar(P: PObject; var S: TStream);
begin
  PR_RMouseBar(P)^.Store(S);
end;

type
  PR_RSaversDialog = ^Setups.TSaversDialog;

function Build_RSaversDialog(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSaversDialog, Load(S)));
end;

procedure Store_RSaversDialog(P: PObject; var S: TStream);
begin
  PR_RSaversDialog(P)^.Store(S);
end;

type
  PR_RSaversListBox = ^Setups.TSaversListBox;

function Build_RSaversListBox(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RSaversListBox, Load(S)));
end;

procedure Store_RSaversListBox(P: PObject; var S: TStream);
begin
  PR_RSaversListBox(P)^.Store(S);
end;

type
  PR_RTextCollection = ^Startupp.TTextCollection;

function Build_RTextCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTextCollection, Load(S)));
end;

procedure Store_RTextCollection(P: PObject; var S: TStream);
begin
  PR_RTextCollection(P)^.Store(S);
end;

type
  PR_RGameWindow = ^Tetris.TGameWindow;

function Build_RGameWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RGameWindow, Load(S)));
end;

procedure Store_RGameWindow(P: PObject; var S: TStream);
begin
  PR_RGameWindow(P)^.Store(S);
end;

type
  PR_RGameView = ^Tetris.TGameView;

function Build_RGameView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RGameView, Load(S)));
end;

procedure Store_RGameView(P: PObject; var S: TStream);
begin
  PR_RGameView(P)^.Store(S);
end;

type
  PR_RGameInfo = ^Tetris.TGameInfo;

function Build_RGameInfo(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RGameInfo, Load(S)));
end;

procedure Store_RGameInfo(P: PObject; var S: TStream);
begin
  PR_RGameInfo(P)^.Store(S);
end;

type
  PR_RTreeView = ^Tree.TTreeView;

function Build_RTreeView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTreeView, Load(S)));
end;

procedure Store_RTreeView(P: PObject; var S: TStream);
begin
  PR_RTreeView(P)^.Store(S);
end;

type
  PR_RTreeReader = ^Tree.TTreeReader;

function Build_RTreeReader(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTreeReader, Load(S)));
end;

procedure Store_RTreeReader(P: PObject; var S: TStream);
begin
  PR_RTreeReader(P)^.Store(S);
end;

type
  PR_RTreeWindow = ^Tree.TTreeWindow;

function Build_RTreeWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTreeWindow, Load(S)));
end;

procedure Store_RTreeWindow(P: PObject; var S: TStream);
begin
  PR_RTreeWindow(P)^.Store(S);
end;

type
  PR_RTreePanel = ^Tree.TTreePanel;

function Build_RTreePanel(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTreePanel, Load(S)));
end;

procedure Store_RTreePanel(P: PObject; var S: TStream);
begin
  PR_RTreePanel(P)^.Store(S);
end;

type
  PR_RTreeDialog = ^Tree.TTreeDialog;

function Build_RTreeDialog(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTreeDialog, Load(S)));
end;

procedure Store_RTreeDialog(P: PObject; var S: TStream);
begin
  PR_RTreeDialog(P)^.Store(S);
end;

type
  PR_RTreeInfoView = ^Tree.TTreeInfoView;

function Build_RTreeInfoView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RTreeInfoView, Load(S)));
end;

procedure Store_RTreeInfoView(P: PObject; var S: TStream);
begin
  PR_RTreeInfoView(P)^.Store(S);
end;

type
  PR_RHTreeView = ^Tree.THTreeView;

function Build_RHTreeView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RHTreeView, Load(S)));
end;

procedure Store_RHTreeView(P: PObject; var S: TStream);
begin
  PR_RHTreeView(P)^.Store(S);
end;

type
  PR_RDirCollection = ^Tree.TDirCollection;

function Build_RDirCollection(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDirCollection, Load(S)));
end;

procedure Store_RDirCollection(P: PObject; var S: TStream);
begin
  PR_RDirCollection(P)^.Store(S);
end;

type
  PR_REditScrollBar = ^UniWin.TEditScrollBar;

function Build_REditScrollBar(var S: TStream): PObject;
begin
  Result := PObject(New(PR_REditScrollBar, Load(S)));
end;

procedure Store_REditScrollBar(P: PObject; var S: TStream);
begin
  PR_REditScrollBar(P)^.Store(S);
end;

type
  PR_REditFrame = ^UniWin.TEditFrame;

function Build_REditFrame(var S: TStream): PObject;
begin
  Result := PObject(New(PR_REditFrame, Load(S)));
end;

procedure Store_REditFrame(P: PObject; var S: TStream);
begin
  PR_REditFrame(P)^.Store(S);
end;

type
  PR_RUserWindow = ^UserMenu.TUserWindow;

function Build_RUserWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RUserWindow, Load(S)));
end;

procedure Store_RUserWindow(P: PObject; var S: TStream);
begin
  PR_RUserWindow(P)^.Store(S);
end;

type
  PR_RUserView = ^UserMenu.TUserView;

function Build_RUserView(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RUserView, Load(S)));
end;

procedure Store_RUserView(P: PObject; var S: TStream);
begin
  PR_RUserView(P)^.Store(S);
end;

type
  PR_RMyScrollBar = ^Views.TMyScrollBar;

function Build_RMyScrollBar(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RMyScrollBar, Load(S)));
end;

procedure Store_RMyScrollBar(P: PObject; var S: TStream);
begin
  PR_RMyScrollBar(P)^.Store(S);
end;

type
  PR_RDoubleWindow = ^panelwinx.TXDoubleWindow;

function Build_RDoubleWindow(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RDoubleWindow, Load(S)));
end;

procedure Store_RDoubleWindow(P: PObject; var S: TStream);
begin
  PR_RDoubleWindow(P)^.Store(S);
end;

type
  PR_RColorPoint = ^SWE.TColorPoint;

function Build_RColorPoint(var S: TStream): PObject;
begin
  Result := PObject(New(PR_RColorPoint, Load(S)));
end;

procedure Store_RColorPoint(P: PObject; var S: TStream);
begin
  PR_RColorPoint(P)^.Store(S);
end;

procedure SetStreamRecs_regall;
begin

  RFilterValidator.VmtLink := PtrUInt(TypeOf(Validate.TFilterValidator));
  RFilterValidator.Load := @Build_RFilterValidator;

  RFilterValidator.Store := @Store_RFilterValidator;

  RRangeValidator.VmtLink := PtrUInt(TypeOf(Validate.TRangeValidator));
  RRangeValidator.Load := @Build_RRangeValidator;

  RRangeValidator.Store := @Store_RRangeValidator;

  RView.VmtLink := PtrUInt(TypeOf(Views.TView));
  RView.Load := @Build_RView;

  RView.Store := @Store_RView;

  RFrame.VmtLink := PtrUInt(TypeOf(Views.TFrame));
  RFrame.Load := @Build_RFrame;

  RFrame.Store := @Store_RFrame;

  RScrollBar.VmtLink := PtrUInt(TypeOf(Views.TScrollBar));
  RScrollBar.Load := @Build_RScrollBar;

  RScrollBar.Store := @Store_RScrollBar;

  RGroup.VmtLink := PtrUInt(TypeOf(Views.TGroup));
  RGroup.Load := @Build_RGroup;

  RGroup.Store := @Store_RGroup;

  RWindow.VmtLink := PtrUInt(TypeOf(Views.TWindow));
  RWindow.Load := @Build_RWindow;

  RWindow.Store := @Store_RWindow;

  RZIPArchiver.VmtLink := PtrUInt(TypeOf(arc_Zip.TZIPArchive));
  RZIPArchiver.Load := @Build_RZIPArchiver;

  RZIPArchiver.Store := @Store_RZIPArchiver;

  RLHAArchiver.VmtLink := PtrUInt(TypeOf(arc_LHA.TLHAArchive));
  RLHAArchiver.Load := @Build_RLHAArchiver;

  RLHAArchiver.Store := @Store_RLHAArchiver;

  RRARArchiver.VmtLink := PtrUInt(TypeOf(arc_RAR.TRARArchive));
  RRARArchiver.Load := @Build_RRARArchiver;

  RRARArchiver.Store := @Store_RRARArchiver;

  RCABArchiver.VmtLink := PtrUInt(TypeOf(arc_CAB.TCABArchive));
  RCABArchiver.Load := @Build_RCABArchiver;

  RCABArchiver.Store := @Store_RCABArchiver;

  RACEArchiver.VmtLink := PtrUInt(TypeOf(arc_ACE.TACEArchive));
  RACEArchiver.Load := @Build_RACEArchiver;

  RACEArchiver.Store := @Store_RACEArchiver;

  RHAArchiver.VmtLink := PtrUInt(TypeOf(arc_HA.THAArchive));
  RHAArchiver.Load := @Build_RHAArchiver;

  RHAArchiver.Store := @Store_RHAArchiver;

  RARCArchiver.VmtLink := PtrUInt(TypeOf(arc_ARC.TARCArchive));
  RARCArchiver.Load := @Build_RARCArchiver;

  RARCArchiver.Store := @Store_RARCArchiver;

  RBSAArchiver.VmtLink := PtrUInt(TypeOf(arc_BSA.TBSAArchive));
  RBSAArchiver.Load := @Build_RBSAArchiver;

  RBSAArchiver.Store := @Store_RBSAArchiver;

  RBS2Archiver.VmtLink := PtrUInt(TypeOf(arc_BS2.TBS2Archive));
  RBS2Archiver.Load := @Build_RBS2Archiver;

  RBS2Archiver.Store := @Store_RBS2Archiver;

  RHYPArchiver.VmtLink := PtrUInt(TypeOf(arc_HYP.THYPArchive));
  RHYPArchiver.Load := @Build_RHYPArchiver;

  RHYPArchiver.Store := @Store_RHYPArchiver;

  RLIMArchiver.VmtLink := PtrUInt(TypeOf(arc_LIM.TLIMArchive));
  RLIMArchiver.Load := @Build_RLIMArchiver;

  RLIMArchiver.Store := @Store_RLIMArchiver;

  RHPKArchiver.VmtLink := PtrUInt(TypeOf(arc_HPK.THPKArchive));
  RHPKArchiver.Load := @Build_RHPKArchiver;

  RHPKArchiver.Store := @Store_RHPKArchiver;

  RTARArchiver.VmtLink := PtrUInt(TypeOf(arc_TAR.TTARArchive));
  RTARArchiver.Load := @Build_RTARArchiver;

  RTARArchiver.Store := @Store_RTARArchiver;

  RTGZArchiver.VmtLink := PtrUInt(TypeOf(arc_TGZ.TTGZArchive));
  RTGZArchiver.Load := @Build_RTGZArchiver;

  RTGZArchiver.Store := @Store_RTGZArchiver;

  RZXZArchiver.VmtLink := PtrUInt(TypeOf(arc_ZXZ.TZXZArchive));
  RZXZArchiver.Load := @Build_RZXZArchiver;

  RZXZArchiver.Store := @Store_RZXZArchiver;

  RQUARKArchiver.VmtLink := PtrUInt(TypeOf(arc_QRK.TQuArkArchive));
  RQUARKArchiver.Load := @Build_RQUARKArchiver;

  RQUARKArchiver.Store := @Store_RQUARKArchiver;

  RUFAArchiver.VmtLink := PtrUInt(TypeOf(arc_UFA.TUFAArchive));
  RUFAArchiver.Load := @Build_RUFAArchiver;

  RUFAArchiver.Store := @Store_RUFAArchiver;

  RIS3Archiver.VmtLink := PtrUInt(TypeOf(arc_IS3.TIS3Archive));
  RIS3Archiver.Load := @Build_RIS3Archiver;

  RIS3Archiver.Store := @Store_RIS3Archiver;

  RSQZArchiver.VmtLink := PtrUInt(TypeOf(arc_SQZ.TSQZArchive));
  RSQZArchiver.Load := @Build_RSQZArchiver;

  RSQZArchiver.Store := @Store_RSQZArchiver;

  RHAPArchiver.VmtLink := PtrUInt(TypeOf(arc_HAP.THAPArchive));
  RHAPArchiver.Load := @Build_RHAPArchiver;

  RHAPArchiver.Store := @Store_RHAPArchiver;

  RZOOArchiver.VmtLink := PtrUInt(TypeOf(arc_ZOO.TZOOArchive));
  RZOOArchiver.Load := @Build_RZOOArchiver;

  RZOOArchiver.Store := @Store_RZOOArchiver;

  RCHZArchiver.VmtLink := PtrUInt(TypeOf(arc_CHZ.TCHZArchive));
  RCHZArchiver.Load := @Build_RCHZArchiver;

  RCHZArchiver.Store := @Store_RCHZArchiver;

  RUC2Archiver.VmtLink := PtrUInt(TypeOf(arc_UC2.TUC2Archive));
  RUC2Archiver.Load := @Build_RUC2Archiver;

  RUC2Archiver.Store := @Store_RUC2Archiver;

  RAINArchiver.VmtLink := PtrUInt(TypeOf(arc_AIN.TAINArchive));
  RAINArchiver.Load := @Build_RAINArchiver;

  RAINArchiver.Store := @Store_RAINArchiver;

  RS7ZArchiver.VmtLink := PtrUInt(TypeOf(arc_7Z.TS7ZArchive));
  RS7ZArchiver.Load := @Build_RS7ZArchiver;

  RS7ZArchiver.Store := @Store_RS7ZArchiver;

  RBZ2Archiver.VmtLink := PtrUInt(TypeOf(Arc_BZ2.TBZ2Archive));
  RBZ2Archiver.Load := @Build_RBZ2Archiver;

  RBZ2Archiver.Store := @Store_RBZ2Archiver;

  RARJArchiver.VmtLink := PtrUInt(TypeOf(Archiver.TARJArchive));
  RARJArchiver.Load := @Build_RARJArchiver;

  RARJArchiver.Store := @Store_RARJArchiver;

  RFileInfo.VmtLink := PtrUInt(TypeOf(Archiver.TFileInfo));
  RFileInfo.Load := @Build_RFileInfo;

  RFileInfo.Store := @Store_RFileInfo;

  RArcDrive.VmtLink := PtrUInt(TypeOf(ArcView.TArcDrive));
  RArcDrive.Load := @Build_RArcDrive;

  RArcDrive.Store := @Store_RArcDrive;

  RArvidDrive.VmtLink := PtrUInt(TypeOf(Arvid.TArvidDrive));
  RArvidDrive.Load := @Build_RArvidDrive;

  RArvidDrive.Store := @Store_RArvidDrive;

  RTable.VmtLink := PtrUInt(TypeOf(ASCIITab.TTable));
  RTable.Load := @Build_RTable;

  RTable.Store := @Store_RTable;

  RReport.VmtLink := PtrUInt(TypeOf(ASCIITab.TReport));
  RReport.Load := @Build_RReport;

  RReport.Store := @Store_RReport;

  RASCIIChart.VmtLink := PtrUInt(TypeOf(ASCIITab.TASCIIChart));
  RASCIIChart.Load := @Build_RASCIIChart;

  RASCIIChart.Store := @Store_RASCIIChart;

  RCalcWindow.VmtLink := PtrUInt(TypeOf(Calc.TCalcWindow));
  RCalcWindow.Load := @Build_RCalcWindow;

  RCalcWindow.Store := @Store_RCalcWindow;

  RCalcView.VmtLink := PtrUInt(TypeOf(Calc.TCalcView));
  RCalcView.Load := @Build_RCalcView;

  RCalcView.Store := @Store_RCalcView;

  RCalcInfo.VmtLink := PtrUInt(TypeOf(Calc.TCalcInput));
  RCalcInfo.Load := @Build_RCalcInfo;

  RCalcInfo.Store := @Store_RCalcInfo;

  RInfoView.VmtLink := PtrUInt(TypeOf(Calc.TInfoView));
  RInfoView.Load := @Build_RInfoView;

  RInfoView.Store := @Store_RInfoView;

  RCellCollection.VmtLink := PtrUInt(TypeOf(CellsCol.TCellCollection));
  RCellCollection.Load := @Build_RCellCollection;

  RCellCollection.Store := @Store_RCellCollection;

  RCalendarView.VmtLink := PtrUInt(TypeOf(Calendar.TCalendarView));
  RCalendarView.Load := @Build_RCalendarView;

  RCalendarView.Store := @Store_RCalendarView;

  RCalendarWindow.VmtLink := PtrUInt(TypeOf(Calendar.TCalendarWindow));
  RCalendarWindow.Load := @Build_RCalendarWindow;

  RCalendarWindow.Store := @Store_RCalendarWindow;

  RCalcLine.VmtLink := PtrUInt(TypeOf(CCalc.TCalcLine));
  RCalcLine.Load := @Build_RCalcLine;

  RCalcLine.Store := @Store_RCalcLine;

  RIndicator.VmtLink := PtrUInt(TypeOf(CCalc.TIndicator));
  RIndicator.Load := @Build_RIndicator;

  RIndicator.Store := @Store_RIndicator;

  RCollection.VmtLink := PtrUInt(TypeOf(Collect.TCollection));
  RCollection.Load := @Build_RCollection;

  RCollection.Store := @Store_RCollection;

  RLineCollection.VmtLink := PtrUInt(TypeOf(Collect.TLineCollection));
  RLineCollection.Load := @Build_RLineCollection;

  RLineCollection.Store := @Store_RLineCollection;

  RStringCollection.VmtLink := PtrUInt(TypeOf(Collect.TStringCollection));
  RStringCollection.Load := @Build_RStringCollection;

  RStringCollection.Store := @Store_RStringCollection;

  RStrCollection.VmtLink := PtrUInt(TypeOf(Collect.TStrCollection));
  RStrCollection.Load := @Build_RStrCollection;

  RStrCollection.Store := @Store_RStrCollection;

  RStringList.VmtLink := PtrUInt(TypeOf(DNStrL.TStringList));
  RStringList.Load := @Build_RStringList;

  RColorSelector.VmtLink := PtrUInt(TypeOf(ColorSel.TColorSelector));
  RColorSelector.Load := @Build_RColorSelector;

  RColorSelector.Store := @Store_RColorSelector;

  RMonoSelector.VmtLink := PtrUInt(TypeOf(ColorSel.TMonoSelector));
  RMonoSelector.Load := @Build_RMonoSelector;

  RMonoSelector.Store := @Store_RMonoSelector;

  RColorDisplay.VmtLink := PtrUInt(TypeOf(ColorSel.TColorDisplay));
  RColorDisplay.Load := @Build_RColorDisplay;

  RColorDisplay.Store := @Store_RColorDisplay;

  RColorGroupList.VmtLink := PtrUInt(TypeOf(ColorSel.TColorGroupList));
  RColorGroupList.Load := @Build_RColorGroupList;

  RColorGroupList.Store := @Store_RColorGroupList;

  RColorItemList.VmtLink := PtrUInt(TypeOf(ColorSel.TColorItemList));
  RColorItemList.Load := @Build_RColorItemList;

  RColorItemList.Store := @Store_RColorItemList;

  RColorDialog.VmtLink := PtrUInt(TypeOf(ColorSel.TColorDialog));
  RColorDialog.Load := @Build_RColorDialog;

  RColorDialog.Store := @Store_RColorDialog;

  RR_BWSelector.VmtLink := PtrUInt(TypeOf(DNColor.T_BWSelector));
  RR_BWSelector.Load := @Build_RR_BWSelector;

  RR_BWSelector.Store := @Store_RR_BWSelector;

  RDBWindow.VmtLink := PtrUInt(TypeOf(DBView.TDBWindow));
  RDBWindow.Load := @Build_RDBWindow;

  RDBWindow.Store := @Store_RDBWindow;

  RDBViewer.VmtLink := PtrUInt(TypeOf(DBView.TDBViewer));
  RDBViewer.Load := @Build_RDBViewer;

  RDBViewer.Store := @Store_RDBViewer;

  RDBIndicator.VmtLink := PtrUInt(TypeOf(DBView.TDBIndicator));
  RDBIndicator.Load := @Build_RDBIndicator;

  RDBIndicator.Store := @Store_RDBIndicator;

  RFieldListBox.VmtLink := PtrUInt(TypeOf(DBView.TFieldListBox));
  RFieldListBox.Load := @Build_RFieldListBox;

  RFieldListBox.Store := @Store_RFieldListBox;

  RDialog.VmtLink := PtrUInt(TypeOf(Dialogs.TDialog));
  RDialog.Load := @Build_RDialog;

  RDialog.Store := @Store_RDialog;

  RInputLine.VmtLink := PtrUInt(TypeOf(Dialogs.TInputLine));
  RInputLine.Load := @Build_RInputLine;

  RInputLine.Store := @Store_RInputLine;

  RHexLine.VmtLink := PtrUInt(TypeOf(DNDlgs.THexLine));
  RHexLine.Load := @Build_RHexLine;

  RHexLine.Store := @Store_RHexLine;

  RLongInputLine.VmtLink := PtrUInt(TypeOf(Dialogs.TLongInputLine));
  RLongInputLine.Load := @Build_RLongInputLine;

  RLongInputLine.Store := @Store_RLongInputLine;

  RButton.VmtLink := PtrUInt(TypeOf(Dialogs.TButton));
  RButton.Load := @Build_RButton;

  RButton.Store := @Store_RButton;

  RCluster.VmtLink := PtrUInt(TypeOf(Dialogs.TCluster));
  RCluster.Load := @Build_RCluster;

  RCluster.Store := @Store_RCluster;

  RRadioButtons.VmtLink := PtrUInt(TypeOf(Dialogs.TRadioButtons));
  RRadioButtons.Load := @Build_RRadioButtons;

  RRadioButtons.Store := @Store_RRadioButtons;

  RComboBox.VmtLink := PtrUInt(TypeOf(DNDlgs.TComboBox));
  RComboBox.Load := @Build_RComboBox;

  RComboBox.Store := @Store_RComboBox;

  RCheckBoxes.VmtLink := PtrUInt(TypeOf(Dialogs.TCheckBoxes));
  RCheckBoxes.Load := @Build_RCheckBoxes;

  RCheckBoxes.Store := @Store_RCheckBoxes;

  RMultiCheckBoxes.VmtLink := PtrUInt(TypeOf(Dialogs.TMultiCheckBoxes));
  RMultiCheckBoxes.Load := @Build_RMultiCheckBoxes;

  RMultiCheckBoxes.Store := @Store_RMultiCheckBoxes;

  RListBox.VmtLink := PtrUInt(TypeOf(Dialogs.TListBox));
  RListBox.Load := @Build_RListBox;

  RListBox.Store := @Store_RListBox;

  RStaticText.VmtLink := PtrUInt(TypeOf(Dialogs.TStaticText));
  RStaticText.Load := @Build_RStaticText;

  RStaticText.Store := @Store_RStaticText;

  RLabel.VmtLink := PtrUInt(TypeOf(Dialogs.TLabel));
  RLabel.Load := @Build_RLabel;

  RLabel.Store := @Store_RLabel;

  RHistory.VmtLink := PtrUInt(TypeOf(Dialogs.THistory));
  RHistory.Load := @Build_RHistory;

  RHistory.Store := @Store_RHistory;

  RParamText.VmtLink := PtrUInt(TypeOf(DNDlgs.TParamText));
  RParamText.Load := @Build_RParamText;

  RParamText.Store := @Store_RParamText;

  RNotepad.VmtLink := PtrUInt(TypeOf(DNDlgs.TNotepad));
  RNotepad.Load := @Build_RNotepad;

  RNotepad.Store := @Store_RNotepad;

  RPage.VmtLink := PtrUInt(TypeOf(DNDlgs.TPage));
  RPage.Load := @Build_RPage;

  RPage.Store := @Store_RPage;

  RBookmark.VmtLink := PtrUInt(TypeOf(DNDlgs.TBookmark));
  RBookmark.Load := @Build_RBookmark;

  RBookmark.Store := @Store_RBookmark;

  RPageFrame.VmtLink := PtrUInt(TypeOf(DNDlgs.TPageFrame));
  RPageFrame.Load := @Build_RPageFrame;

  RPageFrame.Store := @Store_RPageFrame;

  RNotepadFrame.VmtLink := PtrUInt(TypeOf(DNDlgs.TNotepadFrame));
  RNotepadFrame.Load := @Build_RNotepadFrame;

  RNotepadFrame.Store := @Store_RNotepadFrame;

  RDiskInfo.VmtLink := PtrUInt(TypeOf(DiskInfo.TDiskInfo));
  RDiskInfo.Load := @Build_RDiskInfo;

  RDiskInfo.Store := @Store_RDiskInfo;

  RDriveView.VmtLink := PtrUInt(TypeOf(DiskInfo.TDriveView));
  RDriveView.Load := @Build_RDriveView;

  RDriveView.Store := @Store_RDriveView;

  RBackground.VmtLink := PtrUInt(TypeOf(mainapp.TBackground));
  RBackground.Load := @Build_RBackground;

  RBackground.Store := @Store_RBackground;

  RDesktop.VmtLink := PtrUInt(TypeOf(mainapp.TDesktop));
  RDesktop.Load := @Build_RDesktop;

  RDesktop.Store := @Store_RDesktop;

  RFileInputLine.VmtLink := PtrUInt(TypeOf(DNStdDlg.TFileInputLine));
  RFileInputLine.Load := @Build_RFileInputLine;

  RFileInputLine.Store := @Store_RFileInputLine;

  RFileCollection.VmtLink := PtrUInt(TypeOf(DNStdDlg.TFileCollection));
  RFileCollection.Load := @Build_RFileCollection;

  RFileCollection.Store := @Store_RFileCollection;

  RFileList.VmtLink := PtrUInt(TypeOf(DNStdDlg.TFileList));
  RFileList.Load := @Build_RFileList;

  RFileList.Store := @Store_RFileList;

  RFileInfoPane.VmtLink := PtrUInt(TypeOf(DNStdDlg.TFileInfoPane));
  RFileInfoPane.Load := @Build_RFileInfoPane;

  RFileInfoPane.Store := @Store_RFileInfoPane;

  RFileDialog.VmtLink := PtrUInt(TypeOf(DNStdDlg.TFileDialog));
  RFileDialog.Load := @Build_RFileDialog;

  RFileDialog.Store := @Store_RFileDialog;

  RSortedListBox.VmtLink := PtrUInt(TypeOf(DNStdDlg.TSortedListBox));
  RSortedListBox.Load := @Build_RSortedListBox;

  RSortedListBox.Store := @Store_RSortedListBox;

  RDataSaver.VmtLink := PtrUInt(TypeOf(DNUtil.TDataSaver));
  RDataSaver.Load := @Build_RDataSaver;

  RDataSaver.Store := @Store_RDataSaver;

  RDrive.VmtLink := PtrUInt(TypeOf(Drives.TDrive));
  RDrive.Load := @Build_RDrive;

  RDrive.Store := @Store_RDrive;

  RInfoLine.VmtLink := PtrUInt(TypeOf(editundo.TInfoLine));
  RInfoLine.Load := @Build_RInfoLine;

  RInfoLine.Store := @Store_RInfoLine;

  RBookLine.VmtLink := PtrUInt(TypeOf(editundo.TBookmarkLine));
  RBookLine.Load := @Build_RBookLine;

  RBookLine.Store := @Store_RBookLine;

  RXFileEditor.VmtLink := PtrUInt(TypeOf(Editor.TXFileEditor));
  RXFileEditor.Load := @Build_RXFileEditor;

  RXFileEditor.Store := @Store_RXFileEditor;

  RFindDrive.VmtLink := PtrUInt(TypeOf(FileFind.TFindDrive));
  RFindDrive.Load := @Build_RFindDrive;

  RFindDrive.Store := @Store_RFindDrive;

  RTempDrive.VmtLink := PtrUInt(TypeOf(FileFind.TTempDrive));
  RTempDrive.Load := @Build_RTempDrive;

  RTempDrive.Store := @Store_RTempDrive;

  RFilesCollection.VmtLink := PtrUInt(TypeOf(FilesCol.TFilesCollection));
  RFilesCollection.Load := @Build_RFilesCollection;

  RFilesCollection.Store := @Store_RFilesCollection;

  RFilePanel.VmtLink := PtrUInt(TypeOf(filepanel.TFilePanel));
  RFilePanel.Load := @Build_RFilePanel;

  RFilePanel.Store := @Store_RFilePanel;

  RFlPInfoView.VmtLink := PtrUInt(TypeOf(filepanel.TInfoView));
  RFlPInfoView.Load := @Build_RFlPInfoView;

  RFlPInfoView.Store := @Store_RFlPInfoView;

  RDirView.VmtLink := PtrUInt(TypeOf(filepanel.TDirView));
  RDirView.Load := @Build_RDirView;

  RDirView.Store := @Store_RDirView;

  RSortView.VmtLink := PtrUInt(TypeOf(TopView_.TSortView));
  RSortView.Load := @Build_RSortView;

  RSortView.Store := @Store_RSortView;

  RSeparator.VmtLink := PtrUInt(TypeOf(panelwin.TSeparator));
  RSeparator.Load := @Build_RSeparator;

  RSeparator.Store := @Store_RSeparator;

  RDriveLine.VmtLink := PtrUInt(TypeOf(filepanel.TDriveLine));
  RDriveLine.Load := @Build_RDriveLine;

  RDriveLine.Store := @Store_RDriveLine;

  RDirStorage.VmtLink := PtrUInt(TypeOf(FStorage.TDirStorage));
  RDirStorage.Load := @Build_RDirStorage;

  RDirStorage.Store := @Store_RDirStorage;

  RFileViewer.VmtLink := PtrUInt(TypeOf(FViewer.TFileViewer));
  RFileViewer.Load := @Build_RFileViewer;

  RFileViewer.Store := @Store_RFileViewer;

  RFileWindow.VmtLink := PtrUInt(TypeOf(FViewer.TFileWindow));
  RFileWindow.Load := @Build_RFileWindow;

  RFileWindow.Store := @Store_RFileWindow;

  RViewScroll.VmtLink := PtrUInt(TypeOf(FViewer.TViewScroll));
  RViewScroll.Load := @Build_RViewScroll;

  RViewScroll.Store := @Store_RViewScroll;

  RQFileViewer.VmtLink := PtrUInt(TypeOf(FViewer.TQFileViewer));
  RQFileViewer.Load := @Build_RQFileViewer;

  RQFileViewer.Store := @Store_RQFileViewer;

  RDFileViewer.VmtLink := PtrUInt(TypeOf(FViewer.TDFileViewer));
  RDFileViewer.Load := @Build_RDFileViewer;

  RDFileViewer.Store := @Store_RDFileViewer;

  RViewInfo.VmtLink := PtrUInt(TypeOf(FViewer.TViewInfo));
  RViewInfo.Load := @Build_RViewInfo;

  RViewInfo.Store := @Store_RViewInfo;

  RTrashCan.VmtLink := PtrUInt(TypeOf(Gauges.TTrashCan));
  RTrashCan.Load := @Build_RTrashCan;

  RTrashCan.Store := @Store_RTrashCan;

  RKeyMacros.VmtLink := PtrUInt(TypeOf(Gauges.TKeyMacros));
  RKeyMacros.Load := @Build_RKeyMacros;

  RKeyMacros.Store := @Store_RKeyMacros;

  RHelpTopic.VmtLink := PtrUInt(TypeOf(HelpKern.THelpTopic));
  RHelpTopic.Load := @Build_RHelpTopic;

  RHelpTopic.Store := @Store_RHelpTopic;

  RHelpIndex.VmtLink := PtrUInt(TypeOf(HelpKern.THelpIndex));
  RHelpIndex.Load := @Build_RHelpIndex;

  RHelpIndex.Store := @Store_RHelpIndex;

  REditHistoryCol.VmtLink := PtrUInt(TypeOf(Histries.TEditHistoryCol));
  REditHistoryCol.Load := @Build_REditHistoryCol;

  REditHistoryCol.Store := @Store_REditHistoryCol;

  RViewHistoryCol.VmtLink := PtrUInt(TypeOf(Histries.TViewHistoryCol));
  RViewHistoryCol.Load := @Build_RViewHistoryCol;

  RViewHistoryCol.Store := @Store_RViewHistoryCol;

  RMenuBar.VmtLink := PtrUInt(TypeOf(Menus.TMenuBar));
  RMenuBar.Load := @Build_RMenuBar;

  RMenuBar.Store := @Store_RMenuBar;

  RMenuBox.VmtLink := PtrUInt(TypeOf(Menus.TMenuBox));
  RMenuBox.Load := @Build_RMenuBox;

  RMenuBox.Store := @Store_RMenuBox;

  RStatusLine.VmtLink := PtrUInt(TypeOf(Menus.TStatusLine));
  RStatusLine.Load := @Build_RStatusLine;

  RStatusLine.Store := @Store_RStatusLine;

  RMenuPopup.VmtLink := PtrUInt(TypeOf(Menus.TMenuPopup));
  RMenuPopup.Load := @Build_RMenuPopup;

  RMenuPopup.Store := @Store_RMenuPopup;

  RFileEditor.VmtLink := PtrUInt(TypeOf(editcore.TFileEditor));
  RFileEditor.Load := @Build_RFileEditor;

  RFileEditor.Store := @Store_RFileEditor;

  REditWindow.VmtLink := PtrUInt(TypeOf(editwin.TEditWindow));
  REditWindow.Load := @Build_REditWindow;

  REditWindow.Store := @Store_REditWindow;

  RDStringView.VmtLink := PtrUInt(TypeOf(StrView.TDStringView));
  RDStringView.Load := @Build_RDStringView;

  RDStringView.Store := @Store_RDStringView;

  RPhone.VmtLink := PtrUInt(TypeOf(Phones.TPhone));
  RPhone.Load := @Build_RPhone;

  RPhone.Store := @Store_RPhone;

  RPhoneDir.VmtLink := PtrUInt(TypeOf(Phones.TPhoneDir));
  RPhoneDir.Load := @Build_RPhoneDir;

  RPhoneDir.Store := @Store_RPhoneDir;

  RPhoneCollection.VmtLink := PtrUInt(TypeOf(Phones.TPhoneCollection));
  RPhoneCollection.Load := @Build_RPhoneCollection;

  RPhoneCollection.Store := @Store_RPhoneCollection;

  RStringCol.VmtLink := PtrUInt(TypeOf(PrintMan.TStringCol));
  RStringCol.Load := @Build_RStringCol;

  RStringCol.Store := @Store_RStringCol;

  RPrintManager.VmtLink := PtrUInt(TypeOf(PrintMan.TPrintManager));
  RPrintManager.Load := @Build_RPrintManager;

  RPrintManager.Store := @Store_RPrintManager;

  RPrintStatus.VmtLink := PtrUInt(TypeOf(PrintMan.TPrintStatus));
  RPrintStatus.Load := @Build_RPrintStatus;

  RPrintStatus.Store := @Store_RPrintStatus;

  RPMWindow.VmtLink := PtrUInt(TypeOf(PrintMan.TPMWindow));
  RPMWindow.Load := @Build_RPMWindow;

  RPMWindow.Store := @Store_RPMWindow;

  RScroller.VmtLink := PtrUInt(TypeOf(Scroller.TScroller));
  RScroller.Load := @Build_RScroller;

  RScroller.Store := @Store_RScroller;

  RListViewer.VmtLink := PtrUInt(TypeOf(Scroller.TListViewer));
  RListViewer.Load := @Build_RListViewer;

  RListViewer.Store := @Store_RListViewer;

  RSysDialog.VmtLink := PtrUInt(TypeOf(Setups.TSysDialog));
  RSysDialog.Load := @Build_RSysDialog;

  RSysDialog.Store := @Store_RSysDialog;

  RCurrDriveInfo.VmtLink := PtrUInt(TypeOf(Setups.TCurrDriveInfo));
  RCurrDriveInfo.Load := @Build_RCurrDriveInfo;

  RCurrDriveInfo.Store := @Store_RCurrDriveInfo;

  RMouseBar.VmtLink := PtrUInt(TypeOf(Setups.TMouseBar));
  RMouseBar.Load := @Build_RMouseBar;

  RMouseBar.Store := @Store_RMouseBar;

  RSaversDialog.VmtLink := PtrUInt(TypeOf(Setups.TSaversDialog));
  RSaversDialog.Load := @Build_RSaversDialog;

  RSaversDialog.Store := @Store_RSaversDialog;

  RSaversListBox.VmtLink := PtrUInt(TypeOf(Setups.TSaversListBox));
  RSaversListBox.Load := @Build_RSaversListBox;

  RSaversListBox.Store := @Store_RSaversListBox;

  RTextCollection.VmtLink := PtrUInt(TypeOf(Startupp.TTextCollection));
  RTextCollection.Load := @Build_RTextCollection;

  RTextCollection.Store := @Store_RTextCollection;

  RGameWindow.VmtLink := PtrUInt(TypeOf(Tetris.TGameWindow));
  RGameWindow.Load := @Build_RGameWindow;

  RGameWindow.Store := @Store_RGameWindow;

  RGameView.VmtLink := PtrUInt(TypeOf(Tetris.TGameView));
  RGameView.Load := @Build_RGameView;

  RGameView.Store := @Store_RGameView;

  RGameInfo.VmtLink := PtrUInt(TypeOf(Tetris.TGameInfo));
  RGameInfo.Load := @Build_RGameInfo;

  RGameInfo.Store := @Store_RGameInfo;

  RTreeView.VmtLink := PtrUInt(TypeOf(Tree.TTreeView));
  RTreeView.Load := @Build_RTreeView;

  RTreeView.Store := @Store_RTreeView;

  RTreeReader.VmtLink := PtrUInt(TypeOf(Tree.TTreeReader));
  RTreeReader.Load := @Build_RTreeReader;

  RTreeReader.Store := @Store_RTreeReader;

  RTreeWindow.VmtLink := PtrUInt(TypeOf(Tree.TTreeWindow));
  RTreeWindow.Load := @Build_RTreeWindow;

  RTreeWindow.Store := @Store_RTreeWindow;

  RTreePanel.VmtLink := PtrUInt(TypeOf(Tree.TTreePanel));
  RTreePanel.Load := @Build_RTreePanel;

  RTreePanel.Store := @Store_RTreePanel;

  RTreeDialog.VmtLink := PtrUInt(TypeOf(Tree.TTreeDialog));
  RTreeDialog.Load := @Build_RTreeDialog;

  RTreeDialog.Store := @Store_RTreeDialog;

  RTreeInfoView.VmtLink := PtrUInt(TypeOf(Tree.TTreeInfoView));
  RTreeInfoView.Load := @Build_RTreeInfoView;

  RTreeInfoView.Store := @Store_RTreeInfoView;

  RHTreeView.VmtLink := PtrUInt(TypeOf(Tree.THTreeView));
  RHTreeView.Load := @Build_RHTreeView;

  RHTreeView.Store := @Store_RHTreeView;

  RDirCollection.VmtLink := PtrUInt(TypeOf(Tree.TDirCollection));
  RDirCollection.Load := @Build_RDirCollection;

  RDirCollection.Store := @Store_RDirCollection;

  REditScrollBar.VmtLink := PtrUInt(TypeOf(UniWin.TEditScrollBar));
  REditScrollBar.Load := @Build_REditScrollBar;

  REditScrollBar.Store := @Store_REditScrollBar;

  REditFrame.VmtLink := PtrUInt(TypeOf(UniWin.TEditFrame));
  REditFrame.Load := @Build_REditFrame;

  REditFrame.Store := @Store_REditFrame;

  RUserWindow.VmtLink := PtrUInt(TypeOf(UserMenu.TUserWindow));
  RUserWindow.Load := @Build_RUserWindow;

  RUserWindow.Store := @Store_RUserWindow;

  RUserView.VmtLink := PtrUInt(TypeOf(UserMenu.TUserView));
  RUserView.Load := @Build_RUserView;

  RUserView.Store := @Store_RUserView;

  RMyScrollBar.VmtLink := PtrUInt(TypeOf(Views.TMyScrollBar));
  RMyScrollBar.Load := @Build_RMyScrollBar;

  RMyScrollBar.Store := @Store_RMyScrollBar;

  RDoubleWindow.VmtLink := PtrUInt(TypeOf(panelwinx.TXDoubleWindow));
  RDoubleWindow.Load := @Build_RDoubleWindow;

  RDoubleWindow.Store := @Store_RDoubleWindow;

  RColorPoint.VmtLink := PtrUInt(TypeOf(SWE.TColorPoint));
  RColorPoint.Load := @Build_RColorPoint;

  RColorPoint.Store := @Store_RColorPoint;

end;

initialization
  SetStreamRecs_regall;
end.
