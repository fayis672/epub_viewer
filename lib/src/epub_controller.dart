import 'dart:async';
import 'dart:convert';

import 'package:flutter_epub_viewer/src/helper.dart';
import 'package:flutter_epub_viewer/src/utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'clear_storage_type.dart';

class EpubController {
  InAppWebViewController? webViewController;

  ///List of chapters from epub
  List<EpubChapter> _chapters = [];

  ///List of bookmarks
  List<EpubBookmark> _bookmarks = [];

  ///List of highlights
  List<EpubHighlight> _highlights = [];

  ///List of underlines
  List<EpubUnderline> _underlines = [];

  /// Completer for highlights updated callback
  Completer<List<EpubHighlight>>? _highlightsCompleter;

  /// Completer for underlines updated callback
  Completer<List<EpubUnderline>>? _underlinesCompleter;

  /// Getter for the highlights completer
  Completer<List<EpubHighlight>>? get highlightsCompleter =>
      _highlightsCompleter;

  /// Getter for the underlines completer
  Completer<List<EpubUnderline>>? get underlinesCompleter =>
      _underlinesCompleter;

  ///Current font size
  double _fontSize = 16.0;

  ///Current font family
  String _fontFamily = 'sans-serif';

  ///Current line height
  String _lineHeight = '1.5';

  ///Current theme name
  String _currentTheme = 'default';

  setWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  ///Move epub view to specific area using Cfi string or chapter href
  display({
    ///Cfi String of the desired location, also accepts chapter href
    required String cfi,
  }) {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'toCfi("$cfi")');
  }

  ///Moves to next page in epub view
  next() {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'next()');
  }

  ///Moves to previous page in epub view
  prev() {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'previous()');
  }

  ///Returns current location of epub viewer
  Future<EpubLocation> getCurrentLocation() async {
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'getCurrentLocation()');

    if (result == null) {
      throw Exception("Epub locations not loaded");
    }

    return EpubLocation.fromJson(result);
  }

  ///Returns list of [EpubChapter] from epub,
  /// should be called after onChaptersLoaded callback, otherwise returns empty list
  List<EpubChapter> getChapters() {
    checkEpubLoaded();
    return _chapters;
  }

  ///Parsing chapters list form epub
  Future<List<EpubChapter>> parseChapters() async {
    if (_chapters.isNotEmpty) return _chapters;
    checkEpubLoaded();
    final result =
        await webViewController!.evaluateJavascript(source: 'getChapters()');
    _chapters =
        List<EpubChapter>.from(result.map((e) => EpubChapter.fromJson(e)));
    return _chapters;
  }

  Completer searchResultCompleter = Completer<List<EpubSearchResult>>();

  ///Search in epub using query string
  ///Returns a list of [EpubSearchResult]
  Future<List<EpubSearchResult>> search({
    ///Search query string
    required String query,
    // bool optimized = false,
  }) async {
    searchResultCompleter = Completer<List<EpubSearchResult>>();
    if (query.isEmpty) return [];
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'searchInBook("$query")');
    return await searchResultCompleter.future;
  }

  ///Adds a highlight to epub viewer
  Future<String> addHighlight(EpubHighlight highlight) async {
    _highlightsCompleter = Completer<List<EpubHighlight>>();
    final colorHex = highlight.color;
    final opacityString = highlight.opacity.toString();
    final text = highlight.text;
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source:
            'addHighlight("${highlight.cfi}", "$colorHex", "$opacityString", "$text")');
    await _highlightsCompleter?.future;
    return result as String;
  }

  ///Adds an underline to epub viewer
  Future<String> addUnderline(EpubUnderline underline) async {
    _underlinesCompleter = Completer<List<EpubUnderline>>();
    final colorHex = underline.color;
    final opacityString = underline.opacity.toString();
    final thicknessString = underline.thickness.toString();
    final text = underline.text;
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source:
            'addUnderline("${underline.cfi}", "$colorHex", "$opacityString", "$thicknessString", "$text")');
    await _underlinesCompleter?.future;
    return result as String;
  }

  ///Adds an underline to the current selection
  Future<String?> addUnderlineToSelection({
    String color = '#0000ff',
    double opacity = 0.7,
    double thickness = 1.0,
  }) async {
    _underlinesCompleter = Completer<List<EpubUnderline>>();
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'addUnderline("$color", $opacity, $thickness)');
    await _underlinesCompleter?.future;
    return result as String?;
  }

  ///Removes a highlight from epub viewer
  Future<String?> removeHighlight(String cfi) async {
    _highlightsCompleter = Completer<List<EpubHighlight>>();
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'removeHighlight("$cfi")');
    await _highlightsCompleter?.future;
    return result as String?;
  }

  ///Removes an underline from epub viewer
  Future<void> removeUnderline(String cfi) async {
    _underlinesCompleter = Completer<List<EpubUnderline>>();
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'removeUnderline("$cfi")');
    await _underlinesCompleter?.future;
  }

  ///Set [EpubSpread] value
  setSpread({required EpubSpread spread}) async {
    await webViewController?.evaluateJavascript(source: 'setSpread("$spread")');
  }

  ///Set [EpubFlow] value
  setFlow({required EpubFlow flow}) async {
    await webViewController?.evaluateJavascript(source: 'setFlow("$flow")');
  }

  /// Apply multiple settings at once to reduce layout recalculations
  Future<void> applySettings({
    double? fontSize,
    String? fontFamily,
    String? lineHeight,
    EpubTheme? theme,
    EpubSpread? spread,
    EpubFlow? flow,
  }) async {
    checkEpubLoaded();

    // Update local state
    if (fontSize != null) _fontSize = fontSize;
    if (fontFamily != null) _fontFamily = fontFamily;
    if (lineHeight != null) _lineHeight = lineHeight;

    // Create settings JSON
    final Map<String, dynamic> settings = {};
    if (fontSize != null) settings['fontSize'] = fontSize;
    if (fontFamily != null) settings['fontFamily'] = fontFamily;
    if (lineHeight != null) settings['lineHeight'] = lineHeight;
    if (theme != null) {
      settings['theme'] = {
        'backgroundColor': theme.backgroundColor?.value,
        'foregroundColor': theme.foregroundColor?.value,
        'themeType': theme.themeType.toString().split('.').last,
      };
    }
    if (spread != null) settings['spread'] = spread.toString().split('.').last;
    if (flow != null) settings['flow'] = flow.toString().split('.').last;

    // Apply settings in a single JS call
    final settingsJson = jsonEncode(settings);
    await webViewController?.evaluateJavascript(
        source: 'applySettingsBatch($settingsJson)');
  }

  ///Set [EpubManager] value
  setManager({required EpubManager manager}) async {
    await webViewController?.evaluateJavascript(
        source: 'setManager("$manager")');
  }

  ///Adjust font size in epub viewer
  setFontSize(double size) {
    _fontSize = size;
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'setFontSize($size)');
  }

  updateTheme({required EpubTheme theme}) async {
    String? backgroundColor = theme.backgroundColor?.toHex();
    String? foregroundColor = theme.foregroundColor?.toHex();
    await webViewController?.evaluateJavascript(
        source: 'updateTheme("$backgroundColor","$foregroundColor")');
  }

  Completer<EpubTextExtractRes> pageTextCompleter =
      Completer<EpubTextExtractRes>();

  ///Extract text from a given cfi range,
  Future<EpubTextExtractRes> extractText({
    ///start cfi
    required startCfi,

    ///end cfi
    required endCfi,
  }) async {
    checkEpubLoaded();
    pageTextCompleter = Completer<EpubTextExtractRes>();
    await webViewController?.evaluateJavascript(
        source: 'getTextFromCfi("$startCfi","$endCfi")');
    return pageTextCompleter.future;
  }

  ///Extracts text content from current page
  Future<EpubTextExtractRes> extractCurrentPageText() async {
    checkEpubLoaded();
    pageTextCompleter = Completer<EpubTextExtractRes>();
    await webViewController?.evaluateJavascript(source: 'getCurrentPageText()');
    return pageTextCompleter.future;
  }

  ///Given a percentage moves to the corresponding page
  ///Progress percentage should be between 0.0 and 1.0
  toProgressPercentage(double progressPercent) {
    assert(progressPercent >= 0.0 && progressPercent <= 1.0,
        'Progress percentage must be between 0.0 and 1.0');
    checkEpubLoaded();
    webViewController?.evaluateJavascript(
        source: 'toProgress($progressPercent)');
  }

  ///Moves to the first page of the epub
  moveToFistPage() {
    toProgressPercentage(0.0);
  }

  ///Moves to the last page of the epub
  moveToLastPage() {
    toProgressPercentage(1.0);
  }

  /// Get page number from CFI
  /// Returns -1 if page list is not available
  Future<double> pageFromCfi(String cfi) async {
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'pageFromCfi("$cfi")');
    return double.tryParse(result) ?? 0;
  }

  /// Get CFI from page number
  /// Returns null if page list is not available or page not found
  Future<String?> cfiFromPage(int page) async {
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'cfiFromPage($page)');
    return result != null && result != -1 ? result.toString() : null;
  }

  /// Get page number from percentage (0.0 to 1.0)
  /// Returns -1 if page list is not available
  Future<double> pageFromPercentage(double percentage) async {
    assert(percentage >= 0.0 && percentage <= 1.0,
        'Percentage must be between 0.0 and 1.0');
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'pageFromPercentage($percentage)');
    return double.tryParse(result) ?? 0;
  }

  /// Get percentage (0.0 to 1.0) from page number
  /// Returns -1 if page list is not available
  Future<double> percentageFromPage(int page) async {
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'percentageFromPage($page)');
    return double.tryParse(result) ?? 0;
  }

  /// Get percentage (0.0 to 1.0) from CFI
  /// Returns -1 if page list is not available
  Future<double> percentageFromCfi(String cfi) async {
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'percentageFromCfi("$cfi")');
    return double.tryParse(result) ?? 0;
  }

  /// Get the current font size
  double get fontSize => _fontSize;

  /// Get the current font family
  String get fontFamily => _fontFamily;

  /// Get the current line height
  String get lineHeight => _lineHeight;

  /// Get the current theme name
  String get currentTheme => _currentTheme;

  /// Get the list of bookmarks
  List<EpubBookmark> get bookmarks => _bookmarks;

  /// Completer for bookmarks updated callback
  Completer<List<EpubBookmark>> bookmarksCompleter =
      Completer<List<EpubBookmark>>();

  /// Completer for metadata callback
  Completer<EpubMetadata> metadataCompleter = Completer<EpubMetadata>();

  /// Set font family for the book content
  Future<void> setFont({required String family}) async {
    _fontFamily = family;
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'setFont("$family")');
  }

  /// Set line height for the book content
  Future<void> setLineHeight({required String height}) async {
    _lineHeight = height;
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'setLineHeight("$height")');
  }

  /// Toggle spreads mode (single or double page view)
  Future<void> toggleSpreads({required String spread}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'toggleSpreads("$spread")');
  }

  /// Resize the viewport
  Future<void> setViewportSize(
      {required int width, required int height}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'setViewportSize($width, $height)');
  }

  /// Go to the first page of the book
  Future<void> firstPage() async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'firstPage()');
  }

  /// Go to the last page of the book
  Future<void> lastPage() async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'lastPage()');
  }

  /// Go to a specific chapter by ID
  Future<void> gotoChapter({required String chapterId}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'gotoChapter("$chapterId")');
  }

  /// Add a bookmark at the current location
  /// [customTitle] Optional custom title for the bookmark
  Future<String> addBookmark({String? customTitle}) async {
    checkEpubLoaded();
    bookmarksCompleter = Completer<List<EpubBookmark>>();
    final result = await webViewController?.evaluateJavascript(
        source: customTitle != null
            ? 'addBookmark("${customTitle.replaceAll('"', '\\"')}")'
            : 'addBookmark()');
    await bookmarksCompleter.future;
    return result as String;
  }

  /// Remove a bookmark by its CFI
  Future<void> removeBookmark({required String cfi}) async {
    checkEpubLoaded();
    bookmarksCompleter = Completer<List<EpubBookmark>>();
    await webViewController?.evaluateJavascript(
        source: 'removeBookmark("$cfi")');
    await bookmarksCompleter.future;
  }

  /// Get all bookmarks
  Future<List<EpubBookmark>> getBookmarks() async {
    checkEpubLoaded();
    final result =
        await webViewController?.evaluateJavascript(source: 'bookmarks');
    if (result != null) {
      _bookmarks = List<EpubBookmark>.from(
          (result as List).map((e) => EpubBookmark.fromJson(e)));
    }
    return _bookmarks;
  }

  /// Get all highlights
  Future<List<EpubHighlight>> getHighlights() async {
    checkEpubLoaded();
    final result =
        await webViewController?.evaluateJavascript(source: 'highlights');
    if (result != null) {
      _highlights = List<EpubHighlight>.from(
          (result as List).map((e) => EpubHighlight.fromJson(e)));
    }
    return _highlights;
  }

  /// Get all underlines
  Future<List<EpubUnderline>> getUnderlines() async {
    checkEpubLoaded();
    final result =
        await webViewController?.evaluateJavascript(source: 'getUnderlines()');
    if (result != null) {
      _underlines = List<EpubUnderline>.from(
          (result as List).map((e) => EpubUnderline.fromJson(e)));
    }
    return _underlines;
  }

  /// Go to a bookmarked location
  Future<void> goTo({required String cfi}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'goTo("$cfi")');
  }

  /// Get book metadata
  Future<EpubMetadata> getMetadata() async {
    checkEpubLoaded();
    metadataCompleter = Completer<EpubMetadata>();
    final result =
        await webViewController?.evaluateJavascript(source: 'getMetadata()');
    if (result != null) {
      return EpubMetadata.fromJson(result);
    }
    throw Exception("Failed to get metadata");
  }

  /// Register a new theme with custom styles
  Future<void> registerTheme(
      {required String name, required Map<String, dynamic> styles}) async {
    checkEpubLoaded();
    final stylesJson = jsonEncode(styles);
    await webViewController?.evaluateJavascript(
        source: 'registerTheme("$name", $stylesJson)');
    _currentTheme = name;
  }

  /// Select a theme by name
  Future<void> selectTheme({required String name}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'selectTheme("$name")');
    _currentTheme = name;
  }

  /// Export all annotations as JSON
  Future<String> exportAnnotations() async {
    checkEpubLoaded();
    final result = await webViewController?.evaluateJavascript(
        source: 'exportAnnotations()');
    return result as String;
  }

  /// Import annotations from JSON
  Future<void> importAnnotations({required String json}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'importAnnotations(${jsonEncode(json)})');
  }

  /// Display table of contents
  Future<List<EpubChapter>> displayTOC() async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'displayTOC()');
    return _chapters;
  }

  /// Go to a specific page number
  Future<void> goToPage({required int pageNumber}) async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(
        source: 'goToPage($pageNumber)');
  }

  /// Save the current reading state
  Future<void> saveReadingState() async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'saveReadingState()');
  }

  /// Load reading state from localStorage
  Future<void> loadReadingState() async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'loadReadingState()');
  }

  /// Clear memory cache to reduce memory usage
  Future<void> clearMemoryCache() async {
    checkEpubLoaded();
    await InAppWebViewController.clearAllCache();
    // Clear JavaScript memory
    await webViewController?.evaluateJavascript(source: 'clearMemoryCache()');
  }

  /// Completer for storage cleared callback
  Completer<String>? _storageCleared;

  /// Getter for the storage cleared completer
  Completer<String>? get storageCleared => _storageCleared;

  /// Clear stored reading state from localStorage
  /// [type] can be: 'all', 'bookmarks', 'highlights', or 'current-book'
  /// - 'all': Clears all stored data
  /// - 'bookmarks': Clears only bookmarks
  /// - 'highlights': Clears only highlights
  /// - 'current-book': Clears data only for the current book
  Future<bool> clearStorage({
    ClearStorageType type = ClearStorageType.currentBook,
  }) async {
    checkEpubLoaded();
    _storageCleared = Completer<String>();

    // Reset local lists based on what's being cleared
    if (type == ClearStorageType.all ||
        type == ClearStorageType.bookmarks ||
        type == ClearStorageType.currentBook) {
      _bookmarks = [];
    }

    if (type == ClearStorageType.all ||
        type == ClearStorageType.highlights ||
        type == ClearStorageType.currentBook) {
      _highlights = [];
    }

    final result = await webViewController?.evaluateJavascript(
        source: 'clearStorage("${type.value}")');

    // Wait for the storage cleared callback
    await _storageCleared?.future;

    return result == true;
  }

  /// Prefetch content for smoother reading
  Future<void> prefetchContent() async {
    checkEpubLoaded();
    await webViewController?.evaluateJavascript(source: 'prefetchContent()');
  }

  checkEpubLoaded() {
    if (webViewController == null) {
      throw Exception(
          "Epub viewer is not loaded, wait for onEpubLoaded callback");
    }
  }
}

class LocalServerController {
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
      documentRoot: 'packages/flutter_epub_viewer/lib/assets/webpage');

  Future<void> initServer() async {
    if (_localhostServer.isRunning()) return;
    await _localhostServer.start();
  }

  Future<void> disposeServer() async {
    if (!_localhostServer.isRunning()) return;
    await _localhostServer.close();
  }
}
