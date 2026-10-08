# The resources of DN

The dialogs, menus, status lines and strings of each language are text files in `dn/src/resource/<language>/`:

| file | what it holds | compiled to |
|---|---|---|
| `dn.dnl` | the strings (`dlXxx` of `TStrIdx`, one per line: `dlName 'text'`) | `<language>.lng` |
| `dn.dnr` | the dialogs, the menus, the status lines, the colour dialog, the editor commands | `<language>.dlg` |
| `dnhelp.htx` | the help | `<language>.hlp` (by `tv/tools/tvhc.pas`) |
| `../actions.dna` | the actions of the menus and the status lines, for all the languages (below) | the resource `dlgActions` of each `<language>.dlg` |

`rcp` (`dn/src/rcp.pas`, run by `tools/build.sh`) compiles them; `dn/src/rcpvpd.ini` names the languages, the input and output
files and the Pascal units whose constants the resources may name (`cm*`, `hc*`, `hs*`, `kb*`, `of*`, `TDlgIdx`, `TStrIdx`).
The compiled files are streams of the objects of tv3 and DN (registered in `dn/src/regall.pas`); they are made again by every
build, so their format follows the sources (no compatibility with the files of the old DN).

Lines that start with `;` are comments; `;$IFDEF NAME`, `;$ELSE`, `;$ENDIF` keep or drop lines by the defines of
`dn/src/stdefine.inc`. Strings are in single quotes; `^M`, `#13` outside the quotes give control characters; `~X~` marks the
hot letter. Numbers and the names of constants are separated by commas.

## Dialogs

```
DIALOG dlgName, width, height, 'Title'
    HELPCTX hcName
#1  InputLine x1, y1, x2, y2, maxlen, hsHistory      (y2 is ignored: one row; hsHistory 0 = no history list)
    GROW gfGrowHiX                                    (optional, see below)
    Label x, y, '~T~ext', ofPostProcess, ofPreProcess (linked to the control before it)
    ...
END
```

The controls: `InputLine`, `LongInputLine` (no history), `HexLine` (the hex view of the input line before it), `Label`,
`StaticText x1, y1, x2, y2, 'text'`, `ParamText x1, y1, x2, y2, 'text', count`, `Button x1, y1, x2, y2, 'text', cmCommand,
bfDefault...`, `CheckBoxes`, `RadioButtons`, `ComboBox`, `DriveCheckBoxes` (each `x1, y1, x2, y2` and then `ITEM 'text'` lines
up to `END`), `ScrollBar`, `MouseScrollBar` (`x1, y1, x2, y2`), `ListBox x1, y1, x2, y2, columns` (with the scroll bar defined
just before it), `ColorPoint x, y, colour`. The names `of*` at the end of a control line are added to its `Options`; `HELPCTX`
after a control gives the help context of the control; `SelectForward` / `SelectBack` move the focus; `#1` ... `#9` at the start
of a line keep the control in `DirectLink[1..9]` of the dialog (the code of DN finds it there).

`NOTEPAD dlgName, width, height, 'Title', bookmarkStart` is a dialog with pages: `PAGE 'title'` ... `END` hold the controls of
each page. `DIALOG dlgSystemSetup` makes `TSysDialog`.

### Resizing (grow modes)

A `DIALOG` is a `TResDialog` (`dn/src/dlglayout.pas`): it has the resize corners of tv3 and, when it is shown, gives each control
a grow mode (`TView.GrowMode` of tv3) by its layout rule:

- input lines (`InputLine`, `LongInputLine`, `HexLine`) stretch to the right; list views stretch to the right and down. Of
  several in the same rows only the rightmost stretches; of several in the same column only the lowest stretches down;
- a control to the right of one that stretches or moves (in the rows it covers) moves with the right edge; a control below
  one that stretches down moves with the bottom edge;
- buttons move with the right edge unless something that stretches is to the right of them;
- the scroll bars of a list view follow the list view.

