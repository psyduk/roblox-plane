"""Run pure Battle Lab checks and repeatable cross-power timing samples.

Requires the optional Lupa package. For the local test environment:
    build/testenv/bin/python scripts/sample_battle.py --samples 10
    build/testenv/bin/python scripts/sample_battle.py --tests-only
    build/testenv/bin/python scripts/sample_battle.py --samples 10 --mirrors --json
    build/testenv/bin/python scripts/sample_battle.py --samples 2 --modifier-sample --baseline build/battle-lab-v3/BattleSimulation.luau --baseline-scope meteor-charge --json

These are simulation checks, not evidence of player enjoyment, real Roblox
network behavior, presentation quality, or competitive balance.
"""
from collections import Counter
from itertools import product
from pathlib import Path
from statistics import mean
import argparse
import json

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MEASURE = """function(sim, seed, powerA, angleA, powerB, angleB, modifierA, modifierB)
 local state=sim.newRound(seed,{powerId=powerA,angle=angleA,modifierId=modifierA},
  {powerId=powerB,angle=angleB,modifierId=modifierB})
 local serial,lastAction,longestQuiet,firstHit,peakProjectiles=state.eventSerial,0,0,nil,0
 local peakWakes,blocks,wakeHits,boosts=0,0,0,0
 local dives,activeDives,charges={},{},{}
 for _=1,math.ceil(sim.MAX_TIME/sim.FIXED_DT)+2 do
  sim.step(state,sim.FIXED_DT)
  peakProjectiles=math.max(peakProjectiles,#state.projectiles)
  peakWakes=math.max(peakWakes,#state.wakes)
  for _,event in ipairs(state.events) do
   if event.serial>serial and event.kind~='finish' and event.kind~='launch' then
    longestQuiet=math.max(longestQuiet,state.elapsed-lastAction)
    lastAction=state.elapsed
    if (event.kind=='hit' or event.kind=='wake_hit') and firstHit==nil then firstHit=state.elapsed end
    if event.kind=='blocked' then blocks=blocks+1 end
    if event.kind=='wake_hit' then wakeHits=wakeHits+1 end
    if event.kind=='modifier' and event.modifierId=='Afterburner' then boosts=boosts+1 end
    if event.kind=='windup' and state.fighters[event.actor].powerId=='Meteor' then charges[event.actor]=event.at end
    if event.kind=='dive' then
     local opponent=state.fighters[3-event.actor]
     local dive={actor=event.actor,started=event.at,startX=event.x,startY=event.y,
      chargeSeconds=charges[event.actor] and event.at-charges[event.actor] or 0,
      separation=math.sqrt((event.x-opponent.x)^2+(event.y-opponent.y)^2)}
     activeDives[event.actor]=dive;dives[#dives+1]=dive
    end
    if event.kind=='hit' or event.kind=='wake_hit' or event.kind=='blocked' then
     for actor,dive in pairs(activeDives) do
      if event.kind=='hit' and event.source=='meteor' and event.actor==actor then dive.ending='hit'
      elseif event.kind=='blocked' and event.source=='meteor' and event.target==actor then dive.ending='blocked'
      elseif dive.ending==nil then dive.ending='interrupted' end
     end
    end
    if event.kind=='miss' and activeDives[event.actor] then activeDives[event.actor].ending='miss' end
   end
  end
  serial=state.eventSerial
  for actor,dive in pairs(activeDives) do
   local fighter=state.fighters[actor]
   if not fighter.armed or state.finished then
    dive.ended=state.elapsed;dive.seconds=state.elapsed-dive.started
    dive.travel=math.sqrt((fighter.x-dive.startX)^2+(fighter.y-dive.startY)^2)
    dive.ending=dive.ending or (state.finished and 'round_end' or 'recover')
    activeDives[actor]=nil
   end
  end
  if state.finished then break end
 end
 assert(state.finished,'Simulation failed to terminate')
 longestQuiet=math.max(longestQuiet,state.elapsed-lastAction)
 return {seconds=state.elapsed,winner=state.winner,reason=state.reason,
  winnerPower=state.winner==0 and 'draw' or state.fighters[state.winner].powerId,
  firstHit=firstHit or state.elapsed,longestQuiet=longestQuiet,
  attacks=state.fighters[1].attacks+state.fighters[2].attacks,
  hits=state.fighters[1].hits+state.fighters[2].hits,peakProjectiles=peakProjectiles,
  peakWakes=peakWakes,blocks=blocks,wakeHits=wakeHits,boosts=boosts,dives=dives}
end"""

