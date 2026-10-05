# DN OSP 2.14 under FPC: what we learned (2026-10-02)

Source: `tools/dn-probe.sh` (compiles every unit in the tree with FPC 3.2.2, native x86_64, `tp` mode) on the
DN OSP 2.14 tree (186 `.pas`, 182 units excluding programs). Record here every FPC fix
(a cause-“d” patch in `dn/patches` or a unit in `dn/new`) and its reason.

## 1. DN OSP is a Virtual Pascal project

- `vpc.cfg` (VP config): `-ALFN=LFNVP;WINCLP=WINCLPVP` — unit substitution (`-A`); FPC has no
  such option; `-$Delphi+`, `-$Use32+`, keys `-$Cdecl-`, `-$Far16-` are VP-specific.
- Platforms are selected by symbols `DPMI32` (102+41 `{$IFDEF}` hits), `OS2` (97+77), `WIN32` (79),
  `LINUX` (14): the DOS build of DN OSP is the VP DPMI32 target (32-bit DOS via DPMI), which
  matches our go32v2 in meaning.
- External units not in the tree: `vputils`, `files`, `events` (there is `Events.inc`), `windows`, `strings`,
  `os2base`/`os2def`/`os2pmapi`, `dpmi32`/`dpmi32df`, `vpkbdw32`, `lfn` (= `lfnvp` via `-A`), `winclp`
  (= `winclpvp`), `use16`, and DN’s own modules (`navylink`, `dn2pmapi`, `terminal`, `udialer`,
  `modemio`, `country_`, `fltl.001`, `fnotify.001` — in OSP they live under other extensions).

## 2. Root causes (probe: count of units stopped by each cause)

| Root | Units | What it is |
|---|---|---|
| `vpsyslow.pas` | 119 | **Virtual Pascal 2.1 Runtime Library** (© 1995–2003 vpascal.com, “system” layer): types `SmallWord`, `TFileSize`, `TFileSystem`, constants `PROT_*`, `xcpt_Ctrl_Break`, OS2/Linux/Win32/DPMI32 branches |
| `archiver.pas` | 31 | needs the `Files` unit (VP) |
| `commands.pas` | 8 | `INLINE` on procedural types (VP/Delphi syntax) |
| `filescol.pas` | 5 | `Files` unit |
| `objects.pas` | 2 | different `$` symbol in a directive |
| other | 1 each | `xtime` (`Events`), `version`, `uue2inc`, `titleset`, `rtpatch`, `regexp`, `plugrez`, `plugin`, `modules`, `memory` |

Of 182 units, 4 compile as-is — the rest almost entirely hit the VP layer.

## 3. What we do (working decisions so far)

1. **Do not take VP-RTL into the build**; replace it with our own units in `dn/new` under the same name and API,
   limited to what DN actually uses: `vpsyslow` (of ~169 declared names DN uses
   41, 98 uses total: `TDriveType`, `SysPlatformId`, `SysTvInitCursor`, `THandle`,
   `SysFileOpen`, `SysFileCreate`, `SysTvGetScrMode`, `SysTvSetCurPos`, `SysCtrlSleep`,
   `SysGetCurPos`, `SysBeepEx`, ... — full list from `tools/` on request), `vputils`, `files`,
   `windows` pieces, `dpmi32df`, `vpkbdw32`. Write from scratch from DN call sites and FPC docs,
   **without copying** `vpsyslow.pas` (vpascal.com copyright; VP RTL license unknown to us);
   `vpsyslo2.pas` (JO/Cat contribution to DN OSP) and `lfnvp.pas` (DN) — DN OSP code by their headers;
   they stay and are adjusted with cause-“d” patches. Screen/mouse/keyboard I/O goes through our `tv/`.
2. Unit substitution `-A` — via cause-“d” patches (rename `uses LFN` → `uses LFNVP`, etc.) or
   wrapper units in `dn/new`; the probe makes alias copies automatically.
3. go32v2 target: define `DPMI32` (DN OSP’s DOS branches are already written for it); FPC side —
   on top of FPC RTL `go32`/`dos`; `LFN` — via RTL `LFNSupport` (`dn/new`).
