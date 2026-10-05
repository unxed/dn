# Archive matrix: nested formats, ops, autotests

Status: **in progress** (owner report 2026-10-05; nested `.tgz`/`.tar.gz` Enter fixed 2026-10-05)  
Depends on: plain zip/7z Enter already fixed (`override` on `fmt*` + drive hierarchy).

**Done so far:** Unix `fmttgz` lists tar-in-gzip members (gunzip + tar headers; GNU `tar`
defaults for pack/unpack). Fixture generator `tools/gen-archive-fixtures.py` + PTY
smoke `tools/dn-linux-archives.py` (zip / 7z / tar / tgz / tar.gz Enter+leave).

## Symptoms (user)

- Nested / compound archives do not work (`.tar.gz`, `.tgz`, and similar).
- Entering some archives sometimes ends in Fatal Error / Access violation.
- Once: internal editor hung when opening a file from inside an archive
  (F3/F4 path).

Plain Enter on simple `aaa.zip` / `aaa.7z` listing `inside.txt` is **not**
enough to close archives for the class gate.

## Required work

### 1. Generate a fixture set of typical archives

Build (scripted, reproducible) at least:

| Kind | Examples | Notes |
|---|---|---|
| Simple | `.zip`, `.7z`, `.tar`, `.gz`, `.bz2`, `.xz` | Single member `inside.txt` |
| Nested / compound | `.tar.gz` / `.tgz`, `.tar.bz2`, `.tar.xz`, zip-in-zip if DN supports nesting | Outer enter + inner member / nested enter |
| Optional if tools present | `.rar`, `.cab`, `.iso` (via 7z) | Skip cleanly when packer missing |
| Layout | dirs inside archive, mixed names | Catch path/`..` / slash bugs |

Prefer generating under `tools/` (e.g. `tools/gen-archive-fixtures.py`) into a
temp or `tools/testdata/archives/` tree that CI can recreate; do not commit
huge binaries if generation is cheap.

### 2. Manual / PTY click-through (class build)

For each fixture, on the latest class Linux build:

1. Enter archive (panel shows listing; no Broken/Fatal/`dn.err`).
2. Leave archive (back to parent dir).
3. Basic ops where applicable: F3 view member, F4 edit member (must not hang),
   F5 extract/copy out, cancel/error paths.
4. For nested types: enter outer → see inner archive or unpacked tree as DN
   designs it; enter nested level if the UI allows; leave cleanly.

Record failures with format, step, screen/`dn.err`. Fix class bugs before
treating the format as covered. Compare against last object baseline when a
behavior is ambiguous (hard gate still applies globally).

### 3. Turn the matrix into autotests

- Extend `tools/dn-linux-ops.py` or add `tools/dn-linux-archives.py` (+
  pytest under `tools/tests/` if that is the local pattern).
- Each fixture: generate → PTY Enter → assert member visible / panel title →
  leave → assert no Fatal; subset with F3/F4/F5 smoke and hang timeout.
- Wire into CI (`dn-linux` workflow) when stable; skip formats whose packer is
  absent on the runner.
- Nested cases are first-class tests, not optional extras.

## Acceptance for this task

- [x] Fixture generator checked in and documented (`tools/gen-archive-fixtures.py`).
- [x] Click-through / PTY covers zip, 7z, tar, tgz, tar.gz Enter+leave on class Linux
      (`tools/dn-linux-archives.py`).
- [x] Nested `.tar.gz`/`.tgz` enter without AV; listing shows `inside.txt` (TGZ: panel).
- [ ] F3/F4 from inside archive does not hang (timeout-bounded test).
- [x] Autotests in CI for zip, 7z, tar, tgz, tar.gz Enter/leave
      (`dn-linux` / `linux64-utf8` → `tools/dn-linux-archives.py`).
- [ ] Peers still open: `.tar.bz2` / `.tar.xz`, zip-in-zip, plain `.gz`, F5 extract;
      F3/F4 hang-bounded smoke.

Related: Unix packer defaults (`fmtzip`/`fmttar`/`fmt7z`…), ZIP charset
(`docs/ZIP-CHARSET.md`), object/class gate
(`docs/CLASS-MIGRATION-ACCEPTANCE-GATE.md`).
