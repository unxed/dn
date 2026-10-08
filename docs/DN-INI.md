# Settings of dn.ini that need a word of explanation

`dn.ini` lives in the configuration directory (`~/.config/dn/` on Linux, `DN2` overrides it). The comments in the file `dn/data/dn.ini` describe every
line; this page keeps the ones whose meaning is not obvious. The file is UTF-8.

## Scroll bar characters (section `[Interface]`)

```
VertScrollBarChars=▲▼▒■▓
HorizScrollBarChars=◄►▒■▓
```

Each value is a string of **five characters**, in this order:

1. the arrow at the start (top, left),
2. the arrow at the end (bottom, right),
3. the page area (the track between the arrows),
4. the thumb,
5. the track of a bar that has nothing to scroll.

* Write them as ordinary Unicode text. In a build with UTF-8 inside (the Linux one) any character is drawn as it is (`↑↓▒■▓` works, so does the
  plain ASCII `^v:#.`).
* In the DOS build the characters are turned into the bytes of the current code page (`GlyphsToPage`); a character that the page lacks becomes its plain
  sign (`CpFallback`: `^`, `v`, `#` ...), else `?`.
* The old form of the value, the bytes of a code page (`VertScrollBarChars=` followed by the bytes `1E 1F B1 FE B2`), is still read; a value that is
  not valid UTF-8 is taken this way.
* The characters are applied when `dn.ini` is read (`ApplyIniVars`, also when the file comes from the cache), so a change needs a restart of DN.

Test: `python3 tools/dn-linux-scrollchars.py OUTDIR` (the defaults, ASCII characters, a long list with a thumb, characters outside the code page, the old
form).

## Other settings with a test

* `DefaultSortMode=name|ext|size|date|unsorted`: the sort of the preset panels of a DN that has no saved setup (`t_defsort`).
* `[XLat] Enabled=`: hot keys on a non-Latin layout; more layouts in `xlat.txt` next to `dn.ini` (`tv/tests/t_xlat.pas`).
