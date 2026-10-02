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
   **не копируя** `vpsyslow.pas`/`vpsyslo2.pas`/`lfnvp.pas` (авторские права vpascal.com;
   лицензия VP RTL нам не известна). Ввод/вывод экрана, мыши, клавиатуры — на наш `tv/`.
2. Подмену юнитов `-A` — патчами «д» (переименование `uses LFN` → `uses LFNVP` и т. п.) или
   юнитами-обёртками в `dn/new`; проба делает копии под псевдонимом автоматически.
3. Цель go32v2: определяем `DPMI32` (ветки DOS DN OSP уже написаны под него), FPC-часть —
   поверх юнита `go32`/`dos` RTL FPC; `LFN` — через `LFNSupport` RTL (`dn/new`).
4. Конструкции VP/Delphi, которые FPC в режиме `tp` не принимает (`INLINE` у типов процедур, `$`-директивы) —
   патчи «д»; выбрать режим (`objfpc`/`delphi`/`tp`) по юнитам, а не глобально.

## 4. Открытый вопрос

Остаётся ли в дереве `vpsyslow.pas`/`vpsyslo2.pas`/`lfnvp.pas` как есть (они в публичном
архиве DN OSP, но это код vpascal.com, а не RIT/DN)? Предложение: в `dn/exclude.list` и
заменить своими юнитами в `dn/new` (п. 3.1) — это и нужно для FPC, и снимает вопрос лицензии.
