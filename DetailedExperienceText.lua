-----------------------------------------------------------------------------------------------
-- Client Lua Script for DetailedExperienceText
-- Created by Caleb. All rights reserved
-----------------------------------------------------------------------------------------------

--[[
	TODO:
		when opening the config set the left middle right text as it is in the savedvariables
]]--

require "Window"
require "GameLib"
require "math"
require "string"

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local GetXp = GetXp
local GetRestXp = GetRestXp
local GetXpToCurrentLevel = GetXpToCurrentLevel
local GetXpToNextLevel = GetXpToNextLevel
local GetXpToNextLevel = GetXpToNextLevel
local GetElderPoints = GetElderPoints
local GetPeriodicElderPoints = GetPeriodicElderPoints
local Apollo = Apollo
local GameLib = GameLib
local math = math
local string = string
local tostring = tostring
local tonumber = tonumber
local type = type
local ipairs = ipairs
local setmetatable = setmetatable
local select = select
local time = os.time

-----------------------------------------------------------------------------------------------
-- DetailedExperienceText Module Definition
-----------------------------------------------------------------------------------------------
local DetailedExperienceText = {}
local addon = DetailedExperienceText

-----------------------------------------------------------------------------------------------
-- Strings
-----------------------------------------------------------------------------------------------

local L = {
	["TotalTimePlayed"] = "Total time played",
	["TimeThisLevel"] = "Time this level",
	["TimeThisSession"] = "Time this session",
	["Level"] = "Level",
	["TotalXPThisLevel"] = "Total XP this level",
	["Gained"] = "Gained",
	["Remaining"] = "Remaining",
	["TotalXPThisSession"] = "Total XP this session",
	["RestXP"] = "Rest XP",
	["XPPerHourThisLevel"] = "XP/h this level",
	["XPPerHourThisSession"] = "XP/h this session",
	["TimeToLevelForThisLevel"] = "Time to level for this level",
	["TimeToLevelForThisSession"] = "Time to level for this session",
	["ElderPointsPerGem"] = "Elder points/gem",
	["WeeklyElderPoints"] = "Weekly elder points",
	["Default"] = "Default",
	["Nothing"] = "Nothing",
}

