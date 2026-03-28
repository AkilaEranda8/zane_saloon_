import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/walkin_entry.dart';

/// Persists the walk-in queue per branch on device so the mobile screen can
/// recover after a failed network request (including when the last successful
/// fetch was an empty list).
class WalkInQueueCache {
  WalkInQueueCache._();

  static const _prefix = 'walkin_queue_cache_v1_';

  static Future<void> save(String branchId, List<WalkInEntry> entries) async {
    if (branchId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('$_prefix$branchId', raw);
  }

  /// Returns `null` if nothing was ever saved for this branch.
  static Future<List<WalkInEntry>?> load(String branchId) async {
    if (branchId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$branchId');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((m) => WalkInEntry.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
