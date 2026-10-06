# DN platform separation

Stage 3 of [`POST-CLASS-WORK.md`](POST-CLASS-WORK.md), after English and the
readability refactor. This file records the observed seams and the definition
of done before implementation. It is not authorization to change product
behaviour or to port unsupported targets.

## Current boundaries (2026-10-06)

| Area | Current location | What is mixed today | Intended boundary |
|---|---|---|---|
| Files, paths, search, disks, process execution | `dn/compat/osdep.pas`, `dn/compat/osdisk*.pas` | Most DOS/Unix/Windows operations still share `osdep`; disk queries are now routed through a stable `OSDisk` facade to GO32V2, Windows, or Unix backend units | Continue extracting target operations behind stable facades; disk selection is centralized in `osdisk.pas` |
| External commands and user screen | `dn/src/dnrun.pas`, `dn/compat/dnuserscreendos.pas`, `dn/compat/osdep.pas` | Linux VT/PTy flow and DOS vector swapping remain in `DNRun`; DOS BIOS/video-memory user-screen handling is now in `DNUserScreenDos`; shell and process replacement are delegated to `osdep` facades | Keep `DNRun` as the portable call surface; give platform runners explicit units and keep argument/path conversion with the runner that owns it |
| Real-mode compatibility | `dn/compat/realmode.pas` | GO32-only BIOS/DPMI operations are conditional stubs on other targets | Keep DOS-only implementation isolated; do not spread direct BIOS/DPMI calls into application units |
| Startup path and screen restoration | `dn/src/boot.pas`, `mainapp.pas`, `panelroot.pas` | Some terminal/UTF-8/OS initialization and user-screen restoration decisions remain at application call sites | Replace OS decisions with narrow facade calls; portable startup owns sequencing, platform services own mechanics |
| UTF-8 names and terminal text | `dn/compat/osdep.pas`, `dn/compat/dnscreen.pas`, `dn/src/dnutf8.pas`, selected callers | Name conversion, screen-cell conversion, and terminal rendering have different platform semantics | Keep text policy in the shared facade; put OS-specific conversion/rendering at backend edges and document each unavoidable conditional |

First extraction landed: Linux command-line path/encoding conversion moved
from `DNRun` to the stable `osdep` facade as `SysCommandLineToOs`; its six
command-path regression checks remain in `t_dnrun`. Local proof before commit:
`tools/dn-test.sh` PASS (12 programs), `tools/build.sh linux64` PASS for legacy
and `DN_UTF8=1` variants. Exact-SHA CI `1f51f75` then passed all 177 object/class
acceptance scenarios (`37387363591`), Linux (`37387361374`), Windows
(`37387362011`), `dn` (`37387362801`), and layout (`37387361710`). No mismatch
was introduced; this extraction is closed.

The disk-query family is extracted and verified: `osdep` retains its existing
four public `Sys*` APIs, while `OSDisk` selects `OSDiskDos`, `OSDiskWindows`,
or `OSDiskUnix`. `t_osdep` exercises free-space, total-space, drive-number,
and drive-map behavior through the facade. On DN
`22b7db490f76276ef426cf475bc85c30a4504b22`, the strict class gate, all 12
unit-test programs, layout, Linux legacy/UTF-8 and PTY/archive matrix, Windows,
DOS full build, and object/class acceptance all passed; acceptance summary:
177 pass, 0 fail. Actions: `dn` run `37390644713`, layout `37390645351`, Linux
`37390644764`, Windows `37390644905`, DOS/toolchain `37390644563`, and
acceptance `37390645223`. The DOS build exposed and prompted the `PGroup` →
`TGroup` correction recorded in the regression checklist. The toolchain
workflow uses the same `runner.temp` prefix for cache, compiler, hello program,
and DN build.

Unix process replacement was then moved from `DNRun` into
`osdep.SysRestartSelf`; the Windows and DOS `ExecuteProcess` branch is there as
well. Exact-SHA DN `e551fee53eddf009720f6d79037a1bc06bd9f570` passed the class
gate, layout, Linux, Windows, full DOS build, and object/class acceptance
(177 pass, 0 fail; runs `37395436984`, `37395436849`, `37395436982`,
`37395436934`, `37395436869`, and `37395436777`, respectively). A new
`restart_language` acceptance scenario now changes the active language, checks
that the setting was persisted, and requires DN to return to a live localized
startup screen. Its first CI run exposed uppercase resource artifact globs
although `build.sh` emits lowercase `.lng/.dlg/.hlp`, leaving both test binaries
without language assets; the workflow globs and scenario fixture were corrected.
A local replay with both object and class binaries plus the packaged resources
passes. Exact-SHA CI with freshly uploaded resources is pending.

