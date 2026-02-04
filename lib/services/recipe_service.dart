import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/recipe.dart';

class RecipeService {
  // Android emulator must use 10.0.2.2 to reach host machine.
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:8000/api';

  // TODO: replace with your machine IP if needed.
  static const String _hostIp = '192.168.1.39';
  static const String _deviceBaseUrl = 'http://$_hostIp:8000/api';

  String get baseUrl {
    if (!kIsWeb && Platform.isAndroid) {
      return _androidEmulatorBaseUrl;
    }
    return _deviceBaseUrl;
  }

  Future<List<Recipe>> fetchRecipes() async {
    final uri = Uri.parse('$baseUrl/recipes');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load recipes: ${response.statusCode}');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final data = payload['data'];

    if (data is! List) {
      return [];
    }

    return data
        .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
