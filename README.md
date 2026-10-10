# Skybound — plane battles

A bright arcade flight club with a walkable aircraft hangar and quick automatic plane battles. Press PLAY, choose a weapon and up to two wild cards, then watch the planes fight.

The current direction is documented in [Skybound Clash design](docs/SKYBOUND-CLASH-DESIGN.md): quick automatic plane battles, a few readable choices, and fresh combat builds each match. The earlier [flight retention research](docs/RETENTION-STRATEGY.md) remains background. Technical checks and remaining release gaps are in [VALIDATION.md](VALIDATION.md).

## Try the Battle Lab

Open `Skybound.rbxlx` in Roblox Studio, press **Play**, then select the main **PLAY** button in the hangar. Choose **Meteor** or **Firework**, add up to two wild cards, and press **FIGHT!**. The opposing plane is a bot whose build is rolled when the fight starts; it brings as many wild cards as you did. Both planes attack automatically; glowing committed dives and rockets remove one of three armor pips. Ordinary bumps only push.

The wild cards are **Afterburner** (a brief speed/turn burst after attacking), **Spring Bumper** (absorb the first damaging hit and spring apart), and **Fizzy Fuel** (a short damaging wake). A plane carries none, one or two different cards; with none, the fight moves exactly as it did before wild cards existed. Attack tells, impact feedback, spent-bumper/boost status and distinct sounds show their consequences. **Sound ON/OFF** shares the existing hangar mute preference.

Meteor pulls up and away, visibly charges, then commits to a fast ram that can still miss; Firework fires a slow rocket on its attack pass. Both have visible windup and recovery. Ordinary circling and recovery retain their existing movement. At 18 seconds, amber wind boundaries begin closing. At the 35-second cap, the plane with more armor wins; equal armor is a draw. Simultaneous knockouts also draw.

The signature presentation pass gives Meteor a heavier armored silhouette and comet-like dive, and Firework oversized launch tubes and striped, sputtering rockets. Each has distinct charge, release and hit sounds. Three-segment armor and brief hit flashes track actual damage; extra exhaust, sparks and light accents are cosmetic. The camera stays stable. A plane that loses its last armor segment tumbles to the arena floor, lands with a burst and thud, and remains as a wreck. Timeout survivors stay airborne. Retry is available immediately, including during a crash.

Results offer **Run it again**, **Change setup**, or **Hangar**. This lab uses a fixed seed so identical settings reproduce the same experiment. Retrying resets armor, positions, timers, rockets and effects. Test selections persist for convenience while in the lab; exiting and entering restores the defaults. Lab battles do not award flight stats, currency or cosmetics.

This is the first combat toy. Random offers, human combat matchmaking and multi-round drafting are later milestones. Firework mirrors currently trade into repeated draws; those are exposed honestly for testing. Competitive balance and replay appeal still need player observation.

Battle audio layers Roblox's bundled sounds with free licensed samples from the official Pro Sound Effects and APM Music Creator Store channels (asset IDs and titles are listed in `src/client/BattleAudio.luau`). The full look-and-feel backlog is in [the battle audit](docs/BATTLE-AUDIT.md).

Simulation checks: `build/testenv/bin/python scripts/sample_battle.py --tests-only`. With the optional Lupa dependency in another environment, use that environment's Python. Add `--samples 20 --mirrors` for reproducible matchup samples. Server-flow checks remain `python scripts/test_server.py`.

The observed BALL vs BALL lobby references and the scope chosen for this pass are in [Hangar references](docs/HANGAR-REFERENCES.md).

## Current hangar flow

Press **PLAY** in the hangar to open plane-battle setup. Choose a weapon and wild cards, then **FIGHT!**. **Hangar** returns to the parked-plane bay. There is one game entry; the old Solo button, separate Battle Lab shortcut, distance gates and automatic pad matchmaking are absent from the default build.

The plane selector, paint, owned cosmetics and hangar scenery remain available. These hangar appearance choices do not replace the Meteor/Firework battle choices. The existing cosmetic collection and flight records are retained; combat rewards and progression are still future work.

