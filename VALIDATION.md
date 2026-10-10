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
