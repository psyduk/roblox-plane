# Sky Battle: Milestones 1–2 playtest

This is a free playtest candidate. Milestones 3 and 4, monetization, extra skills, daily rewards and season passes are outside scope. Passing local tests does not close the published/phone or unfamiliar-player gates.

**Current test build:** Skybound Test, place **86507299893768**, universe **10770074500**, published **version 12** at **2026-10-11 02:47:04 UTC** (October 10, 19:47:04 PDT), from source commit **`70cc5d22f3a2d1c0d9e4d3037a0a853cfe0df5a8`**. Version 12 adds circling between attacks, seeded opening timing and a visible attack-load ring. A verified new pilot still starts with one guided bot match before the normal draft. The build retains version 10's [phone layout fixes](QA-2026-10-10.md#version-10-publication--phone-fit) and version 9's [fight HUD, full-roster draft, round length and Magnet changes](QA-2026-10-10.md#version-9-publication--first-player-feedback-pass). [Version 12 publication proof](validation/qa-2026-10-10/published-version-12.jpg).

Access was left unchanged. Studio confirmed availability to playtesters; Creator Dashboard was not refreshed during version 12 publication. The earlier dashboard observation was **Limited**, with **Playtesters enabled** and **Friends disabled**. Independent-account gameplay, physical-phone and live-save checks below remain unverified.

**Previous test build:** version **11**, published **2026-10-11T01:19:15Z** (October 10, 18:19:15 PDT), from source commit **`27a71f8bf36447342f4e27adf255945bac2c3f6c`**. Its checks are retained below.

## Build and launch

1. Run `build/testenv/bin/python scripts/sample_battle.py --tests-only` and `build/testenv/bin/python scripts/test_server.py` from the repository. The optional environment needs `lupa`.
2. Run `python3 scripts/build.py`, then `python3 scripts/validate_package.py --place build/Sky-Battle-Playtest.rbxlx`. Open **`/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`** in Studio. The build refreshes this distinctly named copy and canonical `Skybound.rbxlx` with identical bytes. Stop old play sessions and reopen this exact path after rebuilding; confirm **Sky-Battle-Playtest.rbxlx** in the Studio title. An older `Skybound.rbxlx` window may belong to another worktree. Building does not publish or update an already-open Studio document.
3. Press Studio Play, then the main PLAY button. A new session-only Studio pilot, or a published pilot whose verified profile has no completed battles, immediately gets a **five-second guided countdown → Meteor versus Firework bot fight**. There is no opening pick. Coaching explains automatic combat, armor and the chosen wild card. Published profiles still loading or unavailable use the normal queue rather than being assumed new. Distance/launch-angle/furthest-flight screens mean the wrong mode or place is running.
4. In the guided match, the first wild-card pick offers **Spring Bumper and Afterburner**; a later second pick offers **three eligible, distinct cards**. Each guided pick allows **40 seconds**. After completing the guide, normal PLAY waits up to eight seconds for a human, then clearly identifies a practice bot. Normal picks show the full eligible roster: four offences at the opening and each remaining eligible wild later. Normal picks allow **15 seconds**. Tap a card and LOCK IN; the deadline locks the current valid selection or chooses the first offered card. There is no Reroll or Pick Any in either flow.
5. Combat runs automatically. Both sides gain one new wild-card pick after each decisive round if the match continues, up to two. Three armor pips belong to each round; two round wins take the match. At **22 seconds**, more armor wins; level armor enters sudden death until one plane loses armor, with a **35-second hard stop**. A draw repeats the same builds with a fresh seed and no point or new pick. The match ends within **five physical rounds or 240 seconds**, using completed-round scores at the match limit.
6. A completed guided match grants normal rewards and counts toward progression. REMATCH starts the normal full draft; both humans must agree when playing a human rival. Next opponent returns to the public queue. Direct challenges also use the normal draft. Hangar is always an exit; Sound and Motion controls are available in battle. Exiting an unfinished guide does not mark it completed.

## Version 12 checks — October 10, 2026

Local candidate SHA-256: **`c319c7b95d6f8ca331a4c3fd3d3fd72847aadfc2aa699c906c13c090103da2eb`**. Five changed scripts were synchronized; all **35 cloud script sources** matched UTF-8 FNV checksums and byte lengths, with **zero extra scripts** and no diagnostic flags. This verifies source synchronization, not byte identity between the local XML and Roblox's published native file.

- **Fresh native checks:** **57** cases passed: 44 BattleSimulation and 13 BattleView. [Native results](validation/qa-2026-10-10/version-12-native.json).
- **Offline checks:** **44 simulation**, **5 catalog** and **48 full-server scenarios** passed (15 current battle mode, 33 archived distance mode). [Simulation output](validation/qa-2026-10-10/version-12-simulation.txt), [server output](validation/qa-2026-10-10/version-12-server.txt).
- **Actual desktop input:** completed a three-round guided match, losing **1–2** and receiving **50 session-only coins**. Afterburner and Magnet were selected and locked, including the second, three-card pick. Motion off was verified through the reduced-motion attribute and continued combat. REMATCH opened the normal four-attack, 15-second draft with score **0–0** and fresh armor. [Combat](validation/qa-2026-10-10/version-12-combat-smoke.jpg), [result](validation/qa-2026-10-10/version-12-result-smoke.jpg).
- **Attack-load ring:** a 12-second native client probe observed loaded and unloaded states on both planes. This supplements the visual/input smoke check; it is not a player-comprehension result.
- **Follow-up:** Meteor's approach still overrides its circling target while waiting. Applying the waiting-plane fixture to a Meteor mirror produced nine harmless bumps across four seeds; the existing no-touch circling test covers the other three offences. This remains an incomplete movement behavior to address and recheck for balance.
- **Not repeated for this publication:** a full phone, multiplayer/network or persistence pass. Unfamiliar-player comprehension and subjective motion quality remain open. Studio confirmed publication; earlier local and historical evidence below does not close these gates.

## Historical version 11 checks — October 10, 2026

Local candidate SHA-256: **`e05457cb397d642b7b103ae58912092f5cad4fa140af2e7861720d134a5b91ad`**. All **35 cloud script sources** matched UTF-8 FNV checksums and byte lengths, with **zero extra scripts**. This verifies source synchronization, not byte identity between the local XML and Roblox's published native file.

- **Fresh native checks:** **93** cases passed: 35 BattleMatch, 12 BattleClient, 41 BattleSimulation and 5 SkillCatalog.
- **Server harness:** **48** scenarios passed: 15 current battle-mode scenarios and 33 archived distance-mode regressions. Regressions cover verified fresh and returning profiles, initial load failure and a pending asynchronous load; local session-only guidance still passes.
- **Actual desktop input:** PLAY opened the guided countdown and Meteor/Firework fight; the two-card wild pick, Spring Bumper selection/lock and following coaching were exercised. The final verified-profile guard received a fresh opening smoke check. [Final guided opening](validation/qa-2026-10-10/version-11-guided-smoke.jpg).
- **Not repeated for this publication:** physical-phone, live multiplayer or persistence testing. This desktop smoke check does not validate the three-card guided pick on a phone or unfamiliar-player comprehension. Studio confirmed publication and playtester availability; Creator Dashboard was not refreshed.

## Historical version 7 checks — October 10, 2026

Version 7 was published at **2026-10-10T18:58:42Z** (11:58:42 PDT), from source **`6b4648f`**. Creator Dashboard showed its Published checkmark (last saved 11:57). Its candidate SHA-256 was **`5c94d4dbaeea3e6aee079e0c30ef51cd6b185642bf482aa64278a3074fb1ca14`**. All 35 cloud scripts matched UTF-8 checksums and byte lengths after four script updates; no extra scripts or diagnostic flags remained. The four remotes and Sensor orientation were preserved. Fresh native checks passed **12 BattleView, 11 BattleClient and 32 BattleMatch cases**; Python checks passed **40 simulation, 5 catalog and 44 full-server scenarios** (11 current PvP, 33 archived distance). These were mechanical checks; that republication did not repeat the full visual or two-client playtest. [Detailed evidence](QA-2026-10-10.md#version-7-republication--october-10-2026), [historical dashboard proof](validation/qa-2026-10-10/published-version-7.jpg).

## Earlier full local QA — October 10, 2026

The following five-match and two-client evidence belongs to the earlier `a0c9d9e` candidate, SHA-256 **`b0280d3c5a037e5364d260e488770a0bd84d5c73b1be7fa699c7c32c4f2d80db`**, published as version 6. It is retained as historical evidence, not a fresh visual pass of version 12. See [the full QA round](QA-2026-10-10.md).

- **Visual and normal-input play:** five complete bot matches, four before the QA fixes and one on the final candidate. Desktop, iPhone landscape/portrait emulation and Samsung A06 emulation were inspected. Actual gameplay earned 275 coins, then buying Aurora for 250 left 25; gift, equip, rematch and exit paths were exercised. On the final candidate, a completed loss awarded 50, Blue Comet was claimed/equipped, and a rematch confirmed Reroll, Pick Any and locking Pinball. No normal visual draw was observed in this pass.
- **Mechanical checks:** 200 native Studio checks and 44 full-server scenarios passed. The latter comprise 11 current PvP scenarios and 33 explicitly opted-in archived distance regressions; those archived checks do not make distance mode the default.
- **Networking:** a fresh 10-check run with two real Studio clients passed in **74.66 seconds**, including a three-round match and matching 50/75-coin session awards. Inputs crossed the production remotes programmatically. This is real local client/server evidence, not a two-human GUI playtest or cloud-save proof.

All local progression above was **session-only**. Physical-phone touch/performance, heard audio, two independent accounts playing the published version, live persistence/rejoin, and unfamiliar-player comprehension, fun and balance remain open. Emulation and automated tests do not close those gates. This pass also does not sign off every effect in [the presentation audit](BATTLE-AUDIT.md).

## Local two-client check

In the Studio testing dropdown choose **Server & Clients**, select **2** clients, then press Play or F7. Each fresh Studio pilot must first complete the guided bot match. Return both to the hangar within the same session, then press PLAY within eight seconds of one another. Repeat the pairing, hidden draft, result agreement, rematch and challenge rows below. End Session closes all test instances. See [Roblox testing modes](https://create.roblox.com/docs/studio/testing-modes).

The opt-in scripts in `scripts/qa/SkyBattleNetwork.server.luau` and `.client.luau` produced the historical automated two-client evidence above and are excluded from the packaged place. **They need updating before a current-build rerun:** the fixture assumes immediate public pairing and the old Pick Any/reroll resources. Do not treat an old report as a current pass. After the fixture is updated, temporarily install its server Script in ServerScriptService and client LocalScript in StarterPlayerScripts, then run `print(game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2,"SkyBattleNetworkV1"))` from the Edit command bar. The JSON report ends the test; remove both QA scripts and any temporary guidance override before saving/publishing. This verifies networking with programmatic input, not human UI use or cloud saves. [StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

## Published destination and future updates

The existing limited test destination is **Skybound Test**, start place `86507299893768`, universe `10770074500`; version **12** contains the verified 35-script source from commit `70cc5d22f3a2d1c0d9e4d3037a0a853cfe0df5a8`. For future updates, verify the owner/destination, synchronize and compare the intended candidate, publish to this existing place, then record the new version and UTC time. Do not substitute an old open tab or create a public release. [Roblox publishing/access instructions](https://create.roblox.com/docs/production/publishing/publish-games-and-places). Keep the experience Limited/Playtesters and verify both test accounts have Playtest access; prior access records alone are not proof of today's permissions. No purchases or paid products are required.

Restart existing game servers so both devices load that version. Record each account role, device model, OS, client version and network. Use one real phone and one independently connected desktop or second phone. A Studio client and the device emulator do not meet this gate.

## Two-player and phone pass

| Check | Expected observation | Evidence to record |
| --- | --- | --- |
| Fresh phone entry | PLAY is obvious; verified first-time pilot gets five-second countdown and Meteor/Firework bot fight without an opening pick; first fight target ≤20 seconds after usable lobby | Screen recording; usable→first fight seconds; confusion without external coaching |
| Guided progression | First wild pick has two cards, second has three; 40-second clock, readable coaching and usable Lock; completion gives normal rewards and the next match uses the full draft | Both guided wild stages, reward and next opening |
| Public pairing | After completing guidance, both press PLAY within eight seconds and see each other's correct names/skins | Match/round IDs; both screens; verified returning profiles |
| Hidden picks | Only prior revealed builds show until both lock in a normal match | Both screens before/after reveal |
| Normal offers | All four offences, then all remaining eligible wilds; 15-second clock; no Reroll/Pick Any or duplicate wilds | One offence and two wild stages |
| Complete rivalry | Both clients agree on hits, round winners, score and match end; turning point matches visible event | Winning and losing perspective |
| Draw and caps | At 22s more armor wins; level armor enters sudden death; draw grants no point/pick; ≤35s physical round, ≤5 rounds and ≤240s accepted→terminal | Normal observation plus separate deterministic Studio fixtures |
| Mutual rematch | One vote waits; two votes start fresh builds and normal full-roster picks; decline/exit leaves usable controls | Result→actual next launch time |
| Challenge | Available player receives named Accept/Decline; expiry/cancel/crossing invites/departure cannot force or duplicate a match | Accept, decline, expiry and crossing attempts |
| Departure | Leave during draft and combat; survivor can start another match; leaver rejoins cleanly | Both clients, errors and reward eligibility |
| Phone UI | All cards and controls readable/tappable in landscape and portrait; no clipping or jump/control overlap | Screenshots and model/orientation |
| Combat tells | Identify each offence, hit/miss, block, Magnet and Second Wind; chosen skin stays recognizable | Explain one event without coaching |
| Audio | Hear charge/release/hit, harmless rocket fizzle, result and mute; no oppressive music or masking | Listener judgement and sound/permission errors |
| Progression | Win 75, completed loss/draw 50; first-match cosmetic choice; five qualifying losses reach 250 from zero | Balances, starter claim, goal buy and equip |
| Persistence | Wait for Saved, leave, rejoin: coins, owned/equipped trail and mastery survive; repeat result gives no extra award | Before/after confirmed save; store warnings |
| Accessibility | Motion off suppresses camera shake/flash/confetti; mute stays respected; controls remain usable | Phone capture |
| Performance | Watch several complete matches; note frame stability, thermal slowdown and network stalls | Device model, approximate frame rate, client/server errors |

Studio cap/disconnect fixtures supplement published normal play. Do not spend hours trying to produce a rare cap manually. A regression in result agreement, controls, match cleanup or confirmed reward/cosmetic persistence blocks release.

## First discovery cohort

Recruit 12–20 unfamiliar testers, including phone users and friend pairs. Record recruitment source, new/returning status, bot/human/challenge mode and cohort size. Do not coach the first session. After a round, ask the player to identify one thing that happened and what they might pick next. Observe actual next battle starts after both wins and losses, not just button presses.

Predeclared discovery targets: at least 80% reach a first fight within 20 seconds of a usable screen without help; at least 80% correctly describe the shown turning point; no result disagreements, blocked core controls, stuck matches or lost confirmed grants. These are iteration gates, not established retention benchmarks. Report the largest observed drop-off, then choose one next experiment before collecting another cohort. Next-day return is a separate cohort measure.

## Result record (fill during the published test)

- Candidate build SHA-256: `c319c7b95d6f8ca331a4c3fd3d3fd72847aadfc2aa699c906c13c090103da2eb` (verify against manifest after any rebuild)
- Local candidate path: `/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`
- Published place / universe: `86507299893768` / `10770074500` (Skybound Test)
- Published place version / UTC: **12** / **2026-10-11T02:47:04Z**; Studio success confirmation observed; Creator Dashboard not refreshed ([publication proof](validation/qa-2026-10-10/published-version-12.jpg))
- Published source commit: `70cc5d22f3a2d1c0d9e4d3037a0a853cfe0df5a8` (35 scripts matched UTF-8 FNV checksums and byte lengths; zero extra scripts; the local XML hash is not a published native-file hash)
- Access retained: unchanged; Studio confirmed playtester availability. Last dashboard observation was Limited, Playtesters enabled and Friends disabled; individual test-account access still to verify
- Accounts / roles / fresh or progressed:
- Phone and other device / OS / orientation / network:
- Unfamiliar tester count / recruitment:
- First-launch timing / draft, combat and transition time:
- Wins/losses/draws and actual replay starts:
- Challenge / departure / reconnect observations:
- Saved award / starter cosmetic / 250-coin goal evidence:
- Heard audio judgement / frame stability / errors:
- Largest drop-off / keep-change-drop / next experiment and threshold:

Current observed evidence and remaining blockers are in [the October 10 QA round](QA-2026-10-10.md) and [VALIDATION.md](../VALIDATION.md). Local visual/input play, two-client programmatic checks and publication are recorded separately. The account/device/gameplay/save fields remain empty intentionally until the published test runs. An empty field here is unverified, not a pass.
