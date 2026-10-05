# LocaleCp (Pascal)

In-tree seed of [unxed/localecp](https://github.com/unxed/localecp) for DN and
other native consumers: host locale → legacy OEM/ANSI code pages, plus
decoders to UTF-8.

Behavioral lock: same locale tables and Unix `LANG`/`LC_*` init as the Go
library (including fallback encodings such as IBM737→Windows-1253). Windows
ACP/OEMCP + UTF-8-ACP Far-style fallback is stubbed to defaults until ported.

Used by `dn/lib/zipcharset` and `fmtzip` listing. OEM display pick for the UI
remains `tv/src/tvlocale.pas` (OEM half of the same table).

Regenerate decode maps:

```bash
python3 tools/gen-localecp-tables.py > dn/lib/localecp/localecp_tables.inc
```
