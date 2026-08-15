/**
 * Trio Glance View
 *
 * Displays glucose data in the Garmin glance menu.
 * Shows SGV value, direction arrow symbol, and loop status in a compact format.
 *
 * @author Trio Development Team
 * @version 1.2 (Using simple text symbols for direction)
 */

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Time;

(:glance)
class TrioGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    /**
     * Update the glance view
     * Called whenever the glance should be refreshed
     */
    function onUpdate(dc as Dc) as Void {
        var statusRaw = Application.Storage.getValue("status");
        var status = statusRaw as Dictionary;
        if (statusRaw instanceof Array) {
            // Status is an array, take the first value
            if (statusRaw.size() > 0) {
                status = statusRaw[0] as Dictionary;
            }
        }
        
        var glucoseText = "--";
        var glucoseValue = 0;
        var hasGlucose = false;
        var iobText = "--";
        var loopMinutes = -1;

        if (status instanceof Dictionary) {
            // Get glucose value
            var glucose = status["sgv"];
            if (GlucoseUnits.isNumeric(glucose)) {
                glucoseValue = glucose;
                hasGlucose = true;
                glucoseText = GlucoseUnits.formatValue(glucose, status);
            }
            
            // Get IOB value
            var iob = status["iob"];
            if (iob instanceof Number || iob instanceof Float || iob instanceof Double) {
                iobText = iob.format("%2.1f") + "U";
            } else if (iob != null) {
                iobText = iob.toString() + "U";
            }
            
            // Calculate loop minutes
            var lastLoopDate = status["date"];
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
        }
        
        // Format loop text
        var loopText;
        if (loopMinutes < 0) {
            loopText = "--";
        } else if (loopMinutes == 0) {
            loopText = "<1m ago";
        } else {
            loopText = loopMinutes.format("%d") + "m ago";
        }
        
        // Clear background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        var height = dc.getHeight();
        var centerY = height / 2;
        
        // Determine glucose color from the shared thresholds (mg/dL), so the
        // glance agrees with the arc gauge and the trend graph. Without a
        // reading, stay neutral rather than colouring a placeholder zero.
        var glucoseColor = hasGlucose
            ? GlucoseThresholds.getColor(glucoseValue)
            : Graphics.COLOR_LT_GRAY;
        
        // Draw glucose value (left, vertically centered, color-coded)
        dc.setColor(glucoseColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(10, centerY, Graphics.FONT_LARGE, glucoseText,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Draw IOB value (after glucose, vertically centered)
        var glucoseWidth = dc.getTextWidthInPixels(glucoseText, Graphics.FONT_LARGE);
        var iobX = glucoseWidth + 20;
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(iobX, centerY, Graphics.FONT_MEDIUM, iobText,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // Draw loop status below IOB (smaller font, gray color)
        var iobFontHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var loopY = centerY + (iobFontHeight / 2) + 5;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(iobX, loopY, Graphics.FONT_XTINY, loopText,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    
}