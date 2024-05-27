import 'package:json_annotation/json_annotation.dart';
part 'helper.g.dart';

@JsonSerializable(explicitToJson: true)
class EpubChapter {
  /// The title of the chapter
  final String title;

  /// The href of the chapter, use to navigate to the chapter
  final String href;
  final String id;

  /// The subchapters of the chapter
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
  /// The cfi string search result
  String cfi;

  /// The excerpt of the search result
  String excerpt;

  EpubSearchResult({
    required this.cfi,
    required this.excerpt,
  });
  factory EpubSearchResult.fromJson(Map<String, dynamic> json) =>
      _$EpubSearchResultFromJson(json);
  Map<String, dynamic> toJson() => _$EpubSearchResultToJson(this);
}

@JsonSerializable(explicitToJson: true)
class EpubLocation {
  /// Start cfi string of the page
  String startCfi;

  /// End cfi string of the page
  String endCfi;

  EpubLocation({
    required this.startCfi,
    required this.endCfi,
  });
  factory EpubLocation.fromJson(Map<String, dynamic> json) =>
      _$EpubLocationFromJson(json);
  Map<String, dynamic> toJson() => _$EpubLocationToJson(this);
}

class EpubTextSelection {
  final String selectedText;
  final String selectionCfi;

  EpubTextSelection({
    required this.selectedText,
    required this.selectionCfi,
  });
}
