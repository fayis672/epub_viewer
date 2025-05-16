import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/src/epub_controller.dart';
import 'package:flutter_epub_viewer/src/helper.dart';
import 'package:flutter_epub_viewer/src/utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

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
    this.onBookmarksUpdated,
    this.onHighlightsUpdated,
    this.onUnderlinesUpdated,
    this.onMetadataLoaded,
    this.onStorageCleared,
  });

  ///Epub controller to manage epub
  final EpubController epubController;

  ///Epub source, accepts url, file or assets
  ///opf format is not tested, use with caution
  final EpubSource epubSource;

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

  ///Callback for handling annotation click (Highlight and Underline)
  final ValueChanged<String>? onAnnotationClicked;

  ///Callback for when bookmarks are updated
  final ValueChanged<List<EpubBookmark>>? onBookmarksUpdated;

  ///Callback for when highlights are updated
  final ValueChanged<List<EpubHighlight>>? onHighlightsUpdated;

  ///Callback for when underlines are updated
  final ValueChanged<List<EpubUnderline>>? onUnderlinesUpdated;

  ///Callback for when metadata is loaded
  final ValueChanged<EpubMetadata>? onMetadataLoaded;

  ///Callback for when storage is cleared
  final ValueChanged<String>? onStorageCleared;

  ///context menu for text selection
  ///if null, the default context menu will be used
  final ContextMenu? selectionContextMenu;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> with WidgetsBindingObserver {
  final GlobalKey webViewKey = GlobalKey();

  // late PullToRefreshController pullToRefreshController;
  // late ContextMenu contextMenu;
  var selectedText = '';

  InAppWebViewController? webViewController;
  Timer? _scrollDebounce;

  InAppWebViewSettings settings = InAppWebViewSettings(
      useHybridComposition: true,
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      clearSessionCache: false,
      allowFileAccessFromFileURLs: true,
      allowUniversalAccessFromFileURLs: true,
      // Performance optimizations
      cacheEnabled: true,
      cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
      useWideViewPort: false,
      loadWithOverviewMode: true,
      javaScriptCanOpenWindowsAutomatically: false,
      mediaPlaybackRequiresUserGesture: true,
      // Optimize rendering
      useShouldInterceptAjaxRequest: true,
      useShouldInterceptFetchRequest: true,
      // Improve scrolling performance
      overScrollMode: OverScrollMode.NEVER,
      verticalScrollbarThumbColor: const Color(0x00000000),
      horizontalScrollbarThumbColor: const Color(0x00000000),
      isInspectable: kDebugMode,
      transparentBackground: true,
      supportZoom: false,
      allowsInlineMediaPlayback: true,
      disableLongPressContextMenuOnLinks: false,
      iframeAllowFullscreen: true,
      allowsLinkPreview: false,
      verticalScrollBarEnabled: false,
      // disableVerticalScroll: true,
      selectionGranularity: SelectionGranularity.CHARACTER);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // App going to background
      webViewController?.evaluateJavascript(source: 'saveReadingState()');
      webViewController?.pause(); // Pause WebView to save resources
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground
      webViewController?.resume();
    }
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

    webViewController?.addJavaScriptHandler(
        handlerName: "markClicked",
        callback: (data) {
          String cfi = data[0];
          widget.onAnnotationClicked?.call(cfi);
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "epubText",
        callback: (data) {
          var text = data[0].trim();
          var cfi = data[1];
          widget.epubController.pageTextCompleter
              .complete(EpubTextExtractRes(text: text, cfiRange: cfi));
        });

    webViewController?.addJavaScriptHandler(
        handlerName: "locationChanged",
        callback: (args) {
          if (_scrollDebounce?.isActive ?? false) _scrollDebounce!.cancel();
          _scrollDebounce = Timer(const Duration(milliseconds: 200), () {
            // Prefetch next content for smoother reading
            Future.delayed(const Duration(milliseconds: 300), () {
              webViewController?.evaluateJavascript(
                  source: 'prefetchContent()');
            });
          });
        });

    // Add handler for bookmarks updates
    webViewController?.addJavaScriptHandler(
        handlerName: "bookmarksUpdated",
        callback: (data) {
          final bookmarks = List<EpubBookmark>.from(
              (data[0] as List).map((e) => EpubBookmark.fromJson(e)));
          widget.epubController.getBookmarks();
          widget.onBookmarksUpdated?.call(bookmarks);
          if (!widget.epubController.bookmarksCompleter.isCompleted) {
            widget.epubController.bookmarksCompleter.complete(bookmarks);
          }
        });

    // Add handler for highlights updates
    webViewController?.addJavaScriptHandler(
        handlerName: "highlightsUpdated",
        callback: (data) {
          final highlights = List<EpubHighlight>.from(
              (data[0] as List).map((e) => EpubHighlight.fromJson(e)));
          widget.epubController.getHighlights();
          widget.onHighlightsUpdated?.call(highlights);
          if (widget.epubController.highlightsCompleter != null &&
              !widget.epubController.highlightsCompleter!.isCompleted) {
            widget.epubController.highlightsCompleter!.complete(highlights);
          }
        });

    // Add handler for underlines updates
    webViewController?.addJavaScriptHandler(
        handlerName: "underlinesUpdated",
        callback: (data) {
          final underlines = List<EpubUnderline>.from(
              (data[0] as List).map((e) => EpubUnderline.fromJson(e)));
          widget.epubController.getUnderlines();
          widget.onUnderlinesUpdated?.call(underlines);
          if (widget.epubController.underlinesCompleter != null &&
              !widget.epubController.underlinesCompleter!.isCompleted) {
            widget.epubController.underlinesCompleter!.complete(underlines);
          }
        });

    // Add handler for storage cleared event
    webViewController?.addJavaScriptHandler(
        handlerName: "storageCleared",
        callback: (data) {
          final type = data[0] as String;
          // Notify the controller that storage has been cleared
          if (widget.epubController.storageCleared != null &&
              !widget.epubController.storageCleared!.isCompleted) {
            widget.epubController.storageCleared!.complete(type);
          }
          // Notify any listeners that storage has been cleared
          widget.onStorageCleared?.call(type);
        });
  }

  loadBook() async {
    var data = await widget.epubSource.epubData;
    final displaySettings =
        widget.displaySettings ?? const EpubDisplaySettings();
    String manager = displaySettings.manager.name;
    String flow = displaySettings.flow.name;
    String spread = displaySettings.spread.name;
    bool snap = displaySettings.snap;
    bool allowScripted = displaySettings.allowScriptedContent;
    String cfi = widget.initialCfi ?? "";
    String direction = widget.displaySettings?.defaultDirection.name ??
        EpubDefaultDirection.ltr.name;

    bool useCustomSwipe =
        Platform.isAndroid && !displaySettings.useSnapAnimationAndroid;

    String? backgroundColor =
        widget.displaySettings?.theme?.backgroundColor?.toHex();
    String? foregroundColor =
        widget.displaySettings?.theme?.foregroundColor?.toHex();

    webViewController?.evaluateJavascript(
        source:
            'loadBook([${data.join(",")}], "$cfi", "$manager", "$flow", "$spread", $snap, $allowScripted, "$direction", $useCustomSwipe, "$backgroundColor", "$foregroundColor")');

    // After loading, try to load saved state
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.epubController.loadReadingState();

      // Load metadata if callback is provided
      if (widget.onMetadataLoaded != null) {
        widget.epubController.getMetadata().then((metadata) {
          widget.onMetadataLoaded?.call(metadata);
        }).catchError((e) {
          debugPrint("Error loading metadata: $e");
        });
      }

      // Load bookmarks if callback is provided
      if (widget.onBookmarksUpdated != null) {
        widget.epubController.getBookmarks().then((bookmarks) {
          widget.onBookmarksUpdated?.call(bookmarks);
        }).catchError((e) {
          debugPrint("Error loading bookmarks: $e");
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      contextMenu: widget.selectionContextMenu,
      key: webViewKey,
      initialFile:
          'packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html',
      initialSettings: settings
        ..disableVerticalScroll = widget.displaySettings?.snap ?? false
        ..disableHorizontalScroll =
            widget.displaySettings?.flow == EpubFlow.scrolled,
      onWebViewCreated: (controller) async {
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

        if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
            .contains(uri.scheme)) {
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
      onUpdateVisitedHistory: (controller, url, androidIsReload) {},
      onConsoleMessage: (controller, consoleMessage) {
        if (kDebugMode) {
          debugPrint("EpubViewer: ${consoleMessage.message}");
        }
      },
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer()
            ..onStart = (details) {
              debugPrint("onStart: $details");
            }
            ..onUpdate = (details) {
              debugPrint("onUpdate: $details");
            }
            ..onEnd = (details) {
              debugPrint("onEnd: $details");
            },
        ),
      },
    );
  }

  @override
  void dispose() {
    if (_scrollDebounce?.isActive ?? false) {
      _scrollDebounce!.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
