local ESX = exports["es_extended"]:getSharedObject()

-- Wait for ESX to be ready
Citizen.CreateThread(function()
    while not ESX do
        Citizen.Wait(100)
    end
end)

-- Command to open the registration menu (police only)
RegisterCommand("registercar", function()
    local playerData = ESX.GetPlayerData()
    if playerData and playerData.job and playerData.job.name == "police" then
        TriggerServerEvent("kilian_lspd:openRegistrationMenu")
    else
        ESX.ShowNotification("You can only use this command as LSPD!")
    end
end, false)

-- Receive list of vehicles and open the registration UI
RegisterNetEvent('kilian_lspd:showRegistrationMenu')
AddEventHandler('kilian_lspd:showRegistrationMenu', function(vehicles)
    OpenVehicleRegistrationMenu(vehicles)
end)

-- Main registration menu logic
function OpenVehicleRegistrationMenu(vehicles, searchPlate, nearbyOnly)
    local elements = {}

    if not searchPlate and not nearbyOnly then
        local unregisteredCount = 0
        for _, vehicle in ipairs(vehicles) do
            if not vehicle.value or vehicle.value == "" or vehicle.value:match("^%d%d%d%d%d%d$") then
                unregisteredCount = unregisteredCount + 1
            end
        end
        table.insert(elements, { label = "🚘 Unregistered Vehicles: " .. unregisteredCount, value = nil })
        table.insert(elements, { label = "🔍 Search by Plate", value = "search" })
        table.insert(elements, { label = "🚗 Nearby Vehicles", value = "nearby" })
    end

    for _, vehicle in ipairs(vehicles) do
        local modelName = GetDisplayNameFromVehicleModel(vehicle.vehicleData.model) or vehicle.vehicleData.model or "Unknown"
        if (not searchPlate or (vehicle.value and string.find(vehicle.value, searchPlate:upper()))) and 
           (not nearbyOnly or IsVehicleNearby(vehicle.vehicleData.plate)) then
            table.insert(elements, {
                label = modelName .. " - " .. (vehicle.value or "Unregistered"),
                value = vehicle.value,
                vehicleData = vehicle.vehicleData
            })
        end
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_registration', {
        title = 'Vehicle Registration',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if not data.current.value then return end

        if data.current.value == "search" then
            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'search_plate', {
                title = "Enter license plate"
            }, function(data2, menu2)
                local searchPlate = tostring(data2.value)
                if searchPlate and #searchPlate > 0 then
                    menu2.close()
                    menu.close()
                    OpenVehicleRegistrationMenu(vehicles, searchPlate)
                else
                    ESX.ShowNotification("Please enter a valid license plate!")
                end
            end, function(data2, menu2)
                menu2.close()
            end)
            return

        elseif data.current.value == "nearby" then
            menu.close()
            OpenVehicleRegistrationMenu(vehicles, nil, true)
            return
        end

        local selectedVehicle = data.current
        local playerData = ESX.GetPlayerData()

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'plate_selection', {
            title = 'Plate Options',
            align = 'top-left',
            elements = {
                { label = "Enter custom plate", value = "custom" },
                { label = "Generate random plate", value = "random" }
            }
        }, function(data2, menu2)
            if data2.current.value == "custom" then
                if playerData.job.grade < 8 then
                    ESX.ShowNotification("Only rank 8+ can assign custom plates!")
                    return
                end

                ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'enter_plate', {
                    title = "New plate for " .. selectedVehicle.vehicleData.model
                }, function(data3, menu3)
                    local newPlate = data3.value
                    if newPlate and #newPlate > 0 then
                        TriggerServerEvent('kilian_lspd:updatePlate', selectedVehicle.value, newPlate)
                        menu3.close()
                        menu2.close()
                        menu.close()
                    else
                        ESX.ShowNotification("Please enter a valid plate!")
                    end
                end, function(data3, menu3)
                    menu3.close()
                end)

            elseif data2.current.value == "random" then
                local randomPlate = GenerateRandomPlate()
                TriggerServerEvent('kilian_lspd:updatePlate', selectedVehicle.value, randomPlate)
                menu2.close()
                menu.close()
            end
        end, function(data2, menu2)
            menu2.close()
        end)
    end, function(data, menu)
        menu.close()
    end)
end

-- Helper: Check if vehicle is near the player
function IsVehicleNearby(plate)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        if #(playerCoords - vehicleCoords) < 25.0 then
            local vehiclePlate = GetVehicleNumberPlateText(vehicle)
            if string.gsub(vehiclePlate, "%s+", "") == plate then
                return true
            end
        end
    end
    return false
end

-- Helper: Generate random plate
function GenerateRandomPlate()
    local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local numbers = "0123456789"
    
    local plate = ""
    for i = 1, 3 do
        plate = plate .. letters:sub(math.random(1, #letters), math.random(1, #letters))
    end
    plate = plate .. " "
    for i = 1, 4 do
        plate = plate .. numbers:sub(math.random(1, #numbers), math.random(1, #numbers))
    end
    return plate
end

-- Update the plate on all clients
RegisterNetEvent('kilian_lspd:updateVehiclePlate')
AddEventHandler('kilian_lspd:updateVehiclePlate', function(oldPlate, newPlate)
    local playerPed = PlayerPedId()
    local vehicles = GetGamePool('CVehicle')

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehiclePlate = GetVehicleNumberPlateText(vehicle)
            if string.gsub(vehiclePlate, "%s+", "") == oldPlate then
                SetVehicleNumberPlateText(vehicle, newPlate)
                local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)
                TriggerServerEvent('kilian_lspd:syncVehiclePlate', vehicleNetId, newPlate)
                break
            end
        end
    end
end)

-- Sync vehicle plate from network ID (from server)
RegisterNetEvent('kilian_lspd:syncVehiclePlate')
AddEventHandler('kilian_lspd:syncVehiclePlate', function(vehicleNetId, newPlate)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if DoesEntityExist(vehicle) then
        SetVehicleNumberPlateText(vehicle, newPlate)
    end
end)
