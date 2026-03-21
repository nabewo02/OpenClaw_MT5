# Tokyo 9:55 USDJPY Micro EA Findings (2026-03)

## Scope

- 対象: USDJPY
- データ: 10年分の M1 CSV
- 実装形: M1 OHLC + tick volume による proxy 版
- サーバー時刻前提:
  - 冬時間: GMT+2
  - 夏時間: GMT+3（米国DST連動）
- 東京 09:55 JST を
  - 冬時間 02:55
  - 夏時間 03:55
 へ変換して検証

## Critical Limitation

元アイデアは本来、BBO / ミッド / 秒単位のテープ変化を前提としています。

今回の検証で使えるのは以下のみです。

- M1 OHLC
- tick volume
- CSV上の簡略 spread 情報

したがって、今回の結果は **proxy 検証** であり、元アイデアの完全再現ではありません。

## Prompt-like Strict Settings

近い条件:

- `MinVolumeBurstZ = 2.0`
- `TakeATRMult = 0.6`
- `StopATRMult = 0.35`
- `MinDriftATR = 0.4`

結果:

- continuation
  - 20 trades
  - win rate 10.00%
  - PF 0.0515
  - net -40.42R
  - positive years 0/6

- reversal
  - 13 trades
  - win rate 7.69%
  - PF 0.0117
  - net -22.28R
  - positive years 1/7

- auto
  - 33 trades
  - win rate 9.09%
  - PF 0.0377
  - net -62.69R
  - positive years 1/9

所見:

- かなり厳格な元ルールに近づけると、M1 proxy ではほぼ機会が出ません
- 出ても期待値は強くマイナスです

## Looser Sensitivity Checks

かなり緩めた条件でも改善しませんでした。

### Example: looser continuation / reversal / auto

- `MinVolumeBurstZ = 0.0`
- `TakeATRMult = 1.2`
- `StopATRMult = 0.45`
- `MinDriftATR = 0.0`

結果:

- continuation
  - 42 trades
  - PF 0.1263
  - net -76.60R
  - positive years 0/10

- reversal
  - 15 trades
  - PF 0.1469
  - net -22.49R
  - positive years 1/7

- auto
  - 57 trades
  - PF 0.1311
  - net -99.09R
  - positive years 0/10

## Conclusion

今回のデータと proxy 実装では、このアイデアは **頑健な standalone EA としては成立を確認できませんでした**。

理由:

- 秒単位の flow / tape 変化を M1 で再現しきれない
- BBO / mid ベースの優位性が、OHLC 化で薄れる可能性が高い
- スプレッドと約定の影響を受けやすい超短期戦略である

## Practical Interpretation

- MT5での proxy 実装自体は可能
- ただし、現状の M1 データでは優位性確認に失敗
- 本気で続けるなら、次に必要なのは
  - tick / BBO に近いデータ
  - サーバー時刻の厳密確認
  - 秒単位の執行再現
 です

## Status

- 実装: 完了
- コンパイル: 実施予定
- 採用判断: 現時点では見送り
