# WMR Fix Fade EA

## Overview

WMRFixFadeEA は、WM/Reuters 16:00 London fix まわりの短期フロー偏位に対して、fix 後の均衡回帰を狙うEAです。

基本発想:

- 15:57:30〜16:02:30 の WMR 計算窓で価格が一方向へ偏る
- その偏位が十分大きく、かつ tick 活性が高い日に限定
- fix 窓終了直後に逆張りで入り、短時間の戻しを取る

## Important Notes

- このEAは tick ベース proxy 実装です
- 研究では Dukascopy tick を使って検証しています
- M1 データだけでは再現しきれないため、tick ベースで扱う前提です

## Default Parameters

- `FixHourWinterServer = 16`
- `FixHourSummerServer = 15`
- `MoveThresholdBps = 4.0`
- `RetraceRatio = 0.5`
- `StopRatio = 0.75`
- `MaxSpreadMultiplier = 1.5`
- `MinTickRateRatio = 1.3`
- `MinPreTicks = 100`
- `MinFixTicks = 20`
- `TimeoutMinutes = 8`

上記の時刻デフォルトは **UTC サーバー前提** です。ブローカーサーバー時刻に応じて調整してください。

## Logic

### Pre-fix window

- 15:30:00 〜 15:57:30 London
- ここで
  - 事前 mid
  - spread の中央値
  - pre-fix tick 数
  を集計

### Fix window

- 15:57:30 〜 16:02:30 London
- fix 終了時点の mid と tick 数を記録

### Entry filters

- 現在 spread <= pre-fix median spread × `MaxSpreadMultiplier`
- fix 窓の tick rate / pre 窓の tick rate >= `MinTickRateRatio`
- fix 窓での move >= `MoveThresholdBps`

### Entry direction

- fix 窓で上に大きく動いたら売り
- fix 窓で下に大きく動いたら買い

### Exit

- target: fix move の `RetraceRatio` 分だけ戻す
- stop: fix move × `StopRatio`
- time exit: `TimeoutMinutes`

## Intended Use

- 最有力は EURUSD
- USDJPY は secondary candidate
- GBPUSD は現時点では非推奨
