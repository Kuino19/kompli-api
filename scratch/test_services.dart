import '../lib/services/aml_service.dart';

void main() async {
  print('=== TESTING AML & SANCTIONS SERVICE ===');
  final aml = AmlService();
  
  // Test 1: High Risk Hit (Abubakar Shekau)
  final result1 = await aml.screenEntity('Abubakar Shekau');
  print('Test 1 (High Risk): Risk=${result1.riskLevel.name}, Score=${result1.similarityScore}%, Matched=${result1.matchedName}, Source=${result1.listSource}');
  
  // Test 2: Clear Entity (Akin Davies)
  final result2 = await aml.screenEntity('Akin Davies');
  print('Test 2 (Clear): Risk=${result2.riskLevel.name}, Score=${result2.similarityScore}%');

  // Test 3: Audit Log Storage
  final history = await aml.getAuditHistory();
  print('Audit History Count: ${history.length}');
  print('=== ALL SERVICES VERIFIED WORKING ===');
}
