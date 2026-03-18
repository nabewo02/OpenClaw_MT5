#property strict
#property version   "1.00"
#property description "Short-term mean reversion EA using Bollinger Bands, RSI, and ATR-based exits"

#include <Trade/Trade.mqh>

CTrade trade;

input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M15;
input int BollingerPeriod = 20;
input double BollingerDeviation = 2.5;
input int RSIPeriod = 14;
input double BuyRSIMax = 30.0;
input double SellRSIMin = 70.0;
input int ATRPeriod = 14;
input double StopATRMult = 1.0;
input double TakeATRMult = 1.2;
input double MaxSpreadPoints = 20.0;
input double MinATRPoints = 50.0;
input double MaxATRPoints = 250.0;
input double RiskPercent = 0.5;
input int MaxTradesPerDay = 2;
input bool OnePositionPerSymbol = true;
input int TradingStartHour = 1;
input int TradingEndHour = 21;
input ulong MagicNumber = 26031803;

int bandsHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int tradesToday = 0;
int trackedDay = -1;

int OnInit()
{
   bandsHandle = iBands(_Symbol, InpEntryTF, BollingerPeriod, 0, BollingerDeviation, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, InpEntryTF, RSIPeriod, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, InpEntryTF, ATRPeriod);

   if(bandsHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
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
   if(bandsHandle != INVALID_HANDLE) IndicatorRelease(bandsHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

void OnTick()
{
   ResetDailyCounterIfNeeded();

   datetime currentBar = iTime(_Symbol, InpEntryTF, 0);
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
   if(atrPoints <= 0 || atrPoints < MinATRPoints || atrPoints > MaxATRPoints)
      return;

   double upper = 0.0, middle = 0.0, lower = 0.0;
   if(!GetBands(upper, middle, lower))
      return;

   double rsi = GetRSI();
   if(rsi <= 0)
      return;

   double close1 = iClose(_Symbol, InpEntryTF, 1);
   double high1 = iHigh(_Symbol, InpEntryTF, 1);
   double low1 = iLow(_Symbol, InpEntryTF, 1);

   bool buySignal = low1 < lower && close1 > lower && rsi <= BuyRSIMax;
   bool sellSignal = high1 > upper && close1 < upper && rsi >= SellRSIMin;

   if(buySignal)
      OpenPosition(ORDER_TYPE_BUY, atrPoints);
   else if(sellSignal)
      OpenPosition(ORDER_TYPE_SELL, atrPoints);
}

bool IsTradingWindow()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= TradingStartHour && dt.hour < TradingEndHour);
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

double GetSpreadPoints()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / _Point;
}

double GetATRPoints()
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, buffer) <= 0)
      return -1.0;
   return buffer[0] / _Point;
}

double GetRSI()
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(rsiHandle, 0, 1, 1, buffer) <= 0)
      return -1.0;
   return buffer[0];
}

bool GetBands(double &upper, double &middle, double &lower)
{
   double upperBuf[], middleBuf[], lowerBuf[];
   ArraySetAsSeries(upperBuf, true);
   ArraySetAsSeries(middleBuf, true);
   ArraySetAsSeries(lowerBuf, true);

   if(CopyBuffer(bandsHandle, 0, 1, 1, upperBuf) <= 0) return false;
   if(CopyBuffer(bandsHandle, 1, 1, 1, middleBuf) <= 0) return false;
   if(CopyBuffer(bandsHandle, 2, 1, 1, lowerBuf) <= 0) return false;

   upper = upperBuf[0];
   middle = middleBuf[0];
   lower = lowerBuf[0];
   return true;
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
      if(trade.Buy(volume, _Symbol, price, sl, tp, "Mean reversion buy"))
         tradesToday++;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = price + stopPoints * _Point;
      tp = price - takePoints * _Point;
      if(trade.Sell(volume, _Symbol, price, sl, tp, "Mean reversion sell"))
         tradesToday++;
   }
}
