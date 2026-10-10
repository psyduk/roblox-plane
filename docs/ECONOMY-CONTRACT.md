# Sky Battle economy contract v1

Approved Milestones 1–2 implementation, October 10, 2026. All four offences and five wild cards are equally available to new, returning and bot pilots. Coins, aircraft, trails and mastery never enter combat calculations or offer eligibility. No Robux purchase, paid reroll, multiplier, random crate or skill ownership is enabled.

| Terminal condition | Coins | Eligibility |
| --- | ---: | --- |
| Normal completed win | 75 | At least one completed physical round |
| Normal completed loss or draw | 50 | At least one completed physical round |
| Five-round or 240-second cap | 75 winner / 50 loss or draw | At least one completed physical round; unfinished round earns no score |
| Opponent departs | 75 to remaining pilot | At least one completed round OR 30 seconds of combat already watched |
| Pilot exits or disconnects before result | 0 to that pilot | No instant-forfeit farming |
| Both leave before qualification / shutdown abort | 0 | No completed qualifying result |
| Repeated result delivery or reconnect | 0 additional | Server-session match ID is a persisted receipt |
| Isolated experimental/fixed-seed diagnostics | 0 | Never mix diagnostic play with the public economy |

Watching automatic combat is participation. Picking, tapping or steering during combat is not required. Draft/queue waiting is not combat time. A rematch is a new match ID and starts with empty builds and fresh free draft resources.

Awards are atomic with mastery and receipts in the existing fenced player record. `saved` means a store write succeeded; `pending` means the local award is waiting for persistence; `unavailable` must never be presented as durable. Studio uses an explicit session-only record. Save retries retain the same write ID. An unsafe/failed initial load never overwrites cloud data. Confirmed cosmetic purchases and grants share that same record.

The first qualifying completion makes one guaranteed starter-trail choice available, separate from coins. The choice can be claimed and equipped without blocking replay. The separate 250-coin goal is previewed in results and the hangar. Mastery records completed matches and skill use; its small title track has no stat bonuses.

Worked examples: a fresh loss gives 50 coins and the starter choice; a fresh win gives 75; a draw gives 50. Five qualifying losses from zero produce 250 coins, enough for the goal without spending any along the way. Repeating the fifth result leaves 250. Buying the goal debits exactly 250 and grants ownership once; repeat purchase cannot debit again. Equipping an unowned trail fails. A disconnect after a saved result preserves the award; a disconnect before qualification awards nothing. A pending or failed write is explicitly unconfirmed until retried successfully.

These are implementation rules and tuning hypotheses. Published persistence and player motivation require the separate release playtest.
