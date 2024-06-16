import 'dart:async';

import 'package:flutter_epub_viewer/src/helper.dart';
import 'package:flutter_epub_viewer/src/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubController {
  InAppWebViewController? webViewController;

  ///List of chapters from epub
  List<EpubChapter> chapters = [];

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
    return chapters;
  }

  ///Parsing chapters list form epub
  Future<List<EpubChapter>> parseChapters() async {
    if (chapters.isNotEmpty) return chapters;
    checkEpubLoaded();
    final result =
        await webViewController!.evaluateJavascript(source: 'getChapters()');
    chapters =
        List<EpubChapter>.from(result.map((e) => EpubChapter.fromJson(e)));
    return chapters;
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

  ///Removes a highlight from epub viewer
  removeHighlight({required String cfi}) {
    checkEpubLoaded();
    webViewController?.evaluateJavascript(source: 'removeHighlight("$cfi")');
  }

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
