# Wild cards that change your plane: Squadron, Giant, Eject, Vampire, Chicken — October 10, 2026 (not committed, not published)

Playtest feedback: the powers do not feel different, and nothing makes a player curious about what else exists. Direction from the owner: add powers that change what the plane is or break a rule (Linear AND-233). This is the first five of nineteen.

**Rules**
- **Squadron:** three small planes, one per armor left. Every plane fires the attack and every plane can be hit.
- **Giant:** 1.9× size, 4 armor, 0.78× speed, 1.7× shot size.
- **Eject:** at zero armor the pilot bails out once with 1 life, a pea-shooter, a parachute-sized hitbox and half speed.
- **Vampire:** starts with 2 armor; every hit landed adds 1 (up to 5). A parachuting pilot is never healed.
- **Chicken:** the first hit landed turns the rival into a chicken for 3 s; a chicken cannot wind up or attack.
- A build that matches a named pair (15 so far, such as "VAMPIRE SWARM!") is named on its reveal card.
- The roster now has 10 wild cards. Each pick deals 5: the cards already on the plane plus a random draw from the rest.
- The HUD shows up to 5 armor pips.

**Measured (40 seeds, both seats, against every attack with no wild card)**

| Card | Score | Existing cards for comparison |
|---|---|---|
| Squadron | 54% | Afterburner 66% |
| Giant | 57% | Spring Bumper 63% |
| Eject | 66% | Magnet 61% |
| Vampire | 55% | Fizzy Fuel 61% |
| Chicken | 61% | Second Wind 60% |

Pairs checked: Eject + Vampire 66%, Eject + Giant 66%, Giant + Spring Bumper 72%, Chicken + Magnet 72%; the strongest existing pair (Afterburner + Spring Bumper) is 71%. First drafts that were out of range and were changed: Giant at 5 armor (77%), Eject with a small hitbox (83%), Eject + Vampire with healing (80%), Chicken that shortened the rival's wait (46%).

**Checks run**
- `scripts/sample_battle.py --tests-only`: 52 simulation tests (6 new) and 5 catalog tests pass.
- `scripts/test_server.py`: 33 match, 11 client and 48 server scenarios pass.
- Native Studio: 52 simulation, 14 view and 24 audio tests pass.
- Three staged fights watched in local Studio at desktop size, driven by the real simulation: Squadron formation and its two tracer lines, the Giant and its oversized ball, the chicken, the parachute and pea-shot, 4 armor pips, and combo names on the reveal cards all appeared (`previews/planes-eject.jpg`).

**Not verified**
- Nothing was heard: the new sounds are existing samples re-pitched, and there is no real chicken cluck.
- No full match through the real draft with these cards, no phone-sized check, no human opponent.
- The combo name did not appear over the plane in the arena; only the reveal card shows it.
- The HUD attack label still shows the plane's attack words (for example "DIVE!") after the pilot ejects.
- Squadron with Machine Gun can put more tracers in the air than the 24 the view draws.
- The chicken and parachute are emoji pictures in place of the plane, not models.

# A loadout you keep and can swap every round — October 10, 2026 (not yet published)

Playtest feedback: a young pilot could not tell which attack or wild card he had picked, or whether a pick still applied in rounds two and three. Before this change the attack was chosen once and could never change, each wild card was chosen once, and the only record of either was a small pill and emoji-only chips in the top bar.

**Rules**
- Before every round each pilot sets up a whole plane: **one attack, plus one wild card slot for each decisive round played** (none in round one, one after the first decisive round, two after the second).
- Everything already on the plane stays there. **Any slot can be swapped before any round**, attack included, and one wild card cannot fill two slots.
- Each pick starts from the plane that just flew, so a pilot who only wants the new card taps it and locks, as before. The pick clock is 20 s (was 15 s).
- A pilot who runs out of time keeps whatever they tapped; only empty slots are filled, with the first offered card. (Before, the deadline replaced a tapped card with the first one.)
- A drawn round still replays at once with the same planes. A bot keeps its plane and adds one random wild card per round.
- The guided first match is unchanged in shape; its later picks offer Meteor/Firework and the same small wild card hands.
- The unused random-hand draft (reroll, Pick Any, hand size) was removed from server, client and tests.

**Screen**
- The pick screen has a **loadout bar**: a named tile for the attack and for each wild card slot. The tile being changed is lit; the others say "TAP TO SWAP". The cards below belong to the lit slot, and a wild card in the other slot is dimmed and marked as already on the plane.
- The pilot's own plate in the top bar shows the plane as it is being built.
- In the top bar, **wild cards now show their names** next to the attack whenever the plate has room (desktop and a phone on its side); an upright phone keeps the icon badges.
- The countdown reveal shows each pilot's whole plane (attack name plus wild card icons) and is titled "PLANES REVEALED!".

- **Checks:** 33 match cases (4 obsolete random-hand cases removed; new or rewritten cases for carrying the plane, swapping every slot, doubled and short loadouts, the deadline, the bot and the guided hands), 11 client cases (2 new), 48 server scenarios, simulation and catalog suites unchanged and passing. In local Studio the 33 match and 11 client cases pass natively. Two live bot matches (desktop and 812×375) and one guided match were played through the new picker, including an attack swap in round two, with no script errors. The two-slot round-three screen was driven with a server-sent snapshot at desktop, 812×375 and 390×780. [Adding a wild card](previews/loadout-1-add-wild-card.jpg), [round three](previews/loadout-2-round-three-swap.jpg), [upright phone](previews/loadout-3-phone-portrait.jpg), [phone on its side](previews/loadout-4-phone-landscape.jpg), [names in the fight](previews/loadout-5-fight-hud.jpg).
- **Not checked:** a real round-three pick in a live match (both live matches ended 2–0), a real phone, two human clients, and whether free attack swaps change which attacks win (the sampler measures fixed builds only). Scripted taps on the slot tiles were sometimes dropped by Studio's input injection (press with no release in the event log); when both events arrived the tile always responded.

# Version 13 publication — distinct powers, October 10, 2026

**Skybound Test version 13 is published**, place `86507299893768`, universe `10770074500`, at **2026-10-11T03:24:05Z** (October 10, 20:24:05 PDT), from **`fc2cb0b86897ff77f89c511fab6572f6915d41a5`**. Studio confirmed publication and Playtester availability; access settings were unchanged. [Publication proof](docs/validation/qa-2026-10-10/published-version-13.jpg), [current manifest](docs/validation/sky-battle-build.json).

Fresh publication checks passed **46 simulation, 5 catalog and 48 server scenarios**, plus **84 native Studio checks** (46 simulation, 14 view, 24 audio). All 35 cloud sources matched UTF-8 FNV checksums and byte lengths after eight script updates, with zero extra scripts/diagnostic flags, four remotes and Sensor orientation. Local XML SHA-256: `cd3bf4d854a56252f1f4e43aaf51df3c93c0b2b61f156408efeede5953865a1e`; native artifact byte identity is not claimed. [Native/source/probe evidence](docs/validation/qa-2026-10-10/version-13-native.json), [server](docs/validation/qa-2026-10-10/version-13-server.txt), [simulation/catalog](docs/validation/qa-2026-10-10/version-13-simulation.txt).

Actual desktop input selected/locked Pinball, completed a two-round 2–0 bot win with +75 session-only coins, and rematched into a fresh four-attack draft with 15 seconds, full armor and 0–0 score. Read-only client observation captured a visible Pinball ball and ricochet/bounce/hit events. A runtime-only server guidance override enabled this normal draft; stopping Play discarded it and the final Edit place had no overrides. No game-script errors appeared. [Match result](docs/validation/qa-2026-10-10/version-13-result-smoke.jpg). Audio tests did not play real sound. Physical phone, live multiplayer/persistence and full balance were not retested.

Publication follow-ups: the balance concerns below remain open; MagnetGrip continues animating with Motion off in source review. The smoke highlighted Magnet near the pick deadline, but the final build used Afterburner; this does not establish a successful Magnet lock and warrants a focused last-second selection check. The implementation measurements below precede this publication pass.

Playtest feedback was that the powers do not feel powerful or different. Measured before this change: Pinball and Meteor were both "back off, then ram at speed 65", and three of five wild cards had no visible moment (single-card lift: Afterburner 0, Fizzy Fuel +2.5, Magnet +5.5, Second Wind +9.5, Spring Bumper +15 points).

**Rules**
- **Pinball** no longer rams. The plane swells a ball on its nose, aims at the rival's reflection in the nearest wall and fires. The ball bounces off the arena edges up to three times and removes one armor on contact.
- **Afterburner (rush):** after its owner attacks, the plane jets away at 56 (was 44) and its trip back to the next attack is 5% shorter. Larger hurry values made it the automatic pick (+22 points at 10%).
- **Spring Bumper (block):** unchanged block; the recoil that delays the next attack is 1.4 s (was 0.7 s).
- **Fizzy Fuel (trap):** each attack lays a wall of up to six clouds, radius 3.6 (was 2.5), that hang for 2.2 s (was 0.9 s).
- **Magnet (pull):** yanks only the rival toward the owner at 30 studs/s for 0.8 s. Before, both planes drifted together at 7.
- **Second Wind (comeback):** rule unchanged.
- **Every hit** throws the target at 36 (was 22). Machine Gun `earliest` 1.0 → 0.95, Pinball 1.7 → 1.15 with default approach and recovery times.

**Look and sound.** Each power has its own colour, effect and sound: Pinball's electric-blue ball with a wide trail, a flash and ping on every wall, and an arcade smack on a hit; Afterburner's long blue jet and ignition roar; Spring Bumper's lime ring, boing and clang; Fizzy Fuel's bubbling green clouds, hiss and wet pop; Magnet's pink beam with a ring clamped on the rival and a falling hum; Second Wind's green aura, thunder and crowd. Hits have more sparks, shake, freeze and a sub-bass thump, and each attack's hit looks different.

**Numbers** (standard sampler, 30 seeds, 8,640 bare rounds): Meteor 48.9%, Firework 50.6%, Machine Gun 51.5%, Pinball 49.0%. Single-card lift (10 seeds, one angle): Afterburner +13.3, Spring Bumper +13.0, Second Wind +10.0, Fizzy Fuel +8.3, Magnet +7.2 points.

- **Checks:** 46 simulation tests (4 new or rewritten for the ball, bounces, the yank and the rush), 5 catalog, 35 match, 12 client, 48 server scenarios. In local Studio: 46 simulation, 14 view (1 new: ball, beam, jet and aura each show only when active) and 24 audio tests pass natively. One three-round bot match was played with Pinball, Magnet and Fizzy Fuel, with no script errors. [Ball after a wall bounce](previews/distinct-powers-1-pinball-ball.jpg), [aiming](previews/distinct-powers-2-pinball-aiming.jpg).
- **Magnet follow-up (same day):** Magnet made Pinball about 10 points worse, because the yank dragged the rival off the banked shot. It now pulls the rival toward the owner's nearest shot in the air (45 studs/s), or toward the owner's plane when there is none (14 studs/s), and the beam is drawn from whichever is pulling. Single-card lift for Magnet is now Meteor +13.8, Firework +3.8, Machine Gun +16.3, Pinball +8.8 (10 seeds, one angle). 46 simulation and 14 view tests pass natively.
- **Known problems:** Several two-card builds exceed 65% against bare planes in the quick sample. Balance remains timing-sensitive: a 0.05–0.15 s change to one attack's `earliest` moves its field score by 5–15 points.
- **Not checked:** how any of it sounds (no audio was heard), the Magnet beam, cloud wall, jet and aura on screen in a live fight (stills did not catch them; the native view test covers them), a phone, two human clients.

---

# Version 12 publication — circle, then strike, October 10, 2026

**Skybound Test version 12 is published**, place `86507299893768`, universe `10770074500`, at **2026-10-11T02:47:04Z** (October 10, 19:47:04 PDT). Source commit: **`70cc5d22f3a2d1c0d9e4d3037a0a853cfe0df5a8`**, containing implementation `a4f2546`. Studio confirmed publication and Playtester availability. Access settings were unchanged. [Publication proof](docs/validation/qa-2026-10-10/published-version-12.jpg), [current manifest](docs/validation/sky-battle-build.json).

Fresh publication checks passed **44 simulation, 5 catalog and 48 full-server scenarios** (15 battle mode, 33 archived distance), plus **57 native Studio checks** (44 simulation and 13 view). All **35 cloud sources** matched UTF-8 FNV checksums and byte lengths after five script updates, with zero extra scripts, no diagnostic overrides, four required remotes and Sensor orientation. Local XML SHA-256: `c319c7b95d6f8ca331a4c3fd3d3fd72847aadfc2aa699c906c13c090103da2eb`; published native-file byte identity is not claimed. [Native/source evidence](docs/validation/qa-2026-10-10/version-12-native.json), [server](docs/validation/qa-2026-10-10/version-12-server.txt), [simulation/catalog](docs/validation/qa-2026-10-10/version-12-simulation.txt).

