#!/bin/sh
# The class migration gate: the old Pascal `object` dialect must be absent from the tracked Pascal sources.
# What exactly is checked, and the settings (CLASS_GATE_EXCLUDE, CLASS_GATE_STRICT): tools/class-gate.py
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
exec python3 "$here/tools/class-gate.py" "$here"
