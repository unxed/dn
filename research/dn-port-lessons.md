# DN OSP 2.14 под FPC: что выяснили (2026-10-02)

Источник: `tools/dn-probe.sh` (компилирует каждый юнит дерева FPC 3.2.2, native x86_64, режим `tp`) на дереве
DN OSP 2.14 (186 `.pas`, 182 юнита без программ). Записывать сюда каждое исправление для FPC
(патч причины «д» в `dn/patches` или юнит в `dn/new`) и его причину.

## 1. DN OSP — проект Virtual Pascal

- `vpc.cfg` (конфиг VP): `-ALFN=LFNVP;WINCLP=WINCLPVP` — подмена юнитов (`-A`), в FPC такой
  опции нет; `-$Delphi+`, `-$Use32+`, ключи `-$Cdecl-`, `-$Far16-` — свои у VP.
- Платформы выбираются символами `DPMI32` (102+41 вхождений `{$IFDEF}`), `OS2` (97+77), `WIN32` (79),
  `LINUX` (14): DOS-версия DN OSP — это VP-цель DPMI32 (32-битный DOS через DPMI), что по смыслу
  совпадает с нашим go32v2.
- Внешние юниты, которых нет в дереве: `vputils`, `files`, `events`(есть `Events.inc`), `windows`, `strings`,
  `os2base`/`os2def`/`os2pmapi`, `dpmi32`/`dpmi32df`, `vpkbdw32`, `lfn` (= `lfnvp` по `-A`), `winclp`
  (= `winclpvp`), `use16`, и модули самого DN (`navylink`, `dn2pmapi`, `terminal`, `udialer`,
  `modemio`, `country_`, `fltl.001`, `fnotify.001` — в OSP лежат под другими расширениями).

## 2. Корневые причины (проба, число юнитов, остановленных причиной)

| Корень | Юнитов | Что это |
|---|---|---|
| `vpsyslow.pas` | 119 | **Runtime Library Virtual Pascal 2.1** (© 1995–2003 vpascal.com, слой «система»): типы `SmallWord`, `TFileSize`, `TFileSystem`, константы `PROT_*`, `xcpt_Ctrl_Break`, ветки OS2/Linux/Win32/DPMI32 |
| `archiver.pas` | 31 | нужен юнит `Files` (VP) |
| `commands.pas` | 8 | `INLINE` у процедурных типов (синтаксис VP/Delphi) |
| `filescol.pas` | 5 | юнит `Files` |
| `objects.pas` | 2 | иной символ `$` в директиве |
| прочие | по 1 | `xtime` (`Events`), `version`, `uue2inc`, `titleset`, `rtpatch`, `regexp`, `plugrez`, `plugin`, `modules`, `memory` |

Из 182 юнитов как есть компилируются 4 — остальные упираются почти целиком в слой VP.

## 3. Что делаем (решения, пока рабочие)

1. **VP-RTL не берём в сборку**, заменяем своими юнитами в `dn/new` с тем же именем и API,
   ограниченным тем, что DN реально использует: `vpsyslow` (из ~169 объявленных имён DN использует
   41, всего 98 употреблений: `TDriveType`, `SysPlatformId`, `SysTvInitCursor`, `THandle`,
   `SysFileOpen`, `SysFileCreate`, `SysTvGetScrMode`, `SysTvSetCurPos`, `SysCtrlSleep`,
   `SysGetCurPos`, `SysBeepEx`, ... — полный список даёт `tools/` по запросу), `vputils`, `files`,
   `windows`-часть, `dpmi32df`, `vpkbdw32`. Писать с нуля по вызовам в DN и по документации FPC,
   **не копируя** `vpsyslow.pas` (авторские права vpascal.com, лицензия VP RTL нам не известна);
   `vpsyslo2.pas` (вклад JO/Cat в проект DN OSP) и `lfnvp.pas` (DN) — код DN OSP по их заголовкам,
   они остаются и подгоняются патчами «д». Ввод/вывод экрана, мыши, клавиатуры — на наш `tv/`.
