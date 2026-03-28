//+------------------------------------------------------------------+
//| BollingerBandsDivergenceDetector.mqh                             |
//| Detects aggressive Bollinger Band expansion (divergence)         |
//| Automatically uses last closed candle as entry point             |
//|                                                                  |
//| © 2026 JF Software Services Ltd                                  |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_BANDS__DIVERGENCE_DETECTOR__
#define __BOLLINGER_BANDS__DIVERGENCE_DETECTOR__
//
#include "../CommonLibs/Indicators/BollingerBands.mqh"
#include "VisualAngleCalculator.mqh"
//
struct BBandsDivergenceResult
  {
   bool              diverging;                     // True if bands diverge aggressively
   double            upperBandAngle;                // Angle of upper band (degrees)
   double            lowerBandAngle;                // Angle of lower band (degrees)
  };
//
class CBollingerBandsDivergenceDetector
  {
private:
   string              m_symbol;
   ENUM_TIMEFRAMES     m_tf;
   CBollingerBands     m_bollingerBands; // reference
public:
                     CBollingerBandsDivergenceDetector(string symbol,
                                     ENUM_TIMEFRAMES tf,
                                     CBollingerBands &bollingerBands)
      :              m_symbol(symbol),
                     m_tf(tf),
                     m_bollingerBands(bollingerBands)
     {}
   //+------------------------------------------------------------------+
   //| AnalyzeBandDivergence                                            |
   //| Detects aggressive expansion: upper up, lower down               |
   //| Automatically uses last closed candle as entry point             |
   //+------------------------------------------------------------------+
   BBandsDivergenceResult AnalyzeBandDivergence(
      int breakCandleShift,          // how far back the "break" candle is
      double angleThreshold)
     {
      BBandsDivergenceResult result = {false, 0.0, 0.0};
      if(breakCandleShift < 1)
         return result;
      CVisualAngleCalculator angleCalc;
      int shiftBreak = breakCandleShift;
      // Newest point: last closed candle (entry candle)
      int shiftEntry = 1;
      datetime tBreak = iTime(m_symbol, m_tf, shiftBreak);
      datetime tEntry = iTime(m_symbol, m_tf, shiftEntry);
      double upperBreak = m_bollingerBands.GetUpper(shiftBreak);
      double upperEntry = m_bollingerBands.GetUpper(shiftEntry);
      double lowerBreak = m_bollingerBands.GetLower(shiftBreak);
      double lowerEntry = m_bollingerBands.GetLower(shiftEntry);
      double upperAngle = angleCalc.GetAngle(tBreak, upperBreak, tEntry, upperEntry);
      double lowerAngle = angleCalc.GetAngle(tBreak, lowerBreak, tEntry, lowerEntry);
      result.upperBandAngle = upperAngle;
      result.lowerBandAngle = lowerAngle;
      // Divergence: upper rising, lower falling, both above threshold
      result.diverging =
         (upperAngle > angleThreshold) &&
         (lowerAngle < -angleThreshold);
      return result;
     }
  };
#endif
//+------------------------------------------------------------------+
