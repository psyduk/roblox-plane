"""Run the actual pure Lua modules and optionally print a deterministic aim sweep.

Usage: python3 scripts/test_peg_sim.py [--sweep]
Requires the optional test dependency lupa. No Roblox services are mocked.
"""
from pathlib import Path
import argparse
import statistics

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def load_modules(runtime):
    powers = runtime.execute((ROOT / "src/shared/PegPowers.luau").read_text())
    runtime.globals().script = runtime.table_from({
        "Parent": runtime.table_from({"PegPowers": powers})
    })
    runtime.globals().require = runtime.eval("function(value) return value end")
    simulation = runtime.execute((ROOT / "src/shared/PegSimulation.luau").read_text())
    return simulation, powers


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sweep", action="store_true")
    args = parser.parse_args()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    simulation, powers = load_modules(runtime)
    for name, module in (("PegPowers", powers), ("PegSimulation", simulation)):
        test = runtime.execute((ROOT / f"tests/{name}.spec.luau").read_text())
        print(test(module))
    if args.sweep:
        play = runtime.eval("""function(Sim, seed, angle, powerId)
            local board = Sim.makeBoard(seed)
            local state = Sim.newShot(board, {angle=angle, powerId=powerId})
            while not state.done do Sim.step(state, board, 1/30) end
            return state
        end""")
        for power_id in ("pulse", "split", "return"):
            states = [(angle, play(simulation, 49351, angle, power_id)) for angle in range(-65, 66)]
            durations = sorted(state.elapsed for _, state in states)
            activated = [(angle, state) for angle, state in states if state.powerUsed]
            print(f"{power_id}: n={len(states)}, median={statistics.median(durations):.2f}s, "
                  f"p90={durations[int(len(durations)*.9)]:.2f}s, max={max(durations):.2f}s, "
                  f"power={len(activated)}/{len(states)}, "
                  f"timeouts={sum(s.finishReason == 'time limit' for _, s in states)}, "
                  f"median hits={statistics.median(s.hitCount for _, s in states):g}")
            best = sorted(states, key=lambda pair: pair[1].score, reverse=True)[:5]
            print("  best:", "; ".join(f"{angle}deg={state.score:,} ({state.elapsed:.1f}s, {state.hitCount} hits)" for angle, state in best))
            print("  activating angles:", ", ".join(str(angle) for angle, _ in activated))


if __name__ == "__main__":
    main()