2. Подмену юнитов `-A` — патчами «д» (переименование `uses LFN` → `uses LFNVP` и т. п.) или
   юнитами-обёртками в `dn/new`; проба делает копии под псевдонимом автоматически.
3. Цель go32v2: определяем `DPMI32` (ветки DOS DN OSP уже написаны под него), FPC-часть —
   поверх юнита `go32`/`dos` RTL FPC; `LFN` — через `LFNSupport` RTL (`dn/new`).
4. Конструкции VP/Delphi, которые FPC в режиме `tp` не принимает (`INLINE` у типов процедур, `$`-директивы) —
   патчи «д»; выбрать режим (`objfpc`/`delphi`/`tp`) по юнитам, а не глобально.

## 4. Решено (владелец проекта, 2026-10-02)

Код vpascal.com заменяем своими юнитами; `vpsyslow.pas` внесён в `dn/exclude.list`. Список имён,
которые DN реально берёт у `vpsyslow` (56 имён, 143 употребления в оставляемых файлах),
`vpsyslo2` (1) и `lfnvp` (37 имён, 765 употреблений — это DN-шный LFN, он остаётся) —
`spec/vp-api-*.md` (`tools/vp-api.py`; только имена и числа).
Ошибка в первой версии этого файла: `vpsyslo2.pas` и `lfnvp.pas` не принадлежат vpascal.com —
по заголовкам это код DN OSP; код vpascal.com только в `vpsyslow.pas`.

## 5. После исключения (проба, 2026-10-02): список недостающих юнитов

С `dn/exclude.list` (38 файлов аудита + `vpsyslow.pas`) в дереве 144 юнита; компилируются 4 (как и раньше).
Юниты, которых теперь нет и которые надо дать (`dn/new` или `tv/`), по числу юнитов, которые на них упираются:

| Юнит | Юнитов упирается | Кто даёт |
|---|---|---|
| `Defines`, `_Defines` | 38 + 9 | переписать: общие типы и константы DN (28 + 60 имён, `spec/dn-boundary-dnosp214.md`), частично `tv/` |
| `Files` (VP) | 35 | наш юнит: файловый слой DN поверх RTL FPC (имена — по вызовам в DN; в оставляемых файлах — см. ошибки пробы) |
| `VPSysLow` | 17 | наш юнит по `spec/vp-api-vpsyslow.md` (56 имён) |
| `Collect`, `Views`, `Streams`, `Gauge`, `Dialogs`, `DNApp` | 12, 4, 3, 1, 1, 1 | адаптеры поверх `tv/` (`tools/api-coverage.py`: что уже есть) |
| `use16`, `Os2Def`, `Events` | по 1 | ветки OS/2 и `use16` отключаем (`{$IFDEF}` в патче «д»), `Events.inc` — включаемый файл |

Дальше проба пойдёт каскадом: каждый добавленный юнит открывает следующий слой ошибок — это и есть порядок работ вехи 4.

## 6. Первые замены (2026-10-02, вечер)

Проба на дереве после исключения, шимов (`dn/new/shims.map`, `tools/gen-shim.py`) и правок (`dn/edits/`):
**25 из 160 юнитов компилируются** (было 4 из 182). Это цифра локальной пробы на разобранном
архиве (`DN_LOCAL_TREE=... tools/dn-materialize.sh`, `tools/dn-probe.sh tp -dDPMI32`); CI-проба — то же.

Что сделано:
- **Шимы** (`dn/new/shims.map`): юниты с именами Borland-овских (`Views`, `Defines`, `Dialogs`, `Collect`, `Streams`,
  `Scroller`, `Validate`, `ColorSel`, `HistList`, `MsgBox`, `App`, `Menus`, `StdDlg`, `_Views`...) дают имена наших
  `tv/` (типы и константы — псевдонимами, переменные — `absolute`, процедуры — обёртками, члены перечислений — константами).
  Что DN называет иначе — `dn/new/manual/*.inc` (пока `TPhase = TPhaseType`).
