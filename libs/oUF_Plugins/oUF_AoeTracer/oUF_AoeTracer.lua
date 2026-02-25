--[[
# Element: AoeTracer (AOE Healing Effectiveness Tracer)

Traces AOE heal effectiveness as they go out, displaying indicators on unit
frames showing how many targets were hit by each AOE heal cast. Inspired by
WeakAura-based AOE heal tracers.

## Widget

AoeTracer - A `Frame` containing the AOE trace indicator elements.

## Sub-Widgets

.text    - A `FontString` to display hit count (1, 2, 3+).
.bg      - A `Texture` for the indicator background.

## Notes

The element monitors COMBAT_LOG_EVENT_UNFILTERED for SPELL_HEAL events from
the player, groups heals within a short time window (~200ms) as belonging to
the same cast, and displays indicators showing how many friendly targets
were hit.

Persistence is weighted based on effectiveness:
- Default: 10 seconds
- High effectiveness (configurable threshold): 20 seconds
- Low effectiveness (1 target, low heal amount): 1 second

## Configuration (via element properties)

.enabled              - Enable/disable the tracer indicator
.position             - Anchor position (TOPLEFT, TOP, TOPRIGHT, LEFT, CENTER, 
                        RIGHT, BOTTOMLEFT, BOTTOM, BOTTOMRIGHT)
.size                 - Base indicator size
.sizeUpPercent        - Size increase per additional target hit (default: 10%)
.defaultPersistence   - Default indicator duration (default: 10)
.highPersistence      - Duration for high effectiveness heals (default: 20)
.lowPersistence       - Duration for low effectiveness heals (default: 1)
.highThreshold        - Heal amount threshold for high effectiveness
.lowThreshold         - Heal amount threshold for low effectiveness
.color1               - Color for 1 target hit (default: red)
.color2               - Color for 2 targets hit (default: yellow)
.color3               - Color for 3+ targets hit (default: green)
.xOffset              - X position offset
.yOffset              - Y position offset

## Example

    local AoeTracer = CreateFrame("Frame", nil, self)
    AoeTracer:SetSize(16, 16)
    AoeTracer:SetPoint("TOPRIGHT", self, "TOPRIGHT")
    
    AoeTracer.bg = AoeTracer:CreateTexture(nil, "BACKGROUND")
    AoeTracer.bg:SetAllPoints()
    AoeTracer.bg:SetColorTexture(0, 0, 0, 0.5)
    
    AoeTracer.text = AoeTracer:CreateFontString(nil, "OVERLAY")
    AoeTracer.text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    AoeTracer.text:SetPoint("CENTER")
    
    self.AoeTracer = AoeTracer

--]]

local _, ns = ...
local oUF = ns.oUF
local LUF = ns

-- Upvalues for performance
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local pairs = pairs
local ipairs = ipairs
local floor = math.floor
local wipe = table.wipe

-- Constants
local CAST_GROUP_WINDOW = 0.2  -- Time window to group heals as same cast (200ms)
local CLEANUP_INTERVAL = 1.0   -- How often to clean up expired traces
local GLOW_DURATION = 1.0      -- Glow always lasts 1 second

-- Module state
local activeFrames = {}        -- Frames with AoeTracer enabled (keyed by frame)
local guidToFrames = {}        -- Map of GUID -> list of frames for that unit
local activeTraces = {}        -- Currently active traces keyed by destGUID
local activeGlows = {}         -- Currently active glows keyed by frame
local castTracker = {}         -- Track casts in progress: [spellId] = {startTime, targets[], totalHealing}
local lastCleanup = 0

-- Default configuration
local defaults = {
    enabled = false,
    position = "TOPRIGHT",
    size = 12,
    sizeUpPercent = 10,
    defaultPersistence = 10,
    highPersistence = 20,
    lowPersistence = 1,
    highThreshold = 3000,       -- Total heal amount to trigger high persistence
    lowThreshold = 500,         -- Per-target heal below this with 1 target = low persistence
    color1 = { r = 0.9, g = 0.2, b = 0.2 },  -- Red for 1 target
    color2 = { r = 0.9, g = 0.9, b = 0.2 },  -- Yellow for 2 targets  
    color3 = { r = 0.2, g = 0.9, b = 0.2 },  -- Green for 3+ targets
    xOffset = 0,
    yOffset = 0,
}

