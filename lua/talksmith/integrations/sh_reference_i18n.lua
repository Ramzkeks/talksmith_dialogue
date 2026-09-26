local TS = Talksmith

local semantics = {
    ru = {
        sources = {
            core = "Talksmith",
            darkrp = "DarkRP",
            inventory = "Выбранная интеграция инвентаря",
            currency = "Выбранная валютная интеграция",
        },
        actions = {
            start_combat = { name = "VJ: начать бой с собеседником", description = "Завершает разговор и начинает бой с этим игроком. Убийство владельцем — успех; его смерть или выход — провал. Единственное действие в списке. Источник: %s." },
            spawn_target = { name = "VJ: создать персональную цель", description = "Создаёт VJ NPC с диалогом на указанной карте и в точных координатах. Занятая точка отклоняется. Единственное действие в списке. Источник: %s." },
            add = { name = "Добавить валюту", description = "Начисляет игроку указанное количество валюты. Источник: %s." },
            add_levels = { name = "Добавить уровни", description = "Повышает уровень игрока на указанное количество. Источник: %s." },
            add_points = { name = "Добавить очки", description = "Начисляет игроку указанное количество очков. Источник: %s." },
            add_xp = { name = "Добавить опыт", description = "Начисляет игроку указанное количество опыта. Источник: %s." },
            change_job = { name = "Сменить профессию", description = "Переводит игрока на разрешённую профессию DarkRP. Источник: %s." },
            change_team = { name = "Сменить команду", description = "Переводит игрока в разрешённую команду. Источник: %s." },
            clear_flag = { name = "Снять флаг", description = "Удаляет сохранённый флаг у игрока. Источник: %s." },
            close_dialogue = { name = "Закрыть диалог", description = "Завершает текущий диалог сразу после выполнения цепочки. Источник: %s." },
            emit_event = { name = "Вызвать событие", description = "Вызывает серверное событие Talksmith с указанными именем и данными. Источник: %s." },
            give_ammo = { name = "Выдать боеприпасы", description = "Добавляет игроку указанный тип и количество боеприпасов. Источник: %s." },
            give_armor = { name = "Добавить броню", description = "Увеличивает запас брони игрока на указанное значение. Источник: %s." },
            give_health = { name = "Восстановить здоровье", description = "Увеличивает здоровье игрока, не превышая его максимум. Источник: %s." },
            give_item = { name = "Выдать предмет", description = "Добавляет указанный предмет в инвентарь игрока. Источник: %s." },
            give_money = { name = "Выдать деньги", description = "Начисляет игроку указанную сумму денег DarkRP. Источник: %s." },
            give_weapon = { name = "Выдать оружие", description = "Выдаёт игроку оружие разрешённого класса. Источник: %s." },
            open = { name = "Открыть инвентарь", description = "Открывает интерфейс инвентаря для игрока. Источник: %s." },
            open_dialogue = { name = "Перейти в другой диалог", description = "Завершает текущий документ и открывает указанный диалог. Источник: %s." },
            open_inventory = { name = "Открыть инвентарь", description = "Открывает интерфейс инвентаря для игрока. Источник: %s." },
            open_shop = { name = "Открыть магазин", description = "Открывает интерфейс магазина для игрока. Источник: %s." },
            pass_selected_answer = { name = "Передать выбранный ответ", description = "Передаёт индекс выбранного ответа на выход Wiremod. Источник: %s." },
            play_sound = { name = "Проиграть звук", description = "Проигрывает игроку разрешённый локальный звук. Источник: %s." },
            pulse_output = { name = "Послать импульс на выход", description = "Кратковременно активирует указанный выход Wiremod. Источник: %s." },
            send_string = { name = "Передать строку на выход", description = "Передаёт указанную строку на выход Wiremod. Источник: %s." },
            set_flag = { name = "Установить флаг", description = "Сохраняет у игрока флаг с указанными ключом и значением. Источник: %s." },
            set_level = { name = "Установить уровень", description = "Устанавливает игроку точное значение уровня. Источник: %s." },
            set_output = { name = "Установить значение выхода", description = "Записывает указанное значение в выход Wiremod. Источник: %s." },
            strip_weapon = { name = "Забрать оружие", description = "Удаляет у игрока оружие указанного класса. Источник: %s." },
            take = { name = "Списать валюту", description = "Списывает у игрока указанное количество валюты. Источник: %s." },
            take_ammo = { name = "Забрать боеприпасы", description = "Удаляет у игрока указанный тип и количество боеприпасов. Источник: %s." },
            take_item = { name = "Забрать предмет", description = "Удаляет указанный предмет из инвентаря игрока. Источник: %s." },
            take_money = { name = "Забрать деньги", description = "Списывает у игрока указанную сумму денег DarkRP. Источник: %s." },
            take_points = { name = "Списать очки", description = "Списывает у игрока указанное количество очков. Источник: %s." },
            take_weapon = { name = "Забрать оружие", description = "Удаляет у игрока оружие разрешённого класса. Источник: %s." },
            take_xp = { name = "Списать опыт", description = "Уменьшает опыт игрока на указанное количество. Источник: %s." },
        },
        conditions = {
            can_edit_dialogues = { name = "Может редактировать диалоги", description = "Проверяет наличие права на редактирование диалогов Talksmith. Источник: %s." },
            can_level_up = { name = "Может повысить уровень", description = "Проверяет, достаточно ли игроку опыта для следующего уровня. Источник: %s." },
            does_not_have_weapon = { name = "Нет оружия", description = "Проверяет, что у игрока нет оружия указанного разрешённого класса. Источник: %s." },
            faction_is = { name = "Фракция совпадает", description = "Проверяет текущую фракцию выбранного персонажа. Источник: %s." },
            flag_is_not_set = { name = "Флаг не установлен", description = "Проверяет, что указанный флаг игрока отсутствует или выключен. Источник: %s." },
            flag_is_set = { name = "Флаг установлен", description = "Проверяет, что указанный флаг игрока существует и включён. Источник: %s." },
            has_access = { name = "Есть право доступа", description = "Проверяет наличие у игрока указанного права доступа. Источник: %s." },
            has_ammo = { name = "Есть боеприпасы", description = "Проверяет наличие у игрока указанного типа и количества боеприпасов. Источник: %s." },
            has_amount = { name = "Достаточно валюты", description = "Проверяет, что баланс игрока не меньше указанной суммы. Источник: %s." },
            has_free_weight = { name = "Достаточно свободного веса", description = "Проверяет, выдержит ли инвентарь игрока указанный дополнительный вес. Источник: %s." },
            has_item = { name = "Есть предмет", description = "Проверяет наличие указанного предмета в инвентаре игрока. Источник: %s." },
            has_money = { name = "Достаточно денег", description = "Проверяет, что у игрока достаточно денег DarkRP. Источник: %s." },
            has_space = { name = "Есть свободное место", description = "Проверяет, достаточно ли места для указанного предмета. Источник: %s." },
            has_weapon = { name = "Есть оружие", description = "Проверяет наличие у игрока оружия указанного класса. Источник: %s." },
            health_above = { name = "Здоровье выше значения", description = "Проверяет, что здоровье игрока строго выше указанного значения. Источник: %s." },
            health_below = { name = "Здоровье ниже значения", description = "Проверяет, что здоровье игрока строго ниже указанного значения. Источник: %s." },
            id_is = { name = "ID персонажа совпадает", description = "Проверяет ID выбранного персонажа. Источник: %s." },
            index_is = { name = "Индекс персонажа совпадает", description = "Проверяет индекс выбранного персонажа. Источник: %s." },
            input_active = { name = "Вход активен", description = "Проверяет, что указанный вход Wiremod активен. Источник: %s." },
            input_equals = { name = "Вход равен значению", description = "Сравнивает значение указанного входа Wiremod с заданным значением. Источник: %s." },
            input_greater = { name = "Вход больше значения", description = "Проверяет, что значение входа Wiremod больше заданного. Источник: %s." },
            input_inactive = { name = "Вход неактивен", description = "Проверяет, что указанный вход Wiremod неактивен. Источник: %s." },
            is_admin = { name = "Игрок — администратор", description = "Проверяет, имеет ли игрок статус администратора сервера. Источник: %s." },
            is_cp = { name = "Состоит в гражданской защите", description = "Проверяет, относится ли профессия игрока к гражданской защите DarkRP. Источник: %s." },
            is_day = { name = "Сейчас день", description = "Проверяет, что на карте сейчас дневное время. Источник: %s." },
            is_foggy = { name = "Есть туман", description = "Проверяет наличие тумана в текущей погоде. Источник: %s." },
            is_full = { name = "Инвентарь заполнен", description = "Проверяет, что в инвентаре игрока больше нет свободного места. Источник: %s." },
            is_job = { name = "Профессия DarkRP совпадает", description = "Проверяет команду текущей профессии игрока DarkRP. Источник: %s." },
            is_night = { name = "Сейчас ночь", description = "Проверяет, что на карте сейчас ночное время. Источник: %s." },
            is_raining = { name = "Идёт дождь", description = "Проверяет наличие дождя в текущей погоде. Источник: %s." },
            is_snowing = { name = "Идёт снег", description = "Проверяет наличие снега в текущей погоде. Источник: %s." },
            item_allowed = { name = "Предмет разрешён", description = "Проверяет, разрешена ли работа с указанным предметом. Источник: %s." },
            item_equipped = { name = "Предмет экипирован", description = "Проверяет, экипирован ли указанный предмет игроком. Источник: %s." },
            job_is = { name = "Профессия персонажа совпадает", description = "Проверяет профессию выбранного персонажа. Источник: %s." },
            level_at_least = { name = "Уровень не ниже", description = "Проверяет, что уровень игрока не меньше указанного. Источник: %s." },
            level_at_most = { name = "Уровень не выше", description = "Проверяет, что уровень игрока не больше указанного. Источник: %s." },
            name_is = { name = "Имя персонажа совпадает", description = "Проверяет имя выбранного персонажа. Источник: %s." },
            points_at_least = { name = "Достаточно очков", description = "Проверяет, что у игрока не меньше указанного количества очков. Источник: %s." },
            random_chance = { name = "Случайный шанс", description = "Пропускает условие с указанной вероятностью от 0 до 1. Источник: %s." },
            ready = { name = "Персонаж выбран", description = "Проверяет, что игрок загрузил и выбрал персонажа. Источник: %s." },
            team_is = { name = "Команда совпадает", description = "Проверяет, что игрок состоит в указанной команде. Источник: %s." },
            team_is_not = { name = "Команда не совпадает", description = "Проверяет, что игрок не состоит в указанной команде. Источник: %s." },
            temperature_at_least = { name = "Температура не ниже", description = "Проверяет, что текущая температура не ниже указанной. Источник: %s." },
            temperature_at_most = { name = "Температура не выше", description = "Проверяет, что текущая температура не выше указанной. Источник: %s." },
            usergroup_is = { name = "Группа пользователя совпадает", description = "Проверяет текущую группу пользователя. Источник: %s." },
            weather_is = { name = "Погода совпадает", description = "Проверяет идентификатор текущей погоды. Источник: %s." },
            xp_at_least = { name = "Достаточно опыта", description = "Проверяет, что у игрока не меньше указанного количества опыта. Источник: %s." },
        },
    },
    en = {
        sources = {
            core = "Talksmith",
            darkrp = "DarkRP",
            inventory = "Selected inventory provider",
            currency = "Selected currency provider",
        },
        actions = {
            add = { name = "Add currency", description = "Credits the specified currency amount to the player. Source: %s." },
            add_levels = { name = "Add levels", description = "Increases the player's level by the specified amount. Source: %s." },
            add_points = { name = "Add points", description = "Credits the specified number of points to the player. Source: %s." },
            add_xp = { name = "Add experience", description = "Credits the specified amount of experience to the player. Source: %s." },
            change_job = { name = "Change job", description = "Moves the player to an allowed DarkRP job. Source: %s." },
            change_team = { name = "Change team", description = "Moves the player to an allowed team. Source: %s." },
            clear_flag = { name = "Clear flag", description = "Removes a stored flag from the player. Source: %s." },
            close_dialogue = { name = "Close dialogue", description = "Ends the current dialogue after the action chain completes. Source: %s." },
            emit_event = { name = "Emit event", description = "Runs a server-side Talksmith event with the specified name and data. Source: %s." },
            give_ammo = { name = "Give ammo", description = "Adds the specified ammo type and amount to the player. Source: %s." },
            give_armor = { name = "Add armor", description = "Increases the player's armor by the specified amount. Source: %s." },
            give_health = { name = "Restore health", description = "Increases the player's health without exceeding its maximum. Source: %s." },
            give_item = { name = "Give item", description = "Adds the specified item to the player's inventory. Source: %s." },
            give_money = { name = "Give money", description = "Credits the specified DarkRP money amount to the player. Source: %s." },
            give_weapon = { name = "Give weapon", description = "Gives the player an allowed weapon class. Source: %s." },
            open = { name = "Open inventory", description = "Opens the inventory interface for the player. Source: %s." },
            open_dialogue = { name = "Open another dialogue", description = "Leaves the current document and opens the specified dialogue. Source: %s." },
            open_inventory = { name = "Open inventory", description = "Opens the inventory interface for the player. Source: %s." },
            open_shop = { name = "Open shop", description = "Opens the shop interface for the player. Source: %s." },
            pass_selected_answer = { name = "Pass selected answer", description = "Sends the selected response index to a Wiremod output. Source: %s." },
            play_sound = { name = "Play sound", description = "Plays an allowed local sound for the player. Source: %s." },
            pulse_output = { name = "Pulse output", description = "Briefly activates the specified Wiremod output. Source: %s." },
            send_string = { name = "Send string", description = "Sends the specified string to a Wiremod output. Source: %s." },
            set_flag = { name = "Set flag", description = "Stores a flag with the specified key and value on the player. Source: %s." },
            set_level = { name = "Set level", description = "Sets the player's exact level value. Source: %s." },
            set_output = { name = "Set output value", description = "Writes the specified value to a Wiremod output. Source: %s." },
            strip_weapon = { name = "Take weapon", description = "Removes the specified weapon class from the player. Source: %s." },
            take = { name = "Take currency", description = "Deducts the specified currency amount from the player. Source: %s." },
            take_ammo = { name = "Take ammo", description = "Removes the specified ammo type and amount from the player. Source: %s." },
            take_item = { name = "Take item", description = "Removes the specified item from the player's inventory. Source: %s." },
            take_money = { name = "Take money", description = "Deducts the specified DarkRP money amount from the player. Source: %s." },
            take_points = { name = "Take points", description = "Deducts the specified number of points from the player. Source: %s." },
            take_weapon = { name = "Take weapon", description = "Removes an allowed weapon class from the player. Source: %s." },
            take_xp = { name = "Take experience", description = "Reduces the player's experience by the specified amount. Source: %s." },
        },
        conditions = {
            can_edit_dialogues = { name = "Can edit dialogues", description = "Checks whether the player may edit Talksmith dialogues. Source: %s." },
            can_level_up = { name = "Can level up", description = "Checks whether the player has enough experience for the next level. Source: %s." },
            does_not_have_weapon = { name = "Does not have weapon", description = "Checks that the player does not have the specified allowed weapon class. Source: %s." },
            faction_is = { name = "Character faction matches", description = "Checks the selected character's current faction. Source: %s." },
            flag_is_not_set = { name = "Flag is not set", description = "Checks that the player's specified flag is missing or disabled. Source: %s." },
            flag_is_set = { name = "Flag is set", description = "Checks that the player's specified flag exists and is enabled. Source: %s." },
            has_access = { name = "Has access", description = "Checks whether the player has the specified access right. Source: %s." },
            has_ammo = { name = "Has ammo", description = "Checks whether the player has the specified ammo type and amount. Source: %s." },
            has_amount = { name = "Has enough currency", description = "Checks that the player's balance is at least the specified amount. Source: %s." },
            has_free_weight = { name = "Has enough free weight", description = "Checks whether the inventory can carry the specified additional weight. Source: %s." },
            has_item = { name = "Has item", description = "Checks whether the player's inventory contains the specified item. Source: %s." },
            has_money = { name = "Has enough money", description = "Checks whether the player has enough DarkRP money. Source: %s." },
            has_space = { name = "Has free space", description = "Checks whether there is enough room for the specified item. Source: %s." },
            has_weapon = { name = "Has weapon", description = "Checks whether the player has the specified weapon class. Source: %s." },
            health_above = { name = "Health is above value", description = "Checks that the player's health is strictly above the specified value. Source: %s." },
            health_below = { name = "Health is below value", description = "Checks that the player's health is strictly below the specified value. Source: %s." },
            id_is = { name = "Character ID matches", description = "Checks the selected character's ID. Source: %s." },
            index_is = { name = "Character index matches", description = "Checks the selected character's index. Source: %s." },
            input_active = { name = "Input is active", description = "Checks that the specified Wiremod input is active. Source: %s." },
            input_equals = { name = "Input equals value", description = "Compares the specified Wiremod input with the configured value. Source: %s." },
            input_greater = { name = "Input is greater than value", description = "Checks that the Wiremod input is greater than the configured value. Source: %s." },
            input_inactive = { name = "Input is inactive", description = "Checks that the specified Wiremod input is inactive. Source: %s." },
            is_admin = { name = "Player is an administrator", description = "Checks whether the player is a server administrator. Source: %s." },
            is_cp = { name = "Is Civil Protection", description = "Checks whether the player's DarkRP job belongs to Civil Protection. Source: %s." },
            is_day = { name = "It is daytime", description = "Checks whether the map is currently in daytime. Source: %s." },
            is_foggy = { name = "It is foggy", description = "Checks whether the current weather contains fog. Source: %s." },
            is_full = { name = "Inventory is full", description = "Checks that the player's inventory has no free space left. Source: %s." },
            is_job = { name = "DarkRP job matches", description = "Checks the command of the player's current DarkRP job. Source: %s." },
            is_night = { name = "It is nighttime", description = "Checks whether the map is currently in nighttime. Source: %s." },
            is_raining = { name = "It is raining", description = "Checks whether the current weather contains rain. Source: %s." },
            is_snowing = { name = "It is snowing", description = "Checks whether the current weather contains snow. Source: %s." },
            item_allowed = { name = "Item is allowed", description = "Checks whether operations with the specified item are allowed. Source: %s." },
            item_equipped = { name = "Item is equipped", description = "Checks whether the player has equipped the specified item. Source: %s." },
            job_is = { name = "Character job matches", description = "Checks the selected character's job. Source: %s." },
            level_at_least = { name = "Level is at least", description = "Checks that the player's level is at least the specified value. Source: %s." },
            level_at_most = { name = "Level is at most", description = "Checks that the player's level is at most the specified value. Source: %s." },
            name_is = { name = "Character name matches", description = "Checks the selected character's name. Source: %s." },
            points_at_least = { name = "Has enough points", description = "Checks that the player has at least the specified number of points. Source: %s." },
            random_chance = { name = "Random chance", description = "Passes with the configured probability from 0 to 1. Source: %s." },
            ready = { name = "Character is selected", description = "Checks that the player has loaded and selected a character. Source: %s." },
            team_is = { name = "Team matches", description = "Checks that the player belongs to the specified team. Source: %s." },
            team_is_not = { name = "Team does not match", description = "Checks that the player does not belong to the specified team. Source: %s." },
            temperature_at_least = { name = "Temperature is at least", description = "Checks that the current temperature is at least the specified value. Source: %s." },
            temperature_at_most = { name = "Temperature is at most", description = "Checks that the current temperature is at most the specified value. Source: %s." },
            usergroup_is = { name = "User group matches", description = "Checks the player's current user group. Source: %s." },
            weather_is = { name = "Weather matches", description = "Checks the current weather identifier. Source: %s." },
            xp_at_least = { name = "Has enough experience", description = "Checks that the player has at least the specified amount of experience. Source: %s." },
        },
    },
}