-- falses are empty lines
-- always have empty line at top and bottom to have it fit nicely in the frame
local tTooltipLines = {
	false,
	"TotalTimePlayed",
	"TimeThisLevel",
	"TimeThisSession",
	false,
	"Level",
	"TotalXPThisLevel",
	"Gained",
	"Remaining",
	"TotalXPThisSession",
	"RestXP",
	false,
	"XPPerHourThisLevel",
	"XPPerHourThisSession",
	"TimeToLevelForThisLevel",
	"TimeToLevelForThisSession",
	"Alt+Left Click to reset session data.",
	false,
	"ElderPointsPerGem",
	"WeeklyElderPoints",
	false,
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function addon:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	-- initialize variables here
	return o
end

function addon:Init()
	Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- DetailedExperienceText OnLoad
-----------------------------------------------------------------------------------------------
function addon:OnLoad()
	-- Register handlers for events, slash commands and timer, etc.
	-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
	Apollo.RegisterSlashCommand("det", "OnDetailedExperienceTextOn", self)
	Apollo.RegisterTimerHandler("OneSecTimer", "OnTimer", self)
	Apollo.RegisterEventHandler("UI_XPChanged", "GetXP", self)
	Apollo.RegisterEventHandler("PlayerLevelChange", "OnPlayerLevelChange", self)
	self.nXPIntoLevel = nil
	self.nXPToNextLevel = nil
	self.nXPRemainingToNextLevel = nil
	self.nXPPerc = nil
	self.nRestedXP = nil

	self.nTimeThisSession = nil
	self.nSessionStart = time()
	self.nSessionXPStart = GetXp()

	self.tDB = {}
	self.tDB.nPlayed = 0
	self.tDB.nLevelStart = nil
	self.tDB.moveable = nil
	self.tDB.LeftText = "Default"
	self.tDB.MiddleText = nil
	self.tDB.RightText = nil

	-- load our forms
	self.wndMain = Apollo.LoadForm("DetailedExperienceText.xml", "DetailedExperienceTextForm", nil, self)
	self.wndMain:Show(true)

	self.wndTooltipForm = self.wndMain:FindChild("Text"):LoadTooltipForm("DetailedExperienceText.xml", "TooltipForm", self)
	local l,t,r,b = self.wndTooltipForm:GetAnchorOffsets()
	-- do it like this so when changing the TooltipLine height it dynamically changes the whole tooltips height too
	self.wndTooltipForm:SetAnchorOffsets(l, t, r, #tTooltipLines*select(4, Apollo.LoadForm("DetailedExperienceText.xml", "TooltipLine", nil, self):GetAnchorOffsets()))
	self.wndMain:FindChild("Text"):SetTooltipForm(self.wndTooltipForm)

	self.wndOptions = Apollo.LoadForm("DetailedExperienceText.xml", "Options", nil, self)
	self.wndOptions:Show(false)

	self.wndOptions:FindChild("LeftText"):FindChild("ChoiceContainer"):Show(false)
	self.wndOptions:FindChild("MiddleText"):FindChild("ChoiceContainer"):Show(false)
	self.wndOptions:FindChild("RightText"):FindChild("ChoiceContainer"):Show(false)
end

-----------------------------------------------------------------------------------------------
-- DetailedExperienceText Functions
-----------------------------------------------------------------------------------------------
function addon:OnSave(eLevel)
	if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	self.tDB.nPlayed = tostring(self.tDB.nPlayed + self.nTimeThisSession)

	self.tDB.nLevelStart = tostring(self.tDB.nLevelStart)

	local l,t,r,b = self.wndMain:GetAnchorOffsets()
	local wndMainposition = { l = l, t = t, r = r, b = b }
	self.tDB.wndMainposition = wndMainposition

	return self.tDB
end

function addon:OnRestore(eLevel, tData)
	-- just store this and use it later
	self.tDB.nLevelStart = tonumber(tData.nLevelStart)
	self.tDB.nPlayed =  tonumber(tData.nPlayed or 0)
	self.tDB.moveable = tData.moveable
	if self.tDB.moveable then
		self.wndMain:AddStyle("Moveable")
	else
		self.wndMain:RemoveStyle("Moveable")
	end
	self.tDB.LeftText = tData.LeftText
	self.tDB.MiddleText = tData.MiddleText
	self.tDB.RightText = tData.RightText

	if tData.wndMainposition then
		self.wndMain:SetAnchorOffsets(tData.wndMainposition.l, tData.wndMainposition.t, tData.wndMainposition.r, tData.wndMainposition.b)
	end
end

function addon:OnPlayerLevelChange(nLevel, nAttributePoints, nAbilityPoints)
	self.tDB.nLevelStart = self.tDB.nPlayed + self.nTimeThisSession
end

-- on SlashCommand "/det"
function addon:OnDetailedExperienceTextOn()
	self.wndOptions:Show(true)
	--self.wndMain:Show(true) -- show the window
end

local function formatInt(number)
	local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

	-- reverse the int-string and append a comma to all blocks of 3 digits
	int = int:reverse():gsub("(%d%d%d)", "%1,")

	-- reverse the int-string back remove an optional comma and put the
	-- optional minus and fractional part back
	return minus .. int:reverse():gsub("^,", "") .. fraction
end

local function round(x)
  return math.floor(x + 0.5);
end

local function formatTime(nTimeLeft)
	if type(nTimeLeft) ~= "number" then return nTimeLeft end
	local nDays, nHours, nMinutes, nSeconds = math.floor(nTimeLeft / 86400), math.floor((nTimeLeft % 86400) / 3600), math.floor((nTimeLeft % 3600) / 60), nTimeLeft % 60;

	if nDays ~= 0 then
		return ("%dd %dh %dm %ds"):format(nDays, nHours, nMinutes, nSeconds)
	elseif nHours ~= 0 then
		return ("%dh %dm %ds"):format(nHours, nMinutes, nSeconds)
	elseif nMinutes ~= 0 then
		return ("%dm %ds"):format(nMinutes, nSeconds)
	else
		return ("%ds"):format(nSeconds)
	end
end

function addon:UpdateText()
	-- XXX look into if we need more checks or delay some calculations due to game loading too slow
	self.nTimeThisSession = time() - self.nSessionStart
	local nTotalTimePlayed = self.tDB.nPlayed + self.nTimeThisSession
	if not self.tDB.nLevelStart then
		self.tDB.nLevelStart = nTotalTimePlayed
	end
	local nTimeThisLevel = nTotalTimePlayed - self.tDB.nLevelStart

	local nLevel = GameLib.GetPlayerUnit():GetBasicStats().nLevel
	local nXPThisSession = GetXp() - self.nSessionXPStart

	local nXPPerHourThisLevel = round(self.nXPIntoLevel/(nTimeThisLevel/3600))
	local nXPPerHourThisSession = round(nXPThisSession/(self.nTimeThisSession/3600))

	local timeToLevelThisLevel
	if GetXp() == 0 then
		timeToLevelThisLevel = "Infinite"
	else
		timeToLevelThisLevel = self.nXPRemainingToNextLevel * nTimeThisLevel / self.nXPIntoLevel
	end

	local timeToLevelThisSession
	if nXPThisSession == 0 then
		timeToLevelThisSession = "Infinite"
	else
		timeToLevelThisSession = self.nXPRemainingToNextLevel * self.nTimeThisSession / nXPThisSession
	end

	self.tShortTextsAndValues = {
		["TotalTimePlayed"] = {"TTP", formatTime(nTotalTimePlayed)},
		["TimeThisLevel"] = {"TTL", formatTime(nTimeThisLevel)},
		["TimeThisSession"] = {"TTS", formatTime(self.nTimeThisSession)},
		["Level"] = {"lvl", nLevel},
		["TotalXPThisLevel"] = {"TXPTL", formatInt(self.nXPToNextLevel)},
		["Gained"] = {"Gain", ("%s (%.2f%%)"):format(formatInt(self.nXPIntoLevel), self.nXPPerc)},
		["Remaining"] = {"Remain", ("%s (%.2f%%)"):format(formatInt(self.nXPRemainingToNextLevel), 100-self.nXPPerc)},
		["TotalXPThisSession"] = {"TXPTS", formatInt(nXPThisSession)},
		["RestXP"] = {"Rest", formatInt(self.nRestedXP)},
		["XPPerHourThisLevel"] = {"XP/hTL", formatInt(nXPPerHourThisLevel)},
		["XPPerHourThisSession"] = {"XP/hTS", formatInt(nXPPerHourThisSession)},
		["TimeToLevelForThisLevel"] = {"TTLFTL", type(timeToLevelThisLevel) == "number" and formatTime(timeToLevelThisLevel) or timeToLevelThisLevel},
		["TimeToLevelForThisSession"] = {"TTLFTS", type(timeToLevelThisSession) == "number" and formatTime(timeToLevelThisSession) or timeToLevelThisSession},
		["ElderPointsPerGem"] = {"EPPG", formatInt(GetElderPoints())},
		["WeeklyElderPoints"] = {"WEP", formatInt(GetPeriodicElderPoints())},
		["Default"] = {"XP", ("%.2f%% (%s/%s)"):format(self.nXPPerc, formatInt(self.nXPIntoLevel), formatInt(self.nXPToNextLevel))}
	}

	self.wndTooltipForm:DestroyChildren() -- clear the tooltip
	for k, v in ipairs(tTooltipLines) do
		-- empty line text fields are left empty
		local wndCurrLines = Apollo.LoadForm("DetailedExperienceText.xml", "TooltipLine", self.wndTooltipForm, self)
		if v and self.tShortTextsAndValues[v] then
			wndCurrLines:FindChild("Key"):SetText(L[v]..":") -- this is alligned to right
			wndCurrLines:FindChild("Value"):SetText(self.tShortTextsAndValues[v][2])
		elseif v then
			wndCurrLines:SetText(v) -- full line string aligned to center
		end
	end
	self.wndTooltipForm:ArrangeChildrenVert(0)

	local left = ""
	if self.tDB.LeftText and self.tShortTextsAndValues[self.tDB.LeftText] then
		left = ("%s: %s "):format(self.tShortTextsAndValues[self.tDB.LeftText][1], self.tShortTextsAndValues[self.tDB.LeftText][2])
	end
	local middle = ""
	if self.tDB.MiddleText and self.tShortTextsAndValues[self.tDB.MiddleText] then
		middle = ("%s: %s "):format(self.tShortTextsAndValues[self.tDB.MiddleText][1], self.tShortTextsAndValues[self.tDB.MiddleText][2])
	end
	local right = ""
	if self.tDB.RightText and self.tShortTextsAndValues[self.tDB.RightText] then
		right = ("%s: %s "):format(self.tShortTextsAndValues[self.tDB.RightText][1], self.tShortTextsAndValues[self.tDB.RightText][2])
	end

	local str = left .. middle .. right
	if string.len(str) == 0 then -- everything is nil, still display something
		str = ("%s: %s"):format(self.tShortTextsAndValues["Default"][1], self.tShortTextsAndValues["Default"][2])
	end
	self.wndMain:FindChild("Text"):SetText(str)
end

function addon:GetXP()
	if self.nSessionXPStart == 0 then -- failed to get xp on logon
		self.nSessionXPStart = GetXp()
	end
	local nTotalXpToCurrentLevel = GetXpToCurrentLevel()

	self.nXPIntoLevel = GetXp() - nTotalXpToCurrentLevel
	self.nXPToNextLevel = GetXpToNextLevel()
	self.nXPRemainingToNextLevel = self.nXPToNextLevel - self.nXPIntoLevel
	self.nXPPerc = self.nXPIntoLevel/self.nXPToNextLevel*100
	self.nRestedXP = GetRestXp()

	if not self.nXPIntoLevel or not self.nXPToNextLevel or not self.nXPRemainingToNextLevel or not self.nRestedXP then
		return
	end

	self:UpdateText()
end

-- on timer
function addon:OnTimer()
	if GameLib.GetPlayerUnit() then
		self:GetXP()
	end
end

-----------------------------------------------------------------------------------------------
-- DetailedExperienceTextForm Functions
-----------------------------------------------------------------------------------------------
function addon:OnMouseButtonDown(_, _, button)
	if button and button == 0 and Apollo.IsAltKeyDown() then -- left button and alt key down
		self.nSessionStart = time()
		self.nSessionXPStart = GetXp()
	end
end

function addon:CloseOptions()
	self.wndOptions:Close()
end

function addon:OnOptionsShow()
	local width = self.wndMain:GetWidth()
	self.wndOptions:FindChild("WidthSlider"):SetValue(width)
	self.wndOptions:FindChild("WidthEditBox"):SetText(width)
	self.wndOptions:FindChild("MoveableBtn"):SetText(self.tDB.moveable and "Yes" or "No")

	self.wndOptions:FindChild("LeftText"):FindChild("DropTextSelect"):SetText(self.tDB.LeftText and L[self.tDB.LeftText] or L["Nothing"])
	self.wndOptions:FindChild("MiddleText"):FindChild("DropTextSelect"):SetText(self.tDB.MiddleText and L[self.tDB.MiddleText] or L["Nothing"])
	self.wndOptions:FindChild("RightText"):FindChild("DropTextSelect"):SetText(self.tDB.RightText and L[self.tDB.RightText] or L["Nothing"])

	local texts = {"LeftText", "MiddleText", "RightText"}
	for k, form in ipairs(texts) do
		local arBtns = self.wndOptions:FindChild(form):GetChildren()
		for idxBtn = 1, #arBtns do
			arBtns[idxBtn]:SetCheck(false)
		end
	end
end

function addon:OnMoveableBtn(wndHandler)
	if self.tDB.moveable then
		self.wndMain:RemoveStyle("Moveable")
		self.wndOptions:FindChild("MoveableBtn"):SetText("No")
		self.tDB.moveable = false
	else
		self.wndMain:AddStyle("Moveable")
		self.wndOptions:FindChild("MoveableBtn"):SetText("Yes")
		self.tDB.moveable = true
	end
end

function addon:OnResetPositionButton()
	self.wndMain:SetAnchorOffsets(260, -28, 576, 0)
end

function addon:OnWidthSliderChanged(wndHandler, wndControl, fValue, fOldValue)
	local l,t,r,b = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(l, t, l+fValue, b)
	self.wndOptions:FindChild("WidthEditBox"):SetText(fValue)
end

function addon:OnTextSelect(wndHandler, wndControl)
	if wndHandler ~= wndControl then -- in case the window closing trips this
		return
	end
	wndControl:FindChild("ChoiceContainer"):Show(wndControl:IsChecked())
end

function addon:OnTextItemSelect(wndHandler, wndControl)
	local sTextPosition = wndControl:GetParent():GetParent():GetParent():GetName()
	self.tDB[sTextPosition] = wndHandler:GetName() ~= "Nothing" and wndHandler:GetName() or nil

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

-----------------------------------------------------------------------------------------------
-- DetailedExperienceText Instance
-----------------------------------------------------------------------------------------------
local DetailedExperienceTextInst = addon:new()
DetailedExperienceTextInst:Init()