local QBCore = exports['qb-core']:GetCoreObject()

local playerLocks = {}
local loginTimestamps = {}  -- Track when login was initiated (anti-exploit for spawnComplete)

-- Debug event from client
RegisterNetEvent('morjard-multicharacter:server:debug', function(msg)
    print('[MULTICHAR-DEBUG] pid=' .. tostring(source) .. ' ' .. tostring(msg))
end)

-- ============================================================
-- ROUTING BUCKET ISOLATION
-- Each player gets their own bucket on join (no ambient NPCs)
-- Returned to bucket 0 after character selection
-- ============================================================

-- Set routing bucket as early as possible (playerConnecting fires first)
AddEventHandler('playerConnecting', function()
    local src = source
    if src and src > 0 then
        SetPlayerRoutingBucket(src, src)
    end
end)

-- Redundant safety net: also set on playerJoining in case playerConnecting missed it
AddEventHandler('playerJoining', function()
    local src = source
    if src and src > 0 then
        SetPlayerRoutingBucket(src, src)
    end
end)

-- ============================================================
-- HELPERS
-- ============================================================

local function safeDecode(value)
    if not value then return {} end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or {}
end

-- Safe player name (GetPlayerName returns nil after disconnect mid-async)
local function safePlayerName(src)
    return GetPlayerName(src) or ('id:' .. tostring(src))
end

-- ============================================================
-- VIP SLOTS: Get max character slots for a player
-- Checks: Config table → Tebex packages → default
-- ============================================================

local function GetMaxSlots(src)
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then return Config.DefaultSlots end

    -- 1. Check per-license override (ServerConfig.PlayersNumberOfCharacters)
    local vipPlayers = (ServerConfig and ServerConfig.PlayersNumberOfCharacters) or Config.PlayersNumberOfCharacters
    if vipPlayers and next(vipPlayers) then
        for _, v in pairs(vipPlayers) do
            if v.license == license then
                return v.numberOfChars
            end
        end
    end

    -- 2. Check Tebex packages (if enabled)
    local tebexCfg = (ServerConfig and ServerConfig.TebexSlots) or Config.TebexSlots
    if tebexCfg and tebexCfg.enabled and next(tebexCfg.packages or {}) then
        local maxFromTebex = 0
        local identifier = QBCore.Functions.GetIdentifier(src, 'steam') or QBCore.Functions.GetIdentifier(src, 'license')

        -- Query tebex_transactions table for this player's purchases
        local queryOk, result = pcall(MySQL.query.await, [[
            SELECT package_id FROM tebex_transactions
            WHERE identifier = ? OR identifier = ?
        ]], { license, identifier })

        if queryOk and result then
            for _, row in ipairs(result) do
                local pkgId = tonumber(row.package_id)
                local pkg = tebexCfg.packages[pkgId]
                if pkg and pkg.slots and pkg.slots > maxFromTebex then
                    maxFromTebex = pkg.slots
                end
            end
        end

        if maxFromTebex > 0 then
            return maxFromTebex
        end
    end

    -- 3. Default
    return Config.DefaultSlots
end

-- ============================================================
-- SERVER LOGGING
-- ============================================================

local function LogAction(action, color, message)
    -- qb-log integration (sends to Discord)
    pcall(function()
        TriggerEvent('qb-log:server:CreateLog', 'multicharacter', action, color, message)
    end)
end

-- ============================================================
-- CALLBACKS
-- ============================================================

