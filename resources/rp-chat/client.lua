local isOpen = false
local isFocused = false
local currentRange = Config.DefaultRange

-- Apply the server-wide hybrid style (Morjard / DDCZ, see morjard-settings) on top
-- of the chat UI's own theming. Safe no-op if morjard-settings isn't present/started.
-- Retries: both resources start via the same `ensure [category]` line in
-- server.cfg with no guaranteed order, so a single immediate attempt could
-- silently give up forever if morjard-settings happens to start a moment
-- later (found 2026-10-01).
CreateThread(function()
    for _ = 1, 10 do
        local ok, style = pcall(function()
            return exports['morjard-settings']:GetStyle()
        end)
        if ok and style then
            SendNUIMessage({ action = 'applyMorjardStyle', style = style })
            return
        end
        Wait(250)
    end
end)

-- Framework detection
local QBCore = nil
local ESX = nil

CreateThread(function()
    if Config.Framework == 'auto' or Config.Framework == 'qbcore' then
        local attempts = 0
        while attempts < 50 do
            local ok, core = pcall(function()
                return exports['qb-core']:GetCoreObject()
            end)
            if ok and core then
                QBCore = core
                break
            end
            attempts = attempts + 1
            Wait(200)
        end
    end
    if not QBCore and (Config.Framework == 'auto' or Config.Framework == 'esx') then
        local ok, esx = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)
        if ok and esx then
            ESX = esx
        end
    end
end)

-- Get player name
local function GetCharacterName()
    if QBCore then
        local PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData and PlayerData.charinfo then
            return PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname
        end
    elseif ESX then
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.firstName then
            return playerData.firstName .. ' ' .. (playerData.lastName or '')
        end
    end
    return GetPlayerName(PlayerId()) or 'Unknown'
end

-- (na žádost uživatele — "vypisovaly příkazy, co na serveru existují") Real
-- server command discovery, same pattern the reference FiveM chat uses
-- (Lachee/fivem-chat's refreshCommands): every command actually registered
-- by ANY resource, filtered to only the ones this player's ACE grants let
-- them run. Sent fresh each time chat opens (permissions/resources can
-- change between opens) — cheap, GetRegisteredCommands() is a plain list.
local function GetUsableCommands()
    local list = {}
    if not GetRegisteredCommands then return list end
    for _, entry in ipairs(GetRegisteredCommands()) do
        if IsAceAllowed(('command.%s'):format(entry.name)) then
            list[#list + 1] = entry.name
        end
    end
    return list
end

-- Open chat
local function OpenChat(prefill)
    isOpen = true
    isFocused = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'show',
        prefill = prefill or ''
    })
    SendNUIMessage({
        action = 'commandList',
        commands = GetUsableCommands(),
    })
end

-- Close chat
local function CloseChat()
    isOpen = false
    isFocused = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

-- ============================================================
-- AVATAR SYSTEM — DB-persistent headshot photos via MugShotBase64
-- Avatars are stored as base64 in DB, shared via server events
-- ============================================================
local avatarCache = {} -- [serverId] = base64 data URL

-- Receive avatar updates from server (for all players)
RegisterNetEvent('rp-chat:avatarUpdate')
AddEventHandler('rp-chat:avatarUpdate', function(serverId, base64)
    if type(serverId) ~= 'number' or type(base64) ~= 'string' then return end
    avatarCache[serverId] = base64
    SendNUIMessage({
        action = 'updateAvatar',
        serverId = serverId,
        avatarUrl = base64
    })
end)

-- Generate own headshot after spawn and send to server
local function GenerateAndUploadAvatar()
    CreateThread(function()
        Wait(3000)
        local ok, base64 = pcall(function()
            return exports['MugShotBase64']:GetMugShotBase64(PlayerPedId(), false)
        end)
        if ok and base64 and type(base64) == 'string' and base64:match('^data:image/') then
            TriggerServerEvent('rp-chat:updateAvatar', base64)
        end
    end)
end

-- Tell the NUI our own name so it can highlight messages that mention us
-- (Nastavení → Zprávy → "Zvýraznit zmínky mého jména") — GetCharacterName()
-- existed but nothing ever actually called it before this.
local function SendMyName()
    SendNUIMessage({ action = 'setMyName', name = GetCharacterName() })
