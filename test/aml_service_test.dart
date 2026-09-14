import 'package:flutter_test/flutter_test.dart';
import 'package:kompli/services/aml_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AML Screening Test - High Risk Sanctions Hit', () async {
    final aml = AmlService();
    final result = await aml.screenEntity('Abubakar Shekau');
    
    expect(result.riskLevel, equals(AmlRiskLevel.highRiskMatch));
    expect(result.similarityScore, greaterThanOrEqualTo(85.0));
    expect(result.matchedName, contains('ABUBAKAR SHEKAU'));
  });

  test('AML Screening Test - Clear Person', () async {
    final aml = AmlService();
    final result = await aml.screenEntity('Akin Davies');
    
    expect(result.riskLevel, equals(AmlRiskLevel.clear));
    expect(result.similarityScore, lessThan(60.0));
  });
}
