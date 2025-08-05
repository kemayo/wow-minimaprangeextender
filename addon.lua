local myname, ns = ...
local module = ns
local core = ns

local HBD = LibStub("HereBeDragons-2.0")
local HBDPins = LibStub("HereBeDragons-Pins-2.0")

local f = CreateFrame('Frame')
f:SetScript("OnEvent", function(_, event, ...)
	ns[ns.events[event]](ns, event, ...)
end)
f:Hide()
ns.events = {}
function ns:RegisterEvent(event, method)
	self.events[event] = method or event
	f:RegisterEvent(event)
end
function ns:UnregisterEvent(...) for i=1,select("#", ...) do f:UnregisterEvent((select(i, ...))) end end
ns:RegisterEvent("ADDON_LOADED")

local db
local compat_disabled

local function setDefaults(options, defaults)
	setmetatable(options, { __index = function(t, k)
		if type(defaults[k]) == "table" then
			t[k] = setDefaults({}, defaults[k])
			return t[k]
		end
		return defaults[k]
	end, })
	-- and add defaults to existing tables
	for k, v in pairs(options) do
		if defaults[k] and type(v) == "table" then
			setDefaults(v, defaults[k])
		end
	end
	return options
end

function ns:ADDON_LOADED(event, name)
	if name ~= myname then return end

	_G[myname.."DB"] = setDefaults(_G[myname.."DB"] or {}, {
		enabled = true,
		mystery = true,
		types = {
			vignettekill = true,
			vignettekillelite = true,
			vignetteloot = true,
			vignettelootelite = true,
			vignetteevent = true,
			vignetteeventelite = true,
		},
	})
	db = _G[myname.."DB"]
	ns.db = db

	compat_disabled = not C_EventUtils.IsEventValid("VIGNETTE_MINIMAP_UPDATED")
	self.compat_disabled = compat_disabled

	self.pool = CreateFramePool("FRAME", Minimap, "MinimapRangeExtenderPinTemplate", function(_, icon)
		-- this behavior is copied from HandyNotes, on the assumption that it knows what it's doing for minimap icons
		local frameLevel = Minimap:GetFrameLevel() + 5
		local frameStrata = Minimap:GetFrameStrata()
		icon:SetFrameStrata(frameStrata)
		icon:SetFrameLevel(frameLevel)
	end)

	if compat_disabled then return end

	ns:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
	ns:RegisterEvent("VIGNETTES_UPDATED")
	ns:RegisterEvent("PLAYER_ENTERING_WORLD", "VIGNETTES_UPDATED")

	self:VIGNETTES_UPDATED()

	f:UnregisterEvent("ADDON_LOADED")
end

function ns:GetCoord(x, y)
	return floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end

-- Everything below here is just kept in sync with SilverDragon_RangeExtender
-- (It can *almost* entirely be copy-pasted in, but the references to `self.db.profile` need to be replaced.)

function module:GetVignetteID(vignetteGUID, vignetteInfo)
	return vignetteInfo and vignetteInfo.vignetteID or tonumber((select(6, strsplit('-', vignetteGUID))))
end

local vignetteIcons = {
	-- [instanceid] = icon
}

function module:VIGNETTE_MINIMAP_UPDATED(event, instanceid, onMinimap, ...)
	-- Debug("VIGNETTE_MINIMAP_UPDATED", instanceid, onMinimap, ...)
	if not instanceid then
		-- ...just in case
		return
	end

	local icon = vignetteIcons[instanceid]
	if not icon then
		return self:UpdateVignetteOnMinimap(instanceid)
	end

	if onMinimap then
		icon.texture:Hide()
		icon:EnableMouse(false)
	else
		icon.texture:Show()
		icon:EnableMouse(true)
	end
