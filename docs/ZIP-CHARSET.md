# ZIP single-byte charset (names and comments)

Status: **implemented (minimal DN listing path)**  
Recorded: 2026-10-05 (owner clarification); landed 2026-10-05

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

- Built-in ZIP listing: `dn/archives/fmtzip.pas` (`GetFile` name bytes) via
  `dn/lib/zipcharset` + `dn/lib/localecp`.
- Later: pack/unpack UI strings that round-trip names through ZIP headers
  (must stay consistent with the same rules); ZIP **comment** display path
  (decode API is ready; `GetFile` does not surface comments yet).
- Not a substitute for external `zip`/`unzip`/`7z` tools’ own name handling;
  DN’s **internal** reader must still match the references when it shows the
  panel listing.

## In-tree layout

| Path | Role |
|---|---|
| `dn/lib/localecp/` | Pascal seed of `localecp`: locale tables, Unix init, OEM/ANSI/System UTF-8 decoders (`localecp_tables.inc` from `tools/gen-localecp-tables.py`) |
| `dn/lib/zipcharset/` | Port of `DecodeText` / `ParseUnicodeExtraField` |
| `tv/src/tvlocale.pas` | Still the UI OEM page pick (OEM half of the same locale table); ZIP decode uses `localecp` |

Staged into the DN build by `tools/dn-env.sh` (`dn_stage`).

## Acceptance

- [x] Golden vectors from `zipcharset` tests decode identically in DN
      (`dn/tests/t_zipcharset.pas`).
- [x] Fixture + Go harness: `tools/test-zipcharset.py` writes
      `tools/testdata/zipcharset/cp866-privet.zip` and checks the reference
      `zipcharset` decoder → `привет.txt`.
- [ ] Manual: CP866 / CP1251 / flag-0x800 / `0x7075` archives in a UTF-8 DN
      panel match the Go harness (smoke left to owner / archives PTY).
- Document any intentional deviation only with owner approval (none expected).

## Remaining gaps

- Windows `GetACP` / `GetOEMCP` + UTF-8-ACP Far-style fallback not ported
  (Unix `LANG`/`LC_*` init matches `localecp_unix.go`).
- Multi-byte locale encodings (GBK, BIG5, CP932, CP949) are not decoded;
  same as a nil decoder → raw bytes (Go uses `htmlindex`).
- ZIP comment bytes are not shown by `fmtzip` yet (decode helper exists).
- ShortString 255-byte cap still truncates long UTF-8 expansions of OEM names.

## Related open work

- Class-migration: enter-archive AV / Broken archive (`override` on
  `GetFile`); Unix archiver command defaults (far2l multiarc).
- This charset task is **orthogonal** to Enter-archive crashes but blocks
  correct Cyrillic (and other legacy) names once listing works.
- Archive matrix: `docs/ARCHIVE-MATRIX.md`; status:
  `docs/CLASS-MIGRATION-STATUS.md` / checklist.
