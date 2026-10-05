local QBCore = exports['qb-core']:GetCoreObject()

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin')
end

local function guard(src)
    if not isAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, 'devtest: admin only', 'error')
        return false
    end
    return true
end

RegisterCommand('testinvstash', function(source)
    if not guard(source) then return end
    exports['qb-inventory']:OpenInventory(source, 'stash-devtest', { maxweight = 100000, slots = 50 })
    TriggerClientEvent('morjard-inventory-devtest:ack', source, 'stash')
end, false)

RegisterCommand('testinvtrunk', function(source)
    if not guard(source) then return end
    exports['qb-inventory']:OpenInventory(source, 'trunk-DEVTEST', { maxweight = 60000, slots = 30 })
    TriggerClientEvent('morjard-inventory-devtest:ack', source, 'trunk')
end, false)

RegisterCommand('testinvglove', function(source)
    if not guard(source) then return end
    exports['qb-inventory']:OpenInventory(source, 'glovebox-DEVTEST', { maxweight = 10000, slots = 5 })
    TriggerClientEvent('morjard-inventory-devtest:ack', source, 'glovebox')
end, false)

RegisterCommand('testinvshop', function(source)
    if not guard(source) then return end
    local items = {
        { name = 'bandage', amount = 50,  price = 10, slot = 1 },
        { name = 'bread',   amount = 100, price = 5,  slot = 2 },
        { name = 'water',   amount = 100, price = 5,  slot = 3 },
    }
    exports['qb-inventory']:CreateShop({ name = 'shop-devtest', label = 'Dev Test Shop', slots = 10, items = items })
    exports['qb-inventory']:OpenShop(source, 'shop-devtest')
    TriggerClientEvent('morjard-inventory-devtest:ack', source, 'shop')
end, false)

RegisterCommand('testinvwipe', function(source)
    if not guard(source) then return end
    MySQL.query('DELETE FROM stashitems WHERE stash IN (?, ?)', { 'stash-devtest', 'shop-devtest' })
    TriggerClientEvent('morjard-inventory-devtest:ack', source, 'wipe')
end, false)
