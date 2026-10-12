"""How a round plays, measured offline.

Runs every top against every top in both seats and prints what a spectator
would feel: how long rounds last, how often tops touch, how often one nearly
falls, who wins. NAME=value arguments override BattleSimulation constants and
Top.field=value overrides one number in BattleSkills (for tuning).

    build/testenv/bin/python scripts/qa/ring_feel.py 40
    build/testenv/bin/python scripts/qa/ring_feel.py 40 --upgrades
    build/testenv/bin/python scripts/qa/ring_feel.py 40 KICK=34 Bolt.move.speed=80
"""
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import lupa  # noqa: E402
from lua_modules import load_battle  # noqa: E402

RUN = """
return function(sim, seed, a, b)
  local s = sim.newRound(seed, a, b)
  local clashes, closes, blocks, saves, first, serial = 0, 0, 0, 0, 0, 0
  local firstAt
  while not s.finished do
    sim.step(s, sim.FIXED_DT)
    for _, e in ipairs(s.events) do
      if e.serial > serial then
        serial = e.serial
        if e.kind == 'clash' then
          clashes = clashes + 1
          if first == 0 and not e.even then first = e.actor; firstAt = e.at end
        elseif e.kind == 'close' then closes = closes + 1
        elseif e.kind == 'blocked' then blocks = blocks + 1
        elseif e.kind == 'revive' then saves = saves + 1 end
      end
    end
  end
  return s.winner, s.elapsed, clashes, closes, first, s.reason, firstAt or -1
end
"""


def main():
    args = sys.argv[1:]
    seeds = int(next((a for a in args if a.isdigit()), 24))
    upgrades = '--upgrades' in args
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    sim, skills, catalog = load_battle(lua)
    for arg in args:
        if '=' not in arg:
            continue
        name, value = arg.split('=')
        if '.' in name:
            parts = name.split('.')
            table = skills.offence[parts[0]] or skills.wild[parts[0]]
            for part in parts[1:-1]:
                table = table[part]
            table[parts[-1]] = float(value)
        else:
            sim[name] = float(value)
    run = lua.execute(RUN)
    tops = [e.id for e in catalog.all('offence').values()]
    wilds = [e.id for e in catalog.all('wild').values()]

    def build(top, *cards):
        return lua.table_from({'offenceId': top, 'wildIds': lua.table_from(list(cards))})

    lengths, clashes, closes, first_wins, first_total, draws, timeouts, rounds, ringouts = [], [], [], 0, 0, 0, 0, 0, 0
    score = {t: [0.0, 0] for t in tops}
    pair = {}
    for a in tops:
        for b in tops:
            wins = 0.0
            for n in range(seeds):
                seed = 1000 + n * 7919 + tops.index(a) * 131 + tops.index(b) * 17
                winner, elapsed, c, cl, first, reason, _ = run(sim, seed, build(a), build(b))
                rounds += 1
                lengths.append(elapsed); clashes.append(c); closes.append(cl)
                draws += winner == 0; timeouts += reason == 'timeout'; ringouts += reason == 'ringout'
                if first and winner:
                    first_total += 1; first_wins += first == winner
                points = 0.5 if winner == 0 else (1.0 if winner == 1 else 0.0)
                wins += points
                score[a][0] += points; score[a][1] += 1
                score[b][0] += 1 - points; score[b][1] += 1
            pair[(a, b)] = wins / seeds
    lengths.sort()
    print(f"{rounds} rounds · length median {statistics.median(lengths):.1f}s  p10 {lengths[len(lengths)//10]:.1f}s  p90 {lengths[len(lengths)*9//10]:.1f}s")
    print(f"touches per round {statistics.mean(clashes):.1f} · close calls per round {statistics.mean(closes):.2f} · "
          f"draws {100*draws/rounds:.1f}% · decided by the clock {100*timeouts/rounds:.1f}%")
    print(f"knocked out through a gap {100*ringouts/rounds:.0f}% · out-spun {100*(rounds-ringouts-timeouts)/rounds:.0f}%")
    print(f"the top that wins the first touch wins the round {100*first_wins/max(1,first_total):.0f}%")
    print("field score: " + "  ".join(f"{t} {100*s[0]/s[1]:.0f}%" for t, s in score.items()))
    print("left seat's score against each rival:")
    for a in tops:
        print(f"  {a:8}" + "  ".join(f"{b} {100*pair[(a,b)]:.0f}" for b in tops))
    if upgrades:
        print("one upgrade against a bare top, both seats:")
        for w in wilds:
            total, count = 0.0, 0
            for a in tops:
                for b in tops:
                    for n in range(max(4, seeds // 3)):
                        seed = 5000 + n * 104729 + tops.index(a) * 31 + tops.index(b) * 7
                        winner = run(sim, seed, build(a, w), build(b))[0]
                        total += 0.5 if winner == 0 else (1.0 if winner == 1 else 0.0)
                        winner = run(sim, seed, build(b), build(a, w))[0]
                        total += 0.5 if winner == 0 else (1.0 if winner == 2 else 0.0)
                        count += 2
            print(f"  {w:8} {100*total/count:.0f}%")


if __name__ == '__main__':
    main()