The next narrow step moved DOS process creation out of `DNRun`: it now calls
the existing `osdep.SysExecute` facade while retaining DOS vector swapping and
screen handling in the runner. Exact-SHA DN `68400a80218b01503f7f55900c7535299d3db093`
passed the class gate, layout, Linux, Windows, full DOS build, and object/class
acceptance (177 pass, 0 fail; runs `37393996207`, `37393995793`, `37393995904`,
`37393996078`, `37393995642`, and `37393995667`, respectively). This closes
only process creation; BIOS screen handling and vector lifecycle are still
platform-specific code in `DNRun`.

The DOS user-screen operations were then moved to `compat/dnuserscreendos.pas`:
BIOS mode/cursor reads, video-memory capture/restore, and the Ctrl-O display
path no longer live in `DNRun`/`mainapp`. Exact-SHA `e2d49d9` passes `dn`,
layout, Windows, and all four Linux targets; the complete object/class
acceptance rerun reports 178/178 (run `37406171992`; its first execution had a
`menu_5_13` mismatch, recorded in the migration checklist). That same scenario
failed again on `cd37065` (`37408063297`, 177/178). Full row diagnostics showed
that its Options→Editors file-selection tree recursively scans the host root;
the object/class snapshots were taken 28 seconds apart during that scan, and
the `files with … bytes` aggregate advanced from 68,459 / 5,538,459K to 120,614
/ 9,916,057K. Commit `0ad0900` added full differing-row output; the first
stabilization at `3318781` (10 seconds unchanged) still sampled progress at
81,121 / 5,694,486K versus 126,183 / 10,450,278K. On `ca44f21`, the 45-second
stabilizer still sampled changing totals because it returned before the row
first appeared. The current change waits for the aggregate to appear and then
remain unchanged for 45 seconds (110-second cap; 150-second scenario limit).
Exact-SHA DN `d569ddd69b91c04c3260ece04520b97549ff7378` acceptance run
`37412056898` passed 178/178, including `menu_5_13`; the Linux workflow
`37412056902` passed all four Linux jobs (legacy/UTF-8 x86_64, i386 and
aarch64). The class/object parity gate is closed on this SHA.
The DOS build passes, but its new `userscr` runtime smoke exposed a
harness bug: `CheckScreenDump` (which injects `DNKEYS` and enforces
`DNDUMPSEC`) was defined but never called, so DOSBox-X timed out before running
the external command. Commit `cb55ec3` adds a shorter timeout and trace on
failure; `cd37065` calls the test hook from the GO32V2 idle loop. On that exact
SHA, DOS/toolchain run `37408063336` passed and printed `userscr ok` after
finding `hi` in the captured user screen. This closes the user-screen
preservation smoke for this batch. DOS vector swapping/lifecycle and Linux PTY
remain in `DNRun`.

The inventory is deliberately limited to the first extraction families; the
presence of `Dos` in historical DN units alone does not mean that every caller
should be rewritten. Preserve DN's DOS path/error semantics through the
facades.

## Completion criteria

1. **One stable call surface per concern.** Application units do not call
   `BaseUnix`, `Windows`, `go32`, BIOS interrupts, or platform process APIs
   directly. Compatibility facades retain DN's documented path, error,
   screen, and process semantics.
2. **Visible ownership.** Platform implementations live in named backend
   units/directories, with target selection in one small place. Each remaining
   target conditional outside those boundaries has a one-line rationale in
   this file.
3. **Build matrix.** Every shipped build configuration has a compile check:
   Linux legacy and UTF-8, Windows, and DOS/GO32 where the toolchain is
   available. A skipped target is reported as unavailable, never as passed.
4. **Behaviour lock.** A batch touching paths, screen, terminal, startup,
   or process execution runs targeted platform tests and the object/class
   parity acceptance matrix. No output, key handling, or text/background
   colour difference is accepted without owner-approved scope change.
