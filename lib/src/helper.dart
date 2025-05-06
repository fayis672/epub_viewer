import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  const EpubChapter({
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
  final String cfi;

  /// The excerpt of the search result
  final String excerpt;

  const EpubSearchResult({
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
  final String? startCfi;

  /// End cfi string of the page
  final String? endCfi;

  /// Progress percentage of location, value between 0.0 and 1.0
  final double progress;

  const EpubLocation({
    this.startCfi,
    this.endCfi,
    this.progress = 0,
  });
  factory EpubLocation.fromJson(Map<String, dynamic> json) =>
      _$EpubLocationFromJson(json);
  Map<String, dynamic> toJson() => _$EpubLocationToJson(this);
}

@JsonSerializable(explicitToJson: true, includeIfNull: false)
class EpubDisplaySettings {
  /// Font size of the reader
  final int fontSize;

  /// Page spread settings
  final EpubSpread spread;

  /// Page flow settings
  final EpubFlow flow;

  /// Default reading direction
  final EpubDefaultDirection defaultDirection;

  /// Allow or disallow scripted content
  final bool allowScriptedContent;

  /// Manager type
  final EpubManager manager;

  /// Enables swipe between pages
  final bool snap;

  ///Uses animation between page snapping when snap is true.
  /// **Warning:** Using this animation will break `onRelocated` callback
  final bool useSnapAnimationAndroid;

  /// Theme of the reader, by default it uses the book theme
  @JsonKey(fromJson: _themeFromJson, toJson: _themeToJson)
  final EpubTheme? theme;

  const EpubDisplaySettings({
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

  // Helper methods for theme JSON conversion
  static EpubTheme? _themeFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final themeType = EpubThemeType.values.firstWhere(
      (e) => e.toString() == 'EpubThemeType.${json["themeType"]}',
      orElse: () => EpubThemeType.light,
    );

    final backgroundColor = json['backgroundColor'] != null
        ? Color(json['backgroundColor'] as int)
        : null;

    final foregroundColor = json['foregroundColor'] != null
        ? Color(json['foregroundColor'] as int)
        : null;

    return EpubTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      themeType: themeType,
    );
  }

  static Map<String, dynamic>? _themeToJson(EpubTheme? theme) {
    if (theme == null) return null;

    return {
      'backgroundColor': theme.backgroundColor?.value,
      'foregroundColor': theme.foregroundColor?.value,
      'themeType': theme.themeType.toString().split('.').last,
    };
  }
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

/// Abstract interface for loading epub data
abstract class EpubDataLoader {
  Future<Uint8List> loadData();
}

/// File system epub loader implementation
class FileEpubLoader implements EpubDataLoader {
  final File file;

  FileEpubLoader(this.file);

  @override
  Future<Uint8List> loadData() {
    return file.readAsBytes();
  }
}

/// Network/URL epub loader implementation
class UrlEpubLoader implements EpubDataLoader {
  final String url;
  final Map<String, String>? headers;
  final bool isCachedToLocal;

  UrlEpubLoader(
    this.url, {
    this.headers,
    this.isCachedToLocal = false,
  });

  @override
  Future<Uint8List> loadData() async {
    try {
      if (isCachedToLocal) {
        // Get the application documents directory
        final appDocDir = await getApplicationDocumentsDirectory();
        final fileName = _getFileNameFromUrl(url);
        final filePath = '${appDocDir.path}/$fileName';
        final file = File(filePath);

        // Check if the file already exists in the cache
        if (await file.exists()) {
          return await file.readAsBytes();
        } else {
          // Download the file
          final response = await http.get(Uri.parse(url), headers: headers);

          if (response.statusCode == 200) {
            // Save the file to the local cache
            await file.writeAsBytes(response.bodyBytes);
            return response.bodyBytes;
          } else {
            throw Exception('Failed to download file from URL');
          }
        }
      } else {
        final response = await http.get(Uri.parse(url), headers: headers);

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('Failed to download file from URL');
        }
      }
    } catch (e) {
      throw Exception('Failed to download file from URL, $e');
    }
  }

  /// Extracts a filename from the URL
  String _getFileNameFromUrl(String url) {
    Uri uri = Uri.parse(url);
    String path = uri.path;
    String fileName = path.split('/').last;

    // If the URL doesn't have a filename, generate a hash-based filename
    if (fileName.isEmpty) {
      fileName = 'epub_${url.hashCode.toString()}.epub';
    }

    return fileName;
  }
}

/// Asset epub loader implementation
class AssetEpubLoader implements EpubDataLoader {
  final String assetPath;

  AssetEpubLoader(this.assetPath);

  @override
  Future<Uint8List> loadData() async {
    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }
}

/// Epub file source
class EpubSource {
  // final Uint8List epubData;
  final Future<Uint8List> epubData;

  EpubSource._({required this.epubData});

  ///Loading from a file
  factory EpubSource.fromFile(File file) {
    final loader = FileEpubLoader(file);
    return EpubSource._(epubData: loader.loadData());
  }

  ///load from a url with optional headers
  factory EpubSource.fromUrl(
    String url, {
    Map<String, String>? headers,
    bool isCachedToLocal = false,
  }) {
    final loader =
        UrlEpubLoader(url, headers: headers, isCachedToLocal: isCachedToLocal);
    return EpubSource._(epubData: loader.loadData());
  }

  ///load from assets
  factory EpubSource.fromAsset(String assetPath) {
    final loader = AssetEpubLoader(assetPath);
    return EpubSource._(epubData: loader.loadData());
  }
}

///Theme type
enum EpubThemeType { dark, light, custom }

///Class for customizing the theme of the reader
class EpubTheme {
  Color? backgroundColor;
  Color? foregroundColor;
  EpubThemeType themeType;

  /// Default constructor
  EpubTheme({
    this.backgroundColor,
    this.foregroundColor,
    required this.themeType,
  });

  /// Private constructor for internal use
  EpubTheme._({
    this.backgroundColor,
    this.foregroundColor,
    required this.themeType,
  });

  /// Uses dark theme, black background and white foreground color
  factory EpubTheme.dark({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return EpubTheme._(
      backgroundColor: backgroundColor ?? Colors.black,
      foregroundColor: foregroundColor ?? Colors.white,
      themeType: EpubThemeType.dark,
    );
  }

  /// Uses light theme, white background and black foreground color
  factory EpubTheme.light({
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return EpubTheme._(
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: foregroundColor ?? Colors.black,
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

/// JSON converter for EpubTheme
class EpubThemeConverter
    implements JsonConverter<EpubTheme?, Map<String, dynamic>?> {
  const EpubThemeConverter();

  @override
  EpubTheme? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final themeType = EpubThemeType.values.firstWhere(
      (e) => e.toString() == 'EpubThemeType.${json["themeType"]}',
      orElse: () => EpubThemeType.light,
    );

    final backgroundColor = json['backgroundColor'] != null
        ? Color(json['backgroundColor'] as int)
        : null;

    final foregroundColor = json['foregroundColor'] != null
        ? Color(json['foregroundColor'] as int)
        : null;

    return EpubTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      themeType: themeType,
    );
  }

  @override
  Map<String, dynamic>? toJson(EpubTheme? theme) {
    if (theme == null) return null;

    return {
      'backgroundColor': theme.backgroundColor?.value,
      'foregroundColor': theme.foregroundColor?.value,
      'themeType': theme.themeType.toString().split('.').last,
    };
  }
}

///Epub text extraction callback object
@JsonSerializable(explicitToJson: true)
class EpubTextExtractRes {
  final String? text;
  final String? cfiRange;

  EpubTextExtractRes({
    this.text,
    this.cfiRange,
  });

  factory EpubTextExtractRes.fromJson(Map<String, dynamic> json) =>
      _$EpubTextExtractResFromJson(json);

  Map<String, dynamic> toJson() => _$EpubTextExtractResToJson(this);
}

/// Represents a bookmark in the EPUB book
@JsonSerializable(explicitToJson: true)
class EpubBookmark {
  /// The CFI string of the bookmark location
  final String cfi;

  /// The title or description of the bookmark
  final String title;

  EpubBookmark({
    required this.cfi,
    required this.title,
  });

  factory EpubBookmark.fromJson(Map<String, dynamic> json) =>
      _$EpubBookmarkFromJson(json);

  Map<String, dynamic> toJson() => _$EpubBookmarkToJson(this);
}

class EpubHighlight {
  /// The CFI string of the highlight location
  final String cfi;

  /// The text that is highlighted
  final String text;

  /// The color of the highlight
  final String color;

  /// The opacity of the highlight
  final double opacity;

  EpubHighlight({
    required this.cfi,
    required this.text,
    required this.color,
    required this.opacity,
  });

  factory EpubHighlight.fromJson(Map<String, dynamic> json) {
    return EpubHighlight(
      cfi: json['cfi'] as String,
      text: json['text'] as String,
      color: json['color'] as String,
      opacity: double.parse(json['opacity'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cfi': cfi,
      'text': text,
      'color': color,
      'opacity': opacity.toString(),
    };
  }
}

/// Represents an underline in the epub
class EpubUnderline {
  /// The CFI string of the underline location
  final String cfi;

  /// The text that is underlined
  final String text;

  /// The color of the underline
  final String color;

  /// The opacity of the underline
  final double opacity;
  
  /// The thickness of the underline in pixels
  final double thickness;

  EpubUnderline({
    required this.cfi,
    required this.text,
    required this.color,
    required this.opacity,
    required this.thickness,
  });

  factory EpubUnderline.fromJson(Map<String, dynamic> json) {
    return EpubUnderline(
      cfi: json['cfi'] as String,
      text: json['text'] as String,
      color: json['color'] as String,
      opacity: double.parse(json['opacity'].toString()),
      thickness: double.parse(json['thickness'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cfi': cfi,
      'text': text,
      'color': color,
      'opacity': opacity.toString(),
      'thickness': thickness.toString(),
    };
  }
}

/// Represents book metadata
@JsonSerializable(explicitToJson: true)
class EpubMetadata {
  final String? identifier;

  /// The title of the book
  final String? title;

  /// The author/creator of the book
  final String? creator;

  /// The publisher of the book
  final String? publisher;

  /// The language of the book
  final String? language;

  /// The publication date
  final String? pubdate;

  /// The last modified date
  final String? modifiedDate;

  /// Copyright information
  final String? rights;

  /// Book description
  final String? description;

  EpubMetadata({
    this.identifier,
    this.title,
    this.creator,
    this.publisher,
    this.language,
    this.pubdate,
    this.modifiedDate,
    this.rights,
    this.description,
  });

  factory EpubMetadata.fromJson(Map<String, dynamic> json) =>
      _$EpubMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$EpubMetadataToJson(this);
}
