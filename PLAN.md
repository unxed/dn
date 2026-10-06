# dn: DOS Navigator on Free Pascal and Turbo Vision, translated from magiblot/tvision

Goal: DOS Navigator without Borland code from commercial BP7, built with Free Pascal on
our own TV. This TV is a Pascal translation of the magiblot/tvision C++ library, which
goes back to C++ TV 2.0 published by Borland itself. First DOS with long file names (LFN)
and the system clipboard, then UTF-8 in DN and backends for different OSes, then unxed/go2dos.

**Primary goal (milestones 0–5):** DN on our TV builds with FPC for DOS (go32v2) and works
with LFN and the system clipboard where that DOS supports them. Audit gates in CI are green.

**Nearest product release — DN 3.0:** a stable port to the new stack (FPC + our TV +
classes), with minimal interventions in OSP logic. Further feature work — strictly
after this milestone. Exceptions (Far UX, advanced input/clipboard): see
[`docs/DN-3.0.md`](docs/DN-3.0.md).

How we work: commits go straight to `main`. Builds and checks are in GitHub Actions. Each
milestone is split into small sessions, and each session's result can be tried hands-on.
**Borland sources never go into the repository:** CI downloads the reference by URL,
checks sha256, and unpacks into a temporary directory (`audit/fetch_reference.sh`).
Reports about third-party projects are also not committed to the repository.

## Sources

- magiblot/tvision: https://github.com/magiblot/tvision (as of 2026-10-01 — `b4831e2`).
  License: Borland disclaimer plus MIT (`COPYRIGHT`). Provenance verified:
  `research/2026-10-01-magiblot-provenance.md`.
- Published Borland TV 2.0 release: https://github.com/FSharpCSharp/TurboVision
  (unpacked `tv.zip`); `tv.zip` itself: http://www.sigala.it/sergio/tvision/borland/tv.zip,
  https://web.archive.org/web/20170708213734/http://www.sigala.it/sergio/tvision/borland/tv.zip;
  Sergio Sigala sources page: http://www.sigala.it/sergio/tvision/resources.html#sources.
  The magiblot "Version 2.0" import matches it by code in all 201 files.
- SET 2.0.3 port (GPL, for checking magiblot provenance):
  http://old-dos.ru/dl.php?id=9393, sha256
  `34d27cffff01d0b38b199c035d040bb2b3e88c41935f63d9828dd4db033471ac`.
- **DN OSP 2.14** (Virtual Pascal) — the base for our DN (decision 10):
  https://web.archive.org/web/20220202202636/http://www.dnosp.com/files/dn2/dn2s214.rar
  (sha256 pinned in `dn/upstream.env`; same contents we examined earlier: 210 files, 751658 tokens).
- DN 1.51 from RIT (BP7), fallback and for comparison:
  https://web.archive.org/web/20250406173244/https://download.ritlabs.com/dn/dn151src.zip
- Borland reference for audit (BP 7.0 + 7.01 update), sha256
  `1ba6251209ae4a56a4f6ce5926bff0eca815ea53a3dd5f57f779d52d1e1dc2fc`:
  http://old-dos.ru/dl.php?id=9670
  https://web.archive.org/web/20231211134715if_/http://old-dos.ru/dl.php?id=9670
  Drivers, Menus, and TextView sources are absent from it.

## Licenses

- DN code is under the DN license. It cannot be relicensed (the DN license from the public release);
  and we do not relicense it.
- `tv/` (translation of magiblot/tvision) — under the same license as upstream: Borland disclaimer
  plus MIT. The translation is a derivative work; notices are preserved.
- In one binary: DN (BSD-like), TV (MIT), FPC RTL (LGPL with a static linking exception).
  No conflict: none of the licenses requires relicensing someone else's code. Code must not be
  copied between `dn/` and `tv/`: they have different licenses.
- In `tv/` there are two kinds of files: translated from magiblot (Borland disclaimer + magiblot MIT)
  and written for the port (MIT, `tv/LICENSE`). The kind is stated in each unit's header.
  I chose the MIT license for our additions so the package has one clear license; see
  "Open questions".

## Decisions (2026-10-01)

1. **TV — a translation of magiblot/tvision to FPC, package `tv/`** (confirmed by unxed 2026-10-01).
   We translate only the library: `source/tvision`, `source/platform`, `include/tvision` without
   `compat/`. We do not translate `examples/` (tvdemo, tvhc, etc.): that is not part of the published
   TV release. Free Vision, the original TV from DN, and dn* attempts are not used as a source
   of code. Why: `research/2026-10-01-provenance.md`, `research/2026-10-01-magiblot-provenance.md`.
2. **API — in Pascal TV style,** matching what DN uses: `object` objects, `TView.HandleEvent`,
   `cm*`/`kb*` constants, `New(P, Init)`. The implementation follows magiblot's C++ code. Each
   `tv/` unit header states which magiblot files and which commit it was translated from.
3. **Strings in TV — UTF-8 from day one** (as magiblot is built). DN's single-byte strings
   (on DOS — in OEM encoding) are accepted by TV as follows: invalid UTF-8 is treated as code-page
   characters. Magiblot uses CP437; for us the **code page is a setting**
   (default 866 or the active DOS code page). This way DN works without rework,
   and in milestone 6 it moves to UTF-8.
4. **Backends:**
   - DOS (VRAM/int 10h, int 16h, int 33h, WinOldAp int 2Fh) and an in-memory backend for tests
     we write ourselves;
   - Unix/Windows — translation of magiblot's platform layer (`source/platform`: ANSI, far2l, kitty,
     OSC 52, Win32 console).
5. **Audit gates in CI:**
   - `dn/` is compared to the Borland reference strictly: `raw% ≤ 2` and `maxrun < 48` per file;
   - in `tv/`, matches with Borland's Pascal TV are natural (same author and same architecture),
     so only procedures whose unit header cites a magiblot source are allowed there. Thresholds
     are calibrated on the first files.
6. **Suspicious DN files** (`scroller`, `HELPKERN`, `helpfile`, `DNAPP`, `DNStdDlg`,
   `messages`, `gauge(s)`, `asciitab`, `listmakr`, `COLLECT`, `streams`, `tvhc`, partially
   `FVIEWER`) are replaced with analogues from `tv/` (the magiblot library has help, StdDlg,
   MsgBox, scroller, collections, and streams) or matching procedures are rewritten.
   The ASCII table, gauges, and the help compiler (`tvhc`) are not in the library — we
   write them ourselves. We rewrite from a behavior specification, without code. The session
   that writes code does not see the Borland source.

7. **TV and DN are two independent projects** (2026-10-02, per unxed direction): different licenses,
   each keeps its own units. `tv/` does not know about `dn/` and uses only its own units and
   the RTL; `dn/` uses TV only as a package. Checked by `tools/check-layout.sh`
   (workflow `layout`): allowed `uses` in `tv/`, provenance mark in each unit,
   no mentions of `dn/` in `tv/`, no `tv/` files in `dn/`. The `tv/` directory
   is self-contained (README, LICENSE, its own DESIGN, its own tests) and can be extracted into
   a separate repository with history if desired (`git subtree split`).
8. **DN code comes only from publicly available sources** (2026-10-02, per unxed direction):
   DN releases (OSP 2.14, fallback — RIT 1.51) and our new code. Third-party repositories
   with prior porting attempts are not a source of code, and there are no links to them in this
   repository or its history.
9. **There are no DN sources in the repository — only what is needed to reproduce our tree**
   (2026-10-02, per unxed direction): the public archive URL and sha256 (`dn/upstream.env`),
   the list of excluded files (`dn/exclude.list`: replaced by the new TV or rewritten — their
   Borland-origin code is not stored anywhere), a series of patches on clean files (`dn/patches/`),
   our new files (`dn/new/`), and scripts (`tools/dn-fetch.sh`, `tools/dn-materialize.sh`).
   The DN tree is obtained as follows: download the archive, check sha256, unpack, remove
   excluded files, apply patches, add new files. Patches touch only files that passed the
   audit gates, so their context has no Borland code. The entire history of DN changes
   is the history of patches. There is no `upstream/` directory and no copy of DN in git.
10. **The first version is the original with minimal changes** (2026-10-02, per unxed direction). On top of
   public DN OSP 2.14 code, only the following are allowed: (a) switch to a license-clean new
   TV (`tv/`); (b) UTF-8, if the API exists on the DOS we run on; (c) LFN; (d) system clipboard;
   (e) build with a modern compiler (FPC). Everything else — refactoring, improvements,
   fixing others' bugs — we do not do in the first version, and we record it in a list in the repository
   (`dn/TODO-later.md`). This keeps the maximum of time-tested original code.
   Each patch in the series is marked with a reason (a–e); a patch without a reason is not accepted.

11. **From public archives we take only RIT code and its direct descendants in DN OSP**
   (2026-10-02, per unxed direction). Chunks of Borland and Virtual Pascal code (and third-party code of other
   rights holders) we discard and recreate entirely, unless they are available under
   a clearly compatible license. All "scaffolding" around RIT code and its continuation in OSP
   (adapters, replacements, tests, scripts, build) is ours. This is version 1.0; later we may rewrite
   the RIT code too and modernize it, but for now — this way (the rest the project owner is still considering).
   Consequences: (1) the exclusion list is not only "above the audit threshold" (Borland code), but everything that is not
   RIT/OSP: `tools/dn-provenance.py` classifies tree files by copyright notice
   (RIT/OSP, Borland, VP, third-party author, no notice) — the result is reviewed manually; (2) our own
   replacements go "with the same name and API" into `dn/new` (`vpsyslow`, `defines`, `views`...); (3) OSP files
   marked by project participants (Cat, JO, AK155 — "Contribution to DN/2 OSP project") we treat as
   DN OSP descendants; files with a third-party notice (regexp — P. Ziemian, eaoper — A. Trunov) —
   we exclude.

## Repository layout

