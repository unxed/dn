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
| `dnini.pas`, `iniengine.pas` (was `dnini_p`) | `DN.INI`: reading and writing the settings |
| `boot.pas` (was `dn1.pas`) | reading `DN.CFG` (`ReadConfig`), applying the settings after a dialog (`UpdateConfig`), `DoStartup`, `RUN_IT` (the start of the program) |
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

## Settings and the desktop: who writes what, and when
The question that comes first when a setting "is not kept" or the panels "do not come back". Checked in the sources and in a run on Linux (2026-10-03).

| What | File on disk (next to the program) | Written by | Read by |
|---|---|---|---|
| Settings of the dialogs (`StartupData`, `SystemData`, panel presets...) | `DN.CFG` (blocks `cfg*` in `dnutil.pas`) | `WriteConfig` (`dnutil.pas`): at the exit **only if** `ConfigModified` (`startup.pas`; the dialogs set it) and right after some dialogs (colors, `UpdateConfig`) | `ReadConfig` (`dn1.pas`) |
| Settings in text form | `DN.INI` (and the cache `DNINI.IN_`) | the ini engine: `dnini.pas` (the variables), `dnini_p.pas` (`RegisterVar`: what is in the file); `copyini.pas` carries values over to `StartupData` | at the start |
| Desktop saved by the user or by autosave | `DN.DSK` | `SaveRealDsk` (`dnutil.pas`): Options -> Save desktop (`cmSaveDesk`) and at the exit when `StartupData.Unload and osuAutosave` (Options -> Startup, "Autosave Desktop") | `Init` of `TDNApplication` (if there is no `DN<n>.SWP`), Options -> Load desktop (`cmLoadDesk`, `RetrieveDesktop`) |
| Desktop for the return from an external program | `DN<n>.SWP` (in `SwpDir`) | `SaveDsk` (`dnutil.pas`) at the exit, except the total exit | `Init`, then the file is erased |
| Histories | `DN.HIS` | `SaveHistories` at a normal exit | at the start |

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
`calc.pas` (the calculator window, the dBase writer), `calculat.pas` (the evaluator of expressions), `calendar.pas`, `tetris.pas`, `phones.pas` (the telephone book),
`printman.pas` (the print manager), `gauges.pas` and `gauge.pas` (progress and indicators: heap, clock), `idlers.pas` (the screen savers), `colorvga.pas` (the colors dialog),
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
| `rcp.pas` | the resource compiler (a separate program: `RESOURCE/*` → `*.LNG`, `*.DLG`) |

## Where to look for what (the first hour)
* A key does not work → `apploop.pas` (the loop), then the `HandleEvent` of the view that has the focus; the key codes are in `commands.pas`.
* A panel draws wrong → `filepanel.pas` `TFilePanel.Draw` (the partial redraw is in the same procedure: after a cursor move only two lines are drawn).
* A name is cut or padded wrong → `advance.pas` `FormatLongName` (and `dnutf8.pas` for the columns).
* The editor → `editcore.pas` (everything is one byte per column; `DocTab` in `dnutf8.pas` makes it UTF-8).
* A command is run → `dnexec.pas` → `dnrun.pas` → `tv/src/tvvtrun.pas`.
