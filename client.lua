local QBCore = exports['qb-core']:GetCoreObject()
local PlacementMode = false
local PlacedLights = {} 
local currentPreview = nil
local targetNetId = nil
local editMode = false
local currentPlacementDist = Config.PlacementDistance or 3.0
local currentPlacementZOffset = 0.0
local modelBottomOffset = 0.0

local function GetMyCid()
    local pData = QBCore.Functions.GetPlayerData()
    return pData and pData.citizenid or nil
end

local function PlayLightAnim(animType)
    local dict = "anim@mp_snowball"
    local anim = "pickup_snowball"
    if animType == 'place' then
        anim = "pickup_snowball"
    else
        dict = "pickup_object"
        anim = "pickup_low"
    end
    
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) do 
        Wait(10) 
        timeout = timeout + 1
        if timeout > 50 then return end
    end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, 8.0, 1000, 48, 0, false, false, false)
end

local function ShowUI(title, controls)
    SendNUIMessage({
        action = 'show',
        title = title,
        controls = controls
    })
end

local function HideUI()
    SendNUIMessage({
        action = 'hide'
    })
end

local function MakeEntitySolid(ent)
    if DoesEntityExist(ent) then
        SetEntityCollision(ent, true, true)
        FreezeEntityPosition(ent, true)
        SetEntityInvincible(ent, true)
        SetEntityCanBeDamaged(ent, false)
        SetEntityLights(ent, false)
    end
end

local function GetSafeEntityFromNetId(netId)
    if not netId or not NetworkDoesEntityExistWithNetworkId(netId) then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(ent) then return ent end
    return 0
end

local function CacheLightData(netId, data)
    local ent = GetSafeEntityFromNetId(netId)
    if ent ~= 0 then
        data.ent = ent
        data.entCoords = GetEntityCoords(ent)
        MakeEntitySolid(ent)
        
        if data.rot then 
            SetEntityRotation(ent, data.rot.x, data.rot.y, data.rot.z, 2, true) 
        end

        local off = Config.LightDefaults.offset or vector3(0.0, 0.0, 0.0)
        local dirOffset = Config.LightDefaults.dirOffset or vector3(0.0, -1.0, 0.0)
        
        data.basePos = GetOffsetFromEntityInWorldCoords(ent, off.x, off.y, off.z)
        local targetPos = GetOffsetFromEntityInWorldCoords(ent, off.x + dirOffset.x, off.y + dirOffset.y, off.z + dirOffset.z)
        
        local dir = targetPos - data.basePos
        local len = #(dir)
        data.forwardDir = len > 0 and (dir / len) or vector3(0.0, 0.0, -1.0)
    else
        data.ent = nil
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cb-lighting:server:RequestSync')
end)

RegisterNetEvent('cb-lighting:client:SyncLights', function(lights)
    PlacedLights = lights
    local myCid = GetMyCid()
    Wait(500)
    for netId, data in pairs(PlacedLights) do
        data.isOwner = (data.owner == myCid)
        data.ent = nil 
    end
end)

-- Added back to catch entity spawn and register state bag handlers
RegisterNetEvent('cb-lighting:client:SpawnLight', function(netId, color, enabled, brightness, distance, width, owner, rot)
    local myCid = GetMyCid()
    PlacedLights[netId] = { 
        color = color, 
        enabled = enabled, 
        brightness = brightness or Config.LightDefaults.brightness,
        distance = distance or Config.LightDefaults.distance,
        width = width or Config.LightDefaults.width,
        owner = owner,
        isOwner = (owner == myCid),
        ent = nil,
        rot = rot
    }
    
    CreateThread(function()
        local timeout = 0
        while timeout < 50 do
            local ent = GetSafeEntityFromNetId(netId)
            if ent ~= 0 then
                CacheLightData(netId, PlacedLights[netId])
                
                -- Listen for State Bag updates on this specific entity
                AddStateBagChangeHandler('brightness', 'entity:' .. netId, function(bagName, key, value)
                    if PlacedLights[netId] then PlacedLights[netId].brightness = value end
                end)
                AddStateBagChangeHandler('distance', 'entity:' .. netId, function(bagName, key, value)
                    if PlacedLights[netId] then PlacedLights[netId].distance = value end
                end)
                AddStateBagChangeHandler('width', 'entity:' .. netId, function(bagName, key, value)
                    if PlacedLights[netId] then PlacedLights[netId].width = value end
                end)
                AddStateBagChangeHandler('color', 'entity:' .. netId, function(bagName, key, value)
                    if PlacedLights[netId] then PlacedLights[netId].color = value end
                end)
                AddStateBagChangeHandler('rot', 'entity:' .. netId, function(bagName, key, value)
                    if PlacedLights[netId] then 
                        PlacedLights[netId].rot = value 
                        PlacedLights[netId].ent = nil -- Force cache refresh
                    end
                end)
                break
            end
            timeout = timeout + 1
            Wait(100)
        end
    end)
end)

