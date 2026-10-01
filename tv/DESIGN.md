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
| 1 | `TvGeom` — `TPoint`, `TRect` | `objects.h` | сделан, CI зелёный (Linux и DOS) |
| 2a | `TvColors` — цвета BIOS/RGB/xterm, атрибут (64 бита), квантование в 16 и 256 цветов | `colors.h`, `source/platform/colors.cpp` | сделан |
| 2b | `TvUtf8` — декодирование/кодирование UTF-8, ширина символа | `internal/utf8.h`; ширина — таблицы из базы Unicode (`tools/gen-width.py`) | сделан |
| 2c | `TvCell` — `TScreenCharacter`, `TScreenCell` (ячейка с UTF-8) | `scrncell.h` | сделан |
| 2d | `TvCodePg`, `TvText` — кодовые страницы; `TText`: Next, Width, Prev, DrawOne, DrawStr, Scroll | `ttext.h`, `source/platform/{ttext,codepage}.cpp` | сделан (без `equalsIgnoreCase`, UTF-32 и `drawStrEx` с обратным вызовом) |
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

## Принятые решения по ходу перевода

- **Цвет и атрибут** — простые типы с функциями, а не классы с операторами:
  `TColor` — `LongWord` (24 бита значения и 3 бита типа), `TColorAttr` — запись с 64
  битами (27 бит `fg`, 27 бит `bg`, 10 бит стиля), как у magiblot. Нулевой атрибут —
  цвета по умолчанию без стиля. Функции называются `ColorXxx`, `AttrXxx`.
- **Двухбайтный атрибут DN.** DN привык к атрибуту-байту BIOS и к ячейке из двух
  байтов. Для него есть `AttrFromBIOS`, `AttrAsBIOSByte` (`$5F`, если атрибут не
  сводится к BIOS) и `AttrToBIOS` (с квантованием). Как именно сопрягается
  `TDrawBuffer` DN с ячейкой UTF-8, решаем в юните `TvDrawBuf` (№ 4).
- **Имена файлов тестов** `t_*.pas`: DOS без LFN допускает 8 знаков.
- **Ширина символа** magiblot берёт у системы (`wcwidth` в Unix, проверка консоли в
  Windows). У нас таблицы из базы Unicode, сгенерированные скриптом
  `tools/gen-width.py` (`tv/src/tvwidth.inc`, версия Unicode записана в шапке): так
  результат одинаков на всех платформах, включая DOS. Ширина: −1 для управляющих,
  0 для комбинируемых и форматирующих (категории Mn, Me, Cf, кроме U+00AD, плюс
  U+1160..11FF), 2 для East Asian Wide/Fullwidth, иначе 1. Обновление Unicode — новый
  прогон скрипта.
- **Декодер UTF-8 свой:** проверяет кратчайшую форму, суррогаты и верхнюю границу
  U+10FFFF; при ошибке возвращает `Used`, с которого можно продолжать
  (как с однобайтным символом кодовой страницы).
- **Ячейка экрана** — как у magiblot: `TScreenCharacter` (15 байт текста UTF-8 плюс байт
  «длина−1 / флаги»: широкий, хвост широкого, переполнение), 16 байт; `TScreenCell` —
  символ плюс `TColorAttr`, 24 байта. Это plain data: нулевые байты — валидная пустая
  ячейка, сравнение побайтовое. Конвертер из слова DOS (`CellFromBIOS`) нужен для DN и для
  DOS-бэкенда.
- **Кодовые страницы** (`TvCodePg`, таблицы из `tools/gen-codepage.py`): сейчас 437 и 866,
  выбор `CpSelect`, по умолчанию 866 (у magiblot 437). Нижняя половина (0..31 и 7Fh)
  показывается как графические символы IBM PC (☺, ♥, ⌂…), верхняя — из кодека Python.
  Таблицу CP437 я сверил с таблицей magiblot: совпадение во всех 256 позициях. Новая
  страница — строка в `PAGES` скрипта и ветка в `CpSelect`.
- **Текст** — пары `PByte` + длина (плюс обёртки для `ShortString`): так не копируются
  данные и просто работать с кусками буфера. Ячейки — `PScreenCell` + счётчик. Атрибут
  необязателен (`PColorAttr`, `nil` — не менять). Недопустимый UTF-8 считается символом
  ширины 1 и рисуется через кодовую страницу.