4. VP/Delphi constructs that FPC in `tp` mode rejects (`INLINE` on procedure types, `$` directives) —
   cause-“d” patches; pick mode (`objfpc`/`delphi`/`tp`) per unit, not globally.

## 4. Decided (project owner, 2026-10-02)

Replace vpascal.com code with our units; `vpsyslow.pas` is on `dn/exclude.list`. Name lists
that DN actually takes from `vpsyslow` (56 names, 143 uses in kept files),
`vpsyslo2` (1) and `lfnvp` (37 names, 765 uses — this is DN’s LFN, it stays) —
`spec/vp-api-*.md` (`tools/vp-api.py`; names and counts only).
Error in the first version of this file: `vpsyslo2.pas` and `lfnvp.pas` do not belong to vpascal.com —
by headers they are DN OSP code; vpascal.com code is only in `vpsyslow.pas`.

## 5. After exclusion (probe, 2026-10-02): missing-unit list

With `dn/exclude.list` (38 audit files + `vpsyslow.pas`) the tree has 144 units; 4 compile (same as before).
Units that are now missing and must be supplied (`dn/new` or `tv/`), by how many units depend on them:

| Unit | Units blocked | Who supplies it |
|---|---|---|
| `Defines`, `_Defines` | 38 + 9 | rewrite: shared DN types and constants (28 + 60 names, `spec/dn-boundary-dnosp214.md`), partly `tv/` |
| `Files` (VP) | 35 | our unit: DN file layer on FPC RTL (names from DN call sites; in kept files — see probe errors) |
| `VPSysLow` | 17 | our unit per `spec/vp-api-vpsyslow.md` (56 names) |
| `Collect`, `Views`, `Streams`, `Gauge`, `Dialogs`, `DNApp` | 12, 4, 3, 1, 1, 1 | adapters over `tv/` (`tools/api-coverage.py`: what already exists) |
| `use16`, `Os2Def`, `Events` | 1 each | disable OS/2 and `use16` branches (`{$IFDEF}` in a cause-“d” patch), `Events.inc` is an include file |

Further probes will cascade: each added unit opens the next error layer — that is the work order for milestone 4.

## 6. First replacements (2026-10-02, evening)

Probe on the tree after exclusion, shims (`dn/new/shims.map`, `tools/gen-shim.py`) and edits (`dn/edits/`):
**25 of 160 units compile** (was 4 of 182). That is the local probe figure on the unpacked
archive (`DN_LOCAL_TREE=... tools/dn-materialize.sh`, `tools/dn-probe.sh tp -dDPMI32`); CI probe is the same.

What was done:
- **Shims** (`dn/new/shims.map`): units named like Borland’s (`Views`, `Defines`, `Dialogs`, `Collect`, `Streams`,
  `Scroller`, `Validate`, `ColorSel`, `HistList`, `MsgBox`, `App`, `Menus`, `StdDlg`, `_Views`...) expose our
  `tv/` names (types/constants as aliases, variables via `absolute`, procedures as wrappers, enum members as constants).
  Where DN names differ — `dn/new/manual/*.inc` (so far `TPhase = TPhaseType`).
- **Edits** (`dn/edits`, applied by `tools/dn-materialize.sh`): `05-conditionals.sh` — conditionals are evaluated for the target
  from `dn/target.env` (`DPMI32`, `tools/ifdef-strip.py`: understands `{$I file}`); `10-getpalette.sed` — `GetPalette: PPalette` →
  `TPalette`, `:= @S` → `MakePalette(S)`; `20-interface-bodies.py` — function bodies in `interface` (VP style) move
  to `implementation`, `inline;` is removed.

What still blocks (probe roots): `vpsyslo2.pas` (44 units) — needs `TOSSearchRec`, `SysFindFirst/Next/Close` from `VPSysLow`;
`archiver.pas` (31) and `filescol.pas` (8) — `Files` unit (VP); `_model1` — `TRegExpStatus`, `AsciiZ`, `TXlat`... (DN names
that were in `defines.pas`: by hand in `manual/defines.inc`); `_menus` — `PMenu`, `PMenuItem` (shim `Menus` needed where DN expects `Menus`);
`objects.pas` — stub file (literal one-line non-Pascal text `Nefig!`); `ufnmatch.pas` — empty.

