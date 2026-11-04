import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercheck/core/errors/app_exception.dart';
import 'package:supercheck/features/update/apk_downloader.dart';
import 'package:supercheck/features/update/update_checker.dart';

/// Un "APK" de mentira: empieza como un zip y tiene relleno.
List<int> _apk([int size = 6000]) => [0x50, 0x4b, 0x03, 0x04, ...List<int>.generate(size, (i) => i % 251)];

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('supercheck_update_');
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  final url = Uri.parse('https://github.com/B3njaminGC/SuperCheck/releases/download/app-9/SuperCheck.apk');

  HttpApkDownloader downloader(MockClientHandler handler) => HttpApkDownloader(
        client: MockClient(handler),
        directory: () async => dir,
      );

  MockClientHandler serving(List<int> bytes, {int status = 200}) => (request) async =>
      http.Response.bytes(bytes, status, headers: {'content-length': '${bytes.length}'});

  group('HttpApkDownloader', () {
    test('baja el archivo completo, informa el progreso y no deja restos', () async {
      final bytes = _apk();
      final progress = <int>[];
      final file = await downloader(serving(bytes)).download(
        UpdateInfo(
          build: 9,
          url: url,
          size: bytes.length,
          sha256: sha256.convert(bytes).toString(),
        ),
        onProgress: (received, total) => progress.add(received * 1000 + total),
      );

      expect(file.readAsBytesSync(), bytes);
      expect(progress.last, bytes.length * 1000 + bytes.length);
      expect(Directory('${dir.path}/update').listSync().map((e) => e.path.split('/').last),
          ['SuperCheck-9.apk']);
    });

    test('borra las descargas de versiones anteriores', () async {
      final old = File('${dir.path}/update/SuperCheck-3.apk')..createSync(recursive: true);
      await downloader(serving(_apk())).download(UpdateInfo(build: 9, url: url));
      expect(old.existsSync(), isFalse);
    });

    test('si el tamaño no coincide, la descarga es incompleta y no se ofrece', () async {
      final bytes = _apk();
      await expectLater(
        downloader(serving(bytes)).download(UpdateInfo(build: 9, url: url, size: bytes.length + 500)),
        throwsA(isA<AppException>().having((e) => e.message, 'mensaje', contains('incompleta'))),
      );
      expect(File('${dir.path}/update/SuperCheck-9.apk').existsSync(), isFalse);
      expect(File('${dir.path}/update/SuperCheck-9.apk.part').existsSync(), isFalse);
    });

    test('si la huella no coincide, el archivo está dañado', () async {
      final bytes = _apk();
      await expectLater(
        downloader(serving(bytes)).download(
          UpdateInfo(build: 9, url: url, size: bytes.length, sha256: 'b' * 64),
        ),
        throwsA(isA<AppException>().having((e) => e.message, 'mensaje', contains('dañada'))),
      );
      expect(File('${dir.path}/update/SuperCheck-9.apk').existsSync(), isFalse);
    });

    test('algo que no es un APK (por ejemplo una página web) se rechaza', () async {
      final html = '<html>${'x' * 3000}</html>'.codeUnits;
      await expectLater(
        downloader(serving(html)).download(UpdateInfo(build: 9, url: url)),
        throwsA(isA<AppException>()),
      );
    });

    test('un error del servidor da un mensaje claro', () async {
      await expectLater(
        downloader(serving(const [], status: 404)).download(UpdateInfo(build: 9, url: url)),
        throwsA(isA<RemoteServiceException>()),
      );
    });

    test('sin conexión da un error de red', () async {
      await expectLater(
        downloader((request) async => throw const SocketException('sin red'))
            .download(UpdateInfo(build: 9, url: url)),
        throwsA(isA<NetworkException>()),
      );
    });

    test('se puede cancelar y no queda nada', () async {
      final cancel = DownloadCancel()..cancel();
      await expectLater(
        downloader(serving(_apk())).download(UpdateInfo(build: 9, url: url), cancel: cancel),
        throwsA(isA<DownloadCancelled>()),
      );
      expect(Directory('${dir.path}/update').listSync(), isEmpty);
    });
  });
}
