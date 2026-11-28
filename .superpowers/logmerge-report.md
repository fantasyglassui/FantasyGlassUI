# 13.0.1 logmerge: quests Questie doesn't know, ready hand-ins, the zone count and the font's boxes

Branch planner-logmerge (worktree /home/claude/fgui-logmerge), from quest-planner. BagWindow.lua and ChatMore.lua are
not touched. No version bump. New smoke tests sit in tests/smoke.py between "-- logmerge 13.0.1 tests: begin" and
"-- logmerge 13.0.1 tests: end"; the glyph check is GLYPH_BLOCKS / glyph_errors near the end of tests/smoke.py.

## What the screenshots showed, and why

1. **Log quests ignored.** With Questie loaded, `src.ids()` already added log entries Questie doesn't list, and
   `src.quest()` fell back to `ns.PlannerLogSource().quest()` for them. But the log source's record had no objectives,
   0 xp and its only place in `ends` (from `GetNextWaypoint`). So such a quest got no Do step. With 0 xp, its hub scored
   behind every pick-up. When the game gave no waypoint, it had no anchor and dropped out of the plan without a word.
2. **The lines under the step** ("* Harmony in Balance", "* The Anchors of Zephras") are the panel's preview of the
   next two steps (Guide.lua, `panel.later`). "*" is the badge of a **Do** step (`ns.guideKinds["do"]`). The plan had Do
   steps for quests that were already complete. A hub was laid out as "accept all, do all, hand in all", so
   ready hand-ins waited behind the hub's new accepts ("Accept: Elemental Unrest").
3. **"Zone: 1 of 22 quests"** is the zone goal (PlannerPages.lua `GoalProgress`). It counts Questie's quests filed
   under the goal zone that are doable or done, and "done" means handed in. So 1 is one quest handed in, not quests
   in your log. It was wrong in one way: Questie files none of Forever's own quests under a zone, so they were missing
   from the total. The words also read as "1 quest in this zone".

## Fixes

**Log source records** (PlannerSource.lua, `ns.PlannerLogSource().quest`). Used on their own, and by the Questie
source for every log quest Questie doesn't know:
- Objectives come from `C_QuestLog.GetQuestObjectives`, unfinished ones only. Each has what is left of it as its
  count: a monster is "kill", an item is "item", anything else is "other".
- Place: `GetNextWaypoint`, else the quest's mark from `C_QuestLog.GetQuestsOnMap` on your map and the maps above it,
  up to the zone. While objectives remain, the place goes on the objectives. Once the quest is ready
  (`ReadyForTurnIn` / `IsComplete`), or when it has no objectives, the place is its hand-in (`ends`).
- `xp` comes from `GetQuestLogRewardXP`. When the game won't say, the record gets `xpGuess`: ten kills at its level
  (`ns.PLANNER_LOG_XP_KILLS`). `ns.PlannerCandidates` then sets it to the median of the other candidates within 3
  levels, so an unknown reward never counts as none.
- `fromLog = true` and `complete = ready` are set on the record.

**"Doesn't know"** (Questie `src.ids()`): a log id is added only when it is not in QuestPointers **and** no Questie
quest is matched to it by title. The match is read through `ns.PlannerMappedId` over `ns.root.plannerQuestIds`, so a
pair proven wrong is let go. A pair learned during a plan (`ctx.matchLog`) was already dropped by the existing
`ctx.mappedId` pass in `ns.PlannerCandidates`, so neither path plans one quest twice.

**Route** (PlannerRoute.lua):
- `Anchor`: a log quest with no hand-in known is anchored where the game puts its objectives.
- `Ready(ctx, q)` uses `rec.complete`, or the new `ctx.ready(id)` (`ReadyForTurnIn`/`IsComplete` by the server id).
  A ready quest has no Do step and no quest time. Its hand-ins come first in the hub (`hub.lead`), nearest next.
  A new quest's giver goes before a hand-in only when it is on the way: a detour of at most
  `ns.PLANNER_ON_WAY_YARDS` = 20 yd. The same code serves Questie and log-only quests. Across hubs, a ready hub has
  almost no time, so its rate puts it first.
- **Ruling on log quests with no place** (`Placeless` / `LayPlaceless`):
  - Still to do: a Do step with no place, then a Turn in step with no place, **after every step that has a place**.
    The route can't lead there, so it never pulls the route off its way. The game's own quest markers and the
    panel's progress line (the log's count under a Do step) guide the player.
  - Ready to hand in: a Turn in step with no place **at the start of the zone's steps**, after any travel into the
    zone. With no zone at all, it goes at the start of the plan.
  - Both steps say "(no place known: follow the game's quest marker)" when "Show why" is on. Their experience and time
    are added to the summary. When they are the only thing to plan, the plan is those steps, not empty.

**Zone goal** (PlannerPages.lua): with Questie, the total also counts log quests Questie doesn't know whose place
(hand-in or objective) is in the goal zone. The line now reads "Zone: %d of %d quests handed in". Limit: Forever's own
quests already handed in can't be counted as done, because nothing says which zone they were in. The total only gains
the ones still in your log.

**Font** (part 2):
- "→" is replaced by the word "to" in:
  - "Planned: %s, level %s to %s" (Guide.lua);
  - "Level %s to %s" (PlannerPages.lua).