QBCore.Functions.CreateCallback('morjard-multicharacter:server:getCharacters', function(source, cb)
    local src = source
    local license = QBCore.Functions.GetIdentifier(src, 'license')
    local maxSlots = GetMaxSlots(src)

    if not license then cb({ maxSlots = maxSlots, characters = {} }) return end

    -- Prepare spawn locations for NUI
    local spawnLocs = {}
    if Config.SpawnLocations then
        for _, loc in ipairs(Config.SpawnLocations) do
            spawnLocs[#spawnLocs + 1] = {
                id    = loc.id,
                label = loc.label,
                icon  = loc.icon,
                x     = loc.x or (loc.coords and loc.coords.x) or 0,
                y     = loc.y or (loc.coords and loc.coords.y) or 0,
            }
        end
    end

    MySQL.query('SELECT * FROM players WHERE license = ? ORDER BY cid ASC', { license }, function(result)
        local characters = {}
        if result then
            for _, row in ipairs(result) do
                local cid = tonumber(row.cid)
                if cid and cid >= 1 and cid <= maxSlots then
                    characters[#characters + 1] = {
                        citizenid = row.citizenid,
                        cid       = cid,
                        charinfo  = safeDecode(row.charinfo),
                        money     = safeDecode(row.money),
                        job       = safeDecode(row.job),
                        position  = safeDecode(row.position),
                        metadata  = safeDecode(row.metadata),
                    }
                end
            end
        end
        cb({
            maxSlots          = maxSlots,
            characters        = characters,
            spawnLocations    = spawnLocs,
            enableLastLocation = Config.EnableLastLocation ~= false,
        })
    end)
end)

QBCore.Functions.CreateCallback('morjard-multicharacter:server:getSkin', function(source, cb, citizenid)
    local license = QBCore.Functions.GetIdentifier(source, 'license')
    if not license then cb(nil) return end
    if type(citizenid) ~= 'string' or #citizenid < 5 or #citizenid > 20 then cb(nil) return end

    MySQL.query('SELECT s.model, s.skin FROM playerskins s INNER JOIN players p ON s.citizenid = p.citizenid WHERE s.citizenid = ? AND s.active = 1 AND p.license = ?', { citizenid, license }, function(result)
        if result and result[1] then
            cb({ model = result[1].model, skin = result[1].skin })
        else
            cb(nil)
        end
    end)
end)

-- ============================================================
-- SELECT CHARACTER (with ownership check)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:server:selectCharacter', function(data)
    local src = source
    if playerLocks[src] then return end
    playerLocks[src] = true
    SetTimeout(15000, function()
        if playerLocks[src] then
            print('[morjard-multicharacter] Lock timeout for ' .. src .. ', releasing')
            playerLocks[src] = nil
        end
    end)

    if not data then playerLocks[src] = nil return end
    local citizenid = data.citizenid
    if type(citizenid) ~= 'string' or #citizenid < 5 or #citizenid > 20 then playerLocks[src] = nil return end

    -- Validate spawnLocation type and length
    local spawnLocation = data.spawnLocation
    if spawnLocation ~= nil and (type(spawnLocation) ~= 'string' or #spawnLocation > 50) then spawnLocation = nil end

    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then playerLocks[src] = nil return end

    MySQL.single('SELECT citizenid FROM players WHERE citizenid = ? AND license = ?', { citizenid, license }, function(row)
        if not row then
            print('[morjard-multicharacter] Unauthorized select attempt by ' .. safePlayerName(src))
            TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
            playerLocks[src] = nil
            return
        end

        local success = QBCore.Player.Login(src, citizenid)
        if not success then
            print('[morjard-multicharacter] Login failed for ' .. citizenid)
            TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
            playerLocks[src] = nil
            return
        end

        -- Wait until player object is ready
        local Player = nil
        local attempts = 0
        while not Player and attempts < 50 do
            Player = QBCore.Functions.GetPlayer(src)
            if not Player then
                Wait(100)
                attempts = attempts + 1
            end
        end

        if not Player then
            print('[morjard-multicharacter] Player object not found after login for ' .. citizenid)
            TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
            playerLocks[src] = nil
            return
        end

        -- Refresh QBCore commands for this player
        pcall(function() QBCore.Commands.Refresh(src) end)

        -- Routing bucket 0 is set in spawnComplete handler (after client finishes spawning)

        -- Determine spawn coords based on player's choice
        local coords = Player.PlayerData.position
        local spawnLocationId = spawnLocation

        if spawnLocationId and spawnLocationId ~= 'last_location' and Config.SpawnLocations then
            for _, loc in ipairs(Config.SpawnLocations) do
                if loc.id == spawnLocationId and loc.coords then
                    local lx, ly, lz = loc.coords.x, loc.coords.y, loc.coords.z
                    -- Validate spawn location coords are finite and within map bounds
                    if lx and ly and lz and lx == lx and ly == ly and lz == lz
                       and lx > -4500.0 and lx < 8500.0 and ly > -4500.0 and ly < 8500.0 then
                        coords = { x = lx, y = ly, z = lz, w = loc.coords.w or 0.0 }
                    else
                        print('[morjard-multicharacter] Invalid spawn location coords for ' .. tostring(loc.id) .. ', using last position')
                    end
                    break
                end
            end
        end

        -- Final safety: ensure coords table has required fields
        if not coords or not coords.x or coords.x ~= coords.x then
            coords = { x = Config.DefaultSpawn.x, y = Config.DefaultSpawn.y, z = Config.DefaultSpawn.z, w = Config.DefaultSpawn.w or 0.0 }
        end

        loginTimestamps[src] = GetGameTimer()
        TriggerClientEvent('morjard-multicharacter:client:spawnCharacter', src, coords)

        LogAction('Login', 'green', '**' .. safePlayerName(src) .. '** logged in as ' .. citizenid)
        print('[morjard-multicharacter] Player ' .. safePlayerName(src) .. ' logged in as ' .. citizenid)
        playerLocks[src] = nil
    end)
end)

