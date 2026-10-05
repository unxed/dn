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

unit calcline;

interface

uses
  Defines, Streams, Dialogs, Views, Drivers, evaluator
  ;

type
  TCalcLine = class(TInputLine)
    procedure HandleEvent(var Event: TEvent); override;
    procedure SetData(var B); override;
    procedure SetValues(SetSelf: Boolean);
    procedure Awaken; override;
    destructor Destroy; override;
    end;

  TIndicator = class(TView)
    CalcLine: TCalcLine;
    Radio: TRadioButtons;
    Value: CReal;
    SResult: array[0..5] of String[40];
    CalcError: Boolean;
    constructor Create(var R: TRect);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure HandleEvent(var Event: TEvent); override;
    procedure Draw; override;
    procedure WrtT(X: CReal; var S: String);
    function GetPalette: TPalette; override;
    end;

type
  TCalcFormat = array[0..5] of SmallInt;

procedure InsertCalc;

const
  Calc: TView = nil;

implementation

uses
  basics, strutil, fileutil,
  mainapp, DNUtil,
  Commands, HistList, startup, dlgrecs
  , objutil
  ;

{ AK155 19/10/2006
 TCalcLine and TIndicator are meant for use inside the calculator
dialog. That dialog's DirectLink[1] must point to the input line,
DirectLink[2] to the radio buttons for result format, and DirectLink[3]
is undefined in the resource but used in code as a link to the
indicator (PIndicator) from the input line. Putting such a field
directly into TCalcLine would prevent loading the input line from the
dialog resource and replacing its type with TCalcLine }

constructor TIndicator.Create(var R: TRect);
  begin
  inherited Create(R);
  EventMask := evBroadcast;
  CalcError := False;
  Value := 0;
  end;

constructor TIndicator.Load(var S: TStream);
  begin
  inherited Load(S);
  GetPeerViewPtr(S, CalcLine);
  GetPeerViewPtr(S, Radio);
  end;

procedure TIndicator.Store(var S: TStream);
  begin
  inherited Store(S);
  PutPeerViewPtr(S, CalcLine);
  PutPeerViewPtr(S, Radio);
  end;


function TIndicator.GetPalette: TPalette;
  const
    S: String[1] = CCluster;
  begin
  GetPalette := MakePalette(S);
  end;

function GetNValue(L: LongInt; A: Integer): String;
  begin
  Result := '';
  if L = 0 then
    Result := '0'
  else
    while (L <> 0) do
      begin
      Result := HexStr[(L and ((1 shl A)-1))]+Result;
      L := L shr A;
      end;
  end;


procedure TIndicator.HandleEvent(var Event: TEvent);
  var
    SelectedForm: Integer;
    s: string;
    sCalcFormat: array[Low(TCalcFormat)..High(TCalcFormat)] of string[2];
    i, n, iErr: Integer;
  label
    TryFormatDlg;

  procedure CE;
    begin
    DrawView;
    ClearEvent(Event);
    end;

  begin
  inherited HandleEvent(Event);
  if  (Event.What = evBroadcast) then
    case Event.Command of
      cmSetValue:
        begin
        CalcError := False;
        Value := PCReal(Event.InfoPtr)^;
        Draw;
        CE
        end;
      cmSetError:
        begin
        CalcError := True;
        CE
        end;
      cmCancel:
        begin
        Event.What := evCommand;
        Event.Command := cmClose;
        Event.InfoPtr := nil;
        PutEvent(Event);
        CE
        end;
      cmCopyClip:
        begin
        ClearEvent(Event);
        Radio.GetData(SelectedForm);
        PutInClip(SResult[SelectedForm]);
        end;
      cmChangeFormat:
        begin
        ClearEvent(Event);
TryFormatDlg:
        for i := Low(TCalcFormat) to High(TCalcFormat) do
          begin
          Str(CalcFormat[i], s);
          sCalcFormat[i] := s;
          end;
        if ExecResource(dlgCalcFormat, sCalcFormat) = cmOK then
          begin
          for i := Low(TCalcFormat) to High(TCalcFormat) do
            begin
            Val(sCalcFormat[i], n, iErr);
            if (iErr <> 0) or (n < 0) or (n > MaxCalcFormat[i]) then
              goto TryFormatDlg;
            if n <> CalcFormat[i] then
              begin
              CalcFormat[i] := n;
              ConfigModified := True;
              end;
            end;
          Draw;
          end;
        end;
    end {case};
  end { TIndicator.HandleEvent };

procedure TIndicator.WrtT(X: CReal; var S: String);
  var
    Hour, Min: LongInt;
    Sec: CReal;
    Negative: Boolean;
    sHour, sMin: String[20];
  begin
  if X < 0 then
    begin
    Negative := True;
    X := -X;
    end
  else
    Negative := False;
  Hour := Trunc(X/3600);
  Min := Trunc((X-Hour*3600)/60);
  Sec := X-Hour*3600-Min*60;
  Str(Hour, sHour);
  if Negative then
    sHour := '-'+sHour;
  Str(Min, sMin);
  if Length(sMin) < 2 then
    sMin := '0'+sMin;
  Str(Sec: 0: CalcFormat[5], S);
  if PosChar('E', S) = 0 then
    while S[Length(S)] = '0' do
      SetLength(S, Length(S)-1);
  if S[Length(S)] = '.' then
    SetLength(S, Length(S)-1);
  if  (Length(S) < 2) or (PosChar('.', S) = 2) then
    S := '0'+S;
  S := sHour+':'+sMin+':'+S;
  end { TIndicator.WrtT };

