# Plane battle audit — look, sound and feel

Audit date: October 10, 2026. Scope: the plane-versus-plane mode only (the shelved distance flight is ignored). Goal set by the owner: the battle should pop, look and sound impressive, and feel addictive and suspenseful — a hit Roblox game, not a lab tool.

This file is the reference list. Status is updated as items ship; evidence for shipped items belongs in [VALIDATION.md](../VALIDATION.md). Product rules stay in [the Clash design](SKYBOUND-CLASH-DESIGN.md).

## Original audit method

- Played one full default round (Meteor vs Firework, no effects) in Roblox Studio on desktop, from hangar PLAY through results, on the `codex/plane-battles-entry` build.
- Read `BattleView.luau`, `BattleAudio.luau`, `BattleLab.luau` (client and server) and the battle design record.
- Not done in that original audit: listening to the audio (judged from code), phone or portrait layouts, a physical device. The later QA evidence below supersedes only the checks it explicitly covers.

## Owner decisions (October 10, 2026)

| Question | Decision |
| --- | --- |
| Camera | Override the design doc's "stable camera". A dynamic camera that frames the two planes, zooms and shakes is approved. |
| Audio assets | Free Creator Store audio is approved. Use official licensed channels (Pro Sound Effects, APM Music), not arbitrary user uploads. |
| Arena theme | A sky stadium: open sky, clouds, a crowd. |
| Rewards | Add as an audit item (29); not part of the first pass. |
| Interaction | Tap-to-cheer during a fight is acceptable (30). |
| Creative latitude | Full creative freedom on taste; ask when a decision is really the owner's. |

## The five that matter most

1. **The fight is tiny.** The arena fills about 40% of the screen width and each plane about 3–4% of it; the rest is black void. The camera never moves. Frame the two planes instead of the whole field: zoom in when they close, pull out when they separate, punch in on hits.
2. **Hits have no weight.** A hit is ten neon sticks, a ring and a 0.13s flash, with no hit-stop, camera shake, screen flash or debris. The killing blow looks the same as the first. Add a freeze-frame, shake, white flash and real particles, plus slow-motion and a zoom on the knockout.
3. **There is almost no sound.** Eleven battle events are made from four stock Roblox samples, pitch-shifted, at low volume. No music, engine, crowd, countdown beep, timer tick, UI click or victory sting; the countdown is deliberately silent.
4. **Your plane isn't your plane.** The battle always spawns a default cruiser in fixed coral or cyan. The plane, paint and trail chosen in the hangar never appear.
5. **Nothing is at stake.** The seed is fixed, so "Run it again" replays the identical fight. No rewards, no streak, no best-of-three, and the opponent is called "SIM".

## Visuals

6. **World:** replace the navy grid and black slab with a sky arena: parallax clouds, a stadium or crowd, time-of-day lighting, matching the bright chunky hangar.
7. **Post-processing:** no bloom or colour grading in battle. Add bloom so neon glows, and a brief punch on hits.
8. **Damage states:** a plane at one armor looks the same as at three. Add stacking smoke, then fire, sparks and a wobble.
9. **Meteor charge and dive:** the charge shell is 74–96% transparent and barely reads. Make it a growing fireball, then a streak with afterimages and a shockwave on impact.
10. **Firework rocket:** small, with a 0.26s trail. Make it bigger, with a long sparkling trail and a real firework burst in the pilot's colour on hit or fizzle.
11. **Closing wind:** a yellow rectangle with a faint fill. Make it a visible storm wall with streaking particles, darkening edges and lightning.
12. **Knockout and crash:** the fall and ground thud exist but are small. Add a smoke trail down, a bounce, a dust cloud, scattered parts and a camera follow.
13. **Callout text:** "CHARGING" and "HIT!" are 13px Gotham in a dark pill. Use the hangar's cartoon lettering as big pop-in comic words.

## HUD and flow

14. **Entry:** PLAY cuts instantly to the setup screen. Add a takeoff transition and a VS splash with both planes, names and powers.
15. **Countdown:** "LAUNCH IN 1" in the status bar. Make it a full-screen 3-2-1-FIGHT with a beep per number.
16. **Armor:** three 6px bars in the header, far from the action. Put chunky pips over each plane that shatter when lost.
17. **Timer:** small "27 seconds left · Automatic combat" text. Use a big central clock that turns red and pulses in the last ten seconds.
18. **Power select:** two text buttons that cycle ("Meteor ↔"). Reuse the illustrated power-card style from the distance mode.
19. **Results:** a recoloured status bar plus "Change one effect and see what happens." Build a real win/lose screen with the winner posed, confetti, stats and a large REMATCH button.
20. **Language:** remove "Battle Lab", "Simulated opponent", "SIM" and "Automatic combat" from the player-facing path. Give the bot a name and a face.