5. **No broad cleanup.** Extract one concern per commit; keep each commit
   independently buildable and push immediately. Add/extend a regression test
   for every behavior-sensitive branch moved.

## Implementation order

1. Continue extracting `osdep` file/path/search operations without changing
   its public API; disk queries are complete. Prove platform behavior for each
   additional family before closing it.
2. Extract `DNRun` platform runners and DOS user-screen handling. DOS command
   creation uses `SysExecute`, and process replacement uses `SysRestartSelf`;
   BIOS user-screen operations now live in `DNUserScreenDos`, with the DOS
   persistence smoke passing. DOS vector swapping and Linux PTY remain in
   `dn/src/dnrun.pas`. Prove Linux PTY/user-screen and Windows shell smoke.
3. Move remaining startup/screen platform mechanics behind existing/new
   facades, guided by call-site search and parity failures.
4. Re-run the full source inventory; mark stage 3 complete only when criteria
   1–5 are demonstrated and unresolved target limitations are explicitly
   listed.

Do not begin stage 4 (broader platform test expansion) until stage 3 is
complete, except for narrow tests required to prove an extraction batch.

Next narrow step (2026-10-06): the Unix names family (`NameConv`, `NameFromOs`,
`NameToOs`, `ResolveCase`, the path and command-line conversion) moved from
`osdep` to `compat/osnamesunix.pas`; `osdep` keeps `SysOsPath`, `SysNameToOs`,
`SysCommandLineToOs` as thin wrappers and its other users of the names
(`SysRunShell`, `SysGetDirDos`, `SysFindFirst`, the initialization) call the new
unit. The code is moved as it was, no behaviour change. Compiles for linux64,
win64 and dos locally; the proof is the CI of the commit (unit tests `t_osdep`,
`t_dnrun`, the class gate, Linux and Windows, the full DOS build). Left in
`osdep`: the DOS names (`DosNameToUtf8`, `DosNameFromUtf8`, the AMIS provider
`DOS-UTF8/NAMES`), then the file calls, the find calls, `SysExecute`.

Second narrow step (2026-10-06): the DOS names family (the AMIS provider
`DOS-UTF8/NAMES` switch `DosNamesInit`, `DosNamesUtf8`, `DosNameToUtf8`,
`DosNameFromUtf8`) moved from `osdep` to `compat/osnamesdos.pas` (code as it
was). `osdep` keeps `SysOsPath` / `SysNameToOs` and the file calls, which use the
unit on the GO32V2 target. Compiles for dos (code page inside), dos with
`DN_UTF8=1`, linux64 and win64 locally; the proof is the CI of the commit
(full DOS build with the scenarios of `tools/dn-dos-input.py`, among them
`utf8-names-cp`). Left in `osdep`: the file calls, the find calls, the disk
calls of the facade, `SysExecute`, the start screen of DOS.

Also found while testing archives (not a separation step): DN starts its helpers
(the archivers) as `COMSPEC /c command`; on Unix COMSPEC is not set, the command
became `"" /c ...` and nothing was extracted or packed. `SysExecute` now takes
the `/c` form on Unix and runs the command in the shell of the system without
the pause for Enter (`RunShellUnix`); test in `t_osdep`, the real extraction in
`tools/dn-linux-archives.py`.

Third narrow step (2026-10-06): starting programs moved out of `osdep` into the
facade `compat/osrun.pas` with the backends `osrununix.pas`, `osrunwindows.pas`
and `osrundos.pas` (`RunShell`, `Execute`, `RestartSelf`; the DOS way
`COMSPEC /c command` on Unix is in `OSRunUnix.BackendExecute`). `osdep` keeps
`SysRunShell`, `SysExecute`, `SysRestartSelf` as thin wrappers. Same code, same
behaviour. Compiles for linux64, win64, dos and dos with `DN_UTF8=1`; the proof
is the CI of the commit. What stays in `osdep` now: the thin wrappers, the file
and find calls (already neutral: `SysUtils` + the names units), the volume label
and device calls with a GO32V2 branch, the start screen of DOS.

Fourth narrow step (2026-10-06): the small calls of the system (device test of a
handle, volume label, disk buffers, the PC speaker, memory for buffers) moved to
the facade `compat/ossystem.pas` with `ossystemdos.pas` (BIOS/DPMI) and
`ossystemother.pas` (Unix and Windows: nothing to do); `osdep` keeps the `Sys*`
names as wrappers. Same code and behaviour; compiles for linux64, win64 and dos;
CI is the proof. `osdep` now has no direct DOS call except the start screen
(`GrabStartScreen`, the vars `SysStartScreen*`, read by `dnuserscreendos`): moving
them needs the readers to use the new unit; the next step.

