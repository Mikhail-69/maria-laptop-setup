# Ручные шаги

Скрипты не входят ни в один аккаунт. Здесь собрано всё, что нужно сделать
руками после `11-verify.sh`.

## 1. Установка Ubuntu

При установке выбрать:

- язык русский, раскладка русская + английская;
- часовой пояс Москва;
- **шифрование диска — выключено**;
- обычная установка, сторонние кодеки можно включить;
- имя пользователя `maria`, компьютер — любое;
- пароль запомнить: он нужен для `sudo`.

После первого входа поставить `git` и запустить этапы из `README.md`.

## 2. Аккаунты

Ничего не авторизовано, всё ставится «как есть». По порядку:

| Что | Как |
|---|---|
| GitHub | `gh auth login` (нужно для `git push`) |
| Claude Code | `claude` → вход через браузер |
| Codex CLI | `codex` → вход |
| OpenCode | `opencode auth login` |
| Claude Desktop | запустить приложение, войти |
| ChatGPT / Codex Desktop | запустить приложение, войти |
| Firefox | по желанию: вход в аккаунт Mozilla для синхронизации |
| Bitwarden | расширение уже стоит, открыть и войти |
| Spotify | запустить и войти |
| Яндекс Музыка | запустить и войти (нужна подписка Плюс) |
| Discord | запустить и войти |
| VK | запустить и войти |
| Zoom / MTS Link | войти в аккаунт при первом созвоне |
| Steam | запустить, войти, включить Steam Play |

### Ключи провайдеров для OpenCode

`~/.config/opencode/opencode.jsonc` ссылается на файлы, которых в репозитории
нет:

```
~/.config/opencode/secrets/github-pat
~/.config/opencode/secrets/mistral-key
```

Каталог `~/.config/opencode/secrets/` создан с правами `700`. Файлы нужно
положить самому, если эти провайдеры нужны. Без них OpenCode работает с
провайдерами по OAuth.

## 3. Firefox

- Расширения уже распакованы в профиль. При первом запуске Firefox может
  показать вкладку «Отключить неподписанные расширения» — этого не будет,
  все `.xpi` подписаны Mozilla.
- Русский интерфейс включён через `user.js`. Если интерфейс остался английским:
  Настройки → Основные → Язык → добавить русский и перезапустить.
- Домашняя страница — подписки YouTube (как на текущей машине).
- Пароли в Firefox не переносятся: импорт из Bitwarden вручную.

## 4. VS Code

- Расширения установлены, `settings.json` записан. Старый файл, если был,
  сохранён как `settings.json.laptop-setup.bak`.
- Тема иконок `material-icon-theme`, тема `Dark+`, шрифт JetBrains Mono.
- Синхронизация настроек (Settings Sync) не включалась — включи, если нужен
  GitHub-аккаунт в редакторе.

## 5. Алиасы и терминал

`~/.bash_aliases` перенесён из текущей машины. Там есть `fuck` (thefuck),
`gs/ga/gc/gl` для git, `update`, `cls`, `..`, `vpn` (запуск FlClashX) и
`deepseek`. Алиасы вступают в силу в новом терминале.

`.gitconfig` содержит имя и почту Михаила. Если коммиты должны быть от имени
Марии:

```bash
git config --global user.name "Maria ..."
git config --global user.email "maria@example.com"
```

Подпись коммитов не включена (по требованию).

## 6. Исправление раскладки (langfix)

Скрипт работает через `xclip` и `xdotool`, поэтому только в сессии X11.

На экране входа нажать шестерёнку → выбрать **Ubuntu on Xorg** → войти.
В Wayland комбинация `Ctrl+Alt+7` не сможет печатать в чужие окна.

## 7. Steam и Proton

1. Запустить Steam, войти.
2. Настройки → Совместимость → **Включить Steam Play для всех остальных
   игр** → выбрать `GE-Proton` (уже скачан в
   `~/.steam/steam/compatibilitytools.d`).
3. MangoHud включается в свойствах игры: параметр запуска
   `mangohud %command%`, GameMode — `gamemoderun %command%`.
4. Если GE-Proton не скачался: `protonup-ng` в терминале, выбрать версию,
   каталог `~/.steam/steam/compatibilitytools.d`.

## 8. Windows 11 в виртуалке

