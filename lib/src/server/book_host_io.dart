import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../epub_data_loader.dart';
import '../models/epub_source.dart';
import 'book_host_stub.dart' show BookHostingUnsupported, HostedBook;
import 'epub_book_server.dart';
import 'epub_zip.dart';

export 'book_host_stub.dart' show BookHostingUnsupported, HostedBook;

const bool isBookHostingSupported = true;

/// Serves [source] through [EpubBookServer].
///
/// * File: entries stream straight from disk; the file is never fully read.
/// * URL: downloaded straight to a temporary file (no in-memory copy), which
///   is deleted on [HostedBook.close].
/// * Asset / data: served from the bytes already in memory.
///
/// Throws [BookHostingUnsupported] when the archive cannot be served this way
/// (not a zip, ZIP64, encrypted); other errors (missing file, HTTP failure)
/// propagate as load errors.
Future<HostedBook> hostEpub(EpubSource source) async {
  final loader = epubSourceLoader(source);
  File? download;
  try {
    final EpubZip zip;
    if (loader is FileEpubLoader) {
      zip = await EpubZip.openFile(loader.file.path);
    } else if (loader is UrlEpubLoader) {
      download = await _download(loader);
      zip = await EpubZip.openFile(download.path);
    } else {
      zip = await EpubZip.openBytes(await source.epubData);
    }
    final url = await EpubBookServer.instance.register(zip);
    return _HostedBook(url, download);
  } on EpubZipException catch (e) {
    await _deleteQuietly(download);
    throw BookHostingUnsupported(e);
  } catch (_) {
    await _deleteQuietly(download);
    rethrow;
  }
}

class _HostedBook implements HostedBook {
  _HostedBook(this._url, this._download);

  final Uri _url;
  final File? _download;
  bool _closed = false;

  @override
  String get url => _url.toString();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await EpubBookServer.instance.unregister(_url);
    await _deleteQuietly(_download);
  }
}

final Random _random = Random();
bool _cleanedStaleDownloads = false;

Future<File> _download(UrlEpubLoader loader) async {
  final dir = Directory('${Directory.systemTemp.path}/flutter_epub_viewer');
  await dir.create(recursive: true);
  if (!_cleanedStaleDownloads) {
    _cleanedStaleDownloads = true;
    unawaited(_deleteStale(dir));
  }
  final file = File(
    '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}.epub',
  );

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(loader.url));
    if (loader.headers != null) request.headers.addAll(loader.headers!);
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to download EPUB from ${loader.url} (HTTP ${response.statusCode})',
      );
    }
    await response.stream.pipe(file.openWrite());
    return file;
  } catch (_) {
    await _deleteQuietly(file);
    rethrow;
  } finally {
    client.close();
  }
}

/// Removes downloads left behind by a previous run that ended without
/// closing its viewer (e.g. the app was killed).
Future<void> _deleteStale(Directory dir) async {
  final cutoff = DateTime.now().subtract(const Duration(days: 1));
  try {
    await for (final entity in dir.list()) {
      if (entity is File && (await entity.lastModified()).isBefore(cutoff)) {
        await _deleteQuietly(entity);
      }
    }
  } catch (_) {}
}

Future<void> _deleteQuietly(File? file) async {
  try {
    if (file != null && await file.exists()) await file.delete();
  } catch (_) {}
}
