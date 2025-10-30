import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../flutter_epub_viewer.dart';
import 'utils.dart';

class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.epubController,
    required this.epubSource,
    this.initialCfi,
    this.onChaptersLoaded,
    this.onEpubLoaded,
    this.onRelocated,
    this.onTextSelected,
    this.displaySettings,
    this.selectionContextMenu,
    this.onAnnotationClicked,
  });

  final EpubController epubController;
  final EpubSource epubSource;
  final String? initialCfi;
  final VoidCallback? onEpubLoaded;
  final ValueChanged<List<EpubChapter>>? onChaptersLoaded;
  final ValueChanged<EpubLocation>? onRelocated;
  final ValueChanged<EpubTextSelection>? onTextSelected;
  final EpubDisplaySettings? displaySettings;
  final ValueChanged<String>? onAnnotationClicked;
  final ContextMenu? selectionContextMenu;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  final GlobalKey webViewKey = GlobalKey();

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
    selectionGranularity: SelectionGranularity.CHARACTER,
  );

  @override
  void initState() {
    super.initState();
  }

  void addJavaScriptHandlers() {
    webViewController?.addJavaScriptHandler(
      handlerName: "displayed",
      callback: (data) {
        widget.onEpubLoaded?.call();
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "chapters",
      callback: (data) async {
        final chapters = await widget.epubController.parseChapters();
        widget.onChaptersLoaded?.call(chapters);
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "selection",
      callback: (data) {
        var cfiString = data[0];
        var selectedText = data[1];
        widget.onTextSelected?.call(
          EpubTextSelection(selectedText: selectedText, selectionCfi: cfiString),
        );
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "search",
      callback: (data) async {
        var searchResult = data[0];
        widget.epubController.searchResultCompleter.complete(
          List<EpubSearchResult>.from(
            searchResult.map((e) => EpubSearchResult.fromJson(e)),
          ),
        );
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "relocated",
      callback: (data) {
        var location = data[0];
        widget.onRelocated?.call(EpubLocation.fromJson(location));
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "readyToLoad",
      callback: (data) {
        loadBook();
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "markClicked",
      callback: (data) {
        String cfi = data[0];
        widget.onAnnotationClicked?.call(cfi);
      },
    );

    webViewController?.addJavaScriptHandler(
      handlerName: "epubText",
      callback: (data) {
        var text = data[0].trim();
        var cfi = data[1];
        widget.epubController.pageTextCompleter.complete(
          EpubTextExtractRes(text: text, cfiRange: cfi),
        );
      },
    );
  }

  Future<void> loadBook() async {
    var data = await widget.epubSource.epubData;
    final displaySettings = widget.displaySettings ?? EpubDisplaySettings();
    String manager = displaySettings.manager.name;
    String flow = displaySettings.flow.name;
    String spread = displaySettings.spread.name;
    bool snap = displaySettings.snap;
    bool allowScripted = displaySettings.allowScriptedContent;
    String cfi = widget.initialCfi ?? "";
    String direction =
        widget.displaySettings?.defaultDirection.name ?? EpubDefaultDirection.ltr.name;
    int fontSize = displaySettings.fontSize;

    bool useCustomSwipe =
        Platform.isAndroid && !displaySettings.useSnapAnimationAndroid;

    String? foregroundColor = widget.displaySettings?.theme?.foregroundColor?.toHex();

    webViewController?.evaluateJavascript(
      source:
          'loadBook([${data.join(',')}], "$cfi", "$manager", "$flow", "$spread", $snap, $allowScripted, "$direction", $useCustomSwipe, "${null}", "$foregroundColor", "$fontSize")',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.displaySettings?.theme?.backgroundDecoration,
      child: InAppWebView(
        contextMenu: widget.selectionContextMenu,
        key: webViewKey,
        initialFile:
            'packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html',
        initialSettings: settings
          ..disableVerticalScroll = widget.displaySettings?.snap ?? false,
        onWebViewCreated: (controller) async {
          webViewController = controller;
          widget.epubController.setWebViewController(controller);
          addJavaScriptHandlers();
        },
        onLoadStart: (controller, url) {},
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          return NavigationActionPolicy.ALLOW;
        },
        onLoadStop: (controller, url) async {},
        onReceivedError: (controller, request, error) {},
        onProgressChanged: (controller, progress) {},
        onUpdateVisitedHistory: (controller, url, androidIsReload) {},
        onConsoleMessage: (controller, consoleMessage) {
          if (kDebugMode) {
            debugPrint("JS_LOG: ${consoleMessage.message}");
          }
        },
        gestureRecognizers: {
          Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(),
          ),
          Factory<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 30),
            ),
          ),
        },
      ),
    );
  }

  @override
  void dispose() {
    webViewController?.dispose();
    super.dispose();
  }
}