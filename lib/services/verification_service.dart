import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VerificationService {
  static final VerificationService _instance = VerificationService._();
  factory VerificationService() => _instance;
  VerificationService._();

  // Sandbox registry of top Nigerian companies for high-fidelity mock responses
  final Map<String, Map<String, dynamic>> _sandboxRegistry = {
    'Dangote Group': {
      'companyName': 'DANGOTE INDUSTRIES LIMITED',
      'rcNumber': 'RC99432',
      'tin': '00293849-0001',
      'status': 'ACTIVE',
      'address': '1 Alfred Rewane Road, Ikoyi, Lagos, Nigeria',
      'type': 'Private Limited Company',
      'incorporationDate': '1981-05-14',
      'industry': 'Manufacturing & Conglomerate',
      'directors': ['Aliko Dangote', 'Sani Dangote', 'Devakumar Edwin'],
      'isTaxCompliant': true,
      'lastFilingDate': '2025-11-20',
    },
    'Flutterwave': {
      'companyName': 'FLUTTERWAVE TECHNOLOGY SOLUTIONS LTD',
      'rcNumber': 'RC1324832',
      'tin': '19384029-0001',
      'status': 'ACTIVE',
      'address': '8 Providence Street, Lekki Phase 1, Lagos, Nigeria',
      'type': 'Private Limited Company',
      'incorporationDate': '2016-03-05',
      'industry': 'Financial Technology',
      'directors': ['Olugbenga Agboola', 'Iyinoluwa Aboyeji', 'Bode Abifarin'],
      'isTaxCompliant': true,
      'lastFilingDate': '2025-06-15',
    },
    'Paystack': {
      'companyName': 'PAYSTACK PAYMENTS LIMITED',
      'rcNumber': 'RC1294821',
      'tin': '09283749-0001',
      'status': 'ACTIVE',
      'address': '126 Joel Ogunnaike Street, Ikeja GRA, Lagos, Nigeria',
      'type': 'Private Limited Company',
      'incorporationDate': '2015-09-10',
      'industry': 'Financial Technology',
      'directors': ['Shola Akinlade', 'Ezra Olubi', 'Gbenro Dara'],
      'isTaxCompliant': true,
      'lastFilingDate': '2025-08-12',
    },
    'Kompli Tech': {
      'companyName': 'KOMPLI LEGAL TECHNOLOGIES LTD',
      'rcNumber': 'RC1890432',
      'tin': '29402938-0001',
      'status': 'ACTIVE',
      'address': 'Plot 14, Admiralty Way, Lekki Phase 1, Lagos, Nigeria',
      'type': 'Private Limited Company',
      'incorporationDate': '2023-01-20',
      'industry': 'Legal Technology & Compliance',
      'directors': ['Ifedayo Lawal', 'Antigravity AI', 'Oluwaseun Adebayo'],
      'isTaxCompliant': true,
      'lastFilingDate': '2025-12-05',
    },
  };

  /// Verify a business via CAC database search (Custom Scraper -> API -> Sandbox)
  Future<Map<String, dynamic>> verifyCompany(String query) async {
    final cleanQuery = query.trim().toUpperCase();
    if (cleanQuery.isEmpty) {
      throw Exception('Search query cannot be empty');
    }

    final scraperUrl = dotenv.env['SCRAPER_SERVICE_URL'];
    final dojahKey = dotenv.env['DOJAH_API_KEY'];
    final monoKey = dotenv.env['MONO_SECRET_KEY'];

    if (scraperUrl != null && scraperUrl.isNotEmpty) {
      try {
        return await _verifyWithScraper('$scraperUrl/api/scrape/cac', {'companyName': query});
      } catch (e) {
        // Fallback if custom scraper service is temporarily unavailable
      }
    }

    if (dojahKey != null && dojahKey.isNotEmpty) {
      return _verifyCompanyWithDojah(query, dojahKey);
    } else if (monoKey != null && monoKey.isNotEmpty) {
      return _verifyCompanyWithMono(query, monoKey);
    } else {
      // Simulate network delay for Sandbox mode
      await Future.delayed(const Duration(milliseconds: 1800));
      return _getSandboxCompany(query);
    }
  }

  /// Verify a Tax Identification Number (TIN) (Custom Scraper -> API -> Sandbox)
  Future<Map<String, dynamic>> verifyTin(String tin) async {
    final cleanTin = tin.trim();
    if (cleanTin.isEmpty) {
      throw Exception('TIN cannot be empty');
    }

    final scraperUrl = dotenv.env['SCRAPER_SERVICE_URL'];
    final dojahKey = dotenv.env['DOJAH_API_KEY'];

    if (scraperUrl != null && scraperUrl.isNotEmpty) {
      try {
        return await _verifyWithScraper('$scraperUrl/api/scrape/tin', {'searchVal': cleanTin});
      } catch (e) {
        // Fallback if custom scraper service is temporarily unavailable
      }
    }

    if (dojahKey != null && dojahKey.isNotEmpty) {
      return _verifyTinWithDojah(cleanTin, dojahKey);
    } else {
      // Simulate network delay for Sandbox mode
      await Future.delayed(const Duration(milliseconds: 1500));
      return _getSandboxTin(cleanTin);
    }
  }

  Future<Map<String, dynamic>> _verifyWithScraper(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json;
    }
    throw Exception('Scraper returned HTTP ${response.statusCode}');
  }

  // ─────────────────────────────────────────
  // Sandbox Engine Implementations
  // ─────────────────────────────────────────

  Map<String, dynamic> _getSandboxCompany(String query) {
    final cleanQuery = query.toLowerCase();
    
    // Check if searching for registry keys
    for (final key in _sandboxRegistry.keys) {
      if (cleanQuery.contains(key.toLowerCase()) || 
          (cleanQuery.replaceAll(RegExp(r'\D'), '').isNotEmpty &&
          _sandboxRegistry[key]!['rcNumber'].toString().contains(cleanQuery))) {
        return {
          'success': true,
          'source': 'Sandbox Database',
          'data': _sandboxRegistry[key],
        };
      }
    }

    // Dynamic fallback generation for realistic user searches
    final cleanName = query.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').toUpperCase();
    final String formattedName = cleanName.endsWith(' LTD') || cleanName.endsWith(' LIMITED') 
        ? cleanName 
        : '$cleanName NIGERIA LIMITED';

    final String generatedRc = 'RC' + (1000000 + (query.hashCode.abs() % 900000)).toString();
    final String generatedTin = (10000000 + (query.hashCode.abs() % 90000000)).toString() + '-0001';

    return {
      'success': true,
      'source': 'Sandbox Simulator',
      'data': {
        'companyName': formattedName,
        'rcNumber': generatedRc,
        'tin': generatedTin,
        'status': 'ACTIVE',
        'address': 'Plot ${12 + (query.hashCode.abs() % 80)}, Herbert Macaulay Way, Yaba, Lagos, Nigeria',
        'type': 'Private Limited Company',
        'incorporationDate': '2019-11-${(1 + (query.hashCode.abs() % 28)).toString().padLeft(2, '0')}',
        'industry': 'SME Retail & Consulting Services',
        'directors': ['${query.split(' ').first} Founder', 'Olamide Balogun'],
        'isTaxCompliant': true,
        'lastFilingDate': '2025-06-30',
      }
    };
  }

  Map<String, dynamic> _getSandboxTin(String tin) {
    final hash = tin.hashCode.abs();
    final isOdd = hash % 2 == 0;
    
    // Look up in registry if TIN matches one of the sandbox companies
    for (final company in _sandboxRegistry.values) {
      if (company['tin'] == tin) {
        return {
          'success': true,
          'source': 'Sandbox Database',
          'data': {
            'tin': tin,
            'taxpayerName': company['companyName'],
            'status': 'ACTIVE',
            'firsOffice': 'MSTO Ikoyi, Lagos',
            'email': 'finance@${company['companyName'].toString().split(' ').first.toLowerCase()}.com',
            'isCompliant': true,
          }
        };
      }
    }

    return {
      'success': true,
      'source': 'Sandbox Simulator',
      'data': {
        'tin': tin,
        'taxpayerName': 'SME ENTERPRISE ${hash % 1000}',
        'status': 'ACTIVE',
        'firsOffice': isOdd ? 'MSTO Ikeja, Lagos' : 'MSTO Wuse, Abuja',
        'email': 'tax@smeenterprise${hash % 1000}.ng',
        'isCompliant': isOdd,
      }
    };
  }

  // ─────────────────────────────────────────
  // Real Identity Provider Integrations
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>> _verifyCompanyWithMono(String query, String secretKey) async {
    final response = await http.post(
      Uri.parse('https://api.withmono.com/lookup/cac'),
      headers: {
        'Content-Type': 'application/json',
        'mono-sec-key': secretKey,
      },
      body: jsonEncode({'search': query}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return {
        'success': true,
        'source': 'Mono Live API',
        'data': {
          'companyName': json['name'],
          'rcNumber': json['rc_number'],
          'status': json['status'],
          'address': json['address'],
          'type': json['type'],
          'incorporationDate': json['registration_date'],
          'directors': List<String>.from((json['directors'] as List?)?.map((d) => d['name']) ?? []),
        }
      };
    } else {
      throw Exception('Mono company lookup failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _verifyCompanyWithDojah(String query, String apiKey) async {
    final isRc = RegExp(r'^\d+$').hasMatch(query.replaceAll(RegExp(r'\D'), ''));
    final endpoint = isRc ? 'v1/kyb/cac/rc' : 'v1/kyb/cac/name';
    final paramName = isRc ? 'rc_number' : 'company_name';

    final response = await http.get(
      Uri.parse('https://api.dojah.io/$endpoint?$paramName=$query'),
      headers: {
        'Authorization': apiKey,
        'AppId': dotenv.env['DOJAH_APP_ID'] ?? '',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final entity = json['entity'];
      return {
        'success': true,
        'source': 'Dojah Live API',
        'data': {
          'companyName': entity['company_name'],
          'rcNumber': entity['rc_number'],
          'status': entity['status'],
          'address': entity['address'],
          'type': entity['company_type'],
          'incorporationDate': entity['incorporation_date'],
          'directors': List<String>.from((entity['directors'] as List?)?.map((d) => d['name']) ?? []),
        }
      };
    } else {
      throw Exception('Dojah company lookup failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _verifyTinWithDojah(String tin, String apiKey) async {
    final response = await http.get(
      Uri.parse('https://api.dojah.io/api/v1/kyc/tin?tin=$tin'),
      headers: {
        'Authorization': apiKey,
        'AppId': dotenv.env['DOJAH_APP_ID'] ?? '',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final entity = json['entity'];
      return {
        'success': true,
        'source': 'Dojah Live API',
        'data': {
          'tin': entity['tin'] ?? tin,
          'taxpayerName': entity['taxpayer_name'],
          'status': entity['status'],
          'firsOffice': entity['firs_office'],
          'email': entity['email'],
          'isCompliant': entity['status'] == 'ACTIVE',
        }
      };
    } else {
      throw Exception('Dojah TIN lookup failed: ${response.body}');
    }
  }
}
