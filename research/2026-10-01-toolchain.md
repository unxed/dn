# FPC → DOS (go32v2) toolchain in CI (2026-10-01)

Green run: https://github.com/unxed/dn/actions/runs/36927004962 (commit `6642bd9`,
workflow `toolchain`, about 2 minutes). Verified: `hello.pas` compiles
with the cross-compiler to `HELLO.EXE`, which runs in DOSBox-X headless and prints
`hello from go32v2` (the step checks the string via `grep`).

## How it is built

- `tools/build-fpc-go32v2.sh PREFIX`: FPC 3.2.2 sources from GitLab (tag `release_3_2_2`),
  bootstrap compiler — `fp-compiler` from apt, DJGPP binary tools — release
  `andrewwutw/build-djgpp` (`djgpp-linux64-gcc1220.tar.bz2`). `make crossall` and
  `crossinstall` with `OS_TARGET=go32v2 CPU_TARGET=i386 BINUTILSPREFIX=i586-pc-msdosdjgpp-`.
  Result — wrapper `PREFIX/bin/fpc-go32v2`. Result is cached by script hash.
- Linker: DJGPP `ld` with `OUTPUT_FORMAT("coff-go32-exe")`; stub is inserted automatically.
  Separate `exe2coff` and `stubify` are not needed.
- DPMI host: DOSBox-X without an external host reports “Load error: no DPMI - Get csdpmi*b.zip”.
  Workflow downloads `https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip`
  and places `CWSDPMI.EXE` next to the program. The host is not committed to the repo.

## What went wrong (for later sessions)

- Ubuntu package `fpc-source-3.2.2` (and its stub `fpc-source`) is unsuitable for cross-build:
  it lacks the top-level `Makefile` (`crossall` targets) and the `compiler/msg` directory.
- `apt install fpc` pulls GTK, SDL, etc.: install takes 13 minutes. Only
  `fp-compiler fp-units-rtl` are needed.
- Installed units live under `lib/fpc/3.2.2/units/go32v2/<package>`, not
  `.../i386-go32v2`.
- From a Claude session `delorie.com`, `old-dos.ru`, `web.archive.org`, `sigala.it` are unreachable;
  in CI they are available (delorie verified by this run).

## Not verified

- How an FPC program behaves without `CWSDPMI.EXE` under FreeDOS and under Windows (NTVDM):
  that is the milestone 5 matrix.
- CWSDPMI redistribution license: for now it is only downloaded in CI and not
  published as a release artifact.

## CI verification (commit `a73efc4`, runs `36927921007` and `36927920980`)

- Workflow `audit`: Borland reference is downloaded in CI (`audit/fetch_reference.sh`,
  sha256 matched, 72 files unpacked, `unrar` from apt), detector self-test on the
  corpus — 100 % (`TOTAL 6 files, 58256 tokens: raw 100.0%`). Download from
  web.archive.org or old-dos.ru from CI works (which of the two sources
  succeeded is not shown in the log).
- Workflow `toolchain` from cache (cache ~97 MB, full run ~45 seconds): compile
  `hello.pas` and run in DOSBox-X yield `hello from go32v2`. Artifact `hello-go32v2`
  (`HELLO.EXE` and `OUT.TXT`).
- Archive `csdpmi7b.zip` (CWSDPMI r7, 2010) contains `bin/CWSDPMI.EXE`, `CWSDPR0.EXE`
  (ring 0), `CWSPARAM.EXE`, `CWSDSTUB.EXE` (stub with built-in host) and
  `bin/cwsdpmi.doc` with redistribution terms. First attempt to read them in the log
  failed: wrong path inside the archive; fixed in a separate task
  `cwsdpmi-license`.

## CWSDPMI r7 license (from `bin/cwsdpmi.doc`, read in CI: task `cwsdpmi-license`)

Copyright 1995–2010 Charles W Sandmann. Quote: “The files in this binary distribution may
be redistributed under the GPL (with source) or without the source code provided”:
- `CWSDPMI.EXE` and `CWSDPR0.EXE` are not modified except via `CWSPARAM`;
- internals of `CWSDSTUB.EXE` are not modified except via `CWSPARAM` or `STUBEDIT`
  (a COFF image and data may be appended);
- users are told they have the right to obtain sources and updated
  CWSDPMI binaries; the distributor points in documentation to a site with sources.

Conclusion: `CWSDPMI.EXE` may be placed in DN release archives unchanged if `cwsdpmi.doc`
is included and the source location is stated (link in release docs). Choice:
- default — `CWSDPMI.EXE` next to the program (as in CI);
- single-file option: `CWSDSTUB.EXE` + program COFF image (`copy /b`), see `cwsdpmi.doc`.
HDPMI32 terms (HX project) were not reviewed; whether it is needed will be decided from milestone 5
results (FreeDOS, NTVDM).
