# Sky Battle: Milestones 1–2 playtest

This is a free playtest candidate with the revised loadout draft and expanded power roster. Monetization, daily rewards and season passes remain outside scope. Passing local tests does not close the published/phone or unfamiliar-player gates.

**Current published build:** [Skybound Test](https://www.roblox.com/games/86507299893768/Skybound-Test), place **86507299893768**, universe **10770074500**, published **version 21** at **2026-10-11 07:35:07.714 UTC** (October 11, 00:35:07.714 PDT). Native Studio confirmed publication and offered version notes for v21. Publication preceded the source commit; the recorded candidate hash and source parity identify the published content. [Publication record](validation/legendary-cosmetics-publication-2026-10-11.json).

Version 21 adds **Stormcrown Eagle, Ironwing Eagle, Eclipse Phoenix, and Rift Manta** as free cosmetic planes with animated wings and seated avatar riders, while retaining version 17's eight attacks, twenty wild cards, powers wall, and battle logic. Local candidate SHA-256: **`8e9933e64dd60b6d193a4bc5416b07ad95570bb1bddbae1a1f82eac1f6fe2f5f`**. Before publication, all **37 target-place sources** matched the intended candidate, and all **80 template descendant signatures** matched its properties, attributes, CFrames, and asset IDs across four models and 24 MeshParts. Native checks in that target passed **20 PlaneCatalog, 5 MountVisuals, and 14 BattleView cases**; template preloading reported no failures. This verifies source/template synchronization and publication, not byte identity between local XML and the published native file. [Cosmetic implementation and validation](LEGENDARY-FLIGHT-COSMETICS.md).

The last recorded dashboard access observation was **Limited**, with **Playtesters enabled** and **Friends disabled**. Publication does not establish a fresh live-server gameplay session, independent-account access, physical-phone quality or live saving; those checks below remain unverified.

**Previous recorded publication:** version **17**, published **2026-10-11T06:06:05Z** (October 10, 23:06:05 PDT), from source commit **`76bc8a51d2297f47781587a0aa18e262e95b2cde`**, based on feature commit `21e369a`. Native Studio confirmed publication. Local SHA-256: **`37827f68092a386794ab1fb44234f2006f93702a3889ccb847f723032c357c4e`**. Its 35 cloud sources matched UTF-8 checksums and byte lengths, with zero extra scripts or diagnostic flags, four required remotes and Sensor orientation. [Version 17 publication proof](validation/qa-2026-10-10/published-version-17.jpg). Earlier version 15 and subsequent historical checks are retained below; no intermediate version history is inferred.

## Build and launch

1. Run `build/testenv/bin/python scripts/sample_battle.py --tests-only` and `build/testenv/bin/python scripts/test_server.py` from the repository. The optional environment needs `lupa`.
2. Run `python3 scripts/build.py`, then `python3 scripts/validate_package.py --place build/Sky-Battle-Playtest.rbxlx`. Open **`/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`** in Studio. The build refreshes this distinctly named copy and canonical `Skybound.rbxlx` with identical bytes. Stop old play sessions and reopen this exact path after rebuilding; confirm **Sky-Battle-Playtest.rbxlx** in the Studio title. An older `Skybound.rbxlx` window may belong to another worktree. Building does not publish or update an already-open Studio document.
3. Press Studio Play, then the main PLAY button. A new session-only Studio pilot, or a published pilot whose verified profile has no completed battles, immediately gets a **five-second guided countdown → Meteor versus Firework bot fight**. There is no opening pick. Coaching explains automatic combat, armor and the chosen wild card. Published profiles still loading or unavailable use the normal queue rather than being assumed new. Distance/launch-angle/furthest-flight screens mean the wrong mode or place is running.
4. In the guided match, later loadout picks offer **Meteor and Firework** as attacks, **Spring Bumper and Afterburner** for the first wild slot, then **Spring Bumper, Afterburner and Fizzy Fuel** for two distinct wild slots. Each guided pick allows **40 seconds**. The previous loadout carries forward; tap its attack or wild-slot tile to change that slot, add the missing wild card, then LOCK IN.
5. After completing the guide, normal PLAY waits up to eight seconds for a human, then clearly identifies a practice bot. Normal loadout picks allow **20 seconds** and deal **five of eight attacks and five of twenty wild cards**, always including cards already on the plane. The opening loadout is one attack with no wild slots. Each decisive round that continues the match opens one more wild slot, up to two. Keep or swap any offered attack/wild card using the slot tiles; wild cards must be distinct. LOCK IN submits the whole loadout. The deadline preserves valid choices and fills missing slots from the hand. There is no Reroll or Pick Any. A card first dealt to this pilot carries a **NEW!** badge.
6. Combat runs automatically. Base armor is three; powers can change starting/max armor, damage, size or form, and the HUD reflects that state. Two round wins take the match. At **22 seconds**, more armor wins; level armor enters sudden death until armor differs, with a **35-second hard stop**. A draw repeats the same builds with a fresh seed and no point or new draft. The match ends within **five physical rounds or 240 seconds**, using completed-round scores at the match limit.
7. A completed guided match grants normal rewards and counts toward progression. REMATCH starts a fresh normal loadout draft; both humans must agree when playing a human rival. Next opponent returns to the public queue. Direct challenges also use the normal draft. Hangar is always an exit; Sound and Motion controls are available in battle. Exiting an unfinished guide does not mark it completed.
8. The result screen has a **wall of all 28 powers**. Powers already seen show their icons; unseen powers show **?** and a one-line teaser when tapped. A card counts as seen when dealt, flown or faced. Discovery is stored in the profile; older profiles begin with no discovery record. Studio progression is session-only, and live discovery persistence still needs a save/rejoin check.

## Version 17 powers and checks — October 10, 2026

The eight attacks are **Meteor, Firework, Machine Gun, Pinball, Sniper, Boomerang, Black Hole and UFO Beam**. The twenty wild cards are **Afterburner, Spring Bumper, Fizzy Fuel, Magnet, Second Wind, Squadron, Giant, Eject, Vampire, Chicken, Bug, Snowball, Swap, Gambler, Wrap, Hot Potato, Decoy, Thief, Mothership and Rewind**.

- **Black Hole:** pulls both planes and bends nearby shots; shots reaching its core disappear. After a short arming delay, rival contact breaks one armor and closes the hole. It never damages its owner.
- **UFO Beam:** grabs a nearby unprotected rival, holds it briefly, then throws it toward a wall for one armor of damage. Spring Bumper blocks the wall hit; a beam aimed at a Decoy pops it.
- **Mothership:** makes the plane larger and slower. It launches pairs of drones that carry out its attack instead of attacking directly; Meteor drones ram. Enemy shots can destroy a drone.
- **Rewind:** cancels the first hit and restores the round state from three seconds earlier, including both planes' armor and positions, shots, bombs and stolen cards. The clock, closing walls and event history continue. It works once per plane.
- **Thief and presentation:** when no eligible wild card can be stolen, Thief delays the rival's next attack by 1.5 seconds. HUD chips now follow stolen cards, and the attack label changes to DRONES or PEA-SHOOTER when appropriate. Floating attack/combo words render over the planes; Chicken and the ejected pilot use models built from parts. [Detailed rules and provisional balance measurements](../VALIDATION.md).

**Final checks:** offline checks passed **69 simulation, 6 catalog and 48 server scenarios** (15 current battle mode, 33 explicitly opted-in archived distance). All **69 native simulation** cases passed again after the Meteor-drone and stolen-Rewind fixes. The unchanged modules passed **6 catalog, 14 view, 24 audio, 35 match, 12 client and 52 profile** cases earlier in the same publication pass. Audio checks verify behavior, not heard sound. [Native/source evidence](validation/qa-2026-10-10/version-17-native.json).

Actual desktop input completed a normal bot match using **UFO Beam, Thief and Rewind**, ending **1–2 with +50 session-only coins**. Runtime snapshots captured beam/throw/slam, Rewind and theft of Magnet. The result wall showed **17 of 28 powers found**; clicking the unknown Mothership tile displayed its teaser. This smoke check preceded the two narrow fixes, which received the final regression checks above; Rematch was not retested. It does not verify every power combination or continuous motion of the staged Black Hole/drone effects. The earlier implementation pass also recorded NEW! badges and the powers wall at desktop and 844×390 HUD sizes. Physical-phone touch/performance, heard audio, two independent published players, live saving/rejoining and unfamiliar-player comprehension remain open. Balance remains provisional; the full two-wild-card interaction space has not been signed off.

## Historical version 15 powers and checks — October 10, 2026

Published at **2026-10-11T05:01:10Z** from **`752ed54ca67ff6d223aee88e3fee5f93874ef72e`**, based on feature commit `f952aaa`. Local SHA-256: **`bfdf320737b0ef0b2e312905528be6d0265d1f19a04a3f4aa80434453d32aabf`**. All 35 cloud sources matched with no extra scripts or diagnostic flags, four remotes and Sensor orientation. Studio confirmed publication and playtester availability; dashboard access was not refreshed. [Version 15 publication proof](validation/qa-2026-10-10/published-version-15.jpg).

The attack pool is **Meteor, Firework, Machine Gun, Pinball, Sniper and Boomerang**. Sniper locks its aim before a two-armor shot; Boomerang can hit while going out or returning, then is caught without hurting its owner. Magnet now pulls toward the owner's attack path.

The eighteen wild cards are **Afterburner, Spring Bumper, Fizzy Fuel, Magnet, Second Wind, Squadron, Giant, Eject, Vampire, Chicken, Bug, Snowball, Swap, Gambler, Wrap, Hot Potato, Decoy and Thief**. New behaviors include extra firing planes, changing size/armor, a last-life parachuting pilot, healing on landed hits, temporary chicken form, growing damage, an armor swap, a seeded die roll, wrapping shots, a transferable bomb, decoy targets and stealing one eligible wild card. Thief now clears only the stolen card's state; the rival's retained power keeps working. [Detailed rules and measured limits](../VALIDATION.md).

- **Final offline checks:** **63 simulation**, **5 catalog** and **48 server scenarios** passed, including the Thief regression.
- **Native checks:** the final **63 simulation** cases passed after the Thief fix. The unchanged modules passed **5 catalog, 14 view, 24 audio, 33 match and 11 client** cases before that fix. Audio tests verify behavior, not heard sound. [Native/source evidence](validation/qa-2026-10-10/version-15-native.json).
- **Actual desktop input:** with guidance disabled only in the running Studio session, Boomerang won round one; swapping to **Sniper + Squadron** lost round two; adding **Giant** lost round three. Final result: **1–2**, **50 session-only coins**. This exercised attack swapping, retaining a wild card and adding the second wild slot through the normal draft. REMATCH was clicked and confirmed fresh armor, score **0–0** and no wild cards.
- **Limits:** no phone, heard-audio, live-network or persistence verification for this candidate. The expanded roster has provisional balance samples, not a completed two-card balance pass. Thief's HUD chips still show original cards, mastery currently credits the final loadout, and Squadron + Wrap gives wingman shots an extra second of life beyond the leader's bonus. The prior Meteor waiting-approach and MagnetGrip Motion-off follow-ups remain. Individual rule tests and staged effects do not establish that unfamiliar players understand all new powers.

## Historical version 13 checks — October 10, 2026

Local candidate SHA-256: **`cd3bf4d854a56252f1f4e43aaf51df3c93c0b2b61f156408efeede5953865a1e`**. Eight changed scripts were synchronized; all **35 cloud sources** matched, with **zero extra scripts or diagnostic flags**. The four required remotes and Sensor orientation remained intact. Local XML and published native-file byte identity is not claimed.

- **Fresh checks:** **46 simulation**, **5 catalog** and **48 server scenarios** passed (15 current battle mode, 33 archived distance mode). **84 native checks** passed: 46 simulation, 14 view and 24 audio. Audio tests verify behavior, not how it sounds. [Native results](validation/qa-2026-10-10/version-13-native.json), [simulation/catalog](validation/qa-2026-10-10/version-13-simulation.txt), [server](validation/qa-2026-10-10/version-13-server.txt).
- **Actual mouse input:** selected and locked Pinball, completed a two-round bot win **2–0** with **75 session-only coins**, then rematched into the normal four-attack, 15-second draft with full armor and score **0–0**. Magnet was highlighted near the wild-pick deadline, but the final build contained **Afterburner**; this does not verify a Magnet lock. [Result](validation/qa-2026-10-10/version-13-result-smoke.jpg).
- **Runtime evidence:** a read-only client probe observed a visible Pinball projectile, bounce/hit events and Magnet/Afterburner skill events. The Magnet beam was not observed. No game-script errors appeared. A runtime-only `BattleGuidedFirstMatch=false` override allowed the normal Pinball draft; it disappeared after Stop, and Edit was verified free of diagnostic flags before publication.
- **Follow-ups and limits:** Pinball plus Magnet remains a weak combination; several two-card builds exceed the quick balance threshold. MagnetGrip still animates with Motion off, and the earlier Meteor waiting-approach issue remains. No physical-phone, live-network, persistence or heard-audio retest was performed.

## Historical version 12 checks — October 10, 2026

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

The following five-match and two-client evidence belongs to the earlier `a0c9d9e` candidate, SHA-256 **`b0280d3c5a037e5364d260e488770a0bd84d5c73b1be7fa699c7c32c4f2d80db`**, published as version 6. It is retained as historical evidence, not a fresh visual pass of the latest candidate. See [the full QA round](QA-2026-10-10.md).

- **Visual and normal-input play:** five complete bot matches, four before the QA fixes and one on the final candidate. Desktop, iPhone landscape/portrait emulation and Samsung A06 emulation were inspected. Actual gameplay earned 275 coins, then buying Aurora for 250 left 25; gift, equip, rematch and exit paths were exercised. On the final candidate, a completed loss awarded 50, Blue Comet was claimed/equipped, and a rematch confirmed Reroll, Pick Any and locking Pinball. No normal visual draw was observed in this pass.
- **Mechanical checks:** 200 native Studio checks and 44 full-server scenarios passed. The latter comprise 11 current PvP scenarios and 33 explicitly opted-in archived distance regressions; those archived checks do not make distance mode the default.
- **Networking:** a fresh 10-check run with two real Studio clients passed in **74.66 seconds**, including a three-round match and matching 50/75-coin session awards. Inputs crossed the production remotes programmatically. This is real local client/server evidence, not a two-human GUI playtest or cloud-save proof.

All local progression above was **session-only**. Physical-phone touch/performance, heard audio, two independent accounts playing the published version, live persistence/rejoin, and unfamiliar-player comprehension, fun and balance remain open. Emulation and automated tests do not close those gates. This pass also does not sign off every effect in [the presentation audit](BATTLE-AUDIT.md).

## Local two-client check

In the Studio testing dropdown choose **Server & Clients**, select **2** clients, then press Play or F7. Each fresh Studio pilot must first complete the guided bot match. Return both to the hangar within the same session, then press PLAY within eight seconds of one another. Repeat the pairing, hidden draft, result agreement, rematch and challenge rows below. End Session closes all test instances. See [Roblox testing modes](https://create.roblox.com/docs/studio/testing-modes).

The opt-in scripts in `scripts/qa/SkyBattleNetwork.server.luau` and `.client.luau` produced the historical automated two-client evidence above and are excluded from the packaged place. **They need updating before a current-build rerun:** the fixture assumes immediate public pairing and the old Pick Any/reroll resources. Do not treat an old report as a current pass. After the fixture is updated, temporarily install its server Script in ServerScriptService and client LocalScript in StarterPlayerScripts, then run `print(game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2,"SkyBattleNetworkV1"))` from the Edit command bar. The JSON report ends the test; remove both QA scripts and any temporary guidance override before saving/publishing. This verifies networking with programmatic input, not human UI use or cloud saves. [StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

## Published destination and future updates

The existing limited test destination is **Skybound Test**, start place `86507299893768`, universe `10770074500`; version **21** contains the verified 37-script candidate and four cosmetic templates described above. For future updates, verify the owner/destination, synchronize and compare the intended candidate, publish to this existing place, then record the new version and UTC time. Do not substitute an old open tab or create a public release. [Roblox publishing/access instructions](https://create.roblox.com/docs/production/publishing/publish-games-and-places). Keep the experience Limited/Playtesters and verify both test accounts have Playtest access; prior access records alone are not proof of today's permissions. No purchases or paid products are required.

Restart existing game servers so both devices load that version. Record each account role, device model, OS, client version and network. Use one real phone and one independently connected desktop or second phone. A Studio client and the device emulator do not meet this gate.

## Two-player and phone pass

| Check | Expected observation | Evidence to record |
| --- | --- | --- |
| Fresh phone entry | PLAY is obvious; verified first-time pilot gets five-second countdown and Meteor/Firework bot fight without an opening pick; first fight target ≤20 seconds after usable lobby | Screen recording; usable→first fight seconds; confusion without external coaching |
| Guided progression | Two attack options; first wild hand has two cards, second has three; 40-second clock, readable coaching and usable slot tiles/Lock; completion gives normal rewards and the next match uses the normal draft | Both guided wild stages, reward and next opening |
| Public pairing | After completing guidance, both press PLAY within eight seconds and see each other's correct names/skins | Match/round IDs; both screens; verified returning profiles |
| Hidden picks | Only prior revealed builds show until both lock in a normal match | Both screens before/after reveal |
| Normal offers | Five attacks and five wild cards dealt from pools of eight/twenty; held cards remain offered; 20-second clock; no Reroll/Pick Any or duplicate wilds | Opening attack, both wild slots, attack swap and wild replacement |
| Complete rivalry | Both clients agree on hits, round winners, score and match end; turning point matches visible event | Winning and losing perspective |
| Draw and caps | At 22s more armor wins; level armor enters sudden death; draw grants no point/pick; ≤35s physical round, ≤5 rounds and ≤240s accepted→terminal | Normal observation plus separate deterministic Studio fixtures |
| Mutual rematch | One vote waits; two votes start fresh builds and a normal five-attack hand with no wild slots; decline/exit leaves usable controls | Result→actual next launch time |
| Challenge | Available player receives named Accept/Decline; expiry/cancel/crossing invites/departure cannot force or duplicate a match | Accept, decline, expiry and crossing attempts |
| Departure | Leave during draft and combat; survivor can start another match; leaver rejoins cleanly | Both clients, errors and reward eligibility |
| Phone UI | All cards and controls readable/tappable in landscape and portrait; no clipping or jump/control overlap | Screenshots and model/orientation |
| Combat tells | Identify attacks, multi-armor hits, blocks, changed forms, bomb holder, decoy, stolen card, beam throw, drones and Rewind; chosen side stays recognizable | Explain one event and current loadout without coaching |
| Power discovery | First-dealt cards show NEW!; dealt/flown/faced powers appear on the 28-power result wall; unseen powers show a tappable teaser | Before/after count, teaser and next-draft badges on phone |
| Audio | Hear charge/release/hit, harmless rocket fizzle, result and mute; no oppressive music or masking | Listener judgement and sound/permission errors |
| Progression | Win 75, completed loss/draw 50; first-match cosmetic choice; five qualifying losses reach 250 from zero | Balances, starter claim, goal buy and equip |
| Persistence | Wait for Saved, leave, rejoin: coins, owned/equipped trail, mastery and discovered powers survive; repeat result gives no extra award | Before/after confirmed save; store warnings |
| Accessibility | Motion off suppresses camera shake/flash/confetti; mute stays respected; controls remain usable | Phone capture |
| Performance | Watch several complete matches; note frame stability, thermal slowdown and network stalls | Device model, approximate frame rate, client/server errors |

Studio cap/disconnect fixtures supplement published normal play. Do not spend hours trying to produce a rare cap manually. A regression in result agreement, controls, match cleanup or confirmed reward/cosmetic persistence blocks release.

## First discovery cohort

Recruit 12–20 unfamiliar testers, including phone users and friend pairs. Record recruitment source, new/returning status, bot/human/challenge mode and cohort size. Do not coach the first session. After a round, ask the player to identify one thing that happened and what they might pick next. Observe actual next battle starts after both wins and losses, not just button presses.

Predeclared discovery targets: at least 80% reach a first fight within 20 seconds of a usable screen without help; at least 80% correctly describe the shown turning point; no result disagreements, blocked core controls, stuck matches or lost confirmed grants. These are iteration gates, not established retention benchmarks. Report the largest observed drop-off, then choose one next experiment before collecting another cohort. Next-day return is a separate cohort measure.

## Result record (fill during the published test)

- Candidate build SHA-256: `8e9933e64dd60b6d193a4bc5416b07ad95570bb1bddbae1a1f82eac1f6fe2f5f` (verify against manifest after any rebuild)
- Local candidate path: `/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`
- Published place / universe: `86507299893768` / `10770074500` (Skybound Test)
- Published place version / UTC: **21** / **2026-10-11T07:35:07.714Z**; native Studio success confirmation observed ([publication record](validation/legendary-cosmetics-publication-2026-10-11.json))
- Published source: the working tree at publication time, before the source commit (37 sources and 80 template descendant signatures matched the candidate; the local XML hash is not a published native-file hash)
- Access: last dashboard observation was Limited, Playtesters enabled and Friends disabled; individual test-account access still to verify
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