Distance flight is preserved for later in the source and [archived mode reference](docs/DISTANCE-FLIGHT-REFERENCE.md). It is disabled on the server by default, including direct practice requests and former pad locations, so players cannot accidentally enter it.

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
| `src/shared/SkillCatalog.luau` | Every battle skill: kind (offence or wild card), name, card copy, colour, starter flag, and the rule for a legal build |
| `src/shared/BattleSkills.luau` | What each battle skill does, as one table of hooks per skill |
| `src/shared/BattleSimulation.luau` | Deterministic plane battle: movement, phases, collisions, damage and endings. Calls skill hooks; names no skill |
| `src/shared/World.luau` | Procedural hangar, bays, flight board and effects counter, paired pads, course scenery and cosmetic plane rendering |
| `src/server/Main.server.luau` | Queues, independent duels, command validation, rematches, forfeits and rankings |
| `src/client/Main.client.luau` | Hub/match camera, interpolation, avatar controls, input and snapshots |
| `src/client/Hud.luau` | Hub guidance, voting, launch setup, duel readout and results |
| `src/client/EffectsShop.luau` | Responsive effects catalog, collection filtering, plane/color preview, buy/equip actions and save feedback |
| `src/client/HangarBay.luau` | Per-pilot hangar visuals: your parked plane and trail ribbons, the next-unlock stand and claim, coin flight, other pilots' bays and runway departures |
| `src/client/PilotAvatar.luau` | Cosmetic seated player avatars and neutral ghost pilots |
| `src/client/FlightAudio.luau` | Pooled two-pilot flight sounds, independent event cursors and mute |
| `src/server/PlayerStats.luau` | Fenced statistics and cosmetic economy, credit rewards, validated purchases/equipment and session-only fallback |
| `src/server/Telemetry.luau` | Bounded native Roblox lifecycle analytics |
| `tests/Simulation.spec.luau` | Determinism, collision, recovery, touchdown, plane speed, aim preview and input-boundary checks |
| `tests/PlaneCatalog.spec.luau` | Free selection, profile metadata, detached records and invalid-ID checks |
| `tests/CosmeticCatalog.spec.luau` | Trail catalog IDs, prices, appearance data and detached records |
| `tests/PlayerStats.spec.luau` | Statistics persistence, economy migration, reward deduplication, purchases and equipment validation |
| `tests/BattleSimulation.spec.luau` | Battle determinism, collisions, endings, each wild card alone and in pairs, catalog/behaviour agreement |
| `tests/SkillCatalog.spec.luau` | Skill copy, kinds, starters, detached records and build rules |
| `tests/FlightAudio.spec.luau` | Two-pilot mix, camera switches, event cursors, cooldowns and cleanup without emitting sound |
| `scripts/test_server.py` | Optional server-flow checks using in-memory Roblox service doubles |
| `scripts/sample_simulation.py` | Optional repeatable seed/settings sample for flight length, collisions and low-altitude recoveries |

## How to add a battle skill

A skill is two things with the same id: a card in `src/shared/SkillCatalog.luau` and a behaviour table in `src/shared/BattleSkills.luau`. Nothing else needs to know its name.

1. **Catalog entry.** Add the id to `order` and a record to `skills`: `kind` (`"offence"` or `"wild"`), `name`, `icon`, `word`, `promise`, `color`, `starter`, `rarity`. An offence also needs `windupTell` and `attackTell`, the words shown over the plane. The setup screen, server validation and fighter bar pick it up from here.
2. **Behaviour table.** Add `BattleSkills.offence.<Id>` or `BattleSkills.wild.<Id>`. The comment at the top of that file lists every field and hook. An offence needs six numbers (`windup`, `attackTime`, `attackSpeed`, `earliest`, `leadSpeed`, `leadFactor`) and usually an `attack` hook; a wild card needs only the hooks it uses.
3. **Run the checks.** `scripts/sample_battle.py --tests-only` fails if a card has no behaviour or a behaviour has no card, and runs every wild card loadout to the end of a round.

Rules a skill must keep, because other skills and the replay tools rely on them:

