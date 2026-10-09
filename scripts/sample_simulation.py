"""Deterministic offline balance sample. Requires optional `lupa` dependency.

python3 scripts/sample_simulation.py --samples 30
python3 scripts/sample_simulation.py --samples 30 --baseline /path/to/old/Simulation.luau

The same seeds/settings are used for both modules. Near misses use the module's
counter when available; the baseline estimate measures a cleared missile's
minimum edge gap up to 12 studs. This is simulation evidence, not gameplay QA.
"""
from pathlib import Path
import argparse
from statistics import mean
from lupa import LuaRuntime
from lua_modules import load_simulation

ROOT = Path(__file__).resolve().parents[1]
PRESETS = [('Cruiser', 'cruiser', 35, 'Shield'), ('Skyhopper', 'skyhopper', 48, 'Shield'),
           ('Dart', 'dart', 24, 'Shield'), ('LowAim', 'cruiser', 15, 'Shield'),
           ('HighAim', 'cruiser', 60, 'Shield'), ('Magnet', 'cruiser', 35, 'Magnet'),
           ('Boost', 'cruiser', 35, 'Boost')]
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
                course = simulation.makeCourse(104729 + (i * 7 + 3) * 7919 + (i % 5 + 1) * 3571, variant)
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
    args = parser.parse_args()
    if args.samples < 1:
        parser.error('--samples must be positive')
    if args.baseline:
        sample(args.baseline, args.samples, 'BASELINE')
    sample(ROOT / 'src/shared/Simulation.luau', args.samples, 'CURRENT')
