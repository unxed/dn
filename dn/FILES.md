# What is in which file of `dn/src`

The names are often the old DOS archive names (8 characters), so the name
says little. This is the newcomer map: role of each unit and the main types.
Every `dn/src/*.pas` unit appears below (grouped tables + “Remaining units”
index). "(?)" marks a detail that was not fully verified. Origin class of
each file: [`PROVENANCE.md`](PROVENANCE.md).

## How `dn/` is laid out (since 2026-10-03)

The sources are grouped by role, not by the date they arrived. The unit names are still the old ones (the renames are the next steps, see `TODO-refactoring.md`); a build puts the
directories together (`tools/dn-env.sh`, one flat stage of links), so a unit does not know in which directory it lies.

| Directory | What is in it |
|---|---|
| `src/` | DN itself: the program, the panels, the editor, the viewer, the dialogs, the basics; the texts of the resources (`RESOURCE/`) |
| `archives/` | one unit per archive format (`fmtzip`, `fmtrar`, `fmt7z`, `fmttar`... 26 of them; were `arc_zip`...; `fmt` = format: `arczip` would clash with the constant `arcZIP`); the common code is `archiver.pas`, `archdet.pas` in `src/` |
| `compat/` | **the environment that the old code expects, made over `tv/` and the RTL of FPC:** the layer of Virtual Pascal (`osdep` (was `vpsyslow`, `vpsysext` and `vpsyslo2`), `dnscreen` (the screen glue that was in `vpsyslow`)), the Borland units on `tv/` (`drivers`, `objutil` (was `baseobjs` and `objects2`)), the layer of DPMI32 (`realmode`: was `dpmi32`, `dpmi32df` and `doslow`, one unit), the country table (`country`, was `country_`) |
| `compat/linux/` | units that replace those of `compat/` in the builds that are not for DOS (`country.pas`: the table of CP866 for Linux and Windows) |
| `compat/shims/` | the map of what DN takes from `tv/` (`shims.map`) and the hand-written parts (`manual/*.inc`); the shim units are generated from it by `tools/gen-shim.py` |
| `data/`, `tests/` | the data that DN reads, the tests of our units |

The records of the analysis of the original archive (the old names) are in [`../spec/`](../spec/README.md); the old name -> the new one: [`renames.map`](renames.map).

What is in `compat/` is not DN: it is what makes the code of DN run on a modern runtime. When the code of DN no longer asks for a unit of `compat/`, the unit goes away.

**Keep vs thin wrap (sync with `TODO-refactoring.md`, 2026-10-05):**

| Unit | Role | Policy |
|---|---|---|
| `osdep` | file/search/disk APIs with DOS error codes + name conversion | **keep** — callers check DOS codes; not a pure FPC rename |
| `dnscreen` | 16-bit cell screen glue over `tv/` | **keep** until DN reads `TvScreen` cells directly |
| `realmode` | DOS real-mode / LFN / FAT32 | **DOS only** (`GO32V2`); stubs elsewhere |
| `drivers` | keys/events/draw buffers over `tv/` | **keep** — DN↔TV border |
| `objutil` | `FreeObject` / `ObjChangeType` + stream aliases | **keep** until shims/`Collect` go |
| `country` (+ `linux/country`) | country table / CP866 upper case | **keep** |
| New VP-emulation units | — | **forbidden**; add to `tv/` or portable `src/` unless DOS real-mode only |

