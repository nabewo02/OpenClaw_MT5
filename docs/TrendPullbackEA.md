# Trend Pullback EA

## Overview

Trend Pullback EA は、中期トレンドに順方向で乗りつつ、短期的な押し目・戻り目で入るためのEAです。

考え方は以下です。

- 上位足でトレンド方向を定義する
- 下位足で一時的な逆行を待つ
- トレンド再開の気配が出たところで入る

単純なブレイクアウトより飛びつきになりにくく、トレンド日に比較的素直に機能しやすい設計です。

## Intended Market

- 主対象: EURUSD, GBPUSD, USDJPY, AUDUSD
- 推奨トレンド足: H1
- 推奨エントリー足: M15

## Entry Logic

### Trend Definition

- H1 の EMA Fast > EMA Slow で上昇トレンド
- H1 の EMA Fast < EMA Slow で下降トレンド

### Buy Setup

- 上位足が上昇トレンド
- M15 で価格が Entry EMA まで押す
- その足が EMA 上で引ける
- RSI が過熱ではなく、押し目水準にある

### Sell Setup

- 上位足が下降トレンド
- M15 で価格が Entry EMA まで戻す
- その足が EMA 下で引ける
- RSI が過熱ではなく、戻り売り水準にある

## Exit Logic

- 損切り: ATR × `StopATRMult`
- 利確: ATR × `TakeATRMult`

## Core Parameters

- `InpTrendTF`
- `InpEntryTF`
- `FastMAPeriod`
- `SlowMAPeriod`
- `EntryMAPeriod`
- `ATRPeriod`
- `StopATRMult`
- `TakeATRMult`
- `RSIEntryPeriod`
- `BuyRSIMax`
- `SellRSIMin`
- `MaxSpreadPoints`
- `RiskPercent`
- `MaxTradesPerDay`

## Why This Design

このEAは、FXで比較的再現しやすいモメンタム/トレンド継続の考え方を、MT5で扱いやすい形に落としたものです。

利点:
- 上位足と下位足の役割分担が明確
- 単純な順張りよりエントリー価格が改善しやすい
- 複数ペアへ展開しやすい

注意点:
- レンジ相場でダマシが増える
- フィルタを増やしすぎると取引が減る
- ブローカー時間やスプレッド条件で結果がぶれうる

## Suggested Improvements

- ADX 等でトレンド強度フィルタ追加
- 建値移動
- 分割利確
- ニュース回避
- 日次損失制限
- セッション制限
