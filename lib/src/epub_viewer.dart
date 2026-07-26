import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../flutter_epub_viewer.dart';
import 'platform/epub_web_view.dart';
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
typedef EpubSelectionCallback =
    void Function(
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
    this.initialXPath,
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
    this.onInitialPositionLoading,
    this.onInitialPositionLoaded,
    this.onTouchDown,
    this.onTouchUp,
    this.suppressNativeContextMenu = false,
    this.clearSelectionOnPageChange = true,
    this.selectAnnotationRange = false,
  });

  //Epub controller to manage epub
  final EpubController epubController;

  ///Epub source, accepts url, file or assets
  ///opf format is not tested, use with caution
  final EpubSource epubSource;

  ///Initial cfi string to  specify which part of epub to load initially
  ///if null, the first chapter will be loaded
  final String? initialCfi;

  ///Initial xpath/XPointer string to specify which part of epub to load initially
  ///if null and initialCfi is also null, the first chapter will be loaded
  final String? initialXPath;

  ///Call back when epub is loaded and displayed
  final VoidCallback? onEpubLoaded;

  /// Callback when the location are generated for epub, progress will be only available after this
  final VoidCallback? onLocationLoaded;

  ///Call back when chapters are loaded
  final ValueChanged<List<EpubChapter>>? onChaptersLoaded;

  ///Call back when epub page changes
  final ValueChanged<EpubLocation>? onRelocated;

  ///Callback when initial position loading starts (for showing progress indicator)
  ///Receives the type: 'xpath' or 'cfi'
  final ValueChanged<String>? onInitialPositionLoading;

  ///Callback when initial position loading completes
  final VoidCallback? onInitialPositionLoaded;

  ///Call back when text selection changes
  final ValueChanged<EpubTextSelection>? onTextSelected;

  ///initial display settings
  final EpubDisplaySettings? displaySettings;

  ///Callback for handling annotation click (Highlight and Underline)
  ///Provides the CFI range and the selection rect (same format as onSelection)
  final void Function(String cfiRange, Map<String, dynamic>? rect)?
  onAnnotationClicked;

  /// Context menu for text selection.
  /// If null, the default context menu will be used.
  /// Applies to mobile/desktop only; ignored on the web.
  final EpubContextMenu? selectionContextMenu;

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

  /// Whether to programmatically select annotation ranges when clicked.
  ///
  /// When true, clicking on an annotation (highlight/underline) will automatically
  /// select the text range, triggering the selection event with the correct rect.
  /// This is useful for displaying custom selection UI for annotations.
  ///
  /// When false (default), annotation clicks will only trigger [onAnnotationClicked]
  /// without programmatically selecting the text.
  final bool selectAnnotationRange;

  /// Callback fired when the user touches down on the EPUB viewer.
  ///
  /// Provides normalized coordinates (0.0-1.0) relative to the WebView dimensions.
  /// Coordinates use the same calculation logic as selection coordinates.
  ///
  /// Fires regardless of whether there's an active text selection, allowing you to:
  /// * Determine which zone of the EPUB viewer was tapped
  /// * Compare tap location with selection location to trigger selection-specific pop-ups
  /// * Control navigation and menus based on tap position
  ///
  /// Parameters:
  /// * [x] - Normalized X coordinate (0.0 = left edge, 1.0 = right edge)
  /// * [y] - Normalized Y coordinate (0.0 = top edge, 1.0 = bottom edge)
  final void Function(double x, double y)? onTouchDown;

  /// Callback fired when the user releases a touch on the EPUB viewer.
  ///
  /// Provides normalized coordinates (0.0-1.0) relative to the WebView dimensions.
  /// Coordinates use the same calculation logic as selection coordinates.
  ///
  /// Fires regardless of whether there's an active text selection, allowing you to:
  /// * Determine which zone of the EPUB viewer was tapped
  /// * Compare tap location with selection location to trigger selection-specific pop-ups
  /// * Control navigation and menus based on tap position
  ///
  /// Parameters:
  /// * [x] - Normalized X coordinate (0.0 = left edge, 1.0 = right edge)
  /// * [y] - Normalized Y coordinate (0.0 = top edge, 1.0 = bottom edge)
  final void Function(double x, double y)? onTouchUp;

  @override
  State<EpubViewer> createState() => _EpubViewerState();
}

class _EpubViewerState extends State<EpubViewer> {
  Timer?
  _selectionCheckTimer; // Timer to periodically verify selection still exists

