# maria-laptop-setup

Автоматическая настройка ноутбука на Ubuntu 24.04 LTS: приложения, среда
разработки, AI-инструменты, dotfiles, горячие клавиши, расширения браузера и
VS Code, виртуалка с Windows 11.

Скрипты только устанавливают и настраивают. **Никаких входов в аккаунты,
никакой синхронизации и никаких паролей в репозитории.** Всё, что требует
логина, вынесено в [`MANUAL.md`](MANUAL.md).

## Что нужно до начала

- Ноутбук с Ubuntu 24.04 LTS, пользователь `maria` (создаётся при установке ОС).
- Интернет.
- Пароль `maria` (для `sudo`).
- Около 60 ГБ свободного места (Windows VM добавляет ещё ~40–60 ГБ).

Установка ОС: русский язык, часовой пояс Москва, **без шифрования диска**,
обычная установка. Имя пользователя — `maria`, иначе часть скриптов
пропустит шаги с группами.

## Быстрый старт

```bash
# 1. git (единственное, что ставится вручную)
sudo apt update && sudo apt install -y git

# 2. клонировать репозиторий в домашний каталог
cd ~
git clone https://github.com/Mikhail-69/maria-laptop-setup.git
cd maria-laptop-setup

# 3. идти по этапам по порядку
bash 01-base.sh
bash 02-dev.sh
bash 03-ai.sh
bash 04-apps.sh
bash 05-desktop.sh
bash 06-gaming.sh
bash 07-vm.sh
bash 08-vscode.sh
bash 09-firefox.sh
bash 10-user.sh
bash 11-verify.sh
```

Перезагрузка/перелогин нужен после `05-desktop.sh` (расширения GNOME),
после `10-user.sh` (группы) и после `06-gaming.sh` (Steam).

Каждый этап идемпотентен: повторный запуск ничего не ломает. Прогресс
хранится в `~/.local/state/laptop-setup/`, лог — в
`~/.local/state/laptop-setup/setup.log`. Перезапустить этап принудительно:

```bash
FORCE=1 bash 04-apps.sh
```

Проверить, что скрипт сделает, ничего не делая:

```bash
DRY_RUN=1 bash 04-apps.sh
```

## Этапы

| Скрипт | Что делает |
|---|---|
| `01-base.sh` | базовые пакеты, кодеки, шрифты, `thefuck`, aliases, `.gitconfig`, flatpak, автообновления |
| `02-dev.sh` | git, gh, Go, uv, bun, Java, Docker + compose, PyCharm Community |
| `03-ai.sh` | Claude Code, Codex, OpenCode, Claude Desktop, ChatGPT/Codex Desktop, перенос конфигов `~/.claude`, `~/.codex`, `~/.config/opencode`, скиллы |
| `04-apps.sh` | Chrome, Discord, Spotify, Яндекс Музыка, Zoom, MTS Link, Coucou, Happ, FlClashX, DeepSeek, LocalSend, Notepad++, draw.io, DBeaver, Camunda Modeler, VK, RustDesk, Tailscale, LibreOffice, ярлыки FigJam/Miro/Excalidraw |
| `05-desktop.sh` | расширения GNOME, Snowhush, скрипты горячих клавиш, `langfix`, привязки клавиш, часовой пояс |
| `06-gaming.sh` | Steam, MangoHud, GameMode, Vulkan, GE-Proton |
| `07-vm.sh` | KVM/QEMU/libvirt, virt-manager, UEFI, TPM 2.0, virtiofsd, `virtio-win.iso` |
| `08-vscode.sh` | VS Code, 38 расширений, `settings.json` |
| `09-firefox.sh` | Firefox, 20 расширений с addons.mozilla.org, русский интерфейс |
| `10-user.sh` | второй sudo-пользователь `mikhail`, группы |
| `11-verify.sh` | проверка всего и список оставшихся ручных шагов |

## Что перенесено с текущей машины

- `~/.claude/`: `CLAUDE.md`, `settings.json`, хуки, 15 скиллов.
- `~/.codex/`: `AGENTS.md`, `config.toml`, `hooks.json`, `workflow.py`, правила, скиллы.
- `~/.config/opencode/`: `AGENTS.md`, `opencode.jsonc`, команды, плагин `coucou.js`, 15 скиллов.
- Глобальные конфиги: `.bash_aliases`, `.gitconfig`, `settings.json` VS Code.
- Горячие клавиши: 7 действий в двух вариантах — `Ctrl+NumPad` и `Ctrl+Alt+1..7`.
- Расширения VS Code (38 из 44) и Firefox (20).
- Snowhush целиком, включая GNOME-расширение с движком.

**Не переносится:** история чатов и память AI-инструментов, `secrets/`,
`.credentials.json`, `auth.json`, `service.json`, привязки Sticky и смены обоев.

## Горячие клавиши

| Действие | Numpad | Любая клавиатура |
|---|---|---|
| GitHub | `Ctrl+NumPad-2` | `Ctrl+Alt+1` |
| YouTube | `Ctrl+NumPad-1` | `Ctrl+Alt+2` |
| LeetCode | `Ctrl+NumPad-3` | `Ctrl+Alt+3` |
| Шпаргалка | `Ctrl+NumPad-0` | `Ctrl+Alt+4` |
| PDF-книга | `Ctrl+NumPad-4` | `Ctrl+Alt+5` |
| DBeaver | `Ctrl+NumPad-5` | `Ctrl+Alt+6` |
| Исправить раскладку | `Ctrl+NumPad-7` | `Ctrl+Alt+7` |

Исправление раскладки работает в сессии X11: на экране входа выбери
«Ubuntu on Xorg». Под Wayland `xdotool` не может печатать в чужие окна.

## Windows 11 в виртуалке

`07-vm.sh` готовит хост, `vm/create-vm.sh` создаёт машину (4 vCPU, 8 ГБ RAM,
120 ГБ, UEFI + Secure Boot, TPM 2.0), `vm/autounattend.xml` ставит Windows
без вопросов, `vm/post-install.ps1` доставляет Office, Visio и Visual Studio
с двумя workload. Подробности — в [`vm/README.md`](vm/README.md).

## Безопасность

- Репозиторий не содержит ключей, токенов и паролей. Провайдеры в
  `opencode.jsonc` ссылаются на файлы в `~/.config/opencode/secrets/`,
  каталог создаётся пустым.
- `maria` попадает в группу `docker`, а это фактически root-доступ.
- Второй пользователь `mikhail` получает `sudo` — это осознанное решение для
  удалённой поддержки.
- RustDesk и Tailscale не заработают, пока не задан постоянный пароль и не
  выполнен вход.
- Шифрования диска нет (по требованию).

## Проверка

GitHub Actions проверяет то, что можно проверить без графики:

- `bash -n` и `shellcheck` для всех скриптов;
- `DRY_RUN=1` для всех этапов;
- наличие всех apt-пакетов и snap-пакетов в Ubuntu 24.04;
- доступность всех внешних URL (`.deb`, API addons.mozilla.org, GitHub release assets);
- установку apt-части в контейнере `ubuntu:24.04`.

Графику, snap, GNOME и KVM в CI проверить нельзя — реальная проверка это
`11-verify.sh` на ноутбуке.