RegisterNetEvent('cb-lighting:client:RemoveLight', function(netId)
    PlacedLights[netId] = nil
end)

RegisterNetEvent('cb-lighting:client:PlayAnim', function(animType)
    PlayLightAnim(animType)
end)

function OpenControlMenu(netId)
    local currentColor = PlacedLights[netId] and PlacedLights[netId].color or Config.DefaultColor
    local currentBrightness = PlacedLights[netId] and PlacedLights[netId].brightness or Config.LightDefaults.brightness
    local currentDistance = PlacedLights[netId] and PlacedLights[netId].distance or Config.LightDefaults.distance
    local currentWidth = PlacedLights[netId] and PlacedLights[netId].width or Config.LightDefaults.width
    local r, g, b = 255, 255, 255
    
    if type(currentColor) == "table" then
        r = math.floor(currentColor.r or 255)
        g = math.floor(currentColor.g or 255)
        b = math.floor(currentColor.b or 255)
    end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openControlPanel',
        color = {r = r, g = g, b = b},
        brightness = currentBrightness,
        distance = currentDistance,
        width = currentWidth,
        minBrightness = Config.MinBrightness or 0.5,
        maxBrightness = Config.MaxBrightness or 10.0,
        netId = tonumber(netId)
    })
end

RegisterNUICallback('liveUpdate', function(data, cb)
    local netId = tonumber(data.netId)
    if netId and data.r then
        local color = {r = math.floor(data.r), g = math.floor(data.g), b = math.floor(data.b)}
        local brightness = tonumber(data.brightness) or Config.LightDefaults.brightness
        local distance = tonumber(data.distance) or Config.LightDefaults.distance
        local width = tonumber(data.width) or Config.LightDefaults.width
        
        if PlacedLights[netId] then
            PlacedLights[netId].color = color
            PlacedLights[netId].brightness = brightness
            PlacedLights[netId].distance = distance
            PlacedLights[netId].width = width
        else
            PlacedLights[netId] = { 
                color = color, 
                enabled = true, 
                brightness = brightness, 
                distance = distance,
                width = width,
                ent = nil 
            }
        end

        local ent = GetSafeEntityFromNetId(netId)
        if ent ~= 0 then
            Entity(ent).state:set('brightness', brightness, true)
            Entity(ent).state:set('distance', distance, true)
            Entity(ent).state:set('width', width, true)
            Entity(ent).state:set('color', color, true)
        end
    end
    cb('ok')
end)

RegisterNUICallback('saveControlPanel', function(data, cb)
    SetNuiFocus(false, false)
    if data and data.netId then
        if data.r then
            TriggerServerEvent('cb-lighting:server:SaveLightSettings', tonumber(data.netId), {
                r = math.floor(data.r), 
                g = math.floor(data.g), 
                b = math.floor(data.b)
            }, tonumber(data.brightness), tonumber(data.distance), tonumber(data.width))
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeControlPanel', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('syncAllLights', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideControlPanel' })
    
    if data.r then
        local color = {r = math.floor(data.r), g = math.floor(data.g), b = math.floor(data.b)}
        local brightness = tonumber(data.brightness) or Config.LightDefaults.brightness
        TriggerServerEvent('cb-lighting:server:SyncAllColors', color, brightness)
        QBCore.Functions.Notify('Applying color to all studio lights globally...', 'primary')
    end
    cb('ok')
end)

function OpenShopUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openShop',
        items = Config.ShopItems
    })
end

