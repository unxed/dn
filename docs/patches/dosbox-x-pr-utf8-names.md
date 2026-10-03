# PR to joncampbell123/dosbox-x (the UTF-8 file names part)

Branch: `unxed/dosbox-x` `claude/utf8-names` (pushed). It is **stacked on the clipboard PR** (`claude/amis-utf8-clipboard`, see `dosbox-x-pr-clipboard.md`): it uses the AMIS interface from there, so open the clipboard PR first (or retarget this one after it is merged). The session cannot open a PR in a repository that is not its own: open it with this link and paste the text below (until the clipboard PR is merged the compare view also shows its commit).

https://github.com/joncampbell123/dosbox-x/compare/master...unxed:dosbox-x:claude/utf8-names?expand=1

**Title:** DOS: UTF-8 file names: option "utf8 file names", escape {U+XXXX}, AMIS provider DOS-UTF8/NAMES

**Body:**

DOSBox-X keeps every name in the guest code page, so a host file whose name has a character that the page lacks (Cyrillic under CP437, CJK under CP866, ...) is skipped in directory listings, and cannot be opened by a DOS program at all.

**What.** New option `[dos] utf8 file names` (default false, deactivated in the secure mode):

1. *Escape form (every program).* The conversion host -> guest turns a character that the code page lacks into `{U+XXXX}` (4 to 6 hexadecimal digits of the code point) instead of failing; the conversion guest -> host turns the escape back into the character. The file is visible under the escaped name and can be opened, created, renamed and deleted. A host name that has the text `{U+` itself gets its `{` escaped as `{U+007B}`.
2. *UTF-8 for programs that ask (AMIS `DOS-UTF8` / `NAMES`).* `AL=10h BX=65001` makes the long file name functions of the calling process (`INT 21h AH=71h`) take and return UTF-8 (`BX=0` goes back, `AL=11h` reads the mode; the mode belongs to the process and is not inherited). Invalid UTF-8 in input is error 2; short names are ASCII; `6502h`/`6504h` return identity tables for 80h-FFh and `6520h`-`6522h` leave those bytes alone, so table-driven case conversion cannot corrupt UTF-8; a long name that does not fit the buffer is replaced by its escaped/short form.

**Details.**
- `src/dos/dos_utf8names.cpp` (new): the provider, the escape conversions, the UTF-8 border helpers.
- `src/dos/drive_local.cpp`: the four `CodePage{Host,Guest}To{Guest,Host}UTF{8,16}` functions are renamed `*_Core` (unchanged); the public names are wrappers in the new file that call `_Core` when the option is off, so nothing changes by default.
- `src/dos/dos.cpp`: the 71xx handlers read names through `DOS_LFN_StrCopy` and write them through `DOS_LFN_NameWrite` / `DOS_LFN_FindData` (identity when the process is not in the UTF-8 mode); input check at the dispatcher; the 65xx tables.
- Config option in `src/dosbox.cpp`, `src/misc/programs.cpp` (changeable at run time), AMIS table in `dos_misc.cpp`, `dos_execute.cpp` (mode ends with the process), `Makefile.am`, `vs/` project files, `CHANGELOG`.

**Specification and a second implementation:** https://github.com/unxed/go2dos (`docs/UTF8NAMES.md`, `dos/utf8names.go`).

**Tested** on Linux with SDL2 (headless) with a host file `дом 世界.txt` and `dos utf8 file names = true`, `lfn = true`: `DIR /B` shows `{U+0434}{U+043E}{U+043C} {U+4E16}{U+754C}.txt`; the go2dos test client `utf8names.com` finds the provider and gets `D0B4D0BE D0BC20 E4B896 E7958C 2E747874` (the UTF-8 long name) with the UTF-8 mode on and the escaped name with it off; an invalid UTF-8 pattern gives error 2; a test client creates (`716Ch`) and renames (`7156h`) files with UTF-8 names and the host has them with the right UTF-8 names. Not tested: Windows host (the wrappers use the existing UTF-16 conversions), DBCS code pages, overlay/FAT/ISO drives beyond what shares the wrappers.

**Known limits.** The short name of such a file is an ordinary DOSBox-X mangled one (it can contain `{`); no numeric-tail uniqueness is guaranteed for non-ASCII names beyond what DOSBox-X already does. The escape is also used by the other users of the conversion (mount paths, CD-ROM names) when the option is on.
