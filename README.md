# Trainfitter

Накатывает скины и маски для **Metrostroi Subway Simulator** на живой сервер, без рестартов и без манипуляций с Workshop-подписками. Игрок вкинул ссылку в UI, нажал Apply - у всех новый поезд

**© SellingVika.** В шапке каждого `.lua` есть `-- Made by SellingVika` - это просьба, а не криптозащита. Форкаешь - оставь, допиши свою строчку ниже. Подробности в [License](#license)

Сайт: <https://sellingvika.party/> · Доки: [Русский](#русский) / [English](#english) / [Dansk](#dansk)

---

## Русский

### Зачем

UI → workshop-ссылка или WSID → Apply → у всех на сервере новый скин. Никаких рестартов, никакого "перезапусти сервер, потом снова перезапусти, потом ещё раз"

Аддон **не пускает что попало**: парсит GMA руками, валидирует пути/расширения/размеры, гоняет user-lua в песочнице. Закинуть SWEP-пак или ssh-бекдор через `lua/autorun/*.lua` - не получится. Хотя попытаться можешь, забавно посмотреть как тебе откажут на седьмом слое

### Что делает

- Один клик и скин на сервере
- "В избранное" - скин становится persistent, маунтится автоматом при рестарте, догоняется новым игрокам
- Встроенный Workshop-браузер (DHTML внутри игры). Кнопка Subscribe на странице переименована в "Select for Trainfitter", клик - пошло качаться
- Маски (`lua/metrostroi/masks/*.lua`) и пульты поддерживаются, но **требуют включения `trainfitter_allow_full_lua 1`** - они содержат настоящий Lua и без явного "да" админа не пускаются. Без флага - только скины
- Точечный hot-reload: визуально обновляются ТОЛЬКО поезда инициатора. Чужие - не дёргаются. Если ты сидишь в кабине - твой тоже не трогается, иначе рендер крашится (привет, Source engine)
- История скачиваний игрока в `data/trainfitter/client_history.json`, живёт через рестарт игры
- Уведомления, а не спам в чат. Прогресс-бары через `notification.AddProgress`
- Три языка: Русский / English / Dansk. Флажки нарисованы прямо в Lua, никаких PNG-ассетов
- На каждой смене карты - autocleanup non-persistent
- Listen и dedicated оба работают. На listen авто-уход в HTTP (нативный `steamworks.DownloadUGC` валит x64-клиент - это engine-баг, не наш). Dedicated с `gmsv_workshop` - нативный путь, быстрее

### Что нужно

| Сторона | Что |
|---|---|
| Сервер | Garry's Mod DS (Win/Linux, 32/64) либо listen |
| Сервер | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) |
| Сервер | `gmsv_workshop` DLL в `garrysmod/lua/bin/` - только для dedicated |
| Сервер | Доступ наружу к `api.steampowered.com`, `*.steamcontent.com` |
| Клиент | Garry's Mod (Legacy либо x86-64) |

LFAdmin / ULX / SAM - опционально. Без админки идёт через `IsAdmin()`/`IsSuperAdmin()`

### Поставить

1. Кинь репо в `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` должен лежать на одном уровне с `lua/`. Двойная вложенность типа `addons/trainfitter/trainfitter/lua/` - **самая частая причина "не работает"**, проверь
2. Для dedicated - скачай [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), положи в `garrysmod/lua/bin/`. Имя файла по битности srcds. На listen пропускаешь
3. Запусти. В консоли должно быть:
   ```
   [Trainfitter] gmsv_workshop loaded - server has native steamworks.DownloadUGC.
   Trainfitter v2.2.9 (server)
   ```
   Видишь `gmsv_workshop binary not installed - using HTTP fetch` - на listen это норма, на dedicated значит DLL положил не туда
4. Зашёл игроком, открыл UI командой `trainfitter` (или `bind F3 trainfitter`)

### UI

- **Установка** - поле для ссылки/WSID, превью, кнопки Подтвердить / В избранное. "Открыть Мастерскую" поднимает встроенный браузер
- **Избранное** - список persistent-скинов, single-slot модель (один активный)
- **История** - карточки текущей сессии с кнопкой удаления
- **Настройки** - только админам с правом `Manage`. У обычных игроков вкладка спрятана, не подсвечивается, ничего

В шапке - переключатель языка (флажки) и "Очистить мой кеш" (доступно всем)

### Консоль

