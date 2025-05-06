import 'dart:convert';
import 'package:example/model/highlight.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalService {
  LocalService._();

  static final LocalService instance = LocalService._();

  factory LocalService() => instance;

  final sharedPrefs = GetIt.I<SharedPreferences>();

  static const _highlightKey = 'highlight';

  Future<bool> saveHighlight(Highlight highlight) async {
    final List<Highlight> highlights = await getHighlights();
    highlights.add(highlight);

    final List<Map<String, dynamic>> highlightsJson =
        highlights.map((highlight) => highlight.toJson()).toList();
    final String highlightsString = jsonEncode(highlightsJson);

    return await sharedPrefs.setString(_highlightKey, highlightsString);
  }

  Future<List<Highlight>> getHighlights() async {
    final String? highlightsString = sharedPrefs.getString(_highlightKey);

    if (highlightsString == null || highlightsString.isEmpty) {
      return [];
    }

    final List<dynamic> highlightsJson = jsonDecode(highlightsString);
    return highlightsJson
        .map<Highlight>((json) => Highlight.fromJson(json))
        .toList();
  }
}
