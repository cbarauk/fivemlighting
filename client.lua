local QBCore = exports['qb-core']:GetCoreObject()
local PlacementMode = false
local PlacedLights = {} 
local currentPreview = nil
local targetNetId = nil
local editMode = false
local currentPlacementDist = Config.PlacementDistance or 3.0
local currentPlacementZOffset = 0.0

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

RegisterNetEvent('cb-lighting:client:SyncLights', function(lights)
    PlacedLights = lights
    Wait(500)
    for netId, _ in pairs(PlacedLights) do
        local ent = GetSafeEntityFromNetId(netId)
        if ent ~= 0 then
            MakeEntitySolid(ent)
        end
    end
end)

RegisterNetEvent('cb-lighting:client:SpawnLight', function(netId, color, enabled, brightness, maxDistance)
    PlacedLights[netId] = { 
        color = color, 
        enabled = enabled, 
        brightness = brightness or Config.LightDefaults.brightness,
        maxDistance = maxDistance or 0.0
    }
    
    CreateThread(function()
        local timeout = 0
        while timeout < 50 do
            local ent = GetSafeEntityFromNetId(netId)
            if ent ~= 0 then
                MakeEntitySolid(ent)
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

RegisterNetEvent('cb-lighting:client:UpdateLightState', function(netId, color, enabled, brightness, maxDistance)
    if PlacedLights[netId] then
        if color then PlacedLights[netId].color = color end
        if enabled ~= nil then PlacedLights[netId].enabled = enabled end
        if brightness then PlacedLights[netId].brightness = brightness end
        if maxDistance then PlacedLights[netId].maxDistance = maxDistance end
    else
        PlacedLights[netId] = { 
            color = color or Config.DefaultColor, 
            enabled = enabled ~= nil and enabled or Config.DefaultEnabled,
            brightness = brightness or Config.LightDefaults.brightness,
            maxDistance = maxDistance or 0.0
        }
    end
end)

function OpenControlMenu(netId)
    local currentColor = PlacedLights[netId] and PlacedLights[netId].color or Config.DefaultColor
    local currentBrightness = PlacedLights[netId] and PlacedLights[netId].brightness or Config.LightDefaults.brightness
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
        minBrightness = Config.MinBrightness or 0.5,
        maxBrightness = Config.MaxBrightness or 10.0,
        netId = tonumber(netId)
    })
end

RegisterNUICallback('liveUpdateColor', function(data, cb)
    local netId = tonumber(data.netId)
    if netId and data.r then
        local color = {r = math.floor(data.r), g = math.floor(data.g), b = math.floor(data.b)}
        if PlacedLights[netId] then
            PlacedLights[netId].color = color
        else
            PlacedLights[netId] = { color = color, enabled = true, brightness = Config.LightDefaults.brightness }
        end
    end
    cb('ok')
end)

RegisterNUICallback('liveUpdateBrightness', function(data, cb)
    local netId = tonumber(data.netId)
    if netId and data.brightness then
        local val = tonumber(data.brightness)
        if PlacedLights[netId] then
            PlacedLights[netId].brightness = val
        else
            PlacedLights[netId] = { color = Config.DefaultColor, enabled = true, brightness = val }
        end
    end
    cb('ok')
end)

