local TS = Talksmith

TS.Examples = TS.Examples or {}

local function localized(ru, en)
    return { ru = ru, en = en }
end

TS.Examples.Catalog = {
    {
        id = "armory_allowlist_demo",
        file = "armory_allowlist_demo.json",
        category = "standard",
        title = localized("Оружейная и allowlist", "Armory and allowlist"),
        description = localized(
            "Условия наличия оружия, выдача и возврат разрешённых классов, серверные события и шесть ответов в одном узле.",
            "Weapon ownership conditions, issuing and returning allowed classes, server events, and six responses in one node."
        ),
    },
    {
        id = "darkrp_services_demo",
        file = "darkrp_services_demo.json",
        category = "standard",
        title = localized("Сервисы DarkRP", "DarkRP services"),
        description = localized(
            "Проверка денег, профессии и Civil Protection, смена работы, выдача и списание средств. Требуется DarkRP.",
            "Money, job, and Civil Protection checks with job changes and money grants/deductions. Requires DarkRP."
        ),
    },
    {
        id = "flags_reward_demo",
        file = "flags_reward_demo.json",
        category = "standard",
        title = localized("Флаги и одноразовая награда", "Flags and a one-time reward"),
        description = localized(
            "Постоянный флаг игрока, одноразовое лечение и броня, административный сброс состояния и завершение действием.",
            "A persistent player flag, one-time health and armour, administrator reset, and action-driven completion."
        ),
    },
    {
        id = "medical_limits_demo",
        file = "medical_limits_demo.json",
        category = "standard",
        title = localized("Здоровье, броня и границы", "Health, armour, and limits"),
        description = localized(
            "Ветки по диапазонам здоровья, лечение с ограничением максимума, броня и параметры числовых действий.",
            "Branches for health ranges, healing with maximum clamping, armour, and numeric action parameters."
        ),
    },
    {
        id = "medic_first_aid",
        file = "medic_first_aid.json",
        category = "standard",
        title = localized("Медик: осмотр и снаряжение", "Medic: examination and equipment"),
        description = localized(
            "Полноценный ролевой разговор с несколькими ветками, повторными посещениями, флагами и выдачей защитного снаряжения.",
            "A complete roleplay conversation with multiple branches, repeat visits, flags, and protective equipment."
        ),
    },
    {
        id = "random_event_router_demo",
        file = "random_event_router_demo.json",
        category = "standard",
        title = localized("Случайность, события и маршрутизация", "Randomness, events, and routing"),
        description = localized(
            "Случайный старт, вероятность, несколько случайных целей, звук, события и переход в flags_reward_demo.",
            "Random start, chance, multiple random targets, sound, events, and a route into flags_reward_demo."
        ),
    },
    {
        id = "integration_advanced_character_creator_test",
        file = "advanced_character_creator_test.json",
        category = "integration",
        integration = "advanced_character_creator",
        title = localized("Advanced Character Creator", "Advanced Character Creator"),
        description = localized(
            "Данные имени, ID, профессии и фракции активного персонажа, условия и динамические текстовые переменные.",
            "Active-character name, ID, job, and faction data with conditions and dynamic text variables."
        ),
    },
    {
        id = "integration_barney_test",
        file = "barney_test.json",
        category = "integration",
        integration = "barney",
        title = localized("Barney Inventory 2.0", "Barney Inventory 2.0"),
        description = localized(
            "Предметы, свободный вес, боеприпасы и универсальный Inventory-провайдер Barney.",
            "Items, free weight, ammunition, and Barney as the generic Inventory provider."
        ),
    },
    {
        id = "integration_darkrp_leveling_test",
        file = "darkrp_leveling_test.json",
        category = "integration",
        integration = "darkrp_leveling",
        title = localized("DarkRP Leveling System", "DarkRP Leveling System"),
        description = localized(
            "Проверки уровня и XP, повышение, списание опыта, установка уровня и переменные прогресса.",
            "Level and XP checks, levelling, XP deductions, level assignment, and progression variables."
        ),
    },
    {
        id = "integration_darkrp_multicharacter_test",
        file = "darkrp_multicharacter_test.json",
        category = "integration",
        integration = "darkrp_multicharacter",
        title = localized("DarkRP Multi Character", "DarkRP Multi Character"),
        description = localized(
            "Условия выбранного персонажа, имени, индекса и профессии с ветками по фактическому состоянию игрока.",
            "Selected-character, name, index, and job conditions branching from the player's live state."
        ),
    },
    {
        id = "integration_finventory_test",
        file = "finventory_test.json",
        category = "integration",
        integration = "finventory",
        title = localized("Finventory", "Finventory"),
        description = localized(
            "Наличие и выдача предметов, вместимость, заполненность, ограничения и явный выбор Finventory-провайдера.",
            "Item checks and grants, capacity, full state, restrictions, and explicit Finventory provider selection."
        ),
    },
    {
        id = "integration_gws_test",
        file = "gws_test.json",
        category = "integration",
        integration = "gws",
        title = localized("GWS Inventory System", "GWS Inventory System"),
        description = localized(
            "Предметы, вместимость, оружие, боеприпасы, ограничения GWS и универсальные Inventory-операции.",
            "Items, capacity, weapons, ammunition, GWS restrictions, and generic Inventory operations."
        ),
    },
    {
        id = "integration_pointshop_test",
        file = "pointshop_test.json",
        category = "integration",
        integration = "pointshop",
        title = localized("PointShop 1", "PointShop 1"),
        description = localized(
            "Очки, владение и экипировка предметов, магазин, а также универсальные Currency и Inventory-провайдеры.",
            "Points, item ownership and equipment, the shop, plus generic Currency and Inventory providers."
        ),
    },
    {
        id = "integration_stormfox2_test",
        file = "stormfox2_test.json",
        category = "integration",
        integration = "stormfox2",
        title = localized("StormFox 2", "StormFox 2"),
        description = localized(
            "День, ночь, осадки, туман, температура, текущая погода и динамические переменные мира.",
            "Day, night, precipitation, fog, temperature, current weather, and dynamic world variables."
        ),
    },
    {
        id = "integration_ulib_test",
        file = "ulib_test.json",
        category = "integration",
        integration = "ulib",
        title = localized("ULib", "ULib"),
        description = localized(
            "Проверки UCL-доступа и точной группы пользователя на сервере с ULib.",
            "UCL access and exact user-group checks on a server running ULib."
        ),
    },
    {
        id = "integration_ulx_test",
        file = "ulx_test.json",
        category = "integration",
        integration = "ulx",
        title = localized("ULX", "ULX"),
        description = localized(
            "Доступ к ULX-командам и CAMI-привилегии редактора Talksmith.",
            "ULX command access and the Talksmith editor CAMI privilege."
        ),
    },
    {
        id = "integration_wiremod_test",
        file = "wiremod_test.json",
        category = "integration",
        integration = "wiremod",
        title = localized("Wiremod", "Wiremod"),
        description = localized(
            "Входы ExternalValue, пользовательские выходы, импульсы, строки и передача выбранного ответа.",
            "ExternalValue inputs, custom outputs, pulses, strings, and forwarding the selected response."
        ),
    },
}

TS.Examples.ByID = {}
for _, entry in ipairs(TS.Examples.Catalog) do
    TS.Examples.ByID[entry.id] = entry
end

TS.Examples.TrialID = "armory_allowlist_demo"

function TS.Examples.Get(id)
    return isstring(id) and TS.Examples.ByID[id] or nil
end

function TS.Examples.Text(entry, field, language)
    local values = istable(entry) and entry[field]
    if not istable(values) then
        return ""
    end
    language = language == "ru" and "ru" or "en"
    return values[language] or values.en or values.ru or ""
end

function TS.Examples.Path(entry, language)
    if not istable(entry) or not isstring(entry.file) then
        return nil
    end
    language = language == "ru" and "ru" or "en"
    local folder = entry.category == "integration" and "integrations" or "standard"
    return "data_static/talksmith/examples/" .. language .. "/" .. folder .. "/" .. entry.file
end
