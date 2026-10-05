# ZIP single-byte charset (names and comments)

Status: **specified; not implemented in DN yet**  
Recorded: 2026-10-05 (owner clarification)

## Requirement

When DN reads ZIP central/local headers, **one-byte** filename and comment
fields must be decoded with logic that is **1:1 with the reference projects,
including bugs**:

| Layer | Reference | Role |
|---|---|---|
| Locale → OEM / ANSI code pages | [unxed/localecp](https://github.com/unxed/localecp) | Host locale → legacy OEM and ANSI encodings (and codepage numbers where the platform has them) |
| ZIP name/comment decode | [unxed/zipcharset](https://github.com/unxed/zipcharset) | Extra fields `0x7075` / `0x6375`, flag 0x800, creator OS / version → OEM vs ANSI vs “raw as UTF-8”, then `localecp` decoders |

Do **not** invent a “better” heuristic. Port or call the same decision tree as
`zipcharset.DecodeText` / `ParseUnicodeExtraField` and the same locale tables
and platform init as `localecp` (Unix `LANG`/`LC_*`; Windows `GetACP` /
`GetOEMCP` with the UTF-8-ACP Far-style legacy fallback).

UTF-8 path (flag 0x800, Info-ZIP Unicode extra fields, Unix/MacOSX creator)
stays as in `zipcharset`: prefer Unicode extra when CRC matches; otherwise
treat bytes as UTF-8 when the flag or creator says so.

## Where it applies in DN

- Built-in ZIP listing: `dn/archives/fmtzip.pas` (`GetFile` name bytes) and any
  comment display path.
- Later: pack/unpack UI strings that round-trip names through ZIP headers
  (must stay consistent with the same rules).
- Not a substitute for external `zip`/`unzip`/`7z` tools’ own name handling;
  DN’s **internal** reader must still match the references when it shows the
  panel listing.

## Subproject split (locale codepage)

`localecp` is already a reusable Go library. For DN and other native
consumers, **locale → OEM/ANSI deduction should live in a small shared
subproject** (Pascal unit and/or keep publishing Go `localecp`), so:

- DN, other archivers, and tools share one mapping;
- `zipcharset`-equivalent ZIP heuristics can depend on that subproject only;
- others can reuse locale detection without pulling ZIP code.

Existing seed in-tree: `tv/src/tvlocale.pas` already carries the OEM side of
`localecp`’s `lcToOemTable` (for DOS/host codepage pick). That is **not** yet
the full `localecp` API (ANSI, Windows ACP/OEMCP + UTF-8-ACP fallback,
encoders/decoders) nor `zipcharset`. Grow or extract from there rather than
forking a second table.

Suggested shape (implementation order, not binding names):

1. **Locale CP subproject** — tables + Unix/Windows init, API shaped like
   `localecp` (`OEMDecoder` / `ANSIDecoder` / `SystemDecoder`, codepage
   numbers). Tests locked to `localecp` fixtures where practical.
2. **ZIP charset layer** — port of `zipcharset` on top of (1), used by
   `fmtzip` (and any future ZIP writers).

Exact repo layout (in-tree library vs sibling GitHub repo) is chosen when
implementation starts; the behavioral lock to the two GitHub projects is
mandatory either way.

## Acceptance

- Golden vectors from `zipcharset` / `localecp` tests (and known buggy
  corner cases) decode identically in DN.
- Manual: CP866 / CP1251 / flag-0x800 / `0x7075` archives show the same
  names as a small Go harness using `zipcharset` on the same files.
- Document any intentional deviation only with owner approval (none expected).

## Related open work

- Class-migration: enter-archive AV / Broken archive (`override` on
  `GetFile`); Unix archiver command defaults (far2l multiarc).
- This charset task is **orthogonal** to Enter-archive crashes but blocks
  correct Cyrillic (and other legacy) names once listing works.
