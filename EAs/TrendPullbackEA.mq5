#property strict
#property version   "1.00"
#property description "Trend pullback EA using higher timeframe EMA trend and lower timeframe pullback entry"

#include <Trade/Trade.mqh>

CTrade trade;

input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M15;
input int FastMAPeriod = 20;
input int SlowMAPeriod = 50;
input int EntryMAPeriod = 20;
input int ATRPeriod = 14;
input double StopATRMult = 1.2;
input double TakeATRMult = 2.2;
input double MaxSpreadPoints = 25.0;
input double RiskPercent = 1.0;
input int RSIEntryPeriod = 14;
input double BuyRSIMax = 45.0;
input double SellRSIMin = 55.0;
input bool OnePositionPerSymbol = true;
input int MaxTradesPerDay = 2;
input ulong MagicNumber = 26031802;

int fastTrendHandle = INVALID_HANDLE;
int slowTrendHandle = INVALID_HANDLE;
int entryMaHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int tradesToday = 0;
int trackedDay = -1;

int OnInit()
{
   fastTrendHandle = iMA(_Symbol, InpTrendTF, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowTrendHandle = iMA(_Symbol, InpTrendTF, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   entryMaHandle = iMA(_Symbol, InpEntryTF, EntryMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, InpEntryTF, ATRPeriod);
   rsiHandle = iRSI(_Symbol, InpEntryTF, RSIEntryPeriod, PRICE_CLOSE);

   if(fastTrendHandle == INVALID_HANDLE || slowTrendHandle == INVALID_HANDLE || entryMaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
   {
      Print("Indicator handle creation failed");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   ResetDailyCounterIfNeeded();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(fastTrendHandle != INVALID_HANDLE) IndicatorRelease(fastTrendHandle);
   if(slowTrendHandle != INVALID_HANDLE) IndicatorRelease(slowTrendHandle);
   if(entryMaHandle != INVALID_HANDLE) IndicatorRelease(entryMaHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
}

void OnTick()
{
   ResetDailyCounterIfNeeded();

   datetime currentBar = iTime(_Symbol, InpEntryTF, 0);
   if(currentBar == 0 || currentBar == lastBarTime)
      return;
   lastBarTime = currentBar;

   if(tradesToday >= MaxTradesPerDay)
      return;

   if(OnePositionPerSymbol && PositionSelect(_Symbol))
      return;

   if(GetSpreadPoints() > MaxSpreadPoints)
      return;

   double fastTrend = GetIndicatorValue(fastTrendHandle);
   double slowTrend = GetIndicatorValue(slowTrendHandle);
   double entryMA = GetIndicatorValue(entryMaHandle);
   double atrPrice = GetATRPrice();
   double rsi = GetIndicatorValue(rsiHandle);

   if(fastTrend <= 0 || slowTrend <= 0 || entryMA <= 0 || atrPrice <= 0 || rsi <= 0)
      return;

   double close1 = iClose(_Symbol, InpEntryTF, 1);
   double close2 = iClose(_Symbol, InpEntryTF, 2);
   double low1 = iLow(_Symbol, InpEntryTF, 1);
   double high1 = iHigh(_Symbol, InpEntryTF, 1);

   bool upTrend = fastTrend > slowTrend;
   bool downTrend = fastTrend < slowTrend;

   bool buyPullback = upTrend && low1 <= entryMA && close1 > entryMA && close2 <= close1 && rsi <= BuyRSIMax;
   bool sellPullback = downTrend && high1 >= entryMA && close1 < entryMA && close2 >= close1 && rsi >= SellRSIMin;

   if(buyPullback)
      OpenPosition(ORDER_TYPE_BUY, atrPrice);
   else if(sellPullback)
      OpenPosition(ORDER_TYPE_SELL, atrPrice);
}

void ResetDailyCounterIfNeeded()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day != trackedDay)
   {
      trackedDay = dt.day;
      tradesToday = 0;
   }
}

double GetIndicatorValue(int handle)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, 1, 1, buffer) <= 0)
      return -1.0;
   return buffer[0];
}

double GetATRPrice()
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, buffer) <= 0)
      return -1.0;
   return buffer[0];
}

double GetSpreadPoints()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / _Point;
}

double CalculateVolume(double stopDistancePrice)
{
   if(stopDistancePrice <= 0)
      return 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (RiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tickValue <= 0 || tickSize <= 0 || volumeStep <= 0)
      return minVolume;

   double moneyPerPriceUnitPerLot = tickValue / tickSize;
   if(moneyPerPriceUnitPerLot <= 0)
      return minVolume;

   double rawVolume = riskMoney / (stopDistancePrice * moneyPerPriceUnitPerLot);
   double stepped = MathFloor(rawVolume / volumeStep) * volumeStep;
   double volume = MathMax(minVolume, MathMin(maxVolume, stepped));
   return NormalizeDouble(volume, 2);
}

void OpenPosition(ENUM_ORDER_TYPE orderType, double atrPrice)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;

   double stopDistance = atrPrice * StopATRMult;
   double takeDistance = atrPrice * TakeATRMult;
   double volume = CalculateVolume(stopDistance);

   if(volume <= 0)
      return;

   double sl = 0.0;
   double tp = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - stopDistance;
      tp = price + takeDistance;
      if(trade.Buy(volume, _Symbol, price, sl, tp, "Trend pullback buy"))
         tradesToday++;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = price + stopDistance;
      tp = price - takeDistance;
      if(trade.Sell(volume, _Symbol, price, sl, tp, "Trend pullback sell"))
         tradesToday++;
   }
}
