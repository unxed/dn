# ZipCharset (Pascal)

In-tree port of [unxed/zipcharset](https://github.com/unxed/zipcharset)
`DecodeText` / `ParseUnicodeExtraField` for DN’s built-in ZIP reader
(`fmtzip`). Depends only on `dn/lib/localecp`.

Do not invent better heuristics: Unicode extra `0x7075`/`0x6375`, flag `0x800`,
creator OS/version → OEM vs ANSI vs raw-as-UTF-8 matches the Go package 1:1
(including known quirks).
