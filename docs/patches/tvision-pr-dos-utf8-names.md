# PR to magiblot/tvision (DOS: UTF-8 file names) and the comment in DOSBox-X #6632

Everything is prepared in the fork `unxed/tvision`, branch `dos-utf8-names` (one commit on top of `master`, pushed). The session cannot open a pull request in
`magiblot/tvision` (the repository is not its own): open it with this link and paste the text below.

https://github.com/magiblot/tvision/compare/master...unxed:tvision:dos-utf8-names?expand=1

Before opening: if `magiblot/tvision` `master` has moved, press "Sync fork" on the fork (the branch is one commit on the `master` of the fork, which I could not compare with upstream from here; it touches
`README.md`, `source/tvision/tapplica.cpp` and the new `source/tvision/dosutf8.cpp` only).

**Title:** DOS: optional switch of the long file names to UTF-8 (AMIS DOS-UTF8/NAMES), off by default

**Body:**

Since joncampbell123/dosbox-x#6632 DOSBox-X can give and take long file names (`INT 21h AH=71h`) in UTF-8 to a program that asks for it (AMIS, `INT 2Dh`, signature `DOS-UTF8` / `NAMES`, `AL=10h BX=65001`, read back with `AL=11h`; the mode belongs to the process).

This pull request adds `initDosUtf8()` (new `source/tvision/dosutf8.cpp`, called from `TAppInit`). It is **off by default**: with `TV_DOS_UTF8_NAMES=1` in the environment a 16-bit DOS build looks for the provider and sets the encoding. In 32-bit and non-DOS builds the function is empty.

**What this does not do (please read before merging).** It only switches the mode of the DOS. Turbo Vision itself does not call the long file name functions: `findfirst`, `fexpand`, `getcurdir` and the streams go through the Borland RTL, which uses the short names (`AH=4Eh` and others), and on DOS `TText` handles one byte as one character in the OEM code page (`include/tvision/ttext.h`, the `__BORLANDC__` branch; the UTF-8 code and the cp437 tables are in `source/platform`, which the DOS makefile does not build). So `TFileDialog` and friends do not get UTF-8 names from this, and if a program did pass UTF-8 names to them they would be shown byte by byte as OEM characters. It is useful only for a program that calls `INT 21h AH=71h` itself and converts the names. Making the library itself UTF-8 aware on DOS would need long-name versions of the directory functions plus UTF-8 to OEM conversion for display and editing; I did not attempt that here. If you think this plumbing alone is not worth having, please close the pull request.

**CI.** The first version failed in "DOS (BCC)" and "Windows (BCC32) (DPMI32)" at link time: `source/tvision/makefile` lists the objects of `tv.lib` explicitly, and `DOSUTF8.OBJ` was missing (fixed). The file also used `noexcept` without including `tv.h`, which defines it away for Borland C++ (fixed). The Linux jobs (GCC unity, Clang, tests) were reproduced locally and pass.

**Tested.** CMake builds (GCC unity with tests, Clang) on Linux. The logic of the 16-bit branch was run on Linux against a stub of `dos.h` and a model of the DOSBox-X AMIS handler (default: nothing is called; `=0`: nothing; `=1`: provider found, `AL=10h BX=65001`, read back). **Not tested:** compilation with Borland C++ 4.52 (no compiler here; the CI is the first test), real DOS, DPMI16 branch (`INT 31h AX=0002h`).

**Comment for joncampbell123/dosbox-x#6632** (English; optional, the PR is merged):

> A user of the new API: Turbo Vision (magiblot/tvision) asks for the `DOS-UTF8`/`NAMES` provider at start-up and then uses UTF-8 long file names: magiblot/tvision#<number of the pull request above>. Tested with the test client from this PR; thanks for the AMIS interface.
