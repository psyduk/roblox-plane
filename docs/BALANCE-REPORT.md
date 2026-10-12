# Balance report: spinning tops

Measured October 11, 2026 on the source that introduced bowl physics and spin. Earlier reports are in git history. These are simulation results, not a playtest.

```sh
build/testenv/bin/python scripts/sample_battle.py --samples 60 --upgrades
```

960 rounds: every top against every top, both seats, 60 seeds each.

| Measure | Result |
| --- | --- |
| Round length | median 13.4 s, 10th percentile 7.8 s, 90th percentile 18.4 s |
| Touches per round | 10.1 |
| Close calls per round (wall hit right beside a gap) | 2.1 |
| Knocked out through a gap / out-spun | 49% / 51% |
| Drawn rounds | 0.1% |
| Decided by the clock | 0.0% |
| The top that wins the first touch wins the round | 49% |

| Top | Score against the field |
| --- | --- |
| Bolt | 52% |
| Cyclone | 55% |
| Boulder | 47% |
| Drifter | 46% |

Left seat's score in each pairing:

| | Bolt | Cyclone | Boulder | Drifter |
| --- | --- | --- | --- | --- |
| Bolt | 50 | 62 | 40 | 58 |
| Cyclone | 38 | 47 | 88 | 47 |
| Boulder | 60 | 15 | 40 | 68 |
| Drifter | 43 | 53 | 42 | 51 |

One part against a bare top, both seats: Flywheel 73%, Free-Spin Guard 72%, Jagged Rim 68%, Metal Weight 67%, Rubber Tip 64%, Left Spin 63%.

## What is not right yet

- **Cyclone beats Boulder about 86% of the time.** There is a loop (Bolt over Cyclone, Cyclone over Boulder, Boulder over Bolt), but it runs the opposite way to the real toys' rule of thumb, and that one leg is far too strong.
- **Boulder mirrors lean to the right seat** (40% for the left over 120 rounds). Other mirrors are within 3 points of even. Not investigated.
- **The balance is fragile.** Earlier settings of the same model swung a top's field score by 20 points for small changes in mass or spin drain. The shipped values were found by a search over 30 seeds and then adjusted by hand on 40 to 60.
- **Two-part builds were not measured**, and neither was any part on one specific top. Left Spin in particular is a counter-pick whose value depends entirely on the rival.
- **Parts are on the strong side**: every one is worth 63–73% against a bare top.
- Luck decides up to 35% of each touch's recoil. That is what stops a pairing playing out the same way every round; whether it reads as fair is a question for people, not for this table.
