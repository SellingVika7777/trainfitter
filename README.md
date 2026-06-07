# Trainfitter

**Trainfitter** - аддон для Garry's Mod: вставил Workshop-ссылку, нажал Apply - и у всех на сервере новый скин (а если смелый - маска или пульт) для **Metrostroi Subway Simulator**. Без рестартов, без лазанья в `server.cfg`, без ритуала с бубном

**© SellingVika.** В шапке каждого `.lua` стоит `-- Made by SellingVika` - это просьба автора, при форке оставь. Подробности в [License](#license)

Сайт: <https://sellingvika.party/> · [Русский](#русский) / [English](#english) / [Dansk](#dansk)

---

## Русский

### Что нужно

| Сторона | Что |
|---|---|
| Сервер | Garry's Mod DS (Win/Linux, 32/64) либо listen-сервер |
| Сервер | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) - без него аддон молча скажет "не наш" и работать не будет |
| Сервер | `gmsv_workshop` DLL в `garrysmod/lua/bin/` - только для dedicated, на listen НЕ нужен |
| Сервер | Доступ наружу к `api.steampowered.com` и `*.steamcontent.com` |
| Клиент | Garry's Mod (Legacy либо x86-64) |

Админка (LFAdmin / ULX / SAM / ServerGuard / любая) - **опционально**. Без неё права идут через стандартные `IsAdmin()` / `IsSuperAdmin()`

### Поставить

1. Кинь репо в `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` должен лежать на одном уровне с `lua/`. Двойная вложенность типа `addons/trainfitter/trainfitter/lua/` - **самая частая причина "не работает"**, проверь путь первым делом
2. Для dedicated - качни [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), положи в `garrysmod/lua/bin/`, имя файла по битности srcds. На listen этот шаг пропускаешь
3. Запусти сервер, в консоли должно появиться `Trainfitter v2.3.0 (server)`
4. Зашёл игроком, открыл UI командой `trainfitter` (или `bind F3 trainfitter`)

### Как пользоваться

Открываешь меню командой `trainfitter`. Вкладки:

- **Установка** - вставил ссылку/WSID, видишь превью, жмёшь **Подтвердить**. Вставил ссылку на **коллекцию** - кнопка сама станет "Применить коллекцию" и поставит всё пачкой. **В избранное** - скин станет persistent (после рестарта поднимется сам). **Открыть Мастерскую** - встроенный браузер Workshop, там Subscribe переименован в "Select for Trainfitter"
- **Избранное** - список persistent-скинов
- **История** - что качал в этой сессии
- **Настройки** - сверху твои **клиентские** настройки (видны всем), ниже **серверные** (только админу с правом `Manage`)
- **Логи** - audit-лог сервера, видна тем у кого есть право `trainfitter_logs`

В шапке окна - переключатель языка и "Очистить мой кеш"

**Слабый ПК ?** В Настройках → Клиент поставь `trainfitter_skins_enabled` в выкл - клиент вообще не будет качать и маунтить скины, составы останутся с дефолтным видом, зато экономишь CPU/RAM/трафик

### Консоль

| Команда | Кому | Что делает |
|---|---|---|
| `trainfitter` | все | Открыть UI |
| `trainfitter_workshop` | все | Встроенный Workshop-браузер |
| `trainfitter_client_purge` | все | Снести свой локальный кеш |
| `trainfitter_list` | все | Показать persistent |
| `trainfitter_stats` | все | Топ-20 скачанных wsid |
| `trainfitter_remove <wsid>` | Persistent | Убрать wsid из избранного |
| `trainfitter_reload` | Persistent | Перечитать и пере-маунтить |
| `trainfitter_{whitelist,blacklist}_{add,remove,list}` | Manage | Списки wsid |
| `trainfitter_cache_clear` | Manage | Снести HTTP-кеш |
| `trainfitter_forget_all` | Manage | Забыть весь non-persistent |
| `trainfitter_purge_all` | Manage | **Ядерная нулёвка** - всё в ноль |
| `trainfitter_audit [N]` | SuperAdmin | Последние N строк лога (default 30, max 500) |

### ConVar'ы

Серверные (пишутся в `server.cfg`):

