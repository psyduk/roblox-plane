-- Pure tests: require(thisModule)(Telemetry). All service calls use doubles.
return function(Telemetry)
	local passed = 0
	local function test(name, callback)
		local ok, problem = pcall(callback)
		assert(ok, name .. ": " .. tostring(problem))
		passed = passed + 1
	end
	local function fixture(overrides)
		local calls, time = {}, {value = 10}
		local analytics = {LogCustomEvent = function(_, player, name, value, fields)
			table.insert(calls, {player = player, name = name, value = value, fields = fields})
		end}
		local options = {enabled = true, isStudio = false, analytics = analytics, clock = function() return time.value end}
		for key, value in pairs(overrides or {}) do options[key] = value end
		return Telemetry.new(options), calls, time
	end

	test("disabled by default and in Studio", function()
		local calls = 0
		local analytics = {LogCustomEvent = function() calls = calls + 1 end}
		local disabled = Telemetry.new({analytics = analytics, isStudio = false})
		local studio = Telemetry.new({enabled = true, analytics = analytics, isStudio = true})
		assert(not disabled:sessionStart({}) and not studio:sessionStart({}))
		assert(calls == 0)
	end)

	test("environment detection fails closed", function()
		local telemetry, calls = fixture({isStudio = function() error("unavailable") end})
		assert(not telemetry:sessionStart({}) and #calls == 0)
	end)

	test("lifecycle counts, durations and duplicate suppression", function()
		local telemetry, calls, time = fixture()
		local player = {}
		assert(telemetry:sessionStart(player))
		assert(not telemetry:sessionStart(player))
		assert(telemetry:queueStart(player) and not telemetry:queueStart(player))
		time.value = 15
		assert(telemetry:matchStart(player, false) and not telemetry:matchStart(player, false))
		time.value = 40
		assert(telemetry:matchComplete(player, "win", false))
		assert(not telemetry:matchComplete(player, "win", false))
		assert(calls[4].name == "MatchCompleted" and calls[4].fields.CustomField02 == "win")
		assert(calls[5].name == "MatchDurationSeconds" and calls[5].value == 25)
		assert(telemetry:rematch(player) and not telemetry:rematch(player))
		time.value = 50
		assert(telemetry:sessionEnd(player) and not telemetry:sessionEnd(player))
		assert(calls[7].name == "SessionDurationSeconds" and calls[7].value == 40)
		assert(not telemetry:queueStart(player) and not telemetry:matchStart(player, true))
	end)

	test("practice and rematch use the original launch mode", function()
		local telemetry, calls = fixture()
		local player = {}
		telemetry:sessionStart(player)
		assert(not telemetry:rematch(player) and not telemetry:matchComplete(player, "win", false))
		telemetry:matchStart(player, true)
		telemetry:matchComplete(player, "loss", false)
		telemetry:rematch(player)
		assert(calls[2].fields.CustomField01 == "practice")
		assert(calls[3].fields.CustomField01 == "practice" and calls[5].fields.CustomField01 == "practice")
		assert(telemetry:matchStart(player, false))
		telemetry:matchComplete(player, "tie", false)
		assert(telemetry:rematch(player))
	end)

	test("arbitrary identifiers never enter the fixed schema", function()
		local telemetry, calls = fixture()
		local player = {Name = "private name", UserId = 987654321}
		telemetry:sessionStart(player)
		telemetry:matchStart(player, false)
		telemetry:matchComplete(player, player.Name, false)
		telemetry:phaseAbandoned(player, "secret match ID")
		assert(calls[3].fields.CustomField02 == "unknown")
		assert(calls[5].fields.CustomField03 == "Unknown")
		for _, call in ipairs(calls) do
			assert(call.player == player)
			for key, value in pairs(call.fields or {}) do
				assert(key == "CustomField01" or key == "CustomField02" or key == "CustomField03")
				assert(type(value) == "string" and value ~= player.Name and value ~= tostring(player.UserId))
			end
		end
	end)

	test("abandonment clears queue and flight state", function()
		local telemetry, calls = fixture()
		local player = {}
		telemetry:sessionStart(player)
		telemetry:queueStart(player)
		assert(telemetry:phaseAbandoned(player, "Queued"))
		assert(not telemetry:phaseAbandoned(player, "Queued"))
		assert(telemetry:queueStart(player))
		assert(telemetry:phaseAbandoned(player, "Aim"))
		assert(calls[#calls].fields.CustomField03 == "Aim")
		telemetry:matchStart(player, false)
		assert(telemetry:phaseAbandoned(player, "Flight"))
		assert(not telemetry:matchComplete(player, "win", false) and not telemetry:rematch(player))
		assert(telemetry:matchStart(player, false))
	end)

	test("service failures cannot propagate or cause retries", function()
		local attempts = 0
		local telemetry = fixture({analytics = {LogCustomEvent = function()
			attempts = attempts + 1
			error("service error")
		end}})
		local player = {}
		assert(not telemetry:sessionStart(player))
		assert(not telemetry:sessionStart(player) and attempts == 1)
		telemetry:matchStart(player, false)
		telemetry:matchComplete(player, "win", false)
		telemetry:sessionEnd(player)
		assert(attempts == 5 and telemetry._sessionCount == 0)
	end)

	test("per-player rolling rate limit expires and remains bounded", function()
		local telemetry, calls, time = fixture()
		local player = {}
		telemetry:sessionStart(player)
		for _ = 1, 100 do telemetry:queueStart(player); telemetry:phaseAbandoned(player, "Queued") end
		assert(#calls == 16 and #telemetry._sessions[player].events == 16)
		time.value = 70
		assert(telemetry:queueStart(player))
		assert(#calls == 17 and #telemetry._sessions[player].events == 1)
	end)

	test("server rolling rate limit survives session churn", function()
		local telemetry, calls = fixture()
		for _ = 1, 500 do local player = {}; telemetry:sessionStart(player); telemetry:sessionEnd(player) end
		assert(#calls == 112 and #telemetry._events == 112 and telemetry._sessionCount == 0)
	end)

	test("session storage is capped and released on departure", function()
		local telemetry = fixture()
		local players = {}
		for i = 1, 300 do players[i] = {}; telemetry:sessionStart(players[i]) end
		assert(telemetry._sessionCount == 256 and not telemetry._sessions[players[257]])
		telemetry:sessionEnd(players[1])
		telemetry:sessionStart(players[257])
		assert(telemetry._sessionCount == 256 and telemetry._sessions[players[257]])
	end)

	test("invalid clocks cannot propagate or prevent cleanup", function()
		local telemetry, calls, time = fixture()
		local player = {}
		telemetry:sessionStart(player)
		time.value = 0 / 0
		assert(not telemetry:matchStart(player, false))
		assert(not telemetry:sessionEnd(player) and telemetry._sessionCount == 0)
		assert(#calls == 1)
		local broken = fixture({clock = function() error("clock failed") end})
		assert(not broken:sessionStart({}))
	end)

	test("durations remain finite and nonnegative across clock regression", function()
		local telemetry, calls, time = fixture()
		local player = {}
		telemetry:sessionStart(player)
		telemetry:matchStart(player, false)
		time.value = -50
		telemetry:matchComplete(player, "completed", false)
		assert(calls[4].value == 0)
		time.value = 100000
		telemetry:sessionEnd(player)
		assert(calls[5].value == 86400)
	end)
    test("battle funnel counts actual launches not replay requests", function()
        local telemetry,calls,time=fixture()
        local player={}
        telemetry:sessionStart(player)
        assert(telemetry:battleEvent(player,"join",{cohort="new"}))
        assert(telemetry:battleEvent(player,"usable_lobby",{device="phone"}))
        time.value=18
        assert(telemetry:battleEvent(player,"first_launch",{matchId="a"}))
        assert(not telemetry:battleEvent(player,"first_launch",{matchId="a"}))
        time.value=80
        telemetry:battleEvent(player,"terminal_result",{matchId="a",outcome="loss"})
        telemetry:battleEvent(player,"replay_requested",{matchId="a"})
        local count=#telemetry:battleLog()
        assert(telemetry:battleLog()[count].event=="replay_requested")
        time.value=90
        telemetry:battleEvent(player,"first_launch",{matchId="b",rosterVersion="experimental-test"})
        local log=telemetry:battleLog()
        assert(log[#log-1].event=="next_actual_launch" and log[#log-1].elapsed==10)
        assert(log[#log-1].outcome=="loss" and log[#log-1].voluntary==true)
        assert(log[#log-1].rosterVersion=="experimental-test")
        assert(log[#log].event=="match_launch" and log[#log].firstLaunchSeconds==nil)
        assert(log[3].firstLaunchSeconds==8 and log[3].device=="phone")
        telemetry:battleLeave(player)
        assert(telemetry._battle[player]==nil)
    end)
    test("Studio diagnostic events are bounded and never submitted", function()
        local telemetry,calls=fixture({isStudio=true})
        local player={}
        for i=1,300 do telemetry:battleEvent(player,"match_accepted",{matchId=i}) end
        assert(#telemetry:battleLog()==256 and #calls==0)
        assert(telemetry:battleLog()[1].developer==true)
        assert(not telemetry:battleEvent(player,"arbitrary_event",{}))
    end)
	return string.format("Telemetry: %d tests passed", passed)
end
