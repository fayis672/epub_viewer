import 'dart:typed_data';

/// Web stub for `dart:io`'s `File`.
///
/// The web build has no filesystem access, so this only carries a [path] and
/// cannot be read. Use [EpubSource.fromUrl], [EpubSource.fromAsset] or
/// [EpubSource.fromData] on the web instead.
class File {
  File(this.path);

  final String path;
}

/// Always throws on the web — there is no local filesystem to read from.
Future<Uint8List> readEpubFileBytes(File file) => throw UnsupportedError(
  'EpubSource.fromFile is not supported on the web. '
  'Use EpubSource.fromUrl, EpubSource.fromAsset or EpubSource.fromData instead.',
);
