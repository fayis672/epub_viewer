/// Platform entry point for the EPUB web view.
///
/// Re-exports the shared bridge interface plus a platform specific
/// [createEpubPlatformView] function chosen at compile time:
///
/// * `dart.library.io`         -> mobile / desktop (flutter_inappwebview)
/// * `dart.library.js_interop` -> web (native `<iframe>` + `dart:js_interop`)
library;

export 'epub_web_view_interface.dart';
export 'epub_web_view_stub.dart'
    if (dart.library.io) 'epub_web_view_io.dart'
    if (dart.library.js_interop) 'epub_web_view_web.dart';
