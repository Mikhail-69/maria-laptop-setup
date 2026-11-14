# Откуда взято расширение Snowhush

`extension.js`, `metadata.json`, `bin/snowhush` и `LICENSE` — точная копия
рабочего расширения GNOME с машины Михаила:

```
~/.local/share/gnome-shell/extensions/snowhush@mbezruchko.github.io/
```

Почему копия, а не загрузка:

- Upstream-проект <https://github.com/mbezruchko/Snowhush> собирает deb, но его
  описание требует KDE Plasma 6, Hyprland, Sway или niri — не GNOME.
- Deb-пакет содержит `/usr/bin/snowhush`, собранный без интеграции с GNOME
  (другой бинарник: sha256 отличается от того, что лежит в `bin/`).
- Расширение общается с движком через D-Bus (`io.github.mbezruchko.Snowhush`,
  интерфейс `...Gnome`) и запускает именно `${extension.path}/bin/snowhush`.
  Подменить бинарник на системный нельзя: он не умеет этот интерфейс.

`metadata.json` заявляет `shell-version: ["46", "50"]`, то есть расширение
поддерживает GNOME 46 из Ubuntu 24.04.

Лицензия — PolyForm Noncommercial 1.0.0 (`LICENSE`, upstream). Личное
некоммерческое использование и приватное распространение в этом репозитории
разрешены. При публикации репозитория или коммерческом использовании
проверьте условия лицензии у автора.

Сопровождение: при обновлении расширения заменить файлы здесь и перезапустить
`FORCE=1 bash 05-desktop.sh`.
