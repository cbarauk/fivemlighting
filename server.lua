local QBCore = exports['qb-core']:GetCoreObject()
local PlacedLights = {}

RegisterNetEvent('cb-lighting:server:RequestSync', function()
    local src = source
    Wait(1000)
    TriggerClientEvent('cb-lighting:client:SyncLights', src, PlacedLights)
end)

RegisterNetEvent('cb-lighting:server:SyncAllLights', function()
    TriggerClientEvent('cb-lighting:client:SyncLights', -1, PlacedLights)
end)

RegisterNetEvent('cb-lighting:server:SyncAllColors', function(color, brightness)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ownerCitizenId = Player.PlayerData.citizenid
    brightness = tonumber(brightness) or Config.LightDefaults.brightness
    brightness = math.max(Config.MinBrightness, math.min(Config.MaxBrightness, brightness))

    if not color or not color.r or not color.g or not color.b then return end

    for netId, data in pairs(PlacedLights) do
        if data.owner == ownerCitizenId then
            PlacedLights[netId].color = color
            PlacedLights[netId].brightness = brightness
            PlacedLights[netId].lastInteract = os.time()
            TriggerClientEvent('cb-lighting:client:UpdateLightState', -1, netId, color, nil, brightness)
        end
    end
end)

RegisterNetEvent('cb-lighting:server:PlaceLight', function(coords, rot, color, enabled, oldNetId, brightness)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local ownerCitizenId = Player.PlayerData.citizenid
    
    if oldNetId and PlacedLights[oldNetId] then
        if PlacedLights[oldNetId].owner == ownerCitizenId then
            local oldEntity = NetworkGetEntityFromNetworkId(oldNetId)
            if DoesEntityExist(oldEntity) then
                DeleteEntity(oldEntity)
            end
            PlacedLights[oldNetId] = nil
            TriggerClientEvent('cb-lighting:client:RemoveLight', -1, oldNetId)
        end
    end

    local model = Config.LightModel
    local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true, false)
    
    while not DoesEntityExist(obj) do Wait(10) end
    
    SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)

    local netId = NetworkGetNetworkIdFromEntity(obj)
    
    PlacedLights[netId] = {
        coords = coords,
        rot = rot,
        color = color or Config.DefaultColor,
        enabled = enabled ~= nil and enabled or Config.DefaultEnabled,
        brightness = brightness or Config.LightDefaults.brightness,
        owner = ownerCitizenId,
        lastInteract = os.time()
    }

    TriggerClientEvent('cb-lighting:client:SpawnLight', -1, netId, PlacedLights[netId].color, PlacedLights[netId].enabled, PlacedLights[netId].brightness)
end)

RegisterNetEvent('cb-lighting:server:UpdateRotation', function(netId, rot)
    local src = source
    if not PlacedLights[netId] then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, true)
        PlacedLights[netId].rot = rot
        PlacedLights[netId].lastInteract = os.time()
    end
end)

RegisterNetEvent('cb-lighting:server:ToggleLight', function(netId, state)
    local src = source
    if not PlacedLights[netId] then return end

    PlacedLights[netId].enabled = state
    PlacedLights[netId].lastInteract = os.time()
    TriggerClientEvent('cb-lighting:client:UpdateLightState', -1, netId, nil, state, nil)
end)

RegisterNetEvent('cb-lighting:server:ChangeColor', function(netId, color)
    local src = source
    if not PlacedLights[netId] then return end
    if not color or not color.r or not color.g or not color.b then return end

    PlacedLights[netId].color = color
    PlacedLights[netId].lastInteract = os.time()
    TriggerClientEvent('cb-lighting:client:UpdateLightState', -1, netId, color, nil, nil)
end)

RegisterNetEvent('cb-lighting:server:ChangeBrightness', function(netId, brightness)
    local src = source
    if not PlacedLights[netId] then return end

    brightness = tonumber(brightness) or Config.LightDefaults.brightness
    brightness = math.max(Config.MinBrightness, math.min(Config.MaxBrightness, brightness))

    PlacedLights[netId].brightness = brightness
    PlacedLights[netId].lastInteract = os.time()
    TriggerClientEvent('cb-lighting:client:UpdateLightState', -1, netId, nil, nil, brightness)
end)

RegisterNetEvent('cb-lighting:server:PickUp', function(netId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local ownerCitizenId = Player.PlayerData.citizenid

    if PlacedLights[netId] and PlacedLights[netId].owner == ownerCitizenId then
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        
        PlacedLights[netId] = nil
        TriggerClientEvent('cb-lighting:client:RemoveLight', -1, netId)
        
        Player.Functions.AddItem(Config.ItemName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.ItemName], "add")
    else
        TriggerClientEvent('QBCore:Notify', src, "You do not own this light!", "error")
    end
end)

QBCore.Functions.CreateUseableItem(Config.ItemName, function(source, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    Player.Functions.RemoveItem(Config.ItemName, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.ItemName], "remove")
    TriggerClientEvent('cb-lighting:client:UseWorklight', src)
end)

CreateThread(function()
    while true do
        Wait(60000)
        local currentTime = os.time()
        for netId, data in pairs(PlacedLights) do
            if data.lastInteract and (currentTime - data.lastInteract >= Config.Timeout) then
                local entity = NetworkGetEntityFromNetworkId(netId)
                if DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
                PlacedLights[netId] = nil
                TriggerClientEvent('cb-lighting:client:RemoveLight', -1, netId)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    
    for netId, _ in pairs(PlacedLights) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    PlacedLights = {}
end)