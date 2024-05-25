import 'dart:convert';

import 'package:epub_viewer/src/helper.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubController {
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
      documentRoot: 'packages/epub_viewer/lib/assets/webpage');

  InAppWebViewController? webViewController;

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

  Future<List<EpubChapter>> getChapters() async {
    if (webViewController == null) {
      throw Exception("Epub viewer is not loaded");
    } else {
      final result =
          await webViewController!.evaluateJavascript(source: 'getChapters()');

      print('EPUB_TEST : $result');
      return List<EpubChapter>.from(
          result.map((e) => EpubChapter.fromJson(e)));
    }
  }

  ///===================WEBVIEW CONTROLS=================

  ///javascript handles for webview
}
