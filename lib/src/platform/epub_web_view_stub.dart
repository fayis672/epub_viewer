import 'package:flutter/widgets.dart';

import 'epub_web_view_interface.dart';

/// Fallback used only when neither `dart:io` nor `dart:js_interop` is available.
///
/// A real implementation is always selected on supported platforms via the
/// conditional export in `epub_web_view.dart`.
Widget createEpubPlatformView(EpubPlatformViewConfig config) {
  throw UnsupportedError(
    'flutter_epub_viewer is not supported on this platform.',
  );
}
