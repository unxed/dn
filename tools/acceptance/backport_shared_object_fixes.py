#!/usr/bin/env python3
"""Apply shared-bug fixes to the pinned object comparator checkout.

The historical object commit remains unchanged. This exact, guarded backport
lets the acceptance gate compare the class port with the corrected legacy
behavior, as required by docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

OBJECT_DN_SHA = "b4916b874989d7b35660d02cf935dc5f0db7a656"


def replace_once(path: Path, old: bytes, new: bytes) -> None:
    source = path.read_bytes()
    newline = b"\r\n" if b"\r\n" in source else b"\n"
    old = old.replace(b"\n", newline)
    new = new.replace(b"\n", newline)
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one exact source pattern, found {count}")
    path.write_bytes(source.replace(old, new, 1))


def replace_between(path: Path, start: bytes, end: bytes, replacement: bytes) -> None:
    source = path.read_bytes()
    newline = b"\r\n" if b"\r\n" in source else b"\n"
    start = start.replace(b"\n", newline)
    end = end.replace(b"\n", newline)
    replacement = replacement.replace(b"\n", newline)
    if source.count(start) != 1:
        raise SystemExit(f"{path}: expected one section start marker")
    first = source.index(start)
    if source.count(end, first + len(start)) < 1:
        raise SystemExit(f"{path}: section end marker is missing")
    last = source.index(end, first + len(start))
    if last <= first:
        raise SystemExit(f"{path}: section markers are out of order")
    path.write_bytes(source[:first] + replacement + source[last:])


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} OBJECT_DN_CHECKOUT", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    actual_sha = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual_sha != OBJECT_DN_SHA:
        raise SystemExit(f"expected object DN {OBJECT_DN_SHA}, got {actual_sha}")
    tv_root = root / "tv"
    actual_tv_sha = subprocess.check_output(
        ["git", "-C", str(tv_root), "rev-parse", "HEAD"], text=True
    ).strip()
    if actual_tv_sha != "521d06479198789deeaa6fda287236ca83ba4051":
        raise SystemExit(
            "expected object TV 521d06479198789deeaa6fda287236ca83ba4051, "
            f"got {actual_tv_sha}"
        )

    osdep = root / "dn/compat/osdep.pas"
    # SysFindFirst told "no more files" (18) for a missing directory: PathExist of DN took every directory as existing (the extraction from
    # an archive looped forever looking for a free temporary directory). The class build has the fix; the comparator gets the same one.
    replace_once(
        osdep,
        b"""function SysFindFirst(Path: PChar; Attr: LongInt; var F: TOSSearchRec; IsPChar: Boolean): LongInt;
var
  I: Integer;
begin
  I := 1;""",
        b"""function SysFindFirst(Path: PChar; Attr: LongInt; var F: TOSSearchRec; IsPChar: Boolean): LongInt;
var
  I: Integer;
  Mask, Dir: string;
begin
  I := 1;""",
    )
    replace_once(
        osdep,
        b"""  if SysUtils.FindFirst(FixMask(SysOsPath(StrPas(Path))), Attr or faSymLink, Searches[I]^) <> 0 then
  begin
    SysUtils.FindClose(Searches[I]^);
    Dispose(Searches[I]);
    Searches[I] := nil;
    F.Handle := 0;
    Exit(18);
  end;""",
        b"""  Mask := FixMask(SysOsPath(StrPas(Path)));
  if SysUtils.FindFirst(Mask, Attr or faSymLink, Searches[I]^) <> 0 then
  begin
    SysUtils.FindClose(Searches[I]^);
    Dispose(Searches[I]);
    Searches[I] := nil;
    F.Handle := 0;
    Dir := ExtractFileDir(Mask);
    if Dir = '' then
      Dir := '.';
    if not DirectoryExists(Dir) then
      Exit(3);
    Exit(18);
  end;""",
    )

    # SysUtils gives the Unix time on Unix and TOSSearchRec.Time is a DOS packed time: the panels showed garbage dates (5.06.33 10:12) and a time
    # that depends on the second of the creation of a file. The class build has the conversion (SysFileTimeToDos); the comparator gets the same one.
    replace_once(
        osdep,
        b"""procedure Fill(var F: TOSSearchRec; const R: SysUtils.TSearchRec; IsPChar: Boolean);
