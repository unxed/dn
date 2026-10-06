#!/usr/bin/env python3
"""One-time repair of the Russian and Ukrainian resource texts (dn/src/resource/russian, ukrain): tools/fix-resource-lookalikes.py [--apply]

The old one-byte texts were typed with Latin look-alikes inside Cyrillic words (a Latin p for the Russian r, the Latin i for the Ukrainian i ...),
with the Belarusian short u for the Ukrainian i, and with Cyrillic look-alikes inside Latin words (ESC, Ctrl, desktop). In UTF-8 these are wrong
letters. The rule, for every word of letters (the hotkey tildes do not break a word; %-specs are not words):
  * Cyrillic letters are the majority: the Latin look-alikes become Cyrillic (Ukrainian: i, I too; the Belarusian short u too);
  * Latin letters are the majority (or a tie): the Cyrillic look-alikes become Latin, except an abbreviation with a Russian ending (DNu, FATa);
  * a word that still has a letter without a look-alike is listed as "manual" and not changed.
Without --apply it only prints the report (the changed words with the counts, the manual ones). The text policy test keeps the result: no word
of the resources mixes the two scripts, but the words of the list KEEP below."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAT2CYR = dict(zip('ABCEHKMOPTXaceopxy', 'АВСЕНКМОРТХасеорху'))
UKR_EXTRA = {'i': 'і', 'I': 'І', 'ў': 'і', 'Ў': 'І'}       # the short u was the hack for i
CYR2LAT = {v: k for k, v in LAT2CYR.items()}
CYR2LAT.update({'і': 'i', 'І': 'I'})
KEEP = {'DNу', 'DNа', 'FATа'}       # abbreviation + a Russian ending: both scripts on purpose
ENGLISH = {'O~К': 'O~K', 'ОK': 'OK'}            # the button OK is English in all the languages (a tie between the two scripts)
WORD = re.compile(r"[A-Za-zЀ-ӿ]+(?:~[A-Za-zЀ-ӿ]+)*")
SPEC = re.compile(r'%[-0-9.*]*[A-Za-z]')
CYR = re.compile('[Ѐ-ӿ]')
FILES = ('dn.dnl', 'dn.dnr', 'dnhelp.htx')


def fix_word(word, ukr):
    plain = word.replace('~', '')
    if ukr:
        plain = plain.replace('\u045e', 'і').replace('\u040e', 'І')
    cyr = [c for c in plain if CYR.match(c)]
    lat = [c for c in plain if c.isascii() and c.isalpha()]
    if word in KEEP or word in ENGLISH:
        return ENGLISH.get(word, word), None
    if not cyr and not (ukr and word != plain):
        return word, None
    table = dict(LAT2CYR)
    if ukr:
        table.update({'i': 'і', 'I': 'І'})
    to_cyr_ok = all(c in table for c in lat)           # every Latin letter has a Cyrillic look-alike
    to_lat_ok = all(c in CYR2LAT for c in cyr)          # every Cyrillic letter has a Latin look-alike
    if not lat:
        return (word.replace('\u045e', 'і').replace('\u040e', 'І') if ukr else word), None
    if to_cyr_ok and (len(cyr) >= len(lat) or not to_lat_ok):
        mapped = {'\u045e': 'і', '\u040e': 'І'}
        return ''.join(c if c == '~' else table.get(c, mapped.get(c, c)) if c.isascii() else (mapped.get(c, c) if ukr else c) for c in word), None
    if to_lat_ok:
        return ''.join(CYR2LAT.get(c, c) for c in word), None
    return word, 'manual'


LEFT_CYR = re.compile('[\u0400-\u04ff]{2,}[ ]+$')
RIGHT_CYR = re.compile(r"^[ ,]+[\"'~(\-]*[A-Za-z]*-?[\u0400-\u04ff]")


def standalone(text, ukr, changes):
    """A Latin letter that stands alone as a Cyrillic word: the Ukrainian i/I ('and'), the Russian c ('with')."""
    letters = '[iI]' if ukr else '[c]'
    rx = re.compile(r"(?<![A-Za-z0-9'~%\\./:\-])(LETTERS)(?=[ ,])".replace('LETTERS', letters))

    def sub(m):
        left = text[max(0, m.start() - 40):m.start()]
        right = text[m.end():m.end() + 40]
        if not (LEFT_CYR.search(left) or RIGHT_CYR.match(right)):
            return m.group()
        new = {'i': 'і', 'I': 'І', 'c': 'с'}[m.group()]
        changes[(m.group(), new)] = changes.get((m.group(), new), 0) + 1
        return new
    return rx.sub(sub, text)


def fix_text(text, ukr, changes, manual):
    def spec_safe(m):
        return m.group()
    parts = []
    pos = 0
    for sm in SPEC.finditer(text):
        parts.append(('t', text[pos:sm.start()]))
        parts.append(('s', sm.group()))
        pos = sm.end()
    parts.append(('t', text[pos:]))
    out = []
    for kind, chunk in parts:
        if kind == 's':
            out.append(chunk)
            continue
        def sub(m):
            new, flag = fix_word(m.group(), ukr)
            if flag == 'manual':
                manual[m.group()] = manual.get(m.group(), 0) + 1
            elif new != m.group():
                changes[(m.group(), new)] = changes.get((m.group(), new), 0) + 1
            return new
        out.append(WORD.sub(sub, chunk))
    return standalone(''.join(out), ukr, changes)


def main(argv):
    apply = '--apply' in argv
    for lang in ('russian', 'ukrain'):
        changes, manual = {}, {}
        for name in FILES:
            p = ROOT / 'dn/src/resource' / lang / name
            old = p.read_bytes().decode('utf-8')
            new = fix_text(old, lang == 'ukrain', changes, manual)
            if apply and new != old:
                p.write_bytes(new.encode('utf-8'))
        print('== %s: %d kinds of words changed, %d times' % (lang, len(changes), sum(changes.values())))
        for (a, b), n in sorted(changes.items(), key=lambda x: -x[1])[:25]:
            print('   %5d  %s -> %s' % (n, a, b))
        print('   manual (not changed):', sorted(manual.items(), key=lambda x: -x[1]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
