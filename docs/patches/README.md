# Patches for other projects

## `dosbox-x-amis-utf8-clipboard.patch`: INT 2Dh (AMIS) and the UTF-8 clipboard text for DOSBox-X

A patch for `git am` on top of `joncampbell123/dosbox-x` `master` (made 2026-10-03, checked on a build with SDL2 on Linux). It adds the AMIS interface
(`INT 2Dh`) and the provider `DOS-UTF8` / `CLIPBRD`: a DOS program asks (`AL=10h`, `BX=65001`) for UTF-8 text in the DOS clipboard API (`INT 2Fh AX=17xxh`,
formats 01h and 07h) instead of the OEM code page. The mode belongs to the calling process. The specification and a second implementation are in
`unxed/go2dos` (branch `claude/utf8-clipboard`: `docs/UTF8CLIPBOARD.md`, `dos/utf8clip.go`, the test client `testdata/progs/utf8clip.asm`).

Check (the client is in `dosbox-x-test/utf8clip.asm`, `nasm -f bin -o UCLIP.COM utf8clip.asm`):

    printf '[dos]\ndos clipboard api = true\n' > t.conf
    SDL_VIDEODRIVER=dummy dosbox-x -silent -nogui -noconsole -defaultconf -conf t.conf -c "mount c DIR" -c "c:" -c "UCLIP.COM > OUT.TXT" -c "exit"

The answer must have `SET=FF PREV=0000`, `SETC=0001`, `SIZE2=00000015` (the text "Привет", CR LF, "мир" as UTF-8 and the final 0), `MODE=FDE9`; with
`dos clipboard api = false` it prints `NOT FOUND`.

## `dosbox-x-utf8-names.patch`: UTF-8 file names for DOSBox-X (stacked on the clipboard patch)

Made as `git diff claude/amis-utf8-clipboard claude/utf8-names` (branch `unxed/dosbox-x` `claude/utf8-names`); apply after the clipboard patch. Option `[dos] utf8 file names`:
the characters that the code page lacks are kept in the names as `{U+XXXX}` so no file is hidden, and a program that asks (AMIS `DOS-UTF8` / `NAMES`, `AL=10h BX=65001`)
gets UTF-8 long names. The PR text is `dosbox-x-pr-utf8-names.md`. Tests (nasm -f bin): the go2dos client `testdata/progs/utf8names.asm` and `dosbox-x-test/utf8names-create.asm`
(creates `716Ch` and renames `7156h` with UTF-8 names). Config for the check: `[dos]` `utf8 file names = true`, `lfn = true`, `ver = 7.1`.

The Windows part of the clipboard patch (`CF_UNICODETEXT`) is written but was not compiled.
