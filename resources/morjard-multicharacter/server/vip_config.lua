-- Server-only VIP configuration (not shared with clients)
-- License hashes and Tebex integration are kept server-side for security

ServerConfig = ServerConfig or {}

-- Per-license slot override (VIP players get more slots)
-- License hashes are sensitive — never expose to clients via shared_scripts
ServerConfig.PlayersNumberOfCharacters = {
    -- { license = 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', numberOfChars = 6 },
}

-- Tebex integration for extra slots
-- Requires 'tebex_transactions' table — adjust query in server/main.lua
ServerConfig.TebexSlots = {
    enabled = false,
    packages = {
        -- [12345] = { slots = 6, label = 'VIP Bronze' },
        -- [12346] = { slots = 8, label = 'VIP Gold' },
        -- [12347] = { slots = 10, label = 'VIP Diamond' },
    },
}
