# DN platform separation

Stage 3 of [`POST-CLASS-WORK.md`](POST-CLASS-WORK.md), after English and the
readability refactor. This file records the observed seams and the definition
of done before implementation. It is not authorization to change product
behaviour or to port unsupported targets.

## Current boundaries (2026-10-06)

| Area | Current location | What is mixed today | Intended boundary |
|---|---|---|---|
| Files, paths, search, disks, process execution | `dn/compat/osdep.pas`, `dn/compat/osdisk*.pas` | Most DOS/Unix/Windows operations still share `osdep`; disk queries are now routed through a stable `OSDisk` facade to GO32V2, Windows, or Unix backend units | Continue extracting target operations behind stable facades; disk selection is centralized in `osdisk.pas` |
| External commands and user screen | `dn/src/dnrun.pas`, `dn/compat/osdep.pas` | Linux VT/PTy flow and DOS BIOS/video-memory user-screen handling/vector swapping remain in `DNRun`; shell and process replacement are delegated to `osdep` facades | Keep `DNRun` as the portable call surface; give platform runners explicit units and keep argument/path conversion with the runner that owns it |
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
startup screen. The focused class self-comparison passes locally; exact
object/class comparison and target builds for this new scenario are pending.

The next narrow step moved DOS process creation out of `DNRun`: it now calls
the existing `osdep.SysExecute` facade while retaining DOS vector swapping and
screen handling in the runner. Exact-SHA DN `68400a80218b01503f7f55900c7535299d3db093`
passed the class gate, layout, Linux, Windows, full DOS build, and object/class
acceptance (177 pass, 0 fail; runs `37393996207`, `37393995793`, `37393995904`,
`37393996078`, `37393995642`, and `37393995667`, respectively). This closes
only process creation; BIOS screen handling and vector lifecycle are still
platform-specific code in `DNRun`.

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
   creation uses `SysExecute`, and process replacement now uses
   `SysRestartSelf`; BIOS screen handling, DOS vector swapping, and Linux PTY
   remain in `dn/src/dnrun.pas`. Prove Linux PTY/user-screen and DOS screen
   behavior, plus Windows shell smoke.
3. Move remaining startup/screen platform mechanics behind existing/new
   facades, guided by call-site search and parity failures.
4. Re-run the full source inventory; mark stage 3 complete only when criteria
   1–5 are demonstrated and unresolved target limitations are explicitly
   listed.

Do not begin stage 4 (broader platform test expansion) until stage 3 is
complete, except for narrow tests required to prove an extraction batch.
