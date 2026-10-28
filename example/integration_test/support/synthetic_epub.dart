import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds valid EPUB 3 files for load tests, so large books do not have to be
/// checked into the repo.
///
/// * [chapters] chapters of [paragraphsPerChapter] paragraphs each.
/// * When [imageSize] > 0, every chapter has one [imageSize]×[imageSize]
///   24-bit BMP of random noise (≈ 3·size² bytes, incompressible), like a
///   photo-heavy book. Images are stored, as EPUB tools do for JPEG/PNG.
Future<File> writeSyntheticEpub(
  String path, {
  required String title,
  required int chapters,
  int paragraphsPerChapter = 30,
  int imageSize = 0,
}) async {
  final random = Random(7);
  final archive = Archive();

  void add(String name, List<int> data, {bool store = false}) {
    final file = ArchiveFile.bytes(name, data)
      ..compression = store ? CompressionType.none : CompressionType.deflate;
    archive.add(file);
  }

  add('mimetype', ascii.encode('application/epub+zip'), store: true);
  add('META-INF/container.xml', utf8.encode('''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>'''));

  final manifest = StringBuffer();
  final spine = StringBuffer();
  final nav = StringBuffer();
  for (var c = 1; c <= chapters; c++) {
    final id = 'ch$c';
    manifest.writeln(
      '<item id="$id" href="text/$id.xhtml" media-type="application/xhtml+xml"/>',
    );
    spine.writeln('<itemref idref="$id"/>');
    nav.writeln('<li><a href="text/$id.xhtml">Chapter $c</a></li>');

    final body = StringBuffer('<h1>Chapter $c</h1>');
    if (imageSize > 0) {
      manifest.writeln(
        '<item id="img$c" href="images/img$c.bmp" media-type="image/bmp"/>',
      );
      body.write('<p><img src="../images/img$c.bmp" alt="Figure $c" '
          'style="max-width:100%"/></p>');
      add('OEBPS/images/img$c.bmp', _noiseBmp(imageSize, random), store: true);
    }
    for (var p = 0; p < paragraphsPerChapter; p++) {
      body.write('<p>${_paragraph(random, c, p)}</p>');
    }
    add('OEBPS/text/$id.xhtml', utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Chapter $c</title><link rel="stylesheet" href="../style.css"/></head>
<body>$body</body>
</html>'''));
  }

  add('OEBPS/style.css', utf8.encode('body { font-family: serif; } h1 { color: #333; }'));
  add('OEBPS/nav.xhtml', utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>Contents</title></head>
<body><nav epub:type="toc"><ol>$nav</ol></nav></body>
</html>'''));
  add('OEBPS/content.opf', utf8.encode('''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:synthetic-$title</dc:identifier>
    <dc:title>$title</dc:title>
    <dc:language>en</dc:language>
    <meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="css" href="style.css" media-type="text/css"/>
$manifest  </manifest>
  <spine>
$spine  </spine>
</package>'''));

  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
  return file;
}

const _words = [
  'the', 'reader', 'turned', 'page', 'quiet', 'river', 'light', 'morning',
  'window', 'story', 'across', 'distant', 'hills', 'and', 'slowly', 'water',
  'garden', 'letter', 'evening', 'voice', 'remembered', 'small', 'house',
];

String _paragraph(Random random, int chapter, int paragraph) {
  final words = List.generate(80, (_) => _words[random.nextInt(_words.length)]);
  return 'Chapter $chapter paragraph $paragraph: ${words.join(' ')}.';
}

Uint8List _noiseBmp(int size, Random random) {
  final rowSize = (size * 3 + 3) & ~3;
  final pixelBytes = rowSize * size;
  final data = ByteData(54 + pixelBytes)
    ..setUint8(0, 0x42) // 'B'
    ..setUint8(1, 0x4D) // 'M'
    ..setUint32(2, 54 + pixelBytes, Endian.little)
    ..setUint32(10, 54, Endian.little)
    ..setUint32(14, 40, Endian.little)
    ..setInt32(18, size, Endian.little)
    ..setInt32(22, size, Endian.little)
    ..setUint16(26, 1, Endian.little)
    ..setUint16(28, 24, Endian.little)
    ..setUint32(34, pixelBytes, Endian.little);
  final bytes = data.buffer.asUint8List();
  for (var i = 54; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}
