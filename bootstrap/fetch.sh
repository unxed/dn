#!/bin/sh
# Downloads the public archive of DOS Navigator named in bootstrap/upstream.env and checks its
# sha256. The archive goes to build/cache/ (not committed).
# usage: bootstrap/fetch.sh [NAME]      NAME: dnosp214 (the base) or dn151; default DN_BASE
# With sha256 = TOFU the value found is printed and the archive is accepted: pin it in
# bootstrap/upstream.env (a trust-on-first-use step for the first fetch only).
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
. "$here/bootstrap/upstream.env"
name=${1:-$DN_BASE}
eval url=\$${name}_URL file=\$${name}_FILE want=\$${name}_SHA256
[ -n "${url:-}" ] || { echo "fetch: unknown upstream '$name'" >&2; exit 2; }
cache="$here/build/cache"
mkdir -p "$cache"
if [ ! -s "$cache/$file" ]; then
    curl -fsSL --retry 4 --max-time 900 -o "$cache/$file.part" "$url" \
        || curl -fsSL --retry 4 --max-time 900 -o "$cache/$file.part" "$(echo "$url" | sed 's|web.archive.org/web/[0-9]*if_/||')"
    mv "$cache/$file.part" "$cache/$file"
fi
got=$(sha256sum "$cache/$file" | cut -d' ' -f1)
if [ "$want" = TOFU ]; then
    echo "fetch: $name sha256 = $got   (pin it in bootstrap/upstream.env)" >&2
elif [ "$got" != "$want" ]; then
    echo "fetch: $name: sha256 $got, expected $want" >&2
    exit 1
else
    echo "fetch: $name sha256 ok" >&2
fi
echo "$cache/$file"
