#!/usr/bin/env python3
"""Which Turbo Vision names does a Pascal program use that it does not define itself?

usage: api-usage.py SRC_DIR MAGIBLOT_INCLUDE_DIR [OUT.md]

Reads *.pas / *.inc under SRC_DIR (comments and strings are skipped), collects
  - type names T... that are used but not declared in the sources,
  - constants with the Turbo Vision prefixes (cm, kb, hc, ev, of, sf, gf, dm, wf, wp, ...)
    that are used but not declared in the sources,
and says which of the types exist in the classes of magiblot/tvision (so the translation
in tv/ covers them) and which do not. Only names are printed: no code of the sources.
"""
import os
import re
import sys
from collections import defaultdict

PREFIXES = ("cm", "kb", "hc", "ev", "of", "sf", "gf", "dm", "wf", "wp", "sb", "mb", "mw",
            "cp", "ap", "bf", "cf", "fd", "od", "ms", "mf", "vs", "ik", "ap", "ff", "ib")

def strip(src):
    src = re.sub(r"\(\*.*?\*\)", " ", src, flags=re.S)
    src = re.sub(r"\{[^}]*\}", " ", src, flags=re.S)
    src = re.sub(r"//[^\n]*", " ", src)
    src = re.sub(r"'(?:[^'\n]|'')*'", " ", src)
    return src

def main():
    srcdir, incdir = sys.argv[1], sys.argv[2]
    out = sys.argv[3] if len(sys.argv) > 3 else None
    files = []
    for root, _, names in os.walk(srcdir):
        for n in names:
            if n.lower().endswith((".pas", ".inc")):
                files.append(os.path.join(root, n))
    declared = set()
    uses = defaultdict(lambda: [0, set()])
    consts = defaultdict(lambda: [0, set()])
    text = {}
    for f in files:
        text[f] = strip(open(f, encoding="cp866", errors="replace").read())
        for m in re.finditer(r"\b([A-Za-z_]\w*)\s*=\s*(?:packed\s+)?(object|class|record|array|set|string|\^|\(|procedure|function|file|\d|\$)",
                             text[f], flags=re.I):
            declared.add(m.group(1).lower())
        for m in re.finditer(r"\bconst\b(.*?)\b(?:type|var|procedure|function|begin|implementation)\b", text[f], flags=re.S | re.I):
            for c in re.finditer(r"\b([A-Za-z_]\w*)\s*(?::[^=;]+)?=", m.group(1)):
                declared.add(c.group(1).lower())
    for f, t in text.items():
        for m in re.finditer(r"\bT[A-Z][A-Za-z0-9_]*\b", t):
            n = m.group(0)
            if n.lower() not in declared:
                uses[n][0] += 1
                uses[n][1].add(os.path.basename(f).upper())
        for m in re.finditer(r"\b(%s)[A-Z][A-Za-z0-9]*\b" % "|".join(PREFIXES), t):
            n = m.group(0)
            if n.lower() not in declared:
                consts[n][0] += 1
                consts[n][1].add(os.path.basename(f).upper())

    classes = set()
    for root, _, names in os.walk(incdir):
        if "compat" in root:
            continue
        for n in names:
            if n.endswith(".h"):
                for m in re.finditer(r"\b(?:class|struct)\s+(?:_FAR\s+)?(T[A-Za-z0-9_]+)", open(os.path.join(root, n), encoding="utf-8", errors="replace").read()):
                    classes.add(m.group(1).lower())
    # names that differ between Pascal TV and the C++ library
    alias = {"tcollection": "tnscollection", "tsortedcollection": "tnssortedcollection",
             "tstringcollection": "tnsstringcollection", "tstrcollection": "tstringcollection",
             "tobject": "tobject", "tresourcefile": "tresourcefile", "tdosstream": "tdosstream"}
    def known(n):
        l = n.lower()
        return l in classes or alias.get(l, "") in classes

    lines = ["# Какие имена Turbo Vision использует код", "",
             "Создано `tools/api-usage.py` (только имена). Это граница объёма перевода в `tv/`.", "",
             "Исходники: `%s`, файлов: %d." % (os.path.basename(os.path.normpath(srcdir)), len(files)), "",
             "## Типы `T...`, которых нет в исходниках", "",
             "| Тип | Употреблений | Файлов | Есть в magiblot | Файлы (первые) |", "|---|---|---|---|---|"]
    for n, (c, fs) in sorted(uses.items(), key=lambda kv: (-kv[1][0], kv[0])):
        lines.append("| %s | %d | %d | %s | %s |" % (n, c, len(fs), "да" if known(n) else "нет", ", ".join(sorted(fs)[:4])))
    lines += ["", "## Константы с префиксами TV, которых нет в исходниках", "",
              "| Имя | Употреблений | Файлов |", "|---|---|---|"]
    for n, (c, fs) in sorted(consts.items(), key=lambda kv: (-kv[1][0], kv[0])):
        lines.append("| %s | %d | %d |" % (n, c, len(fs)))
    s = "\n".join(lines) + "\n"
    if out:
        open(out, "w", encoding="utf-8").write(s)
    print(s[:3000])
    print("types: %d (%d known to magiblot), constants: %d" % (len(uses), sum(1 for n in uses if known(n)), len(consts)))

main()
