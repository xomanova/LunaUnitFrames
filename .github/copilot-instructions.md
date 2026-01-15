# Copilot Instructions for LunaUnitFrames

## WoW Classic TBC API Version

This addon targets **WoW Classic Anniversary - The Burning Crusade** with Interface version **20505** (Patch 2.5.5).

## API Guidelines

When writing or modifying Lua code for this addon, only use UI elements and API functions that are available in TBC Classic 2.5.x. Do NOT use APIs from:
- Retail WoW (The War Within, Dragonflight, etc.)
- Cataclysm Classic
- Wrath of the Lich King Classic
- Mists of Pandaria Classic
- WoW Classic Era (Vanilla 1.15.x - some APIs differ)

## Available APIs (TBC Classic 2.5.x)

### Aura Functions
Use the legacy aura API functions:
- `UnitAura(unit, index, filter)` - Returns: name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nameplateShowPersonal, spellId
- `UnitBuff(unit, index, filter)` - Wrapper for UnitAura with "HELPFUL" filter
- `UnitDebuff(unit, index, filter)` - Wrapper for UnitAura with "HARMFUL" filter

Note: TBC provides native aura duration information, so LibClassicDurations is not required.

Do NOT use:
- `C_UnitAuras` namespace (Retail only)
- `AuraUtil.ForEachAura()` (Retail only)
- `GetAuraDataByIndex()` (Retail only)
- `GetAuraDataBySlot()` (Retail only)

### Addon Metadata
Use the TBC/modern API:
- `C_AddOns.GetAddOnMetadata(addonName, field)` - Returns metadata from TOC file

Do NOT use:
- `GetAddOnMetadata()` (deprecated in TBC Classic)

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
- `SetBackdrop()` - Still available in TBC Classic
- `SetBackdropColor()`
- `SetBackdropBorderColor()`

Do NOT use:
- `BackdropTemplateMixin` (use direct SetBackdrop instead)

### Unit Functions
Available in TBC Classic:
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
Use TBC Classic events. Some events that exist in Retail may not exist or have different payloads in TBC Classic.

### Libraries
This addon uses these compatible libraries:
- LibStub
- CallbackHandler-1.0
- LibSharedMedia-3.0
- AceDB-3.0 / AceConfig-3.0 / AceGUI-3.0
- LibHealComm-4.0 (Classic-specific healing prediction)
- LibClassicCasterino (Classic-specific cast bar info)
- oUF (Unit Frame framework)

Note: LibClassicDurations is optional and not needed in TBC as duration info is provided natively.

## Code Style

- Follow existing code patterns in the addon
- Use `select(2, ...)` for addon namespace access
- Prefer local variables for performance
- Use native `UnitAura()` for aura information (TBC provides duration info natively)
