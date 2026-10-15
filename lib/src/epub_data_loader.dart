import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'io/file_loader.dart';

/// Abstract interface for loading epub data
abstract class EpubDataLoader {
  Future<Uint8List> loadData();
}

/// File system epub loader implementation.
///
/// Not supported on the web (see [readEpubFileBytes]).
class FileEpubLoader implements EpubDataLoader {
  final File file;

  FileEpubLoader(this.file);

  @override
  Future<Uint8List> loadData() {
    return readEpubFileBytes(file);
  }
}

/// Network/URL epub loader implementation
class UrlEpubLoader implements EpubDataLoader {
  final String url;
  final Map<String, String>? headers;

  UrlEpubLoader(this.url, {this.headers});

  @override
  Future<Uint8List> loadData() async {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to download EPUB from $url (HTTP ${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }
}

/// Asset epub loader implementation
class AssetEpubLoader implements EpubDataLoader {
  final String assetPath;

  AssetEpubLoader(this.assetPath);

  @override
  Future<Uint8List> loadData() async {
    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }
}

/// In-memory epub loader implementation (bytes already available).
class DataEpubLoader implements EpubDataLoader {
  final Uint8List data;

  DataEpubLoader(this.data);

  @override
  Future<Uint8List> loadData() async => data;
}
