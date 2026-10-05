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

## Справка (tvhc/TvHelp)
- `.hlp` занимает 400-460 КБ из-за индекса: он плоский (массив позиций по номеру контекста), а в справке DN номера доходят до
  ~49000 (и `_`=65535). Хранить индекс разреженным (отсортированные пары) — формат наш, менять можно; пока не мешает.
- Формат `.htx` выведен из исходника оригинального `tvhc` (в архиве `angelbbs_DosNavigator`; он только читался, код не
  переносился) и проверен сверкой: номера тем совпадают с `dnhelp.pas` из архива для всех общих имён (в самих `.pas` из архива
  встречаются имена, которых нет в `.htx`: версии файлов разные).
- Строки справки ограничены 255 символами (`ShortString` в `GetLine`); абзац — 4095 байт (как в оригинале).
- Окно справки — 50x18 как в Borland; настройка размера — позже (вынести в настройку).

## go2dos: что нужно от хоста для UTF-8 в DOS (предложения владельцу go2dos)
- Буфер обмена: сейчас WinOldAp только OEM (`CF_TEXT`/`CF_OEMTEXT`, `docs/DOS-EXTENSIONS.md` §3). Нужен режим UTF-8 по образцу
  `DOS-UTF8/NAMES` (выбор кодировки процессом) или формат `CF_UNICODETEXT` в UTF-8.
- Экран и клавиатура: в спецификации go2dos остаются OEM; честный UTF-8 экрана и ввода — отдельное расширение (когда понадобится).

## Linux: известные огрехи (2026-10-02)
- Имена файлов в UTF-8 показываются как байты в кодовой странице (мусор вместо «файл.txt»): решается переходом на UTF-8 внутри DN (PLAN, п. 4).
- Файлы с точки (`.hidden`) и битые символические ссылки в панели не видны: `FindFirst` их отдаёт (кроме битых ссылок), значит скрывает сам DN
  (проверить настройку панели «скрытые файлы» и сравнение `Name[1] = '.'` в разборе каталога); права и ссылки Unix в `Attr` не показываются.
- Пути выглядят как DOS (`C:\home\you`): диск C: — корень файловой системы; показывать Unix-пути — после перехода на UTF-8.
- Регистр: имена, которых нет на диске в том регистре, что просит DN, ищутся без учёта регистра (`SysOsPath`); два файла, различающихся
  регистром, DN различить не сможет.
- Заставка «Warning» (beta) при каждом старте: Esc закрывает.

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

## XLT рядом с программой (найдено при сборке под Windows)

DN ищет таблицы `XLT\*.xlt` (в т.ч. `ru441.xlt`, раскладка по умолчанию) рядом с программой (`SourceDir`). Раньше их нигде не клали,
и при старте печаталось «Error in country setups» (на Linux его скрывал альтернативный экран; таблица смены раскладки не строилась).
Теперь `tools/build.sh` кладёт `dn/data/XLT` рядом с `dn`/`dn.exe`, dist-скрипты тоже; тест `tools/dn-linux-ops.py` проверяет, что ошибки нет.
Остальное из `dn/data` (`COLORS`, `DN.FLG`) пока не используется: проверить, нужно ли оно, когда дойдём до настроек цветов.

## Windows (win64/win32)

- Сборка: `tools/build-fpc-windows.sh`, `tools/build.sh win64|win32`, `tools/dn-win-dist.sh`; CI: workflow `dn-windows` (кросс-сборка на Linux,
  запуск на `windows-latest` через ConPTY: `tools/dn-win-smoke.py`). Терминальный слой — `tv/src/tvtermos.pas` (консоль Windows в режиме
  VT, ввод через ReadConsoleInputW → байты UTF-8 → общий разбор `TvTermIO`), поверх тот же `TvUnix`, что и на Linux.
- Имена файлов: сейчас — байты системной (ANSI) кодовой страницы как есть; перекодирование ANSI↔OEM (`CharToOemBuff`/`OemToCharBuff`) и
  `GetOEMCP` → `TvLocale` ещё не сделаны (сделаем вместе с этапом UTF-8: имена целиком в UTF-8 через `...W`-функции API).
- Wine (Linux Mint, 2026-10-03, сообщение владельца): с VT-выводом экран пустой, виден обрывки последовательностей (консоль wine VT не обрабатывает).
  Поэтому по умолчанию режим консоли (`tv/src/tvtermos.pas`, блок «the console mode»): последовательности `TvAnsi` разбираются на месте
  (CUP, CHA, CUU/D/F/B, ED, EL, SGR с приведением цвета к 16, режимы 25 и 1000/1002/1006, форма курсора) и рисуются `WriteConsoleOutputW`
  в собственный буфер экрана; клавиши и мышь консоли переводятся в те же последовательности, что шлёт терминал. `DN_WIN_OUTPUT=vt` — старый режим.
  Wine (сообщение владельца): серый фон панелей двух оттенков, области меняются. Буфер ячеек в порядке (атрибут `8B` у всех ячеек панелей, `TV_CONDUMP=файл` пишет
  буфер в файл для проверки), терминал wine теряет яркий фон (`ESC[100m`) у части ячеек. Обход: на wine фон без бита яркости (чёрный вместо тёмно-серого);
  `DN_WIN_BRIGHT_BG=1` возвращает как есть, `=0` включает обход на настоящей Windows. Палитра DN сама использует фон 8 (`dnpalet.pas`).
  Не сделано в этом режиме: цвета с оттенками (всё к 16), символы вне BMP (`?`), жирный/подчёркнутый стиль, ширина CJK проверена только по таблице TvUtf8.