""",
        b"""function SysFileTimeToDos(T: LongInt): LongInt;
{$IFDEF UNIX}
var
  Y, M, D, H, N, S, MS: Word;
begin
  DecodeDate(FileDateToDateTime(T), Y, M, D);
  DecodeTime(FileDateToDateTime(T), H, N, S, MS);
  if Y < 1980 then
  begin
    Y := 1980; M := 1; D := 1; H := 0; N := 0; S := 0;
  end;
  Result := LongInt((Cardinal(Y - 1980) shl 25) or (Cardinal(M) shl 21) or (Cardinal(D) shl 16) or (Cardinal(H) shl 11) or (Cardinal(N) shl 5) or (Cardinal(S) shr 1));
end;
{$ELSE}
begin
  Result := T;
end;
{$ENDIF}

procedure Fill(var F: TOSSearchRec; const R: SysUtils.TSearchRec; IsPChar: Boolean);
""",
    )
    replace_once(osdep, b"  F.Time := R.Time;\n", b"  F.Time := SysFileTimeToDos(R.Time);\n")

    # the same conversion in the file finder of TV (the dialogs that list files showed Unix times as DOS times: dates of 2033)
    tvfiles = tv_root / "src/tvfiles.pas"
    replace_once(
        tvfiles,
        b"""procedure TFileFinder.Fill;
var
  P: PSysRec;
begin
  P := PSysRec(Sys);
  Rec.Attr := Byte(P^.Attr);
  Rec.Time := P^.Time;
""",
        b"""{$IFDEF UNIX}
function UnixTimeToDos(T: LongInt): LongInt;
var
  Y, M, D, H, N, S, MS: Word;
begin
  DecodeDate(FileDateToDateTime(T), Y, M, D);
  DecodeTime(FileDateToDateTime(T), H, N, S, MS);
  if Y < 1980 then
  begin
    Y := 1980; M := 1; D := 1; H := 0; N := 0; S := 0;
  end;
  Result := LongInt((Cardinal(Y - 1980) shl 25) or (Cardinal(M) shl 21) or (Cardinal(D) shl 16) or
    (Cardinal(H) shl 11) or (Cardinal(N) shl 5) or (Cardinal(S) shr 1));
end;
{$ENDIF}

procedure TFileFinder.Fill;
var
  P: PSysRec;
begin
  P := PSysRec(Sys);
  Rec.Attr := Byte(P^.Attr);
{$IFDEF UNIX}
  Rec.Time := UnixTimeToDos(P^.Time);
{$ELSE}
  Rec.Time := P^.Time;
{$ENDIF}
""",
    )

    filescol = root / "dn/src/filescol.pas"
    replace_once(
        filescol,
        b"""function SameFile(P1, P2: PFileRec): Boolean;
  begin
  Result := False;
  if P1^.FlName[True] <> P2^.FlName[True] then
    Exit;
  if (P1^.Owner <> P2^.Owner) and (P1^.Owner^ <> P2^.Owner^) then
    Exit;
  Result := True;
  end;""",
        b"""function SameFile(P1, P2: PFileRec): Boolean;
  begin
  Result := False;
  if (P1 = nil) or (P2 = nil) then
    Exit;
  if P1^.FlName[True] <> P2^.FlName[True] then
    Exit;
  if P1^.Owner <> P2^.Owner then
    begin
    if (P1^.Owner = nil) or (P2^.Owner = nil) then
      Exit;
    if P1^.Owner^ <> P2^.Owner^ then
      Exit;
    end;
  Result := True;
  end;""",
    )
    replace_once(
        filescol,
        b"""  type
    TIsDupe = function(i: Integer): Boolean;
  var
    i,j, DupeStart, k: Integer;
    H: PFilesHash;
    S: TSize;
    IsDupe: TIsDupe;""",
        b"""  var
    i,j, DupeStart, k: Integer;
    H: PFilesHash;
    S: TSize;
    IsDupe, UseHash: Boolean;""",
    )
    replace_between(
        filescol,
        b"  function IsSortedDupe(i: Integer): Boolean;",
        b"  begin\n  if not Duplicates then",
        b"",
    )
    replace_between(
        filescol,
        b"  if SortMode = psmUnsorted then",
        b"\n\n  {",
        b"""  UseHash := SortMode = psmUnsorted;
  if UseHash then
    begin
    New(H, Init(@Self));
    if H^.HT <> nil then
      Exit;
    end;""",
    )
    replace_once(
        filescol,
        b"""  for i := 1 to Count-1 do
    if not IsDupe(i) then
      begin""",
        b"""  for i := 1 to Count-1 do
    begin
    if UseHash then
      IsDupe := not H^.AddItem(i)
    else
      IsDupe := SameFile(Items^[i-1], Items^[i]);
    if not IsDupe then
      begin""",
    )
    replace_once(
        filescol,
        b"""      inc(j);
      end;
  Count := j;""",
        b"""      inc(j);
      end;
    end;
  Count := j;""",
    )

    colors = root / "dn/src/colors.pas"
    replace_between(
        colors,
        b"procedure ChangeColors;\n  var",
        b"\nprocedure TWindowCol.FreeItem(Item: Pointer);",
        b"""procedure ChangeColors;
  var
    { TV's dialog streams a dynamic TPalette, not SystemColors' ShortString. }
    CurPal: TPalette;
    S: ShortString;
    I, N: Integer;
  begin
  CurPal := MakePalette(SystemColors[appPalette]);
  if ExecResource(dlgColors, CurPal) <> cmCancel then
    begin
    N := PaletteSize(CurPal);
    if N > 255 then
      N := 255;
    SetLength(S, N);
    for I := 1 to N do
      S[I] := Char(AttrToBIOS(CurPal[I]));
    SystemColors[appPalette] := S;
    Application^.Redraw;
    end;
  CurPal := nil;
  if VGASystem then
    GetPalette(VGA_palette);
  end;
