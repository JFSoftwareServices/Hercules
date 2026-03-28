//+----------------------------------------------------------------------------+
//|  TimeExclusionFilter.mqh                                                   |
//|  Utility class to block trading during specified time ranges.              |
//|  Handles ranges crossing midnight.                                         |
//|  Supports both numeric (HH,MM) and string ("HH:MM-HH:MM") initialization.  |
//|  Times are broker time.                                                    |
//|                                                                            |
//| © 2026 JF Software Services Ltd                                            |
//+----------------------------------------------------------------------------+
#include "../CommonLibs/Core/Logger.mqh"
class CTimeExclusionFilter
  {
private:
   int               m_startMinutes;   // Start time in minutes from midnight
   int               m_endMinutes;     // End time in minutes from midnight

   //+------------------------------------------------------------------+
   //| Convert hours and minutes into total minutes since midnight      |
   //| Params:                                                          |
   //|   hour   - hour part (0-23)                                      |
   //|   minute - minute part (0-59)                                    |
   //| Returns: total minutes since 00:00                               |
   //+------------------------------------------------------------------+
   int               ToMinutes(int hour, int minute)
     {
      return hour * 60 + minute;
     }
   //
public:
   //+------------------------------------------------------------------+
   //| Numeric constructor: specify start/end hours and minutes         |
   //| Params:                                                          |
   //|   startHour   - Start hour of exclusion period (0-23)            |
   //|   startMinute - Start minute of exclusion period (0-59)          |
   //|   endHour     - End hour of exclusion period (0-23)              |
   //|   endMinute   - End minute of exclusion period (0-59)            |
   //+------------------------------------------------------------------+
                     CTimeExclusionFilter(int startHour, int startMinute, int endHour, int endMinute)
     {
      m_startMinutes = ToMinutes(startHour, startMinute);
      m_endMinutes   = ToMinutes(endHour, endMinute);
     }
   //+------------------------------------------------------------------+
   //| String constructor: parses "HH:MM-HH:MM"                         |
   //| Example: "23:30-07:45"                                           |
   //+------------------------------------------------------------------+
                     CTimeExclusionFilter(string range)
     {
      int dashPos = StringFind(range, "-");
      if(dashPos == -1 || StringLen(range) < 11)
        {
         Logger::Instance().Error("Invalid time range format: " + range);
         m_startMinutes = 0;
         m_endMinutes   = 0;
         return;
        }
      string startStr = StringSubstr(range, 0, dashPos);
      string endStr   = StringSubstr(range, dashPos + 1);
      int startHour   = (int)StringToInteger(StringSubstr(startStr, 0, 2));
      int startMinute = (int)StringToInteger(StringSubstr(startStr, 3, 2));
      int endHour     = (int)StringToInteger(StringSubstr(endStr, 0, 2));
      int endMinute   = (int)StringToInteger(StringSubstr(endStr, 3, 2));
      m_startMinutes = ToMinutes(startHour, startMinute);
      m_endMinutes   = ToMinutes(endHour, endMinute);
     }
   //+------------------------------------------------------------------+
   //| Get current time in minutes since midnight                       |
   //| Returns: total minutes since 00:00                               |
   //+------------------------------------------------------------------+
   int               GetCurrentMinutes()
     {
      datetime now = TimeCurrent();  // broker time
      MqlDateTime timeStruct;
      TimeToStruct(now, timeStruct);
      return ToMinutes(timeStruct.hour, timeStruct.min);
     }
   //+------------------------------------------------------------------+
   //| Check if current time falls inside the exclusion period          |
   //| Returns: true if trading is blocked, false otherwise             |
   //+------------------------------------------------------------------+
   bool              IsExcluded()
     {
      int nowMin = GetCurrentMinutes();

      // Normal range (does not cross midnight)
      if(m_startMinutes < m_endMinutes)
         return (nowMin >= m_startMinutes && nowMin <= m_endMinutes);

      // Crosses midnight (e.g., 23:30 → 07:45)
      else
         return (nowMin >= m_startMinutes || nowMin <= m_endMinutes);
     }
   //+------------------------------------------------------------------+
   //| Convenience method: Is trading allowed at current time?          |
   //| Returns: true if trading is allowed, false if blocked            |
   //+------------------------------------------------------------------+
   bool              IsTradingAllowed()
     {
      return !IsExcluded();
     }
   //+------------------------------------------------------------------+
   //| Get current exclusion state as a string with HH:MM times         |
   //+------------------------------------------------------------------+
   string            GetStatusString()
     {
      // Convert minutes to HH:MM
      int startHour = m_startMinutes / 60;
      int startMin  = m_startMinutes % 60;
      int endHour   = m_endMinutes / 60;
      int endMin    = m_endMinutes % 60;

      int nowMinTotal = GetCurrentMinutes();
      int nowHour = nowMinTotal / 60;
      int nowMin  = nowMinTotal % 60;

      string status = "TimeExclusionFilter: Start=" + IntegerToString(startHour) + ":" + (startMin < 10 ? "0" : "") + IntegerToString(startMin) +
                      " End=" + IntegerToString(endHour) + ":" + (endMin < 10 ? "0" : "") + IntegerToString(endMin) +
                      " Now=" + IntegerToString(nowHour) + ":" + (nowMin < 10 ? "0" : "") + IntegerToString(nowMin) +
                      " Excluded=" + (IsExcluded() ? "true" : "false");

      return status;
     }
  };
//+------------------------------------------------------------------+
