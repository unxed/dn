#!/usr/bin/env python3
"""Hot letters of the dialogs on a Cyrillic layout (Linux, a pty): tools/dn-linux-dialoghot.py OUTDIR [LANGUAGE...] [-j N]
Every item of the main menu that opens a dialog is opened from a fresh start (by its hot letters when it has them on the way, else by the arrows: the
items that exist only on some systems shift the arrows, so another dialog may open; it does not matter here). The hot letters of the dialog are found on the screen (the cells that the
dialog drew with the color of a hot letter: cyan, a letter that differs from both neighbours). Alt+<that letter> (Esc and the letter in UTF-8) is sent
for each of them; the screen (the cells, their colors and the cursor) must change: a check box is switched, a button acts, the focus moves. A letter that
does nothing is a defect (the letter does not match: a Latin letter in a Russian word, a Cyrillic letter in a Latin one, the case...). When a dialog is
closed by a letter the item is opened again for the letters that are left.
Exit status 1 when a letter does nothing or DN has a fatal error."""
import os, shutil, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, 'dn-linux-hotkeys.py'), encoding='utf-8').read().rsplit('\nmain()', 1)[0]
NS = {'__file__': os.path.join(HERE, 'dn-linux-hotkeys.py')}
exec(compile(SRC, 'dn-linux-hotkeys', 'exec'), NS)         # the parser of the menu and the keys of the sibling test
NS['LANGDIR']['ENGLISH'] = 'english'
HOT = ('i', 11)                                             # the color of a hot letter in a dialog (cyan)


def snapshot(t):
    return [[c for c in row] for row in t.screen.cells], (t.screen.x, t.screen.y)


def hot_cells(t, base):
    """(row, column, letter) of the hot letters that the dialog drew: new cells, a letter of the hot color between cells of another color"""
    out = []
    # a dialog is a lot of new cells (the clock and the panel footers change by themselves): with fewer there is no dialog, whatever has the hot color
    changed = sum(1 for y, row in enumerate(t.screen.cells) for x, c in enumerate(row) if y > 0 and c != base[y][x])
    if changed < 200:
        return out
    for y, row in enumerate(t.screen.cells):
        for x in range(1, len(row) - 1):
            ch, a = row[x]
            if not ch.isalpha() or not a or (ch, a) == base[y][x] or a[0] != HOT:
                continue
            left, right = row[x - 1][1], row[x + 1][1]
            if left and right and left[0] != HOT and right[0] != HOT:
                out.append((y, x, ch))
    return out


def start(out, lang, path, chain, d):
    d, w = NS['install'](out, d)
    t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d})
    t.started()
    t.send('\x1b', 0.4)
    base = [[c for c in row] for row in t.screen.cells]
    for k in (NS['hot_keys'](chain) if chain else NS['arrow_keys'](path)):
        t.send(k, 0.25)
    t.pump(0.6, 2)
    return t, base, d


def probe(job):
    out, lang, path, chain, name = job
    d = tempfile.mkdtemp(prefix='dnhd-')
    done, bad, found = set(), [], 0
    try:
        for attempt in range(8):
            t, base, d = start(out, lang, path, chain, d)
            cells = hot_cells(t, base)
            found = max(found, len(cells))
            todo = [c for c in cells if c not in done]
            if not todo:
                t.close(0.2)
                break
            closed = False
            for y, x, ch in todo:
                before = snapshot(t)
                t.send('\x1b' + ch, 0.5)
                t.pump(0.3, 1.5)
                if not t.alive():
                    bad.append((ch, 'DN ended'))
                    done.add((y, x, ch))
                    closed = True
                    break
                done.add((y, x, ch))
                after = snapshot(t)
                if after == before:
                    bad.append((ch, 'nothing happened'))
                    continue
                if 'Fatal Error' in t.text():
                    bad.append((ch, 'fatal error'))
                    closed = True
                    break
                if hot_cells(t, base) != cells:           # the dialog is gone or changed: start again for the letters that are left
                    closed = True
                    break
            t.close(0.2)
            shutil.rmtree(d, ignore_errors=True)
            if not closed:
                break
        return lang, name, found, bad
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    args = sys.argv[1:]
    jobs_n = 16
    if '-j' in args:
        i = args.index('-j')
        jobs_n = int(args[i + 1])
        del args[i:i + 2]
    out = os.path.abspath(args[0])
    langs = [a.upper() for a in args[1:]] or ['RUSSIAN', 'UKRAIN']
    jobs = []
    for lang in langs:
        def walk(items, path, chain):
            pos = 0
            for it in items:
                if it['name'] == 'LINE':
                    continue
                sibs = [x['hot'].lower() for x in items if x['hot']]
                hot = it['hot'].lower() if it['hot'] and sibs.count(it['hot'].lower()) == 1 else None
                sub = chain + [hot] if chain is not None and hot else None
                if it['items'] is not None:
                    yield from walk(it['items'], path + [pos], sub)
                elif not any(c in it['cmd'] for c in NS['SKIP_CMDS']):
                    yield path + [pos], sub, it['name']
                pos += 1
        for path, chain, name in walk(NS['parse'](lang), [], []):
            jobs.append((out, lang, path, chain, name))
    bad = letters = dialogs = 0
    with ThreadPoolExecutor(jobs_n) as ex:
        for lang, name, found, fails in ex.map(probe, jobs):
            if found:
                dialogs += 1
                letters += found
            for ch, why in fails:
                bad += 1
                print('FAIL %s %s: Alt-%s %s' % (lang, name, ch, why), flush=True)
    print('%d items with hot letters, %d letters tried, %d failed' % (dialogs, letters, bad), flush=True)
    sys.exit(1 if bad else 0)


main()