| Convar | Default | Что делает |
|---|---|---|
| `trainfitter_max_mb` | 200 | Лимит размера аддона в МБ, больше = отказ ДО скачки |
| `trainfitter_require_admin` | 0 | `1` = качать может только привилегированный |
| `trainfitter_use_whitelist` | 0 | `1` = разрешены только wsid из whitelist.json |
| `trainfitter_request_cooldown` | 2 | Кулдаун (сек) между запросами одного игрока |
| `trainfitter_max_persistent` | 1 | Макс. в избранном, `0` = безлимит |
| `trainfitter_max_loaded` | 0 | Макс. загружено на сервере одновременно, `0` = безлимит |
| `trainfitter_max_per_player` | 1 | Макс. на одного игрока, `0` = безлимит |
| `trainfitter_max_per_admin` | 1 | Макс. на одного админа, `0` = безлимит |
| `trainfitter_allow_collections` | 0 | `1` = можно применять коллекции Workshop |
| `trainfitter_max_collection` | 0 | Макс. аддонов из одной коллекции, `0` = безлимит |
| `trainfitter_audit_log` | 1 | Писать в `data/trainfitter/audit.log` |
| `trainfitter_server_premount` | 1 | Сервер маунтит избранное на старте |
| `trainfitter_allow_full_lua` | 0 | **ОПАСНО**, см ниже |

**`trainfitter_allow_full_lua`** - главный переключатель безопасности. По дефолту (`0`) аддон пускает **только скины** - чистые текстуры, безопасно. Включил `1` - разрешаются **маски, пульты, любой Lua**, и этот код бежит **БЕЗ песочницы с полными правами сервера** (считай выдал rcon тому кто заливает). Врубай только если доверяешь всем кто может ставить аддоны - и обязательно подопри `trainfitter_require_admin 1` + `trainfitter_use_whitelist 1`

Тонкая настройка (трогай только если знаешь зачем): `trainfitter_max_lua_kb` (64, 1-1024 - лимит размера одного lua), `trainfitter_sandbox_instr_m` (100, лимит инструкций песочницы в млн), `trainfitter_reject_bytecode` (1 - режем Lua-байткод, **не выключай**), `trainfitter_use_http` (0 = авто)

Клиентские (каждый игрок сам, во вкладке Настройки → Клиент): `trainfitter_lang`, `trainfitter_skins_enabled` (0 = не качать скины себе, для слабых ПК), `trainfitter_auto_subscribe`, `trainfitter_gma_scan`

### Права

Четыре прайвилегии: `trainfitter_download` (user), `trainfitter_persistent` (admin), `trainfitter_manage` (superadmin), `trainfitter_logs` (admin)

Trainfitter спрашивает твою админку: **ULX / SAM / ServerGuard / FAdmin (DarkRP) / Maestro** подхватываются автоматом через **CAMI** - прайвилегии сами появятся в их меню, выдавай/отзывай группам там. Плюс отдельно поддержаны LFAdmin и evolve. Нет админки - падает на `IsAdmin()` / `IsSuperAdmin()`. Хост listen-сервера всегда босс

Своя самописная админка ? Регай свой провайдер одной строкой:
```lua
-- fn(ply, privilege) -> true (пускаем) / false (нет) / nil (без мнения)
Trainfitter.RegisterPermissionProvider("моя_админка", function(ply, priv)
    if MyAdmin and MyAdmin:HasAccess(ply, priv) then return true end
    return nil
end)
```

### Рецепты для server.cfg

**Безопасно но удобно (дефолт)** - скины свободно, маски/пульты нет:
```
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```

**Доверенный круг** - маски и пульты, но только админам и только из списка:
```
trainfitter_allow_full_lua 1
trainfitter_use_whitelist 1
trainfitter_require_admin 1
```

**Паранойя** - игроки ставят только то что админ заранее одобрил (`trainfitter_whitelist_add <wsid>`):
```
trainfitter_allow_full_lua 0
trainfitter_use_whitelist 1
trainfitter_require_admin 1
```

**Анархия** (ТОЛЬКО тест-сервер, не в продакшн - это rcon каждому):
```
trainfitter_allow_full_lua 1
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```

### Свой скин

Кладёшь в `addon/lua/metrostroi/skins/my_skin.lua`:
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
Категории: `train` (кузов), `pass` (салон), `cab` (кабина), `765logo` (эмблема). Текстуры - в `addon/materials/models/my_author/my_skin/*.vmt + .vtf`

**Маска** - то же самое в `lua/metrostroi/masks/*.lua` через `Metrostroi.Masks`, но поставить её можно только при `trainfitter_allow_full_lua 1` (там код)

### Если не работает

Открой консоль, ищи строки с `[Trainfitter]`:

