{$I STDEFINE.INC}

unit UserSavr;

interface

uses
  Views, objutil
  ;

type


  TUserSaver = class(TView)
    Screen: Pointer;
    SSize, SWidth: AInt;
    CShape, CPos: AWord;
    CheckIO: Boolean;
    isValid: Boolean;
    constructor Create(ACheck: Boolean);
    destructor Destroy; override;
    function Read(Ip: ipstream): Pointer; override;
    procedure Write(Os: opstream); override;
    function Valid(Command: Word): Boolean; override;
    end;

procedure InsertUserSaver(ACheck: Boolean);

implementation

uses
  Drivers, DNUtil, Messages, Commands, mainapp
  ;

{ ------------------------------------------------------------------------- }

constructor TUserSaver.Create(ACheck: Boolean);
  var
    R: TRect;
  begin
  R := TRect.Create(0, 0, 0, 0);
  inherited Create(R);
  CheckIO := ACheck;
  SetState(sfVisible, False);
  isValid := True;
  Screen := GetMem(UserScreenSize);
  if Screen = nil then
    Fail;
  Move(UserScreen^, Screen^, UserScreenSize);
  CLSAct := False;
  SSize := UserScreenSize;
  SWidth := UserScreenWidth;
  CShape := OldCursorShape;
  CPos := OldCursorPos;
  end;

function TUserSaver.Valid(Command: Word): Boolean;
  begin
  Valid := isValid
  end;

function TUserSaver.Read(Ip: ipstream): Pointer;
  var
    I: Byte;
  begin
  Result := Self;
  inherited Read(Ip);
  DataSaver := Self;
  Ip.ReadBytes(SSize, 4*SizeOf(AInt)+SizeOf(Boolean));
  if UserScreen <> nil then
    FreeMem(UserScreen, UserScreenSize);
  UserScreenSize := SSize;
  UserScreenWidth := SWidth;
  UserScreen := GetMem(SSize);
  OldCursorShape := CShape;
  OldCursorPos := CPos;
  Ip.ReadBytes(UserScreen^, SSize);
  Screen := nil;
  isValid := False;
  I := 0;
  if I <> 0 then
    Msg(dlErrorsOccurred, nil, mfWarning+mfOKButton);
  end;

destructor TUserSaver.Destroy;
  begin
  if Screen <> nil then
    FreeMem(Screen, SSize);
  inherited Destroy;
  end;

procedure TUserSaver.Write(Os: opstream);
  begin
  inherited Write(Os);
  Os.WriteBytes(SSize, 4*SizeOf(AInt)+SizeOf(Boolean));
  Os.WriteBytes(Screen^, SSize);
  end;

procedure InsertUserSaver(ACheck: Boolean);
  begin
  Desktop.Insert(TUserSaver.Create(ACheck));
  FreeMem(UserScreen, UserScreenSize);
  UserScreenSize := ScreenWidth*ScreenHeight*2;
  UserScreenWidth := ScreenWidth;
  OldCursorPos := 0;
  OldCursorShape := $FFFF;
  HideMouse;
  GetMem(UserScreen, UserScreenSize);
  System.Move(ScreenBuffer^, UserScreen^, UserScreenSize);
  ShowMouse;
  end;

end.
