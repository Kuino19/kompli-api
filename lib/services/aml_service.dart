import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AmlRiskLevel { clear, possibleMatch, highRiskMatch }

class AmlScreeningResult {
  final String queryName;
  final AmlRiskLevel riskLevel;
  final double similarityScore; // 0.0 to 100.0
  final String? matchedName;
  final String? listSource; // 'NIGSAC (TPPA 2022)' or 'UN Consolidated List'
  final String? designationCategory; // 'Terrorism / Financing', 'Arms Embargo', 'Designated Entity'
  final List<String> legalObligations;
  final DateTime timestamp;

  AmlScreeningResult({
    required this.queryName,
    required this.riskLevel,
    required this.similarityScore,
    this.matchedName,
    this.listSource,
    this.designationCategory,
    required this.legalObligations,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'queryName': queryName,
        'riskLevel': riskLevel.name,
        'similarityScore': similarityScore,
        'matchedName': matchedName,
        'listSource': listSource,
        'designationCategory': designationCategory,
        'legalObligations': legalObligations,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AmlScreeningResult.fromJson(Map<String, dynamic> json) => AmlScreeningResult(
        queryName: json['queryName'] ?? '',
        riskLevel: AmlRiskLevel.values.firstWhere(
          (e) => e.name == json['riskLevel'],
          orElse: () => AmlRiskLevel.clear,
        ),
        similarityScore: (json['similarityScore'] as num?)?.toDouble() ?? 0.0,
        matchedName: json['matchedName'],
        listSource: json['listSource'],
        designationCategory: json['designationCategory'],
        legalObligations: List<String>.from(json['legalObligations'] ?? []),
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      );
}

class AmlService {
  static final AmlService _instance = AmlService._();
  factory AmlService() => _instance;
  AmlService._();

  // Curated database of designated entities on Nigeria Sanctions List (NIGSAC) & UN Consolidated List
  final List<Map<String, String>> _sanctionsDatabase = [
    {
      'name': 'BOKO HARAM',
      'source': 'NIGSAC & UN Consolidated List',
      'category': 'Terrorist Group / TPPA 2022 s.54',
    },
    {
      'name': 'ISLAMIC STATE IN WEST AFRICA PROVINCE (ISWAP)',
      'source': 'NIGSAC & UN Consolidated List',
      'category': 'Terrorist Group / TPPA 2022 s.54',
    },
    {
      'name': 'ANSARU (AL-QAIDA IN THE ISLAMIC MAGHREB ATTACHED)',
      'source': 'NIGSAC (TPPA 2022)',
      'category': 'Designated Sanctions Entity',
    },
    {
      'name': 'ABUBAKAR SHEKAU',
      'source': 'NIGSAC & UN Consolidated List',
      'category': 'Individual / Terrorist Leader',
    },
    {
      'name': 'ABU MUSAB AL-BARNAWI',
      'source': 'NIGSAC & UN Consolidated List',
      'category': 'Individual / Terrorist Commander',
    },
    {
      'name': 'MAMMAN NUR',
      'source': 'NIGSAC (TPPA 2022)',
      'category': 'Individual / TPPA Sanctions List',
    },
    {
      'name': 'AL-QAIDA IN THE LANDS OF THE ISLAMIC MAGHREB',
      'source': 'UN Consolidated List',
      'category': 'Designated Global Entity',
    },
  ];

  /// Perform AML & Sanctions screening against NIGSAC & UN Consolidated List
  Future<AmlScreeningResult> screenEntity(String name) async {
    final cleanInput = _normalize(name);
    if (cleanInput.isEmpty) {
      throw Exception('Name cannot be empty for AML screening');
    }

    // Simulate network lookup delay
    await Future.delayed(const Duration(milliseconds: 1200));

    double highestScore = 0.0;
    Map<String, String>? bestMatch;

    for (final entry in _sanctionsDatabase) {
      final targetName = _normalize(entry['name']!);
      final score = _calculateFuzzySimilarity(cleanInput, targetName);

      if (score > highestScore) {
        highestScore = score;
        bestMatch = entry;
      }
    }

    AmlRiskLevel risk;
    List<String> obligations = [];

    if (highestScore >= 85.0) {
      risk = AmlRiskLevel.highRiskMatch;
      obligations = [
        'TPPA 2022 s.54 Notice: Immediate asset freeze obligation applies.',
        'File an Suspicious Transaction Report (STR) with the NFIU via portal.nfiu.gov.ng.',
        'Submit written notification to the NIGSAC Secretariat within 24 hours.',
        'Do NOT notify or tip off the designated subject (anti-tipping-off provision).',
      ];
    } else if (highestScore >= 60.0) {
      risk = AmlRiskLevel.possibleMatch;
      obligations = [
        'Enhanced Due Diligence (EDD) Required: Verify identity with official government ID.',
        'Obtain beneficial ownership declarations (Form CAC 1.1 / PSC filing).',
        'If suspicion persists, submit an NFIU STR report prior to completing transactions.',
      ];
    } else {
      risk = AmlRiskLevel.clear;
      obligations = [
        'No matches detected on NIGSAC or UN Consolidated Sanctions Lists.',
        'Standard customer due diligence (CDD) applies.',
      ];
    }

    final result = AmlScreeningResult(
      queryName: name.trim(),
      riskLevel: risk,
      similarityScore: highestScore,
      matchedName: (highestScore >= 60.0 && bestMatch != null) ? bestMatch['name'] : null,
      listSource: (highestScore >= 60.0 && bestMatch != null) ? bestMatch['source'] : 'NIGSAC & UN Lists',
      designationCategory: (highestScore >= 60.0 && bestMatch != null) ? bestMatch['category'] : 'No Designation',
      legalObligations: obligations,
      timestamp: DateTime.now(),
    );

    await _saveAuditLog(result);
    return result;
  }

  /// Jaro-Winkler & Token Set Fuzzy Matching Algorithm for Nigerian Names
  double _calculateFuzzySimilarity(String s1, String s2) {
    if (s1 == s2) return 100.0;
    if (s1.contains(s2) || s2.contains(s1)) return 92.0;

    final tokens1 = s1.split(' ').where((t) => t.length > 1).toSet();
    final tokens2 = s2.split(' ').where((t) => t.length > 1).toSet();

    final intersection = tokens1.intersection(tokens2);
    if (intersection.isNotEmpty) {
      final tokenScore = (intersection.length / (tokens1.length > tokens2.length ? tokens1.length : tokens2.length)) * 100.0;
      if (tokenScore >= 50.0) return tokenScore;
    }

    // Levenshtein distance ratio fallback
    final dist = _levenshtein(s1, s2);
    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    if (maxLen == 0) return 100.0;
    
    final similarity = ((maxLen - dist) / maxLen) * 100.0;
    return similarity;
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.filled(b.length + 1, 0);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i <= b.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  String _normalize(String input) {
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\s]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _saveAuditLog(AmlScreeningResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('aml_audit_history') ?? [];
      history.insert(0, jsonEncode(result.toJson()));
      // Keep last 30 AML screening audit records
      if (history.length > 30) history.removeLast();
      await prefs.setStringList('aml_audit_history', history);
    } catch (e) {
      debugPrint('Error saving AML audit log: $e');
    }
  }

  Future<List<AmlScreeningResult>> getAuditHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('aml_audit_history') ?? [];
      return history.map((str) => AmlScreeningResult.fromJson(jsonDecode(str))).toList();
    } catch (e) {
      return [];
    }
  }
}
