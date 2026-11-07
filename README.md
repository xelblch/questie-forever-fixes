# Questie Forever Fixes

A small WoW Forever addon that fills in quest-chain data missing from [Questie](https://github.com/Questie/Questie) / [QuestieDB](https://github.com/Questie/QuestieDB).

Many Forever-only quests have no prerequisite in QuestieDB, so Questie shows follow-up quests on the map before they are available. For example, *Wild Eyes* (91920) shows up before *Return to Quinn* (430) is done. This addon adds the missing links through QuestieDB's public correction API (`LibQuestieDB.SetCorrection`). Questie and QuestieDB stay untouched, so their updates don't wipe the fixes.

## Install
Copy the folder to `World of Warcraft\_forever_\Interface\AddOns\QuestieForeverFixes`, restart the game fully, and enable **Questie Forever Fixes** in the AddOns list. Requires QuestieDB.

## Commands
| Command | What it does |
|---|---|
| `/qff` | Show how many fixes are active and how many NPCs are logged |
| `/qff check` | Compare each manual fix with what QuestieDB returns (`ok` / `MISMATCH`, plus who supplied the value) |
| `/qff npc [note]` | Log the targeted NPC (ID, name, map, coordinates, your quest log) so its chains can be checked later |
| `/qff log` / `/qff clear` | Show the last log entries / empty the log |
| `/qff help` | List the commands |

The log is saved to `WTF\Account\<account>\SavedVariables\QuestieForeverFixes.lua` on logout or `/reload`.

## Files
- `Fixes.lua`: hand-written fixes, one entry per quest using QuestieDB field names (`preQuestSingle`, `nextQuestInChain`, ...). These win over generated ones.
- `Generated.lua`: fixes generated offline from Wowhead chain data and Blizzard's quest-line table. Don't edit it by hand.
- `Core.lua`: merges both lists, publishes them to QuestieDB, and handles the `/qff` commands. If QuestieDB's API is missing, it does nothing and prints one chat line.

Generated fixes only fill **missing** prerequisites, never override QuestieDB. A step `A -> B` is applied only when A's turn-in NPC starts B and A isn't an optional breadcrumb. Uncertain chains are left out.

When QuestieDB ships a fix upstream, `/qff check` shows it coming from QuestieDB and the local entry can be deleted.
