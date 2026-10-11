# Sky Battle

Build a flying fighter, watch your choices matter, then outsmart the same rival next round. The free playtest candidate implements approved **Milestones 1 and 2**. Milestones 3 and 4, paid products and combat roster expansion remain outside scope.

The approved direction is in [the ticket review](docs/SKY-BATTLE-TICKET-REVIEW.md). Current evidence and limitations are in [VALIDATION.md](VALIDATION.md); use [the playtest handoff](docs/SKY-BATTLE-PLAYTEST.md) for the published two-player and real-phone gate. This build is ready for iteration, not a claim of proven balance, comprehension or retention.

## Play

Build with the commands below, then open **`build/Sky-Battle-Playtest.rbxlx` from this checkout** in Roblox Studio. Confirm that distinct filename in the Studio window title; an older `Skybound.rbxlx` window may belong to a different worktree. Press Studio **Play**, then the hangar's main **PLAY** button. The expected flow is **rival search → card pick → first-to-two plane battle**. If you see distance, launch-angle or furthest-flight results, stop: that is the old mode, not this candidate.

A human searching in the same server joins immediately; after eight seconds alone you get a named, clearly labelled bot. Choose an offence from three offers and **LOCK IN**. Your pilot fights automatically. The ten-second pick deadline takes the first offered card.

- **First to two round wins.** Both players gain a wild-card pick after each decisive round, up to two different wild cards. New picks stay hidden until both lock, then reveal together. Every match and rematch starts with empty builds.
- **Shared roster:** Meteor, Firework, Machine Gun and Pinball; Afterburner, Spring Bumper, Fizzy Fuel, Magnet and Second Wind. Every human and bot has identical access. The aircraft, paint and trail you choose are cosmetic.
- **One free Reroll and one free Pick Any per match.** These remain spent through drawn rounds. Reroll never returns the identical eligible set when an alternative exists.
- **Three armor pips per round.** After 18 seconds the visible wind boundary closes. At 35 seconds, more armor wins and equal armor draws. Draws add neither a point nor a new pick. A match stops at five physical rounds or 240 seconds; only completed-round wins determine that result. There is no hidden tiebreak.
- **Same rival:** REMATCH requires both humans. Next opponent searches again. The hangar's **Challenge a pilot** invites someone in the same server; Accept/Decline, cancel and expiry are explicit. No invite interrupts an active match.
- **Automatic participation counts.** A qualifying completion gives 50 coins, plus 25 for a win. A first-match trail choice and a 250-coin Aurora goal are cosmetic. Mastery titles at 1, 5 and 15 completions add no combat power. Five qualifying losses from zero buy the goal. See [the eligibility rules](docs/ECONOMY-CONTRACT.md).
- Results show the score, final builds, factual turning point, reward, save status and goal. Replay remains available while optional cosmetics are shown. Hangar exits every phase. Sound and reduced-motion controls are available in battle.

Combat and progression are server-owned. Clients cannot choose the rival's cards, fabricate a reward, alter the simulation clock or buy combat access. No Robux purchase path is enabled.

