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

Маски включены по умолчанию (`trainfitter_allow_masks 1`). Любой Lua из Workshop-аддона (скины, маски, `lua/autorun`, MEL-рецепты, языковые файлы) выполняется **только внутри песочницы Trainfitter**, а не как обычный код сервера:

- Сервер монтирует **перепакованную копию GMA без единого `.lua`** - файлы аддона не видны ни `include`, ни автозапуску после смены карты, ни загрузчикам Metrostroi/MEL. Код исполняется только из памяти, в песочнице
- Песочница видит только безопасный набор: `Metrostroi.AddSkin` и прочие функции для скинов/масок, таблицы составов `gmod_subway_*` и их клиентпропы, `hook`/`timer` (с префиксом и лимитами), `ents`/`player` (только через прокси). Данные Metrostroi, базовые классы, таблицы остальных энтити и материалы - только чтение
- В таблицах составов нельзя трогать права и владельца: `CanTool`, `CanProperty`, `PhysgunPickup`, `SpawnFunction`, дюп-колбэки, `Use`, `AcceptInput`, любые поля с `owner`/`cppi`/`fpp`/`steamid`/`admin`... - маска не может выдать себе тулган на чужие составы или обойти prop protection
- **Нет доступа** к `RunString`, `CompileString`, `require`, `file`, `http`, `net`, `concommand`, `RunConsoleCommand`, `game.ConsoleCommand`, `debug`, `getfenv`/`setfenv`, `coroutine`, `sql`, метатаблицам движка
- Игроки для песочницы - только чтение (`Nick`, `SteamID`...): никаких `SendLua`, `SetUserGroup`, `Kick`, `ConCommand`. Чужие энтити - только чтение. Игрок или чужая энтити, которую песочница пытается подсунуть в код сервера (например в MEL), превращается в `NULL`
- Хуки только "безопасные" (`Think`, `InitPostEntity`, `Metrostroi*`...), их аргументы только для чтения, возвращаемые значения игнорируются - через маску нельзя подменить `CheckPassword`, `PlayerSay`, `CAMI.PlayerHasAccess` и т.п.
- MEL-рецепты регистрируются замороженной проверенной копией, тип поезда проверяется (никаких паттернов-бомб в код MEL), языковые файлы не могут перезаписать чужие фразы
- Лимиты: инструкции на загрузку файла и на каждый вызов, память, размер строк/паттернов, CPU (аддон, который жрёт больше половины времени сервера, автоматически отключается), число хуков/таймеров/клиентских моделей
- Lua-байткод запрещён, путь и размер каждого файла проверяются, парсер GMA совпадает с движком
- Контент тоже проверяется: из аддона берутся только `materials/`, `models/`, `sound/`, `resource/localization/` и безопасные форматы (vmt, vtf, png, jpg, mdl, vvd, phy, vtx, ani, wav, mp3, ogg). Заголовки моделей и текстур валидируются (кривой `.mdl`/`.vtf` не доедет до движка), подмена стандартных файлов игры и интерфейса (`materials/console`, `materials/vgui/logos`...) запрещена
- Защита от спама и DoS: код аддона выполняется один раз за карту (повторный запрос не перезапускает его), лимиты `trainfitter_max_session_addons` и `trainfitter_max_new_per_hour` для игроков, кеш на диске ограничен `trainfitter_cache_max_gb`, лог не забивается спамом
- Встроенный браузер открывает только Steam, превью берутся только с CDN Steam и проверяются, что это картинка. Trainfitter отписывает игрока только от того, на что сам его подписал
- Запрет от админки уважается: если провайдер прав сказал `false`, `IsAdmin()` его не перебьёт

Проверено на реальном сервере с Metrostroi + MEL: 2 MEL-маски, 2 маски старого формата и скин-пак ставятся и работают, 64 атаки на песочницу (побег через метатаблицы, `string.dump`, бесконечные циклы, бомбы памяти/паттернов, опасные хуки, подмена `CanTool`/владельца, утечка игроков в MEL, запись в данные Metrostroi, порча материалов и т.д.) блокируются

`trainfitter_allow_full_lua 1` - **опасный** режим без песочницы, и работает он **только для аддонов из whitelist** (`trainfitter_whitelist_add <wsid>`): Lua такого аддона бежит с полными правами сервера. Все остальные аддоны остаются в песочнице. Нужен только для аддонов, которые меняют саму энтити поезда целиком (свои `lua/entities`). Добавляй в whitelist только то, код чего сам прочитал

### MEL (Metrostroi Extensions Library)

