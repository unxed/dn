#!/usr/bin/env python3
"""Every item of the main menu of DN, in every language (Linux, a pty): tools/dn-linux-menusweep.py OUTDIR [LANGUAGE...] [-j N]
Each item (the submenus included) is opened from a fresh start with F10, the arrows and Enter, the screen is looked at for a fatal error, the dialog is left with Esc.
The items come from the main menu of dn/src/resource/english/dn.dnr (the order is the same in the other languages). The gate of the acceptance compares the items of the
top level only; this is what the dialogs below them need (the one that died at Alt-K was found this way). Items that start something long or leave DN are not opened.
Exit status 1 when a screen has a fatal error."""
import os, re, shutil, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pty_screen import PtyTerm

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, '..', 'dn', 'src', 'resource', 'english', 'dn.dnr')
# the items that are not opened (the names are in English): they leave DN, scan the disk, run a program or are not the same twice
SKIP = ('Exit', 'Directory tree', 'Game', 'Trash Can', 'Trashcan', 'Edit OS Environment', 'Execute OS command', 'Screen rest', 'Screen grabber',
        'Find...', 'Directory Branch', 'Count directory length', 'Compare directories', 'Change drive', 'Free space', 'Disk information')
KEYS = {'ESC': '\x1b', 'ENTER': '\r', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'F10': '\x1b[21~'}


def parse():
    lines = open(RES, encoding='utf-8', errors='replace').read().split('\n')
    start = [k for k, l in enumerate(lines) if l.strip().startswith('MENU dlgMainMenu')][0]
    top, stack = [], None
    tree = []
    stack = [tree]
    for l in lines[start + 1:]:
        s = l.strip()
        if s.startswith(('DIALOG', 'MENU ')):
            break
        if s.startswith(';') or not s:
            continue
        if s.startswith('SubMenu'):
            node = {'name': s, 'items': []}
            stack[-1].append(node)
            stack.append(node['items'])
        elif s.startswith('MenuItem'):
            stack[-1].append({'name': s, 'items': None})
        elif s.startswith('MenuLine'):
            stack[-1].append({'name': 'LINE', 'items': None})
        elif s.upper().startswith('END'):
            if len(stack) > 1:
                stack.pop()
            else:
                break
    return tree


def title(s):
    m = re.match(r"(?:SubMenu|MenuItem)\s+'([^']*)'", s)
    return m.group(1).replace('~', '') if m else s


def leaves(items, path, names):
    n = 0
    for it in items:
        if it['name'] == 'LINE':
            continue
        nm = names + [title(it['name'])]
        if it['items'] is not None:
            yield from leaves(it['items'], path + [n], nm)
        else:
            yield path + [n], nm
        n += 1


def keys_for(path):
    m, rest = path[0], path[1:]
    ks = ['F10'] + ['RIGHT'] * m
    for depth, r in enumerate(rest):
        # the first Down opens the menu of the bar and selects its first item; a submenu opened with Enter has its first item selected already
        ks += ['DOWN'] * (r + 1 if depth == 0 else r) + ['ENTER']
    return ks


def install(out):
    d = tempfile.mkdtemp(prefix='dnsweep-')
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'a.txt'), 'w').write('hello\n')
    return d, w


def one(job):
    out, lang, path, names = job
    d, w = install(out)
    try:
        t = PtyTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d})
        t.pump(1.2, 5)
        t.send(KEYS['ESC'], 0.4)
        for k in keys_for(path):
            t.send(KEYS[k], 0.25)
        t.pump(0.8, 2.5)
        text = t.text()
        bad = 'Fatal Error' in text or not t.alive()
        for _ in range(4):
            if t.alive():
                t.send(KEYS['ESC'], 0.15)
        t.close(0.2)
        return lang, path, names, bad, text if bad else ''
    finally:
        shutil.rmtree(d, ignore_errors=True)


def main():
    args = sys.argv[1:]
    jobs_n = 4
    if '-j' in args:
        i = args.index('-j')
        jobs_n = int(args[i + 1])
        del args[i:i + 2]
    out = os.path.abspath(args[0])
    langs = [a.upper() for a in args[1:]] or ['ENGLISH', 'RUSSIAN', 'UKRAIN']
    tree = parse()
    jobs = []
    for m, top in enumerate(tree):
        for path, names in leaves(top['items'], [m], [title(top['name'])]):
            if any(s.lower() in names[-1].lower() for s in SKIP):
                continue
            for lang in langs:
                jobs.append((out, lang, path, names))
    print('%d items x %d languages = %d runs' % (len(jobs) // len(langs), len(langs), len(jobs)), flush=True)
    bad = 0
    with ThreadPoolExecutor(jobs_n) as ex:
        for lang, path, names, isbad, text in ex.map(one, jobs):
            if isbad:
                bad += 1
                print('FAIL %s %s %s' % (lang, ' > '.join(names), path), flush=True)
                print('    | ' + '\n    | '.join(l[:100] for l in text.split('\n')[:8]), flush=True)
    print('%d runs, %d with a fatal error' % (len(jobs), bad), flush=True)
    sys.exit(1 if bad else 0)


main()
