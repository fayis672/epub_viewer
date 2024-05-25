import 'package:epub_viewer/src/epub_controller.dart';
import 'package:epub_viewer/src/helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.epubController,
    required this.epubUrl,
    required this.headers,
    this.initialCfi,
    this.onChaptersLoaded,
  });

  ///Epub controller to mange epub
  final EpubController epubController;

  ///Epub url to load epub from network
  final String epubUrl;

  ///Epub headers to load epub from network
  final Map<String, String> headers;

  ///Initial cfi string to  specify which part of epub to load initially
  ///if null, the first chapter will be loaded
  final String? initialCfi;

  ///Call back when chapters are loaded
  final ValueChanged<List<EpubChapter>>? onChaptersLoaded;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  final GlobalKey webViewKey = GlobalKey();
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
        handlerName: "chapters",
        callback: (data) async {
          final chapters = await widget.epubController.getChapters();
          print("EPUB_TEST");
          widget.onChaptersLoaded?.call(chapters);
        });

    ///selection handler
    webViewController?.addJavaScriptHandler(
        handlerName: "selection",
        callback: (data) {
          var cfiString = data[0];
          var selectedText = data[1];
        });

    ///search callback
    webViewController?.addJavaScriptHandler(
        handlerName: "search",
        callback: (data) async {
          var searchResult = data[0];

          // decodeSearchJson(searchResult) {
          //   return List<BookSearchRes>.from(
          //       jsonDecode(searchResult).map((e) => BookSearchRes.fromJson(e)));
          // }

          // _bookSearchResults = await compute(decodeSearchJson, searchResult);
          // _isLoading = false;
          // update([bookSearchWidgetId]);
          // customLog(tag: "SEARCH_RESULT", searchResult);
        });

    ///current cfi callback
    webViewController?.addJavaScriptHandler(
        handlerName: "current_cfi",
        callback: (data) {
          var currentCfi = data[0];
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "displayed", callback: (data) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: widget.epubController.initServer(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading epub'));
          }

          return InAppWebView(
            // contextMenu: contextMenu,
            key: webViewKey,
            initialUrlRequest: URLRequest(
                url: WebUri(
                    'http://localhost:8080/html/swipe.html?epubUrl=${widget.epubUrl}&cfi=')),
            initialSettings: settings,
            // pullToRefreshController: pullToRefreshController,
            onWebViewCreated: (controller) {
              webViewController = controller;
              widget.epubController.setWebViewController(controller);
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
