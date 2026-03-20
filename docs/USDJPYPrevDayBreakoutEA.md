# USDJPY Previous Day Breakout EA

## Overview

USDJPYPrevDayBreakoutEA は、前日高値・安値のブレイクを H1 トレンド方向に限定して追うEAです。

## Logic

- 前営業日の高値 / 安値を取得
- 完成済み H1 EMA20 / EMA50 で上位方向を判定
- M15 終値で前日高値 / 安値をブレイクしたら順張り
- ATR ストップ / ATR ターゲットを設定
- 1 日 1 回まで

## Default Parameters

- `TradeStartHour = 7`
- `TradeEndHour = 16`
- `MinATRPoints = 100`
- `StopATRMult = 1.2`
- `TakeATRMult = 2.4`

## Notes

- 今回の別案スキャンでは、USDJPY で secondary candidate として残りました
- ロンドン寄りから欧州前半までに絞る設計です
- 低ボラ日を切るために、ATR フィルタは強めです
