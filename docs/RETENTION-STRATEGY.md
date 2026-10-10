# Skybound research and retention strategy

Research date: October 9, 2026. Status: proposed product direction and experiments; retention improvements have not been established.

**Direction update — October 9, 2026:** [Skybound Clash design and decision record](SKYBOUND-CLASH-DESIGN.md) is the current agreed direction and supersedes the implementation sequence below. The first authorized milestone is a two-power automatic arena Battle Lab with a labelled simulated opponent. The existing distance-flight game is preserved; this earlier research remains useful background, not the current build plan or evidence of retention gains.

Skybound's strongest opportunity is a quick competitive flight game where every result suggests a useful adjustment and every session develops the player's pilot identity. The immediate priority is faster entry, faster replay, and understandable flight results. A small progression layer should follow evidence that players voluntarily want another flight.

The proposed loop is **read the course → choose a plan → launch → understand the result → adjust → fly again → earn something lasting**. Automatic flight remains the starting assumption. Whether to test one manually triggered gadget remains an open product choice.

The [README](../README.md) describes implemented behavior. [VALIDATION.md](../VALIDATION.md) records technical and gameplay verification. This strategy separates the current base from future experiments.

## Competitive landscape

Skybound overlaps two established Roblox categories: automatic competitive duels and launch–earn–improve distance games. The research did not verify an exact match combining our angle selection, shared fuel/missile course, automatic plane flight, and paired 1v1 lobby; this does not establish that no such game exists.

Mechanics below come from official Roblox descriptions and public API responses. They establish comparable designs, not which features caused retention or revenue. Competitor onboarding, pacing, and shops still need direct playtesting before copying their details.

