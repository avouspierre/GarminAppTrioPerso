/**
 * Trio View Tests
 *
 * Covers the two helpers the trend graph relies on:
 * - getEntryDate: rejects malformed entries pushed by the phone
 * - glucoseToY:   projects a glucose value onto the plot's vertical axis
 *
 * Run with: make test
 */

import Toybox.Test;
import Toybox.Lang;
import Toybox.Graphics;

// One case per test: a single combined test only ever reports the first
// failure, and Test.assertEqual() cannot be used for a null expectation
// (it invokes equals() on the value, which throws).

(:test)
function testEntryDateFromNull(logger as Test.Logger) as Boolean {
    Test.assert(new TrioView().getEntryDate(null) == null);
    return true;
}

(:test)
function testEntryDateFromString(logger as Test.Logger) as Boolean {
    Test.assert(new TrioView().getEntryDate("not-a-dictionary") == null);
    return true;
}

(:test)
function testEntryDateFromBareNumber(logger as Test.Logger) as Boolean {
    Test.assert(new TrioView().getEntryDate(1786796299000l) == null);
    return true;
}

(:test)
function testEntryDateMissingKey(logger as Test.Logger) as Boolean {
    Test.assert(new TrioView().getEntryDate({ "sgv" => 100 }) == null);
    return true;
}

(:test)
function testEntryDateNullDate(logger as Test.Logger) as Boolean {
    Test.assert(new TrioView().getEntryDate({ "date" => null }) == null);
    return true;
}

(:test)
function testEntryDateNonNumericDate(logger as Test.Logger) as Boolean {
    Test.assert(new TrioView().getEntryDate({ "date" => "abc" }) == null);
    return true;
}

(:test)
function testGetEntryDateAcceptsNumerics(logger as Test.Logger) as Boolean {
    var view = new TrioView();

    var asLong = view.getEntryDate({ "date" => 1786796299000l });
    Test.assert(asLong != null);
    Test.assertEqual(asLong, 1786796299000l);

    // A plain Number must be promoted, not rejected.
    var asNumber = view.getEntryDate({ "date" => 1700 });
    Test.assert(asNumber != null);
    Test.assertEqual(asNumber, 1700l);

    return true;
}

(:test)
function testArcValueRejectsNonNumeric(logger as Test.Logger) as Boolean {
    var view = new TrioView();

    // Anything the arc cannot clamp must fall back to the scale minimum.
    // A String used to reach getGlucoseDegree(), where toFloat() returns
    // null and the following comparison crashes the whole render.
    Test.assertEqual(view.getArcValue({ "sgv" => "abc" }), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue({ "sgv" => "115" }), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue({ "sgv" => null }), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue({ "sgv" => {} }), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue({ "iob" => 2.5 }), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue({}), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue(null), GlucoseThresholds.ARC_MIN);
    Test.assertEqual(view.getArcValue("not-a-dictionary"), GlucoseThresholds.ARC_MIN);

    return true;
}

(:test)
function testArcValuePassesNumericThrough(logger as Test.Logger) as Boolean {
    var view = new TrioView();

    Test.assertEqual(view.getArcValue({ "sgv" => 115 }), 115);
    Test.assertEqual(view.getArcValue({ "sgv" => 40 }), 40);

    // Out-of-scale readings stay untouched here; the gauge clamps them.
    Test.assertEqual(view.getArcValue({ "sgv" => 350 }), 350);
    Test.assertEqual(view.getArcValue({ "sgv" => 20 }), 20);

    // Floats must survive the guard, not be swapped for the fallback.
    Test.assert((view.getArcValue({ "sgv" => 115.4 }) - 115.4).abs() < 0.0001);

    return true;
}

(:test)
function testGlucoseToYSpansThePlot(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 100.0;
    var graphHeight = 50.0;

    // The usable range is inset by one point radius at each end, so a value
    // on a scale limit draws its whole disc inside the frame.
    var margin = view.GRAPH_POINT_RADIUS;
    var yMin = view.glucoseToY(GlucoseThresholds.GRAPH_MIN, graphY, graphHeight);
    var yMax = view.glucoseToY(GlucoseThresholds.GRAPH_MAX, graphY, graphHeight);

    Test.assert((yMin - (graphY + graphHeight - margin)).abs() < 0.01);
    Test.assert((yMax - (graphY + margin)).abs() < 0.01);

    return true;
}

