# WMR Fix Fade EA Findings (2026-03)

## Data / Method

- データ: Dukascopy tick
- 種別: tick proxy backtest
- 対象ウィンドウ:
  - pre-fix: 15:30:00〜15:57:30 London
  - fix: 15:57:30〜16:02:30 London
  - exit: fix 後 8 分以内

## Strict Candidate

検証で最も残った条件:

- `move_bps = 4.0`
- `retrace_ratio = 0.5`
- `stop_ratio = 0.75`
- `spread_mult = 1.5`
- `tick_rate_ratio_min = 1.3`

## Results

### EURUSD

- 2020-2023
  - 132 trades
  - win rate 61.36%
  - PF 1.2494
  - net +9.97R
  - positive years 3/4

- 2024
  - 22 trades
  - win rate 63.64%
  - PF 1.4688
  - net +2.65R
  - positive years 1/1

評価:

- 現時点で最も有望
- 高い活動日だけに絞れば残る可能性がある

### USDJPY

- 2020-2023
  - 111 trades
  - win rate 57.66%
  - PF 1.1066
  - net +3.48R
  - positive years 2/4

- 2024
  - 20 trades
  - win rate 65.00%
  - PF 1.3523
  - net +2.20R
  - positive years 1/1

評価:

- 薄くプラス
- EURUSD より優位性は弱いが、研究継続候補には入る

### GBPUSD

- 2020-2023
  - 220 trades
  - win rate 54.09%
  - PF 0.7953
  - net -17.57R
  - positive years 0/4

- 2024
  - 22 trades
  - win rate 27.27%
  - PF 0.2663
  - net -8.94R
  - positive years 0/1

評価:

- 明確に弱い
- 現時点では除外してよい

## Conclusion

- 採用候補: EURUSD
- 準候補: USDJPY
- 除外: GBPUSD

この戦略は、毎日打つ戦略ではなく

- fix 窓の偏位が大きい
- spread が悪化していない
- tick 活性が高い

という日だけを狙うイベント戦略として扱うのが妥当です。
