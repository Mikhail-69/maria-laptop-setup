# Windows 11 в виртуалке

## Что делает автоматика

`07-vm.sh` ставит KVM/QEMU/libvirt/virt-manager, UEFI (OVMF), TPM 2.0 (swtpm),
virtiofsd и скачивает `virtio-win.iso`. `vm/create-vm.sh` создаёт саму машину:
4 vCPU, 8 ГБ RAM, 120 ГБ qcow2, UEFI + Secure Boot, TPM 2.0, virtio-диски и сеть.

`vm/autounattend.xml` разворачивает Windows без вопросов: русский язык, разметка
диска, локальный пользователь `maria`, обход требования сети и Microsoft-аккаунта.
`vm/post-install.ps1` внутри Windows ставит 7-Zip, Chrome, PowerToys,
Visual Studio Community (оба workload: .NET desktop и C++ desktop) и Microsoft 365
с Visio через Office Deployment Tool.

## Что нужно руками

1. **ISO Windows 11.** Скачать с <https://www.microsoft.com/software-download/windows11>
   и положить в `vm/iso/`. Автоматически с сайта Microsoft не скачивается: там
   капча и одноразовые ссылки.
2. **Проверить редакцию.** В `autounattend.xml` стоит `/IMAGE/INDEX` = 6 (Pro).
   Посмотреть реальные индексы:
   ```bash
   sudo apt install wimtools
   wiminfo vm/iso/Win11.iso | grep -E "^(Index|Name)"
   ```
   Если в ISO нет Pro, поменяй значение на нужное.
3. **Пароль локального пользователя в VM.** В `autounattend.xml` стоит
   `ChangeMe123!` — поменяй до первого запуска, иначе пароль придётся менять
   внутри Windows.
4. **Активация Windows.** Ключ вводится после установки: Параметры → Система →
   Активация. До активации Windows работает, но с водяным знаком и без
   персонализации.
5. **Активация Office и Visio.** Вход в Microsoft 365 под вашей подпиской:
   любое приложение Office → Войти. Отдельный ключ не нужен.
6. **Visual Studio.** Community бесплатна, но требует вход в аккаунт Microsoft
   при первом запуске.

## Производительность

16 ГБ RAM на хосте: 8 ГБ отдаём VM. Word/Excel/Visio работают нормально,
Visual Studio заметно медленнее, чем на железе, но компилировать можно.
Если ноутбук начнёт свопиться — уменьши RAM VM в virt-manager до 6 ГБ.

## 1С

1С в этот сценарий не входит: клиент для Linux и конфигурация УНФ скачиваются
с `users.v8.1c.ru` под логином ИТС. Это отдельный этап, см. `MANUAL.md`.
