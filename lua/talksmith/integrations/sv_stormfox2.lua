local TS = Talksmith
local ID = "stormfox2"

TS.Integrations.Register(ID, {
    name = "StormFox 2",
    category = "world",
    priority = 80,
    capabilities = { "weather", "time", "temperature" },
    detect = function()
        return istable(StormFox2)
            and istable(StormFox2.Weather)
            and istable(StormFox2.Time)
            and istable(StormFox2.Temperature)
            and isfunction(StormFox2.Weather.GetCurrent)
            and isfunction(StormFox2.Weather.GetPercent)
            and isfunction(StormFox2.Weather.IsRaining)
            and isfunction(StormFox2.Weather.IsSnowing)
            and isfunction(StormFox2.Time.Get)
            and isfunction(StormFox2.Time.IsDay)
            and isfunction(StormFox2.Time.IsNight)
            and isfunction(StormFox2.Temperature.Get), "StormFox2 API"
    end,
})

local function weatherName()
    local current = StormFox2.Weather.GetCurrent and StormFox2.Weather.GetCurrent()
    if not current then
        return "clear"
    end

    return tostring(current.Name or current.name or current.Inherit or current)
end

local function temperature()
    local temperatureAPI = StormFox2.Temperature
    return tonumber(temperatureAPI and temperatureAPI.Get and temperatureAPI.Get()) or 0
end

TS.Integrations.RegisterCondition(ID, "is_day", {
    name = "StormFox 2: is day",
    params = {},
    run = function()
        return StormFox2.Time.IsDay()
    end,
})

TS.Integrations.RegisterCondition(ID, "is_night", {
    name = "StormFox 2: is night",
    params = {},
    run = function()
        return StormFox2.Time.IsNight()
    end,
})

TS.Integrations.RegisterCondition(ID, "is_raining", {
    name = "StormFox 2: is raining",
    params = {},
    run = function()
        return StormFox2.Weather.IsRaining()
    end,
})

TS.Integrations.RegisterCondition(ID, "is_snowing", {
    name = "StormFox 2: is snowing",
    params = {},
    run = function()
        return StormFox2.Weather.IsSnowing()
    end,
})

TS.Integrations.RegisterCondition(ID, "is_foggy", {
    name = "StormFox 2: is foggy",
    params = {},
    run = function()
        return string.find(string.lower(weatherName()), "fog", 1, true) ~= nil
    end,
})

TS.Integrations.RegisterCondition(ID, "weather_is", {
    name = "StormFox 2: weather is",
    params = { weather = { type = "string", required = true, max = 64 } },
    run = function(_, params)
        return string.lower(weatherName()) == string.lower(params.weather)
    end,
})

TS.Integrations.RegisterCondition(ID, "temperature_at_least", {
    name = "StormFox 2: temperature at least",
    params = { amount = { type = "number", required = true, min = -273, max = 1000 } },
    run = function(_, params)
        return temperature() >= params.amount
    end,
})

TS.Integrations.RegisterCondition(ID, "temperature_at_most", {
    name = "StormFox 2: temperature at most",
    params = { amount = { type = "number", required = true, min = -273, max = 1000 } },
    run = function(_, params)
        return temperature() <= params.amount
    end,
})

TS.Providers.Register("world", ID, {
    integration = ID,
    priority = 80,
    get_weather = function()
        return weatherName()
    end,
    get_temperature = function()
        return temperature()
    end,
    get_time = function()
        return StormFox2.Time.Get()
    end,
})

TS.Integrations.RegisterVariable("stormfox2.weather", {
    integration = ID,
    resolve = function()
        return weatherName()
    end,
})

TS.Integrations.RegisterVariable("stormfox2.temperature", {
    integration = ID,
    resolve = function()
        return temperature()
    end,
})

TS.Integrations.RegisterVariable("stormfox2.time", {
    integration = ID,
    resolve = function()
        return StormFox2.Time.Get()
    end,
})

TS.Integrations.RegisterVariable("stormfox2.weather_percent", {
    integration = ID,
    resolve = function()
        return StormFox2.Weather.GetPercent and StormFox2.Weather.GetPercent() or 0
    end,
})
