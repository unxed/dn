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

unit Phones;

interface

uses
  SysUtils, Defines, objutil, Streams, Drivers, Dialogs, Menus,
  Views, DNStdDlg, Collect, StrView
  ;

type
  TPhoneCollection = class(TSortedCollection)
    constructor Create(ALimit, ADelta: LongInt); overload;
    function Read(Ip: ipstream): Pointer; override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    function ReadItem(Ip: ipstream): Pointer; override;
    procedure WriteItem(Item: Pointer; Os: opstream); override;
    function Compare(P1, P2: Pointer): Integer; override;
    procedure FreeItem(Item: Pointer); override;
    end;

  TPhoneDir = class(TStreamable)
    Name: String[30];
    Memo1: PString;
    Memo2: PString;
    Password: String[15];
    Phones: TCollection;
    Encrypted: Boolean;
    constructor Create(const APassword, AName, AMemo1, AMemo2: String); overload;
    constructor Create(AInit: TStreamableInit); overload;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    destructor Destroy; override;
    end;

  TPhone = class(TStreamable)
    Name: String[30];
    Memo1: PString;
    Memo2: PString;
    Number: PString;
    constructor Create(const ANumber, AName, AMemo1, AMemo2: String); overload;
    constructor Create(AInit: TStreamableInit); overload;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
    function StreamableName: ShortString; override;
    class function Build: TStreamable; static;
    destructor Destroy; override;
    end;


  TPhoneBox = class(TSortedListBox)
    GroupLabel, ItemLabel: TLabel;
    AlphaMode, SearchMode: Boolean;
    Phones: TCollection;
    Active: TPhoneDir;
    Info: TDStringView;
    destructor Destroy; override;
    procedure HandleEvent(var Event: TEvent); override;
    function GetText(Item: LongInt; MaxLen: Integer): String; virtual;
    function GetKey(const S: String): Pointer; virtual;
    procedure SetList(Alpha: Boolean);
    {      procedure SetState(AState: Word; Enable: Boolean); virtual;}
    end;

procedure PhoneBook(Manual: Boolean);

implementation
uses
  FlightRec,
  mainapp, Startup, Commands, Messages, ObjType
  , DNHelp, basics, strutil, fileutil
  
  ;

var
  EnterButton, ReturnButton: TButton;

function CryptWith(Pass, S: String): String;
  var
    I: Integer;
  begin
  if Pass <> '' then
    begin
    for I := 1 to Length(S) do
      S[I] := Char(Byte(S[I]) xor Byte(Pass[1+I mod Length(Pass)]) xor
             (I xor $AA));
    end;
  CryptWith := S;
  end;

var
  PPH: TPhone;

const
  { the head of dn.phn: the last byte is the version of the format; a file of another version is not read }
  PhonesSign = 'DN Phone book'#26#1;

{ dn.phn: PhonesSign, then the collection of the phone book written by an opstream }
function LoadPhones: TCollection;
  var
    S: TBufStream;
    Ip: ipstream;
    Sign: String;
  begin
  Result := nil;
  S := TBufStream.Create(ConfigDir+'dn.phn', stOpenRead, 1024);
  if (S.Status = stOK) and (S.GetSize > Length(PhonesSign)) then
    begin
    SetLength(Sign, Length(PhonesSign));
    S.Read(Sign[1], Length(PhonesSign));
    if Sign <> PhonesSign then
      FRNote('file', 'the phone book is of another version: not read')
    else
      begin
      Ip := ipstream.Create(S);
      try
        Result := TCollection(Ip.ReadPointer);
      except
        on E: Exception do
          begin
          FRNote('file', 'the phone book was not read: ' + E.Message);
          Result := nil;
          end;
      end;
      Ip.Free;
      end;
    end;
  S.Free;
  end;

procedure SavePhones(C: TCollection);
  var
    S: TBufStream;
    Os: opstream;
  begin
  S := TBufStream.Create(ConfigDir+'dn.phn', stCreate, 1024);
  S.Write(PhonesSign[1], Length(PhonesSign));
  Os := opstream.Create(S);
  Os.WritePointer(TStreamable(C));
  Os.Free;
  S.Free;
  end;

