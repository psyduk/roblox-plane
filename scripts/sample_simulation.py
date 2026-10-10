"""Deterministic offline balance sample. Requires optional `lupa` dependency.

python3 scripts/sample_simulation.py --samples 30
python3 scripts/sample_simulation.py --samples 30 --baseline /path/to/old/Simulation.luau
python3 scripts/sample_simulation.py --powers --samples 10 --baseline /tmp/Simulation.before.luau
python3 scripts/sample_simulation.py --powers --samples 10 --json

The same seeds/settings are used for both modules. Near misses use the module's
counter when available; the baseline estimate measures a cleared missile's
minimum edge gap up to 12 studs. This is simulation evidence, not gameplay QA.
"""
from pathlib import Path
import argparse
from itertools import combinations
import json
from statistics import mean
from lupa import LuaRuntime
from lua_modules import load_simulation

ROOT = Path(__file__).resolve().parents[1]
PRESETS = [('Cruiser', 'cruiser', 35, 'Shield'), ('Skyhopper', 'skyhopper', 48, 'Shield'),
           ('Dart', 'dart', 24, 'Shield'), ('LowAim', 'cruiser', 15, 'Shield'),
           ('HighAim', 'cruiser', 60, 'Shield'), ('Magnet', 'cruiser', 35, 'Magnet'),
           ('Boost', 'cruiser', 35, 'Boost')]
POWERS = ('Pinball', 'Muncher', 'Meteor')
PLANES = ('cruiser', 'skyhopper', 'dart')
ARENAS = ('Coast', 'Skyline', 'Storm')
MEASURE = r'''function(s, settings, course)
 local f=s.newFlight(settings,course)
 local lowRescues,quiet,last,height=0,0,0,0
 local minimumGaps={}
 for _=1,2702 do
  local vy,y,pickups,hits=f.vy,f.y,f.pickups,f.hits
  s.step(f,course,1/60)
  height=math.max(height,f.y)
  if f.pickups>pickups and vy<0 and y<=40 and f.vy>0 then lowRescues=lowRescues+1 end
  if f.pickups>pickups or f.hits>hits then quiet=math.max(quiet,f.elapsed-last);last=f.elapsed end
  if f.nearMisses==nil then
   for _,item in ipairs(course.items)do
    if item.kind=='missile' and math.abs(item.x-f.x)<=45 then
     local x,y=s.itemPosition(item,f.elapsed)
     local gap=math.sqrt((f.x-x)^2+(f.y-y)^2)-item.radius-s.PLANE_RADIUS
     minimumGaps[item.id]=math.min(minimumGaps[item.id] or math.huge,gap)
    end
   end
  end
  if not f.alive then break end
 end
 quiet=math.max(quiet,f.elapsed-last)
 local near=f.nearMisses or 0
 if f.nearMisses==nil then
  for _,item in ipairs(course.items)do
   local gap=minimumGaps[item.id]
   if item.kind=='missile' and item.x<f.x and not f.used[item.id] and gap and gap>0 and gap<=12 then near=near+1 end
  end
 end
 return {time=f.elapsed,distance=f.distance,fuel=f.pickups,hits=f.hits,near=near,
  lowRescues=lowRescues,quiet=quiet,height=height,timeout=f.finishReason=='timeout',objects=#course.items}
end'''

# Keep the full 60 Hz x trace in Lua only; Python receives aggregate metrics.
# Action silence includes power activation/phase changes and actual contacts,
# but excludes launch, finish, near-miss decoration, and continuous motion.
MEASURE_POWER = r'''function(s, settings, course)
 local f=s.newFlight(settings,course)
 assert(f.powerId==settings.powerId,'This simulation does not support the requested power')
 local quiet,last=0,0
 local xs={[0]=f.x}
 local ticks=0
 for i=1,math.ceil(s.MAX_FLIGHT_TIME*60)+2 do
  local pickups,hits,uses,phase=f.pickups,f.hits,f.powerUses,f.powerPhase
  s.step(f,course,1/60)
  ticks=i
  xs[i]=f.x
  if f.pickups>pickups or f.hits>hits or f.powerUses~=uses or f.powerPhase~=phase then
   quiet=math.max(quiet,f.elapsed-last);last=f.elapsed
  end
  if not f.alive then break end
 end
 assert(not f.alive,'Flight did not finish within its configured time limit')
 quiet=math.max(quiet,f.elapsed-last)
 return {time=f.elapsed,distance=f.distance,uses=f.powerUses or 0,
  quiet=quiet,timeout=f.finishReason=='timeout',xs=xs,ticks=ticks}
end'''

