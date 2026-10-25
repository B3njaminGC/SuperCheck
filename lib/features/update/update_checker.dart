import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

/// Una versión más nueva que la instalada.
class UpdateInfo {
  const UpdateInfo({required this.build, required this.url});

  /// Número de compilación (el mismo que lleva la etiqueta `app-N` de la release).
  final int build;

  /// Dónde descargar el APK.
  final Uri url;
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
  final assets = json['assets'];
  if (assets is List) {
    for (final a in assets) {
      if (a is Map && a['name'] == 'SuperCheck.apk') {
        url = a['browser_download_url'] as String?;
      }
    }
  }
  url ??= json['html_url'] as String?;
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') return null;

  return UpdateInfo(build: int.parse(match.group(1)!), url: uri);
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
