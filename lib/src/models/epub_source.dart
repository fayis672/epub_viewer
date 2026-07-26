import 'dart:typed_data';
import 'package:flutter_epub_viewer/src/epub_data_loader.dart';
import 'package:flutter_epub_viewer/src/io/file_loader.dart';

/// Epub file source
class EpubSource {
  // final Uint8List epubData;
  final Future<Uint8List> epubData;

  EpubSource._({required this.epubData});

  ///Loading from a file.
  ///
  ///Not supported on the web — use [EpubSource.fromUrl], [EpubSource.fromAsset]
  ///or [EpubSource.fromData] instead.
  factory EpubSource.fromFile(File file) {
    final loader = FileEpubLoader(file);
    return EpubSource._(epubData: loader.loadData());
  }

  ///load from a url with optional headers
  factory EpubSource.fromUrl(String url, {Map<String, String>? headers}) {
    final loader = UrlEpubLoader(url, headers: headers);
    return EpubSource._(epubData: loader.loadData());
  }

  ///load from assets
  factory EpubSource.fromAsset(String assetPath) {
    final loader = AssetEpubLoader(assetPath);
    return EpubSource._(epubData: loader.loadData());
  }

  ///load from in-memory bytes (works on every platform, including the web)
  factory EpubSource.fromData(Uint8List data) {
    final loader = DataEpubLoader(data);
    return EpubSource._(epubData: loader.loadData());
  }
}
