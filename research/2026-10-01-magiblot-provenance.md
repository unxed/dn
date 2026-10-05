# Provenance of magiblot/tvision code (2026-10-01)

Goal: confirm that the magiblot/tvision portion we are translating contains only code from
the published Borland Turbo Vision 2.0 release and code by magiblot and co-authors (MIT).
In other words, that it did not pick up code from other ports (especially the GPL SET port)
or from Borland commercial products.

Tool: `audit/cclone.py` — same approach as `xclone.py` (verbatim chains of
24 tokens), but for C/C++ and with two references. Column `only%` — code that matches the
second reference and is absent from the first.

## Materials

- magiblot/tvision, full history (1361 commits, HEAD `b4831e2`). Root commit
  `adb6e3a` — “Version 1.03”, then `4a67222` — “Version 2.0”. Both dated 2019-01-02; these are
  imports of Borland releases. The 2.0 import has 201 files, only `include/` and `source/`,
  Borland mentioned in each.
- SET port (Salvador E. Tropea) 2.0.3 — archive `TV_2.03_sources.ver.2.03.English.7z`,
  http://old-dos.ru/dl.php?id=9393, sha256
  `34d27cffff01d0b38b199c035d040bb2b3e88c41935f63d9828dd4db033471ac`. This is not
  the original Borland release but a derived GPL v2 port; it contains `borland.txt`
  with Borland’s text. Its `readme.txt` names the original source
  (`ftp.inprise.com/pub/borlandcpp/devsupport/archive/turbovision/tv.zip`) and says that
  per Inprise this is a “Public Domain version”. Some SET examples came from the Sigala port (BSD).

## Results

**Translation scope — magiblot library:** `source/tvision`, `source/platform` and
`include/tvision` without `compat/`. That is 261 C/C++ files, 204k tokens.

1. Code from the GPL SET port that is absent from the Borland import was not found in the library.
   Longest such chains — 60, 53 and 53 tokens. In `tview.cpp` this is the
   `TView` constructor initializer list (field values from Borland code; both ports
   rewrote assignments into initializers). In `base64.cpp` — the table of numbers 26…51,
   in `codepage.cpp` — the alphabet “A”…“Z” in a table. Everything else — chains no longer than 43 tokens.
2. Code present in TV 1.03 and absent from TV 2.0 is 0.1 % of the library: one chain
   of 27 tokens (`tparamte.cpp`). Borland code in the library therefore comes from
   the 2.0 release.
3. 46.1 % of library tokens match the Borland 2.0 import verbatim. The rest
   was written by magiblot and co-authors (MIT).
4. The magiblot “Version 2.0” import matches the SET port verbatim on 52.6 % of tokens
   (SET heavily edited its files). That is consistent with shared origin from one
   Borland release.

## What we do not translate

- `examples/` (tvdemo, tvedit, tvhc, tvforms, etc.). The Borland 2.0 import has no examples,
  and they match the SET port 40–90 % outside the import. They are not part of the published
  TV release; they have different provenance. We write the help compiler for DN (`tvhc`) ourselves.
  The library help pieces (`helpbase`, `help`) are in the release.
- `include/tvision/compat/borland/` — Borland C++ RTL compatibility headers. Per
  history (`f9c6121`) some were copied from Borland C++ 4.0. Not needed in the Pascal translation.

## Cross-check against the published release

Source of the published release — https://github.com/FSharpCSharp/TurboVision, commit
`5b9182e` (“Adding the unzipped files published by Borland”, 2019-02-01). It has `Include/`,
`Source/`, `readme.txt` (Borland text “NOTE ON THE CONTENTS OF THIS ARCHIVE…”),
`disclaim.txt`.

Comparison with magiblot import `4a67222` (“Version 2.0”), file by file:
- 200 of 201 files match fully; difference only in line endings (CRLF) and the
  end-of-file character;
- `tv.h` differs only in the header comment: the published version has the
  warranty disclaimer and “Copyright (c) 1991, 1994”; magiblot has “Copyright (c) 1994”.
  Code matches token for token (2076 tokens).

Conclusion: Borland code in magiblot comes from the published TV 2.0 release. The
“Version 1.03” import (`adb6e3a`) is not in the published release, but code absent from 2.0
is 0.1 % of the current library (one 27-token chain, `tparamte.cpp`).

Caveat: `FSharpCSharp/TurboVision` is a third-party mirror. The canonical `tv.zip`
is on Sergio Sigala’s site, but was unreachable from the session (sigala.it — 403, web.archive
closed). The check against it can be repeated in CI.

## Links

- Published TV 2.0 release, unpacked: https://github.com/FSharpCSharp/TurboVision
- Sources page on Sergio Sigala’s site (TV port, BSD):
  http://www.sigala.it/sergio/tvision/resources.html#sources
- Borland `tv.zip`: http://www.sigala.it/sergio/tvision/borland/tv.zip,
  web.archive copy:
  https://web.archive.org/web/20170708213734/http://www.sigala.it/sergio/tvision/borland/tv.zip
- Original Borland/Inprise URL (from SET port `readme.txt`, currently unavailable):
  `ftp://ftp.inprise.com/pub/borlandcpp/devsupport/archive/turbovision/tv.zip`
- SET port 2.0.3 (GPL): http://old-dos.ru/dl.php?id=9393
- magiblot/tvision: https://github.com/magiblot/tvision
