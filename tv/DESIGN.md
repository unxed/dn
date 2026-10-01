# tv: перевод magiblot/tvision на Free Pascal

Источник: https://github.com/magiblot/tvision, коммит `b4831e2` (2026-09-18). Переводим
библиотеку (`source/tvision`, `source/platform`, `include/tvision` без `compat/`);
`examples/` не переводим (см. `research/2026-10-01-magiblot-provenance.md`). Лицензия:
`tv/COPYRIGHT.magiblot` (отказ от гарантий Borland плюс MIT) — переводом она сохраняется.

## Правила перевода

1. **Заголовок юнита** называет, из каких файлов и какого коммита magiblot он
   переведён. Нового кода без источника в `tv/` нет, кроме платформенных бэкендов,
   которые помечены `{ original }`.
2. **Объектная модель — `object` (Borland-стиль):** `constructor Init`, `destructor Done`,
   `virtual`, `New(P, Init(...))`. Так устроен DN. Классы (`class`) не используем.
3. **Имена — как в Pascal TV** (`TView.HandleEvent`, `TRect.Assign`, `cmQuit`, `kbEnter`):
   имена методов и констант — интерфейс, который использует DN. Методы, которых в
   Pascal TV нет (юникодные у magiblot), называем как у magiblot с заглавной буквы.
4. **Целые:** `Integer` — 32 бита (режим `objfpc`), `Int32` явно там, где важна ширина.
   16-битных допущений нет.
5. **Строки:** публичный API — `ShortString` (как у DN), внутри текст — UTF-8 байты.
   Невалидный UTF-8 трактуется как символы однобайтной кодовой страницы
   (настройка `TvCodePage`, по умолчанию 866); это позволяет DN работать без переделок.
6. **Режим компиляции:** `{$mode objfpc}{$H-}{$modeswitch advancedrecords}`, общий файл
   `tv/src/tvdefs.inc`. Юниты не зависят от платформы, кроме `tv/src/platform/*`.
7. **Ассемблера нет**, кроме, возможно, DOS-бэкенда.
8. **Тесты:** каждый юнит имеет программу в `tv/tests/t_<юнит>.pas` (имя файла не длиннее 8 знаков: под DOS без LFN длиннее нельзя), печатающую
   `PASS`/`FAIL` и в конце `ALL OK`. CI гоняет их на Linux (нативно) и под DOS
   (go32v2, DOSBox-X).

## Порядок юнитов (от листьев к корню)

| № | Юнит | Из | Статус |
|---|---|---|---|
| 1 | `TvGeom` — `TPoint`, `TRect` | `objects.h` | сделан |
| 2 | `TvColors`, `TvCell` — атрибуты цвета, ячейка экрана с UTF-8 | `colors.h`, `scrncell.h`, `ttext.h`, `source/platform/{ttext,utf8,codepage}.cpp` | |
| 3 | `TvEvents`, `TvKeys` — события, коды клавиш и команд | `system.h`, `tkeys.h`, `tevent.cpp`, `tkey.cpp` | |
| 4 | `TvDrawBuf` — `TDrawBuffer` | `drawbuf.h`, `tvtext*.cpp` | |
| 5 | `TvViews` — `TView`, `TGroup`, `TFrame`, `TScrollBar`, `TWindow` | `views.h`, `tview.cpp`, `tgroup.cpp`, … | |
| 6 | `TvMenus` — меню и строка статуса | `menus.h`, `tmnuview.cpp`, `tstatusl.cpp` | |
| 7 | `TvApp` — `TProgram`, `TApplication`, `TDesktop` | `app.h`, `tprogram.cpp`, … | |
| 8 | Бэкенд «в памяти» (тесты) и бэкенд DOS | свой | |

После пилота (вехи 3–4 плана): диалоги, кластеры, списки, файловые диалоги, справка,
коллекции и потоки, редактор — в объёме, который использует DN.

## Что не переводим

- `source/platform` для Unix и Win32 — веха 6.
- Слой совместимости с Borland C++ (`include/tvision/compat`).