RegisterNUICallback('closeShop', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('processPurchase', function(data, cb)
    TriggerServerEvent('cb-lighting:server:ProcessPurchase', data.cart, data.paymentType)
    SetNuiFocus(false, false)
    cb('ok')
end)

local function SetupTarget()
    local model = Config.LightModel

    if Config.Target == 'qb-target' then
        pcall(function() 
            exports['qb-target']:RemoveTargetModel(model, { 
                'Light Settings', 'Light Controls', 'Move', 'Rotate', 'Pick Up',
                'Change Colour', 'Adjust Brightness', 'Turn Light On/Off', 'Sync All Lights' 
            }) 
        end)
        
        exports['qb-target']:AddTargetModel(model, {
            options = {
                {
                    label = 'Light Controls',
                    icon = 'fas fa-sliders',
                    action = function(entity)
                        OpenControlMenu(NetworkGetNetworkIdFromEntity(entity))
                    end,
                    canInteract = function(entity)
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        return PlacedLights[netId] and PlacedLights[netId].isOwner
                    end
                },
                {
                    label = 'Move',
                    icon = 'fas fa-arrows-up-down-left-right',
                    action = function(entity)
                        StartPlacement(NetworkGetNetworkIdFromEntity(entity))
                    end,
                    canInteract = function(entity)
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        return PlacedLights[netId] and PlacedLights[netId].isOwner
                    end
                },
                {
                    label = 'Rotate',
                    icon = 'fas fa-sync',
                    action = function(entity)
                        StartRotateMode(NetworkGetNetworkIdFromEntity(entity))
                    end,
                    canInteract = function(entity)
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        return PlacedLights[netId] and PlacedLights[netId].isOwner
                    end
                },
                {
                    label = 'Pick Up',
                    icon = 'fas fa-hand-paper',
                    action = function(entity)
                        TriggerServerEvent('cb-lighting:server:PickUp', NetworkGetNetworkIdFromEntity(entity))
                    end,
                    canInteract = function(entity)
                        local netId = NetworkGetNetworkIdFromEntity(entity)
                        return PlacedLights[netId] and PlacedLights[netId].isOwner
                    end
                }
            },
            distance = Config.InteractionDistance
        })

    elseif Config.Target == 'ox_target' then
        local oxOptions = {
            {
                label = 'Light Controls',
                icon = 'fas fa-sliders',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    OpenControlMenu(NetworkGetNetworkIdFromEntity(data.entity))
                end,
                canInteract = function(entity, distance, _)
                    local netId = NetworkGetNetworkIdFromEntity(entity)
                    return PlacedLights[netId] and PlacedLights[netId].isOwner
                end
            },
            {
                label = 'Move',
                icon = 'fas fa-arrows-up-down-left-right',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    StartPlacement(NetworkGetNetworkIdFromEntity(data.entity))
                end,
                canInteract = function(entity, distance, _)
                    local netId = NetworkGetNetworkIdFromEntity(entity)
                    return PlacedLights[netId] and PlacedLights[netId].isOwner
                end
            },
            {
                label = 'Rotate',
                icon = 'fas fa-sync',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    StartRotateMode(NetworkGetNetworkIdFromEntity(data.entity))
                end,
                canInteract = function(entity, distance, _)
                    local netId = NetworkGetNetworkIdFromEntity(entity)
                    return PlacedLights[netId] and PlacedLights[netId].isOwner
                end
            },
            {
                label = 'Pick Up',
                icon = 'fas fa-hand-paper',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    TriggerServerEvent('cb-lighting:server:PickUp', NetworkGetNetworkIdFromEntity(data.entity))
                end,
                canInteract = function(entity, distance, _)
                    local netId = NetworkGetNetworkIdFromEntity(entity)
                    return PlacedLights[netId] and PlacedLights[netId].isOwner
                end
            }
        }
        exports['ox_target']:addModel(model, oxOptions)
    end
end

function GetPlacementCoords(distOverride)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local fwd = vector3(-math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))), math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))), math.sin(math.rad(camRot.x)))
    
    local targetDistance = distOverride or Config.PlacementDistance or 3.0
    local dest = pos + (fwd * targetDistance)
    
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(camCoords, dest + (fwd * 5.0), 511, ped, 7)
    local _, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
    
    if hit == 1 then return true, endCoords end
    return false, dest
end

