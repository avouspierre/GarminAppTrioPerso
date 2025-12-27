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
 * 3. Font Metrics Caching: Font measurements done once at layout
 * 4. Dictionary Optimization: All data extracted once per update
 *
 * @author Trio Development Team
 * @version 3.0 (Widget with Optimized Layout)
 */

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.Time.Gregorian as Calendar;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Sura.Device;

class TrioView extends WatchUi.View {

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
     * ENERGY OPTIMIZATION: Cached font metrics
     * Measured once at layout to avoid repeated font metric calculations
     */
    private var cachedFontMetrics = null;

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
     * Caches screen dimensions and font metrics to eliminate repeated queries.
     * These values never change during widget lifetime.
     *
     * @param dc Drawing context for metric queries
     */
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
        
        screenWidth = dc.getWidth();
        screenHeight = dc.getHeight();
        
        var mainFont = Graphics.FONT_MEDIUM;
        var unitFont = Graphics.FONT_XTINY;
        var glucoseFont = Graphics.FONT_NUMBER_MILD;
        var deltaFont = Graphics.FONT_SYSTEM_TINY;
        var secondaryFont = Graphics.FONT_TINY;
        
        cachedFontMetrics = {
            "mainHeight" => dc.getFontHeight(mainFont),
            "mainDescent" => dc.getFontDescent(mainFont),
            "unitHeight" => dc.getFontHeight(unitFont),
            "unitDescent" => dc.getFontDescent(unitFont),
            "glucoseHeight" => dc.getFontHeight(glucoseFont),
            "glucoseDescent" => dc.getFontDescent(glucoseFont),
            "deltaHeight" => dc.getFontHeight(deltaFont),
            "deltaDescent" => dc.getFontDescent(deltaFont),
            "loopHeight" => dc.getFontHeight(secondaryFont),
            "loopDescent" => dc.getFontDescent(secondaryFont)
        };

         Device.init(dc);
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
        if (statusData instanceof Dictionary) {
            var unitsHint = statusData["units_hint"];
            return (unitsHint != null && unitsHint.equals("mmol"));
        }
        return false;
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
        if (value instanceof Number) {
            if (isMMOL(statusData)) {
                return value * 0.05556;
            }
            return value.toFloat();
        }
        return 0.0;
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

        var BGGraph;
        BGGraph = new ArcGoalView({
            :direction => Graphics.ARC_CLOCKWISE,
            :color => Graphics.COLOR_DK_BLUE,
            :position => "top",
        });

        var arcGraphRadius = Device.screenCenter.getMin() - 8;
            BGGraph.setPosition(
            Device.screenCenter.x,
            Device.screenCenter.y
        );

        // Use larger font for glucose display
        var glucoseFont = Graphics.FONT_NUMBER_HOT;
        var deltaFont = Graphics.FONT_LARGE;

        var glucoseText = "--";
        var deltaText = "--";
        var glucose = 40;
        
