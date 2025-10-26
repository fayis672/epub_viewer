///Epub text selection callback object
class EpubTextSelection {
  /// The selected text
  final String selectedText;

  /// The cfi string of the selected text
  final String selectionCfi;

  EpubTextSelection({
    required this.selectedText,
    required this.selectionCfi,
  });
}
