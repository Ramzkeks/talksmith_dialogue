# Talksmith

**English** | [Русский](README.ru.md)

**[Documentation](https://ramzkeks.github.io/talksmith-docs/)**

### Advanced NPC dialogue system for Garry's Mod

Create lively nonlinear conversations, configure characters, and connect dialogues to game systems through a convenient visual editor.

![Garry's Mod](https://img.shields.io/badge/Garry's%20Mod-Addon-4B69FF?style=flat-square)
![Talksmith Studio](https://img.shields.io/badge/Visual-Talksmith%20Studio-35B8C5?style=flat-square)
![Languages](https://img.shields.io/badge/Interface-Russian%20%7C%20English-E7A93B?style=flat-square)
![Version](https://img.shields.io/badge/Version-2.0.0-1F252B?style=flat-square)

---

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo7.jpg" alt="Talksmith dialogue with selectable player responses" width="100%">
</p>

## What is Talksmith?

Talksmith is a complete dialogue builder for Garry's Mod servers. It lets you create NPC characters with branching conversations without writing Lua code manually.

A single dialogue can combine:

- Actor lines and player responses;
- direct and randomized transitions between branches;
- conditions that show responses only to eligible players;
- actions such as rewards, flags, health, weapons, jobs, and more;
- Actor name, description, model, animations, audio, and appearance;
- one of several ready-made runtime interface themes;
- game data supplied by supported integrations.

Dialogues are created in **Talksmith Studio** as a visual graph: every card is an Actor line, and connections between cards represent the routes taken by player responses.

> Talksmith is suitable for shops, tutorials, story characters, job assignment, access systems, interactive objects, and ordinary atmospheric conversations.

## Contents

- [Main features](#main-features)
- [How dialogue creation works](#how-dialogue-creation-works)
- [Talksmith Studio](#talksmith-studio)
- [Actors and the runtime interface](#actors-and-the-runtime-interface)
- [Conditions, actions, and variables](#conditions-actions-and-variables)
- [Dialogue themes](#dialogue-themes)
- [Integrations](#integrations)
- [Quick start](#quick-start)
- [Installation](#installation)
- [Permissions and security](#permissions-and-security)
- [Frequently asked questions](#frequently-asked-questions)
- [Developer documentation](#developer-documentation)

## Main features

| Feature | What it provides |
| --- | --- |
| Visual graph | Build large branching conversations without working directly with code |
| Configurable Actor | Configure name, description, model, scale, skin, bodygroups, and idle animations |
| Response conditions | Show different choices based on money, items, job, flags, and other data |
| Actions | Grant rewards, change player state, open other dialogues, and trigger server events |
| Randomization | Use randomized starting lines, transitions, and chance checks |
| Dynamic text | Insert current game data into lines through variables |
| Safe Preview | Test the current graph in the real runtime interface without executing rewards or server actions |
| Presets | Start with ready-made standard and integration examples |
| Import and export | Move dialogues between servers as JSON |
| Russian and English | Change the Studio language immediately without reconnecting |
| Separated permissions | Control access to Studio, publishing, Actors, integrations, and sensitive actions independently |

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo9.jpg" alt="Talksmith Studio overview" width="100%">
</p>

## How dialogue creation works

A normal workflow consists of a few clear steps:

1. Create a new dialogue and assign it a unique ID.
2. Write the first Actor line.
3. Add player responses.
4. Create subsequent lines and connect responses to them.
5. Add conditions and actions where needed.
6. Configure the Actor, animations, audio, and interface theme.
7. Start the safe Preview.
8. Fix reported problems and save the dialogue.
9. Place the Actor on the map.
10. Approach the Actor and press `E`.

The server determines which responses are available, executes the required actions, and moves the player to the next line.

```text
Actor speaks
      ↓
The player sees the available responses
      ↓
The player selects a response
      ↓
Talksmith executes the actions
      ↓
The dialogue continues or ends
```

## Talksmith Studio

Talksmith Studio is the main interface for creating and managing dialogues.

### Dialogue library

The left side contains all saved documents. You can:

- search by title and ID;
- open and edit documents;
- rename documents;
- duplicate documents;
- import and export documents;
- delete documents with confirmation.

Unsaved changes are marked separately, and Studio warns you before closing a modified document.

### Graph

The central area contains the working canvas:

- cards represent Actor lines;
- rows inside cards represent player responses;
- connections show transitions;
- a red terminal port ends the dialogue;
- the canvas can be panned and zoomed;
- multiple nodes can be selected, copied, pasted, and moved together.

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo8.jpg" alt="Branching dialogue graph in Talksmith Studio" width="100%">
</p>

### Property editor

The selected line is configured on the right:

- main text;
- responses and their order;
- transitions;
- conditions;
- actions;
- card note and color;
- gestures and audio.

### Diagnostics

Talksmith checks the graph while you work:

- errors block saving and Preview;
- warnings highlight suspicious but valid areas;
- selecting a problem takes you to the relevant node;
- revision control prevents an older editor session from silently overwriting newer changes.

### Presets and tutorial

Studio includes:

- a step-by-step tutorial;
- standard examples for the main mechanics;
- separate examples for supported integrations;
- Russian and English preset versions selected according to the interface language.

A preset is added as a draft, so it can be studied and changed before publishing.

## Actors and the runtime interface

An Actor is a Talksmith character placed on the map. One saved dialogue controls one placed Actor; placing the same dialogue again replaces the previous Actor.

You can configure:

- name and description;
- model;
- model scale;
- skin and bodygroups;
- overhead text height;
- one idle animation or a randomized set;
- interaction distance;
- the one-player-at-a-time restriction;
- visibility of the name, description, and `E` interaction hint;
- runtime dialogue theme.

An already placed Actor receives updated settings after the document is saved. Actor placement can be saved automatically for each map.

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo1.jpg" alt="Talksmith Actor with name, description, and interaction hint" width="100%">
</p>

During a conversation, the player can:

- select a response with the mouse;
- use number keys `1-6`;
- scroll long text and response lists with the mouse wheel;
- press `Esc` to leave the conversation.

The conversation also closes safely if the player moves too far away, loses sight of the Actor, remains inactive for too long, or the document changes.

## Conditions, actions, and variables

These tools turn an ordinary conversation into a complete gameplay scenario.

### Conditions

Conditions determine whether the player can see a particular response.

For example:

- whether the player has a required flag;
- whether the player has enough health or money;
- whether the player owns a weapon or item;
- whether the player belongs to a required team or job;
- whether the player is an administrator;
- whether a chance check succeeds;
- whether the current weather, time, level, or active character matches.

When a response has multiple conditions, all of them must pass.

### Actions

Actions run when a line is entered or after the player selects a response.

They can:

- set or clear a flag;
- give or remove an allowed weapon;
- restore health or armor;
- play a sound;
- change the player's job;
- give or take money;
- work with items and inventories;
- open another dialogue;
- end the conversation;
- emit an allowed server event;
- control Wiremod signals.

Preview does not execute real actions. Studio displays what would happen in the game instead.

### Allowed weapons

The `core.give_weapon` and `core.take_weapon` actions, together with weapon-related conditions, use the active server allowlist. It can be managed without editing Lua:

1. Open **Talksmith Studio → Settings → Server**.
2. Under **Allowed weapons**, select **Manage list**.
3. Add a class such as `weapon_pistol`, or remove an entry that is no longer needed.

Changes take effect immediately and persist in `garrysmod/data/talksmith/settings.json`. Managing the list requires `talksmith.settings.manage`. Up to 256 unique classes are accepted; each class is limited to 64 characters using lowercase letters, numbers, and `_`.

If the server owner manually changes the Lua `allowed_weapons` block from its stock value, Lua becomes the authoritative source. Studio displays the effective list but disables menu add/remove. An invalid Lua list blocks weapon actions until it is corrected.


### Variables

Variables insert current data directly into dialogue lines.

For example, a dialogue can show:

```text
Your balance: {pointshop.points}
Current weather: {stormfox2.weather}
Your level: {darkrp_leveling.level}
Health kits in inventory: {inventory.item_count:item_healthkit}
```

Values are calculated separately for every player while the conversation is running.

## Dialogue themes

Four runtime themes are included:

| Theme | Character |
| --- | --- |
| Cinematic | Expressive general-purpose interface for story-focused conversations |
| Retro Terminal | Technical interface inspired by old terminals |
| Panoramic Glass | Wide translucent panels over the game world |
| Open Frame | Minimal display without heavy background blocks |

Text reveal speed is configured globally. The selected theme is used both in the game and in Preview.

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo6.jpg" alt="Cinematic dialogue theme" width="49%">
  <img src="https://hm258634.webhm.pro/talksmith/photo5.jpg" alt="Retro Terminal dialogue theme" width="49%">
</p>
<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo4.jpg" alt="Panoramic Glass dialogue theme" width="49%">
  <img src="https://hm258634.webhm.pro/talksmith/photo2.jpg" alt="Open Frame dialogue theme" width="49%">
</p>

## Integrations

The core Talksmith features work independently. Third-party addons are optional.

When installed, they can provide additional conditions, actions, and variables:

| Integration | What it adds |
| --- | --- |
| PointShop 1 | Points, items, equipment, and shop access |
| Finventory | Items, capacity, and blocked-item rules |
| GWS Inventory System | Inventory, weapons, and ammunition |
| Barney Inventory 2.0 | Inventory, weight, and ammunition |
| DarkRP Leveling System | Levels and experience |
| DarkRP Multi Character | Active character, name, and job |
| Advanced Character Creator 1.5.5+ | Character, name, job, and faction |
| StormFox 2 | Weather, time, and temperature |
| ULib | Permissions and groups |
| ULX | Command access and administrative permissions |
| sAdmin | Permissions and groups |
| Wiremod | Inputs, outputs, signals, and map automation |

Basic DarkRP features are connected automatically when DarkRP is installed. Ultimate Logs can be used separately for Talksmith server diagnostics.

All twelve optional integrations are disabled by default. Administrators enable only the required integrations under **Settings - Integrations**. Integration status and the available action catalog update in an already open Studio window without reconnecting.

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo10.jpg" alt="Talksmith integration settings" width="100%">
</p>

## Quick start

### 1. Open Studio

Join the server with the required permissions and enter this command in chat:

```text
!talksmith_menu
```

Server-side tools are available to `superadmin` by default.

### 2. Create a dialogue

Select **Create**, enter a unique Latin-character ID, and open the new document.

### 3. Build the conversation

Edit the starting line, add responses and nodes, and connect responses to the required cards. A response can also be left as a dialogue-ending option.

### 4. Configure the Actor

Open **Actor and scene**, then select the model, name, description, animations, interaction distance, and theme.

### 5. Test the result

Select **Preview**. Actions in this mode do not grant real money, items, or other rewards.

### 6. Save and place

Fix reported errors, select **Save**, and then select **Place Actor in front of me**.

### 7. Start the conversation

Approach the Actor and press `E`.

> For a quick introduction, open **Presets**, add a standard example as a draft, and examine its graph.

## Installation

### Workshop installation

1. Add Talksmith to the server collection.
2. Make sure the addon is downloaded by the server and clients.
3. Restart the server.
4. Open Studio by entering `!talksmith_menu` in chat.

### Manual installation

Place the addon folder in:

```text
garrysmod/addons/talksmith/
```

The resulting structure must contain at least:

```text
garrysmod/addons/talksmith/lua/autorun/talksmith_init.lua
```

Restart the server completely after installation. No additional database or mandatory third-party library is required.

## Permissions and security

Talksmith is designed for use on public servers:

- player choices are validated again by the server;
- the client cannot grant itself a reward;
- documents are validated before publishing;
- sensitive actions require separate permissions;
- models, sounds, weapons, items, and server events are restricted;
- an older document copy cannot silently overwrite newer changes;
- previous dialogue revisions are stored as backups;
- an ambiguous file API result is accepted only after an exact read-back confirms the persisted content, so live settings and dialogue state do not require a restart;
- reward sequences are protected against accidental repeated execution.

Group-based permissions default to `superadmin`. With sAdmin, ULX/ULib, or a CAMI-compatible admin mod, a minimum group can be configured separately for:

- opening Studio;
- creating, editing, and deleting dialogues;
- publishing;
- managing Actors;
- server settings;
- integrations;
- economy, inventory, jobs, and other sensitive actions.

Access sources work in parallel. A player is allowed when at least one of these checks succeeds:

- Garry's Mod reports the player as a native `superadmin`;
- the player is in Talksmith's individual superadmin list;
- the player's admin-mod group meets the configured minimum group for that specific permission.

Group members receive only the Talksmith permissions configured for their group. An individual Talksmith superadmin receives every Talksmith permission, even without an admin-mod group. This does not change the player's real ULX, sAdmin, or CAMI group and grants no permissions outside Talksmith.

Because `talksmith.settings.manage` can modify the individual list, treat it as full Talksmith access-delegation permission.

### Individual access and RCON recovery

Up to 16 Steam accounts can be managed in **Settings → Permissions** by SteamID or SteamID64. The same list can be managed from the server console or RCON:

```text
talksmith_superadmin_add "STEAM_0:1:12345678"
talksmith_superadmin_remove "STEAM_0:1:12345678"
talksmith_superadmin_status
talksmith_superadmin_clear
```

`talksmith_superadmin_status` lists every configured account and shows whether it is currently online. These commands are server-console-only and cannot be executed by a player client.

The protected archived convar can replace the entire list at once:

```text
talksmith_superadmin "STEAM_0:1:12345678,76561198000000000"
```

An empty value clears the list. Unlike `talksmith_superadmin_add`, changing the convar replaces all current entries, so include every account that should keep access.

The normalized SteamID64 list is saved with the other server settings in:

```text
data/talksmith/settings.json
```

The JSON field is named `superadmins`. Changes are saved before they become active; if saving fails, the previous access list remains in effect.

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo11.jpg" alt="Talksmith permission settings" width="100%">
</p>

## Import, export, and migration

A saved dialogue can be exported as JSON and moved to another server.

Export provides:

- the complete JSON document;
- a copy button;
- a ready-made Lua snippet for placing the Actor from code;
- a local file in `data/talksmith/exports/`.

Import always opens the document as an unpublished draft. Talksmith validates it before saving, so pasting JSON never executes actions automatically.
## Frequently asked questions

### Do I need to program to create a dialogue?

No. Normal dialogues, branches, conditions, actions, Actors, and themes are configured entirely through Talksmith Studio.

### Is DarkRP required?

No. Talksmith works as a standalone addon. Additional conditions and actions become available when DarkRP is installed.

### Can I test a dialogue without granting real rewards?

Yes. Preview shows the real conversation interface but replaces actions with safe notifications.

### Can I move a dialogue to another server?

Yes. Use JSON export and import. The imported document must be reviewed and saved manually.

### Can the language be changed without reconnecting?

Yes. The Russian and English interfaces update immediately in all open Studio windows.

### Why is an integration action unavailable?

Make sure the target addon is installed and its integration is enabled in Talksmith settings. Some operations also require publishing permission.

### Can multiple players talk to the same Actor?

This depends on the dialogue setting. You can allow parallel conversations or enable the one-player-at-a-time mode.

### How should I report a problem?

Include reproduction steps, a screenshot, console or server log errors, the map name, and the list of involved integrations. If the problem affects a specific dialogue, include its exported JSON.

## License

Talksmith is free source-available software.

You may use and modify Talksmith on personal, public and commercial Garry’s Mod servers. GitHub forks, pull requests and independent integrations are welcome.

You may not re-upload, redistribute, resell, rebrand or publish the original or modified Talksmith addon as a separate product.

See [LICENSE.md](LICENSE.md) for the complete terms.

## Developer documentation

For architecture, API, integration lifecycle, parameters, permissions, hooks, and complete server adapter examples, open the [Talksmith developer documentation](https://ramzkeks.github.io/talksmith-docs/).

---

**Talksmith turns an ordinary NPC into a complete participant in the game world.**

<p align="center">
  <img src="https://hm258634.webhm.pro/talksmith/photo13.jpg" alt="Talksmith conversation in the game world" width="100%">
</p>
