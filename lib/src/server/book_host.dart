/// Serves an [EpubSource] to the WebView by URL (Android, iOS, macOS).
///
/// On the web there is no local server; [isBookHostingSupported] is false and
/// the viewer hands epub.js the bytes instead.
library;

export 'book_host_stub.dart' if (dart.library.io) 'book_host_io.dart';
