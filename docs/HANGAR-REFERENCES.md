# Hangar and earned effects references

Research checked October 9, 2026. This pass inspected selected paused YouTube frames and auto-generated transcripts from two gameplay videos, plus the official Roblox experience page. BALL vs BALL was not launched or played, and neither video was watched continuously. Upload dates do not establish when footage was recorded; prices below describe the visible footage, not a verified current live shop.

## Observed reference behavior

| Source and moment | Visible observation |
| --- | --- |
| [Clout Brothers, September 10 — 0:05](https://www.youtube.com/watch?v=rFez89DlGJY&t=5s) | A wide central walkway connects duel stations. Shop kiosks, large category signs and ball landmarks are visible near spawn; white tutorial arrows lead toward a first match. |
| [Clout Brothers — 3:07](https://www.youtube.com/watch?v=rFez89DlGJY&t=187s) | A collection reveal follows the first match. The transcript identifies a first-battle completion reward despite losing. Store, Inventory, Play and Quick Join remain accessible in the lobby. |
| [Clout Brothers — 3:37](https://www.youtube.com/watch?v=rFez89DlGJY&t=217s) | Daily objectives show progress and rewards. The store separates Balls, Explosions and Flyers. |
| [Clout Brothers — 3:52](https://www.youtube.com/watch?v=rFez89DlGJY&t=232s) | A basic ball crate displays its pool, rarity odds and purchase buttons for 150 coins or 15 gems. |
| [SSundee, October 8 — 10:14](https://www.youtube.com/watch?v=IljisgHnhhc&t=614s) | The newer shop shows Events, Balls, Explosions and Flyers, with separate coin and diamond explosion crates, prize previews and odds. The coin crate displays 300 for one or 3,000 for ten. |
| [SSundee — 10:19](https://www.youtube.com/watch?v=IljisgHnhhc&t=619s) | Explosion inventory uses large effect cards and a detail panel. The transcript at 10:19–10:22 describes choosing an equipped explosion. |

The newer footage shows an earned-coin route to explosion cosmetics, so the older guide's spoken assumption that effects require premium currency should not be carried forward. Exact live payouts, current shop contents and the complete onboarding flow remain unverified.

The [official Roblox page](https://www.roblox.com/games/96510596525082/Ball-VS-Ball) advertises 1v1/2v2, three random round choices, choosing from owned balls once per match, 40+ collectible balls, trading and a group reward. That description supports the broad collection/match loop; it does not establish the prices or reward amounts shown in these videos.

## Scope chosen for Skybound

The implemented loop is **complete flights → earn credits → return to the hangar → preview a known trail → buy → equip → fly again**. A clear center aisle leads to four duel gates; parked fleet planes, a working effects counter and a solo dispatch desk give the lobby useful destinations. The aircraft hangar, models and interface are Skybound's own implementation.

This pass includes one free trail and five deterministic earned-credit purchases. Aircraft and powers remain free. The preview shows trail colors around a plane; the equipped trail appears on the moving match plane. Studio keeps the economy for the current Play session; the published persistence implementation still requires live reconnect verification. See [README](../README.md) for controls, prices and rewards and [VALIDATION](../VALIDATION.md) for evidence and remaining checks.

## Later experiments

- Give a guaranteed first-completion cosmetic and teach equipping it once.
- Add short flight objectives with visible progress and claim feedback.
- Expand cosmetic categories to launch bursts and landing celebrations, with clear previews.
- Add a shared flight board or display of equipped planes to make collections visible socially.

Daily quests, free completion unlocks, extra effect categories, trading and paid/randomized purchases are not implemented by this pass. Validate the existing earn–buy–equip loop before expanding the economy.
