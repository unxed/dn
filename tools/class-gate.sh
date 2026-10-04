#!/bin/sh
# The class migration gate: the legacy type spelling must be absent from the tracked tree.
set -eu
here=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if git -C "$here" grep -I -n -i 'obj[e]ct' -- .; then
    echo "CLASS GATE FAIL: legacy type spelling is still present" >&2
    exit 1
fi
echo "dn class gate: PASS"
