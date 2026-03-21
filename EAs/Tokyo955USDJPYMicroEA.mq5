#property strict
#property version   "1.00"
#property description "Tokyo 9:55 JST fix micro-play for USDJPY using M1 proxy rules"

input ENUM_TIMEFRAMES InpSignalTF = PERIOD_M1;
input bool UseUsDstServerClock = true;
input int FixHourWinterServer = 2;
input int FixHourSummerServer = 3;
input int FixedHourServer = 2;
input int FixMinute = 55;
input int PreFixWindowMinutes = 10;
input int VolumeLookbackMinutes = 60;
input int ATRPeriod = 10;
input double MinDriftATR = 0.4;
input double MinVolumeBurstZ = 2.0;
input double TakeATRMult = 0.6;
input double StopATRMult = 0.35;
input double HardPercentStop = 0.25;
input int SignalMode = 0; // 0=auto, 1=continuation, 2=reversal
input double MaxSpreadPoints = 20.0;
input double SpreadMedianMultiplier = 2.0;
input double RiskPercent = 0.5;
input int MaxHoldMinutes = 8;
input bool OneTradePerDay = true;
input ulong MagicNumber = 26032101;

int atrHandle = INVALID_HANDLE;
datetime lastBarTime = 0;
int lastTradeDateCode = -1;

int OnInit()
{
   atrHandle = iATR(_Symbol, InpSignalTF, ATRPeriod);
   if(atrHandle == INVALID_HANDLE)
   {
      Print("ATR handle creation failed");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
}

void OnTick()
{
   ManageOpenPosition();

   datetime currentBar = iTime(_Symbol, InpSignalTF, 0);
   if(currentBar == 0 || currentBar == lastBarTime)
      return;
   lastBarTime = currentBar;

   if(HasOurPosition())
      return;

   if(!IsEntryBarTime(currentBar))
      return;

   if(OneTradePerDay && IsTradeTakenToday(currentBar))
      return;

   double spreadPoints = GetSpreadPoints();
   if(spreadPoints > MaxSpreadPoints)
      return;

   double spreadMedian = GetMedianSpreadPoints(1, 5);
   if(spreadMedian > 0 && spreadPoints > spreadMedian * SpreadMedianMultiplier)
      return;

   int signal = 0;
   double atrPrice = 0.0;
   if(!BuildSignal(signal, atrPrice))
      return;

   if(signal > 0)
      OpenPosition(ORDER_TYPE_BUY, atrPrice, "Tokyo955 cont/rev buy");
   else if(signal < 0)
      OpenPosition(ORDER_TYPE_SELL, atrPrice, "Tokyo955 cont/rev sell");
}

bool BuildSignal(int &signal, double &atrPrice)
{
   signal = 0;
   atrPrice = GetATRPrice(2);
   if(atrPrice <= 0)
      return false;

   int preEndShift = 2;
   int preStartShift = PreFixWindowMinutes + 1;
   int prevEndShift = preStartShift + 1;
   int prevStartShift = preStartShift + VolumeLookbackMinutes;

   if(Bars(_Symbol, InpSignalTF) < prevStartShift + 5)
      return false;

   double preOpen = iOpen(_Symbol, InpSignalTF, preStartShift);
   double preClose = iClose(_Symbol, InpSignalTF, preEndShift);
   double drift = preClose - preOpen;
   if(drift == 0.0)
      return false;

   double driftATR = MathAbs(drift) / atrPrice;
   if(driftATR < MinDriftATR)
      return false;

   double preVolumeAvg = GetAverageTickVolume(preEndShift, PreFixWindowMinutes);
   double prevVolumeMean = 0.0;
   double prevVolumeStd = 0.0;
   if(!GetTickVolumeStats(prevEndShift, VolumeLookbackMinutes, prevVolumeMean, prevVolumeStd))
      return false;

   double volumeZ = 0.0;
   if(prevVolumeStd > 0.0)
      volumeZ = (preVolumeAvg - prevVolumeMean) / prevVolumeStd;
   if(volumeZ < MinVolumeBurstZ)
      return false;

   double preHigh = -DBL_MAX;
   double preLow = DBL_MAX;
   for(int shift = preEndShift; shift <= preStartShift; shift++)
   {
      double high = iHigh(_Symbol, InpSignalTF, shift);
      double low = iLow(_Symbol, InpSignalTF, shift);
      if(high > preHigh) preHigh = high;
      if(low < preLow) preLow = low;
   }

   double fixOpen = iOpen(_Symbol, InpSignalTF, 1);
   double fixHigh = iHigh(_Symbol, InpSignalTF, 1);
   double fixLow = iLow(_Symbol, InpSignalTF, 1);
   double fixClose = iClose(_Symbol, InpSignalTF, 1);

   int cont = 0;
   int rev = 0;
   if(drift > 0.0)
   {
      if(fixClose > preHigh && fixClose > fixOpen)
         cont = 1;
      if(fixHigh > preHigh && fixClose < preHigh && fixClose < fixOpen)
         rev = -1;
   }
   else
   {
      if(fixClose < preLow && fixClose < fixOpen)
         cont = -1;
      if(fixLow < preLow && fixClose > preLow && fixClose > fixOpen)
         rev = 1;
   }

   if(SignalMode == 1)
      signal = cont;
   else if(SignalMode == 2)
      signal = rev;
   else
      signal = (cont != 0) ? cont : rev;

   return (signal != 0);
}

void ManageOpenPosition()
{
   ulong ticket = 0;
   long posType = -1;
   datetime entryTime = 0;
   if(!GetOurPosition(ticket, posType, entryTime))
      return;

   if((TimeCurrent() - entryTime) < MaxHoldMinutes * 60)
      return;

   CloseOurPosition(ticket, posType, "Tokyo955 time exit");
}

bool IsEntryBarTime(datetime currentBar)
{
   MqlDateTime dt;
   TimeToStruct(currentBar, dt);

   int fixHour = GetFixHourServer(currentBar);
   int entryHour = fixHour;
   int entryMinute = FixMinute + 1;
   if(entryMinute >= 60)
   {
      entryMinute -= 60;
      entryHour = (entryHour + 1) % 24;
   }

   return (dt.hour == entryHour && dt.min == entryMinute);
}

int GetFixHourServer(datetime currentBar)
{
   if(!UseUsDstServerClock)
      return FixedHourServer;
   return IsUsDst(currentBar) ? FixHourSummerServer : FixHourWinterServer;
}

bool IsUsDst(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   datetime start = NthWeekdayOfMonth(dt.year, 3, 0, 2);
   datetime end = NthWeekdayOfMonth(dt.year, 11, 0, 1);
   datetime dateOnly = DateOnly(t);
   return (dateOnly >= start && dateOnly < end);
}

datetime DateOnly(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   MqlDateTime d;
   ZeroMemory(d);
   d.year = dt.year;
   d.mon = dt.mon;
   d.day = dt.day;
   return StructToTime(d);
}

datetime NthWeekdayOfMonth(int year, int month, int weekday, int nth)
{
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = 1;
   datetime t = StructToTime(dt);
   MqlDateTime cur;
   TimeToStruct(t, cur);
   while(cur.day_of_week != weekday)
   {
      t += 86400;
      TimeToStruct(t, cur);
   }
   t += (nth - 1) * 7 * 86400;
   return DateOnly(t);
}

bool IsTradeTakenToday(datetime currentBar)
{
   MqlDateTime dt;
   TimeToStruct(currentBar, dt);
   int dateCode = dt.year * 1000 + dt.day_of_year;
   return (dateCode == lastTradeDateCode);
}

double GetATRPrice(int shift)
{
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(atrHandle, 0, shift, 1, buffer) <= 0)
      return -1.0;
   return buffer[0];
}

