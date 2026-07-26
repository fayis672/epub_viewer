/// Conditionally exposes the `dart:io` `File` type and a byte reader.
///
/// On the web there is no filesystem, so a lightweight stub `File` is used and
/// [readEpubFileBytes] throws [UnsupportedError]. Consumers should prefer
/// [EpubSource.fromUrl], [EpubSource.fromAsset] or [EpubSource.fromData] there.
library;

export 'file_loader_web.dart' if (dart.library.io) 'file_loader_io.dart';
