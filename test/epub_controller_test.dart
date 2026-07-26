import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_epub_viewer/src/platform/epub_web_view_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls and returns canned responses so the controller can be tested
/// without a real WebView / browser.
class FakeBridge implements EpubWebViewController {
  FakeBridge({this.responses = const {}, this.delay = Duration.zero});

  final Map<String, dynamic> responses;
  final Duration delay;
  final List<({String name, List<dynamic> args})> calls = [];

  @override
  Future<dynamic> callMethod(String name, [List<dynamic> args = const []]) async {
    calls.add((name: name, args: args));
    return null;
  }

  @override
  Future<dynamic> callAsync(String name, [List<dynamic> args = const []]) async {
    calls.add((name: name, args: args));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return responses[name];
  }

  @override
  void addHandler(String name, EpubJsHandler callback) {}

  @override
  void dispose() {}
}

void main() {
  group('EpubController fire-and-forget commands', () {
    late FakeBridge bridge;
    late EpubController controller;

    setUp(() {
      bridge = FakeBridge();
      controller = EpubController()..setWebViewController(bridge);
    });

    test('next/prev/display map to the right JS functions', () {
      controller.next();
      controller.prev();
      controller.display(cfi: 'epubcfi(/6/2)');
      expect(bridge.calls[0].name, 'next');
      expect(bridge.calls[1].name, 'previous');
      expect(bridge.calls[2].name, 'toCfi');
      expect(bridge.calls[2].args, ['epubcfi(/6/2)']);
    });

    test('addHighlight passes cfi + hex color + opacity', () {
      controller.addHighlight(cfi: 'cfi1', color: const Color(0xFFFF0000));
      final call = bridge.calls.single;
      expect(call.name, 'addHighlight');
      expect(call.args[0], 'cfi1');
      expect(call.args[1], '#ff0000');
    });

    test('setSpread/setFlow use enum .name', () async {
      await controller.setSpread(spread: EpubSpread.always);
      await controller.setFlow(flow: EpubFlow.scrolled);
      expect(bridge.calls[0].args, ['always']);
      expect(bridge.calls[1].args, ['scrolled']);
    });

    test('throws when the viewer is not loaded', () {
      expect(() => EpubController().next(), throwsA(isA<Exception>()));
    });
  });

  group('EpubController request/response', () {
    test('getCurrentLocation parses the returned map', () async {
      final bridge = FakeBridge(responses: {
        'getCurrentLocation': {
          'startCfi': 'a',
          'endCfi': 'b',
          'startXpath': '/x',
          'endXpath': '/y',
          'progress': 0.42,
        },
      });
      final controller = EpubController()..setWebViewController(bridge);
      final loc = await controller.getCurrentLocation();
      expect(loc.startCfi, 'a');
      expect(loc.endCfi, 'b');
      expect(loc.progress, 0.42);
    });

    test('search parses a list of results', () async {
      final bridge = FakeBridge(responses: {
        'searchInBook': [
          {'cfi': 'c1', 'excerpt': 'hello', 'xpath': null},
          {'cfi': 'c2', 'excerpt': 'world', 'xpath': '/z'},
        ],
      });
      final controller = EpubController()..setWebViewController(bridge);
      final results = await controller.search(query: 'x');
      expect(results, hasLength(2));
      expect(results[1].cfi, 'c2');
      expect(results[1].excerpt, 'world');
    });

    test('empty search query short-circuits without a bridge call', () async {
      final bridge = FakeBridge();
      final controller = EpubController()..setWebViewController(bridge);
      expect(await controller.search(query: ''), isEmpty);
      expect(bridge.calls, isEmpty);
    });

    test('getRectFromCfi returns a Rect, or null when JS returns null', () async {
      final withRect = EpubController()
        ..setWebViewController(FakeBridge(responses: {
          'getRectFromCfi': {
            'left': 1.0,
            'top': 2.0,
            'right': 3.0,
            'bottom': 4.0
          },
        }));
      expect(await withRect.getRectFromCfi('cfi'),
          const Rect.fromLTRB(1, 2, 3, 4));

      final nullRect = EpubController()
        ..setWebViewController(FakeBridge(responses: {'getRectFromCfi': null}));
      expect(await nullRect.getRectFromCfi('cfi'), isNull);
    });

    test('a request that never replies throws TimeoutException', () async {
      final bridge = FakeBridge(delay: const Duration(seconds: 5));
      final controller = EpubController()
        ..setWebViewController(bridge)
        ..requestTimeout = const Duration(milliseconds: 40);
      await expectLater(
        controller.getCurrentLocation(),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
