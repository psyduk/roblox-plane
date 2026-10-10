# Skybound Clash — design and decision record

Decision date: October 9, 2026. Status: agreed product direction; the first authorized milestone is a playable Battle Lab. This document defines intent and decision gates, not implementation or retention results.

The [README](../README.md) describes implemented behavior. [VALIDATION.md](../VALIDATION.md) records completed checks and remaining gaps. Earlier distance-flight research remains in [Retention strategy](RETENTION-STRATEGY.md); this document supersedes its proposed implementation sequence.

## Direction update: Sky Battle (October 10, 2026)

Owner decision, made after looking at Ball VS Ball, RIVALS, Blade Ball and Roblox's monetization guidance. Where this section conflicts with a later one, this section wins. The later sections stay as the record of how the combat toy was built.

**Promise: draft a build one pick at a time, watch it fight, want one more match.**

### Skins and skills are separate

- **Aircraft are skins.** They are the main cosmetic and the first thing sold. A skin never changes combat.
- Every skin shares one hitbox and one set of mount points (nose, belly, wings, tail, centre). Skills attach to mount points, never to a particular model, so every skill works on every skin. Later skins need not be planes (a gryphon, a broom, an airship) as long as they honour the same contract.
- **Skills come in two kinds.** An **offence** is the weapon: how you remove armor. A **wild card** is the trick: it changes movement, the arena or how a hit lands. There is no separate defence slot; defensive tricks such as Spring Bumper and Dodge Roll are wild cards.

The starting roster is ten of each. "Built" means it exists in the game today.

| Offence | What it does |
| --- | --- |
| Meteor (built) | Charges, then dives into a ram |
| Firework (built) | One big slow rocket |
| Machine Gun | A short burst along its heading |
| Pinball | Banks off a wall, then rams |
| Chomper | Eats one projectile at a time and bites up close |
| Boomerang | A blade that arcs out and can hit on the way back |
| Sky Mines | Drops floating mines behind it |
| Harpoon | Hooks the rival and slings it into a wall |
| Bomber | Climbs above and drops a bomb straight down |
| Tesla | A short-range zap that only reaches up close |

| Wild card | What it does |
| --- | --- |
| Afterburner (built) | Speed burst after attacking |
| Fizzy Fuel (built) | Leaves a damaging wake |
| Spring Bumper (built) | Blocks the first hit and springs apart |
| Dodge Roll | Rolls out of one hit, then a long cooldown |
| Decoy | A balloon copy that draws the next aimed attack |
| Magnet | Pulls the planes together after each attack |
| Storm Caller | The wind closes sooner and faster |
| Cloud Cover | Slips through a cloud that breaks the rival's aim |
| Second Wind | A speed boost once you are on your last armor |
| Copycat | Copies the rival's wild card at reduced strength |

No skill is strictly stronger than the starter skills. Rarity means stranger, not stronger. Advantages, not hard counters, still applies. Balance targets: each offence wins 45–55% against the field, no single pairing is worse than about 65/35, no wild card lifts a build by more than about ten points on average, and draws and timeouts stay no higher than today's worst matchup.

New skills are built fight logic first, with placeholder visuals and sounds, so the whole matchup table can be measured and beta testers can play every skill before any is polished. Beta builds unlock every skill.

### Match

- First to two round wins.
- One pick per round: an offence before round one, a wild card before round two, and a second wild card before a deciding round three. The build resets every match.
- Each pick is an offer of three random skills from the ones the player owns of that kind. Each player gets one free reroll and one free "pick any skill I own" per match.
- Both players draft under the same rules. The rival's existing build is visible; the new pick is hidden until both lock.
- First to three, with swap picks in later rounds, is a later experiment.

### Skills are earned, looks are bought

