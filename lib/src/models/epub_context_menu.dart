/// A single item in the native text-selection context menu (mobile/desktop).
///
/// This is a platform-agnostic type owned by this package so the public API
/// does not leak `flutter_inappwebview`. On mobile it is mapped to the plugin's
/// native context-menu item; on the web it is ignored (browsers manage their
/// own selection menu).
class EpubContextMenuItem {
  EpubContextMenuItem({
    required this.id,
    required this.title,
    this.action,
  });

  /// Stable identifier for the item.
  final int id;

  /// Label shown in the menu.
  final String title;

  /// Invoked when the item is tapped.
  final void Function()? action;
}

/// The native text-selection context menu (mobile/desktop only).
///
/// Pass to [EpubViewer.selectionContextMenu]. Ignored on the web.
class EpubContextMenu {
  EpubContextMenu({
    this.items = const [],
    this.hideDefaultSystemItems = false,
  });

  /// Custom menu items.
  final List<EpubContextMenuItem> items;

  /// Whether to hide the platform's default selection menu items
  /// (Copy / Look Up / …), showing only [items].
  final bool hideDefaultSystemItems;
}
