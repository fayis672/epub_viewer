import 'dart:convert';

import 'package:epub_viewer/src/helper.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubController {
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
      documentRoot: 'packages/epub_viewer/lib/assets/webpage');

  InAppWebViewController? webViewController;

  Future<void> initServer() async {
    await _localhostServer.start();
  }

  Future<void> disposeServer() async {
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
      return List<EpubChapter>.from(
          jsonDecode(result[0]).map((e) => EpubChapter.fromJson(e)));
    }
  }

  ///===================WEBVIEW CONTROLS=================

  ///javascript handles for webview
}
