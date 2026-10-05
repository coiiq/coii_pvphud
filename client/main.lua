local ESX = exports.es_extended:getSharedObject()
local ready, enabled, visible = false, true, false
local currentWeapon, inventory = nil, {}
local lastSent, lastJob = {}, nil
local nextPlayer, nextSafe, safeRequest = 0, 0, 0
local safe = { available = false }
local unarmed = joaat('WEAPON_UNARMED')
local killStreak, killStreakSequence = 0, 0
local streakWasDead, countedVictims = false, {}

local function clamp(value, low, high)
    return math.min(high, math.max(low, tonumber(value) or low))
end

local function send(section, data)
    if not ready then return end
    local encoded = json.encode(data)
    if lastSent[section] == encoded then return end
    lastSent[section] = encoded
    SendNUIMessage({ action = section, data = data })
end

local function streakTier(count)
    local tier, label = 0, 'KILL STREAK'
    for index, level in ipairs((Config.KillStreak and Config.KillStreak.Levels) or {}) do
        if count < (tonumber(level.Kills) or math.huge) then break end
        tier, label = index, level.Label or label
    end
    return tier, label
end

local function publishKillStreak(levelUp)
    local tier, label = streakTier(killStreak)
    killStreakSequence = killStreakSequence + 1
    send('killstreak', {
        enabled = Config.KillStreakUI == true,
        visible = killStreak > 0,
        count = killStreak,
        tier = tier,
        label = label,
        levelUp = levelUp == true,
        sequence = killStreakSequence,
    })
end

local function setKillStreak(value)
    local previousTier = streakTier(killStreak)
    killStreak = math.max(0, math.floor(tonumber(value) or 0))
    local currentTier = streakTier(killStreak)
    publishKillStreak(killStreak > 0 and currentTier > previousTier)
end

local function resetKillStreak()
    if killStreak == 0 then return end
    setKillStreak(0)
end

local function nuiImage(path)
    return path and path:gsub('^nui://', 'https://cfx-nui-') or nil
end

local function imageFor(item)
    local metadata = item.metadata or {}
    if type(metadata.imageurl) == 'string' and metadata.imageurl ~= '' then
        return nuiImage(metadata.imageurl)
    end

    local definition
    local ok, result = pcall(function()
        return exports.ox_inventory:Items(item.name)
    end)
    if ok then definition = result end

    local image = metadata.image
        or (definition and definition.client and definition.client.image)
        or (definition and definition.image)

    if type(image) == 'string' and image ~= '' and image:match('^[%w]+://') then
        return nuiImage(image)
    end

    image = type(image) == 'string' and image ~= '' and image or item.name
    if not image:match('%.%w+$') then image = image .. '.png' end

    local path = Config.ImagePath ~= '' and Config.ImagePath
        or GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images')
    return nuiImage(path:gsub('/$', '') .. '/' .. image)
end

local function refreshInventory()
    if GetResourceState('ox_inventory') ~= 'started' then
        inventory, currentWeapon = {}, nil
        return
    end
    inventory = exports.ox_inventory:GetPlayerItems() or {}
    currentWeapon = exports.ox_inventory:getCurrentWeapon()
end

local function quickSlots()
    local slots = {}
    for index = 1, 5 do
        local slotId = Config.QuickSlots[index] or index
        local item = inventory[slotId]
        local data = { key = Config.QuickKeys[index] or tostring(index), slot = slotId, empty = true }
        if item and (item.count or 0) > 0 then
            data.empty = false
            data.name = item.name
            data.label = (item.metadata or {}).label or item.label or item.name
            data.count = item.count
            data.image = imageFor(item)
            data.weapon = item.name:upper():sub(1, 7) == 'WEAPON_'
        end
        slots[index] = data
    end
    send('slots', slots)
end