semantics.en.actions.start_combat = { name = "VJ: start combat with speaker", description = "Ends dialogue and fights its player. Only the owner's kill succeeds; owner death/disconnect fails. Must be the only action in its list. Source: %s." }
semantics.en.actions.spawn_target = { name = "VJ: spawn personal target", description = "Creates a VJ dialogue NPC at exact map coordinates. Occupied points fail. Must be the only action in its list. Source: %s." }
semantics.ru.conditions.result_is = { name = "VJ: результат боя", description = "Проверяет результат попытки игрока: active, success или failed. Источник: %s." }
semantics.en.conditions.result_is = { name = "VJ: combat result", description = "Checks the player's attempt result: active, success or failed. Source: %s." }
semantics.ru.conditions.has_target = { name = "VJ: у игрока есть цель", description = "Проверяет наличие персональной цели или активного боя у игрока. Источник: %s." }
semantics.en.conditions.has_target = { name = "VJ: player has a target", description = "Checks whether the player owns a dialogue target or has an active fight. Source: %s." }

TS.Localization.ReferenceSemantics = semantics

local function languageID()
    local language = TS.Config and TS.Config.language or "en"
    return semantics[language] and language or "en"
end

local function sourceName(language, integrationID)
    local manifest = TS.Integrations and TS.Integrations.Registry[integrationID]
    if not manifest and TS.Editor.Catalog and TS.Editor.Catalog.integrations then
        manifest = TS.Editor.Catalog.integrations[integrationID]
    end
    return tostring(manifest and manifest.name or semantics[language].sources[integrationID] or integrationID)
end

function TS.Localization.ReferenceTextFor(id, kind, field)
    local integrationID, localID = string.match(tostring(id or ""), "^([^.]+)%.(.+)$")
    if not integrationID or not localID then return end

    local language = languageID()
    local languageTable = semantics[language]
    local entries = languageTable[kind .. "s"] or {}
    local entry = entries[localID]
    if not entry and language ~= "en" then
        entry = (semantics.en[kind .. "s"] or {})[localID]
    end
    if not entry then return end

    if field == "description" then
        return string.format(entry.description, sourceName(language, integrationID))
    end
    if field == "name" then
        return entry.name
    end
end

TS.Localization.IntegrationText.ru.reference_group_core = "Talksmith — встроенные возможности"
TS.Localization.IntegrationText.en.reference_group_core = "Talksmith — built-in"
