import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'epub_zip.dart';

/// A response for a book request answered by interception (Android).
class InterceptedResponse {
  const InterceptedResponse(this.statusCode, this.contentType, this.body);

  final int statusCode;
  final String contentType;
  final Uint8List body;

  /// CORS headers: the reader page (`file://`) is a different origin, and
  /// both epub.js's XHR and `@font-face` need them.
  static const headers = {
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'private, max-age=31536000, immutable',
  };
}

/// Serves opened EPUBs to the WebView by URL.
///
/// epub.js then opens the book as an unpacked directory: it fetches only the
/// container, package file and the chapters it displays, and images and fonts
/// load as ordinary URLs. With bytes, it instead had to receive the whole file
/// over the JS bridge, hold it in JSZip and unpack every image, font and
/// stylesheet into a blob URL before showing the first page.
///
/// Two transports share one registry of books:
///
/// * iOS / macOS: a loopback HTTP server, `http://127.0.0.1:<port>/<token>/`.
///   Entries stream from disk straight into the socket.
/// * Android: request interception (`shouldInterceptRequest`) on
///   `https://flutter-epub-viewer.invalid/<token>/`. Android blocks cleartext
///   HTTP by default — including to 127.0.0.1 — so a loopback server would
///   fail unless every app changed its network security config. Intercepted
///   requests never touch the network, and no port is opened.
///
/// Security: books are only reachable under a random 128-bit token; the HTTP
/// server listens on the loopback interface only.
class EpubBookServer {
  EpubBookServer._();

  /// Shared by all viewers. The HTTP server starts on first use and stops
  /// when the last book is unregistered.
  static final EpubBookServer instance = EpubBookServer._();

  /// Host of intercepted book URLs. `.invalid` never resolves, so a request
  /// that somehow escapes interception fails instead of leaving the device.
  static const interceptHost = 'flutter-epub-viewer.invalid';

  /// Whether book URLs are served by interception rather than HTTP.
  static bool get usesInterception =>
      debugUseInterception ?? (!kIsWeb && Platform.isAndroid);

  /// Overrides the transport choice (tests).
  @visibleForTesting
  static bool? debugUseInterception;

  final Map<String, EpubZip> _books = {};
  Future<HttpServer>? _server;
  final Random _random = Random.secure();

  /// Number of books currently served (for tests).
  @visibleForTesting
  int get bookCount => _books.length;

  /// When non-null, the path of every request is appended (for tests that
  /// check which files a load actually reads).
  @visibleForTesting
  List<String>? debugRequestLog;

  /// Serves [zip] and returns the base URL epub.js should open.
  Future<Uri> register(EpubZip zip) async {
    // Register before awaiting the start, so a concurrent [unregister] of the
    // last other book does not shut the server down under this one.
    final token = _newToken();
    _books[token] = zip;
    if (usesInterception) {
      return Uri(scheme: 'https', host: interceptHost, path: '/$token/');
    }
    final HttpServer server;
    try {
      server = await (_server ??= _start());
    } catch (_) {
      _books.remove(token);
      _server = null;
      rethrow;
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/$token/',
    );
  }

  /// Stops serving the book at [url] (as returned by [register]).
  Future<void> unregister(Uri url) async {
    final segments = url.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isEmpty) return;
    _books.remove(segments.first);
    if (_books.isEmpty && _server != null) {
      final server = _server;
      _server = null;
      await (await server)?.close(force: true);
    }
  }

  /// Answers an intercepted WebView request, or returns null when [url] is
  /// not a book URL (the WebView then loads it normally).
  Future<InterceptedResponse?> intercept(Uri url) async {
    if (url.host != interceptHost) return null;
    final found = _lookup(url.pathSegments);
    if (found == null) {
      return InterceptedResponse(404, 'text/plain', Uint8List(0));
    }
    try {
      return InterceptedResponse(
        200,
        contentTypeFor(found.entry.name),
        await found.zip.readBytes(found.entry),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[EpubBookServer] $url: $e');
      return InterceptedResponse(500, 'text/plain', Uint8List(0));
    }
  }

  ({EpubZip zip, EpubZipEntry entry})? _lookup(List<String> segments) {
    debugRequestLog?.add(segments.skip(1).join('/'));
    final zip = segments.isEmpty ? null : _books[segments.first];
    final entry = zip?.find(segments.skip(1).join('/'));
    if (zip == null || entry == null) return null;
    return (zip: zip, entry: entry);
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // Drop Dart's defaults: X-Frame-Options: SAMEORIGIN would stop the
    // reader page (a different origin) from framing book content.
    server.defaultResponseHeaders.clear();
    server.listen(_handle, onError: (Object e) {
      if (kDebugMode) debugPrint('[EpubBookServer] $e');
    });
    return server;
  }

  String _newToken() {
    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    try {
      if (request.method == 'OPTIONS') {
        response.headers.set('Access-Control-Allow-Headers', '*');
        response.statusCode = HttpStatus.noContent;
        return;
      }
      if (request.method != 'GET' && request.method != 'HEAD') {
        response.statusCode = HttpStatus.methodNotAllowed;
        return;
      }

      final found = _lookup(request.uri.pathSegments);
      if (found == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }

      response.headers
        ..set(HttpHeaders.contentTypeHeader, contentTypeFor(found.entry.name))
        // Tokens are unique per open, so content under a URL never changes.
        ..set(HttpHeaders.cacheControlHeader, 'private, max-age=31536000, immutable');
      response.contentLength = found.entry.size;
      if (request.method == 'GET') {
        await response.addStream(found.zip.read(found.entry));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[EpubBookServer] ${request.uri}: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
      } on StateError {
        // Headers already sent; closing below ends the truncated response.
      }
    } finally {
      try {
        await response.close();
      } catch (_) {
        // The WebView may have cancelled the request.
      }
    }
  }

  /// MIME type for a file in an EPUB, by extension.
  @visibleForTesting
  static String contentTypeFor(String name) {
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return _contentTypes[ext] ?? 'application/octet-stream';
  }

  static const _contentTypes = {
    'xhtml': 'application/xhtml+xml',
    'xht': 'application/xhtml+xml',
    'html': 'text/html',
    'htm': 'text/html',
    'xml': 'application/xml',
    'opf': 'application/oebps-package+xml',
    'ncx': 'application/x-dtbncx+xml',
    'smil': 'application/smil+xml',
    'css': 'text/css',
    'js': 'text/javascript',
    'json': 'application/json',
    'svg': 'image/svg+xml',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'avif': 'image/avif',
    'bmp': 'image/bmp',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'txt': 'text/plain',
  };
}
