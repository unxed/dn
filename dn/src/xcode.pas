unit XCode;

interface

uses
  Defines, objutil, Streams, keymap
  ;

type

  TXCoder = class;
  {`2 Recoding support in viewer, dbf, etc.}
  TXCoder = class
    XLatCP: TXLatCP;
    KeyMap: TKeyMap;
      {` KeyMap=kmXlat for an encoding loaded from an xlt file`}
    MaxCodeTagLen: Byte;
      {` Maximum CodeTag length. At most 8.`}
    CodeTag: Str8;
      {` Encoding label shown in the frame.
      Name of a predefined encoding or of a loaded
      xlt table file without path `}
    constructor Create(AMaxCodeTagLen: Byte);
    { the fields in a stream (a part of the viewer that has the coder) }
    procedure Read(Ip: ipstream);
    procedure Write(Os: opstream);
    procedure UseToAscii;
      {` Set everything to kmXlat from XLatCP[ToAscii]`}
    procedure UseKeyMap;
      {` Set everything to the current KeyMap (kmAscii or higher)`}
    procedure LoadXlatTable;
    procedure NextXLat;
      {` Cycle through predefined encodings `}
    procedure FromHistory(fKeyMap: TKeyMap;
      fToAscii: TXLat; fCodeTag: Str8);
    procedure ToHistory(var fKeyMap: TKeyMap;
      var fToAscii: TXLat; var fCodeTag: Str8);
    end;
    {`}

implementation
uses DnPath,
  basics, strutil, Lfn, DNStdDlg, mainapp, Commands, DnIni
  ;

constructor TXCoder.Create(AMaxCodeTagLen: Byte);
  begin
  inherited Create;
  KeyMap := kmAscii;
  UseKeyMap;
  if (AMaxCodeTagLen > 8) then
    AMaxCodeTagLen := 8;
  MaxCodeTagLen := AMaxCodeTagLen;
  end;

procedure TXCoder.Write(Os: opstream);
  begin
  Os.WriteBytes(KeyMap, SizeOf(KeyMap));
  Os.WriteBytes(MaxCodeTagLen, SizeOf(MaxCodeTagLen));
  Os.WriteBytes(CodeTag, SizeOf(CodeTag));
  if KeyMap = kmXlat then
    Os.WriteBytes(XLatCP[ToAscii], SizeOf(TXLat));
  end;

procedure TXCoder.Read(Ip: ipstream);
  var
    FName: PString;
  begin
  Ip.ReadBytes(KeyMap, SizeOf(KeyMap));
  Ip.ReadBytes(MaxCodeTagLen, SizeOf(MaxCodeTagLen));
  Ip.ReadBytes(CodeTag, SizeOf(CodeTag));
  if KeyMap <> kmXlat then
    UseKeyMap
  else
    begin
    Ip.ReadBytes(XLatCP[ToAscii], SizeOf(TXLat));
    UseToAscii;
    end;
  end;

procedure TXCoder.UseToAscii;
  begin
  KeyMap := kmXlat;
  AcceptToAscii(XLatCP);
  end;

procedure TXCoder.UseKeyMap;
  begin
  XLatCP := KeyMapDescr[KeyMap].XLatCP^;
  CodeTag := KeyMapDescr[KeyMap].Tag;
  end;

procedure TXCoder.LoadXlatTable; {JO}
  var
    FN: String;
    More: Boolean;
    None: Boolean;
    Dr: String;
    Nm: String;
    Xt: String;
  label
    SkipMenu;
  begin
  More := True;
  None := KeyMap = kmXlat;
   if SkipXLatMenu then
     goto SkipMenu;
  FN := GetFileNameMenu(SourceDir+'xlt'+DnSep, '*.xlt', FN, True, More, None);
  if None then
    begin
    UseKeyMap;
    Exit;
    end;
  if More then
SkipMenu:
    FN := GetFileNameDialog(SourceDir+'xlt'+DnSep+'*.xlt',
        GetString(dlSelectXLT),
        GetString(dlOpenFileName),
        fdOKButton+fdHelpButton,
        hsOpenXLT);
  if BuildCodeTable(FN, XLatCP) then
    begin
    lFSplit(FN, Dr, Nm, Xt);
    CodeTag := Cut(Nm, MaxCodeTagLen);
    KeyMap := kmXlat;
    end;
  end { LoadXlatTable }; {JO}

procedure TXCoder.NextXLat;
  begin
  KeyMap := RollKeyMap[KeyMap];
  UseKeyMap;
  end;

procedure TXCoder.FromHistory(fKeyMap: TKeyMap;
      fToAscii: TXLat; fCodeTag: Str8);
  begin
  KeyMap := fKeyMap;
  CodeTag := fCodeTag;
  XLatCP[ToAscii] := fToAscii;
  if KeyMap = kmXlat then
    UseToAscii
  else
    UseKeyMap;
  end;

procedure TXCoder.ToHistory(var fKeyMap: TKeyMap;
      var fToAscii: TXLat; var fCodeTag: Str8);
  begin
  fKeyMap := KeyMap;
  fCodeTag := CodeTag;
  fToAscii := XLatCP[ToAscii];
  end;

end.
