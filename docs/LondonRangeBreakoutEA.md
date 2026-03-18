# London Range Breakout EA

## Overview

London Range Breakout EA は、FX市場で比較的再現しやすい時間帯効果を使った順張り型EAです。

発想はシンプルです。

- アジア時間は比較的レンジになりやすい
- ロンドン勢参加後はボラティリティが拡大しやすい
- そのため、アジアレンジの明確な上抜け/下抜けにエッジ候補がある

ただし、単なる高値抜け・安値抜けではダマシが多いため、以下のガードを入れています。

- ATR最小値フィルタ
- H1トレンドフィルタ
- 最大スプレッド制限
- 1日あたり取引回数制限
- 取引時間帯制限

## Intended Market

- 主対象: EURUSD, GBPUSD, USDJPY
- 推奨時間足: M15
- 想定用途: 研究・バックテスト・改良のベース

## Entry Logic

### Buy

- アジア時間レンジ高値を、確定足終値で上抜け
- その時点で H1 の EMA Fast > EMA Slow
- 現在スプレッドが許容内
- 現在ATRが最小閾値以上
- ロンドン取引時間内
- 当日の最大取引回数未満

### Sell

- アジア時間レンジ安値を、確定足終値で下抜け
- その時点で H1 の EMA Fast < EMA Slow
- 現在スプレッドが許容内
- 現在ATRが最小閾値以上
- ロンドン取引時間内
- 当日の最大取引回数未満

## Exit Logic

- 損切り: ATR × `StopATRMult`
- 利確: ATR × `TakeATRMult`
- 任意で建値移動やトレーリングを後付け可能

## Core Parameters

- `AsiaSessionStartHour` / `AsiaSessionEndHour`
- `LondonSessionStartHour` / `LondonSessionEndHour`
- `ATRPeriod`
- `MinATRPoints`
- `StopATRMult`
- `TakeATRMult`
- `TrendTF`
- `FastMAPeriod`
- `SlowMAPeriod`
- `MaxSpreadPoints`
- `RiskPercent`
- `MaxTradesPerDay`

## Why This Design

このEAを最初の実装に選んだ理由は以下です。

- MT5標準データで組みやすい
- 外部ファンダメンタルデータへの依存が少ない
- ロジックが明確で、改善点を切り出しやすい
- エッジの有無だけでなく、実装品質の差が出やすい

## Major Risks

- 指標発表時のダマシブレイク
- ボラティリティ不足の日の無理なエントリー
- セッション時刻のブローカーサーバー時間依存
- 低流動時間のスプレッド急拡大

## Backtest Checklist

- まずは単一ペアで検証
- 次に複数年データで確認
- 次に複数ペアへ展開
- パラメータを少しずつずらして頑健性確認
- スプレッド条件を変えて脆弱性確認
- 年ごとの損益ばらつきを確認

## Suggested Next Improvements

- ニュースフィルタの追加
- 部分利確
- 建値移動
- トレーリングストップ
- 日次損失制限
- 通貨相関を見た同時保有制御
