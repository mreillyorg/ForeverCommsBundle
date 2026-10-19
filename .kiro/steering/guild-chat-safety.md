# Chat safety invariants

Two addons in this bundle write to shared social channels. Spam, duplicates, or a message
sent to the wrong audience is the worst failure mode either has — worse than a missed
greeting. Treat every rule below as a hard invariant and preserve it in any change that
touches sending, roster diffing, chat parsing or the shared voice layer.

`ForeverCommsVoice` has no rules here because it never sends. **Keep it that way:** the
library renders text and the consumer decides whether, when and where it goes out. Never
move a delivery decision into the library.

## ForeverGuildComms — guild chat

### Never send without all of these

1. **`A:CanUse()`** — addon enabled *and* `IsInGuild()`.
2. **The feature's own toggle** (`db.greetLogin`, `db.greetJoin`, `db.congratulateLevel`).
3. **Self-exclusion** via `A:IsSelf(name, guid)` — checks GUID first, then the normalized
   name and realm-qualified variants. Never shorten a character name beyond stripping an
   explicit `-Realm` suffix; guildmates can share a first name.
4. **Duplicate suppression** via `A:QueueGuild(message, key, cooldown)`. The key is
   `kind:normalizedName[:detail]`; cooldowns in use are logins `db.loginCooldown` (300s
   default), joins 300s, level-ups 1800s, alerts 120s.
5. **The spacing queue** — `A:QueueGuild` → `A:DrainQueue` enforces at least
   `max(3, db.messageSpacing)` seconds between sends. Never call `A:SendGuild` directly
   for automatic messages; direct sends are reserved for explicit user button presses
   (`A:SendHelpRequest`, which additionally rate-limits to one per 20 seconds, and
   `A:ApproveMessage`).

### Outgoing mode

- `db.outgoingMode` is `automatic` or `verify`, and anything else is forced to
  `automatic` on load. In `verify`, `A:QueueGuild` stages the entry instead of enqueuing
  it and nothing posts until the user clicks Send.
- **Toggling the mode is not an approval.** Switching `verify` → `automatic` must leave
  staged entries staged. Switching `automatic` → `verify` while a message is in the
  spacing delay must capture it into the backlog rather than letting it post.
- `A:ApproveMessage` re-checks `CanUse()` and the guild identity at click time and
  discards the entry if the guild changed. It must never schedule a delayed send after a
  click — the click *is* the send.

### Roster diffing rules

- The first roster read after login, `/reload`, or a guild change is a **baseline**: it
  updates state and sends nothing. Missing an early transition is preferred over
  greeting everyone at once.
- Login greetings fire only on `offline → online`; level congratulations only on
  `online → online` with a numeric previous level greater than zero and a strictly
  higher new level. Newly seen members never produce a level message.
- Discard suspicious roster reads rather than acting on them: zero members, or a count
  that collapses to under 70% of the known count when the guild has more than 10 members.
- On a guild change, `wipe(A.pendingMessages)` and `A:ClearApprovals()` so queued or
  staged text cannot leak into the new guild, and reset `rosterReady` / `roster` / counts.
- Poll the roster at most once per 30 seconds (`A:RequestRoster` throttle) and on a
  60-second ticker. Do not request on every `GUILD_ROSTER_UPDATE`.

### Parsing rules

- Only `CHAT_MSG_GUILD` feeds alert detection, and the sender is dropped if
  `A:IsSelf(sender)`.
- Strip color and hyperlink escapes with the `cleanChat` helper before matching, keeping
  the visible item name.
- Craft alerts require **both** an explicit request phrase and an exact cached
  recipe/output name. Group alerts require a request pattern and must not fire on a
  message already treated as a craft request.
- Guild-join detection must build its pattern from the localized `ERR_GUILD_JOIN_S`
  global, never from a hardcoded English sentence.

## ForeverGroupComms — party, raid and instance chat

### Never send without all of these

1. **`A:CanChat()`** — addon enabled *and* `activeGroup` *and* `SendChatMessage` exists.
2. **`A:GroupChannel()`** resolves the destination — `INSTANCE_CHAT`, then `RAID`, then
   `PARTY`. Never hardcode a channel and never fall back to a guild or public channel.
