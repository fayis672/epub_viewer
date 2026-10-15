/// Conditionally exposes the `dart:io` `File` type and a byte reader.
///
/// On the web there is no filesystem, so a lightweight stub `File` is used and
/// [readEpubFileBytes] throws [UnsupportedError]. Consumers should prefer
/// [EpubSource.fromUrl], [EpubSource.fromAsset] or [EpubSource.fromData] there.
library;

export 'file_loader_io.dart' if (dart.library.js_interop) 'file_loader_web.dart';
