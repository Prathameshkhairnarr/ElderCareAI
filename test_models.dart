import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiKey = 'AIzaSyADzvXUy3OgSU0nR5iTK8Gba6WVPy8xl00';
  final url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';
  
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final models = data['models'] as List;
      for (var model in models) {
        if (model['supportedGenerationMethods'].contains('generateContent')) {
          print(model['name']);
        }
      }
    } else {
      print('Error: \${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Exception: \$e');
  }
}
