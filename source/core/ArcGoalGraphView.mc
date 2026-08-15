import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.Graphics;

class ArcGoalGraphView extends BaseView {
  var value as Number = 0;
  var color as Graphics.ColorValue = Graphics.COLOR_BLUE;
  var backgroundColor as Number = store.foregroundColor;
  var direction as Graphics.ArcDirection = Graphics.ARC_CLOCKWISE;
  var radius as Number = 40;
  var position as String = "bottom";
  var arcAngleRage as Number = 180;

  function initialize(params as {
    :value as Number?,
    :color as Graphics.ColorValue?,
    :backgroundColor as Graphics.ColorValue?,
    :direction as Graphics.ArcDirection?,
    :radius as Number?,
    :position as String?,
    :arcAngleRage as Number?,
  }) {
    BaseView.initialize();
    var value = params[:value];
    var color = params[:color];
    var backgroundColor = params[:backgroundColor];
    var direction = params[:direction];
    var radius = params[:radius];
    var position = params[:position];
    var arcAngleRage = params[:arcAngleRage];

    if (value != null) {
      self.value = value;
    }
    if (color != null) {
      self.color = color;
    }
    if (backgroundColor != null) {
      self.backgroundColor = backgroundColor;
    }
    if (direction != null) {
      self.direction = direction;
    }
    if (radius != null) {
      self.radius = radius;
    }
    if (position != null) {
      self.position = position;
    }
    if (arcAngleRage != null) {
      self.arcAngleRage = arcAngleRage;
    }
  }

  function setRadius(radius as Number) as Void {
    self.radius = radius;
  }

  function setData(params as { :value as Number }) as Void {
    var value = params[:value];

    if (value != null) {
      self.value = value;
    }
  }
  
  function draw(dc as Dc) as Void {
    dc.setColor(self.backgroundColor, self.backgroundColor);
    var penWidth = 13;
    var radius = (self.radius - penWidth / 2).toNumber();
    dc.setPenWidth(penWidth);
    
    var endDegree = self.getEndDegree();


    
    // Colour zones are derived from GlucoseThresholds so the arc, the trend
    // graph and the glance all agree on what counts as low or high:
    //   Red:    ARC_MIN  - VERY_LOW   (severe hypoglycemia)
    //   Yellow: VERY_LOW - LOW        (hypoglycemia)
    //   Green:  LOW      - HIGH       (target range)
    //   Yellow: HIGH     - VERY_HIGH  (hyperglycemia)
    //   Red:    VERY_HIGH- ARC_MAX    (severe hyperglycemia)

    // Draw severe low zone (ARC_MIN - VERY_LOW)
    dc.setColor(GlucoseThresholds.getZoneColor(GlucoseThresholds.ZONE_VERY_LOW), Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(GlucoseThresholds.ARC_MIN),
      self.getGlucoseDegree(GlucoseThresholds.VERY_LOW)
    );

    // Draw low zone (VERY_LOW - LOW)
    dc.setColor(GlucoseThresholds.getZoneColor(GlucoseThresholds.ZONE_LOW), Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(GlucoseThresholds.VERY_LOW),
      self.getGlucoseDegree(GlucoseThresholds.LOW)
    );

    // Draw in-range zone (LOW - HIGH)
    dc.setColor(GlucoseThresholds.getZoneColor(GlucoseThresholds.ZONE_IN_RANGE), Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(GlucoseThresholds.LOW),
      self.getGlucoseDegree(GlucoseThresholds.HIGH)
    );

    // Draw high zone (HIGH - VERY_HIGH)
    dc.setColor(GlucoseThresholds.getZoneColor(GlucoseThresholds.ZONE_HIGH), Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(GlucoseThresholds.HIGH),
      self.getGlucoseDegree(GlucoseThresholds.VERY_HIGH)
    );

    // Draw severe high zone (VERY_HIGH - ARC_MAX)
    dc.setColor(GlucoseThresholds.getZoneColor(GlucoseThresholds.ZONE_VERY_HIGH), Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(GlucoseThresholds.VERY_HIGH),
      endDegree
    );

    // Draw white indicator dot at current glucose position
    var currentDegree = self.getCurrentDegree();
    var circleDotRadius = penWidth * 1;
    
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
    dc.fillCircle(
      self.x + Math.cos(currentDegree * Math.PI / 180) * radius,
      self.y - Math.sin(currentDegree * Math.PI / 180) * radius,
      circleDotRadius
    );
    dc.setPenWidth(1);
  }

  function getCenterDegree() as Number {
    switch (self.position) {
      case "left": return 180;
      case "top": return 90;
      case "right": return 0;
      case "bottom": return 270;
      default: return 270;
    }
  }

  function getMultiplier() as Number {
    return self.direction == Graphics.ARC_CLOCKWISE ? -1 : 1;
  }

  function getStartDegree() as Number {
    return self.getCenterDegree() - (self.getMultiplier() * self.arcAngleRage / 2);
  }

  function getEndDegree() as Number {
    return self.getCenterDegree() + (self.getMultiplier() * self.arcAngleRage / 2);
  }

  function getCurrentDegree() as Number {
    return self.getGlucoseDegree(self.value);
  }

  function getGlucoseDegree(glucoseValue as Number) as Number {
    var multiplier = self.getMultiplier();
    var startDegree = self.getStartDegree();
    
    // Map glucose value (ARC_MIN - ARC_MAX mg/dL) to arc position
    var minGlucose = GlucoseThresholds.ARC_MIN.toFloat();
    var maxGlucose = GlucoseThresholds.ARC_MAX.toFloat();
    
    // Clamp glucose value to range
    var clampedValue = glucoseValue.toFloat();
    if (clampedValue < minGlucose) {
      clampedValue = minGlucose;
    } else if (clampedValue > maxGlucose) {
      clampedValue = maxGlucose;
    }
    
    // Calculate percentage across the range (0.0 to 1.0)
    var percentage = (clampedValue - minGlucose) / (maxGlucose - minGlucose);
    
    // Calculate degree position
    var currentDegree = (startDegree + (multiplier * self.arcAngleRage * percentage)).toNumber();

    if (currentDegree == startDegree) {
      return currentDegree + multiplier;
    }

    return currentDegree;
  }

  // Keep for backward compatibility but now uses getGlucoseDegree
  function getSpecificDegree(specificValue as Number) as Number {
    return self.getGlucoseDegree(specificValue);
  }
}