1. Скачать ISO Windows 11 с <https://www.microsoft.com/software-download/windows11>
   и положить в `vm/iso/`.
2. Проверить редакцию:

   ```bash
   sudo apt install -y wimtools
   wiminfo vm/iso/Win11.iso | grep -E "^(Index|Name)"
   ```

   В `vm/autounattend.xml` стоит индекс 6 (Pro). Если его нет — поменять.
3. Поменять пароль `ChangeMe123!` в `vm/autounattend.xml` на свой.
4. `bash vm/create-vm.sh`, затем открыть `virt-manager` и установить Windows.
5. Внутри Windows запустить `post-install.ps1` (PowerShell от администратора):

   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\post-install.ps1
   ```

6. Активировать Windows ключом (Параметры → Система → Активация).
   До активации система работает с водяным знаком.
7. Войти в Microsoft 365 — Office и Visio активируются подпиской.
8. Войти в Visual Studio Community (бесплатная лицензия требует аккаунт).

Если разметка диска в `autounattend.xml` не подошла (нестандартный ISO),
установить Windows вручную: остальные шаги те же.

## 9. 1С

1С в этот сценарий не входит. Клиент для Linux и конфигурация УНФ качаются
с `users.v8.1c.ru` под логином ИТС. Порядок:

1. Скачать `deb` клиента 1С для Linux (x86_64).
2. `sudo apt install ./1c-*.deb`.
3. Запустить `1cv8` и добавить базу по адресу сервера.
4. Если нужна локальная файловая база — создать её в клиенте.

Лицензия привязывается к аккаунту ИТС, автоматизировать это нельзя.

## 10. Удалённый доступ

- **RustDesk**: запустить, Параметры → Безопасность → задать постоянный
  пароль. Без пароля подключиться нельзя.
- **Tailscale**: `sudo tailscale up` и войти в браузере. До этого машина не
  в tailnet.
- **SSH** не включался. Если нужен: `sudo apt install openssh-server`.

## 11. Что установлено не так, как на текущей машине

Осознанные отличия, потому что на новой машине другое окружение:

| Что | Решение | Почему |
|---|---|---|
| Miro | ярлык Chrome (`--app`) | официального клиента для Linux нет |
| FigJam, Excalidraw | ярлыки Chrome | нет десктоп-клиентов |
| Jamboard | заменён на FigJam/Miro/Excalidraw | сервис закрыт 31.12.2024 |
| Notepad++ | snap `notepad-plus-plus` | нативный сборки нет, работает через Wine |
| PyCharm | Community из snap | Professional требует лицензию; переключение — JetBrains Toolbox |
| DBeaver | Community | Azure Data Studio снят с поддержки |
| Snowhush | GNOME-расширение с движком в репозитории | deb-версия требует KDE/Hyprland/Sway/niri |
| VK | zip-сборка в `/opt/vk-desktop` | deb-пакета в релизе нет |
| Camunda Modeler | `tar.gz` в `/opt` | deb-пакета в релизе нет |
| Яндекс Музыка | версия из `versions.env` | у S3 нет ссылки «latest» |
| Chrome | только браузер | расширения Chrome не переносились (их нет на текущей машине) |
| Wayland/X11 | Xorg для langfix | xdotool не работает в Wayland |

## 12. Обновление версий

Версии, у которых нет стабильной ссылки «latest», лежат в `versions.env`:
`GO_VERSION`, `YANDEX_MUSIC_VERSION`, параметры VM. Если скачивание начало
падать с 404 — обновить значение и перезапустить нужный этап с `FORCE=1`.

Всё остальное (GitHub-релизы Coucou, draw.io, Camunda, VK, RustDesk, Happ,
FlClashX) резолвится через GitHub API в момент установки.

## 13. Если что-то пошло не так

- Лог: `~/.local/state/laptop-setup/setup.log`.
- Отметки этапов: `~/.local/state/laptop-setup/done-*`. Удалить файл — этап
  выполнится заново.
- `DRY_RUN=1 bash NN-*.sh` показывает команды без выполнения.
- `11-verify.sh` показывает, что не установилось, и завершается с кодом 1,
  если есть провалы.
- Snap-приложения иногда не видны сразу: `snap list`, перезапуск терминала.
- Новые расширения GNOME включаются после перелогина.
- Группы `docker`, `libvirt`, `kvm` применяются после перелогина.