Часть масок требует [MEL](https://steamcommunity.com/workshop/filedetails/?id=3401843254) (в Workshop он в списке "Required items"). Где-то MEL стоит, где-то нет, поэтому:

- `trainfitter_mel_support 0` (по умолчанию) - любой аддон, у которого MEL в обязательных, или который использует MEL в коде, **отклоняется автоматически** ещё до скачивания
- `trainfitter_mel_support 1` - включай, **только если MEL реально стоит на сервере**. Тогда MEL-рецепты из аддона выполняются в песочнице и подхватываются MEL на лету, без рестарта

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
| `trainfitter_allow_masks` | 1 | Маски, пульты и скриптовые Metrostroi-аддоны (в песочнице). `0` = только скины |
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
| `trainfitter_allow_full_lua` | 0 | **ОПАСНО**, Lua аддонов из whitelist без песочницы, см выше |

Тонкая настройка (трогай только если знаешь зачем): `trainfitter_max_lua_kb` (256, 1-4096 - лимит размера одного lua), `trainfitter_sandbox_instr_m` (100, лимит инструкций песочницы на файл в млн), `trainfitter_reject_bytecode` (1 - режем Lua-байткод в режиме full_lua, **не выключай**), `trainfitter_use_http` (0 = авто)

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

**Безопасно и удобно (дефолт)** - скины и маски свободно, всё в песочнице:
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
и потом `trainfitter_whitelist_add <wsid>` для каждого доверенного аддона. Всё, чего нет в whitelist, по-прежнему грузится в песочнице

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
- `Server refused to mount <wsid>: ...` - это не баг, сканер работает как надо, причина прямо в сообщении
- `addon contains masks/scripts; enable 'trainfitter_allow_masks 1'` - маски выключены конваром
- `addon requires Metrostroi Extensions Library (MEL)` - включи `trainfitter_mel_support 1`, если MEL реально стоит на сервере
- `addon ships Lua that only works as a full addon` - аддон подменяет целую энтити, такое грузится только в опасном `trainfitter_allow_full_lua 1` и только из whitelist
- `addon tries to replace a base game file` / `malformed file` - аддон подменяет файлы игры или несёт битую модель/текстуру, это защита
- `This map session already loaded its maximum of addons` / `You reached your hourly limit` - сработали `trainfitter_max_session_addons` / `trainfitter_max_new_per_hour`
- `[Trainfitter:<wsid>] sandboxed code error: ...` - ошибка в коде самой маски, сервер не пострадал
- `[Trainfitter:<wsid>] sandbox disabled: CPU usage too high` - аддон пытался положить сервер и был отключён
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

Masks are on by default (`trainfitter_allow_masks 1`). Any Lua shipped by a Workshop addon (skins, masks, `lua/autorun`, MEL recipes, language files) runs **only inside the Trainfitter sandbox**, never as regular server code:

- The server mounts a **repacked copy of the GMA with zero `.lua` files** - addon Lua is invisible to `include`, to autorun after a map change and to Metrostroi/MEL loaders. It only runs from memory, sandboxed
- The sandbox sees a safe subset: `Metrostroi.AddSkin` and other skin/mask helpers, the `gmod_subway_*` entity tables and their client props, prefixed and capped `hook`/`timer`, proxied `ents`/`player`. Metrostroi data, base classes, other entity tables and materials are read-only
- Train tables can't touch permissions or ownership: `CanTool`, `CanProperty`, `PhysgunPickup`, `SpawnFunction`, dupe callbacks, `Use`, `AcceptInput`, any field with `owner`/`cppi`/`fpp`/`steamid`/`admin`... - a mask can't grant itself the toolgun on other people's trains or bypass prop protection
- **No access** to `RunString`, `CompileString`, `require`, `file`, `http`, `net`, `concommand`, `RunConsoleCommand`, `game.ConsoleCommand`, `debug`, `getfenv`/`setfenv`, `coroutine`, `sql` or engine metatables
- Players are read-only (`Nick`, `SteamID`...): no `SendLua`, `SetUserGroup`, `Kick`, `ConCommand`. Foreign entities are read-only. A player or foreign entity the sandbox tries to hand to server code (MEL for example) turns into `NULL`
- Only "safe" hooks (`Think`, `InitPostEntity`, `Metrostroi*`...), their arguments are read-only and return values are ignored - a mask can't hijack `CheckPassword`, `PlayerSay`, `CAMI.PlayerHasAccess` and friends
- MEL recipes are registered as a frozen, validated copy, the train type is checked (no pattern bombs inside MEL), language files can't overwrite other phrases
- Limits: instructions per file and per call, memory, string/pattern size, CPU (an addon eating more than half of the server time gets disabled), number of hooks/timers/client models
- Lua bytecode is rejected, every path and size is checked, the GMA parser matches the engine
- Content is checked too: only `materials/`, `models/`, `sound/`, `resource/localization/` and safe formats (vmt, vtf, png, jpg, mdl, vvd, phy, vtx, ani, wav, mp3, ogg) are kept. Model and texture headers are validated (a broken `.mdl`/`.vtf` never reaches the engine), replacing base game and UI files (`materials/console`, `materials/vgui/logos`...) is refused
- Spam and DoS protection: an addon's code runs once per map (a repeated request doesn't re-run it), `trainfitter_max_session_addons` and `trainfitter_max_new_per_hour` cap players, the disk cache is capped by `trainfitter_cache_max_gb`, the audit log can't be flooded
- The embedded browser only opens Steam, previews only come from the Steam CDN and must be real images. Trainfitter only unsubscribes players from items it subscribed them to itself
- Admin mod denials are respected: if a permission provider says `false`, `IsAdmin()` can't override it

