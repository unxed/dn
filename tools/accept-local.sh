#!/bin/sh
# The object vs class acceptance gate on this machine, in one command (what .github/workflows/dn-accept.yml does on the runners).
#
#   tools/accept-local.sh build              # build the object baseline (a worktree in build/accept/object, TV pinned, shared fixes
#                                            # backported) and the class build of the working tree: out/accept/object, out/accept/class
#   tools/accept-local.sh run [ARGS...]      # run the scenarios (ARGS go to tools/dn-linux-accept.py: --area menus, --shard 3/12,
#                                            # --list, scenario names); needs a built pair
#   tools/accept-local.sh all [ARGS...]      # build, then run
#   tools/accept-local.sh shot OUT KEYS      # one build on a screen (tools/dn-linux-try.py): tools/accept-local.sh shot out/accept/class 'F5 ESC'
#
# The pins are read from tools/dn-linux-accept.py (OBJECT_DN_SHA, OBJECT_TV_SHA). The class build uses the checkout as it is, with the
# tv/ submodule as it is on disk (a change in tv/ is built without being committed). Needs fpc 3.2.x, python3, git; DN_ACCEPT_FAST=1
# (the default here) shortens the settles as on the runners.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
work=${DN_ACCEPT_WORK:-$here/build/accept}
out=${DN_ACCEPT_OUT:-$here/out/accept}
pin() { sed -n "s/^$1 = '\\([0-9a-f]*\\)'.*/\\1/p" "$here/tools/dn-linux-accept.py"; }

build() {
    dn_sha=$(pin OBJECT_DN_SHA); tv_sha=$(pin OBJECT_TV_SHA)
    mkdir -p "$work" "$out"
    if [ ! -d "$work/object/.git" ] && [ ! -f "$work/object/.git" ]; then
        git -C "$here" worktree add -f "$work/object" "$dn_sha"
    fi
    git -C "$work/object" checkout -q -f "$dn_sha"
    git -C "$work/object" submodule update --init --depth 1 tv
    git -C "$work/object/tv" fetch -q --depth 1 origin "$tv_sha" || true
    git -C "$work/object/tv" checkout -q -f "$tv_sha"
    git -C "$work/object" checkout -q -- dn/compat/osdep.pas dn/src/colors.pas dn/src/filescol.pas dn/src/topview.pas 2>/dev/null || true
    python3 "$here/tools/acceptance/backport_shared_object_fixes.py" "$work/object"
    echo "== object: DN $dn_sha, TV $tv_sha"
    ( cd "$work/object" && tools/build.sh linux64 "$out/object" )
    echo "== class: the working tree ($(git -C "$here" rev-parse --short HEAD), tv $(git -C "$here/tv" rev-parse --short HEAD))"
    ( cd "$here" && tools/build.sh linux64 "$out/class" )
}

run() {
    [ -x "$out/object/dn" ] && [ -x "$out/class/dn" ] || { echo "no built pair in $out: run '$0 build' first" >&2; exit 1; }
    cd "$here"
    DN_ACCEPT_FAST=${DN_ACCEPT_FAST:-1} exec python3 tools/dn-linux-accept.py "$out/object" "$out/class" "$@"
}

case "${1:-}" in
    build) build ;;
    run) shift; run "$@" ;;
    all) shift; build; run "$@" ;;
    shot) shift; cd "$here"; exec python3 tools/dn-linux-try.py "${1:?usage: $0 shot OUTDIR KEYS}" "${2:-}" ;;
    *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
