//+---------------------------------------------------------------------+
//|                      CStrategySignalService.mqh                     |
//|  Bollinger Bands + RSI mean-reversion signal service                |
//+---------------------------------------------------------------------+
#ifndef __BOLLINGER_RSI_SIGNAL__
#define __BOLLINGER_RSI_SIGNAL__

#include "../CommonLibs/Indicators/BollingerBands.mqh"
#include "../CommonLibs/Indicators/RSIIndicator.mqh"
//
enum SignalType
  {
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
  };
//
enum TradeDirection
  {
   DIR_BUY,
   DIR_SELL
  };

// RuleCheck struct stores result of each rule evaluation
struct RuleCheck
  {
   bool              BreakCandleRSIThresholdMet; //RSI on break candle meets threshold (oversold for BUY, overbought for SELL)
   bool              BreakCandleBreaksBand;      //Break candle closes outside Bollinger band (with buffer)
   bool              EntryCandleReentersBand;    //Entry candle moves back into Bollinger band (with buffer)
   bool              EntryCandleIsGreen;         //Entry candle color (close>open for green, else red)
   bool              EntryCandleIsRed;           //Entry candle color (close>open for green, else red)
   bool              BreakCandleIsGreen;         //Break candle color (close>open for green, else red)
   bool              BreakCandleIsRed;           //Break candle color (close>open for green, else red)
   bool              EntryBodyRelativeToMidBB;   //Entry candle entirely below (BUY) or above (SELL) middle Bollinger band
  };

// CandleData stores relevant candle and indicator data
struct CandleData
  {
   double            closeEntry;
   double            openEntry;
   double            closeBreak;
   double            openBreak;

   double            bbLowerEntry;
   double            bbMiddleEntry;
   double            bbUpperEntry;
   double            bbLowerBreak;
   double            bbUpperBreak;

   double            rsiBreak;

   double            entryBody;
   double            breakBody;
   double            entryBuffer;
   double            breakBuffer;
  };
// Generated signal result
struct SignalResult
  {
   SignalType        type;
   double            entryPrice;
   double            stopLossPrice;
   double            takeProfitPrice;
   double            stopLossPoints;
   double            takeProfitPoints;
   string            message;
  };