| Команда | Кому | Что |
|---|---|---|
| `trainfitter` | все | Открыть UI |
| `trainfitter_workshop` | все | Встроенный Workshop-браузер |
| `trainfitter_client_purge` | все | Снести локальный кеш (история / превью / GMA) |
| `trainfitter_list` | все | Показать persistent |
| `trainfitter_stats` | все | Топ-20 скачанных wsid |
| `trainfitter_remove <wsid>` | Persistent | Убрать wsid из persistent |
| `trainfitter_reload` | Persistent | Перечитать JSON и пере-маунтить |
| `trainfitter_{whitelist,blacklist}_{add,remove,list}` | Manage | Списки wsid |
| `trainfitter_cache_clear` | Manage | Снести HTTP-кеш `data/trainfitter/gmas/` |
| `trainfitter_forget_all` | Manage | Забыть весь non-persistent в текущей сессии |
| `trainfitter_purge_all` | Manage | **Полная нулёвка** - persistent, кеш, runtime-state, broadcast forget |
| `trainfitter_audit [N]` | SuperAdmin | Последние N строк audit-лога (default 30) |

### ConVar'ы

Главное:

| Convar | Default | Что |
|---|---|---|
| `trainfitter_max_mb` | 200 | Размерный лимит аддона в МБ. Больше - отказ ДО скачки |
| `trainfitter_require_admin` | 0 | `1` = качать может только привилегированный |
| `trainfitter_use_whitelist` | 0 | `1` = разрешены только wsid из whitelist.json |
| `trainfitter_request_cooldown` | 2 | Кулдаун (сек) между запросами одного игрока |
| `trainfitter_audit_log` | 1 | Писать в `data/trainfitter/audit.log` |
| `trainfitter_server_premount` | 1 | Сервер маунтит persistent на старте |
| `trainfitter_use_http` | 0 | `1` = принудительно HTTP, `0` = авто |

Защитные (PROTECTED, **не трогай**): `trainfitter_server_gma_scan`, `trainfitter_content_scan`, `trainfitter_gma_scan`. Все дефолт = 1, выключать буквально нет смысла, это и есть защита

**ОПАСНЫЙ переключатель** `trainfitter_allow_full_lua` (дефолт 0). По дефолту Trainfitter пускает **только скины** (`lua/metrostroi/skins/`) - это чистая текстурная дата, безопасно. Включил `1` - теперь можно ставить **маски, пульты, custom SENT, расширенные effects-ы**, словом всё что имеет настоящий Lua-код. Эти файлы запускаются **БЕЗ песочницы**, с полными правами сервера. Скины как работали в песочнице - так и работают. Включай только если **доверяешь всем кто может ставить аддоны** - лучше ещё параллельно поставить `trainfitter_use_whitelist 1` и `trainfitter_require_admin 1`, чтоб только admin мог ставить из заранее одобренного списка. Когда в safe-режиме игрок попытается поставить маску/пульт - в чате/консоли увидит подсказку про этот конвар

**Гибкая настройка защиты** (все три REPLICATED, по умолчанию выставлены безопасно но если у тебя специфичный кейс - крути):

| Convar | Default | Что |
|---|---|---|
| `trainfitter_max_lua_kb` | 64 | Максимальный размер одного addon-lua файла в КБ. Жёстко клампится 1-1024 (макс 1 МБ). Подними если твои маски жирнее 64 КБ |
| `trainfitter_sandbox_instr_m` | 100 | Лимит инструкций в песочнице в миллионах. Клампится 1-10000. Подними если тяжёлая инициализация маски (процедурные текстуры, большие циклы) упирается в лимит |
| `trainfitter_reject_bytecode` | 1 | `1` = режем Lua-байткод (по умолчанию, безопасно). `0` = пускаем (ОПАСНО, через байткод можно обойти парсер). Включать `0` только если ты ВОТ ПРЯМ уверен в источниках |

Клиентские: `trainfitter_lang` (`ru`/`en`/`da`), `trainfitter_auto_subscribe` (1 = авто-Steam-подписка на Apply, listen only)

### Права

Проверяются по очереди, первый сработавший - победитель:

1. `ply:IsRamzi()` (LFAdmin-группы `ramzi/meow/rawr/licen`) → true
2. LFAdmin access (`trainfitter_download` `v` / `_persistent` `a` / `_manage` `s`)
3. ULX через `ULib.ucl.query` - видны в XGUI, можно выдавать группам или отзывать у суперадмина
4. Стандартные `IsAdmin()` / `IsSuperAdmin()` как fallback

