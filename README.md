# Trainfitter

**Trainfitter** - аддон для Garry's Mod: вставил Workshop-ссылку, нажал Apply - и у всех на сервере новый скин, маска или пульт для **Metrostroi Subway Simulator**. Без рестартов, без лазанья в `server.cfg`, без ритуала с бубном

**© SellingVika.** В шапке каждого `.lua` стоит `-- Made by SellingVika` - это просьба автора, при форке оставь. Подробности в [License](#license)

Сайт: <https://sellingvika.party/> · [Русский](#русский) / [English](#english) / [Dansk](#dansk)

---

## Русский

### Что нужно

| Сторона | Что |
|---|---|
| Сервер | Garry's Mod DS (Windows/Linux, 32/64 бита) либо listen-сервер |
| Сервер | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) - без него аддон скажет "не наш" и работать не будет |
| Сервер | `gmsv_workshop` 4.0 из папки [`gmsv_workshop/bin`](gmsv_workshop/bin) в `garrysmod/lua/bin/` - только для dedicated, на listen НЕ нужен |
| Сервер | Доступ наружу к `api.steampowered.com`, `steamcommunity.com` и `*.steamcontent.com` |
| Сервер | [Metrostroi Extensions Library (MEL)](https://steamcommunity.com/workshop/filedetails/?id=3401843254) - **опционально**, только если на сборке есть MEL |
| Клиент | Garry's Mod (32 или 64 бита) |

Админка (LFAdmin / ULX / SAM / ServerGuard / любая) - **опционально**. Без неё права идут через стандартные `IsAdmin()` / `IsSuperAdmin()`

### Поставить

1. Кинь репо в `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` должен лежать на одном уровне с `lua/`. Двойная вложенность типа `addons/trainfitter/trainfitter/lua/` - **самая частая причина "не работает"**, проверь путь первым делом
2. Для dedicated - возьми из [`gmsv_workshop/bin`](gmsv_workshop/bin) файл под свой srcds и положи в `garrysmod/lua/bin/` (папку создай, если нет). На listen шаг пропускаешь - там качает сам хост

   | srcds | Файл |
   |---|---|
   | Windows `srcds.exe` (32 бита) | `gmsv_workshop_win32.dll` |
   | Windows `srcds_win64.exe` (64 бита) | `gmsv_workshop_win64.dll` |
   | Linux `srcds_run` (32 бита) | `gmsv_workshop_linux.dll` |
   | Linux `srcds_run_x64` (64 бита) | `gmsv_workshop_linux64.dll` |

3. Запусти сервер, в консоли должно появиться `[gmsv_workshop] v4.0.0 loaded` и `Trainfitter v2.4.0 (server)`
4. Если на сборке есть MEL - включи `trainfitter_mel_support 1` (или галочку в Настройках)
5. Зашёл игроком, открыл UI командой `trainfitter` (или `bind F3 trainfitter`)

Старый `gmsv_workshop` 3.x с GitHub после обновлений Garry's Mod 2026 (Steamworks API 1.64) **не грузится** (`undefined symbol: SteamAPI_SteamGameServerUGC_v017`) - бери версию из этого репо, подробности в [gmsv_workshop/README.md](gmsv_workshop/README.md)

### Как пользоваться

Открываешь меню командой `trainfitter`. Вкладки:

- **Установка** - вставил ссылку/WSID, видишь превью, жмёшь **Подтвердить**. Вставил ссылку на **коллекцию** - кнопка сама станет "Применить коллекцию" и поставит всё пачкой. **В избранное** - скин станет persistent (после рестарта поднимется сам). **Открыть Мастерскую** - встроенный браузер Workshop, там Subscribe переименован в "Select for Trainfitter"
- **Избранное** - список persistent-скинов
- **История** - что качал в этой сессии
- **Настройки** - сверху твои **клиентские** настройки, ниже **серверные** (только админу с правом `Manage`)
- **Логи** - audit-лог сервера, видна тем у кого есть право `trainfitter_logs`

В шапке окна - переключатель языка и "Очистить мой кеш"

**Слабый ПК ?** В Настройках → Клиент выключи `trainfitter_skins_enabled` - клиент вообще не будет качать и маунтить скины, составы останутся с дефолтным видом, зато экономишь CPU/RAM/трафик

### Маски, пульты и безопасность

Маски и пульты включены по умолчанию (`trainfitter_allow_masks 1`). Всё, что ставится через Trainfitter, проходит проверку и работает под защитой: аддон из Workshop не может навредить серверу, игрокам или чужим составам. Проверено на реальном сервере с Metrostroi и MEL

`trainfitter_allow_full_lua 1` - **опасный** режим без защиты, работает **только для аддонов из whitelist** (`trainfitter_whitelist_add <wsid>`): такой аддон получает полные права сервера. Нужен только для аддонов, которые меняют саму энтити поезда целиком (свои `lua/entities`). Добавляй в whitelist только то, чему полностью доверяешь

### MEL (Metrostroi Extensions Library)

Часть масок требует [MEL](https://steamcommunity.com/workshop/filedetails/?id=3401843254) (в Workshop он в списке "Required items"). Где-то MEL стоит, где-то нет, поэтому:

- `trainfitter_mel_support 0` (по умолчанию) - любой аддон, у которого MEL в обязательных, или который использует MEL в коде, **отклоняется автоматически** ещё до скачивания
- `trainfitter_mel_support 1` - включай, **только если MEL реально стоит на сервере**. Тогда MEL-рецепты из аддона подхватываются на лету, без рестарта

Если MEL стоит, а галочка выключена (или наоборот) - в меню у админа появится предупреждение

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
| `trainfitter_cache_clear` | Manage | Снести кеш GMA |
| `trainfitter_forget_all` | Manage | Забыть весь non-persistent |
| `trainfitter_purge_all` | Manage | **Ядерная нулёвка** - всё в ноль |
| `trainfitter_audit [N]` | SuperAdmin | Последние N строк лога (default 30, max 500) |

### ConVar'ы

Серверные (пишутся в `server.cfg`, всё то же самое есть галочками в Настройках):

| Convar | Default | Что делает |
|---|---|---|
| `trainfitter_allow_masks` | 1 | Маски, пульты и скриптовые Metrostroi-аддоны. `0` = только скины |
| `trainfitter_mel_support` | 0 | `1` = на сервере есть MEL, аддоны с MEL разрешены. `0` = отклоняются |
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
| `trainfitter_max_session_addons` | 100 | Макс. разных аддонов за карту от игроков, `0` = безлимит |
| `trainfitter_max_new_per_hour` | 20 | Макс. новых аддонов на игрока в час, `0` = безлимит |
| `trainfitter_cache_max_gb` | 20 | Лимит кеша GMA на диске в ГБ, старые удаляются, `0` = безлимит |
| `trainfitter_allow_full_lua` | 0 | **ОПАСНО**, аддоны из whitelist без защиты, см выше |

Служебные настройки защиты `trainfitter_max_lua_kb`, `trainfitter_sandbox_instr_m`, `trainfitter_reject_bytecode` - оставь по умолчанию. `trainfitter_use_http` (0 = авто)

Клиентские (каждый игрок сам, во вкладке Настройки → Клиент): `trainfitter_lang`, `trainfitter_skins_enabled` (0 = не качать скины себе, для слабых ПК), `trainfitter_auto_subscribe`

### Права

Четыре прайвилегии: `trainfitter_download` (user), `trainfitter_persistent` (admin), `trainfitter_manage` (superadmin), `trainfitter_logs` (admin)

Trainfitter спрашивает твою админку: **ULX / SAM / ServerGuard / FAdmin (DarkRP) / Maestro** подхватываются автоматом через **CAMI** - прайвилегии сами появятся в их меню, выдавай/отзывай группам там. Плюс отдельно поддержаны LFAdmin и evolve. Нет админки - падает на `IsAdmin()` / `IsSuperAdmin()`. Хост listen-сервера всегда босс

Своя самописная админка ? Регай свой провайдер одной строкой:
```lua
Trainfitter.RegisterPermissionProvider("моя_админка", function(ply, priv)
    if MyAdmin and MyAdmin:HasAccess(ply, priv) then return true end
    return nil
end)
```
Функция возвращает `true` (пускаем), `false` (нет) или `nil` (без мнения). Хоть один `true` - пускаем. Иначе хоть один `false` - отказ, даже админу. Все `nil` - решают `IsAdmin()` / `IsSuperAdmin()`

### Рецепты для server.cfg

**Безопасно и удобно (дефолт)** - скины и маски свободно, всё под защитой:
```
trainfitter_allow_masks 1
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
```

**Сборка с MEL** - то же самое, плюс маски на MEL:
```
trainfitter_allow_masks 1
trainfitter_mel_support 1
```

**Только скины** - маски и любой скриптовый Lua запрещены:
```
trainfitter_allow_masks 0
trainfitter_allow_full_lua 0
```

**Паранойя** - игроки ставят только то что админ заранее одобрил (`trainfitter_whitelist_add <wsid>`):
```
trainfitter_use_whitelist 1
trainfitter_require_admin 1
```

**Полный Lua для проверенных аддонов** (каждый такой аддон получает права сервера, добавляй только то, что прочитал):
```
trainfitter_allow_full_lua 1
```
и потом `trainfitter_whitelist_add <wsid>` для каждого доверенного аддона. Всё, чего нет в whitelist, по-прежнему грузится под защитой

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

**Маска** - либо MEL-рецепт в `lua/recipies/<имя>/sh_<имя>.lua` (`MEL.DefineRecipe`, `MEL.NewClientProp`, `MEL.AddSpawnerField`...), либо старый формат в `lua/autorun/*.lua` через `scripted_ents.GetStored("gmod_subway_...")`, `ENT.ClientProps`, `ENT.Spawner`, `hook.Add("InitPostEntity", ...)`. Оба формата работают в песочнице. Языковые файлы `lua/metrostroi_data/languages/*.lua` тоже подхватываются

### Если не работает

Открой консоль, ищи строки с `[Trainfitter]` и `[gmsv_workshop]`:

- `gmsv_workshop is not installed` - на listen это норма, на dedicated положи DLL из `gmsv_workshop/bin` в `garrysmod/lua/bin/`
- `Couldn't load module library! (... SteamAPI_SteamGameServerUGC_v017)` - стоит старый gmsv_workshop 3.x, замени на 4.0 из этого репо
- `Server refused to mount <wsid>: ...` - это не баг, аддон не прошёл проверку, причина прямо в сообщении
- `addon contains masks/scripts; enable 'trainfitter_allow_masks 1'` - маски выключены конваром
- `addon requires Metrostroi Extensions Library (MEL)` - включи `trainfitter_mel_support 1`, если MEL реально стоит на сервере
- `addon ships Lua that only works as a full addon` - аддон подменяет целую энтити, такое грузится только в опасном `trainfitter_allow_full_lua 1` и только из whitelist
- `This map session already loaded its maximum of addons` / `You reached your hourly limit` - сработали `trainfitter_max_session_addons` / `trainfitter_max_new_per_hour`
- `[Trainfitter:<wsid>] sandboxed code error: ...` - ошибка в коде самой маски, сервер не пострадал
- `[Trainfitter:<wsid>] sandbox disabled: ...` - аддон отключён защитой, сервер не пострадал
- `this Workshop item has no public download URL` - на dedicated без gmsv_workshop качаются только старые аддоны

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

Зависимости (свои лицензии): [Metrostroi](https://steamcommunity.com/workshop/filedetails/?id=261801217) · [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop) (MIT, [gmsv_workshop/LICENSE](gmsv_workshop/LICENSE))

---

## English

**Trainfitter** is a Garry's Mod addon: paste a Workshop link, hit Apply, and everyone on the server gets a new skin, mask or pult for **Metrostroi Subway Simulator**. No restarts, no `server.cfg`, no tambourine dance

**© SellingVika.** Every `.lua` carries a `-- Made by SellingVika` header - keep it when forking. See [License](#license)

### Requirements

| Side | What |
|---|---|
| Server | Garry's Mod DS (Windows/Linux, 32/64-bit) or listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) - without it the addon says "not ours" and refuses to work |
| Server | `gmsv_workshop` 4.0 from [`gmsv_workshop/bin`](gmsv_workshop/bin) in `garrysmod/lua/bin/` - dedicated only, NOT needed on listen |
| Server | Outbound to `api.steampowered.com`, `steamcommunity.com` and `*.steamcontent.com` |
| Server | [Metrostroi Extensions Library (MEL)](https://steamcommunity.com/workshop/filedetails/?id=3401843254) - **optional**, only if your build ships MEL |
| Client | Garry's Mod (32 or 64-bit) |

Admin mod (LFAdmin / ULX / SAM / ServerGuard / any) - **optional**, falls back to `IsAdmin()` / `IsSuperAdmin()`

### Install

1. Drop the repo into `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` must sit next to `lua/`. Double-nesting like `addons/trainfitter/trainfitter/lua/` is **the most common reason for "doesn't work"** - check the path first
2. Dedicated only - copy the file matching your srcds from [`gmsv_workshop/bin`](gmsv_workshop/bin) into `garrysmod/lua/bin/`: `gmsv_workshop_win32.dll` (srcds.exe), `gmsv_workshop_win64.dll` (srcds_win64.exe), `gmsv_workshop_linux.dll` (srcds_run), `gmsv_workshop_linux64.dll` (srcds_run_x64). On listen the host downloads everything, skip this step
3. Start the server, the console should show `[gmsv_workshop] v4.0.0 loaded` and `Trainfitter v2.4.0 (server)`
4. If your build ships MEL - set `trainfitter_mel_support 1`
5. Connect as a player, open UI with `trainfitter` (or `bind F3 trainfitter`)

The old `gmsv_workshop` 3.x no longer loads after the 2026 Garry's Mod updates (Steamworks API 1.64, `undefined symbol: SteamAPI_SteamGameServerUGC_v017`) - use the 4.0 build from this repo, see [gmsv_workshop/README.md](gmsv_workshop/README.md)

### How to use

Open the menu with `trainfitter`. Tabs:

- **Install** - paste a link/WSID, see a preview, hit **Confirm**. Paste a **collection** link and the button becomes "Apply collection", installing the whole batch. **Add to favorites** makes it persistent. **Open Workshop** opens the built-in browser (Subscribe is renamed to "Select for Trainfitter")
- **Favorites** - your persistent skins
- **History** - what you downloaded this session
- **Settings** - your **client** settings on top, **server** settings below (only `Manage` admins)
- **Logs** - the server audit log, shown to anyone with `trainfitter_logs`

The window header has a language switcher and "Purge my cache"

**Weak PC ?** In Settings → Client turn off `trainfitter_skins_enabled` - the client won't download or mount skins at all, trains stay default, saves CPU/RAM/bandwidth

### Masks, pults and security

Masks and pults are on by default (`trainfitter_allow_masks 1`). Everything installed through Trainfitter is checked and runs protected: a Workshop addon can't harm the server, the players or other people's trains. Tested on a real server with Metrostroi and MEL

`trainfitter_allow_full_lua 1` is the **dangerous** unprotected mode and it **only applies to whitelisted addons** (`trainfitter_whitelist_add <wsid>`): such an addon gets full server permissions. Only needed for addons that replace a whole train entity (their own `lua/entities`). Only whitelist what you fully trust

### MEL (Metrostroi Extensions Library)

Some masks require [MEL](https://steamcommunity.com/workshop/filedetails/?id=3401843254) (listed under "Required items" on the Workshop page). Some builds have MEL, some don't:

- `trainfitter_mel_support 0` (default) - any addon that lists MEL as required or uses MEL in its code is **rejected automatically**, before it is even downloaded
- `trainfitter_mel_support 1` - enable **only if MEL is really installed**. MEL recipes from the addon are then picked up live, no restart

If MEL is installed but the switch is off (or the other way round), admins get a warning in the menu

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
| `trainfitter_cache_clear` | Manage | Wipe GMA cache |
| `trainfitter_forget_all` | Manage | Forget all non-persistent |
| `trainfitter_purge_all` | Manage | **Nuclear wipe** - everything to zero |
| `trainfitter_audit [N]` | SuperAdmin | Last N log lines (default 30, max 500) |

### ConVars

Server-side (go into `server.cfg`, also available as switches in Settings):

| Convar | Default | What |
|---|---|---|
| `trainfitter_allow_masks` | 1 | Masks, pults and scripted Metrostroi addons. `0` = skins only |
| `trainfitter_mel_support` | 0 | `1` = the server runs MEL, MEL addons allowed. `0` = rejected |
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
| `trainfitter_max_session_addons` | 100 | Max different addons players can load per map, `0` = unlimited |
| `trainfitter_max_new_per_hour` | 20 | Max new addons per player per hour, `0` = unlimited |
| `trainfitter_cache_max_gb` | 20 | GMA disk cache cap in GB, oldest files go first, `0` = unlimited |
| `trainfitter_allow_full_lua` | 0 | **DANGEROUS**, whitelisted addons without protection, see above |

Internal protection settings `trainfitter_max_lua_kb`, `trainfitter_sandbox_instr_m`, `trainfitter_reject_bytecode` - keep the defaults. `trainfitter_use_http` (0 = auto)

Client (each player, Settings → Client): `trainfitter_lang`, `trainfitter_skins_enabled` (0 = skip skins for weak PCs), `trainfitter_auto_subscribe`

### Permissions

Four privileges: `trainfitter_download` (user), `trainfitter_persistent` (admin), `trainfitter_manage` (superadmin), `trainfitter_logs` (admin)

Trainfitter asks your admin mod: **ULX / SAM / ServerGuard / FAdmin (DarkRP) / Maestro** are picked up automatically via **CAMI** - the privileges show up in their menus, grant/revoke per group there. LFAdmin and evolve are supported directly too. No admin mod - falls back to `IsAdmin()` / `IsSuperAdmin()`. The listen-server host is always boss

Home-grown admin mod ? Register a provider in one line:
```lua
Trainfitter.RegisterPermissionProvider("my_admin", function(ply, priv)
    if MyAdmin and MyAdmin:HasAccess(ply, priv) then return true end
    return nil
end)
```
The function returns `true` (grant), `false` (no) or `nil` (no opinion). Any `true` grants. Otherwise any `false` denies, even for admins. All `nil` - `IsAdmin()` / `IsSuperAdmin()` decide

### Recipes for server.cfg

**Safe and convenient (default)** - skins and masks, all protected:
```
trainfitter_allow_masks 1
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
```

**Build with MEL** - same, plus MEL masks:
```
trainfitter_allow_masks 1
trainfitter_mel_support 1
```

**Skins only** - masks and any scripted Lua forbidden:
```
trainfitter_allow_masks 0
trainfitter_allow_full_lua 0
```

**Paranoia** - players install only pre-approved wsids (`trainfitter_whitelist_add <wsid>`):
```
trainfitter_use_whitelist 1
trainfitter_require_admin 1
```

**Full Lua for reviewed addons** (each such addon gets server permissions, only whitelist what you have read):
```
trainfitter_allow_full_lua 1
```
then `trainfitter_whitelist_add <wsid>` for every trusted addon. Anything not on the whitelist still loads protected

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

**Mask** - either a MEL recipe in `lua/recipies/<name>/sh_<name>.lua` (`MEL.DefineRecipe`, `MEL.NewClientProp`, `MEL.AddSpawnerField`...) or the old format in `lua/autorun/*.lua` via `scripted_ents.GetStored("gmod_subway_...")`, `ENT.ClientProps`, `ENT.Spawner`, `hook.Add("InitPostEntity", ...)`. Both run in the sandbox. Language files `lua/metrostroi_data/languages/*.lua` are picked up too

### If something breaks

Open the console, look for `[Trainfitter]` and `[gmsv_workshop]` lines:

- `gmsv_workshop is not installed` - normal on listen, on dedicated copy the DLL from `gmsv_workshop/bin` into `garrysmod/lua/bin/`
- `Couldn't load module library! (... SteamAPI_SteamGameServerUGC_v017)` - old gmsv_workshop 3.x, replace it with 4.0 from this repo
- `Server refused to mount <wsid>: ...` - not a bug, the addon failed the check, reason is in the message
- `addon contains masks/scripts; enable 'trainfitter_allow_masks 1'` - masks are disabled
- `addon requires Metrostroi Extensions Library (MEL)` - enable `trainfitter_mel_support 1` if MEL is really installed
- `addon ships Lua that only works as a full addon` - the addon replaces a whole entity, only the dangerous `trainfitter_allow_full_lua 1` can load it, and only from the whitelist
- `This map session already loaded its maximum of addons` / `You reached your hourly limit` - `trainfitter_max_session_addons` / `trainfitter_max_new_per_hour` kicked in
- `[Trainfitter:<wsid>] sandboxed code error: ...` - a bug in the mask itself, the server is fine
- `[Trainfitter:<wsid>] sandbox disabled: ...` - the addon was switched off by the protection, the server is fine
- `this Workshop item has no public download URL` - dedicated without gmsv_workshop can only fetch legacy addons

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

Dependencies (own licenses): [Metrostroi](https://steamcommunity.com/workshop/filedetails/?id=261801217) · [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop) (MIT, [gmsv_workshop/LICENSE](gmsv_workshop/LICENSE))

---

## Dansk

**Trainfitter** er et Garry's Mod addon: indsæt et Workshop-link, tryk Apply, og alle på serveren får et nyt skin, en maske eller en pult til **Metrostroi Subway Simulator**. Ingen genstarter, ingen `server.cfg`, ingen tamburin-dans

**© SellingVika.** Hver `.lua` har en `-- Made by SellingVika` header - behold den ved fork. Se [License](#license)

### Krav

| Side | Påkrævet |
|---|---|
| Server | Garry's Mod DS (Windows/Linux, 32/64-bit) eller listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) |
| Server | `gmsv_workshop` 4.0 fra [`gmsv_workshop/bin`](gmsv_workshop/bin) i `garrysmod/lua/bin/` - kun dedicated |
| Server | Udgående til `api.steampowered.com`, `steamcommunity.com` og `*.steamcontent.com` |
| Server | [Metrostroi Extensions Library (MEL)](https://steamcommunity.com/workshop/filedetails/?id=3401843254) - valgfri |
| Klient | Garry's Mod (32 eller 64-bit) |

### Install

1. Læg repo'et i `<srcds>/garrysmod/addons/trainfitter/`, `addon.json` ved siden af `lua/`. Dobbelt-nesting er den hyppigste fejl
2. Til dedicated - kopiér filen til din srcds fra `gmsv_workshop/bin` til `garrysmod/lua/bin/`. På listen springes over
3. Har serveren MEL - sæt `trainfitter_mel_support 1`
4. Start serveren, åbn UI med `trainfitter`

### Brug

Åbn menuen med `trainfitter`. Faner: **Install** (indsæt link, tryk Confirm), **Favorites** (persistent skins), **History**, **Settings** (klient øverst for alle, server kun for `Manage`-admins), **Logs** (kræver `trainfitter_logs`)

**Svag PC ?** Slå `trainfitter_skins_enabled` fra i Settings → Client, så henter klienten ikke skins overhovedet

### Sikkerhed

Masker er tilladt som standard (`trainfitter_allow_masks 1`). Alt, der installeres gennem Trainfitter, bliver kontrolleret og kører beskyttet: et Workshop-addon kan ikke skade serveren, spillerne eller andres tog. Addons der kræver MEL afvises automatisk medmindre `trainfitter_mel_support 1`. `trainfitter_allow_full_lua 1` giver **fulde serverrettigheder**, men kun til addons på whitelisten

Grænser: `trainfitter_max_session_addons` (100 pr. kort), `trainfitter_max_new_per_hour` (20 pr. spiller), `trainfitter_cache_max_gb` (20 GB cache)

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
