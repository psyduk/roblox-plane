# Sky Battle: Milestones 1–2 playtest

This is a free playtest candidate. Milestones 3 and 4, monetization, extra skills, daily rewards and season passes are outside scope. Passing local tests does not close the published/phone or unfamiliar-player gates.

**Current test build:** Skybound Test, place **86507299893768**, universe **10770074500**, published **version 10** at **2026-10-11 00:42:41 UTC** (October 10, 17:42:41 PDT), from source commit **`19350b1`**. Version 10 is version 9 plus [phone layout fixes](QA-2026-10-10.md#version-10-publication--phone-fit). It changes the fight HUD, the draft, round length and Magnet after the first unfamiliar player's feedback. [What changed and what was checked](QA-2026-10-10.md#version-9-publication--first-player-feedback-pass). Steps 3 and 4 below now differ: every pick shows the whole roster with no Reroll or Pick Any, the pick clock is 15 seconds, and a round is decided at 22 seconds with sudden death for level armor.

**Previous test build:** Skybound Test, place **86507299893768**, universe **10770074500**, published **version 7** at **2026-10-10 18:58:42 UTC** (11:58:42 PDT), from source commit **`6b4648f`**. Studio confirmed publication; Creator Dashboard shows version 7 with its Published checkmark (last saved 11:57). Access remains **Limited**, with **Playtesters enabled** and **Friends disabled**. The independent-account, physical-phone and live-save checks below are still unverified. [Publication record](QA-2026-10-10.md#version-7-republication--october-10-2026), [dashboard proof](validation/qa-2026-10-10/published-version-7.jpg).

## Build and launch

1. Run `build/testenv/bin/python scripts/sample_battle.py --tests-only` and `build/testenv/bin/python scripts/test_server.py` from the repository. The optional environment needs `lupa`.
2. Run `python3 scripts/build.py`, then `python3 scripts/validate_package.py --place build/Sky-Battle-Playtest.rbxlx`. Open **`/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`** in Studio. The build refreshes this distinctly named copy and canonical `Skybound.rbxlx` with identical bytes. Stop old play sessions and reopen this exact path after rebuilding; confirm **Sky-Battle-Playtest.rbxlx** in the Studio title. An older `Skybound.rbxlx` window may belong to another worktree. Building does not publish or update an already-open Studio document.
3. Press Studio Play. Use the main PLAY button and visually confirm **rival search → card pick → first-to-two plane battle**. Distance/launch-angle/furthest-flight screens mean the wrong mode or place is running. The public queue waits up to eight seconds, then clearly identifies a practice bot. Choose an offence and LOCK IN; a ten-second deadline chooses the first offered card. Combat runs automatically.
4. Both sides gain one new wild-card pick after each decisive round, up to two. Three armor pips belong to each physical round; two round wins take the match. Draws repeat the same builds with a fresh seed. One free reroll and one free Pick Any last the whole match.
5. Use REMATCH to request the same rival; both humans must agree. Next opponent returns to the public queue. Hangar is always an exit. Sound and Motion controls are available in battle.

## Version 7 checks — October 10, 2026

Current candidate SHA-256: **`5c94d4dbaeea3e6aee079e0c30ef51cd6b185642bf482aa64278a3074fb1ca14`**. All 35 cloud scripts matched UTF-8 checksums and byte lengths after four script updates; no extra scripts or diagnostic flags remained. The four remotes and Sensor orientation were preserved. Fresh native checks passed **12 BattleView, 11 BattleClient and 32 BattleMatch cases**; Python checks passed **40 simulation, 5 catalog and 44 full-server scenarios** (11 current PvP, 33 archived distance). These are mechanical checks; this republication did not repeat the full visual or two-client playtest. [Detailed evidence and remaining presentation checks](QA-2026-10-10.md#version-7-republication--october-10-2026).

## Earlier full local QA — October 10, 2026

The following five-match and two-client evidence belongs to the earlier `a0c9d9e` candidate, SHA-256 **`b0280d3c5a037e5364d260e488770a0bd84d5c73b1be7fa699c7c32c4f2d80db`**, published as version 6. It is retained as historical evidence, not a fresh visual pass of version 7. See [the full QA round](QA-2026-10-10.md).

- **Visual and normal-input play:** five complete bot matches, four before the QA fixes and one on the final candidate. Desktop, iPhone landscape/portrait emulation and Samsung A06 emulation were inspected. Actual gameplay earned 275 coins, then buying Aurora for 250 left 25; gift, equip, rematch and exit paths were exercised. On the final candidate, a completed loss awarded 50, Blue Comet was claimed/equipped, and a rematch confirmed Reroll, Pick Any and locking Pinball. No normal visual draw was observed in this pass.
- **Mechanical checks:** 200 native Studio checks and 44 full-server scenarios passed. The latter comprise 11 current PvP scenarios and 33 explicitly opted-in archived distance regressions; those archived checks do not make distance mode the default.
- **Networking:** a fresh 10-check run with two real Studio clients passed in **74.66 seconds**, including a three-round match and matching 50/75-coin session awards. Inputs crossed the production remotes programmatically. This is real local client/server evidence, not a two-human GUI playtest or cloud-save proof.

All local progression above was **session-only**. Physical-phone touch/performance, heard audio, two independent accounts playing the published version, live persistence/rejoin, and unfamiliar-player comprehension, fun and balance remain open. Emulation and automated tests do not close those gates. This pass also does not sign off every effect in [the presentation audit](BATTLE-AUDIT.md).

## Local two-client check

In the Studio testing dropdown choose **Server & Clients**, select **2** clients, then press Play or F7. In each client press PLAY within eight seconds. Repeat the pairing, hidden draft, result agreement, rematch and challenge rows below. End Session closes all test instances. See [Roblox testing modes](https://create.roblox.com/docs/studio/testing-modes).

The opt-in scripts in `scripts/qa/SkyBattleNetwork.server.luau` and `.client.luau` exercise real client/server remotes automatically. They are excluded from the packaged place. Temporarily install the server file as a Script in ServerScriptService and client file as a LocalScript in StarterPlayerScripts. From an Edit command bar run `print(game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2,"SkyBattleNetworkV1"))`. The JSON report ends the test; remove both QA scripts before saving/publishing. This verifies networking with programmatic input, not human UI use or cloud saves. [StudioTestService reference](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

## Published destination and future updates

The existing limited test destination is **Skybound Test**, start place `86507299893768`, universe `10770074500`; version **7** contains the verified 35-script source from commit `6b4648f`. For future updates, verify the owner/destination, synchronize and compare the intended candidate, publish to this existing place, then record the new version and UTC time. Do not substitute an old open tab or create a public release. [Roblox publishing/access instructions](https://create.roblox.com/docs/production/publishing/publish-games-and-places). Keep the experience Limited/Playtesters and verify both test accounts have Playtest access; prior access records alone are not proof of today's permissions. No purchases or paid products are required.

Restart existing game servers so both devices load that version. Record each account role, device model, OS, client version and network. Use one real phone and one independently connected desktop or second phone. A Studio client and the device emulator do not meet this gate.

## Two-player and phone pass

| Check | Expected observation | Evidence to record |
| --- | --- | --- |
| Fresh phone entry | PLAY is obvious; choose and lock without coaching; first fight target ≤20 seconds after usable lobby | Screen recording; usable→first fight seconds; confusion |
| Public pairing | Both press PLAY within eight seconds and see each other's correct names/skins | Match/round IDs; both screens |
| Hidden picks | Only prior revealed builds show until both lock; resources agree with own use | Both screens before/after reveal |
| Offers | Three distinct eligible cards; reroll changes offer; Pick Any lists all current eligible skills; no duplicate wilds | One offence and two wild stages |
| Complete rivalry | Both clients agree on hits, round winners, score and match end; turning point matches visible event | Winning and losing perspective |
| Draw and caps | Draw grants no point/pick; ≤35s physical round; ≤5 rounds; ≤240s accepted→terminal | Normal observation plus separate deterministic Studio fixtures |
| Mutual rematch | One vote waits; two votes start fresh builds/resources; decline/exit leaves usable controls | Result→actual next launch time |
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

- Candidate source/build hash: `5c94d4dbaeea3e6aee079e0c30ef51cd6b185642bf482aa64278a3074fb1ca14` (verify against manifest after any rebuild)
- Local candidate path: `/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`
- Published place / universe: `86507299893768` / `10770074500` (Skybound Test)
- Published place version / UTC: **7** / **2026-10-10T18:58:42Z**; Studio success confirmation and Creator Dashboard Published checkmark observed (last saved 11:57 PDT)
- Published source commit: `6b4648f774361a3254929bedb5b990f5ecfa2811` (35 scripts matched UTF-8 checksums and lengths; the local XML hash is not a published native-file hash)
- Access retained: Limited; Playtesters enabled; Friends disabled ([publication proof](validation/qa-2026-10-10/published-version-7.jpg)); individual test-account access still to verify
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
