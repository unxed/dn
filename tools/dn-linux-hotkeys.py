#!/usr/bin/env python3
"""Hot letters of the menus on a Cyrillic layout (Linux, a pty): tools/dn-linux-hotkeys.py OUTDIR [LANGUAGE...] [-j N]
For every item of the main menu of the Russian and the Ukrainian resources that has a hot letter (~X~) on the whole way to it, the item is reached from a
fresh start with Alt+<hot letter of the menu of the bar>, then the hot letter of each submenu and of the item, typed as UTF-8 (the build with UTF-8 inside).
Every key must change the screen (the menu opens, the submenu opens, the item starts) and DN must stay alive. A letter that two items of a menu share
(the old resources have a few: the first one wins) is left out, the same as an item without a hot letter; they are counted.
Exit status 1 when a key does nothing or DN has a fatal error."""
import os, re, shutil, sys, tempfile
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dn_wait import DnTerm

HERE = os.path.dirname(os.path.abspath(__file__))
RESDIR = os.path.join(HERE, '..', 'dn', 'src', 'resource')
LANGDIR = {'RUSSIAN': 'russian', 'UKRAIN': 'ukrain'}
# the items that are not opened (the names are in English in the first resource): they leave DN, scan the disk, run a program or are not the same twice
SKIP_CMDS = ('cmQuit', 'cmTree', 'cmGame', 'cmTrashcan', 'cmEditEnvironment', 'cmExecuteDOSCmd', 'cmScreenRest', 'cmExecGrabber', 'cmFindFile',
             'cmDirBranch', 'cmCountDirLen', 'cmCompareDirs', 'cmChangeDrive', 'cmFreeSpace', 'cmDiskInfo', 'cmChLngId', 'cmRestart',
             'cmClock', 'cmCalendar', 'cmShowUserScreen', 'cmShowOutput')
KEYS = {'ESC': '\x1b', 'ENTER': '\r', 'DOWN': '\x1b[B', 'RIGHT': '\x1b[C', 'F10': '\x1b[21~'}


def unquote(s):
    """the first quoted Pascal string of s ('' is a quote) and the rest of the line"""
    i = s.index("'") + 1
    r = []
    while True:
        j = s.index("'", i)
        r.append(s[i:j])
        if s[j + 1:j + 2] == "'":
            r.append("'")
            i = j + 2
        else:
            return ''.join(r), s[j + 1:]


def action_commands():
    """the command of each action of dn/src/resource/actions.dna (the name in lower case): a menu item of the form MenuItem 'caption', action"""
    r = {}
    for l in open(os.path.join(RESDIR, 'actions.dna'), encoding='utf-8').read().split('\n'):
        m = re.match(r'\s*ACTION\s+([^,\s]+)\s*,\s*(\w+)', l, re.I)
        if m:
            r[m.group(1).lower()] = m.group(2)
    return r


def parse(lang):
    ACTIONS = action_commands()
    lines = open(os.path.join(RESDIR, LANGDIR[lang], 'dn.dnr'), encoding='utf-8', errors='replace').read().split('\n')
    start = [k for k, l in enumerate(lines) if l.strip().startswith('MENU dlgMainMenu')][0]
    tree = []
    stack = [tree]
    for l in lines[start + 1:]:
        s = l.strip()
        if s.startswith(('DIALOG', 'MENU ')):
            break
        if s.startswith(';') or not s:
            continue
        if s.startswith('SubMenu') or s.startswith('MenuItem'):
            name, rest = unquote(s)
            h = re.search(r'~(.)~', name)
            node = {'name': name.replace('~', ''), 'hot': h.group(1) if h else None, 'items': None, 'cmd': ''}
            if s.startswith('SubMenu'):
                node['items'] = []
                stack[-1].append(node)
                stack.append(node['items'])
            else:
                parts = [x.strip() for x in rest.split(',')]
                node['cmd'] = parts[3] if len(parts) > 4 else ACTIONS.get(parts[1].lower(), '') if len(parts) > 1 else ''
                stack[-1].append(node)
        elif s.startswith('MenuLine'):
            stack[-1].append({'name': 'LINE', 'hot': None, 'items': None, 'cmd': ''})
        elif s.upper().startswith('END'):
            if len(stack) > 1:
                stack.pop()
            else:
                break
    return tree


