# Skybound — 1v1 flight prototype

A bright arcade flight club with a walkable aircraft hangar, earned flight effects and independent two-pilot duels. Choose one superpower and a launch angle, then watch your transformed plane bounce, eat missiles or dive into a forward blast. Flight is automatic after takeoff.

Product research and proposed next experiments are in [Skybound research and retention strategy](docs/RETENTION-STRATEGY.md), including competitors, replay improvements, progression ideas and success measures. Technical checks and remaining release gaps are in [VALIDATION.md](VALIDATION.md).

The observed BALL vs BALL lobby references and the scope chosen for this pass are in [Hangar references](docs/HANGAR-REFERENCES.md).

## Play locally

Open `Skybound.rbxlx` in Roblox Studio and press **Play**. The hangar builds automatically. Spawning does not start a match. Parked planes and fleet selection are to the left, the **Flight Effects** counter is to the right, and the four 1v1 departure gates are ahead. The open hangar doors frame an apron and runway; a solo dispatch desk also starts practice.

For a human duel, start a local server with at least two player clients using Studio's multiplayer test controls. Walk one player onto each of the two pads at the same duel station. Standing on a single pad waits for an opponent; walking off or pressing **Leave Queue** cancels that queue. Different stations can host separate matches concurrently.

To test alone, press **Practice vs Ghost**. This explicitly starts a duel against one labelled practice pilot. Ghosts are not added to human duels.

1. **Pair up:** two occupied pads create an independent 1v1 match and move both players into its match view.
2. **Vote:** choose Coast, Skyline, or Storm. The vote lasts eight seconds; both pilots receive the same generated course conditions.
3. **Choose your power:** select Pinball, Missile Muncher or Meteor Dive from three large animated cards, optionally change the free plane and paint, then press **Lock In Power**. Once both pilots confirm, or the 25-second selection timer expires, these choices lock and the selection panel closes.
4. **Aim your jet:** on the wider runway view, click or touch ahead of the jet to point it toward your chosen direction, or hold and drag to adjust within **15–60°**. Trajectory dots help line up the shot, keeping the jet clear of angle labels and a crosshair. The dotted guide previews the first three seconds without predicting future course contacts. Release sets the angle; **Ready to Launch** confirms it. Both pilots confirming, or the separate 20-second aiming timer expiring, starts the shared three-second countdown.
5. **Watch:** the planes fly automatically through staggered clusters of numbers and missiles. Fuel marked **+5 / +10 / +20** adds momentum. Missiles reduce speed and push the plane down unless Missile Muncher eats them. Meteor stays committed to its dive through fuel contacts; its own pull-up creates the recovery. Floating feedback shows actual pickups, hits, shield saves and fully cleared near misses; near misses award no extra distance or boost.
6. **Touch down:** final ground contact locks that plane's horizontal distance; Pinball spends its three bounces first. The other plane continues until its own touchdown or the 45-second flight limit.
7. **Choose what is next:** results offer **Rematch** or **Return to Lobby**. A human rematch requires both pilots; practice requires only the human's request. Results expire back to the lobby after 90 seconds, without automatically starting another match.

## Controls and scoring

| Context | Controls |
| --- | --- |
| Hub and queue | Normal Roblox movement and camera; walk onto or off a paired pad |
| Hangar stations | Use the nearby prompt (**E** on keyboard) to select a free fleet plane, browse effects or start solo practice |
| Effects shop | **Flight Effects** also opens the shop anywhere in the hub; select an effect, buy with credits, then **Equip**; **X**, **Escape** or gamepad **B** closes it |
| Selection | Choose a power, plane and color; **Lock In Power** or **R** confirms the choices |
| Aiming | Click/tap ahead or hold and drag to aim; release sets the angle; **A / D** adjust by 1°; **Ready to Launch** or **R** marks ready |
| Flight | Watch automatically; **Q / E** or the camera arrows switch the watched pilot |
| Gamepad | Selectable on-screen buttons; **Y** marks ready; shoulder buttons switch the watched pilot |
| Leaving a duel | Use **Leave Duel** during flight or **Return to Lobby** after results |