## Sound

21. **Music:** a battle loop that intensifies when the wind closes, plus win and lose stings; later a hangar loop.
22. **Continuous layers:** an engine drone per plane that pitches with speed, wind, and a crowd that reacts to hits and near misses.
23. **Impact design:** a layered hit (low thump, crunch, high sparkle), a distinct armor-break, and a different, larger knockout sound.
24. **Tension cues:** a heartbeat or alarm at one armor, a tick in the last ten seconds, a storm rumble during pressure.
25. **Stereo position:** all sounds are centred; pan them by where the plane is on screen.
26. **UI sounds:** every button, card select and lock-in.

## Suspense and addiction

27. **Random seed** in the real PLAY path; keep the fixed seed behind a lab toggle.
28. **Best of three** with a "MATCH POINT" banner (already planned in the design doc); the biggest suspense lever.
29. **Rewards:** coins, a win streak with a flame counter, coins flying to the unlock stand as they already do after distance flights.
30. **Tap to cheer:** fights are about 27 seconds hands-off. A tap-to-cheer or emote keeps hands busy without breaking automatic combat.
31. **Near-miss moments:** brief slow-motion and a "CLOSE!" callout when a dive or rocket barely misses.
32. **Firework mirrors** currently trade into repeated draws; needs a tiebreak or tuning before players see it.

## Status

Updated after the full local QA round on October 10, 2026. The original findings above describe the earlier build; this table supersedes their present-tense claims. “Implemented” records source and mechanical checks, not an unobserved visual or listening pass. Current evidence is in [the full QA record](QA-2026-10-10.md), [VALIDATION.md](../VALIDATION.md), [the balance report](BALANCE-REPORT.md), and [the published playtest checklist](SKY-BATTLE-PLAYTEST.md).

The final candidate is **`/Users/andrew/Documents/ChatGPT/color-switch/build/Sky-Battle-Playtest.rbxlx`**, SHA-256 **`b0280d3c5a037e5364d260e488770a0bd84d5c73b1be7fa699c7c32c4f2d80db`**. Open this exact file after rebuilding and confirm its distinct Studio title. The normal PLAY path must show rival search, card picks and a first-to-two plane battle. An old worktree's `Skybound.rbxlx` was the source of the observed distance-mode session; it was not the current PvP candidate.

The fresh mechanical pass completed **200 native Studio checks** and **44 full-server scenarios: 11 current PvP and 33 explicitly opted-in archived distance regressions**. Separately, the opt-in `StudioTestService` run passed **10 checks with two real networked Studio clients in 74.66 seconds**, including a three-round match, agreed outcomes and 50/75-coin awards, gift/equip, mutual rematch, departure cleanup and challenge lifecycle checks. These used **programmatic production-remote inputs** and **session-only** progression. They establish local client/server behavior, not two-human GUI usability, published networking or cloud saving.

The visual/input pass completed **five bot matches: four before the QA fixes and one on the final candidate**, with desktop, iPhone landscape/portrait emulation and Samsung A06 emulation inspected. Normal gameplay earned 275 coins; purchasing Aurora for 250 left 25. Gift, equip, rematch and exit paths were exercised. The final-candidate loss awarded 50, Blue Comet was claimed/equipped, and its rematch confirmed Reroll, Pick Any and locking Pinball. No normal visual draw was observed this pass. These observations do not close the whole effects checklist: heard audio, physical-phone input/performance, published version and independent-account play, live persistence/rejoin, and unfamiliar-player comprehension, fun and balance remain open.

