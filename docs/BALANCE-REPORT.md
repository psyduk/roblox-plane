# Sky Battle M1 balance report

Measured 2026-10-10. Active roster only: four offences and five wild cards. Milestones 3/4 and expansion skills are outside this run. These are deterministic simulation results, not proof of human enjoyment, phone readability or published networking.

## Combat-feel revision — measured 2026-10-11

This supersedes every table below. The rules changed (planes keep flying, rolls, turns, hits no longer cancel, the round speeds up); see [COMBAT-CONTRACT.md](COMBAT-CONTRACT.md). Method: `build/testenv/bin/python scripts/qa/combat_feel.py 24 --pairs`, 24 seeds for each of the 64 ordered pairings, bare attacks, 1,536 rounds.

| Attack | Field score | Attacks that land | Attacks per round |
|---|---:|---:|---:|
| Meteor | 53% | 48% | 4.4 |
| Firework | 48% | 34% | 5.4 |
| Machine Gun | 43% | 43% | 4.7 |
| Pinball | 53% | 43% | 5.3 |
| Sniper | 49% | 29% | 3.9 |
| Boomerang | 49% | 35% | 5.3 |
| Black Hole | 53% | 48% | 4.5 |
| UFO Beam | 52% | 73% | 3.2 |

Whole field: 9.2 attacks a round, 43% land, median round 14.5 seconds (p90 22.0), 89% knockouts, 0.1% draws.

One wild card against a bare plane, both seats, two seeds per ordered pairing (256 rounds each): Snowball 69, Spring Bumper 67, Chicken 66, Giant 66, Hot Potato 66, Magnet 66, Fizzy Fuel 65, Rewind 65, Decoy 64, Gambler 64, Mothership 64, Wrap 64, Eject 62, Vampire 61, Second Wind 56, Afterburner 54, Bug 54, Thief 53, Squadron 51, Swap 50. Two-card builds were not re-screened.

Still fragile: shortening Meteor's charge from 1.0 to 0.8 seconds moved Meteor against Firework from 58% to 29% over 160 rounds. Approach time is now a weak lever (Boomerang stayed above 60% at nearly double its approach time), so balance was done on the weapons themselves.

## Tempo revision — measured 2026-10-10, source `072782f`

This section supersedes the tables below, which describe the 35-second rules. Rounds now check armor at 22 seconds and settle level armor by sudden death; approach and recovery are shorter; Magnet pulls during the attack. Same method: 20 seeds, nine angle pairs, 2,880 base rounds; wild cards from 3 seeds.

| Offence | Field score | W / L / D | Median / p90 |
|---|---:|---:|---:|
| Meteor | 48.6% | 673 / 713 / 54 | 20.5s / 24.1s |
| Firework | 44.2% | 636 / 802 / 2 | 18.1s / 22.8s |
| Machine Gun | 54.2% | 778 / 658 / 4 | 21.7s / 24.0s |
| Pinball | 53.0% | 753 / 667 / 20 | 22.0s / 24.7s |

Draws fell from 13–15% for Meteor and Pinball to under 4% for every offence; the worst mirror is Meteor at 11%. Pairings run from 31% to 69% (Pinball over Machine Gun, Machine Gun over Meteor, Meteor over Pinball), a little outside the 35–65 target.

| Wild card | Average lift | By offence (Meteor, Firework, Machine Gun, Pinball) |
|---|---:|---|
| Afterburner | −5.7pp | +4.2, −8.3, −12.5, −6.3 |
| Spring Bumper | +2.1pp | +10.4, −4.2, −12.5, +14.6 |
| Fizzy Fuel | +5.2pp | 0, 0, +16.7, +4.2 |
| Magnet | +2.6pp | +16.7, −12.5, −4.2, +10.4 |
| Second Wind | +7.8pp | +12.5, +16.7, −8.3, +10.4 |

**The balance is fragile.** Cadence is the main lever and it has cliffs: moving Machine Gun's approach from 3.0 to 2.8 seconds took its field score from 38% to 71%, and Pinball swung between 18% and 74% across a 0.5-second range. The chosen values (Machine Gun 2.9 / 2.0, Pinball 3.2 / 2.2, others 3.0 / 2.0) sit on a narrow shelf. Afterburner now costs its owner on average and needs a rework. Treat these numbers as a starting point for human play, not a result.

## Reproduce

```sh
build/testenv/bin/python scripts/sample_battle.py --tests-only
build/testenv/bin/python scripts/sample_battle.py --samples 20 --baseline build/m1-baseline/BattleSimulation.luau --baseline-scope outcomes --json
build/testenv/bin/python scripts/sample_battle.py --samples 3 --wild-sample --json
build/testenv/bin/python scripts/sample_battle.py --samples 5 --quick --wild-sample --skill Pinball --markdown
```

The historical sources are exactly commit `173b586c1a4763ef4c4f4e927f96520d56474a7f`. Recreate the baseline folder with `git show 173b586c1a4763ef4c4f4e927f96520d56474a7f:src/shared/BattleSimulation.luau > build/m1-baseline/BattleSimulation.luau` and the equivalent command for `BattleSkills.luau`.

The historical baseline folder must contain the original `BattleSimulation.luau` **and** `BattleSkills.luau` together. `--baseline-scope all` still checks exact unchanged physical fields; `outcomes` is used here because seeded pass cadence and shared tuning deliberately changed. `--quick` uses angle 32 and compares full builds against bare and matching-card opponents; it is a disclosed reduced screen, not the exhaustive command above.

## Counts and uncertainty

