-- ============================================================
--  Morjard Loading Screen — client.lua
--  loadscreen_manual_shutdown 'yes' — we control when it closes
-- ============================================================

-- Hybrid style (Morjard / DDCZ, see ../morjard-settings). A loadscreen resource
-- starts before other resources are guaranteed ready, so we read the style via
-- GetConvar (always available from server.cfg: set morjard_active_style "ddcz")
-- instead of exports['morjard-settings'] -- avoids resource-start-order races.
local STYLES = {
    morjard = { accent = '#10b981', accentAlt = '#ff9a1f' },
    ddcz    = { accent = '#00b0ff', accentAlt = '#ffd700' },
}
CreateThread(function()
    local activeStyle = GetConvar('morjard_active_style', 'morjard')
    local style = STYLES[activeStyle]
    if style then
        SendNUIMessage({ type = 'applyMorjardStyle', style = style })
    end
end)

-- Wait until the player has fully spawned, then shut down the loading screen
AddEventHandler('playerSpawned', function()
    Citizen.Wait(800)
    SendNUIMessage({ type = 'loadingDone' })
    Citizen.Wait(1200)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end)

-- Safety fallback: force close after 90 seconds no matter what
Citizen.CreateThread(function()
    Citizen.Wait(90000)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end)
