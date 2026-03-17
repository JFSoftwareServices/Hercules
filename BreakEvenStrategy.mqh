//+------------------------------------------------------------------+
//|                                      CBreakEvenStrategy.mqh      |
//| PURPOSE: Move stop loss to breakeven when trade reaches X risk   |
//+------------------------------------------------------------------+
#ifndef __BREAK_EVEN_STRATEGY__
#define __BREAK_EVEN_STRATEGY__

#include <Trade/Trade.mqh>
#include "../CommonLibs/Core/Logger.mqh"

// Result structure for break-even action
struct BreakEvenResult
  {
   bool              success;   // true if SL was modified
   string            message;   // detailed info or error
  };

//
class CBreakEvenStrategy
  {
private:
   CTrade            trade;                    // MT5 trade object
   string            m_symbol;                 // Symbol to manage
   int               m_magic;                  // EA magic number
   bool              m_enabled;                // Enable/disable break-even
   double            m_triggerMultiplier;      // Multiplier of initial risk to trigger break-even
   double            m_breakEvenBuffer;        // Extra points past BE to set SL (can be zero)

public:
   // Initialize strategy
   void              Init(string symbol, int magic, bool enabled, double triggerMultiplier, double breakEvenBuffer)
     {
      m_symbol           = symbol;
      m_magic            = magic;
      m_enabled          = enabled;
      m_triggerMultiplier = triggerMultiplier;
      m_breakEvenBuffer    = breakEvenBuffer;

      trade.SetExpertMagicNumber(m_magic);
     }

   // Main entry: scan positions and apply break-even if conditions met
   BreakEvenResult   Manage()
     {
      BreakEvenResult result;
      result.success = false;
      result.message = "No position found to manage";

      if(!m_enabled)
         return result;

      // Only one position is managed per symbol/magic
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;

         // Filter by magic number
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         // Filter by symbol
         if(PositionGetString(POSITION_SYMBOL) != m_symbol)
            continue;

         // Found the position — manage it
         result = ManagePosition(ticket);
         break; // only one position managed
        }

      return result;
     }

private:

   BreakEvenResult   ManagePosition(ulong ticket)
     {
      BreakEvenResult result;
      result.success = false;
      result.message = "";

      if(!PositionSelectByTicket(ticket))
        {
         result.message = "Position not found";
         return result;
        }

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl         = PositionGetDouble(POSITION_SL);
      double tp         = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits    = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);

      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);

      double currentPrice = (type == POSITION_TYPE_BUY) ? bid : ask;

      // Distance between entry and SL (initial risk)
      double risk = MathAbs(entryPrice - sl);

      // Price level required to trigger break-even
      double trigger = (type == POSITION_TYPE_BUY) ?
                       entryPrice + risk * m_triggerMultiplier :
                       entryPrice - risk * m_triggerMultiplier;

      // Broker minimum stop distance
      double stopLevelPoints = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double stopLevelPrice  = stopLevelPoints * point;

      // Calculate new SL (entry + optional buffer)
      double newSL = entryPrice + ((type == POSITION_TYPE_BUY) ? m_breakEvenBuffer : -m_breakEvenBuffer) * point;

      // Normalize price
      newSL = NormalizeDouble(newSL, digits);

      // Ensure SL respects broker stop distance
      if(type == POSITION_TYPE_BUY && (bid - newSL) < stopLevelPrice)
         newSL = NormalizeDouble(bid - stopLevelPrice, digits);

      if(type == POSITION_TYPE_SELL && (newSL - ask) < stopLevelPrice)
         newSL = NormalizeDouble(ask + stopLevelPrice, digits);

      bool triggerReached =
         (type == POSITION_TYPE_BUY  && currentPrice >= trigger) ||
         (type == POSITION_TYPE_SELL && currentPrice <= trigger);

      bool slNeedsUpdate =
         (type == POSITION_TYPE_BUY  && sl < newSL) ||
         (type == POSITION_TYPE_SELL && sl > newSL);

      if(triggerReached && slNeedsUpdate)
        {
         ResetLastError();

         bool modified = trade.PositionModify(m_symbol, newSL, tp);

         result.success = modified;

         if(modified)
           {
            result.message = StringFormat(
                                "Break-even applied | Symbol: %s | Entry: %.5f | Old SL: %.5f | New SL: %.5f | Trigger: %.5f | Current: %.5f | StopLevel: %.1f pts",
                                m_symbol,
                                entryPrice,
                                sl,
                                newSL,
                                trigger,
                                currentPrice,
                                stopLevelPoints
                             );
           }
         else
           {
            result.message = StringFormat(
                                "Failed BE modify | Symbol: %s | Old SL: %.5f | Attempted SL: %.5f | Error: %d",
                                m_symbol,
                                sl,
                                newSL,
                                GetLastError()
                             );
           }
        }
      else
        {
         result.message = StringFormat(
                             "No BE action | Symbol: %s | Current: %.5f | Trigger: %.5f | SL: %.5f | Target SL: %.5f",
                             m_symbol,
                             currentPrice,
                             trigger,
                             sl,
                             newSL
                          );
        }

      return result;
     }
  };

#endif
//+------------------------------------------------------------------+
