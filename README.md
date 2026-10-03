# dn

Порт DOS Navigator на Free Pascal.

![](https://raw.githubusercontent.com/unxed/dn/refs/heads/main/.github/assets/screenshot.png)

В репозитории два независимых проекта с разными лицензиями и один общий инструментарий:

| Каталог | Что это | Лицензия | Откуда код |
|---|---|---|---|
| [`tv/`](tv/README.md) | **TV** — Pascal-перевод библиотеки [magiblot/tvision](https://github.com/magiblot/tvision), свои бэкенды (память, DOS), тесты, демо | отказ от гарантий Borland + MIT (`tv/COPYRIGHT.magiblot`, `tv/LICENSE`) | magiblot/tvision (его код — из опубликованного Borland выпуска TV 2.0 и MIT-вклад magiblot) и наш новый код |
| [`dn/`](dn/README.md) | **DN** — сам файловый менеджер, исходники в git | файлы DN — лицензия DN (не перелицензируется), наши файлы — MIT ([`dn/LICENSE.md`](dn/LICENSE.md)) | публичный выпуск DN OSP 2.14 (путь: `bootstrap/`) и наш новый код |
| [`bootstrap/`](bootstrap/README.md) | запись о том, как получен первый коммит `dn/src` из публичного архива, и способ воспроизвести | MIT | наш код |
| `audit/`, `tools/`, `research/`, `.github/` | детектор кода Borland, сборка и проверки, исследования | — | наш код |

Наш новый код, не входящий в исходные файлы RIT Labs и их потомки - под MIT, как у magiblot ([`LICENSE`](LICENSE)).

## Собрать DN своим fpc

Нужны: `fpc` 3.2.x (проверка: `fpc -iV`; в Debian/Ubuntu `sudo apt install fp-compiler fp-units-rtl`), `python3`, `git`. Больше ничего (ни Lazarus, ни библиотек).

    git clone https://github.com/unxed/dn && cd dn
    tools/build.sh linux64            # x86_64 Linux: компилирует DN, ресурсы и справку, результат в out/linux64/
    cd out/linux64 && ./dn            # нужен терминал не меньше 80x25; выход — Alt-X

Что дальше: правьте `dn/src` (исходники DN) или `tv/src` (библиотека), снова `tools/build.sh linux64` (несколько секунд); проверки —
`tools/dn-test.sh` (юнит-тесты DN), `python3 tools/dn-linux-ops.py out/linux64` (F5/F6/F7/F8/F4 и команда на настоящих файлах в pty), `python3 tools/dn-linux-locale.py out/linux64` (кодовая страница по локали),
тесты TV — п. 1 ниже. Для i386 Linux и DOS нужны кросс-компиляторы (`tools/build-fpc-i386-linux.sh`, `tools/build-fpc-go32v2.sh`), см. `dn/README.md`.
Перед PR: `tools/check-layout.sh` и ворота аудита (`dn/README.md`, «Правила работы»).

Правила разделения (проверяются `tools/check-layout.sh` в CI):

1. `tv/` ничего не знает о `dn/`: его юниты используют только друг друга и RTL FPC.
2. `dn/` использует TV только как пакет, через его юниты; файлы TV в `dn/` не копируются и наоборот.
3. Код из `tv/` и `dn/` не смешивается: у них разные лицензии.
4. Код DN происходит только из **публично доступных источников**. Первый коммит `dn/src` получен из
   публичного архива DN OSP 2.14 скриптами `bootstrap/` (адрес и sha256 архива, исключения, правки, наши файлы:
   `bootstrap/README.md`, любой может воспроизвести и сверить); дальше `dn/src` меняется обычными коммитами. Происхождение
   каждого файла — `dn/PROVENANCE.md`.
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

0. **DN под Linux:** собрать одной командой (нужны `fpc` 3.2.x и `python3`):

       tools/build.sh linux64                  # результат out/linux64/dn, ресурсы и справка рядом
       cd out/linux64 && ./dn                  # нужен терминал не меньше 80x25
       python3 tools/dn-linux-tour.py out/linux64      # обход по сценариям в pty
       python3 tools/dn-linux-ops.py out/linux64       # F7/F5/F6/F8/F4 на настоящих файлах, проверка по файловой системе

   Без сборки: `cd dist/linux && ./dn` (i386, статический ELF; описание — `dist/linux/README.TXT`, экраны — `dist/linux/screenshots/*.txt`).
   i386 из исходников: `tools/build-fpc-i386-linux.sh ПРЕФИКС`, затем `DN_LINUX=ПРЕФИКС tools/build.sh linux`.

0w. **DN под Windows** (кросс-сборка на Linux; нужны `fpc`, `make`, `git`, `binutils-mingw-w64-x86-64` / `-i686`, `python3`):

       tools/build-fpc-windows.sh ПРЕФИКС win64      # кросс-компилятор из исходников FPC (один раз; win32 — так же, с `win32`)
       DN_WIN=ПРЕФИКС tools/build.sh win64          # результат out/win64/dn.exe, ресурсы, справка и XLT\ рядом (win32: DN_WIN32=...)
       python tools/dn-win-smoke.py out/win64       # на Windows: настоящая консоль (ConPTY), pip install pywinpty; в CI — workflow dn-windows

   Без сборки: `dist/win64/DN.EXE`, `dist/win32/DN.EXE` (описание — `README.TXT` рядом; нужна консоль Windows 10 1809+ или Windows Terminal).
   Вывод на Windows по умолчанию идёт через Console API (`WriteConsoleOutputW`: работает в wine и в Windows старше 10); `DN_WIN_OUTPUT=vt` включает прежний режим
   с VT-последовательностями (консоль Windows 10 1809+ / Windows Terminal). Проверяет CI на настоящем Windows (`tools/dn-win-smoke.py`).

1a. **TV в терминале Linux** (нужны `fpc` и `python3`; терминалом служит `tools/pty_screen.py`):

        fpc -Futv/src -FUout -FEout tv/demo/tvdemo.pas
        python3 tv/tests/pty/test_tvdemo.py out/tvdemo      # меню, окна, мышь, смена размера, выход: «ALL OK»
        out/tvdemo                                          # руками, в настоящем терминале (Alt-X — выход)

    Тесты разбора клавиш и вывода (`t_termio`, `t_ansi`) идут в общем цикле пункта 1. Цвета: `TV_COLORS=0|8|16|256|direct`,
    мышь: `TV_MOUSE=0`, задержка Esc: `ESCDELAY=мс`.

2. **Тесты наших юнитов DN** (`dn/tests`): `tools/dn-test.sh` (то же запускает job `units` в `.github/workflows/dn.yml`).

3. **Инструменты для DOS** (один раз; нужны `fpc`, `make`, `git`, `curl`, `bzip2`, `dosbox-x`, `unrar`, `unzip`, `python3`, `patch`):

       tools/build-fpc-go32v2.sh $HOME/go32     # кросс-компилятор FPC → DOS и DJGPP binutils, ~15 минут

4. **DN для DOS: собрать и запустить в DOSBox-X** (без окна, на заглушках SDL):

       DN_PREFIX=$HOME/go32 tools/build.sh dos out/dos           # dn.exe, rcp.exe в DOSBox-X делает *.DLG/*.LNG, tvhc делает *.HLP
       DN_PREFIX=$HOME/go32 tools/dn-tour.sh out/dos [имя...]    # обход по сценариям в DOSBox-X: экраны в out/dos/<имя>.txt

   Нужна сборка с номерами строк для разбора падения: `DN_EXTRA=-gl`. Если DN упал, смотрите `DNERR.TXT` рядом с запуском.
   Отладка: `tools/dn-trace-calls.py` / `tools/dn-trace-init.py` ставят трассы в **копию** `dn/src` (`cp -r dn/src build/traced`),
   сборка с `DN_SRC=build/traced`. Дамп экрана `SCR.DAT` смотреть: `python3 tools/render-dump.py SCR.DAT`.

0. **Без сборки:** в `dist/dos/` лежит готовая DOS-версия (`DN.EXE`, ресурсы, DPMI-хост `CWSDPMI.EXE`, тексты лицензий,
   `screenshots/`): смонтируйте каталог в DOSBox-X и запустите `dn` (см. `dist/dos/README.TXT`). Обновляется скриптом
   `tools/dn-dist.sh` при заметных изменениях; она собрана из того коммита, который указан в сообщении коммита `dist`.

5. **Посмотреть работу руками:** каталог `out/dos/` — готовый набор для DOS (`dn.exe`, `CWSDPMI.EXE`, `*.DLG`, `*.LNG`):
   смонтируйте его в DOSBox-X (`mount c out/dos`, `c:`, `dn`) или скопируйте на машину с DOS.
