local ESX = exports.es_extended:getSharedObject()
local requests = {}

ESX.RegisterServerCallback('coii_pvphud:getSafe', function(source, cb)
    local player = ESX.GetPlayerFromId(source)
    if not player then return cb({ available = false }) end

    local job = player.getJob()
    local unavailable = { available = false, job = job.name }
    if not Config.Safe.Enabled then return cb(unavailable) end
    if Config.Safe.BossOnly and not Config.Safe.BossGrades[job.grade_name] then
        return cb(unavailable)
    end
    if GetResourceState('esx_addonaccount') ~= 'started' then return cb(unavailable) end

    local now = GetGameTimer()
    local previous = requests[source]
    if previous and previous.job == job.name and now - previous.time < 2000 then
        return cb(previous.result or unavailable)
    end
    local request = { job = job.name, time = now }
    requests[source] = request

    local accountName = Config.Safe.Accounts[job.name]
    if not accountName and GetResourceState('esx_society') == 'started' then
        local society = exports.esx_society:GetSociety(job.name)
        accountName = society and society.account
    end
    accountName = accountName or (Config.Safe.AccountPrefix .. job.name)

    -- Never accept an account name or balance from the client.
    TriggerEvent('esx_addonaccount:getSharedAccount', accountName, function(account)
        local currentPlayer = ESX.GetPlayerFromId(source)
        if not currentPlayer or currentPlayer.getJob().name ~= job.name then
            return cb(unavailable)
        end
        request.result = account and {
            available = true, job = job.name, amount = math.floor(tonumber(account.money) or 0)
        } or unavailable
        cb(request.result)
    end)
end)

AddEventHandler('playerDropped', function()
    requests[source] = nil
end)