- Two Core.lua comments now say "gives", and Guide.lua's comment about the check mark is reworded.
- Locales.lua:
  - the old keys are removed in all 8 tables ("Planned: …→…", "Level …→…" and the old "Zone: %d of %d quests");
  - the new keys come from specs/plans/phrases/logmerge-1301.json through add_tr.py;
  - four Korean values whose keys didn't change were edited in place: "Levels %d to %d" → "레벨 %d~%d", the two
    "Mail rule" lines, and "Sending your %s to %s".
- Survey of non-ASCII in Lua: no "•" and no "★" anywhere. "✓" was only in a comment, since 13.0 uses a texture. What
  is shown besides that is Latin-1 or Windows-1252 punctuation: › · × … — – “ ” „ ‘ ’. The task says the default
  fonts cover these, so they are kept. Cyrillic, Korean and Chinese appear only as language names and in their own
  translations.
- Blocklist test (smoke.py `GLYPH_BLOCKS`): every add-on Lua file, translations and comments included, may not hold
  any of:
  - • U+2022;
  - the arrows U+2190–21FF;
  - math and technical symbols U+2200–23FF;
  - box, block and geometric shapes U+2500–25FF (▯ ■ ● ▶);
  - symbols and dingbats U+2600–27BF (★ ✓ ✗ ♥);
  - U+2900–2BFF;
  - U+FFFD;
  - emoji, U+1F000 and above.

  Any hit is added to the smoke run's "errors:" line. On the unchanged branch it lists 41 hits.

New words, in all 9 languages (German uses "du"): "Planned: %s, level %s to %s", "Level %s to %s",
"Zone: %d of %d quests handed in", "(no place known: follow the game's quest marker)".

## Tests (each seen failing first)

Against the unchanged Lua, a filtered run of only these tests failed as follows:
1. "13.0.1 logmerge: a quest in your log that Questie does not know is planned beside Questie's". It failed with "its
   objective, from the log: a kill, 8 to go". The zone-goal part, added later, failed with "0 of 2" against the old
   PlannerPages.lua.
   - The test checks: both planned; Do then Turn in for the log quest, at the game's waypoint (50, 45); its Do before
     "Accept: Agitators" 240 yd away; again with the reward unknown; and the zone goal counting 3.
2. "…a log quest matched to a Questie quest by its title is planned once". It failed with "(learned before) the server
   id of a matched quest is not a quest of its own".
   - The test checks a pair known before the plan and one learned in the plan: no step under the log's id, and one Do
     step for "Agitator".
   - The route-level part of the "learned in this plan" pass was already guarded by `ctx.mappedId`. The source-level
     check is what failed.
3. "…a log quest with no place still appears, after the steps that have one". It failed with "the quest with no place
   is a Do step".
   - The test also checks that a quest placed by `GetQuestsOnMap` is planned there, and that the placeless quest alone
     still makes a plan.
4. "…quests ready to hand in are handed in before a new accept as near". This is the second screenshot: hand-ins 35 yd
   and 57 yd away, a giver 33 yd away. It failed with "handed in before the new accept".
   - It also covers a ready quest with no place (a Turn in step with no place, before the accept) and a Questie quest
     that is ready (no Do step, no accept, the hand-in first).
5. Glyph check: 41 hits on the unchanged files, 0 now.

Changed expectations in old tests: "Level 25 → 26" became "Level 25 to 26", and the title's format string follows the new key.

## Checks (run on the final tree)
- `luacheck .`: 0 warnings, 0 errors in 148 files.
- Full smoke, run twice (/tmp/claude-0/-home-claude/1be75df0-59f1-501a-beb6-ad94e5ad4172/scratchpad/logmerge/run1.txt
  and run2.txt): `errors: no errors`, in both the readable and the SECRET pass, both times.
- forever_audit: "Everything the add-on uses is in Forever." secretaudit: "0 lines compared a hidden value". lockaudit:
  exit 0.
- `pytest tests -q -k "seams or folder or recorders or toc"`: 7 passed.
- Note: secretaudit and lockaudit ended up running at the same time, because both were moved to the background on a
  machine shared with two other worktrees' smoke runs. Each passed on its own output. The two smoke runs ran on
  their own.

## What to check in game (WoW: Forever, Questie loaded, Zephras Isle)
1. With "Harmony in Balance" and "Infestation Investigation" in the log and not done, Plan again.
   - Expect "Do: Harmony in Balance" with "Juvenile Vuldren slain: 0/8" under it, placed where the game's objective
     area is.
   - It should come before "Accept: Agitators" 241 yd away.
   - If the game gives such a quest no waypoint and no map mark, it shows at the end of the route with
     "(no place known: follow the game's quest marker)".
2. Finish both quests. The next plan should start with "Turn in: Harmony in Balance" and "Turn in: Infestation
   Investigation", before "Accept: Elemental Unrest", unless that giver stands on the way. No "* Harmony in Balance"
   Do line should remain in the preview.
3. Check that the Turn in step's arrow points at the right NPC. It uses `GetNextWaypoint`, then `GetQuestsOnMap`. If
   Forever gives the objective area instead of the hand-in NPC for a complete quest, say so: the hand-in place would
   need another API.
4. The title reads "Planned: Zephras Isle, level 1 to 8.5" with no box. The planner window's summary reads
   "Level x to y". Check this in a Korean or Chinese client too, if you can.
5. With a zone goal on Zephras Isle, the line reads "Zone: N of M quests handed in", and M includes the Forever quests
   in your log.
6. "(+N xp)" on a log quest's accept isn't shown, since you don't accept it. Its experience counts in the title's
   level forecast. Check that the forecast is sensible.
