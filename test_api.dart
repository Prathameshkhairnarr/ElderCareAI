import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final url = Uri.https('api.apilayer.com', '/number_verification/validate', {'number': '+917056233509'});
    print(url.toString());
    final response = await http.get(url, headers: {'apikey': 'KGRLVLwCoTbx6bzOcnxSrmAQbDLnUCG0'});
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch(e) {
    print('Error: $e');
  }
}
