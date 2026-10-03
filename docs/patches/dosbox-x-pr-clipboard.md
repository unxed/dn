# PR to joncampbell123/dosbox-x (the clipboard part)

Branch: `unxed/dosbox-x` `claude/amis-utf8-clipboard` (pushed). The session cannot open a PR in a repository that is not its own: open it with this link and paste the text below.

https://github.com/joncampbell123/dosbox-x/compare/master...unxed:dosbox-x:claude/amis-utf8-clipboard?expand=1

**Title:** DOS: INT 2Dh (AMIS) and the provider DOS-UTF8/CLIPBRD: UTF-8 text of the DOS clipboard API

**Body:**

Adds the AMIS interface (`INT 2Dh`, Alternate Multiplex Interrupt Specification 3.6) and its first provider, `DOS-UTF8` / `CLIPBRD`.

**Why.** The DOS clipboard API (`INT 2Fh AX=17xxh`, formats `CF_TEXT` / `CF_OEMTEXT`) carries text in the OEM code page, so characters outside it are lost on the way in both directions (Greek copied from a browser into a CP866 program, and back). A DOS program that is UTF-8 inside cannot do better than the page.

**What.** A program finds the provider with AMIS (for each `AH=00h..FFh`, `INT 2Dh` with `AL=00h`; the provider answers `AL=FFh` and `DX:DI` points to the signature `DOS-UTF8` + `CLIPBRD `). It then calls `AL=10h BX=65001` to get UTF-8 text from `1703h` / `1704h` / `1705h` instead of the OEM code page (`BX=0` goes back; `AL=11h` reads the mode). The mode belongs to the calling process (current PSP) and ends with it; `EXEC` does not inherit it, so programs that do not know about it see no change. The provider is present only when `dos clipboard api=true`, like the API itself. `AH=C0h` is the first number of the providers (the specification reserves none; the first free one from C0h is taken).

**Details.**
- `src/dos/dos_misc.cpp`: the INT 2Dh handler (installation check, the standard AMIS functions 01h-06h, private functions 10h and 11h), the per-process mode, the UTF-8 branches of `1703h`/`1704h`/`1705h` (UTF-8 is validated, invalid bytes become U+FFFD; CR LF on the wire, LF on the host; the 1 MB limit is cut at a character boundary).
- `src/misc/clipboard.cpp`: `DOS_ClipboardGetUTF8` / `DOS_ClipboardSetUTF8` (SDL2: `SDL_GetClipboardText` / `SDL_SetClipboardText`; Windows: `CF_UNICODETEXT`; other hosts return false and keep the OEM path).
- `src/dos/dos_execute.cpp`: the mode ends with the process.

**Specification and a second implementation:** https://github.com/unxed/go2dos (`docs/UTF8CLIPBOARD.md`, `dos/utf8clip.go`; the same interface as its `DOS-UTF8/NAMES` provider for UTF-8 file names).

**Tested** on Linux with SDL2 (headless): a small DOS client finds the provider, turns UTF-8 on, sets "Привет" CR LF "мир", and reads the size back as UTF-8 (21 bytes with the final 0; in OEM mode the same text takes 20), mode FDE9; with `dos clipboard api=false` the provider is not found. The Windows branch (`CF_UNICODETEXT`) was written but not compiled.

UTF-8 file names (`DOS-UTF8/NAMES`) are not included: the drive cache keeps names in the guest code page, so that needs a separate, larger change, which will be its own PR.