MEASURE_DUEL = r'''function(a,b)
 local shared=math.min(a.ticks,b.ticks)
 local close=0
 -- Sample the start of each shared airborne step, excluding landed frames.
 for i=0,shared-1 do
  if math.abs(a.xs[i]-b.xs[i])<=100 then close=close+1 end
 end
 local midpoint=math.floor(math.max(a.ticks,b.ticks)/2)
 local midpointBothAlive=midpoint<shared
 local ad=math.floor(a.distance*10+0.5)/10
 local bd=math.floor(b.distance*10+0.5)/10
 return {wait=math.abs(a.time-b.time),
  closeFraction=shared>0 and close/shared or 0,
  midpointBothAlive=midpointBothAlive,
  midpointGap=midpointBothAlive and math.abs(a.xs[midpoint]-b.xs[midpoint]) or nil,
  winner=ad==bd and 'tie' or (ad>bd and 'a' or 'b')}
end'''


def seed_for(index):
    return 104729 + (index * 7 + 3) * 7919 + (index % 5 + 1) * 3571


def distribution(values):
    values = sorted(values)
    if not values:
        return None
    return dict(mean=round(mean(values), 3), p50=round(values[len(values) // 2], 3),
                p90=round(values[min(len(values) - 1, len(values) * 9 // 10)], 3),
                max=round(values[-1], 3))


def summarize_power(rows):
    return dict(flights=len(rows), timeouts=sum(row['timeout'] for row in rows),
                flight_seconds=distribution([row['time'] for row in rows]),
                distance=distribution([row['distance'] for row in rows]),
                power_uses=distribution([row['uses'] for row in rows]),
                longest_quiet_seconds=distribution([row['quiet'] for row in rows]))


def summarize_duels(rows):
    return dict(duels=len(rows),
                touchdown_wait_seconds=distribution([row['wait'] for row in rows]),
                mean_shared_airtime_within_100_fraction=round(mean(row['closeFraction'] for row in rows), 4),
                both_alive_at_midpoint=sum(row['midpointBothAlive'] for row in rows),
                midpoint_gap_when_both_alive=distribution([row['midpointGap'] for row in rows
                                                          if row['midpointBothAlive']]))


def sample_powers(path, count, label, arenas, angles):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    simulation, _ = load_simulation(runtime, path)
    measure = runtime.eval(MEASURE_POWER)
    duel = runtime.eval(MEASURE_DUEL)
    rows, duel_rows = [], []
    for arena in arenas:
        for plane in PLANES:
            for angle in angles:
                for index in range(1, count + 1):
                    course = simulation.makeCourse(seed_for(index), arena)
                    flights = {}
                    for power in POWERS:
                        settings = runtime.table_from(dict(planeId=plane, angle=angle, powerId=power))
                        result = measure(simulation, settings, course)
                        flights[power] = result
                        rows.append(dict(power=power, arena=arena, **{key: result[key] for key in
                            ('time', 'distance', 'uses', 'quiet', 'timeout')}))
                    for a, b in combinations(POWERS, 2):
                        result = duel(flights[a], flights[b])
                        duel_rows.append(dict(a=a, b=b, arena=arena, **{key: result[key] for key in
                            ('wait', 'closeFraction', 'midpointBothAlive', 'midpointGap', 'winner')}))
    pairs = {}
    for a, b in combinations(POWERS, 2):
        matched = [row for row in duel_rows if row['a'] == a and row['b'] == b]
        wins = {a: sum(row['winner'] == 'a' for row in matched),
                b: sum(row['winner'] == 'b' for row in matched),
                'ties': sum(row['winner'] == 'tie' for row in matched)}
        pairs[f'{a} vs {b}'] = dict(**summarize_duels(matched), wins=wins,
            win_share_including_ties={key: round(value / len(matched), 4) for key, value in wins.items()})
    return dict(label=label, simulation=str(path), samples_per_configuration=count,
                planes=list(PLANES), angles=angles, arenas=arenas,
                by_power={power: summarize_power([row for row in rows if row['power'] == power])
                          for power in POWERS},
                duels=summarize_duels(duel_rows), by_pair=pairs,
                by_arena={arena: {power: summarize_power([row for row in rows
                              if row['arena'] == arena and row['power'] == power])
                              for power in POWERS} for arena in arenas})


def print_power_report(report):
    print(f'\n{report["label"]}: {report["simulation"]}', flush=True)
    print(f'{report["samples_per_configuration"]} seeds/config; planes={",".join(report["planes"])}; '
          f'angles={report["angles"]}; arenas={",".join(report["arenas"])}', flush=True)
    for power, stats in report['by_power'].items():
        duration = stats['flight_seconds']
        quiet = stats['longest_quiet_seconds']
        print(f'{power:7} n={stats["flights"]} seconds mean/p50/p90='
              f'{duration["mean"]:.1f}/{duration["p50"]:.1f}/{duration["p90"]:.1f} '
              f'distance={stats["distance"]["mean"]:.1f} uses={stats["power_uses"]["mean"]:.2f} '
              f'timeouts={stats["timeouts"]} quiet mean/max={quiet["mean"]:.1f}/{quiet["max"]:.1f}', flush=True)
    for pair, stats in report['by_pair'].items():
        wait = stats['touchdown_wait_seconds']
        gap = stats['midpoint_gap_when_both_alive']
        gap_text = f'{gap["mean"]:.1f}' if gap else 'n/a'
        wins = ', '.join(f'{key}={value} ({stats["win_share_including_ties"][key]:.0%})'
                         for key, value in stats['wins'].items())
        print(f'{pair}: n={stats["duels"]}; {wins}; '
              f'wait mean/p90={wait["mean"]:.1f}/{wait["p90"]:.1f}s; '
              f'close shared airtime={stats["mean_shared_airtime_within_100_fraction"]:.0%}; '
              f'midpoint both alive={stats["both_alive_at_midpoint"]}/{stats["duels"]} '
              f'gap={gap_text}', flush=True)
    stats = report['duels']
    print(f'All {stats["duels"]} paired duels: wait mean/p90='
          f'{stats["touchdown_wait_seconds"]["mean"]:.1f}/{stats["touchdown_wait_seconds"]["p90"]:.1f}s; '
          f'close shared airtime={stats["mean_shared_airtime_within_100_fraction"]:.0%}', flush=True)


def sample(path, count, label):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    simulation, catalog = load_simulation(runtime, path)
    measure = runtime.eval(MEASURE)
    all_rows = []
    print(f'\n{label}: {path}', flush=True)
    for variant in ('Coast', 'Skyline', 'Storm'):
        for name, plane_id, angle, gadget in PRESETS:
            rows = []
            for i in range(1, count + 1):
                course = simulation.makeCourse(seed_for(i), variant)
                # Old baselines use power; current modules ignore it and derive
                # speed from the catalog. Old power rounding is approximate.
                profile = catalog.get(plane_id)
                settings = runtime.table_from(dict(planeId=plane_id, angle=angle,
                    power=(profile.speed-46)/0.35, gadget=gadget))
                result = measure(simulation, settings, course)
                rows.append({key: result[key] for key in ('time', 'distance', 'fuel', 'hits', 'near', 'lowRescues', 'quiet', 'height', 'timeout', 'objects')})
            all_rows.extend(rows)
            metrics = ' '.join(f'{key}={mean(row[key] for row in rows):.1f}' for key in ('time', 'distance', 'fuel', 'hits', 'near', 'lowRescues', 'quiet'))
            print(f'{variant:7} {name:7} {metrics} range={min(row["time"] for row in rows):.1f}..{max(row["time"] for row in rows):.1f} timeouts={sum(row["timeout"] for row in rows)}', flush=True)
    times = sorted(row['time'] for row in all_rows)
    print(f'{len(all_rows)} flights; P10/P50/P90={times[len(times)//10]:.1f}/{times[len(times)//2]:.1f}/{times[len(times)*9//10]:.1f}s; '
          f'timeouts={sum(row["timeout"] for row in all_rows)}; '
          f'flights with low fuel upturn={sum(row["lowRescues"]>0 for row in all_rows)/len(all_rows):.1%}; '
          f'objects={mean(row["objects"] for row in all_rows):.0f}; max height={max(row["height"] for row in all_rows):.1f}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=int, default=30, help='Seeds per preset per course')
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--powers', action='store_true', help='Sample powers and matched cross-power duels')
    parser.add_argument('--arenas', nargs='+', choices=ARENAS, default=list(ARENAS), help='Arenas for --powers')
    parser.add_argument('--angles', nargs='+', type=float, default=[15, 35, 55], help='Angles for --powers (15–60)')
    parser.add_argument('--json', action='store_true', help='Machine-readable --powers report, including per-arena summaries')
    args = parser.parse_args()
    if args.samples < 1:
        parser.error('--samples must be positive')
    if any(not 15 <= angle <= 60 for angle in args.angles):
        parser.error('--angles must be between 15 and 60')
    if args.json and not args.powers:
        parser.error('--json requires --powers')
    paths = ([(args.baseline, 'BASELINE')] if args.baseline else []) + [
        (ROOT / 'src/shared/Simulation.luau', 'CURRENT')]
    if args.powers:
        notes = ('Simulation evidence, not gameplay QA. Powers are paired on the same plane, angle, arena, '
                 'and seed; this does not measure optimized power-specific launch strategy. '
                 'Win shares include ties, with distance rounded to 0.1 as on the server. '
                 'Wait is the difference in finish times (including timeouts). Close means horizontal gap '
                 '<=100 studs during shared airtime, averaged equally per duel. Midpoint is half the total '
                 'duel duration; its gap excludes duels where one plane has landed by then. '
                 'Quiet excludes near misses but includes contacts and power transitions. '
                 'Baseline and current both use the current plane and power catalogs.')
        reports = []
        if not args.json:
            print(notes, flush=True)
        for path, label in paths:
            report = sample_powers(path, args.samples, label, list(dict.fromkeys(args.arenas)),
                                   list(dict.fromkeys(args.angles)))
            reports.append(report)
            if not args.json:
                print_power_report(report)
        if args.json:
            print(json.dumps(dict(notes=notes, reports=reports), indent=2))
    else:
        for path, label in paths:
            sample(path, args.samples, label)
