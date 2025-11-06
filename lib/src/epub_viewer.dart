import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../flutter_epub_viewer.dart';
import 'utils.dart';

/// Callback for text selection events with WebView-relative coordinates.
///
/// Provides precise positioning information for implementing custom selection UI.
/// All rectangles are relative to the WebView's coordinate system (not screen coordinates).
///
/// Parameters:
/// * [selectedText] - The text that was selected
/// * [cfiRange] - The EPUB CFI (Canonical Fragment Identifier) range for the selection
/// * [selectionRect] - The bounding rectangle of the selected text (WebView-relative)
/// * [viewRect] - The bounding rectangle of the entire WebView
typedef EpubSelectionCallback = void Function(
  String selectedText,
  String cfiRange,
  Rect selectionRect,
  Rect viewRect,
);

class EpubViewer extends StatefulWidget {
  const EpubViewer({
    super.key,
    required this.epubController,
    required this.epubSource,
    this.initialCfi,
    this.onChaptersLoaded,
    this.onEpubLoaded,
    this.onLocationLoaded,
    this.onRelocated,
    this.onTextSelected,
    this.displaySettings,
    this.selectionContextMenu,
    this.onAnnotationClicked,
    this.onSelection,
    this.onSelectionChanging,
    this.onDeselection,
    this.suppressNativeContextMenu = false,
    this.clearSelectionOnPageChange = true,
  });

  //Epub controller to manage epub
  final EpubController epubController;

  ///Epub source, accepts url, file or assets
  ///opf format is not tested, use with caution
  final EpubSource epubSource;

  ///Initial cfi string to  specify which part of epub to load initially
  ///if null, the first chapter will be loaded
  final String? initialCfi;

  ///Call back when epub is loaded and displayed
  final VoidCallback? onEpubLoaded;

  /// Callback when the location are generated for epub, progress will be only available after this
  final VoidCallback? onLocationLoaded;

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

  /// Context menu for text selection.
  /// If null, the default context menu will be used.
  final ContextMenu? selectionContextMenu;

  /// Whether to suppress the native context menu entirely.
  /// When true, no native context menu will be shown on text selection.
  /// Use with [onSelection] to implement custom selection UI.
  final bool suppressNativeContextMenu;

  /// Callback when text is selected with WebView-relative coordinates.
  /// 
  /// Fires when:
  /// * User completes initial text selection
  /// * User finishes dragging selection handles (after a 300ms debounce)
  /// 
  /// Use this callback to display custom UI at the selection position.
  /// Coordinates are relative to the WebView, not the screen.
  /// 
  /// See also:
  /// * [onSelectionChanging] - Called while user is actively dragging handles
  /// * [onDeselection] - Called when selection is cleared
  final EpubSelectionCallback? onSelection;

  /// Callback fired continuously while the user is dragging selection handles.
  /// 
  /// This callback helps prevent UI flicker and performance issues by allowing you to
  /// hide custom selection UI while the user is actively adjusting the selection.
  /// Once dragging stops, [onSelection] will be called with the final selection.
  /// 
  /// Typical usage:
  /// ```dart
  /// onSelectionChanging: () {
  ///   // Hide custom selection UI while user drags handles
  ///   setState(() => showSelectionMenu = false);
  /// }
  /// ```
  /// 
  /// See also:
  /// * [onSelection] - Called when selection is finalized
  final VoidCallback? onSelectionChanging;

  /// Callback when text selection is cleared.
  /// 
  /// Fired when the user taps elsewhere or explicitly clears the selection.
  /// Use this to hide any custom selection UI.
  final VoidCallback? onDeselection;

  /// Whether to automatically clear text selection when navigating to a new page.
  /// 
  /// When true (default), text selection will be cleared when the user navigates
  /// to a different page using next(), previous(), or toCfi(). This is the standard
  /// behavior in most e-reader applications.
  /// 
  /// Set to false if you want to preserve selection across page changes, though
  /// note that the selection may not be visible on the new page.
  final bool clearSelectionOnPageChange;

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

  void _handleSelection({
    required Map<String, dynamic>? rect,
    required String selectedText,
    required String cfi,
  }) {
    if (!mounted) return;
    
    try {
      final renderBox = context.findRenderObject() as RenderBox;
      final webViewSize = renderBox.size;
      
      if (rect == null) {
        // Still call onTextSelected for basic selection functionality
        widget.onTextSelected?.call(
          EpubTextSelection(
            selectedText: selectedText,
            selectionCfi: cfi,
          ),
        );
        return;
      }
      
      // Convert relative coordinates (0-1) to actual WebView coordinates
      final left = (rect['left'] as num).toDouble();
      final top = (rect['top'] as num).toDouble();
      final width = (rect['width'] as num).toDouble();
      final height = (rect['height'] as num).toDouble();
      
      final scaledRect = Rect.fromLTWH(
        left * webViewSize.width,
        top * webViewSize.height,
        width * webViewSize.width,
        height * webViewSize.height,
      );
      
      // Create viewRect in WebView-relative coordinates
      final viewRect = Rect.fromLTWH(
        0,
        0,
        webViewSize.width,
        webViewSize.height
      );

      // Provide WebView-relative coordinates (not screen coordinates)
      widget.onSelection?.call(
        selectedText,
        cfi,
        scaledRect,  // WebView-relative coordinates
        viewRect,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error in _handleSelection: $e");
      }
    }
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
        final cfiString = data[0] as String;
        final selectedText = data[1] as String;
        Map<String, dynamic>? rect;
        
        try {
          if (data.length > 2 && data[2] != null) {
            rect = Map<String, dynamic>.from(data[2] as Map);
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing selection rect: $e');
          }
          rect = null;
        }

        // Always call basic text selection callback
        widget.onTextSelected?.call(
          EpubTextSelection(
            selectedText: selectedText,
            selectionCfi: cfiString,
          ),
        );

        // If we have coordinates and a selection callback, provide full selection info
        if (rect != null && widget.onSelection != null) {
          _handleSelection(rect: rect, selectedText: selectedText, cfi: cfiString);
        }
      },
    );

    // Add deselection handler
    webViewController?.addJavaScriptHandler(
      handlerName: 'selectionCleared',
      callback: (args) {
        widget.onDeselection?.call();
      },
    );

    // Add selection changing handler (dragging handles)
    webViewController?.addJavaScriptHandler(
      handlerName: 'selectionChanging',
      callback: (args) {
        widget.onSelectionChanging?.call();
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
      handlerName: 'locationLoaded',
      callback: (arguments) {
        widget.onLocationLoaded?.call();
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
        widget.displaySettings?.defaultDirection.name ??
        EpubDefaultDirection.ltr.name;
    int fontSize = displaySettings.fontSize;

    bool useCustomSwipe =
        Platform.isAndroid && !displaySettings.useSnapAnimationAndroid;

    String? foregroundColor = widget.displaySettings?.theme?.foregroundColor
        ?.toHex();
    
    bool clearSelectionOnPageChange = widget.clearSelectionOnPageChange;

    webViewController?.evaluateJavascript(
      source:
          'loadBook([${data.join(',')}], "$cfi", "$manager", "$flow", "$spread", $snap, $allowScripted, "$direction", $useCustomSwipe, "${null}", "$foregroundColor", "$fontSize", $clearSelectionOnPageChange)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: widget.displaySettings?.theme?.backgroundDecoration,
      child: InAppWebView(
        contextMenu: widget.suppressNativeContextMenu 
            ? ContextMenu(
                menuItems: [],
                settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
              )
            : widget.selectionContextMenu,
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
