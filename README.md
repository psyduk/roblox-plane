# Skybound — 1v1 flight prototype

A bright arcade flight club with a walkable social hub and independent two-pilot duels. Choose a launch plan, then watch fuel boosts and missiles determine how far the plane travels before touchdown. Flight is automatic after takeoff.

## Play locally

Open `Skybound.rbxlx` in Roblox Studio and press **Play**. The lobby builds automatically. Spawning does not start a match.

For a human duel, start a local server with at least two player clients using Studio's multiplayer test controls. Walk one player onto each of the two pads at the same duel station. Standing on a single pad waits for an opponent; walking off or pressing **Leave Queue** cancels that queue. Different stations can host separate matches concurrently.

To test alone, press **Practice vs Ghost**. This explicitly starts a duel against one labelled practice pilot. Ghosts are not added to human duels.

1. **Pair up:** two occupied pads create an independent 1v1 match and move both players into its match view.
2. **Vote:** choose Coast, Skyline, or Storm. The vote lasts eight seconds; both pilots receive the same generated course conditions.
3. **Configure:** select angle, power, one free gadget and a cosmetic color. Both pilots pressing **Ready to Fly** starts the countdown early; otherwise the 25-second setup deadline locks the choices.
4. **Watch:** after a three-second countdown, the planes fly automatically through staggered clusters of numbers and missiles. Fuel marked **+5 / +10 / +20** adds forward and upward momentum. Missiles reduce speed and push the plane down. Occasional low-altitude **+20** pockets or the rescue gadget can turn a dive upward. Floating feedback shows actual pickups, hits, shield saves and fully cleared near misses; near misses award no extra distance or boost.
5. **Touch down:** contacting the ground locks that plane's horizontal distance. The other plane continues until its own touchdown or the 45-second flight limit.
6. **Choose what is next:** results offer **Rematch** or **Return to Lobby**. A human rematch requires both pilots; practice requires only the human's request. Results expire back to the lobby after 90 seconds, without automatically starting another match.

## Controls and scoring

| Context | Controls |
| --- | --- |
| Hub and queue | Normal Roblox movement and camera; walk onto or off a paired pad |
| Setup | On-screen controls; **A / D** change angle, **W / S** change power, **R** marks ready |
| Flight | Watch automatically; **Q / E** or the camera arrows switch the watched pilot |
| Gamepad | Selectable on-screen buttons; **Y** marks ready; shoulder buttons switch the watched pilot |
| Leaving a duel | Use **Leave Duel** during flight or **Return to Lobby** after results |

Avatar movement controls are disabled during a match and restored in the hub. The flight HUD shows both pilots' distances, the local player's lead or deficit, the watched pilot's identity, and height above the ground.

The greatest horizontal distance wins. One displayed game meter equals one simulated stud. Final scores and personal best use **0.1 m** precision; equal scores share a rank. Leaving or disconnecting during flight forfeits the duel, even if that pilot had travelled farther. Leaving before flight cancels the pairing; an opponent who has left cannot accept a rematch.

All gadgets are free:

- **Shield:** absorbs one missile hit.
- **Magnet:** collects fuel from farther away without increasing missile collision range.
- **Boost:** provides one automatic rescue burst at low altitude.

The four plane colors have identical performance. Flight settings last for the current session. **My Stats** tracks furthest completed flight, best/current human duel streak, wins/losses/draws and flight/practice counts. Practice can improve distance records but never win streaks; ties preserve the current streak and forfeits reset it. Aborted flights cannot improve best distance.

### Saving and analytics

Studio deliberately uses **session-only** stats, shown in the HUD, and makes no DataStore calls. Published live servers use `Skybound_PlayerStats_v1` with server-only `UpdateAsync`, session leases, duplicate-result protection, retries, autosaves and departure/shutdown saves. Failed loads are never overwritten. Cloud saving still needs a published test experience and reconnect/multiple-server verification; do not enable Studio API access against production data just to test this prototype.

The starter analytics module uses native Roblox custom events for session duration, queueing, match starts/completions/duration, rematches and abandoned phases. Events distinguish practice from human duels, are rate limited, and contain no custom names, user IDs or arbitrary text. Roblox associates events with the supplied player. Analytics is disabled in Studio and enabled by default on published live servers; set the `FlightServer` script's `AnalyticsEnabled` attribute to `false` to opt out. Dashboards and live event delivery require published testing.

### Presentation

Coast has warm grass, coral bluffs, palms and lighthouses. Skyline has an elevated runway among sunset towers and skybridges. Storm has purple basalt, neon crystals, pylons and distant lightning. All three retain ground contact at y=0 and the existing simulation rules. Arena lighting is local to the duel and resets on returning to the hub.

