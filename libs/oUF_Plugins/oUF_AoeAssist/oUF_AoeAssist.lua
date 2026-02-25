--[[
# Element: AoeAssist (AOE Healing Advisor)

Shows an icon on raid frames when a unit is the best target for Chain Heal
(or other AOE healing spells). Specifically designed for Restoration Shamans
in TBC Classic.

## Widget

AoeAssist - A `Frame` containing the AOE assist indicator elements.

## Sub-Widgets

.icon    - A `Texture` to display the spell icon.
.text    - A `FontString` to display heal count/amount (optional).

## Notes

The element calculates which raid member would provide the most total healing
if targeted with Chain Heal, considering:
- Health deficits of nearby players (within 12.5 yard jump range)
- Chain Heal's 50% reduction per jump (in TBC)
- Maximum of 3 jumps (4 total targets)

## Options

.enabled       - Enable/disable the AOE assist indicator
.minHealAmount - Minimum total healing threshold to show indicator (default: 3000)
.updateRate    - How often to recalculate best targets in seconds (default: 0.3)
.showOnlyBest  - Only show on THE single best target vs all good targets

## Example

    local AoeAssist = CreateFrame("Frame", nil, self)
    AoeAssist:SetSize(20, 20)
    AoeAssist:SetPoint("CENTER", self, "CENTER")
    
    AoeAssist.icon = AoeAssist:CreateTexture(nil, "OVERLAY")
    AoeAssist.icon:SetAllPoints()
    
    self.AoeAssist = AoeAssist

--]]

local _, ns = ...
local oUF = ns.oUF
local LUF = ns

-- Upvalues for performance
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitGUID = UnitGUID
local UnitInRange = UnitInRange
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetSpellBonusHealing = GetSpellBonusHealing
local IsSpellKnown = IsSpellKnown
local pairs = pairs
local ipairs = ipairs
local floor = floor
local sqrt = math.sqrt
local min = math.min
local max = math.max
local wipe = table.wipe
local sort = table.sort

-- Constants
local CHAIN_HEAL_SPELL_ID = 1064  -- Base Chain Heal spell ID
local CHAIN_HEAL_MAX_TARGETS = 4  -- Primary + 3 jumps in TBC
local CHAIN_HEAL_JUMP_REDUCTION = 0.5  -- 50% reduction per jump in TBC
local CHAIN_HEAL_JUMP_RANGE = 12.5  -- yards (approximate)
local CHAIN_HEAL_JUMP_RANGE_SQ = CHAIN_HEAL_JUMP_RANGE * CHAIN_HEAL_JUMP_RANGE

-- Module state
local AoeAssist = {}
local activeFrames = {}
local raidUnits = {}
local unitHealthDeficit = {}
local unitPositions = {}
local bestTargets = {}
local lastUpdate = 0
local UPDATE_INTERVAL = 0.3  -- Default update rate

-- Spell info cache
local chainHealName, chainHealIcon
local playerClass = select(2, UnitClass("player"))
local isShaman = (playerClass == "SHAMAN")

-- Initialize spell info
local function InitSpellInfo()
	chainHealName = GetSpellInfo(CHAIN_HEAL_SPELL_ID)
	chainHealIcon = GetSpellTexture(CHAIN_HEAL_SPELL_ID)
end

-- Check if player knows Chain Heal
local function KnowsChainHeal()
	return isShaman and IsSpellKnown(CHAIN_HEAL_SPELL_ID)
end

-- Calculate estimated Chain Heal amount
local function GetChainHealEstimate()
	-- TBC Chain Heal Rank 5 (max rank at 70): 1055-1203 base
	-- Coefficient is approximately 0.714 (2.5/3.5 base cast time)
	local baseHeal = 1129  -- Average of rank 5
	local spellPower = GetSpellBonusHealing() or 0
	local coefficient = 0.714
	
	return floor(baseHeal + (spellPower * coefficient))
end