- `gmsv_workshop binary not installed - using HTTP fetch` - на listen это норма, на dedicated значит DLL положил не туда
- `Server refused to mount <wsid>: ...` - это не баг, сканер работает как надо, причина прямо в сообщении
- `addon contains masks or pults; enable convar 'trainfitter_allow_full_lua 1'` - хочешь маски, включи конвар
- `no file_url in Steam response` - старый Workshop-аддон не отдаёт публичный file_url, нужна Steam-подписка
- **Краш на Apply под x64** - это нативный баг `steamworks.DownloadUGC`, не наш. На listen уходит в HTTP, на dedicated `gmsv_workshop` обязателен

Если в консоли пусто - проверь что `addon.json` лежит на одном уровне с `lua/`

### License

**Автор:** SellingVika - `sellingvika@gmail.com` · <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika, all rights reserved
```

Полный текст - в файле [LICENSE](LICENSE) (custom proprietary, не MIT/GPL). Коротко:

**Можно:** ставить и крутить на своём сервере бесплатно, читать код, делать PR и issue, упоминать со ссылкой, тюнить через `trainfitter_*` конвары, модифицировать локально для себя

**Нельзя:** удалять хедер `-- Made by SellingVika`, выдавать за своё, использовать имя "Trainfitter" для форков, продавать без письменного разрешения, распространять "ослабленные версии" с отключённой защитой, перезаливать в Steam Workshop под своим именем

**Форкаешь ?** Оставь хедер, допиши свой ник ниже, назови форк производным именем (не "Trainfitter") и не отключай защиту. **Коммерция ?** Пиши на почту ЗАРАНЕЕ

Зависимости (свои лицензии): [Metrostroi](https://steamcommunity.com/workshop/filedetails/?id=261801217) · [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop)

---

## English

**Trainfitter** is a Garry's Mod addon: paste a Workshop link, hit Apply, and everyone on the server gets a new skin (or, if you're brave, a mask or pult) for **Metrostroi Subway Simulator**. No restarts, no `server.cfg`, no tambourine dance

**© SellingVika.** Every `.lua` carries a `-- Made by SellingVika` header - keep it when forking. See [License](#license)

### Requirements

| Side | What |
|---|---|
| Server | Garry's Mod DS (Win/Linux, 32/64) or listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) - without it the addon says "not ours" and refuses to work |
| Server | `gmsv_workshop` DLL in `garrysmod/lua/bin/` - dedicated only, NOT needed on listen |
| Server | Outbound to `api.steampowered.com` and `*.steamcontent.com` |
| Client | Garry's Mod (Legacy or x86-64) |

Admin mod (LFAdmin / ULX / SAM / ServerGuard / any) - **optional**, falls back to `IsAdmin()` / `IsSuperAdmin()`

### Install

1. Drop the repo into `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` must sit next to `lua/`. Double-nesting like `addons/trainfitter/trainfitter/lua/` is **the most common reason for "doesn't work"** - check the path first
2. For dedicated - grab [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), drop in `garrysmod/lua/bin/`, filename matches srcds bitness. On listen skip this step
3. Start the server, console should show `Trainfitter v2.3.0 (server)`
4. Connect as a player, open UI with `trainfitter` (or `bind F3 trainfitter`)

### How to use

Open the menu with `trainfitter`. Tabs:

- **Install** - paste a link/WSID, see a preview, hit **Confirm**. Paste a **collection** link and the button becomes "Apply collection", installing the whole batch. **Add to favorites** makes it persistent. **Open Workshop** opens the built-in browser (Subscribe is renamed to "Select for Trainfitter")
- **Favorites** - your persistent skins
- **History** - what you downloaded this session
- **Settings** - your **client** settings on top (everyone sees them), **server** settings below (only `Manage` admins)
- **Logs** - the server audit log, shown to anyone with `trainfitter_logs`

The window header has a language switcher and "Purge my cache"

**Weak PC ?** In Settings → Client turn off `trainfitter_skins_enabled` - the client won't download or mount skins at all, trains stay default, saves CPU/RAM/bandwidth

### Console

| Command | Who | What |
|---|---|---|
| `trainfitter` | everyone | Open UI |
| `trainfitter_workshop` | everyone | Embedded Workshop browser |
| `trainfitter_client_purge` | everyone | Wipe your local cache |
| `trainfitter_list` | everyone | Show persistent |
| `trainfitter_remove <wsid>` | Persistent | Remove from favorites |
| `trainfitter_reload` | Persistent | Reload + re-mount |
| `trainfitter_{whitelist,blacklist}_{add,remove,list}` | Manage | wsid lists |
| `trainfitter_cache_clear` | Manage | Wipe HTTP cache |
| `trainfitter_forget_all` | Manage | Forget all non-persistent |
| `trainfitter_purge_all` | Manage | **Nuclear wipe** - everything to zero |
| `trainfitter_audit [N]` | SuperAdmin | Last N log lines (default 30, max 500) |

### ConVars

Server-side (go into `server.cfg`):

| Convar | Default | What |
|---|---|---|
| `trainfitter_max_mb` | 200 | Addon size cap MB, larger rejected before download |
| `trainfitter_require_admin` | 0 | `1` = only privileged players can download |
| `trainfitter_use_whitelist` | 0 | `1` = only wsids from whitelist.json |
| `trainfitter_request_cooldown` | 2 | Cooldown (sec) between a player's requests |
| `trainfitter_max_persistent` | 1 | Max in favorites, `0` = unlimited |
| `trainfitter_max_loaded` | 0 | Max loaded server-wide at once, `0` = unlimited |
| `trainfitter_max_per_player` | 1 | Max per regular player, `0` = unlimited |
| `trainfitter_max_per_admin` | 1 | Max per admin, `0` = unlimited |
| `trainfitter_allow_collections` | 0 | `1` = players may apply Workshop collections |
| `trainfitter_max_collection` | 0 | Max addons from one collection, `0` = unlimited |
| `trainfitter_audit_log` | 1 | Write to `data/trainfitter/audit.log` |
| `trainfitter_server_premount` | 1 | Server pre-mounts favorites on boot |
| `trainfitter_allow_full_lua` | 0 | **DANGEROUS**, see below |

**`trainfitter_allow_full_lua`** is the main security switch. By default (`0`) the addon accepts **skins only** - pure textures, safe. Flip to `1` and **masks, pults, any Lua** are allowed, and that code runs **UNSANDBOXED with full server permissions** (basically rcon for whoever uploads). Only enable if you trust everyone who can install addons - and back it with `trainfitter_require_admin 1` + `trainfitter_use_whitelist 1`

Fine knobs (touch only if you know why): `trainfitter_max_lua_kb` (64, 1-1024), `trainfitter_sandbox_instr_m` (100), `trainfitter_reject_bytecode` (1 - reject Lua bytecode, **don't disable**), `trainfitter_use_http` (0 = auto)

Client (each player, Settings → Client): `trainfitter_lang`, `trainfitter_skins_enabled` (0 = skip skins for weak PCs), `trainfitter_auto_subscribe`, `trainfitter_gma_scan`

### Permissions

Four privileges: `trainfitter_download` (user), `trainfitter_persistent` (admin), `trainfitter_manage` (superadmin), `trainfitter_logs` (admin)

Trainfitter asks your admin mod: **ULX / SAM / ServerGuard / FAdmin (DarkRP) / Maestro** are picked up automatically via **CAMI** - the privileges show up in their menus, grant/revoke per group there. LFAdmin and evolve are supported directly too. No admin mod - falls back to `IsAdmin()` / `IsSuperAdmin()`. The listen-server host is always boss

Home-grown admin mod ? Register a provider in one line:
```lua
-- fn(ply, privilege) -> true (grant) / false (no) / nil (no opinion)
Trainfitter.RegisterPermissionProvider("my_admin", function(ply, priv)
    if MyAdmin and MyAdmin:HasAccess(ply, priv) then return true end
    return nil
end)
```

### Recipes for server.cfg

**Safe but convenient (default)** - skins free, masks/pults no:
```
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```

**Trusted circle** - masks and pults, but admins only and from a list:
```
trainfitter_allow_full_lua 1
trainfitter_use_whitelist 1
trainfitter_require_admin 1
```

**Paranoia** - players install only pre-approved wsids (`trainfitter_whitelist_add <wsid>`):
```
trainfitter_allow_full_lua 0
trainfitter_use_whitelist 1
trainfitter_require_admin 1
```

**Anarchy** (TEST SERVER ONLY, never production - it's rcon for everyone):
```
trainfitter_allow_full_lua 1
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```

### Making a skin

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
Categories: `train` (body), `pass` (passenger), `cab` (cabin), `765logo` (emblem). Textures in `addon/materials/models/my_author/my_skin/*.vmt + .vtf`

**Mask** - same under `lua/metrostroi/masks/*.lua` via `Metrostroi.Masks`, but installable only with `trainfitter_allow_full_lua 1` (it has code)

### If something breaks

Open the console, look for `[Trainfitter]` lines:

- `gmsv_workshop binary not installed - using HTTP fetch` - normal on listen, on dedicated means the DLL is misplaced
- `Server refused to mount <wsid>: ...` - not a bug, the scanner doing its job, reason is in the message
- `addon contains masks or pults; enable convar 'trainfitter_allow_full_lua 1'` - want masks, enable the convar
- `no file_url in Steam response` - old Workshop addon, no public file_url, needs a Steam subscription
- **Crash on Apply on x64** - native `steamworks.DownloadUGC` bug, not ours. Listen auto-switches to HTTP, dedicated needs `gmsv_workshop`

If the console is silent - check that `addon.json` sits next to `lua/`

### License

**Author:** SellingVika - `sellingvika@gmail.com` · <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika, all rights reserved
```

Full text in the [LICENSE](LICENSE) file (custom proprietary, not MIT/GPL). Short version:

**Allowed:** run on your own server free, read the code, submit PRs and issues, mention with a link, tune via `trainfitter_*` convars, modify locally for yourself

**Forbidden:** removing the `-- Made by SellingVika` header, claiming authorship, using the name "Trainfitter" for forks, selling without written permission, distributing "weakened versions" with security disabled, reuploading to Steam Workshop under your own name

**Forking ?** Keep the header, add your nick below, pick a derived name (not "Trainfitter") and don't disable the security. **Commercial use ?** Email first

Dependencies (own licenses): [Metrostroi](https://steamcommunity.com/workshop/filedetails/?id=261801217) · [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop)

---

## Dansk

**Trainfitter** er et Garry's Mod addon: indsæt et Workshop-link, tryk Apply, og alle på serveren får et nyt skin (eller en maske/pult) til **Metrostroi Subway Simulator**. Ingen genstarter, ingen `server.cfg`, ingen tamburin-dans

**© SellingVika.** Hver `.lua` har en `-- Made by SellingVika` header - behold den ved fork. Se [License](#license)

### Krav

| Side | Påkrævet |
|---|---|
| Server | Garry's Mod DS (Win/Linux, 32/64) eller listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) |
| Server | `gmsv_workshop` DLL i `garrysmod/lua/bin/` - kun dedicated |
| Server | Udgående til `api.steampowered.com` og `*.steamcontent.com` |
| Klient | Garry's Mod (Legacy eller x86-64) |

### Install

1. Læg repo'et i `<srcds>/garrysmod/addons/trainfitter/`, `addon.json` ved siden af `lua/`. Dobbelt-nesting er den hyppigste fejl
2. Til dedicated - download [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases) til `garrysmod/lua/bin/`. På listen springes over
3. Start serveren, åbn UI med `trainfitter`

### Brug

Åbn menuen med `trainfitter`. Faner: **Install** (indsæt link, tryk Confirm), **Favorites** (persistent skins), **History**, **Settings** (klient øverst for alle, server kun for `Manage`-admins), **Logs** (kræver `trainfitter_logs`)

**Svag PC ?** Slå `trainfitter_skins_enabled` fra i Settings → Client, så henter klienten ikke skins overhovedet

### Sikkerhed

Som standard tillader addonet **kun skins** - sikkert. Masker og pults kræver `trainfitter_allow_full_lua 1`, og den Lua kører **uden sandbox med fulde serverrettigheder** (reelt rcon til den der uploader) - aktivér kun hvis du stoler på alle, og helst med `trainfitter_require_admin 1` + `trainfitter_use_whitelist 1`

Resten af convars og kommandoer er identiske med de engelske afsnit ovenfor

### License

**Forfatter:** SellingVika - `sellingvika@gmail.com` · <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika, all rights reserved
```

Fuld licenstekst i [LICENSE](LICENSE)-filen (custom proprietær, ikke MIT/GPL, trilingual EN/RU/DK)

**Tilladt:** brug på din server gratis, læs koden, indsend PR/bug-reports, omtale med kredit, justering via officielle convars, personlige modifikationer. **Forbudt:** fjerne header, hævde forfatterskab, bruge navnet "Trainfitter" til forks, kommerciel brug uden tilladelse, distribuere svækkede sikkerhedsversioner, uploade til Steam Workshop under eget navn. **Kommercielt ?** Skriv til `sellingvika@gmail.com` FØR brug

---

**Trainfitter** © SellingVika