- Everyone starts with a few skills of each kind (start with three offences and three wild cards). The rest come from coin crates and level-ups. Coins come from playing: more for a win, some for a loss.
- Skills are not sold for Robux, and coins are not sold for Robux. This keeps skill crates outside Roblox's paid random items rules and keeps a loss from feeling bought.
- Robux products, in order:
  1. Plane skins at fixed prices, a one-time starter pack shown from first spawn, and a Double Coins pass.
  2. A season pass with a free track and a paid track of skins.
  3. Gems, extra rerolls and cosmetic cases. These are paid random items: they need exact odds shown before purchase and a `PolicyService` check per player.
- No trading for now.

### Opponents

Human 1v1, with a bot when nobody is queued. Bots are named but always marked as bots.

### Build order

1. The draft loop, and skills that work on any skin.
2. Human 1v1 with bot fallback; the hangar shows other pilots' planes.
3. Coins, skill crates, levels, daily quests and playtime rewards.
4. Plane skin shop, starter pack and Double Coins.
5. Season pass, then gems and cases.

### What this replaces below

| Earlier text | Now |
| --- | --- |
| "Each plane has one signature" | Signatures are offence skills and work on any skin |
| One signature plus one modifier | One offence plus up to two wild cards |
| "Permanent combat-stat growth is outside this direction" | Still no stat growth. The skill collection is permanent and widens what a player can be offered |
| "Defer trading, crates, a battle pass, daily chores" | Coin crates, daily quests and playtime rewards arrive in step 3; the season pass in step 5; trading stays deferred |
| First rivalry MVP draft table | The match rules above |
| "Stable camera" | A dynamic camera, approved in [the battle audit](BATTLE-AUDIT.md) |

## Product promise

**Choose a ridiculous plane power. Watch it clash with a rival. Make one useful adjustment and fight again.**

Keep entry simple while allowing meaningful combinations. The first attraction is a short, understandable battle between two toy planes. Drafting, rivalry and cosmetic identity should give that battle additional reasons to replay. A larger collection cannot substitute for an entertaining first fight.

The working direction is a **2.5D automatic arena duel**: three-dimensional toy aircraft move within one two-dimensional combat plane, viewed together from a stable camera. Players choose their build before combat and watch it resolve automatically. This is a proposed new mode; preserve the existing distance-flight game during the experiment.

## Decisions to preserve

| Decision | Meaning |
| --- | --- |
| Simple first, depth through interactions | A few readable choices should change behavior, positioning and timing. Avoid a large opening configuration screen. |
| Both planes share one arena | Their actions directly affect one another. Keep the rival and consequential effects visible. |
| Automatic combat | Decision making happens before rounds. Manual steering and active ability timing are outside the initial test. |
| Temporary combat build | A signature and its modifiers persist between rounds of one match. They reset at **every new match and every rematch**. |
| Permanent cosmetic identity | Paint, contrails, pilot presentation and trophies can persist. Permanent combat-stat growth is outside this direction. |
| Equal drafting opportunity | Both players receive independent compatible offers under equivalent rules, with the same offer count and opportunity to choose. Equal access does not require identical cards. |
| Simultaneous reveal | Each player's existing build is visible before drafting; their new choice remains hidden until both lock or the deadline resolves. |
| Advantages, not hard counters | A matchup may favor one plan, but should leave useful attack opportunities for both. Avoid complete shutdowns or immunity to an opponent's entire kit. |
| Small complete experiments | Prove the combat toy, then the rivalry, then a complete session, then return behavior. |

## First authorized milestone: Battle Lab

Build one local practice arena with **Meteor and Firework**, manual configuration and quick restarts. Either side can choose either signature, including mirror matches. The opposing aircraft must be explicitly labelled as a simulated practice opponent.

The milestone is a way to inspect combat, readability and pacing. It does not yet include the production draft, human 1v1 queue, a multi-round match economy, collection expansion or retention claims.

- Show both planes, their current attack state and three armor pips clearly.
- Make Meteor's dive and Firework's rocket visibly different before adding modifiers.
- Allow an optional opening-angle setting of **10–55°** for manual comparison. Treat this as a test parameter; aiming should remain quick and integrated if retained in production.
- Restart into fresh armor, positions, timers, projectiles and effect state. Retaining manual test selections for convenience is distinct from carrying combat progress between matches.
- Provide a clear result and an immediate retry, plus an exit back to the existing hangar.
- Preserve the existing flight mode and its contracts while the new combat experiment is evaluated.

