/// Thrown (via [EpubViewer.onLoadError]) when a book cannot be opened: the
/// source failed to load, or epub.js could not parse the file.
class EpubLoadException implements Exception {
  const EpubLoadException(this.message, {this.cause});

  final String message;

  /// The underlying error, when the failure came from the Dart side.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'EpubLoadException: $message'
      : 'EpubLoadException: $message ($cause)';
}
