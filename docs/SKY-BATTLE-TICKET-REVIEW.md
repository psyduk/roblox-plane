# Sky Battle product and ticket review

Review date: October 10, 2026. The original review covered all 46 Linear project tickets, AND-170 through AND-215, their descriptions, the five project milestones, and the current repository design and validation records. **The owner has approved the revised plan, ticket and milestone updates, missing tickets, and removal of Copycat.** This document records that approved direction and the findings that motivated it; live ticket status remains in Linear. Approval is not an implementation or validation claim. No new gameplay or retention test was performed.

Project: [Sky Battle in Linear](https://linear.app/pitter-app/project/sky-battle-fb7eb9186d60/issues).

**Applied status, October 10:** the approved review is applied in Linear: 45 retained existing tickets revised, seven follow-up tickets created (AND-216 through AND-222), and all milestone, priority and status assignments updated. AND-215 (Copycat) has been deleted; Linear confirmed its 30-day recovery window in Recently deleted. All 52 remaining issues have a roadmap milestone. The verified snapshot is 20 Todo, 31 Backlog and one Done (AND-190, whose completed status was preserved). This completes the ticket and roadmap revision, not gameplay implementation or validation.

The strongest promise is **build a ridiculous flying fighter, see your choices matter, then outsmart the same rival next round**. Preserve automatic combat, short fights, simultaneous hidden picks, visible windups, and cosmetic aircraft. The next milestone should prove that promise with people before expanding the roster and progression systems. The [current design direction](SKYBOUND-CLASH-DESIGN.md#direction-update-sky-battle-october-10-2026) incorporates the approved decisions.

## Approved changes with the largest payoff

### Put a complete rivalry ahead of the full roster

At review time, milestone 1 contained 21 tickets and human duels were in milestone 2. Move AND-195 into the first playable milestone alongside the shared catalog, skin contract, match flow, offers, mirror fix, and minimum balance tooling. Human play need not wait for every new skill or every presentation improvement.

The approved first public test roster is four offences—Meteor, Firework, Machine Gun, Pinball—and five wild cards—Afterburner, Spring Bumper, Fizzy Fuel, Magnet, Second Wind. Everyone has equal access to that same active roster. This keeps the current work useful, gives each offence a recognizable action, and adds movement and comeback choices without making several new hit-canceling defenses mandatory. If Machine Gun proves hard to understand with three armor pips, test a roster revision explicitly rather than automatically adding another skill.

Treat the remaining retained skills as expansion candidates. The original ten-offence/ten-wild-card proposal yielded 450 completed builds with two distinct, unordered wild cards, before accounting for seeds or draft decisions. The approved four-offence/five-wild-card roster yields 40. A small roster still needs real interaction testing, but gets us to a comprehensible human match much sooner. Copycat is removed from the plan rather than deferred to an expansion wave.

Placeholder art is appropriate for mechanical experiments. Every skill in the first player test still needs a distinct tell, activation, hit or miss, and recovery. In a game people watch, readability is part of the mechanic.

### Make the player's decision visible in the result

The missing product feature is a short, factual answer to “what just happened?” Total hits and elapsed time are insufficient for learning an automatic battle game.

Add one event-backed highlight between rounds, such as “Your bumper blocked Meteor's dive,” showing the two relevant cards. Then display the next choice with a plain promise: “Pull them closer after attacking.” Avoid unsupported claims such as “this card would have won” unless a counterfactual was actually evaluated. Show the trigger in the fight as well as describing it afterward.

Ask unfamiliar testers to explain a loss and choose an adjustment without coaching. If they cannot, address combat readability, card descriptions, and decision timing before adding another system. Tap-to-cheer is optional expression; it does not solve missing agency. Do not imply tapping improves the outcome.

### Resolve competitive access before connecting skills to purchases

At review time, AND-196 said there was no Robux path to coins or skill crates while AND-198's starter pack included coins, creating a direct contradiction: Robux would buy coins that bought random skills. Roblox's paid-random-item rules cover indirect purchases. The approved launch starter pack grants a guaranteed skin and trail, without skill-crate currency. Paid random items are not categorically forbidden, but they require odds disclosure and applicable per-player restrictions. [Roblox policy](https://create.roblox.com/docs/production/monetization/paid-random-items)

Paid battle rerolls are excluded and Double Coins is deferred. A broader collection and extra selection opportunities can confer a tactical advantage without changing damage. The policy classification of a multiplier on earned coins is less explicit than the original starter-pack currency path; the product fairness concern is enough reason to defer it.

The approved first public test uses a shared combat roster, with progression through mastery, cosmetics and identity. Combat access is never bought. Earned combat collection is deferred and needs an explicit future decision about draft fairness, owned-pool dilution, trials, predictable unlocks and collection completion. Do not implement locked starters, owned-only offers or skill crates as part of this test.

The original ownership model had a dilution problem: with uniform three-card offers, a particular skill's inclusion probability is 3/N for N eligible skills. Going from three to ten eligible skills lowers that probability from 100% to 30%. The approved model removes ownership from offer eligibility. Use three-card offers from the same active roster, one free reroll and one free Pick Any per player per match across all stages, and exclude the first equipped wild card from the second pick. Pick Any accesses the same eligible shared roster. AND-191's existing disabled no-op reroll behavior remains useful. Starter-count contradictions are superseded by equal access to the active roster.

### Protect a losing player's next experiment

The original proposed 250-coin skill crate took three wins or ten losses at the 100/25 reward split, before quests, levels, and streak bonuses. “A second crate within about five matches” was therefore not a reliable experience for a struggling beginner. Skill crates are now deferred; use a visible cosmetic goal for the first test.

Approved initial tuning experiment: 50 coins for legitimate match completion plus 25 for a win. That puts a 250-coin cosmetic goal within five completed matches even with no wins. Keep an obvious win celebration and optional capped streak recognition, but make trying again productive. These numbers are test hypotheses, not established economy targets.

The first reward is a chosen cosmetic or visible mastery goal, with an immediate opportunity to use or understand it. It does not lock or unlock combat access. If an earned skill collection is considered later, explicitly resolve its endpoint, duplicate level rewards and trials: random offers cannot promise a newly unlocked skill will appear next match.

AND-220 establishes this specification and the fairness contract in milestone 1. Runtime payouts, saving and the first cosmetic/mastery goal are delivered by AND-174 and AND-196 in milestone 2; writing the contract does not imply those systems are implemented.

### Define a decisive, understandable match

AND-173 already specifies no point or new pick on a draw, repeated builds, and a five-round cap. Preserve that explicit bounded behavior. Both players pick an offence before the first fight, a wild card after the first decisive round, and a second distinct wild card only at 1–1 before the decider. Draft progression follows decisive rounds completed across both players, not physical round number or either player's individual score.

Approved initial limits: **35 seconds per round and 240 seconds per whole match**, including picks and transitions, with no more than five physical rounds. At 35 seconds, more armor wins and equal armor draws. At the round-count or whole-match cap, compare completed round wins; equal scores give a match draw. An unfinished fight at the 240-second cutoff earns no point. Resolve symmetry within the current round cap; any overtime experiment must also fit within 35 seconds. Do not add hidden last-hit or random tiebreaks.

AND-171 has a useful proposed Firework-mirror draw target below 10%. Carry an explicit target into AND-202 and every skill ticket; “no worse than today's worst matchup” is too weak when the recorded Firework mirror baseline drew every sampled round. Count draws separately and state whether win rate excludes draws or uses a half-point score. Otherwise a balanced mirror can fail a nominal 45–55% win target just because draws are common.

Prefer readable attack timing and symmetry-breaking inside the approved caps. Randomize server-owned opening conditions while preserving the ability to reproduce a seed. Check both seats and show uncertainty from independent seeds; many angle variants of one seed are not automatically independent evidence. Test completed builds and adverse interactions, not only an offence table or average wildcard lift.

### Make the first session and playing with a friend explicit work

Add a first-session ticket: one obvious PLAY action, a brief animated card preview, a named and clearly labeled bot when needed, unmistakable player identity, one understandable fight, and an immediate next action. A proposed target is first combat within 20 seconds of a usable initial screen, then tune from observation. Keep a shop available without interrupting the first fight with a sales modal.

The reviewed AND-195 excluded friend invites. The approved follow-up adds a separate small friend-challenge ticket: challenge a friend in the server, accept or decline, play, and mutually rematch the same person. Add supported join/invite behavior next. Keep one default queue at low population; ranked modes and additional queues can wait.

Roblox's current discovery guidance puts early bounce and repeat engagement among its strongest signals and includes intentional co-play. This supports testing first-session clarity and rivalry; it does not establish that any particular feature will improve retention. [Roblox discovery guidance](https://create.roblox.com/docs/discovery)

## Approved delivery milestones

| Milestone | Assigned issues | Exit condition |
| --- | --- | --- |
| 1. Understandable rivalry | 21 | Small readable roster, complete draft match, bounded outcomes, bot fallback, two humans, mutual rematch, one factual round highlight, fairness specification, replay instrumentation, basic phone and sound validation. |
| 2. A session people continue | 9 | Friend challenge, first-session flow, completion rewards, one visible mastery/cosmetic goal, reliable saving, published two-device checks, measured next-match starts. |
| 3. Return and identity | 6 | Tune progression from results; small fixed-price cosmetic offer; mastery goals; add skills that create demonstrably different decisions. |
| 4. Proven expansion | 15 | More roster and cosmetics, restrained daily objectives, seasonal content only after voluntary replay and returns. Premium randomness remains a separate future decision. |
| Future options — decision required | 1 | A decision on whether premium cosmetic randomness or another currency adds value; no implementation authorization. |

The first milestone contains AND-170, AND-171, AND-173, AND-182, AND-183, AND-184, AND-187, AND-189, AND-190, AND-191, AND-192, AND-195, AND-202, AND-203, AND-204, AND-211, AND-214, AND-217, AND-219, AND-220 and AND-221. Its 20 unfinished tickets are Todo; completed AND-190 remains Done. The other 31 tickets are Backlog.

The fifth existing Linear milestone is **Future options — decision required**, containing AND-200. This is an organizational decision bucket, not a fifth release milestone or authorization to implement it.

AND-222 gates the first free published test in milestone 2; a shop is not a prerequisite. Receipt checks are marked not applicable while purchases are disabled. Repeat the relevant published-device, persistence and receipt checks before enabling the milestone-3 shop.

Start with 12–20 unfamiliar testers, including phone players and friend pairs, for short observed sessions. This is a qualitative discovery sample, not proof of retention. Record first-fight completion, ability to explain a consequential event, voluntary next-match starts after wins and losses, time between fights, and confusion or departures. Later measure D1/D7 return by cohort and device; do not use these few testers to claim a population retention rate. Roblox also recommends tracking the steps and drop-offs in the first-time loop. [Roblox retention guidance](https://create.roblox.com/docs/production/analytics/retention)

## Approved ticket dispositions

IDs link to the existing tickets. “First” means needed for the small complete test, not a claim that the ticket is currently implemented.

| Ticket | Recommendation |
| --- | --- |
| [AND-170](https://linear.app/pitter-app/issue/AND-170) Random battle seed | **First.** Preserve server authority and reproducibility. Require distinct seeds, not a guarantee that every fresh seed produces a materially different outcome. Keep the mirror workaround until AND-171 fixes it. |
| [AND-171](https://linear.app/pitter-app/issue/AND-171) Firework mirrors | **First.** Favor readable symmetry-breaking within the 35-second round cap; state draw rate, match duration, and seat bias. Any overtime experiment stays inside that cap. Avoid most-recent-hit as an unexplained deciding rule. |
| [AND-172](https://linear.app/pitter-app/issue/AND-172) Near misses | **Later.** Prefer an authoritative near-miss event. Existing knockout slow motion follows an already-finished simulation; copying it during a live fight needs explicit synchronization and catch-up rules. Start with a word and gasp if slowing time obscures actual hits. |
| [AND-173](https://linear.app/pitter-app/issue/AND-173) Match draft | **First.** Clarify pick stages after draws, stale commands and deadlines, and fresh builds on rematch. Add the factual round highlight. Combine reveal/countdown beats to minimize repeated waiting. |
| [AND-174](https://linear.app/pitter-app/issue/AND-174) Rewards | **Revise.** Use one match ID for reward deduplication; remove residual “per round” language. Test completion-heavy rewards, define disconnect/streak behavior, and avoid humiliating loss presentation. |
| [AND-175](https://linear.app/pitter-app/issue/AND-175) Entry transition | **Trim.** Introduce the rival during necessary loading or reveal time. Do not add an obligatory takeoff, VS splash, and full countdown to every replay. |
| [AND-176](https://linear.app/pitter-app/issue/AND-176) Tap to cheer | **Defer.** Keep outcome-independent and visibly expressive. A sustained tapping meter should not imply hidden combat power or cover important tells. |
| [AND-177](https://linear.app/pitter-app/issue/AND-177) Engines and airflow | **Keep, after listening.** Establish a mix hierarchy in which windups and damage remain audible. More continuous layers are not automatically better. |
| [AND-178](https://linear.app/pitter-app/issue/AND-178) Stereo audio | **Later.** Preserve moderate panning and test mono phone speakers; no essential information should depend on headphones. |
| [AND-179](https://linear.app/pitter-app/issue/AND-179) Tension audio | **Keep small.** Match the visible clock, then assess one-armor cues in a full mix before adding heartbeat, ticking, and rumble together. |
| [AND-180](https://linear.app/pitter-app/issue/AND-180) Music | **Keep, after listening.** Avoid an extended mocking loss sting. Maintain the requested playful tone and clear attack cues. |
| [AND-181](https://linear.app/pitter-app/issue/AND-181) UI sounds | **Keep scoped.** Confirmation, selection, cancel, and failure feedback matter; exhaustive hover/press sounds can wait. |
| [AND-182](https://linear.app/pitter-app/issue/AND-182) Language and bot identity | **First, smaller.** Two or three distinct named bots suffice. Preserve a plain “pick skills; your pilot fights automatically” explanation somewhere; removing all automatic-combat wording can create false control expectations. “Rematch” keeps the rival; a new rival is “Next opponent.” |
| [AND-183](https://linear.app/pitter-app/issue/AND-183) Meteor visuals | **First, legibility pass.** Prioritize charge versus commit versus hit/miss on a phone. Keep skin and hitbox readable inside the fireball. |
| [AND-184](https://linear.app/pitter-app/issue/AND-184) Firework visuals | **First, legibility pass.** Distinguish damage from harmless fizzle. Keep visual wobble close to the real path; several decorative burst shapes can wait. |
| [AND-185](https://linear.app/pitter-app/issue/AND-185) Storm wall | **Keep boundary clarity first.** Use current bounds/pressure so Storm Caller works later; clouds and lightning must not hide attacks. |
| [AND-186](https://linear.app/pitter-app/issue/AND-186) Knockout crash | **Keep with pacing cap.** Do not lengthen every between-round transition for wreckage. Reconcile aircraft parts with the shape-independent skin contract; a broom cannot shed a propeller. |
| [AND-187](https://linear.app/pitter-app/issue/AND-187) Skin contract | **First.** Strong foundation. Replace “rival never has the same skin and paint” for human matches with team outlines, markers, and contrasting UI while preserving both players' purchased appearances. |
| [AND-188](https://linear.app/pitter-app/issue/AND-188) Floating armor pips | **Experiment.** Test health comprehension on a phone against existing fighter-bar pips. Do not add a second display solely to satisfy the old audit. |
| [AND-189](https://linear.app/pitter-app/issue/AND-189) Playtest pass | **First.** Retain evidence discipline. Check a real phone, loss-to-replay, sound, and unfamiliar-player comprehension; emulator layout alone is insufficient. The complete published two-player/real-device release gate is AND-222 in milestone 2. |
| [AND-190](https://linear.app/pitter-app/issue/AND-190) Skill catalog | **Preserve Done status.** Keep the completed modular catalog work. Additional interaction ordering and shared-access requirements belong in the new follow-up tickets, not a reopened implementation ticket. |
| [AND-191](https://linear.app/pitter-app/issue/AND-191) Skill offers | **First, revise.** Use the equal-access active roster, three-card offers, one free reroll and one free Pick Any per match across stages. Exclude equipped wild cards and define deadline behavior while browsing Pick Any. Retain disabled no-op rerolls. |
| [AND-192](https://linear.app/pitter-app/issue/AND-192) Machine Gun | **First roster.** Show progress toward a damaging burst and why stray bullets did not remove armor. Its balance criteria now use the canonical AND-202 half-point score, pairing, draw and round-cap targets. |
| [AND-193](https://linear.app/pitter-app/issue/AND-193) Dodge Roll | **Second wave.** First define exactly when a threatening hit is detected and which defense consumes it; the ticket already identifies stacked cancellation as a risk. |
| [AND-194](https://linear.app/pitter-app/issue/AND-194) Decoy | **Second wave.** Distinct fantasy, but a new target-selection system adds scope. Validate projectile/ram differences and clear balloon recognition. |
| [AND-195](https://linear.app/pitter-app/issue/AND-195) Human duels | **Move into first milestone.** Keep bot fallback and private draft data. Add friend challenge separately and test repeated forfeits so instant wins do not become a currency farm. Avoid splitting the initial population into many queues. |
| [AND-196](https://linear.app/pitter-app/issue/AND-196) Skill unlocks | **Rescope to first-test mastery/cosmetic progression.** Shared combat access replaces locked skills and skill crates. Use a chosen cosmetic/mastery first reward and losing-player completion progress. Earned skill collection requires a separate explicit future decision. |
| [AND-197](https://linear.app/pitter-app/issue/AND-197) Dailies and playtime | **Later.** Prefer a small achievable experiment goal over an hour-long timer track. Do not require unavailable rerolls or skills outside the active roster. Automatic watching is legitimate match participation; keyboard inactivity alone must not invalidate it. |
| [AND-198](https://linear.app/pitter-app/issue/AND-198) Robux shop | **Revise and shrink.** Cosmetic-only starter pack, defer Double Coins, and start with fewer recognizable skins. Include concurrent/repeated purchase handling for permanent ownership. Keep first-spawn visibility nonblocking. |
| [AND-199](https://linear.app/pitter-app/issue/AND-199) Season pass | **Keep deferred gate.** Already correctly requires demonstrated replay. Scope tiers and skips as cosmetics/mastery; no purchased combat access. Review currency paths again before any future collection or paid-randomness experiment. |
| [AND-200](https://linear.app/pitter-app/issue/AND-200) Premium currency | **Future options — decision required.** Exclude paid battle rerolls. The ticket already recognizes fairness risk and recommends cosmetics-only. Keep direct-price cosmetics until there is evidence a second currency adds value; this is not a release milestone. |
| [AND-201](https://linear.app/pitter-app/issue/AND-201) Broom skin | **Small prototype after contract.** Useful to expose assumptions, but do not make polished art a first-test prerequisite. Remove obsolete “defence” slot language. |
| [AND-202](https://linear.app/pitter-app/issue/AND-202) Matchup table | **First, minimum useful scope.** Explicit draw/timeout targets, win-rate definition, seed-level uncertainty, both seats, and known dangerous full builds. Balance numbers do not substitute for player comprehension. |
| [AND-203](https://linear.app/pitter-app/issue/AND-203) Beta unlock | **First, align with shared access.** Retain a reversible test overlay for expansion skills; the active first-test roster is available equally in normal play. Test fresh cosmetic/mastery profiles; all-unlocked beta cannot validate a future earned-collection economy. |
| [AND-204](https://linear.app/pitter-app/issue/AND-204) Pinball | **First roster.** Visually distinct from rockets and bursts. Require a readable rebound and meaningful attack attempts across the full arena. Storm synergy can come later. |
| [AND-205](https://linear.app/pitter-app/issue/AND-205) Chomper | **Later.** Keep the explicit edible-projectile contract and cooldown. Test each ranged matchup and the bite alone before polishing a counter-heavy skill. |
| [AND-206](https://linear.app/pitter-app/issue/AND-206) Boomerang | **Later, promising.** Good visible path interaction; preserve one hit per throw and a fair recovery if eaten. |
| [AND-207](https://linear.app/pitter-app/issue/AND-207) Sky Mines | **Next offence, or replace an unclear first-roster skill.** Offers area-control variety. Cap hazards, avoid stalling, and test how automated pilots visibly respond to them. |
| [AND-208](https://linear.app/pitter-app/issue/AND-208) Harpoon | **Later.** Excellent spectacle with high interaction cost. Define interruption and tether behavior across hazards and closing bounds before tuning win rate. |
| [AND-209](https://linear.app/pitter-app/issue/AND-209) Bomber | **Later.** Ensure the automated approach can actually gain height; resolve mirrors without an endless climb. Keep bomb versus blast defense rules explicit. |
| [AND-210](https://linear.app/pitter-app/issue/AND-210) Tesla | **Later.** Test visible ability to leave the ring, especially under Magnet and the storm; avoid unavoidable proximity damage disguised as counterplay. |
| [AND-211](https://linear.app/pitter-app/issue/AND-211) Magnet | **First roster.** A clear movement-changing trick. Keep the initial version to fighter movement; omit optional projectile/mine attraction. It must not pin a plane. |
| [AND-212](https://linear.app/pitter-app/issue/AND-212) Storm Caller | **Later.** Test symmetric arena timing before adding the suggested owner-only wall advantage. Keep the card's promise simple and the pressure tell unmistakable. |
| [AND-213](https://linear.app/pitter-app/issue/AND-213) Cloud Cover | **Later.** Several other cards already deny hits. Define which windups are delayed and ensure the result is visible rather than looking like a broken opponent. |
| [AND-214](https://linear.app/pitter-app/issue/AND-214) Second Wind | **First roster.** A visible comeback moment. One armor does not necessarily mean losing; test mirror triggers, combined speed caps, and readable trajectories. |
| AND-215 — Copycat | **Deleted from Linear and removed from the plan.** Linear confirmed 30-day Recently deleted recovery. The skill is dropped, not deferred. No Copycat implementation was found in `src/`, `tests/` or `scripts/`; this documentation update makes no gameplay changes. |

## Created follow-up tickets

These tickets exist in Linear; creation does not mean their work is implemented or validated. The contract and instrumentation work starts in milestone 1; progression delivery, onboarding, friend challenges and the complete published release gate remain in milestone 2.

| Ticket | Assigned milestone | Scope |
| --- | --- | --- |
| [AND-216](https://linear.app/pitter-app/issue/AND-216) First session to second match | 2. A session people continue | Own spawn, contextual teaching, first fight, reward, and an actual next match start; include the losing path. |
| [AND-217](https://linear.app/pitter-app/issue/AND-217) Round turning point and useful next pick | 1. Understandable rivalry | Show a factual consequential event with the responsible skills; test comprehension without coaching. |
| [AND-218](https://linear.app/pitter-app/issue/AND-218) Challenge a friend and keep the rivalry | 2. A session people continue | Small in-server invitation, acceptance, same-opponent rematch, and safe decline/leave behavior. |
| [AND-219](https://linear.app/pitter-app/issue/AND-219) Combat interaction rules and caps | 1. Understandable rivalry | Define damage categories, target selection, defense precedence, consumed versus bypassed defenses, protection windows and movement/status stacking. Keep the 35-second round, five-round match and 240-second whole-match caps; ensure auto-pilots can realize the described counterplay. |
| [AND-220](https://linear.app/pitter-app/issue/AND-220) Economy and fairness contract | 1. Understandable rivalry | Establish shared combat access, no paid combat choices, chosen cosmetic/mastery first reward, and the 50 completion plus 25 win coin experiment toward a 250-coin cosmetic goal. Actual progression delivery follows in milestone 2. Earned skill collection requires a separate explicit future decision. |
| [AND-221](https://linear.app/pitter-app/issue/AND-221) Actual replay funnel | 1. Understandable rivalry | Instrument first fight and match completion, next match actually started, human/bot status, device, beta ownership mode and outcome. Distinguish voluntary replay from timer/claim behavior. |
| [AND-222](https://linear.app/pitter-app/issue/AND-222) Published multiplayer and real-phone release gate | 2. A session people continue | Gate the initial free published test with real-device controls, readable effects, sound permissions, connection loss and save/rejoin checks. Receipt checks are not applicable while purchases are disabled; repeat the relevant gate before enabling the later shop. Set device/performance targets from actual hardware observations. |

## Specific consistency fixes

- AND-174 mixes a unique result ID “per round” with payout once per match. Match identity must own rewards.
- The reviewed starter counts conflicted across AND-191, AND-190 and the design. The revised plan supersedes locked starters with shared access to the four-offence/five-wild-card active roster. Preserve completed AND-190 work and carry the transition in follow-up tickets.
- AND-187 forbids a rival sharing skin/paint, while AND-195 requires authentic human cosmetics. Distinguish sides without overwriting what either player owns and chose.
- AND-186 assumes recognizable aircraft wreckage while AND-187/201 permit non-aircraft. Wreckage needs a skin-provided definition or a generic fallback.
- AND-197's original reroll quest could be impossible with its starter collection. Even with the shared roster, filter objectives by currently eligible actions; completed automatic battles must count as participation. Daily/playtime systems remain later work.
- AND-199's paid tier skips must remain outside combat access. Revisit paid-randomness policy before any future currency or collection change.
- README still describes manual rival settings, optional angles, and a stable camera. Latest VALIDATION.md records player-only cards, a rolled bot, hidden angles, and a dynamic camera. Update player instructions as part of the next delivery.

The [current design](SKYBOUND-CLASH-DESIGN.md), [battle audit](BATTLE-AUDIT.md), and [validation record](../VALIDATION.md) remain the implementation and decision references. The approved revision prioritizes a smaller proof of the game and clearer acceptance criteria; it does not mark any unplayed feature as successful.
