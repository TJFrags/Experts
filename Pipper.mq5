//+------------------------------------------------------------------+
//|                                                       Pipper.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;
CPositionInfo pos;
COrderInfo ord;
input group "+++++Trading Inputs++++++"

input double riskPercent = 3; // Risk as Percentage of Balance
input int tpPoints = 200; // TP Points (10 points = 1 pip)
input int slPoints = 200; // SL Points (10 points = 1 pip)

input int tslTriggerPoint = 15; // SL Trailing Triger Point (10 points = 1 pip)
input int tslPoints = 10; // SL Trailing Points (10 points = 1 pip)

input ENUM_TIMEFRAMES timeFrame = PERIOD_CURRENT; // TimeFrame

input string magicNum = "234234"; //Magic Number
input string inpComment = "Money"; //Comment

input int startHour = 1; // Start Hour
input int endHour = 23; //End Hour

int bars = 5;
int expirationBars = 100;
int orderDistancePoints = 100;


int OnInit()
{
   trade.SetExpertMagicNumber (ulong(magicNum));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   TrailStop();
   if(!isNewBar()) return;
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   int Hournow = time.hour;
   if (Hournow<startHour) {CloseAllOrders(); return; }
   if(Hournow>=endHour && endHour!=0) {CloseAllOrders(); return;}
   
   int BuyTotal=0;
   int SellTotal=0;
   for (int i=PositionsTotal()-1; i>=0; i--)
   {
      pos.SelectByIndex(i);
      if(pos.PositionType() ==POSITION_TYPE_BUY && pos.Symbol() == _Symbol && string(pos.Magic()) ==magicNum) BuyTotal++;
      if(pos.PositionType() ==POSITION_TYPE_SELL && pos.Symbol() == _Symbol && string(pos.Magic()) ==magicNum) SellTotal++;
   }
   for (int i=OrdersTotal()-1; i>=0; i--)
   {
      ord.SelectByIndex(i);
      if(ord.OrderType() ==ORDER_TYPE_BUY_STOP && ord. Symbol() == _Symbol && string(pos.Magic()) ==magicNum) BuyTotal++;
      if(ord.OrderType() ==ORDER_TYPE_SELL_STOP && ord. Symbol() == _Symbol && string(pos.Magic()) ==magicNum) SellTotal++;
   } 
   
   if (BuyTotal <=0)
   {
      double high  = getHigh();
      if(high > 0) 
      {
         SendBuyOrder (high);
      }
   }
   if(SellTotal <=0)
   {
      double low = getLow();
      if(low > 0) 
      {
         SendSellOrder(low);
      }
   }
}
//+------------------------------------------------------------------+

double getHigh()
{
   double HighestHigh = 0;
   for(int i=0;i<200;i++)
     {
       double high = iHigh(_Symbol, timeFrame, i);
       if (i > bars && iHighest(_Symbol, timeFrame, MODE_HIGH, bars * 2 + 1, i-bars) == i)
       {
         if(high > HighestHigh)
           {
               return high;
               
           }
       }
       HighestHigh = MathMax(high, HighestHigh);
     }
     return -1;
}

double getLow()
{
   double lowesLow = DBL_MAX;
   for(int i=0;i<200;i++)
     {
       double low = iLow(_Symbol, timeFrame, i);
       if (i > bars && iLowest(_Symbol, timeFrame, MODE_HIGH, bars * 2 + 1, i-bars) == i)
       {
         if(low < lowesLow)
           {
               return low;
               
           }
       }
       lowesLow = MathMax(low, lowesLow);
     }
     return -1;
}

bool isNewBar()
{
   static datetime prevTime = 0;
   datetime currentTime = iTime(_Symbol, timeFrame, 0);
   if(prevTime != currentTime)
   {
      prevTime = currentTime;
      return true;
   }
     
   return false;   
}


