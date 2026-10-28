import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Thrown when a file is not a zip this reader can serve (not a zip, ZIP64,
/// encrypted entries, or an unsupported compression method). The viewer then
/// falls back to handing epub.js the whole file.
class EpubZipException implements Exception {
  EpubZipException(this.message);

  final String message;

  @override
  String toString() => 'EpubZipException: $message';
}

/// One file inside the EPUB container.
class EpubZipEntry {
  EpubZipEntry._({
    required this.name,
    required this.method,
    required this.compressedSize,
    required this.size,
    required int localHeaderOffset,
  }) : _localHeaderOffset = localHeaderOffset;

  /// Path inside the archive, e.g. `OEBPS/ch1.xhtml`.
  final String name;

  /// 0 = stored, 8 = deflate.
  final int method;
  final int compressedSize;

  /// Uncompressed size in bytes.
  final int size;

  final int _localHeaderOffset;

  /// Start of the entry's data; resolved from the local header on first read.
  int? _dataOffset;
}

/// Random-access reader for an EPUB's zip container.
///
/// Only the central directory is read up front. Each entry is read and
/// inflated on demand, streaming straight from disk for files, so serving a
/// book never needs the whole archive in memory.
class EpubZip {
  EpubZip._(this._storage, this.entries)
      : _byLowerCase = {
          for (final e in entries.values) e.name.toLowerCase(): e,
        };

  /// Opens the zip at [path] without reading it into memory.
  static Future<EpubZip> openFile(String path) async {
    final file = File(path);
    return _open(_FileStorage(file, await file.length()));
  }

  /// Opens a zip that is already in memory (assets, `EpubSource.fromData`).
  static Future<EpubZip> openBytes(Uint8List bytes) {
    return _open(_BytesStorage(bytes));
  }

  final _ZipStorage _storage;

  /// Entries by exact path. Directories are not included.
  final Map<String, EpubZipEntry> entries;
  final Map<String, EpubZipEntry> _byLowerCase;

  /// Looks up [name] exactly, then case-insensitively (books often reference
  /// `Images/x.jpg` while the archive stores `images/x.jpg`).
  EpubZipEntry? find(String name) =>
      entries[name] ?? _byLowerCase[name.toLowerCase()];

  /// Streams the uncompressed bytes of [entry].
  Stream<List<int>> read(EpubZipEntry entry) async* {
    final offset = entry._dataOffset ??= await _dataOffset(entry);
    final raw = _storage.stream(offset, entry.compressedSize);
    switch (entry.method) {
      case 0:
        yield* raw;
      case 8:
        yield* raw.transform(ZLibDecoder(raw: true));
      default:
        throw EpubZipException(
          'Unsupported compression method ${entry.method} for ${entry.name}',
        );
    }
  }

  /// Reads all of [entry] into memory (for tests and small files).
  Future<Uint8List> readBytes(EpubZipEntry entry) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in read(entry)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<int> _dataOffset(EpubZipEntry entry) async {
    final header = ByteData.sublistView(
      await _storage.read(entry._localHeaderOffset, 30),
    );
    if (header.lengthInBytes < 30 ||
        header.getUint32(0, Endian.little) != _localHeaderSignature) {
      throw EpubZipException('Corrupt local header for ${entry.name}');
    }
    final nameLength = header.getUint16(26, Endian.little);
    final extraLength = header.getUint16(28, Endian.little);
    return entry._localHeaderOffset + 30 + nameLength + extraLength;
  }

  static const _localHeaderSignature = 0x04034b50;
  static const _centralHeaderSignature = 0x02014b50;
  static const _endOfCentralDirSignature = 0x06054b50;

  static Future<EpubZip> _open(_ZipStorage storage) async {
    // The end-of-central-directory record is 22 bytes plus a comment of up to
    // 64 KB, at the very end of the file.
    final tailLength = storage.length < 22 + 0xFFFF
        ? storage.length
        : 22 + 0xFFFF;
    if (tailLength < 22) throw EpubZipException('Not a zip file');
    final tailStart = storage.length - tailLength;
    final tail = ByteData.sublistView(await storage.read(tailStart, tailLength));

    var eocd = -1;
    for (var i = tailLength - 22; i >= 0; i--) {
      if (tail.getUint32(i, Endian.little) == _endOfCentralDirSignature) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) throw EpubZipException('Not a zip file');

    final entryCount = tail.getUint16(eocd + 10, Endian.little);
    final dirSize = tail.getUint32(eocd + 12, Endian.little);
    final dirOffset = tail.getUint32(eocd + 16, Endian.little);
    if (entryCount == 0xFFFF ||
        dirSize == 0xFFFFFFFF ||
        dirOffset == 0xFFFFFFFF) {
      throw EpubZipException('ZIP64 archives are not supported');
    }
    if (dirOffset + dirSize > storage.length) {
      throw EpubZipException('Corrupt central directory');
    }

    final dir = ByteData.sublistView(await storage.read(dirOffset, dirSize));
    final entries = <String, EpubZipEntry>{};
    var p = 0;
    for (var i = 0; i < entryCount; i++) {
      if (p + 46 > dir.lengthInBytes ||
          dir.getUint32(p, Endian.little) != _centralHeaderSignature) {
        throw EpubZipException('Corrupt central directory');
      }
      final flags = dir.getUint16(p + 8, Endian.little);
      final method = dir.getUint16(p + 10, Endian.little);
      final compressedSize = dir.getUint32(p + 20, Endian.little);
      final size = dir.getUint32(p + 24, Endian.little);
      final nameLength = dir.getUint16(p + 28, Endian.little);
      final extraLength = dir.getUint16(p + 30, Endian.little);
      final commentLength = dir.getUint16(p + 32, Endian.little);
      final localHeaderOffset = dir.getUint32(p + 42, Endian.little);
      final nameBytes = Uint8List.sublistView(dir, p + 46, p + 46 + nameLength);
      p += 46 + nameLength + extraLength + commentLength;

      if (flags & 0x1 != 0) {
        throw EpubZipException('Encrypted zip entries are not supported');
      }
      if (compressedSize == 0xFFFFFFFF ||
          size == 0xFFFFFFFF ||
          localHeaderOffset == 0xFFFFFFFF) {
        throw EpubZipException('ZIP64 archives are not supported');
      }
      final name = _decodeName(nameBytes, utf8Flag: flags & 0x800 != 0);
      if (name.endsWith('/')) continue; // directory
      entries[name] = EpubZipEntry._(
        name: name,
        method: method,
        compressedSize: compressedSize,
        size: size,
        localHeaderOffset: localHeaderOffset,
      );
    }
    return EpubZip._(storage, entries);
  }

  static String _decodeName(Uint8List bytes, {required bool utf8Flag}) {
    if (utf8Flag) return utf8.decode(bytes, allowMalformed: true);
    // Without the flag the spec says CP437, but EPUB tools write UTF-8 in
    // practice. Fall back to Latin-1 for names that are not valid UTF-8.
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}

abstract class _ZipStorage {
  int get length;
  Future<Uint8List> read(int offset, int length);
  Stream<List<int>> stream(int offset, int length);
}

class _FileStorage implements _ZipStorage {
  _FileStorage(this._file, this.length);

  final File _file;

  @override
  final int length;

  @override
  Future<Uint8List> read(int offset, int length) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream(offset, length)) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  // Each read opens its own stream, so concurrent requests never contend for
  // a shared file handle.
  @override
  Stream<List<int>> stream(int offset, int length) =>
      _file.openRead(offset, offset + length);
}

class _BytesStorage implements _ZipStorage {
  _BytesStorage(this._bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Future<Uint8List> read(int offset, int length) async =>
      Uint8List.sublistView(_bytes, offset, _clamp(offset + length));

  @override
  Stream<List<int>> stream(int offset, int length) =>
      Stream.value(Uint8List.sublistView(_bytes, offset, _clamp(offset + length)));

  int _clamp(int end) => end > _bytes.length ? _bytes.length : end;
}
