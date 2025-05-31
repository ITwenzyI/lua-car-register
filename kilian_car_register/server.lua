ESX = exports["es_extended"]:getSharedObject()

-- Command/event to open registration menu (police only)
RegisterNetEvent("kilian_lspd:openRegistrationMenu")
AddEventHandler("kilian_lspd:openRegistrationMenu", function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if xPlayer.job.name ~= "police" then
        xPlayer.showNotification("You are not authorized to perform this action.")
        return
    end

    -- Select all vehicles that are either unregistered or have numeric 6-digit plates
    MySQL.Async.fetchAll("SELECT owner, plate, vehicle FROM owned_vehicles WHERE plate = '' OR plate REGEXP '^[0-9]{6}$'", {}, function(vehicles)
        local elements = {}

        for _, v in ipairs(vehicles) do
            local vehicleData = json.decode(v.vehicle)
            table.insert(elements, {
                label = (vehicleData.model or "Unknown") .. " - " .. (v.plate or "Unregistered"),
                value = v.plate,
                vehicleData = vehicleData,
                owner = v.owner
            })
        end

        -- Send to client UI
        TriggerClientEvent('kilian_lspd:showRegistrationMenu', src, elements)
    end)
end)

-- Event to update a vehicle's license plate
RegisterNetEvent('kilian_lspd:updatePlate')
AddEventHandler('kilian_lspd:updatePlate', function(oldPlate, newPlate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if xPlayer.job.name ~= "police" then
        xPlayer.showNotification("You are not authorized to perform this action.")
        return
    end

    newPlate = string.upper(newPlate)

    MySQL.Async.fetchAll('SELECT plate, owner, vehicle FROM owned_vehicles WHERE plate = @plate', {['@plate'] = oldPlate}, function(result)
        if result[1] ~= nil then
            local vehicle = json.decode(result[1].vehicle)
            vehicle.plate = newPlate
            local owner = result[1].owner
            local officerName = xPlayer.getName()
            local officerJob = xPlayer.job.name
            local officerGrade = xPlayer.job.grade_label

            -- Get owner name from users table
            MySQL.Async.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = @owner', {['@owner'] = owner}, function(ownerData)
                local ownerName = ownerData[1] and (ownerData[1].firstname .. " " .. ownerData[1].lastname) or "Unknown"

                local ownerPlayer = ESX.GetPlayerFromIdentifier(owner)
                local ownerJob = ownerPlayer and ownerPlayer.job.name or "Unknown"
                local ownerJobGrade = ownerPlayer and ownerPlayer.job.grade_label or "Unknown"

                -- Check for duplicate plate
                MySQL.Async.fetchAll('SELECT plate FROM owned_vehicles WHERE plate = @newplate', {['@newplate'] = newPlate}, function(dupeResult)
                    if #dupeResult == 0 then
                        -- Update vehicle in database
                        MySQL.Async.execute('UPDATE owned_vehicles SET plate = @newplate, vehicle = @vehicle WHERE plate = @oldplate', {
                            ['@newplate'] = newPlate,
                            ['@oldplate'] = oldPlate,
                            ['@vehicle'] = json.encode(vehicle)
                        }, function(rowsChanged)
                            if rowsChanged > 0 then
                                -- Update inventories (if using plate-based inventory IDs)
                                MySQL.Async.execute('UPDATE inventories SET identifier = @newplate WHERE identifier = @oldplate', {
                                    ['@newplate'] = newPlate,
                                    ['@oldplate'] = oldPlate
                                }, function(inventoryRowsChanged)
                                    if inventoryRowsChanged > 0 then
                                        print("Updated inventories table.")
                                    else
                                        print("No entry found in inventories table.")
                                    end
                                end)

                                -- Notify vehicle owner (if online)
                                if ownerPlayer then
                                    ownerPlayer.showNotification("Your vehicle (" .. oldPlate .. ") has been registered with the new plate: " .. newPlate)
                                end

                                -- Notify all police players
                                for _, police in pairs(ESX.GetExtendedPlayers("job", "police")) do
                                    police.showNotification(officerName .. " registered plate " .. newPlate .. " for " .. ownerName)
                                end

                                -- Discord Logging
                                local currentTime = os.date("%d.%m.%Y %H:%M:%S")
                                local webhookUrl = "https://discord.com/api/webhooks"

                                local content = {
                                    username = "🚓 Vehicle Registration",
                                    embeds = {{
                                        title = "📋 **License Plate Registration**",
                                        color = 3066993,
                                        fields = {
                                            { name = "👮‍♂️ Police Officer", value = officerName, inline = false },
                                            { name = "💼 Job (Police)", value = officerJob, inline = true },
                                            { name = "⭐ Rank (Police)", value = officerGrade, inline = true },
                                            { name = "🚗 Vehicle Owner", value = ownerName, inline = false },
                                            { name = "💼 Job (Owner)", value = ownerJob, inline = true },
                                            { name = "⭐ Rank (Owner)", value = ownerJobGrade, inline = true },
                                            { name = "🔑 Old Plate", value = oldPlate, inline = false },
                                            { name = "🔄 New Plate", value = newPlate, inline = false },
                                            { name = "🕒 Time", value = currentTime, inline = true }
                                        }
                                    }}
                                }

                                PerformHttpRequest(webhookUrl, function(statusCode, response, headers)
                                    if statusCode ~= 204 then
                                        print("Failed to send Discord log.")
                                    end
                                end, 'POST', json.encode(content), { ['Content-Type'] = 'application/json' })

                                -- Update all clients
                                TriggerClientEvent('kilian_lspd:updateVehiclePlate', -1, oldPlate, newPlate)
                            end
                        end)
                    else
                        xPlayer.showNotification("This plate is already taken!")
                    end
                end)
            end)
        end
    end)
end)
