# ForeverCommsVoice 0.2.2-beta

**Shared, offline translation and roleplay accent library** for ForeverGuildComms and ForeverGroupComms (WoW Forever 1.60.1, Interface 16001). Author: Michael Reilly.

- One shared per-character profile, saved in `ForeverCommsVoiceCharDB.voice`.
- All 8 existing GuildComms languages and 29 curated accent / race styles are owned in one place, including the original guild variants.
- Party/dungeon messages have curated translations for all 8 languages. Greeting/accomplishment messages have optional accent-specific wording; combat-target instructions stay understandable.
- Names, item/quest links and substituted variables are never algorithmically translated, rewritten or modified.
- Built-in phrases are locally curated, **not** live machine translation of typed chat.
- Shuffle bags avoid repeating built-in variants before exhausting the available alternatives; preview messages do not consume shuffle choices.
- GroupComms can disable shared voice per addon (`Use ForeverCommsVoice for group messages`). GuildComms always uses it.

## Installation

Install the **combined package** for the easiest update of all three addons. Or install this addon first, then GuildComms 0.6.3-beta and/or GroupComms 0.3.4-beta. Both clients declare this addon as a hard `## Dependencies:` entry and **will not load without it**.

Put this folder at `_classic_beta_\Interface\AddOns\ForeverCommsVoice`, then `/reload`.

Use **`/fcv`** or Settings > AddOns > Forever Comms Voice to edit the shared per-character language, accent, race filter and intensity. GuildComms continues to expose the same controls in its settings/Titan menu.

## Upgrade and migration

On first login with updated GuildComms, its existing `ForeverGuildCommsCharDB.voice` settings are copied into `ForeverCommsVoiceCharDB.voice` and marked as migrated. Later logins won't overwrite changes made in shared settings. If the player has never used GuildComms, Voice starts from safe defaults. Existing guild account-wide custom text templates remain in `ForeverGuildCommsDB` unchanged.

**Keep your existing WTF/SavedVariables files for rollback.** Normal addon reinstall does not remove those files. Both addons use their own independent behaviour settings. This is a per-character profile, not a synchronised account-wide profile.

## API

```lua
local V = _G.ForeverCommsVoice
local message = V:Render("group", "pull", nil, {random=true})
local welcome = V:Render("guild", "join", {name="Rosa"},
    {custom=ForeverGuildCommsDB.templates.join, random=true})
```

The library does not send chat, run automatic actions or change what the player types. Consuming addons own when/how a message is delivered.

## Accent strength, and which messages it touches

One per-character **Strength** setting applies to both addons. It has two separate effects, and the same rule decides whether *either* applies:

- **Subtle (wording only)** — the accent's own phrasebook, with nothing added in front.
- **Moderate (adds a catchphrase)** — prefixes the regional or racial interjection, for example `By the forge! `.
- **Expressive (catchphrase + emphasis)** — the prefix, and then the closing punctuation is amplified: a final `.` becomes `!`, and a final `!` becomes `!!`.

Both effects are limited to the same set of messages:

| Scope | Messages affected | Messages left exactly neutral |
| --- | --- | --- |
| Guild | every message kind | `help` — keeps `[LFG]` at the front and its original punctuation so it stays scannable |
| Group | `greet`, `welcome`, `level` | every coordination and combat directive: `pull`, `mana`, `regroup`, `heal`, `cc`, `skull`, `interrupt`, plus `roles`, `quests` and `request` |

**Group social messages are in scope on purpose.** Setting Expressive changes the punctuation of your group greetings, welcomes and level congratulations, not just your guild messages. Dungeon instructions are deliberately excluded: at the same setting, `Focus skull first, please.` keeps its full stop while `May the stars guide our group.` becomes `May the stars guide our group!`, because an instruction has to stay plain to be followed under pressure.

Two details worth knowing:

- Some accents ship **curated group wordings** for `greet` and `level`. Those replace the sentence rather than decorating it, so they take no catchphrase prefix — otherwise `By the forge! ` would land in front of `By the forge! Good tae see ye all!`. Expressive still amplifies their final mark.
- Punctuation is amplified **before** `{name}`, `{level}` and `{quest}` are substituted, so a player or quest name is never altered.

`tests/expressive.lua` pins this whole table.

## Development

Run the whole bundle's suite from the repository root with `python tools/run_tests.py`, which discovers every harness. To run just this package's harnesses, from `ForeverCommsVoice`: `lua5.1 tests/integration.lua`, `lua5.1 tests/expressive.lua`, `lua5.1 tests/queue.lua`, `lua5.1 tests/queue_ui.lua`, `lua5.1 tests/syntax.lua`. `integration.lua` requires the sibling `ForeverGuildComms` and `ForeverGroupComms` source folders. Syntax and integration checks were performed offline; the client UI and client-specific race IDs still require in-game testing.

## Shared communication review queue

New in v0.2.1-beta: `Queue.lua` and `QueueUI.lua` provide a single movable, scrollable click-to-send queue for Guild and Group messages. Open it with `/fcv queue`; `/fcv clear` skips everything. Queue settings live under `/fcv`: number of visible rows (1 to 10), source presentation (Guild/Group text or addon icons), expiry time in seconds (0 = no expiry) and auto-open. The queue owner accepts `V:Enqueue{source="guild"|"group",kind="...",label="...",text="...",send=function() return true end,timeout=seconds}`. Leave `timeout` out to use the current default. The producer must validate guild/group identity at send time. `V:Approve(id)` invokes the callback only on an explicit click; `V:Skip(id)` and expiry never invoke it. `V:SkipAll("guild")` or `V:SkipAll("group")` clears one source only. There is no persistent queue storage.


Queue presentation: a compact, movable, scrollable floating overlay (not a normal Blizzard window). Fresh character defaults are **2 visible rows** and **20 seconds** auto-skip; existing saved queue preferences remain unchanged. `/fcv queue` opens the overlay.

## What changed in 0.2.2-beta

**Fixed: the Settings panel now appears as soon as the addon loads.** It previously
registered only after you typed `/fcv`, so Forever Comms Voice was missing from
Settings > AddOns on a fresh login. If you had been using `/fcv` to reach it, you no
longer need to. Nothing about your saved profile changes.

**Clearer accent strength labels.** The three choices now say what they do:
**Subtle (wording only)**, **Moderate (adds a catchphrase)** and
**Expressive (catchphrase + emphasis)**. The behaviour is unchanged — only the labels
were ambiguous, particularly Subtle, which adds no prefix at all.

**New documentation: which messages accent strength touches.** See the section above.
Expressive reaches group greetings, welcomes and level congratulations as well as guild
messages, and never touches a dungeon or combat directive. That was always true and was
never written down.

Internal changes with no intended effect on wording: the review queue's expiry sweep now
runs from a half-second timer instead of every frame; `V:Render` was split into per-scope
resolvers; and two unreachable functions were removed. The refactor was checked by
rendering every combination of scope, kind, language, accent and strength — 3,774
messages — and confirming none came out blank, none had an unfilled placeholder, none
exceeded the chat byte limit and no combat directive picked up an accent. That is a
property check, not a byte-for-byte comparison against the previous version, so if you
spot wording that looks wrong, please report it.
