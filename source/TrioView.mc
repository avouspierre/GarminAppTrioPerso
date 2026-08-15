/**
 * Trio Widget View
 *
 * Main display view for Trio diabetes management widget.
 * Renders glucose data, insulin information, and system status.
 *
 * LAYOUT STRUCTURE:
 * - Top Section: Glucose arc graph centered on screen
 *   - Glucose value (large font, centered at 35% height)
 *   - Delta value (to the right of glucose value)
 * - Bottom Section (at 70% height):
 *   - IOB (15% width, left)
 *   - Direction arrow bitmap (46% width, center)
 *   - Middle metric - COB/ISF/sensRatio (65% width, center-right)
 *   - Loop status circle with minutes inside (88% width, right)
 *
 * DATA INTERFACE:
 * Receives data from Application.Storage["status"] containing:
 * - sgv: Sensor glucose value (mg/dL)
 * - delta: Change in glucose (mg/dL)
 * - direction: Trend arrow (Flat, SingleUp, DoubleUp, etc.)
 * - iob: Insulin on board (units)
 * - tbr: Temporary basal rate multiplier
 * - cob: Carbs on board (grams)
 * - eventualBG: Predicted glucose (mg/dL)
 * - isf: Insulin sensitivity factor
 * - sensRatio: Sensitivity ratio
 * - units_hint: Unit system ("mgdl" or "mmol")
 * - displayDataType1: Middle metric selector ("cob", "isf", "sensRatio")
 * - displayDataType2: Right metric selector ("tbr", "eventualBG")
 * - date: Last update timestamp (ms since epoch)
 *
 * ENERGY OPTIMIZATION FEATURES:
 * 1. Bitmap Caching: Direction arrows loaded once at init
 * 2. Dimension Caching: Screen size queried once at layout
 * 3. Dictionary Optimization: All data extracted once per update
 *
 * @author Trio Development Team
 * @version 3.0 (Widget with Optimized Layout)
 */

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;
import Sura.Device;

class TrioView extends WatchUi.View {

    /**
     * Radius of a plotted glucose point, in pixels.
     *
     * Doubles as the vertical margin of the plot area: glucoseToY() insets
     * the usable range by this much at each end so a point sitting on the
     * scale limit still draws entirely inside the frame.
     */
    const GRAPH_POINT_RADIUS = 5;

    /**
     * ENERGY OPTIMIZATION: Cached direction arrow bitmaps
     * Loaded once at initialization to avoid repeated file I/O and decompression
     */
    private var directionBitmaps = null;
    
    /**
     * ENERGY OPTIMIZATION: Cached screen dimensions
     * Queried once at layout to avoid repeated API calls
     */
    private var screenWidth = 0;
    private var screenHeight = 0;

    /**
     * ENERGY OPTIMIZATION: Cached glucose arc gauge
     * Built once at layout and reused every frame. Its geometry depends only
     * on screen size, so nothing about it changes between updates - only the
     * value it displays does.
     */
    private var bgGraph as ArcGoalView? = null;

    var timeFontSize as Graphics.FontDefinition = Graphics.FONT_NUMBER_MEDIUM;
    var smallFont = Graphics.FONT_XTINY;
    var smallFontSize = Graphics.getFontHeight(smallFont);
    
    var offsetX as Number = 50;
    
    /**
     * Constructor
     * Loads all bitmap resources to avoid repeated loading during updates
     */
    function initialize() {
        View.initialize();
        
        directionBitmaps = {
            "Unknown" => WatchUi.loadResource(Rez.Drawables.Unknown),
            "Flat" => WatchUi.loadResource(Rez.Drawables.Flat),
            "SingleUp" => WatchUi.loadResource(Rez.Drawables.SingleUp),
            "SingleDown" => WatchUi.loadResource(Rez.Drawables.SingleDown),
            "FortyFiveUp" => WatchUi.loadResource(Rez.Drawables.FortyFiveUp),
            "FortyFiveDown" => WatchUi.loadResource(Rez.Drawables.FortyFiveDown),
            "DoubleUp" => WatchUi.loadResource(Rez.Drawables.DoubleUp),
            "DoubleDown" => WatchUi.loadResource(Rez.Drawables.DoubleDown)
        };
    }

