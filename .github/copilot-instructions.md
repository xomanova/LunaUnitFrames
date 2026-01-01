# Copilot Instructions for LunaUnitFrames

## WoW Classic Era API Version

This addon targets **WoW Classic Era** with Interface version **11508** (Patch 1.15.8).

## API Guidelines

When writing or modifying Lua code for this addon, only use UI elements and API functions that are available in WoW Classic Era 1.15.x. Do NOT use APIs from:
- Retail WoW (The War Within, Dragonflight, etc.)
- Cataclysm Classic
- Wrath of the Lich King Classic
- Mists of Pandaria Classic

## Available APIs (Classic Era 1.15.x)

### Aura Functions
Use the legacy aura API functions:
- `UnitAura(unit, index, filter)` - Returns: name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nameplateShowPersonal, spellId
- `UnitBuff(unit, index, filter)` - Wrapper for UnitAura with "HELPFUL" filter
- `UnitDebuff(unit, index, filter)` - Wrapper for UnitAura with "HARMFUL" filter

Do NOT use:
- `C_UnitAuras` namespace (Retail only)
- `AuraUtil.ForEachAura()` (Retail only)
- `GetAuraDataByIndex()` (Retail only)
- `GetAuraDataBySlot()` (Retail only)

### Spell Functions
Use the legacy spell API:
- `GetSpellInfo(spellId)` - Returns: name, rank, icon, castTime, minRange, maxRange, spellId
- `GetSpellTexture(spellId)`
- `IsSpellKnown(spellId)`
- `IsUsableSpell(spell)`

Do NOT use:
- `C_Spell` namespace (Retail only)
- `C_SpellBook` namespace (Retail only)

### Frame/Widget API
Use classic widget methods:
- `SetBackdrop()` - Still available in Classic Era
- `SetBackdropColor()`
- `SetBackdropBorderColor()`

Do NOT use:
- `BackdropTemplateMixin` (use direct SetBackdrop instead)

### Unit Functions
Available in Classic Era:
- `UnitName(unit)`
- `UnitHealth(unit)` / `UnitHealthMax(unit)`
- `UnitPower(unit)` / `UnitPowerMax(unit)`
- `UnitClass(unit)`
- `UnitLevel(unit)`
- `UnitIsPlayer(unit)`
- `UnitIsFriend(unit, otherUnit)`
- `UnitIsEnemy(unit, otherUnit)`
- `UnitExists(unit)`
- `UnitIsDeadOrGhost(unit)`
- `UnitIsConnected(unit)`
- `UnitInRange(unit)`
- `UnitAffectingCombat(unit)`

### Events
Use Classic Era events. Some events that exist in Retail may not exist or have different payloads in Classic Era.

### Libraries
This addon uses these compatible libraries:
- LibStub
- CallbackHandler-1.0
- LibSharedMedia-3.0
- AceDB-3.0 / AceConfig-3.0 / AceGUI-3.0
- LibHealComm-4.0 (Classic-specific healing prediction)
- LibClassicDurations (Classic-specific aura durations)
- LibClassicCasterino (Classic-specific cast bar info)
- oUF (Unit Frame framework)

## Code Style

- Follow existing code patterns in the addon
- Use `select(2, ...)` for addon namespace access
- Prefer local variables for performance
- Use existing library wrappers (like `lCD:UnitAura()` from LibClassicDurations) when available for enhanced functionality
