-- ============================================================
--  LOCALE LOADER
--  Překlady jsou načteny přes shared_scripts v fxmanifest.lua
--  Tato funkce T() musí být definována PŘED locale soubory,
--  ale kontrolu spouštíme až po načtení všech souborů.
-- ============================================================

Lang = Lang or {}

-- Pomocná funkce pro překlad
-- Použije zvolený jazyk, fallback na angličtinu, fallback na klíč
function T(key)
    local locale   = Lang[Config.Locale] or {}
    local fallback = Lang['en']          or {}
    return locale[key] or fallback[key] or key
end
