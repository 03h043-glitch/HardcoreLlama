# HardcoreLlama

HardcoreLlama is a WoW Classic Hardcore addon for account-wide character tracking, XP source breakdowns, grind-session comparisons, automatic dungeon-run history, training reminders, weapon progression info, and fallen-character history.

## Install

1. Download or clone this repository.
2. Copy the `HardcoreLlama` folder into your WoW Classic Era addon directory, for example:
   `World of Warcraft/_classic_era_/Interface/AddOns/HardcoreLlama`
3. Restart the game or run `/reload`.
4. Use `/hcl` or `/hardcorellama` in chat.

## Features

- Tracks every character that logs in on the account/PC through account-wide SavedVariables.
- Records character name, realm, class, level, XP gained, rested XP gained, and XP source breakdowns.
- Tracks fastest recorded time through each level and highest level reached by class.
- Supports grind sessions with XP per hour, kill XP, average XP per mob, raw copper gained, estimated vendor value from looted items, the most commonly killed mob with its observed level range, and best-session comparison by grind/class.
- Automatically logs dungeon runs when entering and leaving party instances, using the dungeon name as the saved run title.
- Shows dungeon metrics without quest XP/rewards by default, while dungeon row tooltips include the quest-inclusive totals.
- Trims dungeon timers to the period between the first and last XP gain so waiting at the entrance and exit downtime do not distort run rates.
- Provides an Info page with rough class-aware weapon progression, item icons, source filters, priest wand targets, and a dual-wield toggle for dual-wield classes.
- Hides crafted weapon-progression options unless the current character has the profession trained that creates the item.
- Uses class colors anywhere a character class is shown in addon text.
- Provides a compact resizable tracker window with configurable text size.
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

Mob level ranges are captured from visible unit data at the XP event and from target/mouseover sightings during the active grind. If no level is exposed for a killed mob type, the grind summary still records the mob name and shows an unknown level marker.

Dungeon quest reward money is separated from repeatable raw money when the client exposes the quest reward amount. If the reward is not exposed by the client event, the run still tracks the XP split and all observed money changes.

Weapon progression is intentionally a rough Hardcore leveling guide, not an exhaustive best-in-slot database. It favors realistic quest, dungeon, vendor, crafted, and Auction House checkpoints, and the Info page source toggles let challenge runs hide acquisition methods they cannot use.

Crafted weapon suggestions are additionally gated by the current character's trained professions. For example, crafted wand checkpoints are only shown when Enchanting is trained.

Looted vendor value is estimated from item sell prices when item data is cached by the client. Raw money is tracked from positive money changes during an active grind session or dungeon run.

Training reminder data lives in `TrainingData.lua`. Static class-spell reminders cover early leveling, and trainer-cache reminders become more accurate after the player opens their class trainer.