-- ============================================================
-- CREATE CHARACTER (with slot validation)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:server:createCharacter', function(data)
    local src = source
    if playerLocks[src] then return end
    playerLocks[src] = true
    SetTimeout(15000, function()
        if playerLocks[src] then
            print('[morjard-multicharacter] Lock timeout for ' .. src .. ', releasing')
            playerLocks[src] = nil
        end
    end)

    if not data then playerLocks[src] = nil return end
    if type(data.firstname) ~= 'string' or type(data.lastname) ~= 'string' then playerLocks[src] = nil return end
    if #data.firstname < 2 or #data.lastname < 2 then playerLocks[src] = nil return end

    -- Server-side validation (strip non-alpha, zero-width chars already removed)
    local firstname = tostring(data.firstname):gsub('[^%a%s%-\'À-ž]', ''):sub(1, 30)
    local lastname = tostring(data.lastname):gsub('[^%a%s%-\'À-ž]', ''):sub(1, 30)
    if #firstname < 2 or #lastname < 2 then playerLocks[src] = nil return end

    -- Server-side profanity check (backup for NUI bypass)
    local nameLower = (firstname .. ' ' .. lastname):lower()
    local profanity = {'admin','moderator','owner','server','console','system','nigger','nigga','faggot','retard','fuck','shit','dick','penis','vagina','cock','pussy','bitch','whore','slut','kurva','pica','kokot','debil','zmrd','hajzl','srac'}
    for _, word in ipairs(profanity) do
        if nameLower:find(word, 1, true) then
            print('[morjard-multicharacter] Profanity blocked from ' .. safePlayerName(src) .. ': ' .. word)
            TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
            playerLocks[src] = nil
            return
        end
    end

    local gender = tonumber(data.gender) or 0
    if gender ~= 0 and gender ~= 1 then gender = 0 end

    local nationality = tostring(data.nationality or 'Czech Republic'):sub(1, 40)
    local birthdate = tostring(data.birthdate or '1990-01-01')
    if not birthdate:match('^%d%d%d%d%-%d%d%-%d%d$') then birthdate = '1990-01-01' end

    local maxSlots = GetMaxSlots(src)
    local cid = tonumber(data.cid)
    if not cid or cid < 1 or cid > maxSlots then playerLocks[src] = nil return end
    cid = math.floor(cid)

    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then playerLocks[src] = nil return end

    local exists = MySQL.scalar.await('SELECT 1 FROM players WHERE license = ? AND cid = ?', { license, cid })
    if exists then
        print('[morjard-multicharacter] Slot ' .. cid .. ' already taken for ' .. safePlayerName(src))
        TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
        playerLocks[src] = nil
        return
    end

    local charinfo = {
        firstname   = firstname,
        lastname    = lastname,
        birthdate   = birthdate,
        gender      = gender,
        nationality = nationality,
        phone       = GeneratePhoneNumber(),
        account     = GenerateBankAccount(),
    }

    local newData = {
        cid      = cid,
        charinfo = charinfo,
    }

    local success = QBCore.Player.Login(src, false, newData)
    if not success then
        print('[morjard-multicharacter] Create character failed for ' .. safePlayerName(src))
        TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
        playerLocks[src] = nil
        return
    end

    -- Wait for player object
    local Player = nil
    local attempts = 0
    while not Player and attempts < 50 do
        Player = QBCore.Functions.GetPlayer(src)
        if not Player then
            Wait(100)
            attempts = attempts + 1
        end
    end

    if not Player then
        TriggerClientEvent('morjard-multicharacter:client:loginFailed', src)
        playerLocks[src] = nil
        return
    end

    -- Refresh QBCore commands
    pcall(function() QBCore.Commands.Refresh(src) end)

    -- Give starter items
    GiveStarterItems(src, Player)

    -- Save default skin so character has appearance even without clothing resource
    SaveDefaultSkin(Player.PlayerData.citizenid, gender)

    -- Routing bucket 0 is set in spawnComplete handler (after client finishes spawning)

    -- Spawn at default location (new character, flag isNew=true)
    loginTimestamps[src] = GetGameTimer()
    TriggerClientEvent('morjard-multicharacter:client:spawnCharacter', src, nil, true)

    LogAction('Create', 'blue', '**' .. safePlayerName(src) .. '** created character ' .. firstname .. ' ' .. lastname)
    print('[morjard-multicharacter] New character created for ' .. safePlayerName(src))
    playerLocks[src] = nil
