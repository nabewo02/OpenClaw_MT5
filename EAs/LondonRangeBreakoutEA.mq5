#property strict
#property version   "1.00"
#property description "London session breakout EA based on Asia range"

#include <Trade/Trade.mqh>

CTrade trade;

input ENUM_TIMEFRAMES InpSignalTF = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;
input int AsiaSessionStartHour = 0;
input int AsiaSessionEndHour = 8;
input int LondonSessionStartHour = 8;
input int LondonSessionEndHour = 16;
input int ATRPeriod = 14;
input double MinATRPoints = 80.0;
input double StopATRMult = 1.3;
input double TakeATRMult = 2.0;
input int FastMAPeriod = 20;
input int SlowMAPeriod = 50;
input double MaxSpreadPoints = 25.0;
input double RiskPercent = 1.0;
input int MaxTradesPerDay = 1;
input bool OnePositionPerSymbol = true;
input ulong MagicNumber = 26031801;

int atrHandle = INVALID_HANDLE;
int fastMaHandle = INVALID_HANDLE;
int slowMaHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int tradesToday = 0;
int trackedDay = -1;

int OnInit()
{
   atrHandle = iATR(_Symbol, InpSignalTF, ATRPeriod);
   fastMaHandle = iMA(_Symbol, InpTrendTF, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMaHandle = iMA(_Symbol, InpTrendTF, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || fastMaHandle == INVALID_HANDLE || slowMaHandle == INVALID_HANDLE)
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
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(fastMaHandle != INVALID_HANDLE) IndicatorRelease(fastMaHandle);
   if(slowMaHandle != INVALID_HANDLE) IndicatorRelease(slowMaHandle);
}

void OnTick()
{
   ResetDailyCounterIfNeeded();

   datetime currentBar = iTime(_Symbol, InpSignalTF, 0);
   if(currentBar == 0 || currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   if(!IsTradingWindow())
      return;

   if(tradesToday >= MaxTradesPerDay)
      return;

   if(OnePositionPerSymbol && PositionSelect(_Symbol))
      return;

   if(GetSpreadPoints() > MaxSpreadPoints)
      return;

   double atrPoints = GetATRPoints();
   if(atrPoints <= 0 || atrPoints < MinATRPoints)
      return;

   double asiaHigh = 0.0;
   double asiaLow = 0.0;
   if(!GetAsiaRange(asiaHigh, asiaLow))
      return;

   double prevClose = iClose(_Symbol, InpSignalTF, 1);
   double prevHigh = iHigh(_Symbol, InpSignalTF, 1);
   double prevLow = iLow(_Symbol, InpSignalTF, 1);

   bool upTrend = IsTrendUp();
   bool downTrend = IsTrendDown();

   bool buySignal = upTrend && prevClose > asiaHigh && prevHigh > asiaHigh;
   bool sellSignal = downTrend && prevClose < asiaLow && prevLow < asiaLow;

   if(buySignal)
      OpenPosition(ORDER_TYPE_BUY, atrPoints);
   else if(sellSignal)
      OpenPosition(ORDER_TYPE_SELL, atrPoints);
}

bool IsTradingWindow()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= LondonSessionStartHour && dt.hour < LondonSessionEndHour);
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

bool GetAsiaRange(double &asiaHigh, double &asiaLow)
{
   asiaHigh = -DBL_MAX;
   asiaLow = DBL_MAX;

   int bars = Bars(_Symbol, InpSignalTF);
   if(bars <= 0)
      return false;

   for(int i = 1; i < bars; i++)
   {
      datetime t = iTime(_Symbol, InpSignalTF, i);
      if(t == 0)
         continue;

      MqlDateTime dt;
      TimeToStruct(t, dt);

      if(dt.hour >= AsiaSessionStartHour && dt.hour < AsiaSessionEndHour)
      {
         double high = iHigh(_Symbol, InpSignalTF, i);
         double low = iLow(_Symbol, InpSignalTF, i);
         if(high > asiaHigh) asiaHigh = high;
         if(low < asiaLow) asiaLow = low;
      }
      else if(dt.hour < AsiaSessionStartHour)
      {
         break;
      }
   }

   if(asiaHigh == -DBL_MAX || asiaLow == DBL_MAX)
      return false;

   return true;
}

double GetATRPoints()
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, buffer) <= 0)
      return -1.0;
   return buffer[0] / _Point;
}

bool IsTrendUp()
{
   double fast = GetIndicatorValue(fastMaHandle);
   double slow = GetIndicatorValue(slowMaHandle);
   return (fast > slow && fast > 0 && slow > 0);
}

bool IsTrendDown()
{
   double fast = GetIndicatorValue(fastMaHandle);
   double slow = GetIndicatorValue(slowMaHandle);
   return (fast < slow && fast > 0 && slow > 0);
}

double GetIndicatorValue(int handle)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, 1, 1, buffer) <= 0)
      return -1.0;
   return buffer[0];
}

double GetSpreadPoints()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / _Point;
}

double CalculateVolume(double stopPoints)
{
   if(stopPoints <= 0)
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

   double pointValuePerLot = tickValue * (_Point / tickSize);
   if(pointValuePerLot <= 0)
      return minVolume;

   double rawVolume = riskMoney / (stopPoints * pointValuePerLot);
   double stepped = MathFloor(rawVolume / volumeStep) * volumeStep;
   double volume = MathMax(minVolume, MathMin(maxVolume, stepped));
   return NormalizeDouble(volume, 2);
}

void OpenPosition(ENUM_ORDER_TYPE orderType, double atrPoints)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;

   double stopPoints = atrPoints * StopATRMult;
   double takePoints = atrPoints * TakeATRMult;
   double volume = CalculateVolume(stopPoints);

   if(volume <= 0)
      return;

   double sl = 0.0;
   double tp = 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - stopPoints * _Point;
      tp = price + takePoints * _Point;
      if(trade.Buy(volume, _Symbol, price, sl, tp, "London breakout buy"))
         tradesToday++;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = price + stopPoints * _Point;
      tp = price - takePoints * _Point;
      if(trade.Sell(volume, _Symbol, price, sl, tp, "London breakout sell"))
         tradesToday++;
   }
}
