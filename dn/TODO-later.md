# Not in the first version

The first version is the original public code with a minimum of changes (PLAN.md,
decision 10). Everything else goes here: refactorings, fixes of old bugs, improvements,
doubtful places that were found on the way. Format: a line with the file, what, and why it
was not done now.

## Doubtful places found while making dn.pas compile (2026-10-02)

- stdefine.inc: the tree is evaluated with VIRTUALPASCAL defined (dn/target.env), otherwise the branch for Borland Pascal
  (BIT_16, no DualName/USELFN) is taken. FPC itself never sees VIRTUALPASCAL (the branches are stripped).
- netbrwsr.pas (Windows network browser) is excluded for the DOS target; flpanel.pas only named it (edit 87). The original
  DOS (DPMI32) configuration did not compile without it either (unit Windows).
- views.inc: TaggedDataOnly/TaggedDataCount exist but tv/ TGroup.GetData does not honour them (the "tagged controls only" data).
- tv/: TDialog.DirectLink, TScrollBar.Step/ForceScroll, TView.EnableCommands (methods) were added for DN. DN's
  TInputLine.Data is an AnsiString, in tv/ it stays PStr; the few DN sites use `Data^` (edit 89).
- Comp -> Int64 (edit 82): in VP Comp is a 64-bit integer; sizes/positions are Int64 here.
- Word is 16 bit here, 32 bit in VP (see the earlier notes): Dos.GetDate/GetTime variables of uucode.pas are Word (edit 86).
- objects2.pas is ours (dn/new): ObjChangeType assumes that the VMT link is the first pointer of an instance (true for tv/ objects).
- ExecFlags/TExecFlags (vpsyslow.pas): only the names; DN compares ExecFlags = efAsync, the value is never set.
- cellscol.pas (spreadsheet): the values of the cells are Double (8 bytes) in the files, Real48 (6 bytes) in the original
  (FPC cannot convert Real48): the spreadsheet files of the original cannot be read, ours cannot be read there (edit 92).
- wfMaxi (views.inc): the flag and the command cmMaxi (maximize a window over the desktop, DN) are not implemented in tv/ yet.
- GetPalette^ := X (dbview.pas and others): DN changes the palette of a view by writing into it; the assignments are dropped (edit 105), the default palettes are used.
- dpmi32.pas: `ShadowCount: Integer = 0` (an initialized variable of the unit) was 8 when the program started under DOSBox-X
  (DOS, go32v2), so DosShadow found its table full; it is set to 0 in the initialization. The cause is not understood
  (the value of another unit's static data? check that the initialized data of the exe are loaded whole).

## Added with the resource compiler (rcp) run
- Argument evaluation order: VP evaluates call arguments left to right, FPC right to left. edit 117 hoists the
  `Token(S, i)` reads of rcp.pas into temporaries. Other places of the tree may depend on the order too (look when a
  value is "shifted" at run time).
- `{$PACKRECORDS 1}` is added to STDEFINE.INC (vpc.cfg: `$AlignRec-`): the data records of the dialogs (TSysData...) must
  be byte-aligned. It also packs the `object`s of DN units (VP aligns objects by `$AlignData+`): check if it matters.
- tv `TListBoxRec` is `packed` with a LongInt `Selection` (DN: Integer, 32 bits in the Delphi mode). The Word of the
  original TV is not kept; `TvList.ListBoxOwnsList` (default True, TV) is set to False by DNApp: TListBox.Done of DN does
  not dispose the list (TSysDialog.Done does it).

## Seen in DOSBox-X (2026-10-02), not done yet
- Running a program (edit 121, dn/new/dnrun.pas): the application stays alive, the screen goes to the text mode, COMMAND.COM runs
  the command, a key returns. Not done: the screen of the program is not kept for the user screen (Ctrl-O, Alt-F5), the
  program is not run in a window, no time information (TimerMark), the cursor and the video mode that the program left are
  not restored in all cases.
- The saved desktop (DN.DSK / swap) is not checked: the panels open at the next start only because no desktop is saved.
- DOSBox-X without a display reports Alt as pressed (BIOS flags 0040:0017 bit 3): the status line shows the Alt labels;
  DNApp clears the flags while DNKEYS drives the run (a test aid only).

## Word of VP (2026-10-02): a systemic doubt
Virtual Pascal's Word has 32 bits (the type `AWord` of DN is the 16-bit one for the file formats; the key codes
`kbAltX = $082D00` are stored in `KeyCode: Word`). FPC has 16 bits. Edit 118 fixes the key codes of the menus and the status
line (Alt-X was Ctrl-Alt-X). Everywhere else DN keeps a value above 65535 in a Word the value is silently cut (range checks are
off): look for it when something "shifted" is seen. Found so far: the key codes (edit 118, 119), the range test of the string lists (edit 120: `Key-Base < Count` wraps in VP). A global way (the type Word = LongWord in each unit, `Lo`/`Hi` of it)
is not tried: it changes the sizes of records that go to `tv/` (TCluster data, TEvent).

## The screen of DN (2026-10-02)
`Drivers.ScreenBuffer` is the 16-bit copy of the screen of tv/ (VPSysLow.SysTvGetSrcBuf), refreshed by DNApp at every idle; DN reads
it (user screen, screen savers) and writes back with SysTvShowBuf. The user screen is the text screen that was there before DN
(VPSysLow grabs it at the start). Not done: the characters above 255 / combined ones of tv/ become '?' in the copy; the copy is
converted at every idle even when nobody reads it (cheap: 2000 cells).

## Help (tvhc/TvHelp)
- `.hlp` is 400-460 KB because of the index: it is flat (an array of positions by context number), and in DN help the numbers go up to
  ~49000 (and `_`=65535). Storing a sparse index (sorted pairs) — the format is ours, can be changed; it does not hurt for now.
- The `.htx` format was derived from the source of the original `tvhc` (in the archive `angelbbs_DosNavigator`; it was only read, the code was not
  ported) and checked by cross-check: topic numbers match `dnhelp.pas` from the archive for all shared names (in the `.pas` files from the archive
  there are names that are not in `.htx`: the file versions differ).
- Help lines are limited to 255 characters (`ShortString` in `GetLine`); a paragraph is 4095 bytes (as in the original).
- The help window is 50x18 as in Borland; size configuration — later (move into a setting).

## go2dos: what is needed from the host for UTF-8 in DOS (proposals to the go2dos owner)
- Clipboard: WinOldAp is OEM-only for now (`CF_TEXT`/`CF_OEMTEXT`, `docs/DOS-EXTENSIONS.md` §3). A UTF-8 mode like
  `DOS-UTF8/NAMES` (encoding chosen by the process) or a `CF_UNICODETEXT` format in UTF-8 is needed.
- Screen and keyboard: in the go2dos specification they stay OEM; honest UTF-8 of the screen and input is a separate extension (when needed).

## Linux: known glitches (2026-10-02)
- UTF-8 file names are shown as bytes in the code page (garbage instead of "file.txt"): solved by moving to UTF-8 inside DN (PLAN, item 4).
- Dot files (`.hidden`) and broken symbolic links are not visible in the panel: `FindFirst` returns them (except broken links), so DN itself hides them
  (check the panel setting "hidden files" and the comparison `Name[1] = '.'` in the directory parse); Unix permissions and links are not shown in `Attr`.
