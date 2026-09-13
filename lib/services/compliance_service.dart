
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages 6 Nigerian statutory compliance obligations.
/// Syncs to Firestore when authenticated; falls back to SharedPreferences offline.
class ComplianceService {
  static final ComplianceService _instance = ComplianceService._internal();
  factory ComplianceService() => _instance;
  ComplianceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  static const List<String> taskIds = [
    'cac_annual',
    'firs_cit',
    'firs_vat',
    'pencom',
    'nsitf',
    'itf',
  ];

  /// Load compliance statuses. Firestore is source of truth; falls back to local.
  Future<Map<String, bool>> loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid;

    // Try Firestore first
    if (uid != null) {
      try {
        final Map<String, bool> statuses = {};
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('compliance')
            .get();

        for (final id in taskIds) {
          final doc = snapshot.docs.where((d) => d.id == id).firstOrNull;
          final isDone = doc?.data()['isDone'] as bool? ?? false;
          statuses[id] = isDone;
          // Mirror to local cache
          await prefs.setBool('compliance_$id', isDone);
        }
        return statuses;
      } catch (e) {
        debugPrint('ComplianceService: Firestore load failed, using local: $e');
      }
    }

    // Fallback: local SharedPreferences
    final Map<String, bool> statuses = {};
    for (final id in taskIds) {
      statuses[id] = prefs.getBool('compliance_$id') ?? false;
    }
    return statuses;
  }

  /// Mark a task as done (filed).
  Future<void> markDone(String taskId) async {
    await _writeStatus(taskId, true);
  }

  /// Mark a task as pending (reset).
  Future<void> markPending(String taskId) async {
    await _writeStatus(taskId, false);
  }

  Future<void> _writeStatus(String taskId, bool isDone) async {
    final prefs = await SharedPreferences.getInstance();
    // Always write locally first (optimistic update)
    await prefs.setBool('compliance_$taskId', isDone);

    final uid = _uid;
    if (uid != null) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('compliance')
            .doc(taskId)
            .set({
          'isDone': isDone,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('ComplianceService: Firestore write failed (local saved): $e');
      }
    }
  }

  /// Returns completed count and progress (0.0 to 1.0).
  Future<Map<String, dynamic>> getProgress() async {
    final statuses = await loadStatus();
    final completed = statuses.values.where((v) => v).length;
    final total = taskIds.length;
    return {
      'completed': completed,
      'total': total,
      'progress': total > 0 ? completed / total : 0.0,
    };
  }

  /// Sync any locally-stored statuses up to Firestore (called after login).
  Future<void> syncOfflineStatuses() async {
    final uid = _uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    try {
      for (final id in taskIds) {
        final localValue = prefs.getBool('compliance_$id');
        if (localValue != null) {
          await _firestore
              .collection('users')
              .doc(uid)
              .collection('compliance')
              .doc(id)
              .set({
            'isDone': localValue,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint('ComplianceService: Offline sync failed: $e');
    }
  }
}
