# Tokyo 9:55 USDJPY Micro EA

## Overview

Tokyo955USDJPYMicroEA は、東京 9:55 JST Fix まわりのごく短時間のフロー偏りを、M1 データで近似実装した研究用EAです。

このEAは次を狙います。

- 09:45-09:54 の事前ドリフト
- ティックボリュームのバースト
- 09:55 の Fix バーでの継続または失敗反転
- エントリー後 8 分以内の短期決着

## Important Assumptions

- 元アイデアは BBO / ミッド / 秒足寄りの情報を前提としています
- 今回のEAは、利用可能な M1 OHLC と tick volume を使った近似版です
- そのため、厳密な同一戦略ではなく **MT5実装可能な proxy 版** です

## Server Time Handling

共有いただいたヒストリカルデータは、ブローカー系でよくある

- 冬時間: GMT+2
- 夏時間: GMT+3（米国DST連動）

の可能性を前提にしています。

デフォルトでは、東京 09:55 JST を以下へ変換します。

- 冬時間: 02:55 server time
- 夏時間: 03:55 server time

## Entry Logic

### Pre-fix window

- 直前 10 本の M1 でドリフトを計測
- 直前 60 分の tick volume と比較して volume burst z-score を計測
- 現在スプレッドが過大なら見送り

### Continuation

- 事前ドリフト方向に 09:55 バーが pre-fix range を終値で明確に抜ける
- 09:56 の始値で順張り

### Reversal

- 09:55 バーが pre-fix high/low を一度抜けるが、終値でレンジ内へ戻る
- 09:56 の始値で逆張り

### Exit

- TP = ATR(10, M1) × `TakeATRMult`
- SL = min(ATR(10, M1) × `StopATRMult`, 価格 × `HardPercentStop`)
- さらに `MaxHoldMinutes` で時間撤退

## Default Parameters

- `FixHourWinterServer = 2`
- `FixHourSummerServer = 3`
- `FixMinute = 55`
- `MinDriftATR = 0.4`
- `MinVolumeBurstZ = 2.0`
- `TakeATRMult = 0.6`
- `StopATRMult = 0.35`
- `MaxHoldMinutes = 8`
- `SignalMode = 0` (`auto`)

## Intended Use

- 研究用
- M1 データでの proxy テスト用
- 実運用前提の完成版ではない