""",
    )

    # The object TV comparator predates TV3's ColorSel stream support. Backport
    # the equivalent object methods only in this disposable comparator checkout.
    colorsel = tv_root / "src/tvcolorsel.pas"
    replace_once(
        colorsel,
        b"""    constructor Init(const Bounds: TRect; ASelType: TColorSel);
    procedure Draw; virtual;""",
        b"""    constructor Init(const Bounds: TRect; ASelType: TColorSel);
    constructor Load(var S: TStream);
    procedure Store(var S: TStream);
    procedure Draw; virtual;""",
    )
    replace_once(
        colorsel,
        b"""    constructor Init(const Bounds: TRect);
    procedure Draw; virtual;""",
        b"""    constructor Init(const Bounds: TRect);
    constructor Load(var S: TStream);
    procedure Draw; virtual;""",
    )
    replace_once(
        colorsel,
        b"""    constructor Init(const Bounds: TRect; const AText: ShortString);
    destructor Done; virtual;""",
        b"""    constructor Init(const Bounds: TRect; const AText: ShortString);
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);""",
    )
    replace_once(
        colorsel,
        b"""    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar; AGroups: PColorGroup);
    destructor Done; virtual;""",
        b"""    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar; AGroups: PColorGroup);
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);""",
    )
    replace_once(
        colorsel,
        b"""    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar; AItems: PColorItem);
    procedure FocusItem(Item: Integer); virtual;""",
        b"""    constructor Init(const Bounds: TRect; AScrollBar: PScrollBar; AItems: PColorItem);
    constructor Load(var S: TStream);
    procedure FocusItem(Item: Integer); virtual;""",
    )
    replace_once(
        colorsel,
        b"""    constructor Init(const APalette: TPalette; AGroups: PColorGroup);
    destructor Done; virtual;""",
        b"""    constructor Init(const APalette: TPalette; AGroups: PColorGroup);
    constructor Load(var S: TStream);
    destructor Done; virtual;
    procedure Store(var S: TStream);""",
    )
    replace_once(
        colorsel,
        b"procedure TColorSelector.Draw;",
        b"""constructor TColorSelector.Load(var S: TStream);
var
  Temp: Integer;
begin
  inherited Load(S);
  S.Read(Color, SizeOf(Color));
  S.Read(Temp, SizeOf(Temp));
  SelType := TColorSel(Temp);
end;

procedure TColorSelector.Store(var S: TStream);
var
  Temp: Integer;