**Important discovery.** `lfnvp.pas` (DN) is the LFN implementation for DOS via real-mode calls (`INT 21h AX=71xx`) on the
`Dpmi32`/`Dpmi32df` layer (`real_mode_call_structure_typ`, `init_register`, `intr_realmode`, `segdossyslow16/32`) — that is **exactly the
LFN part we need on DOS**. The `Dpmi32*` layer is absent from the archive (Virtual Pascal RTL for DOS): we write our own
`dn/new/dpmi32.pas`/`dpmi32df.pas` on top of FPC `go32` (`realintr`, `TRealRegs`, `dosmemput`), names from call sites in
`lfnvp.pas`, `winclpvp.pas` (DN’s WinOldAp clipboard — also from there), `vpsyslo2.pas`.

## 7. VP/Dpmi32 layer and first units (2026-10-02)

- Done: `dn/new/vpsyslow.pas` — files (`SysFileOpen/Create/Seek/Read/Write`) and search (`TOSSearchRec`, `SysFind*`);
  `dn/new/dpmi32.pas`/`dpmi32df.pas` — real mode via `go32` (`realintr`, `transfer_buffer`; on
  non-DOS — stubs with CF=1), `MemGet/MemPut` instead of VP `Mem[]`/`Ptr()` (edit `dn/edits/30-dpmi32-mem.py`: memory below
  1 MB is not in the data segment); `manual/defines.inc` — names from DN `defines.pas` (`Str*`, `LongString`, `TXlat`, `TSize`...),
  plus `TFileSize/SmallWord/TQuad` from VPSysLow (in VP they are visible to everyone). `gen-shim.py`: `+Unit` in `shims.map` — only in the shim’s `uses`.
- Probe (`tools/dn-probe.sh objfpc -dDPMI32`): 31 of 162 units compile (was 25). `lfnvp.pas` gets as far as `drivers.pas`.
- **Finding.** The audit `exclude.list` caught not only “Borland” units but also DN core: `DNAPP.PAS`, `FVIEWER.PAS`,
  `edwin.pas`, `calendar.pas`, `memory.pas`, `filetype.pas`, `version.pas`, `usersavr.pas`, `colorvga.pas`, `advance6.pas`,
  `TopView_.PAS`, `strview.pas`, `asciitab.pas`... Audit gate is `raw% <= 2 and maxrun < 48`; many of these have raw% 1–6 %, and
  *one* long match excluded them (`FVIEWER`: 1 %, but maxrun 112 tokens from `VIEWS.PAS`). Without them you cannot build
  `Events`/`Messages`/`Gauge`/`DNApp`, nor `FViewer` (other units reference them).

## 8. Audit gates and segment rewrites (2026-10-02)

- `audit/runs.py` understands `REN=1` (compare with renamed identifiers). “Structural” matches are often false
  (repeated `PutExtFilter(...)` calls give 90 “clone” tokens); the real signal is `raw` segments: `FVIEWER` —
  `TViewScroll.GetSize/DrawPos` (copy of TScrollBar), `calendar` — keys in `HandleEvent` and `Store` (TV demo). Rewritten
  in `dn/rewrite/*.rw`; after edits `FVIEWER` raw 0 %, maxrun 28; `calendar` raw 4 %, maxrun 42.
- Own `memory.pas` (DN name interface matched Borland entirely — declaration order changed).
- Doubtful spots (do not complicate; record): in VP `Word` is 32-bit, in FPC — 16; DN assumes VP. For now fix by compile
  errors (`dn/edits/40-xtime-word.sed`: `Integer(Word)` casts). Risk: `Word` overflow in arithmetic VP
  did not suffer — look for it in tests. `Events` (DN unit, no source in archive, there is `Events.inc`): shim to TvEvents/TvKeys +
  `GetCurMSec`, `LongWorkBegin/End` (`dn/new/manual/events*.inc`).

## 9. Next root: DNApp, Drivers, VideoMan (2026-10-02)

- `Country_` (not in archive) — our `dn/new/country_.pas` (`CountryInfo` from system settings), test `t_countr`.
  Probe: 37 of 175. `drivers.pas`: `SysErrorFunc = SystemError` → `@SystemError` (`dn/edits/41-drivers.sed`).
