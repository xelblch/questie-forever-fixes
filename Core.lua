-- Publishes Fixes.lua to QuestieDB through its public correction API (LibQuestieDB.SetCorrection).
-- Fails safe: if the API is missing or rejects the data, nothing is changed and one chat line
-- explains why. Questie itself is never modified.

local ADDON_NAME, QFF = ...

local OWNER = ADDON_NAME
local SLOT = "QuestChains"
local PREFIX = "|cff33ff99QuestieForeverFixes|r: "
local DOC_ONLY = { source = true, note = true }

local function say(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function getApi()
	local lib = _G.LibQuestieDB
	if type(lib) ~= "table" or type(lib.SetCorrection) ~= "function"
		or not (lib.Meta and lib.Meta.QuestMeta and lib.Meta.QuestMeta.questKeys) then
		return nil, "QuestieDB correction API not found (QuestieDB changed?) - fixes NOT applied"
	end
	return lib
end

-- Convert { preQuestSingle = {...} } into { [13] = {...} } using QuestieDB's own key table.
-- Generated fixes first, then manual Fixes.lua on top (manual wins per field).
local function mergedFixes()
	local merged = {}
	for _, source in ipairs({ QFF.generated or {}, QFF.fixes or {} }) do
		for questId, fields in pairs(source) do
			merged[questId] = merged[questId] or {}
			for k, v in pairs(fields) do merged[questId][k] = v end
		end
	end
	return merged
end

local function buildRows(questKeys)
	local rows, count, bad = {}, 0, {}
	QFF.all = mergedFixes()
	for questId, fields in pairs(QFF.all) do
		local row = {}
		for name, value in pairs(fields) do
			if not DOC_ONLY[name] then
				local index = questKeys[name]
				if index then
					row[index] = value
				else
					bad[#bad + 1] = questId .. "." .. name
				end
			end
		end
		rows[questId] = row
		count = count + 1
	end
	return rows, count, bad
end

local function apply()
	local lib, err = getApi()
	if not lib then
		say(err)
		return
	end
	local rows, count, bad = buildRows(lib.Meta.QuestMeta.questKeys)
	if #bad > 0 then
		say("unknown field(s) skipped: " .. table.concat(bad, ", "))
	end
	local ok, msg = pcall(lib.SetCorrection, OWNER, "Quest", SLOT, rows)
	if not ok then
		say("QuestieDB rejected the fixes - NOT applied: " .. tostring(msg))
		return
	end
	QFF.applied = count
end

apply()

-- /qff        status
-- /qff check  compare each fix with what QuestieDB now returns, and with the upstream owner
local function fmt(v)
	if type(v) == "table" then
		local parts = {}
		for i = 1, #v do parts[i] = tostring(v[i]) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return tostring(v)
end


--------------------------------------------------------------------------------------------
-- Field log: /qff npc [note] records the targeted NPC so its quest chains can be checked
-- against Wowhead later. Stored account-wide in QuestieForeverFixesLog (SavedVariables,
-- written to WTF\Account\<acc>\SavedVariables\QuestieForeverFixes.lua on logout or /reload).
--------------------------------------------------------------------------------------------

local function getLog()
	QuestieForeverFixesLog = QuestieForeverFixesLog or {}
	QuestieForeverFixesLog.entries = QuestieForeverFixesLog.entries or {}
	return QuestieForeverFixesLog.entries
end

-- "Creature-0-1234-0-12-1951-0000ABCD" -> "Creature", 1951
local function parseGuid(guid)
	if not guid then return nil end
	local unitType, _, _, _, _, id = strsplit("-", guid)
	return unitType, tonumber(id)
end

local function playerPosition()
	local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not mapId then return nil end
	local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapId, "player")
	local x, y
	if pos then x, y = pos:GetXY() end
	local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapId)
	return mapId, info and info.name, x and math.floor(x * 10000) / 100, y and math.floor(y * 10000) / 100
