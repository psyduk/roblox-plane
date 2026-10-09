"""Load pure shared modules for the optional Lupa-based offline test tools."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_simulation(runtime, path=None):
    catalog = runtime.execute((ROOT / 'src/shared/PlaneCatalog.luau').read_text())
    shared = runtime.table_from({'PlaneCatalog': runtime.table_from({'module': catalog})})
    saved_script, saved_require = runtime.globals().script, runtime.globals().require
    runtime.globals().script = runtime.table_from({'Parent': shared})
    runtime.globals().require = runtime.eval('function(module) return module.module end')
    try:
        simulation = runtime.execute((path or ROOT / 'src/shared/Simulation.luau').read_text())
    finally:
        runtime.globals().script, runtime.globals().require = saved_script, saved_require
    return simulation, catalog
