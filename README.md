# Trainfitter

> **© SellingVika.** В каждом `.lua`-файле есть хедер `-- Made by SellingVika.` — **удалять запрещено**, аддон при отсутствии тега тупо отказывается работать (см. `sh_integrity.lua`). Хочешь форкнуть — оставь оригинальный тег, допиши свой ниже строкой `-- Forked by ТвоёИмя.`. Подробности — в разделе License.
>
> Документация: [Русский](#русский) / [English](#english) / [Dansk](#dansk).
> Сайт автора: <https://sellingvika.party/>

---

## Русский

Trainfitter — это runtime-загрузчик скинов и масок поездов **Metrostroi Subway Simulator** для Garry's Mod. Игрок открыл UI, кинул ссылку из Workshop (или взял её во встроенном браузере), нажал Apply — и скин уже на сервере, у всех. Никаких ручных подписок, никаких рестартов, никаких "перезалейте коллекцию и перезапустите server.cfg". Всё работает в реалтайме, на живом сервере, во время игры.

При этом аддон закрыт жёстким многоуровневым сканером — игрок может протащить **только настоящие скины и маски Metrostroi**. SWEP-паки, геймоды, карты, аддоны со зловредными `lua/autorun/*.lua` — всё это отвергается ещё до маунта. Подробно про защиту — в разделе [Безопасность](#безопасность).

### Что внутри коротко

- **Один клик — скин на сервере.** Вставил ссылку, или WSID, или просто URL — всё парсится. Нажал Подтвердить — поехали.
- **Кнопка «В избранное».** Скин становится persistent, автомаунтится после рестарта, догоняется новым игрокам.
- **Встроенный браузер Мастерской.** Жмёшь "Открыть Мастерскую" — открывается DHTML-окно прямо в игре. Можно гулять по Steam Workshop как обычно. JS-инжекция переименовывает Steam-кнопку Subscribe в "Select for Trainfitter" — клик прямо на странице мгновенно стартует загрузку.
- **Маски** — `lua/metrostroi/masks/*.lua` поддерживаются параллельно со скинами.
- **Точечный hot-reload.** Только составы инициатора визуально освежаются. Чужие поезда не дёргаются. Если ты в составе сидишь — он тоже не трогается, чтобы рендер не крашнулся.
- **История** скачиваний игрока сохраняется в `data/trainfitter/client_history.json`, переживает рестарт игры. На каждой записи кнопка «Убрать», в шапке вкладки — «Очистить историю».
- **Уведомления вместо чата.** Прогресс, готовность, ошибки — всё через `notification.AddLegacy` + `AddProgress` (с прогресс-полоской). Чат не засоряется ни разу.
- **Три языка**: Русский, English, Dansk. С нарисованными прямо в Lua флагами в дропдауне (никаких внешних PNG).
- **Авто-очистка** на каждой смене карты: всё что не в избранном — забывается, GMA-кеш-файлы удаляются. Persistent остаётся.
- **Listen-server и dedicated** — оба работают. На listen авто-выбирается HTTP-загрузка через Steam-подписку (потому что нативный `steamworks.DownloadUGC` крашит x64-клиент — это известный engine-баг). На dedicated с `gmsv_workshop` идёт нативный путь — быстрее.
- **Integrity check** — на загрузке проверяется наличие тегов `Trainfitter` и `Made by SellingVika` во всех ключевых файлах. Нет тега — `IntegrityFailed = true`, аддон молча отказывается работать. Форкаешь — теги сохраняй, свои добавляй РЯДОМ.
- **Безопасность 7-слойная** (см. ниже).

### Требования

| Сторона | Что нужно |
|---|---|
| Сервер | Garry's Mod Dedicated Server (Win/Linux, 32/64) или listen-сервер |
| Сервер | Metrostroi Subway Simulator ([Workshop 261801217](https://steamcommunity.com/workshop/filedetails/?id=261801217) / [GitHub Metrostroi-Team](https://github.com/Metrostroi-Team/Metrostroi)) |
| Сервер | `gmsv_workshop` DLL в `garrysmod/lua/bin/` — для dedicated. На listen-сервере **не нужен** — Trainfitter сам видит и переключается на HTTP. |
| Сервер | Исходящие TCP 443 → `api.steampowered.com`, `*.steamcontent.com` |
| Клиент | Garry's Mod (Legacy или x86-64) |

LFAdmin / ULX / SAM / любая популярная админка — опционально. Без них работает через стандартные `IsAdmin()` / `IsSuperAdmin()`.

### Установка

1. Скопируй репозиторий целиком в `<srcds>/garrysmod/addons/trainfitter/`. После копирования `addon.json` должен лежать на одном уровне с `lua/`. Двойная вложенность типа `addons/trainfitter/trainfitter/lua/...` — самая частая причина "не работает".
2. **Поставь `gmsv_workshop` DLL** для dedicated. Скачай с [WilliamVenner/gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), положи в `garrysmod/lua/bin/`. Имя файла по битности srcds: `gmsv_workshop_win32.dll` / `_win64.dll` / `_linux.dll` / `_linux64.dll`. На listen-сервере — этот шаг пропускаешь.
3. Запусти сервер. В консоли увидишь:
   ```
   [Trainfitter] gmsv_workshop loaded — server has native steamworks.DownloadUGC.
   Trainfitter v2.2.8 (server)
   ```
   Если видишь `gmsv_workshop binary not installed — using HTTP fetch` — это нормально на listen, ничего делать не надо. На dedicated — это сигнал что DLL не там.
4. Зашёл игроком, открыл UI командой `trainfitter` (или биндом `bind F3 trainfitter`).

### UI: что внутри

- **Установка** — поле для ссылки/WSID, превью с описанием, кнопки **Подтвердить** и **В избранное**. Кнопка "Открыть Мастерскую" поднимает встроенный DHTML-браузер.
- **Избранное** — список persistent-скинов (single-slot модель), Применить / Убрать / Открыть в браузере.
- **История** — карточки текущей сессии, на каждой иконка корзины (убрать запись), в шапке вкладки кнопка «Очистить историю».
- **Настройки** — **только для админов** с правом `Manage`. Для не-админов вкладка вообще не показывается. Серверные конвары меняются на лету, изменение видят все в чате (`[Trainfitter] %s изменил %s = %s`).

В шапке окна — **переключатель языка с флажками** (UK / RU / DK, нарисованы прямо в Lua через `surface.DrawRect`, никаких PNG-ассетов) и **кнопка «Очистить мой кеш»** для всех (стирает локальную историю, превью и закешированные GMA).

### Консольные команды

| Команда | Кому | Что делает |
|---|---|---|
| `trainfitter` | всем (client) | Открыть UI |
| `trainfitter_workshop` | всем (client) | Встроенный браузер Мастерской |
| `trainfitter_client_purge` | всем (client) | Очистить **локальный** кеш — история, превью, GMA-файлы |
| `trainfitter_list` | всем | Показать persistent-список |
| `trainfitter_stats` | всем | Топ-20 скачанных wsid |
| `trainfitter_remove <wsid>` | `Persistent` | Убрать wsid из persistent |
| `trainfitter_reload` | `Persistent` | Перечитать JSON-файлы и пере-маунтить persistent |
| `trainfitter_whitelist_add/remove/list <wsid>` | `Manage` | Управление whitelist |
| `trainfitter_blacklist_add/remove/list <wsid>` | `Manage` | Управление blacklist |
| `trainfitter_cache_clear` | `Manage` | Удалить весь HTTP-кеш `data/trainfitter/gmas/` |
| `trainfitter_forget_all` | `Manage` | Forget всех не-persistent скинов в текущей сессии |
| `trainfitter_purge_all` | `Manage` | **Ядерная очистка** — persistent.json в ноль, весь кеш, весь runtime-state, broadcast forget каждому wsid |
| `trainfitter_audit [N]` | SuperAdmin | Последние N строк audit-лога (default 30, max 500) с резолвом ников |

### ConVar'ы

Серверные (`FCVAR_ARCHIVE`, пишутся в `cfg/server.cfg`):

| ConVar | Default | Что делает |
|---|---|---|
| `trainfitter_max_mb` | 200 | Лимит размера аддона в МБ. Запросы больше — отвергаются ДО скачки. |
| `trainfitter_require_admin` | 0 | `1` = качать может только привилегированный игрок. `0` = все. |
| `trainfitter_request_cooldown` | 2 | Кулдаун между запросами одного игрока (сек) + bandwidth-backoff. |
| `trainfitter_max_persistent` | 1 | Single-slot модель. Больше 1 не имеет смысла. |
| `trainfitter_audit_log` | 1 | Писать в `data/trainfitter/audit.log`. |
| `trainfitter_use_whitelist` | 0 | `1` = разрешены **только** wsid из whitelist.json. |
| `trainfitter_stats_enabled` | 1 | Считать статистику в stats.json. |
| `trainfitter_server_premount` | 1 | Сервер сам маунтит persistent при старте. |
| `trainfitter_use_http` | 0 | `1` = принудительно HTTP. `0` = авто (HTTP на listen, native на dedicated с gmsv_workshop). |

Защитные (`FCVAR_PROTECTED`, **не трогать без понимания**):

- `trainfitter_server_gma_scan` (1) — серверный scan GMA перед `MountGMA`.
- `trainfitter_content_scan` (1) — runtime scan каждого `.lua` перед `CompileString`.
- `trainfitter_gma_scan` (1, client-local) — клиентский scan.

Клиентские:

- `trainfitter_lang` (`ru` / `en` / `da`) — язык UI.
- `trainfitter_auto_subscribe` (1) — авто-подписка через Steam при Apply (только на listen). `0` — подписки не будет, скин может не скачаться для свежих Workshop-аддонов.

### Права

Trainfitter спрашивает права в **четыре уровня по очереди**, первый сработавший — ответ:

1. **Ramzi short-circuit** — если `ply:IsRamzi() == true` (LFAdmin-группы `ramzi/meow/rawr/licen`) → всегда true.
2. **LFAdmin** — для каждого access-ключа (`trainfitter_download` `v` / `_persistent` `a` / `_manage` `s`). Если LFAdmin загружен и игрок — superadmin → тоже всегда true (отозвать можно только удалив LFAdmin).
3. **ULX** — `ULib.ucl.query(ply, accessName)`. Регистрируются с дефолтами `ACCESS_ALL` / `ACCESS_ADMIN` / `ACCESS_SUPERADMIN`. **Появляются в XGUI** — можно выдавать конкретным группам или **отзывать у superadmin**.
4. **Fallback** — `IsAdmin()` / `IsSuperAdmin()`. Работает с любой админкой, которая override'ит эти методы (это все популярные).

При изменении любой настройки — **broadcast в чат всем игрокам**: `[Trainfitter] %s изменил %s = %s`.

### Безопасность

Семь независимых слоёв сканера + integrity check сверху. Чтобы протащить произвольный аддон, нужно пробить ВСЕ слои разом:

- **Path whitelist**: Lua **только** в `lua/metrostroi/skins/` или `lua/metrostroi/masks/`. Всё остальное в `lua/autorun/`, `lua/weapons/`, `lua/entities/`, `gamemodes/`, `bin/`, `data/` — отказ всему GMA. Файлы данных только под `materials/`, `models/`, `sound/`, `resource/`, `scripts/`.
- **Extension whitelist**: `.lua .vmt .vtf .png .jpg .mdl .vvd .phy .vtx .ani .wav .mp3 .ogg .ttf .otf .txt .md .json .pcf` — и всё. `.exe`, `.dll`, `.bat`, `.so`, `.py` — отказ.
- **Size caps**: 256 МБ на файл, **64 КБ на addon-`.lua`** (tight cap), 1 ГБ суммарно, 4096 файлов всего, 256 lua-файлов.
- **Marker requirement**: должен быть хотя бы один `lua/metrostroi/{skins,masks}/*.lua` с тегом регистрации (`Metrostroi.AddSkin`/`RegisterSkin`/`AddMask` и т.п.).
- **Lua content scanner** — каждый `.lua` нормализуется (выкидываются комментарии и литералы строк) и проверяется по ~80 паттернам: `RunString`, `http.*`, `file.Write`, `hook.*`, `timer.*`, `net.*`, `ents.Create`, `package.*`, `_G.*`, `debug.*`, `os.execute`, `:Kick/Ban/Kill`, `vgui.Create`, `bit.*`, `string.char/byte/rep`. Один матч → отказ всему GMA.
- **Runtime gate** — даже если scan был пропущен, перед `CompileString` каждый файл ещё раз проходит `ValidateSkinLua`.
- **Integrity check** (`sh_integrity.lua`) — на загрузке проверяет, что во всех 11 ключевых файлах есть теги `Trainfitter` И `Made by SellingVika`. Нет хотя бы одного — `IntegrityFailed = true`, и `HandleRequest` / `Trainfitter.Request` / `ServerMountPersistent` тихо отказываются работать. Хочешь форкать — оставь оригинальный тег, добавь свой ниже.
- **Rate limits и length caps** на всех NET-handler'ах. `ReportSkins` принимает только wsid, который уже в активном пайплайне.

Дополнительно:

- **Auto-subscribe rate-limit**: 60с на один и тот же wsid, чтобы Apply-спам не засорял Steam-библиотеку игрока.
- **Mount queue watchdog**: 90с timeout на каждый запуск, очередь не залипает если callback не пришёл.
- **HTTP body size guard**: проверка `#body > maxBytes` ДО `file.Write`, защита от DoS подменой `file_url`.

### Как написать свой скин

Минимальный пример, кладёшь в `addon/lua/metrostroi/skins/my_skin.lua`:

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

Категории Metrostroi: `train` (кузов), `pass` (пассажирский салон), `cab` (кабина машиниста), `765logo` (эмблема для серии 760).

Текстуры — в `addon/materials/models/my_author/my_skin/*.vmt + .vtf`.

Маска — то же самое, но в `lua/metrostroi/masks/*.lua` через таблицу `Metrostroi.Masks` (стандартный Metrostroi её не предоставляет — это convention для community-аддонов, Trainfitter её просто доставляет).

### Файлы данных

Серверные — в `<srcds>/garrysmod/data/trainfitter/`:

- `persistent.json` — массив активного wsid (single-slot)
- `whitelist.json` / `blacklist.json` — управляемые списки wsid
- `stats.json` — счётчик скачиваний
- `nicks.json` — кеш ников для audit-вывода
- `audit.log` (+ `.old`) — аудит с SteamID64 (не ник, защита от log injection через смену ника), ротация при 1 МБ
- `gmas/<wsid>.gma` — HTTP-кеш скачанных GMA. Авто-чистка не-persistent на каждой смене карты.

Клиентские — в той же папке, но на стороне игрока:

- `client_history.json` — история скачиваний игрока. Содержит **тайное поле `apiSource`** в каждой записи (как был получен GMA: `steamworks_native` / `shared_cache` и т.п.) — в UI это поле НЕ показывается, но в файле есть для аудита.
- `previews/<wsid>.png` — кеш превью

### Диагностика

Если что-то не работает — открывай консоль. Trainfitter всегда префиксует свои сообщения `[Trainfitter]`. Самые частые:

- **`INTEGRITY FAIL`** — кто-то стёр хедеры. Восстанови оригинальные файлы.
- **`gmsv_workshop binary not installed — using HTTP fetch`** — нормально на listen, на dedicated установи DLL.
- **`Server refused to mount <wsid>: ...`** — это не баг, это работа сканера, причина указана.
- **`Cannot mount <wsid>: gmsv_workshop missing and trainfitter_use_http=0`** — поставь либо DLL, либо `trainfitter_use_http 1`.
- **`no file_url in Steam response`** — старые Workshop-аддоны больше не имеют публичного file_url, нужна Steam-подписка (Trainfitter делает её сам если на listen).
- **Краш на Apply x64** — это нативный баг `steamworks.DownloadUGC`. На listen Trainfitter авто-уходит в HTTP, на dedicated `gmsv_workshop` обязателен.

### License / Авторство

**Автор:** SellingVika — `sellingvika@gmail.com`. Сайт: <https://sellingvika.party/>.

```
Copyright (c) SellingVika. All rights reserved.
```

**Разрешено:** Использовать на своём сервере. Форкать, делать PR, участвовать в разработке. Упоминать в обзорах / сборках.

**Запрещено:** Удалять или менять хедер `-- Made by SellingVika.` ни в одном файле — иначе integrity check выключит аддон при загрузке. Выдавать аддон за свой / публиковать под другим именем без указания оригинального автора. Продавать оригинал или модификации без письменного разрешения.

**Форкаешь?** Сохрани оригинальный хедер, добавь свой строкой ниже:

```lua
-- Trainfitter — sh_config.lua
-- Made by SellingVika.
-- Forked and modified by ТвоёИмя.
```

Назови форк производным именем (не "Trainfitter") чтобы не путать пользователей.

**Зависимости** (имеют свои лицензии, не часть Trainfitter):

- [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) — куда ставятся скины.
- [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop) — серверный `steamworks.DownloadUGC`.

---

## English

Trainfitter is a runtime loader for Metrostroi Subway Simulator train skins and masks in Garry's Mod. The player opens the UI, drops in a Workshop link (or grabs one in the embedded browser), hits Apply — and the skin is on the server, for everyone. No manual subscriptions, no restarts, no "re-upload the collection and reboot server.cfg" dance. It all runs on a live server, in real time, while everyone keeps playing.

The addon is locked down by a strict multi-layer scanner — players can only push **real Metrostroi skins and masks** through. SWEP packs, gamemodes, maps, anything sneaky with `lua/autorun/*.lua` is rejected before the mount even happens. Details in the [Security](#security) section.

### Features at a glance

- **One click and the skin is live.** Paste a link (or WSID, or URL — all parsed). Confirm. Done.
- **"Add to favorites" button.** Skin becomes persistent — auto-mounts after server restart, gets pushed to new joiners.
- **Embedded Workshop browser.** Hit "Open Workshop" — a DHTML window opens inside the game. Browse Steam Workshop normally. JS injection renames Steam's Subscribe button into "Select for Trainfitter" — a click on the page itself fires the install instantly.
- **Masks** — `lua/metrostroi/masks/*.lua` supported alongside skins.
- **Targeted hot-reload.** Only the initiator's trains visually refresh. Other players' trains are not touched. If you're sitting in a train, it's also skipped — protects the renderer from crashes.
- **History** is persisted to `data/trainfitter/client_history.json`, survives game restart. Every entry has a delete button; the tab header has "Clear history".
- **Notifications instead of chat.** Progress, ready, errors — all via `notification.AddLegacy` + `AddProgress` (with progress bar). Chat stays clean.
- **Three languages**: English, Русский, Dansk. With flags painted in pure Lua in the dropdown (no external PNGs).
- **Auto-cleanup** on every map change: anything not in favorites — forgotten, GMA cache files deleted. Persistent stays.
- **Listen-server and dedicated** both work. On listen, HTTP loading via Steam subscription is auto-selected (because native `steamworks.DownloadUGC` crashes the x64 client — known engine bug). On dedicated with `gmsv_workshop`, the native path is used — faster.
- **Integrity check** — on load verifies that all key files contain `Trainfitter` and `Made by SellingVika` tags. Tag missing → `IntegrityFailed = true`, addon silently refuses to operate. Forking? Keep the original tag, add your own one NEXT to it.
- **7-layer security** (see below).

### Requirements

| Side | Needed |
|---|---|
| Server | Garry's Mod Dedicated Server (Win/Linux, 32/64) or listen-server |
| Server | Metrostroi Subway Simulator ([Workshop 261801217](https://steamcommunity.com/workshop/filedetails/?id=261801217) / [GitHub Metrostroi-Team](https://github.com/Metrostroi-Team/Metrostroi)) |
| Server | `gmsv_workshop` DLL in `garrysmod/lua/bin/` for dedicated. **Not needed on listen** — Trainfitter detects and switches to HTTP. |
| Server | Outbound TCP 443 → `api.steampowered.com`, `*.steamcontent.com` |
| Client | Garry's Mod (Legacy or x86-64) |

LFAdmin / ULX / SAM / any popular admin mod — optional. Without them works through standard `IsAdmin()` / `IsSuperAdmin()`.

### Installation

1. Copy the repo into `<srcds>/garrysmod/addons/trainfitter/`. After copying, `addon.json` must sit at the same level as `lua/`. Double nesting like `addons/trainfitter/trainfitter/lua/...` is the most common reason for "doesn't work".
2. **Install `gmsv_workshop` DLL** for dedicated. Download from [WilliamVenner/gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), drop into `garrysmod/lua/bin/`. Filename matches srcds bitness: `_win32.dll` / `_win64.dll` / `_linux.dll` / `_linux64.dll`. On listen — skip this step.
3. Start the server. Console should show:
   ```
   [Trainfitter] gmsv_workshop loaded — server has native steamworks.DownloadUGC.
   Trainfitter v2.2.8 (server)
   ```
   `gmsv_workshop binary not installed — using HTTP fetch` — normal on listen, do nothing. On dedicated — sign that the DLL isn't there.
4. Connect as a player, open the UI with `trainfitter` (or bind `bind F3 trainfitter`).

### UI

- **Install** — link/WSID field, preview with description, **Confirm** and **Add to favorites** buttons. "Open Workshop" — embedded browser.
- **Favorites** — persistent skin list (single-slot), Apply / Remove / Open in browser.
- **History** — current-session cards, delete-bin icon on each, "Clear history" button in the tab header.
- **Settings** — **admin-only** (`Manage` privilege). Hidden completely for non-admins. Server convars edited live, every player sees the change in chat.

Top bar of the window — **language picker with flags** (UK / RU / DK painted in pure Lua, no PNG assets) and **"Purge my cache" button** for everyone (wipes local history, previews, GMA cache).

### Console commands

| Command | Who | What it does |
|---|---|---|
| `trainfitter` | everyone (client) | Open UI |
| `trainfitter_workshop` | everyone (client) | Embedded Workshop browser |
| `trainfitter_client_purge` | everyone (client) | Wipe **local** cache — history, previews, GMA files |
| `trainfitter_list` | everyone | Show persistent list |
| `trainfitter_stats` | everyone | Top-20 downloaded wsids |
| `trainfitter_remove <wsid>` | `Persistent` | Remove wsid from persistent |
| `trainfitter_reload` | `Persistent` | Reload JSON files and re-mount persistent |
| `trainfitter_whitelist_add/remove/list <wsid>` | `Manage` | Whitelist control |
| `trainfitter_blacklist_add/remove/list <wsid>` | `Manage` | Blacklist control |
| `trainfitter_cache_clear` | `Manage` | Delete entire HTTP cache `data/trainfitter/gmas/` |
| `trainfitter_forget_all` | `Manage` | Forget all non-persistent skins in current session |
| `trainfitter_purge_all` | `Manage` | **Nuclear wipe** — persistent.json zeroed, all cache, all runtime state, broadcast forget per wsid |
| `trainfitter_audit [N]` | SuperAdmin | Last N audit lines (default 30, max 500) with nick resolution |

### ConVars

Server-side (`FCVAR_ARCHIVE`):

| ConVar | Default | What it does |
|---|---|---|
| `trainfitter_max_mb` | 200 | Addon size limit MB. Larger requests rejected BEFORE download. |
| `trainfitter_require_admin` | 0 | `1` = only privileged players can download. `0` = anyone. |
| `trainfitter_request_cooldown` | 2 | Cooldown between requests from the same player (sec) + bandwidth backoff. |
| `trainfitter_max_persistent` | 1 | Single-slot model. Values > 1 are pointless. |
| `trainfitter_audit_log` | 1 | Write to `data/trainfitter/audit.log`. |
| `trainfitter_use_whitelist` | 0 | `1` = only wsids from whitelist.json are allowed. |
| `trainfitter_stats_enabled` | 1 | Track stats in stats.json. |
| `trainfitter_server_premount` | 1 | Server pre-mounts persistent on startup. |
| `trainfitter_use_http` | 0 | `1` = force HTTP. `0` = auto (HTTP on listen, native on dedicated with gmsv_workshop). |

Protected (`FCVAR_PROTECTED`, **don't touch unless you know what you're doing**):

- `trainfitter_server_gma_scan` (1) — server-side GMA scan before `MountGMA`.
- `trainfitter_content_scan` (1) — runtime scan of each `.lua` before `CompileString`.
- `trainfitter_gma_scan` (1, client-local) — client scan.

Client-side:

- `trainfitter_lang` (`ru` / `en` / `da`) — UI language.
- `trainfitter_auto_subscribe` (1) — auto-subscribe via Steam on Apply (listen-server only). `0` = no subscription, recent Workshop addons might not download.

### Permissions

Trainfitter checks privileges in **four levels in order**, first hit wins:

1. **Ramzi short-circuit** — if `ply:IsRamzi() == true` (LFAdmin groups `ramzi/meow/rawr/licen`) → always true.
2. **LFAdmin** — for each access key (`trainfitter_download` `v` / `_persistent` `a` / `_manage` `s`). If LFAdmin loaded and player is superadmin → also always true (revoke only by removing LFAdmin).
3. **ULX** — `ULib.ucl.query(ply, accessName)`. Registered with defaults `ACCESS_ALL` / `ACCESS_ADMIN` / `ACCESS_SUPERADMIN`. **Show up in XGUI** — can be granted to specific groups or **revoked from superadmin**.
4. **Fallback** — `IsAdmin()` / `IsSuperAdmin()`. Works with any admin mod that overrides these (every popular one does).

When any setting changes — **chat broadcast to all players**: `[Trainfitter] %s changed %s = %s`.

### Security

Seven independent scanner layers + integrity check on top. To push an arbitrary addon you'd need to break ALL of them at once:

- **Path whitelist**: Lua **only** in `lua/metrostroi/skins/` or `lua/metrostroi/masks/`. Everything else in `lua/autorun/`, `lua/weapons/`, `lua/entities/`, `gamemodes/`, `bin/`, `data/` → reject the whole GMA. Data files only under `materials/`, `models/`, `sound/`, `resource/`, `scripts/`.
- **Extension whitelist**: `.lua .vmt .vtf .png .jpg .mdl .vvd .phy .vtx .ani .wav .mp3 .ogg .ttf .otf .txt .md .json .pcf` — that's it. `.exe`, `.dll`, `.bat`, `.so`, `.py` → reject.
- **Size caps**: 256 MB per file, **64 KB per addon-`.lua`** (tight cap), 1 GB total, 4096 files total, 256 lua files.
- **Marker requirement**: at least one `lua/metrostroi/{skins,masks}/*.lua` with a registration tag (`Metrostroi.AddSkin`/`RegisterSkin`/`AddMask`/...).
- **Lua content scanner** — every `.lua` is normalized (comments and string literals stripped) and checked against ~80 patterns: `RunString`, `http.*`, `file.Write`, `hook.*`, `timer.*`, `net.*`, `ents.Create`, `package.*`, `_G.*`, `debug.*`, `os.execute`, `:Kick/Ban/Kill`, `vgui.Create`, `bit.*`, `string.char/byte/rep`. One match → reject the whole GMA.
- **Runtime gate** — even if scan was bypassed, every file is re-validated by `ValidateSkinLua` immediately before `CompileString`.
- **Integrity check** — at load `sh_integrity.lua` verifies that all 11 key files contain both `Trainfitter` and `Made by SellingVika` tags. If even one is missing — `IntegrityFailed = true`, addon refuses to operate. Forking? Keep the original tag, add your own.
- **Rate limits and length caps** on every NET handler. `ReportSkins` only accepts wsids already in the active pipeline.

Plus:

- **Auto-subscribe rate-limit**: 60s per wsid, so Apply-spam doesn't pollute the Steam library.
- **Mount queue watchdog**: 90s timeout per attempt, queue doesn't deadlock if callback never fires.
- **HTTP body size guard**: `#body > maxBytes` check BEFORE `file.Write`, defense against DoS via spoofed `file_url`.

### Writing your own skin

Drop into `addon/lua/metrostroi/skins/my_skin.lua`:

```lua
Metrostroi.AddSkin("train", "my_author.my_skin_name", {
    name = "Red Express",
    typ = "81-717",
    textures = {
        ["head"] = "models/my_author/my_skin/head",
        ["hull"] = "models/my_author/my_skin/body",
    },
})
```

Categories: `train` (body), `pass` (passenger interior), `cab` (cabin), `765logo` (front emblem on 760-series).

Textures — in `addon/materials/models/my_author/my_skin/*.vmt + .vtf`.

A mask is the same but in `lua/metrostroi/masks/*.lua` with the `Metrostroi.Masks` table (stock Metrostroi doesn't ship this — it's a convention for community addons; Trainfitter just delivers them).

### Data files

Server-side — in `<srcds>/garrysmod/data/trainfitter/`:

- `persistent.json` — array of active wsids (single-slot)
- `whitelist.json` / `blacklist.json` — managed wsid lists
- `stats.json` — download counters
- `nicks.json` — nick cache for audit output
- `audit.log` (+ `.old`) — SteamID64-based audit (not nick — defense against log injection via nick change), rotates at 1 MB
- `gmas/<wsid>.gma` — HTTP cache. Non-persistent entries auto-cleared on every map change.

Client-side — same folder but on the player's machine:

- `client_history.json` — player's download history. Each entry contains a **hidden `apiSource` field** (how the GMA was obtained: `steamworks_native` / `shared_cache` etc) — NOT shown in the UI, but kept in the file for audit.
- `previews/<wsid>.png` — preview cache

### Troubleshooting

If something doesn't work — check the console. Trainfitter always prefixes its messages with `[Trainfitter]`. Most common:

- **`INTEGRITY FAIL`** — someone stripped headers. Restore originals.
- **`gmsv_workshop binary not installed — using HTTP fetch`** — normal on listen, on dedicated install the DLL.
- **`Server refused to mount <wsid>: ...`** — not a bug, the scanner working, the reason is shown.
- **`Cannot mount <wsid>: gmsv_workshop missing and trainfitter_use_http=0`** — install DLL or set `trainfitter_use_http 1`.
- **`no file_url in Steam response`** — newer Workshop addons no longer have a public file_url, Steam subscription is needed (Trainfitter does it itself on listen).
- **Crash on Apply on x64** — native `steamworks.DownloadUGC` bug. On listen Trainfitter auto-switches to HTTP, on dedicated `gmsv_workshop` is mandatory.

### License

**Author:** SellingVika — `sellingvika@gmail.com`. Site: <https://sellingvika.party/>.

```
Copyright (c) SellingVika. All rights reserved.
```

**Allowed:** Use on your server. Fork, PR, contribute. Mention in reviews / collections.

**Forbidden:** Removing or modifying the `-- Made by SellingVika.` header in any file — integrity check will disable the addon. Passing the addon off as your own / publishing under a different name without crediting the original author. Selling original or modifications without written permission.

**Forking?** Keep the original header, add your own line below:

```lua
-- Trainfitter — sh_config.lua
-- Made by SellingVika.
-- Forked and modified by YourName.
```

Pick a derived name for the fork (not "Trainfitter") to avoid confusing users.

**Dependencies** (have their own licenses, not part of Trainfitter):

- [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) — where the skins go.
- [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop) — server-side `steamworks.DownloadUGC`.

---

## Dansk

Trainfitter er en runtime-loader til skins og masker for Metrostroi Subway Simulator-tog i Garry's Mod. Spilleren åbner UI'et, indsætter et Workshop-link (eller henter ét i den indbyggede browser), trykker Apply — og skinet er på serveren, for alle. Ingen manuelle abonnementer, ingen genstarter, ingen "uploader samlingen igen og genstarter server.cfg". Alt kører på en live server, i realtid, mens alle bliver ved med at spille.

Addonet er beskyttet af en streng multi-lags scanner — spillerne kan kun smugle **rigtige Metrostroi-skins og masker** igennem. SWEP-pakker, gamemodes, baner, alt med smarte `lua/autorun/*.lua`-tricks bliver afvist før mount. Detaljer i [Sikkerhed](#sikkerhed)-sektionen.

### Funktioner kort

- **Ét klik og skinet er live.** Indsæt et link (eller WSID, eller URL — alt parses). Bekræft. Færdig.
- **"Tilføj til favoritter"-knap.** Skinet bliver persistent — auto-monteres efter server-genstart, sendes til nye spillere.
- **Indbygget Workshop-browser.** Tryk på "Åbn Workshop" — et DHTML-vindue åbnes i spillet. Browse Steam Workshop som normalt. JS-injection omdøber Steams Subscribe-knap til "Select for Trainfitter" — et klik på selve siden starter installationen øjeblikkeligt.
- **Masker** — `lua/metrostroi/masks/*.lua` understøttes på lige fod med skins.
- **Målrettet hot-reload.** Kun initiatorens tog opdateres visuelt. Andre spilleres tog røres ikke. Hvis du sidder i et tog, springes det også over — beskytter rendereren mod crashes.
- **Historik** gemmes til `data/trainfitter/client_history.json`, overlever spilgenstart. Hver post har en sletteknap; fanens header har "Ryd historik".
- **Notifikationer i stedet for chat.** Progress, klar, fejl — alt via `notification.AddLegacy` + `AddProgress` (med progress bar). Chatten forbliver ren.
- **Tre sprog**: Dansk, English, Русский. Med flag malet i ren Lua i dropdown (ingen eksterne PNG'er).
- **Auto-oprydning** ved hver banskift: alt der ikke er i favoritter — glemmes, GMA-cache-filer slettes. Persistent bliver.
- **Listen-server og dedicated** virker begge. På listen vælges HTTP-loading via Steam-abonnement automatisk (fordi native `steamworks.DownloadUGC` crasher x64-klienten — kendt engine-bug). På dedicated med `gmsv_workshop` bruges den native sti — hurtigere.
- **Integrity check** — ved load verificeres at alle nøglefiler indeholder `Trainfitter`- og `Made by SellingVika`-tags. Tag mangler → `IntegrityFailed = true`, addonet nægter at fungere. Forker du? Behold den originale tag, tilføj din egen linje VED SIDEN AF.

### Krav

| Side | Påkrævet |
|---|---|
| Server | Garry's Mod Dedicated Server (Win/Linux, 32/64) eller listen-server |
| Server | Metrostroi Subway Simulator ([Workshop 261801217](https://steamcommunity.com/workshop/filedetails/?id=261801217) / [GitHub](https://github.com/Metrostroi-Team/Metrostroi)) |
| Server | `gmsv_workshop` DLL i `garrysmod/lua/bin/` til dedicated. **Ikke nødvendig på listen** — Trainfitter skifter automatisk til HTTP. |
| Server | Udgående TCP 443 → `api.steampowered.com`, `*.steamcontent.com` |
| Klient | Garry's Mod (Legacy eller x86-64) |

LFAdmin / ULX / SAM / enhver populær admin-mod — valgfri. Uden dem virker det via standard `IsAdmin()` / `IsSuperAdmin()`.

### Installation

1. Kopier repo'et til `<srcds>/garrysmod/addons/trainfitter/`. Efter kopiering skal `addon.json` ligge på samme niveau som `lua/`. Dobbelt nesting som `addons/trainfitter/trainfitter/lua/...` er den hyppigste årsag til "virker ikke".
2. **Installér `gmsv_workshop` DLL** til dedicated. Download fra [WilliamVenner/gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), læg i `garrysmod/lua/bin/`. Filnavn matcher srcds-arkitektur: `_win32.dll` / `_win64.dll` / `_linux.dll` / `_linux64.dll`. På listen — spring dette trin over.
3. Start serveren. Konsollen viser:
   ```
   [Trainfitter] gmsv_workshop loaded — server has native steamworks.DownloadUGC.
   Trainfitter v2.2.8 (server)
   ```
4. Forbind som spiller, åbn UI med `trainfitter` (eller bind `bind F3 trainfitter`).

### Konsol-kommandoer

Vigtigste til admins:

- `trainfitter_purge_all` — **fuld nulstilling**, sletter alt.
- `trainfitter_forget_all` — glem alt der ikke er persistent.
- `trainfitter_cache_clear` — kun HTTP-cache.
- `trainfitter_client_purge` — lokal klient-cache (alle kan bruge denne).
- `trainfitter_audit [N]` — sidste N audit-linjer.

Resten er identiske med den engelske sektion ovenfor.

### Sikkerhed

Syv uafhængige scanner-lag plus integrity-check der nægter at køre hvis `Made by SellingVika`-taggene er fjernet. Vil du forke — behold den originale tag, tilføj din egen linje under.

Detaljer på engelsk og russisk ovenfor.

### License

**Forfatter:** SellingVika — `sellingvika@gmail.com`. Site: <https://sellingvika.party/>.

Tilladt: Brug på din server, fork, PR, omtale. Forbudt: Fjerne `-- Made by SellingVika.`-headeren fra nogen fil (ellers slår integrity-check addonet fra), udgive som dit eget, sælge originalen eller modifikationer uden skriftlig tilladelse.

Forker du? Behold original-headeren og tilføj din egen linje under, og navngiv forken med et afledt navn (ikke "Trainfitter").

---

**Trainfitter** © SellingVika. `-- Made by SellingVika.` er en uadskillelig del af hver kildefil.
