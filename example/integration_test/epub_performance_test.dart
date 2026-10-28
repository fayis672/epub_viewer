// Before/after benchmark: in-memory loading (the pre-2.2 path) versus the
// local book server, on the same books and device.
//
//   cd example
//   flutter test integration_test/epub_performance_test.dart -d <device>
//
// Optional: --dart-define=PERF_ROUNDS=5 (default 3)
//           --dart-define=PERF_MODE=server|memory  (one mode only, for memory
//           measurements from the host; see tool/measure_memory.sh)
//
// Prints one `PERF|...` line per measurement and a median table at the end.
// On macOS keep the test window visible: macOS throttles timers and
// animation frames in covered windows, which stalls the WebView.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/reader_harness.dart';
import 'support/synthetic_epub.dart';

const _rounds = int.fromEnvironment('PERF_ROUNDS', defaultValue: 3);
const _onlyMode = String.fromEnvironment('PERF_MODE');

class _Sample {
  _Sample(this.book, this.mode);

  final String book;
  final String mode;
  int? firstPageMs;
  int? locationsMs;
  int? nextMs;
  int? searchMs;
  String? failure;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('performance: in-memory vs local server', (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('epub_perf');
    addTearDown(() => tempDir.delete(recursive: true));

    final sample = File('${tempDir.path}/sample.epub');
    await sample.writeAsBytes(
      (await rootBundle.load('assets/sample.epub')).buffer.asUint8List(),
    );
    // Book label -> (file, search query). The synthetic books use a 23-word
    // vocabulary, so 'river' has tens of thousands of hits there: a stress
    // test of search, not a typical query.
    final books = <String, (File, String)>{
      'sample (${_mb(sample)})': (sample, 'chapter'),
    };
    final illustrated = await writeSyntheticEpub(
      '${tempDir.path}/illustrated.epub',
      title: 'Illustrated',
      chapters: 40,
      imageSize: 480,
    );
    books['illustrated 40 ch + 40 images (${_mb(illustrated)})'] = (illustrated, 'river');
    final longText = await writeSyntheticEpub(
      '${tempDir.path}/long.epub',
      title: 'Long text',
      chapters: 300,
    );
    books['text-only 300 ch (${_mb(longText)})'] = (longText, 'river');

    final modes = _onlyMode.isEmpty ? ['memory', 'server'] : [_onlyMode];

    // Warm up the WebView and caches once per mode; not recorded.
    for (final mode in modes) {
      await _measure(tester, 'warm-up', sample, 'chapter', mode);
    }

    final samples = <_Sample>[];
    for (final entry in books.entries) {
      for (var round = 0; round < _rounds; round++) {
        // Alternate the order so neither mode always runs first.
        final order = round.isEven ? modes : modes.reversed.toList();
        for (final mode in order) {
          final (file, query) = entry.value;
          final s = await _measure(tester, entry.key, file, query, mode);
          samples.add(s);
          debugPrint('PERF|${Platform.operatingSystem}|${s.book}|${s.mode}|'
              'round=$round|firstPage=${s.firstPageMs}|locations=${s.locationsMs}|'
              'next=${s.nextMs}|search=${s.searchMs}|failure=${s.failure ?? ''}');
        }
      }
    }

    debugPrint(_table(samples, books.keys.toList(), modes));
  }, timeout: const Timeout(Duration(minutes: 45)));
}

Future<_Sample> _measure(
  WidgetTester tester,
  String book,
  File file,
  String query,
  String mode,
) async {
  final s = _Sample(book, mode);
  final run = await openReader(
    tester,
    EpubSource.fromFile(file),
    server: mode == 'server',
  );
  try {
    await waitForFirstPage(tester, run, timeout: const Duration(minutes: 3));
    s.firstPageMs = run.firstPageAt!.inMilliseconds;
    await waitForLocations(tester, run, timeout: const Duration(minutes: 5));
    s.locationsMs = run.locationsAt!.inMilliseconds;

    final nextClock = Stopwatch()..start();
    await relocateAfter(tester, run, run.controller.next);
    // relocateAfter adds a fixed 300 ms settle; report the turn itself.
    s.nextMs = nextClock.elapsedMilliseconds - 300;

    final searchClock = Stopwatch()..start();
    run.controller.requestTimeout = const Duration(minutes: 3);
    final results = await _pumpWhile(tester, run.controller.search(query: query));
    s.searchMs = searchClock.elapsedMilliseconds;
    expect(results, isNotEmpty);
  } catch (e) {
    s.failure = e.toString().split('\n').first;
  }
  await closeReader(tester);
  return s;
}

Future<T> _pumpWhile<T>(WidgetTester tester, Future<T> future) async {
  T? value;
  Object? error;
  var done = false;
  future.then((v) {
    value = v;
    done = true;
  }, onError: (Object e) {
    error = e;
    done = true;
  });
  await waitUntil(tester, () => done, what: 'search', timeout: const Duration(minutes: 3));
  if (error != null) throw error!;
  return value as T;
}

String _mb(File f) => '${(f.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB';

int? _median(Iterable<int?> values) {
  final v = values.whereType<int>().toList()..sort();
  if (v.isEmpty) return null;
  return v[v.length ~/ 2];
}

String _table(List<_Sample> samples, List<String> books, List<String> modes) {
  final out = StringBuffer('\nPERF SUMMARY (${Platform.operatingSystem}, median of '
      '$_rounds rounds, ms from mount)\n');
  out.writeln('book | mode | first page | locations ready | next() | search | failures');
  for (final book in books) {
    for (final mode in modes) {
      final rows = samples.where((s) => s.book == book && s.mode == mode);
      out.writeln([
        book,
        mode,
        _median(rows.map((s) => s.firstPageMs)),
        _median(rows.map((s) => s.locationsMs)),
        _median(rows.map((s) => s.nextMs)),
        _median(rows.map((s) => s.searchMs)),
        rows.where((s) => s.failure != null).length,
      ].join(' | '));
    }
  }
  return out.toString();
}
