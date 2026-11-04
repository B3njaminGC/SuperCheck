import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// Una versión más nueva que la instalada.
class UpdateInfo {
  const UpdateInfo({
    required this.build,
    required this.url,
    this.size,
    this.sha256,
    this.pageUrl,
  });

  /// Número de compilación (el mismo que lleva la etiqueta `app-N` de la release).
  final int build;

  /// Dónde descargar el APK.
  final Uri url;

  /// Tamaño exacto del APK en bytes, para comprobar que la descarga llegó completa.
  final int? size;

  /// Huella SHA-256 (en hexadecimal) del APK, si GitHub la informa.
  final String? sha256;

  /// Página de la release, para abrirla en el navegador si la descarga falla.
  final Uri? pageUrl;
}

/// Lee la respuesta de GitHub (`releases/latest`). Devuelve `null` si no tiene el formato
/// esperado: esos datos vienen de afuera, así que solo se aceptan links https de GitHub.
UpdateInfo? parseLatestRelease(Object? json) {
  if (json is! Map) return null;
  final tag = json['tag_name'];
  if (tag is! String) return null;
  final match = RegExp(r'^app-(\d+)$').firstMatch(tag);
  if (match == null) return null;

  String? url;
  int? size;
  String? sha256;
  final assets = json['assets'];
  if (assets is List) {
    for (final a in assets) {
      if (a is Map && a['name'] == 'SuperCheck.apk') {
        url = a['browser_download_url'] as String?;
        final s = a['size'];
        size = s is int && s > 0 ? s : null;
        final digest = a['digest'];
        if (digest is String && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(digest)) {
          sha256 = digest.substring('sha256:'.length);
        }
      }
    }
  }
  final page = _githubUri(json['html_url']);
  // Sin el APK en la release no hay nada que descargar dentro de la app.
  final apk = _githubUri(url) ?? page;
  if (apk == null) return null;

  return UpdateInfo(
    build: int.parse(match.group(1)!),
    url: apk,
    size: apk == page ? null : size,
    sha256: apk == page ? null : sha256,
    pageUrl: page,
  );
}

/// Esos datos vienen de afuera: solo se aceptan links https de github.com.
Uri? _githubUri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') return null;
  return uri;
}

/// Número de compilación instalado (0 si no se puede leer).
final installedBuildProvider = FutureProvider<int>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  } catch (_) {
    return 0;
  }
});

/// Versión nueva disponible, o `null` (no hay, no hay internet o no se pudo consultar).
/// Nunca falla: el aviso es un extra y no debe molestar.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final installed = await ref.watch(installedBuildProvider.future);
  if (installed <= 0) return null;
  try {
    final res = await http.get(
      Uri.parse(AppConstants.latestReleaseApi),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': AppConstants.offUserAgent,
      },
    ).timeout(AppConstants.httpTimeout);
    if (res.statusCode != 200) return null;
    final info = parseLatestRelease(jsonDecode(utf8.decode(res.bodyBytes)));
    return info != null && info.build > installed ? info : null;
  } catch (_) {
    return null;
  }
});

/// Abre un link en el navegador. Es un provider para poder reemplazarlo en las pruebas.
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);
