import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;
import Toybox.Graphics;

class ArcGoalGraphView extends BaseView {
  var value as Number = 0;
  var goal as Number = 1;
  var color as Graphics.ColorValue = Graphics.COLOR_BLUE;
  var backgroundColor as Number = store.foregroundColor;
  var direction as Graphics.ArcDirection = Graphics.ARC_CLOCKWISE;
  var radius as Number = 40;
  var position as String = "bottom";
  var arcAngleRage as Number = 180;

  function initialize(params as {
    :value as Number?,
    :goal as Number?,
    :color as Graphics.ColorValue?,
    :backgroundColor as Graphics.ColorValue?,
    :direction as Graphics.ArcDirection?,
    :radius as Number?,
    :position as String?,
    :arcAngleRage as Number?,
  }) {
    BaseView.initialize();
    var value = params[:value];
    var goal = 180;  // params[:goal];
    var color = params[:color];
    var backgroundColor = params[:backgroundColor];
    var direction = params[:direction];
    var radius = params[:radius];
    var position = params[:position];
    var arcAngleRage = params[:arcAngleRage];

    if (value != null) {
      self.value = value;
    }
    if (goal != null) {
      self.goal = goal;
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

  function setData(params as { :value as Number, :goal as Number }) as Void {
    var value = params[:value];
    var goal = 180; //params[:goal];

    if (value != null) {
      self.value = value;
    }

    if (goal != null) {
      self.goal = goal;
    }
  }
  
  function draw(dc as Dc) as Void {
    dc.setColor(self.backgroundColor, self.backgroundColor);
    var penWidth = 13;
    var radius = (self.radius - penWidth / 2).toNumber();
    dc.setPenWidth(penWidth);
    
    var endDegree = self.getEndDegree();


    
    // Define color zones based on glucose values:
    // Red: 40-70 (hypoglycemia)
    // Yellow: 70-100 (low target)
    // Green: 100-180 (target range)
    // Yellow: 180-210 (high target)
    // Red: 210-250+ (hyperglycemia)
     
    // Draw red zone (40-70)
    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(40),
      self.getGlucoseDegree(70)
    );
 
    // Draw yellow zone (70-100)
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(70),
      self.getGlucoseDegree(100)
    );
 
    // Draw green zone (100-180)
    dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(100),
      self.getGlucoseDegree(180)
    );
 
    // Draw yellow zone (180-210)
    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(180),
      self.getGlucoseDegree(210)
    );
 
    // Draw red zone (210-220)
    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
    dc.drawArc(
      self.x,
      self.y,
      radius,
      self.direction,
      self.getGlucoseDegree(210),
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
    
    // Map glucose value (40-250 mg/dL) to arc position
    var minGlucose = 40.0;
    var maxGlucose = 250.0;
    
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
