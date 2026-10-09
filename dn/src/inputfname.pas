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

unit inputfname;

interface

uses
  Drivers, Defines, Streams, Views, Dialogs
  ;

type
   { quick-rename line (Alt-F6). It runs directly
   in the manager, without an enclosing dialog, so it has its own
   Execute method. Palette colors (C) go into CM_RenameSingleL}
  TInputFName = class(TInputLine)
    EndView: Word;
    function Execute: Word; override;
    procedure HandleEvent(var Event: TEvent); override;
    end;

  TColorPoint = class(TView)
    Color: Byte;
    constructor Create(var ABounds: TRect; AColor: Byte); overload;
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    procedure Write(Os: opstream); override;
    procedure Draw; override;
    end;

implementation

uses
  basics, Commands, mainapp
  ;

function TInputFName.Execute: Word;
  var
    Event: TEvent;
  begin
  EndView := 0;
  repeat
    Owner.GetEvent(Event);
    if Event.What = evNothing then
      TinySlice;
    HandleEvent(Event);
  until EndView <> 0;
  Result := EndView;
  end;

procedure TInputFName.HandleEvent(var Event: TEvent);
  begin
  case Event.What of
    evKeyDown:
      begin
      case DNKeyCode(Event) of
        kbEnter:
          begin
          EndView := cmOK;
          ClearEvent(Event);
          Exit;
          end;
        kbESC:
          begin
          EndView := cmCancel;
          ClearEvent(Event);
          Exit;
          end;
        end {case};
      end;
  end {case};
  if  (Event.What <> evNothing) then
    inherited HandleEvent(Event);
  end { TInputFName.HandleEvent };

constructor TColorPoint.Create(var ABounds: TRect; AColor: Byte);
  begin
  ABounds.B.X := ABounds.A.X+1;
  ABounds.B.Y := ABounds.A.Y+1;
  inherited Create(ABounds);
  Color := AColor;
  end;

function TColorPoint.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  inherited Read(Ip);
  Ip.ReadBytes(Color, SizeOf(Color));
  end;

procedure TColorPoint.Write(Os: opstream);
  begin
  inherited Write(Os);
  Os.WriteBytes(Color, SizeOf(Color));
  end;

class function TColorPoint.Build: TStreamable;
begin
  Result := TColorPoint.Create(streamableInit);
end;

function TColorPoint.StreamableName: ShortString;
begin
  Result := 'inputfname.TColorPoint';
end;

procedure TColorPoint.Draw;
  var
    B: Word;
  begin
  B := Application.GetColorW(Color) shl 8+$00FE {*};
  WriteLineW(0, 0, 1, 1, B);
  end;

end.
