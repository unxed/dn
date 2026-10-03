# What is in which file of `dn/src`

The names are the DOS names of the archive (8 characters), so the name often says little. This is a map for a newcomer: the files that you meet first,
what each holds and the main types in it (`T…` classes are `object` types of Turbo Vision style). It is not complete; "(?)" marks what was guessed
from a name and not checked: fix it when you know. The class of every file by origin is in [`PROVENANCE.md`](PROVENANCE.md).

## How `dn/` is laid out (since 2026-10-03)

The sources are grouped by role, not by the date they arrived. The unit names are still the old ones (the renames are the next steps, see `TODO-refactoring.md`); a build puts the
directories together (`tools/dn-env.sh`, one flat stage of links), so a unit does not know in which directory it lies.

| Directory | What is in it |
|---|---|
| `src/` | DN itself: the program, the panels, the editor, the viewer, the dialogs, the basics; the texts of the resources (`RESOURCE/`) |
| `archives/` | one unit per archive format (`arc_zip`, `arc_rar`, `arc_7z`, `arc_tar`... 26 of them); the common code is `archiver.pas`, `archdet.pas` in `src/` |
| `compat/` | **the environment that the old code expects, made over `tv/` and the RTL of FPC:** the layer of Virtual Pascal (`vpsyslow`, `vpsysext` (was `vpsyslo2`), `vputils`, `use16`, `memory`), the Borland units on `tv/` (`drivers`, `baseobjs` (was `objects2`)), the layer of DPMI32 (`dpmi32`, `dpmi32df`, `doslow`), the country table (`country_`) |
| `compat/linux/` | units that replace those of `compat/` in the builds that are not for DOS (`country_.pas`: the table of CP866 for Linux and Windows) |
| `compat/shims/` | the map of what DN takes from `tv/` (`shims.map`) and the hand-written parts (`manual/*.inc`); the shim units are generated from it by `tools/gen-shim.py` |
| `data/`, `tests/` | the data that DN reads, the tests of our units |

What is in `compat/` is not DN: it is what makes the code of DN run on a modern runtime. When the code of DN no longer asks for a unit of `compat/`, the unit goes away.

