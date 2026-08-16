import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seam for connectivity events. Production watches the platform plugin;
/// widget tests override this with a controllable stream so the offline
/// state can be driven deterministically without platform channels.
final connectivityEventsProvider = Provider<Stream<List<ConnectivityResult>>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// Whether the device currently has no network connection. Starts
/// optimistic (online) so a launch never flashes a false offline banner,
/// then tracks the platform's connectivity stream.
final isOfflineProvider = StreamProvider<bool>((ref) {
  final events = ref.watch(connectivityEventsProvider);
  return _offlineStream(events);
});

Stream<bool> _offlineStream(Stream<List<ConnectivityResult>> events) async* {
  // Optimistic: assume online until the platform reports otherwise. The
  // plugin emits only on CHANGE, so without this the app would sit in
  // "loading" (offline=false by default via the UI fallback, but the
  // banner logic would be undefined on launch).
  yield false;
  await for (final results in events) {
    yield results.every((r) => r == ConnectivityResult.none);
  }
}