procedure PhoneBook(Manual: Boolean);
  var
    D: TDialog;
    R: TRect;
    PV: TView;
    PL: TPhoneBox;
    PC: TCollection;
    S: TBufStream;
    Stream: TStream;
    {$PUSH}{$PACKRECORDS DEFAULT} { the layout of TvList.TListBoxRec }
    DT: record
      C: TCollection;
      n: Word;
      end;
    {$POP}
    W: TWindow;
    I: Integer;
    SS: String;

  procedure DoSearchButton(P: TView);
    begin
    if P is TButton then
      if TButton(P).Command = cmOK then
        EnterButton := TButton(P)
      else if TButton(P).Command = cmNo then
        ReturnButton := TButton(P);
    end;

  begin { PhoneBook }
  PPH := nil;
  SS := '';
  if Manual then
    begin
    if  (ExecResource(dlgManualDial, SS) <> cmOK)
         or (DelSpaces(SS) = '')
    then
      Exit;
    PPH := TPhone.Create(SS, GetString(dlMD_Manual)+SS, '', '');
    end
  else
    begin
    D := TDialog(LoadResource(dlgPhoneBook));
    D.ForEach(DoSearchButton);
    ReturnButton.Hide;
    PV := D.StandardScrollBar(sbVertical+sbHandleKeyboard);
    R := TRect.Create(D.Size.X-3, 3, D.Size.X-2, 12);
    PV.Locate(R);

    R := TRect.Create(2, 3, D.Size.X-3, 12);
    PL := TPhoneBox.Create(R, 1, TScrollBar(PV));
    PL.Options := PL.Options or ofPostProcess;
    PC := LoadPhones;
    if PC = nil then
      PC := TPhoneCollection.Create(10, 10);
    PC.Pack;
    PL.Phones := PC;
    PL.Active := nil;
    PL.AlphaMode := False;
    PL.SearchMode := False;
    PL.NewLisT(PC);

    D.Insert(PL);
    R := TRect.Create(2, 2, 53, 3);

    PL.GroupLabel := TLabel.Create(R, GetString(dlPhonesLabelGroup), PL);
    D.Insert(PL.GroupLabel);

    PL.ItemLabel := TLabel.Create(R, GetString(dlPhonesLabelPhones), PL);
    PL.ItemLabel.Hide;
    D.Insert(PL.ItemLabel);


    D.Insert(PL);
    {D.Insert(PV);}
    R := TRect.Create(2, 12, D.Size.X-2, 14);
    PV := TDStringView.Create(R);
    TDStringView(PV).S1 := '';
    TDStringView(PV).S2 := '';
    D.Insert(PV);
    PL.Info := TDStringView(PV);

    R.A.X := Desktop.ExecView(D);
    D.GetData(DT);
    D.Free;
    if R.A.X <> cmDialPhone then
      Exit;
    end;
  if PPH = nil then
    Exit;
  
  PPH.Free;
  PPH := nil;
  end { PhoneBook };

function TPhoneBox.GetKey(const S: String): Pointer;
  const
    B: Byte = 0;
    ST: String[30] = '';
  begin
  ST := UpStrg(S);
  GetKey := @B;
  end;

{procedure TPhoneBox.SetState(AState: Word; Enable: Boolean);
begin
 Inherited SetState(AState, Enable);
 if (Active <> nil) and ((State And sfFocused)<>0) then
   if (Focused=0) then DisableCommands(CommandSetOf([cmDialPhone, cmImportPhones]))
                  else EnableCommands(CommandSetOf([cmDialPhone, cmImportPhones]))
end;
}
procedure TPhoneBox.SetList(Alpha: Boolean);
  var
    PC: TPhoneCollection;
    S: TBufStream;
    Stream: TStream;

  procedure DoPhones(Ph_: Pointer);
  var Ph: TPhoneDir absolute Ph_;

    procedure InsertPhone(P_: Pointer);
    var P: TPhone absolute P_;
      var
        PP: TPhoneDir;
        I: LongInt;
      begin
      if P <> nil then
        begin
        FreeStr := UpStrg(P.Name);
        if  (Length(FreeStr) = 2) and (FreeStr = '..') then
          Exit;
        PP := TPhoneDir.Create('', FreeStr[1], '', '');
        if PC.Search(PP, I) then
          begin
          PP.Free;
          PP := PC.At(I);
          end
        else
          PC.AtInsert(I, PP);
        if PP.Phones = nil then
          PP.Phones := TPhoneCollection.Create(10, 10);
        TSortedCollection(PP.Phones).Duplicates := True;
        PP.Phones.Insert(P);
        end;
      end { InsertPhone };

    begin { DoPhones }
    if  (Ph <> nil) and (Ph.Phones <> nil)
           and ((Ph.Password = '') or (Ph.Encrypted))
    then
      Ph.Phones.ForEach(InsertPhone);
    Ph.Phones.RemoveAll;
    end { DoPhones };

  begin { TPhoneBox.SetList }
  if Phones = nil then
    Exit;
  if  (AlphaMode xor Alpha) then
    begin
    if Alpha then
      begin
      PC := TPhoneCollection.Create(10, 10);
      Phones.ForEach(DoPhones);
      end
    else
      begin
      PC := TPhoneCollection(LoadPhones);
      if PC = nil then
        PC := TPhoneCollection.Create(10, 10);
      end;
    Phones.Free;
    Phones := PC;
    end;
  AlphaMode := Alpha;
  Items := nil;
  NewLisT(Phones);
  end { TPhoneBox.SetList };

