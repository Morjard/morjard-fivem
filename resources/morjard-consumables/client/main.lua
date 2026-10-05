RegisterNetEvent('morjard-consumables:client:heal', function(amount, regenSeconds)
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    SetEntityHealth(ped, math.min(200, hp + amount))
    if regenSeconds and regenSeconds > 0 then
        CreateThread(function()
            local ticks = regenSeconds
            while ticks > 0 do
                Wait(1000)
                local p = PlayerPedId()
                local cur = GetEntityHealth(p)
                if cur <= 0 then return end
                SetEntityHealth(p, math.min(200, cur + 10))
                ticks = ticks - 1
            end
        end)
    end
end)

RegisterNetEvent('morjard-consumables:client:repair', function(slot, itemName)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        veh = GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 70)
    end
    if veh == 0 or veh == nil then return end
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, false)
    SetVehicleFixed(veh)
    TriggerServerEvent('morjard-consumables:server:consumeRepair', slot, itemName)
end)