Любое изменение конвара → broadcast в чат: `[Trainfitter] %s changed %s = %s`

### Безопасность

Несколько независимых слоёв. Чтобы протащить чужой код через Trainfitter - придётся пробить **всё одновременно**, что мягко говоря маловероятно:

- **Path whitelist (двухуровневый).** В safe-режиме (дефолт) Lua пускается **только** из `lua/metrostroi/skins/`. Всё остальное - маски, autorun, пульты, `lua/entities/`, `lua/weapons/`, и тем более `gamemodes/`/`bin/`/`data/` - отказ всего GMA с подсказкой какой конвар включить. Если владелец сервера осознанно поставил `trainfitter_allow_full_lua 1` - расширяется до `lua/metrostroi/masks/`, `lua/metrostroi/*`, `lua/autorun/`, `lua/entities/`, `lua/weapons/`, `lua/effects/`
- **Extension whitelist.** `.lua`, текстуры, модели, звуки, шрифты, json. `.exe`/`.dll`/`.so`/`.py` - нахуй (этот whitelist не настраивается, и слава богу)
- **Size caps.** Один addon-lua - **64 КБ по умолчанию, настраивается** через `trainfitter_max_lua_kb` (1-1024). Файл - 256 МБ. Весь аддон - 1 ГБ. Максимум 256 lua-файлов. Жёсткие лимиты (256 МБ / 1 ГБ / 256 файлов) НЕ настраиваются - они спасают сервер от OOM
- **Marker requirement.** Должен быть хотя бы один `lua/metrostroi/{skins,masks}/*.lua` либо metrostroi-ассет в `materials/models/sound`. В full-режиме также считается autorun-lua и `lua/entities/*` - чтоб пульты без скинов проходили. Иначе это не наш аддон, до свидания
- **Песочница** (для скинов всегда, для масок только в safe-варианте). Изолированный env: нет `RunString`/`CompileString`/`dofile`, нет `file.*`/`net.*`/`http.*`/`concommand.*`, нет настоящих entity (только прокси с read-only геттерами), нет `FindMetaTable`/`getmetatable`/`setmetatable` (одну `mt.GetClass` для Entity оставили, и хватит), нет `string.dump`, нет `hook.Run`/`Call`/`GetTable` (только `Add`/`Remove` с неймспейсом), нет `coroutine`. Lua-байткод (`\27...`) отвергается на старте (настраивается `trainfitter_reject_bytecode`). Лимит инструкций по умолчанию 100M, настраивается `trainfitter_sandbox_instr_m` (1-10000 миллионов)
- **GMA-парсинг руками.** Тела `.lua` читаются прямо из `.gma` бинарника, а не через `file.Read` на смонтированные файлы (которые может перехватить какой-нибудь анти-чит-хук на `file.Open` и подсунуть мусор - реальный случай, привет lenofag)
- **Material guard.** `Material("...")` в песочнице не пускает `..`, `:`, абсолютные пути
- **Rate-limits на каждом net-handler'е**, длины строк чекаются, `ReportSkins` принимает только wsid из активного пайплайна

Плюс: 60с rate-limit на auto-subscribe, 90с watchdog на mount-queue, HTTP body-size guard до `file.Write`

### Как настраивать защиту

Идея простая: **владелец сервера сам решает что важнее - максимальная безопасность или максимальная гибкость**. Trainfitter даёт ручки, ты крутишь под себя. Дефолты выставлены на "безопасно но удобно для скинов".

**Кто что может ставить.** Тут две ортогональные оси:

| Что хочешь | Конвар | Эффект |
|---|---|---|
| Только админ может качать | `trainfitter_require_admin 1` | Игроки видят кнопку Apply но получают "нет прав" |
| Только заранее одобренные wsid | `trainfitter_use_whitelist 1` + ручной `trainfitter_whitelist_add` | Даже админ не поставит что попало |
| Можно ставить маски и пульты | `trainfitter_allow_full_lua 1` | Иначе только скины (`lua/metrostroi/skins/`) |
| Уменьшить кулдаун между запросами | `trainfitter_request_cooldown N` (в сек) | Дефолт 2с, ставь 0 если паранойи нет |
| Поднять лимит размера скина | `trainfitter_max_lua_kb N` | Дефолт 64, диапазон 1-1024 |
| Поднять лимит инструкций песочницы | `trainfitter_sandbox_instr_m N` | Дефолт 100M, диапазон 1-10000 |

**Готовые рецепты** (просто кинь в `server.cfg`):