Avatar movement controls are disabled during a match or while the effects shop is open, and restored in the hub when the shop closes. The flight HUD shows both pilots' distances, the local player's lead or deficit, the watched pilot's identity, and height above the ground.

The greatest horizontal distance wins. One displayed game meter equals one simulated stud. Final scores and personal best use **0.1 m** precision; equal scores share a rank. Leaving or disconnecting during flight forfeits the duel, even if that pilot had travelled farther. Leaving before flight cancels the pairing; an opponent who has left cannot accept a rematch.

All three planes are freely selectable. Each has a fixed catalog launch speed; dragging changes direction, not power. Changing planes resets the aim to that plane's starting angle, which can then be adjusted on the jet screen. Power, plane and color lock when aiming begins; angle locks at countdown. The profiles are distinct options, not established balance tiers.

| Plane | Launch speed | Starting angle |
| --- | --- | --- |
| Cruiser | 72.25 m/s | 35° |
| Skyhopper | 64.5 m/s | 48° |
| Dart | 81 m/s | 24° |

All three powers are free and activate automatically after takeoff. Choose exactly one per round; charges reset on rematch:

| Power | Flight rule | Launch strategy |
| --- | --- | --- |
| **Pinball** | The first three ground contacts bounce the plane upward and add forward momentum; the fourth lands. | Aim low to use the ground as a launchpad. |
| **Missile Muncher** | The first three missile contacts feed increasingly strong boosts instead of causing damage; later missiles hit normally. | Aim through missile lanes. |
| **Meteor Dive** | The first apex starts a fast dive, followed by one automatic pull-up near the ground. Peak altitude determines the forward burst. | Aim high to charge the blast. |

Powers replace the former gadget picker. A selected power has no hidden Shield, Magnet or rescue-Boost effect. These are initial balance settings, not established competitive tiers.

The four plane colors have identical performance. Flight settings last for the current session. **My Stats** tracks furthest completed flight, best/current human duel streak, wins/losses/draws and flight/practice counts. Practice can improve distance records but never win streaks; ties preserve the current streak and forfeits reset it. Aborted flights cannot improve best distance.

### Earn, buy and equip effects

Complete a flight, see the earned credits on results, return to the hangar, then open **Flight Effects**. Browse the catalog or **My Collection**, inspect the plane and trail-color preview, buy an effect and press **Equip** to use it on the next flight. Buying adds ownership; equipping is a separate action. Queueing allows browsing, but purchases and equipment changes require leaving the queue.

| Completed flight | Credits |
| --- | --- |
| Practice, regardless of result | 25 |
| Human duel loss | 40 |
| Human duel draw | 50 |
| Human duel win | 60 |

Aborted flights and forfeits award no credits. The server validates rewards, prices, ownership and equipment; repeating a result cannot grant another reward. Trails change appearance only, with no effect on flight physics or power strength.

Classic Contrail is owned initially. The five unlocks cost **40** (Sky Blue), **100** (Afterburner), **180** (Mint Current), **300** (Violet Pulse) and **500** (Golden Hour) credits. The hub shows progress toward the next unowned effect. The showroom and shop use static colored ribbons for preview; actual moving trails appear during flight.

### Saving and analytics

Studio deliberately uses **session-only** stats, credits, ownership and equipped trails, shown in the HUD and shop, and makes no DataStore calls. Purchases work during Play but reset when that session stops. Published live servers use `Skybound_PlayerStats_v1` with server-only `UpdateAsync`, session leases, duplicate-result protection, retries, autosaves and departure/shutdown saves. Statistics and the cosmetic collection share one record; existing version-one statistics migrate with the default free trail. Failed loads are never overwritten, and purchases are disabled while data is loading or cloud saving is unavailable. Published persistence is implemented but still needs a published test experience and reconnect/multiple-server verification; do not enable Studio API access against production data just to test this prototype.

The starter analytics module uses native Roblox custom events for session duration, queueing, match starts/completions/duration, rematches and abandoned phases. Events distinguish practice from human duels, are rate limited, and contain no custom names, user IDs or arbitrary text. Roblox associates events with the supplied player. Analytics is disabled in Studio and enabled by default on published live servers; set the `FlightServer` script's `AnalyticsEnabled` attribute to `false` to opt out. Dashboards and live event delivery require published testing.

