#!/usr/bin/env python3
"""Lands a UTF-8 text on a single-byte code page (the DOS build): tools/to-codepage.py CODEPAGE IN OUT

The sources of DN (resources, help) are UTF-8 only. The DOS build shows the text in a code page of the machine, so the build converts it:
a character the code page has is kept; else its letter without the marks (o for the Hungarian o with a double acute), else a sign from
FALLBACK (the closest plain one); else the placeholder '?'. Never a letter of another script. The lost characters are counted on stderr.
The bytes below 0x80 and the line ends are not touched; a text that is not UTF-8 is an error (exit 1)."""
import sys
import unicodedata

FALLBACK = {'≡': '=', '∙': '.', '•': '*', '–': '-', '—': '-', '‘': "'", '’': "'", '“': '"', '”': '"',
            '…': '...', ' ': ' '}


def land(text, codepage):
    """Returns (bytes, {char: count} of the characters that were replaced)."""
    out = bytearray()
    lost = {}
    for ch in text:
        try:
            out += ch.encode(codepage)
            continue
        except UnicodeEncodeError:
            pass
        base = ''.join(c for c in unicodedata.normalize('NFD', ch) if not unicodedata.combining(c))
        alt = base if base != ch else FALLBACK.get(ch, '')
        try:
            out += alt.encode(codepage) if alt else b'?'
        except UnicodeEncodeError:
            out += b'?'
        lost[ch] = lost.get(ch, 0) + 1
    return bytes(out), lost


def main(argv):
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    codepage, src, dst = argv[1:]
    try:
        text = open(src, 'rb').read().decode('utf-8')
    except UnicodeDecodeError as e:
        print('%s: not UTF-8 (byte %d)' % (src, e.start), file=sys.stderr)
        return 1
    data, lost = land(text, codepage)
    open(dst, 'wb').write(data)
    if lost:
        print('%s -> %s: %s' % (src, codepage, ' '.join('U+%04X x%d' % (ord(c), n) for c, n in sorted(lost.items()))), file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
