import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = String.fromEnvironment('GEMINI_API_KEY');
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=' + apiKey);
  
  print('Fetching models...');
  try {
    final response = await http.get(url);
    print('Status code: ' + response.statusCode.toString());
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final models = json['models'] as List;
      for (var model in models) {
        if (model['name'].toString().contains('gemini')) {
          print(model['name']);
        }
      }
    } else {
      print('Error: ' + response.body);
    }
  } catch (e) {
    print('Exception: ' + e.toString());
  }
}