No modifier is required in this milestone. No implemented test, Studio result or player outcome is claimed by this design document.

## Combat rhythm and readable outcomes

Each attack follows **approach → windup → commit → recover**. A player should see what the plane is preparing, what it commits to, and when the other plane has an opportunity to respond. Constant homing and uninterrupted contact damage would obscure those decisions.

Start with **three armor pips** and simple successful hits. Match feedback should identify the hit that removed a pip. A large catalog of damage values, health upgrades and hidden percentages is outside the initial model.

| Parameter | Starting target | What to observe |
| --- | --- | --- |
| Typical round duration | 20–30 seconds | Enough time for recognizable attack exchanges, without prolonged circling |
| Arena pressure | Begins at 18 seconds | Creates an understandable finish while preserving useful recovery windows |
| Hard round cap | 35 seconds | No indefinitely stalled battle; show the resolution reason |
| Armor | Three pips per plane | Observers understand danger and the finishing hit |
| Opening aim | Optional, integrated | Adds a useful decision without a separate long preparation phase |

These are tuning hypotheses, not measured outcomes. Pressure must be visible and shared. It must not quietly change rules or erase the distinction between signatures. Record the exact pressure and timeout rules with implementation evidence before treating them as settled. Equal outcomes must be communicated honestly; do not hide a random winner behind a victory animation.

The camera should keep both planes large enough to recognize on a phone. Favor a bounded arena, limited simultaneous projectiles, short effects and clear silhouettes. A little comic tumbling can improve impact feedback, provided it does not conceal the next attack or delay the result.

## Signature roster

Each plane has one signature. Signatures define attack behavior; modifiers later alter a useful part of that behavior.

| Signature | Core behavior | Opportunity for the rival | Scope |
| --- | --- | --- | --- |
| **Meteor** | Climbs, charges and commits to a dive attack | A readable commitment followed by a vulnerable wide recovery | Battle Lab |
| **Firework** | Lines up an attack pass and launches one large, slow, readable rocket | Needs time and alignment; avoid making the projectile an unavoidable homing hit | Battle Lab |
| **Pinball** | Banks off an arena wall, then makes a charged ram | Predictable rebound path can be intercepted or avoided | Rivalry prototype candidate |
| **Missile Muncher** | Eats projectiles and uses a close bite as its ordinary threat | Still has to close distance; projectile eating supplies an advantage, not total immunity | Expansion only after enough projectiles or objects provide food |

Meteor versus Firework is the first contrast to validate. Test both sides and mirrors so the assessment is not based on one favorable pairing. Pinball expands the movement possibilities after the initial combat works. Muncher depends on an ecosystem that does not exist in a two-signature prototype.

## First depth experiment: one optional effect

The user tried the Battle Lab and singled out the natural fighting movement as the promising part. Preserve the existing no-effect movement exactly while improving attack cues, impacts and the finish. This is one player's qualitative feedback, not completion of the unfamiliar-player gate.

The next lab iteration allows **one optional effect per plane**, with **No Effect** as the default comparison. The player still selects both lab setups manually. Keep aiming available under an optional control. The new slot is a controlled interaction test; it does not add a production draft, permanent combat progression or human matchmaking.

The following effects are experimental lab choices, with tuning documented in validation rather than treated as established balance rules.

| Modifier | Intended behavior | Readability and balance constraint |
| --- | --- | --- |
| **Afterburner** | A short speed burst and tighter turn after attacking | Briefly changes recovery and re-entry; avoid persistent runaway speed |
| **Spring Bumper** | Absorbs the first incoming hit and pushes the planes apart | Clearly show the spent bumper and separation; do not create repeated immunity |
| **Fizzy Fuel** | An attack leaves a short-lived hazardous wake | Keep the wake brief and distinguishable from cosmetic contrails |

