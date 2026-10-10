# Plane battle audit — look, sound and feel

Audit date: October 10, 2026. Scope: the plane-versus-plane mode only (the shelved distance flight is ignored). Goal set by the owner: the battle should pop, look and sound impressive, and feel addictive and suspenseful — a hit Roblox game, not a lab tool.

This file is the reference list. Status is updated as items ship; evidence for shipped items belongs in [VALIDATION.md](../VALIDATION.md). Product rules stay in [the Clash design](SKYBOUND-CLASH-DESIGN.md).

## How it was audited

- Played one full default round (Meteor vs Firework, no effects) in Roblox Studio on desktop, from hangar PLAY through results, on the `codex/plane-battles-entry` build.
- Read `BattleView.luau`, `BattleAudio.luau`, `BattleLab.luau` (client and server) and the battle design record.
- Not done: listening to the audio (judged from code), phone or portrait layouts, a physical device.

## Owner decisions (October 10, 2026)

| Question | Decision |
| --- | --- |
| Camera | Override the design doc's "stable camera". A dynamic camera that frames the two planes, zooms and shakes is approved. |
| Audio assets | Free Creator Store audio is approved. Use official licensed channels (Pro Sound Effects, APM Music), not arbitrary user uploads. |
| Arena theme | A sky stadium: open sky, clouds, a crowd. |
| Rewards | Add as an audit item (29); not part of the first pass. |
| Interaction | Tap-to-cheer during a fight is acceptable (30). |
| Creative latitude | Full creative freedom on taste; ask when a decision is really the owner's. |

## The five that matter most

1. **The fight is tiny.** The arena fills about 40% of the screen width and each plane about 3–4% of it; the rest is black void. The camera never moves. Frame the two planes instead of the whole field: zoom in when they close, pull out when they separate, punch in on hits.
2. **Hits have no weight.** A hit is ten neon sticks, a ring and a 0.13s flash, with no hit-stop, camera shake, screen flash or debris. The killing blow looks the same as the first. Add a freeze-frame, shake, white flash and real particles, plus slow-motion and a zoom on the knockout.
3. **There is almost no sound.** Eleven battle events are made from four stock Roblox samples, pitch-shifted, at low volume. No music, engine, crowd, countdown beep, timer tick, UI click or victory sting; the countdown is deliberately silent.
4. **Your plane isn't your plane.** The battle always spawns a default cruiser in fixed coral or cyan. The plane, paint and trail chosen in the hangar never appear.
5. **Nothing is at stake.** The seed is fixed, so "Run it again" replays the identical fight. No rewards, no streak, no best-of-three, and the opponent is called "SIM".

## Visuals

6. **World:** replace the navy grid and black slab with a sky arena: parallax clouds, a stadium or crowd, time-of-day lighting, matching the bright chunky hangar.
7. **Post-processing:** no bloom or colour grading in battle. Add bloom so neon glows, and a brief punch on hits.
8. **Damage states:** a plane at one armor looks the same as at three. Add stacking smoke, then fire, sparks and a wobble.
9. **Meteor charge and dive:** the charge shell is 74–96% transparent and barely reads. Make it a growing fireball, then a streak with afterimages and a shockwave on impact.
10. **Firework rocket:** small, with a 0.26s trail. Make it bigger, with a long sparkling trail and a real firework burst in the pilot's colour on hit or fizzle.
11. **Closing wind:** a yellow rectangle with a faint fill. Make it a visible storm wall with streaking particles, darkening edges and lightning.
12. **Knockout and crash:** the fall and ground thud exist but are small. Add a smoke trail down, a bounce, a dust cloud, scattered parts and a camera follow.
13. **Callout text:** "CHARGING" and "HIT!" are 13px Gotham in a dark pill. Use the hangar's cartoon lettering as big pop-in comic words.

## HUD and flow

