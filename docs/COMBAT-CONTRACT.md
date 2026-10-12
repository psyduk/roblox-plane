# Ring-out contract

Contract `sky-battle-ring-v1`, roster `sky-battle-tops-v1`. This replaced the plane fight on October 11, 2026; that contract is in git history before this file changed. Exact numbers live in `src/shared/BattleSimulation.luau` and `BattleSkills.luau`; this page says what they mean.

## The round

- Two tops share a round platform, radius 40, centred on the origin. They start 18 from the middle on opposite sides and are launched across the ring at a seeded angle.
- **A top whose centre leaves the platform is out, and the round ends at once.** The other top wins. Two tops leaving on the same tick draw. There is no health, armor or damage.
- After 8 seconds the platform shrinks steadily, reaching radius 8 at 26 seconds. A round still going at 26 seconds goes to the top nearer the middle; level is a draw. In 960 sampled rounds none reached the limit.
- From 6 seconds every kick grows by 6% per second ("heat"), so late hits throw further.
- The simulation is pure and deterministic: the same seed and builds always play out the same way. It runs at 60 ticks a second on the server; clients only draw snapshots.

## How tops move

Nobody steers. A free top turns toward its rival at its own turn rate and spins itself back up to its own cruise speed. The platform is slightly dished and leans every top back toward the middle. A top that has just been thrown cannot turn or drive for a moment (about a third of a second, longer for a harder throw) and simply slides.

## A touch

When two tops touch they first share their speed along the line between them (a heavier or faster top carries the other with it), then each kicks the other away. A kick is the base kick, times the top's own kick, times heat, and **grows with speed: a top driving into the touch at 25 kicks twice as hard as one standing still, at 50 three times**. A seeded share of luck, up to half either way, decides which top catches the other cleanly. The top thrown away faster is the one that "took the hit"; that is the top named as the target of the `clash` event.

## Tops

| Top | Mass | Cruise | What it does |
| --- | --- | --- | --- |
| Boulder | 1.63 | 16 | Slow and very hard to move. Every 3.2 s it bulldozes for a second: faster and turning harder. |
| Bolt | 0.9 | 26 | Every 2 s it stops for half a second, aims (the line on the deck), then dashes at 78 in a straight line. It stops aiming 0.28 s before it goes, so a moving rival can slip it; a miss carries it across the ring. |
| Cyclone | 1.05 | 32 | Fast with a wide turn. Every 2.3 s it swoops: faster still and turning three times as hard. |
| Pogo | 1.15 | 22 | Every 2.5 s it crouches, jumps to where its rival is heading (the circle on the deck) and lands with a shockwave that throws anything within 15.5. Nothing can touch it in the air. It always lands on the platform. |

A top that is thrown while charging keeps its charge and fires once it has steadied. A top caught in the middle of its move has the move cut short.

## Upgrades

| Upgrade | Rule |
| --- | --- |
| Heavy Core | 9% heavier and 10% bigger. |
| Spikes | Kicks 20% harder. |
| Turbo | Cruises 15% faster and makes its move 20% more often. |
| Claws | In the outer 40% of the ring, sheds speed toward the edge. |
| Spring Bumper | The first hit does not move this top; the rival is thrown back instead. Once a round. Two bumpers meeting spend each other. |
| Jetpack | The first time this top leaves the ring it flies back on, landing 72% of the way out. Once a round. |

Upgrades are sorted before a round, so pick order never changes a fight. A build is one top and up to two different upgrades.

## Events

`launch`, `windup`, `attack`, `clash` (with `power`, `source` `bump` or `slam`, `skillId`), `slam`, `land`, `blocked`, `revive`, `close` (a top came within 3 of the edge and got back), `ringout`, `finish`. The server keeps `clash`, `blocked`, `revive`, `ringout` and `finish` for the result screen's one-line explanation.

## Match rules (unchanged)

First to two round wins. A drawn round gives no point and no pick and is replayed with the same builds. A match stops at five rounds or 240 seconds; only completed round wins decide it. The server stops any round still running 32 seconds after it began.
