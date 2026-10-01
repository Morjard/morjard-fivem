--[[
    morjard-settings / shared/settings.lua

    Single place that decides which visual IDENTITY the server runs with.
    We maintain two brand identities on the same codebase:
      - "morjard"  : current brand, cyberpunk/glass-morphism, see rp-chat/STYLE_GUIDE.txt
      - "ddcz"     : original brand (still legally ours, just an older identity)

    Any resource (chat, loadingscreen, multicharacter, spawn-selector, hud...) should
    read its colors/text from here instead of hardcoding a palette, so switching the
    whole server's look is a ONE LINE change (Config.ActiveStyle below), not a
    per-resource find-and-replace.

    Usage from another resource:
        client/server Lua:  local style = exports['morjard-settings']:GetStyle()
        NUI (JS):            sent to the page as a postMessage, see docs/HYBRID_STYLE.md
]]

Config = Config or {}

-- ============================================================================
-- THE ONE SETTING YOU ACTUALLY CHANGE
-- ============================================================================
Config.ActiveStyle = 'morjard' -- 'morjard' | 'ddcz'

-- Allow overriding from server.cfg without touching this file:
--   set morjard_active_style "ddcz"
local cfgStyle = GetConvar('morjard_active_style', '')
if cfgStyle == 'morjard' or cfgStyle == 'ddcz' then
    Config.ActiveStyle = cfgStyle
end

-- ============================================================================
-- PALETTES  (real values, not placeholders)
--   morjard: taken from fivem-resources/rp-chat/STYLE_GUIDE.txt (current live brand)
--   ddcz:    taken from the original ddcz-loadingscreen config.js/style.css
-- ============================================================================
Config.Styles = {
    morjard = {
        name           = 'Morjard',
        accent         = '#10b981',          -- emerald green (default accent)
        accentRgb      = '16, 185, 129',
        accentAlt      = '#ff9a1f',           -- orange, "cyberpunk" variant some pages use
        accentAltRgb   = '255, 154, 31',
        secondary      = '#3b82f6',           -- blue
        bgDark         = 'rgba(15, 20, 35, 0.65)',
        bgDarker       = 'rgba(15, 20, 35, 0.95)',
        textPrimary    = '#ffffff',
        textSecondary  = '#cccccc',
        logo           = 'img/morjard-logo.png',
        font           = "'Segoe UI', system-ui, sans-serif",
    },
    ddcz = {
        name           = 'DDCZ',
        accent         = '#00b0ff',           -- light blue, original ddcz-loadingscreen accent
        accentRgb      = '0, 176, 255',
        accentAlt      = '#ffd700',           -- gold highlight used across ddcz UI
        accentAltRgb   = '255, 215, 0',
        secondary      = '#4caf50',           -- green, secondary ddcz accent
        bgDark         = 'rgba(10, 10, 15, 0.65)',
        bgDarker       = 'rgba(10, 10, 15, 0.95)',
        textPrimary    = '#ffffff',
        textSecondary  = '#cccccc',
        logo           = 'img/ddcz-logo.png',
        font           = "'Segoe UI', system-ui, sans-serif",
    },
}

---Returns the full palette table for the currently active style.
---@return table
function Config.GetActiveStyle()
    return Config.Styles[Config.ActiveStyle] or Config.Styles.morjard
end
