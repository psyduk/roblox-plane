"""Load pure shared modules for the optional Lupa-based offline test tools."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_simulation(runtime, path=None):
    catalog = runtime.execute((ROOT / 'src/shared/PlaneCatalog.luau').read_text())
    powers = runtime.execute((ROOT / 'src/shared/PowerCatalog.luau').read_text())
    shared = runtime.table_from({'PlaneCatalog': runtime.table_from({'module': catalog}),
                                 'PowerCatalog': runtime.table_from({'module': powers})})
    saved_script, saved_require = runtime.globals().script, runtime.globals().require
    runtime.globals().script = runtime.table_from({'Parent': shared})
    runtime.globals().require = runtime.eval('function(module) return module.module end')
    try:
        simulation = runtime.execute((path or ROOT / 'src/shared/Simulation.luau').read_text())
    finally:
        runtime.globals().script, runtime.globals().require = saved_script, saved_require
    return simulation, catalog


def load_battle(runtime, path=None):
    """Return (BattleSimulation, BattleSkills, SkillCatalog).

    `path` loads another copy of BattleSimulation, such as a saved baseline; it
    is given the current BattleSkills if it asks for them.
    """
    skills = runtime.execute((ROOT / 'src/shared/BattleSkills.luau').read_text())
    catalog = runtime.execute((ROOT / 'src/shared/SkillCatalog.luau').read_text())
    shared = runtime.table_from({'BattleSkills': runtime.table_from({'module': skills})})
    saved_script, saved_require = runtime.globals().script, runtime.globals().require
    runtime.globals().script = runtime.table_from({'Parent': shared})
    runtime.globals().require = runtime.eval('function(module) return module.module end')
    try:
        simulation = runtime.execute((path or ROOT / 'src/shared/BattleSimulation.luau').read_text())
    finally:
        runtime.globals().script, runtime.globals().require = saved_script, saved_require
    return simulation, skills, catalog