-- Build list of raid/party units
local function BuildRaidUnitList()
	wipe(raidUnits)
	
	local numRaid = GetNumRaidMembers and GetNumRaidMembers() or GetNumGroupMembers and GetNumGroupMembers() or 0
	local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
	
	if numRaid > 0 then
		for i = 1, numRaid do
			raidUnits[#raidUnits + 1] = "raid" .. i
		end
	elseif numParty > 0 then
		raidUnits[#raidUnits + 1] = "player"
		for i = 1, numParty do
			raidUnits[#raidUnits + 1] = "party" .. i
		end
	else
		raidUnits[#raidUnits + 1] = "player"
	end
end

-- Get health deficit for a unit
local function GetHealthDeficit(unit)
	if not UnitExists(unit) then return 0 end
	if UnitIsDeadOrGhost(unit) then return 0 end
	if not UnitIsConnected(unit) then return 0 end
	
	local health = UnitHealth(unit)
	local healthMax = UnitHealthMax(unit)
	
	if healthMax == 0 then return 0 end
	
	return healthMax - health
end

-- Check if unit is in range (using native API)
local function IsUnitInRange(unit)
	if not UnitExists(unit) then return false end
	if UnitIsDeadOrGhost(unit) then return false end
	if not UnitIsConnected(unit) then return false end
	
	-- UnitInRange returns true if within 40 yards for friendly units
	local inRange = UnitInRange(unit)
	return inRange
end

-- Approximate distance check using CheckInteractDistance
-- Distance 1 = Inspect (28 yards)
-- Distance 2 = Trade (11 yards)  
-- Distance 3 = Duel (10 yards)
-- Distance 4 = Follow (28 yards)
local function GetApproximateDistance(unit1, unit2)
	-- This is a rough approximation since we can't get exact positions in TBC
	-- We use interact distances as a proxy
	
	if unit1 == unit2 then return 0 end
	if not UnitExists(unit1) or not UnitExists(unit2) then return 100 end
	
	-- In TBC, we can't easily get unit positions in instances
	-- So we use a simplified approach: assume all raid members in range
	-- are close enough for chain heal jumps if they're both in "healing range"
	
	-- Check if both units are in range of player
	local u1InRange = (unit1 == "player") or UnitInRange(unit1)
	local u2InRange = (unit2 == "player") or UnitInRange(unit2)
	
	if u1InRange and u2InRange then
		-- Both in healing range, assume they might be in jump range
		-- This is an approximation - in reality we'd need position data
		return 10  -- Assume within jump range
	end
	
	return 100  -- Too far
end

-- Find units that could be hit by chain heal jumps from a target
local function GetChainHealCluster(primaryUnit, maxJumps)
	local cluster = { primaryUnit }
	local usedUnits = { [primaryUnit] = true }
	local currentUnit = primaryUnit
	
	for jump = 1, maxJumps do
		local bestNextUnit = nil
		local bestDeficit = 0
		
		for _, unit in ipairs(raidUnits) do
			if not usedUnits[unit] then
				local deficit = GetHealthDeficit(unit)
				if deficit > 0 then
					local dist = GetApproximateDistance(currentUnit, unit)
					if dist <= CHAIN_HEAL_JUMP_RANGE then
						if deficit > bestDeficit then
							bestDeficit = deficit
							bestNextUnit = unit
						end
					end
				end
			end
		end
		
		if bestNextUnit then
			cluster[#cluster + 1] = bestNextUnit
			usedUnits[bestNextUnit] = true
			currentUnit = bestNextUnit
		else
			break
		end
	end
	
	return cluster
end

-- Calculate total effective healing for a chain heal on a target
local function CalculateChainHealTotal(primaryUnit, baseHeal)
	local cluster = GetChainHealCluster(primaryUnit, CHAIN_HEAL_MAX_TARGETS - 1)
	local totalHealing = 0
	local healAmount = baseHeal
	
	for i, unit in ipairs(cluster) do
		local deficit = GetHealthDeficit(unit)
		local effectiveHeal = min(deficit, healAmount)
		totalHealing = totalHealing + effectiveHeal
		
		-- Reduce heal amount for next jump (50% in TBC)
		healAmount = healAmount * CHAIN_HEAL_JUMP_REDUCTION
	end
	
	return totalHealing, #cluster
end

-- Find the best chain heal targets
local function FindBestChainHealTargets(minHealThreshold)
	wipe(bestTargets)
	
	if not KnowsChainHeal() then return end
	
	BuildRaidUnitList()
	
	local baseHeal = GetChainHealEstimate()
	local bestUnit = nil
	local bestTotalHeal = 0
	
	-- Evaluate each potential primary target
	for _, unit in ipairs(raidUnits) do
		if IsUnitInRange(unit) then
			local deficit = GetHealthDeficit(unit)
			if deficit > 0 then
				local totalHeal, numTargets = CalculateChainHealTotal(unit, baseHeal)
				
				if totalHeal > bestTotalHeal and totalHeal >= minHealThreshold then
					bestTotalHeal = totalHeal
					bestUnit = unit
				end
				
				-- Store all valid targets for potential display
				if totalHeal >= minHealThreshold then
					bestTargets[unit] = {
						totalHeal = totalHeal,
						numTargets = numTargets,
					}
				end
			end
		end
	end
	
	-- Mark the absolute best target
	if bestUnit then
		bestTargets[bestUnit].isBest = true
	end
	
	return bestUnit, bestTotalHeal
end

-- Update function called on timer
local function OnUpdate(self, elapsed)
	lastUpdate = lastUpdate + elapsed
	
	if lastUpdate < UPDATE_INTERVAL then return end
	lastUpdate = 0
	
	-- Don't process if player isn't a shaman or doesn't know Chain Heal
	if not KnowsChainHeal() then
		for frame in pairs(activeFrames) do
			if frame.AoeAssist then
				frame.AoeAssist:Hide()
			end
		end
		return
	end
	
	-- Get config from first active frame (they should all share the same config)
	local minHealAmount = 3000
	local showOnlyBest = true
	
	for frame in pairs(activeFrames) do
		if frame.AoeAssist and frame.AoeAssist.minHealAmount then
			minHealAmount = frame.AoeAssist.minHealAmount
		end
		if frame.AoeAssist and frame.AoeAssist.showOnlyBest ~= nil then
			showOnlyBest = frame.AoeAssist.showOnlyBest
		end
		break
	end
	
	-- Find best targets
	FindBestChainHealTargets(minHealAmount)
	
	-- Update all active frames
	for frame in pairs(activeFrames) do
		local element = frame.AoeAssist
		if element and frame.unit then
			local targetInfo = bestTargets[frame.unit]
			
			if targetInfo and (not showOnlyBest or targetInfo.isBest) then
				-- Show indicator
				if element.icon then
					element.icon:SetTexture(chainHealIcon)
					element.icon:Show()
				end
				
				if element.text then
					local displayText = ""
					if element.showHealAmount then
						displayText = floor(targetInfo.totalHeal / 1000) .. "k"
					elseif element.showTargetCount then
						displayText = tostring(targetInfo.numTargets)
					end
					element.text:SetText(displayText)
					element.text:Show()
				end
				
				element:Show()
			else
				element:Hide()
			end
		end
	end
end

-- Create update frame
local updateFrame = CreateFrame("Frame")
updateFrame:Hide()
updateFrame:SetScript("OnUpdate", OnUpdate)

-- Element update (called by oUF)
local function Update(self, event, unit)
	if self.unit ~= unit then return end
	
	local element = self.AoeAssist
	if not element then return end
	
	if element.PreUpdate then
		element:PreUpdate(unit)
	end
	
	-- The actual update is handled by OnUpdate timer
	-- This just ensures the frame is registered
	
	if element.PostUpdate then
		element:PostUpdate(unit)
	end
end

local function Path(self, ...)
	return (self.AoeAssist.Override or Update)(self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate", element.__owner.unit)
end

local function Enable(self)
	local element = self.AoeAssist
	if not element then return end
	
	-- Only enable for shamans
	if not isShaman then 
		element:Hide()
		return false
	end
	
	element.__owner = self
	element.ForceUpdate = ForceUpdate
	
	-- Initialize spell info if needed
	if not chainHealIcon then
		InitSpellInfo()
	end
	
	-- Set up the icon
	if element.icon then
		element.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	
	-- Register this frame
	activeFrames[self] = true
	
	-- Start the update timer if this is the first frame
	if not updateFrame:IsShown() then
		updateFrame:Show()
	end
	
	-- Register events
	self:RegisterEvent("GROUP_ROSTER_UPDATE", Path, true)
	self:RegisterEvent("UNIT_HEALTH", Path)
	self:RegisterEvent("UNIT_MAXHEALTH", Path)
	
	-- Hide by default
	element:Hide()
	
	return true
end

local function Disable(self)
	local element = self.AoeAssist
	if not element then return end
	
	-- Unregister this frame
	activeFrames[self] = nil
	
	-- Stop update timer if no frames left
	local hasFrames = false
	for _ in pairs(activeFrames) do
		hasFrames = true
		break
	end
	
	if not hasFrames then
		updateFrame:Hide()
	end
	
	-- Unregister events
	self:UnregisterEvent("GROUP_ROSTER_UPDATE", Path)
	self:UnregisterEvent("UNIT_HEALTH", Path)
	self:UnregisterEvent("UNIT_MAXHEALTH", Path)
	
	element:Hide()
end

oUF:AddElement("AoeAssist", Path, Enable, Disable)
