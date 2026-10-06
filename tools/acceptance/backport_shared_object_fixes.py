#!/usr/bin/env python3
"""Apply the two shared-bug fixes to the pinned object comparator checkout.

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

    print(f"Applied guarded shared-bug backports to object DN {actual_sha}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
