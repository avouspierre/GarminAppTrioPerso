/**
 * Trio Widget Application
 * 
 * Main application class for Trio diabetes management widget.
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
 * @version 2.1 (Converted to Widget)
 */

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.Time;
import Toybox.System;
import Toybox.Communications;
using Toybox.Math as Mt;
using Toybox.System as Sys;

(:background)
class TrioApp extends Application.AppBase {

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

        seedSimulatedData();
    }

    /**
     * Simulated data seeding - DEBUG BUILDS ONLY
     *
     * Fills storage with a synthetic history so the UI can be exercised in the
     * simulator, where no phone is connected. Readings are timestamped relative
     * to now, so the loop-age indicator stays meaningful across restarts.
     *
     * The (:debug) annotation is the guard: the compiler keeps this version out
     * of any build made with --release, and links the no-op below instead.
     * There is no runtime "am I in the simulator" API in Connect IQ, so the
     * build flavour is what separates the two.
     *
     * BEWARE: a debug build sideloaded onto a watch WILL overwrite real
     * readings with these fake ones. Ship with `make release` or `make package`.
     */
    (:debug)
    function seedSimulatedData() as Void {
        var now = Time.now().value();
        var fourMinutesAgo = now - 240;
        var lastLoopDateMs = fourMinutesAgo.toLong() * 1000;

        var sampleData = [{
            "sgv" => 190,
            "date" => lastLoopDateMs, // In milliseconds
            "delta" => -15,
            "direction" => "FortyFiveDown",
            "units_hint" => "mmol",
            "iob" => 2.5,
            "cob" => 25,
            "tbr" => 1.45,           // Basal rate in U/hr
            "eventualBG" => 89,
            "isf" => 50,
            "sensRatio" => 0.65,
            "displayPrimaryAttributeChoice" => "sensRatio", // Right side: sensRatio, isf, or cob
            "displaySecondaryAttributeChoice" => "eventualBG" // Middle: eventualBG or tbr
        }] as Array;

        Mt.srand(Sys.getTimer());

        for (var i = 1; i < 24; i++) {
            var dateMinutesAgo = now - (300 * i);
            var lastDatetLoopMs = dateMinutesAgo.toLong() * 1000;
            var randomValue = 40 + Mt.rand() % 200;
            var newData = {
                "sgv" => randomValue,
                "date" => lastDatetLoopMs
            } as Dictionary;
            sampleData.add(newData);
        }

        Application.Storage.setValue("status", sampleData);
    }

    /**
     * Simulated data seeding - RELEASE BUILDS
     *
     * Deliberately does nothing: on a real watch the app waits for the phone to
     * push readings. Fabricating glucose values on a device would be dangerous.
     */
    (:release)
    function seedSimulatedData() as Void {
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
     * Initial view provider for widget
     *
     * @return Array containing the main widget view
     */
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new TrioView() ] as [Views];
    }

    /**
     * Glance view provider
     *
     * @return Array containing the glance view for widget menu
     */
    (:glance)
    function getGlanceView() as [GlanceView] or Null {
        return [ new TrioGlanceView() ] as [GlanceView];
    }

    /**
     * Settings change handler
     *
     * Triggers UI update when user modifies widget settings
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
function getApp() as TrioApp {
    return Application.getApp() as TrioApp;
}