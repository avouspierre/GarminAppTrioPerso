/**
 * Unit Conversion Tests
 *
 * Covers the mg/dL to mmol/L display path.
 *
 * The contract these tests pin down: the phone always sends "sgv" in mg/dL,
 * and "units_hint" only selects the display unit. Everything that reasons
 * about the value (arc position, graph position, zone colours) must keep
 * using the raw mg/dL number; only rendered text gets converted.
 *
 * Run with: make test
 */

import Toybox.Test;
import Toybox.Lang;

const MMOL_FACTOR = GlucoseUnits.MMOL_PER_MGDL;
const EPSILON = 0.0001;

function mmolStatus() as Dictionary {
    return { "units_hint" => "mmol" };
}

function mgdlStatus() as Dictionary {
    return { "units_hint" => "mgdl" };
}

(:test)
function testIsMMOLDetection(logger as Test.Logger) as Boolean {
    var view = new TrioView();

    Test.assertEqual(view.isMMOL(mmolStatus()), true);
    Test.assertEqual(view.isMMOL(mgdlStatus()), false);

    // Missing or absent hint must fall back to mg/dL, never to mmol:
    // showing a mg/dL number on a mmol scale would be off by 18x.
    Test.assertEqual(view.isMMOL({ "units_hint" => null }), false);
    Test.assertEqual(view.isMMOL({ "sgv" => 115 }), false);
    Test.assertEqual(view.isMMOL({}), false);
    Test.assertEqual(view.isMMOL(null), false);
    Test.assertEqual(view.isMMOL("not-a-dictionary"), false);

    return true;
}

(:test)
function testMgdlPassesThroughUnchanged(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var status = mgdlStatus();

    Test.assert((view.convertGlucoseValue(115, status) - 115.0).abs() < EPSILON);
    Test.assert((view.convertGlucoseValue(40, status) - 40.0).abs() < EPSILON);
    Test.assert((view.convertGlucoseValue(0, status) - 0.0).abs() < EPSILON);
    Test.assert((view.convertGlucoseValue(-15, status) + 15.0).abs() < EPSILON);

    return true;
}

(:test)
function testMmolConversion(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var status = mmolStatus();

    // A typical in-range reading
    Test.assert((view.convertGlucoseValue(115, status) - 6.3894).abs() < EPSILON);

    // A negative delta must keep its sign through the conversion
    Test.assert((view.convertGlucoseValue(-15, status) + 0.8334).abs() < EPSILON);

    // Zero stays zero in either unit
    Test.assert((view.convertGlucoseValue(0, status) - 0.0).abs() < EPSILON);

    return true;
}

(:test)
function testThresholdsInMmol(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var status = mmolStatus();

    // The four thresholds, converted, must land on the values a mmol user
    // expects to read on screen.
    Test.assert((view.convertGlucoseValue(GlucoseThresholds.VERY_LOW, status) - 2.778).abs() < 0.01);
    Test.assert((view.convertGlucoseValue(GlucoseThresholds.LOW, status) - 3.889).abs() < 0.01);
    Test.assert((view.convertGlucoseValue(GlucoseThresholds.HIGH, status) - 8.334).abs() < 0.01);
    Test.assert((view.convertGlucoseValue(GlucoseThresholds.VERY_HIGH, status) - 11.112).abs() < 0.01);

    return true;
}

(:test)
function testZoningIsUnitIndependent(logger as Test.Logger) as Boolean {
    // Zone classification runs on the raw mg/dL value, so switching the
    // display unit must never move a reading into a different colour band.
    // Guards against someone "fixing" mmol support by converting before
    // comparing, which would classify 6.4 mmol as a severe hypo.
    var readings = [39, 45, 50, 69, 70, 110, 150, 151, 200, 201, 350];

    for (var i = 0; i < readings.size(); i++) {
        var raw = readings[i];
        var zone = GlucoseThresholds.getZone(raw);

        // The converted number is for display only; feeding it back into
        // getZone would be wrong, and this asserts they really do differ.
        var converted = raw * MMOL_FACTOR;
        if (raw >= GlucoseThresholds.LOW) {
            Test.assert(GlucoseThresholds.getZone(converted) != zone);
        }
    }

    // Explicit spot check: 115 mg/dL is in range, its 6.39 mmol rendering
    // would read as a severe hypo if it were classified directly.
    Test.assertEqual(GlucoseThresholds.getZone(115), GlucoseThresholds.ZONE_IN_RANGE);
    Test.assertEqual(GlucoseThresholds.getZone(115 * MMOL_FACTOR), GlucoseThresholds.ZONE_VERY_LOW);

    return true;
}

