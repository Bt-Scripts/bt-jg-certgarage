local ESX = exports['es_extended']:getSharedObject()

--- Hi

local function getPlayerCerts()
    return LocalPlayer.state.playerCerts or {}
end

local function hasCert(certName)
    return getPlayerCerts()[certName] == true
end


RegisterNetEvent('esx:playerLoaded', function()
    Wait(500)
    TriggerServerEvent('cert-system:server:requestSync')
end)


CreateThread(function()
    Wait(1000)
    TriggerServerEvent('cert-system:server:requestSync')
end)



exports('localPlayerHasCert', function(certName)
    return hasCert(certName)
end)


exports('localPlayerCanAccessGarage', function(garageId)
    local req = Config.GarageRequirements[garageId]
    if not req then return true end
    local pd = ESX.GetPlayerData()
    if pd.job.name ~= req.job then return true end
    if req.minGrade and pd.job.grade >= req.minGrade then return true end
    return hasCert(req.cert)
end)



local function getNearbyPlayers(radius)
    local myCoords = GetEntityCoords(cache.ped)
    local result   = {}
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local dist = #(myCoords - GetEntityCoords(GetPlayerPed(pid)))
            if dist <= (radius or 5.0) then
                result[#result + 1] = {
                    serverId = GetPlayerServerId(pid),
                    name     = GetPlayerName(pid),
                }
            end
        end
    end
    return result
end



local function openGiveMenu(certName)
    local certLabel = Config.Certs[certName].label
    local nearby    = getNearbyPlayers(5.0)

    if #nearby == 0 then
        lib.notify({ title = 'Certifications', description = 'No players within range.', type = 'error' })
        return
    end

    local options = {}
    for _, p in ipairs(nearby) do
        options[#options + 1] = {
            title       = p.name,
            description = 'Server ID: ' .. p.serverId,
            onSelect    = function()
                TriggerServerEvent('cert-system:server:giveCert', p.serverId, certName)
            end,
        }
    end

    lib.registerContext({
        id      = 'cert_give',
        title   = 'Issue: ' .. certLabel,
        menu    = 'cert_sub',
        options = options,
    })
    lib.showContext('cert_give')
end



RegisterNetEvent('cert-system:client:receiveHolders', function(certName, holders, withRevoke)
    local certLabel = Config.Certs[certName] and Config.Certs[certName].label or certName
    local options   = {}

    if #holders == 0 then
        options[1] = { title = 'No current holders', disabled = true }
    else
        for _, h in ipairs(holders) do
            local opt = {
                title       = h.name,
                description = 'CID: ' .. h.citizenid .. ' | Issued: ' .. tostring(h.givenAt),
            }

            if withRevoke then
                local hCopy = h
                opt.onSelect = function()
                    lib.registerContext({
                        id      = 'cert_confirm_revoke',
                        title   = 'Revoke from ' .. hCopy.name .. '?',
                        menu    = 'cert_holders',
                        options = {
                            {
                                title       = 'Confirm Revoke',
                                description = 'This cannot be undone',
                                onSelect    = function()
                                    TriggerServerEvent('cert-system:server:removeCert', hCopy.citizenid, certName)
                                end,
                            },
                            {
                                title    = 'Cancel',
                                onSelect = function() lib.showContext('cert_holders') end,
                            },
                        },
                    })
                    lib.showContext('cert_confirm_revoke')
                end
            end

            options[#options + 1] = opt
        end
    end

    lib.registerContext({
        id      = 'cert_holders',
        title   = (withRevoke and 'Revoke: ' or 'Holders: ') .. certLabel,
        menu    = 'cert_sub',
        options = options,
    })
    lib.showContext('cert_holders')
end)


local function openSubMenu(certName, canGive, canManage)
    local certLabel = Config.Certs[certName].label
    local options   = {}

    if canGive then
        options[#options + 1] = {
            title       = 'Issue Cert',
            description = 'Issue to a nearby player (within 5 m)',
            onSelect    = function() openGiveMenu(certName) end,
        }
    end

    if canManage then
        options[#options + 1] = {
            title       = 'View Holders',
            description = 'See all players who hold this cert',
            onSelect    = function()
                TriggerServerEvent('cert-system:server:getHolders', certName, false)
            end,
        }
        options[#options + 1] = {
            title       = 'Revoke Cert',
            description = 'Remove the cert from a player',
            onSelect    = function()
                TriggerServerEvent('cert-system:server:getHolders', certName, true)
            end,
        }
    end

    lib.registerContext({
        id      = 'cert_sub',
        title   = certLabel,
        menu    = 'cert_main',
        options = options,
    })
    lib.showContext('cert_sub')
end



local function openCertMenu()
    local pd       = ESX.GetPlayerData()
    local jobName  = pd.job.name
    local jobGrade = pd.job.grade
    local options  = {}

    for certName, certData in pairs(Config.Certs) do
        local minGive   = certData.givers[jobName]
        local minManage = certData.managers[jobName]
        local canGive   = minGive   ~= nil and jobGrade >= minGive
        local canManage = minManage ~= nil and jobGrade >= minManage

        if canGive or canManage then
            local cn = certName
            local cg = canGive
            local cm = canManage
            options[#options + 1] = {
                title       = certData.label,
                description = certData.description,
                onSelect    = function() openSubMenu(cn, cg, cm) end,
            }
        end
    end

    if #options == 0 then
        lib.notify({ title = 'Certifications', description = 'You have no cert management access.', type = 'error' })
        return
    end

    lib.registerContext({
        id      = 'cert_main',
        title   = 'Certification Management',
        options = options,
    })
    lib.showContext('cert_main')
end


RegisterCommand('certmenu', function()
    openCertMenu()
end, false)

lib.addKeybind({
    name        = 'cert_open_menu',
    description = 'Open Certification Management',
    defaultKey  = 'F6',
    onPressed   = function()
        openCertMenu()
    end,
})



AddEventHandler('jg-advancedgarages:client:open-garage', function(garageId)
    local req = Config.GarageRequirements[garageId]
    if not req then return end

    local pd = ESX.GetPlayerData()
    if pd.job.name ~= req.job then return end

    if req.minGrade and pd.job.grade >= req.minGrade then return end

    if hasCert(req.cert) then return end

    local certLabel = Config.Certs[req.cert] and Config.Certs[req.cert].label or req.cert
    CreateThread(function()
        Wait(0)
        SendNUIMessage({ type = 'hide' })
        lib.notify({
            title       = 'Access Denied',
            description = 'You require the ' .. certLabel .. ' to access this garage.',
            type        = 'error',
            duration    = 4000,
        })
    end)
end)
