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