- **Правки** (`dn/edits`, применяет `tools/dn-materialize.sh`): `05-conditionals.sh` — условная компиляция вычисляется для цели
  из `dn/target.env` (`DPMI32`, `tools/ifdef-strip.py`: понимает `{$I файл}`); `10-getpalette.sed` — `GetPalette: PPalette` →
  `TPalette`, `:= @S` → `MakePalette(S)`; `20-interface-bodies.py` — тела функций в `interface` (стиль VP) переносятся
  в `implementation`, `inline;` убирается.

Что мешает дальше (корни пробы): `vpsyslo2.pas` (44 юнита) — нужны `TOSSearchRec`, `SysFindFirst/Next/Close` из `VPSysLow`;
`archiver.pas` (31) и `filescol.pas` (8) — юнит `Files` (VP); `_model1` — `TRegExpStatus`, `AsciiZ`, `TXlat`... (имена DN,
которые были в `defines.pas`: руками в `manual/defines.inc`); `_menus` — `PMenu`, `PMenuItem` (шим `Menus` нужен там, где DN ждёт `Menus`);
`objects.pas` — файл-заглушка (`Нефиг!`, 1 строка, не Pascal); `ufnmatch.pas` — пустой.

**Важное открытие.** `lfnvp.pas` (DN) — это реализация LFN для DOS через вызовы реального режима (`INT 21h AX=71xx`) на слое
`Dpmi32`/`Dpmi32df` (`real_mode_call_structure_typ`, `init_register`, `intr_realmode`, `segdossyslow16/32`) — то есть **именно та
LFN-часть, которая нужна нам на DOS**. Слой `Dpmi32*` в архиве отсутствует (RTL Virtual Pascal для DOS): пишем свой
`dn/new/dpmi32.pas`/`dpmi32df.pas` поверх `go32` FPC (`realintr`, `TRealRegs`, `dosmemput`), имена — по вызовам в
`lfnvp.pas`, `winclpvp.pas` (WinOldAp-буфер обмена DN — тоже оттуда), `vpsyslo2.pas`.

## 7. Слой VP/Dpmi32 и первые юниты (2026-10-02)

- Сделано: `dn/new/vpsyslow.pas` — файлы (`SysFileOpen/Create/Seek/Read/Write`) и поиск (`TOSSearchRec`, `SysFind*`);
  `dn/new/dpmi32.pas`/`dpmi32df.pas` — реальный режим через `go32` (`realintr`, буфер передачи `transfer_buffer`; на
  не-DOS — заглушки с CF=1), `MemGet/MemPut` вместо `Mem[]`/`Ptr()` VP (правка `dn/edits/30-dpmi32-mem.py`: память ниже
  1 МБ не лежит в сегменте данных); `manual/defines.inc` — имена из `defines.pas` DN (`Str*`, `LongString`, `TXlat`, `TSize`...),
  плюс `TFileSize/SmallWord/TQuad` из VPSysLow (в VP они видны всем). `gen-shim.py`: `+Unit` в `shims.map` — только в `uses` шима.
- Проба (`tools/dn-probe.sh objfpc -dDPMI32`): 31 из 162 юнитов компилируется (было 25). `lfnvp.pas` проходит до `drivers.pas`.
- **Находка.** В `exclude.list` из аудита попали не только «борландовские» юниты, но и ядро DN: `DNAPP.PAS`, `FVIEWER.PAS`,
  `edwin.pas`, `calendar.pas`, `memory.pas`, `filetype.pas`, `version.pas`, `usersavr.pas`, `colorvga.pas`, `advance6.pas`,
  `TopView_.PAS`, `strview.pas`, `asciitab.pas`... Ворота аудита — `raw% <= 2 и maxrun < 48`; у многих из них raw% 1–6 %, а
  исключило их *одно* длинное совпадение (`FVIEWER`: 1 %, но maxrun 112 токенов из `VIEWS.PAS`). Без них не собрать ни
  юнит `Events`/`Messages`/`Gauge`/`DNApp`, ни `FViewer` (остальные юниты на них ссылаются).