The rule also covers the controls that the code of DN inserts after loading (the lists of the history dialogs, the phone
book, the environment editor). The dialog grows only in the directions where something stretches, and never becomes smaller
than it was shown. Two statements change the rule:

| statement | where | meaning |
|---|---|---|
| `GROW flag, flag...` | after a control | the grow mode of that control (the control, not its label): `gfGrowLoX`, `gfGrowLoY`, `gfGrowHiX`, `gfGrowHiY`, `gfGrowAll`, `gfGrowRel` or a number; `GROW 0` keeps it in place. The layout keeps it and counts it as stretching or moving |
| `RESIZE NONE` / `X` / `Y` / `XY` | anywhere in the dialog | the directions the dialog may grow in, instead of the ones the layout finds (`NONE`: a fixed size) |

`NOTEPAD`, `dlgSystemSetup` and the colour dialog keep their size.

In the stream, a control with `GROW` has the bit `gfExplicit` ($80) in its `GrowMode` (`TResDialog.Load` takes it off), and
`TResDialog` stores one byte after `TDialog`: the `RESIZE` value (`$FF` = as the layout finds).

## Actions, menus and status lines

An action is a command that a menu item or a status line offers, with its key, the text of the key in the menu and its help
context. Each is declared once, for all the languages, in `dn/src/resource/actions.dna` (named by `Actions=` of `rcpvpd.ini`):

```
ACTION main.ViewFile, cmViewFile, kbF3, 'F3', hcFileMenu
ACTION key.Help.F1,   cmHelp,     kbF1, '',   0
```

The names: `main.*`, `editor.*`, `fixer.*`, `sheet.*` for the items of the main menu, the editor, the disk editor and the
spreadsheet (the command without `cm`, `.2` for its second item in the same menu), `key.<command>.<key>` for a key that only a
status line binds. The menus and the status lines of each language name the actions; the caption stays in the language:

```
MENU dlgMainMenu
  SUBMENU '~F~ile', hcFileMenu
    MENUITEM 'M~a~in viewer', main.ViewFile
    MENULINE
  END
END

STATUSLINE
  STATUSDEF hcFrom, hcTo
    STATUSITEM '~F1~ Help', key.Help.F1
    STATUSITEM '~Esc~ Cancel', kbNoKey, cmNo
  STATUSDEF hcOther, hcOther
    ...
END
```

`MENUITEM 'caption', action` takes the key, the text of the key, the command and the help context from the action;
`STATUSITEM 'text', action` the key and the command. The older forms `MENUITEM 'caption', 'key text', kbKey, cmCommand, hcContext`
and `STATUSITEM 'text', kbKey, cmCommand` still compile; the resources use them only for the hints of the status lines that bind
no key (`kbNoKey`). A `STATUSDEF` holds the items for the help contexts `hcFrom..hcTo` (the first that matches the context of the
focused view is shown); an item with an empty text is a key binding only.

Where a language has other keys than `actions.dna` (the Russian and the Ukrainian DN have some), its `dn.dnr` says so once, in a
block before the menus:

```
ACTIONS
  main.MakeList, kbAltW, 'Alt-W'
  main.SetFAttr, kbAltF, 'Alt-F', hcPanelMenu
END
```

(name, key, key text and, if it differs, the help context). The menus and the status lines of that language then use those keys.

`rcp` stores the table of the actions of each language (with the caption of the menu item that names the action) as the resource
`dlgActions` (`TActionTable`, `dn/src/dnactions.pas`); at start DN puts it into the registry `TvActions` of tv3
(`dn/src/dnactreg.pas`), where an action is found by its name, its command or its key. `dn/tests/t_actions.pas` checks that every
menu item and every key of the status lines of the three languages is an action of the table.

## Other blocks

`COLORDIALOG` ... `END`: the groups (`COLORGROUP 'name'`) and items (`COLORITEM 'name', index`) of the colour dialog.
`EDITOR COMMANDS` ... `END`: the key sequences of the editor (`COMMAND cmCommand, kbKey1, kbKey2, 'c1', 'c2'`).
