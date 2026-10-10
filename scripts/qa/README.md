# Opt-in two-client Sky Battle test

These scripts are QA fixtures and are deliberately **not** included in `scripts/build.py` or the generated place.

1. In Studio **Edit** mode, install `SkyBattleNetwork.server.luau` as a temporary Script in ServerScriptService and `SkyBattleNetwork.client.luau` as a temporary LocalScript in StarterPlayerScripts. Use the latest built game source. Leave `BattleFixedSeed` unset, `BattleExperimental` false/unset, and distance mode disabled.
2. From a Studio plugin or an authorized automation command with plugin security, run:

   ```lua
   local result = game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(2, "SkyBattleNetworkV1")
   print(result)
   ```

3. Save the returned JSON alongside the build/source evidence. The server requires `RunService:IsStudio()` and that exact `GetTestArgs()` value before creating the marked QA remote. The client requires Studio and waits up to 60 seconds for that server marker; it performs no inputs in normal Play or production. Startup allows 65 seconds for both clients. The server ends the test after success/failure, with a 240-second watchdog; its report includes joined/ready counts and per-client startup reasons.
4. Remove both temporary scripts from the Edit place before saving/publishing. Verify the generated production package excludes them.

The helper uses **two actual Studio clients**. Commands originate in their LocalScripts and cross the existing production `Command`/`BattleCommand` RemoteEvents. The server checks the snapshots the clients actually received. The extra QA RemoteEvent carries test instructions/observations only; it never mutates battle state.

Coverage: public pairing; own-seat identities; hidden selection until both lock; simultaneous reveal and identical seed; a normal complete match; mirrored score/winner and per-player awards; first-match gift claim; two-vote rematch and fresh resources; early-departure denial and restored lobby controls; challenge decline and acceptance. Both sides use their normal free Pick Any for Firework initially to avoid a slow defensive mirror, then choose eligible offered wild cards. No timers, seeds, armor, rewards or outcomes are overridden.

The report labels input as programmatic. It does **not** establish human UI clicks, phone touch, subjective readability/audio, unfamiliar-player behavior, published networking or cloud persistence. A watchdog failure is an incomplete test, never a pass. Decline/accept are covered; challenge expiry/crossing invites and disconnect/rejoin remain covered by service doubles until separately exercised with real clients.

API reference: [Roblox StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).
