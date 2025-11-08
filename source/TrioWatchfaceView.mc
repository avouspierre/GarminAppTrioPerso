/**
 * Trio Watchface View
 * 
 * Main display view for Trio diabetes management watchface.
 * Renders glucose data, insulin information, and system status.
 * 
 * LAYOUT STRUCTURE:
 * - Top Section: IOB (left), Middle metric (center), TBR/EventualBG (right)
 * - Middle Section: Delta (left), Glucose+Arrow (center), Loop status (right)
 * - Bottom Section: Time, Date, Heart Rate, Battery (from layout XML)
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
 * SCREEN / FONT CALCULATIONS:
 * - Baseline alignment for consistent text positioning
 * - Proportional spacing relative to screen width
 * - Dynamic font selection based on screen size
 * - Adaptive icon positioning with proper spacing
 * 
 * DYNAMIC PLACEMENT:
 * - Center-based positioning for middle metric
 * - Edge-based positioning for side elements
 * - Available space calculation for flexible layout
 * - Icon and text grouping for visual cohesion
 * 
 * @author Trio Development Team
 * @version 2.0 (Energy Optimized)
 */

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.Time.Gregorian as Calendar;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Time;
import Sura.Device;
import Sura.Datetime;

class TrioWatchfaceView extends WatchUi.WatchFace {

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

    /**
     * Font definition used for rendering the primary time digits on the watch face.
     *
     * Type: Graphics.FontDefinition
     * Default: Graphics.FONT_NUMBER_MEDIUM
     *
     * This setting controls the font family and size used when drawing the time.
     * Change to another Graphics.FONT_* constant to alter size/appearance. Ensure
     * the chosen font is available on the target device and remains legible at
     * the watch's screen resolution.
     *
     * Typical usage:
     *  - Passed to Graphics.setFont() before drawing time text
     *  - Supplied to Graphics.drawText() when rendering numeric time values
     */
    var timeFontSize as Graphics.FontDefinition = Graphics.FONT_NUMBER_MEDIUM;
    var smallFont = Graphics.FONT_XTINY;
    var smallFontSize = Graphics.getFontHeight(smallFont);
    
    var offsetX as Number = 50;
    
    /**
     * Flag indicating if the watch face is in low power mode.
     * When true, the watch face will use minimal power consumption settings.
     * @var {Boolean} isLowPowerMode
     */
    var isLowPowerMode = false;
    
