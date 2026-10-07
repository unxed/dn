# Sourced by the scripts that need tv/ (`. "$here/tools/need-tv.sh"`): tv/ is the git submodule of https://github.com/unxed/tv3 (the version that
# dn builds with is the commit recorded in dn; update it by checking out a reviewed tv3 commit and running `git add tv`). If it is not checked out (a clone without
# --recurse-submodules), it is fetched here, once. DN_TV=/path/to/tv: use that directory instead (a link tv -> it is made, git ignores it).
if [ -n "${DN_TV:-}" ] && [ ! -e "$here/tv/src" ]; then
    rmdir "$here/tv" 2>/dev/null || true
    ln -s "$DN_TV" "$here/tv"
fi
if [ ! -f "$here/tv/src/tvgeom.pas" ]; then
    echo "tv/ is empty: fetching the submodule (git submodule update --init --depth 1 tv)" >&2
    git -C "$here" submodule update --init --depth 1 tv >&2 ||
        { echo "ERROR: no tv/. Run: git submodule update --init tv   (or set DN_TV=/path/to/a/checkout of https://github.com/unxed/tv3)" >&2; exit 1; }
fi
# tv/ is checked out at another commit than the one recorded in dn (an old checkout after a pull, or your own work in tv/): a build can fail on names that the recorded version has.
if [ -z "${DN_TV:-}" ] && git -C "$here" submodule status tv 2>/dev/null | grep -q '^[+-]'; then
    echo "NOTE: tv/ is not at the commit recorded in dn; if the build fails on a missing name run: git submodule update --init tv" >&2
fi
# tve/ is the git submodule of https://github.com/unxed/tve (the editor); the same rules: DN_TVE=/path/to/tve uses that directory instead.
if [ -n "${DN_TVE:-}" ] && [ ! -e "$here/tve/src" ]; then
    rmdir "$here/tve" 2>/dev/null || true
    ln -s "$DN_TVE" "$here/tve"
fi
if [ ! -f "$here/tve/src/tvedoc.pas" ]; then
    echo "tve/ is empty: fetching the submodule (git submodule update --init --depth 1 tve)" >&2
    git -C "$here" submodule update --init --depth 1 tve >&2 ||
        { echo "ERROR: no tve/. Run: git submodule update --init tve   (or set DN_TVE=/path/to/a/checkout of https://github.com/unxed/tve)" >&2; exit 1; }
fi