🛡️ **Паранойя-максимум** (только то что админ заранее разрешил):
```
trainfitter_allow_full_lua 0
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Игроки даже скин не поставят пока ты в whitelist не добавишь wsid. Полный контроль.

🚂 **Стандарт** (как у нас по умолчанию - скины свободно, остальное нет):
```
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
trainfitter_use_whitelist 0
trainfitter_reject_bytecode 1
```
Любой игрок может вкинуть workshop-ссылку со скином. Маски/пульты отвергаются с подсказкой админу. Это золотая середина для большинства серверов.

🛠️ **Доверенный круг** (можно ставить пульты и маски, но только админам):
```
trainfitter_allow_full_lua 1
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Включил full-lua, но обернул whitelist-ом и require_admin - чтоб никто кроме админа не мог ставить ничего тяжёлого. Самый практичный рецепт если хочется и маски и безопасность.

🌪️ **Анархия** (всё всем) - не рекомендую но если ты на тест-сервере:
```
trainfitter_allow_full_lua 1
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```
Любой игрок может поставить любой пульт/SENT/маску. Это считай дал rcon каждому подключившемуся. **Только для тестов**, в продакшен не лей.

**Кто считается админом** проверяется по очереди (первый сработавший побеждает): `ply:IsRamzi()` → LFAdmin access (`trainfitter_download`/`_persistent`/`_manage`) → ULX через `ULib.ucl.query` → стандартные `IsAdmin()`/`IsSuperAdmin()`. Если у тебя ULX - права видны в XGUI и можно выдавать отдельным группам.

**Что НЕ настраивается** (специально, чтоб ты не выстрелил себе в ногу): жёсткие лимиты (256 МБ на файл, 1 ГБ на аддон, 256 lua-файлов) - они спасают от OOM-DoS, без них любой школьник положит сервак одним толстым GMA. Whitelist расширений (`.lua`/`.vmt`/`.vtf`/`.mdl`/...) тоже не трогается - `.exe`/`.dll`/`.so` никогда не должны попасть в gmod-аддон, точка.

### Пример скина

`addon/lua/metrostroi/skins/my_skin.lua`:

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

Категории: `train` (кузов), `pass` (пасс. салон), `cab` (кабина), `765logo` (эмблема 760-серии)
Текстуры - в `addon/materials/models/my_author/my_skin/*.vmt + .vtf`

Маска - то же самое, но в `lua/metrostroi/masks/*.lua`, регится через `Metrostroi.Masks`. Чтобы такой аддон вообще можно было поставить - сервер должен включить `trainfitter_allow_full_lua 1`. Маски сложнее скинов (содержат код), потому отдельный переключатель

### Файлы данных

Серверные, `<srcds>/garrysmod/data/trainfitter/`:

- `persistent.json` - активный wsid (single-slot)
- `whitelist.json` / `blacklist.json`
- `stats.json` - счётчик скачиваний
- `nicks.json` - кеш ников для audit
- `audit.log` (+ `.old`) - пишется по SteamID64 (не по нику - чтоб log injection через смену ника не работало), ротация на 1 МБ
- `gmas/<wsid>.gma` - HTTP-кеш. Non-persistent чистится на каждой смене карты

Клиентские (у игрока):

- `client_history.json` - личная история, со скрытым полем `apiSource` для аудита (в UI не показывается, но в файле есть)
- `previews/<wsid>.png` - превью

### Если что-то не работает

Открой консоль, ищи строки с `[Trainfitter]`. Типичные:

- `gmsv_workshop binary not installed - using HTTP fetch` - на listen норма, на dedicated значит DLL не там
- `Server refused to mount <wsid>: ...` - это **не баг**, это сканер работает как надо. Причина указана прямо в сообщении
- `Cannot mount <wsid>: gmsv_workshop missing and trainfitter_use_http=0` - ставь DLL либо `trainfitter_use_http 1`
- `no file_url in Steam response` - старые workshop-аддоны не отдают публичный file_url, нужна Steam-подписка (на listen Trainfitter подписывается сам)
- Краш на Apply под x64 - это нативный баг `steamworks.DownloadUGC`. На listen авто-HTTP, на dedicated `gmsv_workshop` обязателен

### License

Автор: **SellingVika** - `sellingvika@gmail.com`. Сайт: <https://sellingvika.party/>

```
Copyright (c) SellingVika, all rights reserved
```

**Можно:** Использовать на своём сервере. Форкать, делать PR, упоминать в обзорах