procedure TPhoneBox.HandleEvent(var Event: TEvent);
  var
    Dt: record
      Name: String[30];
      Number: String[100];
      Memo1, Memo2: String[50];
      end;
    C: TCollection;
    Stream: TBufStream;
    BaseStream: TStream;
    Ph: TPhone;

  function CheckPassword(Ph: TPhoneDir): Boolean;
    var
      S: String;
    begin
    CheckPassword := True;
    if  (Ph.Password = '') or Ph.Encrypted then
      Exit;
    repeat
      S := '';
      if ExecResource(dlgSetPassword, S) = cmCancel then
        begin
        CheckPassword := False;
        Exit
        end;
    until Ph.Password = S;
    Ph.Encrypted := True;
    end;

  procedure EditDirectory(Append: Boolean);
    var
      D: TDialog;
      Dt: record
        Name: String[30];
        Password: String[15];
        Memo1, Memo2: String[50];
        end;
      R: TRect;
      P: TView;
      Idx: TDlgIdx;
      Ph: TPhoneDir;
      {      PC: TCollection;}
    begin
    FillChar(Dt, SizeOf(Dt), 0);
    if not Append then
      begin
      Ph := List.At(Focused);
      if not CheckPassword(Ph) then
        Exit;
      Dt.Name := Ph.Name;
      Dt.Password := Ph.Password;
      if Ph.Memo1 <> nil then
        Dt.Memo1 := Ph.Memo1^;
      if Ph.Memo2 <> nil then
        Dt.Memo2 := Ph.Memo2^;
      Idx := dlgEditDirectory;
      end
    else
      Idx := dlgAppendDirectory;

    if ExecResource(Idx, Dt) <> cmOK then
      Exit;

    C := List;
    if C = nil then
      C := TPhoneCollection.Create(10, 10);
    Items := nil;
    R.A.X := Focused;
    if Append then
      C.Insert(TPhoneDir.Create(Dt.Password, Dt.Name, Dt.Memo1, Dt.Memo2))
    else
      begin
      Ph.Name := Dt.Name;
      Ph.Password := Dt.Password;
      DisposeStr(Ph.Memo1);
      Ph.Memo1 := NewStr(Dt.Memo1);
      DisposeStr(Ph.Memo2);
      Ph.Memo2 := NewStr(Dt.Memo2);
      C.AtRemove(Focused);
      TSortedCollection(C).Search(Ph, Focused);
      C.AtInsert(Focused, Ph);
      end;
    Owner.Lock;
    NewLisT(C);
    FocusItem(R.A.X);
    Owner.UnLock;
    Phones := C;
    SavePhones(Phones);
    end { EditDirectory };

  procedure EditNumber(Append: Boolean);
    var
      D: TDialog;
      R: TRect;
      P: TView;
      Idx: TDlgIdx;
    begin
    if Active = nil then
      begin
      EditDirectory(Append);
      Exit
      end;
    FillChar(DT, SizeOf(DT), 0);
    if not Append then
      begin
      Ph := List.At(Focused);
      DT.Name := Ph.Name;
      if Ph.Number <> nil then
        DT.Number := Ph.Number^;
      if Ph.Memo1 <> nil then
        DT.Memo1 := Ph.Memo1^;
      if Ph.Memo2 <> nil then
        DT.Memo2 := Ph.Memo2^;
      Idx := dlgEditNumber;
      end
    else
      Idx := dlgAppendNumber;

    repeat
      if ExecResource(Idx, DT) <> cmOK then
        Exit;
    until (DT.Number <> '');

    if  (DT.Number = '') or (DT.Name = '..') {or (DT.Name='')} then
      Exit;
    C := List;
    if C = nil then
      C := TPhoneCollection.Create(10, 10);
    Items := nil;
    R.A.X := Focused;
    if not Append and (C.Count > Focused) then
      C.AtFree(Focused);
    C.Insert(TPhone.Create(DT.Number, DT.Name, DT.Memo1, DT.Memo2));
    Owner.Lock;
    NewLisT(C);
    FocusItem(R.A.X);
    Owner.UnLock;
    Active.Phones := C;
    SavePhones(Phones);
    end { EditNumber };

  procedure CopyDirectory;
    var
      Dt: record
        Name: String[30];
        Password: String[15];
        Memo1, Memo2: String[50];
        end;
      Ph, P1: TPhoneDir;
      I: Integer;
    begin
    if  (List = nil) or (Focused >= List.Count) then
      Exit;
    FillChar(Dt, SizeOf(Dt), 0);
    Ph := List.At(Focused);
    if Ph = nil then
      Exit;
    if not CheckPassword(Ph) then
      Exit;
    Dt.Name := Ph.Name;
    Dt.Password := Ph.Password;
    if Ph.Memo1 <> nil then
      Dt.Memo1 := Ph.Memo1^;
    if Ph.Memo2 <> nil then
      Dt.Memo2 := Ph.Memo2^;

    C := List;
    if C = nil then
      C := TPhoneCollection.Create(10, 10);
    Items := nil;
    I := Focused;

    P1 := TPhoneDir.Create(Dt.Password, Dt.Name, Dt.Memo1, Dt.Memo2);
    P1.Encrypted := False;
    C.Insert(P1);
    Owner.Lock;
    NewLisT(C);
    FocusItem(I);
    Owner.UnLock;
    Phones := C;
    SavePhones(Phones);
    end { CopyDirectory };

  procedure CopyPhones;
    var
      I: Integer;
    begin
    if  (List = nil) or (Focused >= List.Count) then
      Exit;
    if Active = nil then
      begin
      CopyDirectory;
      Exit
      end;
    FillChar(DT, SizeOf(DT), 0);
    Ph := List.At(Focused);
    if Ph = nil then
      Exit;
    DT.Name := Ph.Name;
    if Ph.Number <> nil then
      DT.Number := Ph.Number^;
    if Ph.Memo1 <> nil then
      DT.Memo1 := Ph.Memo1^;
    if Ph.Memo2 <> nil then
      DT.Memo2 := Ph.Memo2^;

    C := List;
    if C = nil then
      C := TPhoneCollection.Create(10, 10);
    Items := nil;
    I := Focused;
    C.Insert(TPhone.Create(DT.Number, DT.Name, DT.Memo1, DT.Memo2));
    Owner.Lock;
    NewLisT(C);
    FocusItem(I);
    Owner.UnLock;
    Active.Phones := C;
    SavePhones(Phones);
    end { CopyPhones };

  procedure CE;
    begin
    ClearEvent(Event)
    end;

  procedure DialPhone;
    var
      P: TPhone;
      W: TWindow;
    begin
    CE;
    if Focused = 0 then
      Exit;
    if  (Active = nil) or (List = nil) or (List.Count = 0) then
      Exit;
    P := List.At(Focused);
    PPH := TPhone.Create(P.Number^, P.Name, '', '');
    Owner.EndModal(cmDialPhone);
    end;

  procedure EnterDir;
    var
      I: Integer;
      S: String;
      PD: TPhoneDir;
      P: TPhone;
    begin
    if Active = nil then
      begin
      if List.Count = 0 then
        Exit;

      PD := List.At(Focused);
      if not CheckPassword(PD) then
        Exit;

      DisableCommands(CommandSetOf([cmDialPhone, cmImportPhones]));
      GroupLabel.Hide;
      ItemLabel.Show;
      EnterButton.Hide;
      ReturnButton.Show;

      (*     if{ SearchMode and} (List <> nil) then
       begin
        List.DeleteAll;
        List.Free;
        Lisr:=nil;
       end;
  *)
      Active := PD;
      Items := nil;
      NewLisT(PD.Phones);
      if  (List = nil) then
        begin
        C := TPhoneCollection.Create(10, 10);
        C.Insert(TPhone.Create(' ', '..', GetString(dlPhonesUpDir), ''));
        Owner.Lock;
        NewLisT(C);
        Owner.UnLock;
        Active.Phones := C;
        SavePhones(Phones);
        DrawView;
        Exit;
        end;
      TSortedCollection(List).Sort;
      if  (TPhone(List.At(0)).Name <> '..') and (List.Count > 0) then
        begin
        P := TPhone.Create(' ', '..', GetString(dlPhonesUpDir), '');
        List.AtInsert(0, P);
        SetRange(List.Count);
        DrawView;
        end;
      {HideCursor;}
      end
    else
      begin
      GroupLabel.Show;
      ItemLabel.Hide;
      EnterButton.Show;
      ReturnButton.Hide;
      if Focused > 0 then
        begin
        DialPhone;
        Exit;
        end;

      if SearchMode and (List <> nil) then
        begin
        List.RemoveAll;
        List.Free;
        Items := nil;
        end;
      SearchMode := False;
      Items := nil;
      NewLisT(Phones);
      FocusItem(Phones.IndexOf(Active));
      Active := nil;
      {HideCursor;}
      end;
    Message(Self, evBroadcast, cmValid, nil);
    end { EnterDir };

  procedure SearchPhone;
    var
      PC: TPhoneCollection;
      S: String;

    procedure SearchDir(Ph_: Pointer);
    var Ph: TPhoneDir absolute Ph_;
      procedure DoPhone(P_: Pointer);
      var P: TPhone absolute P_;
        var
          I: Integer;
        begin
        if  (P <> nil)
                 and ((Pos(S, UpStrg(P.Name)) <> 0) or (Pos(S,
                   UpStrg(P.Number^)) <> 0))
        then
          PC.Insert(P);
        end;
      begin
      if  (Ph <> nil) and (Ph.Phones <> nil)
             and ((Ph.Password = '') or (Ph.Encrypted))
      then
        Ph.Phones.ForEach(DoPhone);
      end;

    begin { SearchPhone }
    if  (Phones = nil) or (Phones.Count = 0) then
      Exit;
    S := '';
    if InputBox(GetString(dlPB_SearchPhone),
         GetString(dlPB_S_earchString), S, 30, 0) <> cmOK
    then
      Exit;
    UpStr(S);
    PC := TPhoneCollection.Create(10, 10);
    PC.Duplicates := True;
    Phones.ForEach(SearchDir);
    if PC.Count = 0 then
      begin
      MessageBox(GetString(dlPB_NoFind), nil, mfError+mfOKButton);
      Exit;
      end;
    if SearchMode then
      begin
      List.RemoveAll;
      List.Free;
      Items := nil
      end;
    SearchMode := True;
    Items := nil;
    if Active = nil then
      Active := Phones.At(Focused);
    PC.AtInsert(0, TPhone.Create(' ', '..', GetString(dlPhonesUpDir), ''));
    NewLisT(PC);
    HideCursor;
    EnterButton.Hide;
    ReturnButton.Show;
    GroupLabel.Hide;
    ItemLabel.Show;
    end { SearchPhone };

  procedure ImportPhones;
    var
      F: TTextReader;
      S: String;
      P: String;
      Ph: TPhone;
      C: Char;
      I, J, K, M: Integer;
      PV: TView;
      Fr: Boolean;
      Template: String;

    procedure MakePhone;
      var
        I, J, K: Integer;
      begin
      for I := 2 to Length(S) do
        if  (S[I] >= '0') and (S[I] <= '9') and (S[I-1] = ' ') then
          begin
          P := '';
          K := I;
          J := I;
          while (J <= Length(S))
               and (S[J] in ['0'..'9', 'W', 'w', '-', ',', '(', ')'])
          do
            begin
            P := P+S[J];
            Inc(J)
            end;
          if Length(P) < 3 then
            Continue;
          S := Copy(S, 1, K-1);
          DelLeft(S);
          DelRight(S);
          if S <> '' then
            begin
            Ph := TPhone.Create(P, S, '', '');
            if Active.Phones = nil then
              Active.Phones := TPhoneCollection.Create(10, 10);
            Active.Phones.Insert(Ph);
            Inc(M);
            end;
          Break;
          end;
      end { MakePhone };

    procedure MakeTPhone;
      begin
      MakePhone;
      end;

    begin { ImportPhones }
    M := 0;
    if  (Active = nil) or AlphaMode or SearchMode then
      Exit;
    S := GetFileNameDialog(x_x, GetString(dlPB_ImportPhones),
        GetString(dlFileName), fdOKButton+fdHelpButton, hsImportPhones);
    if S = '' then
      Exit;
    F := TTextReader.Create(S);
    if F = nil then
      begin
      MessageBox(GetString(dlFBBNoOpen)+S, nil, mfError+mfOKButton);
      Exit
      end;
    PV := WriteMsg(GetString(dlPB_Working));
    Fr := True;
    while not F.Eof do
      begin
      UpdateWriteView(PV);
      S := F.GetStr;
      if S <> '' then
        begin
        if Fr and (S[1] = '|') then
          begin
          Fr := False;
          Template := S;
          Continue;
          end;
        if Template = '' then
          MakePhone
        else
          MakeTPhone;
        end;
      end;
    if PV <> nil then
      PV.Free;
    MessageBox(^C+ItoS(M)+GetString(dlPB_CnvReport), nil,
       mfInformation+mfOKButton);
    Items := nil;
    NewLisT(Active.Phones);
    F.Free;
    SavePhones(Phones);
    end { ImportPhones };

  procedure CopyItem;
    var
      S: String[230];
    begin
    {  FillChar(S[1], 230, 0);
  S[0]:=#230;
  FillChar(S[1], 30, 0);
  Ph := List^.At(Focused);
  Ph^.Name;              30
  Ph^.Number^;           100
  Ph^.Memo1^;            50
  Ph^.Memo2^;            50
  PutInClip(Str);}
    end;

  var
    WasBroad: Boolean;

  begin { TPhoneBox.HandleEvent }
  WasBroad := Event.What = evBroadcast;
  case Event.What of
    evMouseDown:
      if ((Event.Mouse.EventFlags and 2) <> 0) then
        begin
        if Event.Mouse.Buttons and mbRightButton = 0 then
          MessageKey(Owner, kbEnter)
        else
          MessageKey(Owner, kbSpace);
        CE;
        end;
    evCommand:
      case DNKeyCode(Event) of
        cmCopyPhone:
          begin
          CE;
          CopyPhones;
          CE;
          end;
        cmImportPhones:
          begin
          CE;
          ImportPhones;
          CE;
          end;
        cmDialPhone:
          begin
          CE;
          DialPhone
          end;
        cmSearchPhone:
          begin
          CE;
          SearchPhone;
          CE;
          end;
        cmOK, cmNo:
          begin
          if  (EnterButton.State and sfVisible) = 0 then
            Focused := 0;
          EnterDir;
          CE
          end;
        cmInsertPhone:
          begin
          if not AlphaMode or SearchMode then
            EditNumber(True);
          CE
          end;
        cmEditPhone:
          begin
          if List.Count > 0 then
            if not AlphaMode or SearchMode then
              if not ((Active <> nil) and (Focused = 0)) then
                EditNumber(False);
          CE
          end;
        cmPhoneBookMode:
          begin
          SetList(not AlphaMode);
          CE
          end;
        cmDeletePhone:
          begin
          CE;
          if  (List = nil) or (List.Count = 0) then
            Exit;
          if AlphaMode or SearchMode then
            Exit;
          if  (Active <> nil) and (Focused = 0) then
            Exit;
          if Active = nil then
            begin
            if Msg(dlPhoneDirDelete, nil,
                 mf2YesButton+mfNoButton+mfConfirmation) <> cmYes
            then
              Exit;
            if not CheckPassword(List.At(Focused)) then
              Exit;
            end
          else if (List.Count > 0) and
              (MessageBox(GetString(dlPhoneDeleteQuery), nil,
                mfYesButton+mfNoButton+mfConfirmation) <> cmYes)
          then
            Exit;
          if  (List <> nil) and (Focused < List.Count) then
            begin
            List.AtFree(Focused);
            SetRange(List.Count);
            DrawView;
            end;
          SavePhones(Phones);
          end;
      end {case};
    evKeyDown:
      if Char(Event.KeyDown.CharScan.CharCode) = ' ' then
        DialPhone
      else if (Active <> nil) then
        case DNKeyCode(Event) of
          kbCtrlIns:
            CopyItem;
          kbCtrlPgUp, kbCtrlSlash:
            begin
            Focused := 0;
            EnterDir;
            CE;
            Exit;
            end;
          kbEnter:
            begin
            EnterDir;
            CE
            end;
        end {case};
  end {case};
  inherited HandleEvent(Event);
  if WasBroad then
    begin
    if  (Info <> nil) and (List <> nil) and (List.Count > 0) then
      begin
      Ph := List.At(Focused);
      if Ph.Memo1 <> nil then
        Info.S1 := Ph.Memo1^
      else
        Info.S1 := '';
      if Ph.Memo2 <> nil then
        Info.S2 := Ph.Memo2^
      else
        Info.S2 := '';
      Info.DrawView;
      end
    else if Info <> nil then
      begin
      Info.S1 := '';
      Info.S2 := '';
      Info.DrawView;
      end;
    end;
  if Active = nil then
    begin
    DisableCommands(CommandSetOf([cmDialPhone, cmImportPhones]));
    EnableCommands(CommandSetOf([cmPhoneBookMode, cmCopyPhone]));
    Owner.Redraw
    end
  else
    begin
    DisableCommands(CommandSetOf([cmPhoneBookMode]));
    EnableCommands(CommandSetOf([cmImportPhones]));
    if Focused = 0 then
      DisableCommands(CommandSetOf([cmDialPhone, cmCopyPhone]))
    else
      EnableCommands(CommandSetOf([cmDialPhone, cmCopyPhone]));
    Owner.Redraw
    end;

  if SearchMode then
    DisableCommands(CommandSetOf([cmInsertPhone, cmDeletePhone, cmEditPhone,
       cmImportPhones]))
  else
    EnableCommands(CommandSetOf([cmInsertPhone, cmDeletePhone, cmEditPhone]));

  end { TPhoneBox.HandleEvent };