-- AOE heal spell IDs to track (TBC Classic)
local aoeHealSpells = {
    -- Shaman
    [1064] = true,   -- Chain Heal Rank 1
    [10622] = true,  -- Chain Heal Rank 2
    [10623] = true,  -- Chain Heal Rank 3
    [25422] = true,  -- Chain Heal Rank 4
    [25423] = true,  -- Chain Heal Rank 5
    
    -- Priest 
    [596] = true,    -- Prayer of Healing Rank 1
    [996] = true,    -- Prayer of Healing Rank 2
    [10960] = true,  -- Prayer of Healing Rank 3
    [10961] = true,  -- Prayer of Healing Rank 4
    [25316] = true,  -- Prayer of Healing Rank 5
    [25308] = true,  -- Prayer of Healing Rank 6
    [34861] = true,  -- Circle of Healing Rank 1
    [34863] = true,  -- Circle of Healing Rank 2
    [34864] = true,  -- Circle of Healing Rank 3
    [34865] = true,  -- Circle of Healing Rank 4
    [34866] = true,  -- Circle of Healing Rank 5
}

-- Get config value with fallback to defaults
local function GetConfig(element, key)
    if element[key] ~= nil then
        return element[key]
    end
    return defaults[key]
end

-- Create glow texture for a frame if it doesn't exist
local function GetOrCreateGlow(frame)
    local element = frame.AoeTracer
    if not element then return nil end
    
    if not element.glow then
        -- Create glow frame that covers the entire unit frame
        local glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        glow:SetFrameLevel(frame:GetFrameLevel() + 5)
        glow:SetAllPoints(frame)
        
        -- Create glow textures (border style glow)
        glow.top = glow:CreateTexture(nil, "OVERLAY")
        glow.top:SetColorTexture(1, 1, 1, 1)
        glow.top:SetHeight(2)
        glow.top:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
        glow.top:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
        
        glow.bottom = glow:CreateTexture(nil, "OVERLAY")
        glow.bottom:SetColorTexture(1, 1, 1, 1)
        glow.bottom:SetHeight(2)
        glow.bottom:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
        glow.bottom:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
        
        glow.left = glow:CreateTexture(nil, "OVERLAY")
        glow.left:SetColorTexture(1, 1, 1, 1)
        glow.left:SetWidth(2)
        glow.left:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
        glow.left:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
        
        glow.right = glow:CreateTexture(nil, "OVERLAY")
        glow.right:SetColorTexture(1, 1, 1, 1)
        glow.right:SetWidth(2)
        glow.right:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
        glow.right:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
        
        glow:Hide()
        element.glow = glow
    end
    
    return element.glow
end

-- Show glow effect on a frame
local function ShowGlow(frame, color)
    local glow = GetOrCreateGlow(frame)
    if not glow then return end
    
    -- Set glow color
    local r, g, b = color.r, color.g, color.b
    glow.top:SetColorTexture(r, g, b, 0.9)
    glow.bottom:SetColorTexture(r, g, b, 0.9)
    glow.left:SetColorTexture(r, g, b, 0.9)
    glow.right:SetColorTexture(r, g, b, 0.9)
    
    glow:Show()
    
    -- Track glow expiration
    activeGlows[frame] = {
        expirationTime = GetTime() + GLOW_DURATION,
    }
end

-- Hide glow effect on a frame
local function HideGlow(frame)
    local element = frame.AoeTracer
    if element and element.glow then
        element.glow:Hide()
    end
    activeGlows[frame] = nil
end