COMPARE_BASELINE = """function(oldSim,newSim,seed,powerA,angleA,powerB,angleB,modifierA,modifierB,preMeteorWindup)
 local a={powerId=powerA,angle=angleA,modifierId=modifierA or 'None'}
 local b={powerId=powerB,angle=angleB,modifierId=modifierB or 'None'}
 local old,new=oldSim.newRound(seed,a,b),newSim.newRound(seed,a,b)
 local function same(original,current,path,root)
  assert(type(original)==type(current),'Baseline type mismatch: '..path)
  if type(original)~='table' then assert(original==current,'Baseline value mismatch: '..path);return end
  for key,value in pairs(original) do
   -- Presentation events may grow without changing any physical/gameplay state.
   if not (root and (key=='events' or key=='eventSerial')) then
    same(value,current[key],path..'.'..tostring(key),false)
   end
  end
 end
 same(old,new,'initial',true)
 local ticks=0
 while not old.finished do
  oldSim.step(old,oldSim.FIXED_DT);newSim.step(new,newSim.FIXED_DT)
  if preMeteorWindup then
   for index,fighter in ipairs(old.fighters) do
    if fighter.powerId=='Meteor' and (fighter.phase=='Windup' or new.fighters[index].phase=='Windup') then return ticks end
   end
  end
  ticks=ticks+1;same(old,new,'tick'..ticks,true)
  assert(ticks<2200,'Baseline did not terminate')
 end
 return ticks
end"""


