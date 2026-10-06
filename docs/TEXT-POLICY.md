# Text policy: language and encoding

Rules for everything that is tracked in git (checked by `tools/tests/test_text_policy.py`):

1. Comments, documentation, hard-coded strings and the English resources are in **English**.
2. Text files are **UTF-8**. CP866 (and other legacy code pages) is not used for sources or docs.
3. The only places with Russian or Ukrainian text are the cases below.
4. There is no Virtual Pascal build any more (Free Pascal only). Borland and VP are named only to say
   where the starting sources came from (`dn/PROVENANCE.md`, `bootstrap/`, `audit/`) or what a
   compatibility unit replaces.

Run: `python3 -B -m unittest discover -s tools/tests -p 'test_text_policy.py'`

## Allowed: Cyrillic on purpose

| Files | Why |
|---|---|
| `dn/src/resource/russian/`, `dn/src/resource/ukrain/` | the localizations |
| `dn/archives/fmtain.pas` | matches the Russian output of the AIN archiver (`Pos('...', s)`), a function, not a comment |
| `dn/tests/t_dnutf8.pas`, `t_drivrs.pas`, `t_zipcharset.pas`, `tools/dn-linux-*.py`, `tools/test-zipcharset.py`, `tools/tests/test_source_encoding.py` | test data: Cyrillic names and text |
| `docs/ZIP-CHARSET.md`, `docs/patches/` | examples with Cyrillic file names and text |
| `dist/*/screenshots/viewer.txt` | sample text for the viewer encodings |

## Allowed: not UTF-8 on purpose

| Files | Why |
|---|---|
| `dn/data/xlt/`, `dist/*/xlt/` | the code page tables (data) |
| `dn/data/dn.ini`, `dist/*/dn.ini` | the values `VertScrollBarChars` / `HorizScrollBarChars` hold CP437 glyph bytes that DN reads as is. The comments (lines with `;`) are English, the test checks it |

## Not fixed (out of the scope of the cleanup; no decision yet)

- The Russian and Ukrainian resource texts have Latin look-alike letters inside words (the author's old habit: a Russian surname with a Latin `p`; the Ukrainian letter i written as Latin `i` or as the Belarusian short u). They are left as they are: see `dn/TODO-later.md`.
- The `Objects` word is still in docs on purpose: the Borland unit name in provenance texts, and the old name in
  `dn/renames.map` (`objutil.pas objects2.pas`). The unit `Objects` itself is not used (the shim is removed).
- The English help sample of number suffixes had the Russian-letter forms (`1.2к`, `1.2мк`); they are removed from the text. Whether the program accepts them is not checked.

## The DOS build and the code pages

The sources are UTF-8 only. The build of DOS (without `-dDNUTF8`) lands the resources (`dn.dnl`, `dn.dnr`) and the help (`dnhelp.htx`) of every language
on the code page of the language with `tools/to-codepage.py`: `cp866` for English and Russian (`DN_CODEPAGE`), `cp1125` for Ukrainian
(`DN_CODEPAGE_UKRAIN`; the DOS machine must have this page loaded to show the Ukrainian letters). A character that the page has is kept, else the
letter without marks (`Győr` becomes `Gyor`), else a plain sign for a few symbols, else `?`; never a letter of another script. The lost characters are
listed by the build. The builds with `-dDNUTF8` (Linux, Windows) use the files as they are.

## One script per word

A word of the Russian and Ukrainian resources is in one script. The old texts were typed with Latin look-alikes inside Cyrillic words (a Latin `p`
for the Russian `r`, the Latin `i` for the Ukrainian `i`, the Belarusian short u as `i`) and with Cyrillic look-alikes inside English words (`ESC`, `Ctrl`);
`tools/fix-resource-lookalikes.py` repaired them once (it can be run again: nothing changes) and the test keeps it. The only mixed words are the
abbreviations with a Russian ending (`DN`, `FAT` + one Cyrillic letter) and the button `OK` is Latin in all the languages.
