local ESX = exports['es_extended']:getSharedObject()


CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `player_certs` (
            `id`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(60)  NOT NULL COLLATE utf8mb4_uca1400_ai_ci,
            `cert_name` VARCHAR(100) NOT NULL COLLATE utf8mb4_uca1400_ai_ci,
            `given_by`  VARCHAR(60)  NOT NULL COLLATE utf8mb4_uca1400_ai_ci,
            `given_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_player_cert` (`citizenid`, `cert_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
    ]])
end)



local function getPlayer(source)
    return ESX.GetPlayerFromId(source)
end

local function getPlayerJob(source)
    local p = getPlayer(source)
    if not p then return nil, -1 end
    return p.job.name, p.job.grade
end

local function getCitizenId(source)
    local p = getPlayer(source)
    if not p then return nil end
    return p.identifier
end

local function notify(target, msg, ntype)
    TriggerClientEvent('ox_lib:notify', target, { title = 'Certifications', description = msg, type = ntype })
end



local function canGiveCert(source, certName)
    local cert = Config.Certs[certName]
    if not cert then return false end
    local job, grade = getPlayerJob(source)
    local min = cert.givers[job]
    return min ~= nil and grade >= min
end

local function canManageCert(source, certName)
    local cert = Config.Certs[certName]
    if not cert then return false end
    local job, grade = getPlayerJob(source)
    local min = cert.managers[job]
    return min ~= nil and grade >= min
end



local COLLATE = 'COLLATE utf8mb4_uca1400_ai_ci'

local function dbHasCert(citizenid, certName)
    return MySQL.scalar.await(
        ('SELECT 1 FROM player_certs WHERE citizenid = ? %s AND cert_name = ? %s'):format(COLLATE, COLLATE),
        { citizenid, certName }
    ) ~= nil
end

local function dbGetCertHolders(certName)
    return MySQL.query.await(
        ([[SELECT pc.citizenid, pc.given_by, pc.given_at,
                 u.firstname, u.lastname
          FROM   player_certs pc
          LEFT JOIN users u ON u.identifier %s = pc.citizenid %s
          WHERE  pc.cert_name = ? %s]]):format(COLLATE, COLLATE, COLLATE),
        { certName }
    )
end

local function dbInsertCert(citizenid, certName, giverCitizenId)
    MySQL.insert.await(
        'INSERT IGNORE INTO player_certs (citizenid, cert_name, given_by) VALUES (?, ?, ?)',
        { citizenid, certName, giverCitizenId }
    )
end

local function dbRemoveCert(citizenid, certName)
    MySQL.query.await(
        ('DELETE FROM player_certs WHERE citizenid = ? %s AND cert_name = ? %s'):format(COLLATE, COLLATE),
        { citizenid, certName }
    )
end

local function loadAndSyncCerts(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return end
    local rows = MySQL.query.await(
        ('SELECT cert_name FROM player_certs WHERE citizenid = ? %s'):format(COLLATE),
        { citizenid }
    )
    local certs = {}
    for _, row in ipairs(rows) do
        certs[row.cert_name] = true
    end
    Player(source).state:set('playerCerts', certs, true)
end

local function addCertToStateBag(targetSrc, certName)
    local state = Player(targetSrc).state
    local certs = state.playerCerts or {}
    certs[certName] = true
    state:set('playerCerts', certs, true)
end

local function removeCertFromStateBag(targetSrc, certName)
    local state = Player(targetSrc).state
    local certs = state.playerCerts or {}
    certs[certName] = nil
    state:set('playerCerts', certs, true)
end



AddEventHandler('esx:playerLoaded', function(playerId)
    loadAndSyncCerts(playerId)
end)

RegisterNetEvent('cert-system:server:requestSync', function()
    loadAndSyncCerts(source)
end)


RegisterNetEvent('cert-system:server:giveCert', function(targetSrc, certName)
    local src = source

    if not canGiveCert(src, certName) then
        notify(src, 'You are not authorised to issue this certification.', 'error')
        return
    end

    local targetPlayer = getPlayer(targetSrc)
    if not targetPlayer then
        notify(src, 'Target player not found.', 'error')
        return
    end

    local targetCid = targetPlayer.identifier
    local giverCid  = getCitizenId(src)
    local certLabel = Config.Certs[certName].label

    if dbHasCert(targetCid, certName) then
        notify(src, 'That player already holds the ' .. certLabel .. '.', 'warning')
        return
    end

    dbInsertCert(targetCid, certName, giverCid)
    addCertToStateBag(targetSrc, certName)

    notify(src,       'Issued ' .. certLabel .. ' successfully.',        'success')
    notify(targetSrc, 'You have been issued the ' .. certLabel .. '.', 'success')
end)



RegisterNetEvent('cert-system:server:removeCert', function(citizenid, certName)
    local src = source

    if not canManageCert(src, certName) then
        notify(src, 'You are not authorised to revoke this certification.', 'error')
        return
    end

    if not dbHasCert(citizenid, certName) then
        notify(src, 'That player does not hold this certification.', 'warning')
        return
    end

    dbRemoveCert(citizenid, certName)

    local targetPlayer = ESX.GetPlayerFromIdentifier(citizenid)
    if targetPlayer then
        removeCertFromStateBag(targetPlayer.source, certName)
        notify(targetPlayer.source, 'Your ' .. Config.Certs[certName].label .. ' has been revoked.', 'error')
    end

    notify(src, 'Certification revoked.', 'success')
end)


RegisterNetEvent('cert-system:server:getHolders', function(certName, withRevoke)
    local src = source

    if not canManageCert(src, certName) then return end

    local rows   = dbGetCertHolders(certName)
    local result = {}

    for _, row in ipairs(rows) do
        result[#result + 1] = {
            citizenid = row.citizenid,
            name      = (row.firstname or '?') .. ' ' .. (row.lastname or '?'),
            givenAt   = row.given_at,
            givenBy   = row.given_by,
        }
    end

    TriggerClientEvent('cert-system:client:receiveHolders', src, certName, result, withRevoke)
end)


exports('playerHasCert', function(source, certName)
    local cid = getCitizenId(source)
    if not cid then return false end
    return dbHasCert(cid, certName)
end)


RegisterCommand('givecert', function(source, args)
    local targetId = tonumber(args[1])
    local certName = args[2]

    if not targetId or not certName then
        local msg = '[cert-system] Usage: /givecert <serverId> <certName>'
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = 'Usage: /givecert <serverId> <certName>', type = 'error' }) end
        return
    end

    if not Config.Certs[certName] then
        local certList = {}
        for k in pairs(Config.Certs) do certList[#certList + 1] = k end
        local msg = '[cert-system] Unknown cert "' .. certName .. '". Valid: ' .. table.concat(certList, ', ')
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = msg, type = 'error' }) end
        return
    end

    local targetPlayer = getPlayer(targetId)
    if not targetPlayer then
        local msg = '[cert-system] No player found with server ID ' .. targetId
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = msg, type = 'error' }) end
        return
    end

    local targetCid = targetPlayer.identifier
    local giverCid  = source == 0 and 'console' or (getCitizenId(source) or 'admin')
    local certLabel = Config.Certs[certName].label

    if dbHasCert(targetCid, certName) then
        local msg = '[cert-system] ' .. GetPlayerName(targetId) .. ' already has ' .. certLabel
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = msg, type = 'warning' }) end
        return
    end

    dbInsertCert(targetCid, certName, giverCid)
    addCertToStateBag(targetId, certName)

    local successMsg = 'Issued ' .. certLabel .. ' to ' .. GetPlayerName(targetId) .. ' (ID: ' .. targetId .. ')'
    if source == 0 then print('[cert-system] ' .. successMsg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = successMsg, type = 'success' }) end
    TriggerClientEvent('ox_lib:notify', targetId, { title = 'Certifications', description = 'You have been issued the ' .. certLabel .. '.', type = 'success' })
end, true)

RegisterCommand('revokecert', function(source, args)
    local targetId = tonumber(args[1])
    local certName = args[2]

    if not targetId or not certName then
        local msg = '[cert-system] Usage: /revokecert <serverId> <certName>'
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = 'Usage: /revokecert <serverId> <certName>', type = 'error' }) end
        return
    end

    if not Config.Certs[certName] then
        local msg = '[cert-system] Unknown cert "' .. certName .. '"'
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = msg, type = 'error' }) end
        return
    end

    local targetPlayer = getPlayer(targetId)
    if not targetPlayer then
        local msg = '[cert-system] No player found with server ID ' .. targetId
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = msg, type = 'error' }) end
        return
    end

    local targetCid = targetPlayer.identifier
    local certLabel = Config.Certs[certName].label

    if not dbHasCert(targetCid, certName) then
        local msg = '[cert-system] ' .. GetPlayerName(targetId) .. ' does not have ' .. certLabel
        if source == 0 then print(msg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = msg, type = 'warning' }) end
        return
    end

    dbRemoveCert(targetCid, certName)
    removeCertFromStateBag(targetId, certName)

    local successMsg = 'Revoked ' .. certLabel .. ' from ' .. GetPlayerName(targetId) .. ' (ID: ' .. targetId .. ')'
    if source == 0 then print('[cert-system] ' .. successMsg) else TriggerClientEvent('ox_lib:notify', source, { title = 'Certifications', description = successMsg, type = 'success' }) end
    TriggerClientEvent('ox_lib:notify', targetId, { title = 'Certifications', description = 'Your ' .. certLabel .. ' has been revoked.', type = 'error' })
end, true)


exports('canAccessJobGarage', function(source, garageId)
    local req = Config.GarageRequirements[garageId]
    if not req then return true end

    local p = getPlayer(source)
    if not p then return false end

    if p.job.name ~= req.job then return false end

    if req.minGrade and p.job.grade >= req.minGrade then return true end

    local cid = p.identifier
    return dbHasCert(cid, req.cert)
end)
