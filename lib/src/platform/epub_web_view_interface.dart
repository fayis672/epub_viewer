import 'package:flutter/widgets.dart';

/// Signature for handlers invoked from the JavaScript side of the EPUB viewer.
///
/// On mobile this corresponds to `window.flutter_inappwebview.callHandler(name, ...args)`.
/// On web the same contract is fulfilled by a lightweight shim injected into the
/// hosting iframe, so the epub.js glue code (`epubView.js`) works unchanged on
/// every platform.
typedef EpubJsHandler = dynamic Function(List<dynamic> args);

/// Platform agnostic bridge to the JavaScript runtime that hosts epub.js.
///
/// Two implementations exist, selected at compile time via conditional imports:
///
/// * mobile / desktop – wraps `InAppWebViewController` (flutter_inappwebview)
/// * web – talks to a same-origin `<iframe>` directly through `dart:js_interop`
///
/// Both expose the exact same surface so that [EpubController] and [EpubViewer]
/// contain no platform specific branching.
abstract class EpubWebViewController {
  /// Invokes a global JavaScript function (declared in `epubView.js`) by [name]
  /// with the given [args] and returns its (Dart converted) result.
  ///
  /// Argument encoding is platform specific but semantically identical:
  ///
  /// * `String`            -> JS string
  /// * `num` / `bool`      -> JS number / boolean
  /// * `null`              -> JS null
  /// * `Uint8List`         -> JS `Uint8Array` (mobile encodes it as a byte array literal)
  /// * `Map` / `List`      -> plain JS object / array
  ///
  /// Functions that return a `Promise` are awaited before their value is returned.
  ///
  /// Use for fire-and-forget calls and synchronous return values.
  ///
  /// SECURITY INVARIANT: [name] MUST be a compile-time constant naming an
  /// `epubView.js` function — never a caller/book-supplied string. On mobile it
  /// is interpolated into an `evaluateJavascript` source string; passing
  /// untrusted data as [name] would be code injection. (Arguments are safe: they
  /// are `jsonEncode`d / passed as typed JS values.)
  Future<dynamic> callMethod(String name, [List<dynamic> args = const []]);

  /// Like [callMethod] but always awaits an async / `Promise`-returning JS
  /// function and returns its resolved (Dart-converted) value.
  ///
  /// This is the request/response primitive: on mobile it uses
  /// `callAsyncJavaScript` (which, unlike `evaluateJavascript`, resolves
  /// promises); on web it shares [callMethod]'s promise-aware path. Callers add
  /// their own [Future.timeout] so a missing reply surfaces as an error instead
  /// of hanging forever.
  Future<dynamic> callAsync(String name, [List<dynamic> args = const []]);

  /// Registers a [callback] that JavaScript can invoke through
  /// `window.flutter_inappwebview.callHandler('[name]', ...args)`.
  void addHandler(String name, EpubJsHandler callback);

  /// Releases any resources held by the bridge.
  void dispose();
}

/// Configuration passed to [createEpubPlatformView].
///
/// Mobile-only options ([contextMenu], [suppressNativeContextMenu],
/// [disableVerticalScroll]) are ignored by the web implementation.
class EpubPlatformViewConfig {
  EpubPlatformViewConfig({
    required this.onControllerCreated,
    this.backgroundDecoration,
    this.contextMenu,
    this.suppressNativeContextMenu = false,
    this.disableVerticalScroll = false,
  });

  /// Invoked once the platform view is ready and its [EpubWebViewController]
  /// bridge can be used. Handler registration and the initial `loadBook` call
  /// happen inside this callback.
  final void Function(EpubWebViewController controller) onControllerCreated;

  /// Optional background painted behind the viewer.
  final Decoration? backgroundDecoration;

  /// Native selection context menu (mobile only). Typed as [Object] so the
  /// interface does not depend on flutter_inappwebview; the mobile
  /// implementation casts it back to `ContextMenu?`.
  final Object? contextMenu;

  /// Suppress the native context menu entirely (mobile only).
  final bool suppressNativeContextMenu;

  /// Disable vertical scrolling of the underlying web view (mobile only,
  /// used when snap paging is enabled).
  final bool disableVerticalScroll;
}
