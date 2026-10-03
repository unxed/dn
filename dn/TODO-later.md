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
  Не сделано в этом режиме: цвета с оттенками (всё к 16), символы вне BMP (`?`), жирный/подчёркнутый стиль, ширина CJK проверена только по таблице TvUtf8.
- Не проверено на Windows: изменение размера окна, мышь, вставка из буфера (bracketed paste), запуск команды (`SysRunShell` через `COMSPEC`).

## UTF-8 внутри DN: что осталось (ветка utf8-inside, 2026-10-03)

- Регистр и сортировка: `UpStr`, `LowStr`, `UpCase`, `UpStrg`, таблицы `UpCaseArray`/`ABCSortXlat` рассчитаны на однобайтную страницу; на UTF-8 портят
  кириллицу (байты 0xA0..0xAF превращаются в 0x80..0x8F). Нужны UTF-8-версии (Latin-1, кириллица, греческий; позже таблицы Unicode).
- 16-битные буферы (`WriteLineW`/`WriteBufW`: `dblwnd`, `dbview`, `gauge`, `calc`, `ed2`, `idlers`, `calendar`): `drivers.pas` (`MoveStr`/`MoveCStr` в слово-буфер) переводит UTF-8
  в байты текущей кодовой страницы (`LegacyText`): символы, которых в странице нет (CJK, иврит...), остаются сырыми байтами и видны мусором. Календарь исправлен отдельно
  (дни недели режутся по символам). Остальные такие места проверить глазами (прогресс копирования с длинным именем, DBF, заставка).

- Ширина считается как «символ = колонка» (`DNUtf8`): CJK (две колонки) и комбинируемые знаки (ноль колонок) не учтены; выравнивание с ними поедет.
- Быстрый поиск (`flpanel`): сравнение `flnPanelName` с введённой строкой побайтное, с кириллицей в этом режиме не работает.
- Рамка `x` вместо `╔` в левом верхнем углу панелей: есть и в DOS-сборке (старый дефект рисования рамки панелей), к UTF-8 не относится.