Tested on a real server with Metrostroi + MEL: 2 MEL masks, 2 old-style masks and a skin pack install and work, 64 sandbox attacks (metatable escapes, `string.dump`, infinite loops, memory/pattern bombs, dangerous hooks, `CanTool`/owner hijacks, players leaking into MEL, writes to Metrostroi data, material tampering...) are blocked

`trainfitter_allow_full_lua 1` is the **dangerous** no-sandbox mode and it **only applies to whitelisted addons** (`trainfitter_whitelist_add <wsid>`): such an addon's Lua runs with full server permissions. Every other addon stays sandboxed. Only needed for addons that replace a whole train entity (their own `lua/entities`). Only whitelist code you have read yourself

### MEL (Metrostroi Extensions Library)

Some masks require [MEL](https://steamcommunity.com/workshop/filedetails/?id=3401843254) (listed under "Required items" on the Workshop page). Some builds have MEL, some don't:

- `trainfitter_mel_support 0` (default) - any addon that lists MEL as required or uses MEL in its code is **rejected automatically**, before it is even downloaded
- `trainfitter_mel_support 1` - enable **only if MEL is really installed**. MEL recipes from the addon then run in the sandbox and MEL picks them up live, no restart

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
| `trainfitter_allow_masks` | 1 | Masks, pults and scripted Metrostroi addons (sandboxed). `0` = skins only |
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
| `trainfitter_allow_full_lua` | 0 | **DANGEROUS**, unsandboxed Lua for whitelisted addons, see above |

Fine knobs (touch only if you know why): `trainfitter_max_lua_kb` (256, 1-4096), `trainfitter_sandbox_instr_m` (100), `trainfitter_reject_bytecode` (1 - reject Lua bytecode in full_lua mode, **don't disable**), `trainfitter_use_http` (0 = auto)

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

**Safe and convenient (default)** - skins and masks, all sandboxed:
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
then `trainfitter_whitelist_add <wsid>` for every trusted addon. Anything not on the whitelist still loads sandboxed

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
- `Server refused to mount <wsid>: ...` - not a bug, the scanner doing its job, reason is in the message
- `addon contains masks/scripts; enable 'trainfitter_allow_masks 1'` - masks are disabled
- `addon requires Metrostroi Extensions Library (MEL)` - enable `trainfitter_mel_support 1` if MEL is really installed
- `addon ships Lua that only works as a full addon` - the addon replaces a whole entity, only the dangerous `trainfitter_allow_full_lua 1` can load it, and only from the whitelist
- `addon tries to replace a base game file` / `malformed file` - the addon overrides game files or ships a broken model/texture, that's the protection working
- `This map session already loaded its maximum of addons` / `You reached your hourly limit` - `trainfitter_max_session_addons` / `trainfitter_max_new_per_hour` kicked in
- `[Trainfitter:<wsid>] sandboxed code error: ...` - a bug in the mask itself, the server is fine
- `[Trainfitter:<wsid>] sandbox disabled: CPU usage too high` - the addon tried to hog the server and was switched off
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

Masker er tilladt som standard (`trainfitter_allow_masks 1`). Al Lua fra addons kører **kun i Trainfitter-sandboxen**: serveren monterer en kopi af GMA'en uden `.lua`-filer, sandboxen har ingen adgang til `RunString`, `file`, `http`, `net`, konsolkommandoer eller spillernes rettigheder, og har grænser for instruktioner, hukommelse og CPU. Tog-tabeller kan ikke ændre rettigheder eller ejerskab (`CanTool`, `CanProperty`, `owner`...), Metrostroi-data og materialer er skrivebeskyttede, og spillere sendt fra sandboxen til serverkode bliver til `NULL`. Kun `materials/`, `models/`, `sound/` og `resource/localization/` beholdes, model- og teksturheadere valideres, og udskiftning af spillets egne filer afvises. Addons der kræver MEL afvises automatisk medmindre `trainfitter_mel_support 1`. `trainfitter_allow_full_lua 1` kører Lua **uden sandbox med fulde serverrettigheder**, men kun for addons på whitelisten

Nye grænser: `trainfitter_max_session_addons` (100 pr. kort), `trainfitter_max_new_per_hour` (20 pr. spiller), `trainfitter_cache_max_gb` (20 GB cache)

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