RegisterNUICallback('saveControlPanel', function(data, cb)
    SetNuiFocus(false, false)
    if data and data.netId then
        if data.r then
            TriggerServerEvent('cb-lighting:server:ChangeColor', tonumber(data.netId), {
                r = math.floor(data.r), 
                g = math.floor(data.g), 
                b = math.floor(data.b)
            })
        end
        if data.brightness then
            TriggerServerEvent('cb-lighting:server:ChangeBrightness', tonumber(data.netId), tonumber(data.brightness))
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
    else
        TriggerServerEvent('cb-lighting:server:SyncAllLights')
    end
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
                    end
                },
                {
                    label = 'Move',
                    icon = 'fas fa-arrows-up-down-left-right',
                    action = function(entity)
                        StartPlacement(NetworkGetNetworkIdFromEntity(entity))
                    end
                },
                {
                    label = 'Rotate',
                    icon = 'fas fa-sync',
                    action = function(entity)
                        StartRotateMode(NetworkGetNetworkIdFromEntity(entity))
                    end
                },
                {
                    label = 'Pick Up',
                    icon = 'fas fa-hand-paper',
                    action = function(entity)
                        TriggerServerEvent('cb-lighting:server:PickUp', NetworkGetNetworkIdFromEntity(entity))
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
                end
            },
            {
                label = 'Move',
                icon = 'fas fa-arrows-up-down-left-right',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    StartPlacement(NetworkGetNetworkIdFromEntity(data.entity))
                end
            },
            {
                label = 'Rotate',
                icon = 'fas fa-sync',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    StartRotateMode(NetworkGetNetworkIdFromEntity(data.entity))
                end
            },
            {
                label = 'Pick Up',
                icon = 'fas fa-hand-paper',
                distance = Config.InteractionDistance,
                onSelect = function(data)
                    TriggerServerEvent('cb-lighting:server:PickUp', NetworkGetNetworkIdFromEntity(data.entity))
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
    local maxDistance = 0.0
    local startRot = vec3(0.0, 0.0, 0.0)
    
    if existingNetId then
        local data = PlacedLights[existingNetId]
        if data then
            if type(data.color) == "table" then
                color = { r = data.color.r or 255, g = data.color.g or 255, b = data.color.b or 255 }
            end
            enabled = data.enabled
            brightness = data.brightness or Config.LightDefaults.brightness
            maxDistance = data.maxDistance or 0.0
        end
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
    while not HasModelLoaded(model) do Wait(10) end

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
            SetEntityCoords(currentPreview, dest.x, dest.y, dest.z + currentPlacementZOffset)
            SetEntityLights(currentPreview, false)

            local rot = GetEntityRotation(currentPreview, 2)
            
            if IsControlPressed(0, Config.Controls.RotateLeft.key) then rot = rot + vector3(0, 0, Config.RotationSpeed) end
            if IsControlPressed(0, Config.Controls.RotateRight.key) then rot = rot - vector3(0, 0, Config.RotationSpeed) end
            
            SetEntityRotation(currentPreview, rot.x, rot.y, rot.z, 2, true)

            if IsControlJustPressed(0, Config.Controls.Cancel.key) then
                PlacementMode = false
            elseif IsControlJustPressed(0, Config.Controls.Confirm.key) then
                PlacementMode = false
                local pos = GetEntityCoords(currentPreview)
                local finalRot = GetEntityRotation(currentPreview, 2)
                
                TriggerServerEvent('cb-lighting:server:PlaceLight', pos, finalRot, color, enabled, targetNetId, brightness, maxDistance)
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
            
            if IsControlPressed(0, Config.Controls.RotateLeft.key) then rot = rot + vector3(0, 0, Config.RotationSpeed) end
            if IsControlPressed(0, Config.Controls.RotateRight.key) then rot = rot - vector3(0, 0, Config.RotationSpeed) end
            
            SetEntityRotation(ent, rot.x, rot.y, rot.z, 2, true)

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
        
        for netId, data in pairs(PlacedLights) do
            local ent = GetSafeEntityFromNetId(netId)

            if ent ~= 0 then
                SetEntityLights(ent, false)

                if not IsEntityPositionFrozen(ent) then
                    MakeEntitySolid(ent)
                end

                local entCoords = GetEntityCoords(ent)
                local dist = #(pedCoords - entCoords)
                
                if dist < 80.0 and data.enabled then
                    sleep = 0
                    local rgb = data.color or Config.DefaultColor
                    local r, g, b = 255, 255, 255
                    
                    if type(rgb) == "table" then
                        r = math.floor(rgb.r or 255)
                        g = math.floor(rgb.g or 255)
                        b = math.floor(rgb.b or 255)
                    end
                    
                    local brightness = (data.brightness or Config.LightDefaults.brightness) + 0.0
                    
                    local off = Config.LightDefaults.offset or vector3(0.0, 0.0, 1.8)
                    local dirOffset = Config.LightDefaults.dirOffset or vector3(0.0, -1.0, 0.0)
                    
                    local baseLightPos = GetOffsetFromEntityInWorldCoords(ent, off.x, off.y, off.z)
                    local targetDirPos = GetOffsetFromEntityInWorldCoords(ent, off.x + dirOffset.x, off.y + dirOffset.y, off.z + dirOffset.z)
                    
                    local forwardDir = targetDirPos - baseLightPos
                    local length = #(forwardDir)
                    if length > 0 then
                        forwardDir = forwardDir / length
                    else
                        forwardDir = vector3(0.0, 0.0, -1.0) 
                    end

                    DrawSpotLight(
                        baseLightPos.x, baseLightPos.y, baseLightPos.z,
                        forwardDir.x, forwardDir.y, forwardDir.z,
                        r, g, b,
                        Config.LightDefaults.distance or 25.0,
                        brightness,
                        Config.LightDefaults.roundness or 1.0,
                        Config.LightDefaults.radius or 25.0,
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
    TriggerServerEvent('cb-lighting:server:RequestSync')
end)

RegisterCommand(Config.Command, function()
    StartPlacement()
end, false)