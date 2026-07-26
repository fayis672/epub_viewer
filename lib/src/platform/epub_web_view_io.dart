import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/epub_context_menu.dart';
import 'epub_web_view_interface.dart';

/// Maps the package-owned [EpubContextMenu] to the plugin's native menu.
ContextMenu? _toNativeContextMenu(Object? menu, {required bool suppress}) {
  if (suppress) {
    return ContextMenu(
      menuItems: [],
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
    );
  }
  if (menu is! EpubContextMenu) return null;
  return ContextMenu(
    menuItems: [
      for (final item in menu.items)
        ContextMenuItem(id: item.id, title: item.title, action: item.action),
    ],
    settings: ContextMenuSettings(
      hideDefaultSystemContextMenuItems: menu.hideDefaultSystemItems,
    ),
  );
}

/// Mobile / desktop bridge backed by flutter_inappwebview.
class IoEpubWebViewController implements EpubWebViewController {
  IoEpubWebViewController(this._controller);

  final InAppWebViewController _controller;

  @override
  Future<dynamic> callMethod(String name, [List<dynamic> args = const []]) {
    final encoded = args.map(_encodeArg).join(',');
    return _controller.evaluateJavascript(source: '$name($encoded)');
  }

  @override
  Future<dynamic> callAsync(
    String name, [
    List<dynamic> args = const [],
  ]) async {
    // `callAsyncJavaScript` wraps the body in an async function and awaits its
    // result, resolving promises (which `evaluateJavascript` does not).
    // Arguments are passed as named parameters (JSON-serializable values only).
    final argNames = <String>[];
    final argMap = <String, dynamic>{};
    for (var i = 0; i < args.length; i++) {
      argNames.add('a$i');
      argMap['a$i'] = args[i];
    }
    final result = await _controller.callAsyncJavaScript(
      functionBody: 'return await $name(${argNames.join(', ')});',
      arguments: argMap,
    );
    if (result?.error != null) {
      throw Exception('EPUB JS error in "$name": ${result!.error}');
    }
    return result?.value;
  }

  @override
  void addHandler(String name, EpubJsHandler callback) {
    _controller.addJavaScriptHandler(
      handlerName: name,
      callback: (args) => callback(args),
    );
  }

  @override
  void dispose() {
    // The InAppWebViewController lifecycle is owned by the InAppWebView widget.
  }

  /// Encodes a Dart argument into an equivalent JavaScript literal so it can be
  /// spliced into an `evaluateJavascript` call.
  static String _encodeArg(dynamic value) {
    if (value == null) return 'null';
    if (value is bool || value is num) return value.toString();
    if (value is String) return jsonEncode(value);
    // Transfer bytes as a base64 string rather than a decimal array literal:
    // for a 4 MB EPUB that is ~5.5 MB of source instead of ~16 MB. `loadBook`
    // decodes it with atob(). (Web passes a real Uint8Array — see _toJs.)
    if (value is Uint8List) return jsonEncode(base64Encode(value));
    // Maps / Lists / other JSON-encodable structures.
    return jsonEncode(value);
  }
}

/// Builds the mobile EPUB view (an [InAppWebView] hosting `swipe.html`).
Widget createEpubPlatformView(EpubPlatformViewConfig config) {
  return _IoEpubView(config: config);
}

class _IoEpubView extends StatefulWidget {
  const _IoEpubView({required this.config});

  final EpubPlatformViewConfig config;

  @override
  State<_IoEpubView> createState() => _IoEpubViewState();
}

class _IoEpubViewState extends State<_IoEpubView> {
  final GlobalKey _webViewKey = GlobalKey();
  static InAppLocalhostServer? _localhostServer;
  bool _isServerReady = defaultTargetPlatform != TargetPlatform.macOS;

  late final InAppWebViewSettings _settings = InAppWebViewSettings(
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
  )..disableVerticalScroll = widget.config.disableVerticalScroll;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _initLocalServer();
    }
  }

  Future<void> _initLocalServer() async {
    _localhostServer ??= InAppLocalhostServer();
    if (!_localhostServer!.isRunning()) {
      await _localhostServer!.start();
    }
    if (mounted) {
      setState(() {
        _isServerReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServerReady) {
      return Container(decoration: widget.config.backgroundDecoration);
    }

    final config = widget.config;
    final isMacOs = defaultTargetPlatform == TargetPlatform.macOS;
    final port = _localhostServer?.port ?? 8080;
    final url =
        'http://localhost:$port/packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html';

    return Container(
      decoration: config.backgroundDecoration,
      child: InAppWebView(
        contextMenu: _toNativeContextMenu(
          config.contextMenu,
          suppress: config.suppressNativeContextMenu,
        ),
        key: _webViewKey,
        initialUrlRequest: isMacOs ? URLRequest(url: WebUri(url)) : null,
        initialFile: isMacOs
            ? null
            : 'packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html',
        initialSettings: _settings,
        onWebViewCreated: (controller) async {
          if (kDebugMode) {
            debugPrint("[EpubViewer] 1. InAppWebView created");
          }
          config.onControllerCreated(IoEpubWebViewController(controller));
          if (isMacOs) {
            if (kDebugMode) {
              debugPrint("[EpubViewer] 1b. Loading URL via localhost server: $url");
            }
            await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
          }
        },
        onLoadStart: (controller, url) {
          if (kDebugMode) {
            debugPrint("[EpubViewer] 2. WebView load started: $url");
          }
        },
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          return NavigationActionPolicy.ALLOW;
        },
        onLoadStop: (controller, url) async {
          if (kDebugMode) {
            debugPrint("[EpubViewer] 3. WebView load finished: $url");
          }
        },
        onReceivedError: (controller, request, error) {
          if (kDebugMode) {
            debugPrint("[EpubViewer] ERROR WebView error: ${error.description} (code: ${error.type}) for ${request.url}");
          }
        },
        onProgressChanged: (controller, progress) {},
        onUpdateVisitedHistory: (controller, url, androidIsReload) {},
        onConsoleMessage: (controller, consoleMessage) {
          if (kDebugMode) {
            debugPrint("[EpubViewer JS] [${consoleMessage.messageLevel}]: ${consoleMessage.message}");
          }
        },
        onLongPressHitTestResult: (controller, hitTestResult) {
          // On iPad, long press creates a selection but events don't fire.
          // Trigger a JavaScript check for the selection after a short delay
          // and then poll periodically while handles may be dragged.
          Future.delayed(const Duration(milliseconds: 300), () {
            controller.evaluateJavascript(
              source: 'checkSelectionAfterLongPress()',
            );

            var checkCount = 0;
            const maxChecks = 67; // 67 * 150ms = ~10 seconds
            Timer.periodic(const Duration(milliseconds: 150), (timer) {
              checkCount++;
              if (checkCount > maxChecks) {
                timer.cancel();
                return;
              }
              controller.evaluateJavascript(
                source: 'checkSelectionPeriodically()',
              );
            });
          });
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
}
