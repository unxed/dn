# Paths in DN

DN began as a DOS program and kept the names of DOS inside: `C:\HOME\X\FILE.EXT`, a drive letter, a backslash. The Linux build turned
them into system names at the border (`SysOsPath`: drop the drive, `\` to `/`). That is a translation layer, not a cross-platform design,
and it has real faults (a Unix file name that holds a backslash is cut in two; "C:" is shown to the user on a system that has no drives).

## Target

* A path inside DN is a path of the host. On Unix it is `/home/x/file`: no drive, the separator is `/`, the root is `/`. On DOS and Windows
  it stays `C:\DIR\FILE`, or `\\host\share\...`.
* The one place that knows the difference is `dn/compat/dnpath.pas`: `DnSep`, `HasDrives`, `IsPathSep`, `PathRootLen`, `IsAbsPath`,
  `NormalizeSep`. The rest of DN does not spell a separator or a drive letter. `tools/check-paths.py` (called by `tools/check-layout.sh`)
  counts the places that still do, against `tools/paths-baseline.txt`; the number may only fall.
* The members of an archive keep `\` on every host (`ArcSep`): that is the format DN's archive code has always used, it is not a host path.
* Code that needs drives (the drive menu, `D:` hotkeys, the drive bar of a panel) asks `HasDrives` and is absent on Unix. On Unix the
  places to go are mount points, home, `/`, bookmarks.
* Text typed by the user is taken in either form on DOS and Windows; on Unix only `/` separates.

## Status (2026-10-08)

Done: `DnPath` (`DnSep`, `ArcSep`, `HasDrives`, `IsPathSep`, `PathRootLen`, `IsAbsPath`, `IsQualified`, `DriveOf`, `DriveRoot`); `lFExpand`
(components, one code path for every host), `lChDir`, `lGetDir`, `MakeSlash`, `MakeNoSlash`; the temporary and the program directories; the
resource compiler files; the archive layer keeps its own separator (`ArcNormName`, `ArcGetPath`, `TDirStorage`). On Unix a path is `/a/b`, a
backslash in a name is a letter. Checked: the unit tests (all 25 programs), the pty tests (editor, tour, clip, desktop, ops, find, setup, config,
crash, startup, qsearch, sortmark, locale, resize, about, archives, arcmembers, names, kitty).

Open: the drive bar `[ C * ]` and the drive menu (Alt-F1) still show the virtual drive C on Unix: they should show the root, the home
directory and the mount points; the ratchet baseline falls only as callers are converted; the Windows and DOS targets still have to be built
and run with the new `lFExpand` (CI).

## Order of work

1. `DnPath` and the ratchet (done).
2. The core: `lFExpand`, `lChDir`, `lGetDir`, `MakeSlash`, `MakeNoSlash`, `GetShareEnd` in `lfn.pas` and `fileutil.pas` use `DnPath`.
   On Unix `ActiveDir` becomes `/dir/` and `SysOsPath` is the identity (plus the case lookup and the code-page names).
3. The callers, in batches, each batch checked by the pty tests (`tools/dn-linux-*.py`) and the unit tests: panels and tree, copy and
   find, the drive menu, archive layer.
4. The baseline falls to what the DOS and Windows backends need.