(:test)
function testIsNumeric(logger as Test.Logger) as Boolean {
    Test.assertEqual(GlucoseUnits.isNumeric(115), true);
    Test.assertEqual(GlucoseUnits.isNumeric(115.4), true);
    Test.assertEqual(GlucoseUnits.isNumeric(115l), true);

    Test.assertEqual(GlucoseUnits.isNumeric(null), false);
    Test.assertEqual(GlucoseUnits.isNumeric("115"), false);
    Test.assertEqual(GlucoseUnits.isNumeric({}), false);

    return true;
}

(:test)
function testFloatReadingsAreConverted(logger as Test.Logger) as Boolean {
    var view = new TrioView();

    // Regression guard: the converter used to test `instanceof Number` only,
    // so a Float reading silently rendered as 0.0 in both unit systems.
    Test.assert((view.convertGlucoseValue(115.0, mmolStatus()) - 6.3894).abs() < EPSILON);
    Test.assert((view.convertGlucoseValue(115.0, mgdlStatus()) - 115.0).abs() < EPSILON);
    Test.assert((view.convertGlucoseValue(115l, mgdlStatus()) - 115.0).abs() < EPSILON);

    // A non-numeric value still collapses to 0.0 rather than throwing.
    Test.assert((view.convertGlucoseValue("115", mgdlStatus()) - 0.0).abs() < EPSILON);
    Test.assert((view.convertGlucoseValue(null, mgdlStatus()) - 0.0).abs() < EPSILON);

    return true;
}

(:test)
function testFormatValue(logger as Test.Logger) as Boolean {
    // mg/dL renders as a whole number, mmol/L keeps one decimal.
    Test.assertEqual(GlucoseUnits.formatValue(115, mgdlStatus()), "115");
    Test.assertEqual(GlucoseUnits.formatValue(115, mmolStatus()), "6.4");

    // Floats must format identically to their integer counterpart.
    Test.assertEqual(GlucoseUnits.formatValue(115.0, mgdlStatus()), "115");
    Test.assertEqual(GlucoseUnits.formatValue(115.0, mmolStatus()), "6.4");

    // Negative deltas keep their sign; the caller adds "+" for positives.
    Test.assertEqual(GlucoseUnits.formatValue(-15, mgdlStatus()), "-15");

    // Unusable input yields a placeholder, never "0".
    Test.assertEqual(GlucoseUnits.formatValue(null, mgdlStatus()), "--");
    Test.assertEqual(GlucoseUnits.formatValue("abc", mmolStatus()), "--");

    return true;
}

(:test)
function testGlanceAndMainViewAgree(logger as Test.Logger) as Boolean {
    // Both views now share GlucoseUnits, so the same reading must render
    // identically on the glance and on the main screen. They used to differ:
    // the main view showed 0.0 for a Float that the glance rendered fine.
    var view = new TrioView();
    var readings = [40, 70, 115, 150, 200, 350, 115.0, 6.4];
    var systems = [mgdlStatus(), mmolStatus()];

    for (var s = 0; s < systems.size(); s++) {
        for (var i = 0; i < readings.size(); i++) {
            var shared = GlucoseUnits.formatValue(readings[i], systems[s]);
            var mainView = view.convertGlucoseValue(readings[i], systems[s]);

            Test.assert(shared.length() > 0);
            Test.assertEqual(shared.equals("--"), false);

            // The delegating helper must stay in step with the module.
            var direct = GlucoseUnits.convert(readings[i], systems[s]);
            Test.assert((mainView - direct).abs() < EPSILON);
        }
    }

    return true;
}

(:test)
function testArcScaleIsMgdl(logger as Test.Logger) as Boolean {
    // The arc maps ARC_MIN..ARC_MAX onto its sweep using the raw value, so a
    // mmol user still gets a correctly positioned needle. Verify the scale
    // bounds are mg/dL-sized and not mmol-sized (which would be ~2.2..13.9).
    Test.assert(GlucoseThresholds.ARC_MIN > 20);
    Test.assert(GlucoseThresholds.ARC_MAX > 100);
    Test.assert(GlucoseThresholds.GRAPH_MIN > 20);
    Test.assert(GlucoseThresholds.GRAPH_MAX > 100);

    return true;
}