| Directory | What | License |
|---|---|---|
| `tv/` | translation of magiblot/tvision, our backends, demos, tests | Borland disclaimer + MIT (translated), MIT (ours) |
| `dn/` | DN: public archive URL and sha256, exclusion list, patches, our new files (DN sources themselves are not stored); DN license | DN |
| `spec/` | behavior specifications for rewritten DN places | — |
| `tests/` | DN tests (TV tests live in `tv/tests`) | — |
| `audit/` | detector, reference download, DN reports; `audit/ref/` is not committed | — |
| `tools/` | toolchain build, DOSBox-X runs, layout check | — |
| `research/` | research | — |

---

## Milestone 0. Detector and measurements — done (2026-10-01)

`audit/xclone.py`, `audit/runs.py`, `audit/fetch_reference.sh`, reports for DN 1.51 and DN OSP.

## Milestone 1. Toolchain and CI — done (2026-10-01)

Done: FPC → go32v2 cross-compiler, `hello` runs in DOSBox-X without a screen
(`research/2026-10-01-toolchain.md`, workflow `toolchain`). Also done: workflow `audit` (Borland reference is fetched in CI,
detector self-test). DPMI host for distribution: CWSDPMI r7 (GPL or without sources if
conditions are met, see `research/2026-10-01-toolchain.md`). Audit gates for `dn/` and
`tv/` will be enabled when there is code there. A screenshot of the
DOSBox-X screen will be made with the TV demo in milestone 2.

- `toolchain.yml` (done): FPC 3.2.2 from sources, cross-compilation for i386-go32v2
  with DJGPP binutils.
- Outside Windows, go32v2 needs a DPMI host: CWSDPMI or HDPMI32. Choose after checking licenses
  for redistribution.
- `hello.pas` for go32v2 in DOSBox-X without a screen, screenshot as an artifact. FreeDOS in QEMU —
  same workflow or later.
- `audit.yml`: `fetch_reference.sh` (`unrar` from apt); `dn.yml`: DN tree from the public archive, audit report and gates.

Done when: both workflows are green, the hello screenshot from DOSBox-X is in the artifacts.

## Milestone 2. TV pilot (2–4 sessions)

We translate a minimal slice of magiblot: geometry and collections, screen cell and `TDrawBuffer`
(UTF-8, width, code page), `TView`, `TGroup`, `TFrame`, `TWindow`, `TMenuBar`,
`TStatusLine`, `TProgram`/`TApplication`, event queue. Backends: in-memory (tests) and DOS.

Before translating, we check on a short example how FPC coexists with `{$H+}` units
(TV) and `{$H-}`/`{$mode tp}` (DN) and with `object` inheritance from a foreign unit.

Done when: tests on the in-memory backend are green (screen dump), and the demo — menu and window —
works in DOSBox-X (screenshot). **This is the first thing that can be tried hands-on.**

## Milestone 3. TV for DN's needs (N sessions)

- `spec/api-usage.md` is generated by a script: which TV objects, methods, and fields both
  DN bases use. This is the translation scope boundary.
- We translate the rest that is needed: dialogs, input line, lists, scroller, message boxes,
  file dialogs, history, validators, help (`helpbase`, `tvhc`), color selection,
  streams and resources to the extent DN needs.
- For each portion — tests and a demo.

### Milestone 3 status (2026-10-02)

Done and green (native + DOS in `tv.yml`; unit table and decisions — `tv/DESIGN.md`):
core and view (`TvViews`, `TvWindow`, `TvApp`, `TvMenus`), dialogs (`TvDialog`, `TvMsgBox`),
`TvInput`, `TvValid`, `TvCluster` (checkboxes, radio buttons), `TvList` (`TListViewer`,
`TListBox`), `TvHist` (history), `TvFiles` (LFN search, paths, collections),
`TvFileDlg` (`TFileDialog`, `TSortedListBox`, etc.), `TvChDir` (`TChDirDialog`),
`TvColorSel` (`TColorDialog` and selectors), `TvTextView` (`TTerminal`),
backends `TvMem`, `TvDos`.

Help is done (`tv/src/tvhelp.pas` — translation of magiblot `helpbase/help`; `tv/tools/tvhc.pas` — our `.htx`→`.hlp` compiler;
in DN `HelpKern/HelpFile` — names only). Remaining in milestone 3: streams and resources for views (widget `Load`/`Store`),
`TProgram` odds and ends from `spec/api-usage.md` results. DN API adapters — in `dn/new`.

How to write tests (to avoid repeating mistakes):
- test name ≤ 8 characters (`t_clust`, not `t_cluster`): DOS builds `NAME.EXE`;
- comparisons with a buffer and `AnsiString` in the main block keep temporary strings until the end of
  the program — move them into a function, otherwise the "no memory leak" check false-fires;
- on DOS, file names come in upper case; without LFN — only 8.3; paths in the change-directory dialog
  have no drive letter; for file tests — `Quiet`/`HeapBase`/`HeapMark`
  from `tv/tests/testlib.inc` (heap warmup and marks, printed on failure);
- every failed `FindFirst` must be closed with `FindClose` (go32v2 RTL keeps an LFN record);
- the CI DOS step runs all tests and prints a compact `--- t_xxx` report; locally DOS
  does not run (CWSDPMI is not downloaded through the proxy), only cross-compilation.

### DN API coverage (2026-10-02)

`tools/api-coverage.py` compares names that clean DN code takes from replaceable units
(`spec/dn-boundary-dnosp214.md`) with identifiers in `tv/src`; the report is
`spec/api-coverage-2026-10-02.txt`. Roughly: 62% of names and **84% of usages** are already in `tv/`.
What is missing is an adapter queue in `dn/new`: DN extensions (`GetPeerViewPtr`,
`PutPeerViewPtr`, `GetSubViewPtr`, `PutSubViewPtr`, `RegisterToBackground`, `PVideoBuf`,
`ReadStrV`, `GlobalMessage`, `ExecResource`, `LoadResource`, `PString`/`PLongString`...),
not work on `tv/` itself. A name match is not a guarantee of the same behavior: that is checked
by the build (milestone 4).

## Milestone 4. DN on our TV (N sessions)

- Base: DN OSP 2.14 (decision 10). The tree is reproduced by scripts (decision 9):
  `tools/dn-fetch.sh` (download and sha256), `tools/dn-materialize.sh` (exclusions, patches,
  new files), workflow `dn.yml` (same in CI, tree audit, build).
- What needs fixing for FPC we discover from compiler errors and record in
  `research/dn-port-lessons.md`; each fix is a patch with reason "e".
- DN extensions that lived in its TV units we port on top of `tv/`: descendants, hooks.
  DN procedures without Borland matches we port as-is; those with matches we rewrite.
- **DN OSP is a Virtual Pascal project** (details and probe numbers — `research/dn-port-lessons.md`):
  everything tied to VP (`vputils`, `vpsyslow`, `files`, `dpmi32df`, `lfnvp`, `-A` substitutions, `OS2`/`WIN32`/`DPMI32`
  branches) we adapt for FPC with our own units in `dn/new` (API from DN call sites,
  without copying vpascal.com code) and "e" patches. This is the main work of milestone 4 until the first build.
- Suspicious DN files — per decision 6. First DN builds and runs under Linux
  on the in-memory and terminal backends, then go32v2.

Done when: `dn/` builds without files that failed the gates, `audit.yml` is green for `dn/`.

## Milestone 5a (early). Running under DOSBox-X with a single-byte encoding per host locale

Project owner decision (2026-10-02): before honest UTF-8 on DOS (milestone 5, go2dos) we ship
a version that works under DOSBox-X and converts text to the single-byte encoding that DOS
chose from the host locale (DOSBox-X sets the page from the `country`/layout setting).

- `TvDos` takes the active DOS page (`INT 21h AX=6601h`) and picks a `TvCodePg` table;
  known OEM pages 437 737 775 850 852 855 857 858 860 861 862 863 864 865 866 869
  (`tools/gen-codepage.py`); unknown — 437.
- All text inside is UTF-8; into video memory, from the keyboard, from the clipboard (CF_OEMTEXT), and
  from file names it is converted at the DOS boundary via this table. A character not present in
  the page is shown as `?` (on screen output — as it is in the page).
- Showcase for DOSBox-X: `tools/showcase-dosbox.sh` builds `tv/demo/tvdemo.pas` and runs
  it; CI does the same run (artifact `dos-demo`).
- Done when: the demo and (later) DN under DOSBox-X show text on pages 437/866/850/852,
  and CI has a check for at least two pages.

## Milestone 5. DOS: LFN and clipboard — **primary goal**

- LFN — go32v2 RTL `LFNSupport` (int 21h, 71xxh); without it, 8.3.
- Clipboard: WinOldAp; in DN 1.51 it already exists (`WINCLP.PAS`, no Borland code in it).
  Whether it exists is determined by call 1700h; if not, the internal buffer is used.
- go2dos host extensions (spec — `docs/DOS-EXTENSIONS.md` in unxed/go2dos, discovered
  via AMIS, `INT 2Dh`, by scanning AH=00h..FFh with AL=00h): `DOS-UTF8/NAMES` (AL=10h, BX=65001 —
  `71xx` file names in UTF-8 for the calling process, without OEM conversion; short
  names ASCII only; when launching children, pass the short name), `DOS-HOST/TEXTWIN`
  (AL=10h window size, AL=11h BL=1 — resize event: word FF00h in the keyboard
  buffer), `DOS-HOST/HOSTEXEC` (run host commands, disabled by default).
  Where there is no provider (DOSBox-X, FreeDOS), we work as before: OEM code page.
  Screen and keyboard in these extensions remain OEM (honest screen UTF-8 is not yet in the
  go2dos spec) — we do not invent; we check the spec before implementing.
- Test matrix: DOSBox-X (CI), FreeDOS + DOSLFN (QEMU), Windows XP DOS window via
  `vmlab` from `unxed/sandbox`, go2dos (when there is 386 + DPMI). There we also check
  whether NTVDM supports WinOldAp.

