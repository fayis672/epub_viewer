import 'dart:async';

import 'package:flutter_epub_viewer/src/helper.dart';
import 'package:flutter_epub_viewer/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubController {
  InAppWebViewController? webViewController;

  ///List of chapters from epub
  List<EpubChapter> _chapters = [];

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
    webViewController?.evaluateJavascript(
        source: 'addHighlight("$cfi", "$colorHex", "$opacityString")');
  }

  ///Adds a underline annotation
  addUnderline({required String cfi}) {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'addUnderLine("$cfi")');
  }

  ///Adds a mark annotation
  // addMark({required String cfi}) {
  //   checkEpubLoaded();
  //   webViewController?.evaluateJavascript(source: 'addMark("$cfi")');
  // }

  ///Removes a highlight from epub viewer
  removeHighlight({required String cfi}) {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'removeHighlight("$cfi")');
  }

  ///Removes a underline from epub viewer
  removeUnderline({required String cfi}) {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'removeUnderLine("$cfi")');
  }

  ///Removes a mark from epub viewer
  // removeMark({required String cfi}) {
  //   checkEpubLoaded();
  //   webViewController?.evaluateJavascript(source: 'removeMark("$cfi")');
  // }

  ///Set [EpubSpread] value
  setSpread({required EpubSpread spread}) async {
    await webViewController?.evaluateJavascript(source: 'setSpread("$spread")');
  }

  ///Set [EpubFlow] value
  setFlow({required EpubFlow flow}) async {
    await webViewController?.evaluateJavascript(source: 'setFlow("$flow")');
  }

  ///Set [EpubManager] value
  setManager({required EpubManager manager}) async {
    await webViewController?.evaluateJavascript(
        source: 'setManager("$manager")');
  }

  ///Adjust font size in epub viewer
  setFontSize({required double fontSize}) async {
    await webViewController?.evaluateJavascript(
        source: 'setFontSize("$fontSize")');
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
