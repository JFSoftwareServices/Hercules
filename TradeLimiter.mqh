//+------------------------------------------------------------------+
//| TradeLimiter.mqh                                                 |
//|                                                                  |
//| Purpose                                                          |
//| -------                                                          |
//| Prevents more than one trade being opened per candle.            |
//|                                                                  |
//| IMPORTANT PRECONDITION                                           |
//| ---------------------                                            |
//| This limiter assumes it is only called immediately after a       |
//| new candle opens (i.e., once per bar).                           |
//|                                                                  |
//| The EA must already detect new candles, for example:             |
//|                                                                  |
//|   static datetime lastBar = 0;                                   |
//|   datetime currentBar = iTime(_Symbol,_Period,0);                |
//|                                                                  |
//|   if(currentBar != lastBar)                                      |
//|   {                                                              |
//|       lastBar = currentBar;                                      |
//|       limiter.Check(currentBar);                                 |
//|   }                                                              |
//|                                                                  |
//| If Check() is called multiple times during the same candle       |
//| (e.g., on every tick), this class will still prevent duplicates  |
//| but the caller is responsible for correct usage.                 |
//+------------------------------------------------------------------+

// Result returned by the limiter check
struct LimiterResult
{
   bool   canOpen;   // true  = trade allowed this candle
   string message;   // diagnostic message
};

//+------------------------------------------------------------------+
//| Trade limiter class                                              |
//+------------------------------------------------------------------+
class CTradeLimiter
{
private:

   // Stores the candle time when the last trade was opened
   datetime lastTradeCandle;

public:

   CTradeLimiter()
   {
      lastTradeCandle = 0;
   }

   //+----------------------------------------------------------------+
   //| Checks if a trade may be opened on the current candle          |
   //|                                                                |
   //| Parameters                                                     |
   //| ----------                                                     |
   //| currentCandleTime : timestamp of the current bar               |
   //|                     (usually iTime(_Symbol,_Period,0))         |
   //|                                                                |
   //| Returns                                                        |
   //| -------                                                        |
   //| LimiterResult containing permission flag and message           |
   //+----------------------------------------------------------------+
   LimiterResult Check(datetime currentCandleTime)
   {
      LimiterResult result;

      if(lastTradeCandle == currentCandleTime)
      {
         result.canOpen = false;
         result.message = "Trade already opened this candle";
         return result;
      }

      result.canOpen = true;
      result.message = "Trade allowed for this candle";

      return result;
   }


   //+----------------------------------------------------------------+
   //| Records that a trade has been opened for this candle           |
   //| Must be called immediately after successful order placement    |
   //+----------------------------------------------------------------+
   void RecordTrade(datetime currentCandleTime)
   {
      lastTradeCandle = currentCandleTime;
   }
};
//+------------------------------------------------------------------+