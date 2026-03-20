#property strict
#property version   "1.00"
#property description "USDJPY H1 EMA crossover trend-following EA"

input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;
input int FastMAPeriod = 20;
input int SlowMAPeriod = 50;
input int ATRPeriod = 14;
input double MinATRPoints = 40.0;
input double StopATRMult = 2.0;
input double MaxSpreadPoints = 20.0;
input double RiskPercent = 1.0;
input bool OnePositionPerSymbol = true;
input ulong MagicNumber = 26032001;

int fastMaHandle = INVALID_HANDLE;
int slowMaHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
datetime lastEntryBarTime = 0;
datetime lastSignalBarTime = 0;

int OnInit()
{
   fastMaHandle = iMA(_Symbol, InpTrendTF, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowMaHandle = iMA(_Symbol, InpTrendTF, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, InpEntryTF, ATRPeriod);

   if(fastMaHandle == INVALID_HANDLE || slowMaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("Indicator handle creation failed");
      return(INIT_FAILED);
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(fastMaHandle != INVALID_HANDLE) IndicatorRelease(fastMaHandle);
   if(slowMaHandle != INVALID_HANDLE) IndicatorRelease(slowMaHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
}

void OnTick()
{
   datetime currentBar = iTime(_Symbol, InpEntryTF, 0);
   if(currentBar == 0 || currentBar == lastEntryBarTime)
      return;
   lastEntryBarTime = currentBar;

   int signal = 0;
   datetime signalBarTime = 0;
   if(!GetCrossSignal(signal, signalBarTime))
      return;

   if(signalBarTime == lastSignalBarTime)
      return;

   lastSignalBarTime = signalBarTime;

   double atrPrice = GetATRPrice(1);
   double atrPoints = atrPrice / _Point;
   if(atrPrice <= 0 || atrPoints < MinATRPoints)
      return;

   if(GetSpreadPoints() > MaxSpreadPoints)
      return;

   if(PositionSelect(_Symbol))
   {
      long posType = PositionGetInteger(POSITION_TYPE);
      bool shouldReverse = ((signal > 0 && posType == POSITION_TYPE_SELL) || (signal < 0 && posType == POSITION_TYPE_BUY));
      if(!shouldReverse)
         return;

      if(!CloseCurrentPosition())
         return;
   }
   else if(OnePositionPerSymbol && PositionSelect(_Symbol))
   {
      return;
   }

   if(signal > 0)
      OpenPosition(ORDER_TYPE_BUY, atrPrice, "USDJPY H1 trend buy");
   else if(signal < 0)
      OpenPosition(ORDER_TYPE_SELL, atrPrice, "USDJPY H1 trend sell");
}

bool GetCrossSignal(int &signal, datetime &signalBarTime)
{
   signal = 0;
   signalBarTime = iTime(_Symbol, InpTrendTF, 1);
   if(signalBarTime == 0)
      return false;

   double fast1 = GetIndicatorValue(fastMaHandle, 1);
   double fast2 = GetIndicatorValue(fastMaHandle, 2);
   double slow1 = GetIndicatorValue(slowMaHandle, 1);
   double slow2 = GetIndicatorValue(slowMaHandle, 2);

   if(fast1 <= 0 || fast2 <= 0 || slow1 <= 0 || slow2 <= 0)
      return false;

   if(fast2 <= slow2 && fast1 > slow1)
      signal = 1;
   else if(fast2 >= slow2 && fast1 < slow1)
      signal = -1;

   return (signal != 0);
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

double GetSpreadPoints()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
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

bool CloseCurrentPosition()
{
   if(!PositionSelect(_Symbol))
      return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   long posType = PositionGetInteger(POSITION_TYPE);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);

   request.action = TRADE_ACTION_DEAL;
   request.magic = MagicNumber;
   request.symbol = _Symbol;
   request.position = ticket;
   request.volume = volume;
   request.deviation = 20;
   request.type_filling = ORDER_FILLING_IOC;
   request.comment = "USDJPY H1 trend close";

   if(posType == POSITION_TYPE_BUY)
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }

   if(!OrderSend(request, result))
   {
      Print("Close OrderSend failed: ", GetLastError());
      return false;
   }

   return (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED);
}

void OpenPosition(ENUM_ORDER_TYPE orderType, double atrPrice, string comment)
{
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopDistance = atrPrice * StopATRMult;
   double volume = CalculateVolume(stopDistance);
   if(volume <= 0)
      return;

   double sl = (orderType == ORDER_TYPE_BUY) ? price - stopDistance : price + stopDistance;
   SendMarketOrder(orderType, volume, price, sl, 0.0, comment);
}
