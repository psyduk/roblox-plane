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

	return tostring(passed) .. " player-stats tests passed"
end