def distribution(values):
    ordered = sorted(values)
    return {"min": round(ordered[0], 3), "p10": round(ordered[int((len(ordered) - 1) * .1)], 3),
            "median": round(ordered[(len(ordered) - 1) // 2], 3),
            "p90": round(ordered[int((len(ordered) - 1) * .9)], 3),
            "max": round(ordered[-1], 3), "mean": round(mean(ordered), 3)}


def dive_summary(records):
    dives = [dict(dive) for record in records for dive in record["dives"].values()]
    if not dives:
        return {"count": 0}
    landed = [dive for dive in dives if dive["ending"] == "hit"]
    return {"count": len(dives), "armed_seconds": distribution([dive["seconds"] for dive in dives]),
            "landed_armed_seconds": distribution([dive["seconds"] for dive in landed]) if landed else None,
            "travel_units": distribution([dive["travel"] for dive in dives]),
            "release_separation_units": distribution([dive["separation"] for dive in dives]),
            "charge_seconds": distribution([dive["chargeSeconds"] for dive in dives]),
            "at_least_0_3_seconds": sum(dive["seconds"] >= .3 - 1e-7 for dive in dives),
            "under_0_05_seconds": sum(dive["seconds"] < .05 - 1e-7 for dive in dives),
            "endings": dict(Counter(dive["ending"] for dive in dives))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=10, help="Seeds per ordered power matchup; nine angle pairs per seed")
    parser.add_argument("--mirrors", action="store_true", help="Also inspect equal-signature matchups")
    parser.add_argument("--tests-only", action="store_true")
    parser.add_argument("--baseline", type=Path, help="Compare every original physics/gameplay field each tick; exclude only presentation events/eventSerial and added metadata")
    parser.add_argument("--baseline-scope", choices=("all", "meteor-charge"), default="all",
                        help="meteor-charge compares full Firework mirrors and cross-power states only before the first Meteor windup")
    parser.add_argument("--modifier-sample", action="store_true", help="Sample all 16 modifier pairs in both cross-power orders at angle 32")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    runtime = LuaRuntime(unpack_returned_tuples=True)
    simulation = runtime.execute((ROOT / "src/shared/BattleSimulation.luau").read_text())
    modifiers = runtime.execute((ROOT / "src/shared/BattleModifiers.luau").read_text())
    test = runtime.execute((ROOT / "tests/BattleSimulation.spec.luau").read_text())
    result = {"validation": test(simulation, modifiers), "evidence": "Pure simulation only; no human playtest or balance claim."}
    if args.baseline:
        baseline = runtime.execute(args.baseline.read_text())
        compare = runtime.eval(COMPARE_BASELINE)
        rounds, ticks, full_rounds, prefixes = 0, 0, 0, 0
        baseline_matchups = (("Meteor", "Firework"), ("Firework", "Meteor"))
        if args.baseline_scope == "meteor-charge":
            baseline_matchups += (("Firework", "Firework"),)
        for index, angle_a, angle_b, powers in product(range(args.samples), (10, 32, 55), (10, 32, 55),
                                                     baseline_matchups):
            prefix = args.baseline_scope == "meteor-charge" and "Meteor" in powers
            ticks += compare(baseline, simulation, 104729 + index * 7919, powers[0], angle_a, powers[1], angle_b,
                             "None", "None", prefix)
            prefixes += int(prefix)
            full_rounds += int(not prefix)
            rounds += 1
        none_rounds = rounds
        if args.modifier_sample:
            ids = [entry["id"] for entry in modifiers.all().values()]
            for index, modifier_a, modifier_b, powers in product(range(args.samples), ids, ids,
                                                                baseline_matchups):
                prefix = args.baseline_scope == "meteor-charge" and "Meteor" in powers
                ticks += compare(baseline, simulation, 104729 + index * 7919, powers[0], 32, powers[1], 32,
                                 modifier_a, modifier_b, prefix)
                prefixes += int(prefix)
                full_rounds += int(not prefix)
                rounds += 1
        result["baseline_comparison"] = {"rounds": rounds, "none_angle_rounds": none_rounds,
                                         "modifier_rounds": rounds - none_rounds, "ticks": ticks,
                                         "full_rounds": full_rounds, "pre_meteor_windup_prefixes": prefixes,
                                         "scope": args.baseline_scope,
                                         "match": "Every original physics/gameplay field matches exactly for the specified scope. Presentation events/eventSerial and added metadata excluded."}
    if not args.tests_only:
        measure = runtime.eval(MEASURE)
        matches = [("Meteor", "Firework"), ("Firework", "Meteor")]
        if args.mirrors:
            matches.extend([("Meteor", "Meteor"), ("Firework", "Firework")])
        result["samples_per_matchup"] = args.samples * 9
        result["angles"] = [10, 32, 55]
        result["seed_formula"] = "104729 + sample_index * 7919, sample_index starts at zero"
        result["matchups"] = {}
        for power_a, power_b in matches:
            records = []
            for index, a, b in product(range(args.samples), result["angles"], result["angles"]):
                records.append(dict(measure(simulation, 104729 + index * 7919, power_a, a, power_b, b)))
            result["matchups"][f"{power_a} vs {power_b}"] = {
                "rounds": len(records),
                "winners_by_slot": dict(Counter(str(record["winner"]) for record in records)),
                "winners_by_power": dict(Counter(record["winnerPower"] for record in records)),
                "reasons": dict(Counter(record["reason"] for record in records)),
                "duration_seconds": distribution([record["seconds"] for record in records]),
                "first_hit_seconds": distribution([record["firstHit"] for record in records]),
                "longest_event_gap_seconds": distribution([record["longestQuiet"] for record in records]),
                "mean_attacks": round(mean(record["attacks"] for record in records), 3),
                "mean_hits": round(mean(record["hits"] for record in records), 3),
                "peak_projectiles": max(record["peakProjectiles"] for record in records),
                "meteor_dives": dive_summary(records),
            }
        if args.modifier_sample:
            records = []
            ids = [entry["id"] for entry in modifiers.all().values()]
            for index, modifier_a, modifier_b, powers in product(range(args.samples), ids, ids,
                                                                (("Meteor", "Firework"), ("Firework", "Meteor"))):
                records.append(dict(measure(simulation, 104729 + index * 7919,
                                            powers[0], 32, powers[1], 32, modifier_a, modifier_b)))
            result["modifier_sample"] = {
                "rounds": len(records), "angle": 32, "modifier_pairs": "All 16 ordered pairs, both cross-power orders",
                "duration_seconds": distribution([record["seconds"] for record in records]),
                "winners_by_power": dict(Counter(record["winnerPower"] for record in records)),
                "reasons": dict(Counter(record["reason"] for record in records)),
                "bumper_blocks": sum(record["blocks"] for record in records),
                "wake_hits": sum(record["wakeHits"] for record in records),
                "boost_activations": sum(record["boosts"] for record in records),
                "peak_wakes": max(record["peakWakes"] for record in records),
                "meteor_dives": dive_summary(records),
            }
        for label, angle_a, angle_b in (("default_seed_731", 35, 30), ("seed_731_angle32_fixture", 32, 32)):
            fixture = dict(measure(simulation, 731, "Meteor", angle_a, "Firework", angle_b, "None", "None"))
            fixture["dives"] = [dict(dive) for dive in fixture["dives"].values()]
            fixture["settings"] = {"seed": 731, "powerA": "Meteor", "angleA": angle_a, "modifierA": "None",
                                   "powerB": "Firework", "angleB": angle_b, "modifierB": "None"}
            result[label] = fixture
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(result["validation"])
        print(result["evidence"])
        if "baseline_comparison" in result:
            print("Baseline:", result["baseline_comparison"])
        if "modifier_sample" in result:
            print("Modifiers:", result["modifier_sample"])
        for matchup, values in result.get("matchups", {}).items():
            print(f"{matchup}: {values['rounds']} rounds; wins {values['winners_by_power']}; "
                  f"time {values['duration_seconds']}; reasons {values['reasons']}")


if __name__ == "__main__":
    main()
