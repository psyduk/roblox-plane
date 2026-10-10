"""Run pure battle checks and repeatable cross-offence timing samples.

Requires the optional Lupa package. For the local test environment:
    build/testenv/bin/python scripts/sample_battle.py --samples 10
    build/testenv/bin/python scripts/sample_battle.py --tests-only
    build/testenv/bin/python scripts/sample_battle.py --samples 10 --mirrors --json
    build/testenv/bin/python scripts/sample_battle.py --samples 2 --wild-sample --baseline build/battle-lab-v3/BattleSimulation.luau --baseline-scope meteor-charge --json

A baseline is an older copy of BattleSimulation.luau. Copies from before the
skill catalog (one power and one modifier per plane) are translated to builds.

These are simulation checks, not evidence of player enjoyment, real Roblox
network behavior, presentation quality, or competitive balance.
"""
from collections import Counter
from itertools import combinations, product
from pathlib import Path
from statistics import mean
import argparse
import json

from lupa import LuaRuntime

from lua_modules import load_battle

ROOT = Path(__file__).resolve().parents[1]
# Every way to carry zero, one or two different wild cards.
def loadouts(ids):
    return [()] + [(a,) for a in ids] + list(combinations(ids, 2))


MEASURE = """function(sim, seed, powerA, angleA, powerB, angleB, wildA, wildB)
 local state=sim.newRound(seed,{offenceId=powerA,angle=angleA,wildIds=wildA},
  {offenceId=powerB,angle=angleB,wildIds=wildB})
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
    if event.kind=='skill' and event.skillId=='Afterburner' then boosts=boosts+1 end
    if event.kind=='windup' and state.fighters[event.actor].offenceId=='Meteor' then charges[event.actor]=event.at end
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
  winnerPower=state.winner==0 and 'draw' or state.fighters[state.winner].offenceId,
  firstHit=firstHit or state.elapsed,longestQuiet=longestQuiet,
  attacks=state.fighters[1].attacks+state.fighters[2].attacks,
  hits=state.fighters[1].hits+state.fighters[2].hits,peakProjectiles=peakProjectiles,
  peakWakes=peakWakes,blocks=blocks,wakeHits=wakeHits,boosts=boosts,dives=dives}
end"""

COMPARE_BASELINE = """function(oldSim,newSim,seed,powerA,angleA,powerB,angleB,wildA,wildB,preMeteorWindup)
 -- A baseline from before the skill catalog names things differently: one
 -- powerId and one modifierId per plane. Everything else must match exactly.
 local legacy=oldSim.validPower~=nil
 local function build(power,angle,wild) return {offenceId=power,angle=angle,wildIds=wild} end
 local function old(power,angle,wild)
  if not legacy then return build(power,angle,wild) end
  assert(#wild<=1,'A legacy baseline carries one modifier at most')
  return {powerId=power,angle=angle,modifierId=wild[1] or 'None'}
 end
 local old,new=oldSim.newRound(seed,old(powerA,angleA,wildA),old(powerB,angleB,wildB)),
  newSim.newRound(seed,build(powerA,angleA,wildA),build(powerB,angleB,wildB))
 -- State that now belongs to one skill is absent on planes without that skill.
 local unused={bumperReady=false,_boostPending=false,_wakeLeft=0,_wakeNext=0}
 local function same(original,current,path,root)
  if legacy and type(original)=='table' and original.armor~=nil then
   assert(current.offenceId==original.powerId,'Baseline power mismatch: '..path)
   assert((current.wildIds[1] or 'None')==original.modifierId and #current.wildIds<=1,'Baseline modifier mismatch: '..path)
  end
  assert(type(original)==type(current),'Baseline type mismatch: '..path)
  if type(original)~='table' then assert(original==current,'Baseline value mismatch: '..path);return end
  for key,value in pairs(original) do
   local renamed=legacy and original.armor~=nil and (key=='powerId' or key=='modifierId' or key=='settings')
   local absent=legacy and original.armor~=nil and current[key]==nil and unused[key]==value
   -- Presentation events may grow without changing any physical/gameplay state.
   if not (root and (key=='events' or key=='eventSerial')) and not renamed and not absent then
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
    if new.fighters[index].offenceId=='Meteor' and (fighter.phase=='Windup' or new.fighters[index].phase=='Windup') then return ticks end
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


def load_reference(runtime, path):
    """A baseline directory freezes its handlers as well as its round engine."""
    skills_path = path.parent / "BattleSkills.luau"
    if not skills_path.exists():
        return load_battle(runtime, path)[0]
    skills = runtime.execute(skills_path.read_text())
    saved_script, saved_require = runtime.globals().script, runtime.globals().require
    runtime.globals().script = runtime.table_from({"Parent": runtime.table_from({"BattleSkills": runtime.table_from({"module": skills})})})
    runtime.globals().require = runtime.eval("function(module) return module.module end")
    try:
        return runtime.execute(path.read_text())
    finally:
        runtime.globals().script, runtime.globals().require = saved_script, saved_require


FAST_MEASURE = """function(sim, seed, powerA, angleA, powerB, angleB, wildA, wildB)
 local s=sim.newRound(seed,{offenceId=powerA,angle=angleA,wildIds=wildA},{offenceId=powerB,angle=angleB,wildIds=wildB})
 for i=1,2200 do sim.step(s,sim.FIXED_DT);if s.finished then break end end
 assert(s.finished,'Round exceeded cap')
 return {winner=s.winner,reason=s.reason,seconds=s.elapsed,
 secondWindA=s.fighters[1].secondWind==true,secondWindB=s.fighters[2].secondWind==true}
