import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_models.dart';
import 'onboarding_repository.dart';

/// Router-facing onboarding store, mirroring [AuthEvents]. The app router
/// merges this into its `refreshListenable` and reads [status] synchronously
/// inside `redirect`, so a fresh account is steered to /onboarding and a
/// completed one straight into the app.
class OnboardingEvents extends ChangeNotifier {
  OnboardingEvents(this._status);

  OnboardingStatus _status;
  OnboardingStatus get status => _status;

  void set(OnboardingStatus next) {
    _status = next;
    notifyListeners();
  }

  @visibleForTesting
  void debugSet(OnboardingStatus next) {
    _status = next;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _status = OnboardingStatus.unknown;
    notifyListeners();
  }
}

/// The app's single onboarding store instance.
final OnboardingEvents onboardingEvents = OnboardingEvents(
  OnboardingStatus.unknown,
);

/// Fetches the onboarding status whenever the user becomes authenticated
/// (triggered by [AuthController]) and submits the completed form. The
/// [OnboardingEvents] store keeps the router in sync; this provider mirrors
/// it into Riverpod for widgets.
class OnboardingController extends Notifier<OnboardingStatus> {
  @override
  OnboardingStatus build() {
    onboardingEvents.addListener(_sync);
    ref.onDispose(() => onboardingEvents.removeListener(_sync));
    return onboardingEvents.status;
  }

  void _sync() => state = onboardingEvents.status;

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  /// Refresh the gate state from the backend. Never throws — on any
  /// failure the status stays `unknown` and the router does not gate.
  Future<void> refresh() async {
    try {
      final done = await _repo.isCompleted();
      onboardingEvents.set(
        done ? OnboardingStatus.done : OnboardingStatus.needed,
      );
    } catch (_) {
      // Keep `unknown`; the user can still enter the app. A later refresh
      // (e.g. after onboarding completes) corrects the state.
    }
  }

  /// Submit the completed onboarding form. Returns a friendly error string
  /// on failure, or null on success (which also unlocks the app shell).
  Future<String?> submit(OnboardingPayload payload) async {
    try {
      await _repo.submit(payload);
      onboardingEvents.set(OnboardingStatus.done);
      return null;
    } on OnboardingException catch (e) {
      return e.message;
    }
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingStatus>(
      OnboardingController.new,
    );