**Нельзя:** Удалять хедер `-- Made by SellingVika` (это просьба, не lock - но всё равно не надо). Выдавать аддон за свой. Продавать оригинал или модификации без разрешения

**Форкаешь?** Оставь оригинальный хедер, допиши свой ниже:

```lua
-- Trainfitter - sh_config.lua
-- Made by SellingVika
-- Forked and modified by ТвоёИмя
```

Назови форк производным именем (не "Trainfitter"), чтоб не путать людей

**Зависимости** (свои лицензии, не часть Trainfitter):
[Metrostroi](https://steamcommunity.com/workshop/filedetails/?id=261801217) ·
[gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop)

---

## English

Loads skins and masks for **Metrostroi Subway Simulator** on a live server, no restarts and no manual Workshop subscriptions. Player drops a link in the UI, hits Apply - everyone sees the skin

**© SellingVika.** Every `.lua` has a `-- Made by SellingVika` header. It's a request, not a crypto-lock. Forking? Leave the original, add yours below. See [License](#license)

### What it does

Open UI, paste workshop link or WSID, hit Apply - GMA downloads, validates, mounts, everyone sees it. None of that "restart the server" choreography

The addon **doesn't let just anything in**: parses GMA by hand, validates paths/extensions/sizes, runs user-lua in a sandbox. Sneaking in a SWEP pack or backdoor via `lua/autorun/*.lua` - not happening. Feel free to try though, fun to watch it bounce off layer seven

### Features

- One click and the skin is live
- "Add to favorites" - persistent, auto-mounts after restart, pushed to new joiners
- Embedded Workshop browser (DHTML inside the game). Subscribe button on the page is renamed to "Select for Trainfitter" - clicking it installs
- Masks (`lua/metrostroi/masks/*.lua`) and pults are supported, but **require `trainfitter_allow_full_lua 1`** - they contain real Lua and don't get through without the admin explicitly saying yes. Without the flag - skins only
- Targeted hot-reload: only the initiator's trains visually refresh. Other players' trains untouched. If you're sitting inside a train, yours is skipped too - otherwise the renderer crashes (hello, Source engine)
- Player download history in `data/trainfitter/client_history.json`, survives game restart
- Notifications instead of chat spam. Progress bars via `notification.AddProgress`
- Three languages: English / Русский / Dansk. Flags painted in Lua, no PNG assets
- Auto-cleanup of non-persistent on every map change
- Listen and dedicated both work. Listen auto-switches to HTTP (native `steamworks.DownloadUGC` crashes the x64 client - engine bug, not ours). Dedicated with `gmsv_workshop` uses native path - faster

### Requirements

| Side | Needed |
|---|---|
| Server | Garry's Mod DS (Win/Linux, 32/64) or listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) |
| Server | `gmsv_workshop` DLL in `garrysmod/lua/bin/` - dedicated only |
| Server | Outbound to `api.steampowered.com`, `*.steamcontent.com` |
| Client | Garry's Mod (Legacy or x86-64) |

LFAdmin / ULX / SAM - optional. Falls back to `IsAdmin()` / `IsSuperAdmin()`

### Install

1. Drop repo into `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` must sit next to `lua/`. Double-nesting like `addons/trainfitter/trainfitter/lua/` is **the single most common reason it "doesn't work"**, check that first
2. For dedicated - download [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), put in `garrysmod/lua/bin/`. Filename matches srcds bitness. On listen - skip
3. Start the server. Console should say:
   ```
   [Trainfitter] gmsv_workshop loaded - server has native steamworks.DownloadUGC.
   Trainfitter v2.2.9 (server)
   ```
4. Connect as a player, open UI with `trainfitter` (or `bind F3 trainfitter`)

### Console

| Command | Who | What |
|---|---|---|
| `trainfitter` | everyone | Open UI |
| `trainfitter_workshop` | everyone | Embedded Workshop browser |
| `trainfitter_client_purge` | everyone | Wipe local cache |
| `trainfitter_list` | everyone | Show persistent |
| `trainfitter_remove <wsid>` | Persistent | Remove from persistent |
| `trainfitter_reload` | Persistent | Reload JSON + re-mount |
| `trainfitter_{whitelist,blacklist}_{add,remove,list}` | Manage | wsid lists |
| `trainfitter_cache_clear` | Manage | Wipe HTTP cache |
| `trainfitter_forget_all` | Manage | Forget all non-persistent in current session |
| `trainfitter_purge_all` | Manage | **Nuclear wipe** - persistent zero'd, cache gone, runtime cleared, broadcast forget |
| `trainfitter_audit [N]` | SuperAdmin | Last N audit lines (default 30) |

### ConVars

Main:

| Convar | Default | What |
|---|---|---|
| `trainfitter_max_mb` | 200 | Addon size cap, MB. Larger requests rejected before download |
| `trainfitter_require_admin` | 0 | `1` = only privileged players can download |
| `trainfitter_use_whitelist` | 0 | `1` = only wsids from whitelist.json |
| `trainfitter_request_cooldown` | 2 | Cooldown (sec) between requests from same player |
| `trainfitter_audit_log` | 1 | Write to `data/trainfitter/audit.log` |
| `trainfitter_server_premount` | 1 | Server pre-mounts persistent on boot |
| `trainfitter_use_http` | 0 | `1` = force HTTP, `0` = auto |

Protected (don't touch): `trainfitter_server_gma_scan`, `trainfitter_content_scan`, `trainfitter_gma_scan`. All 1 by default - that's literally the security, no reason to disable

**DANGEROUS toggle** `trainfitter_allow_full_lua` (default 0). By default Trainfitter only accepts **skins** (`lua/metrostroi/skins/`) - pure texture data, safe. Flip it to `1` and you can install **masks, pults, custom SENTs, advanced effects** - anything with real Lua code. Those files run **UNSANDBOXED**, with full server permissions. Skins keep their sandbox like before. Only enable if **you fully trust everyone who can install addons** - better also set `trainfitter_use_whitelist 1` and `trainfitter_require_admin 1` so only admins can install pre-approved wsids. In safe mode, if a player tries to install a mask/pult addon, they'll see a console hint about this convar

**Tunable security knobs** (all REPLICATED, defaults are safe but tweak if your case needs it):

| Convar | Default | What |
|---|---|---|
| `trainfitter_max_lua_kb` | 64 | Per addon-lua size cap in KB. Hard-clamped 1-1024 (1 MB max). Raise if your masks are bigger than 64 KB |
| `trainfitter_sandbox_instr_m` | 100 | Sandbox instruction limit in millions. Clamped 1-10000. Raise if a heavy mask init (procedural textures, big loops) hits the limit |
| `trainfitter_reject_bytecode` | 1 | `1` = reject Lua bytecode (default, safe). `0` = allow it (DANGEROUS, bytecode bypasses parser-level defenses). Only set `0` if you trust the sources completely |

Client: `trainfitter_lang`, `trainfitter_auto_subscribe`

### Security

Several independent layers. To sneak code through Trainfitter you'd need to break **all of them at once**, which is unlikely to put it mildly:

- **Two-tier path whitelist.** In safe mode (default) Lua is allowed **only** from `lua/metrostroi/skins/`. Everything else - masks, autorun, pults, `lua/entities/`, `lua/weapons/`, and `gamemodes/`/`bin/`/`data/` for sure - the whole GMA gets rejected with a hint about which convar to flip. Set `trainfitter_allow_full_lua 1` and the whitelist expands to `lua/metrostroi/masks/`, `lua/metrostroi/*`, `lua/autorun/`, `lua/entities/`, `lua/weapons/`, `lua/effects/`
- **Extension whitelist.** `.lua`, textures, models, sounds, fonts, json. `.exe`/`.dll`/`.so`/`.py` → fuck off (not tunable, and thank god)
- **Size caps.** Per addon-lua: **64 KB by default, tunable** via `trainfitter_max_lua_kb` (1-1024). Per file: 256 MB. Per addon total: 1 GB. Max 256 lua files. The hard limits (256 MB / 1 GB / 256 files) are NOT tunable - they keep the server from OOM
- **Marker requirement.** Must contain at least one `lua/metrostroi/{skins,masks}/*.lua` or a metrostroi asset in `materials/models/sound`. In full mode autorun-lua and `lua/entities/*` count too, so pult-only addons pass. Otherwise it's not our addon, bye
- **Sandbox** (skins always, masks too in safe mode). Isolated env: no `RunString`/`CompileString`/`dofile`, no `file.*`/`net.*`/`http.*`/`concommand.*`, no real entities (only proxies with read-only getters), no `FindMetaTable`/`getmetatable`/`setmetatable` (one `mt.GetClass` for Entity kept, that's it), no `string.dump`, no `hook.Run`/`Call`/`GetTable` (only namespaced `Add`/`Remove`), no `coroutine`. Lua bytecode (`\27...`) rejected on the spot (tunable via `trainfitter_reject_bytecode`). Instruction limit default 100M, tunable via `trainfitter_sandbox_instr_m` (1-10000 millions)
- **GMA parsed by hand.** Lua bodies read directly from the `.gma` binary, not via `file.Read` on mounted files (which can be hijacked by an anti-cheat hook on `file.Open` and fed garbage - real case, hello lenofag)
- **Material guard.** `Material("...")` in the sandbox blocks `..`, `:`, absolute paths
- **Rate-limits on every net handler**, string lengths checked, `ReportSkins` only accepts wsids already in the active pipeline

Plus: 60s rate-limit on auto-subscribe, 90s mount-queue watchdog, HTTP body-size guard before `file.Write`

### How to configure security

Idea is simple: **the server owner decides what matters more - max security or max flexibility**. Trainfitter gives you the knobs, you turn them. Defaults are "safe but convenient for skins".

**Who can install what.** Two orthogonal axes:

| What you want | Convar | Effect |
|---|---|---|
| Only admins can download | `trainfitter_require_admin 1` | Players see Apply but get "no perm" |
| Only pre-approved wsids | `trainfitter_use_whitelist 1` + manual `trainfitter_whitelist_add` | Even admins can't install anything not on the list |
| Allow masks and pults | `trainfitter_allow_full_lua 1` | Otherwise only skins (`lua/metrostroi/skins/`) |
| Lower request cooldown | `trainfitter_request_cooldown N` (sec) | Default 2s, set 0 if no paranoia |
| Bigger skin lua cap | `trainfitter_max_lua_kb N` | Default 64, range 1-1024 |
| Bigger sandbox instruction limit | `trainfitter_sandbox_instr_m N` | Default 100M, range 1-10000 |

**Ready-made recipes** (drop into `server.cfg`):

🛡️ **Max paranoia** (only what admin pre-approved):
```
trainfitter_allow_full_lua 0
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Players can't even install a skin until you `trainfitter_whitelist_add` the wsid. Full control.

🚂 **Standard** (our default - skins free, rest blocked):
```
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
trainfitter_use_whitelist 0
trainfitter_reject_bytecode 1
```
Any player can paste a workshop link with a skin. Masks/pults rejected with a hint pointing to the convar. Golden middle for most servers.

🛠️ **Trusted circle** (masks/pults allowed but only for admins):
```
trainfitter_allow_full_lua 1
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Enabled full-lua but wrapped in whitelist+require_admin - so nobody but admins can install anything heavy. The most practical recipe if you want both masks and security.

🌪️ **Anarchy** (everyone everything) - not recommended but if it's a test server:
```
trainfitter_allow_full_lua 1
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```
Any player can install any pult/SENT/mask. Basically gave rcon to everyone who connects. **Test only**, never production.

**Who counts as admin** is checked in order (first hit wins): `ply:IsRamzi()` → LFAdmin access (`trainfitter_download`/`_persistent`/`_manage`) → ULX `ULib.ucl.query` → standard `IsAdmin()`/`IsSuperAdmin()`. If you have ULX - the access keys show up in XGUI and you can grant them to specific groups.

**What's NOT tunable** (on purpose, to keep you from shooting your foot): hard limits (256 MB per file, 1 GB per addon, 256 lua files) - they save you from OOM-DoS, without them any kid can knock down the server with one fat GMA. Extension whitelist (`.lua`/`.vmt`/`.vtf`/`.mdl`/...) also not touchable - `.exe`/`.dll`/`.so` should never appear in a gmod addon, period.

### Skin example

`addon/lua/metrostroi/skins/my_skin.lua`:

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

Categories: `train` (body), `pass` (passenger), `cab` (cabin), `765logo` (760-series emblem)
Textures in `addon/materials/models/my_author/my_skin/*.vmt + .vtf`

Mask - same but under `lua/metrostroi/masks/*.lua`, registered via `Metrostroi.Masks`. To install one the server must enable `trainfitter_allow_full_lua 1`. Masks are more complex than skins (they contain code) - hence the separate toggle

### Data files

Server-side, `<srcds>/garrysmod/data/trainfitter/`:

- `persistent.json` - active wsid (single-slot)
- `whitelist.json` / `blacklist.json`
- `stats.json` - download counter
- `nicks.json` - nick cache for audit
- `audit.log` (+ `.old`) - SteamID64-keyed (so log injection via nick change doesn't work), rotates at 1 MB
- `gmas/<wsid>.gma` - HTTP cache. Non-persistent cleared on every map change

Client-side (on player's machine):

- `client_history.json` - personal history with hidden `apiSource` field for audit (not shown in UI)
- `previews/<wsid>.png` - preview cache

### If something breaks

Open the console, look for `[Trainfitter]` lines:

- `gmsv_workshop binary not installed - using HTTP fetch` - normal on listen, on dedicated means DLL isn't placed correctly
- `Server refused to mount <wsid>: ...` - **not a bug**, scanner doing its job. Reason is in the message
- `Cannot mount <wsid>: gmsv_workshop missing and trainfitter_use_http=0` - install DLL or set `trainfitter_use_http 1`
- `no file_url in Steam response` - old workshop addons don't expose public file_url anymore, Steam subscription needed (Trainfitter does it itself on listen)
- Crash on Apply on x64 - native `steamworks.DownloadUGC` bug. Listen auto-switches to HTTP, on dedicated `gmsv_workshop` is mandatory

### License

Author: **SellingVika** - `sellingvika@gmail.com`. Site: <https://sellingvika.party/>

```
Copyright (c) SellingVika, all rights reserved
```

**Allowed:** Use on your server. Fork, PR, mention in reviews

**Forbidden:** Stripping the `-- Made by SellingVika` header (it's a request, not a lock - but still). Passing it off as your own. Selling original or modifications without permission

**Forking?** Keep the original header, add yours below:

```lua
-- Trainfitter - sh_config.lua
-- Made by SellingVika
-- Forked and modified by YourName
```

Pick a derived name (not "Trainfitter") to not confuse users

**Dependencies** (own licenses, not part of Trainfitter):
[Metrostroi](https://steamcommunity.com/workshop/filedetails/?id=261801217) ·
[gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop)

---

## Dansk

Loader skins og masker til **Metrostroi Subway Simulator** på live server, uden genstarter og uden manuelle workshop-abonnementer. Spilleren smider et link i UI'et, trykker Apply - alle ser skinet

**© SellingVika.** Hver `.lua` har en `-- Made by SellingVika` header. Det er en anmodning, ikke en crypto-lock. Forker du - behold den originale, tilføj din under

### Hvad det gør

Åbn UI, indsæt workshop-link eller WSID, tryk Apply - GMA downloades, valideres, monteres, alle ser det. Ingen "genstart serveren"-dans

Addonet **lukker ikke bare alt ind**: parser GMA i hånden, validerer stier/filtyper/størrelser, kører bruger-lua i en sandbox. SWEP-pakker og bagdøre via `lua/autorun/*.lua` - sker ikke

### Krav

| Side | Påkrævet |
|---|---|
| Server | Garry's Mod DS (Win/Linux, 32/64) eller listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) |
| Server | `gmsv_workshop` DLL i `garrysmod/lua/bin/` - kun dedicated |
| Server | Udgående til `api.steampowered.com`, `*.steamcontent.com` |
| Klient | Garry's Mod (Legacy eller x86-64) |

### Install

1. Læg repo'et i `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` skal ligge ved siden af `lua/`. Dobbelt-nesting er den hyppigste fejl
2. Til dedicated - download [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases) og læg i `garrysmod/lua/bin/`. På listen - spring over
3. Start serveren, åbn UI med `trainfitter` (eller `bind F3 trainfitter`)

### Konsol (vigtigste)

- `trainfitter_purge_all` - **fuld nulstilling**
- `trainfitter_forget_all` - glem alt der ikke er persistent
- `trainfitter_cache_clear` - kun HTTP-cache
- `trainfitter_client_purge` - lokal cache (alle kan)
- `trainfitter_audit [N]` - sidste N audit-linjer

Resten er identiske med engelske afsnit ovenfor

### Sikkerhed

Flere uafhængige lag: path whitelist, extension whitelist, størrelsesgrænser, sandbox med proxy-entities og uden farlige API'er, GMA parses i hånden, rate-limits på net-handlers. Detaljer i engelsk eller russisk afsnit

### License

**Forfatter:** SellingVika - `sellingvika@gmail.com`. Site: <https://sellingvika.party/>

Tilladt: Brug på din server, fork, PR, omtale
Forbudt: Fjerne `-- Made by SellingVika` header, udgive som dit eget, sælge uden tilladelse

Forker du? Behold original-headeren, tilføj din linje under, navngiv forken med et afledt navn (ikke "Trainfitter")

---

**Trainfitter** © SellingVika