3. **The 2-second floor** in `A:Send`, which applies to *every* post including an
   approved suggestion. There is no separate unthrottled path.
4. **Self-exclusion** — `key ~= self.playerKey` before a welcome or congratulation.
5. **Duplicate suppression** via `A:IsDuplicate`. Keys in use: `join:<serial>` 30s,
   `welcome:<key>:<serial>` 30s, `level:<key>:<level>` 180s, `notify:<key>` 90s.

### Staging is the default

- `db.autoGreeting` and `db.autoLevel` both default to **false**, so greetings, welcomes
  and congratulations are staged by `A:Stage` for a click. Keep new chat-posting features
  defaulting to staged.
- Every suggestion is stamped with `groupSerial`. `A:Approve` refuses an entry whose
  serial no longer matches and removes it — a suggestion must never post to a group it
  was not written for.
- `A:Stage` notifies and never force-shows a window.

### Group roster rules

- `A:ScanRoster(silent)` with `silent = true` suppresses all messaging. The first scan at
  `Initialize` is silent, and the `PLAYER_ENTERING_WORLD` path is the only other silent
  one. Anything else must be able to justify sending.
- Any change to the member set bumps `groupSerial`, `wipe`s `approvals` and clears quest
  peers. Clicks are preserved only while the exact roster is stable.
- Read **assigned** roles only (`UnitGroupRolesAssigned`), map an unknown value to
  `NONE`, and never infer a spec or change anyone's role.
- Level congratulations additionally require a **stable GUID** across the two scans, plus
  numeric levels above zero on both sides and a strictly higher new level.
- Role alerts and the ready-check tally are private. An absent `READY_CHECK_CONFIRM` is
  **not** proof of a refusal and must be reported as unconfirmed, in the message text too.
- Ready checks and target marks require `A:CanManageGroup()` (leader, or raid assistant in
  a raid), an out-of-combat check, and a feature-detected API behind `pcall`.

### Addon-message rules

The quest protocol is the bundle's only inbound untrusted-data path. All of this is
invariant:

- Gated by `db.questSync`, `questCommsReady` and `activeGroup` on both send and receive.
- **Outbound**: active quest IDs only. No titles, no objective progress, no completion
  history volunteered. A `R` reply covers **only the IDs the asking peer disclosed**.
  Paced one packet per 1.15s through `addonOutbox`, capped at 60 queued and 12 chunks;
  refuse and report rather than truncating.
- **Never resend an unchanged log.** `QUEST_LOG_UPDATE` fires on kill counts, so
  `BroadcastQuests` compares the sorted ID signature and skips within 240 seconds.
- **Inbound validation, in order**: prefix match, string type, grouped, sender is not
  self, **sender is in the current roster**, channel in
  `PARTY`/`RAID`/`INSTANCE_CHAT`/`WHISPER`, header pattern matches, protocol equals `"1"`,
  every numeric field integral and in range, `part <= total`, CSV parses as digits and
  single commas only, reassembly `total` matches.
- **Epoch rules**: drop a `Q` older than the stored peer epoch; accept an `R` only when it
  equals the local `questEpoch`. This is what prevents a stale reply from producing a
  false "this player is missing the quest".
- Nothing from the wire is executed, concatenated into a pattern, used as a format string,
  or acted on automatically. Quest **titles** shown in the UI come from local
  `C_QuestLog` lookups, and peer **names** from the local roster scan — never from the
  packet body.

## Private vs public

Alerts and notifications are **private** in both applications. GuildComms' `A:AddAlert`
prints to the local chat frame, pushes onto `A.alerts` (capped at 30) and emits nothing to
guild chat or a whisper. GroupComms' `A:Notify` does the same against `A.notifications`.
Whispering requires the user to click, and it only opens the chat edit box via
`ChatFrame_OpenChat`; it does not send.

## When adding an automatic message

State in the commit description which **channel** it uses, which **cooldown key** and
window, and why that window is right. If it posts without a click, say why a staged
default was not appropriate.
