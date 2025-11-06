//**********************************************************************
// DESCRIPTION : Watch Faces for Trio
// AUTHORS :
//          Created by ivalkou - https://github.com/ivalkou
//          Modify by Pierre Lagarde - https://github.com/avouspierre
// COPYRIGHT : (c) 2023 ivalkou / Lagarde
//

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
using Toybox.Time.Gregorian as Calendar;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Time;

class TrioWatchfaceView extends WatchUi.WatchFace {
    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        System.println("onShow");
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {

        var status = Application.Storage.getValue("status") as Dictionary;

        setTime();
        setDate();
        setHeartRate();
        setSteps();
        
        // Set values
        setIOB(status);
        // Don't set COB text - we'll draw it manually
        setEventualBG(status);
        
        // Hide the COB label by setting it to empty
        var cobLabel = View.findDrawableById("COBLabel") as Text;
        if (cobLabel != null) {
            cobLabel.setText("");
        }
        
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        // NOW manually draw the middle section text and position icons
        drawMiddleSection(dc, status);
    }
    
    function drawMiddleSection(dc as Dc, status) as Void {
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        
        // Get font height to adjust icon positioning
        var fontHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var textY = screenHeight * 0.5;
        var iconY = textY - (fontHeight * 0.3);
        
        // Get the icons
        var isfIcon = View.findDrawableById("ISFIcon") as Bitmap;
        var eventualIcon = View.findDrawableById("EventualIcon") as Bitmap;
        
        // Get actual text values
        var iobString = getIOBString(status);
        var eventualString = getEventualBGString(status);
        
        // Determine middle string (COB or sensRatio)
        var middleString = "";
        var showingSensRatio = false;
        
        if (status instanceof Dictionary) {
            var sensRatio = status["sensRatio"];
            var cob = status["cob"];
            
            if (sensRatio != null) {
                middleString = getSensRatioString(status);
                showingSensRatio = true;
            } else if (cob != null) {
                middleString = getCOBString(status);
                showingSensRatio = false;
            } else {
                middleString = "--";
            }
        }
        
        // Calculate text widths
        var iobWidth = dc.getTextWidthInPixels(iobString, Graphics.FONT_MEDIUM);
        var middleWidth = dc.getTextWidthInPixels(middleString, Graphics.FONT_MEDIUM);
        var eventualWidth = dc.getTextWidthInPixels(eventualString, Graphics.FONT_MEDIUM);
        
        // Calculate positions with 2% margins instead of 5%
        var iconSpacing = screenWidth * 0.02;
        var margin = screenWidth * 0.02; // Reduced from 0.05 to 0.02
        
        var iobLeftEdge = margin; // 2% from left edge
        var iobRightEdge = iobLeftEdge + iobWidth;
        
        var eventualRightEdge = screenWidth - margin; // 2% from right edge (98% position)
        var eventualIconWidth = screenWidth * 0.06;
        var eventualIconLeftEdge = eventualRightEdge - eventualWidth - iconSpacing - eventualIconWidth;
        
        // Position eventual icon
        if (eventualIcon != null) {
            eventualIcon.locX = eventualIconLeftEdge;
            eventualIcon.locY = iconY;
        }
        
        // Calculate center of available space
        var availableCenter = (iobRightEdge + eventualIconLeftEdge) / 2;
        
        // Position ISF icon and draw middle text manually
        var isfIconWidth = screenWidth * 0.08;
        
        if (showingSensRatio) {
            // For sensRatio: icon + text should be centered as a unit
            // Calculate total width of icon + spacing + text
            var totalUnitWidth = isfIconWidth + iconSpacing + middleWidth;
            
            // Position icon at the start of the centered unit
            if (isfIcon != null) {
                isfIcon.locX = availableCenter - (totalUnitWidth / 2);
                isfIcon.locY = iconY;
            }
            
            // Text position is after icon + spacing
            var textX = availableCenter - (totalUnitWidth / 2) + isfIconWidth + iconSpacing + (middleWidth / 2);
            
            // Manually draw the middle text at the calculated position
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                textX,
                textY,
                Graphics.FONT_MEDIUM,
                middleString,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        } else {
            // For COB: same approach - icon + text centered as a unit
            var totalUnitWidth = isfIconWidth + iconSpacing + middleWidth;
            
            if (isfIcon != null) {
                isfIcon.locX = availableCenter - (totalUnitWidth / 2);
                isfIcon.locY = iconY;
            }
            
            var textX = availableCenter - (totalUnitWidth / 2) + isfIconWidth + iconSpacing + (middleWidth / 2);
            
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                textX,
                textY,
                Graphics.FONT_MEDIUM,
                middleString,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }
    }

