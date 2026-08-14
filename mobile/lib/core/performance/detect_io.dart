import 'dart:io';

/// Logical CPU concurrency on native platforms (Android/iOS/desktop).
/// A coarse but dependency-free proxy for device tier: budget Android
/// devices cluster at ≤4 cores, so it separates the low-end line without
/// a platform-channel plugin or a permission.
int cpuCount() => Platform.numberOfProcessors;
