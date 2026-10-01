# Тулчейн FPC → DOS (go32v2) в CI (2026-10-01)

Зелёный прогон: https://github.com/unxed/dn/actions/runs/36927004962 (коммит `6642bd9`,
workflow `toolchain`, около 2 минут). Проверено: `hello.pas` компилируется
кросс-компилятором в `HELLO.EXE`, а тот запускается в DOSBox-X без экрана и печатает
`hello from go32v2` (шаг проверяет строку через `grep`).

## Как собирается

- `tools/build-fpc-go32v2.sh PREFIX`: исходники FPC 3.2.2 с GitLab (тег `release_3_2_2`),
  загрузочный компилятор — `fp-compiler` из apt, бинарные утилиты DJGPP — релиз
  `andrewwutw/build-djgpp` (`djgpp-linux64-gcc1220.tar.bz2`). `make crossall` и
  `crossinstall` с `OS_TARGET=go32v2 CPU_TARGET=i386 BINUTILSPREFIX=i586-pc-msdosdjgpp-`.
  Результат — обёртка `PREFIX/bin/fpc-go32v2`. Результат кэшируется по хэшу скрипта.
- Компоновщик: `ld` из DJGPP с `OUTPUT_FORMAT("coff-go32-exe")`, стаб подставляется сам.
  Отдельные `exe2coff` и `stubify` не нужны.
- DPMI-хост: DOSBox-X без внешнего хоста выдаёт «Load error: no DPMI - Get csdpmi*b.zip».
  Workflow скачивает `https://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip`
  и кладёт `CWSDPMI.EXE` рядом с программой. В репозиторий хост не кладётся.

## Что оказалось не так (для следующих сессий)

- Пакет Ubuntu `fpc-source-3.2.2` (и его заглушка `fpc-source`) для кросс-сборки не годится:
  в нём нет верхнего `Makefile` (цели `crossall`) и каталога `compiler/msg`.
- `apt install fpc` тянет GTK, SDL и пр.: установка занимает 13 минут. Нужны только
  `fp-compiler fp-units-rtl`.
- Установленные юниты лежат в `lib/fpc/3.2.2/units/go32v2/<пакет>`, а не в
  `.../i386-go32v2`.
- Из сессии Claude недоступны `delorie.com`, `old-dos.ru`, `web.archive.org`, `sigala.it`;
  в CI они доступны (delorie проверено этим прогоном).

## Не проверено

- Как себя ведёт FPC-программа без `CWSDPMI.EXE` под FreeDOS и под Windows (NTVDM):
  это матрица вехи 5.
- Лицензия CWSDPMI на распространение: пока он только скачивается в CI и не
  публикуется как артефакт релиза.
