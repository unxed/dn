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

unit panelwinx;

interface

uses
  panelwin, Drivers, Views, objutil
  ;

type
  TXDoubleWindow = class;
  TXDoubleWindow = class(TDoubleWindow)
    procedure SetState(AState: Word; Enable: Boolean); override;
    function GetPalette: TPalette; override;
    procedure HandleEvent(var Event: TEvent); override;
    end;

implementation
uses
  Commands, basics, strutil, fileutil, mainapp, DNUtil
  ;

function TXDoubleWindow.GetPalette: TPalette;
  const
    S: String[Length(CDoubleWindow)] = CDoubleWindow;
  begin
  GetPalette := MakePalette(S);
  end;

procedure TXDoubleWindow.SetState(AState: Word; Enable: Boolean);
  begin
  inherited SetState(AState, Enable);
  if  (AState and sfDragging <> 0) or
      (AState and (sfSelected+sfActive) <> 0)
  then
    Separator.Draw;
  if AState = sfSelected then
    begin
    SetState(sfActive, Enable);
    
    TrashCan.Hide;
    
    if Enable then
      begin
      Current.SetState(sfSelected, True);
        // so that ActivePanel and PassivePanel are set
      EnableCommands(DblWndCommands)
      end
    else
      DisableCommands(DblWndCommands);
    end
    
  else if TrashCan.ImVisible then
    begin
    TrashCan.Show;
    TrashCan.MakeFirst;
    end;
  
  end { TXDoubleWindow.SetState };

procedure TXDoubleWindow.HandleEvent(var Event: TEvent);
  var
    CE: Boolean;
    Visible, Selected: array[TPanelNum] of Boolean;
    EV: TEvent;
    i: TPanelNum;
  begin
  Visible[pLeft] := False;
  Visible[pRight] := False;
  Selected := Visible;
  for i := pLeft to pRight do
    begin
    with Panel[i] do
      begin
      if AnyPanel <> nil then
        begin
        Visible[i] := AnyPanel.GetState(sfVisible);
        Selected[i] := AnyPanel.GetState(sfSelected);
        end;
      end;
    end;

  CE := True;
  case Event.What of
    evKeyDown:
      case DNKeyCode(Event) of
        {kbCtrlP,}
        kbCtrlLeft, kbCtrlRight,
        kbCtrlShiftLeft, kbCtrlShiftRight,
        kbAlt1, kbAlt2, kbAlt3, kbAlt4, kbAlt5,
        kbAlt6, kbAlt7, kbAlt8, kbAlt9, kbAlt0,
        kbCtrl1, kbCtrl2, kbCtrl3, kbCtrl4, kbCtrl5, {DataCompBoy}
        kbCtrl6, kbCtrl7, kbCtrl8, kbCtrl9, kbCtrl0, {DataCompBoy}
        kbAltLeft, kbAltRight,
        kbAltShiftLeft, kbAltShiftRight,
        kbCtrlAltZ, {Knave 11.09.99} {DataCompBoy}
        kbAltCtrlSqBracketL, kbAltCtrlSqBracketR,
        kbCtrlSqBracketL, kbCtrlSqBracketR:
          begin
          HandleCommand(Event);
          CE := False;
          end;
      end {case};
    evBroadcast:
      case Event.Message.Command of
        cmLookForPanels, cmGetUserParams, cmGetUserParamsWL,
        cmChangeDrv,
        cmIsRightPanel:
          begin
          HandleCommand(Event);
          CE := False
          end;
      end {case};
    evCommand:
      case Event.Message.Command of
        cmChangeDirectory:
          begin {AK155 This message can really come ONLY
            from the tree, so comparing with dtTree is, to put it mildly,
            unexpected, but works. Of course, instead of this trickery
            the tree should call the panel ChDir directly }
          Panel[Selected[NonFilePanelType <> dtTree]].
            FilePanel.HandleEvent(Event);
          Exit;
          end;
        cmChangeTree:
          if NonFilePanelType = dtTree then
            Panel[NonFilePanel].AnyPanel.HandleEvent(Event);
        cmRereadInfo:
          begin
          for i := pLeft to pRight do
            begin
            with Panel[i] do
              if AnyPanel <> nil then
                AnyPanel.HandleEvent(Event);
            end;
          Exit;
          end;
        cmCloseLinked,
        cmMakeForced,
        cmRereadForced,
        cmTotalReread,
        cmUpdateHighlight,
        cmReboundPanel,
        cmRereadDir:
          begin
          EV := Event;
          Panel[pLeft].FilePanel.HandleEvent(Event);
          Event := EV;
          Panel[pRight].FilePanel.HandleEvent(Event);
          ClearEvent(Event);
          end;
        cmPushName,
        cmZoom,
        cmMaxi,
        cmGetName,
        cmPostHideRight,
        cmPostHideLeft,
        cmChangeInactive,
        cmPanelCompare,
        cmDiskInfo,
        
        cmLoadViewFile,
        cmPushFullName,
        cmPushFirstName,
        cmPushInternalName,
        cmFindTree,
        cmRereadTree,
        cmHideLeft,
        cmHideRight,
        cmChangeLeft,
        cmChangeRight,
        cmDirTree,
        cmQuickView,
        cmDizView,
        cmSwapPanels,
        cmSwitchOther:
          begin
          HandleCommand(Event);
          CE := False
          end;
      end {case};
  end {case};

  if  (Event.What <> evNothing) and CE then
    inherited HandleEvent(Event);
  end { TXDoubleWindow.HandleEvent };
end.
