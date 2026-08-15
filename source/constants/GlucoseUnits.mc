/**
 * Glucose Units
 *
 * Single source of truth for the mg/dL to mmol/L display conversion.
 *
 * CONTRACT: the phone always sends "sgv", "delta" and "isf" in mg/dL.
 * "units_hint" only selects the unit shown on screen - it never describes
 * the unit of the incoming value. Everything that reasons about a value
 * (arc position, graph position, zone colour) keeps using the raw mg/dL
 * number; only rendered text goes through this module.
 *
 * Annotated (:glance) so the glance and the main view share one
 * implementation. They used to carry separate copies that disagreed: the
 * main view rejected Float values and rendered them as 0.0, while the
 * glance converted them correctly.
 */

import Toybox.Lang;

(:glance)
module GlucoseUnits {

    /** 1 mg/dL expressed in mmol/L */
    const MMOL_PER_MGDL = 0.05556;

    /** Value of "units_hint" that selects mmol/L */
    const MMOL_HINT = "mmol";

    /**
     * Numeric type guard
     *
     * Values arrive from the phone untyped, so a reading may be a Number or
     * a Float depending on how the payload was encoded.
     *
     * @param value Candidate value
     * @return true when the value can be converted and formatted
     */
    function isNumeric(value as Object?) as Boolean {
        return value instanceof Number
            || value instanceof Long
            || value instanceof Float
            || value instanceof Double;
    }

    /**
     * Unit system detector
     *
     * Anything other than an explicit "mmol" hint means mg/dL. Defaulting
     * the other way would show a mg/dL number on a mmol scale, an 18x error.
     *
     * @param statusData Data dictionary carrying "units_hint"
     * @return true for mmol/L, false for mg/dL
     */
    function isMMOL(statusData as Object?) as Boolean {
        if (statusData instanceof Dictionary) {
            var unitsHint = statusData["units_hint"];
            if (unitsHint == null) {
                return false;
            }
            // toString() first: the hint is untrusted and may not be a String.
            var hint = (unitsHint as Object).toString();
            return hint.equals(MMOL_HINT);
        }
        return false;
    }

    /**
     * Glucose value converter
     *
     * @param value Glucose value in mg/dL
     * @param statusData Data dictionary for unit detection
     * @return Value in the display unit, or 0.0 when not numeric
     */
    function convert(value as Object?, statusData as Object?) as Float {
        if (!isNumeric(value)) {
            return 0.0;
        }

        var raw = (value as Numeric).toFloat();

        if (isMMOL(statusData)) {
            return raw * MMOL_PER_MGDL;
        }

        return raw;
    }

    /**
     * Glucose value formatter
     *
     * mmol/L keeps one decimal; mg/dL is shown as a whole number. The
     * integer branch converts to Number first: applying "%d" to a Float is
     * undefined in Monkey C.
     *
     * @param value Glucose value in mg/dL
     * @param statusData Data dictionary for unit detection
     * @return Display string, or "--" when the value is not numeric
     */
    function formatValue(value as Object?, statusData as Object?) as String {
        if (!isNumeric(value)) {
            return "--";
        }

        var converted = convert(value, statusData);

        if (isMMOL(statusData)) {
            return converted.format("%2.1f");
        }

        return converted.toNumber().format("%d");
    }
}
