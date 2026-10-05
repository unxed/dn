#!/bin/sh
# reason: (d) building with FPC for one source. The conditional compilation of DN serves four systems (DPMI32, OS2, WIN32, LINUX) of Virtual
# Pascal; here the branches of the base (BOOT_STRIP) are evaluated and the branches of the symbols BOOT_KEEP stay for the compiler
# (tools/ifdef-strip.py; the policy: bootstrap/tree.env). Run by bootstrap/run.sh with the directory of the tree as the argument.
set -eu
here=$(cd "$(dirname "$0")/../.." && pwd)
. "$here/bootstrap/tree.env"
python3 "$here/bootstrap/tools/ifdef-strip.py" "$1" "$1" $BOOT_STRIP --keep $BOOT_KEEP