## 8. Ворота аудита и правки отрезков (2026-10-02)

- `audit/runs.py` понимает `REN=1` (сравнение с переименованными идентификаторами). Совпадения «по структуре» часто ложные
  (повторяющиеся вызовы `PutExtFilter(...)` дают 90 токенов «клона»), реальный сигнал — `raw`-отрезки: `FVIEWER` —
  `TViewScroll.GetSize/DrawPos` (копия TScrollBar), `calendar` — ключи в `HandleEvent` и `Store` (демо TV). Переписаны
  в `dn/rewrite/*.rw`; после правок `FVIEWER` raw 0 %, maxrun 28; `calendar` raw 4 %, maxrun 42.
- Свой `memory.pas` (интерфейс из имён DN совпадал с Borland целиком — порядок объявлений изменён).
- Сомнительные места (не усложняем, фиксируем): в VP `Word` — 32 бита, в FPC — 16; DN рассчитан на VP. Пока правим по ошибкам
  компиляции (`dn/edits/40-xtime-word.sed`: `Integer(Word)`-приведения). Риск: переполнение `Word` в арифметике, которой VP
  не страдал — искать при тестах. `Events` (юнит DN, исходника в архиве нет, есть `Events.inc`): шим на TvEvents/TvKeys +
  `GetCurMSec`, `LongWorkBegin/End` (`dn/new/manual/events*.inc`).

## 9. Следующий корень: DNApp, Drivers, VideoMan (2026-10-02)

- `Country_` (нет в архиве) — свой `dn/new/country_.pas` (`CountryInfo` из настроек системы), тест `t_countr`.
  Проба: 37 из 175. `drivers.pas`: `SysErrorFunc = SystemError` → `@SystemError` (`dn/edits/41-drivers.sed`).
- Корень 58 юнитов — `drivers.pas`, он упирается в `videoman.pas` → `DNApp` (исключён аудитом: 33 % Borland, это копия `App`).
  `DNApp` — 51 юнит его используют. В нём: `TBackground`, `TDesktop`, `TProgram`, `TApplication` (с дополнениями DN:
  `IdleSecs`, `CanMoveFocus`, `ExecuteDialog`, `InsertWindow`, `ActivateView`, `Clock`, `ShowUserScreen`, `WhenShow`,
  `GetTileRect`), ресурсы (`OpenResource`, `ExecResource`, `LoadResource`, `GetString`, `Resource`, `LngStream`,
  `LStringList`), `GlobalMessage*`, `WriteMsg`, `ViewPresent`, `PreExecuteDialog`.
- Расхождения с нашим `tv/` (`TvApp`), которые придётся закрывать: `TDeskTop` (у нас) / `TDesktop` (у DN); `Init(const R)` /
  `Init(var R)`; `Pattern: Byte` / `Char`; `PPalette` / `TPalette`; нет `Load/Store` (потоки представлений не
  переведены); нет ресурсов диалогов. `drivers.pas`/`videoman.pas` держатся на `SysTv*` (VP) — нужен выбор: реализовать
  `SysTv*` поверх `TvScreen/TvSys` или заменить свои `Drivers`/`VideoMan` адаптерами.

## 10. Выбор (а) и модель клеток (2026-10-02)

Решено (владелец: «А»): свой `dn/new/dnapp.pas` поверх `TvApp`, `Drivers`/`VideoMan` DN остаются, `SysTv*` — поверх `TvScreen/TvSys`.
Находка по пути: DN рисует **16-битными клетками** (`Word`: символ OEM + атрибут, `TDrawBuffer`, `MoveChar(B, ...)` из
собственного `drivers.pas` DN, `WriteBuf/WriteLine(…, B)`: ~250 мест в 15 файлах), у нашего `tv/` клетка — `TScreenCell`
(UTF-8 + атрибут), а `TDrawBuffer` — объект. План: в `tv/` добавить перегрузки `TView.WriteBuf/WriteLine` для старых
буферов из `Word` (с таблицей кодовой страницы), из шима `Views` исключить `TDrawBuffer` (в DN он свой, из `Drivers`).
`SysTv*`: `ScreenBuffer` DN — буфер `Word`, `SysTvShowBuf` переводит его в `ScreenWrite`.

