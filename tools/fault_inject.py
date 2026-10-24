"""Mutation check: break one real guard at a time and confirm a harness notices.

    python tools/fault_inject.py

A passing test proves nothing on its own -- a harness can assert against the wrong key,
or exercise a path where the guard is unreachable, and stay green while the behaviour it
claims to protect is gone. Each entry below reverts one specific guard in the shipped
source, runs the single harness that should fail, and restores the file.

This is a developer tool and is deliberately NOT part of `tools/run_tests.py` or CI: it
edits tracked source files in place. It restores them in a `finally`, but an interrupted
run can still leave a fault applied, so check `git status` if it is killed mid-way.

Exit status is 0 only if every injected fault was caught. A MISSED line means the
harness needs a better assertion, not that the addon is broken. Four of these twenty
were initially missed and the assertions were strengthened until they bit.
"""
import pathlib
import subprocess

LUA = r"C:\Users\mreillyorg\tools\lua-5.1.5\lua5.1.exe"

FAULTS = [
    # (package, source file, harness, label, find, replace)
    ("ForeverGuildComms", "Core.lua", "tests/roster.lua",
     "let IsSelf strip a name prefix, so a guildmate sharing a first name is self",
     'local withoutRealm = candidate:match("^(.-)%-[^%-]+$")',
     'local withoutRealm = candidate:sub(1, #(self.playerKey or ""))'),

    ("ForeverGuildComms", "Roster.lua", "tests/roster.lua",
     "drop the suspicious-roster-read guard",
     "if count == 0 or (self.guildCount > 10 and count < self.guildCount * 0.7) then return end",
     "if false then return end"),

    ("ForeverGuildComms", "UI.lua", "tests/alertsui.lua",
     "leave the whisper target on a hidden alert row",
     "            row.sender = nil\n            row:Hide()",
     "            row:Hide()"),

    ("ForeverGuildComms", "UI.lua", "tests/alertsui.lua",
     "stop clamping the alert page, so Next walks off the end",
     "self.alertPage = math.min(self.alertPage, pages)",
     "self.alertPage = self.alertPage"),

    ("ForeverGroupComms", "Core.lua", "tests/safety.lua",
     "remove the 2-second floor between group messages",
     "if self.lastChat > 0 and now-self.lastChat < 2 then",
     "if false then"),

    ("ForeverGroupComms", "Core.lua", "tests/safety.lua",
     "stop rejecting a suggestion staged for a previous group",
     "if serial ~= nil and serial ~= self.groupSerial then",
     "if false then"),

    ("ForeverGroupComms", "Core.lua", "tests/safety.lua",
     "let a plain member start ready checks and mark targets",
     "function A:CanManageGroup()\n    if not self.activeGroup then return false end",
     "function A:CanManageGroup()\n    if true then return true end\n    if not self.activeGroup then return false end"),

    ("ForeverGroupComms", "Quests.lua", "tests/protocol.lua",
     "accept any payload characters, not just digits and commas",
     'if csv:find("[^%d,]") or csv:find("^,") or csv:find(",$") or csv:find(",,") then return nil end',
     "if false then return nil end"),

    ("ForeverGroupComms", "Quests.lua", "tests/protocol.lua",
     "trust a completion reply quoting any epoch",
     "        if epoch ~= self.questEpoch then return end",
     "        if false then return end"),

    ("ForeverGroupComms", "Quests.lua", "tests/protocol.lua",
     "accept addon messages from players outside the group roster",
     'if key == "" or key == self.playerKey or not self.roster[key] then return end',
     'if key == "" then return end'),

    ("ForeverGroupComms", "Quests.lua", "tests/outbox.lua",
     "remove the 60-entry outbox cap",
     "if #self.addonOutbox >= 60 then return end",
     "if false then return end"),

    ("ForeverGroupComms", "Quests.lua", "tests/outbox.lua",
     "ignore the outbox cancellation token",
     "if token ~= (self.outboxToken or 0) then return end",
     "if false then return end"),

    ("ForeverGroupComms", "Quests.lua", "tests/outbox.lua",
     "send a partial log instead of refusing past 12 chunks",
     "if #chunks > 12 then return nil end",
     "if false then return nil end"),

    ("ForeverGroupComms", "Quests.lua", "tests/outbox.lua",
     "ignore the questSync opt-out when queueing",
     "if not self.questCommsReady or not self.activeGroup or not self.db.questSync then return end",
     "if not self.questCommsReady or not self.activeGroup then return end"),

    ("ForeverGroupComms", "TitanMenu.lua", "tests/titanmenu.lua",
     "stop gating target marking on group rank",
     'Action(marks, "Mark target: skull", function() A:Quick("skullMark") end, status.leader)',
     'Action(marks, "Mark target: skull", function() A:Quick("skullMark") end)'),

    ("ForeverGroupComms", "UI.lua", "tests/ui.lua",
     "leave a stale quest row bound under the Share button on a short page",
     "            widgets.share:SetShown(false)",
     "            widgets.share:SetShown(true)"),

    ("ForeverGroupComms", "Options.lua", "tests/ui.lua",
     "drop the canvas OnRefresh so the panel shows stale values",
     "    function f.OnRefresh()",
     "    function f.OnRefreshDisabled()"),

    ("ForeverCommsVoice", "Core.lua", "tests/parity.lua",
     "drift a guild default away from the English catalog",
     'login="Welcome back, {name}!"',
     'login="Welcome back, {name}!!"'),

    ("ForeverCommsVoice", "Options.lua", "tests/options.lua",
     "re-break the ADDON_LOADED gate with a bare, nil ADDON",
     "if name == V.name then",
     "if name == ADDON then"),

    ("ForeverCommsVoice", "Queue.lua", "tests/options.lua",
     "stop validating the auto-skip seconds the options field writes",
     'elseif key == "autoSkipSeconds" then value = integer(value, 0, 3600, q[key])',
     'elseif key == "autoSkipSeconds" then value = tonumber(value) or value'),

    # item 38: the backlog caps
    ("ForeverGuildComms", "Core.lua", "tests/verify.lua",
     "remove the 30-entry approval backlog cap",
     "if #self.pendingApprovals >= 30 then table.remove(self.pendingApprovals, 1) end",
     ""),

    ("ForeverGuildComms", "Core.lua", "tests/verify.lua",
     "drop the NEWEST approval instead of the oldest when the backlog is full",
     "if #self.pendingApprovals >= 30 then table.remove(self.pendingApprovals, 1) end",
     "if #self.pendingApprovals >= 30 then table.remove(self.pendingApprovals) end"),

    ("ForeverCommsVoice", "Queue.lua", "tests/queue.lua",
     "remove the 100-entry shared queue cap",
     "if #self.reviewQueue >= 100 then table.remove(self.reviewQueue, 1) end",
     ""),

    ("ForeverCommsVoice", "Queue.lua", "tests/queue.lua",
     "drop the newest queue entry instead of the oldest",
     "if #self.reviewQueue >= 100 then table.remove(self.reviewQueue, 1) end",
     "if #self.reviewQueue >= 100 then table.remove(self.reviewQueue) end"),

    # item 38: the UTF-8 byte clamp, one fault per implementation
    ("ForeverCommsVoice", "Core.lua", "tests/bytelimit.lua",
     "cut the library's clamp mid-character by ignoring continuation bytes",
     "        if not b or b < 128 or b >= 192 then break end",
     "        if true then break end"),

    ("ForeverGuildComms", "Core.lua", "tests/bytelimit.lua",
     "cut GuildComms' ChatLimit mid-character",
     "        if not byte or byte < 128 or byte >= 192 then break end",
     "        if true then break end"),

    ("ForeverGroupComms", "Core.lua", "tests/bytelimit.lua",
     "cut GroupComms' Trim mid-character",
     "        if not b or b < 128 or b >= 192 then break end",
     "        if true then break end"),

    ("ForeverGuildComms", "Core.lua", "tests/bytelimit.lua",
     "let ChatLimit exceed the 250-byte chat limit",
     "    if #text <= 250 then return text end\n    local limit = 250",
     "    if #text <= 250 then return text end\n    local limit = 260"),
]


def main():
    caught, missed, skipped = 0, [], []
    for pkg, source, harness, label, find, replace in FAULTS:
        path = pathlib.Path(pkg) / source
        original = path.read_text(encoding="utf-8")
        if find not in original:
            skipped.append(f"{pkg}/{source}: {label}")
            print(f"SKIP   {harness:<28} anchor not found -- {label}")
            continue
        path.write_text(original.replace(find, replace, 1), encoding="utf-8")
        try:
            result = subprocess.run([LUA, harness], cwd=pkg,
                                    capture_output=True, text=True)
        finally:
            path.write_text(original, encoding="utf-8")
        if result.returncode != 0:
            caught += 1
            print(f"CAUGHT {harness:<28} {label}")
        else:
            missed.append((harness, label))
            print(f"MISSED {harness:<28} {label}")

    print()
    print(f"caught {caught} / {len(FAULTS) - len(skipped)} injected faults")
    if skipped:
        print(f"{len(skipped)} skipped (anchor text changed)")
    if missed:
        print("NOT DETECTED:")
        for harness, label in missed:
            print(f"  {harness}: {label}")
    return 1 if missed or skipped else 0


if __name__ == "__main__":
    raise SystemExit(main())
