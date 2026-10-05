Config = {}

-- Set any section to false to hide it, then restart the resource.
Config.KillStreakUI = true
Config.InfoHud = true -- Job, grade, cash, bank and job-safe money.
Config.StatusHud = true -- Health and armor.
Config.WeaponHud = true
Config.QuickSlotsUI = true
Config.VehicleHud = true

Config.SpeedUnit = 'kmh' -- 'kmh' or 'mph'
Config.Currency = '$'
Config.Scale = 0.85
Config.UpdateInterval = 100
Config.PlayerRefreshInterval = 200
Config.SafeRefreshInterval = 15000
Config.HideInInventory = true
Config.Radar = 'always' -- 'vehicle', 'always', or 'never'

-- Standard ox_inventory quick slots. ox_inventory handles item use.
Config.QuickSlots = { 1, 2, 3, 4, 5 }
Config.QuickKeys = { '1', '2', '3', '4', '5' } -- Key labels shown on the HUD.
Config.ImagePath = '' -- Leave empty to use ox_inventory item images automatically.

Config.KillStreak = {
    ResetOnDeath = true,
    DuplicateWindow = 2500,
    Levels = {
        { Kills = 2, Label = 'DOUBLE KILL' },
        { Kills = 3, Label = 'TRIPLE KILL' },
        { Kills = 4, Label = 'QUADRA KILL' },
        { Kills = 5, Label = 'RAMPAGE' },
        { Kills = 8, Label = 'DOMINATING' },
        { Kills = 12, Label = 'UNSTOPPABLE' },
        { Kills = 20, Label = 'LEGENDARY' },
    },
}

-- Society balance is read on the server using the player's actual job.
Config.Safe = {
    Enabled = true,
    BossOnly = false,
    BossGrades = { boss = true },
    AccountPrefix = 'society_',
    Accounts = {}, -- Optional job -> account override, e.g. mechanic = 'society_mechanic'.
}