## 11. Достижимость и список недостающего (2026-10-02)

- `tools/dn-reach.py build/dn dn.pas`: из `dn.pas` по `uses` достижимы 131 юнит из 178; не нужны для сборки 47: плагинные
  копии `_*.pas`, `dnfuncs`, `vars`, `rcp`, `plugin*`, `tetris`, `calc`, `version`, `app`, `msgbox`, `stddlg`, `objects`...
  (часть — наши шимы, которые DN подключал под другим именем). Плагинная модель в первой версии не нужна.
- Нужны, но их нет в архиве (RTL VP или файлы, не попавшие в OSP): `asciitab`, `dnstddlg`, `edwin`, `fltl`, `fnotify`,
  `gauge`, `gauges`, `helpfile`, `helpkern`, `use16`, `vputils`; `Drivers._vp` — VP-вариант `drivers`. Файлы `*.001` — не
  исходники, а **заметки AK155 к правкам** (`fltl.001`: `GetDriveTypeNew`, `TDrvTypeNew`, `GetFSString`;
  `fnotify.001`: `NotifySuspend/NotifyResume` отключают автообновление панелей на время диалога) — это наши спецификации.
- `drivers.pas` DN объявляет свой `TEvent` (с `Double`, `ShiftCode`, `KeyCode: LongInt`), он конфликтует с `TEvent` из tv.
  `drivers.pas` заменён нашим `dn/new/drivers.pas` (пока заглушка: имена добавляются по ошибкам компиляции).
- Имена файлов `*.pas` приводятся к нижнему регистру (`TopView_.PAS`: FPC на Linux не найдёт `topview_`).
- Правка `15-short-headers.py`: заголовки реализации без параметров (стиль VP/BP) — 580 штук в 88 файлах.
- Ассемблер VP (Intel-синтаксис) компилируется с `-Rintel`; ~55 блоков `asm` (регистры EBX/ESI/EDI в FPC надо сохранять
  самим) — проверять при запуске, не при компиляции.

## 12. LIB.D32: «недостающие» юниты были в архиве (2026-10-02)

Владелец указал, что DN OSP собирался в Virtual Pascal, и приложил архивы (`dn2s214.rar` — sha256 совпал с закреплённым;
`dn151src.zip` — sha256 закреплён в `dn/upstream.env`). Ошибка была в нашем `tools/dn-materialize.sh`: он брал только
корень архива, а в архиве есть каталоги платформ `LIB.D32` (DOS 32-bit DPMI = наша цель), `LIB.OLF` (OS/2), `LIB.WLF`
(Win32) с юнитами `Events`, `files`, `fltl`, `fnotify`, `country_`, `DosLow`, `dn2pmapi` и копией RTL VP (`VPSYSD32.PAS` —
© vpascal.com, не берём). Теперь `DN_LIB_DIR=LIB.D32` в `dn/target.env`: юниты цели (кроме `vpsysd32`) копируются в корень,
остальные `LIB.*` удаляются.
- Это код DN OSP (JO, Cat, AK155): `fltl` (диск, время файлов, FS через INT 21h 71xx/73xx), `country_` (INT 21h 6521h/3800h),
  `fnotify` (заглушка D32), `Events` (`GetCurMSec` через `VPUtils.GetTimeMSec`), `files` (`TUseLFN`, `uLfn`, `InvLFN`).
  Наши `dn/new/files.pas`, `country_.pas`, `events` и правка `42-keymap` удалены.