Offer only modifiers with a meaningful effect on the current signature. Compatibility is a rule for useful options, not a guarantee that all options are equally strong in every matchup. Test combinations for readable tradeoffs before expanding the pool.

## Signature presentation pass

The user finds the movement and consequential choices promising, while the current skills/effects need stronger appeal. The next authorized pass gives Meteor and Firework clear visual and sound identities with **No Effect equipped**. Preserve their current flight, attack timing, damage and outcomes so the presentation can be judged against the same fights.

- Meteor has a heavier armored silhouette, a gathering charge and a directional comet-like dive. Impact feedback occurs only on an authoritative hit; a missed dive must still read as a miss.
- Firework has oversized striped launch tubes, a bright ignition and a chunky sputtering rocket. The rocket follows its existing committed trajectory; cosmetic exhaust does not imply extra damage or homing.
- The arena and HUD use coordinated pilot colors, clearer three-segment armor, restrained light accents and a strong finish. Keep both planes visible and the camera stable. Effects are bounded, short-lived and reset with the round.
- A committed Meteor attack gets a dedicated presentation event because an attack can begin, hit and recover between network snapshots. This repairs a missing cue without extending the attack or changing movement.

The playtest question is whether each base power feels distinctive and satisfying before adding an effect. Pinball and additional combat systems remain later work.

## Meteor spacing and ground-crash pass

The user explicitly requested a visible Meteor charge and sustained slam while keeping the natural flight, plus defeated planes crashing into the ground. Three-hit armor stays for this experiment; the current three-segment display already communicates remaining health without introducing new damage values.

Meteor now spends 0.6 seconds arcing toward open space and 0.4 seconds aiming before release. Ordinary approach/circling, recovery and Firework's attack rules are preserved. The charge should be legible, the dive should visibly travel, and its direction must remain committed after release. Retain real swept collisions and miss opportunities; no teleport, guaranteed damage or temporary immunity to force the spectacle. Timing and matchup consequences belong in validation.

A plane with zero armor falls, tumbles and lands on the visible arena floor after the authoritative outcome. This is presentation only: no extra damage, changed winner or altered rewards. Both planes crash after a simultaneous knockout; planes retaining armor at the time cap do not. The falling plane remains within the stable camera view. Ground impact gets one sound/effect, and retry or exit clears the entire sequence immediately.

## Single game entrance

The hangar’s main **PLAY** button now enters plane-battle setup. Remove the separate combat shortcut, Solo button, distance gates and automatic distance queues from the default player experience. Keep the distance implementation behind a server startup flag for possible later development and regression checks. The player-facing prototype remains explicitly a simulated opponent; this routing change does not introduce human combat matchmaking or combat rewards.

## First rivalry MVP

The first multi-round target is **first to two wins**, with at most **one signature and one modifier** per player.

| Stage | Choice | Combat build |
| --- | --- | --- |
| Before round one | Choose one signature from a three-option offer | One signature |
| Before round two | Choose one compatible modifier from a three-option offer | Original signature plus one modifier |
| Before round three, if needed | No additional required choice | Keep the same signature and modifier |
| New match or rematch | Reset the match build and score; begin a new signature choice | No combat power carries over |

Keep the choice deadlines short; exact timers require observation rather than a locked specification now. The opponent's previous build remains visible while choosing. New selections reveal together. Default and timeout choices must follow the same rules for both players and be understandable.

Three signatures cannot demonstrate a broad randomized signature pool when every offer contains three. In that early version, test comprehension, matchup variety and rivalry. Do not claim catalog depth from permutation counts or an offer that always contains the same roster.

Independent randomized offers become useful as the compatible pool grows. Their purpose is to make a small decision interesting, not to create situations where one player has no viable option. Neither cosmetic ownership nor spending should narrow an opponent's competitive access.

## Later rivalry expansion

Only after the smaller format works, consider **first to three wins** and a maximum of **two modifiers**:

- Round one: one signature.
- Before round two: add the first modifier.
- Before round three: add the second modifier.
- Before rounds four and five: an optional replacement, with **Keep** as the default.
- A new match or rematch still resets the whole combat build.

