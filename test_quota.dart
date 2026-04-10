import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiKey = 'AIzaSyADzvXUy3OgSU0nR5iTK8Gba6WVPy8xl00';
  final models = ['gemini-pro-latest', 'gemini-flash-latest', 'gemini-2.5-flash'];
  
  for (var model in models) {
    print('Testing \$model...');
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/\$model:generateContent?key=\$apiKey';
    
    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': 'Hello'}]
        }
      ]
    };
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      print('Status: \${response.statusCode}');
      if (response.statusCode != 200) {
        print(response.body);
      } else {
        print('SUCCESS for \$model!');
        break; // Stop on first success
      }
    } catch (e) {
      print('Exception: \$e');
    }
  }
}