## The program and its commands
| File | What it holds |
|---|---|
| `dn.pas` | the main program (starts the application, the loop): `uses boot, mainapp, ...` |
| `mainapp.pas` (ours; was `dnapp.pas`) | the application class on top of `tv/` (`TApplication`, the background, the user screen) |
| `compat/dosharness.pas` (ours) | the test aid of the DOS build (`DNDUMP`, `DNKEYS`, `DNMOUSE`: keys and mouse put in, the screen dumped; `tools/dn-dos-input.py`), taken out of `mainapp.pas` |
| `commands.pas` | all constants: commands `cm*`, key codes `kb*` (DN's codes include the scan code: `kbCtrlS = $041F13`), help contexts |
| `dnutil.pas` | the central dispatcher of the commands of the application (`TDNApplication`: menu items, windows, Ctrl-O...) |
| `apploop.pas` (was `u_myapp`) | the event loop of the application (keys before the dispatch, macros, the idle work) |
| `dnexec.pas`, `dnrun.pas` (ours) | running an external program / a command of the command line: `dnrun.pas` is the portable facade (`HasCommandScreen`, `ShowCommandScreen`), the targets are in `compat/dnrun*.pas` |
| `cmdline.pas` | the command line of the panels (`TCommandLine`) |
| `menus.pas` | menus, the menu bar, the status line (the hot letters) |
| `setups.pas`, `paneldlgs.pas` (was `fltools`) | the dialogs of the settings; the dialogs of the panel (select group, filter, the button "Save setup") |
| `panelsetup.pas` (was `pdsetup`), `panelwinx.pas` (was `xdblwnd`), `fsinfo.pas` (was `fltl`) | the settings records of a panel (show, sort); the window with two panels, the extended one; the information of the file system (cluster, serial number, file ages) |
| `dnini.pas`, `iniengine.pas` (was `dnini_p`) | `dn.ini`: reading and writing the settings |
| `boot.pas` (was `dn1.pas`) | reading the settings image of `dn.ini` (`ReadConfig`; the old `dn.cfg` once), applying the settings after a dialog (`UpdateConfig`), `DoStartup`, `RUN_IT` (the start of the program) |
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
| `filediz.pas` | file descriptions (`descript.ion`, `files.bbs`) |
| `fstorage.pas` | the storage of directories (a hash of the names of directories) |
| `diskinfo.pas`, `diskimg.pas` | disk information panels; disk-image helpers |

## The names of the files (a rule, 2026-10-04) and which file holds what
All names are lower case (the sources, the directories, the files that the program reads and writes, `dist/`): the Linux file systems tell `DN.INI` from `dn.ini`, DOS does not care, and one case is enough. The names stay 8.3 where the program writes them (DOS).
The names of the units are words without digits and underscores (a unit has the name of its file). Where a name is in capitals on purpose (`README`, `LICENSE`, `CWSDPMI`'s own texts) it is a document, not a file of the program.

| What | File on disk (next to the program) | Written by | Read by |
|---|---|---|---|
| Settings of the dialogs (`StartupData`, `SystemData`, panel presets...): a **binary** image of the records (the old format of `dn.cfg`), now **inside `dn.ini`**, in the section `[Saved]` as hex pieces (`[Saved<suffix>]` for `DNCFG=<suffix>`) | `dn.ini`, section `[Saved]` (`cfgstate.pas`; the blocks `cfg*` of the image are in `dnutil.pas`). The old `dn.cfg` is read once if the section is not there and is renamed to `dn.old` | `WriteConfig` (`dnutil.pas`): at the exit **only if** `ConfigModified` (`startup.pas`; the dialogs set it) and at some other places | `ReadConfig` (`boot.pas`) at the start |
| Settings in **text** form (the new way, a person may edit it: Options -> edit `dn.ini`) | `dn.ini` | the ini engine: `iniengine.pas` (`RegisterVar`: what is in the file), the variables are in `dnini.pas`; `copyini.pas` carries values over to `StartupData` | at the start |
| The cache of the parsed `dn.ini` (the start is faster; safe to delete; was `dnini.in_`) | `dn.cbc` | `iniengine.pas` | `iniengine.pas` |
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

One file for the settings (2026-10-04): the image of the records that `dn.cfg` held lives in the section `[Saved]` of `dn.ini` (hex, written by DN at the exit, not for editing; `cfgstate.pas`), the rest of the file (the comments, the settings of the people) is not touched. Making a text key of every field of every record (instead of the image) is a later step (`TODO-later.md`).
One directory: every file in the table is composed as `SourceDir + name` (`basics.SourceDir`: the directory of the program, or the directory in the environment variable `DN2`, set in `dlgrecs.pas`), so the settings, the histories and the desktop can be moved by `DN2`; the Unix per-user directory (`~/.config/dn`) is not the default yet (`TODO-later.md`).

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
| `histories.pas` (was `histries`) | the histories of the edited and viewed files |

## Archives
| File | What it holds |
|---|---|
| `archiver.pas` | the work with archivers (the external programs: lists, extraction); `archdet.pas`: the detection of the type of an archive; `fmt*.pas` of `archives/`: one archive format each |
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
| `winsess.pas` (was `os2sess`, `advance4`) | running a program in a new window on Windows (the OS/2 sessions are dropped) |
| `dndlgs.pas`, `dnstrl.pas`, `dncolor.pas`, `palettes.pas` (was `dnpalet`: `CColor` is the colors of DN as `data/colors/default.pal`, `CColorOsp` the table of the OSP source) | the classes of DN that were carved out of the files that came from Borland (combo box, notepad pages, the string list, the palettes) |
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
| `cfgstate.pas` (ours) | the image of the records of the dialogs (what `dn.cfg` held) in the section `[Saved]` of `dn.ini`: hex pieces, read and written through `profile.pas` |
| `fatalerr.pas` (the place of an address and the wait for a key at the fatal-error screen of `dn.pas`; was in `vpsyslow`, ours) | what the crash screen needs |
| `compat/dnscreen.pas` (the 16-bit cell screen and the cursor of DN over `tv/`, was the `SysTv*` part of `vpsyslow`, ours) | the copy of the screen for the code that reads the screen, the cursor shape |
| `compat/dnuserscreendos.pas` (ours) | GO32V2 BIOS/video-memory handling for restoring, capturing, and showing the external-program user screen |
| `compat/osnamesunix.pas`, `compat/osnamesdos.pas` (ours) | the names of the files of DN at the border of Unix (cp866 <-> UTF-8, the case, the paths) and of DOS (the AMIS provider `DOS-UTF8/NAMES`); `osdep` calls them |
| `compat/dnrundos.pas`, `dnrunlinux.pas`, `dnrunother.pas` (ours) | the backends of `dnrun.pas`: DOS (the user screen, COMMAND.COM), Linux (a pty through `TvVtRun`, the screen of the commands), the rest (the terminal goes to the shell) |
| `compat/osrun.pas` + `osrununix.pas`, `osrunwindows.pas`, `osrundos.pas` (ours) | starting programs and restarting DN: the facade and the backends (the DOS way `COMSPEC /c command` on Unix) |
| `compat/ossystem.pas` + `ossystemdos.pas`, `ossystemother.pas` (ours) | the small calls of the system: device test, volume label, disk buffers, the speaker, memory |
| `compat/osstartscreen.pas` (ours) | the text screen of the program that started DN (DOS), grabbed at the start |
| `compat/osdep.pas` (was `vpsyslow`, ours), `realmode.pas` (was `dpmi32`, `dpmi32df` and `doslow`) | the system layer: files, drives, time, keys, the terminal, running programs, the search of a directory with the times of a file, the calls of the real mode of DOS (replaces the runtime of Virtual Pascal; named by what it does) |
| `compat/country.pas` (was `country_`; DOS), `compat/linux/country.pas` (ours) | the country information and the upper-case table of CP866 for Linux |
| `rcp.pas` | the resource compiler (a separate program: `resource/*` → `*.LNG`, `*.DLG`) |

## Remaining units (full index)

Units not already named in the tables above. One line each so the tree has
no silent gaps (post-class criterion A).

| File | What it holds |
|---|---|
| `archread.pas` | reading archive member streams for viewers / extract |
| `archset.pas` | archiver setup dialogs and `ARCHIVER.INI` editing |
| `arvidtdr.pas` | Arvid tape drive low-level (historic) |
| `asciitab.pas` | ASCII table dialog (Borland-style replacement) |
| `colors.pas` | Colors dialog, highlight groups, Window Manager list |
| `dbwatch.pas` | DBF viewer field / watch helpers |
| `defcoll.pas` | definition collections used while building resources |
| `dirwatch.pas` | directory-change watch stub (all targets) |
| `dnhelp.pas` | help context IDs and help wiring for DN |
| `dnstddlg.pas` | standard file-name dialogs (`GetFileNameDialog` / menu stub) |
| `eraser.pas` | erase-files engine used by panels |
| `fileerrors.pas` | file I/O error messages (was `errmess`) |
| `filelst.pas` | file-list helpers for dialogs and histories |
| `filetype.pas` | file-type / extension classification for panels |
| `findobj.pas` | find-object UI pieces for file find |
| `hash.pas` | hash-table helpers (file collections, etc.) |
| `helpfile.pas` | help file reader (Borland help format glue) |
| `helpkern.pas` | help kernel / topic navigation |
| `inifiles.pas` | generic INI parse helpers under `iniengine` |
| `listmakr.pas` | string-list maker used by the resource toolchain |
| `messages.pas` | message boxes / `ErrMsg` wrappers over `tv/` |
| `objtype.pas` | stream object-type numbers (`ot*`) for DN classes |
| `pktview.pas` | FidoNet `.pkt` viewer |
| `rstrings.pas` | resource string index glue |
| `strview.pas` | string viewer widget |
| `timeutil.pas` | time helpers (was `xtime`; `GetCurMSec`, etc.) |
| `titleset.pas` | window title stack / set helpers |
| `uniwin.pas` | generic / user window types |
| `uselfn.pas` | LFN-related constants (was `files`) |
| `usersavr.pas` | user screen / output window savers |
| `uue2inc.pas` | uue decode / mail include tools |
| `version.pas` | version and build stamp strings |
| `winclp.pas` | system clipboard bridge via `TvClip` |

## Where to look for what (the first hour)
* A key does not work → `apploop.pas` (the loop), then the `HandleEvent` of the view that has the focus; the key codes are in `commands.pas`.
* A panel draws wrong → `filepanel.pas` `TFilePanel.Draw` (the partial redraw is in the same procedure: after a cursor move only two lines are drawn).
* A name is cut or padded wrong → `basics.pas` / `fileutil.pas` `FormatLongName` (and `dnutf8.pas` for the columns).
* The editor → `editcore.pas` (everything is one byte per column; `DocTab` in `dnutf8.pas` makes it UTF-8).
* A command is run → `dnexec.pas` → `dnrun.pas` → `compat/dnrunlinux.pas` → `tv/src/tvvtrun.pas`.
