import 'dart:async';

import 'package:flutter_epub_viewer/src/epub_metadata.dart';
import 'package:flutter_epub_viewer/src/models/epub_display_settings.dart';
import 'package:flutter_epub_viewer/src/models/epub_location.dart';
import 'package:flutter_epub_viewer/src/models/epub_search_result.dart';
import 'package:flutter_epub_viewer/src/models/epub_text_extract_res.dart';
import 'package:flutter_epub_viewer/src/utils.dart';
import 'package:flutter/material.dart';
import 'platform/epub_web_view.dart';
import 'models/epub_chapter.dart';
import 'models/epub_theme.dart';

class EpubController {
  /// Platform bridge to the epub.js runtime.
  ///
  /// Backed by flutter_inappwebview on mobile/desktop and by a native
  /// `<iframe>` + `dart:js_interop` on the web.
  EpubWebViewController? webViewController;

  /// Maximum time to wait for a request/response call before giving up.
  ///
  /// Guarantees request methods never hang forever if the JS side fails to
  /// reply (previously a stuck `Completer` leaked indefinitely). Adjustable for
  /// slow devices or large books.
  Duration requestTimeout = const Duration(seconds: 20);

  ///List of chapters from epub
  List<EpubChapter> _chapters = [];

  setWebViewController(EpubWebViewController controller) {
    webViewController = controller;
  }

  Future<dynamic> _request(String name, [List<dynamic> args = const []]) {
    checkEpubLoaded();
    // `Future.timeout` throws a [TimeoutException] (dart:async) if the JS side
    // never replies, so a request never hangs forever.
    return webViewController!.callAsync(name, args).timeout(requestTimeout);
  }

  ///Move epub view to specific area using Cfi string, XPath/XPointer, or chapter href
  display({
    ///Cfi String, XPath/XPointer string, or chapter href of the desired location
    ///If the string starts with '/', it will be treated as XPath/XPointer
    required String cfi,
  }) {
    checkEpubLoaded();
    webViewController?.callMethod('toCfi', [cfi]);
  }

  ///Moves to next page in epub view
  next() {
    checkEpubLoaded();
    webViewController?.callMethod('next');
  }

  ///Moves to previous page in epub view
  prev() {
    checkEpubLoaded();
    webViewController?.callMethod('previous');
  }

  ///Returns current location of epub viewer
  Future<EpubLocation> getCurrentLocation() async {
    final result = await _request('getCurrentLocation');
    return EpubLocation.fromJson(Utils.asStringMap(result));
  }

  ///Returns list of [EpubChapter] from epub,
  /// should be called after onChaptersLoaded callback, otherwise returns empty list
  List<EpubChapter> getChapters() {
    checkEpubLoaded();
    return _chapters;
  }

  Future<List<EpubChapter>> parseChapters() async {
    if (_chapters.isNotEmpty) return _chapters;
    final result = await _request('getChapters');
    _chapters = parseChapterList(result);
    return _chapters;
  }

  Future<EpubMetadata> getMetadata() async {
    final result = await _request('getBookInfo');
    return EpubMetadata.fromJson(Utils.asStringMap(result));
  }

  ///Search in epub using query string
  ///Returns a list of [EpubSearchResult]
  Future<List<EpubSearchResult>> search({
    ///Search query string
    required String query,
  }) async {
    if (query.isEmpty) return [];
    final result = await _request('searchInBook', [query]);
    return List<EpubSearchResult>.from(
      (result as List).map((e) => EpubSearchResult.fromJson(Utils.asStringMap(e))),
    );
  }

  ///Adds a highlight to epub viewer
  addHighlight({
    ///Cfi string of the desired location
    required String cfi,

    ///Color of the highlight
    Color color = Colors.yellow,

    ///Opacity of the highlight
    double opacity = 0.3,
  }) {
    var colorHex = color.toHex();
    var opacityString = opacity.toString();
    checkEpubLoaded();
    webViewController?.callMethod('addHighlight', [cfi, colorHex, opacityString]);
  }

  ///Adds a underline annotation
  addUnderline({required String cfi}) {
    checkEpubLoaded();
    webViewController?.callMethod('addUnderLine', [cfi]);
  }

  ///Removes a highlight from epub viewer
  removeHighlight({required String cfi}) {
    checkEpubLoaded();
    webViewController?.callMethod('removeHighlight', [cfi]);
  }

  ///Removes a underline from epub viewer
  removeUnderline({required String cfi}) {
    checkEpubLoaded();
    webViewController?.callMethod('removeUnderLine', [cfi]);
  }

  ///Clears any active text selection in the epub viewer
  clearSelection() {
    checkEpubLoaded();
    webViewController?.callMethod('clearSelection');
  }

  ///Set [EpubSpread] value
  setSpread({required EpubSpread spread}) async {
    await webViewController?.callMethod('setSpread', [spread.name]);
  }

  ///Set [EpubFlow] value
  setFlow({required EpubFlow flow}) async {
    await webViewController?.callMethod('setFlow', [flow.name]);
  }

  ///Set [EpubManager] value
  setManager({required EpubManager manager}) async {
    await webViewController?.callMethod('setManager', [manager.name]);
  }

  ///Adjust font size in epub viewer
  setFontSize({required double fontSize}) async {
    await webViewController?.callMethod('setFontSize', [fontSize]);
  }

  updateTheme({required EpubTheme theme}) async {
    String? foregroundColor = theme.foregroundColor?.toHex();
    await webViewController?.callMethod('updateTheme', [
      '',
      foregroundColor,
      theme.customCss,
    ]);
  }

  ///Extract text from a given cfi range
  Future<EpubTextExtractRes> extractText({
    ///start cfi
    required startCfi,

    ///end cfi
    required endCfi,
  }) async {
    final result = await _request('getTextFromCfi', [startCfi, endCfi]);
    return EpubTextExtractRes.fromJson(Utils.asStringMap(result));
  }

  ///Get bounding rectangle for a given CFI range
  ///Returns viewer-relative coordinates in pixels, or null if it cannot be determined
  Future<Rect?> getRectFromCfi(String cfiRange) async {
    final result = await _request('getRectFromCfi', [cfiRange]);
    if (result == null) return null;
    final r = Utils.asStringMap(result);
    return Rect.fromLTRB(
      (r['left'] as num).toDouble(),
      (r['top'] as num).toDouble(),
      (r['right'] as num).toDouble(),
      (r['bottom'] as num).toDouble(),
    );
  }

  ///Extracts text content from current page
  Future<EpubTextExtractRes> extractCurrentPageText() async {
    final result = await _request('getCurrentPageText');
    return EpubTextExtractRes.fromJson(Utils.asStringMap(result));
  }

  ///Given a percentage moves to the corresponding page
  ///Progress percentage should be between 0.0 and 1.0
  toProgressPercentage(double progressPercent) {
    assert(
      progressPercent >= 0.0 && progressPercent <= 1.0,
      'Progress percentage must be between 0.0 and 1.0',
    );
    checkEpubLoaded();
    webViewController?.callMethod('toProgress', [progressPercent]);
  }

  ///Moves to the first page of the epub
  moveToFistPage() {
    toProgressPercentage(0.0);
  }

  ///Moves to the last page of the epub
  moveToLastPage() {
    toProgressPercentage(1.0);
  }

  checkEpubLoaded() {
    if (webViewController == null) {
      throw Exception(
        "Epub viewer is not loaded, wait for onEpubLoaded callback",
      );
    }
  }
}
