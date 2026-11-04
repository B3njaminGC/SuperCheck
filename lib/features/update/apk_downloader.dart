import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/network/http_client_provider.dart';
import 'update_checker.dart';

/// Permite cortar una descarga en curso.
class DownloadCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// La persona canceló la descarga (no es un error).
class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

/// Baja el APK de una versión nueva.
abstract class ApkDownloader {
  /// Devuelve el archivo ya completo y verificado. Lanza [AppException] si algo falla y
  /// [DownloadCancelled] si se canceló. [onProgress] recibe bytes bajados y totales
  /// (0 si no se conoce el total).
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    DownloadCancel? cancel,
  });
}

/// Descarga directa por https, comprobando que el archivo esté completo antes de
/// ofrecerlo: mismo tamaño que informa GitHub, misma huella SHA-256 y formato de APK.
class HttpApkDownloader implements ApkDownloader {
  HttpApkDownloader({
    required http.Client client,
    required Future<Directory> Function() directory,
    Duration idleTimeout = const Duration(seconds: 30),
  })  : _client = client,
        _directory = directory,
        _idleTimeout = idleTimeout;

  final http.Client _client;
  final Future<Directory> Function() _directory;
  final Duration _idleTimeout;

  @override
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    DownloadCancel? cancel,
  }) async {
    final dir = Directory('${(await _directory()).path}/update');
    await dir.create(recursive: true);
    // Descargas de versiones anteriores: ya no sirven y ocupan 75 MB cada una.
    for (final entry in dir.listSync()) {
      if (entry is File) {
        try {
          entry.deleteSync();
        } on FileSystemException {
          // Se limpia en la próxima.
        }
      }
    }

    final target = File('${dir.path}/SuperCheck-${info.build}.apk');
    final partial = File('${target.path}.part');
    IOSink? sink;

    try {
      final request = http.Request('GET', info.url)
        ..headers['User-Agent'] = AppConstants.offUserAgent;
      final response = await _client.send(request).timeout(_idleTimeout);
      if (response.statusCode != 200) {
        throw RemoteServiceException(
          'No se pudo descargar la actualización (error ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }

      final expected = info.size ?? response.contentLength;
      final total = expected ?? 0;
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      sink = partial.openWrite();

      var received = 0;
      var lastReport = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in response.stream.timeout(_idleTimeout)) {
        if (cancel?.isCancelled ?? false) throw const DownloadCancelled();
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastReport).inMilliseconds >= 100) {
          lastReport = now;
          onProgress?.call(received, total);
        }
      }
      hasher.close();
      await sink.flush();
      await sink.close();
      sink = null;
      if (cancel?.isCancelled ?? false) throw const DownloadCancelled();
      onProgress?.call(received, total == 0 ? received : total);

      if (expected != null && received != expected) {
        throw const AppException(
          'La descarga quedó incompleta (se cortó la conexión). Probá de nuevo.',
        );
      }
      if (received < 1024) {
        throw const AppException('El archivo descargado no es válido. Probá de nuevo.');
      }
      final wanted = info.sha256;
      if (wanted != null && digestSink.value.toString() != wanted) {
        throw const AppException('La descarga llegó dañada. Probá de nuevo.');
      }
      final head = await partial.openRead(0, 4).expand((chunk) => chunk).toList();
      const zip = [0x50, 0x4b, 0x03, 0x04]; // un APK es un zip
      if (head.length != 4 || [for (var i = 0; i < 4; i++) head[i] == zip[i]].contains(false)) {
        throw const AppException('El archivo descargado no es un APK válido.');
      }

      await partial.rename(target.path);
      return target;
    } on TimeoutException {
      throw const NetworkException(
        'La descarga se detuvo (sin conexión o muy lenta). Probá de nuevo.',
      );
    } on SocketException {
      throw const NetworkException('No hay conexión a internet.');
    } on http.ClientException {
      throw const NetworkException('No se pudo conectar para descargar la actualización.');
    } finally {
      try {
        await sink?.close();
      } on Object {
        // El archivo parcial se borra igual.
      }
      if (await partial.exists()) await partial.delete();
    }
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _value;
  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}

final apkDownloaderProvider = Provider<ApkDownloader>(
  (ref) => HttpApkDownloader(
    client: ref.watch(httpClientProvider),
    directory: getTemporaryDirectory,
  ),
);

/// Qué pasó al intentar abrir el instalador de Android.
enum InstallOutcome { launched, needsPermission, failed }

/// Abre el instalador de Android con el APK ya descargado.
abstract class ApkInstaller {
  Future<InstallOutcome> install(String path);
}

class OpenFilexInstaller implements ApkInstaller {
  @override
  Future<InstallOutcome> install(String path) async {
    try {
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      return switch (result.type) {
        ResultType.done => InstallOutcome.launched,
        ResultType.permissionDenied => InstallOutcome.needsPermission,
        _ => InstallOutcome.failed,
      };
    } on Object {
      return InstallOutcome.failed;
    }
  }
}

final apkInstallerProvider = Provider<ApkInstaller>((ref) => OpenFilexInstaller());