Actual desktop clicks completed a three-round guided match: Afterburner and Magnet picks/locks, loss 1–2, +50 session-only coins, then REMATCH to the normal four-attack draft with a 15-second clock, full armor and 0–0 score. Both planes' loaded/unloaded gauge states were observed. Motion off was confirmed in client state and combat remained usable. No game-script errors appeared. [Combat](docs/validation/qa-2026-10-10/version-12-combat-smoke.jpg), [result](docs/validation/qa-2026-10-10/version-12-result-smoke.jpg). Physical phone, published multiplayer, live saving and full balance were not retested.

**Known movement follow-up:** Meteor's custom approach can override its waiting orbit target. Review reproduced harmless bumps in a fixture with an artificially prolonged waiting phase; the existing circling regression excludes Meteor. This build improves general movement but does not establish that every waiting Meteor circles. The implementation measurements below predate this publication smoke test.

The owner reported that planes kept flying at each other and colliding with nothing happening. Measured over 400 bare rounds: about 7.2 harmless bumps and 3.9 hits per round, and 2.8 of 5.4 close passes ended with no damage. The cause was the wait between attacks: a plane with nothing to fire flew straight at its rival.

- **Movement:** a plane that cannot attack yet now circles its rival (both the same way round) and peels off if it gets within 24 studs. It turns in only once its attack is loaded. Planes banking away after a hit split up and down. A collision during impact protection is no longer announced as a bump.
- **Opening:** each plane now gets its own seeded opening timing. Before, both shared one value, so the same attack always struck first.
- **Timing retune** (`earliest`): Meteor 1.45 → 1.85, Firework 1.05 → 1.1, Pinball 1.6 → 1.7, Machine Gun unchanged at 1.0.
- **On the plane:** a ring fills piece by piece while a plane circles and snaps full and bright when its attack is loaded.

| Per round (400 bare rounds) | Before | After |
|---|---:|---:|
| Harmless bumps | 7.2 | 0.8 |
| Hits | 3.9 | 4.1 |
| Close passes with no damage | 2.8 | 1.3 |
| Longest stretch without a hit | 8.0 s | 6.8 s |
| Round length | 19.9 s | 18.2 s |

Field scores from the standard sampler (30 seeds, 8,640 rounds): Meteor 52.0%, Firework 48.5%, Machine Gun 50.4%, Pinball 49.1% (version 9 record: 48.6 / 44.2 / 54.2 / 53.0). The widest pairing is still Machine Gun over Firework, about 65–68%. A quick wild-card pass (6 seeds, one angle) showed no full build above 65% against bare planes.

- **Checks:** 44 simulation tests (3 new; the Meteor charge test is now a placed fixture that does not depend on timing values), 5 catalog, 35 match, 12 client and 48 full-server scenarios pass. In local Studio: 44 simulation and 13 view tests (1 new, the gauge) pass natively, and one guided bot round was played with the gauge visible and no script errors. [Gauge filling](previews/circle-then-strike-1-gauge.jpg), [loaded](previews/circle-then-strike-2-loaded.jpg).
- **Not checked:** whether it feels better to a player (stills cannot show motion), a phone, two human clients, and a full wild-card balance sample.

---

# Version 11 publication — guided first match, October 10, 2026

**Skybound Test version 11 is published**, place `86507299893768`, universe `10770074500`, from source commit **`27a71f8bf36447342f4e27adf255945bac2c3f6c`**. Studio confirmed publication and Playtester availability at **2026-10-11T01:19:15Z** (October 10, 18:19:15 PDT). [Publication proof](docs/validation/qa-2026-10-10/published-version-11.jpg), [current manifest](docs/validation/sky-battle-build.json). Access settings were unchanged; the dashboard was not rechecked. All entries below this section describe earlier candidates.

A pilot with no completed battles now gets one guided match. PLAY skips the queue and starts against a bot. Round one has no pick: the pilot is dealt Meteor, the bot Firework (46% for Meteor over 180 sampled rounds, no draws). The first wild-card pick offers two cards (Spring Bumper, Afterburner), the second offers three, and the pick clock is 40 seconds instead of 15. A sentence at the bottom of the screen says what to watch for. The match pays the normal rewards and counts as the first match; every later match uses the full draft. Challenges, returning pilots and experimental rosters are never guided. `BattleGuidedFirstMatch=false` on the server script turns it off. Telemetry records these matches with mode `practice`.

- **Profile eligibility fixed before publication:** a pending or failed profile load no longer treats placeholder zero matches as a verified new pilot. Three new server regressions cover loaded new/returning players, failed initial loads and deferred loads. Both failure regressions reject the previous guard.
- **Fresh checks:** 93 native Studio checks (35 match, 12 client, 41 simulation and 5 catalog) and 48 full-server scenarios (15 current battle mode, 33 archived distance) pass. All 35 cloud sources match the local package by UTF-8 FNV checksum and byte length, with zero extra scripts, no diagnostic overrides, four required remotes and Sensor orientation. Local XML SHA-256: `e05457cb397d642b7b103ae58912092f5cad4fa140af2e7861720d134a5b91ad`. Native artifact byte identity is not claimed. [Native and source evidence](docs/validation/qa-2026-10-10/version-11-native.json), [server output](docs/validation/qa-2026-10-10/version-11-server.txt).
- **Seen in local Studio play** with real clicks, three complete guided matches (two wins, one loss), no script errors: desktop, and the battle UI laid out at 390×780 and 780×360. [Watch](previews/guided-first-match-1-watch.jpg), [armor](previews/guided-first-match-2-armor.jpg), [two cards](previews/guided-first-match-3-two-cards.jpg), [watch for your card](previews/guided-first-match-4-watch-for.jpg), [phone pick](previews/guided-first-match-5-phone-pick.jpg).
- **Publication smoke:** actual desktop clicks opened the guided fight, selected Spring Bumper from the first two-card pick and locked it, then showed its coaching text in combat. A fresh Play after the final eligibility fix again opened the guided fight and reached the round result without game-script errors. [Final-build combat screenshot](docs/validation/qa-2026-10-10/version-11-guided-smoke.jpg).
- **Not rechecked in this publication pass:** physical phone, device emulator, published multiplayer, live persistence, heard audio or unfamiliar-player comprehension. The earlier guided-layout checks above sized the battle UI directly; the three-card second pick still lacks visual observation. `publishedAndRealPhoneVerified=false`.

---

# Version 7 republication — October 10, 2026

