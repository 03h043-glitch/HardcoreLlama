# HardcoreLlama

HardcoreLlama is a WoW Classic Hardcore addon for account-wide character tracking, XP source breakdowns, grind-session comparisons, automatic dungeon-run history, training reminders, weapon progression info, and fallen-character history.

## Install

1. Download or clone this repository.
2. Copy the `HardcoreLlama` folder into your WoW Classic Era addon directory, for example:
   `World of Warcraft/_classic_era_/Interface/AddOns/HardcoreLlama`
3. Restart the game or run `/reload`.
4. Use the minimap button, `/hcl`, or `/hardcorellama` in chat.

## Features

- Tracks every character that logs in on the account/PC through account-wide SavedVariables.
- Records character name, realm, class, level, XP gained, rested XP gained, and XP source breakdowns.
- Tracks fastest recorded time through each level and highest level reached by class.
- Supports grind sessions with XP per hour, kill XP, average XP per mob, total mob kills, looted item vendor value, the most commonly killed mob with its observed level range, and best-session comparison by grind/class.
- Automatically starts a grind when three XP-awarding mobs with the same name are killed within three minutes outside an active dungeon run, then seeds the live session with those trigger kills.
- Shows auto-started grinds in a compact resizable live tracker instead of opening the primary addon window.
- Opens the full live active-grind dashboard for manually started grinds, with realtime XP/hour, total XP, mob kills, average XP per mob, rested XP, vendor value, duration, idle timer, and XP source breakdown.
- Automatically saves and ends an active grind when the player dies, opens a vendor, casts Hearthstone, receives no XP or loot for 90 seconds, or goes three minutes without killing the mob type that triggered auto-start.
- Discards completed grinds with fewer than 10 mob kills so short accidental sessions do not pollute history or tier rankings.
- Assigns and announces XP/hour, vendor value/hour, and combined tier rankings when an open-world grind or dungeon run is completed.
- Shows tier-list tabs for open-world grinds, dungeon grinds, and a combined list where both categories are compared together.
- Automatically logs dungeon runs when entering and leaving party instances, using the dungeon name as the saved run title.
- Shows dungeon metrics without quest XP/rewards by default, while dungeon row tooltips include the quest-inclusive totals.
- Trims dungeon timers to the period between the first and last XP gain so waiting at the entrance and exit downtime do not distort run rates.
- Provides an Info page with rough class-aware weapon progression, item icons, source filters, priest wand targets, and a dual-wield toggle for dual-wield classes.
- Hides crafted weapon-progression options unless the current character has the profession trained that creates the item.
- Uses class colors anywhere a character class is shown in addon text.
- Provides a compact resizable tracker window with configurable text size and a draggable minimap button for opening it without slash commands.
- Shows specific class spell/rank reminders, caches exact class-trainer services after you visit a trainer, and keeps profession reminders tied to the professions and secondary skills the character actually has.
- Warns on level-up when trained professions or secondary skills fall behind the level x 5 target, and warns Warriors/Rogues when Defense is more than 5 skill below cap.
- Keeps chat reminders quiet: level-up summaries only, plus profession-cap warnings when a gained profession skill point makes the next rank trainable.
- Records fallen heroes with name, race, class, level, zone, death time, and `/played` time captured at death.

## Slash Commands

- `/hcl` - Toggle the addon window.
- `/hcl stats` - Print current character/account summary.
- `/hcl reminders` - Print due and upcoming training reminders.
- `/hcl fallen` - Open the fallen heroes log.
- `/hcl dungeons` - Open automatic dungeon history.
- `/hcl info` - Open weapon progression info.
- `/hcl font [9-18|up|down|reset]` - Adjust tracker-window text size or reset the window.
- `/hcl grind start [name]` - Start a grind session. If no name is supplied, the current zone is used.
- `/hcl grind stop` - Stop the active grind session and save it.
- `/hcl grind status` - Print the active grind-session snapshot.
- `/hcl grind best` - Print the best saved grind sessions by XP/hour.
- `/hcl help` - Show command help.

## Notes

XP source attribution relies on Classic combat-log/chat events. Kill and discovery XP are parsed from English XP messages; quest XP is tagged from quest completion events where the client exposes them, with a fallback attribution window around XP changes.

Auto-started grinds use the same XP-awarding kill messages as normal grind metrics. Grey mobs or other kills that do not generate XP are not counted toward the three-kill trigger.

After an auto-started grind begins, the trigger mob type remains important: killing other mobs can keep the normal XP/loot activity timer alive, but the grind still ends if the original trigger mob type is not killed again within three minutes.

Mob level ranges are captured from visible unit data at the XP event and from target/mouseover sightings during the active grind. If no level is exposed for a killed mob type, the grind summary still records the mob name and shows an unknown level marker.

Tier rankings use the XP-to-next-level table from the supplied chart. Each run is assigned a grind level from the highest mob level recorded in the session, then XP/hour is scaled as percent of that level per hour. Vendor value is scaled with the same level requirement denominator, and the combined tier normalizes XP and vendor value within the selected tab before averaging them.

Dungeon quest reward money is separated from repeatable raw money when the client exposes the quest reward amount. If the reward is not exposed by the client event, the run still tracks the XP split and all observed money changes.

Weapon progression is intentionally a rough Hardcore leveling guide, not an exhaustive best-in-slot database. It favors realistic quest, dungeon, vendor, crafted, and Auction House checkpoints, and the Info page source toggles let challenge runs hide acquisition methods they cannot use.

Crafted weapon suggestions are additionally gated by the current character's trained professions. For example, crafted wand checkpoints are only shown when Enchanting is trained.

Grind value is intentionally vendor-only: looted item sell prices are counted when item data is cached by the client, while raw copper gained is ignored for grind comparisons. Dungeon runs still keep their separate repeatable raw money and vendor-value metrics.

Training reminder data lives in `TrainingData.lua`. Static class-spell reminders cover early leveling, and trainer-cache reminders become more accurate after the player opens their class trainer.