    function setCOBorSensRatio(status) as Void {
        var view = View.findDrawableById("COBLabel") as Text;
        
        if (status instanceof Dictionary) {
            var sensRatio = status["sensRatio"];
            var cob = status["cob"];
            
            // Priority to sensRatio if both exist
            if (sensRatio != null) {
                view.setText(getSensRatioString(status));
                // Could update color here for sensRatio if desired
                // view.setColor(Graphics.COLOR_GREEN);
            } else if (cob != null) {
                view.setText(getCOBString(status));
                // view.setColor(Graphics.COLOR_YELLOW);
            } else {
                view.setText("--");
            }
        } else {
            view.setText("--");
        }
    }

    function adjustMiddleSectionPositions(dc as Dc, status) as Void {
        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        
        // Get font height to adjust icon positioning
        var fontHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        
        // Text is at 50% height, but icons need to be adjusted up by half font height
        // to align their centers with the text baseline
        var textY = screenHeight * 0.5;
        var iconY = textY - (fontHeight * 0.3);
        
        // Get the views - cast icons as Bitmap
        var iobLabel = View.findDrawableById("IOBLabel");
        var cobLabel = View.findDrawableById("COBLabel"); // This label shows either COB or sensRatio
        var isfIcon = View.findDrawableById("ISFIcon") as Bitmap;
        var eventualLabel = View.findDrawableById("EventualBGLabel");
        var eventualIcon = View.findDrawableById("EventualIcon") as Bitmap;
        
        // Get actual text values
        var iobString = getIOBString(status);
        var eventualString = getEventualBGString(status);
        
        // Determine if we're showing COB or sensRatio
        var middleString = "";
        var showingSensRatio = false;
        
        if (status instanceof Dictionary) {
            var sensRatio = status["sensRatio"];
            var cob = status["cob"];
            
            // Priority to sensRatio if both exist, or show whichever is available
            if (sensRatio != null) {
                middleString = getSensRatioString(status);
                showingSensRatio = true;
            } else if (cob != null) {
                middleString = getCOBString(status);
                showingSensRatio = false;
            } else {
                middleString = "--";
            }
        }
        
        // Calculate text widths
        var iobWidth = dc.getTextWidthInPixels(iobString, Graphics.FONT_MEDIUM);
        var middleWidth = dc.getTextWidthInPixels(middleString, Graphics.FONT_MEDIUM);
        var eventualWidth = dc.getTextWidthInPixels(eventualString, Graphics.FONT_MEDIUM);
        
        // Define spacing
        var iconSpacing = screenWidth * 0.02; // 2% space between icon and text
        
        // Position IOB (left-aligned at 5% margin)
        var iobLeftEdge = screenWidth * 0.05;
        if (iobLabel != null) {
            iobLabel.locX = iobLeftEdge; // Left edge at 5% (since it's left-justified)
        }
        var iobRightEdge = iobLeftEdge + iobWidth;
        
        // Position Eventual BG first to know its icon position
        var eventualRightEdge = screenWidth * 0.95;
        var eventualIconWidth = screenWidth * 0.06; // 6% as defined in layout.xml
        var eventualIconLeftEdge = eventualRightEdge - eventualWidth - iconSpacing - eventualIconWidth;
        
        if (eventualLabel != null && eventualIcon != null) {
            // Right-align the text at 95% of screen width
            eventualLabel.locX = eventualRightEdge; // Right edge at 95% (since it's right-justified)
            
            // Position icon to the left of eventual BG text
            eventualIcon.locX = eventualIconLeftEdge;
            eventualIcon.locY = iconY; // Adjusted up by half font height
        }
        
        // Now position middle element (COB or sensRatio) centered in the available space
        // Available space is between IOB right edge and eventual BG icon left edge
        var availableCenter = (iobRightEdge + eventualIconLeftEdge) / 2;
        
        // Debug: Let's verify the calculation
        System.println("IOB right edge: " + iobRightEdge);
        System.println("Eventual icon left edge: " + eventualIconLeftEdge);
        System.println("Available center: " + availableCenter);
        System.println("Screen center: " + (screenWidth / 2));
        
        if (cobLabel != null) {
            // Set position FIRST, before setText
            cobLabel.locX = availableCenter; // This should move it from screen center
            
            // Then set the text
            cobLabel.setText(middleString); // Update text to either COB or sensRatio
            
            if (showingSensRatio) {
                // For sensRatio: center position in available space with icon to its left
                cobLabel.locX = availableCenter; // Center in available space
                
                // Position icon to the left of sensRatio text
                if (isfIcon != null) {
                    var isfIconWidth = screenWidth * 0.08; // 8% as defined in layout.xml
                    isfIcon.locX = availableCenter - (middleWidth / 2) - iconSpacing - isfIconWidth;
                    isfIcon.locY = iconY; // Adjusted up by half font height
                }
                
            } else {
                // For COB: icon on left, text on right, both centered in available space
                if (isfIcon != null) {
                    var iconWidth = screenWidth * 0.08; // 8% as defined in layout.xml
                    var totalWidth = iconWidth + iconSpacing + middleWidth;
                    var startX = availableCenter - (totalWidth / 2);
                    
                    isfIcon.locX = startX;
                    isfIcon.locY = iconY; // Adjusted up by half font height
                    cobLabel.locX = availableCenter; // Center in available space
                }
            }
        }
    }
    
