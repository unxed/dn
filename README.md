# dn

Порт DOS Navigator на Free Pascal.

![](https://raw.githubusercontent.com/unxed/dn/refs/heads/main/.github/assets/screenshot.jpg)

В репозитории два независимых проекта с разными лицензиями и один общий инструментарий:

| Каталог | Что это | Лицензия | Откуда код |
|---|---|---|---|
| [`tv/`](tv/README.md) | **TV** — Pascal-перевод библиотеки [magiblot/tvision](https://github.com/magiblot/tvision), свои бэкенды (память, DOS), тесты, демо | отказ от гарантий Borland + MIT (`tv/COPYRIGHT.magiblot`, `tv/LICENSE`) | magiblot/tvision (его код — из опубликованного Borland выпуска TV 2.0 и MIT-вклад magiblot) и наш новый код |
| `dn/` | **DN** — сам файловый менеджер | лицензия DN (не перелицензируется) | публичные выпуски DN (см. [`dn/README.md`](dn/README.md)), наш новый код |
| `audit/`, `tools/`, `research/`, `.github/` | детектор кода Borland, сборка и проверки, исследования | — | наш код |

Наш новый код, не входящий в исходные файлы RIT Labs и их потомки - под MIT, как у magiblot.

Правила разделения (проверяются `tools/check-layout.sh` в CI):

1. `tv/` ничего не знает о `dn/`: его юниты используют только друг друга и RTL FPC.
2. `dn/` использует TV только как пакет, через его юниты; файлы TV в `dn/` не копируются и наоборот.
3. Код из `tv/` и `dn/` не смешивается: у них разные лицензии.
4. Код DN происходит только из **публично доступных источников**; сами исходники DN в
   репозитории не хранятся: хранится то, что позволяет воспроизвести наше дерево (адрес и
   sha256 архива, список исключений, патчи, новые файлы, скрипты). Первая версия — оригинал
   с минимумом изменений (`PLAN.md`, решение 10).
5. Исходники Borland не коммитятся никогда; CI скачивает эталон для аудита по ссылке и
   проверяет sha256 (`audit/fetch_reference.sh`).

План работ: [`PLAN.md`](PLAN.md). Устройство TV: [`tv/DESIGN.md`](tv/DESIGN.md).

## Как потестить то, что уже готово

*(Этот раздел обновляется вместе с каждым изменением, которое меняет способ проверки или то, что можно увидеть.)*

**Что есть сейчас (2026-10-02):** TV (`tv/`) собирается и проходит свои тесты нативно и под DOS; DN (OSP 2.14) собирается
целиком в `dn.exe` для DOS (go32v2), компилятор ресурсов `rcp.exe` работает под DOSBox-X и делает `.DLG/.LNG` на трёх
языках; `dn.exe` в DOSBox-X: две файловые панели с настоящими именами файлов, меню (F10), строка статуса, командная строка,
диалоги из ресурсов (копирование, удаление, создание каталога, выбор диска), просмотрщик (F3) и встроенный редактор (F4),
информация о диске (Ctrl-L), экран пользователя (Ctrl-O), запуск программ (Enter на файле), справка (F1: `*.HLP` делает
наш `tvhc` из `dnhelp.htx`, окно — `TvHelp`), выход (Alt-X). **Не работает:** мышь не проверялась, часть клавиш, сохранение рабочего стола. Смотрите
`dn/TODO-later.md` и `dist/dos/screenshots/`. Прогон «обхода» по сценариям: `tools/dn-tour.sh`.

1. **Тесты TV** (нужен только `fpc` 3.2.x):

       cd tv/tests
       for t in t_*.pas; do fpc -Fu../src -Fu. $t && ./${t%.pas}; done     # каждый печатает «ALL OK»

0. **DN под Linux без сборки:** `cd dist/linux && ./dn` (i386, статический ELF; нужен терминал не меньше 80x25; описание — `dist/linux/README.TXT`,
   экраны — `dist/linux/screenshots/*.txt`). Собрать самому: `tools/build-fpc-i386-linux.sh ПРЕФИКС`, затем
   `DN_LINUX=ПРЕФИКС tools/dn-linux.sh` (дерево `build/dn-linux`, `rcp`, `dn`, ресурсы, справка) и `tools/dn-linux-tour.py out/dnlinux` (обход в pty) и `tools/dn-linux-ops.py out/dnlinux` (F7/F5/F6/F8/F4 на настоящих файлах, проверка по файловой системе).

1a. **TV в терминале Linux** (нужны `fpc` и `python3`; терминалом служит `tools/pty_screen.py`):

        fpc -Futv/src -FUout -FEout tv/demo/tvdemo.pas
        python3 tv/tests/pty/test_tvdemo.py out/tvdemo      # меню, окна, мышь, смена размера, выход: «ALL OK»
        out/tvdemo                                          # руками, в настоящем терминале (Alt-X — выход)

    Тесты разбора клавиш и вывода (`t_termio`, `t_ansi`) идут в общем цикле пункта 1. Цвета: `TV_COLORS=0|8|16|256|direct`,
    мышь: `TV_MOUSE=0`, задержка Esc: `ESCDELAY=мс`.

2. **Тесты наших юнитов DN** (`dn/new`): те же команды запускает job `new` в `.github/workflows/dn.yml`.

3. **Инструменты для DOS** (один раз; нужны `fpc`, `make`, `git`, `curl`, `bzip2`, `dosbox-x`, `unrar`, `unzip`, `python3`, `patch`):

       tools/build-fpc-go32v2.sh $HOME/go32     # кросс-компилятор FPC → DOS и DJGPP binutils, ~15 минут

4. **DN: собрать и запустить в DOSBox-X** (без окна, на заглушках SDL):

       DN_PREFIX=$HOME/go32 tools/dn-run.sh            # результат в out/dnrun/
       DN_PREFIX=$HOME/go32 DN_TRACE=1 tools/dn-run.sh # и трасса запуска в out/dnrun/SER.TXT

   Скрипт: скачивает архив DN OSP 2.14 и делает дерево `build/dn/`; собирает `rcp.exe` и `dn.exe`; запускает `rcp.exe`
   (получаются `ENGLISH/RUSSIAN/UKRAIN.DLG/.LNG`); компилирует справку (`tv/tools/tvhc.pas` нативно → `*.HLP`; проверка:
   `DN_KEYS=3B00 tools/dn-run.sh` — F1 покажет окно справки); запускает `dn.exe` и, если тот дошёл до первого цикла ожидания, пишет
   дамп экрана `SCR.DAT` (и `SCR.PNG`, если есть Pillow) — их можно смотреть `python3 tools/render-dump.py out/dnrun/SCR.DAT`.
   Если DN упал раньше, смотрите `out/dnrun/DNERR.TXT` и `SER.TXT`: при `DN_TRACE=1` в трассу попадает и стек
   исключения со строками исходников (для него `DN_EXTRA=-gl`). `DN_KEYS=1C0D,3B00` кладёт клавиши в буфер (по одной в
   секунду) до снятия дампа. Остальные переменные: `DN_LOCAL_TREE`, `DN_NO_MATERIALIZE`, `DUMPSEC`, `DN_EXTRA` (описаны в
   начале `tools/dn-run.sh`). Отладка: `tools/dn-trace-calls.py` ставит в начало процедур указанных файлов `build/dn`
   запись в трассу (после `tools/dn-materialize.sh`; дерево этим портится, перематериализуйте).

0. **Без сборки:** в `dist/dos/` лежит готовая DOS-версия (`DN.EXE`, ресурсы, DPMI-хост `CWSDPMI.EXE`, тексты лицензий,
   `screenshots/`): смонтируйте каталог в DOSBox-X и запустите `dn` (см. `dist/dos/README.TXT`). Обновляется скриптом
   `tools/dn-dist.sh` при заметных изменениях; она собрана из того коммита, который указан в сообщении коммита `dist`.

5. **Посмотреть работу руками:** каталог `out/dnrun/` — готовый набор для DOS (`DN.EXE`, `CWSDPMI.EXE`, `*.DLG`, `*.LNG`):
   смонтируйте его в DOSBox-X (`mount c out/dnrun`, `c:`, `dn`) или скопируйте на машину с DOS.
