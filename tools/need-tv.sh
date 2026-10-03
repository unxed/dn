# Sourced by the scripts that need tv/ (`. "$here/tools/need-tv.sh"`): tv/ is the git submodule of https://github.com/unxed/tv (the version that
# dn builds with is the commit recorded in dn; update it: `git -C tv pull && git add tv`). If it is not checked out (a clone without
# --recurse-submodules), it is fetched here, once. DN_TV=/path/to/tv: use that directory instead (a link tv -> it is made, git ignores it).
if [ -n "${DN_TV:-}" ] && [ ! -e "$here/tv/src" ]; then
    rmdir "$here/tv" 2>/dev/null || true
    ln -s "$DN_TV" "$here/tv"
fi
if [ ! -f "$here/tv/src/tvgeom.pas" ]; then
    echo "tv/ is empty: fetching the submodule (git submodule update --init --depth 1 tv)" >&2
    git -C "$here" submodule update --init --depth 1 tv >&2 ||
        { echo "ERROR: no tv/. Run: git submodule update --init tv   (or set DN_TV=/path/to/a/checkout of https://github.com/unxed/tv)" >&2; exit 1; }
fi
