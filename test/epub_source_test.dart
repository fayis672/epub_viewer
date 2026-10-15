import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpubSource equality', () {
    test('same asset, file path or url are equal', () {
      expect(EpubSource.fromAsset('a.epub'), EpubSource.fromAsset('a.epub'));
      expect(
        EpubSource.fromFile(File('/books/a.epub')),
        EpubSource.fromFile(File('/books/a.epub')),
      );
      expect(
        EpubSource.fromUrl('https://x/a.epub', headers: {'a': '1', 'b': '2'}),
        EpubSource.fromUrl('https://x/a.epub', headers: {'b': '2', 'a': '1'}),
      );
      expect(
        EpubSource.fromAsset('a.epub').hashCode,
        EpubSource.fromAsset('a.epub').hashCode,
      );
    });

    test('different sources are not equal', () {
      expect(EpubSource.fromAsset('a.epub'), isNot(EpubSource.fromAsset('b.epub')));
      expect(
        EpubSource.fromUrl('https://x/a.epub', headers: {'a': '1'}),
        isNot(EpubSource.fromUrl('https://x/a.epub', headers: {'a': '2'})),
      );
      expect(
        EpubSource.fromAsset('a.epub'),
        isNot(EpubSource.fromFile(File('a.epub'))),
      );
    });

    test('fromData compares by buffer identity', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(EpubSource.fromData(bytes), EpubSource.fromData(bytes));
      expect(
        EpubSource.fromData(bytes),
        isNot(EpubSource.fromData(Uint8List.fromList([1, 2, 3]))),
      );
    });
  });

  group('EpubSource loading', () {
    test('caches the loaded bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final source = EpubSource.fromData(bytes);
      expect(identical(source.epubData, source.epubData), isTrue);
      expect(await source.epubData, bytes);
    });

    test('does not load on construction, and retries after a failure', () async {
      final dir = await Directory.systemTemp.createTemp('epub_source_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/book.epub');

      // Constructing a source for a missing file must not throw or leave an
      // unhandled error behind.
      final source = EpubSource.fromFile(file);
      await expectLater(source.epubData, throwsA(isA<FileSystemException>()));

      await file.writeAsBytes([9, 8, 7]);
      expect(await source.epubData, [9, 8, 7]);
    });
  });
}
