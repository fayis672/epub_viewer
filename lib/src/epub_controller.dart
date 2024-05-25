import 'dart:convert';

import 'package:epub_viewer/src/helper.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubController {
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
      documentRoot: 'packages/epub_viewer/lib/assets/webpage');

  InAppWebViewController? webViewController;

  ///List of chapters from epub
  List<EpubChapter> chapters = [];

  Future<void> initServer() async {
    if (_localhostServer.isRunning()) return;
    await _localhostServer.start();
  }

  Future<void> disposeServer() async {
    if (!_localhostServer.isRunning()) return;
    await _localhostServer.close();
  }

  setWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  ///Returns list of chapters from epub,
  /// should be called after onChaptersLoaded callback, otherwise returns empty list
  getChapters() {
    return chapters;
  }

  ///Parsing chapters list form epub
  Future<List<EpubChapter>> parseChapters() async {
    if (webViewController == null) {
      throw Exception("Epub viewer is not loaded");
    } else {
      final result =
          await webViewController!.evaluateJavascript(source: 'getChapters()');

      chapters =
          List<EpubChapter>.from(result.map((e) => EpubChapter.fromJson(e)));
      return chapters;
    }
  }

  ///===================WEBVIEW CONTROLS=================

  ///javascript handles for webview
}
