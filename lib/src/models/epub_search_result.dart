class EpubSearchResult {
  /// The cfi string search result
  String cfi;

  /// The excerpt of the search result
  String excerpt;

  /// The xpath/XPointer string of the search result
  String? xpath;

  EpubSearchResult({
    required this.cfi,
    required this.excerpt,
    this.xpath,
  });

  factory EpubSearchResult.fromJson(Map<String, dynamic> json) =>
      EpubSearchResult(
        cfi: json['cfi'] as String,
        excerpt: json['excerpt'] as String,
        xpath: json['xpath'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'cfi': cfi,
        'excerpt': excerpt,
        'xpath': xpath,
      };
}
