"""Offline checks for the ring-out battle (requires lupa).

    build/testenv/bin/python scripts/sample_battle.py --tests-only
    build/testenv/bin/python scripts/sample_battle.py --samples 50 --upgrades

--tests-only runs the pure simulation and catalog specs. Without it the specs
run first and then every top meets every top in both seats; --upgrades adds
each upgrade against a bare top. Results describe the simulation only: whether
people can follow a round, or enjoy one, is a playtest question.
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "scripts" / "qa"))
from lupa import LuaRuntime  # noqa: E402
from lua_modules import load_battle  # noqa: E402


def run_specs():
    runtime = LuaRuntime(unpack_returned_tuples=True)
    simulation, skills, catalog = load_battle(runtime)
    test = runtime.execute((ROOT / "tests/BattleSimulation.spec.luau").read_text())
    catalog_test = runtime.execute((ROOT / "tests/SkillCatalog.spec.luau").read_text())
    return [test(simulation, catalog, skills), catalog_test(catalog)]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tests-only", action="store_true")
    parser.add_argument("--samples", type=int, default=24, help="Seeds per ordered pairing")
    parser.add_argument("--upgrades", action="store_true", help="Also measure each upgrade against a bare top")
    args = parser.parse_args()
    if args.samples < 1:
        parser.error("--samples must be positive")
    for line in run_specs():
        print(line)
    if not args.tests_only:
        import ring_feel
        sys.argv = [sys.argv[0], str(args.samples)] + (["--upgrades"] if args.upgrades else [])
        ring_feel.main()