end

-- Generate avatar after session starts
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    Wait(8000)
    -- Request all current avatars from server
    TriggerServerEvent('rp-chat:requestAvatars')
    -- Generate own avatar
    GenerateAndUploadAvatar()
    SendMyName()
end)

-- Regenerate avatar when player loads (character switch)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(5000)
    SendMyName()
    GenerateAndUploadAvatar()
end)

-- Send message to NUI
local function AddMessage(msg)
    if msg.serverId and avatarCache[msg.serverId] then
        msg.avatarUrl = avatarCache[msg.serverId]
    end
    SendNUIMessage({
        action = 'addMessage',
        message = msg
    })
end

-- Register keybind
RegisterCommand('+' .. Config.OpenKeyCommand, function()
    if not isFocused then
        OpenChat()
    end
end, false)

RegisterCommand('-' .. Config.OpenKeyCommand, function() end, false)
RegisterKeyMapping('+' .. Config.OpenKeyCommand, 'Open Chat', 'keyboard', Config.OpenKey)

-- Chat commands registration
RegisterCommand('chatOpen', function(source, args)
    local prefill = args[1] and ('/' .. table.concat(args, ' ')) or ''
    OpenChat(prefill)
end, false)

-- NUI Callbacks
RegisterNUICallback('chatClosed', function(data, cb)
    CloseChat()
    cb('ok')
end)

RegisterNUICallback('focus', function(data, cb)
    SetNuiFocus(data.hasFocus, data.hasCursor)
    cb('ok')
end)

-- Typing indicator — NUI already debounces this (only fires every ~2s while
-- actively typing, see Chat.vue), forwarded straight to the server for
-- range-based broadcast to nearby players.
RegisterNUICallback('typingStart', function(data, cb)
    TriggerServerEvent('rp-chat:typing')
    cb('ok')
end)

RegisterNetEvent('rp-chat:typingUpdate')
AddEventHandler('rp-chat:typingUpdate', function(serverId, name)
    SendNUIMessage({ action = 'typing', serverId = serverId, name = name })
end)

-- Message reactions — emoji react/un-react (server re-broadcasts only to
-- whoever actually received the original message; see server.lua).
RegisterNUICallback('reactMessage', function(data, cb)
    TriggerServerEvent('rp-chat:react', data.msgId, data.emoji)
    cb('ok')
end)

RegisterNetEvent('rp-chat:reactionUpdate')
AddEventHandler('rp-chat:reactionUpdate', function(msgId, emoji, name)
    SendNUIMessage({ action = 'reaction', msgId = msgId, emoji = emoji, name = name })
end)

-- Whitelist of command types this chat resource handles itself.
-- Anything else is forwarded to FXServer's vanilla command dispatcher via
-- ExecuteCommand so /editor, /car, /tx, /admin, /pos etc keep working.
local CHAT_OWNED_COMMANDS = {
    chat = true, me = true, ['do'] = true, ['try'] = true,
    ooc = true, gooc = true,
    whisper = true, shout = true,
    tweet = true, ad = true, news = true,
    radio = true, ['911'] = true, ['311'] = true, ems = true,
    pm = true, r = true,
    announce = true, staff = true, report = true,
    anon = true,
}

