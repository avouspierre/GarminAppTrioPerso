import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
using Toybox.Time.Gregorian as Date;

module Sura {
  module Datetime {
    var is24Hour as Boolean = false;
    var clockTime as System.ClockTime? = null;

    function init() {
      self.is24Hour = System.getDeviceSettings().is24Hour;
      self.clockTime = System.getClockTime();
    }

    function getAmPm() as String {
      if (clockTime == null) {
        return "";
      }
      return self.is24Hour
        ? ""
        : clockTime.hour >= 12 && clockTime.hour < 24
        ? "PM"
        : "AM";
    }

    function getTimeText() as String {
      if (clockTime == null) {
        return "";
      }

      var hour = self.is24Hour
        ? clockTime.hour
        : clockTime.hour % 12 == 0
        ? 12
        : clockTime.hour % 12;
      var timeText = Lang.format("$1$:$2$", [
        hour.format(store.hourLeadingZero ? "%02d" : "%01d"),
        clockTime.min.format("%02d"),
      ]);

      return timeText;
    }

    function getDateText() as String {
      return getDateFormat(store.dateFormat);
    }

    function getDateFormat(dateFormat as String) {
      var now = Time.now();
      var nowLong = Date.info(now, Time.FORMAT_LONG);
      var nowShort = Date.info(now, Time.FORMAT_SHORT);

      var replacements = {
        "yyyy" => nowLong.year.toString(),

        "mmm" => nowLong.month.toString(),
        "ddd" => nowLong.day_of_week.toString(),

        "yy" => nowLong.year.toString().substring(2, 4),
        "mm" => nowShort.month.format("%02d"),
        "dd" => nowShort.day.format("%02d"),

        "m" => nowShort.month.format("%01d"),
        "d" => nowShort.day.format("%01d"),
      };

      return StringHelper.searchAndReplace(dateFormat, replacements);
    }

    function getSecondsText() as String {
      if (clockTime == null) {
        return "";
      }

      var secondsText = Lang.format("$1$", [clockTime.sec.format("%02d")]);

      return secondsText;
    }
  }
}
