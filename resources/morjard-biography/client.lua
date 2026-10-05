local QBCore = exports['qb-core']:GetCoreObject()
local isOpen = false
local playerTickThread = nil

-- Helper: open UI
local function openUI(payload)
    SendNUIMessage({ action = 'open', payload = payload })
    SetNuiFocus(true, true)
    isOpen = true
end

-- Close UI
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isOpen = false
    cb('ok')
end)

-- NUI request to view player's biography by server id
RegisterNUICallback('requestBiography', function(data, cb)
    local target = tonumber(data.target) or nil
    if target then
        TriggerServerEvent('morjard-biography:server:RequestBiography', target)
    else
        -- open own using command-style flow (server will fetch own data)
        TriggerServerEvent('morjard-biography:server:RequestBiography', GetPlayerServerId(PlayerId()))
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)

-- Server will send UI data to open
RegisterNetEvent('morjard-biography:client:OpenUI', function(payload)
    if payload.success == false then
        openUI({ success = false, message = payload.message or 'no_data' })
        return
    end
    openUI(payload)
end)

-- Tick loop: every Config.TickInterval send a tick to save one minute
CreateThread(function()
    while true do
        Wait(Config.TickInterval or 60000)
        -- send server an increment request
        TriggerServerEvent('morjard-biography:server:SaveTick')
    end
end)

-- register command locally for convenience to open UI
RegisterCommand('biography', function(_, args)
    local id = tonumber(args[1])
    TriggerServerEvent('morjard-biography:server:RequestBiography', id or GetPlayerServerId(PlayerId()))
end, false)

-- Keybind (optional): open own bio with F8? Leaving as command only per request

print('morjard-biography client loaded')