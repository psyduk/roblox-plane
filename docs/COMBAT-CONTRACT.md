# Combat contract: spinning tops

Contract `sky-battle-ring-v2`, roster `sky-battle-tops-v2`, October 11, 2026. Earlier contracts (the plane fight, and the first ring-out pass with steering tops and a shrinking platform) are in git history. Exact numbers live in `src/shared/BattleSimulation.luau` and `BattleSkills.luau`; this page says what they mean. The model borrows from how real battling tops behave; it is a game model, not a physics simulation.

## The round

- Two tops are launched into a round bowl, radius 24, with a wall round its rim. They start 12 from the middle on opposite sides and are launched across the bowl at a seeded angle.
- The wall has **three gaps**, each 0.4 radians wide, placed so neither seat is nearer to one.
- A round is lost in one of two ways:
  - **Knocked out.** A top that has been thrown (moving more than 2 faster than its own cruise speed) and reaches a gap goes out. A top under its own power follows the rim past a gap and never leaves by itself.
  - **Out-spun.** Every top starts with 100 spin. At zero it falls over.
- Two tops out on the same tick draw. If one touch stops both, the one it took more out of loses; only a dead heat draws. A ring-out on the same tick as a spin-out wins over it.
- A round still going at 40 seconds goes to the top with the larger share of its spin left. In 960 sampled rounds none got there.
- The simulation is pure and deterministic: the same seed and builds always play out the same way. It runs at 60 ticks a second on the server; clients only draw snapshots.

## How a top moves

Nobody steers and no top aims at its rival. Three things act on a top every tick:

- **The bowl** pulls it toward the middle, harder the further out it is.
- **Its tip** drives it up to its cruise speed, bends its path a little (always the way it spins), and keeps turning it back toward the middle. Together these make a top dive through the centre, out to the wall and back, each pass turned slightly from the last: the petal pattern real tops trace.
- **After a hit** the tip scrubs the extra speed off again. A grippy tip does that quickly; a needle tip barely at all, so it slides.

All of it fades as the spin does. A top with little spin left crawls, brakes badly and is thrown further by every touch (up to 2.6 times as far with none left).

## Spin

Spin drains constantly, at a rate set by the tip, and faster as it runs down (a wobbling top loses spin up to 2.2 times as fast). Touches and wall bounces cost more.

## A touch

When two rims meet, three things happen:

1. An ordinary bounce along the line between them.
2. **Recoil**, in proportion to how fast the two rims are sliding past each other and how jagged they are. Two tops turning the same way meet rim against rim and smash apart. Two turning opposite ways roll together and barely recoil.
3. **A sideways throw.** Each rim drags the other along the way it is turning, so tops leave a touch at an angle and no two hits go the same way.

A seeded share of luck, up to 35% either way, decides which rim catches the other cleanly. Each top then loses spin in proportion to what it took and how jagged the other rim was. **Opposite spins also even out:** 16% of the gap in spin moves from the faster top to the slower, with a fifth lost on the way.

The wall bounces a top back with 55% of its speed and a small spin cost. A top with a grippy tip catches the wall and comes off it at up to 1.25 times its cruise speed.

## Tops

| Top | Type | Mass | Cruise | Spin drain | Rim | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Bolt | Attack | 0.87 | 30 | 2.9/s | very jagged | Fast, dives hardest, light. Speeds up off the wall. |
| Cyclone | Stamina | 0.99 | 5 | 2.37/s | smooth | Sits near the middle. Hardly brakes after a hit. |
| Boulder | Defense | 1.25 | 10 | 3.0/s | smoothest | Takes 76% of recoil and spin damage. |
| Drifter | Balance | 1.07 | 19 | 3.05/s | medium | Takes 95%. |

## Parts

| Part | Rule |
| --- | --- |
| Metal Weight | 14% heavier. |
| Jagged Rim | 30% more bite: more recoil dealt and more spin taken off the rival. |
| Rubber Tip | 8% faster, grips and brakes harder, 5% less spin drain. |
| Free-Spin Guard | Takes 7% less recoil and spin damage. |
| Flywheel | 4% more spin to start, 3% less drain. |
| Left Spin | Turns the other way. Against an ordinary top every touch is a grind. Also takes 8% less. |

Parts are sorted before a round, so pick order never changes a fight. A build is one top and up to two different parts.

## Events

`launch`, `clash` (with `power`, `source` `smash` or `grind`, `skillId`), `wall`, `close` (hit the wall hard right beside a gap), `ringout`, `spinout`, `finish`. The server keeps `clash`, `ringout`, `spinout` and `finish` for the result screen's one-line explanation.

## Match rules (unchanged)

First to two round wins. A drawn round gives no point and no pick and is replayed with the same builds. A match stops at five rounds or 240 seconds; only completed round wins decide it. The server stops any round still running 46 seconds after it began.
