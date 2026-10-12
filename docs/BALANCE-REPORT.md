# Balance report: ring-out

Measured October 11, 2026 on the source that introduced the ring-out game. Earlier reports for the plane fight are in git history. These are simulation results, not a playtest.

```sh
build/testenv/bin/python scripts/sample_battle.py --samples 60 --upgrades
```

960 rounds: every top against every top, both seats, 60 seeds each.

| Measure | Result |
| --- | --- |
| Round length | median 15.4 s, 10th percentile 8.8 s, 90th percentile 20.3 s |
| Touches per round | 12.1 |
| Close calls per round | 0.47 |
| Drawn rounds | 0.0% |
| Decided by the clock | 0.0% |
| The top that wins the first touch wins the round | 51% |

For comparison, the plane fight this replaced had the first hitter winning about 70% of rounds.

| Top | Score against the field |
| --- | --- |
| Boulder | 48% |
| Bolt | 55% |
| Cyclone | 49% |
| Pogo | 48% |

Left seat's score in each pairing:

| | Boulder | Bolt | Cyclone | Pogo |
| --- | --- | --- | --- | --- |
| Boulder | 55 | 52 | 48 | 52 |
| Bolt | 55 | 50 | 33 | 85 |
| Cyclone | 53 | 65 | 47 | 25 |
| Pogo | 63 | 17 | 67 | 53 |

One upgrade against a bare top, both seats: Jetpack 72%, Spikes 67%, Turbo 67%, Heavy Core 66%, Claws 63%, Spring Bumper 59%.

## What is not right yet

- **Bolt beats Pogo about 85% of the time.** Pogo beats Cyclone about 70% and Cyclone beats Bolt about 65%, so there is a loop, but the Bolt–Pogo leg is too strong. Shortening Pogo's crouch made it worse, not better.
- **The balance is fragile.** Boulder's field score went from about 40% to about 75% as its mass moved from 1.4 to 1.7. An automatic search over 17 numbers found settings that looked level on 30 seeds and were not on 70. The values shipped were chosen by hand on 50 to 60 seeds per pairing.
- **Two-upgrade builds were not measured**, and neither was any upgrade on one specific top.
- **Jetpack is the strongest upgrade** even after its landing spot was moved most of the way back to the edge.
- Luck decides up to half of each kick. That is what stops a pairing playing out the same way every round; whether it reads as fair is a question for people, not for this table.
