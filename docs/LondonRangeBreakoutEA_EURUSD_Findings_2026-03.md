# London Range Breakout EA - EURUSD Findings (2026-03)

## Scope

- 対象: EURUSD
- ロジック: London Range Breakout EA
- 期間: 10年分の M1 CSV
- 位置づけ: 一次の再現検証

注意:

- これは MT5 ストラテジーテスター本番の最終結果ではなく、CSV直読みでロジックを再現した一次スクリーニングです
- 実運用判断には、MT5 テスター本番とブローカー条件の確認が必須です

## Baseline

基準条件:

- `MinATRPoints = 80`
- `StopATRMult = 1.3`
- `TakeATRMult = 2.0`
- ロンドン時間: 8-16

結果:

- `base_spread0`
  - Trades: 1099
  - Win rate: 43.95%
  - PF: 1.2183
  - Net: +16696.24 pt

- `base_spread8`
  - Trades: 1099
  - Win rate: 43.95%
  - PF: 1.0418
  - Net: +3508.24 pt

- `base_spread12`
  - Trades: 1099
  - Win rate: 43.95%
  - PF: 0.9648
  - Net: -3085.76 pt

## Parameter Sensitivity

### Smaller take profit

- `take15_spread8`
  - Trades: 1100
  - Win rate: 50.18%
  - PF: 0.9936
  - Net: -472.16 pt

解釈:

- 利確を近づけると勝率は上がる
- ただしコストを吸収しきれず、利益が残りにくい

### Larger take profit

- `take25_spread8`
  - Trades: 1099
  - Win rate: 38.49%
  - PF: 1.0439
  - Net: +4054.95 pt

解釈:

- 勝率は下がる
- ただし利幅を伸ばす方が、このロジックにはまだ合っている可能性がある

### Lower ATR filter

- `minatr60_spread8`
  - Trades: 1491
  - Win rate: 40.24%
  - PF: 0.9051
  - Net: -9656.86 pt

解釈:

- 低ボラ局面まで拾いにいくと大きく悪化
- `MinATRPoints` は安易に下げない方がよい

### Higher ATR filter

- `minatr100_spread8`
  - Trades: 674
  - Win rate: 43.18%
  - PF: 1.0404
  - Net: +2471.03 pt

解釈:

- 取引数は減る
- ただし期待値維持には一定の意味がある

### Shorter London window

- `london14_spread8`
  - Trades: 879
  - Win rate: 44.48%
  - PF: 1.0801
  - Net: +5188.06 pt

解釈:

- ロンドン後半を切ることで改善
- 前半の値動きに絞る方が有利な可能性がある

## Main Takeaways

今回の一次検証から見える要点は次のとおりです。

- EURUSD は London Range Breakout の本命候補
- スプレッド感度が高い
- 0.8 pips 前提ではまだ残るが、1.2 pips 前提では崩れる
- ATR フィルタを弱めると悪化しやすい
- ロンドン時間は 14時までへ短縮する案が有力
- 利確倍率は 2.0〜2.5 の範囲で再検証価値がある

## Current Working Candidate

暫定の候補条件:

- Symbol: EURUSD
- `MinATRPoints = 80`
- `StopATRMult = 1.3`
- `TakeATRMult = 2.0 ~ 2.5`
- `LondonSessionStartHour = 8`
- `LondonSessionEndHour = 14`
- スプレッドは厳格管理

## Next Validation Steps

- MT5 ストラテジーテスター本番での再検証
- ブローカー時間の確認
- 変動スプレッド前提での評価
- 年別成績の分解
- ニュース時間帯除外の有無比較
- EURUSD / USDJPY の横比較