procedure TIndicator.Draw;
  var
    B: TDrawBuffer;
    S: String[40];
    C: Byte;
    L, LL: LongInt;

  procedure Wrt(N: Integer);
    begin
    MoveChar(B[0], ' ', C, Size.X);
    MoveStr(B[Size.X-Length(S)-1], S, C);
    WriteLineC(0, N, Size.X, 1, B);
    SResult[N] := S;
    end;

  begin
  C := GetColorW(1);
  if CalcError then
    begin
    MoveChar(B[0], ' ', C, Size.X);
    WriteLineC(0, 0, Size.X, 2, B);
    WriteLineC(0, 3, Size.X, 3, B);
    S := GetString(CalcErrMess)+GetErrOp(L);
    MoveStr(B[(Size.X-Length(S)) div 2], S, C);
    WriteLineC(0, 2, Size.X, 1, B);
    end
  else
    begin
    Str(Value: 0: CalcFormat[0], S);
    if PosChar('E', S) = 0 then
      while S[Length(S)] = '0' do
        SetLength(S, Length(S)-1);
    if S[Length(S)] = '.' then
      SetLength(S, Length(S)-1);
    Wrt(0);
    if Abs(Value) > $7FFFFFFF then
      begin
      S := GetString(dlOverflow);
      Wrt(1);
      Wrt(2);
      Wrt(3);
      Wrt(5);
      end
    else
      begin
      LL := Trunc(Value);
      S := '$'+GetNValue(LL, 4);
      if Length(s) > CalcFormat[1]+1 then
        S := GetString(dlOverflow);
      Wrt(1);
      S := GetNValue(LL, 1) + 'b';
      if Length(s) > CalcFormat[2]+1 then
        S := GetString(dlOverflow);
      Wrt(2);
      S := GetNValue(LL, 3) + 'o';
      if Length(s) > CalcFormat[3]+1 then
        S := GetString(dlOverflow);
      Wrt(3);
      WrtT(Value, S); Wrt(5);
      end;
    Str(Value:CalcFormat[4]+8, S);
    Wrt(4);
    end;
  end { TIndicator.Draw };

procedure TCalcLine.HandleEvent(var Event: TEvent);
  var
    WasKey: Boolean;
  begin
  WasKey := Event.What = evKeyDown;
  inherited HandleEvent(Event);
  if WasKey then
    begin
    SetValues(False);
    if DNKeyCode(Event) = kbESC then
      begin
      GetData(FreeStr);
      HistoryAdd(hsCalcLine, FreeStr);
      Event.What := evCommand;
      Event.Command := cmClose;
      Event.InfoPtr := nil;
      PutEvent(Event);
      ClearEvent(Event);
      end;
    end
  else if (Event.What = evCommand) then
    case Event.Command of
      cmCalcValue:
        begin
        ClearEvent(Event);
        SetValues(True);
        end;
      cmGetName:
        begin
        PString(Event.InfoPtr)^:= GetString(dlCalculator);
        ClearEvent(Event);
        end;
    end {case};
  end { TCalcLine.HandleEvent };

procedure TCalcLine.SetData(var B);
  begin
  inherited SetData(B);
  SetValues(False);
  end;

procedure TCalcLine.Awaken;
  begin
  inherited Awaken;
  SetValues(False);
  Calc := Owner;
  end;

destructor TCalcLine.Destroy;
  begin
  Calc := nil;
  inherited Destroy;
  end;

procedure TCalcLine.SetValues(SetSelf: Boolean);
  var
    R: CReal;
    SelectedForm: Integer;
    S: String;
  begin
  GetData(S);
  //  DelSpace(S);
  if S = '' then
    begin
    R := 0;
    Message(Owner, evBroadcast, cmSetValue, @R);
    Exit
    end;
  R := Evalue(S, nil);
  if EvalueError then
    begin
    if not SetSelf then
      CalcErrMess := dlMsgError
    else
      begin
      CurPos := CalcErrPos;
      DrawView;
      end;
    Message(Owner, evBroadcast, cmSetError, nil);
    EvalueError := False;
    end
  else
    begin
    Message(Owner, evBroadcast, cmSetValue, @R);
    if SetSelf then
      begin
      GetData(S);
      HistoryAdd(hsCalcLine, S);
      with TIndicator(TDialog(Owner).DirectLink[3]) do
        begin
        Radio.GetData(SelectedForm);
        S := SResult[SelectedForm];
        end;
      SetData(S);
      end;
    end;
  end { TCalcLine.SetValues };

procedure InsertCalc;

  function MakeDialog: TDialog;
    var
      Dlg: TDialog;
      R: TRect;
      Indicator: TIndicator;
    begin
    Dlg := TDialog(LoadResource(dlgCalculator));
    R.Move(10, 5);
    Dlg.Number := GetNum;

    ObjChangeType(Dlg.DirectLink[1], Pointer(System.TClass(TCalcLine)));

    R.Assign(12, 6, Dlg.Size.X-2, 12);
    Indicator := TIndicator.Create(R);
    Indicator.Options := Indicator.Options or ofFramed;
    Indicator.CalcLine := TCalcLine(Dlg.DirectLink[1]);
    Indicator.Radio := TRadioButtons(Dlg.DirectLink[2]);
    Dlg.Insert(Indicator);
    Dlg.DirectLink[3] := Indicator;

    MakeDialog := Dlg;
    end { MakeDialog: };

  begin { InsertCalc }
  if Calc = nil then
    begin
    Calc := MakeDialog;
    Application.InsertWindow(TWindow(Calc));
    end
  else
    Calc.Select;
  end { InsertCalc };

end.