def leaves(items, path, chain, stats):
    """(arrow path, hot letters, names) of every leaf that can be reached by hot letters"""
    pos = 0
    for it in items:
        if it['name'] == 'LINE':
            continue
        sibs = [x['hot'].lower() for x in items if x['hot']]
        ok = it['hot'] is not None and sibs.count(it['hot'].lower()) == 1
        if it['hot'] is None:
            stats['nohot'] += 1
        elif not ok:
            stats['dup'] += 1
        if it['items'] is not None:
            if ok:
                yield from leaves(it['items'], path + [pos], chain + [it['hot'].lower()], stats)
        elif ok and not any(c in it['cmd'] for c in SKIP_CMDS):
            yield path + [pos], chain + [it['hot'].lower()], it['name']
        pos += 1


def arrow_keys(path):
    m, rest = path[0], path[1:]
    ks = ['F10'] + ['RIGHT'] * m
    for depth, r in enumerate(rest):
        ks += ['DOWN'] * (r + 1 if depth == 0 else r) + ['ENTER']
    return [KEYS[k] for k in ks]


def hot_keys(chain):
    return ['\x1b' + chain[0]] + list(chain[1:])


def install(out, d):
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(out):
        if f == 'dn' or f.lower().endswith(('.lng', '.dlg', '.hlp')) or f == 'xlt':
            src = os.path.join(out, f)
            (shutil.copytree if os.path.isdir(src) else shutil.copy)(src, os.path.join(d, f))
    w = os.path.join(d, 'work')
    os.makedirs(os.path.join(w, 'sub'))
    open(os.path.join(w, 'a.txt'), 'w').write('hello\n')
    return d, w


def snapshot(t):
    """the cells (but the clock of the menu bar) and the cursor"""
    return t.shape(), (t.screen.x, t.screen.y)


def one(job):
    """the keys of the chain one by one: each must change the screen (open the menu, open the submenu, start the item) and DN must stay alive"""
    out, lang, chain, name = job
    d = tempfile.mkdtemp(prefix='dnhot-')
    try:
        d, w = install(out, d)
        t = DnTerm(['./dn'], 100, 30, cwd=w, exe=os.path.join(d, 'dn'), env={'DNLNG': lang, 'DN2': d})
        t.started()
        t.send(KEYS['ESC'], 0.4)
        why = ''
        for i, k in enumerate(hot_keys(chain)):
            before = snapshot(t)
            t.send(k, 0.4)
            t.until(lambda: snapshot(t) != before or not t.alive(), 5)     # a loaded machine answers late
            t.pump(0.4, 2)
            if not t.alive():
                why = 'DN ended after %s' % repr(k)
                break
            if 'Fatal Error' in t.text():
                why = 'fatal error after %s' % repr(k)
                break
            if snapshot(t) == before:
                if i == len(chain) - 1 and name.rstrip('.') not in t.text():
                    why = 'SKIP'                    # the item is not in the menu of this build (a part of the resource under a $IFDEF)
                else:
                    why = 'nothing happened at the key %d (%s)' % (i + 1, repr(k))
                break
        text = t.text()
        t.close(0.2)
        return lang, name, chain, why, text
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
        stats = {'nohot': 0, 'dup': 0}
        n = 0
        for path, chain, name in leaves(parse(lang), [], [], stats):
            jobs.append((out, lang, chain, name))
            n += 1
        print('%s: %d items reached by hot letters, %d without a hot letter, %d with a shared one (left out)' % (lang, n, stats['nohot'], stats['dup']), flush=True)
    bad = 0
    with ThreadPoolExecutor(jobs_n) as ex:
        for lang, name, chain, why, text in ex.map(one, jobs):
            if why == 'SKIP':
                print('SKIP %s %s [Alt-%s]: not in the menu of this build' % (lang, name, ' '.join(chain)), flush=True)
                continue
            print(('FAIL ' if why else 'PASS ') + '%s %s [Alt-%s]%s' % (lang, name, ' '.join(chain), ': ' + why if why else ''), flush=True)
            if why:
                bad += 1
                print('    | ' + '\n    | '.join(l[:100] for l in text.split('\n')[:8]), flush=True)
    print('%d runs, %d failed' % (len(jobs), bad), flush=True)
    sys.exit(1 if bad else 0)


main()
