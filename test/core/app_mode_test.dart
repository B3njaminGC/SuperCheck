import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/core/mode/app_mode.dart';

Future<ProviderContainer> containerWith({
  required Map<String, Object> stored,
  required bool cloudAvailable,
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      cloudAvailableProvider.overrideWithValue(cloudAvailable),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('la primera vez arranca sin cuenta', () async {
    final container = await containerWith(stored: {}, cloudAvailable: true);
    expect(container.read(appModeProvider), AppMode.local);
  });

  test('sin servidor configurado siempre usa el modo local', () async {
    final container = await containerWith(
      stored: {'app_mode': 'cloud'},
      cloudAvailable: false,
    );
    expect(container.read(appModeProvider), AppMode.local);

    await container.read(appModeProvider.notifier).set(AppMode.cloud);
    expect(container.read(appModeProvider), AppMode.local);
  });

  test('con servidor configurado recuerda el modo elegido', () async {
    final container = await containerWith(
      stored: {'app_mode': 'cloud'},
      cloudAvailable: true,
    );
    expect(container.read(appModeProvider), AppMode.cloud);

    await container.read(appModeProvider.notifier).set(AppMode.local);
    expect(container.read(appModeProvider), AppMode.local);
    expect(container.read(sharedPreferencesProvider).getString('app_mode'), 'local');
  });
}
