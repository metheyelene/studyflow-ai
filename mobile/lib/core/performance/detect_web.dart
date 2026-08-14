import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Logical CPU concurrency on web from `navigator.hardwareConcurrency`, or
/// 0 when the browser hides it (then the caller uses the standard tier).
int cpuCount() {
  final navigator = globalContext['navigator'];
  if (!navigator.isA<JSObject>()) return 0;
  final hardware = (navigator as JSObject)['hardwareConcurrency'];
  if (!hardware.isA<JSNumber>()) return 0;
  return (hardware as JSNumber).toDartInt;
}
