import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_epub_viewer/src/server/book_host_io.dart';
import 'package:flutter_epub_viewer/src/server/epub_book_server.dart';
import 'package:flutter_epub_viewer/src/server/epub_zip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zipBytes = ZipEncoder().encodeBytes(
    Archive()
      ..add(ArchiveFile.string('META-INF/container.xml', '<container/>'))
      ..add(ArchiveFile.string('OEBPS/ch 1.xhtml', '<html>chapter one</html>'))
      ..add(ArchiveFile.string('OEBPS/style.css', 'body{}')),
  );

  final client = HttpClient();
  tearDownAll(() => client.close(force: true));

  Future<HttpClientResponse> get(Uri url, {String method = 'GET'}) async {
    final request = await client.openUrl(method, url);
    return request.close();
  }

  Future<String> body(HttpClientResponse response) =>
      response.transform(utf8.decoder).join();

  group('EpubBookServer', () {
    late Uri base;
    setUp(() async {
      base = await EpubBookServer.instance.register(
        await EpubZip.openBytes(zipBytes),
      );
    });
    tearDown(() => EpubBookServer.instance.unregister(base));

    test('listens on loopback under a random token', () {
      expect(base.host, '127.0.0.1');
      expect(base.pathSegments.first, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('serves entries with type, length, cache and CORS headers', () async {
      final response = await get(base.resolve('OEBPS/style.css'));
      expect(response.statusCode, 200);
      expect(response.headers.value('content-type'), 'text/css');
      expect(response.headers.value('access-control-allow-origin'), '*');
      expect(response.headers.value('cache-control'), contains('immutable'));
      expect(response.headers.value('x-frame-options'), isNull);
      expect(response.contentLength, 'body{}'.length);
      expect(await body(response), 'body{}');
    });

    test('decodes percent-encoded paths', () async {
      final response = await get(base.resolve('OEBPS/ch%201.xhtml'));
      expect(response.statusCode, 200);
      expect(response.headers.value('content-type'), 'application/xhtml+xml');
      expect(await body(response), '<html>chapter one</html>');
    });

    test('HEAD returns headers without a body', () async {
      final response = await get(base.resolve('OEBPS/style.css'), method: 'HEAD');
      expect(response.statusCode, 200);
      expect(response.contentLength, 'body{}'.length);
      expect(await body(response), isEmpty);
    });

    test('404 for missing entries and unknown tokens', () async {
      final missing = await get(base.resolve('OEBPS/nope.xhtml'));
      expect(missing.statusCode, 404);
      await missing.drain<void>();
      final wrongToken = await get(
        base.replace(path: '/${'0' * 32}/META-INF/container.xml'),
      );
      expect(wrongToken.statusCode, 404);
      await wrongToken.drain<void>();
    });

    test('rejects other methods; answers CORS preflight', () async {
      final post = await get(base.resolve('OEBPS/style.css'), method: 'POST');
      expect(post.statusCode, 405);
      await post.drain<void>();
      final options = await get(base.resolve('OEBPS/style.css'), method: 'OPTIONS');
      expect(options.statusCode, 204);
      await options.drain<void>();
    });

    test('stops serving after unregister', () async {
      final second = await EpubBookServer.instance.register(
        await EpubZip.openBytes(zipBytes),
      );
      await EpubBookServer.instance.unregister(second);
      final response = await get(second.resolve('OEBPS/style.css'));
      expect(response.statusCode, 404);
      await response.drain<void>();
    });
  });

  test('server shuts down when the last book is closed', () async {
    final url = await EpubBookServer.instance.register(
      await EpubZip.openBytes(zipBytes),
    );
    await EpubBookServer.instance.unregister(url);
    expect(EpubBookServer.instance.bookCount, 0);
    await expectLater(get(url), throwsA(isA<SocketException>()));
  });

  group('interception transport (Android)', () {
    setUp(() => EpubBookServer.debugUseInterception = true);
    tearDown(() => EpubBookServer.debugUseInterception = null);

    test('book URLs use the .invalid https host and open no port', () async {
      final url = await EpubBookServer.instance.register(
        await EpubZip.openBytes(zipBytes),
      );
      addTearDown(() => EpubBookServer.instance.unregister(url));
      expect(url.scheme, 'https');
      expect(url.host, EpubBookServer.interceptHost);

      final served = await EpubBookServer.instance.intercept(
        url.resolve('OEBPS/ch%201.xhtml'),
      );
      expect(served!.statusCode, 200);
      expect(served.contentType, 'application/xhtml+xml');
      expect(utf8.decode(served.body), '<html>chapter one</html>');
      expect(InterceptedResponse.headers['Access-Control-Allow-Origin'], '*');
    });

    test('other URLs pass through; unknown books are 404', () async {
      expect(
        await EpubBookServer.instance.intercept(
          Uri.parse('file:///android_asset/flutter_assets/swipe.html'),
        ),
        isNull,
      );
      final missing = await EpubBookServer.instance.intercept(
        Uri.https(EpubBookServer.interceptHost, '/${'0' * 32}/x.xhtml'),
      );
      expect(missing!.statusCode, 404);
    });
  });

  test('content types', () {
    expect(EpubBookServer.contentTypeFor('a/b.XHTML'), 'application/xhtml+xml');
    expect(EpubBookServer.contentTypeFor('f.woff2'), 'font/woff2');
    expect(EpubBookServer.contentTypeFor('img.JPG'), 'image/jpeg');
    expect(EpubBookServer.contentTypeFor('noext'), 'application/octet-stream');
  });

  group('hostEpub', () {
    test('serves a file source', () async {
      final dir = await Directory.systemTemp.createTemp('host_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/b.epub')..writeAsBytesSync(zipBytes);
      final hosted = await hostEpub(EpubSource.fromFile(file));
      addTearDown(hosted.close);
      final response = await get(Uri.parse(hosted.url).resolve('OEBPS/style.css'));
      expect(await body(response), 'body{}');
    });

    test('downloads a URL source to a temp file and deletes it on close', () async {
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => origin.close(force: true));
      String? authHeader;
      origin.listen((request) {
        authHeader = request.headers.value('authorization');
        if (request.uri.path == '/book.epub') {
          request.response.add(zipBytes);
        } else {
          request.response.statusCode = 404;
        }
        request.response.close();
      });
      final originUrl = 'http://127.0.0.1:${origin.port}';

      final hosted = await hostEpub(
        EpubSource.fromUrl('$originUrl/book.epub', headers: {'Authorization': 'Bearer x'}),
      );
      expect(authHeader, 'Bearer x');
      final tempDir = Directory('${Directory.systemTemp.path}/flutter_epub_viewer');
      final before = tempDir.listSync().length;
      final response = await get(Uri.parse(hosted.url).resolve('OEBPS/ch%201.xhtml'));
      expect(await body(response), '<html>chapter one</html>');
      await hosted.close();
      expect(tempDir.listSync().length, before - 1);

      await expectLater(
        hostEpub(EpubSource.fromUrl('$originUrl/missing.epub')),
        throwsA(predicate((e) => e.toString().contains('HTTP 404'))),
      );
    });

    test('serves in-memory data', () async {
      final hosted = await hostEpub(EpubSource.fromData(zipBytes));
      addTearDown(hosted.close);
      final response = await get(Uri.parse(hosted.url).resolve('META-INF/container.xml'));
      expect(await body(response), '<container/>');
    });

    test('non-zip data is reported as unsupported (viewer falls back)', () async {
      await expectLater(
        hostEpub(EpubSource.fromData(utf8.encode('not a zip'))),
        throwsA(isA<BookHostingUnsupported>()),
      );
    });

    test('a missing file is a load error, not a fallback', () async {
      await expectLater(
        hostEpub(EpubSource.fromFile(File('/no/such/book.epub'))),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
