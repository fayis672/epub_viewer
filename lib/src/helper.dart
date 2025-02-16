import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:json_annotation/json_annotation.dart';
part 'helper.g.dart';

/// Epub chapter object
@JsonSerializable(explicitToJson: true)
class EpubChapter {
  /// The title of the chapter
  final String title;

  /// The href of the chapter, use to navigate to the chapter
  final String href;
  final String id;

  /// The subchapters of the chapter
  final List<EpubChapter> subitems;

  EpubChapter({
    required this.title,
    required this.href,
    required this.id,
    required this.subitems,
  });
  factory EpubChapter.fromJson(Map<String, dynamic> json) =>
      _$EpubChapterFromJson(json);
  Map<String, dynamic> toJson() => _$EpubChapterToJson(this);
}

@JsonSerializable(explicitToJson: true)
class EpubSearchResult {
  /// The cfi string search result
  String cfi;

  /// The excerpt of the search result
  String excerpt;

  EpubSearchResult({
    required this.cfi,
    required this.excerpt,
  });
  factory EpubSearchResult.fromJson(Map<String, dynamic> json) =>
      _$EpubSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$EpubSearchResultToJson(this);
}

@JsonSerializable(explicitToJson: true)
class EpubLocation {
  /// Start cfi string of the page
  String startCfi;

  /// End cfi string of the page
  String endCfi;

  /// Progress percentage of location, value between 0.0 and 1.0
  double progress;

  EpubLocation({
    required this.startCfi,
    required this.endCfi,
    required this.progress,
  });
  factory EpubLocation.fromJson(Map<String, dynamic> json) =>
      _$EpubLocationFromJson(json);
  Map<String, dynamic> toJson() => _$EpubLocationToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class EpubDisplaySettings {
  /// Font size of the reader
  int fontSize;

  /// Page spread settings
  EpubSpread spread;

  /// Page flow settings
  EpubFlow flow;

  /// Default reading direction
  EpubDefaultDirection defaultDirection;

  /// Allow or disallow scripted content
  bool allowScriptedContent;

  /// Manager type
  EpubManager manager;

  /// Enables swipe between pages
  bool snap;

  ///Uses animation between page snapping when snap is true.
  /// **Warning:** Using this animation will break `onRelocated` callback
  final bool useSnapAnimationAndroid;

  /// Theme of the reader, by default it uses the book theme
  final EpubTheme? theme;

  EpubDisplaySettings({
    this.fontSize = 15,
    this.spread = EpubSpread.auto,
    this.flow = EpubFlow.paginated,
    this.allowScriptedContent = false,
    this.defaultDirection = EpubDefaultDirection.ltr,
    this.snap = true,
    this.useSnapAnimationAndroid = false,
    this.manager = EpubManager.continuous,
    this.theme,
  });
  factory EpubDisplaySettings.fromJson(Map<String, dynamic> json) =>
      _$EpubDisplaySettingsFromJson(json);
  Map<String, dynamic> toJson() => _$EpubDisplaySettingsToJson(this);
}

enum EpubSpread {
  ///Displays a single page in viewer
  none,

  ///Displays two pages in viewer
  always,

  ///Displays single or two pages in viewer depending on the device size
  auto,
}

enum EpubFlow {
  ///Displays contents page by page
  paginated,

  ///Displays contents in a single scroll view
  scrolled,
}

enum EpubDefaultDirection { ltr, rtl }

enum EpubManager {
  continuous,
  // epub
}

///Epub text selection callback object
class EpubTextSelection {
  /// The selected text
  final String selectedText;

  /// The cfi string of the selected text
  final String selectionCfi;

  EpubTextSelection({
    required this.selectedText,
    required this.selectionCfi,
  });
}

/// Epub file source
class EpubSource {
  // final Uint8List epubData;
  final Future<Uint8List> epubData;

  EpubSource._({required this.epubData});

  ///Loading from a file
  factory EpubSource.fromFile(File file) {
    return EpubSource._(epubData: file.readAsBytes());
  }

  ///load from a url with optional headers
  factory EpubSource.fromUrl(String url, {Map<String, String>? headers}) {
    return EpubSource._(epubData: _downloadFile(url, headers: headers));
  }

  ///load from assets
  factory EpubSource.fromAsset(String assetPath) {
    return EpubSource._(epubData: _getAssetData(assetPath));
  }

  static Future<Uint8List> _getAssetData(assetPath) {
    final byteData = rootBundle.load(assetPath);
    return byteData.then((val) => val.buffer.asUint8List());
  }

  static Future<Uint8List> _downloadFile(String url,
      {Map<String, String>? headers}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download file from URL');
      }
    } catch (e) {
      throw Exception('Failed to download file from URL, $e');
    }
  }
}

///Theme type
enum EpubThemeType { dark, light, custom }

///Class for customizing the theme of the reader
class EpubTheme {
  Color? backgroundColor;
  Color? foregroundColor;
  EpubThemeType themeType;

  EpubTheme._({
    this.backgroundColor,
    this.foregroundColor,
    required this.themeType,
  });

  /// Uses dark theme, black background and white foreground color
  factory EpubTheme.dark() {
    return EpubTheme._(
      backgroundColor: const Color(0xff121212),
      foregroundColor: Colors.white,
      themeType: EpubThemeType.dark,
    );
  }

  /// Uses light theme, white background and black foreground color
  factory EpubTheme.light() {
    return EpubTheme._(
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
    return EpubTheme._(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      themeType: EpubThemeType.custom,
    );
  }
}

@JsonSerializable(explicitToJson: true)

///Epub text extraction callback object
class EpubTextExtractRes {
  String? text;
  String? cfiRange;

  EpubTextExtractRes({
    this.text,
    this.cfiRange,
  });
  factory EpubTextExtractRes.fromJson(Map<String, dynamic> json) =>
      _$EpubTextExtractResFromJson(json);
  Map<String, dynamic> toJson() => _$EpubTextExtractResToJson(this);
}