- Root of 58 units — `drivers.pas`, which hits `videoman.pas` → `DNApp` (excluded by audit: 33 % Borland, a copy of `App`).
  `DNApp` — 51 units use it. Inside: `TBackground`, `TDesktop`, `TProgram`, `TApplication` (with DN additions:
  `IdleSecs`, `CanMoveFocus`, `ExecuteDialog`, `InsertWindow`, `ActivateView`, `Clock`, `ShowUserScreen`, `WhenShow`,
  `GetTileRect`), resources (`OpenResource`, `ExecResource`, `LoadResource`, `GetString`, `Resource`, `LngStream`,
  `LStringList`), `GlobalMessage*`, `WriteMsg`, `ViewPresent`, `PreExecuteDialog`.
- Gaps vs our `tv/` (`TvApp`) that must be closed: `TDeskTop` (ours) / `TDesktop` (DN); `Init(const R)` /
  `Init(var R)`; `Pattern: Byte` / `Char`; `PPalette` / `TPalette`; no `Load/Store` (view streams not
  ported); no dialog resources. `drivers.pas`/`videoman.pas` lean on `SysTv*` (VP) — choose: implement
  `SysTv*` over `TvScreen/TvSys` or replace our `Drivers`/`VideoMan` with adapters.

## 10. Choice (a) and cell model (2026-10-02)

Decided (owner: “A”): our `dn/new/dnapp.pas` over `TvApp`; DN `Drivers`/`VideoMan` stay; `SysTv*` over `TvScreen/TvSys`.
Discovery along the way: DN draws with **16-bit cells** (`Word`: OEM char + attribute, `TDrawBuffer`, `MoveChar(B, ...)` from
DN’s own `drivers.pas`, `WriteBuf/WriteLine(…, B)`: ~250 sites in 15 files); our `tv/` cell is `TScreenCell`
(UTF-8 + attribute), and `TDrawBuffer` is an object. Plan: in `tv/` add `TView.WriteBuf/WriteLine` overloads for old
`Word` buffers (with a code-page table); exclude `TDrawBuffer` from the `Views` shim (DN has its own, from `Drivers`).
`SysTv*`: DN `ScreenBuffer` is a `Word` buffer; `SysTvShowBuf` maps it to `ScreenWrite`.

## 11. Reachability and missing list (2026-10-02)

- `tools/dn-reach.py build/dn dn.pas`: from `dn.pas` via `uses`, 131 of 178 units are reachable; 47 are not needed for the build: plugin
  copies `_*.pas`, `dnfuncs`, `vars`, `rcp`, `plugin*`, `tetris`, `calc`, `version`, `app`, `msgbox`, `stddlg`, `objects`...
  (some are our shims that DN included under another name). Plugin model is not needed for v1.
- Needed but absent from the archive (VP RTL or files missing from OSP): `asciitab`, `dnstddlg`, `edwin`, `fltl`, `fnotify`,
  `gauge`, `gauges`, `helpfile`, `helpkern`, `use16`, `vputils`; `Drivers._vp` — VP variant of `drivers`. Files `*.001` are not
  sources but **AK155 notes on edits** (`fltl.001`: `GetDriveTypeNew`, `TDrvTypeNew`, `GetFSString`;
  `fnotify.001`: `NotifySuspend/NotifyResume` disable panel auto-refresh during a dialog) — these are our specs.
- DN `drivers.pas` declares its own `TEvent` (with `Double`, `ShiftCode`, `KeyCode: LongInt`), which conflicts with tv’s `TEvent`.
  `drivers.pas` replaced by our `dn/new/drivers.pas` (stub for now: names added from compile errors).
- `*.pas` filenames lowercased (`TopView_.PAS`: FPC on Linux will not find `topview_`).
- Edit `15-short-headers.py`: implementation headers without parameters (VP/BP style) — 580 in 88 files.
- VP assembler (Intel syntax) compiles with `-Rintel`; ~55 `asm` blocks (EBX/ESI/EDI must be preserved
  by us in FPC) — verify at run time, not at compile time.

## 12. LIB.D32: “missing” units were in the archive (2026-10-02)