- Paths look like DOS (`C:\home\you`): drive C: is the root of the file system; show Unix paths after the move to UTF-8.
- Case: names that are not on disk in the case DN asks for are looked up without regard to case (`SysOsPath`); two files that differ only by
  case, DN will not be able to tell apart.
- The "Warning" (beta) splash at every start: Esc closes it.

## Symbolic links (Linux), 2026-10-02
- `SysFindFirst/Next` mark a found symbolic link with `SysLinkAttr` ($40, the DOS bit of a device that a search never gives) and the
  search always asks for links (`faSymLink`), so that broken links are found too. The directory tree (`tree.pas`) does not enter a link to
  a directory (`/proc/self/root` made the scan of `C:\` endless). The panels still enter them (Enter on a link to a directory works);
  how the panels show a link (a mark, the target) is not done. Other scanners of DN (Find files, the size of a directory, the
  copy of a tree) may loop on a link cycle: check when they are used on `/`.
## Names of files and keyboard (Linux, code page build only: DN_UTF8=0), 2026-10-02 — the stop-gap before UTF-8 inside (now the default)
## Names of files and keyboard (Linux), 2026-10-02 — stop-gap until DN is UTF-8 inside
- At the border with the file system (`vpsyslow.pas`: `NameFromOs`, `NameToOs`, `SysOsPath`) a name that is valid UTF-8 and has only
  characters of the current code page (CP866) is turned into the bytes of that page and back; other names (other alphabets, not UTF-8)
  stay as bytes and are shown wrong. `DN_NAME_CONV=0` switches the conversion off. The typed text is converted by `InputLineOem` (dnapp).
  The real fix is PLAN.md item 4 (UTF-8 inside).
- The tree (Disk > Directory tree) on `/` reads every directory (30 000 directories took 20 s here), a line "Reading directories: N   Esc - stop" is shown while it works (Esc aborts); `/proc` and `/sys` of the root are skipped.
- `DN0.SWP` (the saved desktop) is written to the current directory when a command is run from the command line: it shows in the panel; the place
  and the need of the file are to be decided.

## DOS: DN.EXE hangs in the DOSBox that is built into Wine (2026-10-02, reported by the owner; to be investigated)
- Symptom: `dist/dos/DN.EXE` started in the DOSBox 0.74-3 of Wine ("Cpu speed: max 100% cycles, Frameskip 1") hangs at once: no output, only the
  blinking cursor under the command line. The same files work in DOSBox-X (our tests: `tools/dn-tour.sh`, `tools/dn-dist.sh`).
- How it was started (screen of the owner): `mount c ~/dos` (a directory of the owner), `c:`, `mount -z y`, `mount z /home/<user>/.wine/dosdevices/z:`,
  `Z:`, `cd \home\<user>\dev\dn\dist\dos`, `config -securemode`, then `Z:\home\<user>\dev\dn\dist\dos\DN.EXE` — i.e. the program runs from the drive Z: (the
  root of the host file system as a long path) with the current directory there; `CWSDPMI.EXE` is in the same directory.
- What is not known (to ask the owner when they are at the computer): (1) does it start when `dist/dos` is copied into the mounted `C:` (a short
  path, a directory with write access: DN writes `DN.INI`, `DN.HIS`, `DNERR.TXT`, `DN0.SWP` next to itself and into the current directory)? (2) does
  a plain go32v2 program (any `*.exe` of FPC for DOS) start in that DOSBox, i.e. does it find `CWSDPMI.EXE`? (3) the files `DNLOG.TXT`/`DNERR.TXT`
  after `set DNDUMP=SCR.DAT` + `set DNDUMPSEC=5` before the start (they say how far DN got).
- Guesses (not checked; no guessing in the code until the data is there): the DPMI host (CWSDPMI) and the 32-bit code under the older DOSBox; a write
  to the read-only Z:; the long path; a video or keyboard call that the old DOSBox does not have (DN reads the BIOS data area, INT 10h/16h).

## Sweep of the menus (Linux x86_64, 2026-10-02, tools/dn-linux-menus.py)
126 items opened, no crash. The 8 items that the sweep marks "did not quit" are waits, not errors: Disk > Directory tree and Panel >
Count/Compare (reading the directories of `/` takes ~20 s, Esc stops it), File > last item (the command line of the shell: waits for Enter).

## The single-byte code page (2026-10-02)
- DN takes the page of its strings (the screen, typed text, converted file names) by the locale of the host (`tv/src/tvlocale.pas`, the table of
  github.com/unxed/localecp: ru_RU 866, de_DE 850, pl_PL 852, en_US 437...); `DN_CODEPAGE=NNN` sets it by hand; the Russian, Ukrainian and Belarusian
  resources (written in CP866) make it 866. Not done: the page of the multi-byte locales (ja, ko, zh: 437 here), 720, 1258, TIS-620 (TvCodePg has
  no such pages); the page that the resources need is known after the panels are read (a Russian UI on a host of another locale: the names that
  were read before are in the page of the host until the next reading); the DOS build takes the page from DOS (TvDos), not from the locale.
- **ZIP names/comments (2026-10-05):** listing decode landed (`dn/lib/localecp` + `dn/lib/zipcharset` + `fmtzip`). Remaining: Win ACP/OEMCP, multi-byte CPs, comment UI — `docs/ZIP-CHARSET.md`.

## XLT next to the program (found while building for Windows)

DN looks for the tables `XLT\*.xlt` (incl. `ru441.xlt`, the default layout) next to the program (`SourceDir`). They were not placed anywhere before,
and at start it printed "Error in country setups" (on Linux the alternate screen hid it; the layout-switch table was not built).
Now `tools/build.sh` puts `dn/data/XLT` next to `dn`/`dn.exe`, the dist scripts too; the test `tools/dn-linux-ops.py` checks that there is no error.
The rest of `dn/data` (`COLORS`, `DN.FLG`) is unused so far: check whether it is needed when we get to the color settings.

## Windows (win64/win32)

- Build: `tools/build-fpc-windows.sh`, `tools/build.sh win64|win32`, `tools/dn-win-dist.sh`; CI: workflow `dn-windows` (cross-build on Linux,
  run on `windows-latest` via ConPTY: `tools/dn-win-smoke.py`). The terminal layer is `tv/src/tvtermos.pas` (Windows console in VT mode,
  input via ReadConsoleInputW → UTF-8 bytes → shared parse `TvTermIO`), on top of the same `TvUnix` as on Linux.
- File names: for now — the bytes of the system (ANSI) code page as-is; ANSI↔OEM recoding (`CharToOemBuff`/`OemToCharBuff`) and
  `GetOEMCP` → `TvLocale` are not done yet (to be done together with the UTF-8 stage: names entirely in UTF-8 through the `...W` API functions).
- Wine (Linux Mint, 2026-10-03, owner report): with VT output the screen is empty, fragments of sequences are visible (the wine console does not handle VT).
  So by default the console mode (`tv/src/tvtermos.pas`, block "the console mode"): `TvAnsi` sequences are parsed in place
  (CUP, CHA, CUU/D/F/B, ED, EL, SGR with color reduced to 16, modes 25 and 1000/1002/1006, cursor shape) and drawn with `WriteConsoleOutputW`
  into its own screen buffer; console keys and mouse are turned into the same sequences the terminal sends. `DN_WIN_OUTPUT=vt` — the old mode.
  Wine (owner report): grey panel backgrounds of two shades, the areas change. The cell buffer is fine (attribute `8B` on all panel cells, `TV_CONDUMP=file` writes
  the buffer to a file for checking), the wine terminal loses the bright background (`ESC[100m`) on some cells. Workaround: on wine a background without the bright bit (black instead of dark grey);
  `DN_WIN_BRIGHT_BG=1` restores as-is, `=0` enables the workaround on real Windows. DN's own palette uses background 8 (`dnpalet.pas`).
  Not done in this mode: colors with shades (everything to 16), characters outside the BMP (`?`), bold/underline style, CJK width checked only against the TvUtf8 table.
- Not checked on Windows: window resize, mouse, paste from the clipboard (bracketed paste), running a command (`SysRunShell` via `COMSPEC`).

## UTF-8 inside DN: what remains (branch utf8-inside, 2026-10-03)

- Case and sorting: `UpStr`, `LowStr`, `UpCase`, `UpStrg`, the tables `UpCaseArray`/`ABCSortXlat` are built for a single-byte page; on UTF-8 they corrupt
  Cyrillic (bytes 0xA0..0xAF become 0x80..0x8F). UTF-8 versions are needed (Latin-1, Cyrillic, Greek; Unicode tables later).
- 16-bit buffers (`WriteLineW`/`WriteBufW`: `dblwnd`, `dbview`, `gauge`, `calc`, `ed2`, `idlers`, `calendar`): `drivers.pas` (`MoveStr`/`MoveCStr` into a word buffer) converts UTF-8
  into the bytes of the current code page (`LegacyText`): characters that the page lacks (CJK, Hebrew...) stay as raw bytes and show as garbage. The calendar was fixed separately
  (weekdays are cut by characters). Check the other such places by eye (copy progress with a long name, DBF, splash).

- Width (`DNUtf8`): in panels/dialogs/calendar wide characters (CJK) take two columns, combining ones take zero (proxy: `Utf8ToProxy`, `FF` — the second half of a wide one). In the editor a line is one byte per character: a wide character there counts as one column, alignment and the cursor will drift with it; in `StrCols` the width is counted, but the places that use `Length` rather than `StrCols` were not checked.
- Quick search in the panel: Ctrl-S (double Alt is impossible on terminals) + Cyrillic works in the UTF-8 build (`DoQuickSearch`, `DNKeyCode` adds a scan code to Ctrl+letter, as in DN). Alt+letter: see `HotKeyAlt`; Alt+letter as the start of a panel search on a terminal was not checked.
- Frame `x` instead of `╔` in the top-left corner of the panels: present in the DOS build too (an old defect of drawing the panel frame), unrelated to UTF-8.
- Build: FPC does not rebuild a unit when only `-d` changes, so the `-dDNUTF8` mode has its own object directory (`tools/dn-env.sh`, suffix `-utf8`); otherwise the plain and UTF-8 builds
  mixed units (in the UTF-8 build `Utf8Enabled` was `False`, the panel footer showed mojibake (UTF-8 bytes misread as OEM)).
- The editor (`microed.pas`) counts position, selection and screen shift in bytes of the line, not in characters: Shift+Right ×6 on the Cyrillic "Hello, world" selects the first 3 characters (6 bytes), the cursor and
  horizontal scroll on lines with Cyrillic are offset. Options: (a) positions in characters (edit every `Pos.X`, `Delta.X`, `Copy` site); (b) store editor lines as
  "proxy" (`DNUtf8`: one byte per character, a character table per document of up to 127 distinct ones), converting on file read/write, draw and clipboard. (b) is faster, but
  does not work for texts with a large alphabet (CJK). Decide and do as a separate stage.
- Clipboard: DN → terminal (OSC 52, `TV_CLIPBOARD=0` switches it off; not sent on the Linux console), Windows — the system clipboard (`CF_UNICODETEXT`, `TvTermOs`); reading
  the terminal clipboard is not done (forbidden in most terminals), paste goes through bracketed paste. OEM↔UTF-8 conversion at the border only in the mode without `-dDNUTF8`
  (DOS and the old mode); in UTF-8 mode DN strings are already UTF-8.
- Windows: data is not recoded, only passing names into the `...W` API is needed (UTF-8 in DN ↔ UTF-16 in the system). Check in CI with files whose names are outside the ANSI page:
  `SetMultiByteFileSystemCodePage(CP_UTF8)` in the FPC RTL; the `Dos` unit may call the ANSI API variants directly.

## Editor: typing characters outside the code page (2026-10-03)
- In a UTF-8 file a typed character that the code page has not takes a free frame cell of the table of the document (`TabTyped`, `DocTab.Used`).
  When the table is full the character is dropped silently (no message). A file that does not fit the table at load time is opened as a legacy
  (non-UTF-8) file: typed characters outside the code page are dropped there (`microed.pas`, evKeyDown).
- Frame characters typed by hand mark their cell as used (`TabMark`), but a frame cell given to a rare character stays given for the session of the file.
- Events with key code 0 and a text (characters outside the code page) now reach all views in the UTF-8 build (`u_myapp.pas`); only the editor uses them.

## Found by looking at the Russian screens (2026-10-03)
- The message boxes (F8 delete confirmation etc.) have the title `Confirm` and the buttons `Yes`/`No` in English in the Russian interface
  (both builds): the stock strings of `tv/` (`MessageBox`), not the language file of DN. To check where DN's own texts should go in.
- Fixed: after the move of the cursor the two redrawn lines of the panel were drawn by `WriteLineW` from a buffer of cells (garbage `♂ ◘` in the
  panel): a leftover of the conversion of the draw buffers to cells (commit 86cb12f), `flpanel.pas` now uses `WriteLineC`; the ops test has a check.
  Other leftovers of that kind may exist: the places that still hand cell buffers to the word-based `WriteLineW/WriteBufW` (the DBF viewer and
  `calendar`, `ed2`, `idlers`, `swe`, `topview_` use word buffers on purpose).

## TvVt (the emulator of the terminal view), 2026-10-03
- Not done: DECRQM, sixel and other graphics, rectangular operations (DECCRA, DECFRA...), double width and height lines, left/right margins (DECSLRM), text reflow when
  the width changes, the title stack (CSI 22/23 t), the answers to OSC 10/11 (colors). The answer to DA says "VT220 with color" (`?62;22`), not xterm.
- The history keeps the rows as they were at the time (no reflow); a row is a reference, not a copy: the memory of 1000 lines x width x 24 bytes per cell.
- `Resize` does not pull the lines back from the history when the window grows.
- `TvVtView`: no selection with the mouse and no copy from the history (the terminal gets the mouse only when the program asks for it, else the wheel scrolls); the keys that
  the owner must keep (hotkeys) are told by `KeyFilter`; the program is read on a timer of 20 ms (the event loop of `tv/` does not wait on the pty): a
  wait on the descriptor of the pty in `TvUnix` would save the idle wakeups; the redraw of the whole view at each change (the dirty rows are known, the
  clip of the view is not used); the colors of the terminal are the default colors of the real terminal, not the palette of the window.

## Embedded terminal in DN (2026-10-03)
- The user screen starts empty (it does not hold the screen that was before DN); it keeps what the commands drew (history of 2000 lines). Not done: the screen of the program that started DN; the command line of DN stays DN's own (no
  completion by the shell); the panels are not shown while the command runs (no half-screen terminal); the F-keys of DN are given to the program while it runs (no way to leave it before it ends except its own exit);
  Windows has no embedded terminal (`TvPty` is Linux only: ConPTY is item 8.5).
- `Esc` on an empty command line shows the user screen (the DN option `ouiEsc`), also when there is nothing but the output of the last command.

## DOS: UTF-8 names and the clipboard (go2dos, DOSBox-X), 2026-10-03
- go2dos: `DOS-UTF8/NAMES` was already there; the UTF-8 clipboard is made: provider `DOS-UTF8/CLIPBRD` (`unxed/go2dos`, branch `claude/utf8-clipboard`, spec `docs/UTF8CLIPBOARD.md`,
  tests `machine/utf8clip_test.go`): to be merged by the owner of go2dos (its rules: a patch for `git am`).
- DOSBox-X: both parts are made and pushed to the fork `unxed/dosbox-x`: `claude/amis-utf8-clipboard` (AMIS + `CLIPBRD`, `docs/patches/dosbox-x-pr-clipboard.md`) and `claude/utf8-names`
  (stacked on it: option `utf8 file names`, escape `{U+XXXX}` in the guest-code-page cache, AMIS `DOS-UTF8/NAMES`, border conversion at the 71xx functions; `docs/patches/dosbox-x-pr-utf8-names.md`).
  Both ran in a build (SDL2, Linux, headless). The PRs to `joncampbell123/dosbox-x` are to be opened by the owner (the session cannot open a PR in a foreign repository): compare links are in the PR texts.
  Doubts: the escape is also used by the other users of the conversion (mount paths, CD-ROM); short names with non-ASCII source are ordinary mangled names (no uniqueness guarantee beyond
  DOSBox-X); the Windows host branch and DBCS code pages are not tested; the cache is still in the guest code page (a design with host names in the cache would be a larger change).
- DN for DOS in the UTF-8 mode (2026-10-04, first step): `DN_UTF8=1 tools/build.sh dos` builds DN with UTF-8 inside (`dist/dos-utf8`, `tools/dn-dist.sh` with `DN_DIST_SUFFIX=-utf8`); the plain DOS build
  (code page inside, any DOS) stays the default. At the start `osdep` finds the provider `DOS-UTF8/NAMES` (AMIS, `TvDos.AmisFind`) and switches the UTF-8 names on for the process (`DN_DOS_UTF8_NAMES=0` does not ask);
  `TvDos` does the same for `DOS-UTF8/CLIPBRD` (`TV_DOS_UTF8_CLIP=0` does not): the clipboard text is UTF-8 on the wire, in both builds. **Not done / not tried** (no patched emulator in the session): the run with the provider;
  without it the UTF-8 build shows the names as the code page bytes (invalid UTF-8 is taken as the code page) and a typed name with non-ASCII characters is wrong (a border conversion at every name entry of `lfn.pas` is the way
  if the UTF-8 build is to run on any DOS); the names passed to a child program (`dnexec`) should be the short ones (UTF8NAMES.md, client checklist 3).

## aarch64 CI: t_chdir (2026-10-03)
- The first ARM run of `tv` failed in `t_chdir` (4 checks): `TDirListBox.ShowDirs` listed the subdirectories in the order of `FindFirst`, i.e. of the file system (a hash on ext4), so "one"/"two" were not in the order that the test expects
  on that runner. Fixed: the names are collected into a `TStringCollection` and shown sorted (`tv/src/tvchdir.pas`). Other places that show directories in the file system order are not searched for.

## DN for DOS under DOSBox-X master (2026-10-03)
- Symptom: the DOS build (`dist/dos/DN.EXE`) makes no screen dump (the harness of `tools/dn-tour.sh`) on DOSBox-X built from `master` (2026.10.01, the base of the patches in `docs/patches/`); on the apt package
  2024.03.01 that CI uses it does. The same on `master` **without** the patches, so it is not the AMIS/UTF-8 patches.
- Found (differential trace of DN, `tools/dn-trace-init.py` + steps by hand, a `gdb` backtrace of the emulator): the **emulator** hangs, not DN: `DOS_FindFirst` -> `DOS_FindDevice` -> `DOS_CheckExtDevice`
  (src/dos/dos_devices.cpp; since when it exists is not checked, the clone is shallow) walks the chain of device headers in guest memory in `while(1)` that ends only at `FFFF:FFFF`. While DN runs, the CON header at `00F9:0000` (`DOS_CONDRV_SEG`, the
  private area of DOS of DOSBox-X) is found zeroed (`next=0000:0000 attr=0000`), the walk leaves into the interrupt table and never ends. The raw INT 21h AX=714Eh/71A1h sequences of DN from a small .COM do not hang.
- Fix for the emulator (a guard of 1024 links): branch `claude/fix-extdevice-loop` of the fork `unxed/dosbox-x` (`docs/patches/dosbox-x-pr-extdevice-loop.md`); with it DN starts and draws the panels under `master`.
- **Not known:** who zeroes `00F9:0000`. A `gdb` watchpoint (the first dword of the header becoming 0) did not fire in one run. Candidates: DN (a write through its DOS transfer buffer `tb_segment`/`dpmi32`),
  the stub or CWSDPMI, or the emulator. To find out: a watchpoint set from the start of the run, or a check of what `tb_segment` is in DN; the known odd thing of the same kind is `ShadowCount` (a variable that had a wrong
  value at the start of the program under DOSBox-X, `dpmi32.pas`). Until it is known a bug of DN cannot be excluded.
- Checked (2026-10-03): `master` + the guard + the patches of `docs/patches/`, `lfn = true`, `utf8 file names = true`: `dist/dos` DN starts and draws the panels; the file "dom 世界.txt" is **in the panel** as
  `{U+0434}{U+043E}{U+043C} {U+4E16}{U+754C}.txt` (cut by the column with the `►` mark; without the option it is hidden). Not yet tried on it: copy, view, rename, delete in DN.
- With the apt package 2024.03.01 and `lfn = true`, DN shows the long names (the column cuts them with the `►` mark; the panel is in the 8.3 width). Files whose names the code page lacks are hidden
  (no `utf8 file names`, that option is only in the patched DOSBox-X): to be tried with DN now that it runs under `master`.

## DN for DOS: saving the state (2026-10-03, under DOSBox-X master + the guard, `dist/dos`)
- Written by DN: `DN.INI` at the first start (and the ini cache `DNINI.IN_`), `DN.HIS` (histories) at every normal exit (Alt-X, exit code 0), `DN.CFG` (16 KB) only when the configuration was changed
  (`ConfigModified` in `TDNApplication.Done`). The desktop: `TDNApplication.Done` calls `SaveDsk` (the `DN<n>.SWP` file, for the return from an external program; nothing at the total exit) or `SaveRealDsk` when
  `StartupData.Unload and osuAutosave` (the startup option "save the desktop on exit", off by default): no `.DSK` file was written in my runs, because that option was not on.
- Checked: the panel sort by size (Alt-B, Down, Down, Enter) works inside a run (the order of the files changes). After Alt-X and a new start the sort is the default again: **expected** with the defaults (nothing
  saves a panel sort unless the setup is saved or the autosave of the desktop is on); not a defect of the port as far as I can tell.
- **Found and fixed (2026-10-03): "Load desktop" gave "Error reading desktop file"** for any desktop that has a file panel window. Cause: `TDoubleWindow.Load` reads the pointers to its own views (`Separator`, the panels) with
  `GetSubViewPtr` after `inherited Load`; in `tv/` that was `TView.GetSubViewPtr`, which only puts the pointer into the list of fixups of an enclosing group (applied at the end of that group's `Load`), so the pointers stayed
  nil and `Fail` was called. Borland TV has `TGroup.GetSubViewPtr`, which gives the view of the group at once; added in `tv/src/tvviews.pas`; test `tv/tests/t_subptr.pas` (3 of 6 checks fail without the fix).
  How it was found: the traces of `Put`/`Get` of every nested object (positions in the file), then of the steps of `TDoubleWindow.Store/Load`; the first 5 builds only showed that DN reads 4 bytes less than it writes.
  Other classes of DN that call `GetSubViewPtr` after `inherited Load`: `calc`, `dbview`, `dndlgs`, `edwin` (the same fix helps them).
- **Verified after the fix (DOS, DOSBox-X master with the guard):** panel sort by size (Alt-B), Options -> Save desktop (`DN.DSK`, 6628 bytes), restart, Options -> Load desktop: no error, the panel comes back in the size
  order (the base start shows the extension order). The same code is in the Linux/Windows/aarch64 builds, where the bug was the same; their `dist/` are not rebuilt yet (a refresh of all `dist/` is due after the next fixes).
- **Checked (2026-10-03, Linux build, pty; `tools/dn-linux-ops.py`):** Options -> Startup -> "Autosave Desktop": `DN.DSK` is written at Alt-X, the option is kept in `DN.CFG`, the next start restores the desktop.
  The directory of the **active** disk panel is restored only together with "Preserve directory" (`TFilePanelRoot.Store`, `osuPreserveDir`): by design of DN, not a defect; the passive panel always keeps it. Not checked on DOS.
- **Not checked yet:** "Save setup" (the button of the panel setup dialogs, `TSaveSetupButton.Press` in `fltools.pas`: only the presets 1..10 set `ConfigModified`, the active/passive targets live in the desktop), and the user screen after an external
  program. The keys of the harness (`DNKEYS`) drive the menus well but each step needs a look at the screen (the first guesses of a hotkey, Ctrl-F3, opened the drive menu instead of a sort).

## DOS: the user screen after an external program (2026-10-03)

Done: `DNRun.RunExternal` (GO32V2) puts `UserScreen` (the screen of DN's start, then what the previous programs left) into the video memory and
the saved cursor in place before the program (the screen is not cleared any more), and copies the video memory and the cursor back into `UserScreen`
after it; Ctrl-O (`TApplication.ShowUserScreen`, DOS branch: `DNRun.ShowUserScreenDos`) shows it until a key. Test: `tools/dn-tour.sh OUT userscr`
(`echo hi`, then Ctrl-O; with DNDUMP the lines of the user screen go to the trace and the scenario checks for `hi`).
Doubts: the text modes other than the width of `UserScreen` are skipped silently (no restore); the graphics modes of the programs are not saved;
the old window of the stored screen (`PUserWindow`, `GetUserScreen` in `dnutil.pas`) is no longer reachable on DOS. Mouse on DOS: not checked yet (next).
**tv/ moved (2026-10-03, owner, a22fa0e):** `tv/` is now the repository `unxed/tv` (its root = our former `tv/`, checked identical). Decision (Claude, "invent an elegant way"):
**git submodule at the same path `tv/`**, so no path in the scripts and CI changes; the commit recorded in `dn` pins the version of tv that DN builds with (update: `git -C tv pull && git add tv`).
`tools/need-tv.sh` (sourced by `build.sh`, `tv-test.sh`, `dn-test.sh`, `check-layout.sh`) fetches the submodule if the clone was made without `--recurse-submodules`;
`DN_TV=/path` uses another checkout (a link). The workflows have `submodules: true`. Open: the workflow `tv.yml` of `dn` duplicates what `unxed/tv` should test itself (it now also checks the pin); the `tv/` text in
`dn/README.md` and `PLAN.md` (history, "tv/ and dn/ code is not mixed") is left as it is.

## DOS: the mouse (2026-10-03)

Test seam: `DNMOUSE=D3:0,U3:0,DD10:5,...` (`dnapp.pas`, next to `DNKEYS`): mouse events (D down, U up, M move, DD down of a double click, a leading R: the right button)
go into the queue of the application once a second (half a second after the keys); the driver is not used (DOSBox-X without a display has no pointer).
The driver itself: `DosMousePresent` is True in DOSBox-X (INT 33h found by `TvDos`); real button presses are not possible in this harness, so by hand only.
Checked: a click on "File" in the menu bar opens the menu; a right click on a file marks it (the row is right); the left click activates the panel.
**Found and fixed:** a double click on a directory did not enter it, and Ctrl-PgDn did not either. The cause was wider: `Message(R, evKeyDown, kbXxx, nil)` (46 calls in 13 units: the command
line, the viewer, the panels, the history, macros, the gauges...) did nothing, because in tv/ the fields `Command` and `KeyCode` of `TEvent` are not at the same place (in the Borland TV they are).
Now `Drivers.MessageKey(Receiver, Code)` (the code in the form of DN with the shift bits, `kbCtrlPgDn = $047600`: `SetDNKeyCode`) does it, and the calls use it. Test: the tour scenario `mousedir` (DOS) and `DNKEYS=011B,C7600`.
Not checked: the Linux and Windows builds with this change (the same code), the callers that give the key as a plain Word (macros: a character, gauges: the table `Keys`).
**Tv is separate:** the repository `unxed/tv` is developed on its own (the owner's decision: "split, not copy"); `dn` only moves the submodule pointer.

## Terminal protocols, step 1: the win32 input mode (2026-10-03)

`tv` (`TvTermIO.ParseWin32Key`, `TvUnix`): DN asks the terminal for the mode (`ESC[?9001h`) and understands `ESC[Vk;Sc;Uc;Kd;Cs;Rc_`: every key and combination (Ctrl/Alt/Shift with
letters, digits, the functional keys, AltGr, Alt+numpad, characters above U+FFFF from the two UTF-16 halves); the releases and the modifier keys alone are not events. `TV_WIN32_INPUT=1|0` forces it;
by default it is asked for only in Windows Terminal (`WT_SESSION`). Tests: `t_termio` (19 checks), `tv/tests/pty/test_win32input.py` (tvdemo), `tools/dn-linux-win32.py` (DN: F7, Esc, Alt-X + Enter).
Open: ask the terminal (DECRQM `ESC[?9001$p`) instead of guessing by `WT_SESSION` (WezTerm, conhost, far2l have the mode too); the repeat count and the key releases are dropped; Ctrl+digit and the
OEM keys with Ctrl give nothing without a character; Windows (the console API of `TvTermOs`) does not use it; the next steps: OSC 52, the kitty keyboard flags as a setting, far2l extensions.

## Terminal protocols, step 2: the far2l extensions (2026-10-03)

Done in `tv` (`TvFar2l`, `TvTermIO.ParseApc`, `TvUnix`): DN asks the terminal (`ESC _ far2l1 ST` + `ESC [ 5 n`), and when it answers `far2lok` the keys and the mouse come as events of the terminal and
the clipboard goes through it (open / empty / pieces of 16 KiB / set / close; read only after a paste gesture); `TV_FAR2L=0` switches it off, `TV_FAR2L_WAIT` is how long the terminal may ask the user.
Why: the far2l terminal takes Ctrl+Ins and Shift+Ins for its own copy and paste, so DN never got them (reported by the owner: Ctrl+Ins in the editor copied nothing, Edit-Copy did; Shift+Ins "worked" because
the terminal typed the text). Checked: `t_far2l` (33, the examples of the documentation), `t_termio` (110), `tv/tests/pty/test_far2l.py` (a terminal of the test: keys, mouse, set and get of the clipboard, 40 KB in pieces).
**Fixed (found with `tools/dn-linux-far2l.py`):** the cause of "Ctrl+Ins copies nothing" was in DN, not in the terminal alone: `DNKeyCode` (drivers.pas) got the codes of tv/ for Ctrl+Ins, Shift+Ins, Ctrl+Del and Shift+Del
($0400, $0500, $0600, $0700) while DN looks for the BIOS scan codes ($9200, $5200, $9300, $5300); so the hotkeys of the menu (Edit-Copy, Edit-Paste) did not work with any terminal. Now Ctrl+Ins in the editor puts the
selection on the clipboard of the far2l terminal (the script checks it: PASS).
**Open:** Shift+Ins (paste) in that script is still RED: DN sends CLIP_OPEN and CLIP_GETDATA (so TvClip asks the terminal), the terminal gives the text, but the editor shows no pasted text. Not diagnosed: look at
`PasteBlock` / `SyncClipOut` in microed.pas and winclp.pas (`FromSys`, `TextLines`) with a selection present (the script pastes over a selected block). If the paste does not work for you in the far2l terminal now,
`TV_FAR2L=0` gives the old behaviour (the terminal types the text itself on Shift+Ins; Ctrl+Ins then stays with the terminal). The script is not in CI yet. Next: F-key titles, notifications, window size, palette, DECRQM, then the far2l images / drag and drop.

**Confirmed by the owner (2026-10-03, the far2l terminal on Linux Mint, dist built from 18b36b9):** Ctrl+Ins copies and Shift+Ins pastes in the editor now. The red Shift+Ins check of `tools/dn-linux-far2l.py`
(a block is selected when it pastes) stays as a note: a possible difference between pasting over a selected block and pasting without one; not seen by the owner.

## DOS: "save the desktop on exit" and "Save setup" (2026-10-03, started, not finished)

What exists in the sources (no new code needed to start): the option "Autosave ~D~esktop" in the dialog Options -> Startup (`RESOURCE/ENGLISH/dn.dnr` line ~3557) is `StartupData.Unload and osuAutosave`; `TDNApplication.Done` (`dnutil.pas` ~710)
then calls `SaveRealDsk` (writes `DN.DSK`), else `SaveDsk` (the swap file `DNn.SWP`); the command `cmSaveDesk` (Options -> Save desktop, `dnutil.pas` ~2738) writes it on demand; the config is `WriteConfig` (`ConfigModified`).
Next steps (a tour scenario each): (1) `tools/dn-tour.sh` scenario that switches "Autosave Desktop" on in Options -> Startup, opens a window (F3 on a file), exits with Alt-X and checks that `DN.DSK` exists and a new start brings the window back;
(2) the same for Options -> "Save setup": change a setting, save, restart, the setting is there (`DN.INI`). Keys: F10, then Right x6 for the menu Options (x5 is Panel), `DNDUMPSEC` must count the keys (n + m + 4). The earlier fix of loading a saved desktop
(`TGroup.GetSubViewPtr`) is in. Not checked on DOS yet: that the autosave on exit really runs there (the exit path of DN-DOS under DOSBox-X: `Halt` in the dump mode skips `Done`).

## DN in real mode vs DPMI under go2dos (owner, 2026-10-04: the very end, not before the other items)

What remains of the DPMI32 layer (`compat/realmode.pas`, the real-mode calls for LFN, the clipboard, FAT32) can go in two ways: (a) teach `go2dos` (our 486 + DPMI emulator)
to run DN as it is, or (b) make DN run in real mode (no DPMI host, no `realmode` calls). To compare when the time comes: (a) keeps the 32-bit code and the 4 MB of the
memory model, costs an emulator feature; (b) needs the 16-bit memory model for ~160 units (not realistic without the Safe Pascal step). The first guess is (a). Not in this session.

## The files of the settings (from the refactoring, 2026-10-04)

- `dn.cfg` is inside `dn.ini` now (the section `[Saved]`, a hex image: done 2026-10-04); open: a text key of every field of the records (`RegisterVar` for `StartupData`, `SystemData`, the presets of the panels...) instead of the image, so that a person can edit them; the migration from `dn.old` can be dropped later.
- The files of the user are in `$XDG_CONFIG_HOME/dn` (else `~/.config/dn`; Windows `%APPDATA%\DN`) since 2026-10-07 (`cfgdir.pas`, `ConfigDir` of `basics`); `DN2` names a directory for everything as before, DOS keeps them next to the program. The first start copies the files of an older DN from the program directory (the originals stay; `dn.ini` of the program directory is the one that is used until the new one exists). Open: the logs and the crash reports go there too (the flight recorder, next item); compatibility of the data files with the old DN is not a goal (an import and an export when somebody needs it).

## Terminal protocols (2026-10-04)
- Done in `tv` (see its README and DESIGN.md): OSC 52 (set; read from the outer terminal with `TV_OSC52_READ=1`; the query `?` in the embedded terminal), the win32 input mode inside (`VirtualKey`, `RepeatCount`, `Win32State`, `evKeyUp`;
  `ESC [ ? 9001 h` of the program in the embedded terminal), far2l: notifications, titles of the F-keys, the exact cursor height, the palette. DN uses them: the key bar of the status line goes to the far2l terminal as the titles of F1..F12
  (`menus.pas`, `TStatusLine.DrawSelect`), the end of copy, move and delete shows a desktop notification (`dnscreen.NotifyUser`; `DN_NOTIFY=0` switches it off).
- Not done: the Kitty keyboard protocol flags (the next step: asked flags, the release and repeat events through `evKeyUp`), far2l images and drag and drop, DECRQM, the size of the window (`w`).

## DOS: checked in DOSBox-X with a real mouse pointer and a normal exit (2026-10-04, `tools/dn-dos-input.py`)
- The emulator: DOSBox-X 2026.10.01 built from the branches `claude/amis-utf8-clipboard` + `claude/utf8-names` (the fork `unxed/dosbox-x`; the binary was `src/dosbox-x` of the clone), on a virtual X display (Xvfb;
  `-silent` forces the dummy video driver of SDL, so it is not used there); the pointer is a real X pointer (XTest through `ctypes`), DOSBox-X turns it into INT 33h, so the real mouse path of `TvDos` is exercised.
- Checked: a click on a menu item, a double click on a directory, a click on a key of the status line (INT 33h works); the autosave of the desktop on DOS (`dn.dsk` is written at File -> Exit -> "Yes", the next start
  restores the directory of the panel; the "Alt-X" of the harness DNKEYS did not exit: DN asks "Do you wish to quit?" and the key `A2D00` does not reach it as Alt-X); the settings of the dialogs survive a restart
  (the section `[Saved]` of `dn.ini`). The UTF-8 build with the provider `DOS-UTF8/NAMES`: the file "dom 世界.txt" is in the panel (shown as `?` where the code page of the DOS screen has no glyph).
- Not driven: the button "Save setup" of the panel setup dialogs (the presets of the panels) and the view of Cyrillic names with `chcp 866`; a hung emulator can write a huge file: always `timeout -k`.

## Colors of the buttons (2026-10-04)
- Users: the buttons are not as in the original DN (the default button was red, the others purple). Cause: the built-in `CColor` was the table of the OSP source (it is the scheme `jaroslaw.pal`: cyan on magenta, white on brown, white on
  bright red); the colors of the original DN are the scheme `default.pal` (white on dark gray, cyan for the default button, yellow hot letters, dark gray text of the check boxes) as in the reference screenshots.
  Now `palettes.CColor` is `default.pal`; `CColorOsp` keeps the old table; a palette that was saved with exactly the old table (nobody changed it) is replaced at the start (`ReadConfig`, `boot.pas`). The other schemes
  are in `data/colors/` (Options -> Colors -> Load). Not compared pixel by pixel with the references: the input lines are black on the references and `9f` (white on light blue) in `default.pal`.
- The selected (focused) button has the background of the path in the title of the active panel (cyan, `3F` white on cyan; was `9F` white on light blue): the entry 12 of the dialog palette (index 43 of `CColor` and of `default.pal`).
- The active controls of a dialog that were blue are cyan like the selected button (`3F`): the selected text of an input line (51), the history arrow (53), the focused and normal items of a list (55, 56); the page of a scroll bar is `31`, the arrows and the thumb `3F` (35, 36). Guess by the screenshot of the user, not checked against the references.

- The command line (`cmdline.pas`) holds UTF-8 in the build DNUTF8: the typed text is `Event.Text`, the cursor, Backspace, Delete, the scrolling and the mouse go by characters (`CharAt`, `CharBefore`, `CellsIn`). Double-cell characters (CJK) count as one cell, and a character that is not in the code page (the key has no CharCode) is not typed: not done. The other inputs that take `Char(Event.CharCode)` (quick search of the panel and of the tree, ...) are in PLAN.md (the list of 2026-10-04, item 2).
- Restart (the change of the language, `cmRestart`): `DNRun.RestartPending` + `RestartSelf` (see PLAN.md, item 5); the old `ExecString('', '')` was the request to the DN.COM loader. On Windows and DOS the old process stays until the new one ends (no exec): a real replacement is not made.
- Text cleanup leftovers (what is allowed to stay and what is not fixed yet): `docs/TEXT-POLICY.md`, section "Not fixed".
- Resources, DOS landing (`tools/to-codepage.py`, `docs/TEXT-POLICY.md`): English and Russian go to cp866, Ukrainian to cp1125 (`DN_CODEPAGE`, `DN_CODEPAGE_UKRAIN`). Not checked on a real DOS machine or in DOSBox-X: whether the DOS build of DN (without `-dDNUTF8`) treats the cp1125 letters (upper and lower case, sorting) right: its tables know cp866. The look-alike letters of the old texts are repaired (`tools/fix-resource-lookalikes.py`); left: a few Latin letters that stand alone and were not converted on purpose (`Track'a`, `a:b`, lists of extensions).

- Cells hold UTF-8 for a code page byte of $80 and up (tv3 `ScInitChar`); the bytes below $20 and $7F stay raw and the writers turn them into the IBM glyphs. The stray `═` cells that made the first attempt fail (`f5_f6_f8` of `dn-accept`) came from DN, not from tv3: `TWhileView.Draw` (`progress.pas`) and `TCalcView.Draw` (`calcwin.pas`) wrote into the draw buffer through a record overlay (`absolute B`, a one-byte `C: Char`), which replaced the first byte of a UTF-8 cell and left the rest (`E2 95 90` became `C9 95 90`). Both now use `SetCellGlyph`. Do not write into a `TScreenCell` through an overlay: use `SetCellChar`, `SetCellGlyph`, `SetCellAttr`.
- File times on Unix: `osdep.Fill` passed `TSearchRec.Time` (the Unix time on Unix) as a DOS packed time, so the panels showed garbage dates for files (`5.06.33  9:63`). Fixed 2026-10-06 (`SysFileTimeToDos`, test in `t_osdep`; the comparator of the gate gets the same fix by `backport_shared_object_fixes.py`). Not checked: `SetFTime`/`GetFTime` of `Dos` on Unix in copy, move and the file ages dialog (they use the unit `Dos` of the RTL, which should pack the DOS time itself), and the creation and access times of `TOSSearchRec` (0 on Unix).
- `DumpAtExit` (`dosharness.pas`, was in `mainapp.pas`) is never called: the DOS harness writes `dnlog.txt` only if it is hooked; either hook it as an exit procedure or delete it.

## Doubts and leftovers of 2026-10-06 (platform separation, archives, input)
- Quick search of the panel: the display of a long search mask cuts by bytes (`QuickSearchString`); the Caps/Shift start modes take UTF-8 characters now (`IsTypedChar`) but no test drives them.
- `uk_UA` in `tvlocale.pas` maps to cp866 (as glibc does); a DOS user with cp1125 would want 1125: make it a setting if asked.
- `DefaultSortMode` of `dn.ini` applies only to a DN without a saved setup (`PanSetupFromConfig`); a user who saved the setup keeps what was saved.
- The archivers on Windows are started through `COMSPEC /c` as before (`osrunwindows.pas`); only the Unix side needed the fix. Not driven by a test on Windows.
- `ArcDrive.Exec` (arcview.pas) and `archiver.pas` still have the DOS 120/95-character command line limits and the `$DNn$.BAT` batch files of the swap mode; on Unix the swap mode (`SwapWhenExec`) must stay off.
- The quick search of the directory tree (window of the button [Tree] of the Copy dialog, `tree.pas`) takes UTF-8 characters now, but has no test: the window scans the whole host (the root of `C:` is `/`) for minutes before the search works (`Reading directories: 22891 Esc - stop`); a test needs a way to limit the scan (a setting or an environment variable).
- F4 in an archive is "Extr": the object build and the class build extract the member to the directory of the other panel at once (no dialog); the editor does not open a member of an archive (`UseFile` leaves on `cmEditFile`).

## Status at the end of the session (2026-10-06, second part)
- Found by the comparison of the UTF-8 build with the code page build (`DN_ACCEPT_U8CP=1 tools/dn-linux-accept.py UTF8_OUT CODEPAGE_OUT`; the scenarios of the area `u8cp` are for it): the status line of the editor (UTF-8 literals, fixed), the SmartPad date line (a raw byte in a UTF-8 document: shown as `?`; a shared bug, fixed in the class build and backported to the comparator), the line drawing mode of the editor (`FrameCells`: the tables of frame characters are cells of the document). Left out on purpose (`U8CP_SKIP`): `menu_6_9` (dn.ini is UTF-8 in both builds, the editor of the code page build shows its bytes by the page).
- Found by the red `dn-linux`: Find File with a text crashed (`SearchFileStr(@S, ...)` passed the address of a class variable: an access violation that the object build did not have; scenarios `find_mask`/`find_text` are in the gate now); the archivers on Unix got the paths of the command line unconverted (`osrununix.pas` now uses `CommandLineToOs`) and `zip -d`/`zip` got `-@listfile` (Info-ZIP reads the names from the standard input: the names go on the command line now). The archive matrix (zip, tar, tgz, tar.gz, tar.bz2, tar.xz; F3, F4, F5, F8, add) passes locally; 7z and rar are not installed in this sandbox, the CI runs them.
- Not done: the DOS checks (the UTF-8 names with the patched DOSBox-X, cp1125 case and sort), the stage 4 gaps of `docs/TEST-PLAN.md`, the full click-through at the final head. See `PLAN.md`, "Next items in order".
- Code page 1125 (Ukrainian) in the builds with the code page inside (DOS, `DN_UTF8=0`): the case of its letters is added to the tables of the OS from the page (`keymap.CompleteUpcaseFromPage`, test `t_cpcase`), and the sort order has its own table `sort1125.xlt` (made by `tools/gen-sort1125.py`: Ghe with upturn after Ghe, Ukrainian Ie after Io, Ukrainian I and Yi before Short I); `ApplyCodetables` takes it when the page is 1125 and the table is the default one, and `mainapp.CodePageChanged` makes the tables again when the language of the resources changes the page. Not driven on a real DOS with the page 1125 (DOSBox-X has no such page in its DOS): the tables are checked by unit tests.
- The attribute ReadOnly of DOS on Unix: the RTL unit `Dos` has no file attributes there (`GetFAttr` says 0, `SetFAttr` does nothing), so DN lost the read-only attribute at a copy (a shared bug: the object build too). `osdep` has `SysGetFAttr`/`SysSetFAttr`/`SysGetTAttr`/`SysSetTAttr` now (the write permission of the owner is the attribute; hidden, system and archive mean nothing on Unix), `lfn` and `filediz` use them; tests `t_osdep`, `tools/dn-linux-fsattrs.py`. A file name in a file record is UTF-16 with FPC 3.2 on Unix (`TFileTextRecChar`): read it by the size of the character (`RecName`). The creation and access times (`TOSSearchRec`: 0 on Unix) and `SetFTime`/`GetFTime` of the unit `Dos` are still not looked at.
- Names cut by bytes with UTF-8 inside (a shared bug: the object build too): the line under the panel (`TDrive.GetDown`), the footer of the panel, the lists of the selection dialogs and the path of the disk info cut a field at N bytes and put the mark on the Nth byte, so a Cyrillic name lost its extension and the cut could stand inside a character (`CutCols` of `strutil` cuts by columns now and is used in those four places; `Utf8Prefix` keeps the 12 bytes of the short name of a file record, `TShortName`, whole). Still by bytes: the long-name cuts of the panel footer by `LFN_Cut` 0 and 1 (`filepanel.pas`, the index arithmetic with `DelFromS`), and the short name itself stays 12 bytes: `privet.txt` of the info line shows `privet` (the short name is a 12 byte field of the file record that streams keep; to make it longer is a change of the record).
- Windows: F5 wrote the data of a copy after a block of zeros (found by the Windows smoke, 2026-10-07): `RewriteWriteStrem` of `filecopy` sets the final size of the new file first (`SysFileSetSize` = `FileTruncate`), and on Windows the truncation leaves the file position at the new end, so the data went to that offset. `SysFileSetSize` keeps the position now (test `t_osdep`, the smoke copies a plain and a Russian-named file and compares the content). The object and the class build of Windows both had it; no one had looked at a copied file on Windows before.

## DOS UTF-8 API (DOSBox-X PR 6632): what is in tv3 and what is in dn (2026-10-07)

- tv3 (`tv/src/tvdos.pas`, `tv/src/tvdosnames.pas`): the AMIS primitives (`AmisFind`, `AmisSetEncoding`), the clipboard provider `DOS-UTF8/CLIPBRD`, the names provider `DOS-UTF8/NAMES` and the conversion of a name.
- dn: only the calls (`osdep`, `osrundos`); the unit `osnamesdos.pas` is gone.
- Done (2026-10-07, the owner asked): the switch-on of the names provider `DOS-UTF8/NAMES` (`TvDos.DosInit`, `TV_DOS_UTF8_NAMES=0` turns it off; was `DN_DOS_UTF8_NAMES`) and the conversion of a name at the border (`TvDosNames`: `DosNameToUtf8`, `DosNameFromUtf8`, tested natively by `tv/tests/t_dosnames.pas`) are in tv3 (branch `claude/dos-names`). The DOS tests of dn stay green with stock DOSBox-X master.

## Flight recorder (2026-10-07, done; what is left)

- Done: `dn.log`/`dn_prev.log`, the report `crash/crashNNN.txt`, the call stack with lines (the builds for Linux and Windows have `-gl`), the screen text, the state of the panels and of the views; the way to hand it over: `docs/CRASH-REPORTS.md`.
- Left: the selected files of the panel and the file under the cursor are not in the report (file names are private; add on request); the report on DOS has addresses only (a map file of the build could name them); a crash outside the handler of `dn.pas` (a signal that is not turned into an exception, a stack overflow, a kill) leaves the log without the line `exit` and the report is not written: the next log says so; the lines of the log are not sent anywhere.

## DOSBox-X master for the DOS tests (2026-10-07)

- Checked: DOSBox-X `master` (2026.10.01, built from `joncampbell123/dosbox-x`) runs `tools/dn-dos-input.py` with `DN_DOS_PATCHED=1`: all 9 checks pass, including the UTF-8 names (the patches are in `master`).
- Open: the CI installs the package `dosbox-x` of Ubuntu (stock, no UTF-8 names), so the UTF-8 DOS scenarios are not in the CI. A job that builds `master` (about 15 minutes; cache the build by the commit) and runs `dn-dos-input.py` with `DN_DOS_PATCHED=1` belongs in `nightly`.
