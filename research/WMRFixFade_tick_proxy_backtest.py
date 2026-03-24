# Research helper copied from workspace-level validation.
# This file documents the strict tick-proxy test used to shortlist WMRFixFadeEA.
# Use Dukascopy tick data and run from the main workspace.

from pathlib import Path
import importlib.util

mod_path = Path('/root/.openclaw/workspace/wmr_fix_proxy_backtest.py')
spec = importlib.util.spec_from_file_location('wmrmod', mod_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

if __name__ == '__main__':
    cfg = {
        'move_bps': 4.0,
        'retrace_ratio': 0.5,
        'stop_ratio': 0.75,
        'entry_after_sec': 0,
        'timeout_min': 8,
        'spread_mult': 1.5,
        'tick_ratio_min': 1.3,
    }
    for pair in ['EURUSD', 'GBPUSD', 'USDJPY']:
        print(pair, mod.simulate_pair(pair, start_year=2020, end_year=2024, **cfg))
