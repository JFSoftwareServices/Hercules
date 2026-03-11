//+------------------------------------------------------------------+
//|                                      CBreakEvenStrategy.mqh      |
//| PURPOSE: Move stop loss to breakeven when trade reaches X risk   |
//+------------------------------------------------------------------+

#ifndef __BREAK_EVEN_STRATEGY__
#define __BREAK_EVEN_STRATEGY__

#include <Trade/Trade.mqh>
//
class CBreakEvenStrategy
  {
private:

   CTrade            trade;

   string            m_symbol;
   int               m_magic;

   bool              m_enabled;
   double            m_riskReward;
   double            m_breakEvenBuffer; // Extra points to move SL slightly past BE; 0 for exact BE

public:

   void              Init(string symbol,int magic,bool enabled,double riskReward,double breakEvenBuffer)
     {
      m_symbol          = symbol;
      m_magic           = magic;
      m_enabled         = enabled;
      m_riskReward      = riskReward;
      m_breakEvenBuffer = breakEvenBuffer;

      trade.SetExpertMagicNumber(m_magic);
     }

   void              Manage()
     {
      if(!m_enabled)
         return;

      for(int i = PositionsTotal()-1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);

         if(!PositionSelectByTicket(ticket))
            continue;

         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         string symbol = PositionGetString(POSITION_SYMBOL);

         if(symbol != m_symbol)
            continue;

         ManagePosition();
        }
     }

private:

   void              ManagePosition()
     {
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double price;

      if(type==POSITION_TYPE_BUY)
         price = SymbolInfoDouble(m_symbol,SYMBOL_BID);
      else
         price = SymbolInfoDouble(m_symbol,SYMBOL_ASK);

      double risk = MathAbs(entry-sl);

      if(risk<=0)
         return;

      double trigger;

      if(type==POSITION_TYPE_BUY)
         trigger = entry + risk*m_riskReward;
      else
         trigger = entry - risk*m_riskReward;

      if(type==POSITION_TYPE_BUY)
        {
         if(price>=trigger && sl<entry)
           {
            double newSL = entry + m_breakEvenBuffer*_Point;
            trade.PositionModify(m_symbol,newSL,tp);
           }
        }

      if(type==POSITION_TYPE_SELL)
        {
         if(price<=trigger && sl>entry)
           {
            double newSL = entry - m_breakEvenBuffer*_Point;
            trade.PositionModify(m_symbol,newSL,tp);
           }
        }
     }
  };

#endif
//+------------------------------------------------------------------+