### Presentation

The hangar has metal walls, roof trusses and skylights, work lights, concrete floors, taxiway markings, parked aircraft with landing gear, maintenance carts and labelled departure gates. The fleet bays select free planes; the effects counter opens the working shop. Three parked effect displays show trail colors and prices, and the solo dispatch corner offers practice.

Coast has warm grass, coral bluffs, palms and lighthouses. Skyline has an elevated runway among sunset towers and skybridges. Storm has purple basalt, neon crystals, pylons and distant lightning. All three retain ground contact at y=0 and the existing simulation rules. Arena lighting is local to the duel and resets on returning to the hub.

Your character is represented by a cosmetic seated avatar in the plane; the walking character is hidden during the duel and restored to the hub afterward. Practice uses an original neutral ghost pilot. Power choice uses oversized illustrated cards, a lock-in burst and a large countdown. Pinball gains a rubber cage, Muncher gains animated jaws and teeth, and Meteor gains a fiery core and fins. Their activations create distinct BOING, CHOMP, DIVE and BLAST callouts, pooled bursts and layered sound cues. Fuel creates an expanding ripple and rising number, while impacts add sparks, a shockwave and smoke. Effects are pooled and cleaned up with the plane.

Flight sounds mix events from both pilots, including the practice ghost, with relative gain **1.0** for the watched pilot and **0.65** for the rival. Each pilot keeps an independent event cursor and cooldowns, so switching cameras changes the mix without replaying old contacts or suppressing the other pilot's events. Sounds use bounded voice pools and a **Sound On/Off** button. Fuel pitches rise with pickup value; shields, impacts, near misses and touchdown have their own mix. The boing is the free [Cartoon Jump Sound by Dizzota](https://create.roblox.com/store/asset/2772396665), with a bundled Roblox jump fallback. Other layers use Roblox's bundled jump, landing, volume-slider and explosion sounds. No external audio was uploaded.

## Current scope

- Walkable procedural aircraft hangar, selectable fleet bays, four paired duel gates, queue occupancy displays and optional practice.
- Earned credit rewards, five purchasable cosmetic trails, collection filtering, preview and separate equip actions.
- Server-controlled cosmetic ownership and equipped trails, with Studio session storage and a published persistence implementation awaiting live verification.
- Independent match state, votes, settings and results for each pair.
- Server-controlled flight simulation, validated commands, shared course conditions and distance rankings.
- Three free selectable plane models with fixed launch speeds and a draggable angle preview.
- Automatic flight with a dedicated course view, two labelled planes, recovery events and camera switching.
- Setup and results controls adapted for short landscape phone screens.
- Cartoon arcade HUD with rounded outlined headings and scores, blue panels, green ready/rematch actions, and native course icons. Small instructions use a simpler font for readability.

All fleet planes remain free and can be selected in the hangar or during match setup. The first shop sells known cosmetic trails for earned credits. Plane purchases, paid cosmetics, random crates, trading, daily quests, launch/landing effect categories, final Blender assets and publishing remain future work. No Robux products are connected.

## Source and build

Packaging requires **Python 3** and its standard library only. Run from this directory:

```sh
python3 scripts/build.py
```

This regenerates `Skybound.rbxlx` from the source files. Stop any running playtest and reopen the generated place after rebuilding. Keep code changes in `src/`; rebuilding replaces manual edits inside the generated place. An alternative output path is available with `--output /path/to/place.rbxlx`.

