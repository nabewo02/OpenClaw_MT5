#property strict
#property version   "1.00"
#property description "EURUSD previous-day breakout continuation EA"

input ENUM_TIMEFRAMES InpSignalTF = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;
input int TradeStartHour = 7;
input int TradeEndHour = 18;
input int ATRPeriod = 14;
input double MinATRPoints = 100.0;
input double StopATRMult = 1.2;
input double TakeATRMult = 1.9;
input int FastMAPeriod = 20;
input int SlowMAPeriod = 50;
input double MaxSpreadPoints = 15.0;
input double RiskPercent = 1.0;
input int MaxTradesPerDay = 1;
input bool OnePositionPerSymbol = true;
input ulong MagicNumber = 26032003;

int atrHandle = INVALID_HANDLE;
int fastMaHandle = INVALID_HANDLE;
int slowMaHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int tradesToday = 0;
int trackedDateCode = -1;

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

   double atrPrice = GetATRPrice(1);
   double atrPoints = atrPrice / _Point;
   if(atrPrice <= 0 || atrPoints < MinATRPoints)
      return;

   double prevDayHigh = 0.0;
   double prevDayLow = 0.0;
   if(!GetPreviousTradingDayRange(prevDayHigh, prevDayLow))
      return;

   double close1 = iClose(_Symbol, InpSignalTF, 1);
   double high1 = iHigh(_Symbol, InpSignalTF, 1);
   double low1 = iLow(_Symbol, InpSignalTF, 1);

   bool upTrend = IsTrendUp();
   bool downTrend = IsTrendDown();

   if(upTrend && close1 > prevDayHigh && high1 > prevDayHigh)
      OpenPosition(ORDER_TYPE_BUY, atrPrice, "EURUSD prev-day breakout buy");
   else if(downTrend && close1 < prevDayLow && low1 < prevDayLow)
      OpenPosition(ORDER_TYPE_SELL, atrPrice, "EURUSD prev-day breakout sell");
}

bool IsTradingWindow()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= TradeStartHour && dt.hour < TradeEndHour);
}

void ResetDailyCounterIfNeeded()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dateCode = dt.year * 1000 + dt.day_of_year;
   if(dateCode != trackedDateCode)
   {
      trackedDateCode = dateCode;
      tradesToday = 0;
   }
}

double GetIndicatorValue(int handle, int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) <= 0)
      return -1.0;
   return buffer[0];
}

double GetATRPrice(int shift)
{
   return GetIndicatorValue(atrHandle, shift);
}

bool IsTrendUp()
{
   double fast = GetIndicatorValue(fastMaHandle, 1);
   double slow = GetIndicatorValue(slowMaHandle, 1);
   return (fast > slow && fast > 0 && slow > 0);
}

bool IsTrendDown()
{
   double fast = GetIndicatorValue(fastMaHandle, 1);
   double slow = GetIndicatorValue(slowMaHandle, 1);
   return (fast < slow && fast > 0 && slow > 0);
}

double GetSpreadPoints()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
}

bool GetPreviousTradingDayRange(double &dayHigh, double &dayLow)
{
   datetime refTime = iTime(_Symbol, InpSignalTF, 1);
   if(refTime == 0)
      return false;

   MqlDateTime ref;
   TimeToStruct(refTime, ref);

   int bars = Bars(_Symbol, InpSignalTF);
   bool targetFound = false;
   int targetYear = 0, targetMonth = 0, targetDay = 0;
   dayHigh = -DBL_MAX;
   dayLow = DBL_MAX;

   for(int i = 1; i < bars; i++)
   {
      datetime t = iTime(_Symbol, InpSignalTF, i);
      if(t == 0)
         continue;

      MqlDateTime dt;
      TimeToStruct(t, dt);

      bool sameCurrentDay = (dt.year == ref.year && dt.mon == ref.mon && dt.day == ref.day);
      if(!targetFound)
      {
         if(sameCurrentDay)
            continue;

         targetFound = true;
         targetYear = dt.year;
         targetMonth = dt.mon;
         targetDay = dt.day;
      }

      bool sameTargetDay = (dt.year == targetYear && dt.mon == targetMonth && dt.day == targetDay);
      if(!sameTargetDay)
         break;

      double high = iHigh(_Symbol, InpSignalTF, i);
      double low = iLow(_Symbol, InpSignalTF, i);
      if(high > dayHigh) dayHigh = high;
      if(low < dayLow) dayLow = low;
   }

   return (targetFound && dayHigh != -DBL_MAX && dayLow != DBL_MAX);
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
   return NormalizeDouble(MathMax(minVolume, MathMin(maxVolume, stepped)), 2);
}

bool SendMarketOrder(ENUM_ORDER_TYPE orderType, double volume, double price, double sl, double tp, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.magic = MagicNumber;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 20;
   request.type_filling = ORDER_FILLING_IOC;
   request.comment = comment;

   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
      return false;
   }

   return (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED);
}

void OpenPosition(ENUM_ORDER_TYPE orderType, double atrPrice, string comment)
{
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopDistance = atrPrice * StopATRMult;
   double takeDistance = atrPrice * TakeATRMult;
   double volume = CalculateVolume(stopDistance);
   if(volume <= 0)
      return;

   double sl = (orderType == ORDER_TYPE_BUY) ? price - stopDistance : price + stopDistance;
   double tp = (orderType == ORDER_TYPE_BUY) ? price + takeDistance : price - takeDistance;

   if(SendMarketOrder(orderType, volume, price, sl, tp, comment))
      tradesToday++;
}
