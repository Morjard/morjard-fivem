-- morjard-settings / client/main.lua
-- Client-side export so NUI-driven resources (chat, loadingscreen, multicharacter)
-- can pull the active palette and forward it to their own HTML/JS as a postMessage.

exports('GetStyle', function()
    return Config.GetActiveStyle()
end)

exports('GetActiveStyleName', function()
    return Config.ActiveStyle
end)
