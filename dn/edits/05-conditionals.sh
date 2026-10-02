#!/bin/sh
# reason: (д) building with FPC for one target. The conditional compilation of DN serves four targets
# (DPMI32, OS2, WIN32, LINUX) of Virtual Pascal; here it is evaluated for the target in dn/target.env
# (tools/ifdef-strip.py), so the tree is the tree of that target. Run by tools/dn-materialize.sh with
# the directory of the tree as the argument.
set -eu
here=$(cd "$(dirname "$0")/../.." && pwd)
. "$here/dn/targets.sh"
. "$DN_TARGET_ENV"
python3 "$here/tools/ifdef-strip.py" "$1" "$1" $DN_DEFINES