end"""


def summary(records):
    from statistics import stdev
    grouped = {}
    for r in records:
        grouped.setdefault(r["seed_index"], []).append(1 if r["winner"] == 1 else .5 if r["winner"] == 0 else 0)
    seed_scores = [mean(v) for v in grouped.values()]
    score = mean(seed_scores)
    # Cluster at the independent seed level, never pretend angle/seat variants
    # are independent observations. This is a descriptive normal interval.
    error = 1.96 * stdev(seed_scores) / len(seed_scores) ** .5 if len(seed_scores) > 1 else None
    wins, losses, draws = (sum(r["winner"] == n for r in records) for n in (1, 2, 0))
    count = len(records)
    caps = sum(r["reason"] == "timeout" for r in records)
    times = distribution([r["seconds"] for r in records])
    flags = []
    if not .35 <= score <= .65: flags.append("pair-score")
    if draws / count >= .1: flags.append("draws")
    if caps / count > .2: flags.append("round-cap")
    if not 20 <= times["median"] <= 30: flags.append("duration")
    return {"rounds": count, "independent_seeds": len(seed_scores), "wins": wins, "losses": losses,
            "draws": draws, "score": round(score, 4), "seed_95_interval":
            [round(max(0, score-error),4),round(min(1,score+error),4)] if error is not None else None,
            "draw_rate": round(draws/count,4), "round_caps": caps, "cap_rate": round(caps/count,4),
            "knockouts": count-caps, "duration_seconds": times,
            "second_wind_trigger_rate": round(sum(r.get("secondWindA", False) for r in records)/count,4), "flags": flags}


def paired_lift_interval(rows, baseline):
    from statistics import stdev
    def by_seed(values):
        scores={}
        for r in values:
            scores.setdefault(r["seed_index"],[]).append(1 if r["winner"]==1 else .5 if r["winner"]==0 else 0)
        return {seed:mean(v) for seed,v in scores.items()}
    a,b=by_seed(rows),by_seed(baseline)
    lifts=[(a[seed]-b[seed])*100 for seed in a]
    if len(lifts)<2:return None
    error=1.96*stdev(lifts)/len(lifts)**.5
    return [round(mean(lifts)-error,2),round(mean(lifts)+error,2)]


def main():
    import time
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=10, help="Independent seeds; angles and seats are paired observations")
    parser.add_argument("--mirrors", action="store_true", help="Compatibility flag: mirrors are always included")
    parser.add_argument("--tests-only", action="store_true")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--baseline-scope", choices=("all", "meteor-charge", "outcomes"), default="all")
    parser.add_argument("--wild-sample", "--modifier-sample", dest="wild_sample", action="store_true", help="Include single-card lift and all full-build pairs")
    parser.add_argument("--quick", action="store_true", help="One opening angle; full builds face every bare and matching paired-card offence, not exhaustive other pairs")
    parser.add_argument("--skill", help="Restrict rows/columns to this active skill id")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--markdown", action="store_true")
    args = parser.parse_args()
    if args.samples < 1: parser.error("--samples must be positive")
    started = time.monotonic()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    simulation, skills, catalog = load_battle(runtime)
    offences = [x["id"] for x in catalog.all("offence").values()]
    wild_ids = [x["id"] for x in catalog.all("wild").values()]
    if args.skill and args.skill not in offences + wild_ids: parser.error("Skill is outside the implemented active roster")
    test = runtime.execute((ROOT / "tests/BattleSimulation.spec.luau").read_text())
    catalog_test = runtime.execute((ROOT / "tests/SkillCatalog.spec.luau").read_text())
    result = {"validation": [test(simulation, catalog, skills), catalog_test(catalog)],
              "evidence": "Pure deterministic simulation; human comprehension, phone readability, network behavior and fun remain playtest gates.",
              "roster_version": catalog.ROSTER_VERSION, "contract_version": simulation.CONTRACT_VERSION,
              "independent_seeds": args.samples, "seed_formula": "104729 + sample_index * 7919",
              "uncertainty": "95% normal interval over seed-cluster mean scores; angles and seats are not independent; one seed has no interval.",
              "scope": "Active 4/5 roster only. Expansion is not implemented and is outside Milestones 1/2."}
    table = lambda values: runtime.table_from(list(values))
    angles = (32,) if args.quick else (10,32,55)
    measure = runtime.eval(FAST_MEASURE)
    cache = {}
    total = 0
    def records(a, b, wa=(), wb=(), angle_pairs=None, sim=None):
        nonlocal total
        sim = sim or simulation
        pairs = tuple(angle_pairs or product(angles, angles))
        key = (a,b,wa,wb,pairs,sim==simulation)
        if key in cache: return cache[key]
        rows=[]
        for index in range(args.samples):
            for aa,ab in pairs:
                r=dict(measure(sim,104729+index*7919,a,aa,b,ab,table(wa),table(wb)))
                r["seed_index"]=index
                rows.append(r);total+=1
        cache[key]=rows
        return rows
    def both_seats(a,b,wa=(),wb=(),angle_pairs=None):
        rows = list(records(a,b,wa,wb,angle_pairs))
        for r in records(b,a,wb,wa,angle_pairs):
            r=dict(r);r["winner"]=3-r["winner"] if r["winner"] else 0
            r["secondWindA"]=r.get("secondWindB",False)
            rows.append(r)
        return rows
    if args.baseline:
        baseline = load_reference(runtime,args.baseline)
        if args.baseline_scope == "outcomes":
            result["baseline_comparison"]={}
            for a,b in product(("Meteor","Firework"), repeat=2):
                result["baseline_comparison"][f"{a} vs {b}"]={"before":summary(records(a,b,sim=baseline)),"after":summary(records(a,b))}
        else:
            compare=runtime.eval(COMPARE_BASELINE)
            compared=ticks=0
            pairs=[("Meteor","Firework"),("Firework","Meteor")]
            if args.baseline_scope == "meteor-charge": pairs.append(("Firework","Firework"))
            for index,aa,ab,(a,b) in product(range(args.samples),(10,32,55),(10,32,55),pairs):
                ticks+=compare(baseline,simulation,104729+index*7919,a,aa,b,ab,table(()),table(()),args.baseline_scope=="meteor-charge" and "Meteor" in (a,b))
                compared+=1
            result["baseline_comparison"]={"exact_rounds":compared,"ticks":ticks,"scope":args.baseline_scope}
    if not args.tests_only:
        result["angles"]=list(angles)
        result["matchups"]={}
        for a,b in product(offences,repeat=2):
            if args.skill in offences and args.skill not in (a,b): continue
            result["matchups"][f"{a} vs {b}"]=summary(records(a,b))
        result["offence_field"]={}
        for a in offences:
            if args.skill in offences and a!=args.skill: continue
            rows=[r for b in offences for r in both_seats(a,b)]
            value=summary(rows)
            value["equal_opponent_weighting"]=True
            if not .45<=value["score"]<=.55: value["flags"].append("field-score")
            result["offence_field"][a]=value
        if args.wild_sample:
            result["wild_lift"]={}
            wild_angles=((32,32),)
            for wild in wild_ids:
                if args.skill in wild_ids and args.skill!=wild: continue
                values={}
                for a in offences:
                    if args.skill in offences and args.skill!=a: continue
                    rows=[r for b in offences for r in both_seats(a,b,(wild,),(),wild_angles)]
                    bare=[r for b in offences for r in both_seats(a,b,(),(),wild_angles)]
                    v=summary(rows);v["lift_points"]=round((v["score"]-summary(bare)["score"])*100,2)
                    v["paired_lift_seed_95_interval_points"]=paired_lift_interval(rows,bare)
                    values[a]=v
                result["wild_lift"][wild]={"by_offence":values,"average_lift_points":round(mean(v["lift_points"] for v in values.values()),2),
                                           "worst_lift_points":max(v["lift_points"] for v in values.values())}
            result["full_builds"]={}
            all_wild=loadouts(wild_ids)
            for a,wa in product(offences,combinations(wild_ids,2)):
                if args.skill and args.skill!=a and args.skill not in wa: continue
                opponents=[(b,wb) for b in offences for wb in (((),wa) if args.quick else all_wild)]
                pair_rows=[(b,wb,both_seats(a,b,wa,wb,wild_angles)) for b,wb in opponents]
                rows=[r for _,_,rr in pair_rows for r in rr]
                adverse=[]
                for b,wb,rr in pair_rows:
                    metrics=summary(rr)
                    if metrics["flags"]:
                        adverse.append({"opponent":b+("+"+"+".join(wb) if wb else ""),**metrics})
                adverse.sort(key=lambda m:abs(m["score"]-.5)+m["draw_rate"]+m["cap_rate"],reverse=True)
                v=summary(rows);v["opposing_builds"]=len(opponents)
                v["adverse_pairing_count"]=len(adverse)
                v["worst_pairings"]=adverse[:5]
                if v["score"]>.65:v["flags"].append("full-build-score")
                result["full_builds"][a+"+"+"+".join(wa)]=v
            result["wild_sampling"]="Paired seeds, both seats, angle 32. "+("QUICK: full builds face bare and same-card opponents only." if args.quick else "All 40 two-card builds versus all 64 active zero/one/two-card builds.")
        result["flags"]=[section+": "+label+": "+", ".join(v["flags"]) for section in ("matchups","offence_field","full_builds") for label,v in result.get(section,{}).items() if v["flags"]]
        result["flags"] += ["wild average lift: "+w for w,v in result.get("wild_lift",{}).items() if v["average_lift_points"]>10]
    result["total_simulated_rounds"]=total
    result["runtime_seconds"]=round(time.monotonic()-started,2)
    if args.json: print(json.dumps(result,indent=2,sort_keys=True))
    else:
        print("\n".join(result["validation"]));print(result["evidence"])
        print(f"{args.samples} independent seeds; angles {list(angles)}; half-point draw score; {total} rounds; {result['runtime_seconds']}s")
        print(result["uncertainty"])
        for section in ("matchups","offence_field","full_builds"):
            if section not in result:continue
            print("\n"+section)
            print("| Build | W/L/D | Score | Seed 95% | Cap | Median / p90 | Flags |")
            print("|---|---:|---:|---|---:|---:|---|")
            for k,v in result[section].items():
                print(f"| {k} | {v['wins']}/{v['losses']}/{v['draws']} | {v['score']:.1%} | {v['seed_95_interval']} | {v['cap_rate']:.1%} | {v['duration_seconds']['median']} / {v['duration_seconds']['p90']} | {', '.join(v['flags'])} |")
        for w,v in result.get("wild_lift",{}).items():
            print(f"{w}: average lift {v['average_lift_points']:+.2f} pp; worst {v['worst_lift_points']:+.2f} pp; "+", ".join(f"{a} {x['lift_points']:+.2f}" for a,x in v['by_offence'].items()))
        if result.get("flags"):print("\nFlags: "+"; ".join(result["flags"]))
        if args.baseline:print("Baseline:",json.dumps(result["baseline_comparison"]))


if __name__ == "__main__":
    main()