end

local function activeQuestIds()
	local ids = {}
	local ok = pcall(function()
		if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
			for i = 1, C_QuestLog.GetNumQuestLogEntries() do
				local info = C_QuestLog.GetInfo(i)
				if info and not info.isHeader and info.questID and info.questID > 0 then
					ids[#ids + 1] = info.questID
				end
			end
		elseif GetNumQuestLogEntries and GetQuestLogTitle then
			for i = 1, GetNumQuestLogEntries() do
				local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
				if not isHeader and questId and questId > 0 then ids[#ids + 1] = questId end
			end
		end
	end)
	return ok and ids or {}
end

local function logNpc(note)
	local guid = UnitGUID("target")
	local unitType, npcId = parseGuid(guid)
	if not guid or UnitIsPlayer("target") or not npcId then
		say("target an NPC first, then /qff npc [note]")
		return
	end
	local mapId, mapName, x, y = playerPosition()
	local entry = {
		time = date("%Y-%m-%d %H:%M:%S"),
		npcId = npcId,
		unitType = unitType,
		name = UnitName("target"),
		mapId = mapId,
		mapName = mapName,
		x = x,
		y = y,
		playerLevel = UnitLevel("player"),
		faction = UnitFactionGroup("player"),
		note = (note and note ~= "") and note or nil,
		activeQuests = activeQuestIds(),
	}
	local log = getLog()
	log[#log + 1] = entry
	say(("logged #%d: %s (npc %d)%s at %s %s,%s"):format(#log, tostring(entry.name), npcId,
		entry.note and (' "' .. entry.note .. '"') or "", tostring(mapName), tostring(x), tostring(y)))
end

local function showLog()
	local log = getLog()
	say(#log .. " logged NPC(s). Saved to disk on logout or /reload.")
	for i = math.max(1, #log - 4), #log do
		local e = log[i]
		say(("#%d %s %s (npc %d) %s"):format(i, e.time, tostring(e.name), e.npcId, e.note or ""))
	end
end

local HELP = {
	"/qff - status",
	"/qff check - verify the manual fixes are active",
	"/qff npc [note] - log the targeted NPC for a later Wowhead chain check",
	"/qff log - show the last logged NPCs",
	"/qff clear - empty the NPC log (do this after the log was processed)",
}

local function checkFixes(lib)
	for questId, fields in pairs(QFF.fixes) do -- manual fixes only; generated ones can be hundreds
		local name = lib.Quest.Get(questId, "name") or "?"
		for field, wanted in pairs(fields) do
			if not DOC_ONLY[field] then
				local now = lib.Quest.Get(questId, field)
				local owner = lib.GetProvenance and lib.GetProvenance("Quest", questId, field) or "?"
				local state = fmt(now) == fmt(wanted) and "|cff00ff00ok|r" or "|cffff0000MISMATCH|r"
				say(("%d %s: %s = %s (%s, from %s)"):format(questId, name, field, fmt(now), state, tostring(owner)))
			end
		end
	end
end

SLASH_QUESTIEFOREVERFIXES1 = "/qff"
SlashCmdList.QUESTIEFOREVERFIXES = function(arg)
	local cmd, rest = (arg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "npc" then
		logNpc(rest)
	elseif cmd == "log" then
		showLog()
	elseif cmd == "clear" then
		local n = #getLog()
		QuestieForeverFixesLog.entries = {}
		say("cleared " .. n .. " log entries")
	elseif cmd == "help" then
		for _, line in ipairs(HELP) do say(line) end
	elseif cmd == "check" then
		local lib = getApi()
		if not lib or not QFF.applied then
			say("fixes are NOT active (see the earlier error)")
			return
		end
		checkFixes(lib)
	else
		say((QFF.applied or 0) .. " quest fix(es) active, " .. #getLog() .. " NPC(s) logged. /qff help for commands.")
	end
end
