"""Hot letters of the dialogs of dn/src/resource/*/dn.dnr: no letter (either case) is marked on two controls of a dialog.

Alt+letter reaches only one control (the one inserted last), so a letter on two controls leaves the other without its key. The controls are
the labels, the buttons and the items of the check boxes and radio buttons; the lines of an $IFDEF all count. A label of two lines (the
second just below the first) is one control. Some dialogs get a label from dn.dnl when DN opens them (RUNTIME): its letter counts too."""
import collections
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / 'dn/src/resource'
LANGS = ('english', 'russian', 'ukrain')
STR = re.compile(r"'((?:[^']|'')*)'")
CLUSTERS = ('CheckBoxes', 'RadioButtons', 'DriveCheckBoxes')

# dialog -> the strings of dn.dnl that DN inserts into it as labels (filecopy.pas, colors.pas, macro.pas, phones.pas)
RUNTIME = {
    'dlgCopyDialog': ('dlFCCopy1', 'dlFCMove1'),
    'dlgWindowManager': ('dlWindowsLabel',),
    'dlgEditEnvironment': ('dlEnvVarLabel',),
    'dlgPhoneBook': ('dlPhonesLabelGroup', 'dlPhonesLabelPhones'),
}


def read(path):
    return path.read_bytes().decode('utf-8', 'surrogateescape').split('\n')


def hot(text):
    k = text.find('~')
    return text[k + 1].lower() if 0 <= k < len(text) - 1 else None


def dnl_strings(lang):
    out = {}
    for ln in read(RES / lang / 'dn.dnl'):
        m = re.match(r"\s*(\w+)\s*,?\s*'((?:[^']|'')*)'", ln)
        if m:
            out[m.group(1)] = m.group(2)
    return out


def dialogs(lang):
    """name -> [(line, text of the control)]"""
    out = {}
    cur = None
    in_cluster = False
    last_label = None                   # (x, y) of the label on the line before, for the labels of two lines
    for i, ln in enumerate(read(RES / lang / 'dn.dnr'), 1):
        if ln.startswith('DIALOG'):
            cur = out.setdefault(ln.split(',')[0].split()[1], [])
            in_cluster = False
            last_label = None
            continue
        if cur is None:
            continue
        if ln.startswith('END'):
            cur = None
            continue
        s = re.sub(r'^#\d+\s*', '', ln).strip()
        word = s.split()[0].rstrip(',') if s else ''
        label = None
        if not s or s.startswith(';'):
            pass
        elif word in CLUSTERS:
            in_cluster = True
        elif word in ('ComboBox', 'ListBox', 'END'):
            in_cluster = False
        elif word in ('Label', 'Button') or (word == 'ITEM' and in_cluster):
            m = STR.search(ln)
            if m:
                if word == 'Label':
                    xy = re.match(r'Label\s+(-?\d+)\s*,\s*(-?\d+)', s)
                    label = (int(xy.group(1)), int(xy.group(2))) if xy else None
                if label and last_label and label == (last_label[0], last_label[1] + 1) and cur:
                    cur[-1] = (cur[-1][0], cur[-1][1] + ' ' + m.group(1))
                else:
                    cur.append((i, m.group(1)))
        last_label = label
    return out


class HotLetterTests(unittest.TestCase):
    def test_no_letter_on_two_controls(self):
        bad = []
        for lang in LANGS:
            dnl = dnl_strings(lang)
            for name, controls in dialogs(lang).items():
                seen = collections.defaultdict(list)
                for line, text in controls:
                    if hot(text):
                        seen[hot(text)].append('line %d %r' % (line, text))
                for sid in RUNTIME.get(name, ()):
                    if hot(dnl.get(sid, '')):
                        seen[hot(dnl[sid])].append('run time %s %r' % (sid, dnl[sid]))
                for ch, where in seen.items():
                    if len(where) > 1:
                        bad.append('%s %s: %s on %s' % (lang, name, ch, '; '.join(where)))
        self.assertEqual(bad, [])

    def test_runtime_labels_exist(self):
        for lang in LANGS:
            dnl = dnl_strings(lang)
            names = dialogs(lang)
            for name, sids in RUNTIME.items():
                self.assertIn(name, names, lang)
                for sid in sids:
                    self.assertIsNotNone(hot(dnl.get(sid, '')), '%s %s' % (lang, sid))

    def test_dialogs_parsed(self):
        for lang in LANGS:
            d = dialogs(lang)
            self.assertEqual(len(d), 91, lang)
            self.assertGreater(sum(len(c) for c in d.values()), 1000, lang)


if __name__ == '__main__':
    unittest.main()
