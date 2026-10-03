# Refactoring candidates (see PLAN.md, "Рефакторинг шаг за шагом")

One step after each big development step: the most burning item of this list, as a separate commit, no change of behavior (the tests are green
before and after). Add what you find; do not stop for it outside of the step. Mark what is done.

## Done
- [x] 2026-10-03: the results of the build are not in the source directories (tests of tv/ and dn/ are built into their own directory): `tools/tv-test.sh`.

- [x] 2026-10-03 (after the embedded terminal): the map "file -> what it holds" for a newcomer: `dn/FILES.md` (the renames are still to be decided).

- [x] 2026-10-03 (after aarch64 and the DOSBox-X patches): one table "script -> what it does -> which workflow calls it": `tools/README.md` (linked from `README.md`).

- [x] 2026-10-03 (after the autosave of the desktop): "who writes what and when" for the settings and the desktop (`DN.CFG`, `DN.INI`, `DN.DSK`, `DN<n>.SWP`, `DN.HIS`): a section in `dn/FILES.md`; the guess "(?)" at `dn1.pas` is replaced by what it holds. No code changed.

- [x] 2026-10-04: the directories of `dn/` by role: `archives/` (the formats of archives), `compat/` (the environment of Virtual Pascal / Borland / DPMI over `tv/`, with `shims/` and `linux/`), `src/` (DN itself). No unit renamed, no code changed: the binary of `linux64` is
  byte for byte the same, `dn-test.sh`, `check-layout.sh`, the builds for DOS and i386 are green. Where: `dn/FILES.md`, "How `dn/` is laid out".