- **Deterministic.** No `math.random`, clocks or Roblox services. The same seed and builds must give the same fight.
- **Use the helpers.** Create projectiles with `api.launch`, puffs with `api.puff` and events with `api.event`; they keep ids and limits correct. A projectile may set `source` to name itself in hit events.
- **Own your state.** Give a wild card's private fields their starting values in `start`; read and write them only from that skill. A plane without the skill does not have the fields.
- **Read the rival carefully.** In `attack`, `inPosition`, `approach` and `windupStart` the rival is its position from before the tick: only `id`, `x`, `y`, `vx`, `vy`.
- **Hook order is fixed.** A plane's wild cards run in alphabetical order of id, whatever order they were picked in. When a hit lands, each of the target's wild cards may cancel it through `hit`; the first to return `true` wins and the rest are not asked, so two cancelling cards never both spend themselves on one hit. Impact protection (0.85s after any hit or cancel) is checked before any card.
- **Tell the player.** Emit an event when the skill does something (`"skill"` with the skill's id for an activation, `"blocked"` for a cancelled hit) so the view and audio can show it. A new skill is drawn as a default plane until it gets its own look in `BattleView`.

If a skill needs something the hooks cannot do, add a hook to `BattleSimulation.luau` and document it in `BattleSkills.luau` rather than naming the skill in the simulation. After a change that should not alter existing fights, compare against the previous simulation tick for tick: `scripts/sample_battle.py --tests-only --samples 10 --wild-sample --baseline <old BattleSimulation.luau>`.

## Validation

Run the simulation suite inside Studio's Edit command bar after opening the generated place:

```lua
print(require(game.ServerStorage.SimulationTests)(require(game.ReplicatedStorage.FlightGame.Simulation)))
print(require(game.ServerStorage.PlaneCatalogTests)(require(game.ReplicatedStorage.FlightGame.PlaneCatalog)))
print(require(game.ServerStorage.PowerCatalogTests)(require(game.ReplicatedStorage.FlightGame.PowerCatalog)))
print(require(game.ServerStorage.CosmeticCatalogTests)(require(game.ReplicatedStorage.FlightGame.CosmeticCatalog)))
print(require(game.ServerStorage.SkillCatalogTests)(require(game.ReplicatedStorage.FlightGame.SkillCatalog)))
print(require(game.ServerStorage.BattleSimulationTests)(require(game.ReplicatedStorage.FlightGame.BattleSimulation), require(game.ReplicatedStorage.FlightGame.SkillCatalog), require(game.ReplicatedStorage.FlightGame.BattleSkills)))
print(require(game.ServerStorage.PlayerStatsTests)(require(game.ServerScriptService.PlayerStats)))
print(require(game.ServerStorage.TelemetryTests)(require(game.ServerScriptService.Telemetry)))
print(require(game.ServerStorage.FlightAudioTests)(require(game.StarterPlayer.StarterPlayerScripts.FlightAudio)))
```

During local Play, the **server** command bar can inspect the first player's authoritative snapshot:

```lua
print(game.ServerStorage.FlightDebug:Invoke("snapshot"))
```

The Studio-only `FlightDebug` helper also exposes `battleSnapshot`, `battleCommand`, `snapshots`, `tests`, `validateSettings`, `practice`, `queueMove`, `forcePair`, `command`, `configure`, `aim` and `launch`. Player-specific actions accept a `userId` in the second argument. These shortcuts are for local diagnostics, not the player interface.

For optional server-flow checks outside Studio, install **lupa** in a Python environment, then run the harness:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install lupa
python scripts/test_server.py
```

The harness exercises queue pairing, match isolation, plane selection, angle validation, speed-spoof rejection, configuration locks, departures, rematches, one-ghost practice and statistics saving. It translates a small subset of Luau for Lua and substitutes Roblox services; it does not validate real networking, avatar physics, rendering, audible output or touch input. Actual Luau and gameplay validation remains in Roblox Studio, including separate player clients and phone emulation.

Using the same optional `lupa` environment, `python scripts/sample_simulation.py --samples 15` evaluates 315 flights across three courses and seven plane/angle/gadget presets. Add `--baseline /path/to/previous/Simulation.luau` to compare both versions with identical seeds; old power-based modules receive an approximate equivalent speed setting. These are simulation outcomes, not player enjoyment or device performance measurements.

For powered pacing, use `python scripts/sample_simulation.py --powers --samples 5 --baseline /path/to/previous/Simulation.luau`. This compares 405 flights per version and matched cross-power duels, reporting flight duration, the wait between landings, time within 100 metres, and wins/ties. `--json` provides machine-readable results; `--arenas` and `--angles` narrow a tuning experiment. Equal-angle comparisons are not optimized launch strategies. The first pacing pass is recorded in [the October 9 sample](docs/PACING-SAMPLE-2026-10-09.json).

Recorded Studio checks and remaining gaps are in `VALIDATION.md`.
