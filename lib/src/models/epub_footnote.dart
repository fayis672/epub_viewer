///Footnote passed to [EpubViewer.onFootnoteTapped]
class EpubFootnote {
  /// Location of the note, relative to the book's package folder
  /// (e.g. `Text/notes.xhtml#n1`). Pass it to `EpubController.display` to
  /// navigate to the note.
  final String href;

  /// Plain text of the note, with whitespace collapsed
  final String text;

  /// Inner HTML of the note element
  final String html;

  /// Text of the tapped link, usually the note number (e.g. `1`)
  final String linkText;

  EpubFootnote({
    required this.href,
    required this.text,
    required this.html,
    required this.linkText,
  });

  factory EpubFootnote.fromJson(Map<String, dynamic> json) => EpubFootnote(
        href: json['href'] as String? ?? '',
        text: json['text'] as String? ?? '',
        html: json['html'] as String? ?? '',
        linkText: json['linkText'] as String? ?? '',
      );
}
