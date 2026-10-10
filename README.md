# Pop Duel

A Roblox arcade duel: **one shot, matching boards, highest score wins.** Aim through colorful targets, trigger a power, and watch the ricochets build your score. Pop Duel is the sole active project in this repository.

![Pop Duel desktop with player avatars](docs/screenshots/pop-duel-bright-desktop.jpg)

## Play locally

Open **`PopDuel.rbxlx`** in Roblox Studio and press **Play**.

- **Practice** starts a match against one explicitly labelled ghost using the same simulation.
- **Play Duel** joins the human queue. For local multiplayer, start a Studio server with two player clients and select it on both. **Cancel** leaves the queue.
- The walkable arcade stations also have nearby interaction prompts.

Drag or touch the board to aim. **A / D** or the arrow keys nudge the angle. Choose a power, then press **LET'S POP!**, **R**, or **Space** to lock your shot. You have up to 15 seconds to aim; both players launch after a shared two-second countdown. Each shot has a 25-second safety limit.

Scores and results come from the server. Each player has an independent copy of the same board. Results offer **Play Again** or **Lobby**; human rematches need both players, while practice needs only your request. Leaving during a shot forfeits the duel.

## Free powers

All three powers activate once when your ball hits the green target.

| Power | Effect |
| --- | --- |
| **Pulse Pop** | Scores nearby targets in a burst. |
| **Split Shot** | Adds a second ball; both contribute to one score. |
| **Second Wind** | Returns the ball through the top once for another pass. |

The presentation uses original native UI shapes and full-body copies of the players' Roblox avatars. Practice has a distinct ghost mascot. **SFX** mutes audio; **FX** reduces avatar motion, trails, flashes, sparks, and celebration effects. Desktop and phone layouts are supported; [see the phone layout](docs/screenshots/pop-duel-bright-phone.jpg).

Statistics are **session-only**, including in published servers. Wins count human duels; practice wins are tracked separately. Practice can improve best score and total rounds. Abandoned rounds cannot set a best score, and reconnecting resets statistics. No purchases or persistent economy are connected.

## Build

Python 3 and its standard library are sufficient:

```sh
python3 scripts/build.py
```

This regenerates `PopDuel.rbxlx` from `src/`. Stop any running playtest and reopen the generated place after rebuilding. Keep code edits in the source files; rebuilding replaces manual script edits inside the generated place. Use `--output /path/to/PopDuel.rbxlx` for a different destination.

| Source | Responsibility |
| --- | --- |
| `src/shared/PegSimulation.luau` | Deterministic physics, board generation, scoring, powers, and aim preview |
| `src/shared/PegPowers.luau` | Free power definitions |
| `src/shared/PegWorld.luau` | Walkable arcade lobby and stations |
| `src/server/PegServer.server.luau` | Queues, authoritative matches, validation, rematches, and session statistics |
| `src/client/PegClient.client.luau` | Input, responsive interface, and match presentation |
| `src/client/PegBoardView.luau` | Board, balls, trajectory, and pooled effects |
| `src/client/PegAvatarView.luau` | Player avatar copies, practice ghost, framing, and cleanup |
| `src/client/PegAudio.luau` | Bounded sound pools and mute control |

## Test and validation

The optional Python test harnesses require `lupa`. In a Python environment with that dependency installed, run:

```sh
python3 scripts/test_peg_sim.py
python3 scripts/test_peg_server.py
python3 scripts/test_peg_sim.py --sweep
```

The first two commands check deterministic physics and server match rules. The sweep evaluates 393 shots on one repeatable board seed. These checks do not replace Studio multiplayer, native input, audible output, or player testing.

Recorded simulation results, Studio checks, two-client replication evidence, screenshots, and remaining validation gaps are in [Pop Duel validation](docs/POP-DUEL-PROTOTYPE.md). Reference research and deliberate changes to the original formula are in [Peggle baseline research](docs/PEGGLE-BASELINE.md).

During local Play, the **server** command bar can inspect an authoritative snapshot:

```lua
print(game.ServerStorage.PegDebug:Invoke("snapshot"))
```

The diagnostic exists only in Studio. Published-server behavior, physical-device performance, audible mix quality, power balance, and repeat-play interest still need validation.

The retired flight prototype remains recoverable from Git at commit `85db5d1`.
