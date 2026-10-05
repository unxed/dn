# DN platform separation

Stage 3 of [`POST-CLASS-WORK.md`](POST-CLASS-WORK.md), after English and the
readability refactor. This file records the observed seams and the definition
of done before implementation. It is not authorization to change product
behaviour or to port unsupported targets.

## Current boundaries (2026-10-06)

| Area | Current location | What is mixed today | Intended boundary |
|---|---|---|---|
| Files, paths, search, disks, process execution | `dn/compat/osdep.pas` | DOS API facade and DOS/Unix/Windows-specific implementations share one unit under `GO32V2`, `UNIX`, and `WINDOWS` conditionals | Keep `osdep` as the stable DN-facing API; move target operations into explicit DOS, Unix, and Windows backend units selected in one place |
| External commands and user screen | `dn/src/dnrun.pas` | Linux VT/PTy flow, DOS BIOS/video-memory user-screen handling, and generic restart/shell flow are compiled together | Keep `DNRun` as the portable call surface; give platform runners explicit units and keep argument/path conversion with the runner that owns it |
| Real-mode compatibility | `dn/compat/realmode.pas` | GO32-only BIOS/DPMI operations are conditional stubs on other targets | Keep DOS-only implementation isolated; do not spread direct BIOS/DPMI calls into application units |
| Startup path and screen restoration | `dn/src/boot.pas`, `mainapp.pas`, `panelroot.pas` | Some terminal/UTF-8/OS initialization and user-screen restoration decisions remain at application call sites | Replace OS decisions with narrow facade calls; portable startup owns sequencing, platform services own mechanics |
| UTF-8 names and terminal text | `dn/compat/osdep.pas`, `dn/compat/dnscreen.pas`, `dn/src/dnutf8.pas`, selected callers | Name conversion, screen-cell conversion, and terminal rendering have different platform semantics | Keep text policy in the shared facade; put OS-specific conversion/rendering at backend edges and document each unavoidable conditional |

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

1. Extract `osdep` file/path/search/disk operations without changing its public
   API; prove Linux paths and Windows/DOS compile paths.
2. Extract `DNRun` platform runners and DOS user-screen handling; prove Linux
   PTY/user-screen and DOS screen behavior, plus Windows shell smoke.
3. Move remaining startup/screen platform mechanics behind existing/new
   facades, guided by call-site search and parity failures.
4. Re-run the full source inventory; mark stage 3 complete only when criteria
   1–5 are demonstrated and unresolved target limitations are explicitly
   listed.

Do not begin stage 4 (broader platform test expansion) until stage 3 is
complete, except for narrow tests required to prove an extraction batch.
