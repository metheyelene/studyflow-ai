/// Conditional wrapper: only web builds compile the `package:web`
/// (dart:js_interop) implementation, so `flutter test` on the VM never
/// pulls in a web-only library.
library;

export 'capture_storage_io.dart'
    if (dart.library.js_interop) 'capture_storage_web.dart';
