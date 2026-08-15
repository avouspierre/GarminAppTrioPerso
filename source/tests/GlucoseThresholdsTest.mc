/**
 * Glucose Thresholds Tests
 *
 * Boundary coverage for the shared glucose thresholds. The band edges are
 * the part that silently drifts when someone edits a limit, so every
 * threshold is asserted from both sides.
 *
 * Run with: make test
 */

import Toybox.Test;
import Toybox.Lang;
import Toybox.Graphics;

(:test)
function testThresholdValues(logger as Test.Logger) as Boolean {
    Test.assertEqual(GlucoseThresholds.VERY_LOW, 50);
    Test.assertEqual(GlucoseThresholds.LOW, 70);
    Test.assertEqual(GlucoseThresholds.HIGH, 150);
    Test.assertEqual(GlucoseThresholds.VERY_HIGH, 200);

    return true;
}

(:test)
function testThresholdsAreOrdered(logger as Test.Logger) as Boolean {
    // A mis-edit that inverts two limits would make whole zones unreachable.
    Test.assert(GlucoseThresholds.ARC_MIN < GlucoseThresholds.VERY_LOW);
    Test.assert(GlucoseThresholds.VERY_LOW < GlucoseThresholds.LOW);
    Test.assert(GlucoseThresholds.LOW < GlucoseThresholds.HIGH);
    Test.assert(GlucoseThresholds.HIGH < GlucoseThresholds.VERY_HIGH);
    Test.assert(GlucoseThresholds.VERY_HIGH < GlucoseThresholds.ARC_MAX);

    // The graph must be able to plot anything the arc can render.
    Test.assert(GlucoseThresholds.GRAPH_MIN <= GlucoseThresholds.ARC_MIN);
    Test.assert(GlucoseThresholds.GRAPH_MAX >= GlucoseThresholds.ARC_MAX);

    return true;
}

(:test)
function testZoneBoundaries(logger as Test.Logger) as Boolean {
    // Below VERY_LOW
    Test.assertEqual(GlucoseThresholds.getZone(39), GlucoseThresholds.ZONE_VERY_LOW);
    Test.assertEqual(GlucoseThresholds.getZone(49), GlucoseThresholds.ZONE_VERY_LOW);

    // VERY_LOW is the first non-severe value
    Test.assertEqual(GlucoseThresholds.getZone(50), GlucoseThresholds.ZONE_LOW);
    Test.assertEqual(GlucoseThresholds.getZone(69), GlucoseThresholds.ZONE_LOW);

    // LOW opens the target range, HIGH closes it - both inclusive
    Test.assertEqual(GlucoseThresholds.getZone(70), GlucoseThresholds.ZONE_IN_RANGE);
    Test.assertEqual(GlucoseThresholds.getZone(110), GlucoseThresholds.ZONE_IN_RANGE);
    Test.assertEqual(GlucoseThresholds.getZone(150), GlucoseThresholds.ZONE_IN_RANGE);

    // Above HIGH, up to and including VERY_HIGH
    Test.assertEqual(GlucoseThresholds.getZone(151), GlucoseThresholds.ZONE_HIGH);
    Test.assertEqual(GlucoseThresholds.getZone(200), GlucoseThresholds.ZONE_HIGH);

    // Beyond VERY_HIGH
    Test.assertEqual(GlucoseThresholds.getZone(201), GlucoseThresholds.ZONE_VERY_HIGH);
    Test.assertEqual(GlucoseThresholds.getZone(400), GlucoseThresholds.ZONE_VERY_HIGH);

    return true;
}

(:test)
function testZoneAcceptsFloats(logger as Test.Logger) as Boolean {
    // Deltas and converted values arrive as floats.
    Test.assertEqual(GlucoseThresholds.getZone(49.9), GlucoseThresholds.ZONE_VERY_LOW);
    Test.assertEqual(GlucoseThresholds.getZone(50.0), GlucoseThresholds.ZONE_LOW);
    Test.assertEqual(GlucoseThresholds.getZone(150.5), GlucoseThresholds.ZONE_HIGH);

    return true;
}

(:test)
function testColorMapping(logger as Test.Logger) as Boolean {
    // Severity is symmetric: extremes red, near-misses yellow, target green.
    Test.assertEqual(GlucoseThresholds.getColor(45), Graphics.COLOR_RED);
    Test.assertEqual(GlucoseThresholds.getColor(60), Graphics.COLOR_YELLOW);
    Test.assertEqual(GlucoseThresholds.getColor(110), Graphics.COLOR_GREEN);
    Test.assertEqual(GlucoseThresholds.getColor(175), Graphics.COLOR_YELLOW);
    Test.assertEqual(GlucoseThresholds.getColor(250), Graphics.COLOR_RED);

    return true;
}

(:test)
function testSevereHypoIsNotGreen(logger as Test.Logger) as Boolean {
    // Regression guard: the glance used to paint anything below 100 green,
    // so a severe hypo read as "good".
    Test.assert(GlucoseThresholds.getColor(45) != Graphics.COLOR_GREEN);
    Test.assert(GlucoseThresholds.getColor(55) != Graphics.COLOR_GREEN);
    Test.assert(GlucoseThresholds.getColor(69) != Graphics.COLOR_GREEN);

    // ... while a normal 90 still is.
    Test.assertEqual(GlucoseThresholds.getColor(90), Graphics.COLOR_GREEN);

    return true;
}

(:test)
function testIsInRange(logger as Test.Logger) as Boolean {
    Test.assertEqual(GlucoseThresholds.isInRange(69), false);
    Test.assertEqual(GlucoseThresholds.isInRange(70), true);
    Test.assertEqual(GlucoseThresholds.isInRange(150), true);
    Test.assertEqual(GlucoseThresholds.isInRange(151), false);

    return true;
}

(:test)
function testEveryZoneIsReachable(logger as Test.Logger) as Boolean {
    // Sweep the whole rendered scale and confirm all five zones occur, and
    // that zones never go backwards as glucose rises.
    var seen = [false, false, false, false, false];
    var previous = GlucoseThresholds.getZone(GlucoseThresholds.GRAPH_MIN);

    for (var v = GlucoseThresholds.GRAPH_MIN; v <= GlucoseThresholds.GRAPH_MAX; v++) {
        var zone = GlucoseThresholds.getZone(v);
        seen[zone] = true;

        // Zones are ordered by value, so the sequence must be non-decreasing.
        Test.assert(zone >= previous);
        previous = zone;
    }

    for (var z = 0; z < seen.size(); z++) {
        Test.assert(seen[z]);
    }

    return true;
}