    /**
     * Constructor
     * Loads all bitmap resources to avoid repeated loading during updates
     */
    function initialize() {
        WatchFace.initialize();
        
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
     * These values never change during watchface lifetime.
     * 
     * @param dc Drawing context for metric queries
     */
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
        
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
     * Previous implementation called helper functions that each performed
     * their own dictionary lookups, resulting in significant overhead.
     * 
     * @param dc Drawing context for rendering
     */
    function onUpdate(dc as Dc) as Void {
        var status = Application.Storage.getValue("status") as Dictionary;

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

        Datetime.init();

        //setTime();
        setDate();
        setHeartRate();
        setSteps();
        
        View.onUpdate(dc);
        
        drawTopSection(dc, statusData);
        drawMiddleSection(dc, statusData);

         //draw the time
        drawTime(dc);

    }

    /*
     * drawTime(dc as Dc) as Void
     *
     * Draws the watch face time elements (hours/minutes and, when enabled, seconds)
     * onto the provided drawing context.
     *
     * Parameters:
     *   dc  - Dc object representing the drawing context used to render text and
     *         shapes on the device screen.
     *
     * Behavior:
     *   - Sets the drawing color to white with a transparent background.
     *   - Chooses vertical centering for text alignment.
     *   - Renders the main time string (hours and minutes) using a numeric font.
     *     The horizontal position of the main time is offset from the right edge
     *     of the screen; the exact offset scales depending on whether the selected
     *     font is the "hot" numeric font.
     *   - If the watch is not in low power mode (self.isLowPowerMode == false),
     *     renders the seconds as a smaller text element slightly below the
     *     vertical center line.
     *
     * Notes:
     *   - AM/PM rendering is present in the source but currently commented out.
     *   - Positioning uses Device.screenSize and Device.screenCenter to adapt to
     *     different screen sizes and orientations.
     *   - This function has visible side effects: it draws directly to the
     *     provided Dc and thus must be invoked only from appropriate drawing
     *     callbacks (eg. onUpdate or paint handlers).
     *
     * Side Effects:
     *   - Modifies the provided drawing context (dc) by drawing text elements.
     *
     * Assumptions:
     *   - Variables such as offsetX, smallFont, smallFontSize, and self.isLowPowerMode
     *     are available in the enclosing scope.
     *   - Datetime.getTimeText() and Datetime.getSecondsText() return formatted
     *     strings suitable for display.
     */
    function drawTime(dc as Dc) as Void {
            var textAlign = Graphics.TEXT_JUSTIFY_VCENTER;
            var timeFontSize = Graphics.FONT_NUMBER_HOT;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

            // Time
            dc.drawText(
            Device.screenSize.x -
                offsetX * (timeFontSize == Graphics.FONT_NUMBER_HOT ? 1.9 : 0.75),
            Device.screenCenter.y*1.11,
            timeFontSize,
            Datetime.getTimeText(),
            textAlign
            );

            // // AM/PM
            // dc.drawText(
            // Device.screenSize.x - 10,
            // Device.screenCenter.y - smallFontSize / 2,
            // smallFont,
            // Datetime.getAmPm(),
            // textAlign
            // );

            if (!self.isLowPowerMode) {
            // Seconds
            dc.drawText(
                Device.screenSize.x - 50,
                Device.screenCenter.y + smallFontSize / 2,
                smallFont,
                Datetime.getSecondsText(),
                textAlign
            );
        }
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
     * Displays glucose value with arc graph, delta, and units.
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
            Device.screenCenter.x
        );

        var glucoseFont = Graphics.FONT_NUMBER_MILD;
        var deltaFont = Graphics.FONT_SYSTEM_TINY;

        var glucoseText = "--";
        var deltaText = "--";
        var glucose = 40;
       
        var glucoseHeight =  cachedFontMetrics["glucoseHeight"]; 
        var deltaHeight =   cachedFontMetrics["deltaHeight"];
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


        var glucoseX = screenWidth * 0.35;
        var glucoseY = (screenHeight * 0.1);
        var glucoseWidth = dc.getTextWidthInPixels(glucoseText, Graphics.FONT_NUMBER_MILD) as Number;

        dc.setColor(primaryColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(glucoseX , 
                    glucoseY, 
                    glucoseFont, 
                    glucoseText, 
                    Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(glucoseX  + glucoseWidth + screenWidth * 0.03,
                    glucoseY + (glucoseHeight - deltaHeight) * 0.5,
                    deltaFont,
                    deltaText,
                    Graphics.TEXT_JUSTIFY_LEFT);    
        
    }

    /**
     * Middle section renderer
     * 
     * Displays IOB, middle metric (sensRatio/isf/cob), glucose trend arrow,
     * and loop status indicator based on data age.
     * 
     * @param dc Drawing context
     * @param statusData Extracted data dictionary
     */
    function drawMiddleSection(dc as Dc, statusData) as Void {
        var primaryColor = getApp().getProperty("PrimaryColor") as Number;

        var iobValue = "--";
        var middleValue = "";
        var loopMinutes = -1;
        
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

         var textY = screenHeight * 0.33;


        // display IOB
        var viewIOB = View.findDrawableById("IOBLabel") as Text;
        viewIOB.setText(iobValue + "U");

        
        // display glucose arrow
        var viewArrow = View.findDrawableById("ISFIcon");
        viewArrow.locX = -100;
        var arrowBitmap = getDirectionBitmap(statusData);
        if (arrowBitmap != null) {
            dc.drawBitmap(screenWidth *0.4, textY*0.9, arrowBitmap);
        }

        // display middle value
        var middleLabel = View.findDrawableById("COBLabel") as Text;
        middleLabel.setColor(primaryColor);
        middleLabel.setText(middleValue);   

    
        // display loop minutes and loop status indicator          
        var loopText;
        if (loopMinutes < 0) {
            loopText = "--";
        } else if (loopMinutes == 0) {
            loopText = "<1";
        } else {
            loopText = loopMinutes.format("%d");
        }
        var loopHeight = cachedFontMetrics["loopHeight"];
      

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            screenWidth *0.83,
            textY,
            Graphics.FONT_XTINY,
            loopText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
        

        var loopColor = getLoopColor(loopMinutes);
        dc.setColor(loopColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(6);
        dc.drawCircle(screenWidth *0.85, textY, loopHeight * 0.5);

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

    function onExitSleep() as Void {
        self.isLowPowerMode = false;
    }

    function onEnterSleep() as Void {
        self.isLowPowerMode = true;
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
