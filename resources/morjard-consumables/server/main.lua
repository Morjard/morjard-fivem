local QBCore = exports['qb-core']:GetCoreObject()

local function updateNeeds(Player, src)
    TriggerClientEvent('hud:client:UpdateNeeds', src,
        Player.PlayerData.metadata['hunger'] or 100,
        Player.PlayerData.metadata['thirst'] or 100)
end

local function consume(source, item, itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return nil end
    if not Player.Functions.GetItemBySlot(item.slot) then return nil end
    Player.Functions.RemoveItem(itemName, 1, item.slot)
    return Player
end

local function registerFood(itemName, amount)
    QBCore.Functions.CreateUseableItem(itemName, { func = function(source, item)
        local Player = consume(source, item, itemName)
        if not Player then return end
        local v = math.min(100, (Player.PlayerData.metadata['hunger'] or 0) + amount)
        Player.Functions.SetMetaData('hunger', v)
        updateNeeds(Player, source)
    end })
end

local function registerDrink(itemName, amount, stressRelief)
    QBCore.Functions.CreateUseableItem(itemName, { func = function(source, item)
        local Player = consume(source, item, itemName)
        if not Player then return end
        local v = math.min(100, (Player.PlayerData.metadata['thirst'] or 0) + amount)
        Player.Functions.SetMetaData('thirst', v)
        updateNeeds(Player, source)
        if stressRelief and stressRelief > 0 then
            local s = math.max(0, (Player.PlayerData.metadata['stress'] or 0) - stressRelief)
            Player.Functions.SetMetaData('stress', s)
            TriggerClientEvent('hud:client:UpdateStress', source, s)
        end
    end })
end

local function registerHeal(itemName, amount, regenSeconds)
    QBCore.Functions.CreateUseableItem(itemName, { func = function(source, item)
        local Player = consume(source, item, itemName)
        if not Player then return end
        TriggerClientEvent('morjard-consumables:client:heal', source, amount, regenSeconds or 0)
    end })
end

local foods = {
    sandwich = 25, tosti = 30, snikkel_candy = 15, twerks_candy = 15,
    pizza_slice = 30, apple = 10, burger = 35, fries = 20, donut = 25, ricebag = 20,
}
for name, amt in pairs(foods) do registerFood(name, amt) end

local drinks = {
    water_bottle = { 25, 0 }, kurkakola = { 20, 0 }, coffee = { 30, 0 }, beer = { 15, 0 },
    whiskey = { 10, 0 }, vodka = { 10, 0 }, wine = { 15, 0 }, energy_drink = { 30, 10 },
}
for name, cfg in pairs(drinks) do registerDrink(name, cfg[1], cfg[2]) end

registerHeal('bandage', 25, 0)
registerHeal('firstaid', 200, 0)
registerHeal('ifaks', 50, 0)
registerHeal('painkillers', 30, 0)
registerHeal('morphine', 200, 10)

QBCore.Functions.CreateUseableItem('lockpick', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.Functions.GetItemBySlot(item.slot) then return end
    TriggerClientEvent('lockpicks:UseLockpick', source, false)
end)

QBCore.Functions.CreateUseableItem('advancedlockpick', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.Functions.GetItemBySlot(item.slot) then return end
    TriggerClientEvent('lockpicks:UseLockpick', source, true)
end)

QBCore.Functions.CreateUseableItem('repairkit', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.Functions.GetItemBySlot(item.slot) then return end
    TriggerClientEvent('morjard-consumables:client:repair', source, item.slot, 'repairkit')
end)

QBCore.Functions.CreateUseableItem('advancedrepairkit', function(source, item)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player or not Player.Functions.GetItemBySlot(item.slot) then return end
    TriggerClientEvent('morjard-consumables:client:repair', source, item.slot, 'advancedrepairkit')
end)

RegisterNetEvent('morjard-consumables:server:consumeRepair', function(slot, _itemName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local slotItem = Player.Functions.GetItemBySlot(slot)
    if not slotItem then return end
    -- (2026-10-05 security audit) Trust the server's view of what sits
    -- in `slot`, not the client-sent `itemName`. On QBCore builds whose
    -- RemoveItem resolves by slot, a client could pass slot=<cheap item>
    -- + itemName='advancedrepairkit' and have the server charge the
    -- cheap item while believing it consumed the kit. Allow only the
    -- two repair items this resource actually registers.
    local name = slotItem.name
    if name ~= 'repairkit' and name ~= 'advancedrepairkit' then return end
    Player.Functions.RemoveItem(name, 1, slot)
end)
