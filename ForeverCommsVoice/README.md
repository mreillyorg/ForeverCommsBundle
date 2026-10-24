# ForeverCommsVoice 0.2.1-beta

**Shared, offline translation and roleplay accent library** for ForeverGuildComms and ForeverGroupComms (WoW Forever 1.60.1, Interface 16001). Author: Michael Reilly.

- One shared per-character profile, saved in `ForeverCommsVoiceCharDB.voice`.
- All 8 existing GuildComms languages and 29 curated accent / race styles are owned in one place, including the original guild variants.
- Party/dungeon messages have curated translations for all 8 languages. Greeting/accomplishment messages have optional accent-specific wording; combat-target instructions stay understandable.
- Names, item/quest links and substituted variables are never algorithmically translated, rewritten or modified.
- Built-in phrases are locally curated, **not** live machine translation of typed chat.
- Shuffle bags avoid repeating built-in variants before exhausting the available alternatives; preview messages do not consume shuffle choices.
- GroupComms can disable shared voice per addon (`Use ForeverCommsVoice for group messages`). GuildComms always uses it.

## Installation

Install the **combined package** for the easiest update of all three addons. Or install this addon first, then GuildComms 0.6.0-beta and/or GroupComms 0.3.0-beta. Both clients declare this addon as a hard `## Dependencies:` entry and **will not load without it**.

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

## Development

From `ForeverCommsVoice`: `texlua tests/integration.lua` (requires the sibling `ForeverGuildComms` and `ForeverGroupComms` source folders). Syntax and integration checks were performed offline; the client UI and client-specific race IDs still require in-game testing.

## Shared communication review queue

New in v0.2.1-beta: `Queue.lua` and `QueueUI.lua` provide a single movable, scrollable click-to-send queue for Guild and Group messages. Open it with `/fcv queue`; `/fcv clear` skips everything. Queue settings live under `/fcv`: number of visible rows (1 to 10), source presentation (Guild/Group text or addon icons), expiry time in seconds (0 = no expiry) and auto-open. The queue owner accepts `V:Enqueue{source="guild"|"group",kind="...",label="...",text="...",send=function() return true end,timeout=seconds}`. Leave `timeout` out to use the current default. The producer must validate guild/group identity at send time. `V:Approve(id)` invokes the callback only on an explicit click; `V:Skip(id)` and expiry never invoke it. `V:SkipAll("guild")` or `V:SkipAll("group")` clears one source only. There is no persistent queue storage.


Queue presentation: a compact, movable, scrollable floating overlay (not a normal Blizzard window). Fresh character defaults are **2 visible rows** and **20 seconds** auto-skip; existing saved queue preferences remain unchanged. `/fcv queue` opens the overlay.
