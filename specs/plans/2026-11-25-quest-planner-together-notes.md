# Quest planner batch 5 (with others and outside the game): build notes

Kept from the build ledger when its workspace was removed. Built as one seams task (Task 1) and three groups in
parallel worktrees (A find a group, B duo, C plan code and the hidden plan page), merged into `quest-planner`
with `--no-ff` (A, B, C) with no git conflict, then checked and fixed together (Task 7).

## Check in the game before release (two accounts where it says so)
- The prefix: `C_ChatInfo.RegisterAddonMessagePrefix("FGUIPlan")` succeeds at PLAYER_LOGIN with the guide unlocked,
  and on unlock mid-session; nothing is registered while locked.
- WHISPER add-on messages (two accounts): they reach a friend on the same realm; what a cross-realm friend gets
  (the duo whispers `d.to`, the name with the realm when the game gave one) and what a cross-faction friend gets
  (expected: nothing, and the leader's "No answer from %s (offline, or no Fantasy Glass UI)" after 30 s).
- The real throttle on Forever: how many messages a second go before `AddonMessageThrottle` / `ChannelThrottle`,
  and the actual `Enum.SendAddonMessageResult` values (the code falls back to Success 0, AddonMessageThrottle 3,
  ChannelThrottle 8, AddOnMessageLockdown 11, TargetOffline 12 when the enum is missing); `TargetOffline` for a friend
  who logs out mid-duo.
- Messaging lockdown (`C_ChatInfo.InChatMessagingLockdown`) inside an instance and after leaving it: the queue holds,
  the panel says "Planning together is paused inside an instance.", the 300 s silence is not counted, and the rest
  goes out in order after.
- The ask page on the friend's side (`PlanDuoAsk`): "Leo asks to plan your route together.", "Plan together" / "No
  thanks", Tab and Enter on it, and that it closes after 30 s (the ruling below).
- Both panels' progress lines during a real hand-in and a real flight: "%s: on this step", "%s: %d steps behind",
  "%s: done", "Wait for %s here" on the turnin/fly step, the title's "with %s".
- Find a group: `ChatFrameUtil.OpenChat` with a `/4 ` line sends to channel 4 when you press Enter (and with no
  prefix, to the chat box's current channel); `GetChannelList` on Forever (expected: number, name, disabled triples;
  check the real shape) for the Guide tab's "Find a group in: %s" cycle; `GetChannelName(name)` for a joined and a not-joined
  channel.
- The copy box (`ns:ShowCopyBox`) with a long plan code (60 steps): it holds the whole code and Ctrl+C copies it all.
- The plan page on a phone with a real code: build with `python3 site-src/build_site.py --out <scratch folder> --plan`
  into a scratch folder, never `docs`, open `<scratch>/plan/index.html#c=<code>`; the zone panels, the dashed legs,
  the checklist's ticks kept across a reload, "Clear the ticks", the language picker.

## Rulings made during the build
- Ruling (plan): seams first; Task 1 added the `"candidate"` and `"replan"` hooks, the three files, the three Guide
  tab sections and the fences, so no group edited Planner.lua, PlannerRoute.lua or Guide.lua.
- Ruling (Task 1 review): `ns:PlannerReplan` returns `false, "refused"` when a `"replan"` hook refuses, plain `false`
  when you are not following; "Plan from here" on the map starts a plan only on plain `false`, so the duo friend's
  map pick no longer ends the duo.
- Ruling (Task 1 review amendments): the friend's `"start"` ends the duo with "no replan" and lets the solo start go
  on (no nested start); ending the duo because a written guide is followed replans nothing on either side.
- Ruling (#31): find a group sends nothing; in combat the line still goes into the chat box (A review); the zone is
  cut to 60 bytes and the `/n ` prefix counts in the 200 bytes; without a chat box the line is printed as "Copy this
  line into your chat: %s".
- Ruling (B review): the friend's ask page closes after 30 s, not 60 s (it matches the leader's 30 s wait), and an
  END from the asking leader closes it at once; the leader waits 30 s for the state after the YES.
- Ruling (B review): a typed name always wins (`/fgui guide duo <name>`); the target, then your only party member,
  only when no name is given.
- Ruling (B review): the friend's saved plan summary keeps `duo = true` only; the partner's name is never saved.
- Ruling (B): a shared plan is at most its first 80 steps (AT counts out of `min(#steps, 80)`); a plan text over 60
  pieces ends the duo with "This plan is too long to share: following it together needs a shorter plan."
- Ruling (B): the guide switched off ends the duo with "Planning together ended."; "You follow another guide now"
  only for a real switch.
- Ruling (C review): `SUIPn!` with n > 1 reads as `version` on both readers, `SUIP0!` and any other text as `kind`;
  the two readers refuse the same inputs (lists keyed exactly 1..n, `lv` two numbers, typed fields).
- Ruling (C review): `tests/sitecheck.py`'s English-phrase scan skips "Time", "Levels" and "Language", which the
  public site uses on its own.
- Ruling (C): `|n` in a step text becomes a space in the plan code.

## Merge conflicts outside a region
- None. All three merges auto-merged; `.luacheckrc` was regenerated after each with no change. quest-planner had moved
  on from the seams' base (batch 4's final review fixes, 268508b, and its notes); those touched Planner.lua,
  PlannerMap.lua and smoke.py too and merged cleanly, but one interaction needed a fix (the candidate hooks, below).