- Они используют VP-слой: `dpmi32`, `dpmi32df` (`real_mode_call_structure_typ`, `getdosmem`, `dosseg_linear`),
  `VPUtils` (`GetTimeMSec`), `Mem[segdossyslow32]`, `Ptr(...)`. Наш `Dpmi32` дополнен: `getdosmem`, `dosseg_linear`,
  `MemFill`, `MemStr` и «тень» `DosShadow` — блок программы, который копируется в DOS-память и обратно вокруг каждого
  `intr_realmode` (так `DosSegFlat^` работает как при плоской памяти). Правки: `30-dpmi32-mem.py` (lfnvp, fltl, doslow),
  `21-oneline-bodies.py` (тела в одну строку в interface), `22-smallword.py` (в VP `SmallWord` виден везде).
- В dn151 (RIT, Borland Pascal 7) этих юнитов нет, зато есть `GAUGE`, `GAUGES`, `HELPFILE`, `HELPKERN`, `ASCIITAB`, `DNSTDDLG`,
  `MESSAGES`, `DNAPP`, `DRIVERS`, `FVIEWER`, `TVHC`.

## 13. Где мы на `dn.pas` (2026-10-02, вечер)

Компиляция главной программы `tools/dn-try.sh dn.pas` (опции из `dn/target.env`: `-Mdelphi -Sh- -Rintel -dDPMI32`) проходит
десятки юнитов; остановка — `Gauges` (нужен свой: `TTrashCan`, `TKeyMacros`, `THeapView`, `TClockView`, регионы под
Borland — в `dn/rewrite`, как для `gauge`).
- Режим Delphi + короткие строки — как в VP: процедуры как значения без `@`, `Result`. `@Name` локальной процедуры в Delphi-режиме
  — нетипизированный указатель, поэтому `FirstThat/ForEach(@X)` правится на `(X)` (`61-callbacks.sed`), параметры
  типизированных указателей — `62-callback-params.py`; `tv` принимает `is nested` (`{$modeswitch nestedprocvars}`).
- `{$V-}` и `nestedprocvars` добавляются в `STDEFINE.INC` (`04-stdefine.sh`).
- tv: `TView.WriteBufW/WriteLineW/GetColorW`, формы `GetBounds/GetExtent/...(var R)`, `TListBox.List`, потоки на `Int64`
  и с расширениями DN, `FirstThat/ForEach` с вложенными процедурами. Все тесты tv проходят.
- DN-расширения `TView`, которых нет в `tv/`: `UpdTicks`, `UpTmr`, `Update` (виртуальный), `ClearPositionalEvents`,
  `GetPeerViewPtr/PutPeerViewPtr`, `GetSubViewPtr/PutSubViewPtr`, `RegisterToBackground` (16 вызовов), `MenuEnabled`;
  `Load/Store` у представлений (потоки) — следующий крупный шаг в `tv/`.
- Свои юниты в `dn/new`: `vpsyslow` (+`SysTv*` над `TvScreen`), `dpmi32`, `dpmi32df`, `vputils`, `use16`, `memory`, `drivers`,
  `messages`, `dnapp`, `dnstddlg`, + `manual/*.inc` для шимов. Из архива: `LIB.D32` (`files`, `fltl`, `fnotify`, `events`,
  `country_`, `doslow`, `dn2pmapi`). Вернулись с правками отрезков: `FVIEWER`, `calendar`, `gauge`.

## 14. Компиляция `dn.pas` под go32v2 (2026-10-02, ночь)

`DN_CROSS=<каталог кросс-компилятора> TMPDIR=<tmp> tools/dn-try.sh dn.pas` компилирует дерево кросс-компилятором для DOS
(цель настоящая: нативный `Dos` отличается). Дерево собирается до `calc.pas` (десятки юнитов подряд).
- **Корень, найденный по дороге:** `tools/ifdef-strip.py` считал директивы внутри комментариев `(* ... *)` и строк
  (в `fltools` это ломало `case`, в `fltools` же — `(* ... {$ELSE} !! *) новый код`). Теперь директивы внутри комментариев
  и строк пропускаются. Вторая находка: `STDEFINE.INC` берёт ветку настоящей сборки (BIT_32, FILE_32, DualName, USELFN...)
  только если задан `VIRTUALPASCAL` — он теперь в `DN_DEFINES` (`dn/target.env`). FPC этого символа не видит: ветки вычтены.