end)

-- ============================================================
-- CLIENT SIGNALS SPAWN COMPLETE → fire QBCore events
-- ============================================================

local spawnCompletePlayers = {}

RegisterNetEvent('morjard-multicharacter:server:spawnComplete', function()
    local src = source

    -- Guard against spam: only fire once per login
    if spawnCompletePlayers[src] then return end

    -- Anti-exploit: require login to have happened first and at least 2s ago
    -- Prevents cheaters from firing spawnComplete prematurely
    if not loginTimestamps[src] then return end
    if GetGameTimer() - loginTimestamps[src] < 2000 then return end
    loginTimestamps[src] = nil

    spawnCompletePlayers[src] = true

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then spawnCompletePlayers[src] = nil return end
    if not Player.PlayerData or not Player.PlayerData.citizenid then spawnCompletePlayers[src] = nil return end

    -- Return to main routing bucket (bucket 0) AFTER client has spawned at correct coords
    SetPlayerRoutingBucket(src, 0)

    -- Fire server-side QBCore loaded event (pass Player object for compatibility)
    TriggerEvent('QBCore:Server:OnPlayerLoaded', Player)
end)

-- ============================================================
-- DELETE CHARACTER
-- ============================================================

RegisterNetEvent('morjard-multicharacter:server:deleteCharacter', function(data)
    local src = source
    if not Config.EnableDelete then return end
    if playerLocks[src] then return end
    playerLocks[src] = true
    SetTimeout(15000, function()
        if playerLocks[src] then
            print('[morjard-multicharacter] Delete lock timeout for ' .. src .. ', releasing')
            playerLocks[src] = nil
        end
    end)

    if not data then playerLocks[src] = nil return end

    local citizenid = data.citizenid
    if type(citizenid) ~= 'string' or #citizenid < 5 or #citizenid > 20 then playerLocks[src] = nil return end

    local license = QBCore.Functions.GetIdentifier(src, 'license')
    if not license then playerLocks[src] = nil return end

    MySQL.single('SELECT license FROM players WHERE citizenid = ? AND license = ?', { citizenid, license }, function(row)
        if not row then
            print('[morjard-multicharacter] Unauthorized delete attempt by ' .. safePlayerName(src))
            playerLocks[src] = nil
            return
        end

        QBCore.Player.DeleteCharacter(src, citizenid)
        TriggerClientEvent('morjard-multicharacter:client:refreshCharacters', src)
        playerLocks[src] = nil

        LogAction('Delete', 'red', '**' .. safePlayerName(src) .. '** deleted character ' .. citizenid)
        print('[morjard-multicharacter] Character ' .. citizenid .. ' deleted by ' .. safePlayerName(src))
    end)
end)

