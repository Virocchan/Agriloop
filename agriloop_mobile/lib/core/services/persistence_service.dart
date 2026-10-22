import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the demo state on the device so a page reload or a crash mid-pitch
/// does not wipe progress.
///
/// The snapshot is a versioned JSON blob so future schema changes can be
/// migrated rather than silently dropped.
class PersistenceService {
  const PersistenceService();

  static const String _key = 'agriloop_state_v1';
  static const int schemaVersion = 1;

  /// Loads the persisted snapshot, or null when there is nothing to restore.
  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final version = decoded['schemaVersion'];
      if (version is! int || version > schemaVersion) {
        // Future/unsupported schema: start fresh rather than crash.
        return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Persists the snapshot. Failures are swallowed — persistence must never
  /// break the demo.
  Future<void> save(Map<String, dynamic> snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        'schemaVersion': schemaVersion,
        ...snapshot,
      }));
    } catch (_) {
      // Ignore — in-memory state remains authoritative for the session.
    }
  }

  /// Wipes the stored snapshot (used by the "Reset demo data" action).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Ignore.
    }
  }
}