Fifth step (2026-10-06): the start screen of DOS (`SysStartScreen*`,
`GrabStartScreen`) moved to `compat/osstartscreen.pas` (mainapp and
dnuserscreendos use it now; `osdep` uses it so that the grab still runs before
`DosInit`). After this `osdep` has no DOS-specific code that is not a thin
wrapper or the initialization of the target. Stage 3 for `osdep` is done at this
granularity; what is left is outside it (`dnrun`, `dnscreen`, `boot` call sites
that decide by the target, see the table at the top), to be taken from the list
there when the CI of the steps above is green.

Sixth step (2026-10-06): the DOS test harness (`DNDUMP`, `DNKEYS`, `DNMOUSE`:
`CheckScreenDump`, its state, `TraceView`, `DumpAtExit`) moved from `mainapp` to
`src/dosharness.pas`; `TProgram.Idle` still calls `CheckScreenDump` under
GO32V2. Same code. `DumpAtExit` is not called by anyone (dead code, kept as it
was; noted in `dn/TODO-later.md`). The proof is the DOS scenarios of
`tools/dn-dos-input.py` in the CI of the commit.

Seventh step (2026-10-06): the units outside the backends no longer call a platform unit. `fmtxz.pas` took `Unix`/`BaseUnix` for `fpSystem` and the
process id of a temporary file name: it now calls `SysRunQuiet` (facade `OSRun.RunQuiet`, backends `OSRunUnix`, `OSRunWindows`, `OSRunDos`) and `SysTempFileName`
(`osdep`, portable). `dnerrlog.pas` took `go32` for the serial trace of DOS: the trace goes through `OSSystem.OSSerialTrace` (`OSSystemDos` writes to COM1,
`OSSystemOther` does nothing). Tests: `t_osrun` (`RunQuiet`), `t_osdep` (`SysTempFileName`). Compiles for linux64 and dos locally (the DOS build runs in DOSBox-X: the
tour scenarios `f5copy`, `tab`, `f1help`, `userscr`). What is left in the inventory: `dnrun` (the Linux PTY runner and the DOS vector swap in one unit), the target
decisions of `mainapp` and `boot`, the `.BAT` defaults of `startup`/`dlgrecs`, and the split of tv3 `tvtermos`.

Eighth step (2026-10-06): `DNRun` is a portable facade and the targets are `compat/dnrundos.pas` (the user screen of DOS, COMMAND.COM, `SwapVectors`),
`compat/dnrunlinux.pas` (the pty of `TvVtRun` and the screen of the commands) and `compat/dnrunother.pas` (the shell gets the terminal); `mainapp` and `dnutil`
ask `HasCommandScreen` instead of deciding by the target. The extension of the files for a command interpreter (`OSSystem.OSBatchExt`), the default temporary
directory (`OSDefaultTempDir`), the directories that a tree scan skips (`SysSkipInTree`) and the sync of the 16-bit screen copy after the first draw
(`SyncScreenCopyAfterDraw` of `dnscreen`) moved behind facades too. In tv3 `TvTermOs` is a facade and the code of the targets is in `TvTermOsUnix`, `TvTermOsWin` and
`TvTermOsNone` (the shared types in `TvTermOsBase`; not done: the replacement of the private parser of the Windows console by `TvVt`, it would change behaviour).
Compiles for linux64 (UTF-8 and code page) and dos locally, the DOS tour scenarios `f5copy`, `tab`, `f1help`, `userscr`, `ctrlo` pass in DOSBox-X; the Windows
build is checked by the CI of the commit.

Ninth step (2026-10-06): the boundary is checked, not only documented: `tools/check-platform.py` (CI: `layout`) fails when a unit outside the backends uses `BaseUnix`,
`Unix`, `Windows`, `go32`, `termio`, `dpmiexcp` or `Linux`, or has a target conditional that is not in its table (the table gives the reason: the facade of the runner, the archive
formats that need the tools of Unix). The DOS test aid `dosharness.pas` moved to `compat/` (it is a DOS backend), `mainapp` no longer uses `go32`.

