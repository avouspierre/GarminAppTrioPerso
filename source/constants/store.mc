import Toybox.Lang;
import Toybox.Time;

/**
 * Shared display constants
 *
 * What remains of the original watchface's settings store. Its init() used
 * to load seven properties (dateFormat, background gradients, ...) that no
 * longer exist in properties.xml - calling it would have crashed on
 * null.toNumberWithBase(). It was never called, and everything it fed has
 * been removed along with it.
 */
module store {
  var foregroundColor as Number = Toybox.Graphics.COLOR_LT_GRAY;
}