The owner noted DN OSP was built with Virtual Pascal and attached archives (`dn2s214.rar` — sha256 matched the pinned one;
`dn151src.zip` — sha256 pinned in `dn/upstream.env`). The bug was in our `tools/dn-materialize.sh`: it took only the
archive root, but the archive has platform dirs `LIB.D32` (DOS 32-bit DPMI = our target), `LIB.OLF` (OS/2), `LIB.WLF`
(Win32) with units `Events`, `files`, `fltl`, `fnotify`, `country_`, `DosLow`, `dn2pmapi` and a copy of VP RTL (`VPSYSD32.PAS` —
© vpascal.com, do not take). Now `DN_LIB_DIR=LIB.D32` in `dn/target.env`: target units (except `vpsysd32`) are copied to the root,
other `LIB.*` are removed.
- This is DN OSP code (JO, Cat, AK155): `fltl` (disk, file times, FS via INT 21h 71xx/73xx), `country_` (INT 21h 6521h/3800h),
  `fnotify` (D32 stub), `Events` (`GetCurMSec` via `VPUtils.GetTimeMSec`), `files` (`TUseLFN`, `uLfn`, `InvLFN`).
  Our `dn/new/files.pas`, `country_.pas`, `events` and edit `42-keymap` were removed.
- They use the VP layer: `dpmi32`, `dpmi32df` (`real_mode_call_structure_typ`, `getdosmem`, `dosseg_linear`),
  `VPUtils` (`GetTimeMSec`), `Mem[segdossyslow32]`, `Ptr(...)`. Our `Dpmi32` was extended: `getdosmem`, `dosseg_linear`,
  `MemFill`, `MemStr` and a `DosShadow` “shadow” — a program block copied into DOS memory and back around each
  `intr_realmode` (so `DosSegFlat^` works as with flat memory). Edits: `30-dpmi32-mem.py` (lfnvp, fltl, doslow),
  `21-oneline-bodies.py` (one-line bodies in interface), `22-smallword.py` (in VP `SmallWord` is visible everywhere).
- In dn151 (RIT, Borland Pascal 7) these units are absent; instead there are `GAUGE`, `GAUGES`, `HELPFILE`, `HELPKERN`, `ASCIITAB`, `DNSTDDLG`,
  `MESSAGES`, `DNAPP`, `DRIVERS`, `FVIEWER`, `TVHC`.

## 13. Where we are on `dn.pas` (2026-10-02, evening)

Compiling the main program `tools/dn-try.sh dn.pas` (options from `dn/target.env`: `-Mdelphi -Sh- -Rintel -dDPMI32`) walks
dozens of units; stop — `Gauges` (needs our own: `TTrashCan`, `TKeyMacros`, `THeapView`, `TClockView`, Borland
regions — in `dn/rewrite`, as for `gauge`).
- Delphi mode + short strings — as in VP: procedures as values without `@`, `Result`. `@Name` of a local procedure in Delphi mode
  is an untyped pointer, so `FirstThat/ForEach(@X)` is fixed to `(X)` (`61-callbacks.sed`); typed-pointer
  parameters — `62-callback-params.py`; `tv` accepts `is nested` (`{$modeswitch nestedprocvars}`).
- `{$V-}` and `nestedprocvars` are added in `STDEFINE.INC` (`04-stdefine.sh`).
- tv: `TView.WriteBufW/WriteLineW/GetColorW`, forms `GetBounds/GetExtent/...(var R)`, `TListBox.List`, streams on `Int64`
  and with DN extensions, `FirstThat/ForEach` with nested procedures. All tv tests pass.
- DN `TView` extensions missing from `tv/`: `UpdTicks`, `UpTmr`, `Update` (virtual), `ClearPositionalEvents`,
  `GetPeerViewPtr/PutPeerViewPtr`, `GetSubViewPtr/PutSubViewPtr`, `RegisterToBackground` (16 calls), `MenuEnabled`;
  view `Load/Store` (streams) — next large step in `tv/`.
- Our units in `dn/new`: `vpsyslow` (+`SysTv*` over `TvScreen`), `dpmi32`, `dpmi32df`, `vputils`, `use16`, `memory`, `drivers`,
  `messages`, `dnapp`, `dnstddlg`, + `manual/*.inc` for shims. From archive: `LIB.D32` (`files`, `fltl`, `fnotify`, `events`,
  `country_`, `doslow`, `dn2pmapi`). Returned with segment rewrites: `FVIEWER`, `calendar`, `gauge`.

