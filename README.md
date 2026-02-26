# LunaUnitFrames

A comprehensive and highly customizable unit frames addon for **WoW Classic Anniversary - The Burning Crusade** (Patch 2.5.5).

![Player and Party Frames](assets/player-party.png)

## Features

### Unit Frames
- **Player, Target, Target of Target** frames with full customization
- **Party frames** with configurable layout
- **Raid frames** optimized for 40-man raids
- **Pet, Focus, and Boss** frames

![Raid Frames](assets/raid.png)

### Core Features
- **Config mode** for easy visual setup and positioning
- **Healing prediction** via LibHealComm-4.0 integration
- **Native aura durations** (TBC provides duration info natively)
- **Enemy and friendly castbars** using LibClassicCasterino
- **Energy / MP5 ticker** for resource management
- **Druid mana bar** - track mana while shapeshifted
- **Reckoning tracker** for Paladin stacks
- **Totem timer** for Shaman totems
- **Mana cost prediction** on the power bar
- **AOE Tracer** - visual feedback for AOE heal effectiveness

### AOE Tracer

The AOE Tracer helps healers visualize how effective their AOE heals are by showing indicators on raid frames when Chain Heal, Prayer of Healing, or Circle of Healing lands.

![AOE Tracer - Chain Heal hitting 3 targets](assets/aoetracer.png)

**How it works:**
- When you cast an AOE heal, each affected unit frame displays a number showing how many targets were hit
- **Color coding**: Red = 1 target (poor), Yellow = 2 targets (okay), Green = 3+ targets (optimal)
- **Size scaling**: Indicators grow larger with more targets hit
- **Glow effect**: A brief 1-second border glow highlights affected frames

![AOE Tracer - Color coding and persistence](assets/aoetracer_2.png)

**Weighted Persistence:**
- High effectiveness heals (high total healing) persist longer on screen (default: 10s)
- Normal heals persist for a moderate duration (default: 5s)
- Low effectiveness heals (1 target, low healing) fade quickly (default: 1s)

![AOE Tracer - Configuration options](assets/aoetracer_3.png)

All colors, sizes, durations, and thresholds are fully configurable via `/luna` → select Raid/Party → AOE Tracer.

### Customization
- Fully configurable bar textures and fonts via LibSharedMedia
- Adjustable frame sizes, positions, and layouts
- Customizable aura filtering and display
- Class-colored health bars
- Portrait options (2D, 3D, class icons)

## Installation

1. Download the latest release
2. Extract to your `World of Warcraft\_anniversary_\Interface\AddOns` folder
3. Ensure the folder is named `LunaUnitFrames`

## Configuration

Type `/luna` or `/luf` in-game to open the configuration panel.

## Recommended Companion Addons

- [Clique](https://www.wowinterface.com/downloads/info5108-Clique.html) - Click-casting support

## Compatibility

- **WoW Classic Anniversary (TBC)** - Interface 20505 (Patch 2.5.5)

This addon is **not** compatible with Retail, Cataclysm Classic, WotLK Classic, or Classic Era