## The program and its commands
| File | What it holds |
|---|---|
| `dn.pas` | the main program (starts the application, the loop): `uses boot, mainapp, ...` |
| `mainapp.pas` (ours; was `dnapp.pas`) | the application class on top of `tv/` (`TApplication`, the background, the user screen) |
| `commands.pas` | all constants: commands `cm*`, key codes `kb*` (DN's codes include the scan code: `kbCtrlS = $041F13`), help contexts |
| `dnutil.pas` | the central dispatcher of the commands of the application (`TDNApplication`: menu items, windows, Ctrl-O...) |
| `apploop.pas` (was `u_myapp`) | the event loop of the application (keys before the dispatch, macros, the idle work) |
| `dnexec.pas`, `dnrun.pas` (ours) | running an external program / a command of the command line (on Linux: the embedded terminal) |
| `cmdline.pas` | the command line of the panels (`TCommandLine`) |
| `menus.pas` | menus, the menu bar, the status line (the hot letters) |
| `setups.pas`, `paneldlgs.pas` (was `fltools`) | the dialogs of the settings; the dialogs of the panel (select group, filter, the button "Save setup") |
| `panelsetup.pas` (was `pdsetup`), `panelwinx.pas` (was `xdblwnd`), `fsinfo.pas` (was `fltl`) | the settings records of a panel (show, sort); the window with two panels, the extended one; the information of the file system (cluster, serial number, file ages) |
| `dnini.pas`, `iniengine.pas` (was `dnini_p`) | `dn.ini`: reading and writing the settings |
| `boot.pas` (was `dn1.pas`) | reading `dn.cfg` (`ReadConfig`), applying the settings after a dialog (`UpdateConfig`), `DoStartup`, `RUN_IT` (the start of the program) |
| `macro.pas` | the macros of the editor (record, play) |

## Panels and files
| File | What it holds |
|---|---|
| `filepanel.pas` (was `flpanel`) | one file panel: drawing, keys, quick search, the info and the title lines (`TFilePanel`, `TInfoView`, `TDirView`) |
| `panelroot.pas` (was `flpanelx`) | the panel with its settings, sort and selection (`TFilePanelRoot`) |
| `panelwin.pas` (was `dblwnd`) | the window with two panels (`TDoubleWindow`) |
| `filescol.pas` | the collection of the records of files and their sort keys (`TFilesCollection`) |
| `drives.pas` | a drive: where the list of a panel comes from (`TDrive`); `filefind.pas`: the drive of the search results; `arcview.pas`: an archive as a drive; `arvid.pas`, `arvidavt.pas`: the drive of the Arvid video-tape streamer (historic) |
| `filecopy.pas` | copy, move, delete (the engine and the dialogs) |
| `tree.pas` | the directory tree |
| `lfn.pas` | long file names (DOS: the services of Windows 95; elsewhere: thin) |
| `filediz.pas` | the descriptions of files (`descript.ion`, `files.bbs`) (?) |
| `fstorage.pas` | the storage of directories (a hash of the names of directories) |
| `diskinfo.pas`, `diskimg.pas` | the information about a disk; disk images (?) |

## The names of the files (a rule, 2026-10-04) and which file holds what
All names are lower case (the sources, the directories, the files that the program reads and writes, `dist/`): the Linux file systems tell `DN.INI` from `dn.ini`, DOS does not care, and one case is enough. The names stay 8.3 where the program writes them (DOS).
The names of the units are words without digits and underscores (a unit has the name of its file). Where a name is in capitals on purpose (`README`, `LICENSE`, `CWSDPMI`'s own texts) it is a document, not a file of the program.

| What | File on disk (next to the program) | Written by | Read by |
|---|---|---|---|
| Settings of the dialogs (`StartupData`, `SystemData`, panel presets...): a **binary** dump of the records (the old way) | `dn.cfg` (blocks `cfg*` in `dnutil.pas`) | `WriteConfig` (`dnutil.pas`): at the exit **only if** `ConfigModified` (`startup.pas`; the dialogs set it) and at some other places | `ReadConfig` (`boot.pas`) at the start |
| Settings in **text** form (the new way, a person may edit it: Options -> edit `dn.ini`) | `dn.ini` | the ini engine: `iniengine.pas` (`RegisterVar`: what is in the file), the variables are in `dnini.pas`; `copyini.pas` carries values over to `StartupData` | at the start |
| The cache of the parsed `dn.ini` (the start is faster; safe to delete; was `dnini.in_`) | `dn.cac` | `iniengine.pas` | `iniengine.pas` |
| Desktop saved by the user or by autosave | `dn.dsk` | `SaveRealDsk` (`dnutil.pas`): Options -> Save desktop (`cmSaveDesk`) and at the exit when `StartupData.Unload and osuAutosave` (Options -> Startup, "Autosave Desktop") | `Init` of the application |
| Desktop for the return from an external program | `dn<n>.swp` (in `SwpDir`) | `SaveDsk` (`dnutil.pas`) at the exit, except the total exit | `Init`, then the file is erased |
| Histories | `dn.his` | `SaveHistories` at a normal exit | at the start |
| The clipboard of the editor between runs (was `clipboar.dn`) | `dn.clp` | `TDNApplication.Done` when "save the clipboard" is on | at the start |
| Tetris | `tetris.cfg` | `tetris.pas` | `tetris.pas` |
| The groups of files for the colors/highlight of the panels (?) | `dnhgl.grp` | by hand | `boot.pas`, `dnutil.pas` |
| The commands of the archivers | `archiver.ini` | by hand | `archiver.pas` |
| The flag of a running copy in the swap directory | `dn.flg` | `dnutil.pas` | `dnutil.pas` |
| Reports of a crash and the log of the start | `dn.err`, `dnerr.txt`, `dnlog.txt` | `dn.pas`, `dnerrlog.pas`, `mainapp.pas` | people |
| Resources: dialogs, menus, strings, help of a language | `<language>.dlg`, `<language>.lng`, `<language>.hlp` (`english`, `russian`, `ukrain`) | the build (`rcp`, `tvhc`) | `mainapp.pas`, `langid.pas` |
| Tables of the layouts of the keyboard, the palettes | `xlt/*.xlt`, `colors/*.pal` (from `dn/data/`) | people | `xcode.pas`, `dnutil.pas` |

Why two files for the settings: `dn.cfg` is the memory dump of the records of the dialogs (what DN did first); `dn.ini` is the text file that came later and holds the rest. Merging them (everything in `dn.ini`) is in `TODO-refactoring.md`.

* The flags of the Startup dialog are `osu*` in `commands.pas` (`osuAutosave = $02`, `osuPreserveDir = $08`...); `StartupData.Load` is for the start, `.Unload` is for the exit. The dialog is in `setups.pas`.
* What goes into the desktop file is decided by the `Store` of each view: `TDoubleWindow` (`dblwnd.pas`), the panels (`flpanelx.pas`). For example the directory of the **active** disk panel is stored only with "Preserve directory" (`osuPreserveDir`); the passive panel always keeps it.
* The button "Save setup" of the panel setup dialogs is `TSaveSetupButton` in `paneldlgs.pas`: it writes the panel settings into the presets 1..10 (and sets `ConfigModified`) or into the active/passive panel (they are kept in the desktop only).
* A setting is not kept → is `ConfigModified` set for it? does the exit reach `Done` (Alt-X, exit code 0)? is it in `WriteConfig` or in `DN.INI`? A panel is not restored → is it in `Store`?

## The viewer and the editor
| File | What it holds |
|---|---|
| `fviewer.pas` | the viewer (F3): text, hex, the other modes (`TFileViewer` and its variants) |
| `editcore.pas` (was `microed`) | the core of the editor (`TFileEditor`): the text as lines, the cursor, the block, search, undo |
| `editfile.pas` (was `microed2`) | the support of the editor: load and save of files, the scan of a document (`ScanDocU8`) |
| `editor.pas` | the editor windows and the entry points (`TXFileEditor`, `EditFile`) |
| `editwin.pas` (was `edwin`) | the window of the editor (`TEditWindow`) and its saver of the state (`TEditSaver`) |
| `editundo.pas` (was `ed2`) | the undo list, the bookmarks, the info line (`TDoCollection`, `TBookmarkLine`) |
| `highlite.pas` | the syntax highlighting of the editor |
| `dbview.pas` | the viewer of dBase files |
| `histries.pas` | the histories of the edited and viewed files |

## Archives
| File | What it holds |
|---|---|
| `archiver.pas` | the work with archivers (the external programs: lists, extraction); `archdet.pas`: the detection of the type of an archive; `arc_*.pas`: one archive format each |
| `uucode.pas`, `decoder.pas` | uuencode and decoding of mail files |

## Tools and extras
`calcwin.pas` (was `calc`: the calculator window, the dBase writer), `evaluator.pas` (was `calculat`: the evaluator of expressions), `calcline.pas` (was `ccalc`: the line of the calculator and its indicator), `bwselect.pas` (was `dncolor`: the selector of the black and white colors), `calendar.pas`, `tetris.pas`, `phones.pas` (the telephone book),
`printman.pas` (the print manager), `progress.pas` (was `gauge`: the progress windows and bars) and `gadgets.pas` (was `gauges`: the trash can, the key macros, the heap and clock indicators), `idlers.pas` (the screen savers), `colorvga.pas` (the colors dialog),
`usermenu.pas` (the user menu F2, the output window, the screen grabber), `cellscol.pas` (the collection of the cells of the calculator).

## Basics that everything uses
| File | What it holds |
|---|---|
| `basics.pas` (was `advance`) | the basics: `FormatLongName`, the text reader, the memory checks, `ClrIO`, small helpers |
| `strutil.pas` (was `advance1`) | strings: padding, centering, case, search in a string (Boyer-Moore), counting |
| `fileutil.pas` (was `advance2`) | files: existence, times, erase, compare, names of temporary files, the quick search of a panel |
| `envutil.pas` (was `advance3`) | the command line and the environment (`FindParam`, `GetEnv`), the time of the day, CRC32 |
| `linepos.pas` (was `advance6`) | the line number of an offset in a file and back, the hot letter of a string, the CRC table |
| `langid.pas` (was `advance7`) | the language of the program and of the help (`LngId`, `HelpLngId`) |
| `os2sess.pas` (was `advance4`) | running a program in a session of OS/2 (not used on our targets) |
| `dndlgs.pas`, `dnstrl.pas`, `dncolor.pas`, `dnpalet.pas` | the classes of DN that were carved out of the files that came from Borland (combo box, notepad pages, the string list, the palettes) |
| `compat/drivers.pas` (ours) | the keys, the events, the draw buffers on top of `tv/` (`DNKeyCode`, `GetAltChar`, `LegacyText`) |
| `dnutf8.pas` (ours) | UTF-8 inside DN: columns, the proxy of a string, the table of a document of the editor |
| `keymap.pas` (was `u_keymap`) | the code page detector and the key maps of the editor |
| `videoman.pas` | the video modes and the palette (as far as the terminal has them) |
| `copyio.pas` (was `fbb`) | the low level of copying a file: reading and writing in big blocks, the overwrite question, the info of the copy (`LongCopy`, `CopyDialog`) |
| `inputfname.pas` (was `swe`) | the input line of a file name (`TInputFName`) and the colour point of the colour dialogs (`TColorPoint`) |
| `findspf.pas` (was `u_srchf`) | search of a file by a path template (`FindFileWithSPF`) (?) |
| `dlgrecs.pas` (was `startupp`) | the records of the dialogs: list boxes, the savers (`TListBoxRec`, `TSaversData`); split from `startup.pas` to cut the circular uses |
| `topview.pas` (was `topview_`) | the view that shows the top of a stack of windows and the sorted view (`TTopView`, `TSortView`) |
| `regall.pas` | the registration of all the object types for the streams (the resource files) |
| `profile.pas`, `getconst.pas` | a buffered stream; the constants that the resource compiler reads |
| `compat/`: `vpsyslow.pas`, `vputils.pas`, `use16.pas` (ours); `vpsysext.pas` (was `vpsyslo2`: the extension of the layer written by JO of DN OSP) | the system layer: files, drives, time, keys, the terminal, running programs (replaces the runtime of Virtual Pascal) |
| `compat/country.pas` (was `country_`; DOS), `compat/linux/country.pas` (ours) | the country information and the upper-case table of CP866 for Linux |
| `rcp.pas` | the resource compiler (a separate program: `resource/*` → `*.LNG`, `*.DLG`) |

## Where to look for what (the first hour)
* A key does not work → `apploop.pas` (the loop), then the `HandleEvent` of the view that has the focus; the key codes are in `commands.pas`.
* A panel draws wrong → `filepanel.pas` `TFilePanel.Draw` (the partial redraw is in the same procedure: after a cursor move only two lines are drawn).
* A name is cut or padded wrong → `advance.pas` `FormatLongName` (and `dnutf8.pas` for the columns).
* The editor → `editcore.pas` (everything is one byte per column; `DocTab` in `dnutf8.pas` makes it UTF-8).
* A command is run → `dnexec.pas` → `dnrun.pas` → `tv/src/tvvtrun.pas`.
