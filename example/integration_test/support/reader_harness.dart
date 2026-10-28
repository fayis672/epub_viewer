import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything a mounted [EpubViewer] reported, with timestamps measured from
/// the moment it was mounted.
class ReaderRun {
  ReaderRun(this.source, {required this.server});

  final EpubSource source;
  final bool server;
  final controller = EpubController();
  final clock = Stopwatch();

  Duration? firstPageAt;
  Duration? chaptersAt;
  Duration? locationsAt;
  final chapterEvents = <List<EpubChapter>>[];
  final relocations = <EpubLocation>[];
  final errors = <EpubLoadException>[];
  final generatedLocations = <String>[];
  int displayedCount = 0;

  List<EpubChapter> get chapters => chapterEvents.last;
}

/// Pumps frames until [condition] holds. Real time passes (integration tests
/// run on a live binding), so WebView work progresses meanwhile.
Future<void> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String what,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Timed out after $timeout waiting for $what');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump();
  }
}

/// Lets a test swap the source of an already-mounted viewer.
final sourceNotifier = ValueNotifier<EpubSource?>(null);

/// Mounts a viewer for [source] and returns its event recorder.
Future<ReaderRun> openReader(
  WidgetTester tester,
  EpubSource source, {
  required bool server,
  String? initialLocations,
  String? initialCfi,
}) async {
  final run = ReaderRun(source, server: server);
  sourceNotifier.value = source;
  run.clock.start();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: ValueListenableBuilder<EpubSource?>(
            valueListenable: sourceNotifier,
            builder: (context, current, _) => EpubViewer(
              epubController: run.controller,
              epubSource: current!,
              useLocalServer: server,
              initialLocations: initialLocations,
              initialCfi: initialCfi,
              onEpubLoaded: () {
                run.displayedCount++;
                run.firstPageAt ??= run.clock.elapsed;
              },
              onChaptersLoaded: (chapters) {
                run.chaptersAt ??= run.clock.elapsed;
                run.chapterEvents.add(chapters);
              },
              onLocationLoaded: () => run.locationsAt ??= run.clock.elapsed,
              onLocationsGenerated: run.generatedLocations.add,
              onRelocated: run.relocations.add,
              onLoadError: run.errors.add,
            ),
          ),
        ),
      ),
    ),
  );
  return run;
}

Future<void> waitForFirstPage(WidgetTester tester, ReaderRun run,
    {Duration timeout = const Duration(seconds: 120)}) {
  return waitUntil(
    tester,
    () {
      if (run.errors.isNotEmpty) {
        throw StateError('Load failed: ${run.errors.first}');
      }
      return run.firstPageAt != null;
    },
    what: 'first page (${run.server ? 'server' : 'in-memory'})',
    timeout: timeout,
  );
}

Future<void> waitForLocations(WidgetTester tester, ReaderRun run,
    {Duration timeout = const Duration(seconds: 180)}) {
  return waitUntil(tester, () => run.locationsAt != null,
      what: 'locations', timeout: timeout);
}

/// Unmounts the viewer and gives the WebView a moment to tear down.
Future<void> closeReader(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await tester.pump();
}

/// Calls [action] and waits for the relocation it causes.
Future<EpubLocation> relocateAfter(
  WidgetTester tester,
  ReaderRun run,
  void Function() action, {
  String what = 'relocation',
}) async {
  final before = run.relocations.length;
  action();
  await waitUntil(tester, () => run.relocations.length > before, what: what);
  // Let follow-up relocations from the same navigation settle.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await tester.pump();
  return run.relocations.last;
}
