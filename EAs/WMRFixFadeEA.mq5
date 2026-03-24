#property strict
#property version   "1.00"
#property description "WM/Reuters 4pm London fix fade EA based on tick-activity and post-fix mean reversion"

input bool UseLondonDstServerClock = true;
input int FixHourWinterServer = 16;
input int FixHourSummerServer = 15;
input int FixMinute = 0;
input int EntryDelaySeconds = 0;
input int TimeoutMinutes = 8;
input double MoveThresholdBps = 4.0;
input double RetraceRatio = 0.5;
input double StopRatio = 0.75;
input double MaxSpreadMultiplier = 1.5;
input double MinTickRateRatio = 1.3;
input int MinPreTicks = 100;
input int MinFixTicks = 20;
input double RiskPercent = 0.5;
input bool OneTradePerDay = true;
input ulong MagicNumber = 26032401;

struct SessionState
{
   int dateCode;
   datetime preStart;
   datetime preEnd;
   datetime fixEnd;
   datetime entryTime;
   double preMid;
   double fixMid;
   double preSpreadMedian;
   int preTickCount;
   int fixTickCount;
   bool preCaptured;
   bool fixCaptured;
   bool evaluated;
   bool traded;
};

SessionState state;
double preSpreads[];

int OnInit()
{
   ArrayResize(preSpreads, 0);
   state.dateCode = -1;
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   ResetSessionIfNeeded();
   CollectSessionStats();
   ManageOpenPosition();
   TryEntry();
}

void ResetSessionIfNeeded()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dateCode = dt.year * 1000 + dt.day_of_year;
   if(dateCode == state.dateCode)
      return;

   state.dateCode = dateCode;
   BuildSessionTimes();
   state.preMid = 0.0;
   state.fixMid = 0.0;
   state.preSpreadMedian = 0.0;
   state.preTickCount = 0;
   state.fixTickCount = 0;
   state.preCaptured = false;
   state.fixCaptured = false;
   state.evaluated = false;
   state.traded = false;
   ArrayResize(preSpreads, 0);
}

void BuildSessionTimes()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   int fixHour = UseLondonDstServerClock ? (IsLondonDst(now) ? FixHourSummerServer : FixHourWinterServer) : FixHourWinterServer;

   MqlDateTime fixStruct;
   ZeroMemory(fixStruct);
   fixStruct.year = dt.year;
   fixStruct.mon = dt.mon;
   fixStruct.day = dt.day;
   fixStruct.hour = fixHour;
   fixStruct.min = FixMinute;
   fixStruct.sec = 0;

   datetime fixBase = StructToTime(fixStruct);
   state.preStart = fixBase - 30 * 60;
   state.preEnd = fixBase - 150;
   state.fixEnd = fixBase + 150;
   state.entryTime = state.fixEnd + EntryDelaySeconds;
}

bool IsLondonDst(datetime serverTime)
{
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   datetime start = LastSundayOfMonth(dt.year, 3, 1);
   datetime end = LastSundayOfMonth(dt.year, 10, 1);
   datetime today = DateOnly(serverTime);
   return (today >= start && today < end);
}

datetime LastSundayOfMonth(int year, int month, int hour)
{
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month + 1;
   dt.day = 1;
   if(month == 12)
   {
      dt.year = year + 1;
      dt.mon = 1;
   }
   datetime t = StructToTime(dt) - 86400;
   MqlDateTime cur;
   TimeToStruct(t, cur);
   while(cur.day_of_week != 0)
   {
      t -= 86400;
      TimeToStruct(t, cur);
   }
   cur.hour = hour;
   cur.min = 0;
   cur.sec = 0;
   return StructToTime(cur);
}

datetime DateOnly(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   MqlDateTime out;
   ZeroMemory(out);
   out.year = dt.year;
   out.mon = dt.mon;
   out.day = dt.day;
   return StructToTime(out);
}

void CollectSessionStats()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   if(tick.time < state.preStart)
      return;

   double spread = tick.ask - tick.bid;
   double mid = 0.5 * (tick.ask + tick.bid);

   if(tick.time <= state.preEnd)
   {
      int n = ArraySize(preSpreads);
      ArrayResize(preSpreads, n + 1);
      preSpreads[n] = spread;
      state.preTickCount++;
      state.preMid = mid;
      state.preCaptured = true;
      return;
   }

   if(tick.time <= state.fixEnd)
   {
      state.fixTickCount++;
      state.fixMid = mid;
      state.fixCaptured = true;
   }
}

void TryEntry()
{
   if(state.evaluated)
      return;
   if(OneTradePerDay && state.traded)
      return;
   if(TimeCurrent() < state.entryTime)
      return;

   state.evaluated = true;

   if(!state.preCaptured || !state.fixCaptured)
      return;
   if(state.preTickCount < MinPreTicks || state.fixTickCount < MinFixTicks)
      return;

   state.preSpreadMedian = Median(preSpreads);
   if(state.preSpreadMedian <= 0.0)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   double spreadNow = tick.ask - tick.bid;
   if(spreadNow > state.preSpreadMedian * MaxSpreadMultiplier)
      return;

   double preMinutes = 27.5;
   double fixMinutes = 5.0;
   double tickRateRatio = (state.fixTickCount / fixMinutes) / (state.preTickCount / preMinutes);
   if(tickRateRatio < MinTickRateRatio)
      return;

   double move = state.fixMid - state.preMid;
   double moveBps = MathAbs(move) / state.preMid * 10000.0;
   if(moveBps < MoveThresholdBps)
      return;

   int direction = (move > 0.0) ? -1 : 1;
   double entryPx = (direction > 0) ? tick.ask : tick.bid;
   double targetMid = state.fixMid - RetraceRatio * move;
   double targetDist = MathAbs(entryPx - targetMid);
   double stopDist = MathAbs(move) * StopRatio;
   if(targetDist <= 0.0 || stopDist <= 0.0)
      return;

   double sl = (direction > 0) ? entryPx - stopDist : entryPx + stopDist;
   double tp = (direction > 0) ? entryPx + targetDist : entryPx - targetDist;
   double volume = CalculateVolume(stopDist);
   if(volume <= 0.0)
      return;

   ENUM_ORDER_TYPE orderType = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(SendMarketOrder(orderType, volume, entryPx, sl, tp, direction > 0 ? "WMR fade buy" : "WMR fade sell"))
      state.traded = true;
}

void ManageOpenPosition()
{
   ulong ticket;
   long posType;
   datetime posTime;
   if(!GetOurPosition(ticket, posType, posTime))
      return;

   if((TimeCurrent() - posTime) < TimeoutMinutes * 60)
      return;

   CloseOurPosition(ticket, posType, "WMR time exit");
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

double Median(double &arr[])
{
   int n = ArraySize(arr);
   if(n <= 0)
      return 0.0;
   double tmp[];
   ArrayResize(tmp, n);
   for(int i = 0; i < n; i++)
      tmp[i] = arr[i];
   ArraySort(tmp);
   if((n % 2) == 1)
      return tmp[n / 2];
   return 0.5 * (tmp[n / 2 - 1] + tmp[n / 2]);
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
   return (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED);
}
