local isMenuOpen = false
local cam = nil
local currentVehicle = nil

local function getModOptions(vehicle, modType, stockName)
    local numMods = GetNumVehicleMods(vehicle, modType)
    if numMods <= 0 then return nil end

    local options = { { index = -1, name = stockName or "Stock" } }
    for i = 0, numMods - 1 do
        local modNameLabel = GetModTextLabel(vehicle, modType, i)
        local modName = GetLabelText(modNameLabel)
        if modName == "NULL" or modName == "" or not modName then
            modName = "Option #" .. (i + 1)
        end
        table.insert(options, { index = i, name = modName })
    end
    return options
end

RegisterCommand("mods", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not DoesEntityExist(vehicle) then return end

    if Config.RestrictVehicles then
        local model = GetEntityModel(vehicle)
        if not Config.AllowedVehicles[model] then 
            return
        end
    end

    if Config.DisableWhileDriving then
        if GetEntitySpeed(vehicle) > 1.0 then
            return
        end
    end

    currentVehicle = vehicle
    isMenuOpen = true
    SetVehicleModKit(vehicle, 0)

    if Config.EnableCameraControls then
        local initialCamPos = GetGameplayCamCoord()
        cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(cam, initialCamPos.x, initialCamPos.y, initialCamPos.z)
        SetCamFov(cam, GetGameplayCamFov())
        PointCamAtEntity(cam, currentVehicle, 0.0, 0.0, 0.25, true) 
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    local categories = {
        callsign = { displayName = "Set Callsign", type = 'input' }
    }
    local categoryOrder = { 'callsign' }

    for _, item in ipairs(Config.Menu) do
        local modType = Config.ModTypes[item.id]
        if modType then
            local options = getModOptions(vehicle, modType, "Stock")
            if options then
                categories[item.id] = {
                    displayName = item.displayName,
                    modType = modType,
                    options = options,
                    currentIndex = GetVehicleMod(vehicle, modType)
                }
                table.insert(categoryOrder, item.id)
            end
        end
    end

    if #categoryOrder <= 1 then return end

    SendNUIMessage({
        action = "display",
        categories = categories,
        categoryOrder = categoryOrder
    })
    SetNuiFocus(true, true)
end, false)

RegisterNUICallback("dragMove", function(data, cb)
    if not Config.EnableCameraControls then return cb({ success = true }) end
    
    if not isMenuOpen or not cam or not currentVehicle then return cb({ success = true }) end

    local vehPos = GetEntityCoords(currentVehicle)
    local camPos = GetCamCoord(cam)
    
    local newCamX, newCamY, newCamZ = camPos.x, camPos.y, camPos.z

    if data.dx then
        local angle = -data.dx * 0.35 
        local rad = math.rad(angle)
        local cos = math.cos(rad)
        local sin = math.sin(rad)
        local offsetX = newCamX - vehPos.x
        local offsetY = newCamY - vehPos.y
        local newOffsetX = offsetX * cos - offsetY * sin
        local newOffsetY = offsetX * sin + offsetY * cos
        newCamX = vehPos.x + newOffsetX
        newCamY = vehPos.y + newOffsetY
    end

    local foundGround, groundZ = GetGroundZFor_3dCoord(newCamX, newCamY, newCamZ, false)
    
    if data.dy then
        local newZ = newCamZ + (data.dy * 0.02)
        local minHeight = (foundGround and groundZ or vehPos.z) + 0.2
        local maxHeight = vehPos.z + 7.0
        newCamZ = math.max(minHeight, math.min(maxHeight, newZ))
    end

    SetCamCoord(cam, newCamX, newCamY, newCamZ)
    PointCamAtEntity(cam, currentVehicle, 0.0, 0.0, 0.25, true)

    cb({ success = true })
end)