- **Алиасы юнитов `vpc.cfg`** (`-ALFN=LFNVP;WINCLP=WINCLPVP`): `dn-materialize.sh` переименовывает файл и `unit` и остальные
  упоминания (два имени — один юнит, как в VP), затем `tools/dedup-uses.py` убирает повторы в `uses`.
- **Свой `Menus` из архива** (код DN, RIT; расширенные `TMenuItem`: `Flags`, `Param`, `miSubmenu`...) вместо шима над
  `TvMenus`: шим убран, `menus.pas` компилируется с небольшими правками. `dnapp.pas` ещё использует `TvMenus` (TODO: переход
  на меню DN: `MenuBar`, `StatusLine`).
- **`tools/dn-carve.py` + `dn/carve.list`:** классы, которые DN добавил сам в исключённых файлах (`TComboBox` из `DIALOGS.PAS`),
  вырезаются в новые юниты дерева (`DNDlgs`), в `uses` юнитов, которые их называют, юнит добавляется. Следующие кандидаты:
  `THexLine`, `TParamText`, `TPage`, `TPageFrame`, `TNotepad`, `TNotepadFrame` (по ошибкам компиляции).
- Свои юниты: `objects2` (`TObject` из tv/, `ObjChangeType`), `strview`, `asciitab` (оригинал — копия демо Borland), `edwin`
  вернулся с правками отрезков (`dn/rewrite/edwin-*.rw`, raw 13% -> 0%).
- Правки (`dn/edits`): `70` (циклы `for` с изменяемым счётчиком: `decoder`, `tetris`), `71` (двойной `+` во всех файлах),
  `73` (`with` над указателем), `80` (ключи только у событий, `Double`), `81` (имена `FileRec`), `82` (`Comp` -> `Int64`),
  `83` (`as`), `84` (поле записи как счётчик цикла), `85`, `86`, `87` (без `netbrwsr`), `88`, `89` (`TInputLine.Data^`),
  `91` (копия `Bounds` в `ChangeBounds`), `92` (`Real48` -> `Double`), `93` (записи `TStreamRec` -> фабрики tv/, `RegisterAll`
  по именам).
- tv/: `TWindow.Title` — `PStr` (как в Borland), `TDialog.DirectLink`, `TScrollBar.Step/ForceScroll`, `TInputLine.LC/RC/C`,
  методы команд у `TView` и `MenuEnabled` (+`CommandHiddenHook`), `TFilterValidator.Init(set of Char)`,
  `TSortedListBox.NewList(PCollection)`, `TCollection.AtReplace`, `ModalCount`, `WindowNumberFreeHook` (`GetNum` в шиме Views).
  Тесты tv и `dn/tests/t_objects2` проходят.
- **Ресурсы:** в архиве есть текстовые исходники ресурсов — `RESOURCE/ENGLISH|RUSSIAN|UKRAIN` (`dn.dnr` — диалоги и меню,
  `dn.dnl` — строки, `dnhelp.htx` — справка), компилятор ресурсов `rcp.pas`. Без собранного `DN.RES` `LoadResource` пуст:
  это следующий крупный шаг после компиляции (сборка `rcp`, генерация ресурсов, `LoadResource`/`ExecResource`/`GetString`).
- Хвост ошибок в `calc.pas`: `TScrollBar.Min/Max` (в tv `MinVal/MaxVal`), `TFileDialog.GetFileName` с параметрами,
  `Decimals`, цикл со счётчиком `I`; дальше — `Gauges`-соседи, `scroller`, `histlist`, `colorsel`, `validate`, `listmakr`, `tvhc`.
