-- paste this entire file into jg-advancedgarages/config-cl.lua, replacing the existing contents

local certBlockLoop = false

AddEventHandler('jg-advancedgarages:client:open-garage', function(garageId)
    if GetResourceState('cert-system') ~= 'started' then return end
    local ok, canAccess = pcall(exports['cert-system'].localPlayerCanAccessGarage, exports['cert-system'], garageId)
    if ok and not canAccess and not certBlockLoop then
        certBlockLoop = true
        CreateThread(function()
            local endTime = GetGameTimer() + 3000
            while GetGameTimer() < endTime do
                SendNUIMessage({ type = 'hide' })
                SetNuiFocus(false, false)
                Wait(50)
            end
            certBlockLoop = false
        end)
    end
end)

---@param vehicle integer Vehicle entity
---@param vehicleDbData table Vehicle row from the database
---@param type "personal" | "job" | "gang"
RegisterNetEvent("jg-advancedgarages:client:InsertVehicle:config", function(vehicle, vehicleDbData, type)

end)

---@param vehicle integer
RegisterNetEvent("jg-advancedgarages:client:ImpoundVehicle:config", function(vehicle)

end)

---@param vehicle integer
---@param vehicleDbData table
---@param type "personal" | "job" | "gang"
RegisterNetEvent("jg-advancedgarages:client:TakeOutVehicle:config", function(vehicle, vehicleDbData, type)
    if not DoesEntityExist(vehicle) then return end

    if GetResourceState("brazzers-fakeplates") == "started" and vehicleDbData and vehicleDbData.fakeplate and vehicleDbData.fakeplate ~= "" then
        SetVehicleNumberPlateText(vehicle, vehicleDbData.fakeplate)
    end

    local plateForKeys = GetVehicleNumberPlateText(vehicle)
    if vehicleDbData and vehicleDbData.fakeplate and vehicleDbData.fakeplate ~= "" then
        plateForKeys = vehicleDbData.fakeplate
    elseif vehicleDbData and vehicleDbData.plate and vehicleDbData.plate ~= "" then
        plateForKeys = vehicleDbData.plate
    end

    if plateForKeys and plateForKeys ~= "" then
        Framework.Client.VehicleGiveKeys(plateForKeys, vehicle, type)
    end

    SetVehicleNeedsToBeHotwired(vehicle, false)
end)

---@param plate string
---@param newOwnerPlayerId integer
RegisterNetEvent("jg-advancedgarages:client:TransferVehicle:config", function(plate, newOwnerPlayerId)

end)

---@param vehicle integer
---@param plate string
---@param garageId string
---@param vehicleDbData table
---@param props table
---@param fuel integer
---@param body integer
---@param engine integer
---@param damageModel table
RegisterNetEvent('jg-advancedgarages:client:insert-vehicle-verification', function(vehicle, plate, garageId, vehicleDbData, props, fuel, body, engine, damageModel, cb)
    cb(true)
end)

---@param plate string
---@param vehicleDbData table
---@param garageId string
lib.callback.register("jg-advancedgarages:client:takeout-vehicle-verification", function(plate, vehicleDbData, garageId)
    if GetResourceState('cert-system') == 'started' then
        local ok, canAccess = pcall(exports['cert-system'].localPlayerCanAccessGarage, exports['cert-system'], garageId)
        if ok and not canAccess then
            lib.notify({ title = 'Access Denied', description = 'You do not have the required certification for this garage', type = 'error' })
            return false
        end
    end
    return true
end)

---@param fromPlayerSrc integer
---@param toPlayerSrc integer
---@param plate string
---@return boolean allowTransfer
lib.callback.register("jg-advancedgarages:client:transfer-vehicle-verification", function(fromPlayerSrc, toPlayerSrc, plate)
    return true
end)

---@param currentGarageId string
---@param fromGarageId string
---@param toGarageId string
---@param plate string
---@return boolean allowTransfer
lib.callback.register("jg-advancedgarages:client:transfer-garage-verification", function(currentGarageId, fromGarageId, toGarageId, plate)
    return true
end)
