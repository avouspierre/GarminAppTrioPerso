import Toybox.Lang;

module Sura {
  module StringHelper {
    class SortLengthDesc {
      function compare(x as String, y as String) as Number {
        return y.length() - x.length();
      }
    }

    function searchAndReplace(
      input as String,
      replacements as Dictionary<String, String>
    ) {
      var sortedKeys = replacements.keys();
      if (sortedKeys.size() == 0) {
        return input;
      }
      sortedKeys.sort(new SortLengthDesc() as Lang.Comparator);
      var output = input;

      for (var i = 0; i < sortedKeys.size(); i++) {
        var search = sortedKeys[i].toString();
        var foundIndex = output.find(search);
        while (foundIndex != null && foundIndex >= 0) {
          if (foundIndex != null && foundIndex >= 0) {
            var prepend = output.substring(0, foundIndex);
            var value = replacements[search];
            var append = output.substring(
              foundIndex + search.length(),
              output.length()
            );
            output = prepend + value + append;
            foundIndex = output.find(search);
          }
        }
      }

      return output;
    }

    function padStart(
      target as String,
      targetLength as Number,
      padChar as String
    ) as String {
      while (target.length() < targetLength) {
        target = padChar + target;
      }

      return target;
    }
  }
}
