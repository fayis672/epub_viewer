import '../models/epub_source.dart';

/// A book served to the WebView; see `book_host_io.dart`.
abstract class HostedBook {
  /// Base URL to pass to epub.js `book.open`.
  String get url;

  /// Stops serving the book and deletes any temporary download.
  Future<void> close();
}

/// Thrown when the archive cannot be served by URL; the viewer then falls
/// back to loading the bytes.
class BookHostingUnsupported implements Exception {
  BookHostingUnsupported(this.reason);

  final Object reason;

  @override
  String toString() => 'BookHostingUnsupported: $reason';
}

const bool isBookHostingSupported = false;

Future<HostedBook> hostEpub(EpubSource source) =>
    throw UnsupportedError('Book hosting is not available on the web');
