import 'epub_theme.dart';

class EpubDisplaySettings {
  /// Font size of the reader
  int fontSize;

  /// Page spread settings
  EpubSpread spread;

  /// Page flow settings
  EpubFlow flow;

  /// Default reading direction
  EpubDefaultDirection defaultDirection;

  /// Allow or disallow scripts embedded in the EPUB content to run.
  ///
  /// Defaults to `false`. **Keep it `false` for untrusted EPUBs.** When `true`,
  /// scripts inside the book execute in the rendering context — and on the web
  /// that context is a same-origin iframe, so a malicious book could reach the
  /// host page. Only enable it for content you trust.
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
      EpubDisplaySettings(
        fontSize: (json['fontSize'] as num?)?.toInt() ?? 15,
        spread: EpubSpread.values.asNameMap()[json['spread']] ?? EpubSpread.auto,
        flow: EpubFlow.values.asNameMap()[json['flow']] ?? EpubFlow.paginated,
        allowScriptedContent: json['allowScriptedContent'] as bool? ?? false,
        defaultDirection:
            EpubDefaultDirection.values.asNameMap()[json['defaultDirection']] ??
                EpubDefaultDirection.ltr,
        snap: json['snap'] as bool? ?? true,
        useSnapAnimationAndroid:
            json['useSnapAnimationAndroid'] as bool? ?? false,
        manager: EpubManager.values.asNameMap()[json['manager']] ??
            EpubManager.continuous,
        theme: json['theme'] == null
            ? null
            : EpubTheme.fromJson(json['theme'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'spread': spread.name,
        'flow': flow.name,
        'defaultDirection': defaultDirection.name,
        'allowScriptedContent': allowScriptedContent,
        'manager': manager.name,
        'snap': snap,
        'useSnapAnimationAndroid': useSnapAnimationAndroid,
        if (theme != null) 'theme': theme!.toJson(),
      };
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
