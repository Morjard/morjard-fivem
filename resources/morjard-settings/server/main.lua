-- morjard-settings / server/main.lua
-- Server-side export mirror so server scripts (e.g. a resource that writes
-- server-rendered HTML, or a Discord bot bridge) can read the active style too.

exports('GetStyle', function()
    return Config.GetActiveStyle()
end)

exports('GetActiveStyleName', function()
    return Config.ActiveStyle
end)