        var primaryColor = getApp().getProperty("PrimaryColor") as Number;
      
         
        BGGraph.setRadius(arcGraphRadius);
        if (statusData instanceof Dictionary) {
            glucose = statusData["sgv"];
            if (glucose instanceof Number || glucose instanceof Float || glucose instanceof Double) {
                var convertedValue = convertGlucoseValue(glucose, statusData);
                if (isMMOL(statusData)) {
                    glucoseText = convertedValue.format("%2.1f");
                } else {
                    glucoseText = convertedValue.format("%d");
                }
            }

            var delta = statusData["delta"];
            if (delta instanceof Number || delta instanceof Float || delta instanceof Double) {
                var convertedValue = convertGlucoseValue(delta, statusData);
                var sign = (delta >= 0) ? "+" : "";
                if (isMMOL(statusData)) {
                    deltaText = sign + convertedValue.format("%2.1f");
                } else {
                    deltaText = sign + convertedValue.format("%d");
                }
            }
        }
        BGGraph.setData({ :value => glucose, :goal => 220 });
        BGGraph.draw(dc);

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
                if (isf instanceof Number || isf instanceof Float || isf instanceof Double) {
                    var convertedValue = convertGlucoseValue(isf, statusData);
                    if (isMMOL(statusData)) {
                        middleValue = convertedValue.format("%2.1f");
                    } else {
                        middleValue = convertedValue.format("%d");
                    }
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
                    if (isf instanceof Number || isf instanceof Float || isf instanceof Double) {
                        var convertedValue = convertGlucoseValue(isf, statusData);
                        if (isMMOL(statusData)) {
                            middleValue = convertedValue.format("%2.1f");
                        } else {
                            middleValue = convertedValue.format("%d");
                        }
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
        System.println("sgvArray: " + sgvArray );
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
        
        // Draw dotted lines for sgv = 180 and sgv = 70
        var y180 = graphY.toFloat() + graphHeight.toFloat() - ((180.toFloat() - 40.toFloat()) / (310.toFloat() - 40.toFloat())) * graphHeight.toFloat();
        var y70 = graphY.toFloat() + graphHeight.toFloat() - ((70.toFloat() - 40.toFloat()) / (310.toFloat() - 40.toFloat())) * graphHeight.toFloat();
        
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        for (var x = graphX.toFloat(); x < graphX.toFloat() + graphWidth.toFloat(); x += 5) {
            dc.drawLine(x, y180, x + 2, y180);
            dc.drawLine(x, y70, x + 2, y70);
        }
         
        // Draw SGV data points
        var maxSGV = 310.0;
        var minSGV = 40.0;
        var maxDate = Time.now().value().toLong() * 1000;// Time.now().value().toLong() * 1000;
        var minDate = sgvArray[0]["date"];
        
        // Find the actual max and min dates in the array
        for (var j = 1; j < sgvArray.size(); j++) {
            var currentDate = sgvArray[j]["date"];
            if (currentDate < minDate) {
                minDate = currentDate;
            }
        }
        
        System.println("maxDate: " + maxDate + " minDate: " + minDate ); 
        // Draw data points and lines
        var x=0;
        var y=0;
        for (var i = 0; i < sgvArray.size(); i++) {
            var sgv = sgvArray[i]["sgv"];
            var currentDate = sgvArray[i]["date"];
            if (sgv instanceof Number) {
                x = graphX + ((currentDate.toFloat() - minDate.toFloat()) / (maxDate.toFloat() - minDate.toFloat()) * graphWidth);
                y = graphY + graphHeight - ((sgv - minSGV) / (maxSGV - minSGV)) * graphHeight;
                
                // Draw data point
                if (sgv >= 70 && sgv <= 180) {
                    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
                } else {
                    dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                }
                dc.fillCircle(x, y, 5);
            }
        }
    }

    
    /**
     * Date display updater
     * Formats and displays current date (weekday, day, month)
     */
    function setDate() as Void {
        var now = Time.now();
        var info = Calendar.info(now, Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$ $2$.$3$", [info.day_of_week, info.day, info.month]);

        var view = View.findDrawableById("DateLabel") as TextArea;
        view.setColor(getApp().getProperty("PrimaryColor") as Number);
        view.setText(dateStr);
    }

    /**
     * Heart rate display updater
     * Retrieves and displays current heart rate from activity sensor
     */
    function setHeartRate() as Void {
        var info = Activity.getActivityInfo();
        var hr = info.currentHeartRate;

        var hrString = (hr == null) ? "--" : hr.toString();

        var view = View.findDrawableById("HRLabel") as Text;
        view.setText(hrString);
    }

    /**
     * Battery level display updater
     * Retrieves and displays current battery percentage
     */
    function setSteps() as Void {
        var myStats = System.getSystemStats();
        var batlevel = myStats.battery;
        var batString = Lang.format( "$1$%", [ batlevel.format( "%2d" ) ] );

        var view = View.findDrawableById("StepsLabel") as Text;
        view.setText(batString);
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