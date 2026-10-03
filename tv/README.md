# tv: Turbo Vision in Free Pascal

A translation into Pascal of the C++ library [magiblot/tvision](https://github.com/magiblot/tvision)
(commit `b4831e2`) in the style of Pascal Turbo Vision: `object`, `Init`/`Done`, `New(P, Init(...))`,
`TView.HandleEvent`. The text inside is UTF-8; single-byte strings are shown through a code
page (a setting).

## License

- The translated units are a derivative work of magiblot/tvision, and so of the Turbo Vision 2.0
  release published by Borland: the Borland disclaimer and the MIT license of magiblot apply
  ([`COPYRIGHT.magiblot`](COPYRIGHT.magiblot)). The header of each such unit names the magiblot
  files it was translated from.
- The units written for this port (`TvSys`, `TvMem`, `TvDos`, `TvUtil` in the part that was not
  translated from magiblot, the tests, the demos) are under the MIT license ([`LICENSE`](LICENSE)), so
  that the package as a whole has one clear license. Their header says "Written for this port".
- DN (the `dn/` directory of the repository) has another license. No code is copied between `tv/` and `dn/`;
  `tv/` does not depend on `dn/`.

## Contents

`src/` holds the units (the list and the correspondence to the magiblot files are in [`DESIGN.md`](DESIGN.md)),
`tests/` the tests on the "in memory" backend (they run both natively and under DOS), `dostests/` the
tests of the DOS backend (in DOSBox-X only), `demo/` the demos.

## Build and check

    cd tv/tests
    for t in t_*.pas; do fpc -Fu../src -Fu. $t && ./${t%.pas}; done   # each prints "ALL OK"

Under DOS: `tools/build-fpc-go32v2.sh` and `tools/dos-run.sh` (see `.github/workflows/tv.yml`).

## How to use it in your project

Add `tv/src` to the unit path (`-Fu`); in the program use `TvApp` (the application),
`TvViews`, `TvWindow`, `TvMenus` and a backend: `TvDos` under DOS or `TvMem` in tests.
The minimal example is `demo/tvdemo.pas`.
