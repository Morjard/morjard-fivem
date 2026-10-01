local QBCore = exports['qb-core']:GetCoreObject()

local lastLocations = {}

-- ============================================================
-- DATABASE SETUP (oxmysql)
-- ============================================================

if Config.UseDatabase then
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `morjard_last_locations` (
                `citizenid` VARCHAR(50) NOT NULL,
                `x` FLOAT NOT NULL DEFAULT 0,
                `y` FLOAT NOT NULL DEFAULT 0,
                `z` FLOAT NOT NULL DEFAULT 0,
                `heading` FLOAT NOT NULL DEFAULT 0,
                `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end)
end

-- ============================================================
-- SAVE LAST LOCATION
-- ============================================================

RegisterNetEvent('morjard-spawnselector:saveLastLocation', function(x, y, z, heading)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local locData = { x = x, y = y, z = z, heading = heading }

    -- Save to memory
    lastLocations[citizenid] = locData

    -- Save to database
    if Config.UseDatabase then
        MySQL.insert([[
            INSERT INTO `morjard_last_locations` (`citizenid`, `x`, `y`, `z`, `heading`)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `heading` = VALUES(`heading`)
        ]], { citizenid, x, y, z, heading })
    end
end)

-- ============================================================
-- GET LAST LOCATION CALLBACK
-- ============================================================

QBCore.Functions.CreateCallback('morjard-spawnselector:getLastLocation', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end

    local citizenid = Player.PlayerData.citizenid

    -- Check memory first
    if lastLocations[citizenid] then
        cb(lastLocations[citizenid])
        return
    end

    -- Check database
    if Config.UseDatabase then
        MySQL.single('SELECT `x`, `y`, `z`, `heading` FROM `morjard_last_locations` WHERE `citizenid` = ?', { citizenid }, function(result)
            if result then
                local locData = {
                    x = result.x,
                    y = result.y,
                    z = result.z,
                    heading = result.heading,
                }
                lastLocations[citizenid] = locData
                cb(locData)
            else
                cb(nil)
            end
        end)
    else
        cb(nil)
    end
end)

-- ============================================================
-- SPAWN COMPLETE (server-side tracking)
-- ============================================================

RegisterNetEvent('morjard-spawnselector:spawnComplete', function()
    local src = source
    -- Other resources can listen to this event
    -- e.g., enable inventory, show HUD, etc.
end)

-- ============================================================
-- INTEGRATION: external resources can request spawn selector
-- ============================================================

RegisterNetEvent('morjard-spawnselector:requestOpen', function()
    local src = source
    TriggerClientEvent('morjard-spawnselector:open', src)
end)

-- ============================================================
-- SAVE ON DISCONNECT
-- ============================================================

if Config.SaveLastLocation then
    AddEventHandler('playerDropped', function(reason)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end

        local citizenid = Player.PlayerData.citizenid
        local ped = GetPlayerPed(src)

        if ped and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)

            if coords.x ~= 0.0 or coords.y ~= 0.0 then
                lastLocations[citizenid] = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    heading = heading,
                }

                if Config.UseDatabase then
                    MySQL.insert([[
                        INSERT INTO `morjard_last_locations` (`citizenid`, `x`, `y`, `z`, `heading`)
                        VALUES (?, ?, ?, ?, ?)
                        ON DUPLICATE KEY UPDATE `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `heading` = VALUES(`heading`)
                    ]], { citizenid, coords.x, coords.y, coords.z, heading })
                end
            end
        end
    end)
end

-- ============================================================
-- CLEANUP ON RESOURCE STOP
-- ============================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Memory cleanup
    lastLocations = {}
end)
