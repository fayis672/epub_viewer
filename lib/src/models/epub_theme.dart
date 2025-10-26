import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'color_converter.dart';

part 'epub_theme.g.dart';

///Theme type
enum EpubThemeType { dark, light, custom }

///Class for customizing the theme of the reader
@JsonSerializable()
@ColorConverter()
class EpubTheme {
  Color? backgroundColor;
  Color? foregroundColor;
  EpubThemeType themeType;

  EpubTheme({
    this.backgroundColor,
    this.foregroundColor,
    required this.themeType,
  });

  /// Uses dark theme, black background and white foreground color
  factory EpubTheme.dark() {
    return EpubTheme(
      backgroundColor: const Color(0xff121212),
      foregroundColor: Colors.white,
      themeType: EpubThemeType.dark,
    );
  }

  /// Uses light theme, white background and black foreground color
  factory EpubTheme.light() {
    return EpubTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      themeType: EpubThemeType.light,
    );
  }

  /// Custom theme option ,
  factory EpubTheme.custom({
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return EpubTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      themeType: EpubThemeType.custom,
    );
  }

  factory EpubTheme.fromJson(Map<String, dynamic> json) =>
      _$EpubThemeFromJson(json);
  Map<String, dynamic> toJson() => _$EpubThemeToJson(this);
}
