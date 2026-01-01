--[[
# Element: Resurrect Indicator (Classic Era)

Toggles the visibility of an indicator based on the units incoming resurrect status.

NOTE: This is a Classic Era compatible version that disables the element since
UnitHasIncomingResurrection() does not exist in Classic Era (1.15.x).
The original oUF resurrectindicator.lua uses this Retail-only API.

## Widget

ResurrectIndicator - A `Texture` used to display if the unit is being resurrected.

## Notes

This element is non-functional in Classic Era as there is no API to detect
incoming resurrections. It is provided to prevent errors from the original
oUF element and to hide the indicator.

## Examples

    -- Position and size
    local ResurrectIndicator = self:CreateTexture(nil, 'OVERLAY')
    ResurrectIndicator:SetSize(16, 16)
    ResurrectIndicator:SetPoint('TOPRIGHT', self)

    -- Register it with oUF
    self.ResurrectIndicator = ResurrectIndicator
--]]

local _, ns = ...
local oUF = ns.oUF

-- Classic Era does not have UnitHasIncomingResurrection API
-- This element is a stub that always hides the indicator

local function Update(self, event, unit)
	if(self.unit ~= unit) then return end

	local element = self.ResurrectIndicator

	--[[ Callback: ResurrectIndicator:PreUpdate()
	Called before the element has been updated.

	* self - the ResurrectIndicator element
	--]]
	if(element.PreUpdate) then
		element:PreUpdate()
	end

	-- Classic Era has no way to detect incoming resurrections
	-- Always hide the indicator
	local incomingResurrect = false

	if(incomingResurrect) then
		element:Show()
	else
		element:Hide()
	end

	--[[ Callback: ResurrectIndicator:PostUpdate(isIncomingResurrect)
	Called after the element has been updated.

	* self                - the ResurrectIndicator element
	* isIncomingResurrect - indicates if the unit is being resurrected (boolean)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(incomingResurrect)
	end
end

local function Path(self, ...)
	--[[ Override: ResurrectIndicator.Override(self, event)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	--]]
	return (self.ResurrectIndicator.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, 'ForceUpdate', element.__owner.unit)
end

local function Enable(self)
	local element = self.ResurrectIndicator
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		-- Classic Era does not have INCOMING_RESURRECT_CHANGED event
		-- We register UNIT_HEALTH as a fallback to trigger updates, but
		-- the indicator will always be hidden since we can't detect resurrects
		self:RegisterEvent('UNIT_HEALTH', Path)

		if(element:IsObjectType('Texture') and not element:GetTexture()) then
			element:SetTexture([[Interface\RaidFrame\Raid-Icon-Rez]])
		end

		-- Ensure element starts hidden
		element:Hide()

		return true
	end
end

local function Disable(self)
	local element = self.ResurrectIndicator
	if(element) then
		element:Hide()

		self:UnregisterEvent('UNIT_HEALTH', Path)
	end
end

oUF:AddElement('ResurrectIndicator', Path, Enable, Disable)
