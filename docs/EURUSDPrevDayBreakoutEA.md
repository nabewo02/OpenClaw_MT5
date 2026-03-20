# EURUSD Previous Day Breakout EA

## Overview

EURUSDPrevDayBreakoutEA は、EURUSD 向けに絞った前日高値・安値ブレイクEAです。

## Logic

- 前営業日の高値 / 安値を取得
- 完成済み H1 EMA20 / EMA50 で方向を限定
- M15 終値で前日高値 / 安値をブレイクしたらエントリー
- ATR ストップ / ATR ターゲットを設定
- 1 日 1 回まで

## Default Parameters

- `TradeStartHour = 7`
- `TradeEndHour = 18`
- `MinATRPoints = 100`
- `StopATRMult = 1.2`
- `TakeATRMult = 1.9`
- `MaxSpreadPoints = 15`

## Notes

- 今回の一次検証では、EURUSD では強いエッジというより薄い優位性でした
- 高ボラ日へ絞ったときにのみ候補として残っています
- 実運用前には、コスト条件と年別成績の確認が必須です
