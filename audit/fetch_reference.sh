#!/bin/sh
# Fetches the Borland Pascal 7.0 (+ 7.01 maintenance update) archive, verifies it,
# extracts ONLY the Turbo Vision related Pascal sources into audit/ref/ and writes
# audit/ref/list.txt (input for xclone.py --ref).
#
# The extracted files are proprietary Borland code: they are used only as a
# reference for the audit and must never be committed (audit/ref/ is ignored).
#
# usage: audit/fetch_reference.sh [path/to/already/downloaded.rar]
# needs: curl, sha256sum, unrar (non-free; unar and 7z cannot unpack this
#        solid RAR3: "Unsupported Method"), unzip
set -eu

URL='https://web.archive.org/web/20231211134715if_/http://old-dos.ru/dl.php?id=9670'
URL_ORIG='http://old-dos.ru/dl.php?id=9670'
SHA256='1ba6251209ae4a56a4f6ce5926bff0eca815ea53a3dd5f57f779d52d1e1dc2fc'

here=$(cd "$(dirname "$0")" && pwd)
ref="$here/ref"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

src=${1:-}
if [ -z "$src" ]; then
    # web.archive first, the original site as a fallback; the sha256 below is the check
    curl -fsSL --retry 4 --max-time 600 -o "$tmp/bp7.rar" "$URL" \
        || curl -fsSL --retry 4 --max-time 600 -o "$tmp/bp7.rar" "$URL_ORIG"
    src="$tmp/bp7.rar"
fi
echo "$SHA256  $src" | sha256sum -c -

unrar x -y -idq "$src" "$tmp/x/"
b="$tmp/x"

rm -rf "$ref"
mkdir -p "$ref"
# name of subdirectory in ref/ : archive inside the BP7 distribution : members
while read -r dir zip members; do
    mkdir -p "$ref/$dir"
    # -C: case-insensitive member match, -j: flatten paths
    # shellcheck disable=SC2086
    unzip -q -o -C -j "$b/$zip" $members -d "$ref/$dir"
done <<'EOF'
tvsrc    BPASCAL.700/D11/TVSRC.ZIP               *.pas
tvdemo   BPASCAL.700/D11/TVDEMO.ZIP              *.pas
tvfm     BPASCAL.700/D8/TVFM.ZIP                 *.pas
tvdebug  BPASCAL.700/D12/TVDEBUG.ZIP             *.pas
greptv   BPASCAL.700/D12/GREPTV.ZIP              *.pas
chesstv  BPASCAL.700/D12/CHESSTV.ZIP             *.pas
miscsrc  BPASCAL.700/D12/MISCSRC.ZIP             strings.pas
rtl701   _UPDATE_/BP_OBJEC.701/2/BP7ETC.ZIP      rtl/tv/*.pas rtl/common/objects.pas
tutor701 _UPDATE_/BP_OBJEC.701/2/BP7ETC.ZIP      examples/docdemos/tv/*.pas
gvmemory _UPDATE_/GVIS_23/GVIS_23.ZIP            examples/msedit/memory.pas
EOF

find "$ref" -type f -iname '*.pas' | LC_ALL=C sort > "$ref/list.txt"
n=$(wc -l < "$ref/list.txt")
echo "reference corpus: $n files in $ref"
# 2026-10-01: 72 files (gvmemory: Borland's Memory unit as changed by Solar
# Designer, shipped with Graph Vision 2.3; the only Memory source available).
# A different count means the archive layout or this script changed: check
# before trusting audit numbers.
[ "$n" -eq 72 ] || { echo "unexpected file count $n (expected 72)" >&2; exit 1; }