-- ============================================================
-- DISCONNECT (from multichar screen)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:server:disconnect', function()
    local src = source
    DropPlayer(src, 'Disconnected from character selection')
end)

-- ============================================================
-- LOGOUT COMMAND
-- ============================================================

QBCore.Commands.Add('logout', 'Return to character selection', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        QBCore.Player.Logout(src)
        -- Reset spawn guard so next login fires OnPlayerLoaded again
        spawnCompletePlayers[src] = nil
        -- Return to isolated routing bucket for character selection
        SetPlayerRoutingBucket(src, src)
        TriggerClientEvent('morjard-multicharacter:client:chooseChar', src)
        LogAction('Logout', 'yellow', '**' .. safePlayerName(src) .. '** returned to character selection')
    end
end)

-- ============================================================
-- ADMIN: FORCE DELETE CHARACTER
-- ============================================================

QBCore.Commands.Add('deletechar', 'Force delete a character by citizenid (admin)', {
    { name = 'citizenid', help = 'Target citizenid to delete' }
}, false, function(source, args)
    local src = source
    if args and args[1] then
        local targetCid = tostring(args[1])
        if #targetCid < 5 then
            TriggerClientEvent('QBCore:Notify', src, 'Invalid citizenid (too short)', 'error')
            return
        end

        -- Use QBCore.Player.ForceDeleteCharacter if available (newer QBCore)
        -- Fallback: find owner source or direct SQL delete
        if QBCore.Player.ForceDeleteCharacter then
            QBCore.Player.ForceDeleteCharacter(targetCid)
        else
            local ownerSrc = nil
            local players = QBCore.Functions.GetQBPlayers()
            if players then
                for _, player in pairs(players) do
                    if player and player.PlayerData and player.PlayerData.citizenid == targetCid then
                        ownerSrc = player.PlayerData.source
                        break
                    end
                end
            end
            if ownerSrc then
                QBCore.Player.DeleteCharacter(ownerSrc, targetCid)
            else
                MySQL.query('DELETE FROM players WHERE citizenid = ?', { targetCid })
                MySQL.query('DELETE FROM playerskins WHERE citizenid = ?', { targetCid })
            end
        end

        TriggerClientEvent('QBCore:Notify', src, 'Character ' .. targetCid .. ' deleted', 'success')
        LogAction('AdminDelete', 'red', '**' .. safePlayerName(src) .. '** force-deleted character ' .. targetCid)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Usage: /deletechar [citizenid]', 'error')
    end
end, 'god')

-- ============================================================
-- CLEANUP
-- ============================================================

