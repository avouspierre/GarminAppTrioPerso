/**
 * Glucose Thresholds
 *
 * Single source of truth for the glucose limits used across the widget.
 * Previously each renderer carried its own hard-coded numbers, which had
 * drifted apart: the arc treated 100-180 as in-range while the glance
 * coloured anything below 100 green - so a severe hypo showed as "good".
 *
 * All values are in mg/dL, matching the raw "sgv" pushed by the phone.
 * Conversion to mmol/L happens at display time only, so comparisons against
 * these thresholds must always use the raw value.
 *
 * ZONES (5 bands derived from the 4 thresholds):
 *   value < VERY_LOW              severe hypoglycemia   (red)
 *   VERY_LOW <= value < LOW       hypoglycemia          (yellow)
 *   LOW <= value <= HIGH          in range              (green)
 *   HIGH < value <= VERY_HIGH     hyperglycemia         (yellow)
 *   value > VERY_HIGH             severe hyperglycemia  (red)
 *
 * Annotated (:glance) so the glance view can share the same thresholds as
 * the main view.
 */

import Toybox.Lang;
import Toybox.Graphics;

(:glance)
module GlucoseThresholds {

    /** Below this, hypoglycemia is severe (mg/dL) */
    const VERY_LOW = 50;

    /** Lower bound of the target range (mg/dL) */
    const LOW = 70;

    /** Upper bound of the target range (mg/dL) */
    const HIGH = 150;

    /** Above this, hyperglycemia is severe (mg/dL) */
    const VERY_HIGH = 200;

    /** Lowest value the arc gauge renders (mg/dL) */
    const ARC_MIN = 40;

    /** Highest value the arc gauge renders (mg/dL) */
    const ARC_MAX = 250;

    /** Lowest value the trend graph renders (mg/dL) */
    const GRAPH_MIN = 40;

    /** Highest value the trend graph renders (mg/dL) */
    const GRAPH_MAX = 310;

    enum Zone {
        ZONE_VERY_LOW = 0,
        ZONE_LOW = 1,
        ZONE_IN_RANGE = 2,
        ZONE_HIGH = 3,
        ZONE_VERY_HIGH = 4
    }

    /**
     * Zone classifier
     *
     * @param value Glucose value in mg/dL
     * @return Zone constant for that value
     */
    function getZone(value as Numeric) as Zone {
        if (value < VERY_LOW) {
            return ZONE_VERY_LOW;
        } else if (value < LOW) {
            return ZONE_LOW;
        } else if (value <= HIGH) {
            return ZONE_IN_RANGE;
        } else if (value <= VERY_HIGH) {
            return ZONE_HIGH;
        }
        return ZONE_VERY_HIGH;
    }

    /**
     * Zone colour mapper
     *
     * Severity is symmetric: both extremes are red, both near-misses yellow.
     *
     * @param zone Zone constant
     * @return Colour for that zone
     */
    function getZoneColor(zone as Zone) as Graphics.ColorValue {
        switch (zone) {
            case ZONE_VERY_LOW:  return Graphics.COLOR_RED;
            case ZONE_LOW:       return Graphics.COLOR_YELLOW;
            case ZONE_IN_RANGE:  return Graphics.COLOR_GREEN;
            case ZONE_HIGH:      return Graphics.COLOR_YELLOW;
            case ZONE_VERY_HIGH: return Graphics.COLOR_RED;
        }
        return Graphics.COLOR_LT_GRAY;
    }

    /**
     * Glucose colour shortcut
     *
     * @param value Glucose value in mg/dL
     * @return Colour matching the value's zone
     */
    function getColor(value as Numeric) as Graphics.ColorValue {
        return getZoneColor(getZone(value));
    }

    /**
     * In-range test
     *
     * @param value Glucose value in mg/dL
     * @return true when the value sits inside [LOW, HIGH]
     */
    function isInRange(value as Numeric) as Boolean {
        return getZone(value) == ZONE_IN_RANGE;
    }
}
