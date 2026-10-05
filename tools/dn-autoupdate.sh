#!/bin/sh
# Optional auto-update for a make-install layout (issue #4, part 1).
#
# Called from the $(PREFIX)/bin/dn wrapper when the effective uid is 0.
# Every DN_UPDATE_EVERY-th launch (default 10) asks GitHub for the latest
# release asset matching this host and stages it under DN_UPDATE_STATE/pending.
# The next launch applies the pending tree over LIB (same layout as make install).
#
# Disable: DN_AUTOUPDATE=0, or touch $DN_UPDATE_STATE/disabled.
# Needs: curl, tar or unzip (depending on the asset), and a published Release.
set -eu

REPO="${DN_UPDATE_REPO:-unxed/dn}"
STATE="${DN_UPDATE_STATE:-/var/lib/dn}"
EVERY="${DN_UPDATE_EVERY:-10}"
LIB="${DN_LIB:-/usr/local/lib/dn}"
API="https://api.github.com/repos/${REPO}/releases/latest"

[ "${DN_AUTOUPDATE:-1}" != 0 ] || exit 0
[ ! -f "$STATE/disabled" ] || exit 0

# Only when the wrapper runs as root (typical sudo/make install path).
euid=$(id -u 2>/dev/null || echo 1)
[ "$euid" = 0 ] || exit 0

command -v curl >/dev/null 2>&1 || exit 0

mkdir -p "$STATE"
count=0
if [ -f "$STATE/run-count" ]; then
  count=$(cat "$STATE/run-count" 2>/dev/null || echo 0)
fi
case "$count" in
  ''|*[!0-9]*) count=0 ;;
esac
count=$((count + 1))
printf '%s\n' "$count" > "$STATE/run-count"

# Apply a previously staged update before starting DN.
if [ -d "$STATE/pending" ] && [ -f "$STATE/pending/dn" ]; then
  # shellcheck disable=SC2086
  cp -a "$STATE/pending/dn" "$LIB/dn"
  for pat in dlg lng hlp; do
    if ls "$STATE/pending/"*."$pat" >/dev/null 2>&1; then
      cp -a "$STATE/pending/"*."$pat" "$LIB/" 2>/dev/null || true
    fi
  done
  if [ -d "$STATE/pending/xlt" ]; then
    rm -rf "$LIB/xlt"
    cp -a "$STATE/pending/xlt" "$LIB/"
  fi
  rm -rf "$STATE/pending"
  if [ -f "$STATE/pending-tag" ]; then
    mv -f "$STATE/pending-tag" "$STATE/installed-tag"
  fi
fi

# Throttle network checks.
if [ "$EVERY" -gt 0 ] && [ $((count % EVERY)) -ne 0 ]; then
  exit 0
fi

arch=$(uname -m 2>/dev/null || echo unknown)
case "$arch" in
  x86_64|amd64) asset_re='linux64\.tar\.gz' ;;
  aarch64|arm64) asset_re='linux-aarch64\.tar\.gz|linux64\.tar\.gz' ;;
  i386|i686) asset_re='linux32\.tar\.gz|linux\.tar\.gz' ;;
  *) exit 0 ;;
esac

json=$(curl -fsSL --retry 2 --max-time 20 \
  -H 'Accept: application/vnd.github+json' \
  -H 'User-Agent: dn-autoupdate' \
  "$API" 2>/dev/null) || exit 0

tag=$(printf '%s' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$tag" ] || exit 0

if [ -f "$STATE/installed-tag" ]; then
  cur=$(cat "$STATE/installed-tag")
  [ "$cur" = "$tag" ] && exit 0
fi

# Prefer the asset whose name matches this arch; fall back to first linux64 tarball.
url=$(printf '%s' "$json" | tr ',' '\n' | sed -n 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | grep -E "$asset_re" | head -1 || true)
[ -n "$url" ] || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/asset"
curl -fsSL --retry 2 --max-time 120 -o "$archive" "$url" || exit 0

rm -rf "$STATE/pending"
mkdir -p "$STATE/pending"
case "$url" in
  *.tar.gz|*.tgz)
    tar -xzf "$archive" -C "$tmp"
    ;;
  *.zip)
    command -v unzip >/dev/null 2>&1 || exit 0
    unzip -q "$archive" -d "$tmp"
    ;;
  *) exit 0 ;;
esac

# Archive layout from the release workflow: dn-<tag>-linux64/dn (+ resources).
found=$(find "$tmp" -type f -name dn | head -1)
[ -n "$found" ] || exit 0
srcdir=$(dirname "$found")
cp -a "$srcdir/dn" "$STATE/pending/dn"
for pat in dlg lng hlp; do
  if ls "$srcdir/"*."$pat" >/dev/null 2>&1; then
    cp -a "$srcdir/"*."$pat" "$STATE/pending/" 2>/dev/null || true
  fi
done
if [ -d "$srcdir/xlt" ]; then
  cp -a "$srcdir/xlt" "$STATE/pending/"
fi
printf '%s\n' "$tag" > "$STATE/pending-tag"