| Experience | Relevant mechanics | Implication for Skybound |
| --- | --- | --- |
| [Ball VS Ball](https://www.roblox.com/games/96510596525082/Ball-VS-Ball) | Automatic 1v1/2v2 battles; round-level selection; 40+ balls with distinct abilities; collection and trading. | Closest structural comparator. Choices and collections can give automatic contests meaning. |
| [Build A Plane](https://www.roblox.com/games/137925884276740/Build-A-Plane) | Build from blocks, fly through obstacles and procedural biomes, earn upgrade money, collect rare blocks. | A flight funds a visible change to the next attempt. Full construction would be a major scope expansion. |
| [Launch ur Plane](https://www.roblox.com/games/103356848587304/Launch-ur-Plane) | Launch for money; upgrade speed, wings and luck; acquire planes/slingshots; land on islands; steer with A/D. | Direct thematic competitor. Landing targets supply a concrete alternative objective; automatic duels were not verified. |
| [RIVALS](https://www.roblox.com/games/17625359962/RIVALS) | Duel pads; first-to-five matches; equipment and skins; contracts; streaks and leaderboards. | Strong reference for social challenges, a multi-round rivalry, and goals between matches. |
| [Yeet A Friend](https://www.roblox.com/games/11708967881/Yeet-A-Friend) | Launch distance, training, pets, worlds, seasonal quests and leaderboards. | A clear social fantasy and several goal horizons. Our pitch needs similar immediate clarity. |
| [Paper Plane for Brainrots](https://www.roblox.com/games/110373292461174/Paper-Plane-for-Brainrots) | Throw a plane to acquire collectibles that generate money in a persistent base. | Flight distance produces something tangible to keep and display. |
| [Fly to SPACE](https://www.roblox.com/games/72515236628292/Fly-to-SPACE) | Charging orbs, pets, dimensions, distance records and friend races. | Recognizable landmarks make distance goals easier to understand. |
| [Become a Plane and Fly](https://www.roblox.com/games/18207529184/Become-a-Plane-and-Fly) | Train energy, fly for money/items, collect pets, explore islands and develop a treehouse. | Persistent ownership fits the genre; a small hangar could serve that purpose in our theme. |
| [Plane Race](https://www.roblox.com/games/18466215642/Plane-Race) | Train speed, collect wins and pets, finish levels and pursue rankings. | Plane-themed numerical progression is already common. Meaningful decisions and rivalries offer stronger differentiation. |
| [Paper Plane Simulator](https://www.roblox.com/games/5680601511/Paper-Plane-Simulator) | Throw planes, unlock areas, collect pets and skins, compete on leaderboards. | Plane launching plus collectibles is established territory. |
| [Build A Boat For Treasure](https://www.roblox.com/games/537413528/Build-A-Boat-For-Treasure) | Construct a personal vehicle and take it on an adventure. | Ownership, experimentation and shared projects can matter between runs. |

On October 9 at 09:16:54 UTC, the official API reported **33,335 concurrent players and 90.26 million visits for Ball VS Ball**, and **4,842 concurrent players and 766.08 million visits for Build A Plane**. These are activity and lifetime-visit snapshots, not retention measurements. The [API endpoint](https://games.roblox.com/v1/games?universeIds=10685282333,7822444776,6172721363,6257892413,4147392742,2005183359,210851291,7782036711,10247712813) returns current values when reopened. [Launch ur Plane and RIVALS metadata](https://games.roblox.com/v1/games?universeIds=8779657730,6035872082) was checked separately at 09:18:41 UTC.

## Findings in the current base

The server-owned simulation, shared conditions, explicit ghost labels, recovery feedback, records and consensual rematches are useful foundations. Four issues should guide the next experiments:

1. **Preparation can exceed flight time.** Voting takes 8 seconds, configuration up to 25, aiming up to 20, and countdown 3: 56 seconds at their deadlines, excluding queueing. Early confirmations shorten configuration and aiming. A recorded 210-flight simulation sample had P10/median/P90 durations of 14.4/21.9/32.4 seconds; these are simulation results, not human session measurements. See [server phase durations](../src/server/Main.server.luau) and [validation](../VALIDATION.md).
2. **A rematch changes the experiment.** `configure` generates a fresh seed each round. Players cannot isolate whether a new angle or the new course improved their result. Results show scores and records but little explanation of the flight.
3. **Identical decisions produce identical flights.** New players share the same default setup. Three planes, three gadgets and 46 integer angles provide 414 configurations, but that count does not establish strategic depth. Plane differences currently come from fixed launch speeds and starting angles. Same-course competition could converge on copied solutions and ties. See [simulation](../src/shared/Simulation.luau) and [catalog](../src/shared/PlaneCatalog.luau).
4. **Human access depends on coordination.** Players must occupy opposite pads at the same station. A small population can be divided among waiting stations. Practice is available, but it is a separate choice rather than a continuation of the queue.

Automatic flight may create anticipation or helplessness. Observing unfamiliar players is necessary to distinguish those reactions.

## Proposed experiments

### Faster entry and repeat preparation

Provide one obvious Play action that connects available opponents. Retain pads for deliberate social challenges and offer a clearly labelled practice fallback when nobody is available. Avoid splitting a small population among additional human queues.

Start newcomers with a suggested loadout and teach aiming through their first launch. Introduce more customization after the first result. Preserve the previous loadout on repeat flights and make editing optional.

Initial design targets are **20–30 seconds to a first launch** and **5–10 seconds of repeat preparation**. These are project hypotheses, not Roblox benchmarks or promises about human readiness. Measure actual elapsed time and abandonment alongside them.

### Flight Lab and understandable results

Test a same-course practice retry with the previous flight as a ghost, a trajectory comparison, and an immediate Tweak & Retry action. Preserve equipment and expose angle adjustment directly. Keep the seed and simulation version consistent across comparisons.

Show observations that help the player form a next experiment: a shield absorbing a missile, passing below a +20 pickup, or the distance difference from the previous attempt. Claims that a missed pickup cost a particular distance require a valid counterfactual simulation.

This is the first experiment for deliberate improvement. Measure voluntary retries after losses, setup changes, improvement on the same course, and whether players can explain what they are trying.

### Short rivalry sets

Test a three-round Sky Cup with a running score and quick between-round adjustments. Retain equipment and avoid repeating the full setup flow. Keep exact same-course retry in practice initially; test competitive course rotation and watch for ties, copying and dominant setups.

A later option is an equal-access draft of temporary modifiers between flights. [ROUNDS](https://store.steampowered.com/app/1557740/ROUNDS/) demonstrates round-level adaptation by giving its losing player an upgrade choice. Skybound's draft would need its own balance and clarity tests.

### Recognizable plane abilities

Prototype two visibly different behaviors before expanding the catalogue. Keep competitive access fair while testing whether players recognize and deliberately choose the tradeoffs.

| Proposed plane | Advantage | Tradeoff |
| --- | --- | --- |
| Glider | Slow descent and longer recovery opportunities | Slower initial launch |
| Afterburner | Strong early forward momentum | Greater speed loss from missile hits |
| Salvager | First missile contact creates a small recovery | Weaker ordinary fuel boosts |
| Skimmer | Extra value from low-altitude fuel | Less effective on high routes |

These are unbalanced concepts. [Super Auto Pets](https://store.steampowered.com/app/1714040/Super_Auto_Pets/) pairs automatic resolution with ability combinations, asynchronous competition and rotating shared packs. [Peglin](https://store.steampowered.com/app/1296610/Peglin/) combines aiming and physics with items that change a run. Both supply useful patterns, not proof of a retention lift in Skybound.

### Pilot Passport

Test a small progression board across Coast, Skyline and Storm. Appropriate completed flights, equipment experiments and personal improvement can earn stamps, liveries, contrails, pilot titles and hangar trophies. Winning supplies additional prestige; players who lose can still progress.

A possible opening sequence is first completed flight → try another plane → improve a course record → earn a distinctive contrail. Show one immediate goal and one aspirational reward. Start with a small trophy shelf or plane display. Preserve earned progress when someone misses a day.

### Daily Flight and friend challenges

Offer a curated daily course with identical rules, approachable medals and friends' distance markers. A specific friend's record gives a concrete challenge. [Trackmania's Track of the Day](https://doc.trackmania.com/play/what-is-totd/) supplies a reference for fresh shared courses and daily records.

Curate seeds and medal thresholds; procedural generation does not guarantee an interesting challenge. The current finite decision space can become solved, so start with personal mastery and friendly comparison before treating this as a durable global competitive ladder. Compare records under the same course and simulation version.

An asynchronous friend ghost is useful even in an empty lobby. Actual invitations and playing together serve a different purpose; ghost challenges alone do not establish intentional friend co-play.

## Later opportunities

- **Flight Expeditions:** several flights with temporary part choices between them, creating a build within a session and a clear endpoint. [Learn to Fly 3](https://store.steampowered.com/app/589870/Learn_to_Fly_3/) provides a reference for modular launch progression and alternative objectives.
- **Delivery challenges:** reach landmarks, carry cargo or land in target areas to change how existing equipment is evaluated.
- **Duo events:** contribute to a shared distance or delivery goal with a friend after individual duels prove enjoyable.
- **One manual gadget:** compare against automatic flight only if improved planning and feedback still leave players disengaged during flight. [Peggle](https://www.ea.com/games/peggle/peggle) offers a reference for aiming, powers, spectacle and mastery challenges while much of the action resolves automatically.

Defer full construction, trading, a large crate economy, rebirths and a battle pass until repeat play is demonstrated. Initial monetization candidates are direct purchases of liveries, contrails, pilot cosmetics and victory presentation. The commercial hypothesis is that players value visible identity within a game they already enjoy.

## Sequence and measurement

| Order | Experiment | Primary evidence | Guardrails |
| --- | --- | --- | --- |
| 1 | Faster entry and repeat preparation | First and second flight conversion; time to launch | Setup comprehension, abandonment, ghost clarity |
| 2 | Flight Lab and result feedback | Voluntary retries, especially after losses; ability to explain the next adjustment | Solved courses, copied setups, misleading explanations |
| 3 | Short cups and a small Passport | Several completed flights; returning to an unfinished goal | Leaving between rounds, repetitive chores, loss frustration |
| 4 | Daily Flight and friend challenges | D1/D7 retention, distinct play days, actual friend co-play | Low-population access, course quality, fair comparisons |
| 5 | Additional abilities, cosmetics and events | Continued demand for variety and visible identity | Competitive balance and sustainable content effort |

Begin with 8–12 unfamiliar players, including physical-phone users, and observe without coaching. This can expose comprehension problems but cannot establish a statistical retention improvement. Watch whether they understand the result and voluntarily choose another flight. Larger controlled comparisons should follow when traffic supports useful estimates; Roblox's [experiment guidance](https://create.roblox.com/docs/production/experiments) explains minimum detectable effects and experiment duration.

The newcomer funnel should be **join → first launch → first completion → voluntary second launch → third completion**. Measure:

| Metric | Definition |
| --- | --- |
| First flight conversion | New players who launch at least once divided by all new players |
| Second flight conversion | New players who voluntarily launch twice divided by all new players; also report the conditional rate among first-flight completers |
| Time to first launch | Median and P90 join-to-launch time, reported alongside the share that never launches |
| Replay delay | Time from result presentation to next launch, with non-replayers reported separately |
| Rematch conversion | Requests among eligible result views, both-player acceptance, and successful relaunch as separate steps |
| Abandonment | Queue and phase exits, separated by phase and player experience |
| Choice and learning | Setup distribution, changes between attempts, tie rate and improvement under identical conditions |
| Return behavior | D1/D7 retention and unique play days, separated by device, acquisition source, new/returning players, and practice/human or solo/friend entry |

Separate replay after winning from replay after losing. Session duration alone can be inflated by waiting or idling.

The [current telemetry](../src/server/Telemetry.luau) measures match duration from launch, excluding queue and preparation time. Queue events do not record wait duration, and rematches record requests rather than accepted relaunches. Add the relevant funnel and phase timing before judging experiments. Revisit the 16-events-per-player-per-minute limit if faster rounds and new events would cause silent drops.

Roblox's October 9 [discovery guidance](https://create.roblox.com/docs/discovery) prioritizes play-through, early bounce, play days and playtime; intentional friend co-play is also important. Home recommendation ranking evaluates Home-acquired players separately from other sources. Keep acquisition cohorts distinct, use [retention cohorts](https://create.roblox.com/docs/production/analytics/retention), and treat available comparison benchmarks as context rather than universal success thresholds.

## Publishing and acquisition

Before scaling acquisition, complete the published two-human lifecycle, reconnect/saving checks, live analytics delivery and physical-device performance validation listed in [VALIDATION.md](../VALIDATION.md).

Test a clear promise such as **Aim your plane. Outfly your friend.** Show authentic close finishes, recoveries and equipment interactions in thumbnails and short clips. Small acquisition tests can reveal onboarding problems; increase promotion after those cohorts show repeat play. Roblox provides [thumbnail performance and personalization tools](https://create.roblox.com/docs/production/publishing/thumbnails).

## Open questions and decision record

- Do players enjoy watching the full flight after they understand the available decisions?
- Can they explain a loss and name a deliberate adjustment without prompting?
- Are several configurations useful, or does one dominate most courses?
- Does same-course retry encourage learning before it becomes solved?
- Do short cups improve rivalry without increasing waits or frustration?
- Which earned item makes players care about their pilot identity?
- Does daily content prompt return play beyond reward claiming?
- Should automatic flight remain absolute, or should one manual gadget be tested?

No retention experiment has a recorded outcome yet. After each experiment, append its date, build, participant/cohort count, acquisition source, primary metric, relevant guardrails, observations and keep/change/drop decision. Promote an experiment into product direction when the evidence supports it, and update the README only when the behavior is implemented.
