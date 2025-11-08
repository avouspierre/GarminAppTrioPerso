/**
 * Trio Watchface Application
 * 
 * Main application class for Trio diabetes management watchface.
 * Handles background data synchronization and application lifecycle.
 * 
 * ENERGY OPTIMIZATION STRATEGY (Fixed):
 * - Background timer registered once at startup (320s backup interval)
 * - Timer NOT reset on modern devices (set and forget strategy)
 * - Timer only reset on legacy devices after data reception
 * - Primary sync via phone messages every 5 minutes
 * - Backup sync via temporal events fires regularly
 * 
 * @author Trio Development Team
 * @version 2.1 (Fixed - Removed excessive timer resets)
 */

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.Time;
import Toybox.System;
import Toybox.Communications;

(:background)
class TrioWatchfaceApp extends Application.AppBase {

    private var inBackground = false;

    function initialize() {
        AppBase.initialize();
    }

    /**
     * Application startup handler
     * 
     * Initializes background synchronization with dual-mode strategy:
     * 1. Phone App Messages: Primary sync method (phone pushes every ~5 minutes)
     * 2. Temporal Events: Backup sync method (320s backup interval)
     * 
     * BACKUP TIMER STRATEGY (Fixed - Set and Forget):
     * Timer set to 320s (5min 20sec) provides 20s buffer after 300s loop cycle.
     * Timer registered ONCE and only reset by legacy devices.
     * This minimizes background wake-ups and system instability.
     * 
     * @param state Application state dictionary (unused)
     */
    function onStart(state as Dictionary?) as Void {
        if(Toybox.System has :ServiceDelegate) {
            Background.registerForTemporalEvent(new Time.Duration(320));
            
            if (Background has :registerForPhoneAppMessageEvent) {
                Background.registerForPhoneAppMessageEvent();
            }
        }

        // Get the current Unix time in milliseconds (matching new structure)
        var now = Time.now().value();
        var fourMinutesAgo = now - (240); // 4 minutes ago in seconds
        var lastLoopDateMs = fourMinutesAgo.toLong() * 1000; // Use Long to avoid overflow

        // Simulate data for testing in the simulator - mg/dL units
        var sampleData = {
            "date" => lastLoopDateMs,
            "sgv" => 130,
            "delta" => -27,
            "direction" => "DoubleUp",
            "units_hint" => "mgdl",
            "iob" => 10.9,
            "tbr" => 1.5,
            "cob" => 20,
            "eventualBG" => 85,
            "isf" => 100,
            "sensRatio" => 0.95,
            "displayDataType1" => "cob",
            "displayDataType2" => "tbr"
        } as Dictionary;

        // Store the sample data (uncomment to test)
        //Application.Storage.setValue("status", sampleData);

    }

    /**
     * Background data reception handler
     * 
     * Processes incoming data from background service delegate.
     * Data can arrive via:
     * - Phone app messages (modern devices)
     * - Temporal event requests (legacy devices or backup)
     * 
     * TIMER RESET STRATEGY (Fixed - Matches Old Working Version):
     * - Modern devices: NO timer reset (set and forget)
     * - Legacy devices only: reset timer to maintain regular sync
     * This eliminates excessive background wake-ups on modern devices.
     * 
     * @param data Dictionary containing glucose and insulin data from phone
     */
    function onBackgroundData(data) {
        if (data instanceof Number || data == null) {
            return;
        }
        
        if (Background has :registerForPhoneAppMessageEvent) {
            // Modern devices: data already stored via onPhoneAppMessage
            // NO timer reset - follows "set and forget" strategy
        } else {
            // Legacy devices: store data and reset timer
            Application.Storage.setValue("status", data as Dictionary);
            Background.deleteTemporalEvent();
            Background.registerForTemporalEvent(new Time.Duration(320));
        }
    }

    /**
     * Application shutdown handler
     * 
     * Cleans up background temporal events when app exits foreground.
     * Only deletes timer when truly exiting (not entering background service).
     * 
     * @param state Application state dictionary (unused)
     */
    function onStop(state as Dictionary?) as Void {
        if(!inBackground) {
    		Background.deleteTemporalEvent();
    	}
    }

    /**
     * Initial view provider
     * 
     * @return Array containing the main watchface view
     */
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new TrioWatchfaceView() ] as [Views];
    }

    /**
     * Settings change handler
     * 
     * Triggers UI update when user modifies watchface settings
     * (e.g., colors, display preferences).
     */
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

    /**
     * Background service delegate provider
     * 
     * @return Array containing background service delegate for data sync
     */
    function getServiceDelegate() {
        inBackground = true;
        return [new TrioBGServiceDelegate()];
    }
}

/**
 * Global app instance accessor
 * 
 * @return Current application instance
 */
function getApp() as TrioWatchfaceApp {
    return Application.getApp() as TrioWatchfaceApp;
}