(:test)
function testGlucoseToYIsInverted(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 100.0;
    var graphHeight = 50.0;

    // Screen Y grows downwards, so a higher glucose must yield a smaller Y.
    var yLow = view.glucoseToY(GlucoseThresholds.LOW, graphY, graphHeight);
    var yHigh = view.glucoseToY(GlucoseThresholds.HIGH, graphY, graphHeight);

    Test.assert(yHigh < yLow);

    // Both target-range markers must land inside the plot area.
    Test.assert(yLow <= graphY + graphHeight && yLow >= graphY);
    Test.assert(yHigh <= graphY + graphHeight && yHigh >= graphY);

    return true;
}

(:test)
function testGlucoseToYClampsAboveScale(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 100.0;
    var graphHeight = 50.0;

    var topEdge = view.glucoseToY(GlucoseThresholds.GRAPH_MAX, graphY, graphHeight);

    // Anything above GRAPH_MAX pins to the top edge instead of being drawn
    // above the frame, over the rest of the screen.
    Test.assert((view.glucoseToY(311, graphY, graphHeight) - topEdge).abs() < 0.01);
    Test.assert((view.glucoseToY(400, graphY, graphHeight) - topEdge).abs() < 0.01);
    Test.assert((view.glucoseToY(9999, graphY, graphHeight) - topEdge).abs() < 0.01);

    return true;
}

(:test)
function testGlucoseToYClampsBelowScale(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 100.0;
    var graphHeight = 50.0;

    var bottomEdge = view.glucoseToY(GlucoseThresholds.GRAPH_MIN, graphY, graphHeight);

    // Same guard on the low side: a severe hypo must not drop below the frame.
    Test.assert((view.glucoseToY(39, graphY, graphHeight) - bottomEdge).abs() < 0.01);
    Test.assert((view.glucoseToY(0, graphY, graphHeight) - bottomEdge).abs() < 0.01);
    Test.assert((view.glucoseToY(-50, graphY, graphHeight) - bottomEdge).abs() < 0.01);

    return true;
}

(:test)
function testEveryPlottedPointStaysInFrame(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 100.0;
    var graphHeight = 50.0;
    var readings = [-50, 0, 39, 40, 70, 150, 200, 310, 311, 400, 9999];
    var radius = view.GRAPH_POINT_RADIUS;

    for (var i = 0; i < readings.size(); i++) {
        var y = view.glucoseToY(readings[i], graphY, graphHeight);

        // The whole disc must fit, not just its centre.
        Test.assert(y - radius >= graphY - 0.01);
        Test.assert(y + radius <= graphY + graphHeight + 0.01);
    }

    return true;
}

(:test)
function testShortPlotFallsBackToFullHeight(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 10.0;
    var graphHeight = 6.0;   // shorter than the two margins combined

    // Without the fallback the usable height would go negative and invert
    // the axis, putting high readings below low ones.
    var yMin = view.glucoseToY(GlucoseThresholds.GRAPH_MIN, graphY, graphHeight);
    var yMax = view.glucoseToY(GlucoseThresholds.GRAPH_MAX, graphY, graphHeight);

    Test.assert(yMax < yMin);
    Test.assert((yMin - (graphY + graphHeight)).abs() < 0.01);
    Test.assert((yMax - graphY).abs() < 0.01);

    return true;
}

(:test)
function testClampDoesNotAffectZoneColour(logger as Test.Logger) as Boolean {
    // The clamp is a rendering concern only: a 350 is pinned to the top of
    // the plot but must still be classified - and coloured - as severely high.
    Test.assertEqual(GlucoseThresholds.getZone(350), GlucoseThresholds.ZONE_VERY_HIGH);
    Test.assertEqual(GlucoseThresholds.getZone(20), GlucoseThresholds.ZONE_VERY_LOW);

    return true;
}

(:test)
function testGlucoseToYMidpoint(logger as Test.Logger) as Boolean {
    var view = new TrioView();
    var graphY = 0.0;
    var graphHeight = 100.0;

    // Halfway up the scale must land halfway up the plot.
    var middle = (GlucoseThresholds.GRAPH_MIN + GlucoseThresholds.GRAPH_MAX) / 2.0;
    var y = view.glucoseToY(middle, graphY, graphHeight);

    Test.assert((y - 50.0).abs() < 0.01);

    return true;
}
