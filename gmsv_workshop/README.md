# gmsv_workshop 4.0 (Trainfitter edition)

Серверный бинарный модуль для Garry's Mod: даёт серверу `steamworks.DownloadUGC` и `steamworks.FileInfo`, чтобы качать и монтировать Workshop-аддоны на лету (`game.MountGMA`). Trainfitter использует его на dedicated-серверах.

Основано на [WilliamVenner/gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop) (MIT, см. [LICENSE](LICENSE)), переписано под обновления Garry's Mod 2025-2026.

## Что изменилось и почему

| Проблема | Причина | Решение |
|---|---|---|
| `Couldn't load module library! (undefined symbol: SteamAPI_SteamGameServerUGC_v017)` | Garry's Mod обновил Steamworks API (сентябрь 2026 - 1.64), в `steam_api` больше нет экспорта `_v017` | Модуль больше не линкуется со `steam_api` вообще: нужные функции ищутся в уже загруженном `steam_api` при запуске, версия интерфейса (`v017`, `v021`, ...) подбирается автоматически |
| Модуль не грузится на 64-bit Windows srcds | С сентября 2026 64-битный srcds есть во всех ветках, а `lua_shared.dll` лежит в `garrysmod/bin/win64/` | Поиск `lua_shared` через уже загруженный модуль процесса, плюс новые пути |
| `Failed to process download: No such file or directory (os error 2)` | Папка кеша не создавалась перед копированием `.gma` | Папка создаётся всегда, распаковка атомарная (`*.part` -> rename) |
| Порча памяти в `FileInfo` | В новых SDK `SteamUGCDetails_t` стала больше, старый модуль писал её в буфер старого размера | Буфер с запасом + структура по SDK 1.6x |
| Сервер подвисал на распаковке больших аддонов | LZMA распаковывалась в главном потоке | Распаковка в фоновом потоке |
| Обновлённый аддон не перекачивался | Кеш по одному `<id>.gma` без учёта версии | Кеш `cache/gmsv_workshop/<id>_<timestamp>.gma`, старые версии удаляются |
| Утечка файловых дескрипторов | Хэндл `file.Open`, переданный в callback, не закрывался | Закрывается после callback |
| Требовался nightly Rust | `gmod`-крейт и старый `steamworks-rs` | Свои минимальные привязки, собирается на stable Rust |
| LZMA-бомба могла забить диск и память | Размер распаковки и словарь LZMA не ограничивались | Заголовок LZMA проверяется до распаковки: словарь до 256 МБ, результат до 2 ГиБ, иначе отказ |
| Поток спама запросов плодил потоки распаковки | Каждый `DownloadUGC` запускал свой поток | Не больше 2 распаковок одновременно, остальные ждут в очереди |
| Кеш рос бесконечно | Старые версии чистились только для того же аддона | При старте чистятся файлы старше 14 дней и зависшие `*.part`, кеш держится в пределах 20 ГБ (старые удаляются первыми) |
| Модуль сам подгружал системные библиотеки | Поиск `lua_shared` мог открыть файл с диска | Модуль берёт только уже загруженные движком библиотеки |

Проверено на Garry's Mod dedicated server (патч 2026, `steam_api` с `SteamGameServerUGC_v021`): Windows x86 и x86-64 - загрузка модуля, `FileInfo`, `DownloadUGC` для `.gma` и legacy `.bin`, `game.MountGMA`. Linux-сборки: ELF без зависимости от `libsteam_api.so`, glibc 2.17+.

## Установка

1. Узнай нужный файл, выполнив в консоли сервера:
   ```lua
   lua_run print("gmsv_workshop_" .. ((system.IsLinux() and "linux" .. (jit.arch == "x86" and "" or "64")) or (system.IsWindows() and "win" .. (jit.arch == "x86" and "32" or "64")) or "UNSUPPORTED") .. ".dll")
   ```
2. Возьми этот файл из папки [`bin/`](bin) и положи в `garrysmod/lua/bin/` сервера (папку `bin` создай, если её нет)
3. Перезапусти сервер. В консоли должно появиться `[gmsv_workshop] v4.0.0 loaded (...)`

| Платформа | Файл |
|---|---|
| Windows 32-bit (`srcds.exe`) | `gmsv_workshop_win32.dll` |
| Windows 64-bit (`srcds_win64.exe`) | `gmsv_workshop_win64.dll` |
| Linux 32-bit (`srcds_run`) | `gmsv_workshop_linux.dll` |
| Linux 64-bit (`srcds_run_x64`) | `gmsv_workshop_linux64.dll` |

macOS: Garry's Mod не выпускает dedicated-сервер под macOS, поэтому сборки нет.

## Lua API

```lua
steamworks.DownloadUGC(wsid, function(path, file) end)
steamworks.FileInfo(wsid, function(info) end)
local ready, message = steamworks.gmsv_workshop_status()
print(steamworks.gmsv_workshop)
```

`path` - путь относительно `garrysmod/` (подходит для `game.MountGMA` и `file.Open(path, "rb", "GAME")`), `nil` при ошибке. `info.children` - обязательные аддоны (Required items) предмета, `info.error` - код ошибки Steam (`9` = предмета нет).

## Сборка

Windows (нужны Rust, MSVC Build Tools, для Linux-сборок `pip install ziglang` и `cargo install cargo-zigbuild`):

```powershell
.\build.ps1
```

Linux:

```bash
./build.sh
```

Готовые файлы появятся в `bin/`.