void SendBuyOrder (double entry) 
{  
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double  stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
 
   if(ask > entry - orderDistancePoints * _Point) return;
   double tp = entry + tpPoints * _Point ;
   double sl = entry - slPoints * _Point;
   
   if(entry -sl < spread + stop_level)
     {
       sl = entry - (spread + stop_level);
     }
   if(tp - entry < spread + stop_level)
     {
       tp = entry + (spread + stop_level);
     }  
   double lots = 0.01;
   if (riskPercent > 0) lots = calcLots (entry-sl);
   datetime expiration = iTime(_Symbol, timeFrame, 0) + expirationBars * PeriodSeconds (timeFrame);
   trade.BuyStop(lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
}

void SendSellOrder (double entry) 
{
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double  stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid < entry + orderDistancePoints * _Point) return;
   double tp = entry - tpPoints * _Point;
   
   double sl = entry + slPoints*_Point;
   
   if(entry -tp < spread + stop_level)
     {
       tp = entry - (spread + stop_level);
     }
   if(sl - entry < spread + stop_level)
     {
       sl = entry + (spread + stop_level);
     }  
     
   double lots = 0.01;
   if (riskPercent > 0) lots = calcLots (sl-entry);
   datetime expiration = iTime (_Symbol, timeFrame,0) + expirationBars * PeriodSeconds(timeFrame);
   trade. SellStop (lots, entry, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration);
}
double calcLots (double _slPoints) 
{
   double risk = AccountInfoDouble (ACCOUNT_BALANCE) * riskPercent / 100;
   
   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble (_Symbol, SYMBOL_VOLUME_STEP);
   double minvolume=SymbolInfoDouble (Symbol(), SYMBOL_VOLUME_MIN);
   double maxvolume=SymbolInfoDouble (Symbol(), SYMBOL_VOLUME_MAX);
   double volumelimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
   
   double moneyPerLotstep = _slPoints / ticksize * tickvalue * lotstep;
   double lots = MathFloor (risk / moneyPerLotstep) * lotstep;
   if(volumelimit!=0) lots = MathMin (lots, volumelimit);
   if(maxvolume!=0) lots = MathMin (lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   if(minvolume!=0) lots = MathMax (lots, SymbolInfoDouble (_Symbol, SYMBOL_VOLUME_MIN));
   lots = NormalizeDouble (lots, 2);
   return lots;
}

void CloseAllOrders () 
{
   for(int i=OrdersTotal()-1;i>=0; i--) {
      ord. SelectByIndex(i);
      ulong ticket = ord. Ticket();
      if(ord.Symbol()== _Symbol && string(ord.Magic()) == magicNum)
      {
         bool res = trade.OrderDelete (ticket);
         
         if(res != true)
           {
               TesterStop();
           }
      }
   }
}


void TrailStop() 
{
   double sl = 0;
   double tp = 0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble (_Symbol, SYMBOL_BID);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double stopDistance = spread + stop_level;

   for (int i=PositionsTotal()-1; i>=0; i--)
   {
      if(pos.SelectByIndex(i)) 
      {
         ulong ticket = pos.Ticket();
         if(string(pos.Magic())==magicNum && pos. Symbol() == _Symbol) 
         {
            if (pos.PositionType() ==POSITION_TYPE_BUY)
               {
                  if(bid-pos.PriceOpen() >tslTriggerPoint*_Point) 
                  {
                     tp = pos.TakeProfit();
                     sl  = bid - (tslPoints * _Point);
                     if(sl > pos.StopLoss() && sl!=0 && ask - sl > stopDistance &&  sl - pos.StopLoss() > _Point)
                     {
                        trade. PositionModify (ticket, sl, tp);
                     }
                  }
               }
               else if(pos.PositionType() == POSITION_TYPE_SELL) 
               {
                  if(ask+(tslTriggerPoint*_Point) <pos. PriceOpen() ) 
                  {
                     tp  = pos.TakeProfit();
                     sl  = ask + (tslPoints * _Point);
                     if(sl < pos.StopLoss() && sl!=0 && sl - bid > stopDistance && pos.StopLoss() - sl > _Point)
                     {
                        trade.PositionModify(ticket, sl, tp);
                     }
                  }
               }
         }
      }
   }   
}
