import 'dart:convert';

import 'package:flutter_epub_viewer/src/epub_controller.dart';
import 'package:flutter_epub_viewer/src/helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.epubController,
    required this.epubSource,
    // required this.epubUrl,
    this.headers,
    this.initialCfi,
    this.onChaptersLoaded,
    this.onEpubLoaded,
    this.onRelocated,
    this.onTextSelected,
    this.displaySettings,
    this.selectionContextMenu,
  });

  ///Epub controller to manage epub
  final EpubController epubController;

  ///Epub url to load epub from network
  // final String epubUrl;
  final EpubSource epubSource;

  ///Epub headers to load epub from network
  final Map<String, String>? headers;

  ///Initial cfi string to  specify which part of epub to load initially
  ///if null, the first chapter will be loaded
  final String? initialCfi;

  ///Call back when epub is loaded and displayed
  final VoidCallback? onEpubLoaded;

  ///Call back when chapters are loaded
  final ValueChanged<List<EpubChapter>>? onChaptersLoaded;

  ///Call back when epub page changes
  final ValueChanged<EpubLocation>? onRelocated;

  ///Call back when text selection changes
  final ValueChanged<EpubTextSelection>? onTextSelected;

  ///initial display settings
  final EpubDisplaySettings? displaySettings;

  ///context menu for text selection
  ///if null, the default context menu will be used
  final ContextMenu? selectionContextMenu;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  final GlobalKey webViewKey = GlobalKey();

  final LocalServerController localServerController = LocalServerController();

  // late PullToRefreshController pullToRefreshController;
  // late ContextMenu contextMenu;
  var selectedText = '';

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      transparentBackground: true,
      supportZoom: false,
      allowsInlineMediaPlayback: true,
      disableLongPressContextMenuOnLinks: false,
      iframeAllowFullscreen: true,
      allowsLinkPreview: false,
      verticalScrollBarEnabled: false,
      selectionGranularity: SelectionGranularity.CHARACTER);

  @override
  void initState() {
    // widget.epubController.initServer();
    super.initState();
  }

  addJavaScriptHandlers() {
    webViewController?.addJavaScriptHandler(
        handlerName: "displayed",
        callback: (data) {
          widget.onEpubLoaded?.call();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "rendered",
        callback: (data) {
          // widget.onEpubLoaded?.call();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "chapters",
        callback: (data) async {
          final chapters = await widget.epubController.parseChapters();
          widget.onChaptersLoaded?.call(chapters);
        });

    ///selection handler
    webViewController?.addJavaScriptHandler(
        handlerName: "selection",
        callback: (data) {
          var cfiString = data[0];
          var selectedText = data[1];
          widget.onTextSelected?.call(EpubTextSelection(
              selectedText: selectedText, selectionCfi: cfiString));
        });

    ///search callback
    webViewController?.addJavaScriptHandler(
        handlerName: "search",
        callback: (data) async {
          var searchResult = data[0];
          widget.epubController.searchResultCompleter.complete(
              List<EpubSearchResult>.from(
                  searchResult.map((e) => EpubSearchResult.fromJson(e))));
        });

    ///current cfi callback
    webViewController?.addJavaScriptHandler(
        handlerName: "relocated",
        callback: (data) {
          var location = data[0];
          widget.onRelocated?.call(EpubLocation.fromJson(location));
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "readyToLoad",
        callback: (data) {
          loadBook();
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "displayError",
        callback: (data) {
          // loadBook();
        });
  }

  loadBook() async {
    var data = await widget.epubSource.epubData;
    // await Future.delayed(const Duration(seconds: 5));
    webViewController?.evaluateJavascript(
        source: 'loadBook([${data.join(',')}])');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: localServerController.initServer(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container();
          }

          final displaySettings = jsonEncode(widget.displaySettings?.toJson() ??
              EpubDisplaySettings().toJson());

          final headers = jsonEncode(widget.headers);

          return InAppWebView(
            contextMenu: widget.selectionContextMenu,
            key: webViewKey,
            initialUrlRequest: URLRequest(
                url: WebUri(
                    'http://localhost:8080/html/swipe.html?cfi=${widget.initialCfi ?? ''}&displaySettings=$displaySettings&headers=$headers')),
            initialSettings: settings,
            // pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (controller) async {
              webViewController = controller;
              widget.epubController.setWebViewController(controller);
              // await loadBook();
              addJavaScriptHandlers();
            },
            onLoadStart: (controller, url) {},
            onPermissionRequest: (controller, request) async {
              return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT);
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              var uri = navigationAction.request.url!;

              if (![
                "http",
                "https",
                "file",
                "chrome",
                "data",
                "javascript",
                "about"
              ].contains(uri.scheme)) {
                // if (await canLaunchUrl(uri)) {
                //   // Launch the App
                //   await launchUrl(
                //     uri,
                //   );
                //   // and cancel the request
                //   return NavigationActionPolicy.CANCEL;
                // }
              }

              return NavigationActionPolicy.ALLOW;
            },
            onLoadStop: (controller, url) async {},
            onReceivedError: (controller, request, error) {},
            
            onProgressChanged: (controller, progress) {},
            onUpdateVisitedHistory: (controller, url, androidIsReload) {},
            onConsoleMessage: (controller, consoleMessage) {
              if (kDebugMode) {
                debugPrint("JS_LOG: ${consoleMessage.message}");
                // debugPrint(consoleMessage.message);
              }
            },
            gestureRecognizers: {
              Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer()),
              Factory<LongPressGestureRecognizer>(() =>
                  LongPressGestureRecognizer(
                      duration: const Duration(milliseconds: 30))),
            },
          );
        });
  }
}