begin
  inherited Store(S);
  S.Write(Color, SizeOf(Color));
  Temp := Ord(SelType);
  S.Write(Temp, SizeOf(Temp));
end;

procedure TColorSelector.Draw;""",
    )
    replace_once(
        colorsel,
        b"procedure TMonoSelector.Draw;",
        b"""constructor TMonoSelector.Load(var S: TStream);
begin
  inherited Load(S);
end;

procedure TMonoSelector.Draw;""",
    )
    replace_once(
        colorsel,
        b"destructor TColorDisplay.Done;",
        b"""constructor TColorDisplay.Load(var S: TStream);
begin
  inherited Load(S);
  Text := S.ReadStr;
  Color := nil;
end;

procedure TColorDisplay.Store(var S: TStream);
begin
  inherited Store(S);
  S.WriteStr(Text);
end;

destructor TColorDisplay.Done;""",
    )
    replace_once(
        colorsel,
        b"""constructor TColorGroupList.Init(const Bounds: TRect; AScrollBar: PScrollBar;
  AGroups: PColorGroup);""",
        b"""procedure WriteColorItems(var S: TStream; Items: PColorItem);
var
  Count: Integer;
  Cur: PColorItem;
begin
  Count := 0;
  Cur := Items;
  while Cur <> nil do
  begin
    Inc(Count);
    Cur := Cur^.Next;
  end;
  S.Write(Count, SizeOf(Count));
  Cur := Items;
  while Cur <> nil do
  begin
    S.WriteStr(Cur^.Name);
    S.Write(Cur^.Index, SizeOf(Cur^.Index));
    Cur := Cur^.Next;
  end;
end;

procedure WriteColorGroups(var S: TStream; Groups: PColorGroup);
var
  Count: Integer;
  Cur: PColorGroup;
begin
  Count := 0;
  Cur := Groups;
  while Cur <> nil do
  begin
    Inc(Count);
    Cur := Cur^.Next;
  end;
  S.Write(Count, SizeOf(Count));
  Cur := Groups;
  while Cur <> nil do
  begin
    S.WriteStr(Cur^.Name);
    WriteColorItems(S, Cur^.Items);
    Cur := Cur^.Next;
  end;
end;

function ReadColorItems(var S: TStream): PColorItem;
var
  Count: Integer;
  Items, Last, Cur: PColorItem;
  Name: PStr;
  Index: Byte;
begin
  S.Read(Count, SizeOf(Count));
  Items := nil;
  Last := nil;
  while Count > 0 do
  begin
    Dec(Count);
    Name := S.ReadStr;
    S.Read(Index, SizeOf(Index));
    New(Cur);
    Cur^.Name := Name;
    Cur^.Index := Index;
    Cur^.Next := nil;
    if Items = nil then
      Items := Cur
    else
      Last^.Next := Cur;
    Last := Cur;
  end;
  ReadColorItems := Items;
end;

function ReadColorGroups(var S: TStream): PColorGroup;
var
  Count: Integer;
  Groups, Last, Cur: PColorGroup;
  Name: PStr;
begin
  S.Read(Count, SizeOf(Count));
  Groups := nil;
  Last := nil;
  while Count > 0 do
  begin
    Dec(Count);
    Name := S.ReadStr;
    New(Cur);
    Cur^.Name := Name;
    Cur^.Index := 0;
    Cur^.Items := ReadColorItems(S);
    Cur^.Next := nil;
    if Groups = nil then
      Groups := Cur
    else
      Last^.Next := Cur;
    Last := Cur;
  end;
  ReadColorGroups := Groups;
end;

constructor TColorGroupList.Init(const Bounds: TRect; AScrollBar: PScrollBar;
  AGroups: PColorGroup);""",
    )
    replace_once(
        colorsel,
        b"destructor TColorGroupList.Done;",
        b"""constructor TColorGroupList.Load(var S: TStream);
begin
  inherited Load(S);
  Groups := ReadColorGroups(S);
end;

procedure TColorGroupList.Store(var S: TStream);
begin
  inherited Store(S);
  WriteColorGroups(S, Groups);
end;

destructor TColorGroupList.Done;""",
    )
    replace_once(
        colorsel,
        b"procedure TColorItemList.FocusItem(Item: Integer);",
        b"""constructor TColorItemList.Load(var S: TStream);
