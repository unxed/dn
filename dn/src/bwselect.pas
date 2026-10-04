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

unit bwselect;

{ Carved by tools/dn-carve.py from colorsel.pas: the classes T_BWSelector of Dos Navigator. }

interface

uses
  Defines, Streams, Drivers, Views, Commands, Dialogs, TvColorSel;

type
  P_BWSelector = ^T_BWSelector;
  T_BWSelector = class(TMonoSelector)
    SelType: TColorSel; {Is't a selector of Foreground color ? }
    constructor Create(var Bounds: TRect; ASelType: TColorSel;
         AStrings: PSItem);
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure NewColor; virtual;
    end;

implementation

constructor T_BWSelector.Create(var Bounds: TRect; ASelType: TColorSel;
    AStrings: PSItem);
  begin
  SelType := ASelType;
  inherited Create(Bounds);
  EventMask := EventMask or evBroadcast;
  Options := Options or (ofSelectable+ofFirstClick+ofFramed);
  end;

procedure T_BWSelector.HandleEvent(var Event: TEvent);
  var
    i: Byte;

  begin
  inherited HandleEvent(Event);
  if GetState(sfVisible) then
    if  (Event.What = evBroadcast) and (Event.Command = cmColorSet) then
      begin
      Value := Event.InfoByte;
      case SelType of
        csForeground:
          for i := 0 to 3 do
            if MonoColors[i] = (Value and $0F) then
              begin
              MovedTo(i);
              DrawView;
              Exit
              end;
        csBackground:
          for i := 0 to 3 do
            if MonoColors[i] = (Value shr 4) then
              begin
              MovedTo(i);
              DrawView;
              Exit
              end;
      end {case};
      MovedTo(-1);
      end;
  end { T_BWSelector.HandleEvent };

procedure T_BWSelector.NewColor;
  begin
  if SelType = csForeground
  then
    MessageL(Owner, evBroadcast, cmColorForegroundChanged, Value and $0F)
  else
    MessageL(Owner, evBroadcast, cmColorBackgroundChanged, Value and $0F);
  end;

{ TColorDisplay }


end.
