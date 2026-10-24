import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda de qué lista de otra persona salió cada lista importada, para avisar
/// "ya tenés esta lista" cuando llega una versión nueva y poder reemplazarla.
class ImportedListsRegistry {
  ImportedListsRegistry(this._prefs);

  static const storageKey = 'imported_lists_v1';

  final SharedPreferences _prefs;

  Map<String, String> _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  /// Id de la lista local que se creó a partir de [sourceId], si hay.
  String? localIdFor(String sourceId) => _load()[sourceId];

  Future<void> remember(String sourceId, String localId) {
    final all = _load()..[sourceId] = localId;
    return _prefs.setString(storageKey, jsonEncode(all));
  }
}
