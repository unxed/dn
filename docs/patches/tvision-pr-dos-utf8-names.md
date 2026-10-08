# PR to magiblot/tvision (DOS: UTF-8 file names) and the comment in DOSBox-X #6632

Everything is prepared in the fork `unxed/tvision`, branch `dos-utf8-names` (one commit on top of `master`, pushed). The session cannot open a pull request in
`magiblot/tvision` (the repository is not its own): open it with this link and paste the text below.

https://github.com/magiblot/tvision/compare/master...unxed:tvision:dos-utf8-names?expand=1

Before opening: if `magiblot/tvision` `master` has moved, press "Sync fork" on the fork (the branch is one commit on the `master` of the fork, which I could not compare with upstream from here; it touches
`README.md`, `source/tvision/tapplica.cpp` and the new `source/tvision/dosutf8.cpp` only).

**Title:** DOS: ask the DOS for UTF-8 file names when it offers them (AMIS DOS-UTF8/NAMES)

**Body:**

Since joncampbell123/dosbox-x#6632 DOSBox-X can give and take long file names in UTF-8 to a program that asks for it; the DOS of [go2dos](https://github.com/unxed/go2dos) does the same. The protocol is the AMIS interface (`INT 2Dh`): the provider has the signature `DOS-UTF8` / `NAMES`, and `AL=10h BX=65001` (read back with `AL=11h`) switches the long file name functions (`INT 21h AH=71h`) of the calling process to UTF-8. The mode belongs to the process.

This pull request makes a DOS build of Turbo Vision ask for it once, in `TAppInit` (the first `TApplication`):

- new `source/tvision/dosutf8.cpp`: `initDosUtf8()` looks for the provider (`INT 2Dh`, the signature is read at the real mode address that the installation check returns; under DPMI through function 0002h) and sets the encoding. The whole file is `#if defined(__BORLANDC__) && defined(__MSDOS__)`: on every other platform `initDosUtf8()` is empty, so nothing changes.
- `source/tvision/tapplica.cpp`: `initDosUtf8()` is called from `TAppInit::TAppInit()`.
- `TV_DOS_UTF8_NAMES=0` in the environment keeps the code page of the DOS.
- `README.md`: one paragraph in the DOS section.

The file names that the program passes to `TFileDialog`, `TDirListBox`, `fexpand` and so on are then UTF-8, which is what the rest of the library already assumes on the other platforms. On a DOS without the provider the installation check finds nothing and the program runs as before.

Both build systems pick the new file up (`source/CMakeLists.txt` and the Borland `makefile` use wildcards).

**Tested.** The Linux (CMake) build of the library compiles with the change. The protocol side was tested against DOSBox-X with the go2dos client `utf8names.com` (finds the provider, gets the UTF-8 name with the mode on, the escaped name with it off). **Not tested:** the Borland C++ build (DOS16, DOS32 with PowerPack) of `dosutf8.cpp` itself: I have no Borland compiler, so please treat the DPMI/real-mode access (`MK_FP` after `INT 31h AX=0002h`) as needing a look by someone who has one. A `far` pointer in the DOS32 flat model may need `_farptr`-style access instead.

**Comment for joncampbell123/dosbox-x#6632** (English; optional, the PR is merged):

> A user of the new API: Turbo Vision (magiblot/tvision) asks for the `DOS-UTF8`/`NAMES` provider at start-up and then uses UTF-8 long file names: magiblot/tvision#<number of the pull request above>. Tested with the test client from this PR; thanks for the AMIS interface.