-- Studied against the reference FiveM chat implementation (Lachee/fivem-chat):
-- it forwards every '/' message straight to ExecuteCommand() with no local
-- whitelist, relying on GetRegisteredCommands() to know what actually
-- exists. We keep our whitelist (RP commands need server-side color/range
-- handling a bare forward can't give them), but borrow the existence check
-- — without it, a typo'd or non-existent command (e.g. '/tx', which isn't
-- registered by anything on this server; txAdmin's menu is Tab-only) just
-- silently does nothing, which reads to a player as "chat doesn't take
-- commands" with no feedback at all.
local function isRegisteredCommand(cmd)
    if not GetRegisteredCommands then return true end -- older FXServer build: fall through to ExecuteCommand as before
    for _, entry in ipairs(GetRegisteredCommands()) do
        if entry.name:lower() == cmd:lower() then
            return true
        end
    end
    return false
end

RegisterNUICallback('chatMessage', function(data, cb)
    if data.command then
        local cmd = (data.command or ''):gsub('^/', '')

        if CHAT_OWNED_COMMANDS[cmd] then
            -- Server determines range, isGlobal, color, permissions
            TriggerServerEvent('rp-chat:sendMessage', {
                type = cmd,
                text = data.args or '',
            })
        elseif isRegisteredCommand(cmd) then
            -- Let FXServer's command dispatcher handle it.
            -- /editor, /car, /admin, /tp, /pos, /goto, … run their real handlers.
            local args = data.args or ''
            ExecuteCommand(args == '' and cmd or (cmd .. ' ' .. args))
        else
            AddMessage({
                type = 'system',
                tag = 'SYSTEM',
                name = 'Systém',
                text = ('Neznámý příkaz: /%s'):format(cmd),
            })
        end
    else
        -- Regular chat message. replyTo is just display metadata (quoted
        -- snippet of the message being replied to) — passed through as-is,
        -- the server re-sanitizes its text field before broadcasting.
        TriggerServerEvent('rp-chat:sendMessage', {
            type = currentRange == 'whisper' and 'whisper' or (currentRange == 'shout' and 'shout' or 'chat'),
            text = data.message or '',
            replyTo = data.replyTo,
        })
    end

    cb('ok')
end)

-- Receive messages from server
RegisterNetEvent('rp-chat:receiveMessage')
AddEventHandler('rp-chat:receiveMessage', function(msg)
    AddMessage(msg)
end)

-- System messages
RegisterNetEvent('rp-chat:systemMessage')
AddEventHandler('rp-chat:systemMessage', function(text)
    AddMessage({
        type = 'system',
        tag = 'SYSTEM',
        name = 'Systém',
        text = text
    })
end)

-- Clear chat
RegisterNetEvent('rp-chat:clear')
AddEventHandler('rp-chat:clear', function()
    SendNUIMessage({ action = 'clear' })
end)

-- Range change command
RegisterCommand('chatrange', function(source, args)
    local newRange = args[1]
    if newRange and Config.Ranges[newRange] then
        currentRange = newRange
        AddMessage({
            type = 'system',
            tag = 'SYSTEM',
            name = 'Systém',
            text = 'Dosah hlasu změněn na: ' .. newRange
        })
    else
        AddMessage({
            type = 'system',
            tag = 'SYSTEM',
            name = 'Systém',
            text = 'Dostupné dosahy: whisper, normal, shout'
        })
    end
end, false)

-- Clear chat command
RegisterCommand('clearchat', function()
    SendNUIMessage({ action = 'clear' })
end, false)

-- Compatibility with default chat resource (QBCore uses chat:addMessage)
RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(data)
    local msg = {
        type = data.template or 'system',
        tag = 'SYSTEM',
        name = type(data.args) == 'table' and data.args[1] or 'System',
        text = type(data.args) == 'table' and data.args[2] or (type(data.args) == 'string' and data.args or ''),
        color = Config.Colors.system
    }
    -- Handle color array
    if data.color and type(data.color) == 'table' then
        msg.color = ('#%02x%02x%02x'):format(
            data.color[1] or 255,
            data.color[2] or 255,
            data.color[3] or 255
        )
    end
    AddMessage(msg)
end)

RegisterNetEvent('chatMessage')
AddEventHandler('chatMessage', function(author, color, text)
    AddMessage({
        type = 'system',
        tag = 'SYSTEM',
        name = author or 'Server',
        text = text or '',
        color = Config.Colors.system
    })
end)

-- ============================================================
-- TOAST NOTIFICATIONS — separate from the chat log, for other resources
-- to surface alerts (jobs, banking, admin actions, errors, ...).
-- type: 'error' | 'success' | 'info' | 'warning'
-- ============================================================
local function Notify(notifyType, title, message)
    SendNUIMessage({
        action = 'notify',
        notifyType = notifyType,
        title = title,
        message = message,
    })
end

RegisterNetEvent('rp-chat:notify')
AddEventHandler('rp-chat:notify', function(notifyType, title, message)
    Notify(notifyType, title, message)
end)

-- Exports
exports('addMessage', AddMessage)
exports('openChat', OpenChat)
exports('closeChat', CloseChat)
exports('notify', Notify)
exports('isOpen', function() return isOpen end)
exports('isFocused', function() return isFocused end)