destructor TPhoneBox.Destroy;
  begin
  { if (List <> nil) and (List <> Phones) }
  {                  then List.DeleteAll;}
  if Phones <> nil then
    Phones.Free;
  Phones := nil;
  { if Active <> nil then Active.Free; Active:=nil;}
  if Info <> nil then
    Info.Free;
  Info := nil;

  inherited Destroy;
  end;

function TPhoneBox.GetText(Item: LongInt; MaxLen: Integer): String;
  var
    S: String;
    P: TPhone;
  begin
  P := List.At(Item);
  S := AddSpace(P.Name, 30);
  if P is TPhone then
    S := S+'  '+AddSpace(P.Number^, 23);
  GetText := S;
  end;

constructor TPhoneCollection.Create(ALimit, ADelta: LongInt);
  begin
  inherited Create(ALimit, ADelta);
  Duplicates := True;
  end;

function TPhoneCollection.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  inherited Read(Ip);
  Duplicates := True;
  Sort;
  end;

class function TPhoneCollection.Build: TStreamable;
begin
  Result := TPhoneCollection.Create(streamableInit);
end;

function TPhoneCollection.StreamableName: ShortString;
begin
  Result := 'Phones.TPhoneCollection';
end;

function TPhoneCollection.ReadItem(Ip: ipstream): Pointer;
  begin
  Result := Ip.ReadPointer;
  end;

