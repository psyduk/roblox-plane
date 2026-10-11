# Sky Battle combat contract v1

Version: `sky-battle-combat-v1`. Active roster: `sky-battle-public-v1`.
This table governs the first test. Expansion skills and Milestones 3/4 are not implemented.
The server runs the pure simulation and adjudicates damage; clients present its snapshots and events.

## Combat-feel revision (October 11, 2026)

This section supersedes the rules below wherever they differ. It exists because the earlier rules made a round a timer race: both planes slowed to a hover to attack, 81% of attacks landed, a hit cancelled the rival's charge, and the first hit decided 78% of rounds.

- **Planes keep flying.** A charging plane carries its charge round the standoff ring (46 units, per-attack override allowed) at cruising speed and turns its nose in only for the last 0.35 seconds. Attacks that steer their own charge (Meteor, Sniper, UFO Beam, and Pinball's final aim) are committed for all of it.
- **Rolls.** A plane that is free (approaching, recovering, or still circling with a charge) rolls out of the way of a rival shot, armed nose or armed drone that will reach it within 0.34 seconds, flees a rival's black hole that opens beside it, and breaks away from a beam about to close. A roll lasts 0.45 seconds at 48 units/s and cannot be repeated for 2.4 seconds (60% of that on the last armor; Afterburner 55%, Second Wind 50%). A plane that has turned in to aim, is attacking, held or thrown cannot roll. A roll is a movement, not immunity: a shot that still reaches the plane hits.
- **Turns.** A plane does not start charging while its rival is charging, for up to 1.2 seconds past its own approach time.
- **A hit no longer cancels anything.** Only a ramming plane whose dive connected banks away. A plane hit while free banks away and rallies: its bank and next approach are halved. A plane hit while charging keeps its charge and loses 0.3 seconds. A plane hit while attacking carries on. A blocked hit (Spring Bumper) gives the bumper's recoil and no rally.
- **The round speeds up.** Every attack begun multiplies later approach and bank times by 0.95, down to 0.6. Base approach is 1.7 seconds and bank 1.0, with a seeded spread of ±0.6 seconds.
- **Last armor.** The hit that leaves a plane on one armor throws it 1.4 times as hard.
- **Retuned skills.** Meteor dives at 75; Machine Gun's stream tracks a rolling rival at 2.5 rad/s; Pinball's ball is faster and larger; Sniper's bullet is thinner and its reload longer; Boomerang's blade is smaller and returns slower; Black Hole arms in 0.8 seconds with a weaker pull; UFO Beam reaches 28 and chases at 48. Giant adds two armor. Mothership launches far less often. Fizzy clouds last 1.4 seconds. Magnet pulls for 0.6 seconds. Hot Potato's fuse is 8 seconds and Swap happens at 6. Exact values live in `BattleSkills.luau`.

Measured with `scripts/qa/combat_feel.py 24 --pairs` (1,536 bare-attack rounds, every ordered pairing):

| Measure | Before | After |
|---|---:|---:|
| Attacks per round | 4.7 | 9.2 |
| Attacks that land | 81% | 43% |
| Shot travel before a hit (median) | 0.37s | 0.52s |
| Charges that never fire | 29% | 6% |
| First hitter wins the round | 78% | 70% |
| Winner was behind at some point | 26% | 34% |
| Longest quiet gap (median) | 5.7s | 2.5s |
| Round length (median) | 17.0s | 14.5s |
| Rounds ending by knockout | 96% | 89% |
| Field score, weakest to strongest attack | 44–55% (four attacks) | 43–53% (eight attacks) |

Open after this revision: several pairings are lopsided (UFO Beam over Black Hole near 87% and Pinball over Firework near 71% are the worst); Squadron, Swap, Thief, Afterburner, Bug and Second Wind give their owner little (50–56% against a bare plane, where most cards give 61–69%); shot travel and round length are just short of their 0.6-second and 15-second targets. These are simulation results, not a playtest.

## Shared adjudication

- Three armor. Each accepted damaging event removes exactly one pip. No cosmetic, ownership, spending or mastery stat changes combat access or strength.
- Fixed 60 Hz ticks, maximum catch-up 0.25 seconds per call, recorded integer seed. Both pilots plan from the same pre-tick positions. Projectiles and rams use relative swept-circle collision; body collisions only push apart.
- Each tick: decrement timers; plan both pilots; apply bounded symmetric Magnet forces; move; reflect Pinball rail commitments; resolve armed noses in seat order, then projectiles in creation order, then wakes in creation order; apply recovery; adjudicate knockout/cap. Damage never checks whether the *attacker* has already lost its last pip that tick. Thus both committed same-tick attacks resolve and a double knockout draws, including ram versus projectile. No last-hit/random-winner rule.
- A target can lose at most one pip per tick. Existing impact protection has precedence over Spring Bumper. Protected contacts disappear without consuming a bumper. Otherwise bumper cancels the event and grants protection plus 0.7s extra defender bank/recovery; otherwise damage grants protection. Protection lasts 0.85 seconds. Nothing bypasses it. Source objects contacting protected targets are consumed, never parked for delayed damage.
- Accepted hits and blocks bank both pilots into recovery; stray Machine Gun contacts do not. Second Wind activates after the one-pip loss reaches one armor and before recovery duration is chosen; movement changes next tick. It does not cancel a committed opposing attack.
- Speed modifiers multiply base thrust, then add knockback and Magnet. Final velocity magnitude is capped at 88 units/s, turn rate at 9.6 rad/s. Second Wind uses 12% extra speed, 20% tighter turns and 16% shorter recovery. Afterburner recovery thrust is 44, so paired thrust is 49.28 before external forces. No duplicate cards; pick order does not affect hooks.
- Arena pressure starts at 18s and contracts continuously until 35s. Rails clamp movement and do no damage. Automatic pilots look ahead and turn inward near rails; committed attacks cannot home. Magnet never moves rails or hazards.
- Every recovery updates a per-pilot seeded cadence: the next approach varies by up to 1.2 seconds around its base. Meteor mirrors additionally stagger one opening approach by 0.25–0.6 seconds. Seed parity exchanges cadence assignment between seats. This changes attack opportunities, not accuracy, damage, scoring or the winner rule.

## Interaction table

| Skill | Target / category | Tell and commitment | Damage / defense | Lifetime and stacking | Automatic counterplay |
|---|---|---|---|---|---|
| Meteor | Rival; frontal ram | 1s charge, including continuous retreat; fixed heading on release; 1.05s strike | One pip on frontal swept contact; rear/body contact does no damage; protection then bumper | One accepted hit per dive; hit, miss or edge banks away | Rival can cross the locked line, attack the vulnerable charge, or pass behind the nose |
| Firework | Rival only; straight projectile | 1s lock tell; one rocket, no homing; 0.5s attack | One pip on swept rocket contact; protection then bumper | 2.4s maximum life at 60 units/s; consumed by contact or arena exit | Automatic turns and altitude changes can take the rival outside the fired line |
| Machine Gun | Rival only; six straight tracers / one burst | 0.65s spin-up; six rounds over 0.6s on the committed heading; 0.65s attack then reload | First two connections spark/push slightly; third removes one pip; at most one pip per burst. Protection cancels the whole burst without consuming bumper. Bumper consumes itself on the first connecting tracer and cancels the whole burst | Each tracer lives 0.8s; burst progress resets on next attack; old burst projectiles cannot add to new progress | Rival crossing the fixed firing line can leave before the third connection; reload provides an attack window |
| Pinball | Rival; frontal reflected ram | Vulnerable charge toward a nearest rail, up to 2.4s; real reflection at the rail; 1.3s committed ram at 65 units/s | One pip on frontal swept contact; protection then bumper; never armed on run-up | One reflection per attack; later edge ends it; storm rails count | Run-up exposes the predicted rebound line; rival can change height/cross it or attack before the bounce |
| Afterburner | Owner movement | Arms on attack commitment; activates when that attack recovers | No damage, defense or immunity | 0.9s recovery boost at 44 units/s and 5.2 rad/s; refreshes rather than stacks | Higher recovery speed can cross a firing line but does not invalidate contact |
| Spring Bumper | Owner defense | Visible ready shield until first unprotected damaging event/tracer | Cancels one event or entire Machine Gun burst; pushes both planes apart; defender banks 0.7s longer; no healing | Once per physical round; protection first does not consume it; no refresh during round | First attack spends shield; next attack must connect after protection ends |
| Fizzy Fuel | Rival; stationary wake | Emits behind committed attack for 0.8s, every 0.16s | Each armed contact can remove one pip; protection then bumper; owner immune | 0.2s arming, 0.9s life, radius 2.5, emitted 12 units behind; six puffs per owner / twelve total; oldest replaces; crossed puffs consumed | Automatic separation/banking can avoid wake; Magnet may pull fighters through it but never moves the wake |
| Magnet | Both fighters; symmetric movement | Activates after owner's committed attack ends, hit or miss | No damage, immunity or projectile attraction | 1s; 7 units/s toward each other; two magnets do not double force; refresh only | Recovery thrust exceeds pull; both automatic pilots can separate; inward rail steering still applies |
| Second Wind | Owner movement | Once when an accepted hit reduces owner to exactly one armor | No healing, extra pip, damage bonus or immunity | Lasts rest of physical round; no retrigger; new round resets | Rival still wins on one more accepted hit; boosted pilot recovers toward another attack rather than receiving avoidance immunity |

## Match layer (server)

First to two round wins; no more than five physical rounds; no more than 240 seconds from acceptance, including drafts and transitions. Every physical round ends within 35 seconds. At its cap compare armor; equal armor draws. Draws give no point and no new draft pick: rerun the same builds with a new seed. Both players advance draft stage only after the same decisive rounds. At two wins terminate immediately. At five rounds or 240 seconds compare completed round wins; tied scores draw. An unfinished round at the wall cap awards no point. There is no overtime beyond these bounds. Once-per-match resources (the free reroll) survive drawn-round reruns; no active combat card is once per match.

## Evidence boundary

`scripts/sample_battle.py` reports independent seeds, raw wins/losses/draws, half-point draw scores, seed-cluster intervals, caps and durations. `--wild-sample` includes every active paired-card build; `--quick` discloses its reduced opponent set. Historical baselines must save both `BattleSimulation.luau` and `BattleSkills.luau` together. A simulation gate is not proof of readability, comprehension, enjoyment, real phone input or published networking. Those require the two-player and real-phone checklist in the delivery records.

## Recorded active-roster sample (2026-10-10)

Command: `build/testenv/bin/python scripts/sample_battle.py --samples 20 --baseline build/m1-baseline/BattleSimulation.luau --baseline-scope outcomes --json`.
The baseline directory also contains its original `BattleSkills.luau` and catalog. Source changes are intentional: variable seeded pass timing addresses repeating trades/interruptions; Firework timing/projectile speed and Pinball run-up were tuned across all four offences. Historical no-skill outcomes therefore are compared, not claimed unchanged.

20 independent seeds, nine paired opening-angle combinations per seed, every ordered offence pair; aggregate field scores give each opposing offence equal weight and include both seats. Draws count as half a point, not excluded games. Runtime 28.3s for 3,600 rounds including 720 baseline rounds. A 95% interval is computed across seed-cluster mean scores; 180 angle variants do **not** mean 180 independent seeds.

| Offence | Field score | Seed 95% interval | Draw rate | Round cap | Median round |
|---|---:|---:|---:|---:|---:|
| Firework | 53.12% | 49.50–56.75% | 2.08% | 2.22% | 23.150s |
| Machine Gun | 44.76% | 40.79–48.72% | 6.18% | 12.85% | 23.383s |
| Meteor | 47.29% | 42.54–52.05% | 13.33% | 16.18% | 24.650s |
| Pinball | 54.83% | 51.58–58.08% | 14.79% | 31.39% | 29.983s |

Firework mirrors changed from **0 / 0 / 180** wins/losses/draws (all double knockouts; median 17.567s, p90 17.683s) to **99 / 81 / 0** (all knockouts; median 22.917s, p90 24.600s). No hidden tiebreak was added. Final mirror seat-one score 55%, seed-level 95% interval 32.63–77.37%; the interval is wide because opening angles correlate. This meets the declared draw gate in the sample, not proof of zero future draws or perfect seat fairness.

Open tuning gates: Machine Gun field score is 0.24 percentage points below 45%; Meteor mirrors draw 18.33%; Pinball mirrors draw 17.22% and cap 39.44%; Meteor/Pinball and Machine Gun/Pinball draw/cap rates remain high. Several ordered seat pairings exceed the 35–65% target (worst Pinball→Machine Gun 70.28%). These are explicit remaining balance risks for the published playtest. All rounds remain bounded and every draw is resolved by the match contract above.


The subsequent wild-only tuning preserves every base-table number above (20-seed rerun equality checked). On the same exhaustive three-seed paired-card screen, Fizzy average lift fell 20.31→8.33 percentage points and Bumper 11.98→8.34. Full-build scores above 65% fell from 7/40 to 2/40. Some defensive draw/cap gates worsened and remain explicit blockers to a balance-complete claim; see [BALANCE-REPORT.md](BALANCE-REPORT.md).