function StartPlacement(existingNetId)
    local ped = PlayerPedId()
    PlacementMode = true
    currentPlacementDist = Config.PlacementDistance or 3.0
    currentPlacementZOffset = 0.0
    
    local color = Config.DefaultColor
    local enabled = Config.DefaultEnabled
    local brightness = Config.LightDefaults.brightness
    local distance = Config.LightDefaults.distance
    local width = Config.LightDefaults.width
    local startRot = vec3(0.0, 0.0, 0.0)
    
    if existingNetId then
        local data = PlacedLights[existingNetId]
        if not data or not data.isOwner then
            QBCore.Functions.Notify('You do not own this light!', 'error')
            PlacementMode = false
            return
        end
        
        if type(data.color) == "table" then
            color = { r = data.color.r or 255, g = data.color.g or 255, b = data.color.b or 255 }
        end
        enabled = data.enabled
        brightness = data.brightness or Config.LightDefaults.brightness
        distance = data.distance or Config.LightDefaults.distance
        width = data.width or Config.LightDefaults.width
        
        local ent = GetSafeEntityFromNetId(existingNetId)
        if ent ~= 0 then 
            startRot = GetEntityRotation(ent, 2)
            DeleteEntity(ent) 
        end
        targetNetId = existingNetId
    else
        targetNetId = nil
    end

    local model = Config.LightModel
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do 
        Wait(10) 
        timeout = timeout + 1
        if timeout > 50 then return end
    end

    local min, max = GetModelDimensions(model)
    modelBottomOffset = -min.z

    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, 0.0)
    currentPreview = CreateObject(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)
    SetEntityAlpha(currentPreview, 150, false)
    SetEntityCollision(currentPreview, false, false)
    SetEntityDrawOutline(currentPreview, true)
    SetEntityRotation(currentPreview, startRot.x, startRot.y, startRot.z, 2, true)

    ShowUI("Lighting Controls", {
        { key = Config.Controls.Confirm.label, action = "Place" },
        { key = Config.Controls.Cancel.label, action = "Cancel" },
        { key = Config.Controls.MoveUp.label, action = "Height Up" },
        { key = Config.Controls.MoveDown.label, action = "Height Down" },
        { key = Config.Controls.RotateLeft.label, action = "Rotate" }
    })

    CreateThread(function()
        while PlacementMode do
            if IsControlPressed(0, Config.Controls.MoveUp.key) then 
                currentPlacementZOffset = math.min(10.0, currentPlacementZOffset + 0.05)
            elseif IsControlPressed(0, Config.Controls.MoveDown.key) then 
                currentPlacementZOffset = math.max(-10.0, currentPlacementZOffset - 0.05)
            end

            local hit, dest = GetPlacementCoords(currentPlacementDist)
            local targetZ = dest.z + currentPlacementZOffset + modelBottomOffset
            SetEntityCoords(currentPreview, dest.x, dest.y, targetZ)
            SetEntityLights(currentPreview, false)

            local rot = GetEntityRotation(currentPreview, 2)
            local rotChanged = false
            
            if IsControlPressed(0, Config.Controls.RotateLeft.key) then 
                rot = rot + vector3(0, 0, Config.RotationSpeed)
                rotChanged = true
            end
            if IsControlPressed(0, Config.Controls.RotateRight.key) then 
                rot = rot - vector3(0, 0, Config.RotationSpeed)
                rotChanged = true
            end
            
            if rotChanged then
                SetEntityRotation(currentPreview, rot.x, rot.y, rot.z, 2, true)
            end

            if IsControlJustPressed(0, Config.Controls.Cancel.key) then
                PlacementMode = false
            elseif IsControlJustPressed(0, Config.Controls.Confirm.key) then
                PlacementMode = false
                local finalCoords = GetEntityCoords(currentPreview)
                local finalRot = GetEntityRotation(currentPreview, 2)
                
                PlayLightAnim('place')
                TriggerServerEvent('cb-lighting:server:PlaceLight', finalCoords, finalRot, color, enabled, targetNetId, brightness, distance, width)
            end
            Wait(0)
        end

        HideUI()
        if currentPreview then
            SetEntityDrawOutline(currentPreview, false)
            DeleteEntity(currentPreview)
            currentPreview = nil
        end
    end)
end