- Не проверено на Windows: изменение размера окна, мышь, вставка из буфера (bracketed paste), запуск команды (`SysRunShell` через `COMSPEC`).

## UTF-8 внутри DN: что осталось (ветка utf8-inside, 2026-10-03)

- Регистр и сортировка: `UpStr`, `LowStr`, `UpCase`, `UpStrg`, таблицы `UpCaseArray`/`ABCSortXlat` рассчитаны на однобайтную страницу; на UTF-8 портят
  кириллицу (байты 0xA0..0xAF превращаются в 0x80..0x8F). Нужны UTF-8-версии (Latin-1, кириллица, греческий; позже таблицы Unicode).
- 16-битные буферы (`WriteLineW`/`WriteBufW`: `dblwnd`, `dbview`, `gauge`, `calc`, `ed2`, `idlers`, `calendar`): `drivers.pas` (`MoveStr`/`MoveCStr` в слово-буфер) переводит UTF-8
  в байты текущей кодовой страницы (`LegacyText`): символы, которых в странице нет (CJK, иврит...), остаются сырыми байтами и видны мусором. Календарь исправлен отдельно
  (дни недели режутся по символам). Остальные такие места проверить глазами (прогресс копирования с длинным именем, DBF, заставка).

- Ширина (`DNUtf8`): в панелях/диалогах/календаре широкие знаки (CJK) занимают две колонки, комбинируемые — ноль (прокси: `Utf8ToProxy`, `FF` — вторая половина широкого). В редакторе строка — по байту на знак: широкий знак там считается за одну колонку, выравнивание и курсор с ним поедут; в `StrCols` ширина считается, но места, которые считают `Length`, а не `StrCols`, не проверялись.
- Быстрый поиск в панели: Ctrl-S (двойной Alt на терминалах невозможен) + кириллица работает в UTF-8 сборке (`DoQuickSearch`, `DNKeyCode` дополняет Ctrl+буква скан-кодом, как в DN). Alt+буква: см. `HotKeyAlt`; Alt+буква как старт поиска в панели на терминале не проверялся.
- Рамка `x` вместо `╔` в левом верхнем углу панелей: есть и в DOS-сборке (старый дефект рисования рамки панелей), к UTF-8 не относится.
- Сборка: FPC не пересобирает юнит при смене только `-d`, поэтому у режима `-dDNUTF8` свой каталог объектов (`tools/dn-env.sh`, суффикс `-utf8`); иначе обычная и UTF-8 сборки
  смешивали юниты (в UTF-8 сборке `Utf8Enabled` оказывался `False`, подвал панели показывал «╨Ъ╨░╤В…»).
- Редактор (`microed.pas`) считает позицию, выделение и сдвиг экрана в байтах строки, а не в символах: Shift+Right ×6 по «Привет, мир» выделяет «При» (6 байт), курсор и
  горизонтальная прокрутка на строках с кириллицей смещены. Варианты: (а) позиции в символах (правка всех мест `Pos.X`, `Delta.X`, `Copy`); (б) строки редактора хранить
  «прокси» (`DNUtf8`: один байт на символ, таблица символов на документ до 127 разных), преобразовывая при чтении и записи файла, отрисовке и буфере обмена. (б) быстрее, но
  не годится для текстов с большим алфавитом (CJK). Решить и сделать отдельным этапом.
- Буфер обмена: DN → терминал (OSC 52, `TV_CLIPBOARD=0` выключает; на консоли Linux не отправляется), Windows — системный буфер (`CF_UNICODETEXT`, `TvTermOs`); чтение
  буфера терминала не делается (в большинстве терминалов запрещено), вставка идёт через bracketed paste. Перекодировка OEM↔UTF-8 на границе только в режиме без `-dDNUTF8`
  (DOS и старый режим); в режиме UTF-8 строки DN уже UTF-8.
- Windows: данные не перекодируются, нужна только передача имён в `...W`-API (UTF-8 в DN ↔ UTF-16 в системе). Проверить в CI файлами с именами вне ANSI-страницы:
  `SetMultiByteFileSystemCodePage(CP_UTF8)` в RTL FPC; юнит `Dos` может звать ANSI-варианты API напрямую.

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
- Checked (2026-10-03): `master` + the guard + the patches of `docs/patches/`, `lfn = true`, `utf8 file names = true`: `dist/dos` DN starts and draws the panels; the file "дом 世界.txt" is **in the panel** as
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
- Unix: the per-user directory (`$XDG_CONFIG_HOME/dn`, else `~/.config/dn`) as the default place of the files that the program writes (now: next to the program, or `DN2`); DOS stays next to the program. A setting (`DN2` or a line in `dn.ini`) decides; the default is to be chosen by the owner.

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
  (the section `[Saved]` of `dn.ini`). The UTF-8 build with the provider `DOS-UTF8/NAMES`: the file "дом 世界.txt" is in the panel (shown as `?` where the code page of the DOS screen has no glyph).
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