## Candidates (rough order of how much they hurt)
**The owner's list (2026-10-04), in the order to do it; each is one step with the same proof (the binary does not change, the tests are green):**
1. *(started 2026-10-04: `dn1` -> `boot`, `dnapp` -> `mainapp`, `vpsyslo2` -> `vpsysext` (`vpsyslow` keeps the name of the unit of Virtual Pascal that it stands for); the tool is `tools/rename-unit.py`; done also: `advance*`, `microed*`, `ed2`, `edwin`, the panels (`flpanel`...), `u_*`, `topview_`, `country_`, `startupp`, `dnini_p`, `fbb`, `swe`; the empty stubs `callspcb`, `ufnmatch` deleted; `drivers2` (unused, a Borland-derived crash dump) deleted, `objects2` -> `baseobjs`)* *Names of the files of code that say nothing:* digits, underscores at the end, almost the same names (`vpsyslow` / `vpsyslo2`, `dn` / `dn1` / `dnapp`, `advance`..`advance7`, `microed` / `microed2`, `drivers` / `drivers2`, `u_myapp`, `topview_`, `country_`). Rules: a lower-case name of words, the unit has the same name as the file, no digits and no
   trailing `_`, one name = one subject. The source files are cross compiled, so 8.3 does **not** limit them (FPC takes long names on Linux); 8.3 matters only for the files that the program reads and writes on DOS (see 3). A tool `tools/rename-unit.py OLD NEW` (renames the file, the `unit` line and the `uses`
   and `{$I}` of all files, checks the build) first; then one family per commit (the first: `dn.pas`, `dn1.pas`, `dnapp.pas`: what each holds is in `dn/FILES.md`). A proposal of the new names goes to the owner before the rename (the names are the owner's to choose).
   The files of `archives/` lose the prefix `arc_` (the directory says it) in the same way.
2. *(done 2026-10-04: all the names are lower case: `dn/data/xlt`, `colors`, `dn.flg`, `dn/src/resource/{english,russian,ukrain}`, the output of the build and `dist/`; DN asks for lower case names and the language is not case sensitive)* *The zoo of the case in the names of files and directories* (`RESOURCE`, `Events.inc`, `DN.pas`...): one rule, lower case for all the sources and directories; the resource names the program reads stay what the DOS build needs (see 3).
3. *(done 2026-10-04 for the names: `dn.cfg dn.ini dn.cac dn.dsk dn<n>.swp dn.his dn.clp tetris.cfg`...: table in `dn/FILES.md`; open: merge `dn.cfg` into `dn.ini`, one directory for all of them)* *The zoo of the files that the program writes and reads* (`DN.CFG`, `DN.INI`, `DN.HIS`, `TETRIS.CFG`, `dnhgl.grp`, `DNINI.IN_`, `DN.DSK`, `DN<n>.SWP`): which of them is needed, what `.cfg` and `.ini` hold and why there are two (the table is in `dn/FILES.md`, "who writes what"), one case, no `_` extensions. Compatibility with the files of the old DN may be broken
   (the owner: not a beta yet). For DOS the names stay 8.3 and lower case; one directory for all of them (`dn/`?) is a decision of the owner.
4. *Shims and everything that emulates an environment* are in `dn/compat/` now; what is left: `helpfile`, `helpkern`, `messages`, `strview`, `listmakr`, `dnstddlg`, `asciitab` (ours, replace Borland units) and `events`, `xtime`, `files` (DN, DPMI helpers) are candidates for `compat/` or for `src/` after the rename step.

- **Final step (owner decision 2026-10-03):** move DN to the Safe Pascal style (repository `unxed/sp`): see `DN-ADOPTION.md` there and the short section "Safe Pascal как стиль кода DN" in PLAN.md (the order S0-S10 chosen by RUP: (c) first, then (a) with a decision point, (b) only as a fallback). Earlier than the end if it turns out cheap (the pilot on new code, stage 3).
- The names of DN files in `dn/src` are the DOS names of the archive (`microed`, `microed2`, `u_myapp`, `topview_`, `country_`, `advance`, `advance1`, `advance2`...): what a file
  holds is not visible from its name. A map "old name -> what it holds" in `dn/README.md` first, renames later (they break the diffs with the archive and
  `bootstrap/`: needs a decision how `bootstrap/` follows).
- `{$IFDEF DNUTF8}` is spread over ~15 files of DN. Put the two behaviors behind one facade (`dnutf8.pas`: columns, proxy, key text) so that the
  places in the code say what they mean, not which mode they are in. When the legacy mode is dropped (DOS only keeps the code page) the `IFDEF`s go.
- Two buffer models in DN: words (`AWord` buffers of the DBF viewer, `calendar`, `ed2`, `idlers`) and cells (`TScreenCell`); `WriteLineW`/`WriteLineC` are easy to mix up (a
  bug of 2026-10-03). One model (cells), `LegacyText` only at the border.
- `tv/src/tvtermos.pas` holds the Unix termios layer, the Windows console layer and the VT interpreter of the console mode: split by what they do; the interpreter
  of the console mode can use `TvVt` (PLAN.md item 8) instead of its own.
- The names of the entities in the sources of DN that came from the archive (`SysXXX`, `DnXXX`, abbreviations of Russian words) — rename only the ones that a newcomer meets in
  the first hour: the entry points (`DN.pas`, `u_myapp`, `flpanel`, `filescol`, `drives`).

## What is left of Virtual Pascal (the review of 2026-10-04: what FPC can do instead)

Done in this step: `vputils` is gone (`Min`/`Max` are `Math`, the hex functions `IntToHex`, the time `GetTickCount64`, the date `Dos.GetDate`, the label `SysGetVolumeLabel`; the rest moved to the unit that uses it or to `compat/drivers.pas`);
dead code of the layer deleted (7 routines, 3 constants); `vpsyslo2` is `osfind` (the units of the layer were renamed by what they do on 2026-10-04: `vpsyslow` -> `osdep`, `vpsysext` -> `osfind`, `dpmi32` -> `realmode`, `dpmi32df` -> `fat32free`, `doslow` -> `dosbuf`; the `Sys*` names of the routines stay). What is left in `dn/compat/` and what it would take to drop it (the number is the call sites outside of `compat/`):

| Unit | What it does | Instead | Verdict |
|---|---|---|---|
| `osdep` (the files: `SysFileOpen/Create/Seek/Read/Write/Close/SetSize` ~35) | the file API of VP with the names of DN (DOS names, `SysOsPath`, the code page) | `SysUtils.FileOpen...` + the conversion of the name in one place | **candidate:** a rewrite of `lfn.pas` over `TFileStream`/`FileOpen`; the conversion of names (`SysOsPath`, 28) stays: it is not an RTL thing |
| `osdep` (`SysFindFirst/Next/Close`, 12) | the search of a directory in the record of VP | `SysUtils.FindFirst` (it already lies on it) | **candidate** together with `osfind` (the "new" record) and `lfn.pas` |
| `osdep` (the disks: `SysDiskFree/SizeLongX`, `SysGetValidDrives`, `SysGetVolumeLabel`, ~20) | free space, drives, label | `DiskFree`, `DiskSize` of FPC (by number of the drive; the Unix mapping of C: is ours) | keep, thin |
| `dnscreen` (was in `osdep`: `SysTv*`, ~35 call sites) | glue to `tv/`: the copy of the screen in 16-bit cells and the cursor shape in lines | — | **done (moved and renamed 2026-10-04):** the glue stays as its own unit with semantic names (`ReadScreenCells`, `WriteScreenCells`, `GetCursorType`...); dropping it needs DN to read `TvScreen` cells (UTF-8) instead of 16-bit cells: that is the UTF-8 step (task 4) |
| `osdep` (`SysBeepEx` 6, `SysKeyPressed/ReadKey` 3, `PhysMemAvail` 3) | small things | `SysCtrlSleep`, `SysPlatformId` are gone (`Sleep`, `{$IFDEF GO32V2}`); the three left are real code (the PC speaker through ports, DPMI memory info, the key of the fatal-error screen) | **keep** (decided 2026-10-04: no FPC equivalent; each is one place of use) |
| `osfind` | the "new" search record (creation time, last access) | `TSearchRec` has them (`FindData` on Windows; `stat` on Unix) | with the search above |
| `memory` | (deleted 2026-10-04) | `MemAlloc` is `GetMem` (`ReturnNilIfGrowHeapFails := True` in `dn.pas`: nil instead of an exception); `LowMemory` was always False: its 22 conditions are removed; the no-op `InitMemory`... are gone | **done** |
| `realmode`, `fat32free`, `dosbuf` | real-mode calls of DOS (LFN of Windows 95, the clipboard, FAT32) | `go32` of FPC (DOS only) | **DOS only:** `{$IFDEF GO32V2}` in `lfn.pas`, `fsinfo.pas`, `videoman.pas`, `dnexec.pas`; on Linux and Windows they are stubs that fail |
| `use16` | (deleted 2026-10-04) | `SmallInt` in `dbwatch`, `pktview`, `uucode`, `uue2inc` (`Word` is 16 bits in FPC anyway) | **done** |
| `baseobjs` | `TObject` of DN = `TObject` of `tv/`; `FreeObject`, `ObjChangeType` | `tv/` | with the shims |
| `country` | the country table | `SysUtils` formats + the table of CP866 (ours) | keep |
| `drivers` | the keys, the events, `DNKeyCode`, `MessageKey`, the cursor | — (it is the adapter to `tv/`) | keep, it is the border |

The order (each is a step with the same proof: the tests, the builds, the binary behaves): 1) (done) `use16` -> `SmallInt`; 2) (done) the small things of `osdep`; 3) (done) `memory`; 4) (done) the screen glue -> `dnscreen`; 5) DOS-only `dpmi32*`; 6) the files and the search (the biggest).

- osdep: SysCtrlSleep, SysPlatformId and the no-op SysTv* (KbdInit/KbdDone/InitCursor/SetScrMode) are gone; the platform
  checks are `{$IFDEF GO32V2}`, the sleep is `Sleep(1)` (done).