| # | Item | Current implementation and verification |
| --- | --- | --- |
| 1 | Dynamic camera | Attack-led framing and reduced-motion path retained; native view checks pass. Five complete bot matches and desktop/phone-emulated layouts were visually inspected across this QA round. A targeted effect-by-effect camera-quality review and physical-phone judgement remain open. |
| 2 | Hit weight: freeze, shake, flash, particles, knockout slow motion | Implemented with bounded effects and native presentation checks. No new targeted visual sign-off for every impact/knockout effect. |
| 3, 23 | Layered impacts, crowd, countdown beeps | Implemented; native event/voice cleanup checks pass. **Unheard** in this implementation pass; loading/playback events do not establish mix quality. |
| 4 | Player skin, paint, trail and pilot | Implemented with shared skin mount points, preserved aircraft identity and own-seat-first human snapshots. Seat/owner/event mapping passes server checks; the real two-client run verified own/rival identity agreement. Actual two-human appearance/portrait visual agreement remains unverified. |
| 6, 7 | Sky stadium, bloom and grade | Stadium and normal arena flow observed during desktop and phone-emulated QA. This is not physical-device frame-performance evidence or a separate bloom/grade sign-off. |
| 8 | Damage smoke and fire | Implemented at two/one armor and during crash. Native presentation execution passes; targeted current smoke/fire visual readability still needs observation. |
| 9, 11 | Meteor fireball and closing storm | Effects retained alongside readable skill events. No new per-effect visual or physical-phone quality sign-off. |
| 10 | Rocket trail and firework burst | Implemented, plus Machine Gun tracers and skill-specific impact cues. Mechanical event/cleanup checks pass; uncoached phone comprehension remains open. |
| 12 | Knockout and crash | Skin-safe debris fallback, one bounded bounce, smoke and ground cue implemented; native landing/bounce/cleanup cases pass. Complete bot matches reached results visually; the pass does not separately sign off every knockout effect, clip or perceived impact quality. |
| 13 | Comic callout words | Catalog-driven offence/wild-card tells implemented, including the new roster. Native client/view tests pass. Readability of every tell in actual phone combat is unverified. |
| 14 | Entry and rival identity | PLAY searches up to about eight seconds with Cancel, then human pairing or a clearly labelled named bot. Distinct Comet/Pip/Fizz looks persist on rematch; reveal shares the countdown. Normal bot search/draft/countdown and replay/exit were visually exercised; actual two-client public pairing and identity mapping passed through programmatic production remotes. Two-human GUI entry, mutual portrait agreement and published checks remain open. |
| 15 | Countdown | Combined reveal and 3-2-1-FIGHT implemented with synchronized server deadline; observed in Studio. Beeps not evaluated by ear. |
| 16, 17 | Armor, score and timer | Fighter bar shows own/rival identity, armor, cumulative build, score and central clock; MATCH POINT appears before a deciding round. Desktop, iPhone landscape/portrait and Samsung A06 emulation were inspected in the QA pass. Physical-phone combat readability and performance remain release checks. |
| 18 | Draft choices | Hidden simultaneous server offers, three choices, one free reroll and Pick Any per match. Privacy, timeout, resources and invalid/stale commands pass native checks; two real clients verified hidden picks and simultaneous reveal through programmatic inputs. The final-candidate visual rematch confirmed Reroll, Pick Any and locking Pinball. Emulated layouts were inspected; physical touch remains unverified. |
| 19 | Results | Match score, final builds, factual event-backed points, rematch/next opponent/hangar and cosmetic progress implemented. Five complete normal-input bot matches reached results across the QA round; the final-candidate loss showed +50, gift claim/equip and a usable rematch. No normal visual draw was observed; draw/timeout presentation and unfamiliar-human voluntary replay remain open. |
| 20 | Player-facing language | Sky Battle flow uses YOU/RIVAL, named bots explicitly marked BOT, and a challenger name. Internal BattleLab module names are not player-facing. No bot is presented as a person. |
| 21 | Music | Lighter APM “Feel That Move” retained with win/result cues. Native playback cleanup passes. Track, fanfare and overall mix remain **unheard** in this pass; no hangar-loop claim. |
| 22, 25 | Continuous layers and stereo position | Crowd/storm beds exist. A complete engine-per-plane/stereo-panning pass is not established by this build and is not claimed complete. |
| 26 | UI sounds | Draft select/lock, reroll, error and cosmetic action cues wired; mechanical checks pass. Actual listening and perceived loudness remain open. |
| 27 | Fresh round seeds | Implemented: distinct server-owned seed per physical round, draw replay and rematch; server-only Studio pin supports diagnostics. Seed/resource reset tests pass. A different seed does not guarantee a different winner. |
| 28 | First-to-two rivalry | Implemented: synchronized offence → wild → second distinct wild stages, honest draws, 35-second physical round, five-round and 240-second acceptance-to-result caps. Includes wall-clock stall protection. Native orchestration covers 2–0, 2–1, draws, caps, stale commands, cleanup and subsequent matches. The fresh two-client production-remote test completed a three-round match with agreed results and mutual rematch checks; five bot matches completed through normal input across the visual pass. Published rivalry and unfamiliar-human GUI play remain release checks. |
| 29 | Rewards and cosmetic progression | 50 completion/25 win bonus, first-match choice, Aurora Ribbon goal at 250, cosmetic-only mastery, migration and fenced persistence implemented. Five-loss, deduplication, save-failure/reconnect and no instant-forfeit-farm cases pass controlled checks. Visual gameplay earned 275; Aurora purchase cost 250 and left 25. The final-candidate loss awarded 50, followed by Blue Comet claim/equip and rematch. Two real Studio clients confirmed matching 50/75 session awards, gift/equip and reward guards through programmatic production remotes. All observed progression was session-only; live saving/rejoin remains unverified. |
| 30, 31 | Tap-to-cheer and near-miss spectacle | **Outside approved Milestones 1–2.** No work or completion claim for these later enhancements. |
| 32 | Firework mirror draws | Seeded automatic-pilot cadence resolved the sampled mirror lockstep: 99/81/0 wins/losses/draws over 180 angle variants from **20 independent seeds**, versus 180/180 baseline draws. No hidden tiebreak. Other roster draw/cap/balance targets still fail; see the balance report. |
| M1 | Active roster and combat interactions | Four offences / five wild cards with equal human/bot access; Copycat absent. Versioned interaction rules and simultaneous-outcome tests implemented. Automated tuning findings are retained rather than described as proven balance. |
| M2 | Same-server friend challenge | Accept/decline/cancel/expiry, crossing invites, atomic reservation, queue conflict and mutual rematch implemented and covered by orchestration/integration checks. Invitation UI is built; short-landscape list/footer overlap was corrected by source review. Real two-client production-remote run passed challenge decline, acceptance and final lobby cleanup. Human GUI invitation input, real-client expiry/crossing/disconnect and published lifecycle remain unverified. |
| M1–2 | Replay measurement and first session | Versioned funnel records request separately from next actual launch, with outcome/device/cohort/mode context. Native telemetry checks pass. No unfamiliar-player cohort, retention result, listening verdict or physical-phone evidence has been collected. |

