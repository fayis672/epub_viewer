// End-to-end tests of book loading on a real WebView (Android, iOS, macOS).
//
//   cd example
//   flutter test integration_test/epub_loading_test.dart -d <device>
//
// Every scenario runs in both loading modes: the local book server
// (`useLocalServer: true`, the default) and the in-memory path that hands
// epub.js the whole file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_epub_viewer/src/server/epub_book_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/reader_harness.dart';
import 'support/synthetic_epub.dart';

const _sampleAsset = 'assets/sample.epub';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File illustrated;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('epub_e2e');
    illustrated = await writeSyntheticEpub(
      '${tempDir.path}/illustrated.epub',
      title: 'Illustrated',
      chapters: 12,
      imageSize: 320,
    );
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  for (final server in [true, false]) {
    final mode = server ? 'local server' : 'in-memory';

    group(mode, () {
      testWidgets('opens, navigates and searches the sample book', (tester) async {
        final run = await openReader(
          tester,
          EpubSource.fromAsset(_sampleAsset),
          server: server,
        );
        await waitForFirstPage(tester, run);
        await waitUntil(tester, () => run.chapterEvents.isNotEmpty, what: 'chapters');
        expect(run.chapters, isNotEmpty);

        final metadata = await run.controller.getMetadata();
        expect(metadata.title, isNotEmpty);

        await waitForLocations(tester, run);
        final start = await run.controller.getCurrentLocation();

        final next = await relocateAfter(tester, run, run.controller.next);
        expect(next.startCfi, isNot(start.startCfi), reason: 'next() moved');

        // Jump to a later chapter from the table of contents.
        final target = run.chapters[run.chapters.length ~/ 2];
        final jumped = await relocateAfter(
          tester,
          run,
          () => run.controller.display(cfi: target.href),
          what: 'display(${target.href})',
        );
        expect(jumped.progress, greaterThan(0));

        final results = await run.controller.search(query: 'the');
        expect(results, isNotEmpty);

        final text = await run.controller.extractCurrentPageText();
        expect(text.text?.trim(), isNotEmpty);
        expect(run.errors, isEmpty);
        await closeReader(tester);
      });

      testWidgets('opens a file and a URL', (tester) async {
        // File.
        final file = File('${tempDir.path}/sample_$server.epub');
        await file.writeAsBytes(
          (await rootBundle.load(_sampleAsset)).buffer.asUint8List(),
        );
        var run = await openReader(tester, EpubSource.fromFile(file), server: server);
        await waitForFirstPage(tester, run);
        await closeReader(tester);

        // URL, served by a throwaway origin server on the device.
        final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => origin.close(force: true));
        String? auth;
        origin.listen((request) async {
          auth = request.headers.value('authorization');
          if (request.uri.path == '/book.epub') {
            await request.response.addStream(file.openRead());
          } else {
            request.response.statusCode = 404;
          }
          await request.response.close();
        });
        run = await openReader(
          tester,
          EpubSource.fromUrl(
            'http://127.0.0.1:${origin.port}/book.epub',
            headers: {'Authorization': 'Bearer test'},
          ),
          server: server,
        );
        await waitForFirstPage(tester, run);
        expect(auth, 'Bearer test');
        await closeReader(tester);

        run = await openReader(
          tester,
          EpubSource.fromUrl('http://127.0.0.1:${origin.port}/missing.epub'),
          server: server,
        );
        await waitUntil(tester, () => run.errors.isNotEmpty, what: 'HTTP 404 error');
        expect(run.errors.single.toString(), contains('HTTP 404'));
        await closeReader(tester);
      });

      testWidgets('reports load errors', (tester) async {
        final cases = <String, EpubSource>{
          'not a zip': EpubSource.fromData(Uint8List.fromList(List.filled(100, 7))),
          'missing asset': EpubSource.fromAsset('assets/missing.epub'),
          'missing file': EpubSource.fromFile(File('${tempDir.path}/nope.epub')),
        };
        for (final entry in cases.entries) {
          final run = await openReader(tester, entry.value, server: server);
          await waitUntil(tester, () => run.errors.isNotEmpty, what: entry.key);
          expect(run.firstPageAt, isNull, reason: entry.key);
          await closeReader(tester);
        }
      });

      testWidgets('swapping the source loads the new book in place', (tester) async {
        final run = await openReader(
          tester,
          EpubSource.fromAsset(_sampleAsset),
          server: server,
        );
        await waitUntil(tester, () => run.chapterEvents.isNotEmpty, what: 'first book');
        final firstTitles = run.chapters.map((c) => c.title).toList();

        sourceNotifier.value = EpubSource.fromFile(illustrated);
        await tester.pump();
        await waitUntil(tester, () => run.chapterEvents.length >= 2, what: 'second book');
        expect(run.chapters.map((c) => c.title), isNot(firstTitles));
        expect(run.chapters.first.title, 'Chapter 1');
        expect((await run.controller.getMetadata()).title, 'Illustrated');
        expect(run.errors, isEmpty);
        await closeReader(tester);
      });

      testWidgets('cached locations skip generation', (tester) async {
        var run = await openReader(tester, EpubSource.fromFile(illustrated), server: server);
        await waitUntil(tester, () => run.generatedLocations.isNotEmpty, what: 'generated');
        await waitForLocations(tester, run);
        final cached = run.generatedLocations.single;
        // Measured from mount: locations can be ready before the first page
        // is displayed, since both load in parallel.
        final generatedIn = run.locationsAt!;
        await closeReader(tester);

        run = await openReader(
          tester,
          EpubSource.fromFile(illustrated),
          server: server,
          initialLocations: cached,
        );
        await waitForLocations(tester, run);
        expect(run.generatedLocations, isEmpty, reason: 'cache used, not regenerated');
        final loadedIn = run.locationsAt!;
        debugPrint('[e2e] locations: generated in ${generatedIn.inMilliseconds} ms, '
            'from cache in ${loadedIn.inMilliseconds} ms ($mode)');
        // Cached locations can be ready before the opening page's relocation
        // reaches Dart; don't mistake that one for the display() below.
        await waitUntil(tester, () => run.relocations.isNotEmpty, what: 'initial relocation');

        final location = await relocateAfter(
          tester,
          run,
          () => run.controller.display(cfi: run.chapters.last.href),
        );
        expect(location.progress, greaterThan(0.8), reason: 'progress from cache');
        await closeReader(tester);
      });
    });
  }

  testWidgets('local server reads only what is displayed', (tester) async {
    final log = EpubBookServer.instance.debugRequestLog = [];
    addTearDown(() => EpubBookServer.instance.debugRequestLog = null);

    final run = await openReader(tester, EpubSource.fromFile(illustrated), server: true);
    await waitForFirstPage(tester, run);
    await waitUntil(
      tester,
      () => log.contains('OEBPS/images/img1.bmp'),
      what: 'chapter 1 image',
      timeout: const Duration(seconds: 15),
    );
    expect(log, contains('OEBPS/text/ch1.xhtml'));
    expect(log.where((p) => p.startsWith('OEBPS/images/')), ['OEBPS/images/img1.bmp'],
        reason: 'only the displayed chapter\'s image is fetched');

    // Location generation reads every chapter's text, but no images.
    await waitForLocations(tester, run);
    expect(log, contains('OEBPS/text/ch12.xhtml'));
    expect(log.where((p) => p.startsWith('OEBPS/images/')).toSet(), {'OEBPS/images/img1.bmp'});
    await closeReader(tester);
  });

  testWidgets('both modes produce the same book', (tester) async {
    Future<Map<String, Object?>> describe(bool server) async {
      final run = await openReader(tester, EpubSource.fromAsset(_sampleAsset), server: server);
      await waitForFirstPage(tester, run);
      await waitUntil(tester, () => run.chapterEvents.isNotEmpty, what: 'chapters');
      await waitForLocations(tester, run);
      final metadata = await run.controller.getMetadata();
      final search = await run.controller.search(query: 'river');
      final firstCfi = (await run.controller.getCurrentLocation()).startCfi;
      final result = {
        'title': metadata.title,
        'author': metadata.author,
        'chapters': run.chapters.map((c) => '${c.title}|${c.href}').toList(),
        'search': search.map((r) => r.cfi).toList(),
        'firstCfi': firstCfi,
      };
      await closeReader(tester);
      return result;
    }

    final viaServer = await describe(true);
    final inMemory = await describe(false);
    expect(viaServer, inMemory);
  });
}
