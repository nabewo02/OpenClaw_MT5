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

## Initial Findings

一次検証では、まず London Range Breakout を3通貨で比較しました。

暫定所見:

- EURUSD が最も有望
- USDJPY は次点
- GBPUSD は優先度を下げる判断

また、EURUSD に対して追加の感度検証を行った結果、次の特徴が見えています。

- コスト感度が高い
- ATR フィルタを弱めると悪化しやすい
- ロンドン時間を長く取りすぎるより、前半へ絞る方が改善の余地がある
- 利確を小さくしすぎると、勝率は上がっても利益が残りにくい

## Current Working Hypothesis

現時点の暫定採用案は以下です。

- 対象: EURUSD
- `MinATRPoints`: 80 以上を維持
- ロンドン時間: 8時開始、終了は 14時案を優先検討
- 利確倍率: 2.0〜2.5 を優先検討
- スプレッド: 厳格管理必須

特に重要なのは、スプレッド条件の悪化で成績が崩れやすいことです。

このEAは「強い万能型エッジ」というより、
**執行条件が良いときにのみ残りやすい薄いエッジを丁寧に守る設計**
として扱うべきです。

## Major Risks

- 指標発表時のダマシブレイク
- ボラティリティ不足の日の無理なエントリー
- セッション時刻のブローカーサーバー時間依存
- 低流動時間のスプレッド急拡大
- ブローカー条件が悪い場合の期待値消失

## Backtest Checklist

- まずは単一ペアで検証
- 次に複数年データで確認
- 次に複数ペアへ展開
- パラメータを少しずつずらして頑健性確認
- スプレッド条件を変えて脆弱性確認
- 年ごとの損益ばらつきを確認
- CSV直読みの再現検証と MT5 テスター本番結果を分けて記録

## Suggested Next Improvements

- ニュースフィルタの追加
- 部分利確
- 建値移動
- トレーリングストップ
- 日次損失制限
- 通貨相関を見た同時保有制御
- ロンドン後半を切るセッション最適化