//
class CStrategySignalService
  {
private:
   CBollingerBands   bollingerBands;
   CRSIIndicator     rsi;

   string            symbol;
   ENUM_TIMEFRAMES   timeframe;

   int               rsiOverbought;
   int               rsiOversold;
   double            breakEntryBufferPercent;
   bool              useBBTP;
   double            riskReward;
   double            minSLPoints;
   double            maxSLPoints;
   double            slBufferPoints;
   //------------------------------------
   // Read current candle and indicator data
   //------------------------------------
   void              ReadCandleData(CandleData &data)
     {
      data.closeEntry = iClose(symbol, timeframe, 1);
      data.openEntry  = iOpen(symbol, timeframe, 1);
      data.closeBreak = iClose(symbol, timeframe, 2);
      data.openBreak  = iOpen(symbol, timeframe, 2);

      data.bbLowerEntry  = bollingerBands.GetLower(1);
      data.bbMiddleEntry = bollingerBands.GetMiddle(1);
      data.bbUpperEntry  = bollingerBands.GetUpper(1);

      data.bbLowerBreak  = bollingerBands.GetLower(2);
      data.bbUpperBreak  = bollingerBands.GetUpper(2);

      data.rsiBreak = rsi.GetValue(2);

      data.entryBody = MathAbs(data.closeEntry - data.openEntry);
      data.breakBody = MathAbs(data.closeBreak - data.openBreak);

      data.entryBuffer = data.entryBody * breakEntryBufferPercent / 100.0;
      data.breakBuffer = data.breakBody * breakEntryBufferPercent / 100.0;
     }
   // Evaluate candle color
   bool              IsGreen(double open, double close) { return close > open; }
   bool              IsRed(double open, double close)   { return close < open; }
   // Evaluate rules for BUY or SELL
   RuleCheck         EvaluateRules(const CandleData &data, TradeDirection direction)
     {
      RuleCheck rules = {};

      double breakBand = direction == DIR_BUY ? data.bbLowerBreak : data.bbUpperBreak;
      double entryBand = direction == DIR_BUY ? data.bbLowerEntry : data.bbUpperEntry;

      // RSI threshold
      rules.BreakCandleRSIThresholdMet = direction == DIR_BUY
                                         ? (data.rsiBreak < rsiOversold)
                                         : (data.rsiBreak > rsiOverbought);

      // Band break condition
      rules.BreakCandleBreaksBand = direction == DIR_BUY
                                    ? (data.closeBreak < breakBand - data.breakBuffer)
                                    : (data.closeBreak > breakBand + data.breakBuffer);

      // Entry candle re-enter band
      rules.EntryCandleReentersBand = direction == DIR_BUY
                                      ? (data.closeEntry > entryBand + data.entryBuffer)
                                      : (data.closeEntry < entryBand - data.entryBuffer);

      // Candle colors
      rules.EntryCandleIsGreen = IsGreen(data.openEntry, data.closeEntry);
      rules.EntryCandleIsRed   = IsRed(data.openEntry, data.closeEntry);

      rules.BreakCandleIsGreen = IsGreen(data.openBreak, data.closeBreak);
      rules.BreakCandleIsRed   = IsRed(data.openBreak, data.closeBreak);

      // Entry body relative to middle BB
      rules.EntryBodyRelativeToMidBB = direction == DIR_BUY
                                       ? (data.closeEntry < data.bbMiddleEntry && data.openEntry < data.bbMiddleEntry)
                                       : (data.closeEntry > data.bbMiddleEntry && data.openEntry > data.bbMiddleEntry);

      return rules;
     }
   //
   string            FormatRuleLog(const RuleCheck &rules, const CandleData &data, TradeDirection direction)
     {
      double entryBand = direction == DIR_BUY ? data.bbLowerEntry : data.bbUpperEntry;
      double breakBand = direction == DIR_BUY ? data.bbLowerBreak : data.bbUpperBreak;

      string indent = "  ";
      string label  = direction == DIR_BUY ? "BUY Rules:" : "SELL Rules:";

      string rsiComp  = direction == DIR_BUY ? "<" : ">";
      string bandComp = direction == DIR_BUY ? "<" : ">";

      // --- Determine actual candle colors
      string breakActual = data.closeBreak > data.openBreak ? "GREEN" :
                           data.closeBreak < data.openBreak ? "RED" : "DOJI";

      string entryActual = data.closeEntry > data.openEntry ? "GREEN" :
                           data.closeEntry < data.openEntry ? "RED" : "DOJI";

      // --- Expected candle colors
      string breakExpected = direction == DIR_BUY ? "RED" : "GREEN";
      string entryExpected = direction == DIR_BUY ? "GREEN" : "RED";

      // --- Color rule results
      bool breakColorPass = direction == DIR_BUY ? rules.BreakCandleIsRed : rules.BreakCandleIsGreen;
      bool entryColorPass = direction == DIR_BUY ? rules.EntryCandleIsGreen : rules.EntryCandleIsRed;

      // --- Mid BB description
      string midBBDesc;

      if(rules.EntryBodyRelativeToMidBB)
         midBBDesc = direction == DIR_BUY ?
                     "Candle body entirely below Mid BB" :
                     "Candle body entirely above Mid BB";
      else
         midBBDesc = direction == DIR_BUY ?
                     "Candle body not entirely below Mid BB" :
                     "Candle body not entirely above Mid BB";

      return StringFormat(
                "%s%s\n"
                "%sBreakCandle RSI Met:     %-4s | RSI: %.2f | Threshold: %s %d\n"
                "%sBreakCandle Band Break:  %-4s | Close: %.5f | Threshold: %s %.5f\n"
                "%sBreakCandle Color:       %-4s | Expected: %s | Actual: %s | Open: %.5f Close: %.5f\n"
                "%sEntryCandle Color:       %-4s | Expected: %s | Actual: %s | Open: %.5f Close: %.5f\n"
                "%sEntryCandle Re-enter BB: %-4s | Close: %.5f | Threshold: %s %.5f\n"
                "%sEntry vs Mid BB:         %-4s | Close: %.5f Open: %.5f Mid BB: %.5f | %s",

                indent, label,

                indent, rules.BreakCandleRSIThresholdMet ? "PASS" : "FAIL",
                data.rsiBreak, rsiComp, direction == DIR_BUY ? rsiOversold : rsiOverbought,

                indent, rules.BreakCandleBreaksBand ? "PASS" : "FAIL",
                data.closeBreak, bandComp, breakBand,

                indent, breakColorPass ? "PASS" : "FAIL",
                breakExpected, breakActual, data.openBreak, data.closeBreak,

                indent, entryColorPass ? "PASS" : "FAIL",
                entryExpected, entryActual, data.openEntry, data.closeEntry,

                indent, rules.EntryCandleReentersBand ? "PASS" : "FAIL",
                data.closeEntry, direction == DIR_BUY ? ">" : "<", entryBand,

                indent, rules.EntryBodyRelativeToMidBB ? "PASS" : "FAIL",
                data.closeEntry, data.openEntry, data.bbMiddleEntry, midBBDesc
             );
     }
   //
   SignalResult      BuildSignal(const CandleData &data, const RuleCheck &rules, TradeDirection direction)
     {
      SignalResult result= {};
      result.type = direction==DIR_BUY?SIGNAL_BUY:SIGNAL_SELL;
      result.entryPrice = data.closeEntry;

      // SL anchor: nearest structure level between break and entry
      double slAnchorPrice = direction == DIR_BUY
                             ? MathMin(data.closeBreak, data.closeEntry)
                             : MathMax(data.closeBreak, data.closeEntry);

      double slBufferPrice = slBufferPoints * _Point;
      // Apply buffer to SL anchor to get final stop loss
      double bufferedSLPrice = 0.0;
      if(direction == DIR_BUY)
         bufferedSLPrice = slAnchorPrice - slBufferPrice;
      else
         bufferedSLPrice = slAnchorPrice + slBufferPrice;
      result.stopLossPrice  = bufferedSLPrice;

      double riskPrice = MathAbs(data.closeEntry - bufferedSLPrice);
      result.stopLossPoints = riskPrice / _Point;

      if(result.stopLossPoints<minSLPoints || result.stopLossPoints>maxSLPoints)
        {
         result.type = SIGNAL_NONE;
         result.message = StringFormat("%s SL out of range | %.1f pts | Allowed %.1f-%.1f",
                                       direction==DIR_BUY?"BUY":"SELL",
                                       result.stopLossPoints,minSLPoints,maxSLPoints);
         return result;
        }

      // Take profit
      double rawTPPrice = data.closeEntry + (direction==DIR_BUY?1:-1)*riskPrice*riskReward;
      double bbTPPrice = direction==DIR_BUY?bollingerBands.GetUpper(1):bollingerBands.GetLower(1);
      result.takeProfitPrice  = useBBTP ? (direction==DIR_BUY?MathMax(bbTPPrice,rawTPPrice):MathMin(bbTPPrice,rawTPPrice)) : rawTPPrice;
      result.takeProfitPoints = MathAbs(result.takeProfitPrice-data.closeEntry)/_Point;

      result.message = StringFormat(
                          "%s signal | Entry: %.5f | SL: %.5f (%.1f pts) | TP: %.5f (%.1f pts) | RR: %.2f | BB L: %.5f M: %.5f U: %.5f | RSI: %.2f\n%s",
                          direction==DIR_BUY?"BUY":"SELL",
                          result.entryPrice,result.stopLossPrice,result.stopLossPoints,
                          result.takeProfitPrice,result.takeProfitPoints,
                          result.stopLossPoints>0?result.takeProfitPoints/result.stopLossPoints:0,
                          data.bbLowerEntry,data.bbMiddleEntry,data.bbUpperEntry,
                          data.rsiBreak,
                          FormatRuleLog(rules,data,direction)
                       );
      return result;
     }
   //
   SignalResult      BuildNoSignal(const CandleData &data,const RuleCheck &buyRules,const RuleCheck &sellRules)
     {
      SignalResult result= {};
      result.type=SIGNAL_NONE;
      result.message = StringFormat("No trade conditions met\n%s\n%s",
                                    FormatRuleLog(buyRules,data,DIR_BUY),
                                    FormatRuleLog(sellRules,data,DIR_SELL));
      return result;
     }
   //
public:
   //
                     CStrategySignalService(CBollingerBands &_bollingerBands,CRSIIndicator &_rsi,string _symbol,ENUM_TIMEFRAMES _tf)
      :              bollingerBands(_bollingerBands), rsi(_rsi), symbol(_symbol), timeframe(_tf)
     {}

   // Configure strategy parameters
   void              Configure(int _rsiOversold,int _rsiOverbought,double _breakEntryBufferPercent,
                               bool _useBBTP,double _riskReward,double _minSLPoints,double _maxSLPoints, double _slBufferPoints)
     {
      rsiOversold             = _rsiOversold;
      rsiOverbought           = _rsiOverbought;
      breakEntryBufferPercent = _breakEntryBufferPercent;
      useBBTP                 = _useBBTP;
      riskReward              = _riskReward;
      minSLPoints             = _minSLPoints;
      maxSLPoints             = _maxSLPoints;
      slBufferPoints          = _slBufferPoints;
     }
   //
   SignalResult      GetSignal()
     {
      CandleData data;
      ReadCandleData(data);

      RuleCheck buyRules  = EvaluateRules(data,DIR_BUY);
      RuleCheck sellRules = EvaluateRules(data,DIR_SELL);

      bool buySignal = buyRules.BreakCandleRSIThresholdMet && buyRules.BreakCandleBreaksBand &&
                       buyRules.EntryCandleReentersBand && buyRules.EntryCandleIsGreen &&
                       buyRules.BreakCandleIsRed && buyRules.EntryBodyRelativeToMidBB;

      bool sellSignal = sellRules.BreakCandleRSIThresholdMet && sellRules.BreakCandleBreaksBand &&
                        sellRules.EntryCandleReentersBand && sellRules.EntryCandleIsRed &&
                        sellRules.BreakCandleIsGreen && sellRules.EntryBodyRelativeToMidBB;

      if(buySignal)
         return BuildSignal(data,buyRules,DIR_BUY);
      if(sellSignal)
         return BuildSignal(data,sellRules,DIR_SELL);

      return BuildNoSignal(data,buyRules,sellRules);
     }
  };

#endif
//+------------------------------------------------------------------+
