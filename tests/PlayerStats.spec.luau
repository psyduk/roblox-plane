-- Pure injected-store tests. No live Roblox DataStore is accessed.
return function(PlayerStats)
	local passed = 0
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end
	local function clone(value)
		if type(value) ~= "table" then return value end
		local copy = {}
		for key, child in pairs(value) do copy[key] = clone(child) end
		return copy
	end
	local function fakeStore()
		local store = { values = {}, calls = 0, failures = 0, commitErrors = 0, duplicateCallbacks = false }
		function store:UpdateAsync(key, transform)
			self.calls = self.calls + 1
			if self.failures > 0 then self.failures = self.failures - 1; error("transient service error") end
			local value = transform(clone(self.values[key]))
			if self.duplicateCallbacks then value = transform(clone(self.values[key])) end
			if self.beforeCommit then local callback = self.beforeCommit; self.beforeCommit = nil; callback() end
			if value ~= nil then self.values[key] = clone(value) end
			if value ~= nil and self.commitErrors > 0 then self.commitErrors = self.commitErrors - 1; error("response lost after commit") end
			if self.beforeReturn then local callback = self.beforeReturn; self.beforeReturn = nil; callback() end
			return clone(value)
		end
		return store
	end
	local function environment()
		return { time = 1000, waits = 0 }
	end
	local function service(store, id, env, extra)
		env = env or environment()
		local options = { store = store, sessionId = id or "server-A", clock = function() return env.time end,
			monotonic = function() return env.time end, wait = function(seconds) env.time = env.time + seconds; env.waits = env.waits + 1 end,
			spawn = function(callback) callback() end, jitter = function() return 0 end, leaseSeconds = 180, saveInterval = 45 }
		for key, value in pairs(extra or {}) do options[key] = value end
		return PlayerStats.new(options), env
	end
	local function flight(stats, handle, id, outcome, options)
		local input = { outcome = outcome or "win", distance = 500, completed = true }
		for key, value in pairs(options or {}) do input[key] = value end
		return stats:recordFlight(handle, id, input)
	end

	test("new profile acquires a lease and starts with zero statistics", function()
		local store = fakeStore(); local stats = service(store)
		local handle = stats:open(42)
		assert(select(2, stats:get(handle)) == "loading")
		assert(stats:load(handle))
		local data, status = stats:get(handle)
		assert(status == "saved" and data.totalFlights == 0 and data.bestDistance == 0)
		assert(store.values.player_42.lease.id == handle.token)
	end)

	test("human wins losses draws and best streak follow resolved outcomes", function()
		local stats = service(fakeStore()); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win")
		flight(stats, handle, "two", "draw", { distance = 600 })
		flight(stats, handle, "three", "win")
		local data, status = stats:get(handle)
		assert(data.wins == 2 and data.draws == 1 and data.currentStreak == 2 and data.bestStreak == 2)
		assert(data.bestDistance == 600 and data.totalFlights == 3 and status == "pending")
		flight(stats, handle, "four", "loss", { distance = 200 })
		data = stats:get(handle)
		assert(data.losses == 1 and data.currentStreak == 0 and data.bestStreak == 2)
	end)

	test("practice can improve distance but never a human record or streak", function()
		local stats = service(fakeStore()); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "duel", "win")
		flight(stats, handle, "practice", "loss", { practice = true, distance = 1000 })
		local data = stats:get(handle)
		assert(data.bestDistance == 1000 and data.totalFlights == 2 and data.practiceFlights == 1)
		assert(data.wins == 1 and data.losses == 0 and data.currentStreak == 1)
	end)

	test("forfeit resets streak and aborted flights cannot improve distance", function()
		local stats = service(fakeStore()); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "win", "win")
		flight(stats, handle, "forfeit", "win", { forfeit = true, distance = 9999 })
		flight(stats, handle, "opponent-left", "win", { completed = false, distance = 8888 })
		local data = stats:get(handle)
		assert(data.bestDistance == 500 and data.losses == 1 and data.wins == 2 and data.currentStreak == 1)
		flight(stats, handle, "practice-abort", "loss", { practice = true, forfeit = true, distance = 7777 })
		data = stats:get(handle)
		assert(data.losses == 1 and data.currentStreak == 1 and data.bestDistance == 500)
	end)

	test("duplicate finishes are idempotent in memory and after reconnect", function()
		local store = fakeStore(); local stats = service(store)
		local handle = stats:open(42); stats:load(handle)
		assert(flight(stats, handle, "round-1", "win"))
		assert(not flight(stats, handle, "round-1", "win"))
		assert(stats:close(handle))
		local nextStats = service(store, "server-B"); local nextHandle = nextStats:open(42); nextStats:load(nextHandle)
		assert(not flight(nextStats, nextHandle, "round-1", "win"))
		assert(nextStats:get(nextHandle).totalFlights == 1)
	end)

	test("load failures never overwrite an existing saved profile", function()
		local store = fakeStore(); local first = service(store)
		local handle = first:open(42); first:load(handle); flight(first, handle, "old", "win", { distance = 1500 }); first:close(handle)
		store.failures = 3
		local stats = service(store, "server-B"); local failed = stats:open(42)
		assert(not stats:load(failed) and select(2, stats:get(failed)) == "unavailable")
		local calls = store.calls
		flight(stats, failed, "unsaved", "loss", { distance = 2000 })
		assert(not stats:save(failed))
		stats:close(failed)
		assert(store.calls == calls and store.values.player_42.stats.bestDistance == 1500 and store.values.player_42.stats.wins == 1)
	end)

	test("unknown schema and corrupt data fail closed", function()
		local store = fakeStore()
		store.values.player_42 = { schemaVersion = 99, stats = { wins = 123 } }
		local stats = service(store); local handle = stats:open(42)
		assert(not stats:load(handle) and not stats:save(handle))
		assert(store.calls == 1 and store.values.player_42.schemaVersion == 99)
	end)

	test("bounded retries recover transient errors without double counting", function()
		local store = fakeStore(); store.failures = 2; store.duplicateCallbacks = true
		local stats, env = service(store); local handle = stats:open(42)
		assert(stats:load(handle) and store.calls == 3 and env.waits == 2)
		flight(stats, handle, "win", "win")
		store.commitErrors = 1
		assert(stats:save(handle))
		assert(store.values.player_42.stats.wins == 1 and store.values.player_42.stats.totalFlights == 1)
	end)

	test("ambiguous final-write response is recognized after releasing the lease", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win"); store.commitErrors = 1
		assert(stats:close(handle))
		assert(store.values.player_42.lease == nil and store.values.player_42.stats.totalFlights == 1)
	end)

	test("another server cannot load or overwrite an active session lease", function()
		local store, env = fakeStore(), environment()
		local first = service(store, "server-A", env); local a = first:open(42); first:load(a)
		flight(first, a, "first-win", "win"); first:save(a)
		local second = service(store, "server-B", env); local b = second:open(42)
		assert(not second:load(b) and select(2, second:get(b)) == "unavailable")
		flight(second, b, "unsafe", "win", { distance = 9999 })
		assert(not second:save(b) and store.values.player_42.stats.bestDistance == 500)
		assert(store.values.player_42.lease.id == a.token)
	end)

	test("expired lease takeover fences the old server even after new owner releases", function()
		local store, env = fakeStore(), environment()
		local first = service(store, "server-A", env); local a = first:open(42); first:load(a)
		flight(first, a, "a", "win"); first:save(a)
		env.time = env.time + 181
		local second = service(store, "server-B", env); local b = second:open(42); assert(second:load(b))
		flight(second, b, "b", "win", { distance = 1000 }); second:close(b)
		flight(first, a, "stale", "loss", { distance = 9000 })
		assert(not first:save(a) and not a.safe)
		assert(store.values.player_42.lease == nil and store.values.player_42.stats.wins == 2 and store.values.player_42.stats.bestDistance == 1000)
	end)

	test("newer local changes during a save remain pending for the next write", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win")
		store.beforeCommit = function() flight(stats, handle, "two", "win", { distance = 750 }) end
		assert(stats:save(handle))
		assert(store.values.player_42.stats.wins == 1 and stats:get(handle).wins == 2)
		assert(select(2, stats:get(handle)) == "pending")
		assert(stats:save(handle) and store.values.player_42.stats.wins == 2)
	end)

	test("outcomes during load are replayed on top of saved data exactly once", function()
		local store = fakeStore(); local first = service(store); local a = first:open(42); first:load(a)
		flight(first, a, "one", "win"); first:close(a)
		local stats = service(store, "server-B"); local handle = stats:open(42)
		store.beforeReturn = function()
			flight(stats, handle, "one", "win") -- Persisted receipt must suppress this on replay.
			flight(stats, handle, "two", "win", { distance = 800 })
		end
		assert(stats:load(handle))
		assert(stats:get(handle).wins == 2 and stats:get(handle).bestDistance == 800 and stats:get(handle).totalFlights == 2)
	end)

	test("save errors retry later but never claim unsaved changes were saved", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win"); store.failures = 3
		assert(not stats:save(handle) and select(2, stats:get(handle)) == "unavailable")
		assert(handle.safe and store.values.player_42.stats.wins == 0)
		assert(stats:save(handle) and select(2, stats:get(handle)) == "saved" and store.values.player_42.stats.wins == 1)
	end)

	test("autosave persists dirty data and renews an unchanged lease", function()
		local store, env = fakeStore(), environment()
		local stats = service(store, "server-A", env); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win")
		env.time = handle.nextSave + 1; stats:step()
		assert(store.values.player_42.stats.wins == 1 and select(2, stats:get(handle)) == "saved")
		local expires = store.values.player_42.lease.expiresAt
		env.time = handle.nextSave + 1; stats:step()
		assert(store.values.player_42.lease.expiresAt > expires and store.values.player_42.stats.wins == 1)
	end)

	test("Studio session-only fallback makes zero store calls and states it honestly", function()
		local store = fakeStore(); local stats = service(store, "studio", nil, { sessionOnly = true })
		local handle = stats:open(42); assert(stats:load(handle))
		flight(stats, handle, "one", "win"); stats:save(handle); stats:step()
		assert(select(2, stats:get(handle)) == "session_only" and stats:get(handle).wins == 1)
		assert(stats:close(handle) and store.calls == 0)
	end)

	test("close during an in-flight load releases the eventual acquired lease", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42)
		store.beforeReturn = function() stats:close(handle, 0) end
		stats:load(handle)
		assert(handle.closed and store.values.player_42.lease == nil and next(stats.records) == nil)
	end)

	test("shutdown saves and releases all loaded handles", function()
		local store = fakeStore(); local stats = service(store)
		local a, b = stats:open(42), stats:open(43); stats:load(a); stats:load(b)
		flight(stats, a, "one", "win"); flight(stats, b, "two", "loss")
		assert(stats:shutdown(25) and next(stats.records) == nil)
		assert(store.values.player_42.lease == nil and store.values.player_43.lease == nil)
		assert(store.values.player_42.stats.wins == 1 and store.values.player_43.stats.losses == 1)
	end)

	test("shutdown waits for a leave-save already in progress", function()
		local store, env = fakeStore(), environment()
		local stats = service(store, "server-A", env); local handle = stats:open(42); stats:load(handle)
		handle.closing = true
		stats.wait = function(seconds)
			env.time = env.time + seconds; env.waits = env.waits + 1
			handle.closing = false; stats:close(handle)
		end
		assert(stats:shutdown(25) and env.waits > 0 and store.values.player_42.lease == nil)
	end)

	test("public payload is detached and internal receipts stay bounded", function()
		local stats = service(fakeStore()); local handle = stats:open(42); stats:load(handle)
		for index = 1, 150 do flight(stats, handle, "round-" .. index, "win") end
		local public = stats:get(handle); public.wins = 0
		assert(stats:get(handle).wins == 150 and #handle.receipts <= PlayerStats.RECEIPT_LIMIT)
		assert(public.lease == nil and public.receipts == nil and public.token == nil)
	end)

	test("v1 migration preserves statistics and receipts without retroactive currency", function()
		local store = fakeStore()
		store.values.player_42 = { schemaVersion = 1, stats = { wins = 7, bestDistance = 810, totalFlights = 7 }, receipts = { "legacy" } }
		local stats = service(store); local handle = stats:open(42); assert(stats:load(handle))
		local wallet = stats:getEconomy(handle)
		assert(stats:get(handle).wins == 7 and stats:get(handle).bestDistance == 810)
		assert(wallet.credits == 0 and wallet.owned.classic and wallet.equippedTrail == "classic" and wallet.canShop)
		assert(store.values.player_42.schemaVersion == PlayerStats.SCHEMA_VERSION and store.values.player_42.economy.credits == 0)
		local applied, reward = flight(stats, handle, "legacy", "win")
		assert(not applied and reward == 0 and stats:getEconomy(handle).credits == 0)
	end)

	test("only completed nonaborted flights award catalog rewards once", function()
		local stats = service(fakeStore()); local handle = stats:open(42); stats:load(handle)
		local ok, reward = flight(stats, handle, "practice", "win", { practice = true })
		assert(ok and reward == 25)
		local _, winReward = flight(stats, handle, "win", "win")
		local _, lossReward = flight(stats, handle, "loss", "loss")
		local _, drawReward = flight(stats, handle, "draw", "draw")
		assert(winReward == 60 and lossReward == 40 and drawReward == 50)
		for index, options in ipairs({ { forfeit = true }, { completed = false }, { aborted = true }, { practice = true, aborted = true } }) do
			local _, amount = flight(stats, handle, "aborted-" .. index, "win", options)
			assert(amount == 0)
		end
		local duplicate, amount = flight(stats, handle, "practice", "win", { practice = true })
		assert(not duplicate and amount == 0 and stats:getEconomy(handle).credits == 175)
	end)

	test("purchase debits once and equip requires ownership; both survive reconnect", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42); stats:load(handle)
		assert(stats:buyCosmetic(handle, "skyblue").code == "insufficient_credits")
		assert(stats:equipCosmetic(handle, "skyblue").code == "not_owned")
		flight(stats, handle, "one", "win", { practice = true }); flight(stats, handle, "two", "win", { practice = true })
		assert(stats:buyCosmetic(handle, "skyblue").code == "purchased")
		local wallet = stats:getEconomy(handle)
		assert(wallet.credits == 10 and wallet.owned.skyblue and wallet.equippedTrail == "classic")
		assert(stats:buyCosmetic(handle, "skyblue").code == "already_owned")
		assert(stats:getEconomy(handle).credits == 10)
		assert(stats:equipCosmetic(handle, "skyblue").code == "equipped")
		assert(stats:equipCosmetic(handle, "skyblue").code == "already_equipped")
		store.duplicateCallbacks = true; store.commitErrors = 1
		assert(stats:close(handle))
		local resumed = service(store, "server-B"); local nextHandle = resumed:open(42); assert(resumed:load(nextHandle))
		wallet = resumed:getEconomy(nextHandle)
		assert(wallet.credits == 10 and wallet.owned.skyblue and wallet.equippedTrail == "skyblue")
		assert(not flight(resumed, nextHandle, "two", "win", { practice = true }))
		assert(resumed:getEconomy(nextHandle).credits == 10)
	end)

	test("invalid identities and detached snapshots cannot alter wallet or ownership", function()
		local stats = service(fakeStore()); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win")
		for _, id in ipairs({ "", "unknown", "Skyblue", {}, 42, false }) do
			assert(stats:buyCosmetic(handle, id).code == "invalid_item")
			assert(stats:equipCosmetic(handle, id).code == "invalid_item")
		end
		assert(stats:buyCosmetic(handle, nil).code == "invalid_item")
		local wallet = stats:getEconomy(handle); wallet.credits = 9999; wallet.owned.sunset = true; wallet.equippedTrail = "sunset"
		wallet = stats:getEconomy(handle)
		assert(wallet.credits == 60 and not wallet.owned.sunset and wallet.equippedTrail == "classic")
	end)

	test("loading failed saves and closed records block economic changes", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42)
		assert(not stats:getEconomy(handle).canShop and stats:buyCosmetic(handle, "skyblue").code == "loading")
		stats:load(handle); flight(stats, handle, "one", "win")
		store.failures = 3; assert(not stats:save(handle))
		assert(not stats:getEconomy(handle).canShop and stats:buyCosmetic(handle, "skyblue").code == "unavailable")
		assert(stats:equipCosmetic(handle, "classic").code == "unavailable")
		assert(stats:getEconomy(handle).credits == 60 and not stats:getEconomy(handle).owned.skyblue)
		assert(stats:save(handle) and stats:getEconomy(handle).canShop)
		assert(stats:buyCosmetic(handle, "skyblue").ok and stats:close(handle))
		assert(not stats:equipCosmetic(handle, "skyblue").ok and not stats:buyCosmetic(handle, "ember").ok)
		assert(store.values.player_42.economy.credits == 20 and store.values.player_42.economy.owned.skyblue)
	end)

	test("failed load never grants purchases or overwrites an existing collection", function()
		local store = fakeStore(); local first = service(store); local a = first:open(42); first:load(a)
		flight(first, a, "one", "win"); first:buyCosmetic(a, "skyblue"); first:equipCosmetic(a, "skyblue"); first:close(a)
		store.failures = 3
		local nextStats = service(store, "server-B"); local b = nextStats:open(42); assert(not nextStats:load(b))
		flight(nextStats, b, "failed-session", "win")
		assert(not nextStats:buyCosmetic(b, "skyblue").ok and not nextStats:equipCosmetic(b, "skyblue").ok)
		nextStats:close(b)
		assert(store.values.player_42.economy.credits == 20 and store.values.player_42.economy.equippedTrail == "skyblue")
	end)

	test("malformed durable economies fail closed instead of resetting ownership", function()
		for _, corrupt in ipairs({
			{ credits = -1, owned = { classic = true }, equippedTrail = "classic" },
			{ credits = 1.5, owned = { classic = true }, equippedTrail = "classic" },
			{ credits = 0/0, owned = { classic = true }, equippedTrail = "classic" },
			{ credits = 1e15, owned = { classic = true }, equippedTrail = "classic" },
			{ credits = 100, owned = { classic = true }, equippedTrail = "sunset" },
			{ credits = 100, owned = { classic = true, unknown = true }, equippedTrail = "classic" },
			{ credits = 100, owned = { classic = true, skyblue = false }, equippedTrail = "classic" },
		}) do
			local store = fakeStore(); store.values.player_42 = { schemaVersion = 2, stats = {}, receipts = {}, economy = corrupt }
			local stats = service(store); local handle = stats:open(42)
			assert(not stats:load(handle) and store.calls == 1)
			assert(not stats:save(handle) and not stats:buyCosmetic(handle, "skyblue").ok)
		end
	end)

	test("currency and purchases arriving during a save stay pending together", function()
		local store = fakeStore(); local stats = service(store); local handle = stats:open(42); stats:load(handle)
		flight(stats, handle, "one", "win")
		store.beforeCommit = function()
			assert(stats:buyCosmetic(handle, "skyblue").ok)
			assert(stats:equipCosmetic(handle, "skyblue").ok)
			flight(stats, handle, "two", "win", { practice = true })
		end
		assert(stats:save(handle))
		assert(store.values.player_42.economy.credits == 60 and not store.values.player_42.economy.owned.skyblue)
		assert(stats:getEconomy(handle).credits == 45 and select(2, stats:get(handle)) == "pending")
		assert(stats:save(handle))
		assert(store.values.player_42.economy.credits == 45 and store.values.player_42.economy.equippedTrail == "skyblue")
	end)

	test("pending load rewards are merged with saved wallet and receipt deduplication", function()
		local store = fakeStore(); local first = service(store); local a = first:open(42); first:load(a)
		flight(first, a, "one", "win"); first:buyCosmetic(a, "skyblue"); first:close(a)
		local stats = service(store, "server-B"); local b = stats:open(42)
		store.beforeReturn = function()
			flight(stats, b, "one", "win"); flight(stats, b, "two", "win", { practice = true })
			assert(not stats:buyCosmetic(b, "skyblue").ok)
		end
		assert(stats:load(b))
		assert(stats:getEconomy(b).credits == 45 and stats:getEconomy(b).owned.skyblue)
	end)

	test("lease takeover fences old collection changes as one atomic record", function()
		local store, env = fakeStore(), environment()
		local first = service(store, "server-A", env); local a = first:open(42); first:load(a)
		flight(first, a, "one", "win"); first:save(a); env.time = env.time + 181
		local second = service(store, "server-B", env); local b = second:open(42); assert(second:load(b))
		second:buyCosmetic(b, "skyblue"); second:equipCosmetic(b, "skyblue"); second:close(b)
		first:buyCosmetic(a, "skyblue"); assert(not first:save(a) and not first:getEconomy(a).canShop)
		assert(store.values.player_42.economy.credits == 20 and store.values.player_42.economy.equippedTrail == "skyblue")
	end)

    local function battle(stats,handle,id,outcome,extra)
        local input={outcome=outcome or "loss",reason="first_to_two",completedRounds=2,fightSeconds=45,
            mode="public",offenceId="Meteor",wildIds={"SpringBumper"}}
        for key,value in pairs(extra or {})do input[key]=value end
        return stats:recordBattle(handle,id,input)
    end
    test("five battle losses reach separate250 goal with first choice and no combat grants",function()
        local stats=service(fakeStore(),"studio",nil,{sessionOnly=true});local h=stats:open(42);stats:load(h)
        for index=1,5 do
            local applied,reward=battle(stats,h,"battle-"..index,"loss")
            assert(applied and reward.coins==50 and reward.eligible and reward.status=="session_only" and not reward.confirmed)
        end
        local e=stats:getEconomy(h)
        assert(e.credits==250 and e.goal.price==250 and e.goal.remaining==0 and e.goal.id=="aurora")
        assert(e.progression.matches==5 and e.progression.losses==5 and e.progression.title=="Wingmate")
        assert(e.progression.mastery.Meteor==5 and e.progression.mastery.SpringBumper==5 and e.progression.starterAvailable)
        assert(e.skills==nil and e.ownedSkills==nil and stats:get(h).totalFlights==0)
        assert(stats:equipCosmetic(h,"aurora").code=="not_owned")
        assert(stats:claimStarter(h,"rookieblue").ok and stats:getEconomy(h).credits==250)
        assert(stats:buyCosmetic(h,"aurora").ok and stats:getEconomy(h).credits==0)
        assert(stats:buyCosmetic(h,"aurora").code=="already_owned" and stats:getEconomy(h).credits==0)
        assert(stats:equipCosmetic(h,"aurora").ok and stats:getEconomy(h).equippedTrail=="aurora")
    end)
    test("battle wins75 draws50 and losses50 use cosmetic-only mastery and streak",function()
        local stats=service(fakeStore());local h=stats:open(42);stats:load(h)
        local _,win=battle(stats,h,"win","win");local _,draw=battle(stats,h,"draw","draw")
        assert(win.coins==75 and draw.coins==50 and stats:getBattle(h).currentStreak==1)
        local _,loss=battle(stats,h,"loss","loss")
        assert(loss.coins==50 and stats:getEconomy(h).credits==175 and stats:getBattle(h).currentStreak==0)
        assert(stats:getBattle(h).bestStreak==1 and stats:getBattle(h).title=="Rookie")
        for index=4,15 do battle(stats,h,"more"..index,"loss")end
        assert(stats:getBattle(h).title=="Sky Rival" and stats:getBattle(h).nextTitleAt==nil)
    end)
    test("abandonment diagnostic instant-forfeit and unfinished caps pay nothing",function()
        local stats=service(fakeStore());local h=stats:open(42);stats:load(h)
        for index,extra in ipairs({{abandoned=true,reason="exit"},{diagnostic=true},{mode="experimental"},
            {reason="exit",completedRounds=0,fightSeconds=29.9},{reason="disconnect",completedRounds=0,fightSeconds=0},
            {reason="wall_cap",completedRounds=0,fightSeconds=35},{reason="unknown"}})do
            local applied,reward=battle(stats,h,"denied"..index,"win",extra)
            assert(applied and not reward.eligible and reward.coins==0)
        end
        assert(stats:getEconomy(h).credits==0 and stats:getBattle(h).matches==0 and not stats:getBattle(h).starterAvailable)
    end)
    test("exit and disconnect break a real streak without completion or mastery credit",function()
        for _,reason in ipairs({"exit","disconnect"})do
            local store=fakeStore();local stats=service(store);local h=stats:open(42);stats:load(h)
            battle(stats,h,"win","win")
            local _,reward=battle(stats,h,"quit","abandoned",{reason=reason,abandoned=true,completedRounds=0,fightSeconds=0})
            local b=stats:getBattle(h)
            assert(not reward.eligible and reward.coins==0 and b.currentStreak==0 and b.bestStreak==1)
            assert(b.matches==1 and b.wins==1 and b.losses==0 and b.mastery.Meteor==1)
            assert(stats:getEconomy(h).credits==75 and stats:close(h))
            local nextStats=service(store,"server-B");local restored=nextStats:open(42);assert(nextStats:load(restored))
            assert(nextStats:getBattle(restored).currentStreak==0)
            battle(nextStats,restored,"next-win","win")
            assert(not battle(nextStats,restored,"quit","abandoned",{reason=reason,abandoned=true}))
            assert(nextStats:getBattle(restored).currentStreak==1 and nextStats:getEconomy(restored).credits==150)
        end
    end)
    test("diagnostic quits and an opponent's early departure do not break a public streak",function()
        local stats=service(fakeStore());local h=stats:open(42);stats:load(h);battle(stats,h,"win","win")
        battle(stats,h,"diagnostic","abandoned",{reason="exit",abandoned=true,diagnostic=true})
        battle(stats,h,"experimental","abandoned",{reason="disconnect",abandoned=true,mode="experimental"})
        battle(stats,h,"opponent-left","win",{reason="exit",completedRounds=0,fightSeconds=0})
        assert(stats:getBattle(h).currentStreak==1 and stats:getBattle(h).matches==1 and stats:getEconomy(h).credits==75)
        local _,reward=battle(stats,h,"outcome-only","abandoned",{reason="exit"})
        assert(not reward.eligible and reward.coins==0 and stats:getBattle(h).currentStreak==0)
    end)
    test("remaining opponent qualifies after one complete round or30 combat seconds",function()
        local stats=service(fakeStore());local h=stats:open(42);stats:load(h)
        local _,one=battle(stats,h,"one","win",{reason="disconnect",completedRounds=1,fightSeconds=12})
        local _,two=battle(stats,h,"two","win",{reason="exit",completedRounds=0,fightSeconds=30})
        assert(one.coins==75 and two.coins==75 and one.reason=="opponent_departed" and two.eligible)
        assert(stats:getBattle(h).matches==2 and stats:getEconomy(h).credits==150)
    end)
    test("battle receipt deduplicates reward and mastery after reconnect",function()
        local store=fakeStore();local stats=service(store);local h=stats:open(42);stats:load(h)
        assert(battle(stats,h,"same","win"));assert(not battle(stats,h,"same","win"));assert(stats:close(h))
        local nextStats=service(store,"server-B");local nextHandle=nextStats:open(42);assert(nextStats:load(nextHandle))
        local applied,reward=battle(nextStats,nextHandle,"same","win")
        assert(not applied and reward.coins==0 and reward.duplicate and stats:getEconomy(h).credits==75)
        assert(nextStats:getBattle(nextHandle).matches==1 and nextStats:getBattle(nextHandle).mastery.Meteor==1)
    end)
    test("first reward claims exactly once without debit and persists choice equipment and goal",function()
        local store=fakeStore();local stats=service(store);local h=stats:open(42);stats:load(h)
        assert(stats:claimStarter(h,"rookieblue").code=="not_earned")
        assert(stats:buyCosmetic(h,"rookieblue").code=="earned_only")
        battle(stats,h,"first","loss")
        assert(stats:claimStarter(h,"sunset").code=="invalid_item")
        assert(stats:claimStarter(h,"rookiecoral").ok)
        assert(stats:claimStarter(h,"rookieblue").code=="already_claimed")
        assert(not stats:getEconomy(h).owned.rookieblue and stats:getEconomy(h).credits==50)
        assert(stats:selectGoal(h,"skyblue").ok and stats:selectGoal(h,"rookieblue").code=="invalid_goal")
        assert(stats:selectGoal(h,"classic").code=="invalid_goal")
        assert(stats:close(h))
        local nextStats=service(store,"server-B");local nextHandle=nextStats:open(42);nextStats:load(nextHandle)
        local e=nextStats:getEconomy(nextHandle)
        assert(e.owned.rookiecoral and e.equippedTrail=="rookiecoral" and e.progression.starterChoice=="rookiecoral")
        assert(not e.progression.starterAvailable and e.goal.id=="skyblue" and e.progression.confirmed)
    end)
    test("schema2 migration preserves earned wallet cosmetics stats and receipts",function()
        local store=fakeStore();store.values.player_42={schemaVersion=2,stats={wins=7,totalFlights=9},receipts={"legacy"},
            economy={credits=123,owned={classic=true,skyblue=true},equippedTrail="skyblue"}}
        local stats=service(store);local h=stats:open(42);assert(stats:load(h))
        local e=stats:getEconomy(h)
        assert(e.credits==123 and e.owned.skyblue and e.equippedTrail=="skyblue" and stats:get(h).wins==7)
        assert(e.progression.matches==0 and e.goal.id=="aurora" and not e.progression.starterAvailable)
        assert(not battle(stats,h,"legacy","loss"));assert(stats:close(h))
        assert(store.values.player_42.schemaVersion==3 and store.values.player_42.battle.matches==0)
    end)
    test("battle completion while profile loading merges exactly once into durable record",function()
        local store=fakeStore();local old=service(store);local h=old:open(42);old:load(h);battle(old,h,"old","win");old:close(h)
        local stats=service(store,"server-B");local nextHandle=stats:open(42)
        battle(stats,nextHandle,"new","loss");assert(stats:getEconomy(nextHandle).credits==50)
        assert(stats:load(nextHandle));assert(stats:getEconomy(nextHandle).credits==125 and stats:getBattle(nextHandle).matches==2)
        assert(not battle(stats,nextHandle,"new","loss"));assert(stats:save(nextHandle))
        assert(store.values.player_42.economy.credits==125 and store.values.player_42.battle.mastery.Meteor==2)
    end)
    test("failed battle save stays explicitly unconfirmed and retry saves a single grant",function()
        local store=fakeStore();local stats=service(store);local h=stats:open(42);stats:load(h)
        local _,reward=battle(stats,h,"one","loss");assert(reward.status=="pending" and not reward.confirmed)
        store.failures=3;assert(not stats:save(h))
        assert(stats:getBattle(h).status=="unavailable" and not stats:getBattle(h).confirmed)
        assert(stats:claimStarter(h,"rookieblue").code=="unavailable")
        assert(store.values.player_42.economy.credits==0 and not battle(stats,h,"one","loss"))
        assert(stats:save(h) and stats:getBattle(h).confirmed and store.values.player_42.economy.credits==50)
    end)
    test("failed initial load cannot overwrite confirmed battle rewards or cosmetics",function()
        local store=fakeStore();local old=service(store);local h=old:open(42);old:load(h);battle(old,h,"old","win")
        old:claimStarter(h,"rookieblue");old:close(h);store.failures=3
        local stats=service(store,"server-B");local failed=stats:open(42);assert(not stats:load(failed))
        local calls=store.calls;battle(stats,failed,"unsafe","loss")
        assert(not stats:getBattle(failed).confirmed and stats:claimStarter(failed,"rookiecoral").code=="unavailable")
        assert(not stats:save(failed));stats:close(failed);assert(store.calls==calls)
        assert(store.values.player_42.economy.credits==75 and store.values.player_42.economy.owned.rookieblue)
    end)
    test("initial-load recovery replays pending awards once over saved rewards and cosmetics",function()
        local store,env=fakeStore(),environment();local old=service(store,"server-A",env)
        local h=old:open(42);old:load(h);battle(old,h,"old","win");old:claimStarter(h,"rookieblue");old:close(h)
        local stats=service(store,"server-B",env);local recovering=stats:open(42)
        battle(stats,recovering,"old","win") -- Durable receipt must win over optimistic replay.
        store.failures=3;assert(not stats:load(recovering))
        battle(stats,recovering,"during-outage","loss")
        assert(not stats:save(recovering) and not stats:getEconomy(recovering).canShop)
        assert(store.values.player_42.economy.credits==75 and store.values.player_42.battle.matches==1)
        local calls=store.calls;env.time=recovering.loadRetryAt-1;stats:step()
        assert(store.calls==calls and not stats:load(recovering))
        store.duplicateCallbacks=true
        store.beforeReturn=function()battle(stats,recovering,"during-retry","win")end
        env.time=recovering.loadRetryAt;stats:step()
        local e=stats:getEconomy(recovering)
        assert(recovering.loaded and recovering.safe and #recovering.pending==0 and e.canShop)
        assert(e.credits==200 and e.progression.matches==3 and e.progression.mastery.Meteor==3)
        assert(e.owned.rookieblue and e.equippedTrail=="rookieblue" and not e.progression.starterAvailable)
        assert(e.progression.status=="pending" and not e.progression.confirmed and store.values.player_42.economy.credits==75)
        env.time=env.time+1;stats:step()
        assert(stats:getBattle(recovering).confirmed and store.values.player_42.economy.credits==200)
        assert(not battle(stats,recovering,"during-outage","loss"))
        assert(stats:close(recovering))
        local nextStats=service(store,"server-C",env);local restored=nextStats:open(42);assert(nextStats:load(restored))
        assert(nextStats:getEconomy(restored).credits==200 and nextStats:getBattle(restored).matches==3)
    end)
    test("locked initial load retries after lease expiry and fences the former owner",function()
        local store,env=fakeStore(),environment();local first=service(store,"owner",env)
        local a=first:open(42);first:load(a);battle(first,a,"saved-win","win");first:save(a)
        local stats=service(store,"returning",env);local h=stats:open(42)
        assert(not stats:load(h));battle(stats,h,"offline-loss","loss")
        env.time=h.loadRetryAt;stats:step()
        assert(not h.safe and store.values.player_42.lease.id==a.token and store.values.player_42.economy.credits==75)
        env.time=store.values.player_42.lease.expiresAt+1;stats:step()
        assert(h.safe and h.loaded and stats:getEconomy(h).credits==125 and stats:getBattle(h).currentStreak==0)
        assert(stats:save(h) and store.values.player_42.lease.id==h.token)
        battle(first,a,"stale","win");assert(not first:save(a))
        local calls=store.calls;env.time=env.time+300;first:step()
        assert(not first:load(a) and store.calls==calls and store.values.player_42.economy.credits==125)
    end)
    test("initial-load backoff is capped and cannot be bypassed by repeated load calls",function()
        local store,env=fakeStore(),environment();store.failures=100
        local stats=service(store,"retry",env,{maxAttempts=1});local h=stats:open(42)
        assert(not stats:load(h))
        for _,delay in ipairs({5,10,20,40,60,60})do
            assert(h.loadRetryAt-env.time==delay)
            local calls=store.calls
            assert(not stats:load(h));stats:step();assert(store.calls==calls and not h.safe)
            env.time=h.loadRetryAt;stats:step();assert(store.calls==calls+1)
        end
        assert(not stats:save(h) and store.values.player_42==nil)
    end)
    test("corrupt profiles and closed recovery handles never resume writes",function()
        local store,env=fakeStore(),environment();store.values.player_42={schemaVersion=99,stats={wins=3}}
        local stats=service(store,"corrupt",env);local h=stats:open(42);assert(not stats:load(h))
        battle(stats,h,"pending","loss");local calls=store.calls
        env.time=env.time+300;stats:step()
        assert(not stats:load(h) and not stats:save(h) and store.calls==calls and store.values.player_42.schemaVersion==99)
        local store2=fakeStore();store2.failures=3
        local retry=service(store2,"closed",env);local closed=retry:open(43);assert(not retry:load(closed))
        calls=store2.calls;retry:close(closed);env.time=env.time+300;retry:step()
        assert(not retry:load(closed) and store2.calls==calls and store2.values.player_43==nil)
    end)
    test("quit recorded during unavailable load resets the recovered saved streak",function()
        local store,env=fakeStore(),environment();local old=service(store,"old",env)
        local a=old:open(42);old:load(a);battle(old,a,"win","win");old:close(a)
        store.failures=3;local stats=service(store,"returning",env);local h=stats:open(42);assert(not stats:load(h))
        battle(stats,h,"quit","abandoned",{reason="disconnect",abandoned=true})
        env.time=h.loadRetryAt;stats:step();assert(stats:save(h))
        local saved=store.values.player_42
        assert(saved.battle.currentStreak==0 and saved.battle.bestStreak==1 and saved.battle.matches==1)
        assert(saved.economy.credits==75 and saved.battle.mastery.Meteor==1)
    end)
    test("ambiguous committed reward write and duplicate store callbacks never duplicate",function()
        local store=fakeStore();store.duplicateCallbacks=true
        local stats=service(store);local h=stats:open(42);stats:load(h);battle(stats,h,"one","win")
        stats:claimStarter(h,"rookieblue");store.commitErrors=1;assert(stats:close(h))
        assert(store.values.player_42.economy.credits==75 and store.values.player_42.battle.matches==1)
        assert(store.values.player_42.economy.owned.rookieblue and store.values.player_42.lease==nil)
    end)
    test("claim concurrent with save remains pending and is preserved on next flush",function()
        local store=fakeStore();local stats=service(store);local h=stats:open(42);stats:load(h);battle(stats,h,"first","loss")
        store.beforeCommit=function()assert(stats:claimStarter(h,"rookiecoral").ok)end
        assert(stats:save(h));assert(stats:getBattle(h).status=="pending" and not store.values.player_42.economy.owned.rookiecoral)
        assert(stats:save(h));assert(store.values.player_42.economy.owned.rookiecoral and stats:getBattle(h).confirmed)
    end)
    test("corrupt new mastery or unbacked starter choice cannot erase an old record",function()
        for _,corrupt in ipairs({"mastery","starter"})do
            local store=fakeStore();local old=service(store);local h=old:open(42);old:load(h);battle(old,h,"one","loss");old:close(h)
            if corrupt=="mastery"then store.values.player_42.battle.mastery.Copycat=99
            else store.values.player_42.battle.starterAvailable=false;store.values.player_42.battle.starterChoice="rookieblue"end
            local stats=service(store,"server-B");local broken=stats:open(42);assert(not stats:load(broken))
            assert(not stats:save(broken) and store.values.player_42.economy.credits==50)
        end
    end)
    test("invalid terminal inputs do not mutate receipts wallet or mastery",function()
        local stats=service(fakeStore());local h=stats:open(42);stats:load(h)
        for _,extra in ipairs({{completedRounds=6},{fightSeconds=0/0},{offenceId="Copycat"},
            {wildIds={"SpringBumper","SpringBumper"}},{wildIds={bad="Afterburner"}},{outcome="invented"}})do
            assert(not battle(stats,h,"bad","loss",extra))
        end
        assert(stats:getEconomy(h).credits==0 and stats:getBattle(h).matches==0 and #h.receipts==0)
    end)

    test("cards seen are recorded once, saved with the profile, and survive a slow load and an old save",function()
        local store=fakeStore();local stats=service(store);local h=stats:open(42)
        -- Seen before the profile has loaded: kept, and merged once it has.
        local early=stats:discover(h,{"Meteor","Nope","Meteor",7})
        assert(#early==1 and early[1]=="Meteor" and stats:getEconomy(h).progression.discovered.Meteor==true)
        assert(stats:load(h))
        local fresh=stats:discover(h,{"Meteor","Rewind","BlackHole"})
        assert(#fresh==2 and fresh[1]=="Rewind" and fresh[2]=="BlackHole","A card already seen was reported as new")
        assert(#stats:discover(h,{"Rewind"})==0 and #stats:discover(h,nil)==0 and #stats:discover(nil,{"Meteor"})==0)
        assert(stats:close(h))
        local saved=store.values.player_42.battle.discovered
        assert(saved.Meteor==true and saved.Rewind==true and saved.BlackHole==true and saved.Nope==nil)
        local nextStats=service(store,"server-B");local nextHandle=nextStats:open(42);assert(nextStats:load(nextHandle))
        assert(nextStats:getBattle(nextHandle).discovered.Rewind==true and #nextStats:discover(nextHandle,{"Rewind","Thief"})==1)
        assert(nextStats:close(nextHandle))
        -- A save from before the record existed loads as "nothing seen yet".
        store.values.player_42.battle.discovered=nil;store.values.player_42.lease=nil
        local old=service(store,"server-C");local oldHandle=old:open(42);assert(old:load(oldHandle))
        assert(next(old:getBattle(oldHandle).discovered)==nil and old:getBattle(oldHandle).matches==0)
        assert(old:close(oldHandle))
        -- A record naming a card that does not exist is corrupt, like any other.
        store.values.player_42.battle.discovered={Paid=true};store.values.player_42.lease=nil
        local bad=service(store,"server-D");local badHandle=bad:open(42)
        assert(not bad:load(badHandle) and bad:getBattle(badHandle).status=="unavailable")
    end)

	return tostring(passed) .. " player-stats tests passed"
end