Base: 20 independent seeds; nine angle pairs (10°,32°,55°); all 16 ordered offence pairings including mirrors. 3,600 simulated rounds including 720 historical baseline rounds, 28.3s.
Wild/full builds: 3 independent seeds, both seats at angle 32; all 40 two-card builds against all 64 zero/one/two-card builds. 11,520 simulated rounds including base and single-card comparisons, 102.52s. Each full build has 384 seat/seed/opponent perspective observations; these are **three**, not 384, independent seed samples.

Seeds: `104729 + sample_index * 7919`. Scores award 1 for a win, 0.5 for a draw and 0 for a loss; each opposing offence is equally weighted. The 95% descriptive normal interval uses the mean within each independent seed, preserving correlations across angles/seats. Three-seed full-build flags are screening signals with wide uncertainty. Raw W/L/D, duration median/p90, trigger rates, intervals and worst full-build pairings are in the linked JSON files.

## Base offence results

| Offence | Score | W / L / D perspective counts | Seed 95% interval | Draw | Cap | Median / p90 |
|---|---:|---:|---:|---:|---:|---:|
| Firework | 53.12% | 750 / 660 / 30 | 49.50%–56.75% | 2.08% | 2.22% | 23.150s / 29.900s |
| MachineGun | 44.76% | 600 / 751 / 89 | 40.79%–48.72% | 6.18% | 12.85% | 23.383s / 35.000s |
| Meteor | 47.29% | 585 / 663 / 192 | 42.54%–52.05% | 13.33% | 16.18% | 24.650s / 35.000s |
| Pinball | 54.83% | 683 / 544 / 213 | 51.58%–58.08% | 14.79% | 31.39% | 29.983s / 35.000s |

Firework mirrors: historical 0/0/180 seat 1 wins/seat 2 wins/draws became 99/81/0. Both samples contain 20 independent seeds and 180 paired-angle rounds. Both samples have 0 timeouts; all rounds terminate by knockout. Median 17.567s → 22.917s, p90 17.683s → 24.600s. Final seat 1 score 55%, seed 95% interval 32.63–77.37%. The draw gate passes in this sample; this does not prove zero future draws or seat fairness. No winner randomization, last-hit rule or hidden tiebreak was added.

## Wild-card lift screen

| Card | Average lift | Worst offence lift | By offence (percentage points) |
|---|---:|---:|---|
| Afterburner | +3.12pp | +14.59pp | Firework +4.16, MachineGun +14.59, Meteor -12.50, Pinball +6.25 |
| FizzyFuel | +8.33pp | +29.17pp | Firework +4.16, MachineGun +29.17, Meteor +0.00, Pinball +0.00 |
| Magnet | -10.94pp | +6.25pp | Firework -4.17, MachineGun +6.25, Meteor -27.09, Pinball -18.75 |
| SecondWind | +7.81pp | +22.91pp | Firework +22.91, MachineGun +12.50, Meteor -6.25, Pinball +2.09 |
| SpringBumper | +8.34pp | +20.84pp | Firework -8.34, MachineGun +20.84, Meteor +18.75, Pinball +2.09 |

Targeted tuning on the identical three seeds reduced Fizzy Fuel average lift **20.31 → 8.33pp** and Spring Bumper **11.98 → 8.34pp**. Fizzy now leaves smaller, shorter hazards farther behind the plane (radius 2.5, life 0.9s, arming 0.2s, rear offset 12). Bumper still blocks the complete first hit or Machine Gun burst, with a visible 0.7s longer defender recovery. The base 20-seed table was rerun and remained exactly unchanged.

Paired lift intervals and Second Wind trigger rates are preserved in full-build JSON. Lower score is not proof a card is useless; Magnet can alter the paths of both pilots and expose its owner.

## Remaining tuning gates

- Machine Gun field score 44.76% is 0.24 percentage points below the 45% target; its interval spans the target.
- Meteor mirror draws 18.33%, above the <10% target. Pinball mirror draws 17.22% and caps 39.44%; several Pinball/Meteor and Pinball/Machine Gun pairings also exceed draw/cap gates.
- Some ordered seat pairings exceed 35–65%, worst Pinball→Machine Gun 70.28%; both-seat field averages do not erase this evidence.
- All wild cards now pass the roughly 10pp average-lift screen in the three-seed sample. Individual interactions still warrant care: Fizzy Fuel adds 29.17pp to Machine Gun; Second Wind adds 22.91pp to Firework; Bumper adds 20.84pp to Machine Gun. Paired confidence intervals are wide.
- Two of 40 paired builds exceed 65% field score after tuning (down from seven): Firework+FizzyFuel+SecondWind 67.84%, Firework+Magnet+SecondWind 65.10%. These combinations need priority playtest/tuning rather than a balance-complete claim.
- Highest full-build draw rate is 26.82%: MachineGun+SpringBumper+SecondWind. Highest cap rate is 58.85%: Pinball+Afterburner+SpringBumper. These remain failed duration/draw gates; reduced damage and Bumper recoil increased some defensive stalls. All games still honor 35s physical-round and server match caps.

## Evidence files

- [Base and before/after outcomes](validation/sky-battle-m1-base.json)
- [Full active builds and paired lifts](validation/sky-battle-m1-full-builds.json)
- [Versioned interaction and cap rules](COMBAT-CONTRACT.md)

Automated mechanics: 40 simulation and 5 catalog checks pass, including three-tracer burst threshold, whole-burst defense consumption and its defender recoil tradeoff, true rail reflection, symmetric bounded Magnet forces, simultaneous Second Wind, total speed cap, category-independent double knockout, determinism and all active offence attack attempts. Native Studio, published two-player, real-phone and persistence evidence is recorded separately by the delivery validation.
