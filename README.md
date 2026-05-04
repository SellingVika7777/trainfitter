# Trainfitter

> **© SellingVika, 2026. All rights reserved.**
> Автор: **SellingVika** — `sellingvika@gmail.com`.
> Хедер `-- Made by SellingVika.` обязан остаться в каждом файле исходного кода.
> Лицензия — в [конце документа](#license--авторство).

Trainfitter — runtime-загрузчик скинов и масок поездов **Metrostroi Subway Simulator** в Garry's Mod. Игроки качают аддоны прямо в игре (без подписки в Steam, без рестарта сервера), сервер их валидирует жёстким многоуровневым сканером и раздаёт остальным. Скин/маска появляется в дропдауне `gmod_train_spawner` сразу после маунта.

---

## Оглавление

1. [Возможности коротко](#возможности-коротко)
2. [Требования](#требования)
3. [Установка](#установка)
4. [Пользовательский UI](#пользовательский-ui)
5. [Архитектура: что происходит при запросе](#архитектура-что-происходит-при-запросе)
6. [Self-healing после рестарта сервера](#self-healing-после-рестарта-сервера)
7. [Структура аддона](#структура-аддона)
8. [ConVar'ы](#convarы)
9. [Права: LFAdmin → fallback](#права-lfadmin--fallback)
10. [Консольные команды](#консольные-команды)
11. [Серверные файлы данных](#серверные-файлы-данных)
12. [Net-протокол](#net-протокол)
13. [Модель безопасности](#модель-безопасности)
14. [Что считается валидным аддоном](#что-считается-валидным-аддоном)
15. [Локализация (en / ru / da)](#локализация-en--ru--da)
16. [Как написать свой скин или маску](#как-написать-свой-скин-или-маску)
17. [Диагностика проблем](#диагностика-проблем)
18. [Обновление и удаление](#обновление-и-удаление)
19. [Известные ограничения](#известные-ограничения)
20. [История версий](#история-версий)
21. [License / Авторство](#license--авторство)

---

## Возможности коротко

- **Установка скина в один клик** через UI: вставка ссылки/WSID, превью из Workshop, кнопка «Применить».
- **Встроенный браузер Мастерской** на DHTML с инжекцией JS — сёрфишь Steam внутри игры и кликаешь Subscribe-кнопку прямо там.
- **Маски** (новый Workshop-аддон под `lua/metrostroi/masks/*.lua`) поддерживаются наравне со скинами.
- **Persistent-слот** на сервере: один «активный» скин, который автомаунтится при старте и догоняется новым игрокам.
- **Точечный hot-reload**: после маунта/удаления освежаются только составы того игрока, кто инициировал — чужие поезда не дёргаются.
- **Sequential download queue** на клиенте — параллельные скачки не забивают канал.
- **Live-уведомления** (`notification.AddLegacy` + `AddProgress`) вместо чата для прогресса/ошибок/готовности.
- **Локализация**: en / ru / da (переключатель в Настройках или конвар `trainfitter_lang`).
- **Стартовый ASCII-баннер** в консоль с версией и брендом.
- **Многоуровневая безопасность** (см. [Модель безопасности](#модель-безопасности)).
- **Аудит-лог** с ротацией, статистика по wsid, whitelist/blacklist.
- **LFAdmin-нативная** интеграция плюс fallback на `IsAdmin/IsSuperAdmin` (работает с ULX/SAM/ServerGuard/xAdmin/NADMOD/FAdmin/vanilla).

---

## Требования

| Сторона | Что нужно | Обязательно |
|---|---|---|
| Сервер | Garry's Mod Dedicated Server (32/64-bit, Win/Linux) | ✅ |
| Сервер | Metrostroi Subway Simulator (через `host_workshop_collection` или `addons/metrostroi/`) | ✅ |
| Сервер | `gmsv_workshop` DLL в `garrysmod/lua/bin/` | ✅ **с 2.1.1** |
| Сервер | Исходящие TCP 443 → `api.steampowered.com`, `*.steamcontent.com`, Steam CDN | ✅ |
| Сервер | LFAdmin или любая стандартная админка | опционально |
| Клиент | Garry's Mod (Legacy или x86-64) | ✅ |
| Клиент | Локальная установка | не нужна — приходит через `AddCSLuaFile` |

> С версии **2.1.1** HTTP-фолбэк удалён полностью. Без `gmsv_workshop` сервер отказывает на любой запрос с явным сообщением игроку и красной плашкой в `BuildServerIssues`. Это сделано осознанно: HTTP-фолбэк через публичный Steam API был медленным, ненадёжным и регулярно ломался под rate-limit'ом CDN.

---

## Установка

### 1. Скопировать аддон

```
<srcds>/garrysmod/addons/trainfitter/
├── addon.json
├── lua/...
└── materials/...
```

`addon.json` лежит на одном уровне с `lua/`. Двойной вложенности (`addons/trainfitter/trainfitter/lua/...`) быть не должно — это самая частая причина «не загрузилось».

### 2. Поставить gmsv_workshop

Бинарник лежит у [WilliamVenner/gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases). Положить в `<srcds>/garrysmod/lua/bin/` (папку `bin` создать руками если её нет):

| Платформа srcds | Файл |
|---|---|
| Windows 32-bit (`srcds.exe`) | `gmsv_workshop_win32.dll` |
| Windows 64-bit (`srcds_win64.exe`) | `gmsv_workshop_win64.dll` |
| Linux 32-bit | `gmsv_workshop_linux.dll` |
| Linux 64-bit | `gmsv_workshop_linux64.dll` |

Битность определяется по `file srcds_linux` или по имени `.exe`. На Windows иногда антивирус (Defender, Kaspersky) удаляет DLL как false-positive — добавить `garrysmod/lua/bin/` в исключения и снять Zone.Identifier через ПКМ → Свойства → Разблокировать.

### 3. Запустить и проверить

В консоли сервера на старте должно появиться:

```
[Trainfitter] gmsv_workshop loaded — server has native steamworks.DownloadUGC.
Trainfitter v2.1.1 (server)
by SellingVika
```

`FATAL: gmsv_workshop ...` или `[Trainfitter] gmsv_workshop missing` — DLL не загрузилась. Проверь битность и путь.

### 4. (Опционально) Настроить права и persistent

Если хочешь, чтобы качать могли только админы:

```
trainfitter_require_admin 1
```

Если хочешь зафиксировать активный скин на старте, добавь wsid в persistent через UI или:

```
] lua_run table.insert(Trainfitter.Persistent, "1234567890") Trainfitter.SavePersistent()
```

Подробнее про права — [ниже](#права-lfadmin--fallback). Про persistent-логику — [тут](#серверные-файлы-данных).

---

## Пользовательский UI

Открывается командой `trainfitter` (биндится по вкусу: `bind F3 trainfitter`) или иконкой в Spawn Menu desktop.

### Вкладки

- **Установка.** Поле для Workshop-ссылки или сырого WSID, превью с описанием, чекбокс «Сделать постоянным», кнопка «Подтвердить». Кнопка «Открыть Мастерскую» поднимает встроенный браузер.
- **Избранное.** Список persistent-wsid с поиском, действия Применить / Убрать / Открыть в браузере.
- **История.** Карточки скачанного в этой сессии, кнопка повторной установки.
- **Настройки** (только для `Trainfitter_Manage`). Дропдаун языка + правка серверных ConVar'ов на лету через `NET.AdminSetConVar`. Список активных скинов с кнопкой «Удалить» (broadcast forget на всех).

### Встроенный браузер Мастерской

Кнопка «Открыть Мастерскую» вместо `gui.OpenURL` поднимает окно `TrainfitterWorkshopBrowser` (`DHTML`):

- Стартует с поиска по `searchtext=metrostroi`.
- Кнопки back / forward / refresh / home, адресная строка.
- Большая кнопка `Apply (<wsid>)` справа активируется автоматически когда URL содержит `/sharedfiles/filedetails/?id=...`.
- Чекбокс «Сделать постоянным» — то же поведение, что и в Install.
- JS-инжекция переименовывает Steam-кнопку Subscribe в **«Select for Trainfitter»** и завязывает её на `gmod.tfselect()` — клик прямо на странице мгновенно стартует загрузку.
- Прямой запуск из консоли: `trainfitter_workshop`.

### Уведомления

Все статусы (скачка началась, готово, отклонено, удалено) уходят в правый нижний угол через `notification.AddLegacy`. Прогресс DownloadUGC показывается через `notification.AddProgress` с прогресс-полоской. Чат при этом не используется — никакого спама.

---

## Архитектура: что происходит при запросе

```
ИГРОК А                    СЕРВЕР                 ВСЕ ОСТАЛЬНЫЕ
   │                          │                          │
   │  [1] UI / browser /       │                          │
   │      trainfitter_workshop │                          │
   │────NET.Request───────────►│                          │
   │                          │  [2] HasSteamworks?       │
   │                          │  [3] CanDownload?          │
   │                          │  [4] Rate-limit/lists?     │
   │                          │  [5] FileInfo, appid=4000? │
   │                          │  [6] Size ≤ max_mb?        │
   │                          │                          │
   │                          │  [7] PendingRequest[wsid]  │
   │                          │      = {sid,title,size,…}  │
   │                          │      Notify «Validating…»  │
   │                          │      (другим — НИЧЕГО)     │
   │                          │                          │
   │                          │  [8] ServerMount(wsid):    │
   │                          │      steamworks.Download…  │
   │                          │      → onGMAReady          │
   │                          │      ├ ScanGMA (7 слоёв)   │
   │                          │      ├ MountGMA            │
   │                          │      └ exec lua/metrostroi/{skins,masks}/*.lua
   │                          │                          │
   │                          │  [9] FinalizePending:     │
   │                          │      BroadcastDownload    │
   │                          │      ├──NET.Broadcast────►│ ← ТОЛЬКО сейчас
   │                          │      ├ SetActiveSkin      │
   │                          │      ├ BumpStats          │
   │                          │      └ persistent logic   │
   │                          │                          │
   │ [10] DownloadUGC client──┤                          │ параллельно остальные
   │      ScanGMA, MountGMA,  │                          │
   │      exec skin/mask Lua  │                          │
   │      DiffAndReportSkins  │                          │
   │──NET.ReportSkins────────►│                          │
   │                          │ [11] EnsureSkinStub        │
   │                          │      (в Metrostroi.Skins   │
   │                          │       или Metrostroi.Masks)│
   │                          │                          │
   │ [12] Игрок берёт         │                          │
   │      gmod_train_spawner, │                          │
   │      выбирает скин/маску │                          │
   │                          │                          │
   │      Metrostroi callback │                          │
   │      видит skin в таблице│                          │
   │      → SetNW2String("Texture") / т.п.               │
   │                          │────NW2 replication──────►│
   │                                          UpdateTextures()
   │                                          → готово
```

**Ключевые точки:**

- Initiator получает `Notify «Validating…»` сразу. Остальные узнают только когда серверная валидация и маунт прошли (`finalize(true)`).
- При неудаче (scanner reject, MountGMA fail) шлётся `Notify «Failed to install…»` **только инициатору** — broadcast'а другим не происходит.
- Клиент после успешного mount'а делает `DiffAndReportSkins`: снимает снапшот `Metrostroi.Skins` и `Metrostroi.Masks` до/после исполнения скриптов, отправляет дельту серверу. Сервер пишет это в `Trainfitter.SkinOwnership[wsid]` (с полем `kind = "skin" | "mask"`), и для каждой записи создаёт стаб в нужной таблице через `EnsureSkinStub` — чтобы дропдаун Metrostroi у новых клиентов видел запись даже до того как они скачают сам аддон.
- Hot-reload (`Trainfitter.ReloadAllTrains`) запускается через 1 с после `Trainfitter.AddonMounted`/`SkinForgotten` хуков, фильтруется по SteamID инициатора и пропускает поезда, в которых сидит локальный игрок. Внутри — только soft-reload (`Texture/PassTexture/CabinTexture = nil` + `pcall(UpdateTextures)`); жёсткий `RemoveCSEnts` убран, потому что крашил.

---

## Self-healing после рестарта сервера

`Metrostroi.Skins`, `Metrostroi.Masks`, `SessionBroadcast`, `MountedServer` — всё in-memory. После рестарта:

1. `LoadPersistent` / `LoadLists` / `LoadStats` / `LoadNicks` поднимают JSON.
2. `pcall(SweepLegacyHttpCache)` чистит унаследованную папку `data/trainfitter/gmas/` (если осталась после апдейта со старой версии).
3. Хук `InitPostEntity` + `timer.Simple(3, ServerMountPersistent)` пере-маунтит persistent-скины.
4. Игрок коннектится → `PlayerInitialSpawn` отдаёт ему `SyncPersistent` + `ActiveSkin` + welcome-`Broadcast` для каждого persistent-wsid.
5. Клиент видит, что у него уже `Trainfitter.Mounted[wsid] = true` (с прошлой сессии). Вместо повторной скачки `Trainfitter.Enqueue` вызывает `ResendOwnership(wsid)` — отсылает кеш `MountedSkins[wsid]`.
6. Сервер пересоздаёт стабы → дропдаун Metrostroi снова находит все имена → `SetNW2String("Texture", ...)` работает.

---

## Структура аддона

```
trainfitter/
├── addon.json                         метаданные Workshop
├── README.md                          этот файл
├── materials/
│   ├── eye                            ASCII-арт для startup-баннера
│   └── icon64/trainfitter.png         иконка в Spawn Menu desktop
└── lua/
    ├── autorun/
    │   ├── sh_trainfitter.lua         shared init: версия, AddCSLuaFile, includes
    │   ├── server/sv_trainfitter.lua  весь server-side (~1.4k строк)
    │   └── client/
    │       ├── cl_trainfitter.lua     download queue, mount, hot-reload, NET-приёмники, ChatMsg→notification
    │       ├── cl_trainfitter_menu.lua    UI: вкладки, превью, settings
    │       ├── cl_trainfitter_browser.lua встроенный DHTML-браузер Мастерской
    │       └── cl_trainfitter_desktop.lua иконка в Spawn Menu desktop
    └── trainfitter/
        ├── sh_config.lua              ConVar'ы, Net-имена, Can*-хелперы (LFAdmin + fallback)
        ├── sh_lang.lua                словари en/ru/da, Trainfitter.L(key, ...), GetLang
        ├── sh_banner.lua              стартовый баннер (eye + версия) на Initialize/InitPostEntity
        └── sh_gma_scan.lua            ScanGMA + ValidateSkinLua: вся жёсткая защита
```

---

## ConVar'ы

Все серверные ConVar'ы — `FCVAR_ARCHIVE` (пишутся в `cfg/server.cfg`).

### Поведение

| ConVar | Default | Что делает |
|---|---|---|
| `trainfitter_max_mb` | 200 | Лимит размера аддона в МБ. Запросы больше — отклоняются до скачки. Диапазон 1–8192. |
| `trainfitter_require_admin` | 0 | `1` — качать может только привилегированный (LFAdmin `v`+ / IsAdmin / ramzi). `0` — все. |
| `trainfitter_request_cooldown` | 2 | Кулдаун между запросами одного игрока (сек). Дополнительно прибавляется bandwidth-backoff `+ sizeMB/10`. |
| `trainfitter_max_persistent` | 1 | Single-slot модель. Значения > 1 игнорируются. |
| `trainfitter_audit_log` | 1 | Писать `data/trainfitter/audit.log`. |
| `trainfitter_use_whitelist` | 0 | `1` — разрешены только wsid из `whitelist.json`. |
| `trainfitter_stats_enabled` | 1 | Считать статистику в `stats.json`. |
| `trainfitter_server_premount` | 1 | Сервер сам маунтит persistent-скины при старте. |
| `trainfitter_use_http` | 0 | `0` — авто: native `steamworks.DownloadUGC` на dedicated srcds с gmsv_workshop, HTTP-fetch на listen-server/SP/x64 (где native крашит) или если gmsv_workshop вообще не установлен. `1` — принудительно HTTP во всех случаях. |
| `trainfitter_lang` *(client)* | `ru` | Язык UI и уведомлений: `en` / `ru` / `da`. |

### Защитные (`FCVAR_PROTECTED`, не менять без понимания)

| ConVar | Default | Что делает |
|---|---|---|
| `trainfitter_server_gma_scan` | 1 | Серверный strict-скан GMA перед `MountGMA`. Отключение = доверие любому Workshop-аддону. |
| `trainfitter_content_scan` | 1 | Runtime-скан каждого `.lua` перед `CompileString`. Defense-in-depth. |
| `trainfitter_gma_scan` *(client)* | 1 | Клиентский скан перед маунтом. |

`FCVAR_PROTECTED` блокирует изменение через `say`/`rcon`/чужой console — нужно SuperAdmin.

---

## Права: LFAdmin → fallback

Trainfitter проверяет права в три уровня **по очереди** (первый сработавший — окончательный).

### 1. IsRamziLike short-circuit

Если у игрока `:IsRamzi() == true` (LFAdmin-группы с `:SetRamzi(true)` — `ramzi`/`meow`/`rawr`/`licen`) **или** `:IsSuperAdmin() == true` — сразу `true` для всех проверок Trainfitter. Спасает суперадмина от багов в реализации детальных флагов.

### 2. LFAdmin (если установлен)

Регистрируются три access-ключа через `LFAdmin.RegisterAccess`:

| Access | Флаг | Что разрешает |
|---|---|---|
| `trainfitter_download` | `v` (VIP/Staff) | Качать скины при `require_admin=1` |
| `trainfitter_persistent` | `a` (Admin) | Делать persistent / удалять чужой active |
| `trainfitter_manage` | `s` (SuperAdmin) | Whitelist/blacklist/ConVar'ы/cache |

Стандартные группы LFAdmin (`user`, `helper`, `moderator`, `administrator`, `curator` и т.д.) получают доступ согласно их флагам — Trainfitter ничего не настраивает за тебя, использует штатный `:HasAccess`.

### 3. Fallback

Если LFAdmin не загружен или access-ключ не зарегистрирован:

- `Trainfitter.CanDownload(ply)` → `ply:IsAdmin()`
- `Trainfitter.CanMakePersistent(ply)` → `ply:IsAdmin()`
- `Trainfitter.CanManage(ply)` → `ply:IsSuperAdmin()`

Эти методы override'ит **любая** популярная админка (ULX, SAM, ServerGuard, xAdmin, NADMOD, FAdmin, EasyAdmin, vanilla GMod). Совместимость максимальная.

---

## Консольные команды

| Команда | Кому | Что делает |
|---|---|---|
| `trainfitter` | всем (client) | Открыть UI |
| `trainfitter_workshop` | всем (client) | Открыть встроенный браузер Мастерской |
| `trainfitter_list` | всем | Показать persistent-список |
| `trainfitter_stats` | всем | Топ-20 wsid по скачкам |
| `trainfitter_remove <wsid>` | `Persistent` | Убрать wsid из persistent |
| `trainfitter_reload` | `Persistent` | Перечитать JSON-файлы и пере-маунтить persistent |
| `trainfitter_whitelist_add/remove/list <wsid>` | `Manage` | Управление whitelist |
| `trainfitter_blacklist_add/remove/list <wsid>` | `Manage` | Управление blacklist |
| `trainfitter_cache_clear` | `Manage` | Удалить **все** файлы из `data/trainfitter/gmas/` (HTTP-кеш). Persistent при следующем запросе пере-скачается. |
| `trainfitter_forget_all` | `Manage` | Forget всех скачанных скинов в текущей сессии **кроме** persistent. NW-ключи на поездах сбрасываются, broadcast forget всем клиентам, не-persistent кеш удаляется. Persistent остаётся как был. |
| `trainfitter_purge_all` | `Manage` | **Ядерная очистка.** Стирает persistent.json, ActiveSkin, MountedServer, SessionBroadcast, SkinOwnership, PendingRequest, удаляет ВЕСЬ кеш `data/trainfitter/gmas/`, broadcast forget всем клиентам по каждому wsid. После этого никаких скинов на сервере. |
| `trainfitter_audit [N]` | SuperAdmin | Последние N строк audit-лога с резолвом ников (default 30, max 500) |

---

## Серверные файлы данных

Всё в `<srcds>/garrysmod/data/trainfitter/`. Имена ниже — рекомендуемые для бэкапа при апдейте.

| Файл | Назначение |
|---|---|
| `persistent.json` | Массив `["3684752236"]` — активный скин. Single-slot. |
| `whitelist.json` | Массив wsid, разрешённых при `use_whitelist=1`. |
| `blacklist.json` | Массив wsid, запрещённых **всегда**, даже в whitelist-режиме. |
| `stats.json` | `{ wsid: { count, title, last } }`. Обновляется при каждом успешном маунте. |
| `nicks.json` | `{ steamid64: nick }`. Кеш для человекочитаемого `trainfitter_audit`. |
| `audit.log` | `[YYYY-MM-DD HH:MM:SS] <SteamID64\|CONSOLE> <action> :: <details>`. SteamID64, не ник — защита от log injection через смену ника. |
| `audit.log.old` | Ротация при 1 МБ. |
| `previews/<wsid>.png` | Клиентский кеш превью. Можно стереть — пере-кэшируется. |
| `gmas/<wsid>.gma` | HTTP-кеш скачанных GMA. Используется в HTTP-режиме (`trainfitter_use_http=1` или listen-server). На каждый `InitPostEntity` авточистка не-persistent файлов через `PruneNonPersistentCache`; на boot — `SweepStaleGMACache` (битые / старше 30 дней). Полная очистка — `trainfitter_cache_clear` или `trainfitter_purge_all`. |

---

## Net-протокол

Все строки регистрируются через `util.AddNetworkString` в начале `sv_trainfitter.lua`.

| Направление | Имя | Полезная нагрузка |
|---|---|---|
| C→S | `Trainfitter.Request` | wsid, makePersistent |
| C→S | `Trainfitter.RemovePersistent` | wsid |
| C→S | `Trainfitter.DeleteSkin` | wsid |
| C→S | `Trainfitter.RequestList` | — |
| C→S | `Trainfitter.GetServerStatus` | — |
| C→S | `Trainfitter.AdminGetConfig` | — |
| C→S | `Trainfitter.AdminSetConVar` | name, value |
| C→S | `Trainfitter.ReportSkins` | wsid, count, [{kind, category, name, typ}] × count |
| S→C | `Trainfitter.Broadcast` | wsid, initiatorNick, title, sizeMB, **initiatorSid** |
| S→C | `Trainfitter.ForgetSkin` | wsid, **initiatorSid** |
| S→C | `Trainfitter.ActiveSkin` | present? + wsid, title, initiator, sizeMB, since, **initiatorSid** |
| S→C | `Trainfitter.SyncPersistent` | count, [wsid] × count |
| S→C | `Trainfitter.Notify` | message, color |
| S→C | `Trainfitter.AdminConfig` | canManage, count, [{name, kind, value}] × count |
| S→C | `Trainfitter.ServerStatus` | count, [{severity, msg}] × count |

**Поля, добавленные в 2.1.0:**
- `initiatorSid` (SteamID64) во всех S→C сообщениях о скинах — для точечного hot-reload.
- `kind` (`"skin"` или `"mask"`) первой строкой каждой записи `ReportSkins` — для разделения owner-таблицы.

**Гарды:**
- Length cap'ы на каждый handler (128 байт для `Request`/`RemovePersistent`/`DeleteSkin`, 512 для `AdminSetConVar`, 8 КБ для `ReportSkins`).
- WSID валидируется регуляркой `^%d+$`, длина ≤ 20.
- Per-player rate-limit на `Request` (через `lastRequest`), `RequestList` (5 сек), `GetServerStatus` (5 сек), `AdminGetConfig` (3 сек).
- `ReportSkins` принимается только для wsid, уже находящегося в `SessionBroadcast`/`MountedServer`/`SkinOwnership`/`Persistent`. Левый wsid → audit `report_skins_unknown_wsid`.

---

## Модель безопасности

Чтобы протащить произвольный Workshop-аддон, надо пробить **семь независимых слоёв**.

### Слой 1 — Request-time gatekeeping (`HandleRequest`)

WSID-формат → `ServerHasSteamworks` → `CanDownload` → rate-limit → `whitelist`/`blacklist` → `Trainfitter.CanRequest` hook → `steamworks.FileInfo` (appid == 4000) → размер ≤ `max_mb`.

### Слой 2 — Path whitelist (`ScanGMA`)

| Тип файла | Где разрешён |
|---|---|
| Lua | **только** `lua/metrostroi/skins/` или `lua/metrostroi/masks/` |
| Данные | `materials/`, `models/`, `sound/`, `resource/`, `scripts/` (произвольные подпапки) |
| Метаданные | `addon.json`/`addon.txt`/`workshop.json`/`readme*`/`license*`/`changelog*` в корне |

Что угодно в `gamemodes/`, `maps/`, `bin/`, `cfg/`, `data/`, `addons/`, `scripts/vehicles/`, `scripts/weapons/`, `lua/autorun/`, `lua/weapons/`, `lua/entities/`, `lua/effects/`, `lua/includes/`, `lua/menu/`, `lua/derma/`, `lua/vgui/` → отказ всему GMA. Также блокируются path traversal'ы: `..`, `\0`, `:`, абсолютные пути.

### Слой 3 — Extension whitelist

Разрешено: `.lua .vmt .vtf .png .jpg .jpeg .mdl .vvd .phy .vtx .ani .wav .mp3 .ogg .ttf .otf .txt .md .json .properties .pcf`. Всё остальное (`.exe`, `.dll`, `.bat`, `.so`, `.py`, …) — отказ, даже под разрешённой папкой.

### Слой 4 — Size & count caps

| Лимит | Значение |
|---|---|
| `MAX_FILE_SIZE` | 256 МБ на один файл |
| `MAX_LUA_FILE_SIZE` | 64 КБ на addon-`.lua` (tight cap, единственный executable surface) |
| `MAX_TOTAL_UNCOMPRESSED` | 1 ГБ суммарно |
| `MAX_TOTAL_FILES` | 4096 файлов |
| `MAX_LUA_FILES` | 256 `.lua` |
| `MAX_TOTAL_LUA_BYTES` | 4 МБ суммарного Lua к сканированию (anti-bomb) |

### Слой 5 — Marker requirement

В GMA должен быть хотя бы один файл под `lua/metrostroi/skins/` или `lua/metrostroi/masks/`. Без них это не аддон Metrostroi-косметики.

### Слой 6 — Lua content scanner (`ValidateSkinLua`)

Каждый addon-`.lua` нормализуется (выкусываются комментарии и литералы строк) и прогоняется через ~80 запрещённых паттернов. Любой матч → отказ всему GMA.

| Категория | Что блокируется |
|---|---|
| Exec | `RunString*`, `CompileString`, `CompileFile`, `loadstring`, `load()`, `loadfile`, `dofile`, `xpcall()`, `string.dump`, `setfenv`, `getfenv` |
| Package | `package.loaded`/`preload`/`loadlib`/`loaders`/`searchers`/`cpath`/`path`/`seeall`, `package.*` |
| Network | `http.*`, `HTTP()`, `socket.*` |
| Filesystem | `file.Write`/`Append`/`Delete`/`CreateDir`/`Rename`, `sql.*`, `cookie.Set`, `:SetPData`, `util.SetPData`, `io.*`, `os.*` (process-уровень) |
| Process | `RunConsoleCommand`, `game.ConsoleCommand`, `cvars.*`, `CreateConVar*`, `os.execute/exit/remove/rename/getenv`, `collectgarbage` |
| Hooks/Timers | `concommand.*`, `hook.*`, `timer.*`, `coroutine.*`, `usermessage.*`, `umsg.*`, `datastream.*` |
| Net | `net.*`, `util.AddNetworkString` |
| Gamemode | `gamemode.Call/Register`, `gmod.GetGamemode` |
| Ents/Tools | `ents.Create/FindByClass/FindInSphere`, `scripted_ents.*`, `weapons.Register`, `list.Add/Set`, `properties.Add`, `spawnmenu.*`, `tool.*` |
| UI | `vgui.Create/Register/RegisterFile` (рисование `surface.*`/`render.*`/`draw.*`/`input.*`/`cam.*` **разрешено** — нужно для `anim`-callback'ов в скинах) |
| Players | `:Kick`/`:Ban`/`:Kill`/`:StripWeapons`/`:StripAmmo`/`:Give`/`:ConCommand`/`:SendLua`/`:Freeze`/`:Spawn`/`:SetPos`, `player.GetAll`/`GetByID` |
| Meta | `_G[]`, `_G.`, `_ENV`, `getmetatable`, `setmetatable`, `debug.*`, `jit.*`, `rawget/set/equal/len`, `system.*`, `engine.*` |
| Chain | `include()`, `require()`, `module()`, `AddCSLuaFile` |
| Obfuscation | `string.char/byte/rep/dump`, `bit.bxor/lshift/rshift/band/bor` |

**Required markers** (минимум один в файле):
`Metrostroi.Skins`, `Metrostroi.RegisterSkin`, `Metrostroi.DefineSkin`, `Metrostroi.AddSkin`, `Metrostroi.Masks`, `Metrostroi.RegisterMask`, `Metrostroi.AddMask`, `Metrostroi.DefineMask`.

### Слой 7 — Runtime execute-time gate

Даже если GMA-сканер пропустил (например, UGC handle не открылся), **каждый** `.lua` ещё раз проходит `ValidateSkinLua` непосредственно перед `CompileString`. На сервере и на клиенте независимо.

### Бонус — `ReportSkins` guard

Клиент не может добавить в `Metrostroi.Skins`/`Masks` стабы под произвольный wsid: серверный handler принимает только wsid, который уже сидит в активном пайплайне. Левые отчёты пишутся в audit и отбрасываются.

---

## Что считается валидным аддоном

Скин или маска проходят, если выполняются ВСЕ условия:

1. Хотя бы один `.lua` под `lua/metrostroi/skins/` ИЛИ `lua/metrostroi/masks/`.
2. Все остальные `.lua` (если есть) — там же, или они не Lua вообще.
3. Не-Lua файлы только в `materials/`/`models/`/`sound/`/`resource/`/`scripts/`.
4. Никаких файлов в blacklist-папках (см. Слой 2).
5. Расширения только из whitelist (Слой 3).
6. Размеры в рамках лимитов (Слой 4).
7. Каждый addon-`.lua` содержит **хотя бы один** required marker (Слой 6).
8. Каждый addon-`.lua` **не содержит** ни одного запрещённого паттерна (Слой 6).

Легаси-аддоны с регистратором в `lua/autorun/` начиная с этой версии **не поддерживаются** — путь блокируется как опасный. Если у тебя есть такие — переложи регистрацию в `lua/metrostroi/skins/`.

---

## Локализация (en / ru / da)

`Trainfitter.L(key, ...)` (в `sh_lang.lua`) возвращает строку из словаря текущего языка с подстановкой через `string.format`. Язык клиента — `trainfitter_lang` (`FCVAR_ARCHIVE + FCVAR_USERINFO` не ставится — это локальная клиентская преференция).

```lua
chat.AddText(Trainfitter.L("ready", "MyTrain"))    -- "Готово: MyTrain" / "Ready: MyTrain" / "Klar: MyTrain"
```

Переключение в UI: вкладка Настройки → дропдаун `Язык` / `Language` / `Sprog`. После смены меню перезапускается, чтобы перерендериться на новой локали.

Сервер всегда отдаёт `NET.Notify` на английском (он не знает язык каждого игрока). Локализованы только клиентские строки и UI.

Чтобы добавить новый язык: добавить поле `Trainfitter.Lang.<code>` с тем же набором ключей, что в `Trainfitter.Lang.en`, и дописать `code` в `Trainfitter.SupportedLanguages`.

---

## Как написать свой скин или маску

### Скин

Положи в `addon/lua/metrostroi/skins/my_skin.lua`:

```lua
Metrostroi.AddSkin("train", "my_author.my_skin_name", {
    name = "Красный экспресс",
    typ = "81-717",
    textures = {
        ["head"] = "models/my_author/my_skin/head",
        ["hull"] = "models/my_author/my_skin/body",
    },
})
```

Текстуры:
```
addon/materials/models/my_author/my_skin/head.vmt + .vtf
addon/materials/models/my_author/my_skin/body.vmt + .vtf
```

Категории: `train` (кузов), `pass` (пассажирский салон), `cab` (кабина), `765logo` (эмблема на лобовом — для серии 760).

### `anim`-callback для логотипов

```lua
Metrostroi.AddSkin("765logo", "my_logo", {
    typ = "81-760e",
    name = "Моё лого",
    path = "materials/my_author/logos/logo.png",
    anim = function(self, mat, w, h)
        local rot = 360 * (CurTime() % 10) / 10
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawTexturedRectRotated(w / 2, h / 2, w - 32, h - 32, rot)
    end,
})
```

В `anim` доступны `surface.*`, `render.*`, `draw.*`, `input.*`, `cam.*`, `CurTime`, `Material`, `Color` — это разрешённый рендер-API.

### Маска

Положи в `addon/lua/metrostroi/masks/my_mask.lua`:

```lua
Metrostroi.Masks = Metrostroi.Masks or {}
Metrostroi.Masks.front = Metrostroi.Masks.front or {}
Metrostroi.Masks.front["my_author.led_22"] = {
    name = "2-2 LED",
    typ  = "81-717",
    textures = {
        ["mask"] = "models/my_author/masks/led_22",
    },
}
```

Trainfitter диффит `Metrostroi.Masks` так же, как `Metrostroi.Skins`, и при удалении сбрасывает соответствующие NW-ключи на поездах (`MaskTexture`, `RearMaskTexture`).

> Базовый Metrostroi-аддон сейчас не предоставляет публичного `RegisterMask`-API: маски в нём — хардкод трёх вариантов (`MaskType` int + два bool'а). Trainfitter поддерживает `Metrostroi.Masks` как соглашение для community-аддонов; конкретное применение к энтити зависит от того, как сам аддон-маска перехватывает рендер.

---

## Диагностика проблем

### `[Trainfitter] FATAL: gmsv_workshop ...` или `gmsv_workshop missing`

```
] lua_run local ok, err = pcall(require, "workshop") print(ok, err)
```

- `false` + `Couldn't load module` → DLL не той битности. Положи правильную в `garrysmod/lua/bin/`.
- `false` + `module 'workshop' not found` → DLL не в `lua/bin/` или папка не создана.
- `true` + `nil` → DLL загрузилась, но `steamworks.DownloadUGC` всё равно nil — в редких случаях помогает рестарт сервера.

Без этого Trainfitter **отказывается работать** (см. [Требования](#требования)).

### `Server refused to mount <wsid>: ...`

Это не ошибка, это работа сканера. Конкретная причина:

| Сообщение | Что значит |
|---|---|
| `file in unsupported folder: '…'` | Не-Lua файл вне разрешённых папок |
| `disallowed file type: …` | Запрещённое расширение |
| `blocked path: … (bad token '…')` | Файл в blacklist-папке (`lua/weapons/`, `bin/`, …) |
| `forbidden API in skin file …: …` | Запрещённый API в Lua (см. Слой 6) |
| `missing Metrostroi.Skins/Metrostroi.Masks registration` | Файл в нужной папке, но без required marker'а |
| `not a Metrostroi train addon (…)` | В GMA нет ни одного файла под `lua/metrostroi/skins/` или `lua/metrostroi/masks/` |
| `addon lua file too large` | Превышен `MAX_LUA_FILE_SIZE` (64 КБ) |

### Скин скачался, но не применяется

```
] lua_run print(Metrostroi.Skins.train and Metrostroi.Skins.train["имя_скина"])
```

- `nil` на сервере → скин-файл не выполнил регистрацию. Ищи `[Trainfitter] Server mounted <wsid>: N skin scripts executed` — если N=0, файл не скомпилился, см. лог.
- `table` на сервере, `nil` на клиенте → проблема с клиентским скачиванием. Открой клиентскую консоль, проверь `Trainfitter.Mounted[wsid]`.
- Везде `table`, но скин не выбирается → проверь имя в дропдауне Metrostroi: оно должно совпадать ровно с ключом в `textures`.

### Скин меняет только часть кузова

Это не проблема Trainfitter. Ключи `textures = {...}` должны соответствовать sub-material'ам конкретной модели Metrostroi (`head`, `hull`, `hull_761e`, ...). Если автор скина пропустил часть — она остаётся дефолтной. Это вопрос к автору скина.

### Persistent-скин падает на каждом рестарте

Возможно, Workshop удалил аддон или сделал приватным:

```
] lua_run steamworks.FileInfo("ВАШ_WSID", function(i) PrintTable(i or {not_found=true}) end)
```

Если `not_found=true` — `trainfitter_remove ВАШ_WSID`.

### Steam UGC-кеш битый

`trainfitter_cache_clear` чистит только унаследованную HTTP-папку. Steam-кеш живёт в `<srcds>/steamapps/workshop/content/4000/`:

```
rm -rf steamapps/workshop/content/4000/<wsid>/
```

Steam перекачает при следующем `DownloadUGC`.

### Игра крашится после маунта

С 2.1.1 убран `RemoveCSEnts` из hot-reload — это была главная причина крашей. Если краш всё ещё возникает — проверь, что у тебя актуальный `cl_trainfitter.lua` (`Trainfitter.Version == "2.1.1"` или новее) и `Trainfitter.ReloadAllTrains` не содержит вызовов `RemoveCSEnts`.

### `about to perform blocking dns call from the main thread`

Premount теперь отложен через `InitPostEntity` + `timer.Simple(3, …)`. Если видишь — у тебя устаревший `sv_trainfitter.lua`.

### Firewall / прокси

Нужны исходящие TCP 443 → `api.steampowered.com`, `*.steamcontent.com`, Steam CDN (`steamusercontent.com`, `*.akamaized.net`). Steam CDN не любит прокси, за корпоративным может не работать.

---

## Обновление и удаление

### Обновление

`data/trainfitter/*.json` и `audit.log*` — пользовательские, переживают обновление. `addons/trainfitter/` целиком замени:

```
rm -rf <srcds>/garrysmod/addons/trainfitter
cp -r <new>/trainfitter <srcds>/garrysmod/addons/
```

Перезапусти сервер. На первом старте `SweepLegacyHttpCache` подчистит `data/trainfitter/gmas/`, если переходишь с <2.1.1.

### Удаление

```
rm -rf <srcds>/garrysmod/addons/trainfitter
rm -rf <srcds>/garrysmod/data/trainfitter
rm <srcds>/garrysmod/lua/bin/gmsv_workshop_*.dll   # только если другие аддоны не используют
```

---

## Известные ограничения

- `steamworks.DownloadUGC` не отдаёт прогресс в %. Показываем `start` / `progress` (бесконечная анимация в `notification.AddProgress`) / `ok` / `fail`.
- Первый `MountGMA` большого архива даёт engine-фриз 1–3 сек. Это ограничение Source, обойти нельзя.
- Маски в базовом Metrostroi — хардкод (см. секцию выше). Trainfitter их доставляет, но как они отрендерятся на поезде — на совести самого аддона.
- Hot-reload только soft (без `RemoveCSEnts`). Если визуально не подхватилось — респавн поезда даст чистый результат.
- На UGC-handles `ReadString` иногда отсутствует. Сканер фолбэчится на byte-by-byte чтение.

---

## История версий

### 2.2.2

- **Auto-cleanup на смене карты.** Раньше lua-стейт srcds переживал map change → таблицы Trainfitter (`MountedServer`, `SessionBroadcast`, `SkinOwnership`, `ActiveSkin`) и сами VFS-маунты GMA не сбрасывались, и не-persistent скины игроков «висели» бесконечно. Теперь хук `InitPostEntity` (фактически = каждая смена карты) вызывает `Trainfitter.ForgetNonPersistent`:
  1. Собирает все wsid из `MountedServer/SessionBroadcast/SkinOwnership`, кроме тех, что в `persistent.json`.
  2. Делает `BroadcastForget` для каждого → клиенты сбрасывают NW-строки, чистят `Metrostroi.Skins/Masks` стабы.
  3. Сбрасывает `ActiveSkin` если он не в persistent.
  4. Удаляет соответствующие GMA-файлы из `data/trainfitter/gmas/` через `PruneNonPersistentCache`.
  Persistent скины остаются и пере-маунтятся через 3с.
- **Команда `trainfitter_purge_all`** (`Manage`). Полная очистка: `persistent.json` → пусто, ActiveSkin → nil, всё in-memory state → пусто, broadcast forget всем wsid'ам, **весь** `data/trainfitter/gmas/` удаляется. После выполнения — на сервере не остаётся ни одного скина. Использовать когда нужно вернуть Trainfitter в нулевое состояние.
- **Команда `trainfitter_forget_all`** (`Manage`). Мягче `purge_all`: forget'ит только не-persistent. Persistent (избранное) остаётся.

### 2.2.1

**Безопасность**

- **Subscribe rate-limit.** `Trainfitter.Subscribe` теперь не подписывает на один и тот же wsid чаще одного раза в 60 с (`subscribeCooldown` таблица). Защита от спама `steamworks.Subscribe` если игрок жмёт Apply много раз подряд.
- **Convar `trainfitter_auto_subscribe`** (default `1`, client). Игрок может выключить авто-подписку — Steam-библиотека не будет засоряться.
- **Skip auto-Subscribe на dedicated.** Подписка на dedicated client'е не помогает серверу (у сервера своя `engine.GetAddons()`), только засоряет личную библиотеку. Поэтому `Trainfitter.Subscribe` теперь возвращает false если `game.IsDedicated()`. На listen / SP — работает.
- **Server-side mount watchdog.** `processServerMountQueue` ставит `timer.Create(SERVER_MOUNT_TIMEOUT=90s)` на каждый запуск. Если callback от `DownloadUGC` или `HttpFetchGMA` не пришёл — таймер форсит `finalize(false)` и освобождает `serverMountInFlight`, чтобы очередь не залипала.
- **HTTP body size guard.** `HttpFetchGMA` теперь проверяет `#gmaBody > maxBytes` (max_mb × 1MB) ДО `file.Write`. Защита от DoS заполнением диска через подменённый `file_url`.

**Дизайн**

Полный пасс по UI на гармоничность. Всё, что работало — оставлено. Изменения чисто визуальные:

- **Палитра** перестроена: `bg`/`bg_panel`/`bg_item`/`bg_hover` теперь холоднее и контрастнее, добавлены `border_soft`, `text_dim`, `warn`, `accent_hi`, `danger_bg`/`danger_hi`, `shadow`. `accent_bg` оставлен — но кнопки используют градиент-имитацию через `accent_hi` на hover.
- **Шрифты**: H1 24/700, H2 17/600, добавлены `BodyB` (14/600 жирный) и `Caption` (11). Иерархия читается лучше.
- **Кнопки**:
  - `MakeAccentButton` — закругление 8px, на hover светлеет до `accent_hi` + добавляется верхний highlight как у glass-buttons.
  - `MakeFlatButton` — закругление 6px, тонкая accent-обводка на hover.
  - **Новая** `MakeDangerButton` (red) — для деструктивных действий (удалить и т.п.).
  - `MakeCloseButton` плавно переходит в красный на hover вместо просто яркого серого.
- **NavItem** — высота 42px, активный пункт имеет белую полоску слева (анимированную) + плавный переход цвета через `activeFrac` Lerp.
- **Карточки истории** — закругление 8px, accent-обводка на hover, статус-полоска чуть нежнее, отступы между ними 8px (было 6).
- **Preview панель** — внутренние отступы +2, тонкая `border_soft` обводка.
- **Текстовые поля** — accent-обводка при фокусе.
- **Главное окно** — закругление 10px, тонкая `border_soft` рамка по периметру, шапка стала +4px.
- **Nav-боковая панель** — закругление 10px + бордер.
- **Все строки настроек/скинов** — закругление 8px.

### 2.2.0

- **Install: явная кнопка «В избранное».** Рядом с «Подтвердить» теперь зелёная кнопка с иконкой звезды. Если wsid уже в favorites — текст меняется на «В избранном» и клик удаляет из persistent. Чекбокс «Сделать постоянным» оставлен для совместимости.
- **Переключатель языка перенесён в шапку меню.** Был внутри Настроек (доступных только админам), теперь — в верхнем баре справа от логотипа, виден всем. После смены меню перезапускается.
- **Settings tab: жёсткая защита от утечки.** При открытии меню `Trainfitter.AdminConfig` сбрасывается в nil, чтобы кеш с прошлой сессии не показывал вкладку игроку, который сейчас не админ. RefreshAdminVis оставляет вкладку скрытой пока сервер не подтвердит canManage.
- **Уведомление в чат при смене серверных настроек.** На каждый успешный `NET.AdminSetConVar` сервер шлёт `Notify` всем игрокам (`[Trainfitter] %s изменил %s = %s`). Через `notification.AddLegacy` на клиенте.
- **ULX-интеграция.** На server-side регистрируются три access-ключа через `ULib.ucl.registerAccess` с дефолтными уровнями `ACCESS_ALL` / `ACCESS_ADMIN` / `ACCESS_SUPERADMIN`. Появляются в XGUI → можно выдавать конкретным группам или отзывать у superadmin. `CheckPrivilege` теперь спрашивает ULX через `ULib.ucl.query` после LFAdmin и до vanilla-fallback.
- **LFAdmin: ramzi/superadmin всегда проходят.** `IsRamziLike` теперь короткозамыкает на `IsSuperAdmin` **только если LFAdmin загружен**. Без LFAdmin (например ULX-only сервер) superadmin идёт через стандартный путь и подчиняется ULX-правилам.
- **История теперь сохраняется на диск.** `data/trainfitter/client_history.json` — клиентский файл, переживает рестарт игры. Емкость 100 записей. Хук `Trainfitter.HistoryUpdated` для перерисовки.
- **Тайное поле `apiSource` в записи истории.** Каждая запись хранит каким путём был получен GMA: `steamworks_native`, `shared_cache` (с listen-серверного HTTP-кеша), и т.д. UI это поле не показывает — только сам файл. Для аудита когда что-то идёт не так.
- **Кнопка «Убрать из истории»** на каждой карточке + кнопка **«Очистить историю»** в шапке вкладки с подтверждением через Derma_Query.
- **Оптимизация лагов при применении скина.** `Trainfitter.ReloadAllTrains` больше не итерирует все составы синхронно за один кадр. Теперь:
  - `CollectSubwayTrains` собирает целевой список (быстрая итерация без `UpdateTextures`)
  - `timer.Create(0.05s, 0, ...)` обрабатывает `RELOAD_BATCH = 4` поезда за тик
  - На сервере с десятком составов лаг при Apply исчезает — нагрузка размазана на ~1с

### 2.1.6

- **Решение для свежих Workshop-аддонов на listen-server.** `steamworks.Download(hcontent)` оказался client-only и не работает на сервере, поэтому фолбэк через hcontent не срабатывал. Заменён на цепочку: после неудачного `file_url` проверяется `engine.GetAddons()` (через хелпер `FindSubscribedAddonPath`) — если игрок уже подписан на аддон в Steam (через DHTML-браузер или вручную), его файл монтируется напрямую. Если не подписан — сервер вызывает `steamworks.Subscribe(wsid)` (если функция доступна) и таймером ждёт до 60 с пока Steam-клиент скачает; после появления файла монтирует.
- **Авто-подписка на клиенте.** Все клиентские вызовы (Apply в Install/Favorites/History/Browser) теперь автоматически дёргают `steamworks.Subscribe(wsid)` через хелпер `Trainfitter.Subscribe`, встроенный в `Trainfitter.Request`. Steam-клиент начинает качать в `steamapps/workshop/content/4000/<wsid>/<file>.gma`, сервер подбирает файл через `engine.GetAddons()` без `DownloadUGC`.

### 2.1.5

- **Steam перестал отдавать `file_url` для свежих Workshop-аддонов.** Для аддонов после ~2018 публичный `ISteamRemoteStorage/GetPublishedFileDetails/v1/` возвращает `file_url=""`, есть только `hcontent_file`. Раньше HTTP-fetch падал с `no file_url in Steam response` для таких аддонов. Теперь `HttpFetchGMA` использует резервный путь: `steamworks.Download(hcontent_file, false, callback)` (другая нативная ветка, не падает там, где `DownloadUGC` крашит) и обёрнута в `timer.Simple(0, ...)` + `pcall`.
- **Клиент шарит серверный HTTP-кеш на listen-server.** На локалке клиент-сторона больше не дёргает `steamworks.DownloadUGC` (которая крашит на x64), а сначала проверяет `data/trainfitter/gmas/<wsid>.gma` — серверная сторона того же процесса уже скачала туда GMA. Если файл есть → клиент монтирует напрямую и исполняет skin/mask Lua. Если нет (dedicated/чужой клиент) — fallback на native `steamworks.DownloadUGC` с `pcall + timer.Simple(0,...)`.
- **`SafeFetchWorkshopInfo`** теперь возвращает `file_url` и `hcontent_file` в info-таблице — больше не нужен повторный `http.Post` внутри `HttpFetchGMA`.

### 2.1.4

- **Авто-выбор пути загрузки.** `ShouldUseHttp()` теперь возвращает `true` если: convar `trainfitter_use_http=1` (принудительно), ИЛИ `gmsv_workshop` не загружен, ИЛИ `not game.IsDedicated()` (listen-server/single-player). На dedicated x32 srcds с gmsv_workshop — нативный путь по-прежнему. Юзеру ничего вручную включать не надо: на локалке HTTP-fetch автоматически, на боевом сервере — native.
- **Тихий boot.** `require("workshop")` больше не зовётся, если бинарного модуля нет — сначала проверяется `util.IsBinaryModuleInstalled("workshop")`. Шумный warning `Couldn't include file 'includes/modules/workshop.lua'` исчез.
- **Чистка мёртвых проверок.** `HandleRequest` / `processServerMountQueue` / `ServerMountPersistent` больше не делают `not ServerHasSteamworks() and not ShouldUseHttp()` — после нового `ShouldUseHttp` это всегда `false`. `BuildServerIssues` теперь предупреждает только о реально проблемном случае (dedicated без gmsv_workshop).

### 2.1.3

- **Опт-ин HTTP-загрузка GMA.** Конвар `trainfitter_use_http` (default `0`). Когда `1` — Trainfitter обходит native `steamworks.DownloadUGC` и качает GMA через `ISteamRemoteStorage/GetPublishedFileDetails/v1/` + `http.Fetch`. Это медленнее, но не крашится на x64 GMod, где native `DownloadUGC` иногда падает в `[C]:-1`. На срчдс с `gmsv_workshop` под x32 оставлять `0` — нативный путь быстрее.
- **Защита нативного DownloadUGC.** Вызов `steamworks.DownloadUGC` теперь обёрнут в `timer.Simple(0, ...)` + `pcall` — снимает stack-reentrancy между `http.Post`-callback'ом из `SafeFetchWorkshopInfo` и нативным download. Лечит часть крашей на x64.
- **HTTP-кеш возвращён.** `data/trainfitter/gmas/<wsid>.gma` снова используется в HTTP-режиме. На boot — `SweepStaleGMACache` (старше 30 дней или меньше 1 КБ → удаляются). При scanner reject / MountGMA fail — `InvalidateGMACache` чистит битый файл, чтобы следующий запрос перекачал. `trainfitter_cache_clear` вернулся к работе с активным кешем.
- **`BuildServerIssues`** теперь различает три состояния: `gmsv_workshop` есть → ОК; нет, но `use_http=1` → жёлтое предупреждение; нет и `use_http=0` → красная ошибка.

### 2.1.2

- **Фикс краша на Apply.** `steamworks.FileInfo` периодически крашил процесс gmod (`[C]:-1` фрейм, panic вне Lua) — это известный баг нативного bindings'а в `gmsv_workshop`. Заменён на безопасный `Trainfitter.SafeFetchWorkshopInfo` поверх `http.Post` к `ISteamRemoteStorage/GetPublishedFileDetails/v1/`. Используется и сервером в `HandleRequest`, и клиентом в превью UI / post-mount info. Скачивание GMA по-прежнему через `steamworks.DownloadUGC` (никакого HTTP-фолбэка для самого GMA).
- **Shared-хелперы.** `Trainfitter.IsValidWSID` и `Trainfitter.SafeFetchWorkshopInfo` переехали в `sh_config.lua` — единая реализация для server/client.

### 2.1.1

- **gmsv_workshop теперь обязателен.** HTTP-фолбэк (`HttpFetchGMA`, `data/trainfitter/gmas/` как путь записи, `InvalidateGMACache`, `SweepBadGMACache`) удалён. Без него — отказ на запросы, красная плашка в `BuildServerIssues`. `trainfitter_cache_clear` оставлен как одноразовая чистилка унаследованных файлов (теперь дёргает `SweepLegacyHttpCache`).
- **Hot-reload без `RemoveCSEnts`.** Жёсткий ресет CSEnts крашил игру, особенно когда поезд активно рендерится. Остался soft-reload (`Texture/PassTexture/CabinTexture = nil` + `pcall(UpdateTextures)`) с пропуском составов, в которых сидит локальный игрок, и таймером 1 с.

### 2.1.0

- **Маски.** Путь `lua/metrostroi/masks/`, маркеры `Metrostroi.Masks/RegisterMask/AddMask/DefineMask`, owner-таблица различает `kind = "skin" | "mask"`.
- **Точечный hot-reload.** Освежаются только составы инициатора (по `CPPIGetOwner`/`GetCreator`/`ent.Owner`).
- **Уведомления вместо чата.** `notification.AddLegacy` + `AddProgress`.
- **Языки.** `Trainfitter.L`, `trainfitter_lang` (en/ru/da), переключатель в Настройках.
- **Стартовый баннер.** `materials/eye` + версия в консоли.
- **Встроенный браузер Мастерской.** `cl_trainfitter_browser.lua`, концоманда `trainfitter_workshop`, JS-инжекция перехватывает Steam-кнопку Subscribe.
- **Сетевой формат:** `initiatorSid` в `Broadcast`/`ForgetSkin`/`ActiveSkin`, `kind` в `ReportSkins`.

### 2.0.x

- 7-слойный сканер, persistent single-slot, LFAdmin-интеграция, audit-лог, статистика, history, favorites, self-healing.

---

## License / Авторство

**Автор:** SellingVika — `sellingvika@gmail.com`. Сайт: <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika. All rights reserved.
```

### Разрешено

- Использовать на своём сервере.
- Форкать, делать PR, участвовать в разработке.
- Упоминать в обзорах/сборках.
- Распространять оригинал без модификаций (с сохранёнными хедерами `-- Made by SellingVika.` в каждом `.lua`).

### Запрещено

- Удалять или менять хедер `-- Made by SellingVika.`.
- Выдавать аддон за свой / публиковать под другим именем без указания оригинального автора.
- Продавать оригинал или его модификации без письменного разрешения автора.
- Удалять упоминания автора из README, метаданных, UI.

### Форк

1. Сохрани оригинальный хедер в каждом файле.
2. Добавь свой строкой ниже:
   ```lua
   -- Trainfitter — sh_config.lua
   -- Made by SellingVika.
   -- Forked and modified by <ТвоёИмя>.
   ```
3. В README форка укажи ссылку на оригинал и список изменений.
4. Не называй форк «Trainfitter» — выбери производное имя.

### Нарушение атрибуции

Сообщи на `sellingvika@gmail.com` (скриншот + ссылка). Автор вправе потребовать удаления или корректной атрибуции.

### Сторонние зависимости

Используются для работы, **не часть Trainfitter**, имеют свои лицензии:

- [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) (Workshop) / [GitHub](https://github.com/Metrostroi-Team/Metrostroi) — целевая версия Metrostroi, под которую Trainfitter разрабатывается. Категории `train`/`pass`/`cab`/`765logo`, NW-ключи `Texture`/`PassTexture`/`CabTexture`, API `Metrostroi.AddSkin` сверяются именно с ней.
- [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop) by WilliamVenner — серверный `steamworks.DownloadUGC`.

### Заявление об авторстве

Можно разместить на странице Workshop / в описании сервера:

> Powered by **Trainfitter** by SellingVika.

---

**Trainfitter** © 2026 SellingVika. Хедер `-- Made by SellingVika.` — неотъемлемая часть каждого файла.