Expansion should add satisfying interactions without extending waits or turning the fight into unreadable effects. Do not add rounds merely to increase session duration.

## Persistent identity and session goals

Retain the hangar as a place to show the player's aircraft and meet rivals. Permanent rewards can include known cosmetic liveries, contrails, pilot titles, victory presentation and trophies. Rewards should support a game players already want to replay.

Keep cosmetic trails visually distinct from damaging wakes and attack telegraphs. Completing or learning from a fight can advance identity without requiring every player to win. Losing should produce an understandable next experiment rather than a need to buy stronger statistics.

Defer trading, crates, a battle pass, daily chores and a large collection economy. Friend challenges, cosmetic mastery and rotating shared pools become candidates after a complete session proves enjoyable. The existing cosmetic implementation is not evidence that these retention ideas work.

## Roadmap and decision gates

| Stage | Deliverable | Advance when | Rework or stop when |
| --- | --- | --- | --- |
| 1. Combat toy | Battle Lab: one arena, Meteor/Firework, labelled simulated opponent, quick retry | People follow the attacks, understand hits and voluntarily try another setup | Circling, arbitrary-looking hits, unclear endings or passive disengagement dominate |
| 2. Rivalry | First-to-two human duels; add Pinball and one modifier slot; equal drafting rules | Between-round adaptation is understandable and both players want the next round | Draft waits outweigh fights, one build dominates, or losses feel predetermined |
| 3. Complete session | Reliable entry, result, rematch, exit and modest cosmetic goal | New players complete the loop and voluntarily start another match, including after losses | Repeat play depends on coaching or rewards alone |
| 4. Return play | Appropriate telemetry, modest acquisition and mature return cohorts | Return behavior improves with acceptable uncertainty and no material guardrail regression | Playtime increases mainly through waiting, idling or compulsory repetition |
| 5. Expand | Larger compatible pool, first-to-three test, second modifier or friend features | Existing players show demand for those specific additions | Complexity reduces clarity or creates unsustainable content demands |

Technical correctness and server authority remain necessary throughout. Simulation checks, Studio play, two-client behavior, published lifecycle checks and physical-phone play establish different things. Record each separately in [VALIDATION.md](../VALIDATION.md).

## Playtest and measurement plan

Start with **8–12 unfamiliar players**, including physical-phone users, and observe without coaching. This qualitative sample can expose comprehension and friction; it cannot establish a statistical retention improvement.

Watch whether players identify their plane, anticipate a windup, explain a hit, understand the result and voluntarily retry. After a round, ask what they think happened and what they would change. Separate observation from the player's stated interpretation, and separate human-opponent sessions from simulated practice.

Before expanding the roster, check:

- Both aircraft, armor, rockets, wakes and windups remain readable on an actual small screen.
- A player can explain a loss and name a useful change without reading a combat log.
- Both signatures and mirror matches produce understandable results over repeated trials.
- Longer fights end through visible pressure rather than an unexplained cutoff.
- Retry and exit work immediately, without accumulating old effects or input state.
- Players choose another fight after losses as well as wins.

For a complete-session test, instrument **join → first battle start → first battle completion → voluntary second battle → match completion → voluntary next match**. Track non-starters and non-replayers as well as elapsed times among those who continue.

| Measure | Definition and guardrail |
| --- | --- |
| Entry and preparation | Median/P90 time to first battle and between-round delay; report abandonment by phase |
| Voluntary replay | Next-battle and next-match conversion; split wins, losses, draws, practice and human play |
| Draft quality | Offer, choice and compatible-build distribution; record defaults and deadline use |
| Combat quality | Round duration, timeouts, draws, hit clarity and matchup outcomes; avoid inferring balance from a few wins |
| Device experience | Readability, input success, frame stability and disconnects on physical phones |
| D1/D7 return | Real new-user cohorts that have reached the respective observation window, with explicit denominators and day definitions matching analytics |

