local QBCore = exports['qb-core']:GetCoreObject()

-- Utility to fetch player citizenid and playerinfo server-side
local function GetPlayerInfoBySource(src)
    local src = tonumber(src)
    if not src then return nil end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local citizenid = Player.PlayerData.citizenid or Player.PlayerData.citizenid
    local firstname = Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname or Player.PlayerData.metadata and Player.PlayerData.metadata['firstname'] or ''
    local lastname = Player.PlayerData.charinfo and Player.PlayerData.charinfo.lastname or Player.PlayerData.metadata and Player.PlayerData.metadata['lastname'] or ''
    local job = Player.PlayerData.job and Player.PlayerData.job.name or 'unknown'
    return { citizenid = citizenid, firstname = firstname, lastname = lastname, job = job }
end

-- Save minutes worked for a player (increments)
local function SaveMinutesForPlayer(src, minutes)
    local info = GetPlayerInfoBySource(src)
    if not info or not info.citizenid then return end
    local citizenid = info.citizenid
    local job = info.job or 'unknown'

    MySQL.query('SELECT * FROM morjard_biography WHERE citizenid = ?', { citizenid }, function(result)
        if not result then return end
        local row = result[1]
        if row then
            -- parse JSON fields
            local jobs = {}
            if row.jobs and row.jobs ~= '' then
                local ok, parsed = pcall(json.decode, row.jobs)
                if ok and type(parsed) == 'table' then jobs = parsed end
            end
            local history = {}
            if row.job_history and row.job_history ~= '' then
                local ok2, parsed2 = pcall(json.decode, row.job_history)
                if ok2 and type(parsed2) == 'table' then history = parsed2 end
            end

            -- add minutes
            local prev = jobs[job] or 0
            jobs[job] = prev + minutes
            local newTotal = (tonumber(row.total_minutes) or 0) + minutes

            -- append history entry (coalesce with most recent entry if same job)
            if history[1] and history[1].job == job then
                history[1].minutes_added = (tonumber(history[1].minutes_added) or 0) + minutes
                history[1].time = os.time()
            else
                table.insert(history, 1, { job = job, minutes_added = minutes, time = os.time() })
            end
            -- keep history bounded to last 50 entries
            while #history > 50 do table.remove(history) end

            MySQL.update('UPDATE morjard_biography SET firstname = ?, lastname = ?, total_minutes = ?, jobs = ?, job_history = ?, updated_at = NOW() WHERE citizenid = ?',
                { info.firstname, info.lastname, newTotal, json.encode(jobs), json.encode(history), citizenid }, function(affected)
                    -- ok
                end)
        else
            -- create new row
            local jobs = { [job] = minutes }
            local history = { { job = job, minutes_added = minutes, time = os.time() } }
            MySQL.insert('INSERT INTO morjard_biography (citizenid, firstname, lastname, total_minutes, jobs, job_history) VALUES (?, ?, ?, ?, ?, ?)',
                { citizenid, info.firstname, info.lastname, minutes, json.encode(jobs), json.encode(history) }, function(id)
                    -- inserted
                end)
        end
    end)
end

-- Periodic tick from client
RegisterNetEvent('morjard-biography:server:SaveTick', function()
    local src = source
    SaveMinutesForPlayer(src, 1) -- increment by 1 minute per tick
end)

-- Manual save (on drop or forced)
AddEventHandler('playerDropped', function(reason)
    local src = source -- note: in playerDropped handler, `source` is not set - use limited info. We will not rely on this to save; clients send one last tick on disconnect.
end)

-- Shared by both entry points below (command and NUI->event). Looking up your own
-- biography is always allowed; looking up someone else's requires actually being
-- near them server-side (GetEntityCoords on both peds, never trust client-reported
-- distance). Security fix 2026-10-01 -- neither entry point checked this before,
-- so any player could pull anyone else's name/job history/playtime by server ID
-- alone (e.g. just typing /biography 5), with no proximity or permission check.
local function SendBiographyTo(requesterSrc, target)
    if target ~= requesterSrc then
        local requesterPed = GetPlayerPed(requesterSrc)
        local targetPed = GetPlayerPed(target)
        if requesterPed == 0 or targetPed == 0 then
            TriggerClientEvent('morjard-biography:client:OpenUI', requesterSrc, { success = false, message = 'player_offline', target = target })
            return
        end
        local dist = #(GetEntityCoords(requesterPed) - GetEntityCoords(targetPed))
        if dist > (Config.MaxLookupDistance or 5.0) then
            TriggerClientEvent('QBCore:Notify', requesterSrc, 'Player is too far away', 'error')
            return
        end
    end

    local targetPlayer = QBCore.Functions.GetPlayer(target)
    if not targetPlayer then
        TriggerClientEvent('morjard-biography:client:OpenUI', requesterSrc, { success = false, message = 'player_offline', target = target })
        return
    end
    local citizenid = targetPlayer.PlayerData.citizenid

    MySQL.query('SELECT * FROM morjard_biography WHERE citizenid = ?', { citizenid }, function(result)
        if not result then return end
        local row = result[1]
        if not row then
            TriggerClientEvent('morjard-biography:client:OpenUI', requesterSrc, { success = false, message = 'no_data', target = target })
            return
        end

        local jobs = {}
        if row.jobs and row.jobs ~= '' then
            local ok, parsed = pcall(json.decode, row.jobs)
            if ok and type(parsed) == 'table' then jobs = parsed end
        end
        local history = {}
        if row.job_history and row.job_history ~= '' then
            local ok2, parsed2 = pcall(json.decode, row.job_history)
            if ok2 and type(parsed2) == 'table' then history = parsed2 end
        end

        TriggerClientEvent('morjard-biography:client:OpenUI', requesterSrc, {
            success = true,
            data = {
                citizenid = row.citizenid,
                firstname = row.firstname,
                lastname = row.lastname,
                total_minutes = tonumber(row.total_minutes) or 0,
                jobs = jobs,
                job_history = history,
                updated_at = row.updated_at
            },
            target = target
        })
    end)
