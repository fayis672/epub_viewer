import 'dart:io';
import 'dart:typed_data';

export 'dart:io' show File;

/// Reads the raw bytes of an EPUB [file] from the local filesystem.
Future<Uint8List> readEpubFileBytes(File file) => file.readAsBytes();
