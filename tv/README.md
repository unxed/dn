# tv: Turbo Vision на Free Pascal

Перевод на Pascal C++-библиотеки [magiblot/tvision](https://github.com/magiblot/tvision)
(коммит `b4831e2`) в стиле Pascal Turbo Vision: `object`, `Init`/`Done`, `New(P, Init(...))`,
`TView.HandleEvent`. Текст внутри — UTF-8; однобайтные строки показываются через кодовую
страницу (настройка).

## Лицензия

- Переведённые юниты — производная работа от magiblot/tvision, а значит и от опубликованного
  Borland выпуска TV 2.0: действуют отказ от гарантий Borland и лицензия MIT magiblot
  ([`COPYRIGHT.magiblot`](COPYRIGHT.magiblot)). Каждый такой юнит в заголовке называет
  файлы magiblot, из которых он переведён.
- Юниты, написанные для этого порта (`TvSys`, `TvMem`, `TvDos`, `TvUtil` в части, не
  переведённой из magiblot, тесты, демо), — под лицензией MIT ([`LICENSE`](LICENSE)), чтобы
  пакет в целом имел одну понятную лицензию. В их заголовке написано «Written for this port».
- DN (каталог `dn/` репозитория) — другая лицензия. Код между `tv/` и `dn/` не копируется;
  `tv/` не зависит от `dn/`.

## Состав

`src/` — юниты (список и соответствие файлам magiblot — в [`DESIGN.md`](DESIGN.md)),
`tests/` — тесты на бэкенде «в памяти» (запускаются и нативно, и под DOS), `dostests/` —
тесты бэкенда DOS (только в DOSBox-X), `demo/` — демо.

## Сборка и проверка

    cd tv/tests
    for t in t_*.pas; do fpc -Fu../src -Fu. $t && ./${t%.pas}; done   # каждый печатает «ALL OK»

Под DOS: `tools/build-fpc-go32v2.sh` и `tools/dos-run.sh` (см. `.github/workflows/tv.yml`).

## Как подключить к своему проекту

Добавить `tv/src` в путь юнитов (`-Fu`), в программе использовать `TvApp` (приложение),
`TvViews`, `TvWindow`, `TvMenus` и бэкенд: `TvDos` под DOS или `TvMem` в тестах.
Минимальный пример — `demo/tvdemo.pas`.
