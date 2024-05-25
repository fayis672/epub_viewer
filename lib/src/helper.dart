import 'package:json_annotation/json_annotation.dart';
part 'helper.g.dart';

@JsonSerializable(explicitToJson: true)
class EpubChapter {
  final String title;
  final String href;
  final String id;
  final List<EpubChapter> subitems;

  EpubChapter({
    required this.title,
    required this.href,
    required this.id,
    required this.subitems,
  });
  factory EpubChapter.fromJson(Map<String, dynamic> json) =>
      _$EpubChapterFromJson(json);
  Map<String, dynamic> toJson() => _$EpubChapterToJson(this);
}

@JsonSerializable(explicitToJson: true)
class EpubSearchResult {
  String? cfi;
  String? excerpt;

  EpubSearchResult({
    this.cfi,
    this.excerpt,
  });
  factory EpubSearchResult.fromJson(Map<String, dynamic> json) =>
      _$EpubSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$EpubSearchResultToJson(this);
}