  EpubWebViewController? webViewController;

  /// Block or unblock gestures using CSS touch-action when selection is active
  void _blockGesturesWhenSelected(bool block) {
    if (!mounted || webViewController == null) return;

    // Use CSS touch-action to block horizontal panning/swiping when selection exists
    // This works at the browser level, before JavaScript event handlers
    webViewController?.callMethod('blockGesturesWhenSelected', [block]);
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
          EpubTextSelection(selectedText: selectedText, selectionCfi: cfi),
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
        webViewSize.height,
      );

      // Provide WebView-relative coordinates (not screen coordinates)
      widget.onSelection?.call(
        selectedText,
        cfi,
        scaledRect, // WebView-relative coordinates
        viewRect,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error in _handleSelection: $e");
      }
    }
  }

  void addJavaScriptHandlers() {
    final controller = webViewController;
    if (controller == null) return;

    controller.addHandler("displayed", (data) {
      if (kDebugMode) {
        debugPrint("[EpubViewer] 6. 'displayed' JS handler received");
      }
      widget.onEpubLoaded?.call();
    });

    controller.addHandler("chapters", (data) async {
      if (kDebugMode) {
        debugPrint("[EpubViewer] 7. 'chapters' JS handler received, parsing chapters...");
      }
      final chapters = await widget.epubController.parseChapters();
      if (kDebugMode) {
        debugPrint("[EpubViewer] 8. Chapters parsed (${chapters.length} chapters found)");
      }
      widget.onChaptersLoaded?.call(chapters);
    });

    controller.addHandler("selection", (data) {
      final cfiString = data[0] as String;
      final selectedText = data[1] as String;
      Map<String, dynamic>? rect;
      String? selectionXpath;

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

      try {
        if (data.length > 3 && data[3] != null) {
          selectionXpath = data[3] as String?;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error parsing selection xpath: $e');
        }
        selectionXpath = null;
      }

      // Block gestures when selection is active
      _blockGesturesWhenSelected(true);
      _startSelectionMonitoring();

      // Always call basic text selection callback
      widget.onTextSelected?.call(
        EpubTextSelection(
          selectedText: selectedText,
          selectionCfi: cfiString,
          selectionXpath: selectionXpath,
        ),
      );

      // If we have coordinates and a selection callback, provide full selection info
      if (rect != null && widget.onSelection != null) {
        _handleSelection(rect: rect, selectedText: selectedText, cfi: cfiString);
      }
    });

    // Add deselection handler
    controller.addHandler('selectionCleared', (args) {
      _stopSelectionMonitoring();
      _blockGesturesWhenSelected(false);
      widget.onDeselection?.call();
    });

    // Add selection changing handler (dragging handles)
    controller.addHandler('selectionChanging', (args) {
      widget.onSelectionChanging?.call();
    });

    // Add touch down handler
    controller.addHandler('onTouchDown', (data) {
      try {
        if (data.length >= 2) {
          final x = (data[0] as num).toDouble();
          final y = (data[1] as num).toDouble();
          widget.onTouchDown?.call(x, y);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error parsing onTouchDown coordinates: $e');
        }
      }
    });

    // Add touch up handler
    controller.addHandler('onTouchUp', (data) {
      try {
        if (data.length >= 2) {
          final x = (data[0] as num).toDouble();
          final y = (data[1] as num).toDouble();
          widget.onTouchUp?.call(x, y);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error parsing onTouchUp coordinates: $e');
        }
      }
    });

    controller.addHandler("relocated", (data) {
      var location = data[0];
      widget.onRelocated
          ?.call(EpubLocation.fromJson(Utils.asStringMap(location)));
    });

    controller.addHandler('locationLoaded', (arguments) {
      widget.onLocationLoaded?.call();
    });

    controller.addHandler('initialPositionLoading', (data) {
      String type = 'cfi';
      if (data.isNotEmpty) {
        try {
          if (data[0] is Map) {
            type = (data[0] as Map)['type'] ?? 'cfi';
          } else if (data[0] is String) {
            type = data[0] as String;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error parsing initialPositionLoading type: $e');
          }
        }
      }
      widget.onInitialPositionLoading?.call(type);
    });

    controller.addHandler('initialPositionLoaded', (arguments) {
      widget.onInitialPositionLoaded?.call();
    });

    controller.addHandler("readyToLoad", (data) {
      if (kDebugMode) {
        debugPrint("[EpubViewer] 4. 'readyToLoad' JS handler received in Dart");
      }
      loadBook();
    });

    controller.addHandler("markClicked", (data) {
      String cfi = data[0];
      Map<String, dynamic>? rect;
      try {
        if (data.length > 1 && data[1] != null) {
          rect = Map<String, dynamic>.from(data[1] as Map);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error parsing annotation rect: $e');
        }
        rect = null;
      }
      widget.onAnnotationClicked?.call(cfi, rect);
    });

    // Note: request/response calls (getCurrentLocation, search, extractText,
    // getRectFromCfi, ...) now return their values directly via
    // [EpubWebViewController.callAsync] and no longer need handler channels.
  }

  Future<void> loadBook() async {
    if (kDebugMode) {
      debugPrint("[EpubViewer] 5. loadBook() called");
    }
    final controller = webViewController;
    if (controller == null) {
      if (kDebugMode) {
        debugPrint("[EpubViewer] ERROR: loadBook() webViewController is null!");
      }
      return;
    }

    final data = await widget.epubSource.epubData;
    final displaySettings = widget.displaySettings ?? EpubDisplaySettings();
    final String manager = displaySettings.manager.name;
    final String flow = displaySettings.flow.name;
    final String spread = displaySettings.spread.name;
    final bool snap = displaySettings.snap;
    final bool allowScripted = displaySettings.allowScriptedContent;
    final String cfi = widget.initialCfi ?? "";
    final String? initialXPath = widget.initialXPath;
    final String direction =
        widget.displaySettings?.defaultDirection.name ??
        EpubDefaultDirection.ltr.name;
    final int fontSize = displaySettings.fontSize;

    // Custom swipe handling only applies to Android (native snap is used elsewhere).
    final bool useCustomSwipe =
        defaultTargetPlatform == TargetPlatform.android &&
        !displaySettings.useSnapAnimationAndroid;

    final String? foregroundColor = widget
        .displaySettings
        ?.theme
        ?.foregroundColor
        ?.toHex();
    final Map<String, dynamic>? customCss =
        widget.displaySettings?.theme?.customCss;

    final bool clearSelectionOnPageChange = widget.clearSelectionOnPageChange;

    // The iOS/iPad selection-polling fallbacks are only needed on mobile;
    // browsers (and desktop) fire `selectionchange` reliably, so we disable
    // polling there to avoid perpetual background CPU/battery cost.
    final bool usePolling = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    controller.callMethod('loadBook', [
      data,
      <String, dynamic>{
        'cfi': cfi,
        'initialXPath': initialXPath,
        'manager': manager,
        'flow': flow,
        'spread': spread,
        'snap': snap,
        'allowScriptedContent': allowScripted,
        'direction': direction,
        'useCustomSwipe': useCustomSwipe,
        'backgroundColor': null,
        'foregroundColor': foregroundColor,
        'fontSize': fontSize,
        'clearSelectionOnPageChange': clearSelectionOnPageChange,
        'selectAnnotationRange': widget.selectAnnotationRange,
        'customCss': customCss,
        'usePolling': usePolling,
      },
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return createEpubPlatformView(
      EpubPlatformViewConfig(
        backgroundDecoration: widget.displaySettings?.theme?.backgroundDecoration,
        contextMenu: widget.selectionContextMenu,
        suppressNativeContextMenu: widget.suppressNativeContextMenu,
        disableVerticalScroll: widget.displaySettings?.snap ?? false,
        onControllerCreated: (controller) {
          webViewController = controller;
          widget.epubController.setWebViewController(controller);
          addJavaScriptHandlers();
        },
      ),
    );
  }

  /// Start monitoring selection state to ensure blocking persists
  void _startSelectionMonitoring() {
    _stopSelectionMonitoring(); // Stop any existing timer

    _selectionCheckTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      if (!mounted || webViewController == null) {
        timer.cancel();
        return;
      }

      // Check if selection still exists and re-apply blocking if needed
      webViewController
          ?.callMethod('checkSelectionAndReapplyBlocking')
          .then((result) {
            // If selection no longer exists, stop monitoring
            if (result == 'no-selection') {
              _stopSelectionMonitoring();
              _blockGesturesWhenSelected(false);
            }
          });
    });
  }

  /// Stop monitoring selection state
  void _stopSelectionMonitoring() {
    _selectionCheckTimer?.cancel();
    _selectionCheckTimer = null;
  }

  @override
  void dispose() {
    _stopSelectionMonitoring();
    webViewController?.dispose();
    super.dispose();
  }
}
