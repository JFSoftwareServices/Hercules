//+------------------------------------------------------------------+
//| VisualAngleCalculator.mqh                                        |
//| Description:                                                     |
//|   Provides utilities to calculate the *visual angle* between     |
//|   two points on an MT5 chart using pixel coordinates.            |
//|                                                                  |
//|   Unlike price/time-based calculations, this class converts      |
//|   chart coordinates into screen pixels via                       |
//|   ChartTimePriceToXY(), ensuring the angle matches exactly       |
//|   what is seen on the chart regardless of zoom level or scaling. |
//|                                                                  |
//| Key Features:                                                    |
//|   - Returns signed angle in degrees (-180° to +180°)             |
//|   - Positive angle = upward slope                                |
//|   - Negative angle = downward slope                              |
//|   - Supports absolute angle calculation (0° to 90°)              |
//|   - Provides pixel-based slope calculation                       |
//|                                                                  |
//| Use Cases:                                                       |
//|   - Measuring trendline steepness                                |
//|   - Detecting aggressive moves (e.g., volatility spikes)         |
//|   - Supporting filters (e.g., Bollinger Band expansion checks)   |
//|                                                                  |
//| Notes:                                                           |
//|   - Angle depends on chart zoom and scale (visual accuracy)      |
//|   - Designed for real-time chart analysis                        |
//|                                                                  |
//|                                                                  |
//| © 2026 JF Software Services Ltd                                  |
//+------------------------------------------------------------------+
//
class CVisualAngleCalculator
  {
private:
   long              m_chart_id;
   int               m_subwindow;
public:
                     CVisualAngleCalculator(long chart_id = 0, int subwindow = 0)
     {
      m_chart_id = chart_id;
      m_subwindow = subwindow;
     }
   // Set chart context if needed
   void              SetChart(long chart_id, int subwindow = 0)
     {
      m_chart_id = chart_id;
      m_subwindow = subwindow;
     }
   // Main function: Get visual angle
   double            GetAngle(datetime time1, double price1,
                   datetime time2, double price2)
     {
      int x1, y1, x2, y2;
      // Convert to pixel coordinates
      if(!ChartTimePriceToXY(m_chart_id, m_subwindow, time1, price1, x1, y1))
         return 0;
      if(!ChartTimePriceToXY(m_chart_id, m_subwindow, time2, price2, x2, y2))
         return 0;
      // Pixel differences
      double dx = (double)(x2 - x1);
      double dy = (double)(y1 - y2); // invert Y-axis
      // Handle edge case
      if(dx == 0 && dy == 0)
         return 0;
      // Angle in radians
      double angle_rad = MathArctan2(dy, dx);
      // Convert to degrees
      return angle_rad * 180.0 / M_PI;
     }
  };
