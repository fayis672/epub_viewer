///Epub text extraction callback object
class EpubTextExtractRes {
  String? text;
  String? cfiRange;
  String? xpathRange;

  EpubTextExtractRes({
    this.text,
    this.cfiRange,
    this.xpathRange,
  });

  factory EpubTextExtractRes.fromJson(Map<String, dynamic> json) =>
      EpubTextExtractRes(
        text: json['text'] as String?,
        cfiRange: json['cfiRange'] as String?,
        xpathRange: json['xpathRange'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'cfiRange': cfiRange,
        'xpathRange': xpathRange,
      };
}
