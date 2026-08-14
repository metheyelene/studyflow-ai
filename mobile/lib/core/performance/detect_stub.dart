/// Fallback for platforms that expose neither `dart:io` nor `dart:js_interop`
/// (in practice never reached — native and web builds both resolve a real
/// detector). Returning 0 makes the caller fall back to the standard tier.
int cpuCount() => 0;
