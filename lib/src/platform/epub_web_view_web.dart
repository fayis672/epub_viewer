import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'epub_web_view_interface.dart';

/// Relative URL (from the web app root) of the bundled epub.js host page.
const String _kEpubAssetPath =
    'assets/packages/flutter_epub_viewer/lib/assets/webpage/html/swipe.html';

/// Monotonic counter used to give every embedded view a unique platform-view
/// type. [Date.now]/random are intentionally avoided (unavailable/undesirable
/// here); a simple counter is enough for uniqueness within a session.
int _viewTypeCounter = 0;

/// Web bridge backed by a same-origin `<iframe>` hosting epub.js.
///
/// Instead of a webview plugin, this talks to the iframe's `contentWindow`
/// directly through `dart:js_interop`: outbound calls invoke the global
/// functions defined in `epubView.js`, and inbound messages arrive through a
/// tiny `window.flutter_inappwebview.callHandler` shim injected into the frame.
class WebEpubWebViewController implements EpubWebViewController {
  WebEpubWebViewController(this._window);

  final JSObject _window;
  final Map<String, EpubJsHandler> _handlers = {};
  bool _disposed = false;

  /// Installs the `window.flutter_inappwebview.callHandler` shim and signals
  /// epub.js that the bridge is ready (mirrors flutter_inappwebview's
  /// `flutterInAppWebViewPlatformReady` event).
  ///
  /// Built entirely through `dart:js_interop` — no `eval`, so it is safe under
  /// a strict Content-Security-Policy.
  ///
  /// Must be called *after* all handlers have been registered so the initial
  /// `readyToLoad` message is not lost.
  void signalReady() {
    final shim = JSObject();
    shim.setProperty('callHandler'.toJS, _callHandler.toJS);
    _window.setProperty('flutter_inappwebview'.toJS, shim);

    // Dispatch the readiness event using the iframe's OWN `Event` constructor so
    // the event and the target window share the same realm.
    final eventCtor = _window.getProperty('Event'.toJS) as JSFunction;
    final event = eventCtor.callAsConstructorVarArgs<JSObject>([
      'flutterInAppWebViewPlatformReady'.toJS,
    ]);
    _window.callMethodVarArgs('dispatchEvent'.toJS, [event]);
  }

  @override
  Future<dynamic> callMethod(String name, [List<dynamic> args = const []]) async {
    if (_disposed) return null;
    final fn = _window.getProperty(name.toJS);
    // Note: `isA<JSFunction>()` uses `instanceof`, which fails across realms —
    // the iframe's functions belong to a different realm than this one. `typeof`
    // is realm-agnostic, so use it instead.
    if (fn == null || !fn.typeofEquals('function')) {
      if (kDebugMode) {
        debugPrint('EpubViewer(web): JS function "$name" is not available');
      }
      return null;
    }
    final jsArgs = args.map(_toJs).toList();
    final result = _window.callMethodVarArgs(name.toJS, jsArgs);
    return _fromJs(result);
  }

  @override
  Future<dynamic> callAsync(String name, [List<dynamic> args = const []]) {
    // `callMethod` already awaits promises via `_fromJs`, so on web the async
    // request/response path is identical to a normal call.
    return callMethod(name, args);
  }

  @override
  void addHandler(String name, EpubJsHandler callback) {
    _handlers[name] = callback;
  }

  @override
  void dispose() {
    _disposed = true;
    _handlers.clear();
  }

  /// Backing implementation of `window.flutter_inappwebview.callHandler`.
  ///
  /// Uses scalar [JSAny] parameters rather than a `JSArray` because DDC's
  /// interop callback validation rejects passing a `JSArray<dynamic>` (the type
  /// a plain JS array arrives as) where a `JSArray<Object?>` is expected.
  /// epub.js never calls a handler with more than four trailing arguments; the
  /// extra slots cover future callbacks. Trailing nulls are trimmed because the
  /// Dart handlers already treat missing trailing arguments as null.
  JSAny? _callHandler(
    JSString name, [
    JSAny? a0,
    JSAny? a1,
    JSAny? a2,
    JSAny? a3,
    JSAny? a4,
    JSAny? a5,
    JSAny? a6,
    JSAny? a7,
  ]) {
    final handlerName = name.toDart;
    final handler = _handlers[handlerName];
    if (handler == null) return null;

    final raw = <JSAny?>[a0, a1, a2, a3, a4, a5, a6, a7];
    var end = raw.length;
    while (end > 0 && raw[end - 1] == null) {
      end--;
    }
    final dartArgs = raw.sublist(0, end).map(_jsToDart).toList();

    try {
      // The return value is never consumed by epub.js (callHandler is
      // fire-and-forget), and handlers may be async (returning a Future that
      // cannot be jsified), so nothing is returned to JavaScript.
      handler(dartArgs);
    } catch (e, s) {
      if (kDebugMode) {
        debugPrint('EpubViewer(web): handler "$handlerName" threw: $e\n$s');
      }
    }
    return null;
  }

