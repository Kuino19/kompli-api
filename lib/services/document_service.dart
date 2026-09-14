import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;
  DocumentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  String _sanitizeDocId(String title) =>
      Uri.encodeComponent(title.replaceAll('/', '_'));

  // ──────────────────────────────────────────────
  // Save a document (local + Firestore)
  // ──────────────────────────────────────────────
  Future<void> saveDocument(String title, String content) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> localDocs = prefs.getStringList('saved_docs') ?? [];

    // Parse existing docs into a map to handle duplicates safely
    final Map<String, Map<String, String>> existingMap = {};
    for (final raw in localDocs) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        existingMap[decoded['title'] as String] = {
          'title': decoded['title'] as String,
          'content': decoded['content'] as String,
          'createdAt': decoded['createdAt'] as String? ??
              DateTime.now().toIso8601String(),
        };
      } catch (_) {
        // Legacy pipe-format fallback
        final sep = raw.indexOf('|');
        if (sep > -1) {
          final t = raw.substring(0, sep);
          existingMap[t] = {
            'title': t,
            'content': raw.substring(sep + 1),
            'createdAt': DateTime.now().toIso8601String(),
          };
        }
      }
    }

    // Upsert
    final isNew = !existingMap.containsKey(title);
    existingMap[title] = {
      'title': title,
      'content': content,
      'createdAt': isNew
          ? DateTime.now().toIso8601String()
          : (existingMap[title]?['createdAt'] ?? DateTime.now().toIso8601String()),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final updatedList =
        existingMap.values.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('saved_docs', updatedList);

    // Sync to Firestore
    final uid = _userId;
    if (uid != null) {
      try {
        final docId = _sanitizeDocId(title);
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('documents')
            .doc(docId)
            .set({
          'title': title,
          'content': content,
          'updatedAt': FieldValue.serverTimestamp(),
          if (isNew) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('DocumentService: Firestore save failed (cached locally): $e');
      }
    }
  }

  // ──────────────────────────────────────────────
  // Get documents (local cache + optional remote merge)
  // ──────────────────────────────────────────────
  Future<List<Map<String, String>>> getDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> localDocs = prefs.getStringList('saved_docs') ?? [];

    final Map<String, Map<String, String>> merged = {};

    // Parse local
    for (final raw in localDocs) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final title = decoded['title'] as String? ?? '';
        if (title.isNotEmpty) {
          merged[title] = {
            'title': title,
            'content': decoded['content'] as String? ?? '',
            'createdAt': decoded['createdAt'] as String? ?? '',
          };
        }
      } catch (_) {
        // Legacy pipe-format migration
        final sep = raw.indexOf('|');
        if (sep > -1) {
          final title = raw.substring(0, sep);
          merged[title] = {
            'title': title,
            'content': raw.substring(sep + 1),
            'createdAt': '',
          };
        }
      }
    }

    // Merge from Firestore (read-only, no uploads here)
    final uid = _userId;
    if (uid != null) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('documents')
            .orderBy('updatedAt', descending: true)
            .get()
            .timeout(const Duration(seconds: 2));

        bool cacheNeedsUpdate = false;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final title = data['title'] as String?;
          final content = data['content'] as String?;
          if (title != null && content != null && !merged.containsKey(title)) {
            merged[title] = {'title': title, 'content': content, 'createdAt': ''};
            cacheNeedsUpdate = true;
          }
        }

        if (cacheNeedsUpdate) {
          final updatedList =
              merged.values.map((e) => jsonEncode(e)).toList();
          await prefs.setStringList('saved_docs', updatedList);
        }
      } catch (e) {
        debugPrint('DocumentService: Firestore fetch failed (using local): $e');
      }
    }

    return merged.values.toList();
  }

  // ──────────────────────────────────────────────
  // Sync offline docs to Firestore (called after login)
  // ──────────────────────────────────────────────
  Future<void> syncOfflineDocuments() async {
    final uid = _userId;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> localDocs = prefs.getStringList('saved_docs') ?? [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('documents')
          .get();
      final existingRemoteIds = snapshot.docs.map((d) => d.id).toSet();

      for (final raw in localDocs) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final title = decoded['title'] as String? ?? '';
          final content = decoded['content'] as String? ?? '';
          if (title.isEmpty) continue;

          final docId = _sanitizeDocId(title);
          if (!existingRemoteIds.contains(docId)) {
            await _firestore
                .collection('users')
                .doc(uid)
                .collection('documents')
                .doc(docId)
                .set({
              'title': title,
              'content': content,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {
          // Skip malformed entries
        }
      }
    } catch (e) {
      debugPrint('DocumentService: Offline sync failed: $e');
    }
  }
}