Done when: DN opens a directory with long names and copies such a file, and the clipboard
works where DOS supports it. We ship an alpha.

## Milestone 6. UTF-8 in DN and backends for other OSes

- `utf8` mode for panels, input line, editor, and viewer (binary viewer mode
  is preserved). File names are converted at the FS boundary.
- On DOS, honest UTF-8 without conversion to single-byte encodings requires the go2dos host API
  (milestone 5: `DOS-UTF8/NAMES`, `DOS-HOST/TEXTWIN`). When we do ports for other OSes, this
  platform layer is replaced with native OS calls (Win32 Unicode API, POSIX with UTF-8).
- Translation of magiblot's platform layer: terminal (far2l, kitty, OSC 52), Win32 console.
- CI build targets: linux (x86_64, aarch64), FreeBSD, macOS, win32/win64, go32v2.

## Milestone 7. unxed/go2dos and showcase

go2dos does not yet have 386 and DPMI (8086/80186 kernel, real mode; `docs/DESIGN.md` there calls
protected mode and DPMI a separate large stage). Until they appear, we test the DOS version in
FreeDOS and DOSBox-X. When go2dos gets 32-bit DPMI, we wire up its DOS extensions.
A fast search found no pure-Go x86 emulator with 386 protected mode (2026-10-01).

**Showcase** (project owner requirement): when the DOS version is ready, there must be a way to actually
run it under go2dos: script `tools/showcase-go2dos.sh` builds go2dos and our
go32v2 build (demo `tv/demo`, then DN), places a DPMI host next to it, and runs it; the same run —
as a separate CI job, like go2dos `e2e-vc`. While go2dos has no 386, the script does the same
in DOSBox-X; we prepare the shared scaffold in advance.

---

## Open questions

- ~~**DN files excluded by audit (38).**~~ Resolved (2026-10-02, "Continue"): two classes. A file stays if
  `raw% <= 10` (since 2026-10-02; was 6) and there is no matched run >= 48 tokens; matched runs are replaced with our text via `dn/rewrite/*.rw` edits
  (`tools/dn-rewrite.py`: anchor lines + sha1 of the replaced text; the replaced text itself does not go into git). The rest (29 files:
  `scroller`, `DNAPP`, `DNStdDlg`, `helpfile`, `HELPKERN`, `listmakr`, `asciitab`, `edwin`, `strview`, `memory`...) —
  shims onto tv/ or our code in `dn/new`. Returned: `FVIEWER`, `calendar` (with edits), `advance6`, `usersavr`, `TopView_`,
  `version`, `colorvga`, `filetype`. Tree audit after edits (`tools/dn-materialize.sh` + `audit/xclone.py`) must not
  show files over the gate (CI step "Files over the gate").

- License for our additions in `tv/` (`TvSys`, `TvMem`, `TvDos`, part of `TvMouse`, and tests):
  I set MIT with "the authors of the dn project" (`tv/LICENSE`). Confirm or
  name another copyright holder.
- Which release to take as the base: currently DN OSP 2.14 (decision 10); we will compare with DN 1.51 after the
  first `dn.yml` run (file count, Borland code share, presence of LFN and clipboard).
- Whether to extract `tv/` into a separate repository now or after milestone 4.

Closed: Q1 (reference — at the URL above), Q2 (go2xp → go2dos), Q3 (we do not use FV),
Q8 (TV base — magiblot translation, confirmed), Q9 (magiblot import verified against
the published release via the FSharpCSharp mirror; verification against `tv.zip` itself can
be repeated in CI),
Q4 (DN license for DN), Q5 (trial build of both bases, milestone 4), Q6 (FreeDOS/DOSBox-X,
go2dos later), Q7 (commits to `main`).

## Doubts and risks

- Borland published C++ TV without an explicit license; this is the strongest available option,
  but not an open license. No borrowings from the GPL SET port were found in the magiblot library
  (`research/2026-10-01-magiblot-provenance.md`).
- Unknown how well C++ (templates, overloading, multiple
  inheritance of `TStreamable`) maps onto FPC `object`. We check with the milestone 2 pilot.
- The go32v2 cross-toolchain on the CI runner is unverified (milestone 1).
- Downloading the reference from web.archive is unverified: it is unavailable from the session. Unpack and
  sample selection were checked on a local copy (72 files).
- The archive is solid RAR3; `unar` and `7z` do not unpack it; `unrar` is required.
- The detector threshold was taken from the background of clean code; it needs calibration.
- In `unxed/go2dos` there is a `dn/` folder (`audit`, `detectors`, `specs`); I have not looked at it.


## Note: target directories in the DN OSP archive (2026-10-02)

In `dn2s214.rar`, system-dependent units live in target directories: `LIB.D32` (DOS, DPMI32 — our target), `LIB.OLF` (OS/2),
`LIB.WLF` (Win32); `EXE.D32`, `EXE.OLF`, `EXE.WLF` — ready program directories. When building a fork for other OSes: `DN_LIB_DIR` in
`dn/target.env` (`tools/dn-materialize.sh` places target units at the tree root and discards other `LIB.*`), our own layer instead of
`VPSYSxxx` (`dn/new`), and corresponding edits (`DN_DEFINES`).


## Status as of 2026-10-02 (night) and estimate of the path to DOSBox-X

- Builds (go32v2 cross-compiler, `DN_CROSS=... tools/dn-try.sh dn.pas`): **128 of 131** units reachable from `dn.pas`; not
  building: `dn1` (in progress), `colorvga`, and `dn.pas` itself. All `tv/` units and all `tv/` and `dn/tests` tests pass.
- "Builds" does not mean "works": stubs — screen savers, `GetFileNameMenu`, DN palettes,
  `wfMaxi/cmMaxi`, `TaggedDataOnly`, `OpenResource/ExecResource/LoadResource`.
- Estimate of the path to "DN runs in DOSBox-X, shows panels, menu and main dialogs work" — **about 40%** (spread ±15):
  `tv/` core ~100% (15% weight); DN layer compilation ~95% (25%); go32v2 linking (size, external symbols, inline asm) 0%
  (15%); resources — `rcp`, `DN.RES` from `RESOURCE/*/dn.dnr`, loading dialogs and menus via streams (~165 classes) ~5% (25%);
  run and behavior (keys, video, LFN, palettes, panels) 0% (20%). The riskiest stretch is resources and run.
- Next steps: `dn1`, `colorvga`, `dn.pas`; linking; build `rcp` natively and get `DN.RES`; `LoadResource`; first run in
  DOSBox-X (CI); then down the stub list.

## Architecture: layers, duplication, API compatibility (proposed 2026-10-02, not done)

Goals: (a) not keep two variants of the same thing in `tv/` and in DN; (b) `tv/` is suitable for porting other old
Pascal software (Borland TV 2.0 API, preferably also compatible with FPC Free Vision); (c) `tv/` stays close to magiblot's API and
code so new fixes from there transfer easily. What is reasonable for that:

1. **Three layers instead of two.** `tv/` — core: magiblot semantics + Pascal names, only what everyone needs. New `tvcompat/` —
   Borland/VP compatibility layer (what `tools/gen-shim.py` + `dn/new/manual/*.inc` do now: units `Views`, `Dialogs`,
   `Menus`, `App`, `Drivers`, `MsgBox`, `StdDlg`, `Objects`, `Memory`, `Validate`, `HistList`, `ColorSel`; 16-bit cells
   `TDrawBuffer`, `kb*` keys as LongInt, `PPalette`/`GetPalette^`, `PString` headers, `Word` 16/32-bit profiles). This is a separate
   MIT product that does not know about DN, with tests and a criterion: a BP7/Free Vision program compiles without edits. `dn/` — only
   what belongs to DN (RIT code from the archive, scripts, edits, cut-out classes).
2. **DN extensions that currently sit in the `tv/` core** (`TDialog.DirectLink`, `TScrollBar.Step/ForceScroll`, `TInputLine.LC/RC/C`,
   `TView.MenuEnabled`, `TDosStream.Position/StreamSize`, `ModalCount`, hooks, etc.) classify by kind: a common hook useful to all
   (stays in the core, with a comment and an entry in `tv/DESIGN.md`); Borland compatibility (moves to `tvcompat`, where it is
   a subclass or adapter); DN-only (into `dn/`). Subclasses work while the stream registry and factories (`InitFrame`,
   `StandardScrollBar`, resource loader) create the needed type; where a subclass does not fit, a core hook remains.
3. **Subsystem duplicates** — resolve one by one, starting with menus: DN has its own `menus.pas` (RIT) next to `TvMenus`; the program will have two
   menu systems. More sensible: implement DN features (`Flags`, `Param`, executable submenu item, default item) in `TvMenus`
   in our own text and remove `menus.pas` from the tree. Similar for DN `TInputLine` (`Data` as a string field, `MaxLen` LongInt, `ofSecurity`),
   collections (`Collect.inc` duplicates `tvobjs`), and streams. License: DN (RIT) code cannot be relicensed and must not be moved
   into MIT-`tv/`; useful behavior we generalize in our own text (reading the original is allowed, copying is not); DN classes
   nobody but DN needs (`TComboBox`, `THexLine`, `TNotepad`...) stay as cut-outs in `dn/`.
4. **Sync with magiblot.** A "C++ file → Pascal unit" table (already in unit headers) + `tools/tv-upstream-diff.py`:
   for new magiblot commits shows which units are affected; + `tv/UPSTREAM-DELTA.md` — a list of deliberate departures from
   the original (already scattered across `DESIGN.md`; gather in one place, each with a test).
5. **Compatibility acceptance:** locally (without publishing third-party code) build Borland TVDEMO and Free Vision examples via `tvcompat`;
   in CI — our own API-compatibility tests (against BP7 TV 2.0 documentation).

Order: items 4 and 2 are cheap and useful immediately (after DN's first run); item 1 — when DN first runs (so we do not
restructure on the fly); item 3 — one duplicate at a time, menus first. None of this blocks milestones 4–5.

