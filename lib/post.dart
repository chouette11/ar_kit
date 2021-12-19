import 'dart:convert';

import 'package:http/http.dart' as http;

Future<http.Response> postDistance(String distance) {
  return http.post(
    Uri.parse('https://c667-133-202-92-109.ngrok.io/set_distance'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'distance': distance,
    }),
  );
}