Your character is represented by a cosmetic seated avatar in the plane; the actual walking character remains in the hub. Practice uses an original neutral ghost pilot. Fuel creates an expanding ripple and rising number, while impacts add sparks, a shockwave and smoke. Effects are pooled and cleaned up with the plane.

Flight sounds use event deduplication, bounded voice pools and a **Sound On/Off** button. Fuel pitches rise with pickup value; shields, impacts, near misses and touchdown have their own mix. The boing is the free [Cartoon Jump Sound by Dizzota](https://create.roblox.com/store/asset/2772396665), with a bundled Roblox jump fallback. Other layers use Roblox's bundled jump, landing, volume-slider and explosion sounds. No external audio was uploaded.

## Current scope

- Walkable procedural club, four paired duel stations, queue occupancy displays and optional practice.
- Independent match state, votes, settings and results for each pair.
- Server-controlled flight simulation, validated commands, shared course conditions and distance rankings.
- Automatic flight with a dedicated course view, two labelled planes, recovery events and camera switching.
- Setup and results controls adapted for short landscape phone screens.
- Cartoon arcade HUD with rounded outlined headings and scores, blue panels, green ready/rematch actions, and native course icons. Small instructions use a simpler font for readability.

Showroom planes, podiums and gift-shaped crates are visual placeholders. They do not sell, open or award items. Shops, paid cosmetics, crate rewards, trading, persistent inventory, final Blender assets and publishing are not implemented. No Robux products are connected.

## Source and build

Packaging requires **Python 3** and its standard library only. Run from this directory:

```sh
python3 scripts/build.py
```

This regenerates `Skybound.rbxlx` from the source files. Stop any running playtest and reopen the generated place after rebuilding. Keep code changes in `src/`; rebuilding replaces manual edits inside the generated place. An alternative output path is available with `--output /path/to/place.rbxlx`.

| File | Purpose |
| --- | --- |
| `src/shared/Simulation.luau` | Deterministic flight physics, fuel, missiles, gadgets and course generation |
| `src/shared/World.luau` | Procedural hub, paired pads, course scenery and plane rendering |
| `src/server/Main.server.luau` | Queues, independent duels, command validation, rematches, forfeits and rankings |
| `src/client/Main.client.luau` | Hub/match camera, interpolation, avatar controls, input and snapshots |
| `src/client/Hud.luau` | Hub guidance, voting, launch setup, duel readout and results |
| `src/client/PilotAvatar.luau` | Cosmetic seated player avatars and neutral ghost pilots |
| `src/client/FlightAudio.luau` | Pooled, event-driven flight sounds and mute |
| `src/server/PlayerStats.luau` | Fenced persistent statistics and honest session-only fallback |
| `src/server/Telemetry.luau` | Bounded native Roblox lifecycle analytics |
| `tests/Simulation.spec.luau` | Determinism, collision, recovery, touchdown and input-boundary checks |
| `scripts/test_server.py` | Optional server-flow checks using in-memory Roblox service doubles |
| `scripts/sample_simulation.py` | Optional repeatable seed/settings sample for flight length, collisions and low-altitude recoveries |

## Validation

Run the simulation suite inside Studio's Edit command bar after opening the generated place:

```lua
print(require(game.ServerStorage.SimulationTests)(require(game.ReplicatedStorage.FlightGame.Simulation)))
print(require(game.ServerStorage.PlayerStatsTests)(require(game.ServerScriptService.PlayerStats)))
print(require(game.ServerStorage.TelemetryTests)(require(game.ServerScriptService.Telemetry)))
```

During local Play, the **server** command bar can inspect the first player's authoritative snapshot:

```lua
print(game.ServerStorage.FlightDebug:Invoke("snapshot"))
```

The Studio-only `FlightDebug` helper also exposes `snapshots`, `tests`, `validateSettings`, `practice`, `queueMove`, `forcePair`, `command`, `configure` and `launch`. Player-specific actions accept a `userId` in the second argument. These shortcuts are for local diagnostics, not the player interface.

For optional server-flow checks outside Studio, install **lupa** in a Python environment, then run the harness:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install lupa
python scripts/test_server.py
```

The harness exercises queue pairing, match isolation, invalid commands, departures, rematches and one-ghost practice. It translates a small subset of Luau for Lua and substitutes Roblox services; it does not validate real networking, avatar physics, rendering or touch input. Actual Luau and gameplay validation remains in Roblox Studio, including separate player clients and phone emulation.

Using the same optional `lupa` environment, `python scripts/sample_simulation.py --samples 15` evaluates 225 flights across three courses and five launch presets. Add `--baseline /path/to/previous/Simulation.luau` to compare both versions with identical seeds. These are simulation outcomes, not player enjoyment or device performance measurements.

Recorded Studio checks and remaining gaps are in `VALIDATION.md`.
