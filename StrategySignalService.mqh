//+---------------------------------------------------------------------+
//|                                      CStrategySignalService.mqh     |
//| PURPOSE: Generate BUY/SELL signals using pre-initialized indicators |
//+---------------------------------------------------------------------+

#ifndef __BOLLINGER_RSI_SIGNAL__
#define __BOLLINGER_RSI_SIGNAL__

#include "../CommonLibs/Indicators/BollingerBands.mqh"
#include "../CommonLibs/Indicators/RSIIndicator.mqh"
#include "../CommonLibs/Core/Logger.mqh"

enum SignalType
  {
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL
  };

struct SignalResult
  {
   SignalType        type;
   double            entryPrice;
   double            stopLossPoints;
   double            takeProfitPoints;
   double            stopLossPrice;
   double            takeProfitPrice;
   string            message;
  };
//
class CStrategySignalService
  {
private:
   CBollingerBands   bollingerBands;
   CRSIIndicator     rsi;

   int               rsiOverbought;
   int               rsiOversold;

   double            breakEntryBufferPercent;
   // % of candle body used as Bollinger Band buffer.
   // Requires price to move slightly beyond the band before triggering a trade.

   bool              useBBTP;        // true = take profit at opposite Bollinger Band

   double            riskReward;     // Risk-reward ratio for TP when not using Bollinger Band TP
   double            minSLPoints;    // Minimum allowed stop loss distance (points)
   double            maxSLPoints;    // Maximum allowed stop loss distance (points)

   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   //
   bool              CheckBuyConditions(double closeEntry, double openEntry, double closeBreak, double openBreak,
                                        double bbLowerEntry, double bbMiddleEntry, double bbLowerBreak,
                                        double rsiBreak, double breakBuffer, double entryBuffer)
     {
      bool buyRSI          = rsiBreak < rsiOversold;
      bool buyBreakBelow   = closeBreak < bbLowerBreak - breakBuffer;
      bool buyEntryAbove   = closeEntry > bbLowerEntry + entryBuffer;
      bool buyEntryGreen   = closeEntry > openEntry;
      bool buyBreakRed     = closeBreak < openBreak;
      bool buyBodyBelowMid = closeEntry < bbMiddleEntry && openEntry < bbMiddleEntry;

      return buyRSI && buyBreakBelow && buyEntryAbove && buyEntryGreen && buyBreakRed && buyBodyBelowMid;
     }

   bool              CheckSellConditions(double closeEntry, double openEntry, double closeBreak, double openBreak,
                                         double bbUpperEntry, double bbMiddleEntry, double bbUpperBreak,
                                         double rsiBreak, double breakBuffer, double entryBuffer)
     {
      bool sellRSI          = rsiBreak > rsiOverbought;
      bool sellBreakAbove   = closeBreak > bbUpperBreak + breakBuffer;
      bool sellEntryBelow   = closeEntry < bbUpperEntry - entryBuffer;
      bool sellEntryRed     = closeEntry < openEntry;
      bool sellBreakGreen   = closeBreak > openBreak;
      bool sellBodyAboveMid = closeEntry > bbMiddleEntry && openEntry > bbMiddleEntry;

      return sellRSI && sellBreakAbove && sellEntryBelow && sellEntryRed && sellBreakGreen && sellBodyAboveMid;
     }

   SignalResult      BuildBuySignal(double closeEntry)
     {
      SignalResult result;
      result.type = SIGNAL_BUY;
      result.entryPrice = closeEntry;

      double stopLossPrice = GetBuyStopLoss();
      double stopLossPoints = MathAbs(closeEntry - stopLossPrice) / _Point;

      if(stopLossPoints < minSLPoints || stopLossPoints > maxSLPoints)
        {
         result.type = SIGNAL_NONE;
         result.message = StringFormat(
                             "BUY SL out of range | SL: %.1f pts | Allowed: %.1f - %.1f pts",
                             stopLossPoints, minSLPoints, maxSLPoints
                          );
         return result;
        }

      double takeProfitPrice = useBBTP ? bollingerBands.GetUpper(1) : closeEntry + (closeEntry - stopLossPrice) * riskReward;
      double takeProfitPoints = MathAbs(takeProfitPrice - closeEntry) / _Point;

      result.stopLossPrice = stopLossPrice;
      result.stopLossPoints = stopLossPoints;
      result.takeProfitPrice = takeProfitPrice;
      result.takeProfitPoints = takeProfitPoints;
      result.message = StringFormat(
                          "BUY signal | Entry: %.5f | SL: %.5f (%.1f pts) | TP: %.5f (%.1f pts)",
                          result.entryPrice, result.stopLossPrice, result.stopLossPoints,
                          result.takeProfitPrice, result.takeProfitPoints
                       );
      return result;
     }

   SignalResult      BuildSellSignal(double closeEntry)
     {
      SignalResult result;
      result.type = SIGNAL_SELL;
      result.entryPrice = closeEntry;

      double stopLossPrice = GetSellStopLoss();
      double stopLossPoints = MathAbs(stopLossPrice - closeEntry) / _Point;

      if(stopLossPoints < minSLPoints || stopLossPoints > maxSLPoints)
        {
         result.type = SIGNAL_NONE;
         result.message = StringFormat(
                             "SELL SL out of range | SL: %.1f pts | Allowed: %.1f - %.1f pts",
                             stopLossPoints, minSLPoints, maxSLPoints
                          );
         return result;
        }

      double takeProfitPrice = useBBTP ? bollingerBands.GetLower(1) : closeEntry - (stopLossPrice - closeEntry) * riskReward;
      double takeProfitPoints = MathAbs(takeProfitPrice - closeEntry) / _Point;

      result.stopLossPrice = stopLossPrice;
      result.stopLossPoints = stopLossPoints;
      result.takeProfitPrice = takeProfitPrice;
      result.takeProfitPoints = takeProfitPoints;
      result.message = StringFormat(
                          "SELL signal | Entry: %.5f | SL: %.5f (%.1f pts) | TP: %.5f (%.1f pts)",
                          result.entryPrice, result.stopLossPrice, result.stopLossPoints,
                          result.takeProfitPrice, result.takeProfitPoints
                       );
      return result;
     }

   double            GetBuyStopLoss()
     {
      // Entry candle index = 1
      // Break candle index = 2
      double entryLow = iLow(symbol, timeframe, 1);
      double breakLow = iLow(symbol, timeframe, 2);

      // Minimum of the two
      return MathMin(entryLow, breakLow);
     }

   double            GetSellStopLoss()
     {
      // Entry candle index = 1
      // Break candle index = 2
      double entryHigh = iHigh(symbol, timeframe, 1);
      double breakHigh = iHigh(symbol, timeframe, 2);

      // Maximum of the two for SELL stop-loss
      return MathMax(entryHigh, breakHigh);
     }

public:
                     CStrategySignalService(CBollingerBands &_bollingerBands,
                          CRSIIndicator &_rsi,
                          string _symbol,
                          ENUM_TIMEFRAMES _tf)
      :              bollingerBands(_bollingerBands), rsi(_rsi), symbol(_symbol), timeframe(_tf)
     {
     }

   void              Configure(int _rsiOversold, int _rsiOverbought, double _breakEntryBufferPercent,
                               bool _useBBTP, double _riskReward, double _minSLPoints, double _maxSLPoints)
     {
      rsiOversold             = _rsiOversold;
      rsiOverbought           = _rsiOverbought;
      breakEntryBufferPercent = _breakEntryBufferPercent;
      useBBTP                 = _useBBTP;
      riskReward              = _riskReward;
      minSLPoints             = _minSLPoints;
      maxSLPoints             = _maxSLPoints;
     }
   SignalResult      GetSignal()
     {
      SignalResult result;
      result.type = SIGNAL_NONE;

      // --- Candle & indicator values ---
      double closeEntry = iClose(symbol, timeframe, 1);
      double openEntry  = iOpen(symbol, timeframe, 1);
      double closeBreak = iClose(symbol, timeframe, 2);
      double openBreak  = iOpen(symbol, timeframe, 2);

      double bbLowerEntry  = bollingerBands.GetLower(1);
      double bbMiddleEntry = bollingerBands.GetMiddle(1);
      double bbUpperEntry  = bollingerBands.GetUpper(1);

      double bbLowerBreak  = bollingerBands.GetLower(2);
      double bbUpperBreak  = bollingerBands.GetUpper(2);

      double rsiBreak = rsi.GetValue(2);

      double entryBody = MathAbs(closeEntry - openEntry);
      double entryBuffer = entryBody * breakEntryBufferPercent / 100.0;

      double breakBody = MathAbs(closeBreak - openBreak);
      double breakBuffer = breakBody * breakEntryBufferPercent / 100.0;

      // --- Individual rule checks for logging ---
      bool buyRSI          = rsiBreak < rsiOversold;
      bool buyBreakBelow   = closeBreak < bbLowerBreak - breakBuffer;
      bool buyEntryAbove   = closeEntry > bbLowerEntry + entryBuffer;
      bool buyEntryGreen   = closeEntry > openEntry;
      bool buyBreakRed     = closeBreak < openBreak;
      bool buyBodyBelowMid = closeEntry < bbMiddleEntry && openEntry < bbMiddleEntry;

      bool sellRSI          = rsiBreak > rsiOverbought;
      bool sellBreakAbove   = closeBreak > bbUpperBreak + breakBuffer;
      bool sellEntryBelow   = closeEntry < bbUpperEntry - entryBuffer;
      bool sellEntryRed     = closeEntry < openEntry;
      bool sellBreakGreen   = closeBreak > openBreak;
      bool sellBodyAboveMid = closeEntry > bbMiddleEntry && openEntry > bbMiddleEntry;

      // --- Calculate signals using helper methods ---
      bool buySignal  = CheckBuyConditions(
                           closeEntry, openEntry, closeBreak, openBreak,
                           bbLowerEntry, bbMiddleEntry, bbLowerBreak,
                           rsiBreak, breakBuffer, entryBuffer
                        );

      bool sellSignal = CheckSellConditions(
                           closeEntry, openEntry, closeBreak, openBreak,
                           bbUpperEntry, bbMiddleEntry, bbUpperBreak,
                           rsiBreak, breakBuffer, entryBuffer
                        );

      Logger::Instance().Debug(
         StringFormat(
            "Signal Details\n"
            "  Entry: C=%.5f O=%.5f B=%.5f Buf=%.5f | Break: C=%.5f O=%.5f B=%.5f Buf=%.5f\n"
            "  BB Entry: L=%.5f M=%.5f U=%.5f | BB Break: L=%.5f U=%.5f | RSI Break: %.2f\n"
            "  BUY Rules: RSI[%s] BreakBelow[%s] EntryAbove[%s] EntryGreen[%s] BreakRed[%s] BodyBelowMid[%s]\n"
            "  SELL Rules: RSI[%s] BreakAbove[%s] EntryBelow[%s] EntryRed[%s] BreakGreen[%s] BodyAboveMid[%s]\n"
            "  Signals: BUY[%s] SELL[%s]",
            closeEntry, openEntry, entryBody, entryBuffer,
            closeBreak, openBreak, breakBody, breakBuffer,
            bbLowerEntry, bbMiddleEntry, bbUpperEntry,
            bbLowerBreak, bbUpperBreak,
            rsiBreak,
            buyRSI?"PASS":"FAIL",
            buyBreakBelow?"PASS":"FAIL",
            buyEntryAbove?"PASS":"FAIL",
            buyEntryGreen?"PASS":"FAIL",
            buyBreakRed?"PASS":"FAIL",
            buyBodyBelowMid?"PASS":"FAIL",
            sellRSI?"PASS":"FAIL",
            sellBreakAbove?"PASS":"FAIL",
            sellEntryBelow?"PASS":"FAIL",
            sellEntryRed?"PASS":"FAIL",
            sellBreakGreen?"PASS":"FAIL",
            sellBodyAboveMid?"PASS":"FAIL",
            buySignal?"YES":"NO",
            sellSignal?"YES":"NO"
         )
      );

      if(buySignal)
         return BuildBuySignal(closeEntry);

      if(sellSignal)
         return BuildSellSignal(closeEntry);

      // --- No signal ---
      result.message = "No trade conditions met";
      return result;
     }
  };
#endif
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
