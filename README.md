# coii_pvphud

A clean, compact FiveM HUD for ESX and ox_inventory.

- Animated kill-streak counter with milestone effects.
- Weapon HUD with weapon image, name and ammunition.
- Status HUD with health and armor bars.
- Job and grade, cash, bank balance and job-safe money.
- Five inventory quick slots and a vehicle speedometer.

## HUD sections

Each HUD section can be enabled separately in `config.lua`: `true` shows it and `false` hides it. After changing an option, run `restart coii_pvphud`.

```lua
Config.KillStreakUI = true -- Animated kill-streak counter.
Config.InfoHud = true -- Job, grade, cash, bank and job-safe money.
Config.StatusHud = true -- Health and armor.
Config.WeaponHud = true -- Weapon image, name and ammunition.
Config.QuickSlotsUI = true -- Inventory quick slots.
Config.VehicleHud = true -- Speedometer, RPM and engine health.
```

For the minimap, use the existing `Config.Radar` option: `'always'`, `'vehicle'` or `'never'`.

## Client exports

Use these exports from another resource's client script. Start `coii_pvphud` before that resource.

```lua
-- Hide/show the entire HUD (for example, when opening/closing your own menu).
exports.coii_pvphud:SetVisible(false)
exports.coii_pvphud:SetVisible(true)

-- Toggle the HUD. Returns the new enabled state.
local enabled = exports.coii_pvphud:ToggleVisible()
```

The HUD automatically hides while the Escape/pause menu is open and returns when it closes, unless hidden through an export. Pause and inventory hiding still apply when `SetVisible(true)` is used. No chat commands are registered.

![HUD preview 1](https://i.imgur.com/npvakxG.jpeg)

![HUD preview 2](https://i.imgur.com/OOpPZTG.jpeg)
