import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mode/app_mode.dart';

/// `true` cuando la persona ya vio (o salteó) la bienvenida.
final onboardingDoneProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

class OnboardingController extends Notifier<bool> {
  static const storageKey = 'onboarding_done_v1';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(storageKey) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(storageKey, true);
  }
}
