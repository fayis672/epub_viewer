import 'package:flutter/material.dart';

extension ColorToHex on Color {
  /// Converts the [Color] to a hex string in the format #RRGGBB.
  /// If [includeAlpha] is true, the format will be #AARRGGBB.
  String toHex({bool includeAlpha = false}) {
    final alpha =
        includeAlpha ? this.alpha.toRadixString(16).padLeft(2, '0') : '';
    final red = this.red.toRadixString(16).padLeft(2, '0');
    final green = this.green.toRadixString(16).padLeft(2, '0');
    final blue = this.blue.toRadixString(16).padLeft(2, '0');
    return '#$alpha$red$green$blue';
  }
}

extension StringHexToColor on String {
  /// Converts a hex color string to a [Color] object.
  ///
  /// The input can be in the format #RRGGBB or #AARRGGBB.
  /// The # character at the beginning is optional.
  ///
  /// Throws a [FormatException] if the input is not a valid hex color string.
  Color get fromHex {
    // Remove the # if present
    final hex = startsWith('#') ? substring(1) : this;

    // Parse based on the length of the string
    if (hex.length == 6) {
      // Format is RRGGBB
      final red = int.parse(hex.substring(0, 2), radix: 16);
      final green = int.parse(hex.substring(2, 4), radix: 16);
      final blue = int.parse(hex.substring(4, 6), radix: 16);
      return Color.fromRGBO(red, green, blue, 1.0);
    } else if (hex.length == 8) {
      // Format is AARRGGBB
      final alpha = int.parse(hex.substring(0, 2), radix: 16);
      final red = int.parse(hex.substring(2, 4), radix: 16);
      final green = int.parse(hex.substring(4, 6), radix: 16);
      final blue = int.parse(hex.substring(6, 8), radix: 16);
      return Color.fromRGBO(red, green, blue, alpha / 255);
    } else {
      throw FormatException('Invalid hex color format: $hex');
    }
  }
}
