# Trainfitter

**Trainfitter** - это аддон для Garry's Mod который позволяет, не залазя в sftp и не дёргая server.cfg по двадцать раз, скармливать игровому серверу скины и (если совсем смело) маски с пультами для **Metrostroi Subway Simulator**. Workshop-ссылка - кнопка Apply - готово, у всех новый поезд. Никакого "перезалейте коллекцию", никаких "перезапусти сервер пять раз", никакого ритуала с бубном

**© SellingVika.** В шапке каждого `.lua` стоит `-- Made by SellingVika` - это не криптозащита и не магия, это **просьба автора**. Форкаешь - оставь, рядом припиши свой ник, спи спокойно. Подробности в [License](#license)

Сайт автора: <https://sellingvika.party/> · Доки: [Русский](#русский) / [English](#english) / [Dansk](#dansk)

---

## Русский

### Зачем

Кагбэ, ставить скин на поезд в Metrostroi - это всегда было через жопу. Подпишись на Workshop, перезапусти клиент, попроси админа перезапустить сервер, всех кикнуть, обновить коллекцию, **внезапно** оказывается что в коллекции этого скина нет, ну ещё раз, потом ещё раз. Прелесть в том что Trainfitter всю эту хуйню убирает. Игрок вставил ссылку в UI, кликнул - скин у всех на сервере, прямо в матче, без рестартов

ИЧСХ аддон не пускает что попало. **Любой школьник который попробует протащить через "скин" sneaky `lua/autorun/*.lua` с бекдором** - получает по щам от семислойного сканера ещё ДО маунта. Подробности в [Безопасности](#безопасность), там доставляет

### Что внутри

- **Один клик - скин на сервере**, без рестартов, без слёз. WSID можно вставить как ссылку, как число, как URL с параметрами - оно само распарсит
- **"В избранное"** - скин становится persistent, после рестарта сервера маунтится автоматом, новым игрокам догоняется тоже автоматом, потому что (ВНЕЗАПНО) так и должно работать
- **Встроенный браузер Workshop** прямо в игре (DHTML-окно). Кнопка Subscribe на странице переименована в "Select for Trainfitter" - кликнул, пошло качаться. Алсо да, это работает
- **Маски** (`lua/metrostroi/masks/*.lua`) и **пульты** поддерживаются, но **только если админ нажал волшебный конвар `trainfitter_allow_full_lua 1`**. Иначе - не пускаем, потому что там Lua-код, а Lua-код = потенциально пиздец. Подробнее в [Безопасности](#безопасность)
- **Точечный hot-reload** - обновляются ТОЛЬКО поезда того кто инициировал. Чужие составы не дёргаются (а то рендер крашится, привет Source engine, золотой движок 2004 года), а если ты сидишь В поезде - твой тоже не трогается (по той же причине)
- **История скачиваний** игрока живёт в `data/trainfitter/client_history.json`, переживает рестарт игры. Каждую запись можно убрать кнопкой, "Очистить историю" - в шапке вкладки
- **Уведомления через `notification.AddProgress`**, а не спам в чат. Чат для общения, а не для логов аддона, это база
- **Три языка**: Русский, English, Dansk. Флажки в дропдауне нарисованы **прямо в Lua** через `surface.DrawRect`, никаких PNG-ассетов, потому что зачем тащить два байта PNG если можно нарисовать
- **Авто-cleanup на каждой смене карты** - всё что не в избранном забывается, GMA-кеш чистится. Persistent остаётся
- **Listen-сервер и dedicated** оба работают. На listen авто-уход в HTTP (нативный `steamworks.DownloadUGC` валит x64-клиент, и это **известный engine-баг** не наш). На dedicated с `gmsv_workshop` - нативный путь, быстрее

### Что нужно

| Сторона | Что |
|---|---|
| Сервер | Garry's Mod DS (Win/Linux, 32/64) либо listen-сервер |
| Сервер | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) - без него вообще нет смысла, **аддон молча скажет "не наш" и откажется работать** |
| Сервер | `gmsv_workshop` DLL в `garrysmod/lua/bin/` - только для dedicated. На listen НЕ нужен (там HTTP-fallback) |
| Сервер | Доступ наружу к `api.steampowered.com`, `*.steamcontent.com` - иначе как ты будешь Workshop опрашивать, через хрустальный шар? |
| Клиент | Garry's Mod (Legacy либо x86-64) - ну ёпта |

LFAdmin / ULX / SAM / любая популярная админка - **опционально**. Без админки идёт через стандартные `IsAdmin()`/`IsSuperAdmin()`. Будет работать в любом случае, но если у тебя ULX - права видны в XGUI и можно крутить

### Поставить

1. **Кинь репо** в `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` должен лежать на одном уровне с `lua/`. Двойная вложенность типа `addons/trainfitter/trainfitter/lua/` - **самая распиздатая причина** "не работает". Если ты сделал именно так - не пиши в issues, посмотри сначала на путь
2. **Для dedicated** - качни [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), положи в `garrysmod/lua/bin/`. Имя файла по битности srcds. На listen этот шаг ИГНОРИРУЕШЬ
3. **Запусти сервер**. В консоли должно появиться:
   ```
   [Trainfitter] gmsv_workshop loaded - server has native steamworks.DownloadUGC.
   Trainfitter v2.2.9 (server)
   ```
   Видишь `gmsv_workshop binary not installed - using HTTP fetch` - это **норма для listen**, на dedicated значит DLL положил не туда (см пункт 2)
4. **Зашёл игроком**, открыл UI командой `trainfitter` (или `bind F3 trainfitter` если ленивый)

### UI

- **Установка** - поле для ссылки/WSID, превью, кнопки Подтвердить / В избранное. "Открыть Мастерскую" поднимает встроенный браузер
- **Избранное** - список persistent-скинов, **single-slot модель** (один активный, остальные не имеют смысла, и да ты можешь крутить `trainfitter_max_persistent` сколько хочешь, оно всё равно >1 игнорит)
- **История** - карточки текущей сессии, на каждой кнопка удаления
- **Настройки** - **только админам с правом `Manage`**. У обычных игроков вкладка вообще не показывается, не подсвечивается, ничего. Если ты не админ и думаешь "почему я не вижу настройки" - именно поэтому

В шапке окна - **переключатель языка** с флажками (нарисованы в Lua) и **"Очистить мой кеш"** (доступно всем, чистит только локально)

### Консоль

| Команда | Кому | Что делает |
|---|---|---|
| `trainfitter` | все | Открыть UI |
| `trainfitter_workshop` | все | Встроенный Workshop-браузер |
| `trainfitter_client_purge` | все | Снести **локальный** кеш (история / превью / GMA) |
| `trainfitter_list` | все | Показать persistent |
| `trainfitter_stats` | все | Топ-20 скачанных wsid |
| `trainfitter_remove <wsid>` | Persistent | Убрать wsid из persistent |
| `trainfitter_reload` | Persistent | Перечитать JSON и пере-маунтить |
| `trainfitter_{whitelist,blacklist}_{add,remove,list}` | Manage | Списки wsid |
| `trainfitter_cache_clear` | Manage | Снести HTTP-кеш `data/trainfitter/gmas/` |
| `trainfitter_forget_all` | Manage | Забыть весь non-persistent в сессии |
| `trainfitter_purge_all` | Manage | **ЯДЕРНАЯ нулёвка** - persistent в ноль, кеш в ноль, runtime в ноль, broadcast forget каждому wsid. Используй когда совсем хочется чистоты |
| `trainfitter_audit [N]` | SuperAdmin | Последние N строк audit-лога (default 30, max 500) с резолвом ников |

### ConVar'ы

**Базовое управление** (`FCVAR_ARCHIVE`, пишутся в `cfg/server.cfg`):

| Convar | Default | Что делает |
|---|---|---|
| `trainfitter_max_mb` | 200 | Размерный лимит аддона в МБ. Больше = отказ ДО скачки. Защита от того что кто-то решит залить 5-гиговый паблик |
| `trainfitter_require_admin` | 0 | `1` = качать может только привилегированный. `0` = все могут (но в safe-режиме только скины) |
| `trainfitter_use_whitelist` | 0 | `1` = разрешены ТОЛЬКО wsid из whitelist.json. Параноидальный режим, рекомендую если ты не доверяешь даже своим админам |
| `trainfitter_request_cooldown` | 2 | Кулдаун (сек) между запросами одного игрока. Защита от спама |
| `trainfitter_audit_log` | 1 | Писать в `data/trainfitter/audit.log`. Включай, потом сам спасибо скажешь когда придётся разбираться "кто что когда" |
| `trainfitter_server_premount` | 1 | Сервер маунтит persistent на старте |
| `trainfitter_use_http` | 0 | `1` = принудительно HTTP, `0` = авто. Меняй только если знаешь зачем |

**Защитные** (`FCVAR_PROTECTED`, **не трогай если не понимаешь**):

- `trainfitter_server_gma_scan` (1) - сканировать ли GMA перед `MountGMA`. **Не выключай**, это и есть защита
- `trainfitter_content_scan` (1) - валидировать ли каждый `.lua` перед `CompileString`. Опять же, **не выключай**
- `trainfitter_gma_scan` (1, клиентский) - клиентский скан

**ОПАСНЫЙ переключатель** `trainfitter_allow_full_lua` (дефолт 0). По дефолту Trainfitter пускает **ТОЛЬКО скины** (`lua/metrostroi/skins/`) - это чистая текстурная дата, безопасно как песочница в детском саду. Включил `1` - теперь можно ставить **маски, пульты, custom SENT, расширенные effects-ы**, словом всё что имеет настоящий Lua-код. Эти файлы запускаются **БЕЗ ПЕСОЧНИЦЫ**, с полными правами сервера. Скины как работали в песочнице - так и работают. Включай только если **доверяешь всем кто может ставить аддоны** - лучше параллельно поставить `trainfitter_use_whitelist 1` и `trainfitter_require_admin 1`. Когда в safe-режиме игрок попытается поставить маску - в консоли увидит подсказку про этот конвар, нытьё в админ-чат не нужно

**Гибкая настройка защиты** (все REPLICATED, дефолты безопасные, но крути если у тебя кейс):

| Convar | Default | Range | Что |
|---|---|---|---|
| `trainfitter_max_lua_kb` | 64 | 1-1024 | Максимальный размер одного addon-lua в КБ. Жёстко клампится (макс 1 МБ). Подними если маски жирнее 64 КБ - бывает, чо |
| `trainfitter_sandbox_instr_m` | 100 | 1-10000 | Лимит инструкций песочницы в миллионах. Подними если тяжёлая инициализация (процедурные текстуры, большие циклы) валится по таймауту |
| `trainfitter_reject_bytecode` | 1 | 0/1 | `1` = режем Lua-байткод (безопасно, по умолч). `0` = пускаем (ВНЕЗАПНО опасно, через байткод можно обойти парсер). Ставь `0` только если ты ВОТ ПРЯМ доверяешь всем источникам, иначе - **не трогай**, серьёзно |

**Клиентские**: `trainfitter_lang` (`ru`/`en`/`da`), `trainfitter_auto_subscribe` (1 = авто-Steam-подписка на Apply, только на listen)

### Права

Проверяются **по очереди**, первый сработавший - победитель. Логика топорная но рабочая:

1. **Ramzi short-circuit** - `ply:IsRamzi()` (LFAdmin-группы `ramzi/meow/rawr/licen`) → true. Если ты в одной из этих групп - ты бог, всё можно
2. **LFAdmin access** - для каждого ключа (`trainfitter_download` `v` / `_persistent` `a` / `_manage` `s`). LFAdmin superadmin → автоматом true (отозвать только удалив LFAdmin)
3. **ULX** через `ULib.ucl.query`. Регистрируются с дефолтами `ACCESS_ALL` / `ACCESS_ADMIN` / `ACCESS_SUPERADMIN`. **Видны в XGUI** - можно выдавать конкретным группам или **отзывать у superadmin** если ты прям параноишь
4. **Fallback** - стандартные `IsAdmin()` / `IsSuperAdmin()`. Работает с любой админкой которая override-ит эти методы (а это все нормальные)

Любое изменение конвара → **broadcast в чат всем**: `[Trainfitter] %s changed %s = %s`. Чтоб все видели кто что крутит

### Безопасность

Несколько независимых слоёв. **Чтобы протащить чужой код через Trainfitter, придётся пробить ВСЁ ОДНОВРЕМЕННО**, что мягко говоря маловероятно. Прелесть в том что каждый слой работает отдельно - даже если один обошли, остальные ловят:

- **Двухуровневый path whitelist.** Safe-режим (дефолт): Lua пускается **только** из `lua/metrostroi/skins/`. Маски, autorun, пульты, `lua/entities/`, `lua/weapons/`, и тем более `gamemodes/`/`bin/`/`data/` - **отказ всего GMA** с подсказкой какой конвар включить. Если админ осознанно поставил `trainfitter_allow_full_lua 1` - whitelist расширяется до `lua/metrostroi/masks/`, `lua/metrostroi/*`, `lua/autorun/`, `lua/entities/`, `lua/weapons/`, `lua/effects/`
- **Extension whitelist.** `.lua`, текстуры, модели, звуки, шрифты, json. `.exe`/`.dll`/`.so`/`.py` - **нахуй, до свидания**. Этот whitelist не настраивается, и слава богу - если у тебя в скине .exe файл, то это уже не скин а малварь
- **Size caps.** Один addon-lua - **64 КБ по умолчанию, настраивается** через `trainfitter_max_lua_kb` (1-1024). Файл - 256 МБ. Весь аддон - 1 ГБ. Максимум 256 lua-файлов. Жёсткие лимиты (256 МБ / 1 ГБ / 256 файлов) **НЕ настраиваются** - они спасают сервер от OOM-DoS если кто-то решит залить 50-гиговый "скин"
- **Marker requirement.** В GMA должен быть хотя бы один `lua/metrostroi/{skins,masks}/*.lua` ЛИБО metrostroi-ассет в `materials/models/sound`. В full-режиме также autorun-lua и `lua/entities/*` считаются - чтоб пульты без скинов проходили. Иначе **это не наш аддон**, до свидания
- **Песочница** (для скинов **всегда**, для масок только в safe-варианте если бы они в safe пропускались). Изолированный env: нет `RunString`/`CompileString`/`dofile`, нет `file.*`/`net.*`/`http.*`/`concommand.*`, нет настоящих entity (только прокси с read-only геттерами), нет `FindMetaTable`/`getmetatable`/`setmetatable` (одну `mt.GetClass` для Entity оставили на всякий, и хватит), нет `string.dump`, нет `hook.Run`/`Call`/`GetTable` (только `Add`/`Remove` с неймспейсом), нет `coroutine`. Lua-байткод (`\27...`) **отвергается на старте** (настраивается `trainfitter_reject_bytecode`). Лимит инструкций по умолчанию 100M (бесконечные циклы умирают), настраивается `trainfitter_sandbox_instr_m`
- **GMA-парсинг руками.** Тела `.lua` читаются **прямо из `.gma` бинарника**, а НЕ через `file.Read` на смонтированные файлы. Прелесть в чём - какой-нибудь анти-чит-хук на `file.Open` (привет lenofag и его `sv_vzlom.lua`) может перехватить и подсунуть honeypot. Мы это обходим, читая байты GMA напрямую
- **Material guard.** `Material("...")` внутри песочницы не пускает `..`, `:`, абсолютные пути. Иначе через `Material("/etc/что-то")` можно было бы получить интересные сюрпризы
- **Rate-limits на каждом net-handler-е**, длины строк чекаются, `ReportSkins` принимает только wsid из активного пайплайна (нельзя зарепортить рандомные id)

Плюс по мелочи: **60с rate-limit на auto-subscribe** (чтоб Apply-спам не засирал Steam-библиотеку), **90с watchdog на mount-queue** (чтоб очередь не залипала если steamworks callback не пришёл), **HTTP body-size guard ДО `file.Write`** (чтоб подменённый file_url не положил диск)

### Как настраивать защиту

Идея простая: **владелец сервера сам решает что важнее - максимальная безопасность или максимальная гибкость**. Trainfitter даёт ручки, ты крутишь. Дефолты выставлены на "безопасно но удобно для скинов"

**Кто что может ставить** - тут две ортогональные оси:

| Что хочешь | Конвар | Эффект |
|---|---|---|
| Только админ может качать | `trainfitter_require_admin 1` | Игроки видят Apply но ловят "нет прав" |
| Только заранее одобренные wsid | `trainfitter_use_whitelist 1` + `trainfitter_whitelist_add` | Даже админ не поставит что не в списке |
| Можно ставить маски и пульты | `trainfitter_allow_full_lua 1` | Иначе только скины (`lua/metrostroi/skins/`) |
| Уменьшить кулдаун между запросами | `trainfitter_request_cooldown N` (сек) | Дефолт 2с, ставь 0 если без паранойи |
| Поднять лимит размера скина | `trainfitter_max_lua_kb N` | Дефолт 64, диапазон 1-1024 |
| Поднять лимит инструкций песочницы | `trainfitter_sandbox_instr_m N` | Дефолт 100M, диапазон 1-10000 |

**Готовые рецепты** (просто кинь в `server.cfg`):

**Паранойя по максимуму** - только то что админ заранее разрешил, никакой свободы:
```
trainfitter_allow_full_lua 0
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Игроки даже скин не поставят пока ты `trainfitter_whitelist_add <wsid>` не сделал. Полный контроль, никаких сюрпризов

**База** - наш дефолт, скины свободно, остальное нет:
```
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
trainfitter_use_whitelist 0
trainfitter_reject_bytecode 1
```
Любой игрок может вкинуть workshop-ссылку со скином. Маски/пульты отвергаются с подсказкой админу. Золотая середина для большинства серверов - и игрокам удобно, и админам нестрашно

**Доверенный круг** - можно ставить пульты и маски, но только админам и только из списка:
```
trainfitter_allow_full_lua 1
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Включил full-lua но обернул whitelist-ом и require_admin - **никто кроме админа не поставит ничего**, плюс админ ограничен whitelist-ом. Самый практичный рецепт если хочется и маски и безопасность

**Фулл-доступ** - всё всем (ТОЛЬКО для тест-серверов, не лей в продакшн):
```
trainfitter_allow_full_lua 1
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```
Любой игрок может поставить любой пульт/SENT/маску. Это **считай что выдал rcon каждому подключившемуся**. На тестах ок, на продакшене - не делай так, плиз

**Что НЕ настраивается** (специально, чтоб ты не выстрелил себе в ногу): жёсткие лимиты (256 МБ на файл, 1 ГБ на аддон, 256 lua-файлов) - они спасают от OOM-DoS, без них любой школьник положит сервак одним толстым GMA. Whitelist расширений (`.lua`/`.vmt`/`.vtf`/`.mdl`/...) тоже не трогается - `.exe`/`.dll`/`.so` в gmod-аддоне быть не должно никогда, точка

### Пример скина

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

Категории: `train` (кузов), `pass` (пасс. салон), `cab` (кабина), `765logo` (эмблема 760-серии)
Текстуры - в `addon/materials/models/my_author/my_skin/*.vmt + .vtf`

**Маска** - то же самое, но в `lua/metrostroi/masks/*.lua`, регится через `Metrostroi.Masks`. Чтобы такой аддон вообще можно было поставить через Trainfitter - сервер должен включить `trainfitter_allow_full_lua 1`. Маски сложнее скинов (содержат код), потому отдельный переключатель, как уже сто раз сказано выше

### Файлы данных

Серверные, `<srcds>/garrysmod/data/trainfitter/`:

- `persistent.json` - активный wsid (single-slot)
- `whitelist.json` / `blacklist.json` - управляемые списки
- `stats.json` - счётчик скачиваний
- `nicks.json` - кеш ников для audit
- `audit.log` (+ `.old`) - пишется **по SteamID64** (а НЕ по нику - чтоб log injection через смену ника не работало, ИЧСХ кто-то пробовал), ротация на 1 МБ
- `gmas/<wsid>.gma` - HTTP-кеш. Non-persistent чистится на каждой смене карты

Клиентские (у игрока):

- `client_history.json` - личная история. Содержит **скрытое поле `apiSource`** в каждой записи (откуда GMA пришла: `steamworks_native` / `shared_cache` / etc) - в UI **не показывается**, но в файле есть для аудита
- `previews/<wsid>.png` - превью

### Если что-то не работает

Открой консоль, ищи строки с `[Trainfitter]`. Самые частые ситуации:

- `gmsv_workshop binary not installed - using HTTP fetch` - на listen-сервере **норма**, на dedicated значит DLL положил не туда (см [Поставить](#поставить))
- `Server refused to mount <wsid>: ...` - **это не баг**, это сканер работает как надо. Причина указана прямо в сообщении, читай её
- `addon contains masks or pults; enable convar 'trainfitter_allow_full_lua 1'` - именно то что написано. Хочешь маски - включи конвар, см [Как настраивать защиту](#как-настраивать-защиту)
- `Cannot mount <wsid>: gmsv_workshop missing and trainfitter_use_http=0` - либо ставь DLL, либо `trainfitter_use_http 1`
- `no file_url in Steam response` - **старые** Workshop-аддоны больше не отдают публичный file_url. Нужна Steam-подписка. На listen Trainfitter подписывается сам, на dedicated - попроси чтобы скачали
- **Краш на Apply под x64** - это **нативный баг `steamworks.DownloadUGC`**, не наш. На listen Trainfitter авто-уходит в HTTP, на dedicated `gmsv_workshop` ОБЯЗАТЕЛЕН

Если что-то не работает и в консоли ничего внятного - проверь что `addon.json` лежит на одном уровне с `lua/`, **двойная вложенность папок самая частая причина "не загружается"**

### License

**Автор:** SellingVika - `sellingvika@gmail.com`. Сайт: <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika, all rights reserved
```

**Полный текст лицензии** - в файле [LICENSE](LICENSE) (custom proprietary, не MIT/GPL, читать целиком). Тут tl;dr для нормальных людей:

**Что можно** (без всяких разрешений):
- Поставить и крутить на своём gmod-сервере бесплатно
- Читать, изучать, инспектировать код
- Делать PR, открывать issue, репортить баги
- Упоминать в обзорах, видео, сборках (со ссылкой на оригинал)
- Тюнить через официальные конвары `trainfitter_*` (для этого они и есть)
- Модифицировать локально для своего сервера (без публичной раздачи)

**Что можно с условиями** (см [LICENSE раздел 2](LICENSE)):
- **Публичный форк** - только если: оставил `-- Made by SellingVika` хедер, добавил свою строку ниже, назвал производным именем (НЕ "Trainfitter"!), в README ссылка на оригинал + CHANGELOG, **не ослаблял защиту**
- **Использование частей кода в других проектах** - с атрибуцией

**Что НЕЛЬЗЯ** (нарушение = автоматическая утрата прав + возможный DMCA + возможный иск):
- **Удалять/менять `-- Made by SellingVika` хедер** в любом `.lua` файле
- **Выдавать аддон за свой** или приписывать авторство себе/команде/третьим лицам
- **Использовать имя "Trainfitter"** для форков (даже "Trainfitter2"/"TrainfitterPlus" - нет)
- **Продавать** оригинал или модификации без письменного разрешения. Включая: премиум-тарифы серверов с этим аддоном, серверные хостинги, обучающие курсы платно, ассет-паки
- **Распространять "ослабленные версии"** где отключены сканер/песочница/whitelist/лимиты/проксирование/rate-limit-ы. Такой форк опасен для пользователей и портит репутацию оригинала
- **Перезаливать в Steam Workshop под своим именем** (на GitHub в форке - можно по условиям выше)
- **Использовать для нарушения** Steam Subscriber Agreement / Garry's Mod ToS / Facepunch policies
- **Вводящая в заблуждение маркировка** ("официальный", "стабильный релиз Trainfitter", "наследник Trainfitter") если такого одобрения у тебя нет

**Форкаешь?** Оставь оригинальный хедер, допиши свой ниже:

```lua
-- Trainfitter - sh_config.lua
-- Made by SellingVika
-- Forked and modified by ТвоёИмя
```

Назови форк **производным именем** (не "Trainfitter") и **не отключай защиту** - иначе твоих пользователей через твой же форк и взломают, оно тебе надо?

**Хочешь коммерчески использовать / встроить в свой продукт / продавать?** Пиши `sellingvika@gmail.com` **ЗАРАНЕЕ**. Отсутствие письменного "да" автоматически = "нет". Часто разрешают, если запрос честный.

**Когда сомневаешься** - читай [LICENSE](LICENSE) целиком (трёхъязычный, RU/EN/DK) или просто спрашивай по почте. Это не страшно

**Зависимости** (имеют свои лицензии, не часть Trainfitter):
[Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) ·
[gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop)

---

## English

**Trainfitter** is a Garry's Mod addon that lets you install skins (and optionally masks/pults) for **Metrostroi Subway Simulator** on a live server without ever touching `server.cfg` again. Paste a Workshop link, hit Apply, everyone sees the new train. No "reupload the collection", no "restart the server five times", no dance with the tambourine

**© SellingVika.** Every `.lua` has a `-- Made by SellingVika` header. It's not crypto-protection or magic, it's just **the author's request**. Forking? Leave it, add your own line nearby, sleep well. See [License](#license)

### Why

Installing a Metrostroi skin has always been miserable. Subscribe on Workshop, restart the client, ask the admin to restart the server, kick everyone, update the collection, **surprise** that skin isn't in the collection, try again, try again. The beauty of Trainfitter is that it just removes all that. Player drops a link in the UI, clicks - everyone sees it, mid-match, no restarts

And the addon doesn't let just anything in. **Any kid who tries to slip a sneaky `lua/autorun/*.lua` backdoor through "a skin"** gets bounced off the seven-layer scanner before the mount even happens. Details in [Security](#security) - it's pretty satisfying

### Features

- **One click and the skin is live** on the server, no restarts. WSID parses from link/number/URL-with-query, all formats
- **"Add to favorites"** makes it persistent - re-mounts on server restart, pushed to new joiners automatically because that's how it should work
- **Embedded Workshop browser** inside the game (DHTML window). Steam's Subscribe button on the page is renamed to "Select for Trainfitter" - one click and it installs. Yes, that actually works
- **Masks** (`lua/metrostroi/masks/*.lua`) and **pults** are supported but **only if the admin enabled `trainfitter_allow_full_lua 1`**. Otherwise no - they contain real Lua and real Lua = potentially trouble. Details in [Security](#security)
- **Targeted hot-reload** - ONLY the initiator's trains visually refresh. Other players' trains aren't touched (otherwise the renderer crashes, hello Source engine), and if you're sitting in a train yours is skipped too (same reason)
- **Player download history** lives in `data/trainfitter/client_history.json`, survives game restart. Per-entry delete button, tab header has "Clear history"
- **Notifications via `notification.AddProgress`**, not chat spam. Chat is for chatting, not for addon logs
- **Three languages**: English, Русский, Dansk. Flags in the dropdown are painted **right in Lua** via `surface.DrawRect`, no PNG assets needed
- **Auto-cleanup on every map change** - non-favorites are forgotten, GMA cache deleted. Persistent stays
- **Listen and dedicated** both work. Listen auto-switches to HTTP (native `steamworks.DownloadUGC` crashes the x64 client, **known engine bug**, not ours). Dedicated with `gmsv_workshop` uses native - faster

### Requirements

| Side | What |
|---|---|
| Server | Garry's Mod DS (Win/Linux, 32/64) or listen |
| Server | [Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) - without it there's no point, **the addon silently says "not ours" and refuses to work** |
| Server | `gmsv_workshop` DLL in `garrysmod/lua/bin/` - dedicated only. NOT needed on listen (HTTP fallback there) |
| Server | Outbound to `api.steampowered.com`, `*.steamcontent.com` - otherwise how are you going to query Workshop, through a crystal ball? |
| Client | Garry's Mod (Legacy or x86-64) |

LFAdmin / ULX / SAM / any popular admin - **optional**. Without it falls back to `IsAdmin()`/`IsSuperAdmin()`. Works either way

### Install

1. **Drop the repo** into `<srcds>/garrysmod/addons/trainfitter/`. `addon.json` must sit next to `lua/`. Double-nesting like `addons/trainfitter/trainfitter/lua/` is **the single most common reason** for "doesn't work". If you did that, don't open an issue, check the path first
2. **For dedicated** - grab [gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop/releases), drop in `garrysmod/lua/bin/`. Filename matches srcds bitness. On listen, SKIP this step
3. **Start the server**, console should show:
   ```
   [Trainfitter] gmsv_workshop loaded - server has native steamworks.DownloadUGC.
   Trainfitter v2.2.9 (server)
   ```
   See `gmsv_workshop binary not installed - using HTTP fetch` - **normal on listen**, on dedicated means the DLL is in the wrong place (see step 2)
4. **Connect as a player**, open UI with `trainfitter` (or `bind F3 trainfitter` if you're lazy)

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

**Main controls**:

| Convar | Default | What |
|---|---|---|
| `trainfitter_max_mb` | 200 | Addon size cap MB. Larger rejected before download |
| `trainfitter_require_admin` | 0 | `1` = only privileged players can download |
| `trainfitter_use_whitelist` | 0 | `1` = only wsids from whitelist.json |
| `trainfitter_request_cooldown` | 2 | Cooldown (sec) between requests from same player |
| `trainfitter_audit_log` | 1 | Write to `data/trainfitter/audit.log` |
| `trainfitter_server_premount` | 1 | Server pre-mounts persistent on boot |
| `trainfitter_use_http` | 0 | `1` = force HTTP, `0` = auto |

**Protected** (don't touch unless you know): `trainfitter_server_gma_scan`, `trainfitter_content_scan`, `trainfitter_gma_scan`. All 1 by default - that IS the security

**DANGEROUS toggle** `trainfitter_allow_full_lua` (default 0). By default Trainfitter only accepts **skins** (`lua/metrostroi/skins/`) - pure texture data, safe. Flip it to `1` and you can install **masks, pults, custom SENTs, advanced effects** - anything with real Lua. Those files run **UNSANDBOXED**, with full server permissions. Skins keep their sandbox. Only enable if **you fully trust everyone who can install addons** - better also set `trainfitter_use_whitelist 1` and `trainfitter_require_admin 1`. In safe mode, when a player tries to install a mask, they see a console hint about this convar

**Tunable security knobs** (all REPLICATED, defaults are safe but tweak if your case needs it):

| Convar | Default | Range | What |
|---|---|---|---|
| `trainfitter_max_lua_kb` | 64 | 1-1024 | Per addon-lua size cap in KB. Hard-clamped. Raise if your masks are bigger than 64 KB |
| `trainfitter_sandbox_instr_m` | 100 | 1-10000 | Sandbox instruction limit in millions. Raise if a heavy mask init (procedural textures, big loops) hits the limit |
| `trainfitter_reject_bytecode` | 1 | 0/1 | `1` = reject Lua bytecode (default, safe). `0` = allow (DANGEROUS, bytecode bypasses parser-level defenses) |

Client: `trainfitter_lang`, `trainfitter_auto_subscribe`

### Permissions

Checked in order, first hit wins:

1. **Ramzi short-circuit** - `ply:IsRamzi()` (LFAdmin groups `ramzi/meow/rawr/licen`) → true. You're a god
2. **LFAdmin access** - for each key (`trainfitter_download` `v` / `_persistent` `a` / `_manage` `s`). LFAdmin superadmin → auto-true (revoke only by removing LFAdmin)
3. **ULX** via `ULib.ucl.query`. Default `ACCESS_ALL` / `ACCESS_ADMIN` / `ACCESS_SUPERADMIN`. **Visible in XGUI** - grant to specific groups or revoke from superadmin
4. **Fallback** - standard `IsAdmin()` / `IsSuperAdmin()`. Works with any admin mod that overrides these (every popular one does)

Any convar change → **chat broadcast to all**: `[Trainfitter] %s changed %s = %s`

### Security

Multiple independent layers. **To smuggle code through Trainfitter, you'd have to break ALL of them at once**, which is unlikely to put it mildly. Each layer works independently - even if one is bypassed, the others catch it:

- **Two-tier path whitelist.** Safe mode (default): Lua only from `lua/metrostroi/skins/`. Masks, autorun, pults, `lua/entities/`, `lua/weapons/`, `gamemodes/`/`bin/`/`data/` - **whole GMA rejected** with a hint pointing to the convar. With `trainfitter_allow_full_lua 1` - expands to masks/, autorun/, entities/, weapons/, effects/
- **Extension whitelist.** `.lua`, textures, models, sounds, fonts, json. `.exe`/`.dll`/`.so`/`.py` - **fuck off**. Not tunable, thank god - if your "skin" has a .exe it's malware not a skin
- **Size caps.** Per addon-lua: **64 KB default, tunable** via `trainfitter_max_lua_kb` (1-1024). Per file: 256 MB. Per addon total: 1 GB. Max 256 lua files. Hard limits (256 MB / 1 GB / 256 files) NOT tunable - they save you from OOM-DoS if someone tries a 50-gig "skin"
- **Marker requirement.** Must contain at least one `lua/metrostroi/{skins,masks}/*.lua` OR metrostroi asset in `materials/models/sound`. In full mode also autorun-lua and `lua/entities/*` count - so pult-only addons pass. Otherwise it's not our addon, bye
- **Sandbox** (skins always, masks too if they were even allowed in safe). Isolated env: no `RunString`/`CompileString`/`dofile`, no `file.*`/`net.*`/`http.*`/`concommand.*`, no real entities (only proxies with read-only getters), no `FindMetaTable`/`getmetatable`/`setmetatable` (one `mt.GetClass` for Entity kept, that's it), no `string.dump`, no `hook.Run`/`Call`/`GetTable` (only namespaced `Add`/`Remove`), no `coroutine`. Lua bytecode (`\27...`) **rejected on the spot** (tunable via `trainfitter_reject_bytecode`). Instruction limit default 100M (infinite loops die fast), tunable via `trainfitter_sandbox_instr_m`
- **GMA parsed by hand.** Lua bodies read **directly from the `.gma` binary**, not via `file.Read` on mounted files. The beauty is that some anti-cheat hook on `file.Open` (hello lenofag and his `sv_vzlom.lua`) could intercept and feed honeypot. We bypass by reading GMA bytes directly
- **Material guard.** `Material("...")` inside sandbox blocks `..`, `:`, absolute paths
- **Rate-limits on every net handler**, string lengths checked, `ReportSkins` only accepts wsids already in the active pipeline

Plus: **60s rate-limit on auto-subscribe**, **90s watchdog on mount-queue**, **HTTP body-size guard before `file.Write`**

### How to configure security

Idea is simple: **server owner decides what matters more - max security or max flexibility**. Trainfitter gives you the knobs, you turn them. Defaults are "safe but convenient for skins"

**Who can install what** - two orthogonal axes:

| What you want | Convar | Effect |
|---|---|---|
| Only admins can download | `trainfitter_require_admin 1` | Players see Apply but get "no perm" |
| Only pre-approved wsids | `trainfitter_use_whitelist 1` + manual `trainfitter_whitelist_add` | Even admins can't install anything off the list |
| Allow masks and pults | `trainfitter_allow_full_lua 1` | Otherwise only skins (`lua/metrostroi/skins/`) |
| Lower request cooldown | `trainfitter_request_cooldown N` (sec) | Default 2s, set 0 if no paranoia |
| Bigger skin lua cap | `trainfitter_max_lua_kb N` | Default 64, range 1-1024 |
| Bigger sandbox instruction limit | `trainfitter_sandbox_instr_m N` | Default 100M, range 1-10000 |

**Ready-made recipes** (drop into `server.cfg`):

**Max paranoia** - only what admin pre-approved, no freedom:
```
trainfitter_allow_full_lua 0
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Players can't install a skin until you `trainfitter_whitelist_add <wsid>`. Full control, no surprises

**Standard** - our default, skins free, rest blocked:
```
trainfitter_allow_full_lua 0
trainfitter_require_admin 0
trainfitter_use_whitelist 0
trainfitter_reject_bytecode 1
```
Any player can paste a workshop link with a skin. Masks/pults rejected with a hint. Golden middle for most servers

**Trusted circle** - masks/pults allowed but only for admins and from a list:
```
trainfitter_allow_full_lua 1
trainfitter_use_whitelist 1
trainfitter_require_admin 1
trainfitter_reject_bytecode 1
```
Enabled full-lua but wrapped in whitelist+require_admin - **nobody but admins can install anything**, plus admins limited to whitelist. Most practical recipe if you want both masks and security

**Anarchy** - everyone everything (TEST SERVERS ONLY, don't ship this):
```
trainfitter_allow_full_lua 1
trainfitter_require_admin 0
trainfitter_use_whitelist 0
```
Any player can install any pult/SENT/mask. Basically gave rcon to everyone. OK on tests, never production

**What's NOT tunable** (on purpose): hard limits (256 MB per file, 1 GB per addon, 256 lua files) - they save you from OOM-DoS, without them any kid kills the server with one fat GMA. Extension whitelist (`.lua`/`.vmt`/`.vtf`/`.mdl`/...) also not touchable - `.exe`/`.dll`/`.so` should never appear in a gmod addon, period

### Skin example

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

Categories: `train` (body), `pass` (passenger), `cab` (cabin), `765logo` (760-series emblem)
Textures in `addon/materials/models/my_author/my_skin/*.vmt + .vtf`

**Mask** - same but under `lua/metrostroi/masks/*.lua`, registered via `Metrostroi.Masks`. To install one through Trainfitter, the server must enable `trainfitter_allow_full_lua 1`. Masks are more complex than skins (they contain code), hence the separate toggle as mentioned above

### Data files

Server-side, `<srcds>/garrysmod/data/trainfitter/`:

- `persistent.json` - active wsid (single-slot)
- `whitelist.json` / `blacklist.json` - managed lists
- `stats.json` - download counter
- `nicks.json` - nick cache for audit
- `audit.log` (+ `.old`) - **SteamID64-keyed** (not nick - so log injection via nick change doesn't work, yes someone tried), rotates at 1 MB
- `gmas/<wsid>.gma` - HTTP cache. Non-persistent cleared on every map change

Client-side (on player's machine):

- `client_history.json` - personal history. Contains a **hidden `apiSource` field** in each entry (where the GMA came from: `steamworks_native` / `shared_cache` / etc) - NOT shown in UI, kept in the file for audit
- `previews/<wsid>.png` - preview cache

### If something breaks

Open the console, look for `[Trainfitter]` lines:

- `gmsv_workshop binary not installed - using HTTP fetch` - **normal** on listen, on dedicated means the DLL is misplaced (see [Install](#install))
- `Server refused to mount <wsid>: ...` - **not a bug**, scanner doing its job. Reason is in the message, read it
- `addon contains masks or pults; enable convar 'trainfitter_allow_full_lua 1'` - exactly what it says. Want masks - enable the convar, see [How to configure security](#how-to-configure-security)
- `Cannot mount <wsid>: gmsv_workshop missing and trainfitter_use_http=0` - install DLL or set `trainfitter_use_http 1`
- `no file_url in Steam response` - **old** Workshop addons no longer expose public file_url. Steam subscription needed. Trainfitter handles it on listen, on dedicated ask someone to subscribe
- **Crash on Apply on x64** - **native `steamworks.DownloadUGC` bug**, not ours. Listen auto-switches to HTTP, dedicated needs `gmsv_workshop` mandatory

If something breaks and the console is silent - check that `addon.json` sits next to `lua/`, **double-nesting is the most common reason for "doesn't load"**

### License

**Author:** SellingVika - `sellingvika@gmail.com`. Site: <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika, all rights reserved
```

**Full license text** is in the [LICENSE](LICENSE) file (custom proprietary, not MIT/GPL, read it in full). Here is the tl;dr:

**What's allowed** (no further permission needed):
- Install and run on your own gmod server, free
- Read, study, audit the code
- Submit PRs, open issues, file bug reports
- Mention in reviews, videos, server collections (with credit + link)
- Tune via official `trainfitter_*` convars (that's what they exist for)
- Modify your local copy for personal use (without public redistribution)

**Allowed with conditions** (see [LICENSE section 2](LICENSE)):
- **Public forks** only if: kept the `-- Made by SellingVika` header, added your own line below, used a derived name (NOT "Trainfitter"!), README links to original + CHANGELOG, **didn't weaken any security mechanism**
- **Reusing code parts in other projects** with attribution

**Strictly forbidden** (violation = automatic loss of rights + possible DMCA + possible lawsuit):
- **Removing/altering the `-- Made by SellingVika` header** in any `.lua` file
- **Claiming authorship** for yourself / your team / any third party
- **Reusing the name "Trainfitter"** for forks (even "Trainfitter2"/"TrainfitterPlus" - no)
- **Selling** original or modifications without written permission. Includes: server premium tiers with this addon, server hosting offerings, paid courses, asset packs
- **Distributing "weakened versions"** where scanner/sandbox/whitelist/limits/proxying/rate-limits are disabled. Such a fork is dangerous to its users and damages the original's reputation
- **Reuploading to Steam Workshop under your own name** (on GitHub as a fork - allowed under above conditions)
- **Using to violate** Steam Subscriber Agreement / Garry's Mod ToS / Facepunch policies
- **Deceptive labeling** ("official", "stable Trainfitter release", "Trainfitter successor") without actual endorsement

**Forking?** Keep the original header, add yours below:

```lua
-- Trainfitter - sh_config.lua
-- Made by SellingVika
-- Forked and modified by YourName
```

Pick a **derived name** (not "Trainfitter") and **don't disable the security** - otherwise your own users will get hacked through your fork, do you really want that?

**Want to use commercially / embed in your product / sell?** Email `sellingvika@gmail.com` **BEFORE** using. No written "yes" automatically means "no". Permission is often granted for honest requests.

**When in doubt** - read the full [LICENSE](LICENSE) (trilingual EN/RU/DK) or just email and ask. It's not scary

**Dependencies** (own licenses, not part of Trainfitter):
[Metrostroi Subway Simulator](https://steamcommunity.com/workshop/filedetails/?id=261801217) ·
[gmsv_workshop](https://github.com/WilliamVenner/gmsv_workshop)

---

## Dansk

**Trainfitter** lader dig installere skins (og valgfrit masker/pults) til **Metrostroi Subway Simulator** på live server, uden at røre `server.cfg`. Spilleren smider et Workshop-link, trykker Apply, alle ser det nye tog. Ingen "upload samlingen igen", ingen "genstart serveren fem gange", ingen tamburin-dans

**© SellingVika.** Hver `.lua` har en `-- Made by SellingVika` header. Det er hverken crypto-beskyttelse eller magi, bare **forfatterens anmodning**. Forker du? Behold den, tilføj din egen ved siden af, sov roligt

### Hvad det gør

Åbn UI, indsæt workshop-link eller WSID, tryk Apply - GMA downloades, valideres, monteres, alle ser det. Ingen "genstart serveren"-dans

Addonet **lukker ikke bare alt ind**: parser GMA i hånden, validerer stier/filtyper/størrelser, kører bruger-lua i en sandbox. SWEP-pakker og bagdøre via `lua/autorun/*.lua` ryger på syvende lag af scannerens forsvar

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

Flere uafhængige lag: to-tier path whitelist, extension whitelist, størrelsesgrænser, sandbox med proxy-entities og uden farlige API'er, GMA parses i hånden, rate-limits på net-handlers. Detaljer på engelsk eller russisk

Skins kører altid sandboxed. Masker og pults kræver `trainfitter_allow_full_lua 1` for overhovedet at blive installeret - de indeholder rigtig Lua-kode og kører ud af sandbox, så aktivér kun hvis du stoler på alle der kan installere addons

### License

**Forfatter:** SellingVika - `sellingvika@gmail.com`. Site: <https://sellingvika.party/>

```
Copyright (c) 2026 SellingVika, all rights reserved
```

Fuld licenstekst i [LICENSE](LICENSE)-filen (custom proprietær, ikke MIT/GPL, trilingual EN/RU/DK)

**Tilladt:** Brug på din server gratis, læs koden, indsend PR/bug-reports, omtale i reviews med kredit, justering via officielle convars, personlige modifikationer for egen brug

**Tilladt med betingelser:** Offentlige forks med bevaret `-- Made by SellingVika` header + afledt navn (ikke "Trainfitter") + link til original + uændrede sikkerhedsmekanismer

**Forbudt:** Fjerne header, hævde at være forfatteren, bruge navnet "Trainfitter" til forks, kommerciel brug uden tilladelse, distribuere svækkede sikkerhedsversioner, uploade til Steam Workshop under dit eget navn, vildledende mærkning

Overtrædelse = automatisk ophør af alle rettigheder + mulig DMCA + mulig retssag

For kommercielle tilladelser: skriv til `sellingvika@gmail.com` FØR brug

---

**Trainfitter** © SellingVika