procedure TPhoneCollection.WriteItem(Item: Pointer; Os: opstream);
  begin
  Os.WritePointer(TStreamable(Item));
  end;

function TPhoneCollection.Compare(P1, P2: Pointer): Integer;
  begin
  if TPhone(P1).Name = TPhone(P2).Name then
    Compare := 0
  else if (TPhone(P1).Name = '..')
       or (TPhone(P1).Name < TPhone(P2).Name)
  then
    Compare := -1
  else
    Compare := 1;
  end;

procedure TPhoneCollection.FreeItem(Item: Pointer);
  var
    PP: TPhone;
  begin
  PP := Item;
  if Item <> nil then
    PP.Free;
  end;

constructor TPhone.Create(const ANumber, AName, AMemo1, AMemo2: String);
  begin
  inherited Create;
  Name := AName;
  Number := NewStr(ANumber);
  Memo1 := NewStr(AMemo1);
  Memo2 := NewStr(AMemo2);
  end;

function TPhone.Read(Ip: ipstream): Pointer;
  begin
  Result := Self;
  Number := Ip.ReadString;
  ReadStrV(Ip, Name);
  {Ip.ReadBytes(Name[0],1); Ip.ReadBytes(Name[1], Byte(Name[0]);}
  Memo1 := Ip.ReadString;
  Memo2 := Ip.ReadString;
  end;

procedure TPhone.Write(Os: opstream);
  begin
  Os.WriteString(Number);
  Os.WriteString(@Name);
  Os.WriteString(Memo1);
  Os.WriteString(Memo2);
  end;

constructor TPhone.Create(AInit: TStreamableInit);
  begin
  end;

class function TPhone.Build: TStreamable;
begin
  Result := TPhone.Create(streamableInit);
end;

function TPhone.StreamableName: ShortString;
begin
  Result := 'Phones.TPhone';
end;

destructor TPhone.Destroy;
  begin
  DisposeStr(Number);
  DisposeStr(Memo1);
  DisposeStr(Memo2);
  inherited Destroy;
  end;

constructor TPhoneDir.Create(const APassword, AName, AMemo1, AMemo2: String);
  begin
  inherited Create;
  Name := AName;
  Memo1 := NewStr(AMemo1);
  Memo2 := NewStr(AMemo2);
  Password := APassword;
  Phones := nil;
  end;

procedure CryptCol(Col: TCollection; Pass: String);
  procedure CryptPhone(P_: Pointer);
  var P: TPhone absolute P_;
    begin
    if P <> nil then
      with P do
        begin
        Name := CryptWith(Pass, Name);
        if Number <> nil then
          Number^:= CryptWith(Pass, Number^);
        if Memo1 <> nil then
          Memo1^:= CryptWith(Pass, Memo1^);
        if Memo2 <> nil then
          Memo2^:= CryptWith(Pass, Memo2^);
        end;
    end;
  begin
  if Col <> nil then
    Col.ForEach(CryptPhone);
  end;

function TPhoneDir.Read(Ip: ipstream): Pointer;
  var
    Q: TFileSize;
  begin
  Result := Self;
  ReadStrV(Ip, Name);
  {Ip.ReadBytes(Name[0],1); Ip.ReadBytes(Name[1], Byte(Name[0]);}
  Memo1 := Ip.ReadString;
  Memo2 := Ip.ReadString;
  Ip.ReadBytes(Password, 1);
  Ip.ReadBytes(Password[1], Byte(Password[0]));
  Password := CryptWith('NaViGaToR', Password);
  Phones := TCollection(Ip.ReadPointer);
  if Phones <> nil then
    CryptCol(Phones, Password);
  Encrypted := False;
  end { TPhoneDir.Load };

procedure TPhoneDir.Write(Os: opstream);
  begin
  Os.WriteString(@Name);
  Os.WriteString(Memo1);
  Os.WriteString(Memo2);
  Password := CryptWith('NaViGaToR', Password);
  Os.WriteBytes(Password, 1);
  Os.WriteBytes(Password[1], Byte(Password[0]));
  Password := CryptWith('NaViGaToR', Password);
  if Phones <> nil then
    CryptCol(Phones, Password);
  Os.WritePointer(Phones);
  if Phones <> nil then
    CryptCol(Phones, Password);
  end;

constructor TPhoneDir.Create(AInit: TStreamableInit);
  begin
  end;

class function TPhoneDir.Build: TStreamable;
begin
  Result := TPhoneDir.Create(streamableInit);
end;

function TPhoneDir.StreamableName: ShortString;
begin
  Result := 'Phones.TPhoneDir';
end;

destructor TPhoneDir.Destroy;
  begin
  DisposeStr(Memo1);
  DisposeStr(Memo2);
  if Phones <> nil then
    Phones.Free;
  Phones := nil;
  inherited Destroy;
  end;

end.
