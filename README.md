# HardcoreLlama

HardcoreLlama is a WoW Classic Hardcore addon for account-wide character tracking, XP source breakdowns, grind-session comparisons, and practical training reminders.

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
- Supports grind sessions with XP per hour, kill XP, average XP per mob, raw copper gained, estimated vendor value from looted items, and best-session comparison by grind/class.
- Shows due and upcoming training reminders, including class-trainer visits and First Aid rank training.

## Slash Commands

- `/hcl` - Toggle the addon window.
- `/hcl stats` - Print current character/account summary.
- `/hcl reminders` - Print due and upcoming training reminders.
- `/hcl grind start [name]` - Start a grind session. If no name is supplied, the current zone is used.
- `/hcl grind stop` - Stop the active grind session and save it.
- `/hcl grind status` - Print the active grind-session snapshot.
- `/hcl grind best` - Print the best saved grind sessions by XP/hour.
- `/hcl help` - Show command help.

## Notes

XP source attribution relies on Classic combat-log/chat events. Kill and discovery XP are parsed from English XP messages; quest XP is tagged from quest completion events where the client exposes them, with a fallback attribution window around XP changes.

Looted vendor value is estimated from item sell prices when item data is cached by the client. Raw money is tracked from positive money changes during an active grind session.

Training reminder data lives in `TrainingData.lua` so the table can be expanded without changing the reminder engine.