RegisterNUICallback("zoom", function(data, cb)
    if not Config.EnableCameraControls then return cb({ success = true }) end

    if not isMenuOpen or not data.direction or not cam or not currentVehicle then
        cb({ success = false })
        return
    end
    
    local model = GetEntityModel(currentVehicle)
    local min, max = GetModelDimensions(model)
    local minDistance = (#(max - min) / 2.0) + 0.5 

    local maxDistance = 8.0
    local zoomAmount = 0.25

    local vehPos = GetEntityCoords(currentVehicle)
    local camPos = GetCamCoord(cam)

    local offset = camPos - vehPos
    local currentDistance = #(offset)
    if currentDistance < 0.01 then return end

    local newDistance = currentDistance + (data.direction * zoomAmount)
    
    newDistance = math.max(minDistance, math.min(maxDistance, newDistance))

    if math.abs(newDistance - currentDistance) > 0.01 then
        local direction = offset / currentDistance
        local newCamPos = vehPos + (direction * newDistance)
        SetCamCoord(cam, newCamPos.x, newCamPos.y, newCamPos.z)
    end
    
    cb({ success = true })
end)

RegisterNUICallback("setCallsign", function(data, cb)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not DoesEntityExist(vehicle) then cb({ success = false }); return end

    local callsignStr = data.callsign or ""
    if callsignStr ~= "" and not string.match(callsignStr, "^[%d%s]+$") then
        cb({ success = false })
        return
    end

    SetVehicleMod(vehicle, Config.ModTypes.callsign_a, -1, false)
    SetVehicleMod(vehicle, Config.ModTypes.arch_covers, -1, false)
    SetVehicleMod(vehicle, Config.ModTypes.aerials, -1, false)
    SetVehicleMod(vehicle, Config.ModTypes.trim, -1, false)
    SetVehicleMod(vehicle, Config.ModTypes.tank, -1, false)

    local parts = {}
    for part in string.gmatch(callsignStr, "[^%s]+") do
        table.insert(parts, part)
    end

    if parts[1] then
        local topNumbers = parts[1]
        local d1 = tonumber(string.sub(topNumbers, 1, 1))
        if d1 and GetNumVehicleMods(vehicle, Config.ModTypes.callsign_a) > d1 then
            SetVehicleMod(vehicle, Config.ModTypes.callsign_a, d1, false)
        end
        local d2 = tonumber(string.sub(topNumbers, 2, 2))
        if d2 and GetNumVehicleMods(vehicle, Config.ModTypes.arch_covers) > d2 then
            SetVehicleMod(vehicle, Config.ModTypes.arch_covers, d2, false)
        end
        local d3 = tonumber(string.sub(topNumbers, 3, 3))
        if d3 and GetNumVehicleMods(vehicle, Config.ModTypes.aerials) > d3 then
            SetVehicleMod(vehicle, Config.ModTypes.aerials, d3, false)
        end
    end

    if parts[2] then
        local bottomNumbers = parts[2]
        local d1 = tonumber(string.sub(bottomNumbers, 1, 1))
        if d1 and GetNumVehicleMods(vehicle, Config.ModTypes.trim) > d1 then
            SetVehicleMod(vehicle, Config.ModTypes.trim, d1, false)
        end
        local d2 = tonumber(string.sub(bottomNumbers, 2, 2))
        if d2 and GetNumVehicleMods(vehicle, Config.ModTypes.tank) > d2 then
            SetVehicleMod(vehicle, Config.ModTypes.tank, d2, false)
        end
    end

    cb({ success = true })
end)

RegisterNUICallback("select", function(data, cb)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if DoesEntityExist(vehicle) and data.index and data.modType then
        local selectedIndex = tonumber(data.index)
        local modType = tonumber(data.modType)
        SetVehicleMod(vehicle, modType, selectedIndex, false)
    end
    cb({ success = true })
end)

RegisterNUICallback("close", function(data, cb)
    isMenuOpen = false
    SendNUIMessage({ action = "hide" })
    SetNuiFocus(false, false)

    if Config.EnableCameraControls then
        if cam and currentVehicle and DoesEntityExist(currentVehicle) then
            local camRot = GetCamRot(cam, 2)
            local vehHeading = GetEntityHeading(currentVehicle)
            local relativeHeading = camRot.z - vehHeading

            SetGameplayCamRelativeHeading(relativeHeading)
            SetGameplayCamRelativePitch(camRot.x, 1.0)
        end

        RenderScriptCams(false, false, 0, true, true)
        if cam then
            DestroyCam(cam, false)
        end
    end

    cam = nil
    currentVehicle = nil

    cb({ success = true })
end)
