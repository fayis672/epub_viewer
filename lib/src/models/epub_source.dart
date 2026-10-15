import 'dart:typed_data';
import 'package:flutter_epub_viewer/src/epub_data_loader.dart';
import 'package:flutter_epub_viewer/src/io/file_loader.dart';

/// Epub file source
///
/// Loading is lazy: nothing is read or downloaded until the viewer needs the
/// bytes, and the result is reused afterwards. Two sources pointing at the same
/// file path, URL (and headers), asset or byte buffer are equal, so creating a
/// source inside `build()` does not reload the book on every rebuild.
class EpubSource {
  EpubSource._(this._loader, this._key);

  final EpubDataLoader _loader;

  /// Identifies what this source points at; drives [==] and [hashCode].
  final Object _key;

  Future<Uint8List>? _data;

  /// The EPUB bytes. Loaded on first access and cached; a failed load is not
  /// cached, so the next access retries.
  Future<Uint8List> get epubData {
    return _data ??= _loader.loadData().catchError((Object e, StackTrace s) {
      _data = null;
      return Future<Uint8List>.error(e, s);
    });
  }

  ///Loading from a file.
  ///
  ///Not supported on the web — use [EpubSource.fromUrl], [EpubSource.fromAsset]
  ///or [EpubSource.fromData] instead.
  factory EpubSource.fromFile(File file) {
    return EpubSource._(FileEpubLoader(file), ('file', file.path));
  }

  ///load from a url with optional headers
  factory EpubSource.fromUrl(String url, {Map<String, String>? headers}) {
    final headerEntries = (headers?.entries.toList() ?? [])
      ..sort((a, b) => a.key.compareTo(b.key));
    return EpubSource._(
      UrlEpubLoader(url, headers: headers),
      ('url', url, headerEntries.map((e) => '${e.key}:${e.value}').join('\n')),
    );
  }

  ///load from assets
  factory EpubSource.fromAsset(String assetPath) {
    return EpubSource._(AssetEpubLoader(assetPath), ('asset', assetPath));
  }

  ///load from in-memory bytes (works on every platform, including the web)
  ///
  ///Sources are equal only when they wrap the same [Uint8List] instance.
  factory EpubSource.fromData(Uint8List data) {
    return EpubSource._(DataEpubLoader(data), ('data', data));
  }

  @override
  bool operator ==(Object other) => other is EpubSource && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}