## Operating rules (2026-10-02)

- `README.md`, section "How to try what is already ready", is updated in the same commit that changes how to check or
  what can be seen (scripts, commands, status: what works, what fails).

## Step-by-step refactoring (owner decision, 2026-10-03)

The original tree was a mess — the important thing was just to get it running. Now there is a working product others can join, and it needs to be made clearer
(file names, how code is laid out across files, entity names). A full refactor is too large a task, and we do not want to stall on it. Rule: **after each
major development step (like UTF-8, embedded terminal) we do one refactoring step — the most urgent in that direction**, as a separate commit, without behavior change
(same tests, green before and after). Candidates are collected in `dn/TODO-refactoring.md` (with marks of what is done); new findings are appended along the way, but we do not
get distracted by them outside the next scheduled step.

Steps:
- after UTF-8 (2026-10-03): build outputs not in source directories (`.o`/`.ppu` in `tv/src`, `dn/src`, and `tv/tests` were landing in the manifest and cluttering the eye) — tv and dn tests build into
  a separate directory (`tools/tv-test.sh`, like `tools/dn-test.sh`).
- after the embedded terminal (2026-10-03): a "file → what is in it" map for newcomers, `dn/FILES.md` (renames — decide separately, see `dn/TODO-refactoring.md`).

## Object API refactoring as part of the current migration (owner decision, 2026-10-04)

The name `PObject` was a temporary compatibility layer: in `tv3` it meant a reference to a
class instance, not a pointer to an old Pascal `object`. To avoid accumulating
technical debt, this layer is removed now, within the same migration.

In `tv3` the stream API uses `TObject` directly (`TStream.Get`, `TStream.Put`,
`TLoadProc`, `TStoreProc`), and dependent DN declarations and call sites are moved to the same
type. This is not a separate project and not free cosmetics: the work is in the current scope,
done as atomic commits, and verified with full `tv3` and DN test suites before
opening a PR.

## Plan tail: comments and documentation into English (added 2026-10-02)

Translate **all comments in all sources and all md files** (including but not limited to `tv/`, `dn/new`,
headers of our scripts; and for the reproducible DN tree —
comments in edits `dn/edits`, `dn/rewrite`, `dn/patches`) into English. Reason: the project builds for both DOS and other
OSes, and Russian comments in DOS encoding (cp866) and UTF-8 cannot be kept together. Done at the very end, when the code has settled
(so as not to interfere with upstream merges and not to inflate diffs), in separate commits per directory; translating comments does not change
code (check: unit binary image without debug info does not change). DN itself from the archive (`build/dn`) is not stored in git;
its Russian comments (cp866) stay in the tree as-is until there is a decision about them (open question: whether to translate them
programmatically at materialization).

**Done (2026-10-03):** `README.md` and `tv/README.md` translated into English (the link to the "Working rules" section in `dn/README.md` still uses its
Russian heading until that is translated). Remaining: `PLAN.md`, `bootstrap/README.md`, `dn/TODO-later.md` (part), `dn/README.md`, comments in sources.

**Added to the plan (2026-10-03, owner): full English translation of all content in `tv` and `sp`** (same work, same rules: at the end, separate commits per directory, code unchanged):
- **`unxed/tv`:** `DESIGN.md` (405 lines; `README.md` already translated), comments in all `.pas`/`.inc`/scripts: `src/`, `tests/`, `demo/`, `dostests/`, `tools/`, and also test message texts.
  Check: unit binary images without debug info do not change; all `tv/tests` and `dostests` tests give the same result.
- **`unxed/sp`:** `SPEC.md` (648 lines), `README.md`, `DN-ADOPTION.md`, `fpc-utf8/README.md`, comments in `safe.pas`, `safethreads.pas`, `tests/*.pas`, `tests/run.sh`, `.github/workflows/ci.yml`.
  For `SPEC.md` this is also a user-facing cost: the specification is attached to prompts, and English text is more reliable for models and readable outside the Russian-speaking circle; translate the rules card (§0) first.
  Check: `tests/run.sh` and CI green; `safe.pas`/`safethreads.pas` build to the same binaries without debug info (comments do not affect code); `SAFE-S*`/`SAFE-R*` identifier names and message texts are already English and do not change.
  Order: `SPEC.md` §0 and §2 → `README.md` → rest of `SPEC.md` → code comments → `DN-ADOPTION.md`.

## Safe Pascal as DN's coding style (proposed by owner 2026-10-03)

