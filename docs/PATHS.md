# Paths in DN

DN began as a DOS program and kept the names of DOS inside: `C:\HOME\X\FILE.EXT`, a drive letter, a backslash. The Linux build turned
them into system names at the border (`SysOsPath`: drop the drive, `\` to `/`). That is a translation layer, not a cross-platform design,
and it has real faults (a Unix file name that holds a backslash is cut in two; "C:" is shown to the user on a system that has no drives).

## Target

* A path inside DN is a path of the host. On Unix it is `/home/x/file`: no drive, the separator is `/`, the root is `/`. On DOS and Windows
  it stays `C:\DIR\FILE`, or `\\host\share\...`.
* The rules of each system live in `TvPath` of tv3 (`tv/src/tvpath.pas`); `dn/compat/dnpath.pas` is a thin layer over it (`DnSep`,
  `HasDrives`, `IsPathSep`, `PathRootLen`, `IsAbsPath`, `NormalizeSep`) with what only DN needs (`ArcSep`, `DriveOf`, `DriveRoot`,
  `HasDriveLetter`, `IsQualified`). The rest of DN does not spell a separator or a drive letter. `tools/check-paths.py` (called by `tools/check-layout.sh`)
  counts the places that still do, against `tools/paths-baseline.txt`; the number may only fall.
* The members of an archive keep `\` on every host (`ArcSep`): that is the format DN's archive code has always used, it is not a host path.
* Code that needs drives (the drive menu, `D:` hotkeys, the drive bar of a panel) asks `HasDrives` and is absent on Unix. On Unix the
  places to go are mount points, home, `/`, bookmarks.
* Text typed by the user is taken in either form on DOS and Windows; on Unix only `/` separates. The functions of the RTL that split or
  expand a name (`ExtractFileName`, `ExtractFileDir`, `ExpandFileName`, `IncludeTrailingPathDelimiter`, `FSplit`, `FExpand`) take `\`
  as a separator on Unix too: DN calls `lFSplit`, `lFExpand` and `TvPath` instead.

## Status (2026-10-08)

Done: `DnPath` (`DnSep`, `ArcSep`, `HasDrives`, `IsPathSep`, `PathRootLen`, `IsAbsPath`, `IsQualified`, `DriveOf`, `DriveRoot`); `lFExpand`
(components, one code path for every host), `lChDir`, `lGetDir`, `MakeSlash`, `MakeNoSlash`; the temporary and the program directories; the
resource compiler files; the archive layer keeps its own separator (`ArcNormName`, `ArcGetPath`, `TDirStorage`). On Unix a path is `/a/b`, a
backslash in a name is a letter. Checked: the unit tests (all 25 programs), the pty tests (editor, tour, clip, desktop, ops, find, setup, config,
crash, startup, qsearch, sortmark, locale, resize, about, archives, arcmembers, names, kitty).

Done: the drive menu (Alt-F1, the tree, the new-window menu) lists the root, the home directory and the mount points of real devices
(`/proc/mounts`) on a host without drives (`LoadPlaces` in fileutil.pas, test `tools/dn-linux-places.py`).
Done: `DnPath` asks `TvPath`; `lFExpand` is `TvPath.PathExpandIn` from `ActiveDir` (or the current directory of the drive); the tests
of a drive letter (`S[2] = ':'`) are `HasDriveLetter` and `IsQualified`, so on Unix the history of directories, the tree and the copy
dialog of the file list take `/a/b`; the archive notation `ARC:\` uses `ArcSep`. The ratchet fell from 46 to 8: the sets of punctuation
(word breaks, the characters a name may not hold), an escape of the highlighter and a call of DOS (`GetShare` in fsinfo.pas).
Open: the drive bar `[ C * ]` still shows the virtual drive C on Unix; the Windows and DOS targets still have to be built and run with
the new `lFExpand` (CI); the masks `*.*` and the switches `/X` of the command line (dnutil.pas, envutil.pas) are not counted by the
ratchet.

## Order of work

1. `DnPath` and the ratchet (done).
2. The core: `lFExpand`, `lChDir`, `lGetDir`, `MakeSlash`, `MakeNoSlash`, `GetShareEnd` in `lfn.pas` and `fileutil.pas` use `DnPath`.
   On Unix `ActiveDir` becomes `/dir/` and `SysOsPath` is the identity (plus the case lookup and the code-page names).
3. The callers, in batches, each batch checked by the pty tests (`tools/dn-linux-*.py`) and the unit tests: panels and tree, copy and
   find, the drive menu, archive layer.
4. The baseline falls to what the DOS and Windows backends need.

## Audit of the whole code base (stage 8b)

A path on a host without drives never shows a drive letter (`C:`), a backslash or a `\\server\share` form: not in the panels, the titles,
the dialogs, the command line, the messages, the history, the file lists, the log or the report of a crash. The same holds for fpide
(`fpide/src`), tv3 (`tvchdir.pas` and the file dialogs) and tve. The audit has three parts: (1) a pty test that visits the screens of
the Linux build and fails on a drive letter or a backslash in a path (`tools/dn-linux-pathscan.py`); (2) the ratchet `tools/check-paths.py`
for dn (it falls only); (3) the same ratchet idea for fpide, tv3 and tve (`tools/check-paths.py` takes the roots). Findings are fixed in the
caller, with `DnPath` or `TvPath`, never by a special case for Linux in the output.
