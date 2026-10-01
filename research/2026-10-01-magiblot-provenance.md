# Происхождение кода magiblot/tvision (2026-10-01)

Задача: убедиться, что в части magiblot/tvision, которую переводим, есть только код из
опубликованного Borland выпуска Turbo Vision 2.0 и код magiblot и соавторов (MIT).
Иначе говоря, что в неё не попал код из других портов (в первую очередь из GPL-порта SET)
или из коммерческих продуктов Borland.

Инструмент: `audit/cclone.py` — тот же подход, что `xclone.py` (дословные цепочки из
24 токенов), но для C/C++ и с двумя эталонами. Колонка `only%` — код, который совпадает со
вторым эталоном и при этом отсутствует в первом.

## Материалы

- magiblot/tvision, полная история (1361 коммит, HEAD `b4831e2`). Корневой коммит
  `adb6e3a` — «Version 1.03», следом `4a67222` — «Version 2.0». Оба от 2019-01-02, это
  импорт выпусков Borland. В импорте 2.0 201 файл, только `include/` и `source/`,
  Borland упомянут в каждом.
- Порт SET (Salvador E. Tropea) 2.0.3 — архив `TV_2.03_sources.ver.2.03.English.7z`,
  http://old-dos.ru/dl.php?id=9393, sha256
  `34d27cffff01d0b38b199c035d040bb2b3e88c41935f63d9828dd4db033471ac`. Это не
  оригинальный выпуск Borland, а производный порт под GPL v2, в нём лежит `borland.txt`
  с текстом Borland. В его `readme.txt` указан источник оригинала
  (`ftp.inprise.com/pub/borlandcpp/devsupport/archive/turbovision/tv.zip`) и сказано, что
  по данным Inprise это «Public Domain version». Часть примеров SET взял из порта Sigala (BSD).

## Результаты

**Объём перевода — библиотека magiblot:** `source/tvision`, `source/platform` и
`include/tvision` без `compat/`. Это 261 файл C/C++, 204 тыс. токенов.

1. Код из GPL-порта SET, которого нет в импорте Borland, в библиотеке не найден.
   Самые длинные такие цепочки — 60, 53 и 53 токена. В `tview.cpp` это список
   инициализации конструктора `TView` (значения полей — из кода Borland; оба порта
   переписали присваивания в инициализаторы). В `base64.cpp` — таблица чисел 26…51,
   в `codepage.cpp` — алфавит «A»…«Z» в таблице. Остальное — цепочки не длиннее 43 токенов.
2. Кода, который есть в TV 1.03 и отсутствует в TV 2.0, в библиотеке 0,1 %: одна цепочка
   в 27 токенов (`tparamte.cpp`). Код Borland в библиотеке, таким образом, происходит из
   выпуска 2.0.
3. 46,1 % токенов библиотеки дословно совпадают с импортом Borland 2.0. Остальное
   написано magiblot и соавторами (MIT).
4. Импорт magiblot «Version 2.0» дословно совпадает с портом SET на 52,6 % токенов
   (SET свои файлы сильно правил). Это согласуется с общим происхождением от одного
   выпуска Borland.

## Что не переводим

- `examples/` (tvdemo, tvedit, tvhc, tvforms и др.). В импорте Borland 2.0 примеров нет,
  а с портом SET они совпадают на 40–90 % мимо импорта. Это не часть опубликованного
  выпуска TV, у них другое происхождение. Компилятор справки для DN (`tvhc`) пишем сами.
  Библиотечная часть справки (`helpbase`, `help`) входит в выпуск.
- `include/tvision/compat/borland/` — заголовки совместимости с RTL Borland C++. По
  истории (`f9c6121`) часть из них скопирована из Borland C++ 4.0. В Pascal-переводе они
  не нужны.

## Сверка с опубликованным выпуском

Источник опубликованного выпуска — https://github.com/FSharpCSharp/TurboVision, коммит
`5b9182e` («Adding the unzipped files published by Borland», 2019-02-01). В нём `Include/`,
`Source/`, `readme.txt` (текст Borland «NOTE ON THE CONTENTS OF THIS ARCHIVE…»),
`disclaim.txt`.

Сравнение с импортом magiblot `4a67222` («Version 2.0»), пофайлово:
- 200 из 201 файла совпадают полностью, разница только в переводах строк (CRLF) и символе
  конца файла;
- `tv.h` отличается только комментарием-шапкой: в опубликованной версии в ней текст
  отказа от гарантий и «Copyright (c) 1991, 1994», у magiblot — «Copyright (c) 1994».
  Код совпадает токен в токен (2076 токенов).

Вывод: код Borland в magiblot происходит из опубликованного выпуска TV 2.0. Импорт
«Version 1.03» (`adb6e3a`) в опубликованный выпуск не входит, но кода, которого нет в 2.0,
в текущей библиотеке 0,1 % (одна цепочка в 27 токенов, `tparamte.cpp`).

Оговорка: `FSharpCSharp/TurboVision` — это стороннее зеркало. Канонический `tv.zip`
лежит на сайте Sergio Sigala, но из сессии он недоступен (sigala.it — 403, web.archive
закрыт). Сверку с ним можно повторить в CI.

## Ссылки

- Опубликованный выпуск TV 2.0, распакованный: https://github.com/FSharpCSharp/TurboVision
- Страница исходников на сайте Sergio Sigala (порт TV, BSD):
  http://www.sigala.it/sergio/tvision/resources.html#sources
- `tv.zip` от Borland: http://www.sigala.it/sergio/tvision/borland/tv.zip,
  копия в web.archive:
  https://web.archive.org/web/20170708213734/http://www.sigala.it/sergio/tvision/borland/tv.zip
- Исходный адрес Borland/Inprise (по `readme.txt` порта SET, сейчас недоступен):
  `ftp://ftp.inprise.com/pub/borlandcpp/devsupport/archive/turbovision/tv.zip`
- Порт SET 2.0.3 (GPL): http://old-dos.ru/dl.php?id=9393
- magiblot/tvision: https://github.com/magiblot/tvision
