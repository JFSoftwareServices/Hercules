//+------------------------------------------------------------------+
//|                                              TradeManager.mqh    |
//| PURPOSE: Execute and manage trades, including SL/TP, breakeven,  |
//|          and safe closing of all positions.                      |
//| FEATURES:                                                        |
//|   - Buy/Sell with lot, SL, TP                                    |
//|   - GetOpenPositionTicket() for open position detection          |
//|   - HasOpenPositions() helper                                    |
//|   - CloseAllPositions() with once-per-trigger logging            |
//+------------------------------------------------------------------+
#ifndef __TRADE_MANAGER__
#define __TRADE_MANAGER__

#include <Trade/Trade.mqh>
#include "../CommonLibs/Core/Logger.mqh"

//
struct TradeResult
  {
   bool              success;      // True if trade executed
   ulong             ticket;       // Order ticket
   double            entryPrice;   // Entry price
   double            stopLoss;     // Stop loss price
   double            takeProfit;   // Take profit price
   string            message;      // Debug or error message
  };
//
struct CloseResult
  {
   int               totalFound;   // positions matching symbol+magic
   int               closed;       // successfully closed
   int               failed;       // failed to close
   string            message;      // optional message
  };
//
class CTradeManager
  {
private:
   CTrade            m_trade;
   string            m_symbol;
   double            m_lotSize;
   double            m_stopLossPrice;
   double            m_takeProfitPrice;
   int               m_magic;
   bool              m_warnedCloseFail; // prevent repeated warnings

public:
   // Initialize trade manager
   void              Init(string symbol, double lotSize, double slPrice, double tpPrice, int magic)
     {
      m_symbol          = symbol;
      m_lotSize         = lotSize;
      m_stopLossPrice   = slPrice;
      m_takeProfitPrice = tpPrice;
      m_magic           = magic;

      m_trade.SetExpertMagicNumber(m_magic);
      m_warnedCloseFail = false;
     }

   // Buy market order
   TradeResult       Buy()
     {
      TradeResult result = {};
      if(!m_trade.Buy(m_lotSize, m_symbol, 0.0, m_stopLossPrice, m_takeProfitPrice))
        {
         result.message = StringFormat("Buy failed: %d (%s)", m_trade.ResultRetcode(), m_trade.ResultComment());
         return result;
        }
      result.success    = true;
      result.ticket     = m_trade.ResultOrder();
      result.entryPrice = m_trade.ResultPrice();
      result.stopLoss   = m_stopLossPrice;
      result.takeProfit = m_takeProfitPrice;

      return result;
     }

   // Sell market order
   TradeResult       Sell()
     {
      TradeResult result = {};
      if(!m_trade.Sell(m_lotSize, m_symbol, 0.0, m_stopLossPrice, m_takeProfitPrice))
        {
         result.message = StringFormat("Sell failed: %d (%s)", m_trade.ResultRetcode(), m_trade.ResultComment());
         return result;
        }

      result.success    = true;
      result.ticket     = m_trade.ResultOrder();
      result.entryPrice = m_trade.ResultPrice();
      result.stopLoss   = m_stopLossPrice;
      result.takeProfit = m_takeProfitPrice;

      return result;
     }

   // Close all positions for symbol+magic
   CloseResult       CloseAllPositions()
     {
      CloseResult result = {};
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;

         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;

         result.totalFound++;

         if(m_trade.PositionClose(ticket))
           {
            result.closed++;
            result.message += StringFormat("Closed position %I64u\n", ticket);
            m_warnedCloseFail = false; // reset warning flag on success
           }
         else
           {
            result.failed++;
            if(!m_warnedCloseFail)
              {
               Logger::Instance().Warn(
                  StringFormat("Failed to close %I64u. Retcode=%d (%s)",
                               ticket,
                               m_trade.ResultRetcode(),
                               m_trade.ResultComment())
               );
               m_warnedCloseFail = true; // only warn once until next success
              }
            result.message += StringFormat("Failed to close %I64u\n", ticket);
           }
        }
      return result;
     }

   // Return first open position ticket for symbol+magic, or 0 if none
   ulong             GetOpenPositionTicket()
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;

         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;

         return ticket;
        }
      return 0;
     }

   // Check if any position is open for symbol+magic
   bool              HasOpenPositions()
     {
      return GetOpenPositionTicket() != 0;
     }
  };

#endif
//+------------------------------------------------------------------+