14. **Entry:** PLAY cuts instantly to the setup screen. Add a takeoff transition and a VS splash with both planes, names and powers.
15. **Countdown:** "LAUNCH IN 1" in the status bar. Make it a full-screen 3-2-1-FIGHT with a beep per number.
16. **Armor:** three 6px bars in the header, far from the action. Put chunky pips over each plane that shatter when lost.
17. **Timer:** small "27 seconds left · Automatic combat" text. Use a big central clock that turns red and pulses in the last ten seconds.
18. **Power select:** two text buttons that cycle ("Meteor ↔"). Reuse the illustrated power-card style from the distance mode.
19. **Results:** a recoloured status bar plus "Change one effect and see what happens." Build a real win/lose screen with the winner posed, confetti, stats and a large REMATCH button.
20. **Language:** remove "Battle Lab", "Simulated opponent", "SIM" and "Automatic combat" from the player-facing path. Give the bot a name and a face.

## Sound

21. **Music:** a battle loop that intensifies when the wind closes, plus win and lose stings; later a hangar loop.
22. **Continuous layers:** an engine drone per plane that pitches with speed, wind, and a crowd that reacts to hits and near misses.
23. **Impact design:** a layered hit (low thump, crunch, high sparkle), a distinct armor-break, and a different, larger knockout sound.
24. **Tension cues:** a heartbeat or alarm at one armor, a tick in the last ten seconds, a storm rumble during pressure.
25. **Stereo position:** all sounds are centred; pan them by where the plane is on screen.
26. **UI sounds:** every button, card select and lock-in.

## Suspense and addiction

27. **Random seed** in the real PLAY path; keep the fixed seed behind a lab toggle.
28. **Best of three** with a "MATCH POINT" banner (already planned in the design doc); the biggest suspense lever.
29. **Rewards:** coins, a win streak with a flame counter, coins flying to the unlock stand as they already do after distance flights.
30. **Tap to cheer:** fights are about 27 seconds hands-off. A tap-to-cheer or emote keeps hands busy without breaking automatic combat.
31. **Near-miss moments:** brief slow-motion and a "CLOSE!" callout when a dive or rocket barely misses.
32. **Firework mirrors** currently trade into repeated draws; needs a tiebreak or tuning before players see it.

## Status

Branch `battle-juice-pass`. "Built" means written and exercised by tests and scripted fights; see VALIDATION.md for exactly what was and was not checked. The owner has played the first pass and likes the direction; rows say what has actually been seen.

| # | Item | Status |
| --- | --- | --- |
| 1 | Dynamic camera | Built, seen briefly. Retuned after feedback: rests wide, closes in on attacks |
| 2 | Hit weight (freeze, shake, flash, particles, knockout slow motion) | Built, unseen |
| 3, 23 | Layered impact sounds, crowd, countdown beeps | Built, unheard |
| 4 | Your paint, trail and pilot in battle | Built, unseen. Plane type still not shown |
| 6, 7 | Sky stadium, bloom and grade | Built, seen on desktop |
| 8 | Damage smoke and fire | Built, unseen |
| 10 | Rocket trail and firework burst | Partly built, unseen |
| 13 | Comic callout words | Built, unseen |
| 15 | 3-2-1-FIGHT countdown | Built, seen on desktop |
| 21 | Battle music | Swapped to a lighter funk track after "too dramatic" feedback; new track unheard. No stings or hangar loop yet |
| 18 | Power select | Built: power cards, wild card chips, FIGHT!; rival rolled at launch. Seen on desktop |
| 20 | Lab wording | Partly: RIVAL / VS PRACTICE BOT. Header still looks like a tool |
| 26 | UI sounds | Partly: setup clicks and commit whoosh |
| 27 | Variety on rematch | Partly: rematch re-rolls the rival; the seed is still fixed |
| 24 | Last-five-seconds tick, thunder at pressure start | Partly built |
| 9, 11, 12 | Meteor fireball, storm wall, bigger crash | Small improvements only |
| 16, 17 | Armor and timer | Built as a fighter bar: portraits, names, chunky pips, central clock. Seen on desktop. Pips are in the bar, not over the planes |
| 19 | Results | Built: banner, winner portrait and crown, stats, REMATCH, confetti, win fanfare. Victory seen on desktop; defeat and draw unseen |
| 14, 22, 25, 28–32 | Everything else | Open |
