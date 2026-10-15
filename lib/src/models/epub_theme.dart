import 'package:flutter/material.dart';

///Theme type
enum EpubThemeType { dark, light, custom }

///Class for customizing the theme of the reader
class EpubTheme {
  ///Background decoration of the reader, overrides customCss
  Decoration? backgroundDecoration;
  ///Foreground color of the reader, overrides customCss
  Color? foregroundColor;
  ///Custom css for the reader
  Map<String, dynamic>? customCss;
  EpubThemeType themeType;

  EpubTheme({
    this.backgroundDecoration,
    this.foregroundColor,
    this.customCss,
    required this.themeType,
  });

  /// Uses dark theme, black background and white foreground color
  factory EpubTheme.dark() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Color(0xff121212)),
      foregroundColor: Colors.white,
      themeType: EpubThemeType.dark,
    );
  }

  /// Uses light theme, white background and black foreground color
  factory EpubTheme.light() {
    return EpubTheme(
      backgroundDecoration: const BoxDecoration(color: Colors.white),
      foregroundColor: Colors.black,
      themeType: EpubThemeType.light,
    );
  }

  /// Custom theme option ,
  factory EpubTheme.custom({
    Decoration? backgroundDecoration,
    Color? foregroundColor,
    Map<String, dynamic>? customCss,
  }) {
    return EpubTheme(
      backgroundDecoration: backgroundDecoration,
      foregroundColor: foregroundColor,
      customCss: customCss,
      themeType: EpubThemeType.custom,
    );
  }

  /// [backgroundDecoration] is not serialized and is null after [fromJson].
  /// [foregroundColor] is stored as an ARGB hex string.
  factory EpubTheme.fromJson(Map<String, dynamic> json) {
    final color = json['foregroundColor'] as String?;
    return EpubTheme(
      foregroundColor: color == null ? null : Color(int.parse(color, radix: 16)),
      customCss: (json['customCss'] as Map?)?.cast<String, dynamic>(),
      themeType: EpubThemeType.values.byName(json['themeType'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'backgroundDecoration': null,
        'foregroundColor': foregroundColor?.toARGB32().toRadixString(16),
        'customCss': customCss,
        'themeType': themeType.name,
      };
}
