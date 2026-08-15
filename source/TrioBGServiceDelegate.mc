/**
 * Trio Background Service Delegate
 * 
 * Handles background data synchronization between iPhone Trio app and watchface.
 * Manages two communication pathways:
 * 1. Phone App Messages: Primary method for modern devices (API 3.2.0+)
 * 2. Communications.transmit: Legacy method for older devices
 * 
 * DATA INTERFACE - Incoming from Phone:
 * Receives array of glucose entries from Trio iOS app, structured as:
 * [{
 *   "date": Long (timestamp in ms),
 *   "sgv": Number (glucose in mg/dL),
 *   "delta": Number (change in mg/dL),
 *   "direction": String (Flat, SingleUp, DoubleUp, etc.),
 *   "units_hint": String ("mgdl" or "mmol"),
 *   "iob": Float (insulin on board),
 *   "tbr": Float (temp basal rate multiplier),
 *   "cob": Number (carbs on board),
 *   "eventualBG": Number (predicted glucose),
 *   "isf": Number (insulin sensitivity factor),
 *   "sensRatio": Float (sensitivity ratio),
 *   "displayDataType1": String (middle metric selector),
 *   "displayDataType2": String (right metric selector)
 * }, ...]
 * 
 * Most recent entry (index 0) is extracted and stored for watchface display.
 * 
 * DUAL DEVICE SUPPORT:
 * - Modern devices (Fenix 6+, etc.): Use registerForPhoneAppMessageEvent
 * - Legacy devices (Fenix 5, etc.): Use Communications.registerForPhoneAppMessages
 * 
 * TIMER STRATEGY (Set and Forget - Fixed):
 * - Timer registered ONCE at application startup
 * - NO timer resets in background service (matches old working version)
 * - Timer only reset by legacy devices in onBackgroundData()
 * - Minimizes background wake-ups for system stability
 * 
 * @author Trio Development Team
 * @version 2.1 (Fixed - Removed excessive timer resets)
 */

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Background;
import Toybox.System;
import Toybox.Communications;

(:background)
class TrioBGServiceDelegate extends System.ServiceDelegate {

    /**
     * Constructor
     * 
     * Initializes communication channel based on device capabilities.
     * Modern devices use automatic message registration via background API.
     * Legacy devices require explicit message handler registration.
     */
    function initialize(){
        ServiceDelegate.initialize();

        if (Background has :registerForPhoneAppMessageEvent) {
            // Modern device: Messages handled automatically
        } else {
            // Legacy device: Register explicit message handler
            Communications.registerForPhoneAppMessages(
                method(:onReceiveMessage) as Communications.PhoneMessageCallback
            );
        }
    }

    /**
     * Legacy message receiver (Fenix 5 and older devices)
     * 
     * Receives phone messages on devices without modern background API.
     * Routes data to background data handler for processing.
     * 
     * FIXED: Removed timer reset (follows old working version strategy)
     * 
     * @param msg Message object containing data payload
     */
    function onReceiveMessage(msg) {
        Background.exit(msg.data);
	}

    /**
     * Temporal event handler (320s backup sync mechanism)
     * 
     * Triggered every 320 seconds as backup data request.
     * Requests data from phone when primary push mechanism may have failed.
     * 
     * TIMER DESIGN:
     * - Set to 320s (5min 20sec) - 20s buffer after 300s loop cycle
     * - NOT reset here (set and forget strategy)
     * - Fires regularly to ensure data freshness
     */
    function onTemporalEvent() {
        // Request status from phone - backup mechanism
        Communications.transmit("status", null, new CommsRelay(method(:onTransmitComplete)));
        Background.exit(null);
    }

    /**
     * Phone app message handler (modern devices)
     * 
     * Primary data reception pathway for devices with modern background API.
     * Receives array of glucose entries from Trio iOS app.
     * 
     * FIXED: Removed timer reset (follows old working version strategy)
     * 
     * @param msg Message object containing data array from phone
     */
    function onPhoneAppMessage(msg) {
        var data = msg.data;
        Application.Storage.setValue("status", data as Array);
        // if (data instanceof Array) {
        //     if (data.size() > 0) {
        //         var firstEntry = data[0];
        //         if (firstEntry instanceof Dictionary) {
        //             Application.Storage.setValue("status", firstEntry as Dictionary);
        //         }
        //     }
        // }
        
        Background.exit(null);
    }

    /**
     * Communication transmission completion handler
     * 
     * Callback for temporal event data requests.
     * Handles both success and failure cases for backup sync.
     * 
     * FIXED: Removed timer reset (follows old working version strategy)
     * 
     * @param isSuccess True if data received successfully, false otherwise
     */
    function onTransmitComplete(isSuccess) {
        Background.exit(isSuccess);
    }
}
