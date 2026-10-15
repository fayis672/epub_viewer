import 'package:flutter/painting.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EpubLocation round-trips through JSON', () {
    final json = {
      'startCfi': 'a',
      'endCfi': 'b',
      'startXpath': '/x',
      'endXpath': '/y',
      'progress': 0.5,
    };
    final loc = EpubLocation.fromJson(json);
    expect(loc.startCfi, 'a');
    expect(loc.progress, 0.5);
    expect(loc.toJson()['endXpath'], '/y');
  });

  test('EpubLocation parses chapter page fields, which are optional', () {
    final loc = EpubLocation.fromJson({
      'startCfi': 'a',
      'endCfi': 'b',
      'progress': 0.25,
      'chapterPage': 3,
      'chapterTotalPages': 12,
      'printedPage': 'xii',
    });
    expect(loc.chapterPage, 3);
    expect(loc.chapterTotalPages, 12);
    expect(loc.printedPage, 'xii');

    final bare =
        EpubLocation.fromJson({'startCfi': 'a', 'endCfi': 'b', 'progress': 0});
    expect(bare.chapterPage, isNull);
    expect(bare.printedPage, isNull);
  });

  test('EpubFootnote parses and tolerates missing fields', () {
    final note = EpubFootnote.fromJson({
      'href': 'Text/notes.xhtml#n1',
      'text': 'A note.',
      'html': '<p>A note.</p>',
      'linkText': '1',
    });
    expect(note.href, 'Text/notes.xhtml#n1');
    expect(note.text, 'A note.');
    expect(note.linkText, '1');
    expect(EpubFootnote.fromJson({}).html, '');
  });

  test('EpubDisplaySettings and EpubTheme round-trip through JSON', () {
    final settings = EpubDisplaySettings(
      fontSize: 18,
      flow: EpubFlow.scrolled,
      spread: EpubSpread.none,
      theme: EpubTheme.custom(
        foregroundColor: const Color(0xff112233),
        customCss: {
          'p': {'color': 'red'},
        },
      ),
    );
    final json = settings.toJson();
    expect(json['flow'], 'scrolled');
    expect(json['theme']['foregroundColor'], 'ff112233');

    final restored = EpubDisplaySettings.fromJson(json);
    expect(restored.fontSize, 18);
    expect(restored.flow, EpubFlow.scrolled);
    expect(restored.spread, EpubSpread.none);
    expect(restored.manager, EpubManager.continuous);
    expect(restored.theme!.foregroundColor, const Color(0xff112233));
    expect(restored.theme!.customCss!['p'], {'color': 'red'});
    expect(restored.theme!.themeType, EpubThemeType.custom);

    // Without a theme, the key is omitted and defaults apply on parse.
    expect(EpubDisplaySettings().toJson().containsKey('theme'), isFalse);
    expect(EpubDisplaySettings.fromJson({}).flow, EpubFlow.paginated);
  });

  test('EpubChapter parses nested subitems', () {
    final chapters = parseChapterList([
      {
        'title': 'One',
        'href': 'ch1.xhtml',
        'id': 'c1',
        'subitems': [
          {'title': 'One.A', 'href': 'ch1a.xhtml', 'id': 'c1a', 'subitems': []},
        ],
      },
    ]);
    expect(chapters, hasLength(1));
    expect(chapters.single.title, 'One');
    expect(chapters.single.subitems.single.href, 'ch1a.xhtml');
  });

  test('parseChapterList tolerates non-string keys (web dartify output)', () {
    // dartify can yield Map<Object?, Object?>; parseChapterList must cope.
    final chapters = parseChapterList(<Object?, Object?>{
      'title': 'T',
      'href': 'h',
      'id': 'i',
      'subitems': <Object?>[],
    });
    expect(chapters.single.title, 'T');
  });

  test('EpubSearchResult parses', () {
    final r = EpubSearchResult.fromJson(
        {'cfi': 'c', 'excerpt': 'e', 'xpath': '/p'});
    expect(r.cfi, 'c');
    expect(r.excerpt, 'e');
  });

  test('EpubTextExtractRes parses', () {
    final r = EpubTextExtractRes.fromJson(
        {'text': 'hello', 'cfiRange': 'r', 'xpathRange': null});
    expect(r.text, 'hello');
    expect(r.cfiRange, 'r');
    expect(r.xpathRange, isNull);
  });

  test('EpubDisplaySettings serializes with defaults', () {
    final s = EpubDisplaySettings();
    final json = s.toJson();
    expect(json['flow'], 'paginated');
    expect(json['manager'], 'continuous');
    expect(EpubDisplaySettings.fromJson(json).spread, EpubSpread.auto);
  });
}