local function refreshPlayer()
    local data = ESX.GetPlayerData()
    local job = data.job or {}
    if lastJob ~= job.name then
        lastJob, safe, nextSafe = job.name, { available = false }, 0
        safeRequest = safeRequest + 1
    end
    local cash, bank = tonumber(data.money) or 0, 0
    for key, account in pairs(data.accounts or {}) do
        local name = type(account) == 'table' and account.name or key
        local amount = type(account) == 'table' and account.money or account
        if name == 'money' or name == 'cash' then cash = tonumber(amount) or 0 end
        if name == 'bank' then bank = tonumber(amount) or 0 end
    end
    send('player', {
        job = job.label or 'Civilian', grade = job.grade_label or '',
        cash = math.floor(cash), bank = math.floor(bank), safe = safe,
    })
end

local function refreshSafe(now)
    if now < nextSafe then return end
    nextSafe = now + math.max(3000, Config.SafeRefreshInterval)
    safeRequest = safeRequest + 1
    local requestId, jobName = safeRequest, lastJob
    ESX.TriggerServerCallback('coii_pvphud:getSafe', function(result)
        if requestId ~= safeRequest or lastJob ~= jobName then return end
        if type(result) == 'table' and result.job == jobName then
            safe = result
            nextPlayer = 0
        end
    end)
end

local function weaponData(ped)
    local hash = GetSelectedPedWeapon(ped)
    if hash == unarmed or hash == 0 then
        return { armed = false, label = 'Unarmed', clip = 0, reserve = 0, slot = 0 }
    end
    local weapon = currentWeapon
    if weapon and weapon.hash ~= hash then weapon = nil end
    local definition = ESX.GetWeaponFromHash(hash)
    local label = definition and definition.label or 'Weapon'
    local hasClip, clip = GetAmmoInClip(ped, hash)
    local total = GetAmmoInPedWeapon(ped, hash)
    local reserve = math.max(0, total - (hasClip and clip or total))
    -- ox_inventory keeps spare rounds as items instead of native ped ammo.
    if weapon and weapon.ammo then
        local ammoType = (weapon.metadata or {}).specialAmmo
        for _, item in pairs(inventory) do
            if item.name == weapon.ammo and (item.metadata or {}).type == ammoType then
                reserve = reserve + (item.count or 0)
            end
        end
    end
    return {
        armed = true,
        label = weapon and ((weapon.metadata or {}).label or weapon.label) or label,
        image = weapon and imageFor(weapon) or '',
        clip = math.max(0, hasClip and clip or total), reserve = reserve,
        -- Flags 2 + 4 include explosives and firearms, excluding fists/melee.
        showAmmo = IsPedArmed(ped, 6),
        reloading = IsPedReloading(ped), slot = weapon and weapon.slot or 0,
    }
end

RegisterNUICallback('ready', function(_, cb)
    ready, lastSent, nextPlayer = true, {}, 0
    send('config', {
        currency = Config.Currency, unit = Config.SpeedUnit, scale = Config.Scale,
        sections = {
            killstreak = Config.KillStreakUI == true,
            info = Config.InfoHud == true,
            status = Config.StatusHud == true,
            weapon = Config.WeaponHud == true,
            slots = Config.QuickSlotsUI == true,
            vehicle = Config.VehicleHud == true,
        },
    })
    refreshInventory()
    quickSlots()
    publishKillStreak(false)
    cb({ ok = true })
end)

AddEventHandler('ox_inventory:updateInventory', function()
    refreshInventory()
    quickSlots()
end)

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
    currentWeapon = weapon
end)

RegisterNetEvent('esx:playerLoaded', function()
    lastSent, nextPlayer, nextSafe = {}, 0, 0
    killStreak, countedVictims, streakWasDead = 0, {}, false
    publishKillStreak(false)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    safeRequest = safeRequest + 1
    inventory, currentWeapon, safe, lastJob = {}, nil, { available = false }, nil
    visible = false
    killStreak, countedVictims, streakWasDead = 0, {}, false
    send('visible', false)
    publishKillStreak(false)
end)