## Fixed during the merge
- Pace: `paceTimed` and `paceStyled` are frozen into the plan's context when a run starts (`ctx.paceTimed`,
  `ctx.paceStyled`, set by the "pace" context hook); `RankPace` reads the frozen values (the live flags only for a
  context that never ran the hook). A time limit cleared or a slider moved mid-run changes the next plan, never the
  one running. Test in "13.5 together: batch 4 leftovers" (both directions).
- Plan from here: a seams test for the map mark's match: a mark within 0.051 of a hub (0-100 coordinates, both axes)
  picks that hub (`first = 3`), one 0.06 away on either axis does not (the yards fallback switched off for the test).
- Candidate hooks: the seams' `"candidate"` hook read the live hook list, while batch 4's final review made every hook
  inside a plan use the copies the context took. `"candidate"` is now in `ns.PLANNER_HOOK_POINTS` and `Keep` asks
  `ns.PlannerHooksFor(ctx, "candidate")`, so the duo's hook added or removed mid-run changes the next plan only. Tested.
- Duo: `d.stateAgain` is cleared when a new `duoState` job starts, so a "once more" left by a state job that died
  (an error) or was stopped no longer sends an extra state with the next job. Test in "13.5 together B: review fixes".
- New test "13.5 together: together": Leo's duo plan whose first step is an elite quest; on Mira's side (friend, Solo)
  the real `ns.PlannerFindGroupStep` gives the step, the panel says "Group quest: Hogger", and "Find a group" puts
  "LFG Hogger, Elwynn Forest" in the chat box; the received plan's code reads back with the same 3 steps; no
  `SendChatMessage` at all, and every add-on message is a "FGUIPlan" WHISPER to Leo.
- Tests: the combat audit (`tests/lockaudit.py`) ran out of memory after the merge (killed at about 5.4 GB; 2.4 GB
  before batch 5). The duo tests' frame loops ran 300-400 frames of 0.02 s over every OnUpdate handler; the time
  that passed made the list restyler (Skin.lua) walk its lists again and again under the audit's mocks. The batch 5
  frame loops now run 30 slices with no time passing (the planner jobs need slices, not time); the tests check the
  same things, and the audit finishes with no protected call in combat.
- Translations: the three groups' phrase files applied in every language (9 + 33 + 3 phrases); `missing_tr.py` lists
  only internal values beyond what was there before ("replan", "elite").

## Minor findings deferred
- Task 1 review: the seams test checks `page.contentHeight >= 896`, not "unchanged" (the stub-body check covers it);
  13.4's literal section-order check became a prefix check.
- B re-review: the friend's 30 s ask page counts from receipt, the leader's 30 s from the ASK leaving the queue; the
  page can outlive the leader's wait by the delivery delay (the END and `Accept`'s age check cover it).
- A re-review: a title cut to nothing would read "LFG , Zone" (cannot happen with the 60-byte zone cap).
- B (Task 3): while Questie is still loading the friend reports `questie 0`, so the leader plans only the shared
  logged quests until the next state.
- B (Task 4): a partner's step past yours reads "%s: done" even when they are not at the end (per the ruling).
- B (Task 3): the hidden-text case of the duo test calls `ns.PlannerDuoEvent` directly (the harness's `fireEvent`
  hands every event to every frame, and Extras.lua's vignette handler would compare the hidden text).
