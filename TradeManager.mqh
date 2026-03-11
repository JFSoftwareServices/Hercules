//+---------------------------------------------------------------------+
//|                                              TradeManager.mqh       |
//| PURPOSE: Execute and manage trades including breakeven logic        |
//+---------------------------------------------------------------------+
#ifndef __TRADE_MANAGER__
#define __TRADE_MANAGER__

#include <Trade/Trade.mqh>

//+---------------------------------------------------------------------+
//| TradeResult structure                                               |
//+---------------------------------------------------------------------+
struct TradeResult
  {
   bool              success;        // True if trade executed
   ulong             ticket;         // Order ticket
   double            entryPrice;     // Entry price
   double            stopLoss;       // Stop loss price
   double            takeProfit;     // Take profit price
   string            message;        // Debug or error message
  };

//+---------------------------------------------------------------------+
//| TradeManager                                                        |
//+---------------------------------------------------------------------+
class CTradeManager
  {
private:
   CTrade            trade;
   double            m_lotSize;
   double            m_stopLossPrice;
   double            m_takeProfitPrice;
   int               m_magic;

public:
   //+------------------------------------------------------------------+
   //| Initialize trade manager configuration                           |
   //+------------------------------------------------------------------+
   void              Init(double lotSize, double slPrice, double tpPrice, int magic)
     {
      m_lotSize        = lotSize;
      m_stopLossPrice  = slPrice;
      m_takeProfitPrice= tpPrice;
      m_magic          = magic;

      trade.SetExpertMagicNumber(m_magic);
     }

   //+------------------------------------------------------------------+
   //| Execute market BUY trade                                         |
   //+------------------------------------------------------------------+
   TradeResult       Buy()
     {
      TradeResult result;
      result.success = false;
      result.entryPrice = 0.0;
      result.stopLoss = 0.0;
      result.takeProfit = 0.0;
      result.message = "";

      if(!trade.Buy(m_lotSize, _Symbol, 0.0, m_stopLossPrice, m_takeProfitPrice))
        {
         result.message = StringFormat("Buy failed: %d", trade.ResultRetcode());
         return result;
        }

      result.success    = true;
      result.ticket     = trade.ResultOrder();
      result.entryPrice = trade.ResultPrice();
      result.stopLoss   = m_stopLossPrice;
      result.takeProfit = m_takeProfitPrice;
      return result;
     }

   //+------------------------------------------------------------------+
   //| Execute market SELL trade                                        |
   //+------------------------------------------------------------------+
   TradeResult       Sell()
     {
      TradeResult result;
      result.success = false;
      result.entryPrice = 0.0;
      result.stopLoss = 0.0;
      result.takeProfit = 0.0;
      result.message = "";

      if(!trade.Sell(m_lotSize, _Symbol, 0.0, m_stopLossPrice, m_takeProfitPrice))
        {
         result.message = StringFormat("Sell failed: %d", trade.ResultRetcode());
         return result;
        }

      result.success    = true;
      result.ticket     = trade.ResultOrder();
      result.entryPrice = trade.ResultPrice();
      result.stopLoss   = m_stopLossPrice;
      result.takeProfit = m_takeProfitPrice;
      return result;
     }
  };
#endif
//+------------------------------------------------------------------+