for _, event in ipairs({ 'esx:setJob', 'esx:setAccountMoney' }) do
    RegisterNetEvent(event, function() nextPlayer = 0 end)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or not Config.KillStreakUI then return end
    local victim, attacker = args and args[1], args and args[2]
    local playerPed = PlayerPedId()
    if not victim or not attacker or attacker ~= playerPed or victim == playerPed
        or not IsEntityAPed(victim) or not IsPedAPlayer(victim) then return end

    local victimPlayer = NetworkGetPlayerIndexFromPed(victim)
    if victimPlayer == -1 then return end
    local victimId = GetPlayerServerId(victimPlayer)
    if not victimId or victimId <= 0 then return end

    CreateThread(function()
        Wait(0)
        if not DoesEntityExist(victim) or (not IsEntityDead(victim) and GetEntityHealth(victim) > 0) then return end
        local now = GetGameTimer()
        local duplicateWindow = math.max(500, tonumber(Config.KillStreak.DuplicateWindow) or 2500)
        if countedVictims[victimId] and now - countedVictims[victimId] < duplicateWindow then return end
        countedVictims[victimId] = now
        setKillStreak(killStreak + 1)
    end)
end)

exports('SetVisible', function(value) enabled = value == true end)
exports('ToggleVisible', function()
    enabled = not enabled
    return enabled
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local loaded = ESX.IsPlayerLoaded()
        -- Escape/pause menu visibility is handled here, independently of export visibility.
        visible = loaded and enabled and not IsPauseMenuActive() and not IsScreenFadedOut()
            and not (Config.HideInInventory and LocalPlayer.state.invOpen == true)
        send('visible', visible)
        if loaded and ready then
            local ped = PlayerPedId()
            local dead = IsEntityDead(ped)
            if Config.KillStreakUI and Config.KillStreak.ResetOnDeath
                and dead and not streakWasDead then resetKillStreak() end
            streakWasDead = dead
            if now >= nextPlayer then
                refreshPlayer()
                refreshInventory()
                quickSlots()
                nextPlayer = now + math.max(500, Config.PlayerRefreshInterval)
            end
            refreshSafe(now)
            if visible then
                local maxHealth = math.max(1, GetEntityMaxHealth(ped) - 100)
                send('vitals', {
                    health = IsEntityDead(ped) and 0 or math.floor(clamp((GetEntityHealth(ped) - 100) / maxHealth * 100, 0, 100)),
                    armor = math.floor(clamp(GetPedArmour(ped), 0, 100)),
                })
                send('weapon', weaponData(ped))
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle ~= 0 then
                    send('vehicle', {
                        active = true,
                        speed = math.floor(GetEntitySpeed(vehicle) * (Config.SpeedUnit == 'mph' and 2.236936 or 3.6) + 0.5),
                        rpm = GetIsVehicleEngineRunning(vehicle) and clamp(GetVehicleCurrentRpm(vehicle), 0, 1) or 0,
                        health = math.floor(clamp(GetVehicleEngineHealth(vehicle) / 10, 0, 100)),
                    })
                else
                    send('vehicle', { active = false })
                end
                send('safezone', clamp((1.0 - GetSafeZoneSize()) * 0.5, 0, 0.1))
            end
        end
        Wait(math.max(50, Config.UpdateInterval))
    end
end)

CreateThread(function()
    while true do
        if visible then
            for _, component in ipairs({ 2, 3, 4, 6, 7, 8, 9, 13, 20 }) do
                HideHudComponentThisFrame(component)
            end
            DisplayAmmoThisFrame(false)
            DisplayRadar(Config.Radar == 'always' or (Config.Radar == 'vehicle' and IsPedInAnyVehicle(PlayerPedId(), false)))
            Wait(0)
        else
            Wait(150)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then DisplayRadar(true) end
end)
