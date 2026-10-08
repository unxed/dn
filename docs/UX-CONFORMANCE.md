# Conformance of DN to the navigation guidelines of vtui

The rules are those of [`UX_GUIDELINES.md`](https://github.com/unxed/vtui/blob/main/UX_GUIDELINES.md) of vtui (the word rules are in its `WORDNAV.md`).
The same audit for tv3, tve and fpide is `tv3/docs/UX-CONFORMANCE.md` (the numbers of the rows are the same). This file is the audit of DN (DOS Navigator),
Linux build, UTF-8 inside, against tv3 commit 62900cc (the switches `UxNavBoundary`, `UxMenuEsc`, `UxMenuAutoOpen`, `UxCtrlTab`, `UxEnterButton`,
`UxWordNav`, the units `TvWordNav` and `TvActions`).

What DN takes from tv3 and what it has of its own decides most of the table:

* from tv3 (so the new behaviour arrived with the pin, with no change in DN): the dialogs (`TDialog`, `TButton`, `TCluster`, `TInputLine`, `THistory`), the lists
  of the dialogs, the desktop (`Ctrl+Tab`), the input lines of the command line and of the dialogs;
* of its own: the menu bar and its menus (`dn/src/menus.pas`, the old Turbo Vision code; tv3's `UxMenuEsc` and `UxMenuAutoOpen` do not reach it), the file panels
  (`filepanel.pas`, `panelroot.pas`), the viewer and the editor.

No switch of tv3 had to be turned off per application: with the new tv3 the whole local suite is green (see "Regressions").

Verdicts: **conformant**, **gap** (does not hold somewhere), **conflict** (the rule and a Norton Commander / DN habit disagree: kept, for the owner),
**n/a**. How checked: `P:ux` = `tools/dn-linux-ux.py` (a pty, the screen is read; this task); `P:sweep` = `tools/dn-linux-menusweep.py` (every item of the menu
opened and left with `Esc`); `P:hot` = `tools/dn-linux-hotkeys.py` and `dn-linux-dialoghot.py` (hot letters in the three languages); `P:path` =
`tools/dn-linux-pathscan.py`; `C` = read in the code only.

## The table

| # | Rule | DN | Verdict | Checked by |
|---|---|---|---|---|
| 0.1 | `Ctrl+Tab` / `Ctrl+Shift+Tab` walk the screens | the windows (panels, viewer, editors) are walked by the desktop of tv3 | conformant | P:ux |
| 0.2 | A switcher overlay lists the titles | not done (as in tv3); DN has `Alt+0`, the list of windows | gap | C |
| 0.3 | The switch is committed when `Ctrl` is released | immediate (no key-up on most terminals) | gap | C |
| 1.1 | `Tab` / `Shift+Tab` move through the elements | dialogs: yes. The two panels: `Tab` changes the panel (the Norton rule) | conformant (dialogs) | P:ux |
| 1.2 | The cycle wraps | yes | conformant | P:ux |
| 2.1 | Arrows navigate inside a component | yes | conformant | P:ux |
| 2.2 | Arrows leave a group / list only at its boundary | radio buttons and check boxes of a dialog: `Up` on the first radio button goes to the previous element, `Down` on the last to the next (the copy dialog); otherwise the key is swallowed. Panels are not dialogs (see P.1) | conformant (dialogs) | P:ux |
| 3.1 | `Alt+<char>` activates, the label marks the letter | `~X~` in the resources; any layout (the Cyrillic hot letters are swept in two languages) | conformant | P:hot |
| 3.2 | In a dialog with no text field focused a plain letter activates | the confirmation of the delete: `N` presses "No" | conformant | P:ux |
| D.1 | `Enter` presses the default button, also in an edit field | Make directory: the name, `Enter`, the directory is made | conformant | P:ux |
| D.2 | `Esc` closes the window or dialog | copy, move, make directory, attributes; every dialog that the sweep opens is left with `Esc` | conformant | P:ux, P:sweep |
| D.3 | `F1` opens the help of the focused element | `F1` in a modal dialog opens the topic of the dialog (the copy dialog) | conformant | P:ux |
| D.4 | Drag the top border to move, the bottom right corner to resize | windows: yes; dialogs: movable, fixed size (as in tv3) | gap | C |
| G.1 | Arrows move the cursor of a group, the selection does not change | radio buttons (cursor moves, `(.)` stays) and check boxes (nothing toggles) | conformant | P:ux |
| G.2a | `Space` toggles / selects the item under the cursor | yes | conformant | P:ux |
| G.2b | `Enter` toggles the item | `Enter` presses the default button (D.1 and this rule cannot both hold) | conflict (same as tv3) | C |
| G.3 | Snake navigation in multi-column groups | `TCluster` of tv3 (the copy dialog has two groups side by side, not one multi-column group) | conformant | C |
| L.1 | `Up`/`Down`, `PgUp`/`PgDn` in lists | yes (menus, history list, list of windows) | conformant | C |
| L.2 | `Home` / `End` in lists | the lists of tv3 go to the first / last row shown (the same conflict as in tv3); the panels: first / last file | conflict (kept) | C |
| L.3 | `Up` on the first and `Down` on the last pass the focus on | dialog lists: tv3; the panels and the vertical menus wrap (the Norton rule) | conformant (dialog lists) | C |
| L.4 | `Enter` or double click performs the action | yes | conformant | P:sweep |
| L.5 | `ListBox` is a one-column `Table` | one list class | conformant | C |
| E.1 | `Left`/`Right` by one character, `Home`/`End` | yes (UTF-8 aware) | conformant | P:ux |
| E.2 | `Ctrl+Left` / `Ctrl+Right` by the far2l rules | the input lines of tv3 (`TvWordNav`): "foo bar.baz", `Ctrl+Left` goes before "baz", twice more before "bar" | conformant | P:ux |
| E.3 | `Shift` adds the finer rules | the same unit | conformant | C |
| E.4 | `Shift` + a navigation key selects | yes | conformant | C |
| E.5 | `Ctrl+C` and `Ctrl+Ins` copy | the input lines of tv3 copy on both | conformant (input lines) | C |
| E.6 | A field opened with a value clears when typing starts | the copy dialog: the first typed letter replaces the name | conformant | P:ux (by hand) |
| E.7 | The word movement of the multi-line editor follows the same rules | the editor has its own word definition (families A and B of tve) | gap (as tve) | C |
| C.1 | `Ctrl+Down` opens the list of a combo box | the history of an input line: `Ctrl+Down` opens the list with the earlier entries | conformant | P:ux |
| C.2 | A chosen item fills the field and focus returns to it | `THistory` of tv3 | conformant | C |
| C.3 | `DropdownOnly` mode | none | n/a | C |
| P.1 | File panels (the guideline says "f4 specific"): `Left`/`Right` jump a page; `Ctrl+Enter` inserts the file name | `Left`/`Right` move by one item in the columns (the Norton rule); `Ctrl+Enter` inserts the name (`filepanel.pas`, `panelroot.pas`); the keys do not change the active panel | conflict (kept) | C |
| M.1 | The bar is activated by `F9` or `Alt+<char>` | `F10` and `Alt+<letter>`. `F9` is "next window" in the editor and the viewer (`cmNext`), and nothing in the panels | conflict (kept) | P:ux |
| M.2 | `Left`/`Right` in the bar cycle the items and open their menus | fixed in `menus.pas`: opens the menu of the item moved to (before, only when a menu was open already) | conformant (fixed) | P:ux |
| M.3 | `Down` or `Enter` opens the menu | yes | conformant | P:ux |
| M.4 | `Esc` closes the drop-down and keeps the bar; the second `Esc` leaves the bar | one `Esc` leaves the whole menu (the Norton rule). `Esc` and `F10` arrive in the menu as the same command (`cmMenu`), so the two-step `Esc` cannot be added without telling them apart | conflict (kept) | P:ux (by hand) |
| M.5 | In a drop-down `Left`/`Right` close it and open the neighbour | yes, except on an item with a submenu (`View`, `Edit` of the File menu): there `Right` opens the submenu first (`RightExpand`) | conformant (with that exception) | P:ux |
| M.6 | `Up` on the first / `Down` on the last item wrap | yes | conformant | C |
| M.7 | Held arrows stop at the end | not done (needs key-up events) | gap | C |
| M.8 | A context menu passes the focus on at its boundary | the popup menu is modal and wraps | n/a | C |
| X.1 | Left click focuses / activates | yes | conformant | C |
| X.2 | Double click is `Enter` | yes (panels, lists) | conformant | C |
| X.3 | Right click for secondary actions in file panels | the right button marks files in the panels (the NC habit) | conformant | C |
| X.4 | The wheel scrolls the component under the cursor | as in tv3 (the focused window scrolls) | gap | C |
| R.1 | One action = one declaration (the registry `TvActions`) | DN keeps its resource tables (`dn.dnr`: menus, status lines, key maps); not migrated | gap | C |

Count: 46 rows: **32 conformant** (some only for dialogs or input lines, as the cell says), **7 gap** (0.2, 0.3, D.4, E.7, M.7, X.4, R.1), **5 conflict** (G.2b, L.2, P.1, M.1, M.4), **2 n/a** (C.3, M.8).

## Other keys the guidelines touch

The F keys keep their DN meaning (F5 copy, F6 move, F7 make directory, F8 delete, F10 menu): `P:ux` opens F7 and F8 after all the navigation tests.
`Ctrl+Tab` is not taken by a text view: the editor window gives it to the desktop.

## What this task changed in DN

* `menus.pas`: `Left`/`Right` in the menu bar open the menu of the item moved to (M.2). A context (vertical) menu is not affected.
* `tools/dn-linux-ux.py`: the pty test of the rules above (28 checks). `tools/dn-linux-pathscan.py`: the screens that show paths (below).
* `tools/dn-linux-menusweep.py`, `tools/dn-linux-hotkeys.py`: the arrow route to an item follows M.2 (after `Right` the menu is open, the first `Down` is not needed).

## Regressions from the new tv3

Local run of the suite against a build with the new tv3 (before and after the change in `menus.pas`): `tools/dn-linux-ops.py` with `DN_OPS_UTF8=1` (42 checks),
tour, fsattrs, names, archives, arcmembers, hotkeys, dialoghot, dialogok, colors, scrollchars, setup, qsearch, menusweep (ENGLISH), `tools/dn-test.sh`,
the python tests of `tools/tests`: all pass. The new tv3 behaviour that DN sees (the cursor of a radio group moves apart from its selection; `Esc` and `Enter` in
the stock dialogs; `Ctrl+Tab`; far2l word movement) does not break a DN key. The old DN menus were the only part that did not follow (M.2, M.4).

## Conflicts that need a decision of the owner

Nothing below was changed (except M.2 above, which is the guideline, cheap, and easy to take back: two lines in `menus.pas`).

1. **M.4, `Esc` in a drop-down.** Norton Commander and DN: one `Esc` leaves the menu. The guideline: the drop-down closes, the bar stays. In DN `Esc` and `F10`
   are the same command inside the menu code; to follow the guideline `Esc` has to become its own event there. Not done, to keep the habit.
2. **M.1, `F9`.** `F10` opens the menu (it is printed in the status line). `F9` is the next window in the editor and the viewer.
3. **P.1 and L.2.** `Left`/`Right` in the panels move by one file, `Home`/`End` go to the first / last file, as in every Norton clone.
4. **G.2b.** `Enter` on a check box presses the default button.
5. **M.5.** `Right` on a File menu item that has a submenu opens the submenu; the next menu is reached with a second `Right` on an item without one.
6. **Drive menu on Unix.** The drive menu (`Alt+F1`) numbers the places `A`, `B`, `C`... (the letter is a hot key, not a drive) and shows the temporary directory as `*: TEMP:`;
   the text names a place, not a path, so the path scan accepts it. Dropping the letters changes the hot keys of the menu.

## Paths on the Linux screens (task part 3)

`tools/dn-linux-pathscan.py` visits 19 screens (the Info panel, the drive menu of both panels, the tree, the find dialog, copy, move, make directory, the user menu,
the history list of the copy dialog and of the command line, the attributes, the Disk menu and the volume label, the length of the directory, an archive panel and
the copy dialog opened in it) and fails on `C:`, `C:\`, `\\server\share` or a backslash between names. `DN_SWEEP_PATHS=1 tools/dn-linux-menusweep.py` does the same
for every item of the menu. Both are clean. In the code: the release of the current directory before a delete (archiver, delete after the extract, running a
program) goes to the root of the host (`PathRootLen`) instead of `Copy(ActiveDir, 1, 2) + '\'`; `lfn.pas` fills the table of the current directories of the
drives only where drives exist. The ratchet `tools/check-paths.py` fell from 55 to 46.
