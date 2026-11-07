-- Quest corrections applied on top of QuestieDB.
--
-- One entry per quest: [questId] = { <field> = <value>, ... }
-- Field names are QuestieDB questKeys (preQuestSingle, preQuestGroup, nextQuestInChain,
-- exclusiveTo, breadcrumbForQuestId, ...). Add a `source` and `note` for traceability;
-- those two keys are documentation only and are never sent to QuestieDB.
--
-- When QuestieDB ships the same fix upstream, the entry becomes redundant (harmless) —
-- `/qff check` reports which entries upstream already matches so they can be deleted.

local _, QFF = ...

QFF.fixes = {
	-- Silverpine Forest, Horde: 428 Lost Deathstalkers -> 429 Wild Hearts -> 430 Return to Quinn
	--   -> 91920 Wild Eyes -> 91921 Return to Quinn (Again)
	[430] = { -- Return to Quinn
		nextQuestInChain = 91920, -- upstream still says 425 (pre-Forever chain)
		source = "https://www.wowhead.com/forever/quest=91920/wild-eyes",
	},
	[91920] = { -- Wild Eyes / Дикие глаза
		preQuestSingle = {430},
		nextQuestInChain = 91921,
		source = "https://www.wowhead.com/forever/quest=91920/wild-eyes",
	},
	[91921] = { -- Return to Quinn (Again) / Назад к Квинну (опять)
		preQuestSingle = {91920},
		source = "https://www.wowhead.com/forever/quest=91920/wild-eyes",
	},
}
