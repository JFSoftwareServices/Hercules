//+------------------------------------------------------------------+
//| CloseTracker.mqh                                                 |
//|                                                                  |
//| Utility class that tracks the timestamp of the most recent       |
//| trade close event.                                               |
//|                                                                  |
//| The tracker listens for deal events (typically from              |
//| OnTradeTransaction) and records the time of the latest           |
//| closing deal (DEAL_ENTRY_OUT).                                   |
//|                                                                  |
//| It provides helper methods to determine how many candles have    |
//| elapsed since the last trade was closed, enabling strategies to  |
//| enforce cooldown periods before allowing a new trade.            |
//|                                                                  |
//| Intended Use                                                     |
//| ------------                                                     |
//| • Trade cooldown logic (e.g., wait N candles after a close)      |
//| • Risk management safeguards                                     |
//| • Preventing immediate re-entry after a position closes          |
//|                                                                  |
//| Integration Example                                              |
//| -------------------                                              |
//| In OnTradeTransaction():                                         |
//|                                                                  |
//|   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)                   |
//|       closeTracker.ProcessDeal(trans.deal);                      |
//|                                                                  |
//| Notes                                                            |
//| -----                                                            |
//| • Only deals with DEAL_ENTRY_OUT update the close timestamp.     |
//| • If no trade has closed yet, CandlesSinceLastClose() returns    |
//|   -1.                                                            |
//| • Candle calculations are based on the chart symbol and period.  |
//+------------------------------------------------------------------+
class CTradeCloseTracker
  {
private:
   datetime          m_lastCloseTime;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   // Constructor
                     CTradeCloseTracker(string symbol, ENUM_TIMEFRAMES timeframe)
     {
      m_symbol = symbol;
      m_timeframe = timeframe;
      m_lastCloseTime = 0;
     }

   // Update tracker when a deal occurs
   void              ProcessDeal(ulong deal_ticket)
     {
      if(!HistoryDealSelect(deal_ticket))
         return;

      if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         return;

      datetime closeTime = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(closeTime > 0)
         m_lastCloseTime = closeTime;
     }

   // Returns number of candles elapsed since last trade close on the given symbol & timeframe
   int               CandlesSinceLastClose()
     {
      if(m_lastCloseTime == 0)
         return -1;

      int lastCloseBar = iBarShift(m_symbol, m_timeframe, m_lastCloseTime, true);
      if(lastCloseBar < 0)
         return -1;

      return lastCloseBar; // number of bars since close
     }

   // Check if X candles have passed since last close
   bool              HasCandlesPassed(int candles)
     {
      int elapsed = CandlesSinceLastClose();
      if(elapsed == -1)
         return false;

      return elapsed >= candles;
     }

   datetime          GetLastCloseTime() { return m_lastCloseTime; }
  };
//+------------------------------------------------------------------+