| File | Purpose |
| --- | --- |
| `src/shared/PlaneCatalog.luau` | Free selectable plane IDs, fixed launch speeds, starting angles and display metadata |
| `src/shared/PowerCatalog.luau` | Free round powers, descriptions, launch hints and display colors |
| `src/shared/CosmeticCatalog.luau` | Earned trail IDs, prices, appearance and completed-flight reward amounts |
| `src/shared/Simulation.luau` | Deterministic flight physics, automatic powers, aim preview, fuel, missiles and course generation |
| `src/shared/World.luau` | Procedural hangar, fleet and effects stations, paired pads, course scenery and cosmetic plane rendering |
| `src/server/Main.server.luau` | Queues, independent duels, command validation, rematches, forfeits and rankings |
| `src/client/Main.client.luau` | Hub/match camera, interpolation, avatar controls, input and snapshots |
| `src/client/Hud.luau` | Hub guidance, voting, launch setup, duel readout and results |
| `src/client/EffectsShop.luau` | Responsive effects catalog, collection filtering, plane/color preview, buy/equip actions and save feedback |
| `src/client/PilotAvatar.luau` | Cosmetic seated player avatars and neutral ghost pilots |
| `src/client/FlightAudio.luau` | Pooled two-pilot flight sounds, independent event cursors and mute |
| `src/server/PlayerStats.luau` | Fenced statistics and cosmetic economy, credit rewards, validated purchases/equipment and session-only fallback |
| `src/server/Telemetry.luau` | Bounded native Roblox lifecycle analytics |
| `tests/Simulation.spec.luau` | Determinism, collision, recovery, touchdown, plane speed, aim preview and input-boundary checks |
| `tests/PlaneCatalog.spec.luau` | Free selection, profile metadata, detached records and invalid-ID checks |
| `tests/CosmeticCatalog.spec.luau` | Trail catalog IDs, prices, appearance data and detached records |
| `tests/PlayerStats.spec.luau` | Statistics persistence, economy migration, reward deduplication, purchases and equipment validation |
| `tests/FlightAudio.spec.luau` | Two-pilot mix, camera switches, event cursors, cooldowns and cleanup without emitting sound |
| `scripts/test_server.py` | Optional server-flow checks using in-memory Roblox service doubles |
| `scripts/sample_simulation.py` | Optional repeatable seed/settings sample for flight length, collisions and low-altitude recoveries |

## Validation

Run the simulation suite inside Studio's Edit command bar after opening the generated place:

```lua
print(require(game.ServerStorage.SimulationTests)(require(game.ReplicatedStorage.FlightGame.Simulation)))
print(require(game.ServerStorage.PlaneCatalogTests)(require(game.ReplicatedStorage.FlightGame.PlaneCatalog)))
print(require(game.ServerStorage.PowerCatalogTests)(require(game.ReplicatedStorage.FlightGame.PowerCatalog)))
print(require(game.ServerStorage.CosmeticCatalogTests)(require(game.ReplicatedStorage.FlightGame.CosmeticCatalog)))
print(require(game.ServerStorage.PlayerStatsTests)(require(game.ServerScriptService.PlayerStats)))
print(require(game.ServerStorage.TelemetryTests)(require(game.ServerScriptService.Telemetry)))
print(require(game.ServerStorage.FlightAudioTests)(require(game.StarterPlayer.StarterPlayerScripts.FlightAudio)))
```

During local Play, the **server** command bar can inspect the first player's authoritative snapshot:

```lua
print(game.ServerStorage.FlightDebug:Invoke("snapshot"))
```

The Studio-only `FlightDebug` helper also exposes `snapshots`, `tests`, `validateSettings`, `practice`, `queueMove`, `forcePair`, `command`, `configure`, `aim` and `launch`. Player-specific actions accept a `userId` in the second argument. These shortcuts are for local diagnostics, not the player interface.

For optional server-flow checks outside Studio, install **lupa** in a Python environment, then run the harness:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install lupa
python scripts/test_server.py
```

The harness exercises queue pairing, match isolation, plane selection, angle validation, speed-spoof rejection, configuration locks, departures, rematches, one-ghost practice and statistics saving. It translates a small subset of Luau for Lua and substitutes Roblox services; it does not validate real networking, avatar physics, rendering, audible output or touch input. Actual Luau and gameplay validation remains in Roblox Studio, including separate player clients and phone emulation.

Using the same optional `lupa` environment, `python scripts/sample_simulation.py --samples 15` evaluates 315 flights across three courses and seven plane/angle/gadget presets. Add `--baseline /path/to/previous/Simulation.luau` to compare both versions with identical seeds; old power-based modules receive an approximate equivalent speed setting. These are simulation outcomes, not player enjoyment or device performance measurements.

Recorded Studio checks and remaining gaps are in `VALIDATION.md`.