## Presentation pass after Milestones 1–2 (October 10, 2026)

The milestone build worked but had flattened the battle's look. A bot match was played on desktop, and at 640×480, iPhone 17 Pro landscape and portrait emulation, before and after; screenshots are `previews/hud-restore-*.jpg`. Sound was not listened to and no physical phone was used.

| Regression found | Now |
| --- | --- |
| Full-width navy bar behind the fighter HUD, 8px armor bars, small Gotham text | No backing. Portrait rings, outlined names, a paint-coloured offence pill, round wild-card chips and chunky armor pips float over the sky; a hit flashes the ring and pips |
| Small clock, "0 — 0" text, "ROUND 1 / 5" | Big outlined clock that turns red and pulses in the last ten seconds; two round-win dots per pilot under it |
| Permanent "FIRST TO TWO / Your pilot fights automatically" strip | One status pill, only while planes fly; hit and bumper callouts returned |
| Flat draft cards on a near-opaque scrim | Illustrated cards with thick outlines, rotated comic word, deal-in and pop on pick; lighter scrim; pulsing LOCK IN |
| Reveal as two navy text boxes, countdown small at the bottom | Skill-coloured VS cards slide in from the sides; centred 3-2-1-FIGHT with pop and fade |
| Results as plain text lines shown at once | Slammed banner for round and match, crown and winner portrait, stat chips, 40-piece confetti, pulsing REMATCH; the match result waits for the crash; coin card has a trail-coloured progress bar |
| Dark indigo cloud blobs and lightning sticks around the closing wind, sky dimmed and desaturated | Removed. Yellow rails, the lilac wind wash and bright inward streaks; the grade stays sunny |
| Bot flew the pilot's own paint (two red planes); side-coloured outlines | A bot never takes the pilot's paint; ink outlines, side colours only for a human paint mirror |
| Hit zoom, Meteor charge shell and rocket fizz toned down | Restored to the earlier audit's weight |

Open after this pass: the 10-second pick timer is tight for a first read of three cards; Machine Gun vs Pinball timed out to a draw twice running in one match; wild-card chips are dropped from the header in phone portrait for lack of room.

Milestones 3 and 4 remain outside scope. Public release/purchases stay gated by [AND-222's published two-player and real-phone run](SKY-BATTLE-PLAYTEST.md); local service doubles, native specs, bot play, two real Studio clients with programmatic input and emulation are supporting evidence only.
