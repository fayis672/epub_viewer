class EpubLocation {
  /// Start cfi string of the page
  String startCfi;

  /// End cfi string of the page
  String endCfi;

  /// Start xpath/XPointer string of the page
  String? startXpath;

  /// End xpath/XPointer string of the page
  String? endXpath;

  /// Progress percentage of location, value between 0.0 and 1.0
  double progress;

  /// Current screen page within the current chapter, starting at 1.
  /// Only set in paginated flow.
  int? chapterPage;

  /// Number of screen pages in the current chapter. Only set in paginated
  /// flow. Counting pages for the whole book would require laying out every
  /// chapter, so this is per chapter.
  int? chapterTotalPages;

  /// Printed page label from the book's page list, or null when the book has
  /// no page list.
  String? printedPage;

  EpubLocation({
    required this.startCfi,
    required this.endCfi,
    this.startXpath,
    this.endXpath,
    required this.progress,
    this.chapterPage,
    this.chapterTotalPages,
    this.printedPage,
  });

  factory EpubLocation.fromJson(Map<String, dynamic> json) => EpubLocation(
        startCfi: json['startCfi'] as String,
        endCfi: json['endCfi'] as String,
        startXpath: json['startXpath'] as String?,
        endXpath: json['endXpath'] as String?,
        progress: (json['progress'] as num).toDouble(),
        chapterPage: (json['chapterPage'] as num?)?.toInt(),
        chapterTotalPages: (json['chapterTotalPages'] as num?)?.toInt(),
        printedPage: json['printedPage'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'startCfi': startCfi,
        'endCfi': endCfi,
        'startXpath': startXpath,
        'endXpath': endXpath,
        'progress': progress,
        'chapterPage': chapterPage,
        'chapterTotalPages': chapterTotalPages,
        'printedPage': printedPage,
      };
}