end

-- Command to open a biography (own or other player's by server ID)
QBCore.Commands.Add(Config.Command, 'Open biography (use player id to view other players, online only)', {{name = 'id', help = 'player server id (optional)'}}, false, function(source, args)
    local target = tonumber(args[1]) or source
    if not QBCore.Functions.GetPlayer(target) then
        TriggerClientEvent('QBCore:Notify', source, 'Player not found or offline', 'error')
        return
    end
    SendBiographyTo(source, target)
end, 'user')

-- Allow UI to request a biography for a given server id (client will call server and server will re-send to requester)
RegisterNetEvent('morjard-biography:server:RequestBiography', function(targetSrc)
    local src = source
    local target = tonumber(targetSrc) or src
    SendBiographyTo(src, target)
end)

-- Server command to force-save a player's current minute (for debugging/admins)
QBCore.Commands.Add('biosave', 'Force save biography minute for yourself', {}, false, function(source, args)
    SaveMinutesForPlayer(source, 1)
    TriggerClientEvent('QBCore:Notify', source, 'Biography saved (1 minute)', 'success')
end, 'user')

-- Allow other server resources to fetch biography via QBCore callback.
-- Security: QBCore's callback system (QBCore:Server:TriggerCallback) is a plain
-- RegisterNetEvent -- ANY registered callback name, including this one, is directly
-- reachable by any client over the network, not just from trusted server-side code.
-- This callback had no check at all, so any player could pull anyone's (even an
-- offline player's) name/job history/playtime by guessing a citizenid, with no
-- distance check even possible here (unlike SendBiographyTo above, citizenid alone
-- doesn't tell us if the target is online to check proximity against). Found/fixed
-- 2026-10-01. Nothing on this server currently calls this export -- restricting to
-- self-lookup only is a safe default; revisit if a real cross-player use case shows up.
QBCore.Functions.CreateCallback('morjard-biography:GetByCitizen', function(source, cb, citizenid)
    if not citizenid then cb(nil); return end
    local requester = QBCore.Functions.GetPlayer(source)
    if not requester or requester.PlayerData.citizenid ~= citizenid then cb(nil); return end
    MySQL.query('SELECT * FROM morjard_biography WHERE citizenid = ?', { citizenid }, function(result)
        if not result then cb(nil); return end
        local row = result[1]
        if not row then cb(nil); return end
        local jobs = {}
        if row.jobs and row.jobs ~= '' then
            local ok, parsed = pcall(json.decode, row.jobs)
            if ok and type(parsed) == 'table' then jobs = parsed end
        end
        local history = {}
        if row.job_history and row.job_history ~= '' then
            local ok2, parsed2 = pcall(json.decode, row.job_history)
            if ok2 and type(parsed2) == 'table' then history = parsed2 end
        end
        cb({
            citizenid = row.citizenid,
            firstname = row.firstname,
            lastname = row.lastname,
            total_minutes = tonumber(row.total_minutes) or 0,
            jobs = jobs,
            job_history = history,
            updated_at = row.updated_at
        })
    end)
end)

-- Sanitize a name string: strip non-alphanumeric/space/dash characters, trim, limit length
local function SanitizeName(name, maxLen)
    if type(name) ~= 'string' then return nil end
    maxLen = maxLen or 50
    -- keep only letters (including accented), digits, spaces, hyphens and apostrophes
    local cleaned = name:gsub('[^%w%s%-\'áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ]', '')
    -- collapse multiple spaces and trim
    cleaned = cleaned:gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if #cleaned > maxLen then cleaned = cleaned:sub(1, maxLen) end
    if cleaned == '' then return nil end
    return cleaned
end

-- Update player's stored name (can be used when character updated)
RegisterNetEvent('morjard-biography:server:SetName', function(firstname, lastname)
    local src = source
    if not src or src <= 0 then return end

    -- Sanitize inputs - reject if both are invalid
    local cleanFirst = SanitizeName(firstname, 50)
    local cleanLast = SanitizeName(lastname, 50)

    local info = GetPlayerInfoBySource(src)
    if not info or not info.citizenid then return end

    -- Use sanitized input or fall back to existing player data
    local finalFirst = cleanFirst or info.firstname
    local finalLast = cleanLast or info.lastname

    MySQL.update('UPDATE morjard_biography SET firstname = ?, lastname = ? WHERE citizenid = ?', { finalFirst, finalLast, info.citizenid }, function(affected)
        -- updated
    end)
end)

print('morjard-biography server loaded')