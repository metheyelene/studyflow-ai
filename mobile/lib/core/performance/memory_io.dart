import 'dart:io';

/// Native (Android/iOS/macOS/Windows/Linux): real resident-set size in KB.
int currentRssKb() => (ProcessInfo.currentRss / 1024).round();
