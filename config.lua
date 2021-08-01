local myname, ns = ...
local myfullname = GetAddOnMetadata(myname, "Title")

local GAP = 8
local EDGEGAP = 16

local checkbox
local function checkboxOnClick(self) PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
do
    local function ShowTooltip(self)
        if self.tiptext then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
        end
    end

    function checkbox(parent, size, label, ...)
        local check = CreateFrame("CheckButton", nil, parent)
        check:SetWidth(size or 26)
        check:SetHeight(size or 26)
        if select(1, ...) then check:SetPoint(...) end

        check:SetHitRectInsets(0, -100, 0, 0)

        check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

        -- Tooltip bits
        check:SetScript("OnEnter", ShowTooltip)
        check:SetScript("OnLeave", GameTooltip_Hide)

        -- Sound
        check:SetScript("OnClick", checkboxOnClick)

        -- Label
        local fs = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", check, "RIGHT", 0, 1)
        fs:SetText(label)

        return check, fs
    end
end

local simple_config_click = function(self)
    checkboxOnClick(self)
    self.db[self.key] = not self.db[self.key]
    ns:VIGNETTES_UPDATED()
end
local simple_config = function(frame, prev, db, key, label, tooltip, spacing)
    local setting = checkbox(frame, nil, label, "TOPLEFT", prev, "BOTTOMLEFT", 0, spacing or -GAP)
    setting.tiptext = tooltip
    setting.db = db
    setting.key = key
    setting:SetScript("OnClick", simple_config_click)
    setting:SetChecked(db[key])
    return setting
end
local simple_section = function(frame, prev, label)
    local section = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    section:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2 * GAP)
    section:SetText(label)
    return section
end

local frame = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
frame.name = myfullname
frame:Hide()
frame:SetScript("OnShow", function(frame)
    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(myfullname)

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetHeight(32)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", frame, -32, 0)
    -- nonSpaceWrap="true" maxLines="3"
    subtitle:SetNonSpaceWrap(true)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetJustifyV("TOP")
    subtitle:SetText(("General settings for %s."):format(myfullname))

    local desc = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", frame, -32, 0)
    desc:SetNonSpaceWrap(true)
    desc:SetJustifyH("LEFT")
    desc:SetText("Minimap vignettes tell us where various things are. Blizzard lets us know about them before they'll be shown on the minimap sometimes, whether because of zoom levels or something concealing the vignette from your view. As such we can fake those hidden vignettes, to give you early warning of things you might want to pursue.")

    local types = simple_section(frame, desc, "Types")

    local types_desc = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    types_desc:SetPoint("TOPLEFT", types, "BOTTOMLEFT", 0, -8)
    types_desc:SetPoint("RIGHT", frame, -32, 0)
    types_desc:SetNonSpaceWrap(true)
    types_desc:SetJustifyH("LEFT")
    types_desc:SetText("You can adjust the types of vignettes to extend. This is inherently fuzzy because we don't get much information about them, so it's just going off their internal icon names. There's nothing stopping Blizzard from categorizing things weirdly, or making new icons.")

    local mystery = simple_config(frame, types_desc, ns.db, "mystery", "Mystery vignettes", "Show mysterious vignettes that don't return any information from the API")

    local type_vignettekill = simple_config(frame, mystery, ns.db.types, "vignettekill", CreateAtlasMarkup("vignettekill", 20, 20) .. " Kill")
    local type_vignettekillelite = simple_config(frame, type_vignettekill, ns.db.types, "vignettekillelite", CreateAtlasMarkup("vignettekillelite", 24, 24) .. " Kill elite")
    local type_vignetteloot = simple_config(frame, type_vignettekillelite, ns.db.types, "vignetteloot", CreateAtlasMarkup("vignetteloot", 20, 20) .. " Loot")
    local type_vignettelootelite = simple_config(frame, type_vignetteloot, ns.db.types, "vignettelootelite", CreateAtlasMarkup("vignettelootelite", 24, 24) .. " Loot elite")
    local type_vignetteevent = simple_config(frame, type_vignettelootelite, ns.db.types, "vignetteevent", CreateAtlasMarkup("vignetteevent", 20, 20) .. " Event")
    local type_vignetteeventelite = simple_config(frame, type_vignetteevent, ns.db.types, "vignetteeventelite", CreateAtlasMarkup("vignetteeventelite", 24, 24) .. " Event elite")

    frame:SetScript("OnShow", nil)
end)

InterfaceOptions_AddCategory(frame)

_G["SLASH_".. myname:upper().."1"] = "/rangeextend"
_G["SLASH_".. myname:upper().."2"] = "/minimaprangeextender"
SlashCmdList[myname:upper()] = function(msg)
    InterfaceOptionsFrame_OpenToCategory(myfullname)
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true)
if ldb then
    LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(myname, {
        type = "launcher",
        icon = [[Interface\Icons\Ability_Spy]],
        OnClick = function(self, button)
            InterfaceOptionsFrame_OpenToCategory(myfullname)
        end,
    })
end
