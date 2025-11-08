/**
 * Communications Relay
 * 
 * Connection listener for background data transmission requests.
 * Provides callback mechanism for async communication operations.
 * 
 * Used by TrioBGServiceDelegate during temporal event backup sync
 * to handle completion/error states of phone data requests.
 * 
 * DESIGN PATTERN:
 * Implements callback pattern for asynchronous communication.
 * Wraps Garmin's ConnectionListener to provide custom callback handling.
 * 
 * USAGE:
 * var relay = new CommsRelay(method(:onTransmitComplete));
 * Communications.transmit("status", null, relay);
 * 
 * @author Trio Development Team
 * @version 2.0
 */

using Toybox.Communications as Comms;
import Toybox.Background;

(:background)
class CommsRelay extends Comms.ConnectionListener {

    /**
     * Callback function to invoke on completion or error
     * Hidden visibility prevents external access
     */
    hidden var mCallback;

    /**
     * Constructor
     * 
     * @param callback Function to call with success/failure status
     *                 Signature: function(isSuccess as Boolean)
     */
    function initialize(callback) {
        ConnectionListener.initialize();
        mCallback = callback;
    }

    /**
     * Success handler
     * 
     * Called when communication completes successfully.
     * Invokes registered callback with true status.
     */
    function onComplete() {
        mCallback.invoke(true);
    }

    /**
     * Error handler
     * 
     * Called when communication fails.
     * Invokes registered callback with false status.
     */
    function onError() {
        mCallback.invoke(false);
    }
}
