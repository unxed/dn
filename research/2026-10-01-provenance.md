# Provenance of DN code and choice of TV base (2026-10-01)

## Tool

`audit/xclone.py`. Reference — Borland sources from the BP 7.0 + 7.01 archive
(`audit/fetch_reference.sh`, 72 files: TV units, Strings, TV demos and examples, Memory from
Graph Vision 2.3 examples).

Code is split into tokens; comments, markup and case are discarded. We look for chains
of 24 consecutive tokens (roughly 2–3 lines of code) that exist in Borland.

- `raw%` — fraction of the file’s tokens covered by such chains verbatim, with the same
  identifiers. Main metric. Clean code is 0–1 %: DN archivers are 0 %.
- `maxrun` — longest continuous matching chain. A chain of 100+ tokens does not arise
  by chance.
- `impl%` — same as `raw%`, but only over the `implementation` section.
- `ren%` — same with identifiers replaced by `ID`. Noisy: for code unrelated
  to Borland it is 5–10 %.

Line-by-line comparison does not work: it misses reformatted code. So
we compare tokens.

## Borland code in DN sources

Tables: `audit/reports/2026-10-01/dn151.txt` (DN 1.51) and `dnosp214.txt` (DN OSP 2.14,
archive `dn2s214.rar`).

Borland code is not limited to files with a Borland copyright. In DN OSP, besides the TV units
themselves, it appears in: `scroller` (from Views), `HELPKERN` and `helpfile` (from the HelpFile demo), `DNStdDlg`
(StdDlg), `DNAPP` (App), `asciitab`, `messages` (MsgBox), `gauge(s)` (TVFM demo), `listmakr`,
`COLLECT`, `_collect`, `_streams`, `_defines` (Objects/Views), `tvhc`, partly `FVIEWER`.
Searching by headers alone misses all of this.

DN 1.51 copies where “clean” TV was already replaced are not a purity baseline: the check
found TV leftovers in one of them.

## Audit limits

- For Drivers, Menus and TextView there is no Borland source: 0 % proves nothing there.
- Paraphrase with renaming and reordering is caught poorly (`ren%` is noisy).
- Borland code absent from the reference (TV 1.0 from TP 6, RTL) is not caught at all.

## Choice of TV base

Options considered:

1. **Own TV from scratch against a spec.** Cleanest option, but also the most expensive: design
   everything anew, including Unicode.
2. **Free Vision.** LGPL is not a blocker here: FV, like the whole FPC RTL, has a static-linking
   exception. It explicitly allows linking FV into one binary with modules under
   any license and distributing the result on your terms; otherwise DN could not be
   built with FPC at all, since System is the same license. Not chosen because of provenance: by
   its own headers FV interfaces say “Copyright Borland”, and `stddlg.pas` is called
   a “port of StdDlg.pas from Borland”. That is Pascal-TV from commercial BP7, which Borland did not
   publish. To get clean, a large part of FV would need rewriting, and Unicode
   there is UTF-16.
3. **Translate `magiblot/tvision` (C++) to Free Pascal — chosen.** It descends from C++ Turbo
   Vision 2.0, whose sources Borland published itself (“Borland International made
   the Turbo Vision source code public…”; warranty disclaimer, no explicit license). magiblot
   changes are MIT. Since 1997 the Sigala, SET and magiblot ports have distributed it openly.
   What we get immediately:
   - UTF-8 inside (what we need);
   - platform layer: far2l extensions (`far2l.cpp`), kitty protocol and OSC 52
     (`termio.cpp`), Unix clipboard, Linux and Win32 consoles, CP437 remapping;
   - a living upstream.

   Size: core about 25k lines (190 files), platform 7.2k.

Caveat on option 3: Borland published the code without an explicit license. That is not the same as
an open license, but it is the strongest available option for TV: the rights holder
published the code themselves.