The concept and plan for converting DN (stages S0–S10 per RUP, measuring violations, ideas from Zig, doubts) moved to a separate repository
**[unxed/sp](https://github.com/unxed/sp)**: `SPEC.md` (specification), `safe.pas` (library, MIT), `DN-ADOPTION.md` (this plan). Step status is tracked there.
Briefly: owner decision (2026-10-03) — convert DN to this style as a final refactoring step or earlier; order "(c) safe new code next to old → (a) extend to `object` → (b) `class` as fallback";
first S1 (`tools/safe-census.py` in this repository, S1–S4, S9 violation counter over `dn/src` and `tv/src`), S2 (`safe.pas` in `dn/third_party/` with an entry in `dn/PROVENANCE.md`).
Measurement as of 2026-10-03: `object` 230/75 vs `class` 1/0 (dn/tv); `New(` 843/103, `Dispose(` 421/39, `GetMem` 45/25.

## Where we stopped (end of session 2026-10-03) and where to continue

**State:** everything committed and pushed. `dn` (`main`): CI green on latest commits; `dist/` for all six targets rebuilt with the desktop load fix (`8f4f379`, `6361988`).
DOSBox-X (fork `unxed/dosbox-x`): branches `claude/amis-utf8-clipboard`, `claude/utf8-names` (PR #6632, CI waiting for maintainer approval to run), `claude/fix-extdevice-loop` (hang fix for
`DOS_CheckExtDevice`; PR #6634 opened by owner). [`unxed/sp`](https://github.com/unxed/sp) (v0.5, MIT; formerly `safe-pascal/` in `unxed/sandbox`, PR #4): another chat also works on it; pull `main` before editing.

**What was done in the session (briefly):** aarch64; UTF-8 names and clipboard for go2dos and DOSBox-X (AMIS); DN-DOS under DOSBox-X `master` (hang was in the emulator); `TGroup.GetSubViewPtr` fix (desktop load);
English for `README.md` and `tv/README.md`; Safe Pascal: S0–S10 order above, MIT license, v0.5 specification and goals table.

**What to do next, in order:**
Order clarified by owner 2026-10-03 (evening):
1. **Owner:** cycle-fix PR opened (joncampbell123/dosbox-x#6634); for #6632 CI awaits maintainer approval; add a caveat to #6632 description "Windows part not tested" (text in `docs/patches/dosbox-x-pr-utf8-names.md`).
2. **Now: remaining DOS work** — **user screen after an external program** and **mouse**; then the "save desktop on exit" option (Options -> Startup) and "Save setup". Desktop save and load already verified and fixed.
3. **Extended terminal protocols** (item 9 of the list above): raised above Safe Pascal — done faster and checked by hand immediately (OSC 52, kitty keyboard, win32 input mode, bracketed paste, far2l extensions).
!!! This item covers both DN interaction with an external terminal, and interaction of an application launched in its embedded terminal with that terminal.
4. **DN for DOS with `utf8 file names`:** copy, view, rename, delete such files in DN. Display is already as the owner wants: characters present in the DOS code page are shown as-is; only the rest become `{U+XXXX}`
   (verified with CP437, which has no Cyrillic; check with CP866: "dom" should be visible as letters, and `世界` — as `{U+4E16}{U+754C}`).
5. **Safe Pascal for DN:** steps S1–S10 (section above), starting with `tools/safe-census.py`.
6. **UTF-8 on DOS via our DOS and `COMMAND.COM`** (needed, not urgent): go2dos and our `COMMAND.COM` use the UTF-8 API (`DOS-UTF8/NAMES`, `CLIPBRD`); DN for DOS — too (currently the DN DOS build stays on the code page);
   on DOS without a provider — name conversion at the boundary.
7. **Plan tail:** English for `PLAN.md`, `bootstrap/README.md`, `dn/README.md`, part of `dn/TODO-later.md`; then comments in sources; full translation of `unxed/tv` and `unxed/sp` (see "Plan tail" above).

**History of `unxed/dn`, `unxed/sp`, and `unxed/tv` was rewritten (2026-10-03, owner).** `dn` and `sp`: Ivan Sorokin co-author added to all Claude commits (hashes changed, contents and dates the same; branch `utf8-inside` rewritten together with `main`);
`tv`: instead of a single "Initial upload" dump, the history of the `tv/` directory from `dn` was restored (95 commits up to `dn` b8f2bd1 + a clarifying commit), file contents the same.
Old state preserved in branches `backup/before-history-rewrite-2026-10-03` of all three repositories (the owner deletes them when all clones are resynced: deleting branches from Claude sessions is unavailable). **If you have an old clone of `dn`, `sp`, or `tv`: do not `git pull`/merge
(old and new history will glue together with duplicates); instead `git fetch origin && git reset --hard origin/main`** (save unpushed work separately first).
New commits in these repositories should be signed the same way: `Co-Authored-By: Claude ...` and `Co-Authored-By: Ivan Sorokin <ivan.sorokin.tech@gmail.com>`.

**How to continue on a new machine:** cross-compilers are built by `tools/build-fpc-*.sh` scripts (prefixes needed by variables `DN_PREFIX`, `DN_LINUX`, `DN_AARCH64`, `DN_WIN`, `DN_WIN32`; see `tools/README.md` and `tools/dn-env.sh`); DOSBox-X for CI comes from apt
(2024.03.01: DN-DOS works on it; on fresh `master` the guard from `claude/fix-extdevice-loop` is needed). All temporary directories from this session (`/tmp`, scratchpad) are ephemeral; nothing needed remains in them.

## Linux showcase: dn2l analysis and plan (2026-10-02)

**Source facts** (analysis of `unxed/dn2l`, working copy; we do not keep it):
- DN OSP for Linux was already built (dn2l: Virtual Pascal with Linux target `vpsyslnx`, then `pe2elf`). So the DN core
  does not depend on DOS/OS/2: of 179 shared `.pas/.inc` files dn2l changed 104, but in total about 1100 changed lines
  (excluding `uucode.pas` and the `collect`→`objects` rename). Edits by kind: `\`→`/` in paths, video stubs
  (`SetBlink`, VGA palette, `VGASystem`), disabled Windows clipboard, unit renames (`DnIni_p`→`DnInip`,
  `Collect`→`Objects`, `U_KeyMap`→`UKeyMap`), `inline` on standalone functions, empty-name checks, trivia.
- **What we may take from dn2l:** only code written by unxed (`linux/init.sh`, `dn_.sh` scripts, CP866→UTF-8 table
  if needed; we already have the tables themselves in `TvCodePg`), and a *map of places* where Linux breaks something.
  **Must not:** edits to existing RIT/OSP code (gray zone), VP RTL files and patches to them (`vpsyslnx.patch`, `sysutils.patch`),
  third-party new files (`arch*.pas` and others not from the 2.14 archive: provenance unclear). All Linux edits to the DN tree we write ourselves,
  in our `dn/edits` mechanism (separate target subdirectory/suffix) and `LIB.LINUX` (`DN_LIB_DIR`), as for DOS.
- TV (`tv/`) backends: memory and DOS; there is no terminal (Unix) backend (`DESIGN.md`: "`source/platform` for Unix and Win32 —
  milestone 6"). This is the main missing piece for Linux.

**Owner decision (2026-10-02): first target — 386 (i386-linux), not x86_64.** DN was written for 32-bit VP: pointers in data records, `LongInt(P)`,
`Integer` = 32 bits, dialog record sizes (`TSysData`), streams with pointers. Under x86_64 this must be fixed across the whole
tree; under i386-linux almost nothing. FPC builds i386-linux statically (without libc); a 32-bit ELF runs on 64-bit
Linux. We make the cross-compiler the same way as for go32v2 (`tools/build-fpc-go32v2.sh` → shared script). x86_64/aarch64 —
after the showcase, as a separate task (search for 32-bit assumptions: we already have `tools/ifdef-strip.py`, `dn-probe.sh`).

**Iterations** (each yields something runnable; estimates in sessions; the first is the most reliable):
1. *TV on a Linux terminal* (1–2) — **done 2026-10-02** (`TvTermIO`, `TvAnsi`, `TvUnix`, tests `t_termio`, `t_ansi`, pty test `tv/tests/pty`, demo `tvdemo` on Linux; no ncurses: we parse simple keys ourselves; not done: OSC 52, Ctrl+Z, far2l, GPM). **Owner decision (2026-10-02): we do not invent the terminal backend; we translate it from
   magiblot/tvision** (`source/platform`: unix/linux console, input parsing, mouse, cell output, far2l/kitty, OSC 52), like the
   rest of TV, with the same rules (unit header names magiblot files, MIT + Borland disclaimer, `tv/COPYRIGHT.magiblot`).
   Add correspondence rows to `tv/DESIGN.md`; tests via pty (`script`/`python pty`: fed bytes, compared screen),
   `tv/demo` in CI with a text "screenshot". Without DN.
2. *DN builds for i386-linux* (2–3). `dn-probe.sh` already counts how many units native FPC takes: we follow errors,
   write `LIB.LINUX` (our `vpsyslow`, `lfn`, `dpmi32` stubs, `dnexec` without DN.COM loader, `killer`, `fnotify`),
   path edits: `\`→`/` in path literals (place list from our own tree search, not from dn2l), drive letters —
   one "drive" `/`. Result: `dn` links.
3. *Run and panels* (1–2). Start: config directories (`~/.dn`), `.DLG/.LNG` resources (rcp under Linux builds with the same
   `dn-run.sh`, only without DOSBox-X), two panels on `/` or `$HOME`, menu, status line. English language first (ASCII).
   Result — a screenshot in the README, as for DOS.
4. *Working file manager* (3+). Walking directories, F-keys, viewer and editor, copy; Unix permissions and
   links (`Attr` in `TFileRec`); UTF-8 file names at the FS boundary; Russian (cp866 in resources → UTF-8 on load).
5. *Showcase in CI*: a job that builds, runs `dn` in `tmux`/pty, sends a key set, and saves a text
   screenshot as an artifact; `tools/dn-run.sh` gets a `linux` mode.

**Shared with DOS** (do once so we do not diverge): `dn/new` layer (`vpsyslow` on top of `TvSys`, `dnapp`, `drivers`,
`messages`), compatibility edits (argument evaluation order, record packing, `ListBoxOwnsList`, `TProgram.Draw`).
What is DOS-specific: `TvDos`, `dpmi32`, `intr_realmode`, LFN. Boundary decision — by `{$IFDEF GO32V2}` inside `dn/new`
or separate files in `LIB.*`; we prefer separate files.

**Risks/questions:** (1) path and drives: how deeply DN is tied to drive letters (`Drives`, `DiskInfo`, `SelectDrive`);
(2) copy/archivers launch external programs via `dnexec`: disable for now; (3) `x86_64`: measurable
volume of 32-bit assumptions (after the showcase); (4) terminals: which key combinations get through (Ctrl/Alt/F-keys) —
a question for `TvUnix`; rely on the kitty keyboard protocol as an optional mode.

Priorities: bring the DOS version to "can walk the panels" first (in progress); Linux iteration 1 can run in parallel because
it does not depend on DN.

**Embedded command line / user screen (owner decision, 2026-10-02):** rewrite into Pascal
[magiblot/tvterm](https://github.com/magiblot/tvterm) (terminal emulator as a Turbo Vision view on top of pty) and use
it instead of DN's embedded command line and "user screen" (Ctrl+O) on Unix. Before starting, check: tvterm license and
dependencies (which VT sequence parsing library and how it is licensed; if a C library — decide:
rewrite it too or take a ready one via FFI), the set of TV API that tvterm uses (must match our `tv/`),
how the shell is launched (pty: `forkpty` via `BaseUnix`). New unit — in `tv/` (`TvTerm`, MIT, translation with tvterm file names
in the header); wiring into DN — via `dn/new` (replace `CmdLine`/`ShowUserScreen` for the Linux target). Not before iteration 4.
For DOS the command line stays native (DN launches programs and shows the user screen via DOS).



> **Layout since 2026-10-02 (owner decision):** DN sources live in git (`dn/src`); further work is ordinary commits and PRs.
> Everything related to obtaining the tree from the public archive (URL and sha256, exclusions, rewritten places, edits, our
> files, tools) is in `bootstrap/` (record and how to reproduce: `bootstrap/README.md`; `bootstrap/BASELINE` — the commit with the tree
> of the first commit; CI compares `bootstrap/run.sh` output to it). Build with one command: `tools/build.sh linux64|linux|dos`.
> File provenance: `dn/PROVENANCE.md`; licenses: `LICENSE`, `dn/LICENSE.md`. Older descriptions (decisions 9–10, `dn-materialize.sh`,
> `dn/new`, `dn/target.env`, etc.) above and in `research/` are history: read them as "how it was before the move".
> Open question for the owner: DN OSP participant files (Cat, JO, AK155) without their own license in the header, that entered the same
> public release (`dn/PROVENANCE.md`, Contributors and Upstream without a notice classes); 19 files not needed by builds were removed from the tree.

## Nearest tasks in order (2026-10-02, order clarified by owner)

What already exists: DN under DOS (go32v2, DOSBox-X) and under i386-linux in a terminal (panels, menu, dialogs, help; tour `tools/dn-linux-tour.py`).

1. **Linux i386 to "can walk"** (Linux plan iterations 3–4): complete the tour without crashes, exit via Alt-X, F3/F4/F5–F8 on real
   Linux files, permissions and links in panels, UTF-8 names at the filesystem boundary, `ESC` delay and keys in different terminals.
   Screenshot and build in `dist/linux/`.
2. **CI for Linux:** a job that builds the cross-compiler (`tools/build-fpc-i386-linux.sh`, cache), `dn`, and runs the tour in pty.
2a. **Walk through basic functions before x86_64** (owner requirement 2026-10-02: manual check showed copy and calculator
   crash): by list — copy (to another panel, multiple files, directories, overwrite, move), delete, rename,
   create directory, view (F3: text, hex, large file), editor (F4: input, search, replace, blocks, save), file search
   (Alt-F7), calculator, directory tree, compare, file selection (Ins, +, -, *), quick search, sort, panel modes, menu
   of all items (each item at least opens without crashing), settings dialogs. Every crash — reproduce in a pty test
   (`tools/dn-linux-ops.py`) and fix; list of what passed — in `dn/TODO-later.md`.
3. **Build for x86_64 Linux** (owner decision: 386 first; working head start already exists — `DN_ARCH=x86_64`, `dn/edits/x64`):
   - first measure: `tools/dn-probe-linux.sh` for native `fpc` (how many units build without edits);
   - 32-bit assumptions: `LongInt(Pointer)` and records with pointers in streams/dialogs (`TSysData`), `-Rintel` assembler on
     32-bit registers (under x86_64 — `NOASM` and Pascal versions), record sizes, `VmtLink`, `Move(…, SizeOf(pointer))`;
   - file format (`DN.INI`, `.DLG`, histories) must not depend on bitness: `rcp` and DN read what i386 wrote;
   - in CI — a second set and the same pty tour.
4. **UTF-8 inside DN** (right after x86_64; if already done by then — verify and close): DN internal strings are UTF-8.
   Where the system boundary is and whether conversion is needed on it:

   | Target | files (names) | screen and keyboard | clipboard |
   |---|---|---|---|
   | Linux | native UTF-8, no conversion | terminal UTF-8, no conversion | OSC 52 / system, UTF-8, no conversion |
   | DOS + go2dos | **go2dos API `DOS-UTF8/NAMES`** (`INT 2Dh` AL=10h, BX=65001: `71xx` calls take and return UTF-8; short names — ASCII): DN passes UTF-8 as-is, no conversion | OEM (in go2dos screen and keyboard remain OEM): `TvDos` converts via the code page | WinOldAp `INT 2Fh AH=17h`: CF_TEXT/CF_OEMTEXT format, on the wire **OEM**: we convert. **go2dos extension needed** — UTF-8 clipboard mode modeled on `DOS-UTF8/NAMES` (proposal to go2dos owner; until then — OEM) |
   | DOS without go2dos (DOSBox-X, FreeDOS) | convert at the boundary: UTF-8 ↔ single-byte page chosen by DOS from locale (milestone 5a: `TvCodePg`) | as above | as above (WinOldAp, OEM) |

   **Work order for item 4 (owner decision 2026-10-02: file names first; 160 DN files, ~1900 `Length`/`Copy` sites, ~300 `UpCase`/`UpStrg`,
   24 files with `TDrawBuffer`, 106 `WriteBufW`/`WriteLineW` calls).** DN strings remain `ShortString`, holding UTF-8 where that is enabled;
   CP866↔UTF-8 conversion for names (stub in `vpsyslow.pas`, `DN_NAME_CONV`) goes away when names become UTF-8 inside.
   - **4.1 Wide cell.** New draw-row type `TWideRow` (cell `LongWord`: code-page character byte, BIOS attribute byte,
     Unicode character code in the upper 16 bits if present) and `WriteBufX`/`WriteLineX` methods in `tv/` (old `WriteBufW`/`WriteLineW` on `Word` remain:
     calls with an unknown buffer type do not break silently); `MoveStrU`/`MoveCStrU` in `drivers.pas` parse UTF-8 and put characters into such a row.
     First to wide cells: name output in file panels (`flpanel`, `filespan`).
   - **4.2 File names in UTF-8 inside.** `FindFirst` returns names as-is; `SysOsPath` changes nothing; column widths and name clipping by `TvUtf8.CharWidth`
     (double width — two cells); sort and case by Unicode (`Country_`, tables for Cyrillic and Latin, then the rest).
   - **4.3 Input lines and editors.** Cursor, delete, selection by characters; paste and clipboard without conversion.
   - **4.4 Resources, help, messages.** `RESOURCE` texts in UTF-8 (`rcp` reads both CP866 and UTF-8), help (`tvhc`), strings in code; DOS without go2dos —
     conversion at the boundary (item 4, table).
   Each step is a separate iteration with a test (`dn/tests`, `tools/dn-linux-ops.py`) and a note in `dn/TODO-later.md` about what remains.
   **Status (2026-10-03, branch merged into `main`; build `DN_EXTRA=-dDNUTF8 tools/build.sh linux64`, mode off by default):**
   done: 4.1 `TScreenCell` cells; 4.2 names without conversion, widths and alignment by characters (`dn/src/dnutf8.pas`), headers, menus, command line, 16-bit buffers
   (UTF-8 → code page when writing into a word buffer), UTF-8 case and sort; 4.3 input lines (`tv/`); 4.4 resources and help in UTF-8 (iconv at build, `tvhc`);
   4.5 viewer (F3/F8, hex); Alt+Cyrillic (menu and dialog hot letters: `HotMatches`, `UpCaseCp`, `HotKeyAlt`); system clipboard (`winclp.pas` via `TvClip`: OSC 52 in
   `TvUnix`, `CF_UNICODETEXT` in `TvTermOs`; OEM↔UTF-8 conversion only without `-dDNUTF8`); character-based editor (document table `DocTab`: internal bytes as in CP866, rare
   characters in free cells; file stays UTF-8; search/replace, blocks, block case). Checks: `tools/dn-linux-ops.py` with `DN_OPS_UTF8=1` (CI: job `linux64-utf8`), `dn/tests`, `tv/tests`.
   Quick search in panel: Ctrl-S + Cyrillic. Editor: typing any keyboard characters (in a UTF-8 file a character outside CP866 gets a free document-table `DocTab` cell; cells occupied by text are not given away). Default mode on Linux (`DN_UTF8=0` — old build); `dist/linux64` and `dist/linux` rebuilt. **Remaining:** CJK and combining-mark width in the editor (in panels, dialogs, etc. done: wide mark — two proxy bytes, `FF` — second half, combining mark lives in its letter's cell);
   DBF viewer and other places; check Russian dialogs by eye; Windows: done — file names via wide APIs (`vpsyslow` sets UTF-8 for RTL names), verified in CI on real Windows (names `Privet` / Russian greeting, `αβγ`, F7 with a Russian name), default mode there too (`DN_UTF8=0` — old build)
   DOS stays on the code page; remove the `DN_NAME_CONV` stub.

   Shared: system boundaries are the only conversion places; in `dn/new` our own `UpCase`/sort for UTF-8 (`Country_`),
   character width — `TvUtf8.CharWidth`. go2dos specification — `docs/DOS-EXTENSIONS.md` §3 (clipboard), §5 (names); we check before
   implementing; we invent nothing.
5. **Russian on Linux:** user screen and embedded command line (`TvTerm` per magiblot/tvterm), Russian resources and help
   in UTF-8 (after item 4 this is mostly verification).
6. **Remaining DOS work:** save and restore state (`DN.INI`, desktop, histories), program screen after launching
   an external program, manual mouse check.
7. Next: aarch64 (**done 2026-10-03**: `tools/build-fpc-aarch64-linux.sh`, `tools/build.sh aarch64`, `dist/aarch64`; verified under `qemu-aarch64-static`: tv 40 tests, tour, ops 25/35; CI: `linux-aarch64` on `ubuntu-24.04-arm` and `tv` matrix); macOS for TV (win64/win32 Windows build done 2026-10-03, `dn/TODO-later.md`, "Windows"); go2dos as showcase (milestone 7), LFN and clipboard for DOS (milestone 5); translate
   comments into English (plan tail).
8. **Embedded terminal** (subproject on top of `tv/`, per [magiblot/tvterm](https://github.com/magiblot/tvterm), as in far2l and F4): a window with a terminal
   (VT emulator, pty); DN's command line runs commands in it; output stays on the DN screen. While it does not exist (done 2026-10-02):
   a command-line command and launching a program with Enter hand the terminal to the shell (`SysRunShell`: application screen is hidden,
   `/bin/sh -c`, Enter — back to DN, screen redrawn); on DOS — the previous `COMMAND.COM`.
   **tvterm analysis (2026-10-03):** tvterm is MIT (`COPYRIGHT`), ~3100 lines of C++ (`source/tvterm-core`: `pty.cc` 513, `vtermemu.cc` 744, `termview.cc` 340,
   `termctrl.cc` 328, `termwnd.cc` 168 + headers) on top of **libvterm** (C, MIT; in tvterm — magiblot fork) and tvision. **Decision:** we do not take libvterm via FFI
   (build with a single `fpc`, no C); we write the emulator in Pascal ourselves (`TvVt`, MIT, from the xterm control-sequence description; cells — `TScreenCell` from `TvCell`:
   wide marks, zero-width, 24-bit color already present). Iterations: 8.1 `TvVt` (**done 2026-10-03**: `tv/src/tvvt.pas`, test `tv/tests/t_vt.pas`, 76 checks) — emulator without I/O (UTF-8/CSI/OSC/DEC-mode parsing,
   screen and alternate screen, scroll and region, history) + tests; 8.2 `TvPty` (**done 2026-10-03** for Linux: `tv/src/tvpty.pas`, test `tv/tests/t_pty.pas`, 16 checks; pty via `/dev/ptmx` and ioctl without libc, fork/exec, size, wait for child; other Unix — via `posix_openpt`, later);
   8.3 `TvVtKeys` + `TvVtView` (**done 2026-10-03** without mouse selection: keys and mouse → bytes, 48 checks `t_vtkeys`; view draws cells, history Shift-PgUp/wheel, size, OSC 52, bracketed paste; demo `tv/demo/tvterm.pas`, pty test `tv/tests/pty/test_tvterm.py`, 13 checks); 8.4 wiring into DN (Ctrl-O, command line): 8.4a `TvVtRun` (**done 2026-10-03**: full-screen application program via the emulator; user screen remains: `VtRunScreen`, `VtShowScreen`; pty test `test_vtrun.py`, 8 checks), 8.4b glue in `dnrun.pas` and Ctrl-O (**done 2026-10-03**: command-line command goes through `VtRunScreen`, `UserScr` — user screen; Ctrl-O and Esc on an empty command line show it; settings `DN_EMBED_TERM=0`, `DN_RUN_PAUSE=0|1|2`; check in `dn-linux-ops.py`);
   8.5 Windows (ConPTY) — optional.
9. **Extended terminal protocols** (check and finish in TV, DN, and tvterm everything magiblot/tvision can do): OSC 52 (clipboard),
   kitty keyboard protocol, win32 input mode, bracketed paste, far2l extensions. The internal keyboard event format (`TEvent.KeyDown`)
   would preferably be extended so it stores everything win32 input mode passes (virtual key code, scan code, character, modifier
   state, repeat count, press/release). If that turns out long — to the very end of the list (before items 10–11).
10. **Graphical backend** (as in far2l: a window with a font instead of a terminal; at the very end). Choice: **fpGUI** (pure Pascal, builds
    with a single `fpc` without Lazarus and IDE; dependencies: Xlib/GDI/Cocoa and FreeType, no heavy libraries), not LCL (pulls Lazarus and a widgetset).
    Fallback if fpGUI does not fit: direct X11/Win32/Cocoa calls and our own character-grid drawing. The backend puts into `TvScreen`
    cells like terminal ones, draws them with a font, delivers keyboard and mouse events (including a full key set and Unicode).
11. **Port Free Pascal's text IDE onto our `tv/`** (separate subproject after everything else; currently the IDE sits on Free Vision):
    raise convenience (system clipboard, all familiar key combinations), add Unicode. Relies on item 9 (keyboard, clipboard)
    and on UTF-8 from item 4.

## User-reported problems found while trying the 2.20 alpha build (2026-10-04) — in order

The list was recorded before work on the items (at the owner's request). Mark `[x]` as done. Rebuild of the distribution (`dist/`) — after items 1–5, on the owner's word ("too early to build").

1. [x] (fixed in code, awaiting owner verification) **Command line: artifacts when typing Cyrillic** (example: Russian "proverka" → garbled "p<box>oe…"; break after "v" and "a"). Cause (from code, not yet verified on screen): in a build with UTF-8 inside (`DNUTF8`) `cmdline.pas` puts byte `Event.CharCode` (cp866) into the string, and the string is treated as UTF-8; bytes like `E0` (a) and `A2` (v) together form a "valid" UTF-8 sequence and draw as garbage. Fix: insert the event's UTF-8 text (`Event.Text`); drive cursor, Backspace, Delete, scroll, and mouse click by characters, not bytes. The "Make directory" input field is already fixed (tv `TInputLine`, `InputLineOem`).
2. [ ] **Check all other input sites for the same bug** (`Char(Event.CharCode)` in UTF-8 strings): panel quick search (`filepanel.pas`, `DoQuickSearch`), tree quick search (`tree.pas`), `dndlgs.pas`, calculator (`calcwin.pas`), menu hot letters (`menus.pas`), `paneldlgs.pas`, search and hex edit in the viewer (`fviewer.pas`), `tetris.pas`, `phones.pas`, editor (`editcore.pas` — already has a branch for `Event.Text`). Each site — either verified and recorded as "correct", or fixed. Verified by code: panel and tree quick search (`DoQuickSearch` already converts a code-page byte to UTF-8: `CpCharToUtf8`) — correct; command line — fixed (item 1). Still to review: calculator input field (`calcwin.pas:2054`), `dndlgs.pas:306–337`, `paneldlgs.pas:158–180`, viewer search (`fviewer.pas`), editor search-phrase input.
3. [ ] **Colors: calendar** — selected day (`80`, black on dark gray) and "today+selected" (`89`) are unreadable. Done in this commit: `3F` and `31` (like a selected button). Rest: **walk the code and palettes** and bring all "active" elements that still have other shades to the same look: palette entries `80/81` (193, 194, 196), `08` (224, 235, 242), blue backgrounds in the `default.pal` tail (269…307), colors hard-coded in code (`$1F`, `$70`, etc. in `cmdline.pas` and others). Rule: active/selected element = `3F` (white on teal, like the path background in the panel header).
4. [x] (fixed in code, awaiting owner verification) **Archives: cannot enter them** (Enter on zip and 7z — "nothing"; programs are on `PATH`). Causes found by sandbox reproduction (`ARC=1 tools/dn-linux-try.py`): (a) **`TView.ClearEvent` erased the key code** — `InfoPtr` overwrote `KeyCode` when win32-mode fields were added to `TEvent`; Enter on an archive checks the key after clearing the event (fixed in `tv`, test in `t_views`); (b) 7z, IS3, ZOO signatures compared as `LongInt = $AFBC7A37` — in FPC such a constant is positive and the comparison is always false (fixed in `archdet.pas`, `archiver.pas`, `fmtzoo.pas`, `fmtzip.pas`); (c) 7-Zip 9.x+ output starts with a properties block containing the string `--`; listing parse took it for a table separator (`fmt7z.pas`); (d) default program name `7Z` — on Linux case matters: `7z` (`fmt7z.pas`); (e) the command line went to the shell with DN paths (`C:\tmp\…`, the shell ate backslashes) — `DNRun.CmdToOs` converts paths (test `t_dnrun`); listing temp file was opened by a DN path — `SysOsPath` (`fmt7z`, `fmtain`, `fmtuc2`); (f) archiver calls by DN itself (`ExecStringRR` with RR = False) must not wait for Enter: "Process ended" pause only when exit code ≠ 0 (`DNRun.QuietRun`).
4a. [x] (partial) **Archives on Linux, continued**: Unix defaults for zip/unzip (Info-ZIP), `rar`, `tar`, `7z` per far2l multiarc; Windows PKZIP/RAR/TAR. Class: `fmt*.pas` + drive `override`; PTY Enter on `aaa.zip`/`aaa.7z` shows `inside.txt`. Additionally: `Destroy; Fail` → `Fail` in `TArcDrive`/`TArvidDrive`. Separate class-only AV: Enter on a non-executable file (`cmExecFile` / `ansistr_to_shortstr`) — do not confuse with entering a zip. F3/F5 extract/add not yet in acceptance.
4b. [x] **ZIP: encoding of single-byte names/comments** (listing decode landed; gaps in docs/ZIP-CHARSET.md) (owner clarification 2026-10-05). Logic **1:1 including bugs** with [unxed/zipcharset](https://github.com/unxed/zipcharset) (ZIP heuristics + Unicode extra `0x7075`/`0x6375`) and [unxed/localecp](https://github.com/unxed/localecp) (OEM/ANSI by host locale). Do not "improve" the heuristics. Locale encoding detection — extract into a **separate reusable subproject** (so others can use it too); on top of it — a layer like `zipcharset` for `fmtzip`. Spec: `docs/ZIP-CHARSET.md`.
4c. [~] **Archive matrix: nested and typical formats + automated tests** (owner 2026-10-05).
   **Done 2026-10-05:** `.tgz`/`.tar.gz` Enter+listing on Unix (`fmttgz`: gunzip +
   tar headers; GNU `tar` in defaults); fixtures `tools/gen-archive-fixtures.py`; PTY
   Enter/leave `tools/dn-linux-archives.py` (zip/7z/tar/tgz/tar.gz). **Remaining:**
   F3/F4/F5 from archive (without hang), peers (`.tar.bz2`/`.tar.xz`, zip-in-zip),
   CI wiring. Spec: `docs/ARCHIVE-MATRIX.md`.
5. [x] (fixed in code, awaiting owner verification) **"Change language" does not work**: instead of changing the language, the terminal screen repeats "[ Process ended (000): Press Enter ]" after the shell prompt (i.e. DN launches an external process with an empty command, three times in a row); language does not change. Owner screenshot 2026-10-04 08:36. Need: find in code what the menu item calls (language-change command, `dnutil.pas`/`mainapp.pas`/`setups.pas`), why it goes into `ExecCommand`/shell launch, and fix. Cause: `ExecString('', '')` (in the original — restart via DN.COM loader) on Linux launches a shell with an empty command. Now `cmRestart` and language change set `DNRun.RestartPending` and quit DN (`EndModal(cmQuit)`: desktop is saved as on exit); after stop `dn.pas` calls `DNRun.RestartSelf` (Unix: `execve` of the same program with the same arguments; Windows and DOS: `ExecuteProcess`, old process waits and ends after the new one). Verify language change on three languages (English, Russian, Ukrainian) and that the choice is saved in `dn.ini`.
6. [x] (tv `tvvtrun.pas`) After "[ Process ended (…): Press Enter ]" there is no newline — added.
7. [ ] **Distribution**: rebuild `dist/` (all targets + dos-utf8) from a clean clone after items 1–5, commit, push.
8. [x] Version "2.20 alpha"; in the About box, lines `Build <hash>` and `Compiled <date>` (without brackets) — done (`f2a8892`).
9. [x] Compiler note `macro.pas(210,5) Note: Local variable "Error" not used` — removed unused variable.
10. [x] Active dialog fields that were blue (selected input-field text, history arrow, list items, scrollbar) — teal `3F`, like a button (`f2a8892`; shades chosen from a screenshot, not compared to references).

## Hard class-migration gate and what comes after (owner, 2026-10-05)

**Now (while the gate is OPEN):** fix the class build. Comparator — latest **object** vs latest **class** DN revision (not `dist/`). Run **all scenarios of all functions**; compare **cell-by-cell bitwise**: glyph, text color, background color, attributes, cursor, process status, side effects. Mismatch → gate not passed → fix; do not go further. Spec: `docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`, summary `CLASS-MIGRATION.md`, status `docs/CLASS-MIGRATION-STATUS.md`.

**Only after a full PASS of the gate** (order fixed, do not reorder), see `docs/POST-CLASS-WORK.md`:

1. **English:** Russian comments; documentation; user-facing strings and hardcode.
2. **Refactoring** for readability and maintainability — **first** formulate and fix completion criteria, then refactor.
3. **Platform-dependent code** — separate and document correctly (Linux / DOS / Windows).
4. **Tests** — expand coverage to a minimally decent level, including Linux, DOS, Windows specifics.

Other items already recorded separately: `dn/TODO-later.md` (Save setup on DOS, UTF-8 boundary without a provider, far2l: pictures and drag-and-drop, Kitty: flags 4/16, dn.cfg keys and user profile, input-line color `9f` vs black in references).

## Owner requirements checklist (audit of 2026-10-06) and what is open

The requirements the owner stated in the working dialog, with the state in the repository. `[x]` done, `[~]` partly, `[ ]` open.

1. [~] **DN on tv3 (classes).** Done; the strict object/class parity gate is still open (the flaky `menu_5_13`: the asynchronous tree scan; see `docs/POST-CLASS-WORK.md`).
   After the gate: the case-insensitive substring `object` may stay only in the sense of Pascal objects (`tools/tests/test_class_names.py` is the check; to be completed with the text policy).
2. [x] **English** for comments, hard-coded text, documentation (`docs/TEXT-POLICY.md`, `tools/tests/test_text_policy.py`).
3. [x] **Refactoring criteria first** (`docs/REFACTORING-CRITERIA.md`), then the refactoring; **platform code** separated step by step (`docs/PLATFORM-SEPARATION.md`: stage 3 in progress); **tests** (stage 4) pending.
4. [~] **UTF-8 only.** No file of the project is in a legacy encoding (the policy test). Exceptions that still break the rule "strictly UTF-8, in any file":
   `dn/data/xlt/*` (binary code page tables: data) and the CP437 bytes of `VertScrollBarChars` / `HorizScrollBarChars` in `dn/data/dn.ini`. [ ] Convert them: the scroll chars as Unicode text in `dn.ini`; the tables stay binary (a data format), the policy says so.
5. [x] **Resources in UTF-8, any language** (`dn/src/resource/*`): `Győr` is right in all three languages; the Latin look-alikes in Cyrillic words (and the Cyrillic ones in English words) are repaired by `tools/fix-resource-lookalikes.py`, the Ukrainian `i` is a real letter; the DOS build lands the resources and the help on the code page of the language (`tools/to-codepage.py`: cp866, Ukrainian cp1125; the lost characters are listed, `?` is the last resort).
   [x] cp1125 (the DOS page of Ukrainian) is in `tools/gen-codepage.py` / `tv/src/tvcp.inc` / `CpSelect` (tv3 `9c9e25a`, test in `t_clip.pas`); `ApplyCodePage` of DN takes it for the Ukrainian language (the code page builds). [x] The host locale table `tvlocale.pas` has `uk_UA` (866, as glibc and `localecp` give it: the host page of a terminal; DN takes 1125 only for the Ukrainian language of its own resources). Left as a doubt: should `uk_UA` map to 1125 when a DOS user has it? (a setting if the owner wants it)
6. [~] **No single-byte hard code in DN and tv3.** Done 2026-10-06 (tv3 `0bc5e6b`): the DOS screen lands a cell character on the current page (`CpFromUnicode`, then `CpFallback`: the plain `- = | + # : % . < > ^ v *`, then `?`); DN `CellChar` gives the byte of the page back where DN asks for it. The attempt to make `ScInitChar` produce UTF-8 at once (cell = UTF-8 only) was **reverted** (tv3 after `0bc5e6b`): it broke `dn-accept` (`f5_f6_f8`: stray `═` cells stay in the panel after a dialog closes; `menu_3_3`, `menu_3_16`: DEL glyph). Cause of the stray cells not found; see `dn/TODO-later.md`.
   [ ] What is left is the **source**: the byte constants for glyphs (`#196 #179 #186 #201 ...`, `#219 #177 #254`, about a hundred places in DN: `panelwin.pas`, `menus.pas`, `progress.pas`, `fviewer.pas`, `filepanel.pas`, `calcwin.pas`, `editundo.pas`, `gadgets.pas`, `pktview.pas` ...; in tv3 `FrameChars`, `MenuFrameChars`, `CloseIcon` ...) become named Unicode constants (a unit of the box characters, UTF-8 strings), by files, each batch with the gate; the palettes written as `#112#113...` are not glyphs and stay.
7. [x] **DOS: the code page for input and output, UTF-8 for files and the clipboard where the API exists.** The DOS build with the code page inside (the default `dos`): the screen and the keyboard are the code page of the machine, the resources are landed on it by the build. When the DOS has the provider `DOS-UTF8/NAMES` (AMIS; go2dos, the patched DOSBox-X) and it is on for the process (`DosNamesInit`, `DN_DOS_UTF8_NAMES=0` switches it off), `osdep` turns every name that goes to the DOS from the code page into UTF-8 (`SysOsPath`, `SysNameToOs`, the program path of `SysExecute`) and every name that comes back (`Fill` of the search, the current directory) from UTF-8 into the code page; a name that the page cannot show stays as UTF-8 bytes and goes back unchanged. The clipboard asks `DOS-UTF8/CLIPBRD` through tv in both builds. Checked in the patched DOSBox-X: `tools/dn-dos-input.py` the scenario `utf8-names-cp` (cp866 screen, Russian names of a file and of a directory, entering the directory). The `dos-utf8` variant (UTF-8 inside) stays. [ ] Not covered: the command line passed to a child program (the child has no UTF-8 mode: it gets the code page, as it should); the shortcut of the names that the provider gives as `NAME~1.EXT`.
8. [x] **The matrix DOS / Windows / Linux** is built in CI (`toolchain.yml` DOS, `dn-windows.yml` win64 and win32, `dn-linux.yml` x86_64, ARM64, i386). **OS/2 is dropped** (2026-10-06): `OS2exec`, `opOS2`, the `{$IFDEF OS2}` places, the OS/2 session types and the `.CMD` start are gone; the unit `os2sess` is `winsess` (Windows only); `rcp` has no `O` / `OS2` option. [ ] Left on purpose: the help topic `hcOS2Support` and the words OS/2 in the resources (the product text: to be reviewed by the owner), the `OS2` menu mark of `usermenu.pas` (a syntax of the user menu files, also used for Windows sessions), the default name `UNTGZOS2` in `fmttgz.pas`. Restoring is possible from the archive of the sources.
9. [x] **Nightly builds of every commit into the releases:** `.github/workflows/nightly.yml` (all the targets, the release `nightly` is replaced on every push to `main`; the packing is `tools/pack-nightly.sh`). Added 2026-10-06; the first run (`8f2eb6c`) made all seven archives (linux64, linux-arm64, linux32, win64, win32, dos, dos-utf8) and the release `nightly`. [ ] The assets are snapshots without the checks of the other workflows: to be linked to their results if wanted.
10. [x] **The letter in the top-left corner of every panel** (English `x`, Russian a box character, Ukrainian a Cyrillic letter). It is not a frame character: it is `TSortView`, the **sort mode letter** (`dlSortTag`: n name, x extension, s size, t time ...); DN sorts by the extension by default, so English shows `x`, as the original does. The Russian and Ukrainian strings are UTF-8 and the code took one byte of them: fixed (`topview.pas`, the letter is a whole character, upper case when the sort is inverted); check `tools/dn-linux-sortmark.py` (in `dn-linux.yml`). [ ] A question to the owner: the default sort by the name (`n`, as in far2l and Norton) as a setting of `dn.ini`?
11. [ ] **Hotkeys on any keyboard layout: the mechanism `xlat`, as in far2l** (the owner decision 2026-10-06: document now, do not make yet). The resource letters of the hotkeys are now real Cyrillic (the Latin look-alikes are repaired), so a hotkey works on the Russian layout and not on the Latin one. Design:
    * one table of layouts (EN, RU, UK; extensible), a character of a layout has its partner on the other layouts (the data: text files in `dn/data/xlat/`, a built-in default, the format close to the far2l `XLat` tables; DN already has `xlt` tables for the layout of the keys: look at them first and reuse);
    * the physical key is the best source: tv3 events carry `VirtualKey` and `ScanCode` (win32 input mode, Kitty); when they are there, the hotkey is matched by the physical key and the layout is not needed; else by the table;
    * the places: the hotkeys of menus and dialogs (`~X~`), the quick search of the panels and of the tree, the input of `Alt+letter`; first the character as typed, then its partners;
    * a settings section `[XLat]` in `dn.ini` (on/off, the list of layouts), the default is on;
    * a command that converts the typed text to the other layout (far2l: the key `Ctrl+Alt+...`), as a second step;
    * tests: the table (a round trip), a hotkey on both layouts in a pty scenario, a character without a partner is unchanged.

## Next items in order (2026-10-06)

Order inside the rules of `docs/POST-CLASS-WORK.md` (the gate first; then the stages). Update the marks when an item is done.

1. [x] **The strict class/object gate** (`dn-accept`): full green run on head `dee88bf` (2026-10-06; the last red scenarios were the sort letter bug, fixed in both builds by the backport in `tools/acceptance/backport_shared_object_fixes.py`; the UTF-8-only cell of tv3 was reverted because it broke the gate, see `dn/TODO-later.md`); keep it green; `menu_5_13` (the tree scan) is the known unstable one: a stabilizer is in, not proven.
2. [x] **Remove the OS/2 remains** (done 2026-10-06, see item 8 of the checklist above).
3. [x] **cp1125 table in tv** (done 2026-10-06, see item 5 of the checklist above).
4. [~] **Frame, scroll and shadow characters as Unicode (UTF-8)** everywhere: the cells and the DOS landing are done (item 6 of the checklist above); the named constants in the source and the `dn.ini` scroll characters as Unicode (item 4) are left.
5. [ ] **Platform separation** (stage 3, `docs/PLATFORM-SEPARATION.md`) and **tests** (stage 4: Linux, DOS, Windows specifics); the DOS names scenario `utf8-names-cp` is the first DOS one.
6. [~] **Other input sites** with `Char(Event.CharCode)` on UTF-8 strings: the quick search of the panel takes the typed text (`DoQuickSearchEvent`, test `tools/dn-linux-qsearch.py`); the tree takes it too; audited 2026-10-06 and nothing to do: the calculator, the hex line and the combo box of `dndlgs.pas`, the hot keys of `paneldlgs.pas` take only ASCII, the dialog input lines and the editor (`TabTyped`) already take `Event.Text`; left: starting the quick search of the panel by a typed character (Caps/Shift modes); the display of a long mask cuts by bytes; **colors**: the rest of the dull palette entries and the colors in the code.
7. [~] **Archive matrix** (`docs/ARCHIVE-MATRIX.md`): the real F5 extraction is in the test (zip, tgz, tar.xz; first CI run pending); left: F3/F4/F5 for 7z and the others, `.tar.bz2` / `.tar.xz`, zip in zip, the CI wiring.
8. [ ] **xlat for hotkeys** (design in item 11 of the checklist): on the owner's word.
9. [ ] **Default sort by the name** as a setting of `dn.ini` (a question to the owner).
10. [ ] Lower: Save setup on DOS, the UTF-8 border without a provider, far2l (pictures, drag and drop), Kitty flags 4 and 16, text keys of the settings in `dn.ini`, the input line color `9f` against black in the references, the `dist/` directory against the nightly releases (keep or drop).