**Legendary flying cosmetics:** Stormcrown Eagle, Ironwing Eagle, Eclipse Phoenix, and Rift Manta join the three existing planes. Open `build/Sky-Battle-Mounts-Final.rbxlx`, press Studio **Play**, use the hangar's **< / >** arrows to choose a look, then press the main **PLAY** button. Their wings animate in the hangar and battle, and your avatar rides the saddle. The templates use a 16-stud visual wingspan, `PilotScale=0.6`, and a 0.65-stud rider root offset above the normalized saddle. All four use Cruiser's flight profile and the unchanged shared battle contracts, including `BattleVisualSize=12`. They are free prototype cosmetics with Legendary labels and no purchase requirement. Published to [Skybound Test](https://www.roblox.com/games/86507299893768/Skybound-Test) as version **21** on **October 11, 2026 at 07:35:07 UTC**; the source and templates were verified in the target Studio place before publication. Live-server asset loading, independent-player gameplay, and phone performance remain unverified. All four flew through the normal UI in the earlier native candidate. The freshly opened final build passed the catalog, mount, and battle-view checks; all four final Studio previews also verified the rider-pose fix for the tested avatar. See [screenshots, asset pipeline, contracts, and validation](docs/LEGENDARY-FLIGHT-COSMETICS.md).

## Build and checks

Packaging uses Python's standard library:

```sh
python3 scripts/build.py
python3 scripts/validate_package.py --manifest docs/validation/sky-battle-build.json
python3 scripts/validate_package.py --place build/Sky-Battle-Playtest.rbxlx
```

The default build refreshes both canonical `Skybound.rbxlx` and the byte-identical `build/Sky-Battle-Playtest.rbxlx`, and prints the exact absolute path to open. Stop old Play sessions and reopen that file after **every rebuild**; Studio does not reload an already-open document when its disk file changes. Keep edits in `src/` and `tests/`; regenerating the place replaces manual edits. `--output /path/to/place.rbxlx` builds only that alternative output. Building does not publish or update an existing Roblox experience.

The package check requires every source/spec to match the generated place exactly, rejects an enabled serialized `DistanceModeEnabled` attribute, and rejects retained experimental/fixed-seed flags or installed network QA fixtures. Packaged test ModuleScripts remain allowed. Passing this check proves the artifact's contents; a handoff also requires opening that exact candidate and visually verifying the PLAY flow above.

Offline checks use optional `lupa` (the existing environment is `build/testenv/bin/python`):

```sh
build/testenv/bin/python scripts/sample_battle.py --tests-only
build/testenv/bin/python scripts/test_server.py
build/testenv/bin/python scripts/sample_battle.py --samples 20 --markdown
build/testenv/bin/python scripts/sample_battle.py --samples 3 --wild-sample --json
```

The sampler discovers the active catalog. It reports ordered pairings, both seats, raw draws/caps, half-point scores, median/p90 duration, seed-level uncertainty, wild-card lifts and paired-card interactions. `--skill Firework` narrows a run; `--quick` is a disclosed screening mode. `--baseline /path/to/old/BattleSimulation.luau --baseline-scope outcomes` compares outcomes; existing exact baseline modes remain. Use `--help` for all options. [Balance report](docs/BALANCE-REPORT.md) records commands, samples and failing tuning targets; sample results are not player-experience evidence. Expansion skills are not included.

Native Studio **server** command-bar checks during Play:

```lua
local t=game.ServerStorage
local s=game.ReplicatedStorage.FlightGame
local c=game.StarterPlayer.StarterPlayerScripts
print(require(t.BattleSimulationTests)(require(s.BattleSimulation),require(s.SkillCatalog),require(s.BattleSkills)))
print(require(t.SkillCatalogTests)(require(s.SkillCatalog)))
print(require(t.MountVisualsTests)(require(s.World)))
print(require(t.BattleMatchTests)(require(game.ServerScriptService.BattleLab),require(s.SkillCatalog)))
print(require(t.PlayerStatsTests)(require(game.ServerScriptService.PlayerStats)))
print(require(t.CosmeticCatalogTests)(require(s.CosmeticCatalog)))
print(require(t.TelemetryTests)(require(game.ServerScriptService.Telemetry)))
print(require(t.BattleViewTests)(require(c.BattleView),require(s.World),require(s.BattleSimulation)))
print(require(t.BattleAudioTests)(require(c.BattleAudio)))
print(require(t.BattleClientTests)(require(c.BattleLab)))
```

Presentation test fixtures temporarily use the camera. Restart Play afterward before visual testing. Native module checks still use controlled fixtures; separate clients and physical devices are required for network and usability claims.

Studio-only diagnostics: `game.ServerStorage.FlightDebug:Invoke("battleSnapshot")`, `"battleTelemetry"`, `"snapshot"`, `"snapshots"`, or `"battleCommand"` with `{userId=...,payload={...}}`. The diagnostic command follows normal validation. Set `FlightServer.BattleFixedSeed` to a number **before Play** only for reproducibility; it disables rewards. Studio never writes the live player-data store.

For an isolated Studio roster experiment, set `BattleExperimental=true`, `BattleExperimentalVersion`, and comma-separated `BattleExperimentalOffences`/`BattleExperimentalWilds` on `FlightServer` before Play. Only registered skills are eligible; invalid pools are refused, pool fingerprints isolate queues, and experiment rewards are disabled. Published servers ignore this override. Clear these attributes for the release candidate.

## Code map

| Area | Source |
| --- | --- |
| Shared active cards and build rules | `src/shared/SkillCatalog.luau` |
| Deterministic skill hooks and combat | `BattleSkills.luau`, `BattleSimulation.luau`; [combat contract](docs/COMBAT-CONTRACT.md) |
| Queues, invitations, hidden draft, caps and authoritative results | `src/server/BattleLab.luau` |
| Profiles, fenced saving, reward receipts and cosmetic/mastery progression | `src/server/PlayerStats.luau` |
| Main integration and bounded replay funnel | `src/server/Main.server.luau`, `Telemetry.luau` |
| Draft, reveal, result, reward and replay interface | `src/client/BattleLab.luau` |
| Aircraft signatures, storm, impact and crash presentation | `src/client/BattleView.luau` |
| Shared sound vocabulary and combat audio | `src/client/BattleAudio.luau` |
| Same-server invitation interface | `src/client/ChallengePanel.luau` |
| Cosmetic preview, goal selection and hangar | `EffectsShop.luau`, `HangarBay.luau`, `World.luau` |

The versioned replay funnel separates button requests from actual next launches, and records mode, bot/human, device, cohort, roster, stage abandonment and phase timing. Studio/developer diagnostics are not retention cohorts. The [playtest sheet](docs/SKY-BATTLE-PLAYTEST.md) defines a 12–20 unfamiliar-player discovery cohort and predeclared iteration thresholds. Analytics service limits can drop submissions; use the bounded Studio diagnostic record for controlled event-order verification.

The earlier distance-flight mode remains disabled by default. Its explicit opt-in regression coverage and source remain in [the archived reference](docs/DISTANCE-FLIGHT-REFERENCE.md). Battle play and cosmetics do not revive that mode.