end
function module:VIGNETTES_UPDATED()
	local vignetteids = C_VignetteInfo.GetVignettes()
	-- Debug("VIGNETTES_UPDATED", #vignetteids)

	for instanceid, icon in pairs(vignetteIcons) do
		if not tContains(vignetteids, instanceid) or (icon.info and not db.types[icon.info.atlasName:lower()]) or (not icon.info and not db.mystery) or not db.enabled then
			HBDPins:RemoveMinimapIcon(self, icon)
			icon:Hide()
			icon.info = nil
			icon.instanceid = nil
			vignetteIcons[instanceid] = nil
			self.pool:Release(icon)
		end
	end

	for i=1, #vignetteids do
		self:UpdateVignetteOnMinimap(vignetteids[i])
	end
end

function module:UpdateVignetteOnMinimap(instanceid)
	if compat_disabled or not db.enabled then
		return
	end
	-- Debug("considering vignette", instanceid)
	local uiMapID = C_Map.GetBestMapForUnit("player")
	if not uiMapID then
		return -- Debug("can't determine current zone")
	end
	local vignetteInfo = C_VignetteInfo.GetVignetteInfo(instanceid)
	if not db.mystery and not (vignetteInfo and vignetteInfo.vignetteGUID and vignetteInfo.atlasName) then
		return -- Debug("vignette had no info")
	end
	if vignetteInfo then
		if not db.types[vignetteInfo.atlasName:lower()] then
			return -- Debug("vignette type not enabled", vignetteInfo.atlasName)
		end
	end
	local position = C_VignetteInfo.GetVignettePosition(instanceid, uiMapID)
	if not position then
		return -- Debug("vignette had no position")
	end
	local x, y = position:GetXY()
	if self:ShouldHideVignette(instanceid, vignetteInfo, uiMapID, x, y) then
		return
	end

	local icon = vignetteIcons[instanceid]
	if not icon then
		icon = self.pool:Acquire()
		icon.texture:SetAtlas(vignetteInfo and vignetteInfo.atlasName or "poi-nzothvision")
		icon.texture:SetAlpha(vignetteInfo and 1 or 0.7)
		icon.texture:SetDesaturated(true)
		vignetteIcons[instanceid] = icon
		HBDPins:AddMinimapIconMap(self, icon, uiMapID, x, y, false, true)
		-- icon.instanceid = instanceid
		icon.info = vignetteInfo
		icon.coord = core:GetCoord(x, y)
	end

	if vignetteInfo and vignetteInfo.onMinimap then
		icon.texture:Hide()
		icon:EnableMouse(false)
	else
		icon.texture:Show()
		icon:EnableMouse(true)
	end

	self:UpdateEdge(icon)
end

do
	-- These show up for glowing highlights on NPCs in-town a lot, which gets in the way
	local inconvenient = {
		-- Valdrakken
		[5473] = true, -- Unatos, Keeper of Renown
		-- Ohn'ahran Plains
		[5472] = true, -- Agari Dotur, Keeper of Renown
		-- Azure Span
		[5435] = true, -- Fishing Gear Crafter
		[5471] = true, -- Murik, Keeper of Renown
		-- Waking Shores
		[5273] = true, -- Expedition Supply Kit
		[5470] = true, -- Cataloger Jakes
		-- Forbidden Reach
		[5670] = true, -- Storykeeper Ashekh (x2, strangely)
		-- Zalarak Cavern
		[5684] = true, -- Mimeep, Keeper of Renown
		-- Emerald Dream
		[5759] = true, -- Amrymn, Keeper of Renown
	}
	function module:ShouldHideVignette(vignetteGUID, vignetteInfo, uiMapID, x, y)
		local vignetteID = self:GetVignetteID(vignetteGUID, vignetteInfo)
		return vignetteID and inconvenient[vignetteID]
	end
end

function module:UpdateEdge(icon)
	icon:SetAlpha(HBDPins:IsMinimapIconOnEdge(icon) and 0.6 or 1)
end

C_Timer.NewTicker(1, function(...)
	for instanceid, icon in pairs(vignetteIcons) do
		module:UpdateEdge(icon)
	end
end)

MinimapRangeExtenderPinMixin = {}
function MinimapRangeExtenderPinMixin:OnLoad()
	self:SetMouseClickEnabled(false)
end
function MinimapRangeExtenderPinMixin:OnMouseEnter()
	-- TODO: see VignettePinMixin for PVP bounty vignettes if I want to handle this?
	-- Debug("OnMouseEnter", self, self.info and self.info.name)
	-- if not (self.info and self.info.name) then return end
	if self:GetCenter() > UIParent:GetCenter() then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip_SetTitle(GameTooltip, self.info and self.info.name or UNKNOWN)
	if not self.info then
		GameTooltip:AddLine("This mystery vignette has no information available", 1, 1, 1, true)
	end
	GameTooltip:AddDoubleLine(" ", "RangeExtender", 1, 1, 1, 1, 0.5, 0.5)
	GameTooltip:Show()
end
function MinimapRangeExtenderPinMixin:OnMouseLeave()
	GameTooltip:Hide()
end