**Skybound Test version 7 published successfully** to the same place `86507299893768`, universe `10770074500`, at **2026-10-10T18:58:42Z** (11:58:42 PDT). Creator Dashboard showed version 7 with its Published checkmark and last-saved time 11:57. Source commit: **`6b4648f774361a3254929bedb5b990f5ecfa2811`**. Current package SHA-256: **`5c94d4dbaeea3e6aee079e0c30ef51cd6b185642bf482aa64278a3074fb1ca14`**. [Publication proof](docs/validation/qa-2026-10-10/published-version-7.jpg), [manifest](docs/validation/sky-battle-build.json), [checks and limitations](docs/QA-2026-10-10.md#version-7-republication--october-10-2026).

The four changed packaged scripts were updated; all **35 cloud sources** matched UTF-8 FNV checksums and byte lengths, with **zero extra scripts**. Diagnostic gameplay flags remained absent; all four remotes and Sensor orientation were preserved. Fresh isolated native checks passed **12 BattleView, 11 BattleClient and 32 BattleMatch cases**. Python passed **40 simulation, 5 catalog and 44 full-server scenarios** (11 current PvP, 33 archived distance). This is targeted mechanical verification, not a repeat of the earlier full visual/input or two-client round.

Physical-phone, audio, independent-account gameplay, live persistence/rejoin and unfamiliar-player/balance gates remain open; `publishedAndRealPhoneVerified=false`. The QA record also retains the minor reduced-motion card bounce and unverified A06 landscape Pick Any readability. Version 6 and its broader local QA evidence below are historical; native-artifact byte identity is still not claimed.

---

# Limited-test publication — October 10, 2026

**Historical version 6 publication:** Skybound Test was published to place `86507299893768`, universe `10770074500`, at **2026-10-10T18:14:58Z** (11:14:58 PDT). Native Studio confirmed publication and Playtester availability; Creator Dashboard showed version 6 at 11:14, following the version 5 autosave at 11:13. Access was confirmed **Limited**, **Playtesters enabled**, **Friends disabled**. Source commit **`a0c9d9eafa08a9bc5624641837ee59c824b3021d`** was committed and pushed before publication. [Historical publication details](docs/QA-2026-10-10.md#limited-test-publication--october-10-2026), [dashboard evidence](docs/validation/qa-2026-10-10/published-version-6.jpg). Version 7 above is now current.

The existing cloud place was updated and published directly after Publish As stalled before upload. All 35 script sources matched the verified candidate; remotes, clean gameplay attributes, empty authored world, Sensor orientation and native visual lighting properties were checked. Protected `RBX_OriginalTechnologyOnFileLoad` metadata remains cloud `1` versus reference `2`, so the published native artifact is not claimed byte-identical to the reference or local XML. The local XML SHA-256 remains `b0280d3c5a037e5364d260e488770a0bd84d5c73b1be7fa699c7c32c4f2d80db`.

This publication update supersedes earlier “unpublished” or “no commit/push” handoff statements below. It does **not** convert local session-only tests into published gameplay or saving proof: physical phone, heard audio, two independent accounts, confirmed live persistence/rejoin and unfamiliar-player/balance gates remain open. `publishedAndRealPhoneVerified` remains `false`.

---

# Fresh visual, input and network QA — October 10, 2026

**This entry supersedes the earlier candidate evidence below. Local QA passed after fixes; release approval remains open.** [Full QA report with screenshots and issue links](docs/QA-2026-10-10.md).

The apparent return to distance mode came from a running older worktree place (`.claude/worktrees/hanger-redesign-proposals-7173ca/Skybound.rbxlx`), not a reversion of canonical PvP source. That session was stopped. The build now emits an unambiguous **`build/Sky-Battle-Playtest.rbxlx`** alongside the identical canonical file. SHA-256: `b0280d3c5a037e5364d260e488770a0bd84d5c73b1be7fa699c7c32c4f2d80db`. All 35 packaged scripts match disk and were synchronized/compared in the final native Studio Edit session. No temporary network fixtures or diagnostic overrides remain.

- **Actual visual/input QA:** five completed bot matches (three wins, two losses; four before fixes and one after), earned rewards, gift/equip, a 250-coin Aurora purchase from 275 genuinely earned coins, rematches and exit/cancel. Desktop, iPhone portrait/landscape and Galaxy A06 landscape emulation inspected. Final build's Firework select/Lock, loss/+50, Blue Comet gift, fresh rematch/reroll/Pick Any/Pinball lock and return to hangar verified with actual UI input and authoritative state confirmation.
- **Seven reproduced bugs fixed:** hidden short-landscape Lock button/card clipping; reroll/lock selecting a different card; unrecoverable initial profile load; quit preserving streak; misleading armor-timeout result fact; wall-clock timer drift; movement behind Stats. AND-223 through AND-229 are In Review. The same 700ms W input behind Stats moved 10.67 studs before and 0 after the fix.
- **200 native Studio checks passed**, plus **44 full-server scenarios** (11 current battle mode, 33 explicitly opted-in archived distance regressions). [Native](docs/validation/qa-2026-10-10/native.json), [server](docs/validation/qa-2026-10-10/server.txt), [simulation](docs/validation/qa-2026-10-10/simulation.txt).
- **Fresh two-client network run: 10 checks passed in 74.66 seconds.** Two real Studio clients used programmatic production remotes, completed three rounds with mirrored 1–2/2–1 scores and 50/75 coins, then passed private picks/reveal, gift, mutual rematch, departure and challenge decline/accept. No captured game errors. [Raw report](docs/validation/qa-2026-10-10/network.json). Explicit `session_only`; no cloud confirmation claim.

At the end of this local QA pass, the candidate was left at the desktop PvP hangar with controls enabled and no game-script console errors. Commit, push and publication happened afterward and are recorded above. AND-189/221/222 remain open for physical-phone touch/performance, heard audio, published two-account networking, confirmed live save/rejoin, unfamiliar-player replay and remaining balance/readability concerns. A normal draw and corrected timeout result still need final-build visual observation. See [the playtest checklist](docs/SKY-BATTLE-PLAYTEST.md).

---

# Earlier Sky Battle Milestones 1–2 candidate — October 10, 2026

Implemented the approved rivalry first, passed the native mechanical gate below, then added cosmetic progression. The deliverable is **Skybound.rbxlx**, with exact source hashes in [the build manifest](docs/validation/sky-battle-build.json). Milestones 3 and 4, paid products, expansion skills and daily/season systems are outside scope. The existing design/ticket-review edits were preserved.

## Final implementation and checks

- Shared public roster: Meteor, Firework, Machine Gun, Pinball; Afterburner, Spring Bumper, Fizzy Fuel, Magnet, Second Wind. Human and bot access is identical; skin geometry, paint, trails, coins and mastery never alter combat stats or draft access.
- Server-owned human queue with named bot fallback, hidden simultaneous draft, one free reroll/Pick Any per match, first to two wins, drawn-round replay, 35-second/5-round/240-second caps, factual results, mutual rematch and same-server challenge lifecycle. Disconnect/shutdown restores controls and cannot generate instant-forfeit rewards.
- Eligible completed loss/draw gives 50 coins; win gives 75. First-match trail choice, separate 250-coin Aurora goal, result/shop/hangar feedback and battle mastery records. Additive schema migration, saved/pending/unavailable/session-only distinctions, idempotent grants and retry-safe saving. No combat purchases.
- **185 native Studio checks passed:** 40 simulation, 5 skill catalog, 28 match orchestration, 44 player stats, 11 cosmetic catalog, 14 telemetry, 12 presentation, 24 audio and 7 client command/feedback. [Native output](docs/validation/sky-battle-native.txt).
- **43 full-server harness scenarios passed:** 10 default battle integrations, 33 explicitly opted-in archived distance regressions. Store-double cases include normal human/bot awards once, first gift plus immediate rematch, terminal purchase/equip, fight mutation denial, challenge/departure, saved rejoin and failed-save autosave retry. These are simulated services, not live cloud persistence. [Output](docs/validation/sky-battle-server.txt).
- Generated place validates all **35 packaged source/spec scripts** against disk, and all 35 sources in the working Studio Edit instance were compared byte-for-byte with disk (no differences). The final Edit instance contains exactly 35 scripts, no temporary QA scripts, and no fixed-seed/experimental flags. `git diff --check` passes. Diagnostic QA scripts are excluded from the package.

## Observed Studio UI and normal play

Inspected desktop 2075×856 and iPhone 17 Pro emulation at 401×778 portrait and 750×381 landscape. Real PLAY input entered search and private draft; unassisted deadline picks reached normal automatic combat. Two complete bot losses ended 0–2 and awarded 50 coins with the first gift available. On the latest combat/client flow, a native gift-button activation granted and equipped **Blue Comet**, preserving the 50 coins. Rematch started a new match against the same Comet identity, with score 0–0, fresh resources and Blue Comet equipped.

Draft cards, score/armor, storm, result/fact/replay, scrollable optional rewards, cosmetic preview/goal and challenge empty state were rendered. Challenge open/close and collection open worked through native UI input; movement is disabled while the modal is open. MY STATS now shows battle matches/wins/losses/draws/streak/mastery rather than distance data. Corrected short-landscape header/controls and challenge-footer overlap, increased gift targets to 44px, and replaced remaining simulated-opponent sign copy. [Portrait draft](docs/validation/sky-battle-phone-draft.jpg), [portrait rewards](docs/validation/sky-battle-phone-rewards.jpg).

The live replay diagnostic distinguished `replay_requested` from a subsequent `next_actual_launch` after the loss. Final review found that reward-shown delivery was missing; the client now sends it once per visible terminal result, with native regression coverage. Manual timing here includes deliberate tool/inspection delays and is **not** a first-session or replay-speed benchmark.

Linear is current: 25 implemented issues are In Review; AND-189, AND-216, AND-221 and AND-222 remain In Progress for observation/release gates; the pre-existing AND-190 completion and Milestones 3/4 were left unchanged.

## Actual local two-client network pass

**10 checks passed in 60.16 seconds** through `StudioTestService:ExecuteMultiplayerTestAsync(2,"SkyBattleNetworkV1")`. Two independent Studio clients sent the production remotes and reported received snapshots. They paired as humans, preserved private selections until both locked, revealed the same seed/builds, completed a normal two-round match with mirrored 0–2 / 2–0 scores and 50/75 coins, claimed a starter through the client remote, required both rematch votes, reset builds/resources without duplicate awards, restored both controls after departure, declined then accepted same-server challenges, and returned to usable lobbies. No captured client/server game errors. [Raw network report](docs/validation/sky-battle-network.json).

Inputs in this test were programmatic. The report's “preserved confirmed grants” check name refers to earned in-session grants; `saveStatus=session_only` is explicit and proves no cloud confirmation. Temporary QA scripts were removed from the editable Studio place and are never packaged. The initial 25-second startup attempt failed; the corrected server-marked client bootstrap completed both clients in 5.83 seconds on the successful run.

## Balance and remaining release gates

[Balance report](docs/BALANCE-REPORT.md): 3,600 base/baseline rounds across 20 independent seeds and 11,520 exhaustive active-build screen rounds across 3 independent seeds. Firework mirrors changed from 180/180 draws to 99/81/0 without a hidden tiebreak. Fizzy/Bumper tuning brought average single-card lifts below 10 percentage points. Remaining flags include Meteor mirror draws, defensive stalls (worst full-build cap rate 58.85%), and two full builds above 65% field score. This is a free iteration candidate, not balance-complete approval.

Still required before release: published two-player agreement and lifecycle checks; real-phone touch/readability/frame stability; heard audio judgement and published sound permissions; confirmed live save/rejoin for grants/equipment/mastery; unfamiliar-player first-session and actual replay observations. Local emulation and native automated audio/presentation assertions do not satisfy those gates. Follow [the exact publishing/playtest checklist](docs/SKY-BATTLE-PLAYTEST.md), which includes account access, place/version recording, cases, success thresholds and an empty results sheet. No published place version is claimed.

Tool/test limitations: one initial view-spec invocation omitted dependencies and was rerun correctly; a real Firework starvation regression was fixed before progression. Phone input automation required explicit coordinates and delayed authoritative confirmation; tool success alone was not treated as a click/grant. The first local multiplayer harness attempt timed out during client startup at 25 seconds and was corrected to wait for a server-marked QA channel with a longer cold-start allowance. Desktop UI automation bound to an older Studio window, so the supported StudioTestService API was used instead.

---

# Milestone 1 prerequisite gate — October 10, 2026

The Milestone 1 mechanical gate passed **before any progression implementation**: native Studio 39 combat, 5 catalog, 27 authoritative match orchestration, 9 presentation, 23 audio, 5 client command/feedback, and 14 telemetry checks. The orchestration suite uses doubles inside native Luau; it is not two independently connected human clients. The full Main.server harness passed 38 service-double scenarios, including 33 retained distance-mode regressions. Existing player-stat 30 and cosmetic 9 checks also passed at this gate.

Observed in actual Studio Play: main PLAY click enters search, named-bot fallback enters a private draft, deadline starts countdown and automatic combat. Inspected desktop 2075×856 and iPhone 17 Pro emulation portrait 401×778. Portrait draft showed all three readable cards, reroll, Pick Any and lock controls. Fixed pale status text over clouds and small role labels; skin geometry is preserved. Later final candidate checks will supersede this intermediate observation.

A native regression test caught a real attack-starvation bug in the first mirror-timing change. It was fixed before the gate passed. One presentation test invocation omitted required dependencies and failed as an AssistantCommand; rerunning with the documented parameters passed. Neither error is suppressed or treated as a game pass.

The 20-seed base sample reports Firework mirrors 99/81/0 wins/losses/draws over 180 angle variants, versus 180/180 baseline draws. Median 22.917s, p90 24.6s, no round caps. There are **20 independent seeds, not 180 independent samples**. Other pairing draw/timeout and balance flags remain open; full sample records are being saved. No human comprehension, fun, real-phone, heard-audio or published persistence claim follows from this gate.

---

# Skill catalog and two wild cards — October 10, 2026

AND-190. Battle skills now live in a shared catalog (`SkillCatalog.luau`) with their behaviour in one table of hooks per skill (`BattleSkills.luau`). `BattleSimulation.luau` no longer names any skill. A plane's build is one offence plus zero, one or two different wild cards (`{ offenceId, wildIds, angle }`), replacing one power and one modifier. The server refuses a whole build if a skill is unknown, of the wrong kind, repeated, or if there are more than two wild cards. The setup screen reads its cards and chips from the catalog; wild card chips toggle, and the bot brings as many wild cards as the pilot. No new skills, no draft, no balance change.

Checked:

- **Old fights are unchanged.** Every physics and gameplay field matched the pre-change simulation on every tick: 500 rounds, 805,417 ticks (10 seeds × 9 angle pairs × both Meteor/Firework orders with no wild cards, plus 10 seeds × all 16 pairs of none-or-one wild card × both orders). Renamed fields were compared by meaning. A deliberate 0.01 change to Firework's attack speed made the same comparison fail, so it is not vacuous.
- 31 simulation tests, including new cases for each pair of wild cards together and all 49 loadout pairs run to the end; 4 catalog tests; 47 server scenarios, including refusal of an unknown skill, a wrong-kind skill, three wild cards, a duplicate and the old power/modifier format.
- In Roblox Studio: all changed modules compile; simulation, catalog, 21 audio and 6 battle-view tests pass natively; a played session accepted a two-wild-card build for each plane, refused a three-card build, and ran to a knockout with bumper, afterburner and wake events and no script errors. The setup screen and battle view were stepped by hand through setup, a fight and results: chips toggle, the hint and fighter bar follow the catalog, and the callouts (CHARGING..., DIVE!, BOOST!, BOING!) appear.
- A throwaway skill added with one catalog entry and one behaviour table passed every check and fought (then removed).

Seen on desktop at about 2075×856, through real clicks: the setup screen with no wild cards and with two selected (chips, hint line), a fight in progress with two cards per plane (fighter bar, bumper ring, footer text), and the victory screen. The first capture showed Fizzy Fuel's icon as an empty box, because Roblox does not draw that emoji; it was swapped for one that renders. Not checked: phone and portrait layouts, and the three-chip row at phone width in particular. No balance claim is made for two wild cards together; that is AND-202.

---

# Results screen — October 10, 2026

Audit item 19. The status pill and dark footer at the end of a fight are replaced by a results moment that waits for the knockout to play out (1.8s after a knockout, 0.6s after a timeout) and then takes the screen: a slammed-in VICTORY! / DEFEAT / DRAW! banner, one plain line saying how it ended, the winner's portrait under a crown, three stat chips (your hits, rival hits, time), and REMATCH as the large button between Change power and Hangar. A win gets falling confetti, APM's "Champion Fanfare" and a crowd roar; a loss gets a groan and a low thump. The battle loop drops to a murmur under the result.

Checked: 47 server scenarios; no script errors in Studio. Seen on desktop: a real victory (3 hits to 1, 27.2s) with banner, crown, portrait, stats, buttons and confetti, then a real click on REMATCH, which went straight to a new countdown against a re-rolled rival. Not checked: the defeat and draw variants, the timeout wording, the stings by ear, phone and portrait layouts.

---

# Fighter bar — October 10, 2026

The dark header strip is replaced, after the owner called it out, by a floating fighting-game bar: each pilot's portrait (the player's Roblox headshot; a robot for the bot), name, power pill and three outlined armor pips at the screen edges, with a large central clock that reads VS before the fight, counts down during it, turns red and pulses in the last ten seconds, and reads K.O. or TIME! at the end. Hangar and sound are two small icon buttons under the left portrait. The leftover hint strip during the countdown is gone.

Checked: 47 server scenarios; no script errors in Studio. Seen on desktop through a real click on FIGHT!: setup, countdown and a mid-fight frame with the clock at 29 and one rival pip lost. Not checked: the last-ten-seconds pulse, the results state of the bar, phone and portrait layouts.

---

# Setup cards, calmer camera, lighter music — October 10, 2026

Follow-up to the pass below, after the owner played it: liked the direction, found the music too dramatic, wanted zooms tied to attacks or reduced, and disliked the cycling setup footer.

- **Setup:** the footer of cycling buttons is replaced by one screen about your own plane: two power cards, four twist chips and a FIGHT! button. The player no longer configures the opponent. The rival's power, twist and opening angle are rolled on the client when FIGHT! or REMATCH is pressed and revealed by the countdown; it never mirrors a Firework pick, because Firework mirrors still trade into draws. Opening-angle tuning is no longer exposed. The server still validates and owns the committed settings.
- **Rematch** re-rolls the rival instead of replaying the identical fight (the round seed is still fixed at 731).
- **Camera:** rests at a 126-stud-wide frame and closes to 94 only while a plane is winding up or attacking, or for a knockout. The hit punch-in is roughly halved.
- **Music:** APM's "Feel That Move" (30-second light version, clavinet funk) replaces "Rival", about a third quieter. Menu clicks and a commit whoosh were added.
- Player-facing "SIM" and "Battle Lab" wording is now "RIVAL" and "VS PRACTICE BOT"; the opponent is still labelled as a bot.

Checked: 47 server scenarios; in Studio, 6 battle-view and 21 audio tests; no script errors. **Seen on desktop at about 2480×1030** through real clicks: the card screen, picking a twist, FIGHT!, the rival reveal, the 3-2 countdown and the opening Meteor-versus-Meteor exchange in the sky arena. Not checked: the new track by ear, a full fight to results with the new camera, REMATCH by click, phone and portrait layouts of the card screen.

---

# Battle look, sound and feel pass — October 10, 2026

First pass on [the battle audit](docs/BATTLE-AUDIT.md), items 1–4, 6, 7, 15, 21 and 23, on branch `battle-juice-pass` (based on `codex/plane-battles-entry`). Presentation only: `BattleSimulation.luau` is untouched. The one server change is countdown length (launch 2.0s → 2.4s, quick retry 1.0s → 1.8s) so three evenly spaced beats fit.

What changed:

- **Camera:** frames both planes and any rocket in flight instead of the whole field, widening fast and tightening slowly, with a punch-in and shake on hits. A knockout plays at 0.35× for half a second and the camera goes to the falling plane first. Reduced-motion mode keeps the old fixed full-field frame with no shake, freeze or slow motion.
- **Impacts:** pooled spark, smoke and fire particles (Roblox built-in textures), a 0.07–0.16s freeze-frame, a white screen flash and a colour-grade kick. Planes smoke after one hit and burn after two. Rockets have a long sparkling trail and burst in the shooter's colour.
- **Arena:** painted late-afternoon sky, sun, 32 drifting clouds at four depths, a floating deck and two bleachers whose crowd rows hop harder as the fight heats up. Bloom and a colour grade are added on entry and removed on exit.
- **Your plane:** fighter one uses the pilot's hangar paint and equipped trail, with their avatar in the cockpit; the rival gets a contrasting paint and a practice pilot. The HUD accents follow the paints. The chosen plane *type* still does not show, because the power replaces the wings and fuselage.
- **Callouts and countdown:** cartoon-lettered pop-in words over the planes, and a full-screen 3-2-1-FIGHT!
- **Sound:** the existing pitched stock voices are kept and layered with 16 licensed one-shots (Pro Sound Effects' official Creator Store channel) plus three beds: APM Music's "Rival - 30 second" (the track already vetted on `claude/game-visuals-sound-80a0f8`), a stadium crowd and a storm bed for the closing wind. Countdown beeps, a start whistle, last-five-seconds ticks and crowd reactions are new.

Checked:

- `sample_battle.py --tests-only`: 27 pass. `test_server.py`: 47 scenarios pass after four countdown waits were lengthened to match.
- Native Studio Luau, run through Studio's automation server: **6 battle-view crash tests and 21 battle-audio tests pass**. One real fix came from this: a wreck could end a frame within 0.002 studs of the floor without counting as landed; touching now lands.
- Three complete simulated fights (plain, Spring Bumper vs Fizzy Fuel, Afterburner vs Fizzy Fuel) were stepped through the view at 60 Hz with no errors. Visible height ranged **73–162** studs, so the lens moves about 2.2×. Bloom, grade and the arena were removed on destroy.
- A second HUD instance was driven through a real server fight on the client: calls appeared as 3, 2, 1 at 0.8s spacing and FIGHT! at 2.5s; the screen flash peaked at 0.63 opacity; the result was reached at 27.2s. `BattlePlane1` reported `PilotAvatarSource=CharacterClone`, the rival `PracticeDummy`.
- All **51 battle sounds** (16 stock, 32 licensed one-shot voices, 3 beds) reported `IsLoaded` with a non-zero length.

**Not checked — nobody has seen or heard this build.** The Mac's screen was locked during the pass, Studio rendered zero frames, and screenshots were unavailable. Every visual and audio judgement (sky colours, particle sizes, shake strength, bloom level, mix balance, whether each licensed sample suits its moment) is untested. Phone and portrait layouts, performance on a low-end device and published-server audio permissions are also unchecked.

---

# Main PLAY enters plane battles — October 9, 2026

The hangar now has one game entrance: **PLAY → battle setup → Launch battle**. The Solo button, separate Battle Lab shortcut and distance-duel gates are removed from the default build. Distance matchmaking and direct practice requests are disabled server-side unless `FlightServer.DistanceModeEnabled` is explicitly set to boolean `true` before startup. The old implementation and its regression coverage remain available for later; see [the archived distance reference](docs/DISTANCE-FLIGHT-REFERENCE.md).

- **47 server scenarios**, 30 player-stat checks and nine cosmetic checks pass. Four scenarios exercise the absent-attribute default: PLAY routing, repeated entry, exit/re-entry, independent simulated opponents, preserved hangar appearance, and blocked pad/practice/debug distance creation. The remaining 43 explicitly opt into the archived distance mode.
- Native Studio clicks used the main PLAY button, launched the default battle, reached Results at **27.25 seconds**, and returned through **Hangar**. The defeated plane reached `CrashState=Landed` with the crash audio event. Exit removed the arena, restored the hangar visuals and HUD, restored `CameraType.Custom`, walk speed 16 and an unanchored avatar, and cleared `SkyboundFlying`.
- A native diagnostic sent the former practice command and moved the player to a former pad location. After more than six seconds the player remained in Lobby with `matchId=0` and no queue. The runtime mode attribute was false, and the old buttons and gate/pad geometry were absent. This pad check used a diagnostic teleport, not a walking-input test.
- Inspected the full-width PLAY button and PLANE BATTLES caption at **2075×856**. Rebuilt `Skybound.rbxlx`; all **30 packaged scripts** match disk and the native Studio sources. The client/server initialized without game-script errors. The session is left at the hangar.

Combat mechanics, rewards and progression are unchanged. This pass establishes the local entry flow; it does not add physical-device or published-network evidence.

---

# Battle Lab and hangar integration — October 9, 2026

Integrated the current Battle Lab onto hangar redesign `ca25d3e`, using `76b18d5` as the reviewed resolution. The final Meteor, crash, audio and simulation modules were verified unchanged. The two entry paths remain separate: **PLAY PLANE BATTLES / BATTLE LAB** starts combat; the hangar's **PLAY / SOLO** starts distance flight.

- The Battle Lab entrance uses `Hud:getHubStackTop()` above the new plane selector. It hides during PLAY search, the shop and the stats popup. The latter was fixed during this integration.
- **43 server scenarios**, 30 player-stat checks and nine cosmetic checks pass. New integration tests cover PLAY then Lab in the same frame, Lab then PLAY, and preservation of hangar appearance/bay assignment through Lab entry, respawn and exit. They validate the `not p.quick` guard and prevent a pending ghost fallback or human reservation from overlapping the Lab.
- **27 combat, 21 audio and six crash checks** pass in actual Studio Luau after integration. A complete native default battle still ends at **27.25 seconds**, Meteor winning 2–0 armor; Firework falls, rests on the floor and emits the ground-crash cue.
- Native clicks verified stats-modal entry suppression, PLAY search and cancel, Lab entry, launch, Results and return to the redesigned hangar. While in the Lab, hangar visuals are empty, the flight HUD is disabled and `SkyboundFlying` is true. Returning restores the parked-plane/unlock visuals, normal camera, walk speed 16 and an unanchored character, removes the battle arena, and clears `SkyboundFlying`.
- Desktop entry placement was inspected at **2075×856**. Rebuilt and checked source parity for all **30 packaged scripts**, including `HangarBay`. This integration does not add physical-phone or published-network evidence; earlier hangar and Battle Lab playtest limits remain below.

---

# Meteor charge and ground crash — October 9, 2026

This revision intentionally changes Meteor preparation to create visible travel before a committed strike. Meteor spends 0.6 seconds arcing toward open space, then 0.4 seconds aiming. Ordinary approach/recovery, Firework attack rules, one damage per successful hit and three-hit armor remain unchanged. Earlier movement-preservation records below apply to their own revisions.

## Native checks

- **27 combat/catalog, 21 audio and six native crash tests** pass in actual Studio Luau. Crash coverage includes actual aircraft/floor contact, double knockout, timeout survivors, retry/destroy during a fall, and near-floor knockouts at heights 8, 10 and 14 with contact and sound cue in the same update. The server harness also passes **36 scenarios**, 30 player-stat checks and nine cosmetic checks.
- Actual Studio clicks entered the lab, launched the default Meteor 35° / Firework 30° matchup with No Effect, retried, changed setup and exited. Captured the charge with real separation and the armed comet during travel. The first charge starts at **2.5667s**, releases at **3.5667s**, and hits at **3.8833s**. That is **0.3167 seconds of actual armed travel**. The default round ends at **27.25s**, Meteor winning with two armor. A fresh local Lupa replay matches this result.
- Observed the defeated Firework falling and resting on the visible floor. The final live replay left its lowest contact point within **0.000002 studs** of the floor. The audio event count advanced once from finish to ground crash and remained there in Results. All 16 pooled voices loaded; subjective sound quality remains a playtest question.
- Full desktop rendering and centered **390×730 Results / 390×440 setup** regions were inspected. No reported text overflow; the wreck and floor remain visible. These are desktop constrained-region checks, not physical-phone or device-emulation evidence.
- Retry clears the wreck and restores three armor segments. Exit removes the arena, stops battle voices, restores the normal camera and restores unanchored walking. Studio client/server initialized without game-script errors.

- Rebuilt `Skybound.rbxlx` and verified all **29 packaged scripts** against disk and the running Studio sources. The final live round again ended at 27.25s, landed the wreck and recorded the crash cue. Studio is left in full-size Configure with default powers, No Effect, sound on and optional angles closed.

## Reproducible simulation sample

`build/testenv/bin/python scripts/sample_battle.py --samples 10 --mirrors --modifier-sample --json` covers 180 No Effect cross-power rounds: **88 Meteor wins, 71 Firework wins, 21 draws; 150 knockouts and 30 timeouts**. Median duration is **27.167s** in both power orders. Of 593 Meteor dives, 319 lasted at least 0.3 seconds and 41 lasted under 0.05 seconds; their endings included 399 hits, 148 interruptions and 45 misses. The 320 modifier rounds exercise 147 bumper blocks, 75 wake hits and 496 boost activations; peak simultaneous wakes is 10.

A scoped comparison against the local pre-edit backup (`--samples 3 --modifier-sample --baseline build/battle-lab-v3/BattleSimulation.luau --baseline-scope meteor-charge --json`) matches every original gameplay field for **75 complete Firework mirror rounds and 150 prefixes before the first Meteor windup**, totaling **101,562 ticks**. This does not claim identical trajectories or outcomes after the changed Meteor charge. The ignored backup and JSON reports are local evidence; the sampler is tracked.

## Scope and remaining tuning

The longer Meteor windup changes matchup outcomes. Some dives are still cut short by contact or an opposing attack; no minimum flight, guaranteed hit, teleport or protective immunity is added. Ground crashes are local presentation after the authoritative result and cannot change the winner. Timeout survivors do not crash. Three armor segments remain the damage model.

The next player check is whether the full charge, committed dive and impact are satisfying while ordinary flight still feels natural. Competitive balance, unfamiliar-player comprehension, physical-phone performance and published networking remain unproven.

---

# Signature presentation validation — October 9, 2026

This pass strengthens Meteor and Firework presentation while retaining combat behavior. Aircraft silhouettes, charge/release/impact effects, arena trim, armor bars and sound envelopes changed. A dedicated Meteor `dive` event preserves attack commitment when an attack begins, hits and recovers between 20 Hz snapshots.

## Source and simulation checks

- **24 combat/catalog checks** pass, including the immediate dive/hit/recovery case. Against the pre-edit local simulation, **100 rounds / 149,995 fixed ticks** match for every original physics and gameplay field. The comparison excludes only the presentation event stream, its serial counter and newly added metadata. This covers 36 no-effect angle-grid rounds and 64 rounds across every ordered modifier pair and both cross-power orders.
- The modifier sample retains exactly the previous outcomes and pacing: median 23.95 seconds, 60 knockouts, four timeouts, 39 Firework wins, 24 Meteor wins and one draw. No movement, attack timing, armor, collision or damage tuning was applied.
- **13 audio checks** pass. A mocked-constructor stress run processed 240 voice plays while retaining 16 Sound instances and at most 16 stored tweens. A real-simulation event replay at 20 Hz routed two Meteor dives, three Firework launches, five hits and one finish once each. These are mechanical routing/lifecycle checks, not a listening assessment.
- **36 server scenarios**, 30 player-stat checks and nine cosmetic checks pass. Short-screen header score/button overlap was removed, and unmodified fights reclaim the empty effect footer's space.

Reproduction: `build/testenv/bin/python scripts/sample_battle.py --samples 2 --modifier-sample --baseline build/battle-lab-v2/BattleSimulation.luau --json`. The baseline is an ignored local pre-edit copy. Existing physical-device, published-network, subjective sound and unfamiliar-player gates still apply.

## Native Studio checks

- Actual Luau passed all **24 combat/catalog and 13 audio checks**. The final client/server initialized without script errors. Native clicks entered the lab, launched fights, retried, edited settings, swapped powers, exited and re-entered.
- Observed Meteor's charged nose, vent glow, targeting marker and an actual dive-hit burst with matching armor-bar flash. The default unmodified matchup finished at **29.0667 seconds**, Firework winning with one armor. A retry reproduced the fight and the first dive hit at 3.2167 seconds.
- A second unmodified matchup, Firework 50° versus Meteor 45° with seed 731, showed the striped rocket and sputtering exhaust during actual flight at approximately 29.68 seconds. Its projectile existed from 29.4667–30.0333 seconds. A temporary runtime monitor observed visible rockets on 65 sampled frames, impact flashes on 16, and at most 532 scene descendants in that round. This is one local sample, not a frame-rate or mobile-performance benchmark; the monitor was removed afterward.
- All 16 battle sounds loaded and the runtime advanced its played-event counter. Subjective loudness and timbre were not assessed. Source-specific sound routing is covered by the audio checks.
- Full desktop rendering was inspected at 2075×856. Centered 390×440 setup, 390×730 combat and 705×430 setup/angle regions had no reported text overflow; both planes and the arena remained visible. These are desktop constrained-region checks, not device emulation or physical-phone evidence.
- Returning to setup left no visible transient charge, muzzle, comet, impact or celebration pieces. Switching a plane's signature twice restored the original 10-piece Meteor signature and the same combat descendant count. Exit removed the scene and stopped battle voices, restoring the normal camera and walking controls. The final session is full-size Configure, Meteor/Firework with No Effect and optional angles closed.
- Regenerated place and native source parity were checked for all 28 packaged scripts.

**Presentation limit:** Meteor commonly commits and hits within one simulation tick; the new event preserves that moment between snapshots. In a seed-731 search of all UI angle pairs and both power orders, the longest unmodified armed interval was 0.10 seconds. This pass does not establish a sustained visible comet flight. A longer anticipation-to-contact interval is a future attack-spacing experiment; the movement and timing were deliberately retained here.

---

# Battle Lab effects and feedback — October 9, 2026

The second combat iteration preserves the natural no-effect fighting movement and adds one optional effect per plane: Afterburner, Spring Bumper or Fizzy Fuel. Setup still defaults to No Effect; opening angles are behind an optional control. The earlier records below describe their own revisions.

## Confirmed in this pass

- **Movement preservation:** compared the previous Battle Lab simulation against this revision for 36 no-effect rounds and **50,606 fixed ticks**. Every pre-existing state value matched exactly, including positions, headings, phases, armor, projectiles and original event fields. Only new modifier fields and event timestamps were excluded from comparison.
- **23 combat/catalog checks and 10 audio checks pass in actual Studio Luau.** Coverage includes modifier validation, a single spent bumper, brief recovery boosts, visible wake lifetime and ownership, swept wake hits, invulnerability, reset state, audio event deduplication, mute, stale-event suppression and bounded voice pools. The server harness passes **36 scenarios**, plus 30 player-stat and nine cosmetic checks. Its two new scenarios cover modifier locks/reset and launching the visible settings after a throttled configuration burst. Service doubles do not establish published networking behavior.
- Actual Studio button clicks selected effects, launched rounds, reached results, retried and exited. Meteor + Fizzy Fuel at 35° versus Firework + No Effect at 30° ended at **19.3167 seconds** with a recorded `wake_hit` removing the final opposing armor pip. The winner retained two pips. Wakes were visible during recovery; the result showed the winner halo, disabled opposing aircraft and 3–1 landed-hit count. An earlier Afterburner/Spring Bumper round showed boost activation and the spent bumper state.
- **Run it again** retained the selected experiment while advancing the round ID and restoring three armor per plane, zero elapsed time, no wakes/projectiles and zero active boosts. Exiting removed the battle scene, stopped all battle voices, restored the normal camera, unanchored the avatar and restored walking speed. Re-entering returned to the default Meteor/Firework setup with No Effect on both sides.
- All **16 pooled battle sounds loaded** in Studio; the completed wake round recorded 20 played events. The sound toggle shared the hangar mute state and silenced both audio groups. These are runtime/load checks; subjective listening quality remains to be playtested.
- Inspected full desktop rendering and centered **390×730, 705×430 and 390×440** UI regions. Power/effect descriptions and optional angle controls had no reported text overflow. Fixed the short-height setup layout so angle controls leave visible arena space. These are constrained-region checks in a desktop viewport, not physical-phone or device-emulation evidence.
- The hangar now names the entrances **PLAY PLANE BATTLES / BATTLE LAB** and **DISTANCE FLIGHT · SOLO**. Combat cues distinguish windup, ordinary bumps, damaging hits, blocked hits and the finish. Studio reported client/server readiness with no game-script errors.
- The regenerated `Skybound.rbxlx` contains **28 packaged scripts**, each verified against its source. Studio is left in full-size Battle Lab setup with default powers, No Effect and sound on.

## Effect sample and limitations

`build/testenv/bin/python scripts/sample_battle.py --samples 2 --modifier-sample --json` samples all 16 ordered effect pairs, both Meteor/Firework orders and two deterministic seeds at 32°: **64 rounds**, median **23.95 seconds**, P90 **30.283**, maximum **35**. Results were 60 knockouts and four timeouts, with 59 boost activations, 32 bumper blocks and 18 wake hits. Peak simultaneous wakes were five; simulation and rendering are capped at 12.

The no-effect comparison additionally used `--baseline build/battle-lab-v1/BattleSimulation.luau` against the local pre-edit copy. That ignored build backup is local evidence, not a tracked test fixture.

This small simulation sample establishes functioning interactions and bounded pacing, not competitive balance or retention. The user's positive movement feedback is one player's qualitative observation. Firework mirrors, unfamiliar-player comprehension/retry behavior, physical phone usability, final sound mix and real human/published-network tests remain open. Random offers, multi-round rivalry and combat progression are still future work.

---

# Battle Lab validation — October 9, 2026

Local prototype work on `codex/skybound-battle-lab`. Product scope and future gates are in [the Clash design](docs/SKYBOUND-CLASH-DESIGN.md). The records below the divider describe earlier flight revisions; their dates and limitations still apply.

## Confirmed in this pass

- The pure combat simulation passes 14 checks in both Lupa and Roblox Studio's actual Luau runtime: deterministic replay, fixed ticks, invalid time/input guards, bounded flight, frontal armed strikes, moving projectile sweeps and ownership, impact protection, simultaneous knockouts, visible pressure and time-cap results.
- The real server sources pass **34 scenarios** with mocked Roblox services, including five Battle Lab integration scenarios. These cover ordered command bursts after network delay, rejecting entry from every flight phase or a queue, keeping lab combat isolated from pads/flight commands/rewards, malformed settings, frozen countdown/fight settings, fresh retries, independent sessions, exit and disconnect cleanup. The same run passes 30 player-stat and nine cosmetic checks. This is service-double evidence, not a published network test.
- In the existing `Skybound.rbxlx` Studio session, actual button clicks entered the lab, changed an angle, launched combat, reached results, returned to setup, and exited to the hangar. The client and server initialized without script errors. Combat showed both colored aircraft, rockets, attack cues, armor updates and results against a labelled simulated opponent.
- Three rapid angle-button taps followed immediately by Launch arrived as the intended **50°** server setting. A final real round ended at **29.30 seconds**; clicking **Run it again** advanced the round ID, restored both planes to three armor pips, zero elapsed time and zero projectiles.
- Exit removed the local battle scene, restored `CameraType.Custom`, unanchored the avatar, re-enabled movement and restored the existing flight/shop GUI. A subsequent legacy practice flight entered `Flight`, advanced its authoritative distance, and rendered with the lab inactive. That smoke test did not complete a new full two-human race.
- Desktop layout was observed at a 2075×856 Studio viewport. Centered **390×730** and **705×280** UI regions were inspected in that same viewport for responsive controls and arena fit. These are constrained-region rendering checks, **not device emulation or physical-phone touch/performance evidence**. Compact setup sacrifices preview size; actual phone readability remains a playtest gate.
- The setup camera was corrected to keep its viewing distance close enough for low-detail rendering; the full arena now remains visible during configuration. The legacy shop GUI is suppressed while the lab owns the screen. Setup input preserves pending edits across periodic snapshots and queues commands before launch.

- The regenerated `Skybound.rbxlx` was parsed and every packaged script was verified against its current source. Studio was left in the full-size Battle Lab setup view with the default Meteor/Firework choices.

## Reproducible pacing sample

`build/testenv/bin/python scripts/sample_battle.py --samples 20 --mirrors` runs 20 deterministic seeds × nine angle pairings × four ordered signature matchups: **720 rounds**. The angles are 10°, 32° and 55°. These sample seeds differ from the lab's fixed seed 731.

| Matchup | Rounds | Median seconds | Maximum seconds | Results |
| --- | ---: | ---: | ---: | --- |
| Meteor / Firework | 180 | 23.733 | 30.367 | Firework 93, Meteor 83, draw 4 |
| Firework / Meteor | 180 | 23.633 | 30.450 | Firework 101, Meteor 79 |
| Meteor / Meteor | 180 | 19.250 | 30.417 | 164 decisive, 16 draws |
| Firework / Firework | 180 | 17.567 | 17.717 | 180 simultaneous-knockout draws |

All sampled rounds ended through knockout. Timeout and pressure rules are separately covered by focused simulation checks. The timings establish a useful first tuning range; they do not establish competitive balance, enjoyment, retention, or optimized strategy. Firework mirrors remain a known limitation to address before expanding into a human rivalry mode.

## Remaining gates

Observe unfamiliar players explaining why hits/misses happened, voluntarily retrying after a loss, and making intentional setup changes. Check physical phones, touch/gamepad use, varied real network conditions and published performance. Add combat-specific sound/impact polish after the movement reads clearly. The first-to-two human rivalry, random offers, modifiers, progression and monetization are not part of this implementation.

---

# Prototype validation — walkable 1v1 revision

Validated locally in Roblox Studio on October 8, 2026.

## Confirmed

- All 15 simulation checks pass in Studio's actual Luau runtime, including deterministic courses, collision handling, terminal distance, and exact touchdown at y=0.
- 13 additional server scenarios pass using the actual server source with mocked Roblox services (scripts/test_server.py). These cover paired-pad entry, same-seat exclusion, walking off, concurrent match isolation, command validation, disconnects, forfeits, cleanup, explicit practice, and two-person rematch consent. Mocked services do not validate replication or physics.
- Actual desktop keyboard input moved the avatar through the hub. Walking to a pad entered Queued; walking off returned to Lobby. Queue signs changed to 1/2.
- Two actual local Studio clients, Player1 and Player2, walked onto opposing pads, entered the same two-player match, received match-only snapshots, and locked distinct Shield/Magnet flight settings. Their avatars had movement disabled only inside the duel. That local test session ended before a complete two-client flight was captured; repeat the full two-human lifecycle before release.
- An explicit practice-button click created exactly one human plus one named ghost. No unattended global round starts from the lobby.
- Complete practice flights finished on land at y=0 with finishReason=landed and ranked the two terminal distances. One reproducible Coast seed (116219) yielded 2040.8 m for Skipper and 1148.9 m for the default human launch.
- Clicking Rematch started round 2 in Voting with the same pair. Clicking Return to Lobby restored the actual avatar to the hub, CameraType.Custom, movement controls, and matchId=0. This was rechecked after the final saved build completed another touchdown round.
- Galaxy A06 landscape simulation used an actual 705x338 viewport. Touch-sized controls changed angle from 35 to 40, selected Magnet and cyan paint, and Ready carried those settings into Countdown.
- The short-screen flight layout reserves airspace below the score bar, uses a 52px score strip, and retains 44px flight-control hit targets. Pickup labels scale with the scene; aircraft have explicit YOU/GHOST/RIVAL labels.
- Match visuals render approximately 5,000 studs from the social hub. The client updates scriptable camera position and Focus after the Roblox camera update, with a closer wide-angle view to retain visible course detail.
- The final saved place contains all six scripts exactly matching their source files and an editor preview of the new hub. Desktop Play starts both client and server without script errors. Phone emulation was reset to the default device after QA; Studio was left in the playable lobby.

Previews: [hub](previews/v2-lobby.jpg), [desktop flight](previews/v2-flight-desktop.jpg), [phone flight](previews/v2-flight-phone.jpg).

## Research used in this revision

- [User's Aviamasters 2 video](https://www.youtube.com/watch?v=VwiD4lVAOG8): inspected and played the section around 3:17–3:31. The observed side view keeps the aircraft toward the left and several rows of numbered pickups and rockets ahead. Only selected sections were reviewed, not the whole video.
- [Blade Ball 1v1 walkthrough](https://www.youtube.com/watch?v=HxixwmXxIK4): inspected lobby/avatar movement and a two-player private-server setup around 0:16 and 1:03.
- [Blade Ball duel gameplay](https://www.youtube.com/watch?v=Wjul5FC_jFc): inspected selected sections showing the transition into a separate duel environment and the surrounding shop/progression UI. This footage does not independently establish that its particular mode uses paired pads.
- Paired pads are the prototype's chosen social interaction. The hub layout, flight game, artwork, and interface are original; the reference game's gambling mechanics are not part of this Roblox prototype.

## Still to validate

- A complete real two-human round, rematch and disconnect/rejoin session on separate machines.
- Physical phone/controller usability, latency, long-session performance, accessibility, final audio, and gameplay/retention balance.
- The three free gadgets are not yet competitively balanced.
- Shop purchases, opening crates, inventory saving, receipt handling, publishing, and commercial performance are not implemented or verified. The hub's store/crate displays are visual placeholders.

## Cartoon HUD refresh — October 8, 2026

Reviewed a representative sample from the live [Roblox top-playing chart](https://www.roblox.com/charts/top-playing-now), rather than every popular experience. The sample shows several styles, not a universal Roblox theme:

- [Pet Simulator 99, official Hatch Wars update](https://www.biggames.io/post/pet-simulator-99-update-96): inspected the battle and upgrades screenshots. Rounded heavy outlined lettering, white panels with dark borders, bright price/action colors, simple icons, and a compact two-opponent score strip. This was the strongest reference for the cartoon direction.
- [Ball VS Ball footage at 0:09, 0:14 and 0:19](https://www.youtube.com/watch?v=rFez89DlGJY&t=9s): walkable promenade, paired pads, large outlined labels, vivid green Play action, controls near the edges, and three choice cards. Ball VS Ball is a separate experience from Blade Ball; its more angular arcade typography is not the same as Pet Simulator's style.
- [RIVALS footage at 0:07](https://www.youtube.com/watch?v=zrgBKxBCJEA&t=7s): gray translucent rounded selection panels, bold white headings, red actions, and green selection borders.
- [Steal An Egg footage at 0:07](https://www.youtube.com/watch?v=7BojOY1ohE0&t=7s): green/cyan edge buttons and heavily outlined labels/currency. A streamer overlay obscures part of this reference.
- [Blox Fruits cosmetic selector at 3:18](https://www.youtube.com/watch?v=DMisI3EfPaQ&t=198s): dark item cards, colorful item artwork and short rarity labels. This older footage informed the comparison, not a claim about the current HUD.

Only selected frames/sections were inspected. These observations do not establish that the visual style causes popularity or revenue. FredokaOne is Skybound's chosen display font, not a verified identification of any reference game's font. Icons are original native Roblox UI shapes; no reference art was copied.

Implemented rounded display lettering and navy text outlines, stronger panel/button borders, subtle button shading and bottom lips, a blue/gold brand header, green ready/rematch actions, and cloud/city/lightning course badges. World signs and pilot labels use the matching display face. Small instructions remain unoutlined Gotham. Gameplay, camera framing, panel sizes and responsive breakpoints are unchanged.

Live checks: desktop lobby, voting, setup and flight render without script errors or visible text overflow. Galaxy A06 landscape (705x338) keeps the 52px flight bar; actual clicks changed angle from 35 to 40 and launched the flight. Runtime font measurements confirmed that the longest ready/rematch labels, winning title and queue heading fit their compact bounds. Adjusted small header text to white on a deeper blue after finding weak cyan-on-blue contrast. Physical touch hardware remains untested.

The practice flight reached Results; clicking Accept Rematch entered round 2 Voting, and clicking Skyline produced one server-confirmed Skyline vote. After saving, all six packaged scripts matched disk, and a fresh Play loaded client/server without script errors. Returned to Lobby and reset phone emulation. No simulation or server logic changed in this style pass.

Updated previews: [setup](previews/v3-setup.jpg), [voting](previews/v3-voting.jpg), [flight](previews/v3-flight.jpg), [results](previews/v3-results.jpg), [phone setup](previews/v3-phone-setup.jpg), [phone flight](previews/v3-phone-flight.jpg), [hub](previews/v3-lobby.jpg).

## Flight tension revision — October 8, 2026

Additional visual research:

- Revisited selected later frames in [the original video](https://www.youtube.com/watch?v=VwiD4lVAOG8&t=295s), including approximately 4:55–5:05 and 10:52: large free-floating numbers, thin rockets, a readable trail, and plenty of course remaining visible during a dive.
- Played and inspected selected portions of [additional Aviamasters 2 footage](https://www.youtube.com/watch?v=VNmpHyL0B-Y&t=125s), approximately 2:05–2:33 and 4:10–4:32. At 2:05, roughly eight fully visible numbers and five rockets surround a plane about 7–8% of playfield width, positioned about 30% from the left. A consecutive-hit sequence around 2:16 shows red indicators and smoke followed by green pickup feedback. These are approximate counts from selected frames, not a whole-video analysis or measured game rules.
- [BGaming's official description](https://bgaming.com/games/aviamasters-2) confirms that rockets lower the trajectory and number pickups raise altitude. Skybound translates the visual pacing into automatic distance competition and keeps land touchdown as the scoring endpoint.

Implementation:

- Five staggered altitude bands, short encounter clusters and wider gaps replace the repeated three-row grid. Later clusters introduce more missiles; some strong +20 pickups appear near the ground. Both pilots still receive the same seeded course.
- Missile collision radius is six studs to better match the thin rocket silhouette. Hits remain recoverable; extra fuel is balanced against visible later pressure.
- Near-miss events require a genuine close swept approach followed by full horizontal clearance. A hit cannot also be a near miss, and touchdown stops event generation. They provide visual feedback only.
- The server sends a bounded 12-event history. Up to three recent events appear above the watched plane, with fewer lines or side placement when screen space is limited. Hits show smoke/fire and a brief downward pitch; boosts show green flare/trail feedback.
- Boost numbers are centered on their collision positions; small fuel cans are secondary cues. Planes render at 3.1 scale. The camera gently follows high climbs to keep the watched plane below the score bar, returning the ground to view during descent.
- Course rendering creates up to eight nearby item models per frame, inside a 260-stud rear/700-stud forward window, and removes consumed/distant models. A desktop sample showed 16 fuel targets and 13 missiles on screen with 54 active item models, rather than constructing the entire course at once.

Matched offline comparison: 15 seeds × five launch presets × three courses = 225 flights per version. Mean objects/course increased from about 150 to 266. Flight duration P10/median/P90 changed from 17.8/26.9/38.0 seconds to 15.4/25.0/34.7 seconds. Fuel-driven upward recoveries while descending below 40 studs occurred in 32% of the new sample versus none in the previous sample; timeout counts were three versus five. This demonstrates changed simulation behavior, not validated player tension or retention.

Validation: all 19 simulation tests passed in Studio's actual Luau runtime; 13 mocked server scenarios also passed. The new practice round finished on land: Coast seed 116219 produced 1592.8 m for the default human and 1677.4 m for Skipper. Rematch via the actual viewport entered configuration for the next round. Desktop and Galaxy A06 landscape (705×338) checks showed the denser field, hit/boost feedback and larger planes; phone feedback fit below the 52px score strip after the high-climb camera adjustment. No game-script runtime errors were observed. Studio automation frame timing varied with window focus, so this is not a device-performance benchmark. Physical phones and two-human end-to-end testing remain in the earlier validation gaps.

Previews: [desktop tension pass](previews/v4-flight-desktop.jpg), [phone tension pass](previews/v4-flight-phone.jpg).

## Personal records, pilots and presentation — October 9, 2026

Implemented personal statistics with atomic DataStore session leases and explicit save status; bounded native analytics; layered event-driven sound; seated cosmetic player/ghost avatars; distinct Coast/Skyline/Storm scenery; and reusable pickup/explosion effects.

- Actual Studio Luau: 19 simulation, 20 injected-store statistics and 12 telemetry tests passed. The Python service-double harness passed 17 server scenarios, including practice persistence across a simulated reconnect, human forfeits/ties, failed-load protection, and disabled DataStore/analytics in unpublished Studio. These tests do not prove live cloud delivery.
- This place has GameId=0 and PlaceId=0. The local HUD correctly reports `session_only`; no production records or analytics were sent. Published reconnect, server-overlap and dashboard checks remain outstanding.
- A complete local practice round landed and recorded 1592.8 m, totalFlights=1 and practiceFlights=1, with wins/losses/draws/currentStreak/bestStreak all zero. Results displayed the same personal distance. Actual button clicks opened/closed My Stats and toggled the flight mix to zero volume and back.
- All five sound sources loaded in Studio. Event checks verified serial deduplication, stale-history suppression, spectator switching, mute, and a fixed pool of 15 Sound instances. Subjective mix quality and published asset availability remain playtest items.
- Arena construction and impact tests passed: scenery builds for each theme; simultaneous effects cap at four slots per plane, retire after their lifetime, and disappear with their plane. Initial Play inspection caught distant scenery disappearing despite existing instances; moving decoration nearer to the course restored it. Decorative depth was reduced while keeping simulation coordinates intact.
- The real player's character clone and original neutral practice pilot both loaded in flight. Their real walking character was preserved. A runtime check caught Humanoid restoring collision on cloned torsos; post-parent Physics state plus physics-property guards fixed it. Fresh Play reported zero unsafe parts after three seconds. Guards disconnect on cleanup.
- Visually checked all three themes in desktop Play. Brightened Storm for plane/missile visibility. A single nearby backdrop follows the course view to prevent tile-culling seams on wider phone views. Fuel ripples, upward numbers, sparks, shockwaves and smoke were visible in flight.
- Galaxy A06 emulation covered 705×338 landscape and 359×718 portrait. My Stats opened through an actual phone-view click and remained legible in both orientations. Sound and flight controls had no overlapping bounds in portrait. This is emulator coverage, not a physical-device performance claim.
- The final saved place contains all 12 source/test scripts exactly matching disk and the editor hub. A fresh Play completed another Coast practice flight, then the actual Return to Lobby button restored walking controls, the normal camera and hub lighting. Plane/pilot/effect containers were empty after return. Phone simulation was reset. The final console contained startup/completion messages and no game-script errors.

Previews: [personal record](previews/v5-stats.jpg), [Coast](previews/v5-coast.jpg), [Skyline](previews/v5-skyline.jpg), [Storm](previews/v5-storm.jpg), [phone flight](previews/v5-phone.jpg), [phone records](previews/v5-phone-stats.jpg).

Full two-human networking/reconnect, physical-phone performance, live analytics and durable cloud saving still require the published test phase. Shops, crates and paid cosmetics remain the earlier placeholders.

## Plane selection, drag aiming and ghost audio — October 9, 2026

Three free planes now use server-owned fixed speeds: Cruiser 72.25 m/s, Skyhopper 64.5 m/s and Dart 81 m/s. Their models have distinct silhouettes. Selecting a plane starts at its suggested angle; dragging the aim pad changes angle from 15° to 60°. Release commits the angle, and Ready starts the shared countdown. The dotted guide uses the real empty-course physics for the first 2.5 seconds, without predicting future contacts. A/D and a selected aim pad's gamepad D-pad remain angle alternatives.

- Actual Studio Luau passed 22 simulation, 5 plane-catalog and 8 audio regression tests. The service-double harness passed 20 server scenarios, including plane allowlisting, speed spoof rejection, per-pilot launch settings and countdown/flight locks. Python build and syntax checks passed.
- Desktop clicks selected all three planes and server snapshots confirmed their fixed speeds and default angles. A mouse drag held 50° locally across server updates while the server retained 35°; release committed 50° at unchanged speed. Live testing caught and corrected an extra GUI inset subtraction.
- Galaxy A06 landscape emulation (705×338) emitted actual `Touch` input. Dragging committed 58°, then 60°, and selecting Skyhopper changed speed to 64.5 m/s. Ready entered Countdown; a subsequent drag did not alter the locked choice. The three plane buttons, gadgets, paints and Ready remain visible with 44 px or larger button targets. Physical touch hardware and gamepad interaction remain untested.
- Preview and flight models represent 60° correctly, including the upper visual pitch limit. Catalog IDs propagate to the actual plane model and seated-pilot rendering.
- Both pilots now have independent audio serials and cooldowns. The watched pilot uses full gain; the rival uses 0.65 gain. While the camera remained on the human, Studio recorded 18 ghost and 7 human audio events, all 20 pooled Sound instances were loaded, and active voices had nonzero volume. Camera switching does not replay prior contacts in the regression tests. Subjective mix quality and published audio availability still need playtesting.
- A complete practice round landed both aircraft, recorded the human's 564.3 m in session stats and ranked the ghost at 1554.0 m. The console had no Skybound runtime errors; Roblox's built-in BubbleChat emitted an unrelated wait warning.
- A 210-flight sample had P10/median/P90 durations of 14.4/21.9/32.4 seconds, one timeout and 30% low-altitude fuel recoveries. Plane profiles are distinct but not competitively balanced.
- Phone simulation was reset and Studio returned to Edit. macOS locked during the final portrait screenshot/native-save step. The source-backed place was saved through XML source synchronization with all 15 packaged scripts verified against disk, preserving the prior saved editor scenery. The current runtime rebuilds the updated three-plane showroom; a final native editor save and portrait visual check remain pending unlock.

Previews: [phone drag aiming](previews/v6-phone-aim.jpg), [phone flight](previews/v6-phone-flight.jpg).

Plane purchases and ownership persistence are not connected; all three choices are free. Prior published-cloud, networking and physical-device validation gaps remain.

## Separate selection and full-jet aiming — October 9, 2026

Setup now has two server-controlled stages. Configure gives 25 seconds for plane, gadget and paint choices; **Next: Aim Jet** confirms that selection. Both confirmations or the deadline enter a separate 20-second Aim stage, resetting readiness. The loadout is locked while the launch angle remains adjustable. Ready confirmations or the Aim deadline start the shared three-second countdown.

- Removed the small aiming panel from selection. Aim and Countdown show an enlarged jet over the runway, a drag handle attached to it, projected physics dots and a compact launch footer. The camera stays fixed while aiming. Mouse/touch can start on the jet or handle, and continue dragging outside the field. Keyboard and gamepad angle controls only operate in Aim.
- All 22 service-double server scenarios passed, including both stage deadlines, ready resets, loadout changes rejected through configure and ready payloads, angle-only/full-settings compatibility, departures in Aim and concurrent duel isolation. The actual Studio telemetry suite passed 12 tests including the new Aim abandonment phase. These tests do not establish real two-client networking performance.
- Actual desktop selection clicks preserved the chosen plane/gadget/paint into Aim; the selection panels closed and readiness reset. Dragging committed 50° with the jet visibly pitched to 50° at unchanged speed. A later drag started farther along the enlarged jet, reached the 60° cap, and clicking **Ready to Launch** entered Countdown then Flight with those settings.
- Galaxy A06 landscape emulation (705×338) confirmed **Next: Aim Jet**, actual Touch dragging and **Ready to Launch**, retaining the locked loadout. Portrait (359×718) showed the separate jet view and complete launch footer. Fixed a portrait clipping issue: all four 48px paint buttons now end six pixels above the selection panel bottom. Physical touch hardware and controller validation remain outstanding.
- Source builds successfully. No Skybound script errors were observed in the fresh final Play session. The wider jet hit area and portrait spacing were included in that session.
- The final practice flight completed with both pilots landed. Returning to the lobby restored walking controls and the normal camera, hid aiming controls, and removed all flight visuals. Phone emulation was reset. Studio's native Save confirmed the place path; all 15 saved source/test scripts exactly match disk, including the rebuilt editor showroom. This also completes the native-save and portrait checks deferred by the earlier Mac lock.

Previews: [selection](previews/v7-loadout.jpg), [full jet aiming](previews/v7-aim-desktop.jpg), [phone aiming](previews/v7-phone-aim.jpg), [portrait selection](previews/v7-portrait-loadout.jpg), [portrait aiming](previews/v7-portrait-aim.jpg).

## Peggle-inspired precision aiming and wider view — October 9, 2026

Forward pointing replaces the backward pull gesture: click, touch or drag ahead of the jet to choose its launch angle. A cyan reticle, 15/30/45/60-degree compass marks and 26 outlined trajectory dots make the setup easier to read. A/D now adjusts one degree at a time. Release commits the angle; Ready still confirms the shared countdown. The guide samples three seconds of empty-course physics and clips at the clear field edges; pickups and missiles can change the actual flight.

The precision-aiming reference is the [official Peggle 2 manual](https://dlassets-ssl.xboxlive.com/public/content/efd011ea-47b6-4b61-9e86-08063a3e1cfa/GameManual/2968fc9a-311b-4beb-8ee6-3903d1bc8643/en-GB/index.html), which separates aiming, fine adjustments and firing. Skybound retains its own two-player Ready flow and art.

- The aiming view spans about 39–45% more world width across the tested desktop and phone layouts, with the jet moved from 30% to 24% of screen width to expose more course ahead. Flight framing and simulation are unchanged.
- Actual desktop clicks changed the server angle, retained it when clicking within the origin deadzone, and clamped to 15 and 60 degrees. A/D changed 51 to 52 and back to 51. Fixed Cruiser speed remained 72.25 m/s. A separate source review checked forward-pointer math, behind-pointer retention, release-to-commit and authoritative phase guards.
- Galaxy A06 landscape emulation (705×338) emitted actual Touch input. Dragging selected 34 degrees, endpoint taps reached both angle limits, and all four compass labels stayed visible. Ready entered Countdown; a subsequent tap left the locked angle unchanged. Physical touch hardware and controller input remain untested.
- Portrait emulation (359×718) initially exposed geometry disappearing with a distant camera. Keeping the same projected coverage through an adaptive field of view and a 180-stud target setback restored the jet, pilot, missiles and scenery. Portrait uses about 108.49-degree FOV; the tested large desktop and landscape layouts remain at 50. The 120-degree FOV cap means unusually tall aspect ratios can still require a greater setback.
- Final portrait checks with Dart at 15 and 60 degrees retained all four angle labels. The shallow shot showed 19 guide dots before the right edge; the steep shot showed all 26. This confirms responsive clipping, not guaranteed visibility of every preview point on every screen.
- Actual Ready input reached Flight with the chosen 35-degree Cruiser settings. Returning to Lobby hid aiming UI and removed all flight visuals. No Skybound script errors were observed. Device emulation was reset and Studio returned to Edit.
- The source build and whitespace checks passed. Native Studio Save confirmed the local place path, and all 15 packaged source/test scripts exactly match disk.

Previews: [desktop aiming](previews/v8-aim-desktop.jpg), [phone aiming](previews/v8-aim-phone.jpg), [portrait aiming](previews/v8-aim-portrait.jpg).

## Larger aiming circles — October 9, 2026

Enlarged the trajectory guide from 7px to 16px circles on desktop/portrait, and from 6px to 12px in short landscape layouts. Navy outlines are now 2px. Closely spaced projected samples are hidden to keep circles separate without moving them off the real trajectory; edge margins include the circle radius and outline. Angle labels and the reticle draw above the circles.

Visually checked desktop, Galaxy A06 landscape (705×338) and portrait (359×718). Landscape displayed five circles and portrait nine at 35 degrees; the portrait 60-degree check also displayed nine. Runtime checks confirmed circle outlines stayed within the aim field and neighboring visible circles did not overlap. No Skybound script errors were observed. Phone emulation was reset, Studio returned to Edit, native Save confirmed the place path, and the saved HUD source exactly matches disk. This is presentation-only; launch controls and simulation are unchanged.

Previews: [desktop circles](previews/v9-aim-desktop.jpg), [phone circles](previews/v9-aim-phone.jpg), [portrait circles](previews/v9-aim-portrait.jpg).

## Superpower selection and flight transformations — October 9, 2026

The first three powers are playable: Pinball bounces off the ground three times, Missile Muncher converts three missiles into escalating boosts, and Meteor Dive dives from its first apex then pulls up near the ground with a height-based forward boost. A power lasts one round. Large illustrated choice cards, animated selection/lock-in, giant countdown numbers, power-specific plane parts, event bursts and selection/flight audio make the choice visible throughout the round. Plane and paint remain available in a secondary drawer, with a pinned 44px button on phones.

- All 32 simulation, 6 power-catalog, 5 plane-catalog and 11 audio checks passed in actual Studio Luau. The 24 mocked server scenarios passed, including power allowlisting, spoofed charge/strength rejection, loadout locking after Configure and fresh charges on the next round. These service doubles do not establish networking performance.
- Desktop mouse input completed selection, lock-in, aiming, countdown and a full Muncher practice flight. Its jaws appeared on the plane and all three bites registered. The ghost's Meteor power and event audio remained independent. All 20 pooled sounds loaded; subjective mix quality still needs listening/playtesting.
- Live Pinball practice used all three bounces, then landed normally at 2244.1 m with zero charges. Live Meteor at 55 degrees entered its dive at 4.33 seconds, pulled up at 6.82 seconds near 18.9 studs altitude, and consumed its one charge. These runs confirm activation and state flow, not competitive balance.
- Galaxy A06 emulation covered 705×338 landscape and 359×718 portrait. All three choices and Lock In fit both layouts. Actual touch input opened/closed Plane & Paint and portrait Lock In entered Aim with Pinball. The tool's portrait instance-target click offset required explicit viewport coordinates; no game input workaround was added.
- Plane transformations contain 24 Pinball, 19 Muncher and 8 Meteor parts. All were noncolliding in the Studio construction check. The existing bounded effect/voice pools are retained.
- A same-seed, three-angle simulation comparison exposed an initially oversized Muncher boost. Reducing its forward boosts to 12/16/20 narrowed its distance advantage in the sampled courses. This is an initial tuning pass, not player-tested fairness.
- The final source build and whitespace checks passed. Native Studio Save confirmed the local place path, and all 17 saved source/test scripts exactly match disk. The editor lobby was refreshed, device simulation reset to default, and Studio returned to Edit. Fresh final Play produced no Skybound script errors.

Previews: [desktop powers](previews/v10-power-desktop.jpg), [phone powers](previews/v10-power-phone.jpg), [portrait powers](previews/v10-power-portrait.jpg), [Meteor Dive](previews/v10-meteor-phone.jpg).

The other seven proposed powers remain concepts. Full two-human networking, physical-phone/controller usability, published audio and competitive balance remain unverified.

## October 9, 2026 — aircraft hangar and earned flight effects

Replaced the plaza with a vaulted aircraft hangar: roof trusses and skylights, work lights, concrete taxiways, parked aircraft, a visible apron/runway, fleet selection stands, an effects counter and a solo dispatch desk. Spawn and all four paired duel stations retain their established coordinates. The lobby contains 602 BaseParts (93 collidable) and six point lights; these counts are not a performance benchmark.

Added one free and five earned trails, a wallet/collection preview, direct purchase and explicit equip, a next-unlock goal, and credit awards on results. Practice completions earn 25; human completions earn 40 plus 20 for a win or 10 for a draw. Leaving and aborted rounds earn no credits. The first 40-credit trail is reachable after two practice completions. Prices, ownership, balance, rewards, and equipped flight settings are server controlled. Wallet, collection and equipped trail share the existing fenced save record, with migration from schema 1 to 2 in the same store.

Verified:

- Actual Studio Luau passed 105 checks: 32 simulation, 30 player-stat/economy, 9 cosmetic-catalog, 6 power-catalog, 5 plane-catalog, 12 telemetry and 11 audio tests. The Python service-double harness passed 29 server scenarios, including save migration/reconnect, reward deduplication, failed-save purchase blocking/recovery, insufficient funds, ownership/price spoof rejection, shared buy/equip throttling and phase locks.
- Two completed runtime practice rounds (including losses) advanced the wallet from 0 to 25 to 50. The results UI displayed the 25-credit award. The diagnostic launcher shortened preparation during this check; the actual server simulation completed both rounds.
- Actual mouse clicks opened the shop, selected Sky Blue, purchased it for 40 and explicitly equipped it. The authoritative snapshot held 10 credits, both Classic and Sky Blue ownership, and `equippedTrail = skyblue`. The button/feedback changed from Buy to Equip to Equipped. Another runtime flight created the human plane with the Sky Blue trail ID. Actual Luau verified the normal blue color, enabled trail and 0.9-second lifetime; temporary boost/hit/power cues retain their separate presentation.
- With the avatar moved to each test stand, actual E input selected Skyhopper (64.5 speed, 48-degree default aim) and opened the effects counter. Shop opening disables avatar controls; closing restores them. A forfeited test flight left the 10-credit balance unchanged.
- Desktop shop and spawn were visually inspected. Client-only constrained frames rendered the real shop at 359×662 and 705×282 available UI sizes. This caught and fixed a clipped landscape preview; the compact layout now scrolls the collection independently and retains a visible preview/name and 44-pixel purchase action. These were responsive-layout harness checks, **not** actual phone touch/device performance tests. Owned-filter selection and asynchronous collection refresh were corrected during review.
- Native Studio Save confirmed `/Users/andrew/Documents/ChatGPT/color-switch/Skybound.rbxlx`. All 20 packaged source/test scripts exactly match disk. A separate source build and `git diff --check` passed. Fresh final Play logged server/client startup, restored walking controls, and showed no Skybound script errors. Studio was left running in the hangar.

Screenshots: [hangar spawn](previews/hangar-lobby.png), [purchased and equipped effect](previews/hangar-effects-shop.png), [portrait layout harness](previews/hangar-effects-portrait-layout.png), [landscape layout harness](previews/hangar-effects-landscape-layout.png). Selected reference frames and source limitations are recorded in [hangar references](docs/HANGAR-REFERENCES.md).

Remaining: published two-human networking and cloud-save/reconnect verification, physical phone/gamepad interaction and device performance. Local Studio purchases intentionally reset between Play sessions. No paid products, daily missions, trading, randomized crates, launch effects or landing-effect catalogue were introduced.

## October 9, 2026 — two-client prepublish smoke test

Studio's Server and Clients test ran Player1 (`-1`) and Player2 (`-2`) through a complete human duel. Diagnostic server positioning placed them on opposing Duel1 pads; commands then travelled through each real client's RemoteEvents with normal server phase timers. This used programmatic inputs, not manual mouse or human play.

- Player1 selected Missile Muncher at 25° and Player2 selected Meteor Dive at 55°. Both clients received `matchId = 1` and identical results: Player1 won at 2506.6 m, earned 60 credits and reached a current streak of 1; Player2 finished at 901.4 m, earned 40 credits and recorded a loss.
- One rematch vote left the match in Results. The second vote started round 2 in Voting, then Configure. Player2's preflight `returnLobby` cancelled the pairing and returned both clients to Lobby with `matchId = 0`, WalkSpeed 16 and unchanged balances of 60/40 credits.
- The server logged `SKYBOUND_DUEL_COMPLETE` with no observed errors. Test clients were closed and the main Studio window returned to Edit.
- The existing Python harness passed 29 server scenarios, 30 player-stat tests and 9 cosmetic-catalog tests. At the prepublish packaging check, all 20 saved source/test scripts matched disk exactly; `git diff --check` passed. The harness uses service doubles and does not establish live cloud behavior.

This closes the complete local two-client networking check with programmatic inputs. Physical-device usability, published networking and cloud-save/reconnect remain unverified.

The latest saved pacing build was successfully published through Studio as [**Skybound Test**](https://www.roblox.com/games/86507299893768/Skybound-Test): universe `10770074500`, start place `86507299893768`, owner `psyduk44` (`4979831885`). Updated Roblox terms were accepted with the user's authorization. Computer/Phone/Tablet are enabled; Console/VR and the data-training opt-in are off.

The content questionnaire was submitted as **Mild — Violence (Repeated/Mild)** with no regional restrictions. Audience settings were saved as **Limited**, with **Playtesters** checked and **Friends** unchecked; the dashboard states that access is limited to 16+ users and trusted friends. Studio saved `LG_Birdo` (display name Birdo, user ID `2376297418`) as a **Playtest** collaborator, which automatically enabled Team Create. Reloaded dashboard permissions confirmed **Playtest this experience** without Edit access. The live game details page was verified. Hosted gameplay by both players and live DataStore/save/reconnect behavior remain untested.


## Power pacing and close-flight framing — October 9, 2026

Shortened Pinball's three recovery launches from 16/15/14 to 12/10/8 upward velocity. Power speed gains are now tracked separately from ordinary launch/fuel momentum: Pinball and Muncher lose about 90% of a burst over three seconds; Meteor's single larger height-dependent burst loses 90% over about 7.7 seconds. Meteor's pull-up is 22–32 rather than 25–35. Fuel collected at the speed cap replaces temporary burst with lasting momentum, so collecting it is still worthwhile.

A shared headwind begins at 18 seconds and ramps over ten seconds. Powered-flight gravity rises from 3.8 to 11.4 and fuel lift falls to 65% of its opening strength. It follows the shared flight clock, never lead, position or remaining charges. All three Pinball/Muncher charges remain usable; the 45-second safety timeout and existing course density remain. Legacy no-power simulation is unchanged.

The camera frames both pilots within a capped zoom, prioritizes the manually selected pilot for large gaps, and keeps the ground near the bottom during low skips. Directional labels retain offscreen rivals and landed distances. Both powers' remaining uses and a shared headwind countdown/state appear simultaneously. Manual camera selection persists after landing.

Validation:

- All 37 simulation checks passed in actual Studio Luau, including burst fade, saturated fuel, shrinking bounces, shared headwind timing, deterministic contacts and deadlines. Independent review checked no-power flight traces against the previous source and the speed floor under overlapping missile hits.
- A same-seed offline comparison sampled 405 flights per version across five seeds, three planes, angles 15/35/55, all three powers and all three arenas. Average landing wait fell from 9.5 to 4.5 seconds; P90 fell from 17.5 to 9.1. Average shared airborne time within 100 metres rose from 37% to 51%. Final mean durations were Pinball 27.9, Muncher 25.4 and Meteor 22.6 seconds, with zero timeouts versus eight in the previous sample. These matched-angle pairs do not establish optimized competitive balance. Configuration, source fingerprint and results are saved in [PACING-SAMPLE-2026-10-09.json](docs/PACING-SAMPLE-2026-10-09.json).
- The first desktop practice flight showed both pilots during the headwind and finished at 29.73/27.52 seconds, with all three Pinball bounces consumed. That run preceded the final Meteor payoff and low-ground camera adjustment. A fresh Play session with the final settings verified Meteor activation, landing and results, then Pinball through all three bounces. Studio diagnostics shortened preparation for the phone runs; one diagnostic reset reused a round ID, so that second run was not a stats/reward test.
- Phone emulation at 750×381 and 401×778 verified the two-column power strip, headwind countdown, bounded camera, close-pair framing, and edge/landed indicators. Real Q/E input switched the watched pilot; the selection persisted after the ghost landed. No Skybound script errors were observed. These are emulator checks, not physical-phone or subjective playtest evidence.
- The final 29 service-double server scenarios passed, alongside 30 player-stat and nine cosmetic-catalog checks. Native Studio Save confirmed `Skybound.rbxlx`; all 20 packaged source/test scripts match disk exactly. The sample's source fingerprint and `git diff --check` passed. Device emulation was reset to the desktop viewport and Studio was left in Edit.

The final settings are a first balancing pass. Real-player tension, repeated play and published multiplayer performance still need playtesting; the numerical sample does not establish those outcomes.

## Bold HUD and reward presentation — 2026-10-09

- Enlarged the hangar controls, course voting, power/setup and aiming controls, personal records, race scoreboard, pilot labels, and results. Rebuilt the effects shop in the same cream/navy/gold/cyan cartoon style. Public currency wording is consistently coins; persisted economy fields and reward amounts are unchanged.
- The hangar wallet includes an actual-color next-trail preview, balance, progress, remaining coins, and a finite affordability pulse. Results reveal the authoritative award/balance once per match and round; reduced motion shows final values immediately. Buying and equipping remain separate server-confirmed actions.
- Actual Studio Play screenshots inspected at desktop 2075×856, phone portrait 401×778, and landscape 750×381. Checked hangar, shop, stats, power choices, plane/paint drawer, aiming, flight scoreboard and final-distance markers, and results. Fixed a short-landscape results overflow so the reward hint and personal best remain visible above the actions; stats modal hides the wallet card. Desktop preview: [hangar preview](previews/bold-ui-hangar.jpg).
- Completed two authoritative practice flights in one Studio session (diagnostics skipped setup waits; flight simulation and rewards were unchanged), including a real rematch button click. Awards advanced the bank 0 → 25 → 50; results and hangar switched from 15 more coins to ready to buy. Native UI purchase of Sky Blue debited 40 coins, ownership appeared with 10 remaining, and a separate Equip click set the equipped trail to Sky Blue. Studio session data resets when Play stops.
- Temporary client-only module checks verified no payout replay on repeated snapshots, immediate reduced-motion final values, intermediate-width lobby title fit, and wallet/purchase-label bounds at 320/401/600/750/2075px widths including the maximum supported balance. A tied practice result exposed an existing misleading victory heading; it now shows DEAD HEAT, verified against a tied diagnostic snapshot. Temporary modules and GUIs were destroyed.
- The final fresh Play logged client/server ready without runtime errors. One earlier inspection command used a wrong reward-frame name; that was an AssistantCommand diagnostic error, corrected during inspection, not a game script failure. `git diff --check` passed. Existing automated checks passed: 30 player-stats tests, 9 cosmetic-catalog tests, and 29 server scenarios. Published persistence and real-device input/performance were not revalidated by this UI pass.

## Hangar redesign — October 9, 2026

This pass rebuilt the hangar layout, added the PLAY quick match, the personal bay, the unlock stand, other pilots' bays, the flight board and runway departures, and made Fly Again skip the course vote. Preview: [hangar](previews/hangar-redesign.jpg).

Checked in a single-client Studio Play session on desktop:

- The place loads and plays with no script errors in the Output window, across two builds.
- The spawn camera frames the parked plane, the unlock stand, both gates and the flight board.
- The plane arrows and paint swatch change the parked plane (Cruiser to Skyhopper, coral to cyan).
- PLAY shows the search status with a countdown, Cancel returns to the hub, and after six seconds alone it starts a practice flight against the ghost.
- Fly Again after a practice flight opens directly on the power choice with the same course type.
- Returning with 50 coins sent coins from the plane to the stand, which turned green with "Ready - claim it!". Pressing E at the stand bought and equipped Sky Blue, left 10 coins, recolored the plane's ribbons and advanced the stand to Afterburner.
- The flight board showed the club best after the first landing, and a departure was visible on the runway.

Also checked outside Studio: `scripts/test_server.py` passes 33 scenarios with mocked Roblox services. Four are new (PLAY pairing two pilots, the ghost fallback and in-place cancel, PLAY joining a pad waiter, the flight board), and two rematch scenarios now expect the Configure phase.

Checked in a Studio Server & Clients session with two players (each client viewport about 494x228, a short landscape size):

- Player2 pressed PLAY alone and, after the fallback, flew the ghost. Player1's hangar showed Player2's wall bay as "Flying now" and the flight board read "Now flying Player2 vs Practice · Skipper".
- Both players pressed PLAY within the search window and entered the same human duel immediately; the flight HUD labelled the opponent as Rival, and results paid the 50-coin draw reward to each.
- After both returned, Player1 saw Player2's plane parked in a wall bay labelled "In the hangar", showing the Skyhopper Player2 had just switched to.
- The hub stack, coin pill and results layout fit the short landscape viewport. Player1's Output showed no script errors. Player2's Output showed one Roblox CoreScript chat error (`ChatScript: SetCore CoreGuiChatConnections has not been registered`), which is Studio's own script, not Skybound's.

Preview: [two pilots](previews/hangar-redesign-two-pilots.jpg).

Still to validate: portrait phones and the mobile jump-button clearance; gamepad navigation of the new buttons; reduced-motion mode; more than four other pilots (only four wall bays exist, so later arrivals are not shown).

## Battle Lab on the redesigned hangar — October 9, 2026

Integration of the Battle Lab work (as it stood in the working tree at 23:18) onto the hangar redesign. Conflicts were in the README, `build.py`, `Hud.luau`, `Main.client.luau` and `Main.server.luau`. The hangar's PLAY stack is kept; the Battle Lab entry button now sits directly above the plane selector instead of over it. A pilot searching through PLAY cannot enter the lab, a pilot in the lab shows as "Flying now" in other pilots' wall bays, and the hangar's local visuals are cleared while the lab is open.

- `scripts/test_server.py`: 40 scenarios pass (33 hangar, 7 Battle Lab). `scripts/sample_battle.py --tests-only`: 27 pass.
- Single-client Studio Play: no script errors. Entered the lab from the hangar, launched a Meteor vs Firework battle, returned with the Hangar button, then PLAY showed the rival search and Cancel returned to the hub.

Not checked: Battle Lab results screens after this merge, and two clients with one in the lab.
