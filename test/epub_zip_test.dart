import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_epub_viewer/src/server/epub_zip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a zip with [files]; names in [stored] are not compressed.
Uint8List buildZip(Map<String, List<int>> files, {Set<String> stored = const {}}) {
  final archive = Archive();
  files.forEach((name, data) {
    final file = ArchiveFile.bytes(name, data);
    file.compression =
        stored.contains(name) ? CompressionType.none : CompressionType.deflate;
    archive.add(file);
  });
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  final random = Random(42);
  final binary = List<int>.generate(200000, (_) => random.nextInt(256));
  final text = utf8.encode('<html>${'lorem ipsum ' * 5000}</html>');

  final zipBytes = buildZip(
    {
      'mimetype': ascii.encode('application/epub+zip'),
      'META-INF/container.xml': utf8.encode('<container/>'),
      'OEBPS/ch1.xhtml': text,
      'OEBPS/Images/pic.bin': binary,
      'OEBPS/Ünïcødé name.xhtml': utf8.encode('unicode'),
    },
    stored: {'mimetype', 'OEBPS/Images/pic.bin'},
  );

  Future<void> expectReadsBack(EpubZip zip) async {
    expect(
      zip.entries.keys,
      containsAll([
        'mimetype',
        'META-INF/container.xml',
        'OEBPS/ch1.xhtml',
        'OEBPS/Images/pic.bin',
        'OEBPS/Ünïcødé name.xhtml',
      ]),
    );
    final ch1 = zip.find('OEBPS/ch1.xhtml')!;
    expect(ch1.method, 8, reason: 'text should be deflated');
    expect(ch1.size, text.length);
    expect(await zip.readBytes(ch1), text);

    final pic = zip.find('OEBPS/Images/pic.bin')!;
    expect(pic.method, 0, reason: 'stored entry');
    expect(await zip.readBytes(pic), binary);

    expect(
      utf8.decode(await zip.readBytes(zip.find('OEBPS/Ünïcødé name.xhtml')!)),
      'unicode',
    );
  }

  test('reads stored, deflated and UTF-8 named entries from memory', () async {
    await expectReadsBack(await EpubZip.openBytes(zipBytes));
  });

  test('reads entries from a file without loading it whole', () async {
    final dir = await Directory.systemTemp.createTemp('epub_zip_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/book.epub')..writeAsBytesSync(zipBytes);
    await expectReadsBack(await EpubZip.openFile(file.path));
  });

  test('concurrent reads of the same entry are independent', () async {
    final zip = await EpubZip.openBytes(zipBytes);
    final ch1 = zip.find('OEBPS/ch1.xhtml')!;
    final results = await Future.wait(List.generate(8, (_) => zip.readBytes(ch1)));
    for (final r in results) {
      expect(r, text);
    }
  });

  test('find falls back to a case-insensitive match', () async {
    final zip = await EpubZip.openBytes(zipBytes);
    expect(zip.find('oebps/images/PIC.bin')?.name, 'OEBPS/Images/pic.bin');
    expect(zip.find('OEBPS/missing.xhtml'), isNull);
  });

  test('handles a zip comment after the central directory', () async {
    final archive = Archive()
      ..add(ArchiveFile.bytes('a.txt', utf8.encode('hello')))
      ..comment = 'x' * 1000;
    final zip = await EpubZip.openBytes(ZipEncoder().encodeBytes(archive));
    expect(utf8.decode(await zip.readBytes(zip.find('a.txt')!)), 'hello');
  });

  test('rejects data that is not a zip', () async {
    await expectLater(
      EpubZip.openBytes(Uint8List.fromList(utf8.encode('not a zip at all'))),
      throwsA(isA<EpubZipException>()),
    );
    await expectLater(
      EpubZip.openBytes(Uint8List(0)),
      throwsA(isA<EpubZipException>()),
    );
  });

  test('reads the bundled sample EPUB', () async {
    final zip = await EpubZip.openFile('example/assets/sample.epub');
    final container = zip.find('META-INF/container.xml');
    expect(container, isNotNull);
    expect(utf8.decode(await zip.readBytes(container!)), contains('rootfile'));
    // Every entry inflates to its declared size.
    for (final entry in zip.entries.values) {
      expect((await zip.readBytes(entry)).length, entry.size, reason: entry.name);
    }
  });
}