  static JSAny? _toJs(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.toJS;
    if (value is bool) return value.toJS;
    if (value is Uint8List) return value.toJS;
    // NOTE: `jsify()` is an extension on Object?, and Dart does NOT dispatch
    // extension methods on a `dynamic` receiver — calling it directly on
    // `value` throws. Assigning to an `Object?`-typed local restores static
    // resolution so nums, Maps and Lists convert correctly.
    final Object? typed = value;
    return typed.jsify();
  }

  Future<dynamic> _fromJs(JSAny? result) async {
    if (result == null) return null;
    // `isA<JSPromise>()` uses `instanceof` and fails across realms, so detect a
    // thenable by duck-typing instead (the iframe's Promise is a different type).
    if (_isThenable(result)) {
      final resolved = await (result as JSPromise<JSAny?>).toDart;
      return _jsToDart(resolved);
    }
    return _jsToDart(result);
  }

  static bool _isThenable(JSAny? value) {
    if (value == null || !value.typeofEquals('object')) return false;
    final then = (value as JSObject).getProperty('then'.toJS);
    return then != null && then.typeofEquals('function');
  }

  /// Converts a JS value from the iframe realm into a plain Dart value.
  ///
  /// `dartify()` cannot be used here: across realms it fails to recognize the
  /// iframe's plain objects/arrays and returns them as opaque interop objects.
  /// Primitives are converted directly; objects and arrays are round-tripped
  /// through the iframe's own `JSON` so they become Dart `Map`/`List` trees.
  dynamic _jsToDart(JSAny? value) {
    if (value == null) return null;
    if (value.typeofEquals('string')) return (value as JSString).toDart;
    if (value.typeofEquals('number')) return (value as JSNumber).toDartDouble;
    if (value.typeofEquals('boolean')) return (value as JSBoolean).toDart;
    if (value.typeofEquals('function')) return null;

    final json = _jsonStringify(value);
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  /// Serializes [value] with the iframe's own `JSON.stringify`.
  String? _jsonStringify(JSAny? value) {
    if (value == null) return null;
    try {
      final jsonObj = _window.getProperty('JSON'.toJS) as JSObject;
      final str = jsonObj.callMethodVarArgs('stringify'.toJS, [value]);
      if (str == null || !str.typeofEquals('string')) return null;
      return (str as JSString).toDart;
    } catch (_) {
      return null;
    }
  }
}

/// Builds the web EPUB view (a native `<iframe>` embedded via [HtmlElementView]).
Widget createEpubPlatformView(EpubPlatformViewConfig config) {
  return _WebEpubView(config: config);
}

class _WebEpubView extends StatefulWidget {
  const _WebEpubView({required this.config});

  final EpubPlatformViewConfig config;

  @override
  State<_WebEpubView> createState() => _WebEpubViewState();
}

class _WebEpubViewState extends State<_WebEpubView> {
  late final String _viewType;
  WebEpubWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _viewType = 'flutter-epub-viewer-${_viewTypeCounter++}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = _kEpubAssetPath
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;

      iframe.onLoad.listen((_) => _onFrameLoaded(iframe));
      return iframe;
    });
  }

  void _onFrameLoaded(web.HTMLIFrameElement iframe) {
    final win = iframe.contentWindow;
    if (win == null) return;

    final controller = WebEpubWebViewController(win as JSObject);
    _controller = controller;

    // Register handlers (and let the viewer store the bridge)...
    widget.config.onControllerCreated(controller);
    // ...then announce readiness so `readyToLoad` -> loadBook fires.
    controller.signalReady();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = HtmlElementView(viewType: _viewType);
    final decoration = widget.config.backgroundDecoration;
    if (decoration == null) return view;
    return DecoratedBox(decoration: decoration, child: view);
  }
}
