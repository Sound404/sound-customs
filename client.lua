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

    isMenuOpen = true
    SetVehicleModKit(vehicle, 0)

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
    SendNUIMessage({ action = "hide" })
    SetNuiFocus(false, false)
    isMenuOpen = false
    cb({ success = true })
end)