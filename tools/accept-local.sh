#!/bin/sh
# The acceptance by the full UI click-through on this machine, in one command (what .github/workflows/dn-accept.yml does on the runners):
# the UTF-8 build of the working tree against its build with the code page inside (DN_UTF8=0), cell by cell (DN_ACCEPT_U8CP=1).
#
#   tools/accept-local.sh build              # build the pair: out/accept/u8 and out/accept/cp
#   tools/accept-local.sh run [ARGS...]      # run the scenarios (ARGS go to tools/dn-linux-accept.py: --area menus, --shard 3/12,
#                                            # --list, scenario names); needs a built pair. Without --shard the scenarios run in
#                                            # DN_ACCEPT_JOBS parts side by side (default 12), each with a HOME of its own
#   tools/accept-local.sh all [ARGS...]      # build, then run
#   tools/accept-local.sh shot OUT KEYS      # one build on a screen (tools/dn-linux-try.py): tools/accept-local.sh shot out/accept/u8 'F5 ESC'
#
# Needs fpc 3.2.x, python3; DN_ACCEPT_FAST=1 (the default here) shortens the settles as on the runners.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
work=${DN_ACCEPT_WORK:-$here/build/accept}
out=${DN_ACCEPT_OUT:-$here/out/accept}
build() {
    mkdir -p "$out"
    # the two builds side by side, each with a TMPDIR of its own (tools/build.sh keeps the objects, the stage and the shims there)
    t=$(mktemp -d)
    ( cd "$here" && TMPDIR=$t/u8 && mkdir -p "$TMPDIR" && export TMPDIR && tools/build.sh linux64 "$out/u8" ) > "$t/u8.log" 2>&1 &
    pu=$!
    ( cd "$here" && TMPDIR=$t/cp && mkdir -p "$TMPDIR" && export TMPDIR DN_UTF8=0 && tools/build.sh linux64 "$out/cp" ) > "$t/cp.log" 2>&1 &
    pp=$!
    ru=0; wait $pu || ru=$?
    rp=0; wait $pp || rp=$?
    echo "== UTF-8"; cat "$t/u8.log"; echo "== code page"; cat "$t/cp.log"
    rm -rf "$t"
    [ $ru = 0 ] && [ $rp = 0 ]
}

run() {
    [ -x "$out/u8/dn" ] && [ -x "$out/cp/dn" ] || { echo "no built pair in $out: run '$0 build' first" >&2; exit 1; }
    cd "$here"
    export DN_ACCEPT_FAST=${DN_ACCEPT_FAST:-1} DN_ACCEPT_U8CP=1
    case " $* " in *" --shard "*|*" --list "*) exec python3 tools/dn-linux-accept.py "$out/u8" "$out/cp" "$@" ;; esac
    j=${DN_ACCEPT_JOBS:-12}; logs=$(mktemp -d)
    CMDS=$(k=0; while [ $k -lt "$j" ]; do
        echo "python3 tools/dn-linux-accept.py '$out/u8' '$out/cp' $* --shard $k/$j > '$logs/part$k.log'"; k=$((k + 1)); done)
    export CMDS
    r=0; tools/ci-par.sh > "$logs/par.log" 2>&1 || r=1
    k=0; while [ $k -lt "$j" ]; do cat "$logs/part$k.log"; k=$((k + 1)); done
    [ $r = 0 ] || cat "$logs/par.log"      # the errors of the parts (their stderr) and which of them failed
    cat "$logs"/part*.log | sed -n 's/^SUMMARY pass=\([0-9]*\) fail=\([0-9]*\).*/\1 \2/p' |
        awk '{ p += $1; f += $2; n++ } END { printf "TOTAL pass=%d fail=%d (%d of '"$j"' parts reported)\n", p, f, n }'
    rm -rf "$logs"
    return $r
}

case "${1:-}" in
    build) build ;;
    run) shift; run "$@" ;;
    all) shift; build; run "$@" ;;
    shot) shift; cd "$here"; exec python3 tools/dn-linux-try.py "${1:?usage: $0 shot OUTDIR KEYS}" "${2:-}" ;;
    *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