-- Update indicator appearance for a frame
local function UpdateIndicator(frame, targetCount, totalHealing, persistence, isNewTrace)
    local element = frame.AoeTracer
    if not element then return end
    
    local config = element.config or {}
    local baseSize = config.size or defaults.size
    local sizeUp = config.sizeUpPercent or defaults.sizeUpPercent
    
    -- Calculate size based on target count (3+ gets largest)
    local sizeMult = 1 + (math.min(targetCount, 3) - 1) * (sizeUp / 100)
    local finalSize = baseSize * sizeMult
    
    element:SetSize(finalSize, finalSize)
    
    -- Set color based on target count
    local color
    if targetCount >= 3 then
        color = config.color3 or defaults.color3
    elseif targetCount == 2 then
        color = config.color2 or defaults.color2
    else
        color = config.color1 or defaults.color1
    end
    
    -- Update text
    if element.text then
        element.text:SetText(tostring(targetCount))
        element.text:SetTextColor(color.r, color.g, color.b, 1)
        
        -- Larger font for 3+ targets
        local fontSize = targetCount >= 3 and (baseSize * 0.9) or (baseSize * 0.75)
        local fontPath = element.text:GetFont()
        element.text:SetFont(fontPath or STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    end
    
    -- Update background
    if element.bg then
        element.bg:SetVertexColor(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
    end
    
    element:Show()
    
    -- Show glow effect on new traces only (not refreshes)
    if isNewTrace then
        ShowGlow(frame, color)
    end
    
    -- Store trace info for cleanup
    local guid = frame.unit and UnitGUID(frame.unit)
    if guid then
        activeTraces[guid] = {
            frame = frame,
            targetCount = targetCount,
            totalHealing = totalHealing,
            expirationTime = GetTime() + persistence,
        }
    end
end

-- Calculate persistence duration based on effectiveness
local function CalculatePersistence(element, targetCount, totalHealing, perTargetHealing)
    local config = element.config or {}
    local defaultPersist = config.defaultPersistence or defaults.defaultPersistence
    local highPersist = config.highPersistence or defaults.highPersistence
    local lowPersist = config.lowPersistence or defaults.lowPersistence
    local highThresh = config.highThreshold or defaults.highThreshold
    local lowThresh = config.lowThreshold or defaults.lowThreshold
    
    -- High effectiveness: total healing over threshold
    if totalHealing >= highThresh then
        return highPersist
    end
    
    -- Low effectiveness: 1 target AND low heal amount
    if targetCount == 1 and perTargetHealing < lowThresh then
        return lowPersist
    end
    
    return defaultPersist
end

-- Process a completed cast group and update all affected frames
local function ProcessCastGroup(castData)
    if not castData or not castData.targets or #castData.targets == 0 then
        return
    end
    
    local targetCount = #castData.targets
    local totalHealing = castData.totalHealing or 0
    local perTargetHealing = totalHealing / targetCount
    
    -- Update indicator on each affected frame
    for _, targetInfo in ipairs(castData.targets) do
        local destGUID = targetInfo.guid
        local frames = guidToFrames[destGUID]
        
        if frames then
            for frame in pairs(frames) do
                local element = frame.AoeTracer
                if element and element:IsShown() or element.enabled then
                    local persistence = CalculatePersistence(element, targetCount, totalHealing, perTargetHealing)
                    UpdateIndicator(frame, targetCount, totalHealing, persistence, true)  -- true = new trace, show glow
                end
            end
        end
    end
end

-- Handle combat log heal events
local playerGUID
local function OnCombatLogEvent()
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool,
          amount, overhealing, absorbed, critical = CombatLogGetCurrentEventInfo()
    
    -- Only track player's heals
    if not playerGUID then
        playerGUID = UnitGUID("player")
    end
    
    if sourceGUID ~= playerGUID then return end
    
    -- Only track spell heals (not periodic/hot ticks)
    if subevent ~= "SPELL_HEAL" then return end
    
    -- Only track configured AOE heal spells
    if not aoeHealSpells[spellId] then return end
    
    local now = GetTime()
    
    -- Check if this is part of an existing cast group
    local castKey = spellId
    local castData = castTracker[castKey]
    
    if castData and (now - castData.startTime) <= CAST_GROUP_WINDOW then
        -- Add to existing cast group
        castData.targets[#castData.targets + 1] = {
            guid = destGUID,
            name = destName,
            amount = amount,
        }
        castData.totalHealing = (castData.totalHealing or 0) + (amount or 0)
        castData.lastUpdate = now
    else
        -- Process previous cast group if it exists and is complete
        if castData and (now - castData.lastUpdate) > CAST_GROUP_WINDOW then
            ProcessCastGroup(castData)
        end
        
        -- Start new cast group
        castTracker[castKey] = {
            spellId = spellId,
            spellName = spellName,
            startTime = now,
            lastUpdate = now,
            totalHealing = amount or 0,
            targets = {
                {
                    guid = destGUID,
                    name = destName,
                    amount = amount,
                }
            },
        }
    end
end

-- Cleanup expired traces and process pending cast groups
local function OnUpdate(self, elapsed)
    local now = GetTime()
    
    -- Cleanup at regular intervals
    if now - lastCleanup < CLEANUP_INTERVAL then return end
    lastCleanup = now
    
    -- Process any pending cast groups that are complete
    for spellId, castData in pairs(castTracker) do
        if castData.lastUpdate and (now - castData.lastUpdate) > CAST_GROUP_WINDOW then
            ProcessCastGroup(castData)
            castTracker[spellId] = nil
        end
    end
    
    -- Cleanup expired traces
    for guid, traceData in pairs(activeTraces) do
        if now >= traceData.expirationTime then
            local frame = traceData.frame
            if frame and frame.AoeTracer then
                frame.AoeTracer:Hide()
            end
            activeTraces[guid] = nil
        end
    end
    
    -- Cleanup expired glows
    for frame, expirationTime in pairs(activeGlows) do
        if now >= expirationTime then
            HideGlow(frame)
        end
    end
end

-- Create update frame for periodic cleanup
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
updateFrame:SetScript("OnUpdate", OnUpdate)

-- Event frame for combat log
local eventFrame = CreateFrame("Frame")
eventFrame:Hide()
eventFrame:SetScript("OnEvent", OnCombatLogEvent)

-- Register GUID to frame mapping when unit changes
local function UpdateGUIDMapping(frame)
    -- Remove old mapping
    for guid, frames in pairs(guidToFrames) do
        frames[frame] = nil
        -- Cleanup empty tables
        local hasEntries = false
        for _ in pairs(frames) do
            hasEntries = true
            break
        end
        if not hasEntries then
            guidToFrames[guid] = nil
        end
    end
    
    -- Add new mapping
    if frame.unit and UnitExists(frame.unit) then
        local guid = UnitGUID(frame.unit)
        if guid then
            guidToFrames[guid] = guidToFrames[guid] or {}
            guidToFrames[guid][frame] = true
        end
    end
end

-- Element update (called by oUF)
local function Update(self, event, unit)
    if unit and self.unit ~= unit then return end
    
    local element = self.AoeTracer
    if not element then return end
    
    if element.PreUpdate then
        element:PreUpdate(unit)
    end
    
    -- Update GUID mapping
    UpdateGUIDMapping(self)
    
    -- Check if there's an active trace for this unit
    local guid = self.unit and UnitGUID(self.unit)
    if guid and activeTraces[guid] then
        local traceData = activeTraces[guid]
        if GetTime() < traceData.expirationTime then
            -- Re-apply the indicator (in case frame was reused)
            local persistence = traceData.expirationTime - GetTime()
            UpdateIndicator(self, traceData.targetCount, traceData.totalHealing, persistence)
        else
            element:Hide()
            activeTraces[guid] = nil
        end
    else
        element:Hide()
    end
    
    if element.PostUpdate then
        element:PostUpdate(unit)
    end
end

local function Path(self, ...)
    return (self.AoeTracer.Override or Update)(self, ...)
end

local function ForceUpdate(element)
    return Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self)
    local element = self.AoeTracer
    if not element then return end
    
    element.__owner = self
    element.ForceUpdate = ForceUpdate
    
    -- Apply default config
    element.config = element.config or {}
    for k, v in pairs(defaults) do
        if element.config[k] == nil then
            element.config[k] = v
        end
    end
    
    -- Register this frame
    activeFrames[self] = true
    
    -- Update GUID mapping
    UpdateGUIDMapping(self)
    
    -- Start update frame if this is the first active frame
    local hasOtherFrames = false
    for frame in pairs(activeFrames) do
        if frame ~= self then
            hasOtherFrames = true
            break
        end
    end
    
    if not hasOtherFrames then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        eventFrame:Show()
        updateFrame:Show()
    end
    
    -- Register events for unit changes
    self:RegisterEvent("UNIT_TARGET", Path)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", Path, true)
    self:RegisterEvent("PLAYER_TARGET_CHANGED", Path, true)
    
    -- Hide by default
    element:Hide()
    
    return true
end

local function Disable(self)
    local element = self.AoeTracer
    if not element then return end
    
    -- Unregister this frame
    activeFrames[self] = nil
    
    -- Remove from GUID mapping
    for guid, frames in pairs(guidToFrames) do
        frames[self] = nil
    end
    
    -- Stop timers if no frames left
    local hasFrames = false
    for _ in pairs(activeFrames) do
        hasFrames = true
        break
    end
    
    if not hasFrames then
        eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        eventFrame:Hide()
        updateFrame:Hide()
        wipe(castTracker)
        wipe(activeTraces)
    end
    
    -- Unregister events
    self:UnregisterEvent("UNIT_TARGET", Path)
    self:UnregisterEvent("GROUP_ROSTER_UPDATE", Path)
    self:UnregisterEvent("PLAYER_TARGET_CHANGED", Path)
    
    element:Hide()
end

-- Expose for external configuration
ns.AoeTracerDefaults = defaults
ns.AoeTracerAoeHealSpells = aoeHealSpells

oUF:AddElement("AoeTracer", Path, Enable, Disable)
