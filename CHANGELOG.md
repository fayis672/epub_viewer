## 2.0.0

Adds **Flutter Web** and **macOS** support and a substantial architecture
cleanup for performance, stability and maintainability.

### ✨ New
- **Flutter Web support.** On the web the viewer runs epub.js inside a native
  `<iframe>` (via `HtmlElementView`) and bridges to it with `dart:js_interop`
  instead of a webview plugin — all `EpubController`/`EpubViewer` APIs and
  callbacks work the same as on mobile.
- **macOS support.** macOS reuses the existing `flutter_inappwebview` (WKWebView)
  rendering path as iOS/Android, so all APIs and callbacks behave the same.
  Requires macOS 10.13+ (per `flutter_inappwebview`).
- `EpubSource.fromData(Uint8List)` — load an EPUB from in-memory bytes
  (recommended on the web, where `fromFile` is unavailable and `fromUrl` is
  subject to CORS).
- `EpubContextMenu` / `EpubContextMenuItem` — package-owned selection context
  menu types (mobile), replacing the re-exported `flutter_inappwebview` types.
- `EpubController.requestTimeout` — configurable timeout for request/response
  calls (default 20s).

### 🩹 Stability
- Request/response calls (`getCurrentLocation`, `search`, `extractText`,
  `getRectFromCfi`, `extractCurrentPageText`, `getMetadata`, `getChapters`) now
  return their values directly and **time out** instead of hanging forever if the
  JS side fails to reply. The previous shared-`Completer` design could hang or
  drop concurrent calls.
- `getRectFromCfi` now works (it previously called a JS function that did not
  exist and never completed).
- Annotation taps now reliably fire `onAnnotationClicked` (the `markClicked`
  event was never emitted to Dart before).

### ⚡ Performance
- Text-selection **polling is disabled on web/desktop** (browsers fire
  `selectionchange` reliably), removing perpetual background 200ms/2000ms timers.
  Mobile keeps the iOS/iPad polling fallback.
- Mobile transfers the EPUB bytes to JS as **base64** instead of a decimal array
  literal (a 4 MB book is ~5.5 MB of source instead of ~16 MB).

### 🧹 Maintainability
- `EpubController` no longer depends on `flutter_inappwebview` directly; all
  platform communication goes through an `EpubWebViewController` bridge.
- `loadBook` now takes an options object instead of 16 positional arguments.
- CFI/XPath conversion helpers were extracted from `epubView.js` into
  `epub_cfi_utils.js` (main glue file reduced by ~700 lines).
- Added a unit-test suite (controller RPC/parsing/timeout + model round-trips).

### ⚠️ Breaking changes
- The package no longer re-exports `ContextMenu`, `ContextMenuSettings`,
  `ContextMenuItem` from `flutter_inappwebview`. Use `EpubContextMenu` and
  `EpubContextMenuItem`:
  ```dart
  // before
  selectionContextMenu: ContextMenu(
    menuItems: [ContextMenuItem(id: 1, title: 'Highlight', action: ...)],
    settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
  ),
  // after
  selectionContextMenu: EpubContextMenu(
    hideDefaultSystemItems: true,
    items: [EpubContextMenuItem(id: 1, title: 'Highlight', action: ...)],
  ),
  ```
- `EpubController.webViewController` is now `EpubWebViewController?` (was
  `InAppWebViewController?`). The removed internal members
  `searchResultCompleter`, `currentLocationCompleter`, `cfiRectCompleter` and
  `completePageText()` were implementation details and are gone.
- Request methods now throw `TimeoutException` (from `dart:async`) on timeout.

## 1.2.8
- Fixed `getCurrentLocation` function

## 1.2.7
- Added `customCss` support in `EpubTheme` for granular styling

## 1.2.6
- Fixed dispose issue ([#71](https://github.com/fayis672/epub_viewer/issues/71))

## 1.2.5
- Added onTouchUp and onTouchDown ([#93](https://github.com/fayis672/epub_viewer/pull/93))
- Add selectAnnotationRange parameter to control annotation selection behavior ([#96](https://github.com/fayis672/epub_viewer/pull/96))
- Block navigation while text is selected ([#92](https://github.com/fayis672/epub_viewer/pull/92))
- Add XPath/XPointer support for EPUB navigation and search ([#89](https://github.com/fayis672/epub_viewer/pull/89))

## 1.2.4
- Initial progress fixes
- Relocation on font change fixes
- background decoration fixes
- Added onSelection callback with WebView-relative coordinates for custom selection UI
- Added onSelectionChanging callback for detecting selection handle dragging
- Added onDeselection callback for selection cleared events
- Added clearSelectionOnPageChange property to control selection behavior on navigation
- Fixed suppressNativeContextMenu to properly hide native context menu
- Fixed text selection coordinate mapping for accurate positioning

## 1.2.3
- iOS chapter parsing fixes

## 1.2.2
- Added book metadata

## 1.2.1
- Fixed book loading issues
- Fixed font size adjust issues
- Added change theme function
- Added navigation to first and last pages

## 1.2.0
- Added Epub Theme with background and foreground color

## 1.1.6
- Remove Highlight fix

## 1.1.5
- LTR -RTL fixes
- Sub chapter parsing fixes
- Fixed `onRelocated` callback on Android
- Changed Default display settings

## 1.1.4

- Size fit fixes

## 1.1.3

- Added reading progress

## 1.1.2

- Added Annotation click handler

## 1.1.1

- Fixed book reloading issues

## 1.1.0

- Added Local file and asset support
- Added underline annotation
- Added text content extraction

## 1.0.2

- Document changes

## 1.0.1

- Fixed blank screen

## 1.0.0

- Highlight text
- Search in Epub
- List chapters
- Text selection
- Highly customizable UI
- Resume reading using cfi
- Custom context menus for selection