double GetSpreadPoints()
{
   return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
}

double GetMedianSpreadPoints(int startShift, int count)
{
   if(count <= 0)
      return 0.0;

   double vals[];
   ArrayResize(vals, count);
   for(int i = 0; i < count; i++)
   {
      double high = iHigh(_Symbol, InpSignalTF, startShift + i);
      double low = iLow(_Symbol, InpSignalTF, startShift + i);
      vals[i] = MathMax(0.0, (high - low) / _Point);
   }
   ArraySort(vals);
   if((count % 2) == 1)
      return vals[count / 2];
   return 0.5 * (vals[count / 2 - 1] + vals[count / 2]);
}

double GetAverageTickVolume(int startShift, int count)
{
   if(count <= 0)
      return 0.0;
   double total = 0.0;
   for(int i = 0; i < count; i++)
      total += (double)iVolume(_Symbol, InpSignalTF, startShift + i);
   return total / count;
}

bool GetTickVolumeStats(int startShift, int count, double &mean, double &stddev)
{
   mean = 0.0;
   stddev = 0.0;
   if(count <= 1)
      return false;

   double vals[];
   ArrayResize(vals, count);
   for(int i = 0; i < count; i++)
      vals[i] = (double)iVolume(_Symbol, InpSignalTF, startShift + i);

   for(int i = 0; i < count; i++)
      mean += vals[i];
   mean /= count;

   double sumsq = 0.0;
   for(int i = 0; i < count; i++)
   {
      double d = vals[i] - mean;
      sumsq += d * d;
   }
   stddev = MathSqrt(sumsq / count);
   return true;
}

double CalculateVolume(double stopDistancePrice)
{
   if(stopDistancePrice <= 0.0)
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

   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      lastTradeDateCode = dt.year * 1000 + dt.day_of_year;
      return true;
   }
   return false;
}

bool GetOurPosition(ulong &ticket, long &posType, datetime &entryTime)
{
   if(!PositionSelect(_Symbol))
      return false;

   if((ulong)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
      return false;

   ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   posType = PositionGetInteger(POSITION_TYPE);
   entryTime = (datetime)PositionGetInteger(POSITION_TIME);
   return true;
}

bool HasOurPosition()
{
   ulong ticket = 0;
   long posType = -1;
   datetime entryTime = 0;
   return GetOurPosition(ticket, posType, entryTime);
}

bool CloseOurPosition(ulong ticket, long posType, string comment)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_DEAL;
   request.magic = MagicNumber;
   request.symbol = _Symbol;
   request.position = ticket;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.deviation = 20;
   request.type_filling = ORDER_FILLING_IOC;
   request.comment = comment;

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
   double atrStop = atrPrice * StopATRMult;
   double pctStop = price * (HardPercentStop / 100.0);
   double stopDistance = MathMin(atrStop, pctStop);
   double takeDistance = atrPrice * TakeATRMult;
   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   double sl = (orderType == ORDER_TYPE_BUY) ? price - stopDistance : price + stopDistance;
   double tp = (orderType == ORDER_TYPE_BUY) ? price + takeDistance : price - takeDistance;
   SendMarketOrder(orderType, volume, price, sl, tp, comment);
}
