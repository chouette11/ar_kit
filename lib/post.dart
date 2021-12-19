import 'dart:convert';

import 'package:http/http.dart' as http;

Future<http.Response> postDistance(String distance) {
  return http.post(
    Uri.parse('https://attamaru2.azurewebsites.net/set_distance'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'distance': distance,
    }),
  );
}