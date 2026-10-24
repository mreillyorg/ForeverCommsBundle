# Settings reference

Every option in the bundle, its default, and where it is saved.

Three things hold true throughout:

- **Language and accent are per character.** Everything else in Guild Comms and Group Comms
  is per account.
- **Each addon's Restore Defaults is scoped to that addon.** Neither one resets the shared
  language and accent, and Guild Comms additionally keeps your outgoing mode.
- **Editing a Guild Comms template opts that message out** of translation, accents and
  wording variation. Your text is used verbatim.

---

## Forever Comms Voice — `/fcv`

Saved in `ForeverCommsVoiceCharDB`, **per character**.

### Voice profile

| Setting | Values | Default |
| --- | --- | --- |
| Message language | English, Spanish, French, German, Italian, Portuguese, Polish, Dutch | English |
| Suggest accents for my character's race | on / off | on |
| Accent / RP voice | `Auto (character race)`, `None`, or one of 29 voices in the current language | None |
| Accent strength | Subtle (wording only) / Moderate (adds a catchphrase) / Expressive (catchphrase + emphasis) | Subtle |

The accent list changes with your language and with the race filter. `Auto` resolves to the
first suggested voice for your race, or to neutral wording on a race the addon does not
recognise. Which messages each strength level touches is documented in
[the accent strength section](ForeverCommsVoice-Modules#accent-strength).

### Message review queue

| Setting | Range | Default |
| --- | --- | --- |
| Rows visible (scroll for more) | 1–10 | 2 |
| Message source column | Guild / Group text, or source icon | text |
| Auto-skip after | 0–3600 seconds; **0 = never** | 20 |
| Open queue when a message is added | on / off | on |
| Window position | dragged by the title bar | centre |

Auto-skip **never sends** — it discards. The queue itself is never saved: pending messages
are discarded on logout or `/reload`.

---

## Forever Guild Comms — `/fgc options`

Behaviour and templates are saved in `ForeverGuildCommsDB`, **per account**. Your cached
recipes and role selections are in `ForeverGuildCommsCharDB`, per character.

### General

| Setting | Default | Notes |
| --- | --- | --- |
| Enable addon | on | off stops guild messages and private monitoring |

### Outgoing guild messages

| Setting | Default | Notes |
| --- | --- | --- |
| Guild greetings and congratulations | **Automatic** | the alternative is **Verify with a click** |
| Greet guild members when they log in | on | offline → online only, after the initial roster snapshot |
| Welcome newly joined guild members | on | uses the game's localized guild-join message |
| Congratulate guild members on leveling | on | online-to-online changes only; you are always excluded |
| Vary built-in message wording | on | rotates curated variants; your own templates are never varied |
| Automatic message spacing | 6 s | range 3–120; applies to automatic sends, not to a click |
| Login greeting cooldown | 300 s | range 0–3600; 0 greets on every detected login |

### Private guild requests

| Setting | Default | Notes |
| --- | --- | --- |
| Alert when a guildmate needs an item I can craft | on | needs a request phrase **and** an exact cached recipe name |
| Alert on LFG / LFM / LF group requests | on | reads guild chat only; whispering is manual |
| Play sound for private alerts | off | |
| Open the review list when a message is staged | on | off keeps a busy login quiet; reach it with `/fgc verify`. With the shared queue installed, its own auto-open setting under `/fcv` applies instead |

### Guild tabard

| Setting | Default | Notes |
| --- | --- | --- |
| Remind me to wear my guild tabard in capital cities | on | original Guild Tabard (item 5976); **never equips automatically** |
| Ask about removing the tabard when leaving a city | off | opens the character panel for manual removal |

### Languages & accents

The same four settings as `/fcv`, editing the same per-character profile. Changing them here
or there is identical.

### Custom messages

| Template | Default | Variables |
| --- | --- | --- |
| Guild login greeting | `Welcome back, {name}!` | `{name}`, `{level}` |
| New guild member welcome | `Welcome to the guild, {name}!` | `{name}` |
| Level-up congratulations | `Congratulations on level {level}, {name}!` | `{name}`, `{level}` |
| Manual guild help request | `[LFG] {type}: {activity}. I can fill: {myroles}. Looking for: {needed}. Whisper me!` | `{type}`, `{activity}`, `{myroles}`, `{needed}`, `{name}` |

Each field has a **Use default** button, which restores the built-in wording and re-enables
translation, accents and variation for that message.

### Restore Defaults

Resets this addon's own settings **except**:

- **your outgoing mode**, because resetting it would silently return you to posting without
  confirmation;
- **the shared language and accent**, because they belong to Forever Comms Voice and are
  shared with Group Comms.

---

## Forever Group Comms — `/fgp settings`

Saved in `ForeverGroupCommsDB`, **per account**.

| Setting | Default | Notes |
| --- | --- | --- |
| Enable Forever Group Comms | on | off stops messages and private notifications |
| Automatically greet new groups and members | **off** | off stages each greeting for a click |
| Automatically congratulate level-ups | **off** | off stages each congratulation for a click |
| Use ForeverCommsVoice for group messages | on | off restores the original English rotation |
| Rotate built-in messages | on | avoids the same wording twice in a row |
| Private role double-check alerts | on | private only; never changes anyone's role |
| Private quest-sharing reminder | on | a private nudge on roster changes |
| Share active quest IDs with other Group Comms users | on | active IDs only; both players need it on |

Plus **Configure shared language and accent**, which opens the Forever Comms Voice panel.

**Restore Defaults** restores this addon's settings and leaves the shared language and accent
alone.

Private notifications are kept to 20 entries by default; the stored value is clamped to
5–40.

---

## Fixed limits, not settings

These are not configurable. They are listed because knowing them explains behaviour you
might otherwise read as a bug.

| Limit | Value |
| --- | --- |
| Chat message length | 250 bytes, cut on a character boundary |
| Guild: minimum gap between **approved** sends | 2 seconds |
| Guild: Ask-for-Help rate limit | one per 20 seconds |
| Guild: duplicate suppression | joins 5 min, level-ups 30 min, private alerts 2 min, logins = your login cooldown |
| Guild: roster polling | at most once per 30 s, plus a 60-second ticker |
| Guild: suspicious roster read discarded | zero members, or under 70% of the known count in a guild of more than 10 |
| Guild: alerts kept | 30, newest first |
| Group: minimum gap between **any** sends | 2 seconds |
| Group: duplicate suppression | greetings and welcomes 30 s, level-ups 3 min, notifications 90 s |
| Group: quest packet pacing | ~1 per 1.15 s, max 60 queued, max 12 chunks |
| Group: unchanged quest log not resent within | 240 seconds |
| Group: peer quest data expires after | 300 seconds |
| Review queue capacity | 100 entries, oldest dropped |
