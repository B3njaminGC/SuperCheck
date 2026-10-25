import 'package:flutter_test/flutter_test.dart';
import 'package:supercheck/features/update/update_checker.dart';

void main() {
  group('parseLatestRelease', () {
    test('toma el número de la etiqueta y el link del APK', () {
      final info = parseLatestRelease({
        'tag_name': 'app-13',
        'html_url': 'https://github.com/B3njaminGC/SuperCheck/releases/tag/app-13',
        'assets': [
          {
            'name': 'SuperCheck.apk',
            'browser_download_url':
                'https://github.com/B3njaminGC/SuperCheck/releases/download/app-13/SuperCheck.apk',
          },
        ],
      });
      expect(info!.build, 13);
      expect(info.url.path, endsWith('/app-13/SuperCheck.apk'));
    });

    test('sin APK usa la página de la release', () {
      final info = parseLatestRelease({
        'tag_name': 'app-5',
        'html_url': 'https://github.com/B3njaminGC/SuperCheck/releases/tag/app-5',
        'assets': <Object>[],
      });
      expect(info!.url.path, endsWith('/tag/app-5'));
    });

    test('rechaza etiquetas raras y links que no son de GitHub', () {
      expect(parseLatestRelease(null), isNull);
      expect(parseLatestRelease({'tag_name': 'v1.2'}), isNull);
      expect(
        parseLatestRelease({'tag_name': 'app-7', 'html_url': 'https://malo.example/x.apk'}),
        isNull,
      );
      expect(
        parseLatestRelease({'tag_name': 'app-7', 'html_url': 'http://github.com/x'}),
        isNull,
      );
    });
  });
}