    function getIOBString(status) as String {
        if (status instanceof Dictionary) {
            var iob = status["iob"];
            if (iob instanceof Number) {
                return iob.format("%2.1f") + "U";
            } else if (iob != null) {
                return iob + "U";
            }
        }
        return "--";
    }
    
    function getCOBString(status) as String {
        if (status instanceof Dictionary) {
            var cob = status["cob"]; // actual COB value
            if (cob instanceof Number) {
                return cob.format("%3d") + "g";
            } else if (cob != null) {
                return cob.toString() + "g";
            }
        }
        return "--";
    }
    
    function getSensRatioString(status) as String {
        if (status instanceof Dictionary) {
            var sensRatio = status["sensRatio"]; // sensRatio value
            if (sensRatio instanceof Number) {
                return sensRatio.format("%2.1f");
            } else if (sensRatio != null) {
                return sensRatio.toString();
            }
        }
        return "--";
    }
    
    function getEventualBGString(status) as String {
        if (status instanceof Dictionary) {
            var ebg = status["eventualBGRaw"];
            if (ebg instanceof Number) {
                return ebg.format("%d");
            } else if (ebg != null) {
                return ebg.toString();
            }
        }
        return "--";
    }

    function setTime() as Void {
        // Get the current time and format it correctly
        var timeFormat = "$1$:$2$";
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        var suffix = "";
        if (!System.getDeviceSettings().is24Hour) {
            if (hours >= 12) {
                suffix = " PM";
                if (hours > 12) {
                    hours = hours - 12;
                    }
            } else {
                suffix = " AM";
            }
        } else {
            timeFormat = "$1$:$2$";
            hours = hours.format("%02d");
        }
        var timeString = Lang.format(timeFormat + suffix, [hours, clockTime.min.format("%02d")]);

        // Update the view
        var view = View.findDrawableById("TimeLabel") as TextArea;
        view.setColor(getApp().getProperty("PrimaryColor") as Number);
        view.setText(timeString);
    }

    function setDate() as Void {
        var now = Time.now();
        var info = Calendar.info(now, Time.FORMAT_MEDIUM);
        // var dateStr = info.day_of_week.substring(0,3) + " " + info.day + "." info.month + ".";
        var dateStr = Lang.format("$1$ $2$.$3$", [info.day_of_week, info.day, info.month]);

        var view = View.findDrawableById("DateLabel") as TextArea;
        view.setColor(getApp().getProperty("PrimaryColor") as Number);
        view.setText(dateStr);
    }

    function setHeartRate() as Void {
        var info = Activity.getActivityInfo();
        var hr = info.currentHeartRate;

        var hrString = (hr == null) ? "--" : hr.toString();

        var view = View.findDrawableById("HRLabel") as Text;
        view.setText(hrString);
    }

    function setSteps() as Void {

        var myStats = System.getSystemStats();
        var batlevel = myStats.battery;
        var batString = Lang.format( "$1$%", [ batlevel.format( "%2d" ) ] );

        var info =  ActivityMonitor.getInfo();
        var steps =   info.steps;
        var stepsString = (steps == null || steps == 0) ? "--" : steps.toString();

        var view = View.findDrawableById("StepsLabel") as Text;
        view.setText(batString);
    }

    function setIOB(status) as Void {
        var view = View.findDrawableById("IOBLabel") as Text;
        view.setText(getIOBString(status));
    }

    function setCOB(status) as Void {
        var view = View.findDrawableById("COBLabel") as Text;
        view.setText(getCOBString(status));
    }

    function setEventualBG(status) as Void {
        var view = View.findDrawableById("EventualBGLabel") as Text;
        view.setColor(getApp().getProperty("PrimaryColor") as Number);
        view.setText(getEventualBGString(status));
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }
}