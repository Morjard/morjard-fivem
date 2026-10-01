if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

---@type table<number, EntityInterface>
local entityStates = {}

---@param netId number
RegisterNetEvent('morjard_target:setEntityHasOptions', function(netId)
    local src = source
    if not src or src <= 0 then return end
    if type(netId) ~= 'number' then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end
    Entity(entity).state.hasTargetOptions = true
    entityStates[netId] = Entity(entity)
end)

---@param netId number
---@param door number
RegisterNetEvent('morjard_target:toggleEntityDoor', function(netId, door)
    local src = source
    if not src or src <= 0 then return end
    if type(netId) ~= 'number' or type(door) ~= 'number' then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    local owner = NetworkGetEntityOwner(entity)
    if not owner then return end
    TriggerClientEvent('morjard_target:toggleEntityDoor', owner, netId, door)
end)

CreateThread(function()
    local arr = {}
    local num = 0

    while true do
        Wait(10000)

        for netId, entity in pairs(entityStates) do
            if not DoesEntityExist(entity.__data) or not entity.state.hasTargetOptions then
                entityStates[netId] = nil
                num += 1

                arr[num] = netId
            end
        end

        if num > 0 then
            TriggerClientEvent('morjard_target:removeEntity', -1, arr)
            table.wipe(arr)

            num = 0
        end
    end
end)