-- Reset spawn guard and isolate routing bucket on logout
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    local playerId = type(src) == 'table' and (src.PlayerData and src.PlayerData.source or src.source) or src
    if playerId and type(playerId) == 'number' and playerId > 0 then
        spawnCompletePlayers[playerId] = nil
        -- Re-isolate into own bucket for character selection
        SetPlayerRoutingBucket(playerId, playerId)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    spawnCompletePlayers[src] = nil
    playerLocks[src] = nil
    loginTimestamps[src] = nil
end)

-- ============================================================
-- HELPERS
-- ============================================================

function GiveStarterItems(src, Player)
    if not QBCore.Shared.StarterItems then return end
    if not Player or not Player.Functions or not Player.Functions.AddItem then
        print('[morjard-multicharacter] AddItem not available, retrying in 2s...')
        Wait(2000)
        Player = QBCore.Functions.GetPlayer(src)
        if not Player or not Player.Functions or not Player.Functions.AddItem then
            print('[morjard-multicharacter] AddItem still not available, skipping starter items')
            return
        end
    end

    for _, item in pairs(QBCore.Shared.StarterItems) do
        local itemName = item.item or item.name or item
        local amount = item.amount or 1

        local ok, err = pcall(function()
            if itemName == 'id_card' then
                local info = {
                    citizenid  = Player.PlayerData.citizenid,
                    firstname  = Player.PlayerData.charinfo.firstname,
                    lastname   = Player.PlayerData.charinfo.lastname,
                    birthdate  = Player.PlayerData.charinfo.birthdate,
                    gender     = Player.PlayerData.charinfo.gender,
                    nationality = Player.PlayerData.charinfo.nationality,
                }
                Player.Functions.AddItem(itemName, amount, false, info)
            elseif itemName == 'driver_license' then
                local info = {
                    firstname = Player.PlayerData.charinfo.firstname,
                    lastname  = Player.PlayerData.charinfo.lastname,
                    birthdate = Player.PlayerData.charinfo.birthdate,
                    type      = 'Class C Driver License',
                }
                Player.Functions.AddItem(itemName, amount, false, info)
            else
                Player.Functions.AddItem(itemName, amount)
            end
        end)
        if not ok then
            print('[morjard-multicharacter] Failed to add item ' .. tostring(itemName) .. ': ' .. tostring(err))
        end
    end
end

-- ============================================================
-- DEFAULT SKIN FOR NEW CHARACTERS (qb-clothing format)
-- Ensures every new character has a playerskins entry even if
-- qb-clothing's CreateFirstCharacter handler is missing/broken
-- ============================================================

local function BuildDefaultSkin()
    local skin = {}
    local faceFeatures = {
        'nose_0','nose_1','nose_2','nose_3','nose_4','nose_5',
        'cheek_1','cheek_2','cheek_3','jaw_bone_width','jaw_bone_back_lenght',
        'chimp_bone_lowering','chimp_bone_lenght','chimp_bone_width','chimp_hole',
        'neck_thikness','lips_thickness','eye_opening','eyebrown_high','eyebrown_forward',
        'face','face2',
    }
    for _, feat in ipairs(faceFeatures) do
        skin[feat] = {item = 0, texture = 0, defaultItem = 0, defaultTexture = 0}
    end
    local clothing = {['t-shirt'] = 1, torso2 = 0, arms = 0, pants = 0, shoes = 1, mask = 0, vest = 0, bag = 0, decals = 0}
    for comp, item in pairs(clothing) do
        skin[comp] = {item = item, texture = 0, defaultItem = item, defaultTexture = 0}
    end
    for _, acc in ipairs({'hat','glass','ear','watch','bracelet','accessory'}) do
        skin[acc] = {item = -1, texture = 0, defaultItem = -1, defaultTexture = 0}
    end
    for _, ov in ipairs({'beard','eyebrows','makeup','blush','lipstick','ageing','moles'}) do
        skin[ov] = {item = -1, texture = 1, defaultItem = -1, defaultTexture = 1}
    end
    skin['eye_color'] = {item = -1, texture = 0, defaultItem = -1, defaultTexture = 0}
    skin['hair'] = {item = 0, texture = 0, defaultItem = 0, defaultTexture = 0}
    skin['facemix'] = {shapeMix = 0, defaultShapeMix = 0.0, skinMix = 0, defaultSkinMix = 0.0}
    return skin