Report D1 and D7 only after cohorts have matured. Separate acquisition source, device, new/returning status, solo/friend entry and practice/human play. Preserve build and experiment identifiers so a mix of changing versions is not treated as one result. Visits, concurrent users and Steam reviews are not retention measurements.

Where traffic permits, compare randomized variants with a declared primary metric, duration and detectable effect; otherwise label before/after evidence as observational. Include sample size and uncertainty. Session duration alone can rise because of waiting. Follow Roblox's [experiment guidance](https://create.roblox.com/docs/production/experiments) and [retention cohort guidance](https://create.roblox.com/docs/production/analytics/retention).

## Research informing the direction

These sources establish mechanics and examples. They do not prove those mechanics will improve Skybound retention.

- [Ball VS Ball](https://www.roblox.com/games/96510596525082/Ball-VS-Ball): small round-level choices and automatic combat. Its [official metadata endpoint](https://games.roblox.com/v1/games?universeIds=10685282333) describes one of three random balls, distinct skills and 1v1/2v2. Borrow approachable decisions and readable identity.
- [ROUNDS — Landfall](https://landfall.se/rounds): escalating combinations and adaptation within a rivalry. ROUNDS upgrades its losing player; Skybound's chosen draft gives both players equal opportunities.
- [Bopl Battle](https://store.steampowered.com/app/1686940/Bopl_Battle/): powers interact with other powers and the arena. Borrow understandable interactions, while recognizing that its combat is directly controlled.
- [Super Auto Pets](https://store.steampowered.com/app/1714040/Super_Auto_Pets/): automatic battles, distinct abilities, shared packs and rotating variety. A limited usable pool can coexist with a larger catalog.
- [CATS](https://play.google.com/store/apps/details?id=com.zeptolab.cats.google&hl=en): visible chassis, weapon and attachment identity makes a fighting machine feel personal. Cosmetic expression and combat readability are separate requirements.

## Living decision record

| Date | Decision | Evidence status |
| --- | --- | --- |
| October 9, 2026 | Explore direct plane-versus-plane arena combat while preserving distance flight | User-approved direction; research-informed hypothesis |
| October 9, 2026 | Start with a two-signature Battle Lab, then test rivalry before progression expansion | Authorized implementation scope; outcomes belong in validation records |
| October 9, 2026 | Reset combat builds every match/rematch; persist cosmetic identity | Product constraint |
| October 9, 2026 | First-to-two with one modifier precedes first-to-three with two | Scope and clarity constraint |
| October 9, 2026 | Preserve the natural fighting movement; improve feedback and test one optional effect slot | User play feedback and authorization; broader playtesting remains open |
| October 9, 2026 | Give Meteor and Firework stronger visual and sound identities before expanding the roster | User likes consequential choices and explicitly requests more visual impact; presentation quality needs playtesting |
| October 9, 2026 | Give Meteor real charge-to-impact spacing and add ground crashes after knockout; retain three-hit armor | Explicit user authorization; ordinary flight/recovery remain the reference feel |
| October 10, 2026 | Aircraft are skins and the main cosmetic; every skill works on every skin | Owner decision |
| October 10, 2026 | Skills drafted one per round from random offers of owned skills, with one free reroll and one free pick-any per match | Owner decision; modelled on Ball VS Ball, untested with players |
| October 10, 2026 | Two kinds of skill, offence and wild card, with no defence slot; a starting roster of ten each, built logic first and all unlocked for beta | Owner decision; the roster is untested concepts apart from the five built skills |
| October 10, 2026 | Skills are earned with coins; Robux buys skins, a starter pack and Double Coins first, a season pass later | Owner decision; informed by RIVALS, Blade Ball and Roblox's guidance, from public sources only |
| October 10, 2026 | Human 1v1 with bot fallback comes before the shop | Owner decision |

After each experiment, append the build, participant/cohort count, device and acquisition context, observations, measured outcomes, relevant uncertainty and a keep/change/drop decision. Update this document when the direction changes, the README when behavior exists, and validation records when it has actually been checked.
