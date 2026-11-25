# Quest planner batch 2 (stops on the way): build notes

Kept from the build ledger when its workspace was removed.

## Check in the game before release
- The mount vendor NPC ids in ns.PLANNER_MOUNT_VENDORS (from memory; the Skyborne races have none yet).
- The supply item ids in ns.PLANNER_SUPPLIES (arrows, bullets, water, food by level).
- Riding: 40, 100 gold, mount 20 gold; that riding counts as known after training, by the riding spell or once mounted; the mount vendor stop still shows after training.
- Whether GetProfessions lists riding at all on Forever, and the profession caps (75/150/225/300 at levels 10/20/35).
- That closing a trainer, merchant or mailbox window ticks the right step, and only when it is the current one.
- That a riding trainer is not counted as your class trainer.
- Talent points: C_ClassTalents/C_Traits report classic talent points the way the panel line expects.
- Exploring: real unexplored spots are found, map edges are not offered, and spots you reach stop coming back.
- Gathering: Mining and Herb Gathering casts are recorded with the node's name (UNIT_SPELLCAST_SENT's arguments).
- A vendor or mailbox seen on one faction never shows for the other.

## Rulings made during the build
- Ruling: held hand-ins (T3) are a post-pass after ns.PlannerAddStops: a crossing turnin moves to just before a later `train` step under the same 300 s / no-extra-trip rules — the train step only exists after the stops pass — costs: none.
- Ruling: T6 "legs" = the straight line between successive placed steps in the planned guide — the route keeps no run-leg steps — costs: paths that bend around obstacles are approximated.
- Ruling: subagents on sonnet; opus tried for the mechanism task (T2) and the final review, falling back to sonnet if it is still over its limit.
- Ruling: the stop registry is renamed ns.PlannerRegisterStop(def) — ns.PlannerStop clashes with the runner's ns:PlannerStop(); Tasks 3-6 use the new name — costs: none.
- Ruling: stops without a key get stopKey "id:" — Tasks 4/6 must give vendor and mail stops a key that changes per visit (a per-character counter bumped when that stop's window closes while it is current) — costs: none.

## Minor findings deferred
- Task 1: minor (deferred): an empty flag scan run before Questie's flags exist stays cached until reset; mount vendor ids from memory.
- Task 2: minor (deferred): TRAINER_SHOW reads places outside the coroutine (cheap, cached); detour not shown under Show why; a plan with no quests gets no stops.
- Task 3: minor (deferred): any `do` between crossing hand-in and train disables holding (conservative); summary.seconds not adjusted for held hand-ins; stray `unspent = 1 + 0` in test.
- Task 4: minor (deferred): disjoint-places safety branch untested; enum is Crossbow (Forever spelling).
- Task 5: minor (deferred): any mount seen marks riding known; skill line 633 guess; ridingTrainer flag not cleared on close.
- Task 6: minor (deferred): nodes have no respawn memory; mail "gone" only seen at plan time (10-min fallback); legs over ~8000 yd sampled for their first 8000 yd.