    /**
     * Layout initialization handler
     *
     * SCREEN CALCULATION OPTIMIZATION:
     * Caches screen dimensions to eliminate repeated queries.
     * These values never change during widget lifetime.
     *
     * @param dc Drawing context for metric queries
     */
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
        
        screenWidth = dc.getWidth();
        screenHeight = dc.getHeight();

        Device.init(dc);

        // Build the arc gauge once, now that the screen geometry is known.
        // onLayout may run again (e.g. on a settings change), so reapply the
        // geometry rather than rebuilding the object.
        if (bgGraph == null) {
            bgGraph = new ArcGoalView({
                :direction => Graphics.ARC_CLOCKWISE,
                :color => Graphics.COLOR_DK_BLUE,
                :position => "top",
            });
        }

        bgGraph.setPosition(Device.screenCenter.x, Device.screenCenter.y);
        bgGraph.setRadius(Device.screenCenter.getMin() - 8);
    }

    function onShow() as Void {
    }

    /**
     * Main update handler
     *
     * DATA EXTRACTION OPTIMIZATION:
     * Extracts all required values from storage dictionary ONCE to minimize
     * repeated dictionary key lookups. Creates a working copy for functions.
     *
     * @param dc Drawing context for rendering
     */
    function onUpdate(dc as Dc) as Void {
        var statusRaw = Application.Storage.getValue("status");
        var status = statusRaw as Dictionary;
        var allSGVValue = [] as Array;
        if (statusRaw instanceof Array) {
            // Status is an array, take the first value
            if (statusRaw.size() > 0) {
                status = statusRaw[0] as Dictionary;
                allSGVValue = statusRaw;
            }
        }

        var statusData = null;
        
        if (status instanceof Dictionary) {
            statusData = {
                "sgv" => status["sgv"],
                "delta" => status["delta"],
                "direction" => status["direction"],
                "iob" => status["iob"],
                "tbr" => status["tbr"],
                "cob" => status["cob"],
                "eventualBG" => status["eventualBG"],
                "isf" => status["isf"],
                "sensRatio" => status["sensRatio"],
                "units_hint" => status["units_hint"],
                "displayDataType1" => status["displayPrimaryAttributeChoice"],
                "displayDataType2" => status["displaySecondaryAttributeChoice"],
                "date" => status["date"]
            };
        }

        View.onUpdate(dc);
        
        drawTopSection(dc, statusData);
        drawMiddleSection(dc, statusData,allSGVValue);

    }



    /**
     * Unit system detector
     *
     * @param statusData Extracted data dictionary
     * @return true if mmol/L units, false if mg/dL
     */
    function isMMOL(statusData) as Boolean {
        return GlucoseUnits.isMMOL(statusData);
    }

    /**
     * Glucose value unit converter
     *
     * Converts mg/dL values to mmol/L when required.
     * Conversion factor: 1 mg/dL = 0.05556 mmol/L
     *
     * @param value Glucose value in mg/dL
     * @param statusData Data dictionary for unit detection
     * @return Converted value (mmol/L if indicated, otherwise mg/dL)
     */
    function convertGlucoseValue(value, statusData) as Float {
        return GlucoseUnits.convert(value, statusData);
    }
    
    /**
     * Top section renderer
     *
     * Displays glucose value with arc graph centered on screen.
     * - Glucose value: Large font (FONT_NUMBER_HOT) at 35% height
     * - Delta value: Positioned to the right of glucose value
     * - Arc graph: Centered using Device.screenCenter
     *
     * @param dc Drawing context
     * @param statusData Extracted data dictionary
     */
    function drawTopSection(dc as Dc, statusData) as Void {

        // Use larger font for glucose display
        var glucoseFont = Graphics.FONT_NUMBER_HOT;
        var deltaFont = Graphics.FONT_LARGE;

        var glucoseText = "--";
        var deltaText = "--";
        // Validated up front: the arc must never receive a non-numeric value.
        var glucose = getArcValue(statusData);

        var primaryColor = getApp().getProperty("PrimaryColor") as Number;


        if (statusData instanceof Dictionary) {
            var sgv = statusData["sgv"];
            if (GlucoseUnits.isNumeric(sgv)) {
                glucoseText = GlucoseUnits.formatValue(sgv, statusData);
            }

            var delta = statusData["delta"];
            if (GlucoseUnits.isNumeric(delta)) {
                var sign = (delta >= 0) ? "+" : "";
                deltaText = sign + GlucoseUnits.formatValue(delta, statusData);
            }
        }

        // Reuses the gauge built at layout; only the value changes per frame.
        // Guarded in case a draw somehow precedes onLayout - the readings
        // below still render without the gauge.
        if (bgGraph != null) {
            bgGraph.setData({ :value => glucose });
            bgGraph.draw(dc);
        }

        // Center the glucose value horizontally and vertically
        var glucoseY = screenHeight * 0.35;
        
        // Calculate glucose text width to position delta to the right
        var glucoseWidth = dc.getTextWidthInPixels(glucoseText, glucoseFont);
        var glucoseX = (screenWidth - glucoseWidth) / 2 - screenWidth * 0.1;

        dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(glucoseX,
                    glucoseY,
                    glucoseFont,
                    glucoseText,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Display delta to the right of glucose value
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(glucoseX + glucoseWidth + screenWidth * 0.05,
                    glucoseY,
                    deltaFont,
                    deltaText,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
         
    }

    /**
     * Bottom section renderer (at 70% height)
     *
     * Displays four metrics in a horizontal row:
     * - IOB: Blue text at 15% width (left)
     * - Direction arrow: Bitmap at 46% width (center)
     * - Middle metric: COB/ISF/sensRatio at 65% width (center-right)
     * - Loop status: Colored circle (25px radius) with minutes text inside at 88% width (right)
     *
     * Loop circle color indicates data freshness:
     * - Green: 0-7 minutes, Yellow: 8-12 minutes, Red: >12 minutes, Gray: No data
     *
     * @param dc Drawing context
     * @param statusData Extracted data dictionary
     */
    function drawMiddleSection(dc as Dc, statusData, sgvArray) as Void {
        var primaryColor = getApp().getProperty("PrimaryColor") as Number;

        var iobValue = "--";
        var middleValue = "";
        var loopMinutes = -1;
         
        // Draw SGV graph if sgvArray is available
        
        if (sgvArray != null && sgvArray.size() > 0) {
            drawSGVGraph(dc, sgvArray);
        }
         
        if (statusData instanceof Dictionary) {
            var iob = statusData["iob"];
            if (iob instanceof Number || iob instanceof Float || iob instanceof Double) {
                iobValue = iob.format("%2.1f");
            } else if (iob != null) {
                iobValue = iob.toString();
            }

            var lastLoopDate = statusData["date"];
            if (lastLoopDate != null) {
                var lastLoopMs = lastLoopDate.toLong();
                var lastLoopSeconds = lastLoopMs / 1000;
                var now = Time.now().value();
                var deltaSeconds = now - lastLoopSeconds;
                 
                if (deltaSeconds <= 0) {
                    loopMinutes = 0;
                } else {
                    loopMinutes = (deltaSeconds / 60).toNumber();
                }
            }

            var dataType1 = statusData["displayDataType1"];
            if (dataType1 != null && dataType1.equals("sensRatio")) {
                var sensRatio = statusData["sensRatio"];
                if (sensRatio instanceof Number || sensRatio instanceof Float || sensRatio instanceof Double) {
                    middleValue = sensRatio.format("%2.2f");
                } else if (sensRatio != null) {
                    middleValue = sensRatio.toString();
                } else {
                    middleValue = "--";
                }

            } else if (dataType1 != null && dataType1.equals("isf")) {
                var isf = statusData["isf"];
                if (GlucoseUnits.isNumeric(isf)) {
                    middleValue = GlucoseUnits.formatValue(isf, statusData);
                } else if (isf != null) {
                    middleValue = isf.toString();
                } else {
                    middleValue = "--";
                }

            } else if (dataType1 != null && dataType1.equals("cob")) {
                var cob = statusData["cob"];
                if (cob instanceof Number || cob instanceof Float || cob instanceof Double) {
                    middleValue = cob.format("%d") +"g";
                } else if (cob != null) {
                    middleValue = cob.toString() + "g";
                } else {
                    middleValue = "--";
                }
            } else {
                var sensRatio = statusData["sensRatio"];
                var cob = statusData["cob"];
                var isf = statusData["isf"];
                
                if (cob != null) {
                    if (cob instanceof Number || cob instanceof Float || cob instanceof Double) {
                        middleValue = cob.format("%d") +"g" ;
                    } else {
                        middleValue = cob.toString() + "g";
                    }
    
                } else if (isf != null) {
                    if (GlucoseUnits.isNumeric(isf)) {
                        middleValue = GlucoseUnits.formatValue(isf, statusData);
                    } else {
                        middleValue = isf.toString();
                    }

                } else if (sensRatio != null) {
                    if (sensRatio instanceof Number || sensRatio instanceof Float || sensRatio instanceof Double) {
                        middleValue = sensRatio.format("%2.2f");
                    } else {
                        middleValue = sensRatio.toString();
                    }

                } else {
                    middleValue = "--";
         
                }
            }
        } else {
            middleValue = "--";

        }

         var textY = screenHeight * 0.8;
         var largeFont = Graphics.FONT_LARGE;

        // Display IOB on the left (larger)
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenWidth * 0.3, textY, largeFont, iobValue + "U",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Display glucose arrow in center
        var arrowBitmap = getDirectionBitmap(statusData);
        if (arrowBitmap != null) {
            dc.drawBitmap(screenWidth * 0.52, textY - 15, arrowBitmap);
        }

        // Display middle value (COB/ISF/sensRatio) in center-right
        dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(screenWidth * 0.75, textY, largeFont, middleValue,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Display loop status indicator on the right with circle
        var loopText;
        if (loopMinutes < 0) {
            loopText = "--";
        } else if (loopMinutes == 0) {
            loopText = "<1";
        } else {
            loopText = loopMinutes.format("%d");
        }

        var loopX = screenWidth * 0.5;
        var loopY = screenHeight * 0.15;
        var circleRadius = 25;
        
        // Draw the colored circle first with thicker border
        var loopColor = getLoopColor(loopMinutes);
        dc.setColor(loopColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawCircle(loopX, loopY, circleRadius);
         
        // Draw the loop minutes text centered inside the circle with smaller font
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(loopX, loopY,
                    Graphics.FONT_TINY,
                    loopText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    }

    /**
     * Direction arrow bitmap provider
     *
     * ENERGY OPTIMIZATION: Uses pre-loaded cached bitmaps
     * Maps trend strings to cached bitmap resources.
     * Triple arrows mapped to double arrows (visual simplification).
     *
     * @param statusData Pre-extracted data dictionary
     * @return Bitmap resource for current trend direction
     */
    function getDirectionBitmap(statusData) as BitmapType {
        if (statusData instanceof Dictionary) {
            var trend = statusData["direction"] as String;
            if (trend != null) {
                if (trend.equals("TripleUp")) {
                    return directionBitmaps["DoubleUp"];
                } else if (trend.equals("TripleDown")) {
                    return directionBitmaps["DoubleDown"];
                } else if (directionBitmaps.hasKey(trend)) {
                    return directionBitmaps[trend];
                }
            }
        }
        return directionBitmaps["Unknown"];
    }
    
    /**
     * Loop status color mapper
     *
     * Determines status indicator color based on data age:
     * - <0: No data (gray)
     * - 0-7: Current (green)
     * - 8-12: Slightly stale (yellow)
     * - >12: Stale (red)
     *
     * @param min Minutes since last update
     * @return Color constant for status indicator
     */
    function getLoopColor(min as Number) as Number {
        if (min < 0) {
            return Graphics.COLOR_LT_GRAY;
        } else if (min <= 7) {
            return Graphics.COLOR_GREEN;
        } else if (min <= 12) {
            return Graphics.COLOR_YELLOW;
        } else {
            return Graphics.COLOR_RED;
        }
    }
    
    /**
     * Draws the SGV graph using the sgvArray data
     *
     * @param dc Drawing context
     * @param sgvArray Array of SGV data points
     */
    function drawSGVGraph(dc as Dc, sgvArray) as Void {
        var graphWidth = screenWidth * 0.8;
        var graphHeight = screenHeight * 0.2;
        var graphX = (screenWidth - graphWidth) / 2;
        var graphY = screenHeight * 0.5;
        
        // Draw graph background
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(graphX, graphY, graphWidth, graphHeight);
        
        // Draw graph axes
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(graphX, graphY, graphX, graphY + graphHeight); // Y-axis
        dc.drawLine(graphX, graphY + graphHeight, graphX + graphWidth, graphY + graphHeight); // X-axis
        
        // Draw dotted lines marking the target range bounds
        var yHigh = glucoseToY(GlucoseThresholds.HIGH, graphY, graphHeight);
        var yLow = glucoseToY(GlucoseThresholds.LOW, graphY, graphHeight);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        for (var x = graphX.toFloat(); x < graphX.toFloat() + graphWidth.toFloat(); x += 5) {
            dc.drawLine(x, yHigh, x + 2, yHigh);
            dc.drawLine(x, yLow, x + 2, yLow);
        }

        // Draw SGV data points
        var maxDate = Time.now().value().toLong() * 1000;// Time.now().value().toLong() * 1000;

        // Find the oldest usable date in the array.
        // Entries with a missing or non-numeric date are skipped rather than
        // crashing the render: the array comes from the phone and is untrusted.
        var minDate = null;
        for (var j = 0; j < sgvArray.size(); j++) {
            var currentDate = getEntryDate(sgvArray[j]);
            if (currentDate != null && (minDate == null || currentDate < minDate)) {
                minDate = currentDate;
            }
        }

        // Nothing plottable: leave the empty grid drawn above.
        if (minDate == null) {
            return;
        }

        // Time span of the graph. Zero or negative when the array holds a single
        // entry, or when the phone clock is ahead of the watch - guarded below
        // so the ratio is never a division by zero.
        var dateSpan = (maxDate - minDate).toFloat();

        // Draw data points and lines
        var x=0;
        var y=0;
        for (var i = 0; i < sgvArray.size(); i++) {
            var currentDate = getEntryDate(sgvArray[i]);
            if (currentDate == null) {
                continue;
            }

            var sgv = sgvArray[i]["sgv"];
            if (sgv instanceof Number) {
                // Subtract as Long before converting: raw ms timestamps exceed
                // Float precision (~131s granularity at 1.7e12).
                var ratio = 1.0;
                if (dateSpan > 0) {
                    ratio = (currentDate - minDate).toFloat() / dateSpan;
                    if (ratio < 0.0) {
                        ratio = 0.0;
                    } else if (ratio > 1.0) {
                        ratio = 1.0;
                    }
                }

                x = graphX + (ratio * graphWidth);
                y = glucoseToY(sgv, graphY, graphHeight);

                // Draw data point, coloured by its glucose zone
                dc.setColor(GlucoseThresholds.getColor(sgv), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, GRAPH_POINT_RADIUS);
            }
        }
    }

    /**
     * Safe arc value resolver
     *
     * The arc gauge drives its needle from this value, and getGlucoseDegree()
     * clamps it via toFloat() - which returns null for a String, crashing the
     * comparison that follows. The status payload comes from the phone and is
     * untrusted, so the value is validated here, before it reaches the gauge,
     * rather than guarded at each point of use.
     *
     * @param statusData Extracted data dictionary
     * @return Glucose value in mg/dL, or ARC_MIN when there is no usable one
     */
    function getArcValue(statusData as Object?) as Numeric {
        if (statusData instanceof Dictionary) {
            var sgv = statusData["sgv"];
            if (GlucoseUnits.isNumeric(sgv)) {
                return sgv as Numeric;
            }
        }

        // No reading: park the indicator at the bottom of the scale.
        return GlucoseThresholds.ARC_MIN;
    }

    /**
     * Glucose to graph Y coordinate mapper
     *
     * Projects a glucose value onto the trend graph's vertical axis, which
     * spans GRAPH_MIN..GRAPH_MAX. Low values map to the bottom of the plot.
     *
     * @param value Glucose value in mg/dL
     * @param graphY Top edge of the plot area
     * @param graphHeight Height of the plot area
     * @return Y coordinate for that value
     */
    function glucoseToY(value as Numeric, graphY as Numeric, graphHeight as Numeric) as Float {
        var minSGV = GlucoseThresholds.GRAPH_MIN.toFloat();
        var maxSGV = GlucoseThresholds.GRAPH_MAX.toFloat();

        // Clamp to the plotted scale. A reading past either bound would
        // otherwise be drawn outside the frame, on top of the rest of the
        // screen. Out-of-scale points pin to the edge instead - they keep
        // their own zone colour, so a 350 still reads as severely high.
        var clamped = value.toFloat();
        if (clamped < minSGV) {
            clamped = minSGV;
        } else if (clamped > maxSGV) {
            clamped = maxSGV;
        }

        var ratio = (clamped - minSGV) / (maxSGV - minSGV);

        // Inset the usable range by one point radius at each end, so a value
        // sitting on a scale limit draws its full disc inside the frame
        // rather than half of it outside. Falls back to the raw height on a
        // plot too short to carry the margins.
        var margin = GRAPH_POINT_RADIUS.toFloat();
        var usableHeight = graphHeight.toFloat() - (2 * margin);
        if (usableHeight <= 0) {
            margin = 0.0;
            usableHeight = graphHeight.toFloat();
        }

        return graphY.toFloat() + margin + usableHeight - (ratio * usableHeight);
    }

    /**
     * Safe timestamp extractor for a glucose entry
     *
     * The status array is pushed by the phone and may contain malformed
     * entries (not a dictionary, missing "date", or a non-numeric date).
     * Reading such an entry directly crashes the graph renderer on comparison
     * or arithmetic, so all access goes through this accessor.
     *
     * @param entry Candidate glucose entry from the status array
     * @return Timestamp in milliseconds, or null when unusable
     */
    function getEntryDate(entry) as Long or Null {
        if (!(entry instanceof Dictionary)) {
            return null;
        }

        var date = entry["date"];
        if (date instanceof Number || date instanceof Long ||
            date instanceof Float || date instanceof Double) {
            return date.toLong();
        }

        return null;
    }


    function onHide() as Void {
    }

    /**
     * Clears the device context screen by setting it to black
     * @param dc The device context to clear
     * @return Void
     */
      function clearScreen(dc as Dc) as Void {
         dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
         dc.clear();
     }
}