end

local DEFAULT_SKIN = BuildDefaultSkin()

local function SaveDefaultSkin(citizenid, gender)
    local existing = MySQL.scalar.await('SELECT 1 FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { citizenid })
    if existing then return end
    local model = tostring((gender == 1) and Config.StarterModelFemale or Config.StarterModel)
    MySQL.insert('INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)',
        { citizenid, model, json.encode(DEFAULT_SKIN) })
end

-- ============================================================
-- UNIQUE PHONE/BANK GENERATORS (with DB collision check)
-- ============================================================

function GeneratePhoneNumber()
    for _ = 1, 20 do
        local phone = tostring(math.random(100, 999)) .. tostring(math.random(1000000, 9999999))
        local exists = MySQL.scalar.await(
            'SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.phone")) = ? LIMIT 1',
            { phone }
        )
        if not exists then return phone end
    end
    return tostring(os.time()):sub(-7) .. tostring(math.random(100, 999))
end

function GenerateBankAccount()
    for _ = 1, 20 do
        local account = 'CZ' .. tostring(math.random(10000000, 99999999))
        local exists = MySQL.scalar.await(
            'SELECT 1 FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.account")) = ? LIMIT 1',
            { account }
        )
        if not exists then return account end
    end
    return 'CZ' .. tostring(os.time()):sub(-8)
end

-- ============================================================
-- LIVE ADJUSTMENT COMMANDS (dev tools)
-- ============================================================

-- Usage: mcam [playerid] [x] [y] [z] [rx] [ry] [rz] [fov]
RegisterCommand('mcam', function(source, args)
    if #args < 8 then print('[mcam] Usage: mcam <pid> <x> <y> <z> <rx> <ry> <rz> <fov>') return end
    local pid = tonumber(args[1])
    TriggerClientEvent('morjard-multicharacter:client:adjustCam', pid,
        tonumber(args[2]), tonumber(args[3]), tonumber(args[4]),
        tonumber(args[5]), tonumber(args[6]), tonumber(args[7]), tonumber(args[8]))
end, false)

-- Usage: mped [playerid] [x] [y] [z]
RegisterCommand('mped', function(source, args)
    if #args < 4 then print('[mped] Usage: mped <pid> <x> <y> <z>') return end
    local pid = tonumber(args[1])
    TriggerClientEvent('morjard-multicharacter:client:adjustPed', pid,
        tonumber(args[2]), tonumber(args[3]), tonumber(args[4]))
end, false)

-- Usage: mlight [playerid] [range] [intensity]
RegisterCommand('mlight', function(source, args)
    if #args < 3 then print('[mlight] Usage: mlight <pid> <range> <intensity>') return end
    local pid = tonumber(args[1])
    TriggerClientEvent('morjard-multicharacter:client:adjustLight', pid,
        tonumber(args[2]), tonumber(args[3]))
end, false)

-- Usage: mscreen [playerid] — capture player's screen via screenshot-basic
RegisterCommand('mscreen', function(source, args)
    if #args < 1 then print('[mscreen] Usage: mscreen <pid>') return end
    local pid = tonumber(args[1])
    exports['screenshot-basic']:requestClientScreenshot(pid, {
        encoding = 'png',
    }, function(err, data)
        if err then
            print('[mscreen] Error: ' .. tostring(err))
            return
        end
        -- Save base64 PNG to file
        local path = GetResourcePath(GetCurrentResourceName()) .. '/screenshot.txt'
        local f = io.open(path, 'w')
        if f then
            f:write(data)
            f:close()
            print('[mscreen] Screenshot saved to ' .. path)
        end
    end)
end, false)