## 14. Compiling `dn.pas` for go32v2 (2026-10-02, night)

`DN_CROSS=<cross-compiler dir> TMPDIR=<tmp> tools/dn-try.sh dn.pas` compiles the tree with the DOS cross-compiler
(the real target: native `Dos` differs). The tree builds through `calc.pas` (dozens of units in a row).
- **Root found along the way:** `tools/ifdef-strip.py` was counting directives inside `(* ... *)` comments and strings
  (in `fltools` that broke `case`; also in `fltools` — `(* ... {$ELSE} !! *) new code`). Directives inside comments
  and strings are now skipped. Second finding: `STDEFINE.INC` takes the real-build branch (BIT_32, FILE_32, DualName, USELFN...)
  only if `VIRTUALPASCAL` is set — now in `DN_DEFINES` (`dn/target.env`). FPC does not see that symbol: branches are stripped.
- **`vpc.cfg` unit aliases** (`-ALFN=LFNVP;WINCLP=WINCLPVP`): `dn-materialize.sh` renames the file and `unit` and other
  mentions (two names — one unit, as in VP), then `tools/dedup-uses.py` removes duplicate `uses`.
- **Own `Menus` from the archive** (DN code, RIT; extended `TMenuItem`: `Flags`, `Param`, `miSubmenu`...) instead of a shim over
  `TvMenus`: shim removed, `menus.pas` compiles with small edits. `dnapp.pas` still uses `TvMenus` (TODO: switch
  to DN menus: `MenuBar`, `StatusLine`).
- **`tools/dn-carve.py` + `dn/carve.list`:** classes DN added itself in excluded files (`TComboBox` from `DIALOGS.PAS`)
  are carved into new tree units (`DNDlgs`); the unit is added to `uses` of units that name them. Next candidates:
  `THexLine`, `TParamText`, `TPage`, `TPageFrame`, `TNotepad`, `TNotepadFrame` (from compile errors).
- Own units: `objects2` (`TObject` from tv/, `ObjChangeType`), `strview`, `asciitab` (original was a Borland demo copy), `edwin`
  returned with segment rewrites (`dn/rewrite/edwin-*.rw`, raw 13% -> 0%).
- Edits (`dn/edits`): `70` (`for` loops with a mutable counter: `decoder`, `tetris`), `71` (double `+` in all files),
  `73` (`with` over a pointer), `80` (keys only on events, `Double`), `81` (`FileRec` names), `82` (`Comp` -> `Int64`),
  `83` (`as`), `84` (record field as loop counter), `85`, `86`, `87` (without `netbrwsr`), `88`, `89` (`TInputLine.Data^`),
  `91` (copy of `Bounds` in `ChangeBounds`), `92` (`Real48` -> `Double`), `93` (`TStreamRec` records -> tv/ factories, `RegisterAll`
  by name).
- tv/: `TWindow.Title` — `PStr` (as in Borland), `TDialog.DirectLink`, `TScrollBar.Step/ForceScroll`, `TInputLine.LC/RC/C`,
  command methods on `TView` and `MenuEnabled` (+`CommandHiddenHook`), `TFilterValidator.Init(set of Char)`,
  `TSortedListBox.NewList(PCollection)`, `TCollection.AtReplace`, `ModalCount`, `WindowNumberFreeHook` (`GetNum` in Views shim).
  tv tests and `dn/tests/t_objects2` pass.
- **Resources:** the archive has textual resource sources — `RESOURCE/ENGLISH|RUSSIAN|UKRAIN` (`dn.dnr` — dialogs and menus,
  `dn.dnl` — strings, `dnhelp.htx` — help), resource compiler `rcp.pas`. Without a built `DN.RES`, `LoadResource` is empty:
  next large step after compilation (build `rcp`, generate resources, `LoadResource`/`ExecResource`/`GetString`).
- Error tail in `calc.pas`: `TScrollBar.Min/Max` (in tv `MinVal/MaxVal`), `TFileDialog.GetFileName` with parameters,
  `Decimals`, loop with counter `I`; next — `Gauges` neighbors, `scroller`, `histlist`, `colorsel`, `validate`, `listmakr`, `tvhc`.