function StartRotateMode(netId)
    if not PlacedLights[netId] or not PlacedLights[netId].isOwner then
        QBCore.Functions.Notify('You do not own this light!', 'error')
        return
    end

    editMode = true
    local ent = GetSafeEntityFromNetId(netId)
    if ent == 0 then return end

    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) do Wait(10) end

    QBCore.Functions.Notify('Rotate Mode Active', 'primary')
    
    ShowUI("Lighting Controls", {
        { key = Config.Controls.Confirm.label, action = "Save" },
        { key = Config.Controls.Cancel.label, action = "Cancel" },
        { key = Config.Controls.RotateLeft.label, action = "Rotate" }
    })

    CreateThread(function()
        while editMode do
            local rot = GetEntityRotation(ent, 2)
            local rotChanged = false
            
            if IsControlPressed(0, Config.Controls.RotateLeft.key) then 
                rot = rot + vector3(0, 0, Config.RotationSpeed)
                rotChanged = true
            end
            if IsControlPressed(0, Config.Controls.RotateRight.key) then 
                rot = rot - vector3(0, 0, Config.RotationSpeed)
                rotChanged = true
            end
            
            if rotChanged then
                SetEntityRotation(ent, rot.x, rot.y, rot.z, 2, true)
            end

            if IsControlJustPressed(0, Config.Controls.Confirm.key) then
                editMode = false
                MakeEntitySolid(ent)
                TriggerServerEvent('cb-lighting:server:UpdateRotation', netId, rot)
            elseif IsControlJustPressed(0, Config.Controls.Cancel.key) then
                editMode = false
                MakeEntitySolid(ent)
            end
            Wait(0)
        end
        HideUI()
    end)
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pedCoords = GetEntityCoords(ped)
        local renderDist = Config.RenderDistance or 80.0
        local renderDistSq = renderDist * renderDist
        
        for netId, data in pairs(PlacedLights) do
            if not data.ent or not DoesEntityExist(data.ent) then
                CacheLightData(netId, data)
            end
            
            local ent = data.ent
            if ent and ent ~= 0 and data.basePos then
                local entCoords = data.entCoords
                local dx, dy, dz = pedCoords.x-entCoords.x, pedCoords.y-entCoords.y, pedCoords.z-entCoords.z
                local distSq = dx*dx + dy*dy + dz*dz
                
                if distSq < renderDistSq and data.enabled then
                    sleep = 0
                    local rgb = data.color or Config.DefaultColor
                    local r, g, b = 255, 255, 255
                    
                    if type(rgb) == "table" then
                        r = math.floor(rgb.r or 255)
                        g = math.floor(rgb.g or 255)
                        b = math.floor(rgb.b or 255)
                    end
                    
                    local brightness = (data.brightness or Config.LightDefaults.brightness) + 0.0
                    local distance = (data.distance or Config.LightDefaults.distance or 25.0) + 0.0
                    local width = (data.width or Config.LightDefaults.width or 25.0) + 0.0

                    DrawSpotLight(
                        data.basePos.x, data.basePos.y, data.basePos.z,
                        data.forwardDir.x, data.forwardDir.y, data.forwardDir.z,
                        r, g, b,
                        distance,
                        brightness,
                        Config.LightDefaults.roundness or 1.0,
                        width,
                        Config.LightDefaults.falloff or 10.0
                    )
                end
            end
        end
        Wait(sleep)
    end
end)

local isStudioNight = false

if Config.EnableNightTimeCommand then
    RegisterCommand('cbnighttime', function()
        isStudioNight = not isStudioNight

        if isStudioNight then
            NetworkOverrideClockTime(22, 0, 0)
            SetWeatherTypeNowPersist("CLEAR")
            QBCore.Functions.Notify('Studio Nighttime Enabled (22:00)', 'success')
        else
            NetworkClearClockTimeOverride()
            ClearWeatherTypePersist()
            QBCore.Functions.Notify('Studio Nighttime Disabled (Reverted to Server Time)', 'primary')
        end
    end, false)
end

RegisterNetEvent('cb-lighting:client:UseWorklight', function()
    StartPlacement()
end)

CreateThread(function()
    while QBCore == nil do Wait(10) end
    SetupTarget()
    
    if not LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('cb-lighting:server:RequestSync')
    end
    
    local npcModel = Config.ShopNpc.model
    RequestModel(npcModel)
    local timeout = 0
    while not HasModelLoaded(npcModel) do 
        Wait(10) 
        timeout = timeout + 1
        if timeout > 50 then return end
    end
    
    local npc = CreatePed(4, npcModel, Config.ShopNpc.coords.x, Config.ShopNpc.coords.y, Config.ShopNpc.coords.z - 1.0, Config.ShopNpc.coords.w, false, false)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    SetModelAsNoLongerNeeded(npcModel)

    if Config.Target == 'qb-target' then
        exports['qb-target']:AddTargetEntity(npc, {
            options = {
                {
                    label = 'Open Shop',
                    icon = 'fas fa-store',
                    action = function()
                        OpenShopUI()
                    end
                }
            },
            distance = 2.5
        })
    elseif Config.Target == 'ox_target' then
        exports['ox_target']:addLocalEntity(npc, {
            {
                label = 'Open Shop',
                icon = 'fas fa-store',
                onSelect = function()
                    OpenShopUI()
                end
            }
        })
    end
end)

RegisterCommand(Config.Command, function()
    StartPlacement()
end, false)