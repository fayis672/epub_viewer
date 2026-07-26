import 'dart:ui';

class Utils {
  /// Normalizes a value coming from the JS bridge into a `Map<String, dynamic>`.
  ///
  /// On mobile the bridge already yields `Map<String, dynamic>`; on the web
  /// `dartify` / JSON decoding can yield `Map<Object?, Object?>`, so convert
  /// defensively.
  static Map<String, dynamic> asStringMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
}

extension ColorToHex on Color {
  /// Converts the [Color] to a hex string in the format #RRGGBB.
  /// If [includeAlpha] is true, the format will be #AARRGGBB.
  String toHex({bool includeAlpha = false}) {
    String channel(double v) =>
        (v * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final alpha = includeAlpha ? channel(a) : '';
    return '#$alpha${channel(r)}${channel(g)}${channel(b)}';
  }
}