begin
  inherited Load(S);
  Items := nil;
end;

procedure TColorItemList.FocusItem(Item: Integer);""",
    )
    replace_once(
        colorsel,
        b"destructor TColorDialog.Done;",
        b"""constructor TColorDialog.Load(var S: TStream);
begin
  inherited Load(S);
  Display := PColorDisplay(ReadChildPtr(S));
  Groups := PColorGroupList(ReadChildPtr(S));
  ForLabel := PLabel(ReadChildPtr(S));
  ForSel := PColorSelector(ReadChildPtr(S));
  BakLabel := PLabel(ReadChildPtr(S));
  BakSel := PColorSelector(ReadChildPtr(S));
  MonoLabel := PLabel(ReadChildPtr(S));
  MonoSel := PMonoSelector(ReadChildPtr(S));
  Pal := nil;
  GroupIndex := 0;
end;

procedure TColorDialog.Store(var S: TStream);
begin
  inherited Store(S);
  PutPeerViewPtr(S, PView(Display));
  PutPeerViewPtr(S, PView(Groups));
  PutPeerViewPtr(S, PView(ForLabel));
  PutPeerViewPtr(S, PView(ForSel));
  PutPeerViewPtr(S, PView(BakLabel));
  PutPeerViewPtr(S, PView(BakSel));
  PutPeerViewPtr(S, PView(MonoLabel));
  PutPeerViewPtr(S, PView(MonoSel));
end;

destructor TColorDialog.Done;""",
    )

    # The sort letter in the corner of a panel: the Russian and Ukrainian strings of dlSortTag are UTF-8 and one byte of them was taken (a box
    # character or a wrong letter in the corner); the object build has the same bug.
    topview = root / "dn/src/topview.pas"
    replace_once(
        topview,
        b"""procedure TSortView.Draw;
  var
    B: Word;
    C: Char;
    R: TRect;
    SortSetup: ^TPanelSortSetup;
  begin""",
        b"""{$IFDEF DNUTF8}
{ the bytes of the character of S that starts at P (the sort letters of the language are UTF-8: the Russian ones are two bytes each) }
function SortCharLen(const S: String; P: Integer): Integer;
  begin
  Result := 1;
  if (P < 1) or (P > Length(S)) then
    Exit;
  case Byte(S[P]) of
    $C2..$DF: Result := 2;
    $E0..$EF: Result := 3;
    $F0..$F4: Result := 4;
  end;
  if P+Result-1 > Length(S) then
    Result := 1;
  end;
{$ENDIF}

procedure TSortView.Draw;
  var
{$IFDEF DNUTF8}
    B: TDrawBuffer;
    S, T: String;
    P, N: Integer;
{$ELSE}
    B: Word;
    C: Char;
{$ENDIF}
    R: TRect;
    SortSetup: ^TPanelSortSetup;
  begin""",
    )
    replace_once(
        topview,
        b"""  C := GetString(dlSortTag)[SortSetup^.SortMode + 1];
  if (SortSetup^.SortFlags and psfInverted) <> 0  then
    C := Upcase(C);
  MoveChar(B, C, Panel^.Owner^.GetColorW(3), 1);
  WriteLineW(0, 0, 1, 1, B);""",
        b"""{$IFDEF DNUTF8}
  S := GetString(dlSortTag);
  P := 1;
  for N := 1 to SortSetup^.SortMode do
    Inc(P, SortCharLen(S, P));
  T := Copy(S, P, SortCharLen(S, P));
  if (SortSetup^.SortFlags and psfInverted) <> 0  then
    Utf8UpStr(T);
  MoveStr(B[0], T, Panel^.Owner^.GetColorW(3));
  WriteLineC(0, 0, 1, 1, B);
{$ELSE}
  C := GetString(dlSortTag)[SortSetup^.SortMode + 1];
  if (SortSetup^.SortFlags and psfInverted) <> 0  then
    C := Upcase(C);
  MoveChar(B, C, Panel^.Owner^.GetColorW(3), 1);
  WriteLineW(0, 0, 1, 1, B);
{$ENDIF}""",
    )

    print(
        f"Applied guarded shared-bug backports to object DN {actual_sha} "
        f"and object TV {actual_tv_sha}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
