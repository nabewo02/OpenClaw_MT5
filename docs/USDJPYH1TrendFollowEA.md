# USDJPY H1 Trend Follow EA

## Overview

USDJPYH1TrendFollowEA は、今回の別案スキャンで最も強かった USDJPY 向けの順張りEAです。

考え方:

- 完成済み H1 の EMA20 / EMA50 クロスを使って方向転換を検出
- 次の M15 でエントリー
- 利確は固定せず、反対クロスまたは ATR ストップで終了

## Intended Market

- 主対象: USDJPY
- トレンド足: H1
- 実行足: M15

## Default Parameters

- `FastMAPeriod = 20`
- `SlowMAPeriod = 50`
- `ATRPeriod = 14`
- `MinATRPoints = 40`
- `StopATRMult = 2.0`

## Notes

- 一次検証では、USDJPY でのみ比較的素直に残りました
- EURUSD / GBPUSD へそのまま転用する前提ではありません
- 反対クロスで手仕舞う設計のため、トレンド継続局面で利益を伸ばすことを狙っています
