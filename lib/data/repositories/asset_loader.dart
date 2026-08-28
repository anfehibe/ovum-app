import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Carga y decodifica una lista JSON desde los assets del bundle.
Future<List<Map<String, dynamic>>> loadJsonList(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);
  final decoded = json.decode(raw) as List<dynamic>;
  return decoded.cast<Map<String, dynamic>>();
}
